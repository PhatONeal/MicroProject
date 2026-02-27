;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 2: Led Blink+
; V 2.0 (final)
; Parpadeo de LED en RB0:
;   - Bloque 1: 5 × (1s ON + 1s OFF)  = 10 segundos
;   - Bloque 2: 2 × (2s ON + 2s OFF)  =  8 segundos
;              + 1s apagado al finalizar
;   - Reinicia la secuencia
;
; Frecuencia: 4 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;=========================================================

    #include <xc.inc>

    
    ; Configuración de Fuses
    
    CONFIG  FOSC = INTOSCIO_EC   
    CONFIG  WDT  = OFF           
    CONFIG  LVP  = OFF           
    CONFIG  PBADEN = OFF         

   
    ; Constantes simbólicas
  
    #define LED_PIN      0       ; LED conectado en RB0

    ; Sin cambios respecto a V 1.0
    #define CNT_EXT      142     ; Bucle externo
    #define CNT_INT      167     ; Bucle interno
    #define CNT_M_1S     7       ; Maestro → ≈ 1.000 s @ 4 MHz

    ; Nuevo en esta versión: contador maestro para 2s
    #define CNT_M_2S     14      ; Maestro → ≈ 2.000 s @ 4 MHz (doble de CNT_M_1S)

    ; Nuevo en esta versión: repeticiones de cada bloque
    #define PARPADEOS_B1 5       ; Bloque 1: 5 repeticiones de 1s
    #define PARPADEOS_B2 2       ; Bloque 2: 2 repeticiones de 2s

    
    ; Vector de Reset
   
    PSECT  resetVec, class=CODE, reloc=2
    ORG     0x00
    GOTO    Inicio

    
    ; Vectores de interrupción (no usados)
  
    PSECT  highIntVec, class=CODE, reloc=2
    ORG     0x08
    RETFIE

    PSECT  lowIntVec, class=CODE, reloc=2
    ORG     0x18
    RETFIE

    
    ; Código Principal
    
    PSECT  main_code, class=CODE, reloc=2

Inicio:
    MOVLW   0x60                 ; IRCF=110 → fijar 4 MHz en OSCCON
    MOVWF   OSCCON
    CLRF    TRISB                ; PORTB como salida
    CLRF    LATB                 ; LED inicialmente apagado

   
    ; Secuencia principal: se repite indefinidamente
   
Secuencia:

    
    ; Bloque 1: 5 × (1s ON + 1s OFF)
    ; Mismo mecanismo que V 1.0, solo cambia la constante
   
    MOVLW   PARPADEOS_B1         ; Cambió de PARPADEOS → PARPADEOS_B1
    MOVWF   ContadorParpadeos    ; para distinguirlo del nuevo Bloque 2

Bloque1_Loop:
    BSF     LATB, LED_PIN        ; Encender LED
    CALL    Retardo_1s           ; 1 segundo encendido

    BCF     LATB, LED_PIN        ; Apagar LED
    CALL    Retardo_1s           ; 1 segundo apagado

    DECFSZ  ContadorParpadeos, F
    GOTO    Bloque1_Loop

    ;-------------------------------------------------------
    ; Bloque 2: 2 × (2s ON + 2s OFF)
    ; Nuevo en esta versión: mismo patrón que Bloque 1
    ; pero con Retardo_2s y solo 2 repeticiones
    ;-------------------------------------------------------
    MOVLW   PARPADEOS_B2         ; Nuevo: cargar 2 repeticiones para este bloque
    MOVWF   ContadorParpadeos    ; se reutiliza la misma variable

Bloque2_Loop:
    BSF     LATB, LED_PIN        ; Encender LED
    CALL    Retardo_2s           ; Nuevo: 2 segundos encendido

    BCF     LATB, LED_PIN        ; Apagar LED
    CALL    Retardo_2s           ; Nuevo: 2 segundos apagado

    DECFSZ  ContadorParpadeos, F
    GOTO    Bloque2_Loop

    ;-------------------------------------------------------
    ; Pausa final de 1s con LED apagado
    ; Nuevo en esta versión: el LED ya quedó apagado por
    ; el BCF al salir de Bloque2_Loop; solo se llama al
    ; retardo sin necesidad de un BCF adicional
    ;-------------------------------------------------------
    CALL    Retardo_1s           ; Nuevo: 1s apagado antes de reiniciar

    GOTO    Secuencia            ; Reiniciar secuencia completa

   
Retardo_1s:
    MOVFF   WREG, W_Backup       ; Preservar W

    MOVLW   CNT_M_1S
    MOVWF   ContadorMaestro

Loop1s_Maestro:
    MOVLW   CNT_EXT
    MOVWF   ContadorExterno

Loop1s_Externo:
    MOVLW   CNT_INT
    MOVWF   ContadorInterno

Loop1s_Interno:
    NOP                          ; Ajuste fino de tiempo
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    Loop1s_Interno

    DECFSZ  ContadorExterno, F
    GOTO    Loop1s_Externo

    DECFSZ  ContadorMaestro, F
    GOTO    Loop1s_Maestro

    MOVFF   W_Backup, WREG       ; Restaurar W
    RETURN

    ;=======================================================
    ; Subrutina: Retardo de 2 Segundos
    ; Nueva en esta versión: misma estructura que Retardo_1s,
    ; solo cambia el contador maestro al doble
    ;=======================================================
Retardo_2s:
    MOVFF   WREG, W_Backup       ; Preservar W

    MOVLW   CNT_M_2S             ; Nuevo: CNT_M_2S = 14 = 2 × CNT_M_1S
    MOVWF   ContadorMaestro

Loop2s_Maestro:
    MOVLW   CNT_EXT              ; Sin cambio: mismos CNT_EXT y CNT_INT
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

    MOVFF   W_Backup, WREG       ; Restaurar W
    RETURN

    
    ; Variables en RAM
    
    PSECT udata
ContadorParpadeos:  DS 1         ; Contador compartido por ambos bloques
ContadorMaestro:    DS 1         ; Nivel superior del retardo
ContadorExterno:    DS 1         ; Nivel intermedio
ContadorInterno:    DS 1         ; Nivel base
W_Backup:           DS 1         ; Respaldo de WREG

    END