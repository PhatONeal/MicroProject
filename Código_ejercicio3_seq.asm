;=======================================
; PIC18F4550 - 4 Secuencias LED
; LEDs     : RD0, RD1, RD2, RD3 (salidas)
; Boton Sec: RB0 (cambio de secuencia)
; Boton Vel: RB1 (cambio de velocidad)
; Oscilador interno 4MHz
; Compilador: XC8 / MPASM - MPLAB X
;=======================================

    CONFIG  FOSC = INTOSC_EC
    CONFIG  WDT  = OFF
    CONFIG  PBADEN = OFF
    CONFIG  LVP  = OFF

#include <xc.inc>

;------ Variables en Access RAM (0x00-0x5F) ------
    PSECT udata_acs
ContadorExterno:    DS  1
ContadorMedio:      DS  1
ContadorInterno:    DS  1
Velocidad:          DS  1   ; 0=lento(500ms)  1=rapido(200ms)
SecActual:          DS  1   ; 0,1,2,3

;------ Vector de Reset ------
    PSECT resetVec, class=CODE, reloc=2
    ORG 0x0000
    GOTO    Inicio

;------ Codigo principal ------
    PSECT main_code, class=CODE, reloc=2

;=============================================
; INICIO: configuracion de puertos
;=============================================
Inicio:
    MOVLW   0b01100010
    MOVWF   OSCCON          ; 4 MHz interno

    ; PORTB: RB0=entrada (boton sec), RB1=entrada (boton vel)
    MOVLW   0b00000011
    MOVWF   TRISB
    CLRF    LATB

    ; PORTD: RD0-RD3 salidas (LEDs)
    CLRF    TRISD
    CLRF    LATD

    ; Deshabilitar analogicos
    MOVLW   0x0F
    MOVWF   ADCON1

    CLRF    Velocidad
    CLRF    SecActual

;=============================================
; DESPACHADOR: decide que secuencia ejecutar
;=============================================
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

;=============================================
; SECUENCIA 1: Desplazamiento izq -> der
; RD0 -> RD1 -> RD2 -> RD3
;=============================================
Secuencia1:
    MOVLW   0b00000001      ; RD0
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000010      ; RD1
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000100      ; RD2
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00001000      ; RD3
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    GOTO    Despachador

;=============================================
; SECUENCIA 2: Pares / Impares alternados
; RD0,RD2 <-> RD1,RD3
;=============================================
Secuencia2:
    MOVLW   0b00000101      ; RD0, RD2
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00001010      ; RD1, RD3
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    GOTO    Despachador

;=============================================
; SECUENCIA 3: Acumulativo (enciende uno a uno)
; RD0 -> RD0+RD1 -> RD0+RD1+RD2 -> todos -> apaga
;=============================================
Secuencia3:
    MOVLW   0b00000001      ; RD0
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000011      ; RD0, RD1
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000111      ; RD0, RD1, RD2
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00001111      ; RD0, RD1, RD2, RD3
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    CLRF    LATD            ; apaga todos
    CALL    RetardoSel
    CALL    RevisarBotones

    GOTO    Despachador

;=============================================
; SECUENCIA 4: Ping-pong (rebote)
; RD0->RD1->RD2->RD3->RD2->RD1->RD0
;=============================================
Secuencia4:
    MOVLW   0b00000001      ; RD0
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000010      ; RD1
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000100      ; RD2
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00001000      ; RD3
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000100      ; RD2 (vuelta)
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    MOVLW   0b00000010      ; RD1 (vuelta)
    MOVWF   LATD
    CALL    RetardoSel
    CALL    RevisarBotones

    GOTO    Despachador

;=============================================
; SUBRUTINA: Revisa ambos botones
; RB0 = cambio secuencia (activo en bajo)
; RB1 = cambio velocidad (activo en bajo)
;=============================================
RevisarBotones:
    BTFSS   PORTB, 0        ; si RB0=1 (no presionado) -> salta
    CALL    CambiarSecuencia
    BTFSS   PORTB, 1        ; si RB1=1 (no presionado) -> salta
    CALL    CambiarVelocidad
    RETURN

;=============================================
; SUBRUTINA: Avanza secuencia 0->1->2->3->0
;=============================================
CambiarSecuencia:
    CALL    Retardo_Debounce
    BTFSC   PORTB, 0        ; si ya se soltó, ignorar
    RETURN

    INCF    SecActual, F
    MOVLW   4
    SUBWF   SecActual, W
    BTFSC   STATUS, 2       ; si SecActual==4 -> resetear a 0
    CLRF    SecActual

EsperaS:
    BTFSS   PORTB, 0        ; espera soltar boton
    GOTO    EsperaS
    CALL    Retardo_Debounce
    GOTO    Despachador     ; ejecuta nueva secuencia de inmediato

;=============================================
; SUBRUTINA: Alterna velocidad lento<->rapido
;=============================================
CambiarVelocidad:
    CALL    Retardo_Debounce
    BTFSC   PORTB, 1        ; si ya se soltó, ignorar
    RETURN

    MOVLW   0
    SUBWF   Velocidad, W
    BTFSC   STATUS, 2       ; si Velocidad==0 -> poner rapido
    GOTO    PonerRapido
    CLRF    Velocidad       ; si no -> poner lento
    GOTO    EsperaV
PonerRapido:
    MOVLW   1
    MOVWF   Velocidad

EsperaV:
    BTFSS   PORTB, 1        ; espera soltar boton
    GOTO    EsperaV
    CALL    Retardo_Debounce
    RETURN

;=============================================
; SUBRUTINA: Selecciona retardo segun Velocidad
; 0 = 500ms (lento)   1 = 200ms (rapido)
;=============================================
RetardoSel:
    MOVLW   0
    SUBWF   Velocidad, W
    BTFSC   STATUS, 2
    GOTO    IrLento
    CALL    Retardo_200ms
    RETURN
IrLento:
    CALL    Retardo_500ms
    RETURN

;=============================================
; RETARDO ~200ms  (4MHz)
;=============================================
Retardo_200ms:
    MOVLW   2
    MOVWF   ContadorExterno
Loop200a:
    MOVLW   133
    MOVWF   ContadorMedio
Loop200b:
    MOVLW   150
    MOVWF   ContadorInterno
Loop200c:
    NOP
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    Loop200c
    DECFSZ  ContadorMedio, F
    GOTO    Loop200b
    DECFSZ  ContadorExterno, F
    GOTO    Loop200a
    RETURN

;=============================================
; RETARDO ~500ms  (4MHz)
;=============================================
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

;=============================================
; RETARDO ~20ms anti-rebote
;=============================================
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

