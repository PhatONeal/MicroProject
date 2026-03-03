;=======================================
; PIC18F4550 - 4 Secuencias + boton RB0
; Boton corregido + anti-rebote
; Sin control de velocidad aun
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
SecActual:          DS  1

    PSECT resetVec, class=CODE, reloc=2
    ORG 0x0000
    GOTO    Inicio

    PSECT main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0b01100010
    MOVWF   OSCCON

    CLRF    TRISD
    CLRF    LATD

    MOVLW   0b00000011
    MOVWF   TRISB
    CLRF    LATB

    MOVLW   0x0F
    MOVWF   ADCON1

    CLRF    SecActual

Despachador:
    MOVLW   0
    SUBWF   SecActual, W
    BTFSC   STATUS, 2
    GOTO    Secuencia1

    MOVLW   1
    SUBWF   SecActual, W
    BTFSC   STATUS, 2
    GOTO    Secuencia2

    MOVLW   2
    SUBWF   SecActual, W
    BTFSC   STATUS, 2
    GOTO    Secuencia3

    GOTO    Secuencia4

Secuencia1:
    MOVLW   0b00000001
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000010
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000100
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00001000
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    GOTO    Despachador

Secuencia2:
    MOVLW   0b00000101
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00001010
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    GOTO    Despachador

Secuencia3:
    MOVLW   0b00000001
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000011
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000111
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00001111
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    CLRF    LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    GOTO    Despachador

Secuencia4:
    MOVLW   0b00000001
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000010
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000100
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00001000
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000100
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    MOVLW   0b00000010
    MOVWF   LATD
    CALL    Retardo_500ms
    CALL    RevisarBoton

    GOTO    Despachador

; Revisa boton RB0 (activo en bajo)
RevisarBoton:
    BTFSS   PORTB, 0        ; si RB0=1 (no presionado) -> salta
    CALL    CambiarSecuencia
    RETURN

CambiarSecuencia:
    CALL    Retardo_Debounce
    BTFSC   PORTB, 0        ; si se soltó durante debounce -> ignorar
    RETURN

    INCF    SecActual, F
    MOVLW   4
    SUBWF   SecActual, W
    BTFSC   STATUS, 2
    CLRF    SecActual

EsperaS:
    BTFSS   PORTB, 0
    GOTO    EsperaS
    CALL    Retardo_Debounce
    GOTO    Despachador

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

Retardo_Debounce:
    MOVLW   1
    MOVWF   ContadorExterno
LoopDa:
    MOVLW   66
    MOVWF   ContadorMedio
LoopDb:
    MOVLW   150
    MOVWF   ContadorInterno
LoopDc:
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    LoopDc
    DECFSZ  ContadorMedio, F
    GOTO    LoopDb
    DECFSZ  ContadorExterno, F
    GOTO    LoopDa
    RETURN

    END
