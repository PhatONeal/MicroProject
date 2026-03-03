;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 4.2 — LEDs movidos a RD0-RD4 (puerto D)
;
; Hardware:
;   LEDs               : RD0-RD4  (5 LEDs, salidas)
;   Pulsador secuencia : RB0/INT0 (entrada, pull-up externo a VDD)
;   Pulsador velocidad : RB1/INT1 (entrada, pull-up externo a VDD)
;
; Oscilador: 4 MHz (HS)
;
; Ventaja de RD vs RC:
;   RD0-RD7 son GPIO de propósito general en el PIC18F4550.
;   No comparten función con USB (RC3=SCL, RC4=D-),
;   por lo que NO se requiere deshabilitar UCON/UCFG.
;   Solo configurar TRISD = 0xE0 y operar LATD.
; -------------------------------------------------------
; TIMER0 — Cálculo de período
; -------------------------------------------------------
; Fosc=4MHz ? Tcy=1µs
; Timer0 modo 8-bit, prescaler 1:256
; Overflow cada (256-T0_PRELOAD)×256×1µs
; Con T0_PRELOAD=6: 250×256µs = 64 ms/tick
;   VEL_NORMAL =  8 ticks ? 512  ms/paso
;   VEL_RAPIDA =  4 ticks ? 256  ms/paso
;   VEL_LENTA  = 16 ticks ? 1024 ms/paso
;=========================================================

    #include <xc.inc>

    ;=======================================================
    ; Bits de configuración
    ;=======================================================
    CONFIG  FOSC   = HS
    CONFIG  CPUDIV = OSC1_PLL2
    CONFIG  USBDIV = 1
    CONFIG  WDT    = OFF
    CONFIG  WDTPS  = 32768
    CONFIG  LVP    = OFF
    CONFIG  PBADEN = OFF        ; RB0-RB4 digitales
    CONFIG  MCLRE  = OFF
    CONFIG  STVREN = ON
    CONFIG  XINST  = OFF

    ;=======================================================
    ; Constantes
    ;=======================================================
    #define T0_PRELOAD       6

    #define VEL_NORMAL       8
    #define VEL_RAPIDA       4
    #define VEL_LENTA        16

    #define DEBOUNCE_TICKS   3      ; 3 × 64 ms = 192 ms

    ; Bits de Flags
    #define FLAG_PASO        0
    #define FLAG_DIR         1      ; 0=hacia RD4, 1=hacia RD0
    #define FLAG_CAMBIO      2
    #define FLAG_VEL         3

    ; Secuencias
    #define TOTAL_SECUENCIAS 4
    #define TOTAL_PASOS_PP   8
    #define TOTAL_PASOS_LL   9
    #define TOTAL_PASOS_ALT  8
    #define TOTAL_PASOS_BIN  32

    ; Máscaras RD0-RD4
    #define MASK_LEDS        0x1F
    #define MASK_PARES       0x15
    #define MASK_IMPARES     0x0A

    ;=======================================================
    ; Vector de Reset
    ;=======================================================
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x0000
    GOTO    Inicio

    ;=======================================================
    ; Vector ISR Alta prioridad (0x0008)
    ;=======================================================
    PSECT  highIntVec, class=CODE, reloc=2
    ORG     0x0008
    GOTO    ISR_High

    ;=======================================================
    ; Vector ISR Baja prioridad (0x0018) — sin uso
    ;=======================================================
    PSECT  lowIntVec, class=CODE, reloc=2
    ORG     0x0018
    RETFIE

    ;=======================================================
    ; ISR Alta prioridad
    ; Guarda/restaura contexto manualmente.
    ; Atiende: Timer0, INT0 (RB0), INT1 (RB1)
    ;=======================================================
    PSECT  isrCode, class=CODE, reloc=2

ISR_High:
    MOVWF   W_ISR, A
    MOVFF   STATUS, STATUS_ISR
    MOVFF   BSR, BSR_ISR

    ; -- Timer0 ------------------------------------------
    BTFSS   INTCON, 2, A        ; T0IF?
    GOTO    ISR_INT0
    BCF     INTCON, 2, A        ; Limpiar T0IF
    MOVLW   T0_PRELOAD
    MOVWF   TMR0L, A

    ; Antirebote SEQ: decrementar si >0; al llegar a 0 ? flag
    MOVF    DebounceTimer_SEQ, F, A
    BZ      ISR_T0_Vel
    DECF    DebounceTimer_SEQ, F, A
    BNZ     ISR_T0_Vel
    BSF     Flags, FLAG_CAMBIO, A

ISR_T0_Vel:
    ; Antirebote VEL: ídem
    MOVF    DebounceTimer_VEL, F, A
    BZ      ISR_T0_Paso
    DECF    DebounceTimer_VEL, F, A
    BNZ     ISR_T0_Paso
    BSF     Flags, FLAG_VEL, A

