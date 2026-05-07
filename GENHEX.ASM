;
;***************************************************************
;*       UPLOAD COM FILE TO INTEL MDS                          *
;*       WRITTEN BY MARC BUFFET 2026                          *
;*       PUBLIC DOMAIN SOFTWARE                                *
;***************************************************************
;
;

REBOOT	EQU		0			; Warm Boot
BDOS	EQU		5			; the work horse
;
CONIN	EQU		1			; Console input
CONOUT	EQU		2			; console output
OPENF	EQU		15			; open file
CLOSEF	EQU		16			; close file
DELETEF	EQU		19			; delete file
READS	EQU		20			; read sequential
WRITES	EQU		21			; write sequential
MAKEF	EQU		22			; create file
SETDMA	EQU		26			; set DMA transfer address
;
FCB		EQU		005CH		; Default FCB
TPA		EQU		0100H		; Default TPA start address
;
CR		EQU		13			
LF		EQU		10
;
		ORG		TPA
;
;				
;---------------------------------------------------------------------------
;       DUMP COM FILE AS INTEL MDS INTO OUTUT FILE
;---------------------------------------------------------------------------
;
GO:		LXI		SP,STACK	; Local stack
		CALL	USTEXT		; signon	
		DB		"GENHEX - FILE -> INTEL HEX Ver 1.0 07/05/2026",0
;
		MVI		C,12		; copy filename.ext length + drive
		LXI		H,FCB		; from default FCB
		LXI		D,INPFCB	; to file input FCB
GO00:	MOV		A,M			; get a byte
		STAX	D			; store it
		INX		H			; increment
		INX		D			; both index
		DCR		C			; decrement count
		JNZ		GO00		; again until all done
;
		MVI		C,9			; copy filename + drive length
		LXI		H,FCB		; from default FCB
		LXI		D,HEXFCB	; to output FCB	
GO01:	MOV		A,M			; get a byte
		STAX	D			; store it
		INX		H			; bump both
		INX		D			; index
		DCR		C			; decrement counter
		JNZ		GO01		; until all done	
;
		MVI		C,OPENF		; open the
		LXI		D,INPFCB	; input file
		CALL	BDOS		;
		INR		A			; test if OK ?
		JNZ		GO02		; OK go on
;
		CALL	GHTEXT		; report error
		DB		"Unable to open input file",0
		JMP		REBOOT		; exit
;
GO02:	MVI		C,DELETEF	; delete output file
		LXI		D,HEXFCB	;	
		CALL	BDOS		;
		
		MVI		C,MAKEF		; create new output file
		LXI		D,HEXFCB	; output file FCB	
		CALL	BDOS		;		
		INR		A			; is it 255 ?
		JNZ		GO03		; no then OK
;
		CALL	GHTEXT		; else display
		DB		"Unable to create output file",0
		JMP		REBOOT		; and exit	
;
GO03:	XRA		A			; clear acu
		STA		WRPTR		; clear write pointer
		STA		RDPTR		; clear read pointer
		LXI		H,TPA		; start of ddress for HEX file
		SHLD	HEXADR		; at storage location	
		LXI		H,0			; clear
		SHLD 	RECWR		; write record counter
		SHLD 	RECRD		; read record counter

;-----------------------------------------------------------------------
;       READ FILE AND DUMP IN HEX
;-----------------------------------------------------------------------
;
WRTHX:	CALL	GHTEXT		; tell job is started
		DB		"Starting conversion.",0
		LXI		D,RDBUFFER
		MVI		C,SETDMA	; set DMA
		CALL	BDOS		; for bdos	
		LHLD	RECRD		; Get record counter
		INX		H			; increment
		SHLD	RECRD		; save again
		LXI		D,INPFCB	; inut file
		MVI		C,READS		; read sequential
		CALL	BDOS		; the open file
		INR		A			; OK ?
		JZ		REBOOT		; No error
		
WRTHX0:	LDA		RDPTR		; get local buffer
		CPI		128
		JNZ		WRTHX1		; no go on	
