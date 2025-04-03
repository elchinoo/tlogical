# 🐘 tlogical — Load Testing for PostgreSQL with pglogical

`tlogical` is a lightweight benchmarking tool designed **specifically to evaluate PostgreSQL performance under load**, particularly when using **pglogical** for logical replication. It simulates data ingestion into a single table and helps uncover replication bottlenecks, WAL pressure, spill file generation, and transaction latency issues.

> ⚠️ This tool is intended for test environments **only**. It is **not suitable for production use**.

---

## 🧪 What It Does

- Load test PostgreSQL using **parallel inserts or COPY operations**
- Supports:
  - One large transaction
  - Multiple threads with smaller batches
- Compares the behavior **with and without pglogical**
- Collects system and PostgreSQL metrics
- Observes **replication lag, spill behavior, WAL growth, etc.**

---

## 🗃️ Table Structure Used

All data is inserted into a single test table:

```sql
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
    purchase_value DECIMAL(15,2),
    num_items INTEGER,
    credit_score SMALLINT,
    account_balance NUMERIC(15,2)
);
```

---

## 🛠️ How to Build

Requires PostgreSQL client libraries and headers (`libpq-dev`, `postgresql-devel`, etc.).

```bash
make
```

To run with memory and leak checks via Valgrind:

```bash
make valgrind  # Requires valgrind to be installed
```

---

## 🚀 How to Use

### 🔧 CLI Program

```bash
./bin/tlogical [OPTIONS]

Options:
  -t, --threads=N         Number of worker threads
  -r, --rows=N            Number of rows per batch per thread
  -m, --method=METHOD     Insertion method: COPY or INSERT
  -f, --file=FILE         CSV file to read from
  -b, --table=NAME        Target table name (default: tb_01)
  -c, --connection=CONN   PostgreSQL connection string
  -h, --help              Show help message
```

### 🧪 Example:

```bash
./bin/tlogical -t 4 -r 4000 -m COPY -f data/data_100M.csv -c "host=localhost dbname=test user=charly"
```

---

## 📂 Project Structure

```
├── bin/                  # Compiled binary goes here
├── data/                 # Pre-generated CSVs
│   ├── data_100k.csv
│   ├── data_1M.csv
│   ├── data_100M.csv
│   └── data_100M-bash.csv
├── include/
│   ├── tlogical.h
│   ├── <...>.h
├── src/
│   ├── main.c
│   ├── tlogical.c        # Main test engine (C)
│   ├── stats.c           # Metrics and statistics collection
│   ├── <...>.c
│   ├── gen_data.py       # Python script to generate random CSVs
├── bash/
│   ├── initdb_<...>.sh   # Bash scripts to spin up PostgreSQL environments
│   ├── stats_collect.sh  # Script to gather metrics during tests
├── Makefile
└── README.md
```

---

## 📊 CSV Generation (Python)

Generates random data with the Python script. For example, to generate 100M rows of random data:

```bash
python3 src/gen_data.py -o data/data_10M.csv -c 1000000 -n 10000000

```

---

## 🧵 Bash Utilities

- Scripts to start PostgreSQL environments:
  - With or without **pglogical**
  - With optional folder separation for PGDATA, WAL, and SPILL files
- `stats_collect.sh`: continuously collects:
  - PostgreSQL metrics (via SQL)
  - System metrics (via `sysstat`)
  - Stored in `/tmp/collected/sample-<timestamp>/`

> ⚠️ It only stops **when a table named `tb_finish` is created**. Be careful or edit the behavior in the script.

---

## 📈 Metrics & Performance Analysis

The C loader collects performance statistics, including:

### ✅ Global Metrics
- [x] Total Execution Time (s)
- [x] Total Transactions
- [x] Total Rows Inserted
- [x] Avg Time per Transaction
- [x] Avg Time per Row
- [x] Transactions per Second
- [x] Inserts per Second
- [x] Stddev of Tx Times (ms)
- [x] Max Transaction Time (ms)
- [x] Min Transaction Time (ms)
- [x] Transaction Time Histogram (ms)
- [ ] Overall latency percentiles (90th/95th/99th)
- [ ] Memory usage
- [ ] CPU time
- [ ] Latency histograms
- [ ] COPY vs INSERT comparison

### ✅ Per-Thread Metrics
- [x] Total Threads
- [ ] Rows inserted
- [ ] Runtime per thread
- [ ] Failed transactions
- [ ] Idle time vs active time
- [ ] Concurrency pressure
- [ ] Timeline visualizations (timestamps per thread)


---

## ⚠️ Known PostgreSQL Considerations

- Large transactions can cause **spill files**, impacting performance
- Replication lag under load may become significant
- Some PostgreSQL parameters to consider tweaking:

```
wal_buffers
checkpoint_timeout
checkpoint_completion_target
max_wal_size
wal_writer_delay
synchronous_commit
work_mem
maintenance_work_mem
max_parallel_workers
max_parallel_workers_per_gather
```

---

## 🛑 Disclaimer

This software is strictly for **testing purposes only**. Again, This software is provided for **testing purposes only. Use at your own risk**. The authors accept no responsibility for any system instability or data loss resulting from its use.

> **DO NOT use in production.**
>
> We accept **no liability** for data loss, crashes, or misuse.