ISR_T0_Paso:
    ; Tick de secuencia
    INCF    TickCount, F, A
    MOVF    VelocidadActual, W, A
    CPFSEQ  TickCount, A
    GOTO    ISR_INT0
    CLRF    TickCount, A
    BSF     Flags, FLAG_PASO, A

    ; -- INT0 (RB0) --------------------------------------
ISR_INT0:
    BTFSS   INTCON, 1, A        ; INT0IF?
    GOTO    ISR_INT1
    BCF     INTCON, 1, A        ; Limpiar INT0IF
    MOVF    DebounceTimer_SEQ, F, A
    BNZ     ISR_INT1            ; Debounce activo ? ignorar rebote
    MOVLW   DEBOUNCE_TICKS
    MOVWF   DebounceTimer_SEQ, A

    ; -- INT1 (RB1) --------------------------------------
ISR_INT1:
    BTFSS   INTCON3, 0, A       ; INT1IF? (INTCON3<0>)
    GOTO    ISR_Exit
    BCF     INTCON3, 0, A       ; Limpiar INT1IF
    MOVF    DebounceTimer_VEL, F, A
    BNZ     ISR_Exit
    MOVLW   DEBOUNCE_TICKS
    MOVWF   DebounceTimer_VEL, A

ISR_Exit:
    MOVFF   BSR_ISR, BSR
    MOVFF   STATUS_ISR, STATUS
    MOVF    W_ISR, W, A
    RETFIE                      ; Sin fast-return

    ;=======================================================
    ; Código Principal
    ;=======================================================
    PSECT  mainCode, class=CODE, reloc=2

Inicio:
    ; -- Pines analógicos ? digitales -------------------
    ; Puerto D no tiene conflicto con USB ni analógicos,
    ; pero ADCON1 se deja en 0x0F por buena práctica.
    MOVLW   0x0F
    MOVWF   ADCON1, A           ; AN0-AN12 todos digitales

    ; -- Puerto D: RD0-RD4 salidas (LEDs) ---------------
    ; TRISD = 1110 0000  (RD0-RD4 salidas, RD5-RD7 entradas)
    MOVLW   0xE0
    MOVWF   TRISD, A
    CLRF    LATD, A

    ; -- Puerto B: entradas (RB0=INT0, RB1=INT1) --------
    MOVLW   0xFF
    MOVWF   TRISB, A

    ; -- Variables ---------------------------------------
    CLRF    TickCount, A
    CLRF    Flags, A
    CLRF    PasoActual, A
    CLRF    SecuenciaActual, A
    CLRF    DebounceTimer_SEQ, A
    CLRF    DebounceTimer_VEL, A
    CLRF    IndiceVelocidad, A
    MOVLW   VEL_NORMAL
    MOVWF   VelocidadActual, A

    ; Estado inicial: RD0 encendido, dirección hacia RD4
    MOVLW   0x01
    MOVWF   LATD, A
    BCF     Flags, FLAG_DIR, A

    ; -- Timer0: 8-bit, reloj interno, prescaler 1:256 --
    ; T0CON = 1100 0111
    MOVLW   0xC7
    MOVWF   T0CON, A
    MOVLW   T0_PRELOAD
    MOVWF   TMR0L, A

    ; -- INT0/INT1 por flanco de bajada ------------------
    ; INTCON2<6>=INTEDG0=0, INTCON2<5>=INTEDG1=0
    BCF     INTCON2, 6, A
    BCF     INTCON2, 5, A

    ; -- INT1 ? alta prioridad (mismo vector que INT0) --
    ; INTCON3<6>=INT1IP=1
    BSF     INTCON3, 6, A
    BCF     INTCON3, 0, A       ; Limpiar INT1IF
    BSF     INTCON3, 3, A       ; INT1IE=1

    ; -- Habilitar interrupciones ------------------------
    BCF     INTCON, 2, A        ; Limpiar T0IF
    BCF     INTCON, 1, A        ; Limpiar INT0IF
    BSF     RCON,   7, A        ; IPEN=1 (modo con prioridades)
    BSF     INTCON, 5, A        ; T0IE=1
    BSF     INTCON, 4, A        ; INT0IE=1
    BSF     INTCON, 7, A        ; GIEH=1

    ;=======================================================
    ; Loop principal
    ; Prioridad: FLAG_CAMBIO > FLAG_VEL > FLAG_PASO
    ;=======================================================
Loop:
    BTFSS   Flags, FLAG_CAMBIO, A
    GOTO    Check_Vel
    BCF     Flags, FLAG_CAMBIO, A
    CALL    Siguiente_Secuencia
    CALL    Reiniciar_Secuencia
    GOTO    Loop

Check_Vel:
    BTFSS   Flags, FLAG_VEL, A
    GOTO    Check_Paso
    BCF     Flags, FLAG_VEL, A
    CALL    Cambiar_Velocidad
    GOTO    Loop

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

    ;=======================================================
    ; SEQ 0: Ping-Pong  RD0?RD4
    ; FLAG_DIR=0 ? hacia RD4 (shift izq)
    ; FLAG_DIR=1 ? hacia RD0 (shift der)
    ;=======================================================
