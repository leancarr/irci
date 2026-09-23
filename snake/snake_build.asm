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
    
    ; Delay (Busy wait)
    ADDI $t0, $zero, 0x4000
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

    ; Mover serpiente
    JAL update_snake
    
    ; El nuevo index de update_snake viene en $v0
    ADD $a1, $zero, $v0
    
    ; Check Collision
    JAL check_collision
    
    ; si $v0 == 1 (Fatal), Game Over
    ADDI $t0, $zero, 1
    BEQ $v0, $t0, game_over
    
    ; Repetir bucle
    J game_loop
    
game_over:
    J game_over
; Game Initialization Module
; Sets up the starting memory grid for the Snake game.
; Expects $a0 to contain the base address of the 16x16 grid (256 bytes)

init_game:
    ; Variables:
    ; $t2 = row (0 to 15)
    ; $t3 = col (0 to 15)
    ; $t4 = current address pointer
    ; $t5 = 16 (limit)
    ; $t6 = 15 (max index for border check)
    ; $t7 = '#' (35)
    ; $t8 = '.' (46)
    
    ADD $t4, $zero, $a0
    ADDI $t2, $zero, 0
    ADDI $t5, $zero, 16
    ADDI $t6, $zero, 15
    
    ADDI $t7, $zero, 35
    ADDI $t8, $zero, 46
    
row_loop_init:
    BEQ $t2, $t5, done_init
    ADDI $t3, $zero, 0
    
col_loop_init:
    BEQ $t3, $t5, end_col_init
    
    ; Es borde si row==0, row==15, col==0, o col==15
    BEQ $t2, $zero, write_wall
    BEQ $t2, $t6, write_wall
    BEQ $t3, $zero, write_wall
    BEQ $t3, $t6, write_wall
    
    ; Si no es borde, dibujamos espacio vacio
    SB $t8, 0($t4)
    J next_col_init
    
write_wall:
    SB $t7, 0($t4)
    
next_col_init:
    ADDI $t4, $t4, 1
    ADDI $t3, $t3, 1
    J col_loop_init
    
end_col_init:
    ADDI $t2, $t2, 1
    J row_loop_init
    
done_init:
    ; Posicionar serpiente (cabeza) en centro (8, 8) => index = 8*16 + 8 = 136
    ADDI $t4, $a0, 136
    ADDI $t7, $zero, 79  ; 'O' (ASCII 79)
    SB $t7, 0($t4)
    
    ; Spawnea la primer comida estaticamente en (4,4) => index = 68
    ADDI $t4, $a0, 68
    ADDI $t7, $zero, 64  ; '@' (ASCII 64)
    SB $t7, 0($t4)
    
    JR $ra
; Renderer Module
; Handles sending ASCII characters to UART (Display)
; Expects $k0 to contain 0xFFFFFF00

clear_screen:
    ; Sends ANSI "\x1b[2J" (Clear screen) and "\x1b[H" (Cursor home)
    ; 1. "\x1b[2J"
    ADDI $t0, $zero, 27   ; ESC
    SB $t0, 0($k0)
    ADDI $t0, $zero, 91   ; '['
    SB $t0, 0($k0)
    ADDI $t0, $zero, 50   ; '2'
    SB $t0, 0($k0)
    ADDI $t0, $zero, 74   ; 'J'
    SB $t0, 0($k0)
    
    ; 2. "\x1b[H"
    ADDI $t0, $zero, 27   ; ESC
    SB $t0, 0($k0)
    ADDI $t0, $zero, 91   ; '['
    SB $t0, 0($k0)
    ADDI $t0, $zero, 72   ; 'H'
    SB $t0, 0($k0)
    
    JR $ra

draw_grid:
    ; Sends a 16x16 grid of ASCII bytes from memory to UART
    ; $a0 = base address of the grid
    
    ADD $t4, $zero, $a0        ; $t4 = current address pointer
    ADDI $t2, $zero, 0         ; $t2 = row counter = 0
    ADDI $t5, $zero, 16        ; Constant 16 for loop limit
    
row_loop:
    BEQ $t2, $t5, end_draw     ; if row == 16, return
    ADDI $t3, $zero, 0         ; $t3 = col counter = 0
    
col_loop:
    BEQ $t3, $t5, end_col      ; if col == 16, print newline
    
    LBU $t6, 0($t4)            ; Load byte from grid
    SB $t6, 0($k0)             ; Send to UART
    
    ADDI $t4, $t4, 1           ; ptr++
    ADDI $t3, $t3, 1           ; col++
    J col_loop
    
