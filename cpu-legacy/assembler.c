#include "assembler.h"
#include "cpu.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* ─────────────────────────────────────────────
   Label table
   ───────────────────────────────────────────── */
#define MAX_LABELS 256
#define MAX_LABEL_LEN 64

typedef struct {
    char     name[MAX_LABEL_LEN];
    uint16_t addr;
} Label;

static Label label_table[MAX_LABELS];
static int   label_count = 0;

static void label_clear(void) { label_count = 0; }

static int label_add(const char *name, uint16_t addr) {
    if (label_count >= MAX_LABELS) return -1;
    strncpy(label_table[label_count].name, name, MAX_LABEL_LEN - 1);
    label_table[label_count].addr = addr;
    label_count++;
    return 0;
}

static int label_find(const char *name, uint16_t *out) {
    for (int i = 0; i < label_count; i++) {
        if (strcmp(label_table[i].name, name) == 0) {
            *out = label_table[i].addr;
            return 0;
        }
    }
    return -1;
}

/* ─────────────────────────────────────────────
   String helpers
   ───────────────────────────────────────────── */
static char *trim(char *s) {
    while (isspace((unsigned char)*s)) s++;
    char *end = s + strlen(s) - 1;
    while (end > s && isspace((unsigned char)*end)) *end-- = '\0';
    return s;
}

static void strip_comment(char *s) {
    char *p = strchr(s, ';');
    if (p) *p = '\0';
}

/* Parse register token like "R3" or "r3", return reg index or -1 */
static int parse_reg(const char *tok) {
    if (!tok) return -1;
    if ((tok[0] != 'R' && tok[0] != 'r') || !isdigit((unsigned char)tok[1]))
        return -1;
    int n = atoi(tok + 1);
    if (n < 0 || n > 15) return -1;
    return n;
}

/* Parse immediate: decimal or 0x hex, with optional sign */
static int parse_imm(const char *tok, int *out) {
    if (!tok) return -1;
    char *end;
    long v;
    /* skip leading '#' if present */
    if (*tok == '#') tok++;
    if (tok[0] == '0' && (tok[1] == 'x' || tok[1] == 'X'))
        v = strtol(tok, &end, 16);
    else
        v = strtol(tok, &end, 10);
    if (end == tok) return -1;
    *out = (int)v;
    return 0;
}

/* ─────────────────────────────────────────────
   Assemble one line → uint16_t
   pc    : current instruction address (for BEQ offset calc)
   pass  : 1 = collect labels only, 2 = encode
   ───────────────────────────────────────────── */
