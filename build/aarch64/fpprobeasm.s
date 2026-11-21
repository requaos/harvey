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
