#include <u.h>
#include <libc.h>

/*
 * netblast — the D-08 TX-bulk generator, serving NETDRV-04's wedge
 * hunt: loop whole-frame writes to a devether conversation's data file
 * as fast as the ring drains.  argv[1] is the clone-opened conversation
 * id (the sweep owns the clone); argv[2] is an optional frame count
 * (default 256, TCG-sane).  The one frame is a 60-byte ARP request
 * (ETHERMINTU — devether's write path rejects n < 60 with Etoosmall)
 * whose target protocol address is 10.0.2.99: slirp answers ARP only
 * for its own addresses, so nothing ever replies — pure TX, zero RX
 * noise (the baked fixture's tpa=10.0.2.2 is the other sanctioned
 * exception per RESEARCH Pitfall N7).  Every write must return exactly
 * 60; a short or failed write is a loud error.  No sleeps, no pacing —
 * when the TX ring is full the write blocks on the driver's wake hook,
 * so a stalled retire wedges the binary and the gate's timeout catches
 * it loudly.
 */

enum { FRAMESZ = 60, DEFAULTN = 256 };

static uchar frame[FRAMESZ] = {
	/* ethernet header: broadcast dst; src rewritten by the kernel */
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0x52, 0x54, 0x00, 0x12, 0x34, 0x56,
	0x08, 0x06,				/* ethertype ARP */
	/* ARP body: htype 1, ptype 0x0800, hlen 6, plen 4, oper 1 */
	0x00, 0x01, 0x08, 0x00, 0x06, 0x04, 0x00, 0x01,
	0x52, 0x54, 0x00, 0x12, 0x34, 0x56,	/* sha */
	0x0a, 0x00, 0x02, 0x0f,			/* spa 10.0.2.15 */
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00,	/* tha zeroed */
	0x0a, 0x00, 0x02, 0x63,			/* tpa 10.0.2.99 — no slirp responder */
	/* 18 zero pad bytes to ETHERMINTU */
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

void
main(int argc, char *argv[])
{
	char path[64];
	long n, i;
	int fd;

	n = DEFAULTN;
	if(argc < 2 || argc > 3){
		fprint(2, "usage: netblast conv [count]\n");
		exits("usage");
	}
	if(argc == 3){
		n = atoi(argv[2]);
		if(n <= 0){
			fprint(2, "netblast: bad count %s\n", argv[2]);
			exits("usage");
		}
	}
	snprint(path, sizeof path, "/net/ether0/%s/data", argv[1]);
	fd = open(path, OWRITE);
	if(fd < 0)
		sysfatal("netblast: open %s: %r", path);
	for(i = 0; i < n; i++){
		if(write(fd, frame, FRAMESZ) != FRAMESZ){
			fprint(2, "netblast: write failed at %ld: %r\n", i);
			exits("errors");
		}
	}
	print("netblast: sent %ld frames\n", n);
	exits(nil);
}
