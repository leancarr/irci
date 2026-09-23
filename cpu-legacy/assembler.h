#ifndef ASSEMBLER_H
#define ASSEMBLER_H

#include <stdint.h>

/* Assemble a .asm text file into program memory.
   Returns number of instructions assembled, or -1 on error. */
int assemble_file(const char *path, uint16_t *prog_mem, int mem_size);

#endif
