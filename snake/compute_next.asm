; Compute Next Head (pure: no memory writes)
; Input:
; $a1 = current head index
; $a2 = direction (119='w', 97='a', 115='s', 100='d')
; Output:
; $v0 = candidate index
; Preserves $a1,$a2. Clobbers $t1,$t2.
; Se usa ANTES de mover para chequear colision sobre el candidato
; (fix del bug de muerte instantanea en frame 1).

compute_next:
    ADDI $t1, $zero, 119  ; 'w'
    BEQ $a2, $t1, up_c
    ADDI $t1, $zero, 115  ; 's'
    BEQ $a2, $t1, down_c
    ADDI $t1, $zero, 97   ; 'a'
    BEQ $a2, $t1, left_c
    ADDI $t1, $zero, 100  ; 'd'
    BEQ $a2, $t1, right_c

    J right_c             ; default: derecha

up_c:
    ADDI $t2, $zero, 16
    SUB $v0, $a1, $t2
    JR $ra

down_c:
    ADDI $t2, $zero, 16
    ADD $v0, $a1, $t2
    JR $ra

left_c:
    ADDI $t2, $zero, 1
    SUB $v0, $a1, $t2
    JR $ra

right_c:
    ADDI $t2, $zero, 1
    ADD $v0, $a1, $t2
    JR $ra
