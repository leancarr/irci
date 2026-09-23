#!/usr/bin/env python3
import sys
import struct
import re
import argparse

# Mapeo oficial de registros STX4 para RTM32 v0.5 (rtm32v2.md)
REGISTERS = {
    "$zero": 0, "$0": 0, "r0": 0,
    "$at": 1, "$1": 1, "r1": 1,
    "$k0": 2, "$2": 2, "r2": 2,
    "$k1": 3, "$3": 3, "r3": 3,
    "$a0": 4, "$4": 4, "r4": 4,
    "$a1": 5, "$5": 5, "r5": 5,
    "$a2": 6, "$6": 6, "r6": 6,
    "$a3": 7, "$7": 7, "r7": 7,
    "$v0": 8, "$8": 8, "r8": 8,
    "$v1": 9, "$9": 9, "r9": 9,
    "$t0": 10, "$10": 10, "r10": 10,
    "$t1": 11, "$11": 11, "r11": 11,
    "$t2": 12, "$12": 12, "r12": 12,
    "$t3": 13, "$13": 13, "r13": 13,
    "$t4": 14, "$14": 14, "r14": 14,
    "$t5": 15, "$15": 15, "r15": 15,
    "$t6": 16, "$16": 16, "r16": 16,
    "$t7": 17, "$17": 17, "r17": 17,
    "$t8": 18, "$18": 18, "r18": 18,
    "$t9": 19, "$19": 19, "r19": 19,
    "$s0": 20, "$20": 20, "r20": 20,
    "$s1": 21, "$21": 21, "r21": 21,
    "$s2": 22, "$22": 22, "r22": 22,
    "$s3": 23, "$23": 23, "r23": 23,
    "$s4": 24, "$24": 24, "r24": 24,
    "$s5": 25, "$25": 25, "r25": 25,
    "$s6": 26, "$26": 26, "r26": 26,
    "$s7": 27, "$27": 27, "r27": 27,
    "$fp": 28, "$28": 28, "r28": 28,
    "$gp": 29, "$29": 29, "r29": 29,
    "$sp": 30, "$30": 30, "r30": 30,
    "$ra": 31, "$31": 31, "r31": 31
}

# Funciones R-type (funct de 7 bits, opcode 00000)
R_FUNCS = {
    "SLL": 0, "SRL": 1, "SRA": 2,
    "SLLR": 3, "SRLR": 4, "SRAR": 5,
    "CFS": 6, "CTS": 7,
    "AND": 8, "OR": 9, "XOR": 10, "NOR": 11,
    "SLT": 12, "SLTU": 13,
    "JR": 14, "JALR": 15,
    "LHX": 16, "LHUX": 17, "LBX": 18, "LBUX": 19,
    "LWX": 20,
    "MUL": 21, "MULH": 22, "MULHU": 23,
    "DIV": 24, "DIVU": 25, "REST": 26, "RESTU": 27,
    "ADD": 28, "SUB": 29,
    "TRAP": 32, "RFT": 33
}

# Opcodes I-type, J-type y Branches (5 bits)
OPCODES = {
    "ADDI": 1,
    "J": 2,
    "JAL": 3,
    "ANDI": 4,
    "ORI": 5,
    "XORI": 6,
    "LUI": 7,
    "LW": 8,
    "SW": 9,
    "SH": 10,
    "SB": 11,
    "LH": 12,
    "LHU": 13,
    "LB": 14,
    "LBU": 15,
    "BEQ": 16,
    "BNE": 17,
    "BLT": 18,
    "BGT": 19,
    "BLE": 20,
    "BGE": 21,
    "SLTI": 22,
    "SLTIU": 23
}

def parse_reg(reg_str):
    s = reg_str.replace(",", "").strip().lower()
    if s in REGISTERS:
        return REGISTERS[s]
    if s.isdigit() and 0 <= int(s) <= 31:
        return int(s)
    for prefix in ("$", "r"):
        if s.startswith(prefix) and s[len(prefix):].isdigit():
            n = int(s[len(prefix):])
            if 0 <= n <= 31:
                return n
    raise ValueError(f"Registro inválido: '{reg_str}'")

