/*
 * fpprobeasm.s — fpprobe's register helpers (r9 x86_64 user FPU/SSE
 * state probe).  The whole user-visible FPU/SSE state (x87, MMX,
 * XMM0-15, MXCSR) moves as one FXSAVE image; FXSAVE64/FXRSTOR64 are
 * hand-encoded with BYTE (6a has no mnemonic for them).  The buffer
 * pointer arrives in BP (6c's REGARG); the image must be 16-byte
 * aligned.
 */

/* fpload(b): FXRSTOR64 the image at b, then FXSAVE64 it back (so bits
 * the hardware does not keep drop out of the expected image) */
TEXT	fpload(SB), 1, $0
	BYTE	$0x48	/* fxrstor64 0(BP) */
	BYTE	$0x0f
	BYTE	$0xae
	BYTE	$0x4d
	BYTE	$0x00
	BYTE	$0x48	/* fxsave64 0(BP) */
	BYTE	$0x0f
	BYTE	$0xae
	BYTE	$0x45
	BYTE	$0x00
	RET

/* fpstore(b): FXSAVE64 the live state into b */
TEXT	fpstore(SB), 1, $0
	BYTE	$0x48	/* fxsave64 0(BP) */
	BYTE	$0x0f
	BYTE	$0xae
	BYTE	$0x45
	BYTE	$0x00
	RET

/*
 * gprspin(b): the note leg's register round.  Load a sentinel into every
 * general register the probe may use (AX BX CX DX SI DI R8-R12; BP holds
 * b, R13 counts down; R14/R15 are 6c's extern registers and SP is the
 * stack), spin until the note handler sets b[0] (or R13 runs out), then
 * store the registers to b[1..12] for the C side to compare.  CX and R11
 * are the pair SYSRET overwrites (rip, rflags), so a NOTED that returned
 * through SYSRET instead of IRETQ shows up here.
 */
TEXT	gprspin(SB), 1, $0
	MOVQ	$0x1111111111111101, AX
	MOVQ	$0x1111111111111102, BX
	MOVQ	$0x1111111111111103, CX
	MOVQ	$0x1111111111111104, DX
	MOVQ	$0x1111111111111105, SI
	MOVQ	$0x1111111111111106, DI
	MOVQ	$0x1111111111111108, R8
	MOVQ	$0x1111111111111109, R9
	MOVQ	$0x111111111111110a, R10
	MOVQ	$0x111111111111110b, R11
	MOVQ	$0x111111111111110c, R12
	MOVQ	$0x80000000, R13
spin:
	CMPQ	0(BP), $0
	JNE	done
	DECQ	R13
	JNE	spin
done:
	MOVQ	AX, 8(BP)
	MOVQ	BX, 16(BP)
	MOVQ	CX, 24(BP)
	MOVQ	DX, 32(BP)
	MOVQ	SI, 40(BP)
	MOVQ	DI, 48(BP)
	MOVQ	R8, 56(BP)
	MOVQ	R9, 64(BP)
	MOVQ	R10, 72(BP)
	MOVQ	R11, 80(BP)
	MOVQ	R12, 88(BP)
	MOVQ	R13, 96(BP)
	RET
