# Desarrollo y Pruebas - Migración a CPU STX4 (RTM32)

Este documento registra los pasos, herramientas y conceptos teóricos aplicados durante la transición de la arquitectura original (Kobarius) a la nueva arquitectura **STX4** del simulador **rtm32**. El objetivo de esta documentación es servir como material de estudio y registro del progreso.

---

## 1. El Desafío de la ROM y la Falta de Ensamblador

### Contexto
En la CPU anterior (`kobarius`), contábamos con un ensamblador nativo (archivos `.asm`). En la nueva arquitectura, las instrucciones se han tenido que ensamblar a mano (convirtiendo de mnemónicos a código de máquina hexadecimal) y cargarlas mediante el depurador telnet. 

El profesor solicitó investigar cómo desarrollar una ROM. Una ROM (Read-Only Memory) en este emulador se carga con el flag `-r` (o `--rom`) y espera un **archivo binario puro (raw binary)**, no un archivo de texto.

### Solución: Script `hex2rom.py`
Para automatizar la creación de estos binarios sin tener que escribir bytes manualmente con un editor hexadecimal, desarrollamos un script en Python llamado `hex2rom.py`.

**¿Qué hace y por qué?**
Toma un archivo de texto plano donde cada línea es una instrucción de 32 bits en hexadecimal (previamente ensamblada por nosotros) y la "empaqueta" en un archivo binario.

**Ejemplo de uso:**
Si tenemos el archivo `test_rom.hex` con el siguiente contenido:
```text
# Instruccion: ADDI $at, $zero, 10
0802000A
# Instruccion: ADDI $k0, $zero, 20
08040014
```

Al ejecutar:
```bash
python3 hex2rom.py test_rom.hex mi_sistema.rom
```
El script lee `0802000A`, lo convierte al número entero correspondiente y usa la librería `struct` de Python para escribir exactamente esos 4 bytes en disco, creando una ROM real que la CPU puede arrancar.

---

## 2. El Orden de los Bytes (Endianness)

Uno de los problemas al generar un archivo binario para una CPU que no conocemos a fondo es el "Endianness". Esto define en qué orden se leen los bytes de una palabra de 32 bits en memoria.

* **Little-Endian:** El byte menos significativo se guarda primero (común en x86 y muchas versiones de RISC-V).
* **Big-Endian:** El byte más significativo se guarda primero (históricamente común en MIPS).

**¿Por qué es importante?**
Si la instrucción es `0x0802000A` y la CPU es Big-Endian, espera encontrar los bytes en el orden `08`, `02`, `00`, `0A`. Si nosotros guardamos el archivo en Little-Endian, la CPU leerá `0A`, `00`, `02`, `08` (`0x0A000208`), lo cual es una instrucción completamente distinta (o inválida) y el programa fallará.

**Solución aplicada:**
Agregamos el flag `--big-endian` al script `hex2rom.py`. Esto nos permite compilar la ROM de ambas formas y probar cuál de las dos logra ejecutar correctamente las instrucciones usando el log trace del emulador (`-L TRACE`).

---

## 3. Próximos Cambios en la Arquitectura: Código Relocable

El profesor mencionó que en la próxima versión de STX4 se eliminará un modo de direccionamiento para hacer que el código sea "totalmente relocable". A continuación, desglosamos este concepto.

### ¿Qué es el código relocable?
También conocido como **Position-Independent Code (PIC)**, es un código que funciona perfectamente sin importar en qué dirección física de la memoria se haya cargado. 
Si el sistema operativo carga nuestro programa en la dirección `0x0000`, debe funcionar igual de bien que si lo carga en `0x4000`.

### El problema con el direccionamiento "Pseudo-Directo"
Actualmente, las instrucciones de salto incondicional como `J` y `JAL` (Formato J) usan **Direccionamiento Pseudo-Directo**. Esto significa que codifican una **dirección absoluta** dentro de la instrucción.

* **Ejemplo del problema:**
  Supongamos que nuestro código arranca en la dirección `0x0000` y en `0x0004` hay un salto a `0x0020`:
  `J 0x0020`
  
  Si el sistema operativo reubica TODO el programa para que empiece en la dirección `0x4000`, la instrucción de salto seguirá diciendo `J 0x0020` (porque es absoluto). El salto nos enviará fuera de nuestro programa, rompiendo la ejecución.

### La solución: Saltos relativos al PC (PC-Relative)
El cambio que propone el profesor implica eliminar la dirección absoluta y cambiarla por un **offset** (desplazamiento), tal como funcionan las instrucciones `BEQ` o `BNE`.

* **Ejemplo de la solución:**
  En lugar de `J 0x0020`, la nueva instrucción dirá, conceptualmente, "Salta 8 instrucciones hacia adelante desde el PC actual".
  Al ser relativo, no importa a qué dirección absoluta se mueva el programa; "8 instrucciones hacia adelante" siempre apuntará a la rutina correcta dentro del bloque de código. Por eso el código se vuelve *relocable*.
