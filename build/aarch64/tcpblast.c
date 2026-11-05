#include <u.h>
#include <libc.h>

/*
 * tcpblast — the NETIP-08 machinery payload: a bidirectional TCP soak
 * client.  D-15: this phase proves the machinery on slirp (hermetic,
 * explicitly labeled not-L2-truth); the tap-leg truth verdict executes
 * in Phase 9 as the joint Phase-8/9 acceptance gate using this binary.
 * argv[1]/argv[2] are the echo server's host and port — the sweep
 * passes the netaddr.rc values (D-11), never a compiled-in address;
 * argv[3] is an optional round count (default 64, TCG-sane).  Each
 * round writes one 32 KiB block patterned with the round index, reads
 * the echoed block back, and byte-compares.  A short, failed, or
 * mismatched round is a loud error; per-round and completion markers
 * ride stdout for the gate.  No sleeps, no pacing — when the stack
 * stalls the binary wedges and the gate's timeout catches it loudly
 * (the 07-04 netblast precedent).
 */

enum { BLKSZ = 32*1024, DEFAULTN = 64 };

static uchar wbuf[BLKSZ], rbuf[BLKSZ];

static void
fill(long round)
{
	int i;

	for(i = 0; i < BLKSZ; i++)
		wbuf[i] = (round ^ i) & 0xff;
}

void
main(int argc, char *argv[])
{
	char addr[128];
	long n, i, got, off;
	int fd;

	n = DEFAULTN;
	if(argc < 3 || argc > 4){
		fprint(2, "usage: tcpblast host port [rounds]\n");
		exits("usage");
	}
	if(argc == 4){
		n = atoi(argv[3]);
		if(n <= 0){
			fprint(2, "tcpblast: bad rounds %s\n", argv[3]);
			exits("usage");
		}
	}
	snprint(addr, sizeof addr, "tcp!%s!%s", argv[1], argv[2]);
	fd = dial(addr, nil, nil, nil);
	if(fd < 0)
		sysfatal("tcpblast: dial %s: %r", addr);
	for(i = 0; i < n; i++){
		fill(i);
		off = 0;
		while(off < BLKSZ){
			got = write(fd, wbuf+off, BLKSZ-off);
			if(got <= 0){
				fprint(2, "tcpblast: write failed round %ld at %ld: %r\n", i, off);
				exits("errors");
			}
			off += got;
		}
		off = 0;
		while(off < BLKSZ){
			got = read(fd, rbuf+off, BLKSZ-off);
			if(got <= 0){
				fprint(2, "tcpblast: read failed round %ld at %ld: %r\n", i, off);
				exits("errors");
			}
			off += got;
		}
		if(memcmp(wbuf, rbuf, BLKSZ) != 0){
			fprint(2, "tcpblast: round %ld payload mismatch\n", i);
			exits("errors");
		}
		print("tcpblast: round %ld ok\n", i);
	}
	print("tcpblast: done %ld rounds\n", n);
	exits(nil);
}
