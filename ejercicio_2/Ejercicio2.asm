;=========================================================
; Código en Assembler para PIC18F4550
; Secuencia de parpadeo en RB0:
; 5 parpadeos de 1 segundo (10 segundos totales)
; Luego 2 parpadeos de 2 segundos
; Reinicia la secuencia
; Usa retardos sin interrupciones ni Timer0
; Frecuencia: 8 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;=========================================================

    #include <xc.inc>   ; Definiciones del ensamblador para PIC18F4550

;=========================================================
; Bits de Configuración (Fuses)
;=========================================================

    CONFIG  FOSC = INTOSCIO_EC   ; Usa el oscilador interno
    CONFIG  WDT = OFF            ; Deshabilitar el Watchdog Timer
    CONFIG  LVP = OFF            ; Deshabilitar la programación en bajo voltaje
    CONFIG  PBADEN = OFF         ; Configurar PORTB como digital

;=========================================================
; Vector de Reinicio
;=========================================================

    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio               ; Saltar a la rutina principal

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

    CLRF    TRISB       ; Configurar PORTB como salida
    CLRF    LATB        ; Apagar LED inicialmente

Secuencia:

;---------------------------------------------
; 5 Parpadeos de 1 segundo
;---------------------------------------------

    MOVLW   5                   ; Cargar contador con 5 repeticiones
    MOVWF   ContadorParp1       ; Guardar en variable de control

Parpadeo1s:

    BSF     LATB,0              ; Encender LED
    CALL    Retardo_1s          ; Esperar 1 segundo

    BCF     LATB,0              ; Apagar LED
    CALL    Retardo_1s          ; Esperar 1 segundo

    DECFSZ  ContadorParp1,F     ; Decrementar contador
    GOTO    Parpadeo1s          ; Repetir hasta completar 5

;---------------------------------------------
; 2 Parpadeos de 2 segundos
;---------------------------------------------

    MOVLW   2                   ; Cargar contador con 2 repeticiones
    MOVWF   ContadorParp2       ; Guardar en variable de control

Parpadeo2s:

    BSF     LATB,0              ; Encender LED
    CALL    Retardo_2s          ; Esperar 2 segundos

    BCF     LATB,0              ; Apagar LED
    CALL    Retardo_2s          ; Esperar 2 segundos

    DECFSZ  ContadorParp2,F     ; Decrementar contador
    GOTO    Parpadeo2s          ; Repetir hasta completar 2

    GOTO    Secuencia           ; Reiniciar toda la secuencia

;=========================================================
; Subrutina Retardo de 1 Segundo (Aprox.)
;=========================================================

Retardo_1s:

    MOVLW   8                   ; Nivel externo del retardo
    MOVWF   Delay1

Loop1:
    MOVLW   250                 ; Nivel intermedio
    MOVWF   Delay2

Loop2:
    MOVLW   250                 ; Nivel interno
    MOVWF   Delay3

Loop3:
    DECFSZ  Delay3,F            ; Decrementar contador interno
    GOTO    Loop3

    DECFSZ  Delay2,F            ; Decrementar contador intermedio
    GOTO    Loop2

    DECFSZ  Delay1,F            ; Decrementar contador externo
    GOTO    Loop1

    RETURN                      ; Retornar al programa principal

;=========================================================
; Subrutina Retardo de 2 Segundos
; (Llama dos veces al retardo de 1 segundo)
;=========================================================

Retardo_2s:
    CALL    Retardo_1s          ; Primer segundo
    CALL    Retardo_1s          ; Segundo segundo
    RETURN

;=========================================================
; Definición de Variables
;=========================================================

    PSECT udata

ContadorParp1:   DS 1   ; Control de los 5 parpadeos
ContadorParp2:   DS 1   ; Control de los 2 parpadeos

Delay1:          DS 1   ; Contador externo del retardo
Delay2:          DS 1   ; Contador intermedio del retardo
Delay3:          DS 1   ; Contador interno del retardo

    END                     ; Fin del programa