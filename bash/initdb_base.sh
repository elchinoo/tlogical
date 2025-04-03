#!/bin/bash

PG_BIN_DIR="/usr/lib/postgresql/17"
EC="sudo -i -H -u postgres bash -c"
PG_DATA=/data/pgsql
PG_PORT=5432


function initdb_start()
{
    ps auxw | grep postgres | grep -v grep | awk '{print $2}' | xargs kill -9

    sleep 30

    $EC "rm -Rf $PG_DATA/*"
    $EC "${PG_BIN_DIR}/bin/initdb -D $PG_DATA"
    $EC "echo \"include = 'postgresql.base.conf'\" >> $PG_DATA/postgresql.conf"
}

function initdb_end()
{
    echo "host    all             all             172.30.1.0/24                 md5" >> $PG_DATA/pg_hba.conf

    sleep 15

    $EC "${PG_BIN_DIR}/bin/pg_ctl -D $PG_DATA -l /dev/null start"
    $EC "psql -h 127.0.0.1 -p ${PG_PORT} -U postgres -c \"CREATE USER charly SUPERUSER PASSWORD 'qaz123'\""
    $EC "psql -h 127.0.0.1 -p ${PG_PORT} -U postgres -c \"CREATE DATABASE test1 OWNER charly\""
}

function split_folders()
{
    $EC "rm -Rf /data/wal/pg_wal"
    $EC "rm -Rf /data/spill/pg_replslot"

    $EC "mv /data/pgsql/pg_wal /data/wal/"
    $EC "ln -vis /data/wal/pg_wal /data/pgsql/"

    $EC "mv /data/pgsql/pg_replslot /data/spill/"
    $EC "ln -vis /data/spill/pg_replslot /data/pgsql/"
}
