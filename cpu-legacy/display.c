#include "display.h"
#include "cpu.h"
#include <stdio.h>
#include <string.h>

/* ─────────────────────────────────────────────
   ANSI color codes
   ───────────────────────────────────────────── */
#define RESET   "\033[0m"
#define BOLD    "\033[1m"
#define CYAN    "\033[36m"
#define YELLOW  "\033[33m"
#define GREEN   "\033[32m"
#define RED     "\033[31m"
#define MAGENTA "\033[35m"
#define DIM     "\033[2m"
#define BG_DARK "\033[48;5;234m"

/* ─────────────────────────────────────────────
   Disassembler
   ───────────────────────────────────────────── */
void disassemble(uint16_t instr, char *out, int out_size) {
    uint8_t  opcode = (instr >> 12) & 0xF;
    uint8_t  f3     = (instr >> 8)  & 0xF;
    uint8_t  f2     = (instr >> 4)  & 0xF;
    uint8_t  f1     =  instr        & 0xF;
    uint16_t addr12 =  instr        & 0xFFF;
    uint8_t  imm8   =  instr        & 0xFF;

    int16_t simm4 = (f1 & 0x8) ? (int16_t)(f1 | 0xFFF0) : (int16_t)f1;
    int16_t simm8 = (int16_t)(int8_t)imm8;

    switch (opcode) {
        case 0x0:
            snprintf(out, out_size, "LOAD R%u, #%d", f3, simm8);
            break;
        case 0x1:
            snprintf(out, out_size, "ADD  R%u, R%u, R%u", f3, f2, f1);
            break;
        case 0x2:
            snprintf(out, out_size, "ADD  R%u, R%u, #%d", f3, f2, simm4);
            break;
        case 0x3:
            snprintf(out, out_size, "LW   R%u, %d(R%u)", f3, simm4, f2);
            break;
        case 0x4:
            snprintf(out, out_size, "SW   R%u, %d(R%u)", f3, simm4, f2);
            break;
        case 0x5:
            snprintf(out, out_size, "BEQ  R%u, R%u, %+d", f3, f2, simm4);
            break;
        case 0x6:
            snprintf(out, out_size, "J    0x%03X", addr12);
            break;
        case 0xF:
            snprintf(out, out_size, "HALT");
            break;
        default:
            snprintf(out, out_size, "??? (0x%04X)", instr);
            break;
    }
}

/* ─────────────────────────────────────────────
   Box drawing helpers
   ───────────────────────────────────────────── */
#define BOX_W 70

static void hline_top(void) {
    printf(CYAN "╔");
    for (int i = 0; i < BOX_W - 2; i++) printf("═");
    printf("╗\n" RESET);
}

static void hline_mid(void) {
    printf(CYAN "╠");
    for (int i = 0; i < BOX_W - 2; i++) printf("═");
    printf("╣\n" RESET);
}

static void hline_mid2(int left, int right) {
    /* Split horizontal rule at column 'left' */
    printf(CYAN "╠");
    for (int i = 0; i < left - 1; i++) printf("═");
    printf("╦");
    for (int i = 0; i < right - 1; i++) printf("═");
    printf("╣\n" RESET);
}

static void hline_bot2(int left, int right) {
    printf(CYAN "╚");
    for (int i = 0; i < left - 1; i++) printf("═");
    printf("╩");
    for (int i = 0; i < right - 1; i++) printf("═");
    printf("╝\n" RESET);
}

/* hline_bot and row are available for future use */

/* ─────────────────────────────────────────────
   Main print_state
   ───────────────────────────────────────────── */
