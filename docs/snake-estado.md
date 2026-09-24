# Snake STX4 — estado: lógica OK, juego bloqueado por el emulador

## Fix aplicado (verificado)

Bug: se chequeaba colisión DESPUÉS de dibujar la nueva cabeza (`'O'`) →
muerte instantánea en frame 1 (PC clavado en `game_over`, probado con
`step 100000` → PC 0x58 en el build original).

Fix en `snake_build.asm` (+ `main.asm`, `update_snake.asm`, nuevo
`compute_next.asm`): calcular candidato puro → chequear → mover.
`update_snake` guarda `$ra` en pila por el JAL anidado.

Prueba por frames (build fix, `step 8000` por ventana, palabra en 0x888
cubre celdas 136-139, little-endian):

| Steps | 0x888      | Cabeza | Estado |
|------:|------------|--------|--------|
|  8000 | 0x2E2E2E4F | 136    | frame 1 en curso, viva |
| 16000 | 0x2E4F2E2E | 137    | movió a la derecha, viva |
| 24000 | 0x4F2E2E2E | 139    | sigue avanzando, viva |

PC siempre en `game_loop`, CAUSE=0, `$sp` balanceado. Paredes y comida
intactas. **El juego progresa y no muere.**

## Bloqueadores del emulador rtm32 v0.5 (no del juego)

1. **`continue` = DOUBLE FAULT instantáneo.** Corre ceros hasta 0x1000 y
   muere (`Vector table fetch failed at 0xF0000004`). Solo `step`/`until`
   ejecutan el programa cargado.
2. **UART no entrega nada al PTY.** Probado hasta con ROM mínima "HOLA"
   (6 escrituras): 0 bytes en el esclavo, con apertura temprana y tardía.
   El emulador encima mantiene abierto el esclavo él mismo (fd 4).
3. **UART hace eco de su propia salida.** `SB 'H'` + `LBU` devuelve `0x48`.
   Si se viera algo, el input leería el propio dibujo como teclas.
4. Build viejo `rtm32.v0.1.1.bak` (puerto 4444) no corre este código
   (PC salvaje tras 20 steps): incompatible, descartado.

## Cómo probarlo hoy (sin pantalla, por memoria)

```bash
cd ~/Escritorio/Proyectos-Mios/irci
python3 cpu/assembler.py snake/snake_build.asm /tmp/snake.bin
rtm32 -d telnet &            # puerto 50001 (NO 4444)
telnet 127.0.0.1 50001
RTM32> load /tmp/snake.bin
RTM32> step 8000
RTM32> examine xw 0x888 1    # 0x2E2E2E4F = cabeza en 136
RTM32> step 8000
RTM32> examine xw 0x888 1    # 0x2E4F2E2E = cabeza en 137 (se movio)
```

## Para jugar de verdad falta

Un build de rtm32 con el serial sano (o correr en una PC donde el PTY
funcione + `continue` no faultee). `play_snake.py` ya está listo para ese
momento (ensambla + load + continue + puente). La lógica del juego está
probada y no se toca más.
