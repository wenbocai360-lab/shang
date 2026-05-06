CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror -std=c11

all: filtfilt_demo

filtfilt_demo: src/main.c src/filtfilt_fixed.c src/filtfilt_fixed.h
	$(CC) $(CFLAGS) src/main.c src/filtfilt_fixed.c -lm -o filtfilt_demo

clean:
	rm -f filtfilt_demo
