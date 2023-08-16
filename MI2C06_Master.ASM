; mi2c06
; Programa para control de bus i2c (versión master)
; Por: Alejandro Alonso Puig - mundobot.com
; Fecha: 2/8/2003
; Controlador: 16F876
; Función: 
; Trabaja como Master de un PIC cargado con "si2c06" (versión slave)
; Realiza transmisión bidireccional i2c.
; Envía al slave el valor de la variable "MensajeOut"
; Pide al slave un dato, que una vez recibido, lo deja en la variable "MensajeIn" y
; lo muestra por los leds conectados al puerto B
;

	list 		p=16F876
	include		"P16F876.INC"


;Definición de constantes

	#define	ClockValue d'9' ;(100khz) valor para cálculo de vel. I2C que pasará a SSPADD

;Definición de variables

	cblock	0x20	
	MensajeIn	;Contendrá el dato recibido por I2C del slave
	MensajeOut	;Contendrá el dato a enviar por I2C al slave
	DirSlave	;Dirección del Slave	
	BkStatus	;Backup del registro STATUS 
	BkW		;Backup W
	BDel0		;Usada en retardos. Usada por subr "HacerTiempo"		
	BDel1		;Usada en retardos. Usada por subr "HacerTiempo"		
	BDel2		;Usada en retardos. Usada por subr "HacerTiempo"		
	Pausa		;Pausa en centesima de sg. Usada por subr "HacerTiempo"
	endc		;Fin de definiciones


	org	0
	goto	INICIO
	org	5		



;-------------------------------------------------------------------------------




INICIO		;Inicio del cuerpo del programa

	banksel	TRISB		;Apunta a banco 1
	movlw	b'00000000'	;Salida (Leds)
	movwf	TRISB		;
	banksel	PORTB		;Apunta a banco 0
	clrf	PORTB		;Limpia puerto B

	call	init_i2c_Master	;Configuración para uso de i2c

	clrf	MensajeIn
	clrf	MensajeOut

	movlw	d'10'		;Pausa de 10 centésimas de segundo para que en...
	movwf	Pausa		;...el arranque de tiempo a los slaves a quedar...
	call	HacerTiempo	;..configurados adecuadamente.

MLoop	

	;ENVIO DE UN BYTE AL SLAVE
	;Se ha de guardar el byte que se quiere transmitir en "MensajeOut" y 
	;la dirección del Slave en "DirSlave". Tras esto solo hay que llamar
	;a la subrutina "Enviar"
	movlw	b'10101010'	;dato cualquiera por I2C que metemos en
	movwf	MensajeOut	;"MensajeOut" para envío por I2C
	movlw	b'01111000'	;Establece dirección de envío..
	Movwf	DirSlave	;..es decir, dirección del slave
	call	Enviar		;Envía el dato de "MensajeOut" al Slave

	;PETICION DE UN BYTE DE DATOS AL SLAVE
	;Se ha de la dirección del Slave en "DirSlave". Tras esto solo hay que llamar
	;a la subrutina "Recibir" y se obtendrá el dato en "MensajeIn"
	movlw	b'01111000'	;Establece dirección de solicitud..
	Movwf	DirSlave	;..es decir, dirección del slave
	call	Recibir		;Toma dato del Slave...  
	movf	MensajeIn,W	;... a través de "MensajeIn"...
	movwf	PORTB		;...y lo muestra por PORTB (Leds)


	goto	MLoop




;*********************************************************************************
; SUBRUTINAS
;*********************************************************************************

;-------------------------------------------------------------------------------
init_i2c_Master		;Inicializa valores para uso de I2C en Master
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
	movlw 	ClockValue 	; Establece velocidad I2C segun...
	movwf 	SSPADD 		; ...valor de ClockValue 	
	bcf 	SSPSTAT,6 	; Establece I2C input levels
	bcf 	SSPSTAT,7 	; Habilita slew rate
	banksel SSPCON 		; Pasamos a direccionar Banco 0
	movlw 	b'00111000'	; Master mode, SSP enable, velocidad segun...
	movwf 	SSPCON 		; ... Fosc/(4x(SSPADD+1))
	bcf	PIR1,SSPIF	; Limpia flag de eventos SSP
	bcf	PIR1,7		; Limpia bit. Mandatorio por Datasheet

	;Restauramos las copias de los registros
	movf	BkStatus,W	;Restaura las copias de registros
	movwf	STATUS		;registro de estado
	movf	BkW,W		;registro W

	return


