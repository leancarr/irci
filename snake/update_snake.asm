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
