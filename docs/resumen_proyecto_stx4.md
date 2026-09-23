# Contexto y Resumen del Proyecto: Arquitectura STX4 (RTM32)

Este documento resume el progreso y las herramientas desarrolladas a lo largo de nuestras sesiones de trabajo para interactuar con la CPU STX4 (emulador `rtm32`) provista por la cátedra.

## 1. Objetivo Principal
El objetivo central fue comprender la arquitectura del procesador RISC de 32 bits (STX4) y desarrollar las herramientas de software base para poder programar, inicializar y testear la máquina sin tener que escribir código máquina (hexadecimal o binario) a mano.

## 2. Herramientas Desarrolladas

### El Ensamblador (`assembler.py`)
Dado que la máquina utiliza un conjunto de instrucciones propio (ISA RTM32), construimos un script en Python que funciona como un compilador cruzado (Cross-Compiler). 
* Traduce código escrito en lenguaje ensamblador con nemotécnicos (ej. `ADD $t0, $t1, $t2`) directamente a un archivo binario `.rom` compatible con el emulador.
* Soporta la resolución de etiquetas (Labels) para saltos relativos de forma automática.
* Fue reescrito completamente para soportar la versión más reciente del ISA (v0.1.5-RC), la cual introdujo sub-códigos de operación, un nuevo mapeo de registros y nuevos formatos de instrucciones.

### El Bootloader (`bootloader.asm`)
Desarrollamos una ROM de arranque (Bootloader) diseñada para superar la limitación del emulador de no contar con un disco duro virtual.
* Se inicializa la memoria (Stack Pointer).
* Entra en un ciclo de escucha a través del puerto serie MMIO (UART) en la dirección `0xFFFFFF00`.
* Lee los bytes transmitidos por el puerto serie y los guarda en la memoria RAM del sistema.
* Al recibir un marcador de fin de archivo (`0xFF`), utiliza un salto incondicional para ceder el control del procesador a la RAM y ejecutar el programa descargado.

### Framework de Pruebas (`run_tests.py`)
Para garantizar la compatibilidad de nuestras herramientas con las actualizaciones de la máquina, construimos un marco de pruebas automatizado de caja negra.
* Genera dinámicamente archivos `.asm` para probar 15 instrucciones distintas, cubriendo todos los formatos de la arquitectura (R-Type, I-Type, J-Type, operaciones lógicas, aritméticas, y saltos indexados a memoria).
* Ensambla, ejecuta un paso en el emulador, lee la traza (trace log) y asegura que la CPU decodifique la instrucción sin disparar fallos (faults) o excepciones de hardware (illegal instructions).

## 3. Evolución y Cambios en la Máquina
A lo largo de las sesiones, la máquina base sufrió dos actualizaciones críticas documentadas por el profesor, a las cuales nos fuimos adaptando:

1. **Reorganización de Registros y Código Relocable (v0.5):** 
   Se alteró el mapeo físico de casi todos los registros de propósito general (ej. el Return Address pasó de `$31` a `$1`). Adicionalmente, se eliminó el direccionamiento pseudo-directo: las instrucciones `J` y `JAL` pasaron a utilizar direccionamiento PC-Relativo, lo que permitió que todo el software de la máquina se vuelva 100% relocable en memoria.

2. **Reorganización Masiva del ISA (v0.1.5-RC):**
   Un cambio drástico que alteró la codificación binaria de todas las instrucciones. Se introdujeron sub-opcodes en los bits restantes de varias instrucciones, duplicando la cantidad de comandos disponibles sin cambiar el formato de 32 bits (por ejemplo, dividiendo `ANDI` de `LCI` mediante el bit `h`, o reutilizando el registro `rt` para los saltos indirectos como `JR`). Las instrucciones indexadas a memoria (`LWX`, `SWX`) pasaron a formar parte del bloque R-Type. Nuestro ensamblador fue actualizado exitosamente para soportar este nuevo "idioma".
