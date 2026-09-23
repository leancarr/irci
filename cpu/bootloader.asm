; STX4 UART Bootloader
; Escucha en la UART (0xFFFFFF00) y descarga los bytes en la RAM (a partir de 0x00000040)
; Usa un marcador de fin (ej. 0xFF) para terminar la carga y ejecutar el codigo.

boot:
    ; Inicializar puntero de pila (final de la RAM, 4KB = 4096 = 0x1000)
    ADDI $sp, $zero, 4096

    ; Cargar direccion base de la UART (0xFFFFFF00) en $k0
    LCI $k0, $zero, 0xFFFF
    ORI $k0, $k0, 0xFF00

    ; Cargar direccion de destino en RAM (0x00000040) en $t1
    ; Empezamos en 0x40 para dejar las primeras direcciones libres por si acaso
    ADDI $t1, $zero, 0x40

receive_loop:
    ; Intento de lectura bloqueante o con polling implicito.
    ; Si el emulador implementa un UART bloqueante, esta instruccion esperara el byte.
    ; Si requiere un Status Register, habria que agregar: LB $t2, 4($k0) -> BEQ $t2, $zero, wait
    LB $t0, 0($k0)
    
    ; Si leemos 0xFF (-1), asumimos que el bus esta vacio o es el marcador de EOF.
    ADDI $t2, $zero, 0xFF
    BEQ $t0, $t2, run_program
    
    ; Almacenar el byte recibido en la memoria RAM
    SB $t0, 0($t1)
    
    ; Incrementar el puntero de destino
    ADDI $t1, $t1, 1
    
    ; Volver a escuchar el siguiente byte
    J receive_loop

run_program:
    ; Hacemos un salto absoluto usando un registro, ya que la instruccion J es PC-Relativa
    ; y queremos saltar a la direccion 0x00000040 fija donde cargamos el programa.
    ADDI $t5, $zero, 0x40
    JR $t5
