#include <u.h>
#include <libc.h>

/*
 * smokenote — SC#4's notes smoke (phase 04-08, D-16), exec'd by the
 * staged init on r9.  notify() installs the handler, then a bounded
 * pure-compute spin (NO sleep — alarm is unimplemented) waits for the
 * parent's postnote(PNPROC, pid, "smoke") — a libc write to
 * /proc/pid/note through devproc-lite.  The kernel delivers at the next
 * return-to-EL0 boundary: pc redirected to the handler, the saved ureg
 * and the note string pushed on the user stack.  The handler prints the
 * message, sets the flag, and resumes the spin via noted(NCONT); main
 * then prints the resume marker and exits "note-ok".  A spin ceiling
 * exits "note-timeout" so a broken delivery fails loudly in the log
 * instead of hanging the boot-test profile (the harness's overall
 * timeout is the outer net).
 */

static int notedflag;

/*
 * The flag read must go through a real call: 7c caches a plain static
 * load in a register across the spin loop (even volatile), so the
 * handler's store would never be observed.  Plan 9 compilers never
 * inline C functions, so seen() reloads notedflag from memory every
 * iteration.
 */
static int
seen(void)
{
	return notedflag;
}

void
handler(void *ureg, char *msg)
{
	if(ureg == nil){
		print("smokenote: nil ureg\n");
		noted(NDFLT);
	}
	print("smokenote: got note %s\n", msg);
	notedflag = 1;
	noted(NCONT);
}

void
main(int, char*[])
{
	uvlong v;

	if(notify(handler) < 0){
		print("smokenote: notify failed: %r\n");
		exits("notify-fail");
	}
	for(v = 0; v < 500000000; v++){
		if(seen()){
			print("smokenote: resumed\n");
			exits("note-ok");
		}
	}
	exits("note-timeout");
}