def parse_imm(imm_str, labels, current_pc, is_branch=False, is_jump=False):
    imm_str = imm_str.replace(",", "").strip()
    if imm_str in labels:
        target = labels[imm_str]
        if is_jump:
            return (target // 4) & 0x7FFFFFF
        if is_branch:
            return ((target - current_pc - 4) // 4) & 0x1FFFF
        return target
    
    # Constante numerica o caracter
    if imm_str.startswith("'") and imm_str.endswith("'") and len(imm_str) >= 3:
        val = ord(imm_str[1])
    elif imm_str.startswith("0x") or imm_str.startswith("0X"):
        val = int(imm_str, 16)
    else:
        val = int(imm_str)
    
    return val

def build_snapshot(payload, base_addr=0):
    """Genera el header de 60 bytes MDBG requerido por rtm32 v0.5"""
    h = struct.pack("<III", 0x4742444D, 2, base_addr)
    h += struct.pack("<I", len(payload))
    h += b"\x00" * 12
    h += b"RTM32\x00".ljust(32, b"\x00")
    return h + payload

def assemble(input_file, output_file):
    with open(input_file, "r") as f:
        lines = f.readlines()
        
    instructions = []
    labels = {}
    pc = 0
    
    # Paso 1: Parsear etiquetas
    for raw_line in lines:
        line = raw_line.split(";")[0].split("#")[0].strip()
        if not line:
            continue
            
        if ":" in line:
            label, rest = line.split(":", 1)
            labels[label.strip()] = pc
            line = rest.strip()
            
        if line:
            instructions.append((pc, line))
            pc += 4
            
    payload = bytearray()
    
    # Paso 2: Codificar instrucciones
    for pc, line in instructions:
        parts = line.replace(",", " ").split()
        mnemo = parts[0].upper()
        
        try:
            instr_val = 0
            
            # --- Pseudo-instrucciones ---
            if mnemo == "NOP":
                instr_val = 0
            elif mnemo == "LCI":
                # LCI $rt, $rs, imm -> ADDI $rt, $rs, imm
                rt = parse_reg(parts[1])
                rs = parse_reg(parts[2])
                imm = parse_imm(parts[3], labels, pc) & 0x1FFFF
                instr_val = (OPCODES["ADDI"] << 27) | (rs << 22) | (rt << 17) | imm
                
            # --- R-type ---
            elif mnemo in R_FUNCS:
                funct = R_FUNCS[mnemo]
                opcode = 0
                rs, rt, rd, aux = 0, 0, 0, 0
                
                if mnemo in ["SLL", "SRL", "SRA"]:
                    rd = parse_reg(parts[1])
                    rt = parse_reg(parts[2])
                    aux = parse_imm(parts[3], labels, pc) & 0x1F
                elif mnemo in ["SLLR", "SRLR", "SRAR"]:
                    rd = parse_reg(parts[1])
                    rt = parse_reg(parts[2])
                    rs = parse_reg(parts[3])
                elif mnemo == "JR":
                    rs = parse_reg(parts[1])
                elif mnemo == "JALR":
                    rs = parse_reg(parts[1])
                    if len(parts) > 2:
                        rt = parse_reg(parts[2])
                    else:
                        rt = 31  # Default $ra
                elif mnemo in ["TRAP", "CFS", "CTS"]:
                    if len(parts) > 1:
                        rs = parse_reg(parts[1])
                    if len(parts) > 2:
                        aux = parse_imm(parts[2], labels, pc) & 0x1F
                elif mnemo == "RFT":
                    pass
                else:
                    # ADD, SUB, MUL, DIV, AND, OR, XOR, NOR, SLT, SLTU: rd, rs, rt
                    rd = parse_reg(parts[1])
                    rs = parse_reg(parts[2])
                    rt = parse_reg(parts[3])
                    
                instr_val = (opcode << 27) | (rs << 22) | (rt << 17) | (rd << 12) | (aux << 7) | funct
                
            # --- J-type ---
            elif mnemo in ["J", "JAL"]:
                opcode = OPCODES[mnemo]
                addr = parse_imm(parts[1], labels, pc, is_jump=True) & 0x7FFFFFF
                instr_val = (opcode << 27) | addr
                
            # --- I-type ALU ---
            elif mnemo in ["ADDI", "ANDI", "ORI", "XORI", "SLTI", "SLTIU"]:
                opcode = OPCODES[mnemo]
                rt = parse_reg(parts[1])
                rs = parse_reg(parts[2])
                imm = parse_imm(parts[3], labels, pc) & 0x1FFFF
                instr_val = (opcode << 27) | (rs << 22) | (rt << 17) | imm
                
            elif mnemo == "LUI":
                opcode = OPCODES[mnemo]
                rt = parse_reg(parts[1])
                rs = 0
                imm = parse_imm(parts[2], labels, pc) & 0x1FFFF
                instr_val = (opcode << 27) | (rs << 22) | (rt << 17) | imm
                
            # --- Branches ---
            elif mnemo in ["BEQ", "BNE", "BLT", "BGT", "BLE", "BGE"]:
                opcode = OPCODES[mnemo]
                rs = parse_reg(parts[1])
                rt = parse_reg(parts[2])
                imm = parse_imm(parts[3], labels, pc, is_branch=True) & 0x1FFFF
                instr_val = (opcode << 27) | (rs << 22) | (rt << 17) | imm
                
            # --- Memory (Loads & Stores) ---
            elif mnemo in ["LW", "SW", "SH", "SB", "LH", "LHU", "LB", "LBU"]:
                opcode = OPCODES[mnemo]
                rt = parse_reg(parts[1])
                mem_op = parts[2]
                if "(" in mem_op:
                    imm_str, rs_str = mem_op.split("(")
                    rs_str = rs_str.strip(")")
                    imm = parse_imm(imm_str, labels, pc) & 0x1FFFF
                    rs = parse_reg(rs_str)
                else:
                    imm = parse_imm(mem_op, labels, pc) & 0x1FFFF
                    rs = 0
                instr_val = (opcode << 27) | (rs << 22) | (rt << 17) | imm
                
            else:
                raise ValueError(f"Mnemónico desconocido: {mnemo}")
                
            payload.extend(struct.pack("<I", instr_val))
            
        except Exception as e:
            print(f"Error ensamblando línea '{line}': {e}")
            sys.exit(1)
            
    # Si la salida es .bin, agregamos el snapshot header MDBG (60 bytes)
    # Si es .rom, guardamos payload crudo para compatibilidad
    if output_file.endswith(".bin"):
        full_data = build_snapshot(payload, base_addr=0)
    else:
        full_data = payload
        
    with open(output_file, "wb") as f:
        f.write(full_data)
        
    print(f"Ensamblado exitoso: {len(instructions)} instrucciones en '{output_file}' ({len(full_data)} bytes).")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="STX4 Assembler v0.5 para RTM32")
    parser.add_argument("input", help="Archivo ensamblador de entrada (.asm)")
    parser.add_argument("output", help="Archivo binario de salida (.bin o .rom)")
    args = parser.parse_args()
    
    assemble(args.input, args.output)
