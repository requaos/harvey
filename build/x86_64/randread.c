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
 * behalf (the D-09 discipline).  No statistical battery (explicitly
 * declined — D-07: distinctness + the boot-facts armed-source line are
 * the pinned evidence).
 *
 * The open uses the DEVICE-DIRECT form #c/random (boot(8)'s own
 * readenv("#c/user") idiom): this marker runs as the FIRST exec,
 * before any bind builds a namespace — /dev in the paqfs root is an
 * empty stub dir, so the plain path would ENOENT.  #c/random IS
 * /dev/random, same qid, same DRBG (devcons serves it
 * unconditionally).
 *
 * 18-02's devcap legs (AUTH-03/D-06+D-07): the same driver exercises
 * the `#¤` capability device over a PRECOMPUTED fixture pair — the cap
 * string glenda@norbert@<base64 20 rand bytes> and its 20-byte
 * HMAC-SHA1 (data "glenda@norbert", key the base64 text; as.c mkcap's
 * contract) fixed at implementation time.  The four markers, in order:
 * POST-OK (the hostowner posts the hash), USE-OK (the capuse present
 * consumes and /dev/user reads norbert — the FIRST r9 kernel uid
 * mutation, read back live), ONESHOT-REJECT (the same cap again errors
 * "invalid capability" — remcap consumed it), HOSTOWNER-GATE (the
 * mutated user is no longer eve: #¤/caphash open Eperm).  The fixture
 * pair is cross-pinned host-side (r9's devcap_tests
 * devcap_boot_fixture_hash_matches_the_module); the boot leg proves
 * the plumbing, the pins prove the implementation (the flagged
 * fixture assumption — no runtime randomness anywhere).
 */
enum {
	Nbytes = 64,
};

/*
 * The fixture: key = base64 of 20 fixed random bytes; hash =
 * HMAC-SHA1("glenda@norbert", key) — computed once (2026-11-14) and
 * verified against r9's port/src/hmacsha1.rs by the host pin above.
 */
static uchar fixhash[20] = {
	0xf5, 0xec, 0xda, 0xc0, 0x18, 0x1c, 0x47, 0x13,
	0x71, 0xfc, 0xf9, 0x7b, 0xf8, 0x85, 0xf9, 0x90,
	0x22, 0xb7, 0xe2, 0xe3,
};
static char fixcap[] = "glenda@norbert@bTpA7isQXxAD7mV7Y3GX3WuHVNk=";

void
capleg(void)
{
	char user[64], err[ERRMAX];
	int fd, n;

	fd = open("#¤/caphash", OWRITE);
	if(fd < 0){
		print("substrate: FAIL cap caphash open: %r\n");
		exits("cap-open");
	}
	if(write(fd, fixhash, sizeof fixhash) != sizeof fixhash){
		print("substrate: FAIL cap post: %r\n");
		exits("cap-post");
	}
	close(fd);
	print("cap: POST-OK\n");

	fd = open("#¤/capuse", OWRITE);
	if(fd < 0){
		print("substrate: FAIL capuse open: %r\n");
		exits("capuse-open");
	}
	if(write(fd, fixcap, strlen(fixcap)) != strlen(fixcap)){
		print("substrate: FAIL cap use: %r\n");
		exits("cap-use");
	}
	close(fd);

	fd = open("#c/user", OREAD);
	if(fd < 0){
		print("substrate: FAIL cap user open: %r\n");
		exits("cap-user-open");
	}
	n = readn(fd, user, sizeof user - 1);
	close(fd);
	if(n < 0){
		print("substrate: FAIL cap user read: %r\n");
		exits("cap-user-read");
	}
	user[n] = 0;
	if(strcmp(user, "norbert") != 0){
		print("substrate: FAIL cap user=%s\n", user);
		exits("cap-user");
	}
	print("cap: USE-OK\n");

	fd = open("#¤/capuse", OWRITE);
	if(fd < 0){
		print("substrate: FAIL capuse reopen: %r\n");
		exits("capuse-reopen");
	}
	if(write(fd, fixcap, strlen(fixcap)) >= 0){
		print("substrate: FAIL cap oneshot: second present succeeded\n");
		exits("cap-oneshot");
	}
	close(fd);
	errstr(err, sizeof err);
	if(strstr(err, "invalid capability") == nil){
		print("substrate: FAIL cap oneshot err=%s\n", err);
		exits("cap-oneshot-err");
	}
	print("cap: ONESHOT-REJECT\n");

	fd = open("#¤/caphash", OWRITE);
	if(fd >= 0){
		print("substrate: FAIL cap gate: mutated user opened caphash\n");
		exits("cap-gate");
	}
	errstr(err, sizeof err);
	print("cap: HOSTOWNER-GATE err=%s\n", err);
}

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
	close(fd);
	same = 1;
	for(i = 0; i < Nbytes; i++)
		if(a[i] != b[i])
			same = 0;
	if(same){
		print("substrate: FAIL random reads identical\n");
		exits("random-identical");
	}
	print("random: READS-OK\n");

	capleg();

	print("substrate: DONE\n");
	exits(nil);
}
