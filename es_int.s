********** Inicializacion **********
		ORG		$0
		DC.L	$8000	* Valor inicial del puntero de pila
		DC.L	INICIO	* Etiqueta del programa principal
			
		ORG		$400
		
		COPIAIMR:	DS.B	1	* Copia del IMR para poder acceder en lectura
					DS.B 	1	* Para evitar problemas de desalineamiento		
		INCLUDE bib_aux.s

********** Buffer A **********	
MR1A	EQU	$EFFC01 * N bits por caracter de linea. Solicitud de interrupcion en recepcion
MR2A	EQU	$EFFC01 * Modo de operacion de linea
SRA		EQU	$EFFC03 * Estado de la linea
CSRA	EQU	$EFFC03 * Control de velocidad de transmision y recepcion
CRA		EQU	$EFFC05	* Control de linea (escritura)
TBA		EQU	$EFFC07	* Transimision de linea (escritura)
RBA		EQU	$EFFC07	* Recepcion de linea (lectura)

********** Buffer B **********	
MR1B	EQU	$EFFC11 * N bits por caracter de linea. Solicitud de interrupcion en recepcion
MR2B	EQU	$EFFC11 * Modo de operacion de linea
SRB		EQU $EFFC13 * Estado de la linea
CSRB	EQU $EFFC13 * Control de velocidad de transmision y recepcion
CRB		EQU $EFFC15 * Control de linea (escritura)
TBB		EQU $EFFC17	* Transimision de linea (escritura)
RBB		EQU $EFFC17 * Recepcion de linea (lectura)

********** REGISTROS AUXILIARES **********	
IVR		EQU	$EFFC19	* Vector de interrupcion
ISR		EQU	$EFFC0B	* Estado de interrupcion
IMR		EQU	$EFFC0B	* Mascara de interrupción
ACR		EQU	$EFFC09	* Control auxiliar

***************************      INIT      ***************************
*             	   Inicializacion de los dispositivos                *                                                									
**********************************************************************

INIT:		MOVE.B	#%00010000,CRA	* Se reinicia puntero MR1
			MOVE.B	#%00000011,MR1A	* 8 bits por carácter. Se inicializa a "RxRDY"
			MOVE.B	#%00000000,MR2A	* Se desactiva Eco
			MOVE.B	#%11001100,CSRA	* Velocidad = 38400bps
			
			MOVE.B	#%00010000,CRB	* Se reinicia puntero MR1
			MOVE.B	#%00000011,MR1B	* 8 bits por carácter. Se inicializa a "RxRDY"
			MOVE.B	#%00000000,MR2B	* Se desactiva Eco
			MOVE.B	#%11001100,CSRB	* Velocidad = 38400 bps
			
			MOVE.B	#%00000000,ACR	* Se selecciona el conjunto 1
			MOVE.B	#%00000101,CRA	* Se activa transmisión y recepcion en A
			MOVE.B	#%00000101,CRB	* Se activa transmisión y recepcion en B
			
			MOVE.B	#$40,IVR		* Vector de interrupcion establecido
			
			MOVE.B	#%00100010,IMR		* Se habilitan interrupciones
			MOVE.B	#%00100010,COPIAIMR * Copia del IMR
			
			MOVE.L 	#RTI,$100		* Se introduce en TV la direccion de RTI
			
			BSR		INI_BUFS		* Llamada al auxiliar para inicializar los buffer
			RTS						* Terminacion de la subrutina


***************************      SCAN      ***************************
*    Lectura de un dispositivo. Devolvera un bloque de caracteres    *
*	 que se haya recibido previamente por la lınea					 *
*    correspondiente (A o B).                                        *
**********************************************************************

SCAN:		LINK	A6,#0		* Inicializacion del marco de pila
			MOVE.L 	8(A6),A1	* Se guarda en A1 dirección Buffer (A1<-M(A6+8))
			MOVE.L	#0,D2		* Inicializacion D2 (D2<-#0)
			MOVE.L	#0,D3		* Inicializacion D3 (D3<-#0)
			MOVE.L	#0,D4		* Inicializacion D4 (D4<-#0)
			MOVE.W	12(A6),D2	* Se guarda en D2 el descriptor
			MOVE.W	14(A6),D3	* Se guarda en D3 el tamaño
			
	SCANBUC:	CMP.W	#0,D2	* Si el descriptor es 0, es la línea A
				BNE		SALTOB	* Salta para comprobar si es línea B	
				MOVE.L	#0,D0	* Para la llamada a LEECAR, D0=0
				BRA		CONTSCAN * Se salta para continuar con la subrutina
	SALTOB:		CMP.W	#1,D2	* Si el descriptor es 1, es la línea B
				BNE		SALTERR	* Si no es 0 ni 1, error de parámetros
				MOVE.L	#1,D0	* Para la llamada a LEECAR, D0=1
				BRA		CONTSCAN
	SALTERR:	MOVE.L 	#$FFFFFFFF,D0	*Ya que hay error, D0=#$FFFFFFFF
				BRA		FINSCAN
			
	CONTSCAN:	BSR LEECAR
				CMP.L #-1,D0	*Buffer vacio, se ha terminado
				BEQ	FINSCAN1
				MOVE.B D0,(A1)+
				ADD.L #1,D4
				SUB.W #1,D3
				CMP.W #0,D3
				BNE   SCANBUC
				
	FINSCAN1:	MOVE.L	D4,D0	* Copiamos caracteres leídos a D0
	FINSCAN:	UNLK	A6
				RTS
				
				
