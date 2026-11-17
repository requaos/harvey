TEXT memset(SB), $0
	MOVBU	c+8(FP), R1
	/* D-14 reconcile: Harvey's libc.h declares memset(void*, int, ulong)
	 * with 32-bit ulong; 9front's usize is 64-bit and this load was MOV
	 * (64-bit), reading garbage in the high half of the slot -> runaway
	 * loop (02-05 gate: fault write at USTKTOP). MOVWU reads the slot
	 * as stored by callers of Harvey's prototype. */
	MOVWU	n+16(FP), R2

	MOV	R0, R5
	ADD	R0, R2, R3
	BIC	$15, R2, R4
	CBZ	R4, _loop1
	ADD	R0, R4, R4

	ORR	R1<<8, R1
	ORR	R1<<16, R1
	ORR	R1<<32, R1

_loop16:
	MOVP	R1, R1, (R5)16!
	CMP	R4, R5
	BNE	_loop16

_loop1:
	CMP	R3, R5
	BEQ	_done

	MOVBU	R1, (R5)1!
	B	_loop1

_done:
	RETURN