static int assemble_line(char *line, uint16_t pc, int pass,
                         uint16_t *out, int lineno) {
    strip_comment(line);
    line = trim(line);
    if (strlen(line) == 0) return 0; /* blank / comment-only */

    /* ── Label detection ── */
    char *colon = strchr(line, ':');
    if (colon) {
        if (pass == 1) {
            *colon = '\0';
            char *lname = trim(line);
            if (label_add(lname, pc) < 0) {
                fprintf(stderr, "Line %d: too many labels\n", lineno);
                return -1;
            }
        }
        /* Advance past the label to any instruction on same line */
        line = trim(colon + 1);
        if (strlen(line) == 0) return 0;
    }

    if (pass == 1) return 1; /* only counting/collecting labels in pass 1 */

    /* ── Tokenize mnemonic + operands ── */
    /* Replace commas and parens with spaces for easier tokenizing */
    for (char *p = line; *p; p++) {
        if (*p == ',' || *p == '(' || *p == ')') *p = ' ';
    }

    char *tokens[8];
    int   ntok = 0;
    char *p = line;
    while (*p && ntok < 8) {
        while (isspace((unsigned char)*p)) p++;
        if (!*p) break;
        tokens[ntok++] = p;
        while (*p && !isspace((unsigned char)*p)) p++;
        if (*p) *p++ = '\0';
    }
    if (ntok == 0) return 0;

    char *mnem = tokens[0];
    /* uppercase mnemonic */
    for (char *c = mnem; *c; c++) *c = toupper((unsigned char)*c);

    /* ── LOAD Rd, #imm8 ── */
    if (strcmp(mnem, "LOAD") == 0) {
        if (ntok < 3) { fprintf(stderr, "Line %d: LOAD needs Rd, #imm\n", lineno); return -1; }
        int Rd = parse_reg(tokens[1]);
        int imm;
        if (Rd < 0 || parse_imm(tokens[2], &imm) < 0) {
            fprintf(stderr, "Line %d: bad LOAD operands\n", lineno); return -1;
        }
        if (imm < -128 || imm > 255) {
            fprintf(stderr, "Line %d: LOAD immediate %d out of 8-bit range\n", lineno, imm);
            return -1;
        }
        *out = (uint16_t)((0x0 << 12) | (Rd << 8) | (imm & 0xFF));
        return 1;
    }

    /* ── ADD Rd, Rs1, Rs2  or  ADD Rd, Rs, #imm4 ── */
    if (strcmp(mnem, "ADD") == 0) {
        if (ntok < 4) { fprintf(stderr, "Line %d: ADD needs 3 operands\n", lineno); return -1; }
        int Rd = parse_reg(tokens[1]);
        int Ra = parse_reg(tokens[2]);
        if (Rd < 0 || Ra < 0) { fprintf(stderr, "Line %d: bad ADD Rd/Rs\n", lineno); return -1; }

        int Rb = parse_reg(tokens[3]);
        if (Rb >= 0) {
            /* R-type: ADD Rd, Rs1, Rs2 */
            *out = (uint16_t)((0x1 << 12) | (Rd << 8) | (Ra << 4) | Rb);
        } else {
            /* I-type: ADD Rd, Rs, #imm4 */
            int imm;
            if (parse_imm(tokens[3], &imm) < 0) {
                fprintf(stderr, "Line %d: bad ADD immediate\n", lineno); return -1;
            }
            if (imm < -8 || imm > 7) {
                fprintf(stderr, "Line %d: ADD immediate %d out of 4-bit range (-8..7)\n", lineno, imm);
                return -1;
            }
            *out = (uint16_t)((0x2 << 12) | (Rd << 8) | (Ra << 4) | (imm & 0xF));
        }
        return 1;
    }

    /* ── LW Rd, imm4(Rs)  (after tokenizing: tokens = LW Rd imm4 Rs) ── */
    if (strcmp(mnem, "LW") == 0) {
        if (ntok < 4) { fprintf(stderr, "Line %d: LW needs Rd, offset(Rs)\n", lineno); return -1; }
        int Rd  = parse_reg(tokens[1]);
        int imm; if (parse_imm(tokens[2], &imm) < 0) imm = 0;
        int Rs  = parse_reg(tokens[3]);
        if (Rd < 0 || Rs < 0) { fprintf(stderr, "Line %d: bad LW registers\n", lineno); return -1; }
        if (imm < -8 || imm > 7) {
            fprintf(stderr, "Line %d: LW offset %d out of 4-bit range\n", lineno, imm); return -1;
        }
        *out = (uint16_t)((0x3 << 12) | (Rd << 8) | (Rs << 4) | (imm & 0xF));
        return 1;
    }

    /* ── SW Rs, imm4(Rb) ── */
    if (strcmp(mnem, "SW") == 0) {
        if (ntok < 4) { fprintf(stderr, "Line %d: SW needs Rs, offset(Rb)\n", lineno); return -1; }
        int Rs  = parse_reg(tokens[1]);
        int imm; if (parse_imm(tokens[2], &imm) < 0) imm = 0;
        int Rb  = parse_reg(tokens[3]);
        if (Rs < 0 || Rb < 0) { fprintf(stderr, "Line %d: bad SW registers\n", lineno); return -1; }
        if (imm < -8 || imm > 7) {
            fprintf(stderr, "Line %d: SW offset %d out of 4-bit range\n", lineno, imm); return -1;
        }
        *out = (uint16_t)((0x4 << 12) | (Rs << 8) | (Rb << 4) | (imm & 0xF));
        return 1;
    }

    /* ── BEQ Rs1, Rs2, label_or_offset ── */
    if (strcmp(mnem, "BEQ") == 0) {
        if (ntok < 4) { fprintf(stderr, "Line %d: BEQ needs Rs1, Rs2, offset\n", lineno); return -1; }
        int Rs1 = parse_reg(tokens[1]);
        int Rs2 = parse_reg(tokens[2]);
        if (Rs1 < 0 || Rs2 < 0) { fprintf(stderr, "Line %d: bad BEQ registers\n", lineno); return -1; }

        int offset;
        uint16_t laddr;
        if (label_find(tokens[3], &laddr) == 0) {
            offset = (int)laddr - (int)pc;
        } else if (parse_imm(tokens[3], &offset) < 0) {
            fprintf(stderr, "Line %d: unknown label or bad offset '%s'\n", lineno, tokens[3]);
            return -1;
        }
        if (offset < -8 || offset > 7) {
            fprintf(stderr, "Line %d: BEQ offset %d out of 4-bit range (-8..7)\n", lineno, offset);
            return -1;
        }
        *out = (uint16_t)((0x5 << 12) | (Rs1 << 8) | (Rs2 << 4) | (offset & 0xF));
        return 1;
    }

    /* ── J label_or_addr ── */
    if (strcmp(mnem, "J") == 0) {
        if (ntok < 2) { fprintf(stderr, "Line %d: J needs address\n", lineno); return -1; }
        int addr;
        uint16_t laddr;
        if (label_find(tokens[1], &laddr) == 0) {
            addr = (int)laddr;
        } else if (parse_imm(tokens[1], &addr) < 0) {
            fprintf(stderr, "Line %d: unknown label or bad address '%s'\n", lineno, tokens[1]);
            return -1;
        }
        if (addr < 0 || addr >= PROG_MEM_SIZE) {
            fprintf(stderr, "Line %d: J address 0x%X out of 12-bit range\n", lineno, addr);
            return -1;
        }
        *out = (uint16_t)((0x6 << 12) | (addr & 0xFFF));
        return 1;
    }

    /* ── HALT ── */
    if (strcmp(mnem, "HALT") == 0) {
        *out = 0xF000;
        return 1;
    }

    fprintf(stderr, "Line %d: unknown mnemonic '%s'\n", lineno, mnem);
    return -1;
}

