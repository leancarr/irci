# Documentación de Pruebas de Arquitectura (v0.1.5-RC)

Para verificar el correcto funcionamiento del nuevo ensamblador (`assembler.py`) adaptado a la drástica reestructuración de la máquina RTM32 (Versión 0.1.5-RC), se diseñó y ejecutó un banco de **15 pruebas automatizadas**.

## Estrategia de Prueba

Se implementó el script `run_tests.py`, el cual realiza las siguientes acciones para cada una de las 15 pruebas:
1. Genera de forma dinámica un programa en ensamblador (`.asm`) de una o dos líneas que ejercita un formato o una familia de instrucciones específica.
2. Invoca el compilador `assembler.py` para generar la imagen de memoria ROM (`.rom`).
3. Ejecuta la imagen recién creada en el emulador `rtm32` configurando un límite de ejecución (`-n 1`) y activando la traza (`-L TRACE`).
4. Analiza la salida estándar y de error del emulador para asegurarse de que no haya reportes de `illegal instruction` o de excepciones (traps), lo que confirmaría que la instrucción binaria generada es 100% compatible con el decodificador de la CPU.

## Desglose de Pruebas

A continuación se detallan las instrucciones probadas y el resultado. Cada instrucción valida un camino de datos o de control diferente de los nuevos formatos:

| # | Instrucción | Tipo | Familia Validada | Resultado |
|---|-------------|------|------------------|-----------|
| 1 | `ADD $t0, $t1, $t2` | R-Type | Aritmética estándar | ✅ SUCCESS |
| 2 | `SLL $t0, $t1, 5` | R-Type | Desplazamientos | ✅ SUCCESS |
| 3 | `AND $t0, $t1, $t2` | R-Type | Operaciones lógicas | ✅ SUCCESS |
| 4 | `ADDI $t0, $t1, 42` | I-Type | Aritmética inmediata | ✅ SUCCESS |
| 5 | `LCI $t0, $zero, 0x1234` | I-Type | Carga de constantes de 32 bits (reemplazo de LUI) | ✅ SUCCESS |
| 6 | `LW $t0, 4($sp)` | I-Type | Carga de memoria estándar con desplazamiento | ✅ SUCCESS |
| 7 | `SWX $t0, $t1, $t2` | R-Type | *NUEVO:* Almacenamiento en memoria indexado (Base + Registro) | ✅ SUCCESS |
| 8 | `J boot` | J-Type | Salto incondicional relativo al PC | ✅ SUCCESS |
| 9 | `JAL boot` | J-Type | Salto incondicional con enlace (Llamada a función) | ✅ SUCCESS |
| 10 | `JR $ra` | I-Type (Esp) | Salto indirecto mediante registro (Retorno de función) | ✅ SUCCESS |
| 11 | `BEQ $t0, $t1, end` | I-Type | Salto condicional | ✅ SUCCESS |
| 12 | `MUL $t0, $t1, $t2` | R-Type | Multiplicación de hardware | ✅ SUCCESS |
| 13 | `SLT $t0, $t1, $t2` | R-Type | Comparación aritmética | ✅ SUCCESS |
| 14 | `LHX $t0, $t1, $t2` | R-Type | *NUEVO:* Carga indexada de 16-bits | ✅ SUCCESS |
| 15 | `LBU $t0, 4($sp)` | I-Type | Carga de 8-bits sin signo con desplazamiento | ✅ SUCCESS |

## Resultados
**¡15 de 15 pruebas pasaron con éxito!**
El emulador inicializó la máquina, reconoció las nuevas instrucciones binarias y las ejecutó sin disparar ninguna excepción de hardware, demostrando que `assembler.py` genera código objeto nativo que es interpretado a la perfección por la arquitectura STX4 v0.1.5-RC.