end_col:
    ; Send CR (13) and LF (10)
    ADDI $t6, $zero, 13
    SB $t6, 0($k0)
    ADDI $t6, $zero, 10
    SB $t6, 0($k0)
    
    ADDI $t2, $t2, 1           ; row++
    J row_loop
    
end_draw:
    JR $ra
; Input Module
; Handles non-blocking UART polling for player controls
; Expects $k0 to contain 0xFFFFFF00

get_input:
    ; Lee un byte del puerto UART
    LBU $v0, 0($k0)
    
    ; Si no hay caracter, el UART retorna tipicamente 0xFF o 0x00
    ; Verificar si es 0xFF (255 en decimal)
    ADDI $t0, $zero, 255
    BEQ $v0, $t0, no_input
    
    ; Verificar si es 0x00 (0)
    BEQ $v0, $zero, no_input
    
    ; Si llego aca, hay una tecla presionada guardada en $v0
    JR $ra

no_input:
    ; No se toco ninguna tecla, retornamos 0
    ADDI $v0, $zero, 0
    JR $ra
; Update Snake logic
; Moves the snake head (length 1 for now)
; Input:
; $a0 = grid base address
; $a1 = current head index
; $a2 = direction (119='w', 97='a', 115='s', 100='d')
; Output:
; $v0 = new head index

update_snake:
    ; Erase old head
    ADD $t0, $a0, $a1
    ADDI $t1, $zero, 46   ; '.'
    SB $t1, 0($t0)
    
    ; Determine offset based on input
    ADDI $t1, $zero, 119  ; 'w'
    BEQ $a2, $t1, move_up
    ADDI $t1, $zero, 115  ; 's'
    BEQ $a2, $t1, move_down
    ADDI $t1, $zero, 97   ; 'a'
    BEQ $a2, $t1, move_left
    ADDI $t1, $zero, 100  ; 'd'
    BEQ $a2, $t1, move_right
    
    ; Default to moving right if unknown
    J move_right

move_up:
    ADDI $t2, $zero, 16
    SUB $v0, $a1, $t2
    J draw_new_head

move_down:
    ADDI $t2, $zero, 16
    ADD $v0, $a1, $t2
    J draw_new_head
    
move_left:
    ADDI $t2, $zero, 1
    SUB $v0, $a1, $t2
    J draw_new_head
    
move_right:
    ADDI $t2, $zero, 1
    ADD $v0, $a1, $t2
    J draw_new_head
    
draw_new_head:
    ADD $t0, $a0, $v0
    ADDI $t1, $zero, 79   ; 'O'
    SB $t1, 0($t0)
    JR $ra
; Collision Detection Module
; Checks the future tile of the snake head to determine the game state.

check_collision:
    ; Input:
    ; $a0 = grid base address
    ; $a1 = next head index
    ; Output:
    ; $v0 = 0 (Safe), 1 (GameOver), 2 (EatFood)
    
    ; Obtener la direccion de la celda futura y leerla
    ADD $t0, $a0, $a1
    LBU $t1, 0($t0)
    
    ; Comparar con Pared '#' (35)
    ADDI $t2, $zero, 35
    BEQ $t1, $t2, is_fatal
    
    ; Comparar con Cuerpo 'O' (79)
    ADDI $t2, $zero, 79
    BEQ $t1, $t2, is_fatal
    
    ; Comparar con Comida '@' (64)
    ADDI $t2, $zero, 64
    BEQ $t1, $t2, is_food
    
    ; Default (Espacio vacio) -> Safe
    ADDI $v0, $zero, 0
    JR $ra

is_fatal:
    ADDI $v0, $zero, 1
    JR $ra

is_food:
    ADDI $v0, $zero, 2
    JR $ra
; PRNG Subroutine (Linear Congruential Generator)
; Input:  $a0 = seed (X_n)
; Output: $v0 = next random number (X_{n+1})
; Formula: X_{n+1} = (5 * X_n + 1) mod 16

random:
    ; 1. Multiplicar semilla por 5
    ADDI $t0, $zero, 5
    MUL $t0, $a0, $t0      ; $t0 = 5 * $a0
    
    ; 2. Sumar 1
    ADDI $t0, $t0, 1       ; $t0 = (5 * $a0) + 1
    
    ; 3. Modulo 16 (equivalente a AND bit a bit con 15)
    ADDI $t1, $zero, 15
    AND $v0, $t0, $t1      ; $v0 = $t0 & 15
    
    ; Retornar
    JR $ra
