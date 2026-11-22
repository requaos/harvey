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
