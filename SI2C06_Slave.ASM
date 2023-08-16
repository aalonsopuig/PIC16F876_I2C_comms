; si2c06
; Programa para control de bus i2c (versión slave)
; Por: Alejandro Alonso Puig - mundobot.com
; Fecha: 02/08/2003
; Controlador: 16F876
; Función: 
; Trabaja como Slave de un PIC cargado con "mi2c06" (versión master)
; Realiza transmisión bidireccional i2c mediante el uso de interrupciones.
; Cuando el Master le envía un dato, lo deja en la variable "MensajeIn" y
; lo muestra por los leds conectados al puerto B
; Cuando el Master le pide un dato, envía el valor que contenga la variable "MensajeOut".
;

	list 		p=16F876
	include		"P16F876.INC"


;Definición de constantes

	#define	DirNodo		b'01111000'	;Dirección I2C de este nodo

;Definición de variables

	cblock	0x20	
	MensajeIn	;Contendrá el dato recibido por I2C del master
	MensajeOut	;Contendrá el dato a enviar por I2C al master
	BkStatus	;Backup del registro STATUS
	BkW		;Backup W
	Temp		;Variable Temporal usada para evaluación de eventos I2C
	endc		;Fin de definiciones


	org	0
	goto	INICIO
	org	5		

;-------------------------------------------------------------------------------
Interrupcion   	;RUTINA DE INTERRUPCIÓN. Se ocupa de los eventos I2C
;-------------------------------------------------------------------------------

	;Guardamos copia de algunos registros
	movwf	BkW		;Hace copia de W
	movf	STATUS,W	;Hace copia de registro de estado
	banksel	PORTA
	movwf	BkStatus


	;Chequeamos si la interrupción es por evento I2C. En caso positivo llamamos
	;a la rutina de proceso del evento
	banksel PIR1
	btfss	PIR1,SSPIF	;Ha ocurrido un evento SSP? (I2C)
	goto	IntNoSSP	;No. entonces será por otra cosa. Saltamos.
	call	SSP_Handler	;Si. Procesamos el evento. Si se reciben ordenes, quedarán
				;registradas en "MensajeIn". Se enviarán las ordenes 
				;guardadas en "MensajeOut".
	banksel PIR1
	bcf	PIR1,SSPIF	;Limpiamos el flag
	goto	Rest

IntNoSSP	;Aquí se gestionan interrupciones que no son por SSP

;..........
; En caso de necesitarse, poner aquí la rutina de gestión de interrupciones 
; que no sean por bus I2C
;..........


Rest	;Restauramos las copias de los registros
	movf	BkStatus,W	;Restaura las copias de registros
	movwf	STATUS		;registro de estado
	movf	BkW,W		;registro W

	retfie


;-------------------------------------------------------------------------------




INICIO		;Inicio del cuerpo del programa

	banksel	TRISB		;Apunta a banco 1
	movlw	b'00000000'	;Salida (Leds)
	movwf	TRISB		;
	banksel	PORTB		;Apunta a banco 0
	clrf	PORTB		;Limpia puerto B

	call	init_i2c_Slave	;Configuración para uso de i2c
	banksel INTCON
	bsf	INTCON,GIE	;Activamos las interrupciones

	banksel MensajeIn
	clrf	MensajeIn
	clrf	MensajeOut


MLoop	
	movlw	b'10011001'	;dato cualquiera por I2C que metemos en
	movwf	MensajeOut	;"MensajeOut" para cuando el Master se lo pida
	movf	MensajeIn,W	;Muestra por port B (leds)...
	movwf	PORTB		;...el ultimo valor enviado por el Master
	goto	MLoop




;*********************************************************************************
; SUBRUTINAS
;*********************************************************************************

;-------------------------------------------------------------------------------
init_i2c_Slave		;Inicializa valores para uso de I2C en Slave
			;Ha de ser llamado tras definir TRISC y un valor para
			;ClockValue. Para frecuencia SCL=Fosc/(4x(ClockValue+1))
;-------------------------------------------------------------------------------

	;Guardamos copia de algunos registros
	movwf	BkW		;Hace copia de W
	movf	STATUS,W	;Hace copia de registro de estado
	banksel	PORTA
	movwf	BkStatus

	;Configuramos I2C
	banksel TRISC		; Pasamos a direccionar Banco 1
	movlw 	b'00011000'	; Establece líneas SDA y SCL como entradas...
	iorwf 	TRISC,f		;..respetando los valores para otras líneas.
	bcf 	SSPSTAT,CKE 	; Establece I2C input levels
	bcf 	SSPSTAT,SMP 	; Habilita slew rate
	bsf	SSPCON2,GCEN	; Habilita direccionamiento global
	movlw	DirNodo		; Dirección esclavo 
	movwf	SSPADD		;
	banksel SSPCON 		; Pasamos a direccionar Banco 0
	movlw 	b'00110110'	; Slave mode, SSP enable, velocidad segun...
	movwf 	SSPCON 		; ... Fosc/(4x(SSPADD+1))
	bcf	PIR1,SSPIF	; Limpia flag de eventos SSP
	bcf	PIR1,7		; Limpia bit. Mandatorio por Datasheet

	;Configuración para interrupciones por evento I2C
	banksel PIE1
	bsf	PIE1,SSPIE
	bsf	INTCON,PEIE

	;Restauramos las copias de los registros 
	movf	BkStatus,W	;Restaura las copias de registros
	movwf	STATUS		;registro de estado
	movf	BkW,W		;registro W

	return


