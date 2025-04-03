# PostgreSQL base path
PG_HOME := /app/pg-17

SRC_DIR := src
INC_DIR := include
BIN_DIR := bin

CC := gcc
CFLAGS := -Wall -Wextra -O2 -I$(INC_DIR) -I$(PG_HOME)/include
LDFLAGS := -L$(PG_HOME)/lib -Wl,-rpath,$(PG_HOME)/lib -lpq -lpthread -lm

SRCS := $(SRC_DIR)/main.c $(SRC_DIR)/tlogical.c $(SRC_DIR)/stats.c
OBJS := $(SRCS:.c=.o)
TARGET := $(BIN_DIR)/tlogical

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

clean:
	rm -f $(SRC_DIR)/*.o $(TARGET)

# Sample args for valgrind test (override with env variables if needed)
VALGRIND_THREADS ?= 2
VALGRIND_ROWS ?= 4000
VALGRIND_METHOD ?= COPY
VALGRIND_FILE ?= data/data_1G.csv
VALGRIND_TABLE ?= tb_01
VALGRIND_CONN ?= "host=localhost dbname=test user=charly"

valgrind: all
	valgrind --leak-check=full --track-origins=yes --show-leak-kinds=all \
	  ./$(TARGET) \
	  --threads=$(VALGRIND_THREADS) \
	  --rows=$(VALGRIND_ROWS) \
	  --method=$(VALGRIND_METHOD) \
	  --file=$(VALGRIND_FILE) \
	  --table=$(VALGRIND_TABLE) \
	  --connection="$(VALGRIND_CONN)"
