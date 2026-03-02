;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 4.0
;
; Hardware:
;   LEDs               : RB0-RB4 (5 LEDs, salidas)
;   Pulsador secuencia : RA0 (entrada, pull-up externo)
;   Pulsador velocidad : RA1 (entrada, pull-up externo)
;
; Frecuencia: 4 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 v2.20
;
; Comentario de versión:
; V 3.0 tenía las secuencias 1 y 2 funcionando. Se agregan
; las secuencias 3 y 4 para completar los 4 efectos del
; ejercicio. Los pulsadores siguen sin estar activos.
;
; Secuencia 3 — Parpadeo alternado:
;   LEDs pares (RB0,RB2,RB4) e impares (RB1,RB3) alternan.
;   XOR 0x1F sobre LATB invierte RB0-RB4 en una sola op.
;
; Secuencia 4 — Contador binario:
;   Los 5 LEDs cuentan de 0 a 31 (00000?11111).
;   ADDLW 1 + ANDLW 0x1F incrementa y limita a 5 bits:
;   al llegar a 32 (0x20) la máscara devuelve 0 ? reinicia.
;
; === TIMER0 ===
; Sin cambios respecto a versiones anteriores.
;=========================================================

    #include <xc.inc>

   
    ; Configuración de Fuses
    
    CONFIG  FOSC   = INTOSCIO_EC
    CONFIG  CPUDIV = OSC1_PLL2
    CONFIG  USBDIV = 1
    CONFIG  WDT    = OFF
    CONFIG  WDTPS  = 32768
    CONFIG  LVP    = OFF
    CONFIG  PBADEN = OFF
    CONFIG  MCLRE  = ON
    CONFIG  STVREN = ON
    CONFIG  XINST  = OFF

   
    ; Constantes
   
    #define PIN_SEQ         0
    #define PIN_VEL         1

    #define T0_HIGH         0xFE
    #define T0_LOW          0x79

    #define VEL_NORMAL      5

    #define FLAG_PASO       0
    #define FLAG_DIR        1

    #define SEQ_PINGPONG    0
    #define SEQ_LLENADO     1
    #define SEQ_ALTERNADO   2
    #define SEQ_BINARIO     3
    #define TOTAL_SECUENCIAS 4

    #define TOTAL_PASOS_PP  8
    #define TOTAL_PASOS_LL  9
    #define TOTAL_PASOS_ALT 8
    #define TOTAL_PASOS_BIN 32

    #define MASK_LEDS       0x1F ; RB0-RB4
    #define MASK_PARES      0x15 ; RB0, RB2, RB4
    #define MASK_IMPARES    0x0A ; RB1, RB3

    
    ; Vector de Reset
    
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

    
    ; Vectores de interrupción
    
    PSECT  highIntVec, class=CODE, reloc=2
    ORG     0x08
    GOTO    ISR_Timer0

    PSECT  lowIntVec, class=CODE, reloc=2
    ORG     0x18
    RETFIE

    
    ; ISR — Sin cambios respecto a V 2.0
    
    PSECT  isr_code, class=CODE, reloc=2

ISR_Timer0:
    MOVFF   WREG, W_ISR
    MOVFF   STATUS, STATUS_ISR
    MOVFF   BSR, BSR_ISR

    BTFSS   INTCON, 2, A
    GOTO    ISR_Exit
    BCF     INTCON, 2, A

    MOVLW   T0_HIGH
    MOVWF   TMR0H, A
    MOVLW   T0_LOW
    MOVWF   TMR0L, A

    INCF    TickCount, F, A
    MOVF    VelocidadActual, W, A
    CPFSEQ  TickCount, A
    GOTO    ISR_Exit

    CLRF    TickCount, A
    BSF     Flags, FLAG_PASO, A

ISR_Exit:
    MOVFF   BSR_ISR, BSR
    MOVFF   STATUS_ISR, STATUS
    MOVFF   W_ISR, WREG
    RETFIE  1

    
    ; Código Principal
    
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0x60
    MOVWF   OSCCON, A

    MOVLW   0xE0
    MOVWF   TRISB, A
    CLRF    LATB, A

    MOVLW   0xFF
    MOVWF   TRISA, A

    CLRF    TickCount, A
    CLRF    Flags, A
    CLRF    PasoActual, A
    CLRF    SecuenciaActual, A
    MOVLW   VEL_NORMAL
    MOVWF   VelocidadActual, A

    MOVLW   0x01
    MOVWF   LATB, A
    BCF     Flags, FLAG_DIR, A

    MOVLW   0x87
    MOVWF   T0CON, A
    MOVLW   T0_HIGH
    MOVWF   TMR0H, A
    MOVLW   T0_LOW
    MOVWF   TMR0L, A

    BSF     INTCON, 2, A
    BSF     INTCON, 6, A
    BSF     INTCON, 7, A

    
    ; Loop principal
    
