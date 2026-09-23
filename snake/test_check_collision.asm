
    ; Inicializamos la pila
    ADDI $sp, $zero, 4096
    
    ; Setup memory base for the grid in $a0
    LCI $a0, $zero, 0x1000
    
    ; Setup next head index in $a1
    ADDI $a1, $zero, 137
    
    ; Llamamos a la funcion
    JAL check_collision
    
    end: J end
    
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
