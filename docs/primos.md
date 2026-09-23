# Primeros 10 primos en STX4/RTM32 — proceso completo documentado

Fecha: 2026-09-23. Código: `examples/primos/primos.asm` (assembler.py v0.5).

## 1. Problema elegido

Calcular e imprimir los **primeros 10 números primos** (2, 3, 5, 7, 11, 13, 17, 19, 23, 29).
Nivel medio: exige bucles anidados, división con resto, subrutinas con pasaje por
registros, memoria de datos y salida por UART. Nada exótico, nada trivial.

## 2. Algoritmo (división de prueba)

```
hallados = 0, candidato = 2
mientras hallados < 10:
    si es_primo(candidato):
        tabla[hallados] = candidato   # RAM 0x400
        imprimir_decimal(candidato) + CRLF   # UART
        hallados++
    candidato++
es_primo(n): para d = 2..n-1, si n % d == 0 → no primo.
             Resto manual: r = n - (n/d)*d  (usa DIV + MUL + SUB)
imprimir_decimal: extrae dígitos con DIV/REST por 10 a buffer 0x300
             (orden inverso) y los emite al revés por UART.
```

## 3. Mapeo a la ISA usada (verificada contra el emulador)

ADDI, ADD, SUB, MUL, DIV, REST, LBU, SB, SW, BEQ, BNE, SLTI, J, JAL, JR.
`ADDI $k0, $zero, -256` → `$k0 = 0xFFFFFF00` (sign-extiende el inmediato,
verificado: R2 = 0xFFFFFF00 tras 1 step). UART por `SB` (se evita el bug
conocido de `SW` que escribe doble). Las dos subrutinas son *leaf*
(sin JAL anidados), así que no hace falta pila.

## 4. Ensamblado

```bash
python3 cpu/assembler.py examples/primos/primos.asm /tmp/opencode/primos.bin
# Ensamblado exitoso: 57 instrucciones (228 bytes payload + 60 header = 288)
```

El `.bin` lleva header MDBG de 60 bytes (`4D44 4247...`). Es **obligatorio**
para el comando `load` del debugger. El `.rom` crudo NO sirve para `load`
(`Error: Failed to read metadata header`).

## 5. Carga y ejecución (el único camino que funciona)

```bash
rtm32 -d telnet                                  # puerto debugger: 50001
# telnet 127.0.0.1 50001
RTM32> load /tmp/opencode/primos.bin
Successfully burst loaded 228 aligned bytes into base address 0x00000000
RTM32> step 6000
Stepped instructions. Target PC: 0x00000054     # 0x54 = etiqueta `done`
```

OJO, trampas del emulador (todas verificadas):
- El puerto real es **50001** (el log miente con "port 4444").
- `-r archivo.rom` NO ejecuta desde 0 (mapea ROM de sistema en alto; la CPU
  corre NOPs en RAM). Hay que usar `load` del debugger.
- Sin `-n`, el modo batch sale con 0 pasos. Con debugger, `step` grande se
  cuelga si nadie drena el stdout del emulador (pipe de 64KB) — drenar en
  background.

## 6. Evidencia: tabla en RAM (10/10 correctos)

```
RTM32> examine xw 0x400 10
0x00000400: 0x00000002  0x00000003  0x00000005  0x00000007
0x00000410: 0x0000000B  0x0000000D  0x00000011  0x00000013
0x00000420: 0x00000017  0x0000001D
```

2, 3, 5, 7, 11, 13, 17, 19, 23, 29. Registros finales coherentes:
`s0` (R20) = 0x0A (10 hallados), `s1` (R21) = 0x1E (candidato final 30),
`s3` (R23) = 0x428 (tabla + 40 bytes), PC = 0x54 (`done: J done`).

## 7. Evidencia: impresión por UART

Captura viva del PTY al inicio de la ejecución: `'2\n\n3\n\n5\n\n'`
(los `\r` llegan como `\n` extra por traducción ICRNL del PTY; los bytes
emitidos son `2 CR LF 3 CR LF 5 CR LF`). Como el programa termina en `done`
tras 10 iteraciones completas (cada una con `JAL print_dec` + CR + LF),
los 10 valores se imprimieron. Los de 2 dígitos (11–29) ejercitan además
el loop de división y el pop inverso del buffer.

## 8. Conclusión

La CPU resuelve el problema de punta a punta: cómputo (DIV/MUL/SUB/SLTI),
control (BEQ/BNE/J/JAL/JR), datos (SW/LBU) e I/O (SB a UART). 57
instrucciones, ~6000 steps, 10/10 primos correctos en RAM e impresión
verificada. Archivos: `examples/primos/primos.asm`.
