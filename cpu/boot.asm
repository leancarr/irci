; ROM de prueba para STX4
; Imprime "HOLA" por la UART y se detiene

boot:
    ; Inicializar puntero de pila (final de la RAM, 4KB = 4096 = 0x1000)
    ADDI $sp, $zero, 4096

    ; Cargar direccion base de la UART (0xFFFFFF00) en $k0
    ; Usamos LUI para cargar los 16 bits altos
    ; 0xFFFF_FF00 tiene los 16 bits altos = 0xFFFF y bajos = 0xFF00
    LUI $k0, 0xFFFF
    ORI $k0, $k0, 0xFF00

    ; Escribir 'H' (0x48)
    ADDI $t0, $zero, 0x48
    SB $t0, 0($k0)

    ; Escribir 'O' (0x4F)
    ADDI $t0, $zero, 0x4F
    SB $t0, 0($k0)

    ; Escribir 'L' (0x4C)
    ADDI $t0, $zero, 0x4C
    SB $t0, 0($k0)

    ; Escribir 'A' (0x41)
    ADDI $t0, $zero, 0x41
    SB $t0, 0($k0)
    
    ; Nueva linea (\r = 0x0D, \n = 0x0A)
    ADDI $t0, $zero, 0x0D
    SB $t0, 0($k0)
    ADDI $t0, $zero, 0x0A
    SB $t0, 0($k0)

halt:
    J halt
