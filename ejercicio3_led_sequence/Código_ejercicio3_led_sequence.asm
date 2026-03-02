;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 3.0
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
; V 2.0 tenía Timer0 funcionando pero el loop solo
; alternaba todos los LEDs. Se agregan las primeras
; dos secuencias usando la infraestructura de ticks
; ya disponible. Los pulsadores aún no están activos:
; las secuencias cambian automáticamente al completar
; cada ciclo para poder verificarlas visualmente.
;
; Secuencia 1 — Ping-pong:
;   Un LED se desplaza RB0?RB4?RB0 usando RLNCF/RRNCF.
;   FLAG_DIR controla la dirección actual.
;
; Secuencia 2 — Llenado y vaciado:
;   LEDs encendidos uno a uno y apagados uno a uno.
;   Se implementa con tabla RETLW indexada por PasoActual.
;
; === TIMER0 ===
; Sin cambios respecto a V 2.0.
; Tick cada 100 ms. VelocidadActual = 5 ? paso cada 500 ms.
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
    
    #define PIN_SEQ         0    ; RA0: pulsador de secuencia
    #define PIN_VEL         1    ; RA1: pulsador de velocidad

    #define T0_HIGH         0xFE ; Preload Timer0 ? tick cada 100 ms
    #define T0_LOW          0x79

    #define VEL_NORMAL      5    ; 5 ticks × 100 ms = 500 ms por paso

    #define FLAG_PASO       0    ; Bit 0: ISR avisa que hay que avanzar
    #define FLAG_DIR        1    ; Bit 1: dirección ping-pong (0=derecha, 1=izquierda)

    #define SEQ_PINGPONG    0
    #define SEQ_LLENADO     1
    #define TOTAL_PASOS_PP  8    ; 4 ida + 4 vuelta
    #define TOTAL_PASOS_LL  9    ; 5 encendidos + 4 apagados

    
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

    ;=======================================================
    ; ISR — Sin cambios respecto a V 2.0
    ; Recarga timer, incrementa TickCount, activa FLAG_PASO
    ;=======================================================
    PSECT  isr_code, class=CODE, reloc=2

ISR_Timer0:
    MOVFF   WREG, W_ISR
    MOVFF   STATUS, STATUS_ISR
    MOVFF   BSR, BSR_ISR

    BTFSS   INTCON, 2, A         ; TMR0IF=1?
    GOTO    ISR_Exit
    BCF     INTCON, 2, A         ; Limpiar TMR0IF

    MOVLW   T0_HIGH
    MOVWF   TMR0H, A             ; Recargar preload
    MOVLW   T0_LOW
    MOVWF   TMR0L, A             ; TMR0H se aplica al escribir TMR0L

    INCF    TickCount, F, A
    MOVF    VelocidadActual, W, A
    CPFSEQ  TickCount, A         ; ¿TickCount == VelocidadActual?
    GOTO    ISR_Exit

    CLRF    TickCount, A
    BSF     Flags, FLAG_PASO, A

ISR_Exit:
    MOVFF   BSR_ISR, BSR
    MOVFF   STATUS_ISR, STATUS
    MOVFF   W_ISR, WREG
    RETFIE  1                    ; 1=FAST: restaura contexto del shadow register

   
    ; Código Principal
    
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0x60
    MOVWF   OSCCON, A            ; IRCF=110 ? 4 MHz

    MOVLW   0xE0                 ; 1110 0000: RB0-RB4 salidas
    MOVWF   TRISB, A
    CLRF    LATB, A

    MOVLW   0xFF
    MOVWF   TRISA, A             ; Todo PORTA como entrada

    CLRF    TickCount, A
    CLRF    Flags, A
    CLRF    PasoActual, A
    CLRF    SecuenciaActual, A
    MOVLW   VEL_NORMAL
    MOVWF   VelocidadActual, A

    MOVLW   0x01                 ; Ping-pong empieza en RB0
    MOVWF   LATB, A
    BCF     Flags, FLAG_DIR, A   ; Dirección inicial: derecha (RB0?RB4)

    MOVLW   0x87                 ; T0CON: TMR0ON, 16bit, Fosc/4, prescaler 1:256
    MOVWF   T0CON, A
    MOVLW   T0_HIGH
    MOVWF   TMR0H, A
    MOVLW   T0_LOW
    MOVWF   TMR0L, A

    BSF     INTCON, 2, A         ; TMR0IE
    BSF     INTCON, 6, A         ; PEIE
    BSF     INTCON, 7, A         ; GIE

    
    ; Loop principal
    
