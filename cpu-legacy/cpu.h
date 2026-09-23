#ifndef CPU_H
#define CPU_H

#include <stdint.h>

/* ─────────────────────────────────────────────
   Kobarius ISA — opcodes (4 bits)
   ───────────────────────────────────────────── */
#define OP_LOAD  0x0   /* L-type: LOAD Rd, #imm8        */
#define OP_ADD   0x1   /* R-type: ADD  Rd, Rs1, Rs2     */
#define OP_ADDI  0x2   /* I-type: ADD  Rd, Rs,  #imm4   */
#define OP_LW    0x3   /* I-type: LW   Rd, imm4(Rs)     */
#define OP_SW    0x4   /* I-type: SW   Rs, imm4(Rb)     */
#define OP_BEQ   0x5   /* I-type: BEQ  Rs1, Rs2, imm4   */
#define OP_J     0x6   /* J-type: J    addr12           */
#define OP_HALT  0xF   /* J-type: HALT                  */

/* ─────────────────────────────────────────────
   Memory sizes
   ───────────────────────────────────────────── */
#define PROG_MEM_SIZE  4096    /* 4K words (12-bit PC) */
#define DATA_MEM_SIZE  65536   /* 64K words            */
#define NUM_REGS       16      /* R0–R15               */

/* ─────────────────────────────────────────────
   PSW — Program Status Word
   ───────────────────────────────────────────── */
typedef struct {
    uint8_t Z;   /* Zero:     result == 0                     */
    uint8_t N;   /* Negative: result bit-15 == 1              */
    uint8_t C;   /* Carry:    unsigned overflow                */
    uint8_t V;   /* Overflow: signed overflow                 */
} PSW;

/* ─────────────────────────────────────────────
   CPU state
   ───────────────────────────────────────────── */
typedef struct {
    uint16_t regs[NUM_REGS];         /* R0–R15                */
    uint16_t pc;                     /* Program Counter       */
    PSW      psw;                    /* Flags                 */
    uint16_t prog_mem[PROG_MEM_SIZE];/* Program Memory        */
    uint16_t data_mem[DATA_MEM_SIZE];/* Data Memory           */
    int      halted;                 /* 1 = stopped           */
    int      last_reg_written;       /* for display highlight */
    uint16_t last_instr;             /* last fetched word     */
} CPU;

/* ─────────────────────────────────────────────
   Bit-field extraction helpers
   ───────────────────────────────────────────── */
static inline int16_t sign_ext4(uint8_t x) {
    /* 4-bit signed -> 16-bit signed */
    return (x & 0x8) ? (int16_t)(x | 0xFFF0) : (int16_t)x;
}

static inline int16_t sign_ext8(uint8_t x) {
    /* 8-bit signed -> 16-bit signed */
    return (int16_t)(int8_t)x;
}

/* ─────────────────────────────────────────────
   Public API
   ───────────────────────────────────────────── */
void     init_cpu(CPU *cpu);
void     reset_cpu(CPU *cpu);
int      step_cpu(CPU *cpu);   /* execute one instruction, return 0=ok 1=halt -1=error */
void     update_psw(CPU *cpu, uint32_t result, uint16_t a, uint16_t b);

#endif /* CPU_H */
