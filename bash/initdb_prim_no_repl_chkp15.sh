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


################

# WAL Optimization
synchronous_commit = off  # Can be 'on' for data safety but impacts latency
# full_page_writes = off  # Reduce WAL size (only if you have battery-backed storage)
wal_compression = on   # Reduce WAL size if CPU load allows
wal_writer_delay = 500ms  # Reduce frequent writes
wal_writer_flush_after = 1MB  # Flush after 1MB instead of every write

# max_wal_size = 200GB   # Adjust based on available storage
# min_wal_size = 10GB   # Adjust to reduce WAL recycling overhead

max_wal_size = 4GB   # Adjust based on available storage
min_wal_size = 1GB   # Adjust to reduce WAL recycling overhead


checkpoint_timeout = 15min  # Avoid frequent checkpoints
checkpoint_completion_target = 0.9  # Spread out checkpoints
wal_buffers = '512MB'

# Memory Tuning
maintenance_work_mem = 1GB  # Increase for faster VACUUM and index rebuilds
random_page_cost = 1.1  # Optimized for SSD (higher for HDD)
seq_page_cost = 1.0  # Optimized for sequential access

# Background Writer & Checkpoint Tuning (Avoid I/O spikes by spreading out writes)
bgwriter_lru_maxpages = 1000  # Helps with cache management
bgwriter_lru_multiplier = 3.0  # Makes writes more aggressive
bgwriter_delay = 50ms  # Reduces sudden I/O bursts

# Autovacuum Tuning
autovacuum_max_workers = 4  # Increase for larger databases
autovacuum_naptime = 30s  # Run vacuum frequently
autovacuum_vacuum_cost_limit = 2000  # Increase if performance allows
autovacuum_vacuum_cost_delay = 10ms  # Reduce delay for better responsiveness


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