#ifndef DISPLAY_H
#define DISPLAY_H

#include "cpu.h"

/* Disassemble one instruction word into a human-readable string.
   out must be at least 40 chars. */
void disassemble(uint16_t instr, char *out, int out_size);

/* Print the full CPU state in a box layout. step = step number. */
void print_state(const CPU *cpu, int step);

/* Print a hex dump of data_mem[start .. start+count-1] */
void print_mem_range(const CPU *cpu, uint32_t start, uint32_t count);

#endif
