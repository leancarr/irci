
    ; Inicializamos la pila
    ADDI $sp, $zero, 4096
    
    ; Setup memory base for the grid in $a0 (e.g. 0x1000)
    LCI $a0, $zero, 0x1000
    
    ; Setup starting seed in $a1
    ADDI $a1, $zero, 42
    
    ; Llamamos a la funcion
    JAL init_game
    
    end: J end
    
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
