#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <libpq-fe.h>
#include <time.h>
#include <unistd.h>
#include "tlogical.h"
#include "stats.h"

void *coordinator(void *arg)
{
    (void)arg;
    int i, j;
    char line[MAX_LINE_SIZE];

    while (1)
    {
        for (i = 0; i < num_threads; i++)
        {
            Buffer *buf = &buffers[i];

            pthread_mutex_lock(&buf->mutex);
            while (buf->ready)
                pthread_cond_wait(&buf->cond, &buf->mutex);

            buf->count = 0;
            pthread_mutex_lock(&file_mutex);
            for (j = 0; j < rows_per_buffer; j++)
            {
                if (fgets(line, MAX_LINE_SIZE, csv_file))
                {
                    strcpy(buf->lines[buf->count++], line);
                }
                else
                {
                    eof_reached = 1;
                    break;
                }
            }
            pthread_mutex_unlock(&file_mutex);

            buf->ready = buf->count > 0 ? 1 : 0;
            pthread_cond_signal(&buf->cond);
            pthread_mutex_unlock(&buf->mutex);

            if (eof_reached && buf->count == 0)
                return NULL;
        }
        if (eof_reached)
            return NULL;
    }
}

void *reporter(void *arg)
{
    (void)arg;
    long last_total = 0;
    struct timespec start_time, now;
    clock_gettime(CLOCK_MONOTONIC, &start_time);

    while (!eof_reached)
    {
        sleep(1);

        pthread_mutex_lock(&global_counter_mutex);
        long current_total = global_rows_inserted;
        pthread_mutex_unlock(&global_counter_mutex);

        clock_gettime(CLOCK_MONOTONIC, &now);
        double elapsed_sec = get_time_diff_ms(start_time, now) / 1000.0;
        long last_second = current_total - last_total;
        last_total = current_total;

        printf("%s[Realtime]%s Total: %s%ld%s | Last second: %s%ld%s | Avg: %s%.2f rows/s%s\n",
               COLOR_YELLOW, COLOR_RESET,
               COLOR_GREEN, current_total, COLOR_RESET,
               COLOR_BLUE, last_second, COLOR_RESET,
               COLOR_BOLD, elapsed_sec > 0 ? current_total / elapsed_sec : 0.0, COLOR_RESET);
    }

    pthread_exit(NULL);
}

void *worker(void *arg)
{
    ThreadArgs *targs = (ThreadArgs *)arg;
    PGconn *conn = PQconnectdb(targs->conninfo);

    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        pthread_exit(NULL);
    }

    Buffer *buf = targs->buffer;
    char query[65536];
    int i;

    while (1)
    {
        pthread_mutex_lock(&buf->mutex);
        while (!buf->ready)
        {
            if (eof_reached)
            {
                pthread_mutex_unlock(&buf->mutex);
                PQfinish(conn);
                pthread_exit(NULL);
            }
            pthread_cond_wait(&buf->cond, &buf->mutex);
        }

        if (buf->count == 0 && eof_reached)
        {
            pthread_mutex_unlock(&buf->mutex);
            PQfinish(conn);
            pthread_exit(NULL);
        }

        struct timespec tx_start, tx_end;
        clock_gettime(CLOCK_MONOTONIC, &tx_start);

        if (strcmp(targs->method, "COPY") == 0)
        {
            char copy_cmd[128];
            snprintf(copy_cmd, sizeof(copy_cmd), "COPY %s FROM STDIN WITH (FORMAT csv)", targs->table_name);
            PGresult *res = PQexec(conn, copy_cmd);
            if (PQresultStatus(res) != PGRES_COPY_IN)
            {
                fprintf(stderr, "COPY failed: %s\n", PQerrorMessage(conn));
                PQclear(res);
                pthread_mutex_unlock(&buf->mutex);
                PQfinish(conn);
                pthread_exit(NULL);
            }
            PQclear(res);

            for (i = 0; i < buf->count; i++)
            {
                PQputCopyData(conn, buf->lines[i], strlen(buf->lines[i]));
            }
            PQputCopyEnd(conn, NULL);
            PGresult *r;
            while ((r = PQgetResult(conn)) != NULL)
            {
                PQclear(r);
            }
        }
        else
        {
            PQexec(conn, "BEGIN");
            snprintf(query, sizeof(query),
                     "INSERT INTO %s (id, customer_id, first_name, last_name, email, country, phone_number, date_birth, purchase_date, purchase_value, num_items, credit_score, account_balance) VALUES ",
                     targs->table_name);
            for (i = 0; i < buf->count; i++)
            {
                char *token, tmp[MAX_LINE_SIZE], values[MAX_LINE_SIZE];
                strcpy(tmp, buf->lines[i]);
                int col = 0;
                strcat(query, "(");
                token = strtok(tmp, ",\n");
                while (token)
                {
                    if (col == 7 || col == 8)
                        snprintf(values, sizeof(values), "'%s'", token);
                    else if (col >= 2 && col <= 6)
                        snprintf(values, sizeof(values), "'%s'", token);
                    else
                        snprintf(values, sizeof(values), "%s", token);

                    strcat(query, values);
                    token = strtok(NULL, ",\n");
                    col++;
                    if (token)
                        strcat(query, ",");
                }
                strcat(query, ")");
                if (i < buf->count - 1)
                    strcat(query, ",");
            }
            PGresult *res = PQexec(conn, query);
            if (PQresultStatus(res) != PGRES_COMMAND_OK)
            {
                fprintf(stderr, "INSERT failed: %s\n", PQerrorMessage(conn));
                PQclear(res);
                PQexec(conn, "ROLLBACK");
                PGresult *r2;
                while ((r2 = PQgetResult(conn)) != NULL)
                    PQclear(r2);
            }
            else
            {
                PQclear(res);
                PQexec(conn, "COMMIT");
                PGresult *r2;
                while ((r2 = PQgetResult(conn)) != NULL)
                    PQclear(r2);
            }
        }

        clock_gettime(CLOCK_MONOTONIC, &tx_end);
        double elapsed = get_time_diff_ms(tx_start, tx_end);

        ThreadStats *s = &stats[targs->thread_id];
        if (s->total_transactions < MAX_TRANSACTIONS_PER_THREAD)
        {
            s->transaction_times[s->total_transactions] = elapsed;
        }
        s->total_rows += buf->count;
        s->total_transactions++;

        if (elapsed > s->max_tx_time)
            s->max_tx_time = elapsed;
        if (elapsed < s->min_tx_time || s->min_tx_time == 0)
            s->min_tx_time = elapsed;

        pthread_mutex_lock(&global_counter_mutex);
        global_rows_inserted += buf->count;
        pthread_mutex_unlock(&global_counter_mutex);

        buf->ready = 0;
        pthread_cond_signal(&buf->cond);
        pthread_mutex_unlock(&buf->mutex);
    }
}
