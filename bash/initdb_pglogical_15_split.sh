#!/bin/bash

set -e

TYPE="${1,,}"

PG_BIN_DIR="/usr/lib/postgresql/17"
EC="sudo -i -H -u postgres bash -c"

PG_HOME=/data
PG_WAL=${PG_HOME}/wal
PG_SPILL=${PG_HOME}/spill
PG_DATA=${PG_HOME}/pgsql
PG_PORT=5432
DB_TEST="test1"
SUPER_USER="charly"

IP_PRIMARY="172.30.1.221"
IP_REPLICA="172.30.1.85"

PSQL_BASE="psql -h 127.0.0.1 -p ${PG_PORT} -U postgres"
PSQL="${PSQL_BASE} -d ${DB_TEST} -c "

NUM_PG_RUNNING=`ps auxw | grep postgres | grep -v grep | wc -l`
if  [ "${NUM_PG_RUNNING}" -gt "0" ]
then
    ps auxw | grep postgres | grep -v grep | awk '{print $2}' | xargs sudo kill -9
    sleep 10
fi

sudo chown -R postgres: ${PG_HOME}
$EC "rm -Rf ${PG_HOME}/pgsql/* ${PG_HOME}/spill/* ${PG_HOME}/wal/*"
$EC "mkdir -p ${PG_HOME}/{pgsql,spill,wal}"

$EC "${PG_BIN_DIR}/bin/initdb -D ${PG_DATA}"
$EC "mv ${PG_DATA}/postgresql.conf ${PG_DATA}/postgresql.base.conf"

echo "

include = 'postgresql.base.conf'

listen_addresses = '*'
port = ${PG_PORT}
max_connections = 100

shared_buffers = 2GB
work_mem = 256MB

checkpoint_timeout = 15min  # Avoid frequent checkpoints
checkpoint_completion_target = 0.9  # Spread out checkpoints


##########################################################################

# WAL Optimization
# synchronous_commit = off  # Can be 'on' for data safety but impacts latency
wal_compression = on   # Reduce WAL size if CPU load allows
wal_writer_delay = 100ms  # Reduce frequent writes
wal_writer_flush_after = 1MB  # Flush after 1MB instead of every write
# 
max_wal_size = 35GB   # Adjust based on available storage
min_wal_size = 2GB    # Adjust to reduce WAL recycling overhead
# 
# wal_buffers = '512MB'

##########################################################################

# WAL Optimization
synchronous_commit = on  # Can be 'on' for data safety but impacts latency
wal_compression = off    # Reduce WAL size if CPU load allows
# wal_writer_delay = 500ms  # Reduce frequent writes
# wal_writer_flush_after = 1MB  # Flush after 1MB instead of every write
#
# max_wal_size = 4GB   # Adjust based on available storage
# min_wal_size = 1GB   # Adjust to reduce WAL recycling overhead

##########################################################################



# Memory Tuning
maintenance_work_mem = 1GB  # Increase for faster VACUUM and index rebuilds
random_page_cost = 1.1  # Optimized for SSD (higher for HDD)
seq_page_cost = 1.0  # Optimized for sequential access

# Background Writer & Checkpoint Tuning (Avoid I/O spikes by spreading out writes)
# bgwriter_lru_maxpages = 1000  # Helps with cache management
# bgwriter_lru_multiplier = 3.0  # Makes writes more aggressive
# bgwriter_delay = 50ms  # Reduces sudden I/O bursts

# Autovacuum Tuning
# autovacuum_max_workers = 4  # Increase for larger databases
# autovacuum_naptime = 30s  # Run vacuum frequently
# autovacuum_vacuum_cost_limit = 2000  # Increase if performance allows
# autovacuum_vacuum_cost_delay = 10ms  # Reduce delay for better responsiveness


################ PGLOGICAL
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
shared_preload_libraries = 'pglogical'


################ Logging 
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y%m%d.log'
log_rotation_age = 1d 
log_rotation_size = 10MB
log_truncate_on_rotation = on

" | sudo tee ${PG_DATA}/postgresql.conf

echo "

# PGLOGICAL
host    all             all            172.30.1.0/24           md5
host    replication     replicator     127.0.0.1/32            trust
host    replication     replicator     172.30.1.243/32         trust
host    replication     replicator     172.30.1.85/32          trust

" | sudo tee -a ${PG_DATA}/pg_hba.conf

sudo chown -R postgres: ${PG_HOME}

$EC "rm -Rf ${PG_WAL}/* ${PG_SPILL}/*"

$EC "mv ${PG_DATA}/pg_wal ${PG_WAL}/"
$EC "ln -vis ${PG_WAL}/pg_wal ${PG_DATA}/"

$EC "mv ${PG_DATA}/pg_replslot ${PG_SPILL}/"
$EC "ln -vis ${PG_SPILL}/pg_replslot ${PG_DATA}/"


$EC "${PG_BIN_DIR}/bin/pg_ctl -D $PG_DATA -l /dev/null start"
${PSQL_BASE} -c "CREATE USER ${SUPER_USER} SUPERUSER PASSWORD 'qaz123'"
${PSQL_BASE} -c "CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'qaz123'"
${PSQL_BASE} -c "CREATE DATABASE ${DB_TEST} OWNER ${SUPER_USER}"
${PSQL} "CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public"
${PSQL} "CREATE EXTENSION pglogical;"



# SELECT pglogical.replication_set_add_all_tables('default', '{public}'::text[]);
# SELECT pglogical.replication_set_add_all_sequences(set_name := 'default', schema_names := '{public}'::text[], synchronize_data := true );
# SELECT * FROM pglogical.show_subscription_status('subscription1');

function setup_primary()
{
    ${PSQL} "SELECT pglogical.create_node(
        node_name := 'provider',
        dsn := 'host=${IP_PRIMARY} port=${PG_PORT} dbname=${DB_TEST} user=${SUPER_USER} password=qaz123'
    );"

    ${PSQL} "SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);"
    ${PSQL} "GRANT USAGE ON SCHEMA pglogical TO ${SUPER_USER}"
}

function setup_replica()
{
    ${PSQL} "SELECT pglogical.create_node(
        node_name := 'subscriber',
        dsn := 'host=${IP_REPLICA} port=${PG_PORT} dbname=${DB_TEST} user=${SUPER_USER} password=qaz123'
    );"

    ${PSQL} "SELECT pglogical.create_subscription(
        subscription_name := 'subscription1',
        provider_dsn := 'host=${IP_PRIMARY} port=${PG_PORT} dbname=${DB_TEST} user=${SUPER_USER} password=qaz123'
    );"
}

if [ "${TYPE}" == "pri" ]
then
    echo "SETUP PRIMARY"
    setup_primary
else 
    if [ "${TYPE}" == "repl" ]
    then
        echo "SETUP REPLICA"
        setup_replica
    fi
fi

#   SELECT pglogical.wait_for_subscription_sync_complete('subscription1');
#   SELECT pglogical.create_subscription(
#       subscription_name := 'subscription2',
#       provider_dsn := 'host=172.30.1.221 port=5432 dbname=test1 user=charly password=qaz123'
#   );
