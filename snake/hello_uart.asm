    LCI $k0, $zero, 0xFFFF
    ORI $k0, $k0, 0xFF00
    ADDI $t0, $zero, 0x48 ; 'H'
    SB $t0, 0($k0)
    ADDI $t0, $zero, 0x69 ; 'i'
    SB $t0, 0($k0)
    ADDI $t0, $zero, 0x0A ; '\n'
    SB $t0, 0($k0)
    
    end: J end
