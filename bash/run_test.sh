#!/bin/bash

INIT=$1
CSV_FILE=$2

DB_HOST=$3
DB_NAME=$4

if [ $INIT == "default" ]
then
    echo "Running DEFAULT CONFIG tests" 
    ssh ubuntu@${DB_HOST} 'sudo /home/ubuntu/initdb_prim_no_repl_default.sh'
fi

if [ $INIT == "5min" ]
then
    echo "Running 05 MIN CONFIG tests" 
    ssh ubuntu@${DB_HOST} 'sudo /home/ubuntu/initdb_prim_no_repl_chkp05.sh'
fi

if [ $INIT == "15min" ]
then
    echo "Running 15 MIN CONFIG tests" 
    ssh ubuntu@${DB_HOST} 'sudo /home/ubuntu/initdb_prim_no_repl_chkp15-split.sh'
fi


if [ $INIT == "30min" ]
then
    echo "Running 30 MIN CONFIG tests" 
    ssh ubuntu@${DB_HOST} 'sudo /home/ubuntu/initdb_prim_no_repl_chkp30.sh'
fi

ssh ubuntu@${DB_HOST} 'sudo /home/ubuntu/stats_collect.sh' >/dev/null &

sleep 15

psql -h ${DB_HOST} -U charly -d ${DB_NAME} -c "DROP TABLE IF EXISTS tb_01"

psql -h ${DB_HOST} -U charly -d ${DB_NAME} -c "
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
)"

psql -h ${DB_HOST} -U charly -d ${DB_NAME} -c "CREATE INDEX idx_customer_id ON tb_01 (customer_id)"
psql -h ${DB_HOST} -U charly -d ${DB_NAME} -c "CREATE INDEX idx_customer_email ON tb_01 (email)"

time psql -h ${DB_HOST} -U charly -d ${DB_NAME} < $CSV_FILE

sleep 15

function cleanup()
{
    psql -h ${DB_HOST} -U charly -d ${DB_NAME} -c "CREATE TABLE tb_finish (a int)" 1>/dev/null  2>&1

}


trap cleanup ERR
trap cleanup SIGINT
trap cleanup EXIT