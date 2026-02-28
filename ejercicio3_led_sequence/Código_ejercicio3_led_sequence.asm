;=========================================================
; Código en Assembler para PIC18F4550
; Ejercicio 3: Led Sequence
; V 1.0
;
; Hardware:
;   LEDs    : RB0-RB4 (5 LEDs, salidas)
;   Pulsador secuencia : RA0 (entrada, pull-up externo)
;   Pulsador velocidad : RA1 (entrada, pull-up externo)
;
; Frecuencia: 4 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;
;=========================================================

    #include <xc.inc>

    
    ; Configuración de Fuses
 
    CONFIG  FOSC = INTOSCIO_EC   ; Oscilador interno
    CONFIG  WDT  = OFF           ; Watchdog deshabilitado
    CONFIG  LVP  = OFF           ; Sin programación en bajo voltaje
    CONFIG  PBADEN = OFF         ; PORTB digital desde reset

   
    ; Constantes simbólicas
    

    ; --- Pines de LEDs ---
    #define LED_TODOS    0x1F    ; 0001 1111: RB0-RB4 encendidos
    #define LED_APAGADOS 0x00    ; 0000 0000: todos apagados

    ; --- Pines de pulsadores (PORTA) ---
    ; Pull-up externo: pin en alto normalmente, bajo al presionar
    #define PIN_SEQ      0       ; RA0 -> pulsador de secuencia
    #define PIN_VEL      1       ; RA1 -> pulsador de velocidad

    ; --- Contadores de retardo (compartidos) ---
    #define CNT_EXT      142     ; Bucle externo
    #define CNT_INT      167     ; Bucle interno

    ; --- Valores del contador maestro según velocidad ---
    #define CNT_M_CORTO  2       ; ? 0.3 s (para verificar RA0)
    #define CNT_M_NORMAL 7       ; ? 1.0 s (velocidad base)
    #define CNT_M_LARGO  14      ; ? 2.0 s (para verificar RA1)

   
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
    MOVLW   0x60                 ; IRCF=110 ? fijar 4 MHz
    MOVWF   OSCCON

    ; --- Configurar PORTB: RB0-RB4 como salidas ---
    ; TRISB = 1110 0000 -> RB0-RB4 salidas, RB5-RB7 entradas
    MOVLW   0xE0                 ; 1110 0000
    MOVWF   TRISB
    CLRF    LATB                 ; LEDs apagados al inicio

    ; --- Configurar PORTA: RA0 y RA1 como entradas ---
    ; TRISA = 1111 1111 -> todo PORTA como entrada
    ; (pull-up externo mantiene los pines en alto)
    MOVLW   0xFF                 ; 1111 1111
    MOVWF   TRISA

    
    ; Bucle principal de prueba:
    ; Enciende todos los LEDs -> espera -> apaga -> espera
    ; La duración del retardo depende de los pulsadores
    
Loop:
    MOVLW   LED_TODOS
    MOVWF   LATB                 ; Encender RB0-RB4

    CALL    Retardo_Variable     ; Esperar según pulsadores

    MOVLW   LED_APAGADOS
    MOVWF   LATB                 ; Apagar RB0-RB4

    CALL    Retardo_Variable     ; Esperar según pulsadores

    GOTO    Loop

   
    ; Subrutina: Retardo Variable
    ; Lee RA0 y RA1 para decidir la duración del retardo.
    ; Pull-up externo: el pin está en alto normalmente
    ; y baja a 0 al presionar. Por eso se usa BTFSS
    ; (salta si el bit está en 1, es decir, NO presionado).
    ;
    ;   RA0 presionado -> retardo corto  (? 0.3 s)
    ;   RA1 presionado -> retardo largo  (? 2.0 s)
    ;   ninguno        -> retardo normal (? 1.0 s)
    
Retardo_Variable:
    MOVFF   WREG, W_Backup       ; Preservar W

    ; Verificar RA0 (pulsador de secuencia)
    BTFSS   PORTA, PIN_SEQ       ; Salta si RA0=1 (no presionado)
    GOTO    Vel_Corta            ; RA0=0 -> presionado -> retardo corto

    ; Verificar RA1 (pulsador de velocidad)
    BTFSS   PORTA, PIN_VEL       ; Salta si RA1=1 (no presionado)
    GOTO    Vel_Larga            ; RA1=0 -> presionado -> retardo largo

    ; Ningún pulsador presionado -> velocidad normal
    MOVLW   CNT_M_NORMAL         ; W = 7
    GOTO    Ejecutar_Retardo

Vel_Corta:
    MOVLW   CNT_M_CORTO          ; W = 2
    GOTO    Ejecutar_Retardo

Vel_Larga:
    MOVLW   CNT_M_LARGO          ; W = 14

Ejecutar_Retardo:
    MOVWF   ContadorMaestro      ; Cargar el valor elegido

Loop_Maestro:
    MOVLW   CNT_EXT
    MOVWF   ContadorExterno

Loop_Externo:
    MOVLW   CNT_INT
    MOVWF   ContadorInterno

Loop_Interno:
    NOP                          ; Ajuste fino de tiempo
    NOP
    NOP
    DECFSZ  ContadorInterno, F
    GOTO    Loop_Interno

    DECFSZ  ContadorExterno, F
    GOTO    Loop_Externo

    DECFSZ  ContadorMaestro, F
    GOTO    Loop_Maestro

    MOVFF   W_Backup, WREG       ; Restaurar W
    RETURN

    
    ; Variables en RAM
 
    PSECT udata
ContadorMaestro:    DS 1         ; Nivel superior del retardo
ContadorExterno:    DS 1         ; Nivel intermedio
ContadorInterno:    DS 1         ; Nivel base
W_Backup:           DS 1         ; Respaldo de WREG

    END


