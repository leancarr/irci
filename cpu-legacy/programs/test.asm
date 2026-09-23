; test.asm — Basic arithmetic test
; Loads two values, adds them, stores result to memory, then halts.
; Expected result: R3 = 0x001E (30), DataMem[0] = 0x001E

LOAD R1, #10        ; R1 = 10
LOAD R2, #20        ; R2 = 20
ADD  R3, R1, R2     ; R3 = R1 + R2 = 30
SW   R3, 0(R0)      ; DataMem[R0 + 0] = R3  (R0 is 0)
HALT
