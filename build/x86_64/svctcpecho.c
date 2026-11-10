#include <u.h>
#include <libc.h>

/*
 * svctcpecho — the services sweep's one-shot loopback tcp client
 * (15-02, USPACE-07): dials the named destination and either reads the
 * first answer line (default; the listen probe's client interaction —
 * the per-connection service answers through the connection and this
 * prints what crossed it) or proves the CONNECT alone (-c; the
 * authsrv probe — D-08's listening-proven shape: a dial to an
 * announced port is accepted while an unannounced one is refused, and
 * authsrv itself stays handshake-silent by design).
 *
 * Built host-side by build/mm/build-9k10t1.sh (6c/6l with explicit -I
 * paths and -L to the checkout's amd64/lib — the nm-input.6
 * discipline), staged as /boot/hsvctcpecho.  usage: svctcpecho [-c] net!addr!port
 */

int connectonly;

void
usage(void)
{
	fprint(2, "usage: %s [-c] net!addr!port\n", argv0);
	exits("usage");
}

void
main(int argc, char **argv)
{
	char buf[256];
	int fd, n;

	ARGBEGIN{
	case 'c':
		connectonly = 1;
		break;
	default:
		usage();
	}ARGEND

	if(argc != 1)
		usage();
	alarm(15000);
	fd = dial(argv[0], 0, 0, 0);
	if(fd < 0){
		fprint(2, "svctcpecho: dial %s: %r\n", argv[0]);
		exits("dial");
	}
	if(connectonly){
		/* the accept is the proof: hang up immediately — the
		 * per-connection program sees EOF and exits cleanly */
		print("connected\n");
		exits(nil);
	}
	n = read(fd, buf, sizeof(buf)-1);
	if(n <= 0){
		fprint(2, "svctcpecho: read: %r\n");
		exits("read");
	}
	buf[n] = 0;
	print("%s", buf);
	exits(nil);
}
