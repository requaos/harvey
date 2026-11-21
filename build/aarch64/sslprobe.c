#include <u.h>
#include <libc.h>

/*
 * sslprobe — the devssl round-trip and mount-over-ssl probe (20-12,
 * D-09).  The arm64 consumer for the cpu-port devssl arms.
 *
 * Phase roundtrip (always): make a pipe, pushssl(2) both ends with
 * rc4_256 and two secrets crossed (one side's secretin is the other's
 * secretout), write a known line on one ssl data fd and read it on the
 * other, then the reverse direction.  It proves the kernel's devssl
 * read and write arms and the fd-resolve hook that turns `fd N' into
 * the underlying pipe chan.
 *
 * Phase mount (-m): after the round trip, fork; the child serves
 * ramfs -i over its ssl data fd, the parent mounts its own ssl data
 * fd on /n/wp (the mount point baked for writeprobe), creates a file
 * there, writes a line, reads it back and unmounts.  It proves mount
 * over a #D chan (9P framed inside ssl records).
 *
 * The two secrets are fixture constants shared only by the two ends
 * of this probe's own pipe; no real key material is read.  They have
 * the shape of cpu(1)'s mksecret output (20 uppercase hex characters,
 * which devssl decodes with dec64).
 *
 * usage: sslprobe [-m]
 *
 * Prints `sslprobe: ok roundtrip' (and with -m `sslprobe: ok mount')
 * and exits nil.  The first failing step prints
 * `sslprobe: FAIL <step>: <errstr>' and exits with the step's name.
 */

enum {
	Bufsz = 256,
};

static char alg[] = "rc4_256";
static char secret0[] = "0123456789ABCDEF0123";
static char secret1[] = "FEDCBA9876543210FEDC";
static char mntpt[] = "/n/wp";
static char mntfile[] = "/n/wp/sslprobe";

static void
fail(char *step)
{
	print("sslprobe: FAIL %s: %r\n", step);
	exits(step);
}

/* write msg on from, read it on to, compare */
static void
xfer(int from, int to, char *msg, char *wstep, char *rstep)
{
	char buf[Bufsz];
	int n, len;

	len = strlen(msg);
	if(write(from, msg, len) != len)
		fail(wstep);
	n = read(to, buf, sizeof buf - 1);
	if(n < 0)
		fail(rstep);
	buf[n] = 0;
	if(n != len || memcmp(buf, msg, len) != 0){
		werrstr("got %d bytes '%s', want %d bytes '%s'", n, buf, len, msg);
		fail(rstep);
	}
}

/*
 * Serve ramfs -i on the child's ssl data fd; never returns.  Once fd 1
 * is the ssl fd a failure goes to fd 2, so the line reaches the console
 * instead of the parent's mount.
 */
static void
server(int fd)
{
	if(dup(fd, 0) < 0 || dup(fd, 1) < 0)
		fail("server-dup");
	if(fd > 1)
		close(fd);
	execl("/bin/ramfs", "ramfs", "-i", nil);
	fprint(2, "sslprobe: FAIL server-exec: %r\n");
	exits("server-exec");
}

static void
mountphase(int fd0, int fd1)
{
	char buf[Bufsz];
	char *line;
	int pid, fd, n, len;

	switch(pid = fork()){
	case -1:
		fail("mount-fork");
	case 0:
		close(fd0);
		server(fd1);
	}
	close(fd1);
	if(mount(fd0, -1, mntpt, MREPL|MCREATE, "") < 0)
		fail("mount");
	fd = create(mntfile, ORDWR, 0666);
	if(fd < 0)
		fail("mount-create");
	line = "sslprobe mount line\n";
	len = strlen(line);
	if(write(fd, line, len) != len)
		fail("mount-write");
	if(seek(fd, 0, 0) != 0)
		fail("mount-seek");
	n = read(fd, buf, sizeof buf - 1);
	if(n < 0)
		fail("mount-read");
	buf[n] = 0;
	if(n != len || memcmp(buf, line, len) != 0){
		werrstr("got %d bytes '%s'", n, buf);
		fail("mount-compare");
	}
	close(fd);
	if(unmount(nil, mntpt) < 0)
		fail("unmount");
	close(fd0);
	postnote(PNPROC, pid, "kill");
	waitpid();
	print("sslprobe: ok mount\n");
}

void
main(int argc, char *argv[])
{
	int p[2], fd0, fd1, mflag;

	mflag = 0;
	ARGBEGIN{
	case 'm':
		mflag = 1;
		break;
	default:
		goto usage;
	}ARGEND
	if(argc != 0)
		goto usage;

	if(pipe(p) < 0)
		fail("pipe");
	fd0 = pushssl(p[0], alg, secret0, secret1, nil);
	if(fd0 < 0)
		fail("pushssl0");
	fd1 = pushssl(p[1], alg, secret1, secret0, nil);
	if(fd1 < 0)
		fail("pushssl1");
	xfer(fd0, fd1, "sslprobe 0 to 1", "write0", "read1");
	xfer(fd1, fd0, "sslprobe 1 to 0", "write1", "read0");
	print("sslprobe: ok roundtrip\n");

	if(mflag)
		mountphase(fd0, fd1);
	exits(nil);

usage:
	fprint(2, "usage: sslprobe [-m]\n");
	exits("usage");
}
