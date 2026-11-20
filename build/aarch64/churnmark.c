#include <u.h>
#include <libc.h>

/*
 * churnmark — the arm64 churn loop's exec payload (20-09, D-08's arm64
 * churn gate; the build/x86_64/churnmark.c twin): the whole point is
 * the exec ITSELF (fork+exec churn at WINDOWS #44's ~1400-iteration
 * repro shape), so the binary does the minimum a real Plan 9 program
 * does and gets OUT — one print through the real pwrite path (each
 * print is the binary's OWN write from EL0; the count post-pass in the
 * r9 xtask virtchurn gate counts these lines to prove every iteration
 * entered EL0), then exits nil.  No alarm, no sleep: smokesleep spends
 * ~300ms parked per copy, which a 1400-deep loop cannot afford.  r9's
 * `cargo xtask initrd` bakes it as /churnmark beside /init.
 */
void
main(int, char*[])
{
	print("churnmark: ready\n");
	exits(nil);
}
