;=========================================================
; Código en Assembler para PIC18F4550
; V 3.2 (final)
; Parpadeo de LED en RB0:
;   - 1 segundo ENCENDIDO
;   - 2 segundos APAGADO
;
; Frecuencia: 4 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;
; NOTA:
; Este código es funcional en su totalidad.
; Las únicas diferencias frente al código anterior
; están marcadas explícitamente con comentarios.
;=========================================================

    #include <xc.inc>


; CONFIGURACIÓN DE FUSES

    CONFIG  FOSC = INTOSCIO_EC   ; Oscilador interno
    CONFIG  WDT  = OFF
    CONFIG  LVP  = OFF
    CONFIG  PBADEN = OFF


; CONSTANTES 

    #define LED_PIN      0

    #define CNT_EXT      142
    #define CNT_INT      167

    #define CNT_M_1S     7
    #define CNT_M_2S     14


; VECTOR DE RESET

    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio


; VECTORES DE INTERRUPCIÓN (no usados)

    PSECT  highIntVec, class=CODE, reloc=2
    ORG     0x08
    RETFIE

    PSECT  lowIntVec, class=CODE, reloc=2
    ORG     0x18
    RETFIE


; CÓDIGO PRINCIPAL

    PSECT  main_code, class=CODE, reloc=2

Inicio:
    ; <<< CAMBIO >>>
    ; Se fuerza explícitamente el oscilador interno a 4 MHz.
    ; En el código anterior esto se asumía implícitamente.
    ; IRCF = 110 → 4 MHz
    MOVLW   0x60
    MOVWF   OSCCON

    CLRF    TRISB
    CLRF    LATB

Loop:
    BSF     LATB, LED_PIN
    CALL    Retardo_1s

    BCF     LATB, LED_PIN
    CALL    Retardo_2s

    GOTO    Loop

; RETARDO DE 1 SEGUNDO

Retardo_1s:
    MOVFF   WREG, W_Backup
    MOVLW   CNT_M_1S
    MOVWF   ContadorMaestro

Loop1s_Maestro:
    MOVLW   CNT_EXT
    MOVWF   ContadorExterno

Loop1s_Externo:
    MOVLW   CNT_INT
    MOVWF   ContadorInterno

Loop1s_Interno:
    NOP
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    Loop1s_Interno

    DECFSZ  ContadorExterno, F
    GOTO    Loop1s_Externo

    DECFSZ  ContadorMaestro, F
    GOTO    Loop1s_Maestro

    MOVFF   W_Backup, WREG
    RETURN


; RETARDO DE 2 SEGUNDOS

Retardo_2s:
    MOVFF   WREG, W_Backup
    MOVLW   CNT_M_2S
    MOVWF   ContadorMaestro

Loop2s_Maestro:
    MOVLW   CNT_EXT
    MOVWF   ContadorExterno

Loop2s_Externo:
    MOVLW   CNT_INT
    MOVWF   ContadorInterno

Loop2s_Interno:
    NOP
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    Loop2s_Interno

    DECFSZ  ContadorExterno, F
    GOTO    Loop2s_Externo

    DECFSZ  ContadorMaestro, F
    GOTO    Loop2s_Maestro

    MOVFF   W_Backup, WREG
    RETURN

; VARIABLES EN RAM

    PSECT udata
ContadorMaestro:    DS 1
ContadorExterno:    DS 1
ContadorInterno:    DS 1
W_Backup:           DS 1

    END