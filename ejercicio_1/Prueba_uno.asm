;=========================================================
; Código en Assembler para PIC18F4550
; LED RB0: 1 segundo encendido / 2 segundos apagado
; Usa retardos sin interrupciones ni Timer0
; Frecuencia: 8 MHz (Oscilador Interno)
; Ensamblador: MPLAB XC8 3.0
;=========================================================

    #include <xc.inc>   ; Incluir definiciones del ensamblador para PIC18F4550

    ; Configuración de bits de configuración (Fuses)
    CONFIG  FOSC = INTOSCIO_EC   ; Usa el oscilador interno a 8 MHz
    CONFIG  WDT = OFF            ; Deshabilitar el Watchdog Timer
    CONFIG  LVP = OFF            ; Deshabilitar la programación en bajo voltaje
    CONFIG  PBADEN = OFF         ; Configurar los pines de PORTB como digitales

    ;===============================================
    ; Vectores de Inicio
    ;===============================================

    PSECT  resetVec, class=CODE, reloc=2  ; Sección para el vector de reinicio
    ORG     0x00                          ; Dirección de inicio
    GOTO    Inicio                         ; Saltar a la rutina de inicio

    ;===============================================
    ; Código Principal
    ;===============================================
    
    PSECT  main_code, class=CODE, reloc=2  ; Sección de código principal

Inicio:
    ; Configurar oscilador interno a 8 MHz
    MOVLW   0x72
    MOVWF   OSCCON

    CLRF    TRISB       ; Configurar PORTB como salida (0 = salida, 1 = entrada)
    CLRF    LATB        ; Apagar todos los pines de PORTB (LED apagado inicialmente)

Loop:
    
    ; LED ENCENDIDO (1 segundo)
    
    BSF     LATB, 0     ; Poner RB0 en 1 (encender LED)
    CALL    Retardo_1s  ; Esperar 1 segundo

    
    ; LED APAGADO (2 segundos)
    
    BCF     LATB, 0     ; Poner RB0 en 0 (apagar LED)
    CALL    Retardo_1s  ; Primer segundo apagado
    CALL    Retardo_1s  ; Segundo segundo apagado

    GOTO    Loop        ; Repetir indefinidamente

    ;===============================================
    ; Subrutina de Retardo de 1 Segundo (Aprox.)
    ;===============================================
Retardo_1s:

    MOVLW   11	; Cargar el valor 11 en el registro W (contador 3)
    MOVWF   Contador3	; Guardar el valor en la variable Contador3

Loop3:
    MOVLW   250 ; Cargar el valor 250 en el registro W (contador externo)
    MOVWF   ContadorExterno ; Guardar el valor en la variable ContadorExterno

Loop2:
    MOVLW   250 ; Cargar el valor 250 en el registro W (contador interno)
    MOVWF   ContadorInterno ; Guardar el valor en la variable ContadorInterno

Loop1:
    DECFSZ  ContadorInterno, F	; Decrementar ContadorInterno, si es cero, salta la siguiente instrucción
    GOTO    Loop1   ; Si no es cero, repetir el bucle interno

    DECFSZ  ContadorExterno, F	; Decrementar ContadorExterno, si es cero, salta la siguiente instrucción
    GOTO    Loop2   ; Si no es cero, repetir el bucle interno

    DECFSZ  Contador3, F    ; Decrementar Contador3, si es cero, salta la siguiente instrucción
    GOTO    Loop3   ; Si no es cero, repetir el bucle interno

    RETURN  ; Retornar al programa principal después del retardo

    ;===============================================
    ; Definición de Variables
    ;===============================================

    PSECT udata  ; Sección de datos sin inicializar (variables en RAM)
ContadorExterno:   DS 1   ; Reserva 1 byte de memoria para el contador externo
ContadorInterno:   DS 1   ; Reserva 1 byte de memoria para el contador interno
Contador3: DS 1
    END            ; Fin del código
