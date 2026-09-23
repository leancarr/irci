# Bootloader para Arquitectura STX4 (RTM32)

## ¿Qué es este Bootloader?
Este documento explica cómo funciona el código `bootloader.asm`, el cual actúa como una ROM de arranque capaz de descargar programas externos en la RAM de la CPU usando el puerto serie (UART) y luego ejecutarlos. 

Dado que el emulador `rtm32` actualmente no soporta un disco duro, usamos el UART como nuestro "disco" improvisado.

## ¿Cómo funciona el código paso a paso?

1. **Inicialización (`boot:`)**
   Como en todo programa que use memoria de forma ordenada, inicializamos el Stack Pointer (`$sp`) apuntando al final de la RAM disponible (4096 bytes).

2. **Configuración de Punteros**
   - `$k0`: Apunta a la dirección MMIO del UART (`0xFFFFFF00`).
   - `$t1`: Apunta a la dirección de RAM destino (`0x00000040`). Elegimos `0x40` para dejar las primeras direcciones libres para posibles variables de sistema, vectores de interrupción, etc.

3. **Bucle de Recepción (`receive_loop:`)**
   El procesador se queda en un bucle continuo leyendo un byte a la vez desde el UART usando `LB`.
   - **Mecanismo de Bloqueo/Espera:** Asumimos que leer de la dirección del UART devuelve un valor válido. Si el UART está vacío, se asume que devuelve `0xFF` (`-1`). 
   - **Marcador de Fin (EOF):** Nuestro bootloader usa el byte `0xFF` como señal de que terminó de descargar el programa. Al recibirlo, sale del ciclo.
   - **Escritura en RAM:** Cada byte válido recibido se guarda en la dirección apuntada por `$t1` usando `SB`, y luego se incrementa `$t1`.

4. **Ejecución (`run_program:`)**
   Una vez que el programa se descargó en RAM, el bootloader debe "pasar la antorcha". 
   Usa la instrucción `JR` (Jump Register) para hacer un salto absoluto a la dirección fija `0x00000040` (donde pusimos el primer byte del programa). A partir de ahí, la CPU empieza a ejecutar las instrucciones que acabamos de descargar.

## Código Fuente
El archivo se encuentra en `cpu-nuevo-koba/bootloader.asm`.

```assembly
; STX4 UART Bootloader
boot:
    ADDI $sp, $zero, 4096
    LUI $k0, 0xFFFF
    ORI $k0, $k0, 0xFF00
    ADDI $t1, $zero, 0x40

receive_loop:
    LB $t0, 0($k0)
    
    ADDI $t2, $zero, 0xFF
    BEQ $t0, $t2, run_program
    
    SB $t0, 0($t1)
    ADDI $t1, $t1, 1
    J receive_loop

run_program:
    ADDI $t5, $zero, 0x40
    JR $t5
```

## Limitaciones Conocidas
Si la implementación real del UART en el emulador requiere leer un "Status Register" (por ejemplo, en `0xFFFFFF04`) antes de leer el dato para no leer basura (polling loop real), el código deberá ser modificado para agregar esa validación. Como actualmente no contamos con esa documentación, hemos implementado la versión con "polling implícito" (lectura bloqueante / validación por 0xFF).