; --------------------------------------------------------------------------------------
SSP_Handler	; Este manejador controla cada evento SSP (I2C) acontecido. 
		; El código que se muestra abajo chequea 5 posibles estados.
		; Cada uno de los 5 estados SSP son identificados haciendo 
		; XOR de los bits del registro SSPSTAT con mascaras de bits
		; predeterminadas. Una vez que el estado ha sido identificado
		; se llevan a cabo las acciones pertinentes. Los estados
		; indefinidos son considerados como estados de error.

		; State 1: Operación de escritura I2C, ultimo byte era de dirección.
		; SSPSTAT bits: S = 1, D_A = 0, R_W = 0, BF = 1

		; State 2: Operación de escritura I2C, ultimo byte era de datos.
		; SSPSTAT bits: S = 1, D_A = 1, R_W = 0, BF = 1

		; State 3: Operación de lectura I2C, ultimo byte era de dirección.
		; SSPSTAT bits: S = 1, D_A = 0, R_W = 1, BF = 0

		; State 4: Operación de lectura I2C, ultimo byte era de datos.
		; SSPSTAT bits: S = 1, D_A = 1, R_W = 1, BF = 0

		; State 5: Reset lógico del Slave I2C por NACK del master.
		; SSPSTAT bits: S = 1, D_A = 1, R_W = 0, BF = 0

; --------------------------------------------------------------------------------------

	banksel SSPSTAT
	movf 	SSPSTAT,W 	; Obtiene el valor de SSPSTAT
	andlw 	b'00101101' 	; elimina los bits no importantes SSPSTAT.
	banksel	Temp
	movwf 	Temp 		; para chequeo posterior.

State1: 			; Operación de escritura, ultimo byte ha sido
	movlw 	b'00001001' 	; de dirección, el buffer está lleno.
	banksel	Temp
	xorwf 	Temp,W 		;
	btfss 	STATUS,Z 	; Estamos en el primer estado?
	goto 	State2 		; No, checkeamos siguiente estado
	call 	ReadI2C 	; SI. Hacemos un read SSPBUF (para vaciar buffer).
				; El Hardware se ocupa de mandar Ack
	return

State2: 			; Operación de escritura, ultimo byte ha sido
	movlw 	b'00101001' 	; de datos, el buffer está lleno.
	banksel	Temp
	xorwf 	Temp,W
	btfss 	STATUS,Z 	; Estamos en el segundo estado?
	goto 	State3 		; NO, checkeamos siguiente estado
	call 	ReadI2C 	; SI, Tomamos el byte del SSP.

	;Aquí tenemos en W el valor del dato recibido
	movwf	MensajeIn
	return

State3: 			; Operación de lectura, ultimo byte ha sido
	movlw 	b'00001100' 	; de dirección, el buffer está vacío
	banksel	Temp
	xorwf 	Temp,W
	btfss 	STATUS,Z 	; Estamos en el tercer estado?
	goto 	State4 		; NO, checkeamos siguiente estado

	;Aquí debemos poner en W el valor del dato a enviar (solicitado por el master)
	movf	MensajeOut,W

	call 	WriteI2C 	; SI, escribimos el byte en SSPBUF
	return

State4: 			; Operación de lectura, ultimo byte ha sido
	movlw 	b'00101100' 	; de datos, el buffer está vacío
	banksel	Temp
	xorwf 	Temp,W
	btfss 	STATUS,Z 	; Estamos en el cuarto estado?
	goto 	State5 		; NO, checkeamos siguiente estado

	;Aquí debemos poner en W el valor del dato a enviar (solicitado por el master)
	movf	MensajeOut,W

	call 	WriteI2C 	; SI, escribimos el byte en SSPBUF
	return

State5:
	movlw 	b'00101000' 	; Se ha recibido un NACK mientras se transmitían...
	banksel	Temp
	xorwf 	Temp,W 		; ..datos al master. Lo lógica del Slave..
	btfss 	STATUS,Z 	; ..se resetea en este caso. R_W = 0, D_A = 1
	goto 	I2CErr 		; y BF = 0
	return 			; Si no estamos en State5, entonces es
				; que algo fue mal

I2CErr 	nop			; Algo fue mal
	return


;---------------------------------------------------------------------
WriteI2C	;Usada por SSP_Handler para escribir datos en bus I2C
;---------------------------------------------------------------------

	banksel SSPCON 		
	movwf 	SSPBUF 		; Escribe el dato en W
	bsf 	SSPCON,CKP 	; Libera el reloj
	return

;---------------------------------------------------------------------
ReadI2C		;Usada por SSP_Handler para escribir datos en bus I2C
;---------------------------------------------------------------------

	banksel SSPBUF
	movf 	SSPBUF,W 	; Toma el byte y lo guarda en W
	return



END
