; loop.asm — Countdown loop test
; Counts from 5 down to 0 using BEQ and J.
; Each iteration stores the counter to consecutive memory addresses.
;
; Expected after HALT:
;   DataMem[0] = 5, DataMem[1] = 4, ..., DataMem[5] = 0
;   R1 = 0 (counter), R2 = 6 (total iterations done), PSW Z=1

LOAD R1, #5         ; R1 = 5  (counter)
LOAD R2, #0         ; R2 = 0  (memory index / iteration count)
LOAD R3, #0         ; R3 = 0  (constant zero for comparison)

loop:
SW   R1, 0(R2)      ; DataMem[R2] = R1
ADD  R2, R2, #1     ; R2++  (advance memory pointer)
ADD  R1, R1, #-1    ; R1--  (decrement counter)
BEQ  R1, R3, done   ; if R1 == 0 jump to done
J    loop           ; else loop back

done:
SW   R1, 0(R2)      ; store final 0
HALT
