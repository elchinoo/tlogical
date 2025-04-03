#!/bin/bash

set -e

INIT=$1
CSV_FILE=$2

DB_HOST_PRI=$3
DB_HOST_REPL=$4
DB_NAME=$5

SQL_TBL="
DROP TABLE IF EXISTS tb_01;
CREATE TABLE tb_01 (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    country VARCHAR(20) NOT NULL,
    phone_number VARCHAR(15),
    date_birth DATE,
    purchase_date DATE,
    purchase_value DECIMAL(15, 2),
    num_items INTEGER,
    credit_score SMALLINT,
    account_balance NUMERIC(15, 2)
);
CREATE INDEX idx_customer_id ON tb_01 (customer_id);
CREATE INDEX idx_customer_email ON tb_01 (email);

"

if [ $INIT == "single" ]
then
    echo "Running 15 MIN CONFIG tests" 
    echo "Initializing PRIMARY" 
    sleep 5
    ssh ubuntu@${DB_HOST_PRI} "sudo /home/ubuntu/initdb_pglogical_15.sh pri ${DB_HOST_PRI} ${DB_HOST_REPL}"

    echo "Initializing REPLICA" 
    sleep 5
    ssh ubuntu@${DB_HOST_REPL} "sudo /home/ubuntu/initdb_pglogical_15.sh repl ${DB_HOST_PRI} ${DB_HOST_REPL}"
else
    if [ $INIT == "split" ]
    then
        echo "Running 15 MIN CONFIG tests" 
        echo "Initializing PRIMARY" 
        sleep 5
        ssh ubuntu@${DB_HOST_PRI} "sudo /home/ubuntu/initdb_pglogical_15_split.sh pri ${DB_HOST_PRI} ${DB_HOST_REPL}"

        echo "Initializing REPLICA" 
        sleep 5
        ssh ubuntu@${DB_HOST_REPL} "sudo /home/ubuntu/initdb_pglogical_15.sh repl ${DB_HOST_PRI} ${DB_HOST_REPL}"
    else
        exit 1
    fi
fi


ssh ubuntu@${DB_HOST_PRI} 'sudo /home/ubuntu/stats_collect.sh' >/dev/null &
ssh ubuntu@${DB_HOST_REPL} 'sudo /home/ubuntu/stats_collect.sh' >/dev/null &

sleep 10

psql -h ${DB_HOST_PRI} -U charly -d ${DB_NAME} -c "${SQL_TBL}"
psql -h ${DB_HOST_REPL} -U charly -d ${DB_NAME} -c "${SQL_TBL}"


psql -h ${DB_HOST_PRI} -U charly -d ${DB_NAME} -c "SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public'])"
psql -h ${DB_HOST_PRI} -U charly -d ${DB_NAME} -c "INSERT INTO tb_01 VALUES (0, 0, 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', NOW(), NOW(), 0, 0, 0, 0)"
sleep 5
psql -h ${DB_HOST_PRI} -U charly -d ${DB_NAME} -c "SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public'])"


time psql -h ${DB_HOST_PRI} -U charly -d ${DB_NAME} < $CSV_FILE

sleep 5

cleanup

function cleanup()
{
    psql -h ${DB_HOST_PRI} -U charly -d ${DB_NAME} -c "CREATE TABLE tb_finish (a int)" 1>/dev/null  2>&1
    psql -h ${DB_HOST_REPL} -U charly -d ${DB_NAME} -c "CREATE TABLE tb_finish (a int)" 1>/dev/null  2>&1
    ps auxw | grep ssh | grep stats | awk '{print $2}'| xargs kill

}


trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 2' ERR