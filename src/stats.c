#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "stats.h"

ThreadStats stats[MAX_BUFFERS];
struct timespec db_start_time, db_end_time;

#define SLOW_THRESHOLD_MS 50.0

double get_time_diff_ms(struct timespec start, struct timespec end)
{
    return (end.tv_sec - start.tv_sec) * 1000.0 +
           (end.tv_nsec - start.tv_nsec) / 1e6;
}

void print_statistics(int num_threads)
{
    double total_tx_time = 0;
    long total_rows = 0, total_tx = 0;
    double *all_tx_times = malloc(sizeof(double) * MAX_BUFFERS * MAX_TRANSACTIONS_PER_THREAD);
    if (!all_tx_times)
    {
        fprintf(stderr, "Error: Unable to allocate memory for transaction statistics.\n");
        return;
    }

    int idx = 0;
    for (int i = 0; i < num_threads; i++)
    {
        total_rows += stats[i].total_rows;
        total_tx += stats[i].total_transactions;
        for (int j = 0; j < stats[i].total_transactions; j++)
        {
            all_tx_times[idx++] = stats[i].transaction_times[j];
            total_tx_time += stats[i].transaction_times[j];
        }
    }

    double mean_tx_time = total_tx_time / total_tx;
    double mean_row_time = total_tx_time / total_rows;
    double duration_sec = get_time_diff_ms(db_start_time, db_end_time) / 1000.0;

    double inserts_per_sec = total_rows / duration_sec;
    double tx_per_sec = total_tx / duration_sec;

    double variance = 0;
    for (int i = 0; i < total_tx; i++)
    {
        variance += pow(all_tx_times[i] - mean_tx_time, 2);
    }
    double stddev = sqrt(variance / total_tx);

    double max_time = 0, min_time = 1e9;
    for (int i = 0; i < num_threads; i++)
    {
        if (stats[i].max_tx_time > max_time)
            max_time = stats[i].max_tx_time;
        if (stats[i].min_tx_time < min_time)
            min_time = stats[i].min_tx_time;
    }

    const char *red_if_slow = (mean_tx_time > SLOW_THRESHOLD_MS) ? COLOR_RED : COLOR_GREEN;
    const char *red_if_max = (max_time > SLOW_THRESHOLD_MS) ? COLOR_RED : COLOR_GREEN;
    const char *red_if_std = (stddev > 10.0) ? COLOR_RED : COLOR_GREEN;

    printf("\n%s==== Insertion Statistics ====%s\n", COLOR_YELLOW, COLOR_RESET);
    printf("%sTotal Threads:%s              %s%d%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, num_threads, COLOR_RESET);
    printf("%sTotal Transactions:%s         %s%ld%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, total_tx, COLOR_RESET);
    printf("%sTotal Rows Inserted:%s        %s%ld%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, total_rows, COLOR_RESET);
    printf("%sTotal Execution Time (s):%s   %s%.2f%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, duration_sec, COLOR_RESET);
    printf("%sAvg Time per Transaction:%s   %s%.3f ms%s\n", COLOR_BLUE, COLOR_RESET, red_if_slow, mean_tx_time, COLOR_RESET);
    printf("%sAvg Time per Row:%s           %s%.6f ms%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, mean_row_time, COLOR_RESET);
    printf("%sTransactions per Second:%s    %s%.2f%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, tx_per_sec, COLOR_RESET);
    printf("%sInserts per Second:%s         %s%.2f%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, inserts_per_sec, COLOR_RESET);
    printf("%sStddev of Tx Times (ms):%s    %s%.3f%s\n", COLOR_BLUE, COLOR_RESET, red_if_std, stddev, COLOR_RESET);
    printf("%sMax Transaction Time (ms):%s  %s%.3f%s\n", COLOR_BLUE, COLOR_RESET, red_if_max, max_time, COLOR_RESET);
    printf("%sMin Transaction Time (ms):%s  %s%.3f%s\n", COLOR_BLUE, COLOR_RESET, COLOR_GREEN, min_time, COLOR_RESET);
    printf("%s===============================%s\n", COLOR_YELLOW, COLOR_RESET);

    // Histogram
    printf("\n%sTransaction Time Histogram (ms)%s\n", COLOR_BOLD, COLOR_RESET);
    int buckets[10] = {0};
    for (int i = 0; i < total_tx; i++)
    {
        int bucket = (int)(all_tx_times[i] / 10);
        if (bucket > 9)
            bucket = 9;
        buckets[bucket]++;
    }

    for (int i = 0; i < 10; i++)
    {
        int count = buckets[i];
        int bars = count / (total_tx / 40 + 1);
        printf("[%2d - %2d ms] ", i * 10, (i + 1) * 10);
        for (int b = 0; b < bars; b++)
            printf("█");
        printf(" %s%d tx%s\n", COLOR_GREEN, count, COLOR_RESET);
    }

    free(all_tx_times);
}