;		
		XRA		A			; clear ACU
		STA		RDPTR		; to reset read pointer
		
		LXI		D,RDBUFFER	; point to file read buffer
		MVI		C,SETDMA	; set DMA
		CALL	BDOS		; for bdos	
		LHLD	RECRD		; Get record counter
		INX		H			; increment
		SHLD	RECRD		; save again
		LXI		D,INPFCB	; point to input file
		MVI		C,READS		; read next record
		CALL	BDOS		; via bdos
		CPI		0			; OK ?
		JNZ		WRTHX3		; NO end of file

WRTHX1:	MVI     C,':'		; start hex dump
		CALL	USHOUT		;
		XRA		A			; clear crc
		STA		CRC			;
		MVI     A,32		; 20 hex bytes / line
		CALL    HXPOUT      ; output record length
		LHLD    HEXADR		; HEX dump address pointer
		MOV     A,H
		CALL    HXPOUT      ; output address high
		MOV     A,L
		CALL    HXPOUT      ; output addresss low
		MVI     A,0
		CALL    HXPOUT      ; output record type
		MVI     A,32        ; setup counter
		STA		COUNT		; store
WRTHX2:	LXI		H,RDBUFFER	; point to read buffer
		LDA		RDPTR		; get read pointer
		MOV		E,A			; to E
		MVI		D,0			; D to 0
		DAD		D			; Add to have byte pointer
		INR		A			; increment count
		STA		RDPTR		; store again	
		MOV     A,M			; Get byte from buffer
		CALL    HXPOUT      ; output byte
		LDA		COUNT		; get count
		DCR		A			; decrementy
		STA		COUNT		; store again
		CPI		0			; at end of the line ?
		JNZ     WRTHX2      ; loop until 20 bytes done
		LDA     CRC			; get that CRC
		CMA					; complement
		INR     A			; increment by 1
		CALL    HXPOUT      ; output crc byte
		MVI     C,13        ; and new line
		CALL    USHOUT      ; as carriage return
		MVI     C,10        ; and linefeed
		CALL    USHOUT		;
		LHLD	HEXADR		; get hex address 
		LXI		D,20H		; add 32 for next line
		DAD		D			; 
		SHLD	HEXADR		; save again
		JMP     WRTHX0		; next record
;
WRTHX3:	CALL    USHTEXT      ; send eof record
		DB      ':00000001FF',13,10,26,0
		
WRTHX4:	LXI		H,WRBUFFER	; point to write buffer
		LDA		WRPTR		; get pointer
		CPI		128			; at end of buffer
		JZ		WRTHX5		; yes
		MOV		E,A			; get position offset
		INR		A			; increment already
		STA		WRPTR		; store again
		MVI		D,0			; D to 0
		DAD		D			; calculate offset
		MVI		M,255		; fill up the buffer with 255	
		JMP		WRTHX4		; till end of it
WRTHX5:	LXI		D,WRBUFFER	; ok point to write buffer
		MVI		C,SETDMA	; set DMA	
		CALL	BDOS		;
;		
		LHLD	RECWR		; Get record counter
		INX		H			; increment
		SHLD	RECWR		; save again
		MVI		C,WRITES	; write last record
		LXI		D,HEXFCB	; to output file	
		CALL	BDOS		;	
		INR		A			; OK ?
		JNZ		WRTHX6
		CALL	GHTEXT		; report error
		DB		"Unable to write the output file",0
		JMP		REBOOT
		
WRTHX6:	MVI		C,CLOSEF	; close the
		LXI		D,INPFCB	; input file
		CALL	BDOS		;
		INR		A
		JNZ		WRTHX7
;
		CALL	GHTEXT		; stupid but is provided
		DB		"Unable to close input file",0
		JMP		REBOOT
;		
WRTHX7:	MVI		C,CLOSEF	; close the
		LXI		D,HEXFCB	; output file
		CALL	BDOS		;
		INR		A			; 255 error ?
		JNZ		WRTHX8		; no it is OK
		CALL	GHTEXT		; else report error
		DB		"Unable to close output file",0
		JMP		REBOOT
