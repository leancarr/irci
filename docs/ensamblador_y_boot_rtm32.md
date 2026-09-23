# Tutorial: Ensamblador y Desarrollo de la ROM (STX4)

Para continuar aprendiendo sobre la arquitectura STX4 y cómo interactuar con ella sin volvernos locos calculando hexadecimales a mano, desarrollamos dos piezas fundamentales: un ensamblador en Python y nuestro propio código de arranque (`boot.asm`).

Aquí te explico detalladamente cómo funciona cada cosa y por qué lo hicimos así.

---

## 1. El Ensamblador Personalizado (`assembler.py`)

### ¿Por qué lo construimos?
Traducir instrucciones assembly como `ADDI $sp, $zero, 4096` a su representación hexadecimal de 32 bits (`0x201E1000`) es un proceso mecánico y propenso a errores humanos.
Un ensamblador (Assembler) hace este trabajo por nosotros: lee texto humano y escupe código máquina.

### ¿Cómo funciona el código por dentro?
El script `assembler.py` funciona en **dos pasadas** (Two-pass assembler), lo cual es el estándar en diseño de compiladores básicos:

1. **Primera Pasada (Resolución de Etiquetas):**
   El script lee el código línea por línea y busca etiquetas (ej. `boot:` o `halt:`). Por cada línea de instrucción real, suma `4` al "Program Counter" (PC). Cuando encuentra una etiqueta, guarda el valor actual del PC en un diccionario. Esto nos permite referenciar a esa etiqueta más tarde.

2. **Segunda Pasada (Ensamblado de Código):**
   El script vuelve a leer las líneas. Dependiendo de la primera palabra (el mnemónico, ej. `ADDI`), aplica una lógica diferente:

   * **Ejemplo Formato I (`ADDI`):**
     * Instrucción: `ADDI $sp, $zero, 4096`
     * Código de operación (opcode) para ADDI = `1`.
     * Registro de destino (`rt`) = `$sp` = 30.
     * Registro fuente (`rs`) = `$zero` = 0.
     * Inmediato = 4096.
     * **El truco de bits (Bitwise Shifts):** El ensamblador desplaza los valores binarios a su posición correcta dentro de los 32 bits usando el operador `<<`:
       ```python
       instr_val = (opcode << 27) | (rs << 22) | (rt << 17) | imm
       ```

   * **Ejemplo Formato J (`J`):**
     * Instrucción: `J halt`
     * Como en la *Primera Pasada* guardamos en qué dirección estaba la etiqueta `halt`, el ensamblador reemplaza "halt" por esa dirección y la inserta en los 27 bits correspondientes.

Al final, el script agarra todas estas instrucciones (números enteros de 32 bits) y usa `struct.pack('<I', val)` para guardarlas en formato binario puro (Little-Endian) en el archivo `boot.rom`.

---

## 2. El Código de Arranque de la ROM (`boot.asm`)

Cuando la CPU STX4 arranca, su PC apunta a `0x00000000`. Nuestro objetivo era inicializar el entorno y luego probar que podíamos escribir datos.

### A. Inicializar la Pila (Stack Pointer)
```assembly
ADDI $sp, $zero, 4096
```
La pila de llamadas crece desde direcciones altas hacia direcciones bajas. Como sabemos por los logs que tenemos 4096 bytes de RAM, inicializamos el registro `$sp` al tope (4096). `$zero` siempre vale 0, por lo que `$sp = 0 + 4096`.

### B. Evadir el Bug de la UART
Según el archivo `README.md` del repositorio, usar `SW` (Store Word, opcode 9) para escribir en la dirección del UART (`0xFFFFFF00`) causa un bug donde los caracteres se imprimen duplicados. El manual sugiere usar `SB` (Store Byte, opcode 11) como workaround.

Para escribir en la memoria mapeada (MMIO) del UART, primero cargamos la dirección en un registro base (usaremos `$k0`, reservado para el kernel/sistema).
Como la dirección `0xFFFFFF00` es de 32 bits y no entra en una sola instrucción, la cargamos en dos pasos:
```assembly
LUI $k0, 0xFFFF       ; Carga 0xFFFF en los 16 bits más altos
ORI $k0, $k0, 0xFF00  ; Mezcla 0xFF00 en los 16 bits más bajos
```

### C. Imprimir el texto "HOLA"
Para cada letra, la cargamos en un registro temporal (`$t0`) usando su valor hexadecimal en la tabla ASCII, y luego la mandamos a la dirección base `$k0`:
```assembly
; Escribir 'H' (ASCII 0x48)
ADDI $t0, $zero, 0x48
SB $t0, 0($k0)       ; Guarda el byte de $t0 en la memoria a la que apunta $k0
```
Repetimos este bloque para la 'O', la 'L', la 'A', y los saltos de línea `\r` (0x0D) y `\n` (0x0A).

### D. Bucle Infinito (Halt Loop)
```assembly
halt:
    J halt
```
Si el programa simplemente terminara, el procesador seguiría incrementando el PC y leyendo basura en la memoria `0x00000040`, `0x00000044`... lo cual causaría una excepción o fallos impredecibles. Lo forzamos a quedar atrapado en este ciclo infinito para simular un "Halt" (Detención).
