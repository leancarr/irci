# irci — CPU STX4 / RTM32 + Snake bare-metal

Monorepo organizado desde `Koba/cpu-koba` (CPU + Snake).
Fuente original: `Koba/cpu-koba` (remote `cpu-koba.git`) + `Koba/docs`.

## Estructura

- `cpu/` — Assembler Python + boot + tools del RTM32 v0.5
  - `assembler.py` — STX4 Assembler v0.5 (`.asm` → `.bin` con header MDBG / `.rom` crudo)
  - `hex2rom.py`, `run_tests.py`
  - `boot.asm`, `bootloader.asm`
  - NOTA: el binario `rtm32` no se versiona (ver abajo). Copialo desde Koba o buildealo.
- `snake/` — Juego Snake bare-metal STX4
  - `main.asm`, `init_game.asm`, `input.asm`, `renderer.asm`, `update_snake.asm`, `random.asm`, `check_collision.asm`, `snake_build.asm`, `hello_uart.asm`
  - `play_snake.py` — launcher automático (ensambla + telnet + UART)
  - `COMO_JUGAR_SNAKE.md` — guía completa
- `cpu-legacy/` — Emulador C original (assembler.c, cpu.c, display.c, main.c, Makefile, programs/)
- `docs/` — arquitectura_rtm32, bootloader_stx4, ensamblador, guía de uso, tests v015rc
- `docs/primos.md` — demo verificada: primeros 10 primos (proceso completo)
- `docs/nueva-version-rtm32asm.md` — análisis assembler v1.2.0 + manual
- `examples/primos/primos.asm` — fuente de la demo (57 instr, assembler.py v0.5)

## Requisitos

- Python 3
- Binario `rtm32` v0.5 (no versionado, ~238KB). Conseguilo así:
  ```bash
  cp ../Koba/cpu-koba/cpu-nuevo-koba/rtm32 ./rtm32
  # o desde cpu-koba/cpu-nuevo-koba/rtm32
  ```
- `picocom` o `screen` para modo manual (opcional)

## Uso rápido

```bash
# 1. Ensamblar snake
python3 cpu/assembler.py snake/snake_build.asm snake/snake.rom

# 2. Demo primos (ver docs/primos.md para el proceso completo)
python3 cpu/assembler.py examples/primos/primos.asm /tmp/primos.bin
rtm32 -d telnet                     # debugger en puerto 50001
# RTM32> load /tmp/primos.bin  ->  burst loaded 228 bytes en 0x00000000
# RTM32> step 6000             ->  PC 0x54 (done), tabla 0x400 = 2..29
```

Modo manual completo: ver `snake/COMO_JUGAR_SNAKE.md`.

## Bug conocido

`SW` a UART (`0xFFFFFF00`) escribe doble (`src/serial.c:243`). Workaround: usar `SB` (opcode 11).
Detalle en `cpu-legacy/README-legacy.md` y `docs/tests_v015rc.md`.

## Origen

Armado el 2026-09-23 desde:
- `Koba/cpu-koba/cpu-nuevo-koba/` (assembler.py, snake/, play_snake.py, boot)
- `Koba/cpu-koba/` (*.c, *.h, Makefile, programs/)
- `Koba/docs/` + `Koba/COMO_JUGAR_SNAKE.md`
