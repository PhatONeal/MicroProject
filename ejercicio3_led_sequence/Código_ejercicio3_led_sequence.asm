; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 5.0 (parcialmente la final)
;
; Hardware:
;   LEDs     : RB0-RB4 (5 LEDs, salidas)
;   Pulsador secuencia : RA0 (entrada, pull-up externo)
;   Pulsador velocidad : RA1 (entrada, pull-up externo)
;
; Frecuencia: 4 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 2.20
;
; Secuencias disponibles:
;   0 – Ping-Pong       : un LED rebota entre RD0 y RD4
;   1 – Llenado/Vaciado : los LEDs se encienden y apagan en cascada
;   2 – Alternado       : LEDs pares e impares parpadean en contrafase
;   3 – Contador Binario: cuenta en binario de 0 a 31
;
; Velocidades:
;   Normal  ?  512 ms/paso  (índice 0, arranque por defecto)
;   Rápida  ?  256 ms/paso  (índice 1)
;   Lenta   ? 1024 ms/paso  (índice 2)
;
; Timer0:
;   Modo 8-bit, reloj interno, prescaler 1:256
;   Fosc = 4 MHz ? Tcy = 1 µs
;   Overflow cada (256 - T0_PRELOAD) × 256 µs
;   Con T0_PRELOAD = 6  ?  250 × 256 µs = 64 ms por tick
;
; Estado:
;   Funcional en simulación (MPLAB / Proteus).
;   NO funcional en hardware físico — pendiente de revisión futura.
;
; Historial de versiones:
;   v9.0  – Secuencia avanzaba automáticamente al terminar cada ciclo.
;           RB0 (INT0) avanzaba la secuencia en lugar de pausar.
;   v10.0 – Corrección del comportamiento de avance automático:
;           · FLAG_CAMBIO reemplaza a FLAG_PAUSA.
;           · Timer0 ya no dispara cambios de secuencia.
;           · Cada bloque Exec_* reinicia PasoActual al completar el ciclo
;             (la misma secuencia se repite indefinidamente).
;           · RB0 ahora avanza la secuencia de forma manual.
;   v10.1 – Limpieza general de código y comentarios.
;=============================================================================

    #include <xc.inc>

;=============================================================================
; Bits de configuración
;=============================================================================
    CONFIG  FOSC   = HS
    CONFIG  CPUDIV = OSC1_PLL2
    CONFIG  USBDIV = 1
    CONFIG  WDT    = OFF
    CONFIG  WDTPS  = 32768
    CONFIG  LVP    = OFF
    CONFIG  PBADEN = OFF        ; RB0–RB4 como pines digitales
    CONFIG  MCLRE  = OFF
    CONFIG  STVREN = ON
    CONFIG  XINST  = OFF

;=============================================================================
; Constantes generales
;=============================================================================

    ; Timer0
    #define T0_PRELOAD       6      ; Preload para 64 ms/tick

    ; Velocidades (en ticks de 64 ms)
    #define VEL_NORMAL       8      ;  512 ms/paso
    #define VEL_RAPIDA       4      ;  256 ms/paso
    #define VEL_LENTA        16     ; 1024 ms/paso

    ; Antirebote
    #define DEBOUNCE_TICKS   3      ; 3 × 64 ms = 192 ms de antirebote

    ; Bits del registro Flags
    #define FLAG_PASO        0      ; 1 = ejecutar siguiente paso
    #define FLAG_DIR         1      ; 0 = hacia RD4  |  1 = hacia RD0
    #define FLAG_CAMBIO      2      ; 1 = RB0 presionado ? avanzar secuencia
    #define FLAG_VEL         3      ; 1 = RB1 presionado ? cambiar velocidad

    ; Secuencias
    #define TOTAL_SECUENCIAS 4
    #define TOTAL_PASOS_PP   8      ; Ping-Pong
    #define TOTAL_PASOS_LL   9      ; Llenado / Vaciado
    #define TOTAL_PASOS_ALT  8      ; Alternado
    #define TOTAL_PASOS_BIN  32     ; Contador binario (0–31)

    ; Máscaras de puerto D
    #define MASK_LEDS        0x1F   ; RD0–RD4
    #define MASK_PARES       0x15   ; RD0, RD2, RD4  (b10101)
    #define MASK_IMPARES     0x0A   ; RD1, RD3        (b01010)

