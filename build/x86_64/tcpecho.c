#include <u.h>
#include <libc.h>

/*
 * tcpecho — the in-guest tcp/7 echo server payload (the aarch64
 * NETIP-03 third-leg helper re-keyed for the x86_64 net gates, 14-09):
 * announce("tcp!*!7") via unmodified libc, then a listen+accept loop
 * echoing each accepted conversation's data until EOF.
 * Single-threaded sequential accept — one connection at a time is all
 * the gate needs.  "tcpecho: announced" after the announce and
 * "tcpecho: conn" per accepted connection are the gate's stdout
 * markers; every failure is a loud sysfatal with %r (the netblast
 * error posture).
 */

void
main(int argc, char *argv[])
{
	char dir[NETPATHLEN], ldir[NETPATHLEN];
	char buf[8192];
	int cfd, lfd, dfd;
	long n;

	if(argc != 1){
		fprint(2, "usage: tcpecho\n");
		exits("usage");
	}
	USED(argv);
	cfd = announce("tcp!*!7", dir);
	if(cfd < 0)
		sysfatal("tcpecho: announce tcp!*!7: %r");
	print("tcpecho: announced\n");
	for(;;){
		lfd = listen(dir, ldir);
		if(lfd < 0)
			sysfatal("tcpecho: listen: %r");
		dfd = accept(lfd, ldir);
		if(dfd < 0)
			sysfatal("tcpecho: accept: %r");
		print("tcpecho: conn\n");
		while((n = read(dfd, buf, sizeof buf)) > 0)
			if(write(dfd, buf, n) != n)
				sysfatal("tcpecho: echo write: %r");
		if(n < 0)
			sysfatal("tcpecho: echo read: %r");
		close(dfd);
		close(lfd);
	}
}