Exec_PingPong:
    BTFSS   Flags, FLAG_DIR, A
    GOTO    PP_HaciaRD4

PP_HaciaRD0:
    RRCF    LATD, W, A          ; Shift derecha ? W (no toca Carry de LATD)
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    XORLW   0x01                ; ¿Llegó a RD0?
    BNZ     PP_FinPaso
    BCF     Flags, FLAG_DIR, A  ; Invertir dirección
    GOTO    PP_FinPaso

PP_HaciaRD4:
    RLCF    LATD, W, A          ; Shift izquierda ? W
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    XORLW   0x10                ; ¿Llegó a RD4?
    BNZ     PP_FinPaso
    BSF     Flags, FLAG_DIR, A  ; Invertir dirección

PP_FinPaso:
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_PP
    BNZ     Loop
    CALL    Siguiente_Secuencia
    CLRF    LATD, A
    GOTO    Loop

    ;=======================================================
    ; SEQ 1: Llenado / Vaciado
    ;=======================================================
Exec_Llenado:
    MOVF    PasoActual, W, A
    CALL    Tabla_Llenado
    MOVWF   LATD, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_LL
    BNZ     Loop
    CALL    Siguiente_Secuencia
    MOVLW   MASK_PARES
    MOVWF   LATD, A
    GOTO    Loop

    ;=======================================================
    ; SEQ 2: Parpadeo Alternado
    ;=======================================================
Exec_Alternado:
    MOVF    LATD, W, A
    XORLW   MASK_LEDS
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_ALT
    BNZ     Loop
    CALL    Siguiente_Secuencia
    CLRF    LATD, A
    GOTO    Loop

    ;=======================================================
    ; SEQ 3: Contador Binario 0-31
    ;=======================================================
Exec_Binario:
    MOVF    LATD, W, A
    INCF    WREG, W
    ANDLW   MASK_LEDS
    MOVWF   LATD, A
    INCF    PasoActual, F, A
    MOVF    PasoActual, W, A
    XORLW   TOTAL_PASOS_BIN
    BNZ     Loop
    CALL    Siguiente_Secuencia
    MOVLW   0x01
    MOVWF   LATD, A
    BCF     Flags, FLAG_DIR, A
    GOTO    Loop

    ;=======================================================
    ; Siguiente_Secuencia: avanza con wrap y resetea paso
    ;=======================================================
Siguiente_Secuencia:
    CLRF    PasoActual, A
    INCF    SecuenciaActual, F, A
    MOVF    SecuenciaActual, W, A
    XORLW   TOTAL_SECUENCIAS
    BNZ     SigSec_Fin
    CLRF    SecuenciaActual, A
SigSec_Fin:
    RETURN

    ;=======================================================
    ; Reiniciar_Secuencia: estado inicial de LEDs
    ;=======================================================
Reiniciar_Secuencia:
    CLRF    LATD, A
    MOVF    SecuenciaActual, W, A
    BZ      Reinic_PP
    DECF    WREG, W
    BZ      Reinic_LL
    DECF    WREG, W
    BZ      Reinic_Alt
    RETURN                      ; Binario: LATD=0

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

    ;=======================================================
    ; Cambiar_Velocidad: cicla Normal?Rápida?Lenta?Normal
    ;=======================================================
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

    ;=======================================================
    ; Tabla_Velocidades (PCL jump table — dentro de página 0)
    ;=======================================================
Tabla_Velocidades:
    ANDLW   0x03
    ADDWF   PCL, F, A
    RETLW   VEL_NORMAL          ; índice 0 ? 512  ms
    RETLW   VEL_RAPIDA          ; índice 1 ? 256  ms
    RETLW   VEL_LENTA           ; índice 2 ? 1024 ms

    ;=======================================================
    ; Tabla_Llenado (PCL jump table)
    ;=======================================================
Tabla_Llenado:
    ANDLW   0x0F
    ADDWF   PCL, F, A
    RETLW   0x01                ; Paso 0: RD0
    RETLW   0x03                ; Paso 1: RD0-RD1
    RETLW   0x07                ; Paso 2: RD0-RD2
    RETLW   0x0F                ; Paso 3: RD0-RD3
    RETLW   0x1F                ; Paso 4: RD0-RD4 (lleno)
    RETLW   0x0F                ; Paso 5: RD0-RD3
    RETLW   0x07                ; Paso 6: RD0-RD2
    RETLW   0x03                ; Paso 7: RD0-RD1
    RETLW   0x01                ; Paso 8: RD0

    ;=======================================================
    ; Variables en RAM — banco de acceso (0x000-0x05F)
    ; PSECT sin class= para que pic-as lo asigne
    ; correctamente al access bank sin error 873.
    ;=======================================================
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