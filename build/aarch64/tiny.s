// tiny.s — 7a execution-evidence stub (06-06, RESEARCH OQ-2).  The
// canary's 7c -FTVw emits .7 directly (no separate 7a run), so the
// assembler gets its own explicit input: staged as bootdir data and
// assembled in-guest by /boot/h7a in the writable /tmp scratch; the
// marker is the produced tiny.7.
TEXT	·main(SB), 0, $0
	RETURN
