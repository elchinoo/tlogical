#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <getopt.h>
#include "stats.h"

// Global definitions (ONLY HERE)
int num_threads;
int rows_per_buffer;
long global_rows_inserted = 0;
FILE *csv_file;
pthread_mutex_t file_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t global_counter_mutex = PTHREAD_MUTEX_INITIALIZER;
int eof_reached = 0;
Buffer buffers[MAX_BUFFERS];

int main(int argc, char *argv[])
{
    int opt;
    char *method = NULL;
    char *filename = NULL;
    char *conninfo = NULL;
    char *table_name = "tb_01";

    static struct option long_options[] = {
        {"threads", required_argument, 0, 't'},
        {"rows", required_argument, 0, 'r'},
        {"method", required_argument, 0, 'm'},
        {"file", required_argument, 0, 'f'},
        {"table", required_argument, 0, 'b'},
        {"connection", required_argument, 0, 'c'},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}};

    void print_usage(const char *progname)
    {
        fprintf(stderr,
                "Usage: %s [OPTIONS]\n\n"
                "Options:\n"
                "  -t, --threads=N        Number of worker threads\n"
                "  -r, --rows=N           Number of rows per batch per thread\n"
                "  -m, --method=METHOD    Insertion method: COPY or INSERT\n"
                "  -f, --file=FILE        CSV file to read from\n"
                "  -b, --table=NAME       Target table name (default: tb_01)\n"
                "  -c, --connection=CONN  PostgreSQL connection string\n"
                "  -h, --help             Show this help message\n\n",
                progname);
    }

    while ((opt = getopt_long(argc, argv, "t:r:m:f:b:c:h", long_options, NULL)) != -1)
    {
        switch (opt)
        {
        case 't':
            num_threads = atoi(optarg);
            break;
        case 'r':
            rows_per_buffer = atoi(optarg);
            break;
        case 'm':
            method = optarg;
            break;
        case 'f':
            filename = optarg;
            break;
        case 'b':
            table_name = optarg;
            break;
        case 'c':
            conninfo = optarg;
            break;
        case 'h':
        default:
            print_usage(argv[0]);
            exit(1);
        }
    }

    if (!num_threads || !rows_per_buffer || !method || !filename || !conninfo)
    {
        fprintf(stderr, "Error: missing required arguments\n");
        print_usage(argv[0]);
        exit(1);
    }

    if (num_threads < 1 || num_threads > MAX_BUFFERS)
    {
        fprintf(stderr, "Error: Threads must be between 1 and %d\n", MAX_BUFFERS);
        exit(1);
    }

    csv_file = fopen(filename, "r");
    if (!csv_file)
    {
        perror("Error opening CSV file");
        exit(1);
    }

    pthread_t reporter_thread;
    pthread_create(&reporter_thread, NULL, reporter, NULL);

    pthread_t coord_thread, worker_threads[num_threads];
    ThreadArgs targs[num_threads];

    for (int i = 0; i < num_threads; i++)
    {
        buffers[i].ready = 0;
        pthread_mutex_init(&buffers[i].mutex, NULL);
        pthread_cond_init(&buffers[i].cond, NULL);

        targs[i].thread_id = i;
        targs[i].buffer = &buffers[i];
        strcpy(targs[i].method, method);
        strcpy(targs[i].conninfo, conninfo);
        strcpy(targs[i].table_name, table_name);

        stats[i].thread_id = i;
        stats[i].total_rows = 0;
        stats[i].total_transactions = 0;
        stats[i].max_tx_time = 0;
        stats[i].min_tx_time = 1e9;

        pthread_create(&worker_threads[i], NULL, worker, &targs[i]);
    }

    clock_gettime(CLOCK_MONOTONIC, &db_start_time);
    pthread_create(&coord_thread, NULL, coordinator, NULL);
    pthread_join(coord_thread, NULL);
    pthread_join(reporter_thread, NULL);

    for (int i = 0; i < num_threads; i++)
        pthread_join(worker_threads[i], NULL);

    clock_gettime(CLOCK_MONOTONIC, &db_end_time);
    fclose(csv_file);

    print_statistics(num_threads);
    return 0;
}