; --------------------------------------------------------------------------------------
Enviar	;Envía un mensaje (comando) almacenado en "MensajeOut" al Slave cuya dirección
	;se ha de encontrarse en la variable "DirSlave"
;---------------------------------------------------------------------------------------


	;Guardamos copia de algunos registros
	movwf	BkW		;Hace copia de W
	movf	STATUS,W	;Hace copia de registro de estado
	banksel	PORTA
	movwf	BkStatus

StEnv	call	Send_Start	;Envía condición de inicio
	call	CheckIdle	;Espera fin evento
	banksel	DirSlave
	movf	DirSlave,W	;Dirección esclavo
	call	Send_Byte	;Envía dirección y orden de escritura
	call	CheckIdle	;Espera fin evento
	call	WrtAckTest	;Verifica llegada ACK
	banksel SSPCON2 	
	bcf	SSPCON2,ACKSTAT	;limpia flag ACK
	xorlw	1
	btfsc	STATUS,Z	;Chequea si llegó ACK
	goto	StEnv		;No. Reintentamos envío
	banksel MensajeOut	;Si. Seguimos con envío dato
	movf	MensajeOut,W	;Lo deja en W para que la subrutina Send_Byte lo envíe

	call	Send_Byte	;envía por i2c
	call	CheckIdle	;Espera fin evento
	call	Send_Stop	;Envia condición de parada
	call	CheckIdle	;Espera fin evento

	;Restauramos las copias de los registros
	movf	BkStatus,W	;Restaura las copias de registros
	movwf	STATUS		;registro de estado
	movf	BkW,W		;registro W

	return


; --------------------------------------------------------------------------------------
Recibir	;Solicita dato al Slave cuya dirección ha de encontrarse en la variable 
	;"DirSlave" y lo mete en "MensajeIn".
;---------------------------------------------------------------------------------------

	;Guardamos copia de algunos registros
	movwf	BkW		;Hace copia de W
	movf	STATUS,W	;Hace copia de registro de estado
	banksel	PORTA
	movwf	BkStatus

StRec	call	Send_Start	;Envía condición de inicio
	call	CheckIdle	;Espera fin evento
	banksel	DirSlave
	movf	DirSlave,W	;Dirección esclavo
	iorlw	b'00000001'	;con orden de lectura
	call	Send_Byte	;Envía dirección y orden de lectura
	call	CheckIdle	;Espera fin evento
	call	WrtAckTest	;Verifica llegada ACK
	banksel SSPCON2 	
	bcf	SSPCON2,ACKSTAT	;limpia flag ACK
	xorlw	1
	btfsc	STATUS,Z	;Chequea si llegó ACK
	goto	StRec		;No. Reintentamos envío
				;Si. Leemos dato
	call	Rec_Byte	;Recibe dato por i2c y lo mete en "MensajeIn"
	call	CheckIdle	;Espera fin evento
	call	Send_Nack	;Envía Nack para finalizar recepción
	call	CheckIdle	;Espera fin evento
	call	Send_Stop	;Envía condición de stop
	call	CheckIdle	;Espera fin evento

	;Restauramos las copias de los registros
	movf	BkStatus,W	;Restaura las copias de registros
	movwf	STATUS		;registro de estado
	movf	BkW,W		;registro W

	return



; --------------------------------------------------------------------------------------
Send_Start	;Envía condición de start
;---------------------------------------------------------------------------------------

	banksel SSPCON2 		
	bsf 	SSPCON2,SEN 	; Envía Start
	return 


; --------------------------------------------------------------------------------------
Send_Ack	;Envía Ack
;---------------------------------------------------------------------------------------

	banksel SSPCON2 	
	bcf 	SSPCON2,ACKDT 	; acknowledge bit state to send (ack)
	bsf 	SSPCON2,ACKEN 	; Inicia secuencia de ack
	return