;
WRTHX8:	CALL	GHTEXT		; signoff
		DB		"Conversion completed.",0
		CALL	GHTEXT
		DB		"  First address : 0x0100",0
		CALL	GHTEXT
		DB		"   Last address : 0x",0
		LHLD	HEXADR		; get latest HEx record start address
		DCX		H			; last byte line before
		CALL	HLOUT		; output this address	
		CALL	GHTEXT		; report
		DB		"Records written : ",0
		LHLD	RECWR		; written records
		CALL	DECOUT
		CALL	GHTEXT		; report
		DB		"   Records read : ",0
		LHLD	RECRD		; read records
		CALL	DECOUT		;		
;		
		JMP		REBOOT		; and Warm Boot


;
;-----------------------------------------------------------------------------
;       HEX BYTE OUT TO PORT  AND UPDATE CRC
;-----------------------------------------------------------------------------
;
HXPOUT: PUSH    PSW			; save value
		MOV     C,A			; to c
		LDA     CRC			; get crc
		ADD     C			; add new byte
		STA     CRC			; save back
		MOV     A,C			; get back byte
		RLC
		RLC			
		RLC
		RLC
		CALL    HXOUT1		; output to port
		POP     PSW			; get back value
HXOUT1:	ANI     15			; get left byte
		ADI     '0'         ; make digit 0 - 9
		CPI     '9'+1
		MOV     C,A         ; to c
		JC      USHOUT
		ADI     7           ; adjust for a - f
		MOV     C,A         ; to e
		JMP     USHOUT      ; GO ECHO IT
;
;------------------------------------------------------------------------------
;       CHARACTER  TO CONSOLE
;------------------------------------------------------------------------------
;
USOUT:	PUSH	B			; To be shure
		PUSH	D			; save all registers 
		PUSH	H			; :-)
		MOV		E,C			; char to E
		MVI		C,CONOUT	; tell Char Out	
		CALL	BDOS		; work bdos ....
		POP		H			; restore 
		POP		D
		POP		B
		RET
;
;------------------------------------------------------------------------------
;       CHARACTER IN C TO OUTPUT FILE
;------------------------------------------------------------------------------
;
USHOUT:	PUSH	B			; To be shure
		PUSH	D			; save all registers 
		PUSH	H			; :-)
		LXI		H,WRBUFFER	; point to file
		LDA		WRPTR		;  get pointer
		MOV		E,A			; to DE
		MVI		D,0			; D=0 
		DAD		D			; add offset
		MOV		M,C			; move byte to buffer
		INR		A			; bump index
		STA		WRPTR		; save again
		CPI		128			; is it at end of record ?
		JZ		USHOUT1		; yes process
		POP		H			; restore 
		POP		D
		POP		B
		RET
		
USHOUT1:XRA		A			; clear ACU
		STA		WRPTR		; clear the pointer	
		LXI		D,WRBUFFER	; point to file buffer
		MVI		C,SETDMA	; set DMA	
		CALL	BDOS		;
		LHLD	RECWR		; Get record counter
		INX		H			; increment
		SHLD	RECWR		; save again
		LXI		D,HEXFCB	; select output FCB
		MVI		C,WRITES	; write sequential	
		CALL	BDOS		;
		ORA		A
		JZ		USHOUT2	
		CALL	GHTEXT		; disk full error
		DB		"Disk full error.",0	
		JMP		REBOOT
USHOUT2:POP		H			; restore 
		POP		D
		POP		B
		RET
;
;
;------------------------------------------------------------------------------
;       TEXT TO CONSOLE
;------------------------------------------------------------------------------
;
GHTEXT:	CALL	USTEXT		; print BIOS error Read
		DB		CR,LF,"GENHEX: ",0
USTEXT: XTHL				; get string address
UTXT1: 	MOV     A,M			; get byte from it
		ORA     A			; test if eos
		JZ      UTXT2		; ok end of string
		MOV     C,A			; to c
		CALL    USOUT		; output it
		INX     H			; pointer++
		JMP     UTXT1		; jump on
UTXT2:	INX     H			; adjust for return
		XTHL				; reset return address
		RET					; go on
