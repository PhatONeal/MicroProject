;=======================================
; PIC18F4550 - Secuencia desplazamiento
; LEDs RD0-RD3, sin botones aun
; Oscilador interno 4MHz
;=======================================

    CONFIG  FOSC = INTOSC_EC
    CONFIG  WDT  = OFF
    CONFIG  PBADEN = OFF
    CONFIG  LVP  = OFF

#include <xc.inc>

    PSECT udata_acs
ContadorExterno:    DS  1
ContadorMedio:      DS  1
ContadorInterno:    DS  1

    PSECT resetVec, class=CODE, reloc=2
    ORG 0x0000
    GOTO    Inicio

    PSECT main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0b01100010
    MOVWF   OSCCON

    CLRF    TRISD
    CLRF    LATD

    ; PORTB entradas (botones - aun sin usar)
    MOVLW   0b00000011
    MOVWF   TRISB
    CLRF    LATB

Secuencia1:
    MOVLW   0b00000001      ; RD0
    MOVWF   LATD
    CALL    Retardo_500ms

    MOVLW   0b00000010      ; RD1
    MOVWF   LATD
    CALL    Retardo_500ms

    MOVLW   0b00000100      ; RD2
    MOVWF   LATD
    CALL    Retardo_500ms

    MOVLW   0b00001000      ; RD3
    MOVWF   LATD
    CALL    Retardo_500ms

    GOTO    Secuencia1

Retardo_500ms:
    MOVLW   2
    MOVWF   ContadorExterno
Loop500a:
    MOVLW   250
    MOVWF   ContadorMedio
Loop500b:
    MOVLW   250
    MOVWF   ContadorInterno
Loop500c:
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    Loop500c
    DECFSZ  ContadorMedio, F
    GOTO    Loop500b
    DECFSZ  ContadorExterno, F
    GOTO    Loop500a
    RETURN

    END
