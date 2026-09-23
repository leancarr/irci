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
