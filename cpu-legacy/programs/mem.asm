; mem.asm — Memory round-trip test (SW + LW)
; Writes a value to memory with SW, reads it back with LW,
; then verifies the read value matches by storing to another location.
;
; Expected after HALT:
;   DataMem[0]  = 0x002B  (written by SW)
;   DataMem[1]  = 0x002B  (read by LW, written again by SW)
;   DataMem[2]  = 0x0042  (second value)
;   R5 = 0x002B, R6 = 0x0042

LOAD R1, #0x2B      ; R1 = 0x2B (43)
LOAD R2, #0x42      ; R2 = 0x42 (66)
LOAD R3, #0         ; R3 = base address 0

; Store R1 to DataMem[0]
SW   R1, 0(R3)      ; DataMem[0] = 0xAB

; Load it back into R5
LW   R5, 0(R3)      ; R5 = DataMem[0] = 0xAB

; Store R5 to DataMem[1] to prove round-trip
SW   R5, 1(R3)      ; DataMem[1] = 0xAB

; Store R2 to DataMem[2]
SW   R2, 2(R3)      ; DataMem[2] = 0x42

; Load DataMem[2] into R6
LW   R6, 2(R3)      ; R6 = 0x42

HALT
