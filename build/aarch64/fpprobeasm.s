/*
 * fpprobeasm.s — fpprobe's register helpers (r9 aarch64 user FP/SIMD
 * state probe).  Hand-encoded with WORD: the instructions are the
 * 128-bit q-register pair moves and the FPCR/FPSR system register
 * moves, which no compiled code in the probe emits.  Leaf routines,
 * no frame; the buffer pointer arrives in R0 and R1 is the scratch.
 *
 * Buffer layout (66 words, 16-byte aligned): q0..q31 as 32 pairs of
 * words (low word first), then fpcr at word 64 and fpsr at word 65.
 */

/* fpload(b): q0..q31, fpcr, fpsr <- b; then fpcr, fpsr read back into b[64], b[65] */
TEXT	fpload(SB), 1, $-4
	WORD	$0xad400400	/* ldp q0, q1, [x0] */
	WORD	$0xad410c02	/* ldp q2, q3, [x0, #0x20] */
	WORD	$0xad421404	/* ldp q4, q5, [x0, #0x40] */
	WORD	$0xad431c06	/* ldp q6, q7, [x0, #0x60] */
	WORD	$0xad442408	/* ldp q8, q9, [x0, #0x80] */
	WORD	$0xad452c0a	/* ldp q10, q11, [x0, #0xa0] */
	WORD	$0xad46340c	/* ldp q12, q13, [x0, #0xc0] */
	WORD	$0xad473c0e	/* ldp q14, q15, [x0, #0xe0] */
	WORD	$0xad484410	/* ldp q16, q17, [x0, #0x100] */
	WORD	$0xad494c12	/* ldp q18, q19, [x0, #0x120] */
	WORD	$0xad4a5414	/* ldp q20, q21, [x0, #0x140] */
	WORD	$0xad4b5c16	/* ldp q22, q23, [x0, #0x160] */
	WORD	$0xad4c6418	/* ldp q24, q25, [x0, #0x180] */
	WORD	$0xad4d6c1a	/* ldp q26, q27, [x0, #0x1a0] */
	WORD	$0xad4e741c	/* ldp q28, q29, [x0, #0x1c0] */
	WORD	$0xad4f7c1e	/* ldp q30, q31, [x0, #0x1e0] */
	WORD	$0xf9410001	/* ldr x1, [x0, #0x200] */
	WORD	$0xd51b4401	/* msr fpcr, x1 */
	WORD	$0xf9410401	/* ldr x1, [x0, #0x208] */
	WORD	$0xd51b4421	/* msr fpsr, x1 */
	WORD	$0xd53b4401	/* mrs x1, fpcr */
	WORD	$0xf9010001	/* str x1, [x0, #0x200] */
	WORD	$0xd53b4421	/* mrs x1, fpsr */
	WORD	$0xf9010401	/* str x1, [x0, #0x208] */
	RETURN

/* fpstore(b): b <- q0..q31, fpcr, fpsr */
TEXT	fpstore(SB), 1, $-4
	WORD	$0xad000400	/* stp q0, q1, [x0] */
	WORD	$0xad010c02	/* stp q2, q3, [x0, #0x20] */
	WORD	$0xad021404	/* stp q4, q5, [x0, #0x40] */
	WORD	$0xad031c06	/* stp q6, q7, [x0, #0x60] */
	WORD	$0xad042408	/* stp q8, q9, [x0, #0x80] */
	WORD	$0xad052c0a	/* stp q10, q11, [x0, #0xa0] */
	WORD	$0xad06340c	/* stp q12, q13, [x0, #0xc0] */
	WORD	$0xad073c0e	/* stp q14, q15, [x0, #0xe0] */
	WORD	$0xad084410	/* stp q16, q17, [x0, #0x100] */
	WORD	$0xad094c12	/* stp q18, q19, [x0, #0x120] */
	WORD	$0xad0a5414	/* stp q20, q21, [x0, #0x140] */
	WORD	$0xad0b5c16	/* stp q22, q23, [x0, #0x160] */
	WORD	$0xad0c6418	/* stp q24, q25, [x0, #0x180] */
	WORD	$0xad0d6c1a	/* stp q26, q27, [x0, #0x1a0] */
	WORD	$0xad0e741c	/* stp q28, q29, [x0, #0x1c0] */
	WORD	$0xad0f7c1e	/* stp q30, q31, [x0, #0x1e0] */
	WORD	$0xd53b4401	/* mrs x1, fpcr */
	WORD	$0xf9010001	/* str x1, [x0, #0x200] */
	WORD	$0xd53b4421	/* mrs x1, fpsr */
	WORD	$0xf9010401	/* str x1, [x0, #0x208] */
	RETURN

/*
 * gprspin(b): the note leg's register round.  Load a sentinel into
 * R1-R16 and R19-R23 (R0 holds b; R17 is the linker's temporary, R18
 * the platform register, R24 counts down, R25 takes the flag, R26-R28
 * are 7c's extern registers and SB), spin until the note handler sets
 * b[0] (or R24 runs out), then store the registers to b[1..21] for the
 * C side to compare: noted(NCONT) after an asynchronous note must give
 * every one of them back.
 */
TEXT	gprspin(SB), 1, $-4
	MOV	$0x1111111111111101, R1
	MOV	$0x1111111111111102, R2
	MOV	$0x1111111111111103, R3
	MOV	$0x1111111111111104, R4
	MOV	$0x1111111111111105, R5
	MOV	$0x1111111111111106, R6
	MOV	$0x1111111111111107, R7
	MOV	$0x1111111111111108, R8
	MOV	$0x1111111111111109, R9
	MOV	$0x111111111111110a, R10
	MOV	$0x111111111111110b, R11
	MOV	$0x111111111111110c, R12
	MOV	$0x111111111111110d, R13
	MOV	$0x111111111111110e, R14
	MOV	$0x111111111111110f, R15
	MOV	$0x1111111111111110, R16
	MOV	$0x1111111111111113, R19
	MOV	$0x1111111111111114, R20
	MOV	$0x1111111111111115, R21
	MOV	$0x1111111111111116, R22
	MOV	$0x1111111111111117, R23
	MOV	$0x80000000, R24
spin:
	MOVW	(R0), R25
	CBNZ	R25, done
	SUB	$1, R24
	CBNZ	R24, spin
done:
	MOV	R1, 8(R0)
	MOV	R2, 16(R0)
	MOV	R3, 24(R0)
	MOV	R4, 32(R0)
	MOV	R5, 40(R0)
	MOV	R6, 48(R0)
	MOV	R7, 56(R0)
	MOV	R8, 64(R0)
	MOV	R9, 72(R0)
	MOV	R10, 80(R0)
	MOV	R11, 88(R0)
	MOV	R12, 96(R0)
	MOV	R13, 104(R0)
	MOV	R14, 112(R0)
	MOV	R15, 120(R0)
	MOV	R16, 128(R0)
	MOV	R19, 136(R0)
	MOV	R20, 144(R0)
	MOV	R21, 152(R0)
	MOV	R22, 160(R0)
	MOV	R23, 168(R0)
	RETURN
