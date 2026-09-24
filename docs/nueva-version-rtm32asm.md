# Nueva versión: `rtm32.asm` v1.2.0 + manual — análisis

Fecha: 2026-09-23. Archivos: `cpu/aarch64-linux-musl-rtm32.asm`,
`cpu/Assembler de RTM32.pdf` (los dejó el usuario en `cpu/`).

## Qué es

- El PDF es el manual del **assembler nuevo** `rtm32.asm` v1.2.0
  (GUIA "Arquitectura del Computador"): instala un ejecutable por plataforma,
  renombrarlo a `rtm32.asm`, uso `rtm32.asm prog.rtm -o prog.bin`,
  objetos con `-c`, linkeo con `-l:obj.o`, preprocesador `%include/%define`,
  ejemplo Hola-mundo con `.section/.asciiz`, `.hi16/.lo16`, `orh/ori`.
- `aarch64-linux-musl-rtm32.asm` (386 KB) **NO es fuente**: es el binario ELF
  del assembler nuevo compilado para **ARM 64-bit musl**. En esta máquina
  (x86_64) no ejecuta (`Formato de ejecutable incorrecto`). Se descargó la
  plataforma equivocada: acá corresponde `x86_64-linux-musl-rtm32.asm`
  (ese es el `rtm32.asm` de 641 KB que ya está en Koba).
- El `rtm32.asm` x86_64 de Koba **segfaultea con `--help`**. Ojo al usarlo.

## Sintaxis nueva vs la nuestra

Todo lo que hay en este repo (`snake/`, `cpu/*.asm`, `examples/`) está en
sintaxis del **`assembler.py` v0.5** (`;` comentarios, `ADDI $rt,$rs,imm`,
`SB $t0, 0($k0)`, `LCI` pseudo). La v1.2.0 usa sintaxis incompatible
(`//` comentarios, `.rtm`, `addi $rt, $rs, simm`, `orh`, directivas
`.section`, operandos `imm($rs)` con otro orden de registros). **No mezclar**:
nuestros `.asm` NO los entiende `rtm32.asm` y viceversa.

## Emulador

`rtm32` (el emulador, aparte del assembler) es **RTM32-0.5** y anda bien en
x86_64. Ver `docs/primos.md` para el flujo de carga/ejecución verificado
(`.bin` + `load` por telnet en puerto **50001**).

## Update 2026-09-24: build correcto v1.2.1 (pero OJO con la ISA)

Se descargó `x86_64-linux-musl-rtm32.asm` (451 KB) y se instaló como
`cpu/rtm32.asm`: `./rtm32.asm --version` → `1.2.1`, sin segfault
(el de Koba es otro build más viejo que se cuelga con `--help`).
Ensambla bien (`mini.rtm` → `mini.bin` con header MDBG).

PERO: su salida **no corre en el emulador v0.5**. Decodificando el
`.bin`: su `addi` sale con opcode 3 (en v0.5 el 3 es JAL) y su `trap`
cae en vector de excepción. O sea, el assembler v1.2.1 apunta a una
revisión de ISA más nueva que la que implementa el emulador v0.5.

Parejas que sí van juntas:
- Emulador v0.5 ⟷ `assembler.py` v0.5 (snake, primos: verificado).
- `rtm32.asm` v1.2.1 ⟷ emulador v1.x (todavía no lo tenemos).

No mezclar toolchains hasta tener el emulador nuevo.
