; Update Snake logic
; Moves the snake head (length 1 for now)
; Input:
; $a0 = grid base address
; $a1 = current head index
; $a2 = direction (119='w', 97='a', 115='s', 100='d')
; Output:
; $v0 = new head index
; NOTA: usa JAL anidado a compute_next -> guarda $ra en pila.

update_snake:
    ; push $ra (llamamos a compute_next con JAL anidado)
    ADDI $sp, $sp, -4
    SW $ra, 0($sp)

    ; Erase old head
    ADD $t0, $a0, $a1
    ADDI $t1, $zero, 46   ; '.'
    SB $t1, 0($t0)

    ; Candidato (puro, ver compute_next.asm)
    JAL compute_next

    ; Dibujar nueva cabeza
    ADD $t0, $a0, $v0
    ADDI $t1, $zero, 79   ; 'O'
    SB $t1, 0($t0)

    ; pop $ra
    LW $ra, 0($sp)
    ADDI $sp, $sp, 4
    JR $ra