;=============================================================================
; Vectores de interrupción y reset
;=============================================================================

    PSECT  resetVec, class=CODE, reloc=2
    ORG 0x0000
    GOTO    Inicio

    PSECT  highIntVec, class=CODE, reloc=2
    ORG 0x0008
    GOTO    ISR_High

    PSECT  lowIntVec, class=CODE, reloc=2
    ORG 0x0018
    RETFIE                          ; Interrupciones de baja prioridad no usadas

;=============================================================================
; ISR – Alta prioridad
;
; Fuentes atendidas:
;   · Timer0 (T0IF)  ? antirebote SEQ/VEL  +  tick de secuencia
;   · INT0   (RB0)   ? solicitud de avance de secuencia
;   · INT1   (RB1)   ? solicitud de cambio de velocidad
;
; El contexto (W, STATUS, BSR) se guarda y restaura manualmente.
;=============================================================================

    PSECT  isrCode, class=CODE, reloc=2

ISR_High:
    ; -- Guardar contexto -----------------------------------------------------
    MOVWF   W_ISR,      A
    MOVFF   STATUS,     STATUS_ISR
    MOVFF   BSR,        BSR_ISR

    ; -- Timer0 ---------------------------------------------------------------
    BTFSS   INTCON, 2,  A           ; ¿T0IF activo?
    GOTO    ISR_INT0
    BCF     INTCON, 2,  A           ; Limpiar T0IF
    MOVLW   T0_PRELOAD
    MOVWF   TMR0L,      A           ; Recargar Timer0

    ; Antirebote SEQ: decrementar contador; al llegar a 0 habilitar FLAG_CAMBIO
    MOVF    DebounceTimer_SEQ, F, A
    BZ      ISR_T0_Vel
    DECF    DebounceTimer_SEQ, F, A
    BNZ     ISR_T0_Vel
    BSF     Flags, FLAG_CAMBIO, A

ISR_T0_Vel:
    ; Antirebote VEL: decrementar contador; al llegar a 0 habilitar FLAG_VEL
    MOVF    DebounceTimer_VEL, F, A
    BZ      ISR_T0_Paso
    DECF    DebounceTimer_VEL, F, A
    BNZ     ISR_T0_Paso
    BSF     Flags, FLAG_VEL, A

ISR_T0_Paso:
    ; Tick de secuencia: incrementar TickCount; al alcanzar VelocidadActual
    ; se genera FLAG_PASO para que el loop principal ejecute el siguiente paso
    INCF    TickCount, F, A
    MOVF    VelocidadActual, W, A
    CPFSEQ  TickCount, A
    GOTO    ISR_INT0
    CLRF    TickCount, A
    BSF     Flags, FLAG_PASO, A

    ; -- INT0 (RB0) – Avanzar secuencia ---------------------------------------
ISR_INT0:
    BTFSS   INTCON, 1,  A           ; ¿INT0IF activo?
    GOTO    ISR_INT1
    BCF     INTCON, 1,  A           ; Limpiar INT0IF
    MOVF    DebounceTimer_SEQ, F, A
    BNZ     ISR_INT1                ; Rebote activo ? ignorar
    MOVLW   DEBOUNCE_TICKS
    MOVWF   DebounceTimer_SEQ, A

    ; -- INT1 (RB1) – Cambiar velocidad ---------------------------------------
ISR_INT1:
    BTFSS   INTCON3, 0, A           ; ¿INT1IF activo? (INTCON3<0>)
    GOTO    ISR_Exit
    BCF     INTCON3, 0, A           ; Limpiar INT1IF
    MOVF    DebounceTimer_VEL, F, A
    BNZ     ISR_Exit                ; Rebote activo ? ignorar
    MOVLW   DEBOUNCE_TICKS
    MOVWF   DebounceTimer_VEL, A

    ; -- Restaurar contexto ---------------------------------------------------
ISR_Exit:
    MOVFF   BSR_ISR,    BSR
    MOVFF   STATUS_ISR, STATUS
    MOVF    W_ISR, W,   A
    RETFIE

;=============================================================================
; Inicio – Configuración del hardware y variables
;=============================================================================

    PSECT  mainCode, class=CODE, reloc=2

