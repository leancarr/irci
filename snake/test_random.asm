
    ; Inicializamos la pila
    ADDI $sp, $zero, 4096
    
    ; Cargamos la semilla inicial = 3 en $a0
    ADDI $a0, $zero, 3
    
    ; Llamamos a la subrutina random
    JAL random
    
    ; Instruccion 'fantasma' para dumpear el valor de $v0 en el trace log de rtm32
    ADD $v0, $zero, $v0
    
    ; Fin de ejecucion
    end: J end
    
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
