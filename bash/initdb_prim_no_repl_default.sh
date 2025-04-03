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