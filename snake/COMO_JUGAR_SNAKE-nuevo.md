# 🐍 Guía para Ejecutar y Testear Snake Bare-Metal en STX4 (RTM32)

Esta guía explica cómo levantar y jugar al Snake desarrollado para la CPU STX4 sobre el emulador `rtm32`.

---

## ⚡ Método 1: Launcher Automático (1 solo comando - Recomendado)

Creamos un script interactivo en Python que automatiza todo el proceso: reensambla el juego, arranca `rtm32`, conecta la UART virtual (`/dev/pts/X`), desbloquea la CPU vía debugger Telnet y captura tus teclas en tiempo real.

```bash
cd cpu-koba/cpu-nuevo-koba
python3 play_snake.py
```

* **Controles:** Teclas `W` (arriba), `A` (izquierda), `S` (abajo), `D` (derecha).
* **Salir:** Presiona `Ctrl+C` o `ESC`. El script cerrará el emulador y restaurará tu terminal automáticamente.

---

## 🛠️ Método 2: Manual (Paso a paso en 2 o 3 Terminales)

Si prefieres levantar cada componente por separado para inspeccionar la CPU o depurar:

### Paso 1: Ensamblar la ROM
En una terminal:
```bash
cd cpu-koba/cpu-nuevo-koba
python3 assembler.py snake/snake_build.asm snake/snake.rom
```

### Paso 2: Iniciar el Emulador
Lanza el emulador en modo Telnet:
```bash
./rtm32 -r snake/snake.rom -d telnet -L WARN
```
Verás en pantalla una línea como esta:
```text
INFO  [src/bus.c:104]: Bus initialized: User RAM = 4096 bytes, Kernel RAM = 0 bytes.
DEBUG [src/serial.c:62]: UART available on /dev/pts/3   <-- ANOTA ESTE PUERTO
INFO  [src/telnet.c:113]: Telnet server active and listening on port 4444.
```

### Paso 3: Conectar la Pantalla del Juego (Terminal 2)
Abre una **segunda terminal** y conéctate al puerto PTY que te indicó el emulador (ej: `/dev/pts/3`):

* **Opción A (con picocom):**
  ```bash
  picocom -b 115200 /dev/pts/3
  ```
* **Opción B (con screen):**
  ```bash
  screen /dev/pts/3
  ```
* **Opción C (con bash raw):**
  ```bash
  stty raw -echo < /dev/pts/3
  cat /dev/pts/3
  ```

### Paso 4: Arrancar la CPU (Terminal 3 o Netcat)
Abre una **tercera terminal** (o usa netcat / telnet) para indicarle al debugger que inicie la ejecución continua:
```bash
nc localhost 4444
```
Aparecerá el prompt `RTM32>`. Escribe:
```text
RTM32> continue
```
¡Listo! La CPU comenzará a ejecutar el bucle del juego y verás el tablero de $16 \times 16$ renderizarse con secuencias ANSI en la Terminal 2.

---

## ⚙️ Calibración de Velocidad (Delay Loop)

Si sientes que la serpiente se mueve muy rápido o muy lento, puedes ajustar la constante de iteraciones del bucle de retardo en `snake/main.asm` (líneas 26-33):

```asm
    ; Delay (Busy wait)
    LCI $t0, $zero, 0x0002      ; Parte alta del contador
    ORI $t0, $t0, 0xFFFF        ; Parte baja del contador (0x0002FFFF = 196,607 iteraciones)
delay_loop:
    ADDI $t1, $zero, 1
    SUB $t0, $t0, $t1
    BEQ $t0, $zero, end_delay
    J delay_loop
end_delay:
```
- **Más lenta:** Aumenta `LCI $t0, $zero, 0x0004`
- **Más rápida:** Reduce `LCI $t0, $zero, 0x0001`
