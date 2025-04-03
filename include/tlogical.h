#ifndef TLOGICAL_H
#define TLOGICAL_H

#include <stdio.h>
#include <pthread.h>
#include <time.h>

#define MAX_LINE_SIZE 1024
#define MAX_BUFFERS 16
#define MAX_ROWS_PER_BUFFER 10000
#define MAX_TRANSACTIONS_PER_THREAD 100000

// ANSI Colors
#define COLOR_RESET    "\033[0m"
#define COLOR_BLUE     "\033[1;34m"
#define COLOR_GREEN    "\033[1;32m"
#define COLOR_YELLOW   "\033[1;33m"
#define COLOR_RED      "\033[1;31m"
#define COLOR_BOLD     "\033[1m"

typedef struct {
    char lines[MAX_ROWS_PER_BUFFER][MAX_LINE_SIZE];
    int count;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int ready;
} Buffer;

typedef struct {
    int thread_id;
    Buffer *buffer;
    char method[10];
    char conninfo[256];
    char table_name[64];
} ThreadArgs;

typedef struct {
    int thread_id;
    long total_rows;
    long total_transactions;
    double transaction_times[MAX_TRANSACTIONS_PER_THREAD];
    double max_tx_time;
    double min_tx_time;
} ThreadStats;

// Declare global variables using extern
extern int num_threads;
extern int rows_per_buffer;
extern FILE *csv_file;
extern pthread_mutex_t file_mutex;
extern int eof_reached;
extern Buffer buffers[MAX_BUFFERS];
extern long global_rows_inserted;
extern pthread_mutex_t global_counter_mutex;

void* reporter(void *arg);
void* coordinator(void *arg);
void* worker(void *arg);

#endif // TLOGICAL_H
