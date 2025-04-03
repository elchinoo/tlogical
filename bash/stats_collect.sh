#!/bin/bash


PT_DEST=/tmp/collected/sample-`date "+%Y%m%d%H%M%S"`
PT_SAMPLES=6000
DB_NAME="test1"


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
# "SELECT * FROM pg_stat_io"
"SELECT * FROM pg_statio_user_tables"
"SELECT sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 AS cache_hit_ratio FROM pg_statio_user_tables"
"SELECT * FROM pg_stat_wal"
"SELECT * FROM pg_stat_replication"
"SELECT * FROM pg_stat_user_tables"
"SELECT * FROM pg_stat_user_indexes")

mkdir -p ${PT_DEST};
vmstat 1 $PT_SAMPLES > ${PT_DEST}/vmstat &
mpstat -u -P ALL 1 $PT_SAMPLES > ${PT_DEST}/mpstat &
iostat -dx 1 $PT_SAMPLES > ${PT_DEST}/iostat &
pidstat 1 $PT_SAMPLES > ${PT_DEST}/pidstat &
pidstat -d 1 $PT_SAMPLES > ${PT_DEST}/pidstat_d &
top -b -n1 > ${PT_DEST}/top
mount -v > ${PT_DEST}/mount
df -h > ${PT_DEST}/df_init
du --block-size=1K -s /data/pgsql/* > ${PT_DEST}/du_init
lsblk --ascii > ${PT_DEST}/lsblk
netstat -s > ${PT_DEST}/netstat
lsb_release -a > ${PT_DEST}/lsb_release
sysctl -a > ${PT_DEST}/sysctl

END_LOOP=1

while [ $END_LOOP -gt 0 ]
do
    i=0
    for _sql in "${SQL_QRY[@]}"
    do
        psql -U postgres -p 5432 -t -c "$_sql" >> ${PT_DEST}/${SQL_FNAME[${i}]} & 
        i=$((i+1))
    done
    
    echo "Waiting for the test to finish..."
    sleep 1
    psql -U postgres ${DB_NAME} -c "SELECT * FROM tb_finish" 1>/dev/null  2>&1
    END_LOOP=$?
done

df -h > ${PT_DEST}/df_finish
du --block-size=1K -s /data/pgsql/* > ${PT_DEST}/du_finish

killall vmstat mpstat iostat pidstat stats_collect.sh
