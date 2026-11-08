#include <u.h>
#include <libc.h>

/*
 * smokesleep — the amd64 exec marker (14-05, D-09): the FIRST Harvey
 * x86_64 binary exec'd on r9 through the real EL/SYSCALL path, staged
 * at /amd64/init (the q35exec BOOT_ENTRY target).  The aarch64
 * smokesleep discipline re-keyed: minimal libc surface, one syscall
 * path, prints that the boot-test gate asserts — and every print is
 * the binary's OWN pwrite from ring 3, never a kernel print on its
 * behalf (the gate's whole point).  The flow exercises the ABI's
 * note-delivery convention the amd64/ABI.md freezes: notify() installs
 * the handler (its ureg arg0 arrives through the bp path), alarm(300)
 * arms the alarm note, sleep(30000) parks — the tick's alarm-expiry
 * arm posts "alarm" at +300ms, the note-interruptible sys_sleep wakes
 * early and fails -1 with errstr "interrupted" (the donor tsleep
 * shape), and the note delivers at the syscall's return-to-ring-3
 * boundary: the handler prints it, sets the flag, and resumes main via
 * noted(NCONT).  main then prints the terminal marker
 * ("smokesleep: interrupted") and exits nil.  Any other outcome (the
 * sleep expiring, a missing delivery) prints the loud failure line and
 * exits "sleep-not-interrupted" so a regression is definitive in the
 * boot-test capture (the harness's overall timeout is the outer net).
 */

static int noteflag;

/*
 * The flag read must go through a real call: 6c caches a plain static
 * load in a register across straight-line code (even volatile), so the
 * handler's store would never be observed.  Plan 9 compilers never
 * inline C functions, so seen() reloads noteflag from memory every call.
 * (The aarch64 smokesleep/smokenote trick, carried verbatim.)
 */
static int
seen(void)
{
	return noteflag;
}

void
handler(void *ureg, char *msg)
{
	if(ureg == nil){
		print("smokesleep: nil ureg\n");
		noted(NDFLT);
	}
	print("smokesleep: got note %s\n", msg);
	noteflag = 1;
	noted(NCONT);
}

void
main(int, char*[])
{
	long r;

	if(notify(handler) < 0){
		print("smokesleep: notify failed: %r\n");
		exits("notify-fail");
	}
	alarm(300);
	r = sleep(30000);
	if(r < 0 && seen()){
		print("smokesleep: interrupted\n");
		exits(nil);
	}
	print("smokesleep: NOT interrupted (r=%ld seen=%d): %r\n", r, seen());
	exits("sleep-not-interrupted");
}
