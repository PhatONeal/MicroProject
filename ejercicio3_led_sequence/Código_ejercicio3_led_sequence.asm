;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 2.0
;
; Hardware:
;   LEDs               : RB0-RB4 (5 LEDs, salidas)
;   Pulsador secuencia : RA0 (entrada, pull-up externo)
;   Pulsador velocidad : RA1 (entrada, pull-up externo)
;
; Frecuencia: 4 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;
; Comentario de version:
; V 1.0 usaba retardo por software: la CPU quedaba
; bloqueada contando ciclos y no podía leer pulsadores
; ni reaccionar a eventos externos durante ese tiempo.
; Se reemplaza por Timer0 con interrupción para que
; el tiempo corra en hardware y la CPU quede libre.
; El comportamiento visual es identico a V 1.0.
;
; === CÁLCULO DE TIMER0 ===
; Configuración: 16 bits, prescaler 1:256, 4 MHz
;   T_ciclo     = 1.0 µs
;   T_por_cuenta = 1.0 µs × 256 = 256 µs
;   Cuentas para 100 ms = 100,000 / 256 = 391
;   Preload = 65,536 - 391 = 65,145 = 0xFE79
;
; Velocidades (ticks de 100 ms por paso):
;   Rápida : 2 ticks = 200 ms
;   Normal : 5 ticks = 500 ms
;   Lenta  : 10 ticks = 1 s
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
    
    #define PIN_SEQ      0       ; RA0: pulsador de secuencia
    #define PIN_VEL      1       ; RA1: pulsador de velocidad

    #define T0_HIGH      0xFE   ; Preload Timer0 (byte alto) ? tick cada 100 ms
    #define T0_LOW       0x79   ; Preload Timer0 (byte bajo)

    #define VEL_RAPIDA   2
    #define VEL_NORMAL   5
    #define VEL_LENTA    10

    #define LED_TODOS    0x1F   ; RB0-RB4 encendidos

    #define FLAG_PASO    0      ; Bit 0 de Flags: ISR avisa al loop que avance

    
    ; Vector de Reset
    
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

    ;=======================================================
    ; Vectores de interrupción
    ; Alta prioridad apunta a la ISR real (antes era RETFIE)
    ;=======================================================
    PSECT  highIntVec, class=CODE, reloc=2
    ORG     0x08
    GOTO    ISR_Timer0

    PSECT  lowIntVec, class=CODE, reloc=2
    ORG     0x18
    RETFIE

    ;=======================================================
    ; ISR — Rutina de Servicio de Interrupción de Timer0
    ; Se ejecuta cada 100 ms cuando Timer0 desborda.
    ; Se desarrolla buscando:
    ;   1. Preservar contexto (W, STATUS, BSR)
    ;   2. Verificar y limpiar flag TMR0IF
    ;   3. Recargar Timer0 con el preload
    ;   4. Incrementar TickCount y activar FLAG_PASO
    ;      cuando llega a VelocidadActual
    ;=======================================================
    PSECT  isr_code, class=CODE, reloc=2

ISR_Timer0:
    MOVFF   WREG, W_ISR          ; Preservar contexto: la ISR puede
    MOVFF   STATUS, STATUS_ISR   ; interrumpir cualquier instrucción
    MOVFF   BSR, BSR_ISR         ; del loop principal

    BTFSS   INTCON, 2, A         ; TMR0IF=1? (¿es interrupción de Timer0?)
    GOTO    ISR_Exit             ; No: salir sin actuar
    BCF     INTCON, 2, A         ; Limpiar TMR0IF o la ISR se repetiría al retornar

    MOVLW   T0_HIGH              ; Recargar preload: sin esto el próximo
    MOVWF   TMR0H, A             ; tick tardaría 65,536 cuentas en lugar de 391
    MOVLW   T0_LOW
    MOVWF   TMR0L, A             ; TMR0H solo se aplica al escribir TMR0L

    INCF    TickCount, F, A
    MOVF    VelocidadActual, W, A
    CPFSEQ  TickCount, A         ; ¿TickCount == VelocidadActual?
    GOTO    ISR_Exit             ; No: aún no es tiempo de avanzar

    CLRF    TickCount, A
    BSF     Flags, FLAG_PASO, A  ; Sí: avisar al loop principal

ISR_Exit:
    MOVFF   BSR_ISR, BSR
    MOVFF   STATUS_ISR, STATUS
    MOVFF   W_ISR, WREG
    RETFIE  1                    ; 1 = FAST: restaura W, STATUS y BSR del shadow register

    
    ; Código Principal
    
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0x60
    MOVWF   OSCCON, A            ; IRCF=110 ? 4 MHz

    MOVLW   0xE0                 ; 1110 0000: RB0-RB4 salidas, RB5-RB7 entradas
    MOVWF   TRISB, A
    CLRF    LATB, A

    MOVLW   0xFF
    MOVWF   TRISA, A             ; Todo PORTA como entrada

    CLRF    TickCount, A
    CLRF    Flags, A
    MOVLW   VEL_NORMAL
    MOVWF   VelocidadActual, A

    ; T0CON = 1000 0111
    ;   Bit 7 (TMR0ON) = 1 : encendido
    ;   Bit 6 (T08BIT) = 0 : modo 16 bits
    ;   Bit 5 (T0CS)   = 0 : reloj interno
    ;   Bit 3 (PSA)    = 0 : prescaler activo
    ;   Bits 2:0       = 111: prescaler 1:256
    
    MOVLW   0x87
    MOVWF   T0CON, A

    MOVLW   T0_HIGH
    MOVWF   TMR0H, A
    MOVLW   T0_LOW
    MOVWF   TMR0L, A

    BSF     INTCON, 2, A         ; TMR0IE: habilitar interrupción de Timer0
    BSF     INTCON, 6, A         ; PEIE: habilitar periféricos
    BSF     INTCON, 7, A         ; GIE: interruptor maestro (sin esto nada interrumpe)

    ;=======================================================
    ; Loop principal
    ; Ya no espera en un retardo: solo revisa FLAG_PASO
    ; que la ISR activa cada vez que se cumple el tiempo.
    ;=======================================================
Loop:
    BTFSS   Flags, FLAG_PASO, A  ; FLAG_PASO=1? (¿avisó la ISR?)
    GOTO    Loop

    BCF     Flags, FLAG_PASO, A  ; Limpiar antes de procesar

    MOVF    LATB, W, A
    XORLW   0x1F                 ; Invertir RB0-RB4 (mismo efecto que V 1.0)
    ANDLW   0x1F
    MOVWF   LATB, A

    GOTO    Loop

    
    ; Variables en RAM
   
    PSECT udata
TickCount:      DS 1             ; Ticks desde el último paso
VelocidadActual: DS 1            ; Ticks necesarios por paso
Flags:          DS 1             ; Bit 0 = FLAG_PASO

W_ISR:          DS 1             ; Contexto ISR
STATUS_ISR:     DS 1
BSR_ISR:        DS 1

    END