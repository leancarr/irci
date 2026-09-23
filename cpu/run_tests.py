import os
import subprocess

tests = [
    ("ADD", "ADD $t0, $t1, $t2\n"),
    ("SLL", "SLL $t0, $t1, 5\n"),
    ("AND", "AND $t0, $t1, $t2\n"),
    ("ADDI", "ADDI $t0, $t1, 42\n"),
    ("LCI", "LCI $t0, $zero, 0x1234\n"),
    ("LW", "LW $t0, 4($sp)\n"),
    ("SWX", "SWX $t0, $t1, $t2\n"),
    ("J", "J boot\nboot: J boot\n"),
    ("JAL", "JAL boot\nboot: JAL boot\n"),
    ("JR", "JR $ra\n"),
    ("BEQ", "BEQ $t0, $t1, end\nend: BEQ $t0, $t1, end\n"),
    ("MUL", "MUL $t0, $t1, $t2\n"),
    ("SLT", "SLT $t0, $t1, $t2\n"),
    ("LHX", "LHX $t0, $t1, $t2\n"),
    ("LBU", "LBU $t0, 4($sp)\n")
]

def run():
    print("=== Corriendo 15 Tests de Arquitectura RTM32 v0.1.5-RC ===\n")
    success_count = 0
    for i, (name, code) in enumerate(tests, 1):
        filename = f"test_{i}.asm"
        romname = f"test_{i}.rom"
        
        # Write .asm
        with open(filename, "w") as f:
            f.write(code)
            
        # Assemble
        res = subprocess.run(["python3", "assembler.py", filename, romname], capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[{i}] {name}: FAILED (Assembler Error)\n{res.stdout}\n{res.stderr}")
            continue
            
        # Run emulator (2 steps)
        # We need a valid instruction after, so we just run 1 step or use a small limit
        res_emu = subprocess.run(["./rtm32", "-r", romname, "-n", "1", "-L", "TRACE"], capture_output=True, text=True)
        out = res_emu.stderr + res_emu.stdout
        
        if "fault" in out.lower() or "illegal" in out.lower() or "violation" in out.lower():
            print(f"[{i}] {name}: FAILED (Emulator Exception)")
            print(out)
        else:
            print(f"[{i}] {name}: SUCCESS")
            if i == 1:
                print("--- DEBUG TRACE ---")
                print(out)
                print("-------------------")
            success_count += 1
            
    print(f"\nTotal Success: {success_count}/15")

if __name__ == "__main__":
    run()
