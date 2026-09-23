#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cpu.h"
#include "assembler.h"
#include "display.h"

/* ─────────────────────────────────────────────
   REPL — interactive step-by-step loop
   ───────────────────────────────────────────── */
static void run_repl(CPU *cpu) {
    int step = 0;
    char input[128];

    printf("\n\033[1;36m  Kobarius CPU Emulator — loaded and ready.\033[0m\n");
    printf("\033[2m  Commands: [Enter] step  [q] quit  [r] reset"
           "  [m ADDR] inspect memory  [run] run to HALT\033[0m\n\n");

    /* Show initial state before first instruction */
    cpu->last_instr = cpu->prog_mem[cpu->pc];
    cpu->last_reg_written = -1;
    print_state(cpu, step);

    while (1) {
        printf("\n\033[1;33m> \033[0m");
        fflush(stdout);

        if (!fgets(input, sizeof(input), stdin)) break;
        /* strip newline */
        input[strcspn(input, "\n")] = '\0';
        char *cmd = input;
        while (*cmd == ' ') cmd++;

        /* ── quit ── */
        if (strcmp(cmd, "q") == 0 || strcmp(cmd, "quit") == 0)
            break;

        /* ── reset ── */
        if (strcmp(cmd, "r") == 0 || strcmp(cmd, "reset") == 0) {
            reset_cpu(cpu);
            step = 0;
            cpu->last_instr = cpu->prog_mem[cpu->pc];
            print_state(cpu, step);
            continue;
        }

        /* ── inspect memory: m ADDR [count] ── */
        if (cmd[0] == 'm' && (cmd[1] == ' ' || cmd[1] == '\0')) {
            uint32_t addr = 0, count = 16;
            if (sscanf(cmd + 1, " %i %u", &addr, &count) < 1) {
                printf("  Usage: m <addr> [count]\n");
                continue;
            }
            if (count < 1 || count > 256) count = 16;
            print_mem_range(cpu, addr, count);
            continue;
        }

        /* ── run to HALT ── */
        if (strcmp(cmd, "run") == 0) {
            int r = 0;
            while (r == 0) {
                r = step_cpu(cpu);
                step++;
            }
            print_state(cpu, step);
            if (r == 1)
                printf("\n\033[1;32m  ✓ HALT reached after %d steps.\033[0m\n", step);
            else
                printf("\n\033[1;31m  ✗ Error at step %d.\033[0m\n", step);
            continue;
        }

        /* ── single step (Enter or any other input) ── */
        if (cpu->halted) {
            printf("  \033[33mCPU is halted. Press [r] to reset.\033[0m\n");
            continue;
        }

        int r = step_cpu(cpu);
        step++;
        print_state(cpu, step);

        if (r == 1)
            printf("\n\033[1;32m  ✓ HALT — execution finished in %d steps.\033[0m\n", step);
        else if (r < 0)
            printf("\n\033[1;31m  ✗ Runtime error at step %d.\033[0m\n", step);
    }

    printf("\n\033[2m  Bye!\033[0m\n");
}

/* ─────────────────────────────────────────────
   Entry point
   ───────────────────────────────────────────── */
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr,
            "Usage: %s <program.asm>\n"
            "\n"
            "  Kobarius CPU Emulator — 16-bit custom ISA\n"
            "  Instruction set: LOAD ADD LW SW BEQ J HALT\n"
            "  Architecture:    Harvard, 16 regs, 4K prog / 64K data\n",
            argv[0]);
        return 1;
    }

    CPU cpu;
    init_cpu(&cpu);

    printf("\033[1;36m  Assembling \033[0m%s\033[1;36m...\033[0m\n", argv[1]);
    int count = assemble_file(argv[1], cpu.prog_mem, PROG_MEM_SIZE);
    if (count < 0) {
        fprintf(stderr, "  Assembly failed.\n");
        return 1;
    }
    printf("\033[1;32m  ✓ %d instruction(s) loaded.\033[0m\n", count);

    run_repl(&cpu);
    return 0;
}
