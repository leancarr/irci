; Snake Game - STX4 Bare Metal
; Main Game Loop

_start:
    ; 1. Setup Stack
    ADDI $sp, $zero, 4096
    
    ; 2. Initialize Pointers and Variables
    ADDI $a0, $zero, 2048      ; $a0 = Grid base address (2048)
    
    ADDI $k0, $zero, -256       ; $k0 = UART base address (0xFFFFFF00)
    
    ADDI $a1, $zero, 136        ; $a1 = Initial head index (center)
    ADDI $a2, $zero, 100        ; $a2 = Initial direction 'd' (100)
    
    ; 3. Inicializar Juego
    JAL init_game
    
game_loop:
    ; Renderizar
    JAL clear_screen
    JAL draw_grid
    
    ; Delay (Busy wait) - ajustado para modo telnet (~0.5s/frame).
    ADDI $t0, $zero, 0x0400
delay_loop:
    ADDI $t1, $zero, 1
    SUB $t0, $t0, $t1
    BEQ $t0, $zero, end_delay
    J delay_loop
end_delay:

    ; Input
    JAL get_input
    BEQ $v0, $zero, keep_direction
    ADD $a2, $zero, $v0         ; Actualizar direccion
keep_direction:

    ; Mover serpiente: calcular candidato SIN mover, chequear, y solo
    ; entonces mover/dibujar. (Antes se chequeaba DESPUES de dibujar la
    ; nueva cabeza, que es 'O' -> muerte instantanea en el frame 1.)
    ADD $t8, $zero, $a1        ; backup head actual ($t8 libre en todo el juego)
    JAL compute_next          ; $v0 = candidato (puro, no toca memoria)

    ; Check Collision sobre el candidato
    ADD $a1, $zero, $v0
    JAL check_collision

    ; si $v0 == 1 (Fatal), Game Over
    ADDI $t0, $zero, 1
    BEQ $v0, $t0, game_over

    ; Seguro (0) o comida (2): restaurar head y mover/dibujar
    ADD $a1, $zero, $t8
    JAL update_snake
    ADD $a1, $zero, $v0

    ; Repetir bucle
    J game_loop
    
game_over:
    J game_over
