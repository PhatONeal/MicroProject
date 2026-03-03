;=======================================
; PIC18F4550 - Prueba inicial
; LED en RD0, parpadeo simple
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

    CLRF    TRISD           ; PORTD todo salidas
    CLRF    LATD

Loop:
    MOVLW   0b00000001      ; enciende RD0
    MOVWF   LATD
    CALL    Retardo

    CLRF    LATD            ; apaga
    CALL    Retardo

    GOTO    Loop

Retardo:
    MOVLW   2
    MOVWF   ContadorExterno
Ra: MOVLW   250
    MOVWF   ContadorMedio
Rb: MOVLW   250
    MOVWF   ContadorInterno
Rc: DECFSZ  ContadorInterno, F
    GOTO    Rc
    DECFSZ  ContadorMedio, F
    GOTO    Rb
    DECFSZ  ContadorExterno, F
    GOTO    Ra
    RETURN

    END
