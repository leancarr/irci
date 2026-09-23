
    ; Inicializamos la pila
    ADDI $sp, $zero, 4096
    
    ; Setup UART base address in $k0
    LCI $k0, $zero, 0xFFFF
    ORI $k0, $k0, 0xFF00
    
    ; Llamamos a la funcion de input
    JAL get_input
    
    end: J end
    
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
