CC      = gcc
CFLAGS  = -Wall -Wextra -std=c11 -g

TARGET  = kobarius
SRCS    = main.c cpu.c assembler.c display.c
OBJS    = $(SRCS:.c=.o)

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Run the three built-in test programs non-interactively
test: $(TARGET)
	@echo ""
	@echo "=== TEST 1: Basic arithmetic (test.asm) ==="
	echo "run\nq" | ./$(TARGET) programs/test.asm
	@echo ""
	@echo "=== TEST 2: Countdown loop (loop.asm) ==="
	echo "run\nq" | ./$(TARGET) programs/loop.asm
	@echo ""
	@echo "=== TEST 3: Memory round-trip (mem.asm) ==="
	echo "run\nq" | ./$(TARGET) programs/mem.asm

clean:
	rm -f $(OBJS) $(TARGET)
