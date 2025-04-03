#!/bin/bash

source initdb_base.sh

initdb_start

echo "
listen_addresses = '*'
port = ${PG_PORT}
max_connections = 100

shared_buffers = 2GB
work_mem = 256MB

wal_level = logical

max_replication_slots = 10

# Optimize PostgreSQL settings for bulk load
# Disabled test 2
# wal_buffers = '512MB'

checkpoint_timeout = '5min'
checkpoint_completion_target = '0.9'

# Disabled test 1 2
max_wal_size = '200GB'                # Adjust based on your workload and disk spac


################
work_mem = '512MB'
maintenance_work_mem = '1GB'


################ Logging 
log_destination = 'stderr'
logging_collector = off
log_directory = 'log'
log_filename = 'postgresql-%Y%m%d.log'
log_rotation_age = 1d
log_rotation_size = 50MB
log_truncate_on_rotation = off
" > $PG_DATA/postgresql.base.conf

initdb_end