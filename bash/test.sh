#!/bin/bash

declare -a SQL_FNAME=("pg_stat_activity.log"
"pg_stat_database.log"
"pg_stat_bgwriter.log"
"pg_stat_io.log"
"pg_statio_user_tables.log"
"cache_hit_ratio.log"
"pg_stat_wal.log"
"pg_stat_replication.log"
"pg_stat_user_tables.log"
"pg_stat_user_indexes.log")

declare -a SQL_QRY=("SELECT * FROM pg_stat_activity"
"SELECT * FROM pg_stat_database"
"SELECT * FROM pg_stat_bgwriter"
"SELECT * FROM pg_stat_io"
"SELECT * FROM pg_statio_user_tables"
"SELECT sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 AS cache_hit_ratio FROM pg_statio_user_tables"
"SELECT * FROM pg_stat_wal"
"SELECT * FROM pg_stat_replication"
"SELECT * FROM pg_stat_user_tables"
"SELECT * FROM pg_stat_user_indexes")

i=0
for _sql in "${SQL_QRY[@]}"
do
   echo "File: ${SQL_FNAME[${i}]} $_sql"
   i=$((i+1))
done