;
;------------------------------------------------------------------------------
;       TEXT TO OUTPUT FILE
;------------------------------------------------------------------------------
;
USHTEXT:XTHL				; get string address
UHTXT1: MOV     A,M			; get byte from it
		ORA     A			; test if eos
		JZ      UHTXT2		; ok end of string
		MOV     C,A			; to c
		CALL    USHOUT		; output it
		INX     H			; pointer++
		JMP     UHTXT1		; jump on
UHTXT2:	INX     H			; adjust for return
		XTHL				; reset return address
		RET					; go on
;
;-----------------------------------------------------------------------
; DISPLAY HL IN HEXIDECIMAL
;-----------------------------------------------------------------------
;
HLOUT:  MOV		A,H             ; Get HIGH byte 
        CALL    HPR             ; Output
        MOV     A,L             ; Get LOW byte
		CALL	HPR
		RET
		
;-----------------------------------------------------------------------------
;       HEX BYTE OUT TO PORT  
;-----------------------------------------------------------------------------
;
HPR:	PUSH    PSW			; SAVE VALUE
		RLC
		RLC			
		RLC
		RLC
		CALL    HPR1		; OUTPUT TO PORT
		POP     PSW			; GET BACK VALUE
HPR1:	ANI     15			; GET LEFT BEET
		ADI     '0'         ; MAKE DIGIT 0 - 9
		CPI     '9'+1
		MOV     C,A         ; TO C
		JC      USOUT
		ADI     7           ; ADJUST FOR A - F
		MOV     C,A         ; TO E
		JMP     USOUT      	; GO ECHO IT
;
;
;-----------------------------------------------------------------------
; ** BINAIR TO ASCII  5 DIGITS IN HL
;-----------------------------------------------------------------------
;
DECOUT:			MVI		B,80H				; flag to no print
				LXI		D,-10000			; setup 10000
				CALL	DECNO				; see how many
				LXI		D,-1000				; setup 1000
				CALL	DECNO				; see howmany
				LXI		D,-100				; setup 100
				CALL	DECNO				; see how many
				LXI		D,-10				; setup 10
				CALL	DECNO				; see howmany
				MVI		B,0					; clear inhibit print flag
				LXI		D,-1				; setup 1
DECNO:			INR		B					; see howmany
				DAD		D					; substract it
				JC		DECNO				; carry ?
				DCR		B					; yes adjust count
				XCHG						; to de
				XRA		A					; clear carry clear acu
				SUB		L					; substarct l
				MOV		L,A					; save l
				MVI		A,0					; save carry but a to 0
				SBB		H					; substract h
				MOV		H,A					; save h
				XCHG						; back to hl
				DAD		D					; readd
				MOV		A,B					; get no print flag
				CPI		80H					; still set
				RZ							; yes then return
				MOV		A,B					; get flag
				ANI		7FH					; mask out flag
				ORI		'0'					; make ascii  
				PUSH	H					; save hl
				MOV		C,A	
				CALL	USOUT				; echo it
				POP		H					; restore hl
				MVI		B,0					; disable flag now
				RET	
;
;
;----------------------------------------------------------------------
;		STORAGE AREA AND STACK
;----------------------------------------------------------------------
;
;
COUNT:		DB		0		; HEX byte line lngth counter
CRC:		DB		0		; the CRC
HEXADR:		DW		0		; Output HEX file address
RECWR:		DW		0		; output file record counter
RECRD:		DW		0		; input file record counter
;
HEXFCB:     DB      0       ; Default drive/alternate drive
HEXFCBF:    DS      8,'?'   ; Filename
HEXFCBE:    DB      'HEX'   ; Extension
            DS      2,0     ; BDOS work area
            DS      16,0
HEXFCBR:    DB      0,0,0   ; Record number
;  
INPFCB:     DB      0       ; Default drive/alternate drive
INPFCBF:    DS      8,'?'   ; Filename
INPFCBE:    DS      3,'?'   ; Extension
            DS      2,0     ; BDOS work area
            DS      16,0
INPFCBR:    DB      0,0,0   ; Record number


WRPTR:		DS		1		; write pointer
WRBUFFER:	DS		128    	; write buffer
RDPTR:		DS		1		; read pointer
RDBUFFER:	DS		128     ; write pointer		
;			
			DS		64		; stack area
STACK		EQU		$
;
			END		0		
;