Loop:
    BTFSS   Flags, FLAG_PASO, A
    GOTO    Loop
    BCF     Flags, FLAG_PASO, A

    MOVF    SecuenciaActual, W, A
    BZ      Exec_PingPong
    DECF    WREG, W
    BZ      Exec_Llenado
    DECF    WREG, W
    BZ      Exec_Alternado
    DECF    WREG, W
    BZ      Exec_Binario
    GOTO    Loop

    
    ; SECUENCIA 1: sin cambios respecto a V 3.0
    
Exec_PingPong:
    INCF    PasoActual, F, A
    BTFSS   Flags, FLAG_DIR, A
    GOTO    PP_Derecha

PP_Izquierda:
    RRNCF   LATB, F, A
    MOVF    LATB, W, A
    ANDLW   MASK_LEDS
    MOVWF   LATB, A
    MOVF    LATB, W, A
    XORLW   0x01
    BNZ     PP_FinPaso
    BCF     Flags, FLAG_DIR, A
    GOTO    PP_FinPaso

PP_Derecha:
    RLNCF   LATB, F, A
    MOVF    LATB, W, A
    ANDLW   MASK_LEDS
    MOVWF   LATB, A
    MOVF    LATB, W, A
    XORLW   0x10
    BNZ     PP_FinPaso
    BSF     Flags, FLAG_DIR, A

PP_FinPaso:
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_PP
    BNZ     Loop
    CALL    Siguiente_Secuencia
    MOVLW   0x01
    MOVWF   LATB, A
    BCF     Flags, FLAG_DIR, A
    GOTO    Loop

    
    ; SECUENCIA 2: Llenado y Vaciado — sin cambios
    
Exec_Llenado:
    MOVF    PasoActual, W, A
    CALL    Tabla_Llenado
    MOVWF   LATB, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_LL
    BNZ     Loop
    CALL    Siguiente_Secuencia
    GOTO    Loop

    
    ; SECUENCIA 3: Parpadeo Alternado
    ; XOR 0x1F invierte RB0-RB4: pares?impares en cada paso
    
Exec_Alternado:
    MOVF    LATB, W, A
    XORLW   MASK_LEDS            ; Invertir RB0-RB4
    ANDLW   MASK_LEDS
    MOVWF   LATB, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_ALT
    BNZ     Loop
    CALL    Siguiente_Secuencia
    MOVLW   MASK_PARES           ; Reiniciar con pares encendidos
    MOVWF   LATB, A
    GOTO    Loop

    
    ; SECUENCIA 4: Contador Binario
    ; ADDLW 1 + ANDLW 0x1F: incrementa y limita a 5 bits.
    ; Al llegar a 32 (0x20), AND produce 0x00 ? reinicio automático.
    
Exec_Binario:
    MOVF    LATB, W, A
    ADDLW   1
    ANDLW   MASK_LEDS            ; Limitar a RB0-RB4
    MOVWF   LATB, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_BIN
    BNZ     Loop
    CALL    Siguiente_Secuencia
    CLRF    LATB, A
    GOTO    Loop

    
    ; Subrutina: Siguiente_Secuencia
    ; Avanza SecuenciaActual (0?1?2?3?0) y resetea PasoActual
    
Siguiente_Secuencia:
    CLRF    PasoActual, A
    INCF    SecuenciaActual, F, A
    MOVF    SecuenciaActual, W, A
    XORLW   TOTAL_SECUENCIAS
    BNZ     Sig_Sec_Fin
    CLRF    SecuenciaActual, A
Sig_Sec_Fin:
    RETURN

    
    ; Tabla de patrones — Secuencia 2
    
Tabla_Llenado:
    ANDLW   0x0F
    ADDWF   PCL, F, A
    RETLW   0x01
    RETLW   0x03
    RETLW   0x07
    RETLW   0x0F
    RETLW   0x1F
    RETLW   0x0F
    RETLW   0x07
    RETLW   0x03
    RETLW   0x01

    
    ; Variables en RAM
    
    PSECT udata
TickCount:      DS 1
VelocidadActual: DS 1
Flags:          DS 1
SecuenciaActual: DS 1
PasoActual:     DS 1
W_ISR:          DS 1
STATUS_ISR:     DS 1
BSR_ISR:        DS 1

    END