Inicio:
    ; -- Pines analógicos ? digitales -----------------------------------------
    MOVLW   0x0F
    MOVWF   ADCON1, A

    ; -- Puerto D: RD0–RD4 como salidas (LEDs) --------------------------------
    MOVLW   0xE0
    MOVWF   TRISD, A
    CLRF    LATD,  A

    ; -- Puerto B: todas las líneas como entradas (RB0=INT0, RB1=INT1) --------
    MOVLW   0xFF
    MOVWF   TRISB, A

    ; -- Inicializar variables -------------------------------------------------
    CLRF    TickCount,          A
    CLRF    Flags,              A
    CLRF    PasoActual,         A
    CLRF    SecuenciaActual,    A
    CLRF    DebounceTimer_SEQ,  A
    CLRF    DebounceTimer_VEL,  A
    CLRF    IndiceVelocidad,    A
    MOVLW   VEL_NORMAL
    MOVWF   VelocidadActual,    A

    ; -- Estado inicial: RD0 encendido, dirección hacia RD4 -------------------
    MOVLW   0x01
    MOVWF   LATD, A
    BCF     Flags, FLAG_DIR, A

    ; -- Timer0: modo 8-bit, reloj interno, prescaler 1:256 -------------------
    MOVLW   0xC7
    MOVWF   T0CON, A
    MOVLW   T0_PRELOAD
    MOVWF   TMR0L, A

    ; -- INT0 / INT1: flanco de bajada -----------------------------------------
    BCF     INTCON2, 6, A
    BCF     INTCON2, 5, A

    ; -- INT1 ? alta prioridad -------------------------------------------------
    BSF     INTCON3, 6, A
    BCF     INTCON3, 0, A
    BSF     INTCON3, 3, A

    ; -- Habilitar interrupciones ----------------------------------------------
    BCF     INTCON, 2,  A           ; Limpiar T0IF
    BCF     INTCON, 1,  A           ; Limpiar INT0IF
    BSF     RCON,   7,  A           ; IPEN: prioridades habilitadas
    BSF     INTCON, 5,  A           ; TMR0IE
    BSF     INTCON, 4,  A           ; INT0IE
    BSF     INTCON, 7,  A           ; GIE

;=============================================================================
; Loop principal
;
; Prioridad de atención de flags:
;   1. FLAG_CAMBIO ? avanzar a la siguiente secuencia
;   2. FLAG_VEL    ? ciclar la velocidad de ejecución
;   3. FLAG_PASO   ? ejecutar el siguiente paso de la secuencia activa
;=============================================================================

Loop:
    ; -- Avanzar secuencia ----------------------------------------------------
    BTFSS   Flags, FLAG_CAMBIO, A
    GOTO    Check_Vel
    BCF     Flags, FLAG_CAMBIO, A
    CALL    Avanzar_Secuencia
    GOTO    Loop

    ; -- Cambiar velocidad ----------------------------------------------------
Check_Vel:
    BTFSS   Flags, FLAG_VEL, A
    GOTO    Check_Paso
    BCF     Flags, FLAG_VEL, A
    CALL    Cambiar_Velocidad
    GOTO    Loop

    ; -- Ejecutar siguiente paso -----------------------------------------------
Check_Paso:
    BTFSS   Flags, FLAG_PASO, A
    GOTO    Loop
    BCF     Flags, FLAG_PASO, A

    MOVF    SecuenciaActual, W, A
    BZ      Exec_PingPong
    DECF    WREG, W
    BZ      Exec_Llenado
    DECF    WREG, W
    BZ      Exec_Alternado
    GOTO    Exec_Binario


; SEQ 0 – Ping-Pong  (RD0 ? RD4)


Exec_PingPong:
    BTFSS   Flags, FLAG_DIR, A
    GOTO    PP_HaciaRD4

PP_HaciaRD0:
    RRCF    LATD, W, A
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    XORLW   0x01                    ; ¿llegó a RD0?
    BNZ     PP_FinPaso
    BCF     Flags, FLAG_DIR, A      ; Cambiar dirección ? hacia RD4
    GOTO    PP_FinPaso

PP_HaciaRD4:
    RLCF    LATD, W, A
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    XORLW   0x10                    ; ¿llegó a RD4?
    BNZ     PP_FinPaso
    BSF     Flags, FLAG_DIR, A      ; Cambiar dirección ? hacia RD0

PP_FinPaso:
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_PP
    BNZ     Loop
    CLRF    PasoActual, A           ; Reiniciar ciclo (misma secuencia)
    MOVLW   0x01
    MOVWF   LATD, A
    BCF     Flags, FLAG_DIR, A
    GOTO    Loop

; SEQ 1 – Llenado / Vaciado

Exec_Llenado:
    MOVF    PasoActual, W, A
    CALL    Tabla_Llenado
    MOVWF   LATD, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_LL
    BNZ     Loop
    CLRF    PasoActual, A           ; Reiniciar ciclo (misma secuencia)
    GOTO    Loop