; --------------------------------------------------------------------------------------
Send_Nack	;Envía Nack para finalizar recepción
;---------------------------------------------------------------------------------------

	banksel SSPCON2 	
	bsf 	SSPCON2,ACKDT 	; acknowledge bit state to send (not ack)
	bsf 	SSPCON2,ACKEN 	; Inicia secuencia de nack
	return


; --------------------------------------------------------------------------------------
Send_Stop	;Envía condición de stop
;---------------------------------------------------------------------------------------

	banksel SSPCON2	
	bsf	SSPCON2,PEN	;Activa secuencia de stop
	return				


; --------------------------------------------------------------------------------------
Send_Byte	;Envía el contenido de W por i2c
;---------------------------------------------------------------------------------------

	banksel SSPBUF 		; Cambia a banco 0
	movwf 	SSPBUF 		; inicia condicion de escritura
	return	



; --------------------------------------------------------------------------------------
Rec_Byte	;Recibe dato por i2c y lo mete en "MensajeIn"
;---------------------------------------------------------------------------------------

	banksel SSPCON2 	; Cambia a banco 1
	bsf 	SSPCON2,RCEN 	; genera receive condition
	btfsc 	SSPCON2,RCEN	; espera a que llegue el dato
	goto 	$-1
	banksel SSPBUF		; Cambia a banco 0
	movf 	SSPBUF,w 	; Mueve el dato recibido ...
	movwf 	MensajeIn 	; ...  a MensajeIn
	return


; --------------------------------------------------------------------------------------
CheckIdle	;Chequea que la operación anterior termino y se puede proceder con
		;el siguiente evento SSP
;---------------------------------------------------------------------------------------

	banksel SSPSTAT		; Cambia a banco 1
	btfsc 	SSPSTAT, R_W 	; Transmisión en progreso?
	goto 	$-1
	movf 	SSPCON2,W 		
	andlw 	0x1F 		; Chequeamos con mascara para ver si evento en progreso
	btfss 	STATUS, Z
	goto 	$-3 		; Sigue en progreso o bus ocupado. esperamos
	banksel PIR1		; Cambia a banco 0
	bcf 	PIR1,SSPIF	; Limpiamos flag
	return


;---------------------------------------------------------------------------------------
WrtAckTest	;Chequea ack tras envío de dirección o dato
		;Devuelve en W 0 o 1 dependiendo de si llegó (0) o no (1) ACK
;---------------------------------------------------------------------------------------

	banksel SSPCON2 	; Cambia a banco 1	
	btfss 	SSPCON2,ACKSTAT ;Chequea llegada ACK desde slave
	retlw	0		;llegó ACK
	retlw	1		;no llegó ACK



;---------------------------------------------------------------------------------------
HacerTiempo	;realiza una pausa del numero de centesimas de segundo especificadas en "Pausa"
;---------------------------------------------------------------------------------------

	movf	Pausa,W		;Coloca el valor de pausa en BDel2...
	movwf	BDel2		;...para no alterar su contenido
	
;............................................................
; Generado con PDEL ver SP  r 1.0  el 24/02/03 Hs 18:31:22
; Descripcion: Delay 10000 ciclos (1 centésima de segundo)
;............................................................
BCiclo  movlw     .8        ; 1 set numero de repeticion  (B)
        movwf     BDel0     ; 1 |
BLoop1  movlw     .249      ; 1 set numero de repeticion  (A)
        movwf     BDel1     ; 1 |
BLoop2  nop                 ; 1 nop   
        nop                 ; 1 ciclo delay
        decfsz    BDel1, 1  ; 1 + (1) es el tiempo 0  ? (A)
        goto      BLoop2    ; 2 no, loop
        decfsz    BDel0,  1 ; 1 + (1) es el tiempo 0  ? (B)
        goto      BLoop1    ; 2 no, loop
BDelL1  goto BDelL2         ; 2 ciclos delay
BDelL2  nop                 ; 1 ciclo delay
;............................................................
	decfsz	BDel2,F		;Repite tantas veces el ciclo de una decima de segundo...
	goto	BCiclo		;..como se lo indique ADel2
        return              ; 2+2 Fin.



END
