#include <u.h>
#include <libc.h>
#include <fcall.h>

/*
 * cpuprobe — the stat and cap legs of the arm64 cpu fixture (20-16,
 * ARM-11).  /rc/bin/cpurc runs it on a cpu boot (the boot string
 * selects init -c); the checks that need an exact errstr are done here
 * in C so the gate does not depend on how rc reports a failure.
 *
 * cpuprobe stat: the kernel's wstat, fwstat and remove arms validate
 * the stat buffer first and refuse by name on a device without the arm.
 *   1. wstat of a 3-byte buffer: `malformed stat buffer'
 *   2. wstat of a well-formed buffer (dirstat + convD2M):
 *      `wstat: device does not implement wstat'
 *   3. fwstat of the same buffer on an open fd: the same text, and the
 *      fd still reads afterwards
 *   4. a well-formed buffer whose size field is one too large:
 *      `malformed stat buffer'
 *   5. remove: `remove: device does not implement remove', and the
 *      file still opens
 *
 * cpuprobe cap: the devcap arms.
 *   1. a hash-length write to caphash succeeds (the boot user is the
 *      hostowner, so it passes the device's eve gate)
 *   2. an unknown capability written to capuse fails, errstr beginning
 *      `invalid capability'
 *   3. a write shorter than the hash length to caphash fails with
 *      `devcap: i/o count too small'
 * The bytes written are throwaway constants; no real key is read.
 *
 * Prints `cpuprobe: ok stat' or `cpuprobe: ok cap' and exits nil.  The
 * first failing step prints `cpuprobe: FAIL <step>: <errstr>' and exits
 * with the step's name.
 *
 * usage: cpuprobe stat|cap
 */

enum {
	Hashlen = 20,	/* devcap's HASHLEN = SHA1dlen */
};

static char target[] = "/lib/namespace";
static char caphash[] = "#¤/caphash";
static char capuse[] = "#¤/capuse";
static char bogus[] = "glenda@bogus@key";

static void
fail(char *step)
{
	print("cpuprobe: FAIL %s: %r\n", step);
	exits(step);
}

/*
 * The call under test returned r; it must have failed with an errstr
 * containing want (at its start when prefix is set).
 */
static void
mustrefuse(char *step, int r, char *want, int prefix)
{
	char err[ERRMAX];

	if(r >= 0){
		werrstr("succeeded (returned %d), want an error '%s'", r, want);
		fail(step);
	}
	rerrstr(err, sizeof err);
	if(prefix){
		if(strncmp(err, want, strlen(want)) == 0)
			return;
	}else if(strstr(err, want) != nil)
		return;
	werrstr("errstr '%s', want '%s'", err, want);
	fail(step);
}

/* the file must still open and read one byte */
static void
mustread(char *step, int fd)
{
	char c;

	if(fd < 0)
		fail(step);
	if(pread(fd, &c, 1, 0) != 1)
		fail(step);
}

static void
statlegs(void)
{
	Dir *d;
	uchar *buf, tiny[3];
	uint n, sz;
	int fd;

	memset(tiny, 0, sizeof tiny);
	mustrefuse("wstat-short", wstat(target, tiny, sizeof tiny), "malformed stat buffer", 0);

	d = dirstat(target);
	if(d == nil)
		fail("dirstat");
	n = sizeD2M(d);
	buf = malloc(n);
	if(buf == nil)
		fail("malloc");
	if(convD2M(d, buf, n) != n){
		werrstr("convD2M did not fill %ud bytes", n);
		fail("convD2M");
	}
	free(d);
	mustrefuse("wstat", wstat(target, buf, n), "wstat: device does not implement wstat", 0);

	fd = open(target, OREAD);
	if(fd < 0)
		fail("open");
	mustrefuse("fwstat", fwstat(fd, buf, n), "wstat: device does not implement wstat", 0);
	mustread("fwstat-read", fd);
	close(fd);

	/* size field one too large: the length no longer matches the buffer */
	sz = buf[0] | buf[1]<<8;
	sz++;
	buf[0] = sz;
	buf[1] = sz>>8;
	mustrefuse("wstat-size", wstat(target, buf, n), "malformed stat buffer", 0);
	free(buf);

	mustrefuse("remove", remove(target), "remove: device does not implement remove", 0);
	fd = open(target, OREAD);
	mustread("remove-open", fd);
	close(fd);

	print("cpuprobe: ok stat\n");
}

static void
caplegs(void)
{
	char hash[Hashlen];
	int fd, ufd, i;

	for(i = 0; i < Hashlen; i++)
		hash[i] = 'a' + i;
	fd = open(caphash, OWRITE);
	if(fd < 0)
		fail("caphash-open");
	if(write(fd, hash, Hashlen) != Hashlen)
		fail("caphash-write");

	ufd = open(capuse, OWRITE);
	if(ufd < 0)
		fail("capuse-open");
	mustrefuse("capuse", write(ufd, bogus, strlen(bogus)), "invalid capability", 1);
	close(ufd);

	mustrefuse("caphash-short", write(fd, hash, Hashlen/2), "devcap: i/o count too small", 0);
	close(fd);

	print("cpuprobe: ok cap\n");
}

static void
usage(void)
{
	fprint(2, "usage: cpuprobe stat|cap\n");
	exits("usage");
}

void
main(int argc, char *argv[])
{
	ARGBEGIN{
	default:
		usage();
	}ARGEND
	if(argc != 1)
		usage();
	if(strcmp(argv[0], "stat") == 0)
		statlegs();
	else if(strcmp(argv[0], "cap") == 0)
		caplegs();
	else
		usage();
	exits(nil);
}
