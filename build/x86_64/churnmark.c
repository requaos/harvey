#include <u.h>
#include <libc.h>

/*
 * churnmark — the 17-02 churn loop's exec payload (D-06 tier (a), the
 * smokesleep lineage): the whole point is the exec ITSELF (fork+exec
 * churn at WINDOWS #44's ~1400-iteration repro shape), so the binary
 * does the minimum a real Plan 9 program does and gets OUT — one print
 * through the real pwrite path (each print is the binary's OWN write
 * from ring 3, the D-09 discipline; the count post-pass in the xtask
 * gate counts these lines to prove every iteration entered ring 3),
 * then exits nil.  No alarm, no sleep: the 14-09 smokesleep marker
 * spends ~300ms parked per copy (the note-interruption path it exists
 * to exercise), which a 1400-deep loop cannot afford; the churn
 * profile stages BOTH and /amd64/init keeps its smokesleep meaning.
 */
void
main(int, char*[])
{
	print("churnmark: ready\n");
	exits(nil);
}
