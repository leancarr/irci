; Numeros primos en STX4 (assembler.py v0.5)
; Calcula los primeros 10 primos por division de prueba:
;   2,3,5,7,11,13,17,19,23,29
; - Guarda cada primo en RAM (tabla en 0x400)
; - Imprime cada primo en decimal por UART + CRLF
;
; Subrutinas leaf (sin llamadas anidadas): is_prime, print_dec
; Registros: $k0=UART, $s0=hallados, $s1=candidato, $s2=meta(10), $s3=tabla

_start:
    ADDI $sp, $zero, 4096
    ADDI $k0, $zero, -256     ; UART 0xFFFFFF00 (sign-extiende OK)

    ADDI $s0, $zero, 0        ; hallados = 0
    ADDI $s1, $zero, 2        ; candidato = 2
    ADDI $s2, $zero, 10       ; meta = 10 primos
    ADDI $s3, $zero, 0x400    ; tabla de resultados en RAM

next_cand:
    BEQ $s0, $s2, done

    ADD $a0, $zero, $s1       ; is_prime(candidato)
    JAL is_prime
    BEQ $v0, $zero, not_prime

    SW $s1, 0($s3)            ; tabla[i] = primo
    ADDI $s3, $s3, 4

    ADD $a0, $zero, $s1       ; print_dec(primo)
    JAL print_dec

    ADDI $t0, $zero, 13       ; CR
    SB $t0, 0($k0)
    ADDI $t0, $zero, 10       ; LF
    SB $t0, 0($k0)

    ADDI $s0, $s0, 1          ; hallados++

not_prime:
    ADDI $s1, $s1, 1          ; candidato++
    J next_cand

done:
    J done

; is_prime: $a0 = n (n >= 2). $v0 = 1 si primo, 0 si no.
; Prueba divisores d = 2..n-1 con resto manual: r = n - (n/d)*d
is_prime:
    ADDI $t0, $zero, 2        ; d = 2
ip_loop:
    BEQ $t0, $a0, ip_yes      ; si d == n, no hubo divisor -> primo
    DIV $t1, $a0, $t0         ; q = n / d
    MUL $t1, $t1, $t0         ; q * d
    SUB $t1, $a0, $t1         ; r = n - q*d
    BEQ $t1, $zero, ip_no     ; r == 0 -> divisible -> no primo
    ADDI $t0, $t0, 1          ; d++
    J ip_loop
ip_yes:
    ADDI $v0, $zero, 1
    JR $ra
ip_no:
    ADDI $v0, $zero, 0
    JR $ra

; print_dec: imprime $a0 en decimal sin ceros a la izquierda
; (0 se imprime como "0"). Clobbers: $t1-$t6. Buffer digitos en 0x300.
print_dec:
    BNE $a0, $zero, pd_nz
    ADDI $t0, $zero, 48       ; '0'
    SB $t0, 0($k0)
    JR $ra
pd_nz:
    ADDI $t1, $zero, 0x300    ; puntero buffer
    ADD $t2, $zero, $a0       ; valor restante
    ADDI $t3, $zero, 10       ; divisor
pd_div:
    BEQ $t2, $zero, pd_out
    DIV $t4, $t2, $t3         ; cociente
    REST $t5, $t2, $t3        ; resto = digito
    ADDI $t5, $t5, 48         ; a ASCII
    SB $t5, 0($t1)            ; guardar (orden inverso)
    ADDI $t1, $t1, 1
    ADD $t2, $zero, $t4
    J pd_div
pd_out:
    ADDI $t1, $t1, -1         ; ultimo digito guardado
pd_pop:
    SLTI $t6, $t1, 0x300      ; salir si ptr < base
    BNE $t6, $zero, pd_ret
    LBU $t5, 0($t1)
    SB $t5, 0($k0)            ; emitir en orden correcto
    ADDI $t1, $t1, -1
    J pd_pop
pd_ret:
    JR $ra
