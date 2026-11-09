#include <u.h>
#include <libc.h>

/*
 * svctcpecho — the services sweep's one-shot loopback tcp client
 * (15-02, USPACE-07): dials the named destination, reads the first
 * answer line (alarm-bounded), prints it.  The listen probe's client
 * interaction: the per-connection service (the staged tcpNNNN echo)
 * answers through the connection and this prints what crossed it.
 *
 * Built host-side by build/mm/build-9k10t1.sh (6c/6l with explicit -I
 * paths and -L to the checkout's amd64/lib — the nm-input.6
 * discipline), staged as /boot/hsvctcpecho.  usage: svctcpecho net!addr!port
 */
void
main(int argc, char **argv)
{
	char buf[256];
	int fd, n;

	if(argc != 2){
		fprint(2, "usage: %s net!addr!port\n", argv0);
		exits("usage");
	}
	alarm(15000);
	fd = dial(argv[1], 0, 0, 0);
	if(fd < 0){
		fprint(2, "svctcpecho: dial %s: %r\n", argv[1]);
		exits("dial");
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
