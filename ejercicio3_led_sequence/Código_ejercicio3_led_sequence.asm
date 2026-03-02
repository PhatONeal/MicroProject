;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 4.1
;
; Hardware:
;   LEDs               : RB0-RB4 (5 LEDs, salidas)
;   Pulsador secuencia : RA0 (entrada, pull-up externo)
;   Pulsador velocidad : RA1 (entrada, pull-up externo)
;
; Frecuencia: 4 MHz
; Ensamblador: MPLAB XC8 v2.20
;
; Comentario de versión:
; V 3.0 tenía las secuencias 1 y 2 funcionando. Se agregan
; las secuencias 3 y 4. Los pulsadores siguen sin estar activos.
;
; Secuencia 3 — Parpadeo alternado:
;   LEDs pares (RB0,RB2,RB4) e impares (RB1,RB3) alternan.
;   XOR 0x1F sobre LATB invierte RB0-RB4 en una sola op.
;
; Secuencia 4 — Contador binario:
;   Los 5 LEDs cuentan de 0 a 31 (00000?11111).
;   ADDLW 1 + ANDLW 0x1F incrementa y limita a 5 bits.
;
; === TIMER0 (8 bits) ===
; T0CON = 0xC7: modo 8 bits, prescaler 1:256
; Preload = 6 ? (256-6) × 256µs = 64ms por tick
; VEL_NORMAL = 8 ticks ? 512ms por paso
;=========================================================

    #include <xc.inc>

    CONFIG  FOSC   = HS
    CONFIG  CPUDIV = OSC1_PLL2
    CONFIG  USBDIV = 1
    CONFIG  WDT    = OFF
    CONFIG  WDTPS  = 32768
    CONFIG  LVP    = OFF
    CONFIG  PBADEN = OFF
    CONFIG  MCLRE  = OFF
    CONFIG  STVREN = ON
    CONFIG  XINST  = OFF

    
    ; Constantes
    
    #define PIN_SEQ         0
    #define PIN_VEL         1

    #define T0_PRELOAD      6

    ;Se cambio la velocidad a 8 ticks × 64ms = 512ms. Anterior: VEL_NORMAL = 5
    #define VEL_NORMAL      8

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

    #define MASK_LEDS       0x1F
    #define MASK_PARES      0x15    ; RB0, RB2, RB4
    #define MASK_IMPARES    0x0A    ; RB1, RB3

    
    ; Vector de Reset
    
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

    ;
    ; Vectores de interrupción
    
    PSECT  highIntVec, class=CODE, reloc=2
    ORG     0x08
    GOTO    ISR_Timer0

    PSECT  lowIntVec, class=CODE, reloc=2
    ORG     0x18
    RETFIE

    
    ; ISR — sin cambios respecto a V 3.0
    
    PSECT  isr_code, class=CODE, reloc=2

ISR_Timer0:
    MOVFF   WREG, W_ISR
    MOVFF   STATUS, STATUS_ISR
    MOVFF   BSR, BSR_ISR

    BTFSS   INTCON, 2, A
    GOTO    ISR_Exit
    BCF     INTCON, 2, A

    MOVLW   T0_PRELOAD
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

    ; CAMBIO 1: T0CON en modo 8 bits (bit6=1). Anterior: 0x87 (16 bits)
    ; Se cambio solo el TMR0L. Anterior cargaba también TMR0H = 0xFE
    MOVLW   0xC7
    MOVWF   T0CON, A
    MOVLW   T0_PRELOAD
    MOVWF   TMR0L, A

    BSF     INTCON, 5, A
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

    ;=======================================================
    ; SECUENCIA 1: Ping-Pong — sin cambios respecto a V 3.0
    ;=======================================================
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
    CLRF    LATB, A
    GOTO    Loop

    ;=======================================================
    ; SECUENCIA 2: Llenado — sin cambios respecto a V 3.0
    ;=======================================================
Exec_Llenado:
    MOVF    PasoActual, W, A
    CALL    Tabla_Llenado
    MOVWF   LATB, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_LL
    BNZ     Loop
    CALL    Siguiente_Secuencia
    MOVLW   MASK_PARES              ; Alternado empieza con pares encendidos
    MOVWF   LATB, A
    GOTO    Loop

    ;=======================================================
    ; SECUENCIA 3: Parpadeo Alternado
    ; XOR 0x1F invierte RB0-RB4 en cada paso: pares?impares.
    ; Estado inicial (puesto por Exec_Llenado): MASK_PARES.
    ;=======================================================
Exec_Alternado:
    MOVF    LATB, W, A
    XORLW   MASK_LEDS               ; Invertir RB0-RB4
    ANDLW   MASK_LEDS
    MOVWF   LATB, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_ALT
    BNZ     Loop
    CALL    Siguiente_Secuencia
    CLRF    LATB, A                 ; Binario empieza en 0
    GOTO    Loop

    ;=======================================================
    ; SECUENCIA 4: Contador Binario
    ; ADDLW 1 + ANDLW 0x1F: al llegar a 32 la máscara
    ; devuelve 0x00, reiniciando el conteo automáticamente.
    ;=======================================================
Exec_Binario:
    MOVF    LATB, W, A
    ADDLW   1
    ANDLW   MASK_LEDS
    MOVWF   LATB, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_BIN
    BNZ     Loop
    CALL    Siguiente_Secuencia
    MOVLW   0x01                    ; Ping-pong reinicia en RB0
    MOVWF   LATB, A
    BCF     Flags, FLAG_DIR, A
    GOTO    Loop

    
    ; Subrutina: Siguiente_Secuencia — sin cambios
    
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
TickCount:          DS 1
VelocidadActual:    DS 1
Flags:              DS 1
SecuenciaActual:    DS 1
PasoActual:         DS 1
W_ISR:              DS 1
STATUS_ISR:         DS 1
BSR_ISR:            DS 1

    END