/* ─────────────────────────────────────────────
   Two-pass assembler
   ───────────────────────────────────────────── */
int assemble_file(const char *path, uint16_t *prog_mem, int mem_size) {
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); return -1; }

    /* Read all lines into memory for two passes */
    #define MAX_LINES 4096
    #define MAX_LINE_LEN 256
    static char lines[MAX_LINES][MAX_LINE_LEN];
    int nlines = 0;
    while (nlines < MAX_LINES && fgets(lines[nlines], MAX_LINE_LEN, f))
        nlines++;
    fclose(f);

    label_clear();

    /* ── Pass 1: collect labels ── */
    uint16_t pc = 0;
    for (int i = 0; i < nlines; i++) {
        char tmp[MAX_LINE_LEN];
        strncpy(tmp, lines[i], MAX_LINE_LEN - 1);
        int r = assemble_line(tmp, pc, 1, NULL, i + 1);
        if (r < 0) return -1;
        if (r > 0) pc++;
    }

    /* ── Pass 2: encode ── */
    pc = 0;
    int count = 0;
    for (int i = 0; i < nlines; i++) {
        char tmp[MAX_LINE_LEN];
        strncpy(tmp, lines[i], MAX_LINE_LEN - 1);
        uint16_t encoded = 0;
        int r = assemble_line(tmp, pc, 2, &encoded, i + 1);
        if (r < 0) return -1;
        if (r > 0) {
            if (pc >= (uint16_t)mem_size) {
                fprintf(stderr, "Line %d: program too large (max %d instructions)\n",
                        i + 1, mem_size);
                return -1;
            }
            prog_mem[pc++] = encoded;
            count++;
        }
    }

    return count;
}
