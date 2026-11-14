#include <u.h>
#include <libc.h>

/*
 * randread — the 18-01 q35auth substrate marker (AUTH-02/D-05+D-07,
 * the smokesleep/churnmark lineage): staged at /amd64/init of the
 * SUBSTRATE image (mkimage's substrate bake — the D-08 leg-1 rule,
 * per-image: this image's marker is the entropy-read driver), the
 * first exec proves live /dev/random reads from ring 3 on the re-keyed
 * DRBG.  Two 64-byte reads: each must land full-length, and the pair
 * must differ in at least one byte — the D-07 distinctness evidence
 * (the DRBG's per-read counter advance + jitter mix make identical
 * consecutive reads a substrate bug, never gate noise).  Every print
 * is the binary's OWN write from ring 3, never a kernel print on its
 * behalf (the D-09 discipline).  18-02's devcap legs extend this
 * driver; the substrate: FAIL family is the fail-fast the xtask gate
 * aborts on.  No statistical battery (explicitly declined — D-07:
 * distinctness + the boot-facts armed-source line are the pinned
 * evidence).
 *
 * The open uses the DEVICE-DIRECT form #c/random (boot(8)'s own
 * readenv("#c/user") idiom): this marker runs as the FIRST exec,
 * before any bind builds a namespace — /dev in the paqfs root is an
 * empty stub dir, so the plain path would ENOENT.  #c/random IS
 * /dev/random, same qid, same DRBG (devcons serves it
 * unconditionally).
 */
enum {
	Nbytes = 64,
};

void
main(int, char*[])
{
	uchar a[Nbytes], b[Nbytes];
	int fd, n, i, same;

	fd = open("#c/random", OREAD);
	if(fd < 0){
		print("substrate: FAIL random open: %r\n");
		exits("random-open");
	}
	n = readn(fd, a, sizeof a);
	if(n != sizeof a){
		print("substrate: FAIL random read a n=%d: %r\n", n);
		exits("random-read");
	}
	n = readn(fd, b, sizeof b);
	if(n != sizeof b){
		print("substrate: FAIL random read b n=%d: %r\n", n);
		exits("random-read");
	}
	same = 1;
	for(i = 0; i < Nbytes; i++)
		if(a[i] != b[i])
			same = 0;
	if(same){
		print("substrate: FAIL random reads identical\n");
		exits("random-identical");
	}
	print("random: READS-OK\n");
	print("substrate: DONE\n");
	exits(nil);
}
