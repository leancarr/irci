#include "cpu.h"
#include <string.h>
#include <stdio.h>

/* ─────────────────────────────────────────────
   init / reset
   ───────────────────────────────────────────── */
void init_cpu(CPU *cpu) {
    memset(cpu, 0, sizeof(CPU));
    cpu->last_reg_written = -1;
}

void reset_cpu(CPU *cpu) {
    /* Keep program memory, clear everything else */
    uint16_t saved[PROG_MEM_SIZE];
    memcpy(saved, cpu->prog_mem, sizeof(saved));
    memset(cpu, 0, sizeof(CPU));
    memcpy(cpu->prog_mem, saved, sizeof(saved));
    cpu->last_reg_written = -1;
}

/* ─────────────────────────────────────────────
   PSW update
   result : 32-bit to detect carry/overflow
   a, b   : original 16-bit operands
   ───────────────────────────────────────────── */
void update_psw(CPU *cpu, uint32_t result, uint16_t a, uint16_t b) {
    uint16_t r16 = (uint16_t)result;

    cpu->psw.Z = (r16 == 0) ? 1 : 0;
    cpu->psw.N = (r16 & 0x8000) ? 1 : 0;
    cpu->psw.C = (result > 0xFFFF) ? 1 : 0;

    /* Signed overflow: same-sign operands produce different-sign result */
    int sa = (a & 0x8000) != 0;
    int sb = (b & 0x8000) != 0;
    int sr = (r16 & 0x8000) != 0;
    cpu->psw.V = (sa == sb && sr != sa) ? 1 : 0;
}

/* ─────────────────────────────────────────────
   Decode and execute one instruction
   Returns: 0=ok, 1=halt, -1=illegal opcode
   ───────────────────────────────────────────── */
int step_cpu(CPU *cpu) {
    if (cpu->halted) return 1;
    if (cpu->pc >= PROG_MEM_SIZE) {
        fprintf(stderr, "ERROR: PC out of bounds: 0x%03X\n", cpu->pc);
        return -1;
    }

    cpu->last_reg_written = -1;

    /* ── FETCH ── */
    uint16_t instr = cpu->prog_mem[cpu->pc];
    cpu->last_instr = instr;

    /* ── DECODE ── */
    uint8_t  opcode = (instr >> 12) & 0xF;
    uint8_t  f3     = (instr >> 8)  & 0xF;  /* bits 11-8  */
    uint8_t  f2     = (instr >> 4)  & 0xF;  /* bits 7-4   */
    uint8_t  f1     =  instr        & 0xF;  /* bits 3-0   */
    uint16_t addr12 =  instr        & 0xFFF;/* J-type addr */
    uint8_t  imm8   =  instr        & 0xFF; /* L-type imm  */

    /* ── EXECUTE ── */
    switch (opcode) {

        /* ── LOAD Rd, #imm8  [L-type] ── */
        case OP_LOAD: {
            uint8_t Rd = f3;
            cpu->regs[Rd] = (uint16_t)(int16_t)sign_ext8(imm8);
            cpu->last_reg_written = Rd;
            cpu->pc++;
            break;
        }

        /* ── ADD Rd, Rs1, Rs2  [R-type] ── */
        case OP_ADD: {
            uint8_t Rd  = f3;
            uint8_t Rs1 = f2;
            uint8_t Rs2 = f1;
            uint32_t result = (uint32_t)cpu->regs[Rs1] + (uint32_t)cpu->regs[Rs2];
            update_psw(cpu, result, cpu->regs[Rs1], cpu->regs[Rs2]);
            cpu->regs[Rd] = (uint16_t)result;
            cpu->last_reg_written = Rd;
            cpu->pc++;
            break;
        }

        /* ── ADD Rd, Rs, #imm4  [I-type] ── */
        case OP_ADDI: {
            uint8_t Rd  = f3;
            uint8_t Rs  = f2;
            int16_t imm = sign_ext4(f1);
            uint16_t b  = (uint16_t)imm;
            uint32_t result = (uint32_t)cpu->regs[Rs] + (uint32_t)b;
            update_psw(cpu, result, cpu->regs[Rs], b);
            cpu->regs[Rd] = (uint16_t)result;
            cpu->last_reg_written = Rd;
            cpu->pc++;
            break;
        }

        /* ── LW Rd, imm4(Rs)  [I-type] ── */
        case OP_LW: {
            uint8_t Rd  = f3;
            uint8_t Rs  = f2;
            int16_t off = sign_ext4(f1);
            uint32_t addr = (uint32_t)((int32_t)cpu->regs[Rs] + off);
            if (addr >= DATA_MEM_SIZE) {
                fprintf(stderr, "ERROR: LW address 0x%05X out of range\n", addr);
                return -1;
            }
            cpu->regs[Rd] = cpu->data_mem[addr];
            cpu->last_reg_written = Rd;
            cpu->pc++;
            break;
        }

        /* ── SW Rs, imm4(Rb)  [I-type] ── */
        case OP_SW: {
            uint8_t Rs  = f3;
            uint8_t Rb  = f2;
            int16_t off = sign_ext4(f1);
            uint32_t addr = (uint32_t)((int32_t)cpu->regs[Rb] + off);
            if (addr >= DATA_MEM_SIZE) {
                fprintf(stderr, "ERROR: SW address 0x%05X out of range\n", addr);
                return -1;
            }
            cpu->data_mem[addr] = cpu->regs[Rs];
            cpu->pc++;
            break;
        }

        /* ── BEQ Rs1, Rs2, imm4  [I-type] ── */
        case OP_BEQ: {
            uint8_t Rs1 = f3;
            uint8_t Rs2 = f2;
            int16_t off = sign_ext4(f1);
            if (cpu->regs[Rs1] == cpu->regs[Rs2]) {
                int32_t new_pc = (int32_t)cpu->pc + off;
                if (new_pc < 0 || new_pc >= PROG_MEM_SIZE) {
                    fprintf(stderr, "ERROR: BEQ branch target 0x%X out of range\n", new_pc);
                    return -1;
                }
                cpu->pc = (uint16_t)new_pc;
            } else {
                cpu->pc++;
            }
            break;
        }

        /* ── J addr12  [J-type] ── */
        case OP_J: {
            cpu->pc = addr12;
            break;
        }

        /* ── HALT  [J-type] ── */
        case OP_HALT: {
            cpu->halted = 1;
            return 1;
        }

        default: {
            fprintf(stderr, "ERROR: Unknown opcode 0x%X at PC=0x%03X\n", opcode, cpu->pc);
            return -1;
        }
    }

    return 0;
}