**************************      PRINT      ***************************
*    Escritura en un dispositivo. Ordenara la escritura de un        *
*    bloque de caracteres por la linea correspondiente (A o B)       *
**********************************************************************

PRINT:		LINK	A6,#0	* Inicializo marco de pila para referenciar parámetros
			MOVE.L 	8(A6),A1	* Guardo en A1 dirección de Buffer, A1<-M(A6+8)
			MOVE.L	#0,D2		* Inicializacion D2 (D2<-#0)
			MOVE.L	#0,D3		* Inicializacion D3 (D3<-#0)
			MOVE.L	#0,D4		* Inicializacion D4 (D4<-#0)
			MOVE.W	12(A6),D2	* D2 <--- descriptor
			MOVE.W	14(A6),D3	* D3 <--- tamaño

	COMPDES:	CMP.W	#0,D2
				BEQ		COMPTAM1		* Si el descriptor=0, es linea A
				CMP.W	#1,D2
				BEQ		COMPTAM2		* Si descriptor=1, es linea B
				MOVE.L 	#$FFFFFFFF,D0	* Si codigo llega aqui, hay error en parametros
				BRA		FINPRINT
			

	COMPTAM1:	MOVE.L	#2,D0	* Ponemos D0=2 para llamada posterior a ESCCAR
				MOVE.L	#2,D6	* Indicacion para escritura posterior en IMR y COPIAIMR
				BRA		COMPTAM		* Salto para comprobar si tamaño=0
	
	COMPTAM2:	MOVE.L	#3,D0	* Ponemos D0=3 para llamada posterior a ESCCAR
				MOVE.L	#3,D6	* Indicacion para escritura posterior en IMR y COPIAIMR 
				BRA		COMPTAM		* Salto para comprobar si tamaño=0

	COMPTAM:	CMP.W	#0,D3
				BEQ		COMPCONT	*Si descriptor=0, salta a copmprobar contador de char
				MOVE.B	(A1)+,D1 	*Movemos valor de A1 en D1 y en memoria, A1=A1+1
				BSR		ESCCAR		*Saltamos a ESCCAR
				CMP.L	#-1,D0		
				BEQ		COMPCONT	*Si D0=0, salta a comprobar contador de char
				ADD.L	#1,D4		*Añadimos 1 al contador de char
				SUB.W	#1,D3		*Restamos 1 al tamaño de escritura
				BRA		COMPDES

	COMPCONT:	CMP.L	#0,D4			
				BEQ		FINPRIN2	*Si contador de char=0, saltamos al prefin
				MOVE.W	SR,D5		*D5<---SR
				MOVE.W	#$2700,SR	*SR<---2700
				CMP.L	#2,D6		
				BEQ		SALTOA		*Si D6=2, estamos en linea A
				BSET	#4,COPIAIMR	
				MOVE.B  COPIAIMR,IMR
				MOVE.W	D5,SR
				BRA		FINPRIN2
	
	SALTOA:		BSET	#0,COPIAIMR
				MOVE.B	COPIAIMR,IMR
				MOVE.W	D5,SR
				BRA 	FINPRIN2

	FINPRIN2:	MOVE.L 	D4,D0
	
	FINPRINT:	UNLK	A6
				RTS				

	
**************************      RTI      ****************************
*	La rutina  debe, entre otras identificar cuál de las cuatro     *
*	cuatro posibles condiciones ha generado la solicitud y despues	*
*	tratarla (dependiendo si es de recepcion o transmision).		*
*********************************************************************