; SEQ 2 – Parpadeo Alternado


Exec_Alternado:
    MOVF    LATD, W, A
    XORLW   MASK_LEDS               ; Toggle de todos los LEDs
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_ALT
    BNZ     Loop
    CLRF    PasoActual, A           ; Reiniciar ciclo (misma secuencia)
    MOVLW   MASK_PARES
    MOVWF   LATD, A
    GOTO    Loop


; SEQ 3 – Contador Binario (0–31)

Exec_Binario:
    MOVF    LATD, W, A
    INCF    WREG, W
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_BIN
    BNZ     Loop
    CLRF    PasoActual, A           ; Reiniciar ciclo (misma secuencia)
    MOVLW   0x01
    MOVWF   LATD, A
    GOTO    Loop


; Avanzar_Secuencia


Avanzar_Secuencia:
    INCF    SecuenciaActual, F, A
    MOVF    SecuenciaActual, W, A
    XORLW   TOTAL_SECUENCIAS
    BNZ     AvSec_Reinic
    CLRF    SecuenciaActual, A

AvSec_Reinic:
    ; Caída intencional hacia Reiniciar_Secuencia (comparte su RETURN)


; Reiniciar_Secuencia


Reiniciar_Secuencia:
    CLRF    LATD,       A
    CLRF    PasoActual, A
    MOVF    SecuenciaActual, W, A
    BZ      Reinic_PP
    DECF    WREG, W
    BZ      Reinic_LL
    DECF    WREG, W
    BZ      Reinic_Alt
    RETURN                          ; Binario: LATD = 0, nada más que hacer

Reinic_PP:
    MOVLW   0x01
    MOVWF   LATD, A
    BCF     Flags, FLAG_DIR, A
    RETURN

Reinic_LL:
    CLRF    LATD, A
    RETURN

Reinic_Alt:
    MOVLW   MASK_PARES
    MOVWF   LATD, A
    RETURN

;=============================================================================
; Cambiar_Velocidad
;
; Cicla entre los tres niveles de velocidad: Normal ? Rápida ? Lenta ? Normal.
; Reinicia TickCount para que el nuevo período surta efecto de inmediato.
;=============================================================================

Cambiar_Velocidad:
    INCF    IndiceVelocidad, F, A
    MOVF    IndiceVelocidad, W, A
    XORLW   3
    BNZ     CambiarVel_Ok
    CLRF    IndiceVelocidad, A

CambiarVel_Ok:
    MOVF    IndiceVelocidad, W, A
    CALL    Tabla_Velocidades
    MOVWF   VelocidadActual, A
    CLRF    TickCount, A
    RETURN

;=============================================================================
; Tabla_Velocidades  (jump table vía PCL – debe permanecer en la página 0)
;
; Índice 0 ? VEL_NORMAL  ( 512 ms/paso)
; Índice 1 ? VEL_RAPIDA  ( 256 ms/paso)
; Índice 2 ? VEL_LENTA   (1024 ms/paso)
;=============================================================================

Tabla_Velocidades:
    ANDLW   0x03
    ADDWF   PCL, F, A
    RETLW   VEL_NORMAL
    RETLW   VEL_RAPIDA
    RETLW   VEL_LENTA


Tabla_Llenado:
    ANDLW   0x0F
    ADDWF   PCL, F, A
    RETLW   0x01                    ; Paso 0: RD0           
    RETLW   0x03                    ; Paso 1: RD0–RD1       
    RETLW   0x07                    ; Paso 2: RD0–RD2       
    RETLW   0x0F                    ; Paso 3: RD0–RD3       
    RETLW   0x1F                    ; Paso 4: RD0–RD4       
    RETLW   0x0F                    ; Paso 5: RD0–RD3       
    RETLW   0x07                    ; Paso 6: RD0–RD2       
    RETLW   0x03                    ; Paso 7: RD0–RD1       
    RETLW   0x01                    ; Paso 8: RD0           


; Variables en RAM 


    PSECT   udata_acs

TickCount:          DS 1    
VelocidadActual:    DS 1    
IndiceVelocidad:    DS 1    
Flags:              DS 1    
SecuenciaActual:    DS 1    
PasoActual:         DS 1    
DebounceTimer_SEQ:  DS 1    
DebounceTimer_VEL:  DS 1    
W_ISR:              DS 1    
STATUS_ISR:         DS 1    
BSR_ISR:            DS 1    

    END