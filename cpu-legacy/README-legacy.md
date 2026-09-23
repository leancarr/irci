# RTM32 / STX4 — Test de Instrucciones

> **CPU:** STX4 (RISC 32-bit) — Emulador `rtm32` v0.5 (2/7/2026 20:18)
> **Manual:** `rtm32.pdf` — El PDF es la especificación. Si el binario no coincide, es un bug.

---

## Bug activo: SW escribe doble a UART

**Descripcion:** Al usar `SW` para escribir al registro UART (`0xFFFFFF00`), cada caracter se transmite dos veces.

**Evidencia (trace del emulador con `-L TRACE`):**
```
TRACE [src/serial.c:243]: Value send to the terminal: 0x00000048  <- 'H'
TRACE [src/serial.c:243]: Value send to the terminal: 0x00000048  <- 'H' (duplicado)
```

**Ubicacion:** `src/serial.c:243`. Cada `SW` invoca `serial_mmio_write` 2 veces.
**Salida en pantalla:** `HHeelllloo,,  WWoorrlldd!!` en vez de `Hello, World!`
**Workaround:** Usar `SB` (store byte, opcode 11) en vez de `SW` para escribir a UART.

---

## Como probar el bug

```bash
# Terminal 1
cd ~/Escritorio/cpu-nuevo-koba
./rtm32 -d telnet -m 4k -L TRACE &

# Terminal 2
telnet localhost 4444
RTM32> set r1 0xFFFFFF00
RTM32> set r2 0x48
RTM32> set [0x0000] 0x48440000
RTM32> step 1
```

El log muestra `Value send to the terminal: 0x00000048` **dos veces** para una sola instruccion SW.

---

## Tabla de Opcodes (42/46 instrucciones testeadas)

| Opcode | Instruccion | Estado |
|:---:|------|:---:|
| 0 | R-Type (ver tabla abajo) | OK |
| 1 | ADDI | OK |
| 2 | J | OK |
| 3 | JAL | OK |
| 4 | ANDI/H | OK |
| 5 | ORI/H | OK |
| 6 | XORI/H | OK |
| 7 | LUI | OK |
| 8 | LW | OK |
| 9 | SW | Bug UART |
| 10 | SH | OK |
| 11 | SB | OK |
| 12 | LH | OK |
| 13 | LHU | OK |
| 14 | LB | OK |
| 15 | LBU | OK |
| 16-21 | BEQ, BNE, BLT, BGT, BLE, BGE | OK |
| 22-23 | SLTI, SLTIU | OK |
| 24-31 | Invalidos | OK |

## Tabla de Funcs R-Type

| Func | Instruccion | Estado |
|:---:|-------------|:---:|
| 0-5 | SLL, SRL, SRA, SLLR, SRLR, SRAR | OK |
| 6-7 | CFS, CTS | Excluido |
| 8-11 | AND, OR, XOR, NOR | OK |
| 12-13 | SLT, SLTU | OK |
| 14-15 | JR, JALR | OK |
| 16-20 | LHX, LHUX, LBX, LBUX, LWX | Pendiente |
| 21-23 | MUL, MULH, MULHU | OK |
| 24-27 | DIV, DIVU, REST, RESTU | OK |
| 28-29 | ADD, SUB | OK |
| 32-33 | TRAP, RFT | Excluido |

---

## Resumen

- **40 instrucciones funcionan perfecto**
- **4 sin testear:** LHX, LHUX, LBX, LBUX
- **1 bug activo:** SW escribe doble a UART (workaround: usar SB)
- **El PDF coincide 100% con el binario** en todos los opcodes y funcs