RTI:		MOVEM.L D0-D1,-(A7)
	BUCLE1:	MOVE.B	ISR,D1
			AND.B 	COPIAIMR,D1
			BTST	#1,D1	* Recepción línea A (copia a Z el opuesto del bit)
			BNE		RXLA	* Si bit=1, Z=0, BNE salta si Z=0
			BTST	#5,D1	* Recepción línea B
			BNE		RXLB
			BTST	#0,D1	* Transmisión línea A1
			BNE 	TXLA
			BTST 	#4,D1	* Transmisión línea BEQ
			BNE		TXLB
			BRA		FINRTI
			
	RXLA:	MOVE.B	RBA,D1
			MOVE.L 	#0,D0
			BSR		ESCCAR	* Copia el caracter recibido al buffer interno de ScanA
			CMP.L 	#-1,D0	* Miramos si el buffer está lleno
			BEQ		FINRTI
			BRA		BUCLE1
			RTE
			
	RXLB:	MOVE.B	RBB,D1
			MOVE.L 	#1,D0
			BSR		ESCCAR	* Copia el caracter recibido al buffer interno de ScanB
			CMP.L 	#-1,D0	* Miramos si el buffer está lleno
			BEQ		FINRTI
			BRA		BUCLE1
			
	TXLA:	MOVE.L 	#2,D0
			BSR		LEECAR
			CMP.L	#-1,D0	* Buffer vacío, paramos
			BEQ		INHA
			MOVE.B	D0,TBA
			BRA		BUCLE1
			
	INHA:	BCLR	#0,COPIAIMR
			MOVE.B 	COPIAIMR,IMR
			BRA		BUCLE1
			
	TXLB:	MOVE.L 	#3,D0
			BSR		LEECAR
			CMP.L	#-1,D0	* Buffer vacío, paramos
			BEQ		INHB
			MOVE.B	D0,TBB
			BRA		BUCLE1
			
	INHB:	BCLR	#4,COPIAIMR
			MOVE.B 	COPIAIMR,IMR
			BRA		BUCLE1
			
	FINRTI:	MOVEM.L (A7)+,D0-D1			
			RTE

**************************      INICIO      *************************
*	La rutina  debe, entre otras identificar cuál de las cuatro     *
*	cuatro posibles condiciones ha generado la solicitud y despues	*
*	tratarla (dependiendo si es de recepcion o transmision).		*
*********************************************************************

BUFFER: DS.B 2100 * Buffer para lectura y escritura de caracteres
PARDIR: DC.L 0 * Direcci´on que se pasa como par´ametro
PARTAM: DC.W 0 * Tama~no que se pasa como par´ametro
CONTC: DC.W 0 * Contador de caracteres a imprimir
DESA: EQU 0 * Descriptor l´ınea A
DESB: EQU 1 * Descriptor l´ınea B
TAMBS: EQU 1 * Tama~no de bloque para SCAN
TAMBP: EQU 1 * Tama~no de bloque para PRINT

* Manejadores de excepciones
INICIO: MOVE.L #BUS_ERROR,8 * Bus error handler
		MOVE.L #ADDRESS_ER,12 * Address error handler
		MOVE.L #ILLEGAL_IN,16 * Illegal instruction handler
		MOVE.L #PRIV_VIOLT,32 * Privilege violation handler
		MOVE.L #ILLEGAL_IN,40 * Illegal instruction handler
		MOVE.L #ILLEGAL_IN,44 * Illegal instruction handler
	
		BSR INIT
		MOVE.W #$2000,SR * Permite interrupciones

BUCPR:  MOVE.W #TAMBS,PARTAM * Inicializa par´ametro de tama~no
	    MOVE.L #BUFFER,PARDIR * Par´ametro BUFFER = comienzo del buffer
OTRAL:  MOVE.W PARTAM,-(A7) * Tama~no de bloque
	    MOVE.W #DESA,-(A7) * Puerto A
		MOVE.L PARDIR,-(A7) * Direcci´on de lectura
ESPL: 	BSR SCAN
		ADD.L #8,A7 * Restablece la pila
		ADD.L D0,PARDIR * Calcula la nueva direcci´on de lectura
		SUB.W D0,PARTAM * Actualiza el n´umero de caracteres le´ıdos
		BNE OTRAL * Si no se han le´ıdo todas los caracteres
				  * del bloque se vuelve a leer

		MOVE.W #TAMBS,CONTC * Inicializa contador de caracteres a imprimir
		MOVE.L #BUFFER,PARDIR * Par´ametro BUFFER = comienzo del buffer
OTRAE:  MOVE.W #TAMBP,PARTAM * Tama~no de escritura = Tama~no de bloque
ESPE:   MOVE.W PARTAM,-(A7) * Tama~no de escritura
		MOVE.W #DESB,-(A7) * Puerto B
		MOVE.L PARDIR,-(A7) * Direcci´on de escritura
		BSR PRINT
		ADD.L #8,A7 * Restablece la pila
		ADD.L D0,PARDIR * Calcula la nueva direcci´on del buffer
		SUB.W D0,CONTC * Actualiza el contador de caracteres
		BEQ SALIR * Si no quedan caracteres se acaba
		SUB.W D0,PARTAM * Actualiza el tama~no de escritura
		BNE ESPE * Si no se ha escrito todo el bloque se insiste
		CMP.W #TAMBP,CONTC * Si el no de caracteres que quedan es menor que
						   * el tama~no establecido se imprime ese n´umero
		BHI OTRAE * Siguiente bloque
		MOVE.W CONTC,PARTAM
		BRA ESPE * Siguiente bloque

SALIR:  BRA BUCPR

BUS_ERROR: BREAK * Bus error handler
		   NOP
ADDRESS_ER: BREAK * Address error handler
			NOP
ILLEGAL_IN: BREAK * Illegal instruction handler
			NOP
PRIV_VIOLT: BREAK * Privilege violation handler
			NOP