void print_state(const CPU *cpu, int step) {
    char disasm[64];
    char buf[128];

    disassemble(cpu->last_instr, disasm, sizeof(disasm));

    /* ── Header ── */
    hline_top();
    snprintf(buf, sizeof(buf),
             BOLD CYAN " KOBARIUS CPU EMULATOR" RESET
             "  │  Step #%d", step);
    /* raw width trick: snprintf with colors inflates len, pad manually */
    printf(CYAN "║" RESET BOLD CYAN "  KOBARIUS CPU EMULATOR" RESET
           "  │  " YELLOW "Step #%-4d" RESET
           "%*s" CYAN "║\n" RESET,
           step, (int)(BOX_W - 4 - 22 - 12), "");

    /* ── Instruction row ── */
    hline_mid();
    snprintf(buf, sizeof(buf), "[PC=0x%03X]  %-30s    Encoding: 0x%04X",
             cpu->pc, disasm, cpu->last_instr);
    printf(CYAN "║" RESET "  " GREEN BOLD "%-*s" RESET CYAN "║\n" RESET,
           BOX_W - 4, buf);

    /* ── Registers | PSW split ── */
    int LEFT = 37, RIGHT = BOX_W - LEFT - 1;
    hline_mid2(LEFT, RIGHT);

    /* Column headers */
    printf(CYAN "║" RESET BOLD "  %-*s" RESET CYAN "║" RESET BOLD "  %-*s" RESET CYAN "║\n" RESET,
           LEFT - 4, "REGISTROS",
           RIGHT - 3, "PSW FLAGS");

    /* 8 rows of registers (R0..R7 left, R8..R15 right inline) + PSW */
    const char *flags_label[] = {
        "Z (Zero)    ", "N (Negative)", "C (Carry)   ", "V (Overflow)"
    };
    uint8_t flags_val[] = { cpu->psw.Z, cpu->psw.N, cpu->psw.C, cpu->psw.V };

    for (int i = 0; i < 8; i++) {
        int  regA = i;
        int  regB = i + 8;
        char starA = (cpu->last_reg_written == regA) ? '*' : ' ';
        char starB = (cpu->last_reg_written == regB) ? '*' : ' ';

        char left_col[40], right_col[40];

        /* Left: two regs per row */
        snprintf(left_col, sizeof(left_col),
                 "R%-2d=0x%04X%c  R%-2d=0x%04X%c",
                 regA, cpu->regs[regA], starA,
                 regB, cpu->regs[regB], starB);

        /* Right: flag or DATA MEM header */
        if (i < 4) {
            uint8_t fv = flags_val[i];
            snprintf(right_col, sizeof(right_col),
                     "%s %s= %s%d" RESET,
                     flags_label[i],
                     fv ? GREEN BOLD : DIM,
                     fv ? GREEN BOLD : DIM,
                     fv);
        } else if (i == 4) {
            snprintf(right_col, sizeof(right_col), "── DATA MEMORY ──────");
        } else {
            /* show 3 words of data mem per remaining row */
            int base = (i - 5) * 3;
            snprintf(right_col, sizeof(right_col),
                     "[%04X] %04X  [%04X] %04X  [%04X] %04X",
                     base,   cpu->data_mem[base],
                     base+1, cpu->data_mem[base+1],
                     base+2, cpu->data_mem[base+2]);
        }

        printf(CYAN "║" RESET "  %-*s" CYAN "║" RESET "  %-*s" CYAN "║\n" RESET,
               LEFT - 4, left_col,
               RIGHT - 3, right_col);
    }

    hline_bot2(LEFT, RIGHT);

    /* ── Legend ── */
    printf(DIM "  * = modified this step"
           "   [Enter] next   [q] quit   [r] reset   [m ADDR] inspect memory\n" RESET);
}

/* ─────────────────────────────────────────────
   Memory range dump
   ───────────────────────────────────────────── */
void print_mem_range(const CPU *cpu, uint32_t start, uint32_t count) {
    printf(CYAN "╔══ DATA MEMORY 0x%04X – 0x%04X ══╗\n" RESET,
           start, start + count - 1);
    for (uint32_t i = 0; i < count; i++) {
        if (i % 8 == 0) printf(CYAN "║" RESET "  %04X: ", start + i);
        uint32_t addr = start + i;
        if (addr < DATA_MEM_SIZE)
            printf("%04X ", cpu->data_mem[addr]);
        else
            printf("---- ");
        if (i % 8 == 7) printf(CYAN "║\n" RESET);
    }
    if (count % 8 != 0) printf(CYAN "║\n" RESET);
    printf(CYAN "╚══════════════════════════════════╝\n" RESET);
}