Loop:
    BTFSS   Flags, FLAG_PASO, A
    GOTO    Loop
    BCF     Flags, FLAG_PASO, A

    MOVF    SecuenciaActual, W, A
    BZ      Exec_PingPong        ; 0 ? ping-pong
    DECF    WREG, W
    BZ      Exec_Llenado         ; 1 ? llenado
    GOTO    Loop

    ;=======================================================
    ; SECUENCIA 1: Ping-Pong
    ; RLNCF/RRNCF rotan el bit del LED activo.
    ; XORLW detecta si llegamos al extremo para invertir FLAG_DIR.
    ;=======================================================
Exec_PingPong:
    INCF    PasoActual, F, A

    BTFSS   Flags, FLAG_DIR, A   ; FLAG_DIR=1 ? ir hacia izquierda
    GOTO    PP_Derecha

PP_Izquierda:
    RRNCF   LATB, F, A           ; Rotar derecha: RB4?RB3?...?RB0
    MOVF    LATB, W, A
    ANDLW   0x1F
    MOVWF   LATB, A
    MOVF    LATB, W, A
    XORLW   0x01                 ; 
    BNZ     PP_FinPaso
    BCF     Flags, FLAG_DIR, A   ; Sí: cambiar dirección
    GOTO    PP_FinPaso

PP_Derecha:
    RLNCF   LATB, F, A           ; Rotar izquierda: RB0?RB1?...?RB4
    MOVF    LATB, W, A
    ANDLW   0x1F
    MOVWF   LATB, A
    MOVF    LATB, W, A
    XORLW   0x10                 ; 
    BNZ     PP_FinPaso
    BSF     Flags, FLAG_DIR, A   ; Sí: cambiar dirección

PP_FinPaso:
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_PP
    BNZ     Loop

    CLRF    PasoActual, A
    MOVLW   SEQ_LLENADO
    MOVWF   SecuenciaActual, A
    CLRF    LATB, A
    GOTO    Loop

    ;=======================================================
    ; SECUENCIA 2: Llenado y Vaciado
    ; PasoActual es el índice en Tabla_Llenado.
    ; ADDWF PCL,F desplaza el PC al RETLW correspondiente.
    ;=======================================================
Exec_Llenado:
    MOVF    PasoActual, W, A
    CALL    Tabla_Llenado
    MOVWF   LATB, A

    INCF    PasoActual, F, A

    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_LL
    BNZ     Loop

    CLRF    PasoActual, A
    MOVLW   SEQ_PINGPONG
    MOVWF   SecuenciaActual, A
    MOVLW   0x01
    MOVWF   LATB, A
    BCF     Flags, FLAG_DIR, A
    GOTO    Loop

    ;=======================================================
    ; Tabla de patrones — Secuencia 2
    ; ADDWF PCL,F suma el índice al PC ? ejecuta el RETLW correcto
    ;=======================================================
Tabla_Llenado:
    ANDLW   0x0F                 ; Limitar índice por seguridad
    ADDWF   PCL, F, A            ; Saltar al RETLW del índice
    RETLW   0x01                 ; Paso 0: RB0
    RETLW   0x03                 ; Paso 1: RB0-RB1
    RETLW   0x07                 ; Paso 2: RB0-RB2
    RETLW   0x0F                 ; Paso 3: RB0-RB3
    RETLW   0x1F                 ; Paso 4: todos
    RETLW   0x0F                 ; Paso 5: apagar RB4
    RETLW   0x07                 ; Paso 6: apagar RB3
    RETLW   0x03                 ; Paso 7: apagar RB2
    RETLW   0x01                 ; Paso 8: apagar RB1

    
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