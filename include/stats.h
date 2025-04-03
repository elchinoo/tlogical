#ifndef STATS_H
#define STATS_H

#include "tlogical.h"

extern ThreadStats stats[MAX_BUFFERS];
extern struct timespec db_start_time, db_end_time;

void print_statistics(int num_threads);
double get_time_diff_ms(struct timespec start, struct timespec end);

#endif // STATS_H
