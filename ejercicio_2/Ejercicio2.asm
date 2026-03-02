;=========================================================
; Código en Assembler para PIC18F4550
; Secuencia de parpadeo en RB0:
; 5 parpadeos de 1 segundo
; Luego 2 parpadeos de 2 segundos
; Reinicia la secuencia
; Usa retardos sin interrupciones ni Timer0
; Frecuencia: 8 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;=========================================================

    #include <xc.inc>   ; Definiciones para PIC18F4550

;=========================================================
; Bits de Configuración (Fuses)
;=========================================================

    CONFIG  FOSC = INTOSCIO_EC   ; Oscilador interno
    CONFIG  WDT = OFF            ; Watchdog deshabilitado
    CONFIG  LVP = OFF            ; Programación en bajo voltaje deshabilitada
    CONFIG  PBADEN = OFF         ; PORTB configurado como digital

;=========================================================
; Vector de Reinicio
;=========================================================

    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

;=========================================================
; Código Principal
;=========================================================

    PSECT  main_code, class=CODE, reloc=2

Inicio:

    ;-----------------------------------
    ; Configurar Oscilador Interno a 8 MHz
    ;-----------------------------------
    MOVLW   0x72        ; IRCF = 111 (8 MHz) | SCS = 10 (Oscilador interno)
    MOVWF   OSCCON

    CLRF    TRISB       ; PORTB como salida
    CLRF    LATB        ; LED apagado inicialmente

Secuencia:

;---------------------------------------------
; 5 Parpadeos de 1 segundo
;---------------------------------------------

    MOVLW   5
    MOVWF   Contador1

Parpadeo1s:

    BSF     LATB,0
    CALL    Retardo_1s

    BCF     LATB,0
    CALL    Retardo_1s

    DECFSZ  Contador1,F
    GOTO    Parpadeo1s


;---------------------------------------------
; 2 Parpadeos de 2 segundos
;---------------------------------------------

    MOVLW   2
    MOVWF   Contador2

Parpadeo2s:

    BSF     LATB,0
    CALL    Retardo_2s

    BCF     LATB,0
    CALL    Retardo_2s

    DECFSZ  Contador2,F
    GOTO    Parpadeo2s

    GOTO    Secuencia

;=========================================================
; Subrutina Retardo 1 Segundo (Aprox.)
;=========================================================

Retardo_1s:

    MOVLW   8
    MOVWF   Contador1     

Loop1:
    MOVLW   250
    MOVWF   Contador2     

Loop2:
    MOVLW   250
    MOVWF   Contador3

Loop3:
    DECFSZ  Contador3,F
    GOTO    Loop3

    DECFSZ  Contador2,F
    GOTO    Loop2

    DECFSZ  Contador1,F
    GOTO    Loop1

    RETURN

;=========================================================
; Subrutina Retardo 2 Segundos
;=========================================================

Retardo_2s:
    CALL    Retardo_1s
    CALL    Retardo_1s
    RETURN

;=========================================================
; Variables en RAM
;=========================================================

    PSECT udata

Contador1:   DS 1
Contador2:   DS 1
Contador3:   DS 1

    END
