# Guía de Uso Manual del Ensamblador y CPU

Esta guía explica qué es lo que tenemos construido actualmente y cómo usarlo paso a paso, ideal para demostrárselo al profesor de forma manual.

## ¿Qué puede hacer nuestra CPU actual?
En este momento, tenemos un flujo de trabajo de software 100% funcional para la última versión de la CPU STX4 (v0.1.5-RC). Específicamente, podemos:
1. **Escribir código de bajo nivel:** Utilizando los nemotécnicos de la arquitectura RTM32 (como `ADD`, `LW`, `BEQ`, `JAL`).
2. **Compilarlo automáticamente:** Nuestro `assembler.py` traduce este texto a código de máquina binario (`.rom`) respetando la nueva distribución de bits y sub-códigos de operación.
3. **Ejecutarlo en el emulador:** Podemos cargar ese archivo `.rom` directamente en la CPU y ver cómo ejecuta el programa ciclo a ciclo.

## ¿Cómo usarlo paso a paso a mano?

Si el profesor te pide una demostración de cómo funciona lo que armaste, sigue estos pasos:

### 1. Escribir el programa en ensamblador
Crea un archivo llamado `miprog.asm` usando cualquier editor de texto y escribe algunas instrucciones simples. Por ejemplo:

```assembly
    ADDI $t0, $zero, 15    ; Carga el valor 15 en el registro $t0
    ADDI $t1, $zero, 20    ; Carga el valor 20 en el registro $t1
    ADD $t2, $t0, $t1      ; Suma $t0 + $t1 (15 + 20) y lo guarda en $t2
    SW $t2, 0($sp)         ; Guarda el resultado en la memoria (usando el stack pointer)
fin:
    J fin                  ; Bucle infinito para terminar el programa
```

### 2. Ensamblar el código
Abre la terminal en la carpeta del proyecto y utiliza nuestro ensamblador en Python para generar el binario:

```bash
python3 assembler.py miprog.asm miprog.rom
```
*Si todo está bien, la consola te dirá `Ensamblado exitoso`.*

### 3. Ejecutar el código en el emulador
Ahora le pasamos el archivo binario (`.rom`) al emulador `rtm32`. Para que el profesor vea qué está haciendo la CPU internamente, es muy útil encender el modo traza (Trace):

```bash
./rtm32 -r miprog.rom -n 10 -L TRACE
```
*   `-r miprog.rom`: Le indica al emulador que inicie leyendo nuestra ROM.
*   `-n 10`: Ejecuta un máximo de 10 instrucciones (para que no se quede infinitamente en el bucle `J fin`).
*   `-L TRACE`: Imprime en la consola cada instrucción que la CPU va decodificando y los valores de los registros.

¡Y listo! Con esto le puedes demostrar al profesor que **no necesitas escribir números hexadecimales a mano**, sino que tienes un compilador y un entorno de pruebas totalmente automatizado para su nueva arquitectura.
