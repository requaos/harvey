#include <u.h>
#include <libc.h>

/*
 * cexecprobe — the close-on-exec probe (20-10, D-03 exec half).
 *
 * An fd opened with OCEXEC must not survive a successful exec; a plain
 * fd must.  libthread's procexec depends on the first half: its
 * exec-status pipe write end is opened OWRITE|OCEXEC, and the parent
 * only sees end of file on it when the exec'd child's copy closes.
 *
 * With no arguments: open /lib/namespace twice, once OREAD|OCEXEC and
 * once OREAD, then exec /bin/cexecprobe with the two fd numbers.
 *
 * With two arguments (the exec'd image): the OCEXEC fd must be closed
 * (dirfstat fails) and the plain fd open (dirfstat succeeds).
 *
 * With -c (the create leg): create must record OCEXEC on both of its
 * arms, as the donor chan.c Acreate does.  lib9p's postfd, rio and the
 * plumber create their /srv posts OWRITE|ORCLOSE|OCEXEC.  In a fresh,
 * empty environment group (rfork(RFCENVG): the names are new and
 * private, and vanish with the process, since r9 has no remove),
 * create /env/cexecprobe.c OWRITE|OCEXEC|OEXCL (OEXCL forces the
 * new-file arm), /env/cexecprobe.p OWRITE|OEXCL, and /env/cexecprobe.c
 * again OWRITE|OCEXEC (the existing-file arm, an OTRUNC open).  Then
 * exec /bin/cexecprobe -C with the three fd numbers: both OCEXEC fds
 * must be closed and the plain one open.
 *
 * Prints `cexecprobe: ok' (`cexecprobe: create ok' for -c) and exits
 * nil; otherwise `cexecprobe: LEAK fd=<n>' (the OCEXEC fd crossed
 * exec), `cexecprobe: LOST fd=<n>' (the plain fd did not), or
 * `cexecprobe: FAIL ...', with a non-nil status.  The create leg names
 * the arm: `LEAK create fd=<n>' (new file), `LEAK create-existing
 * fd=<n>', `LOST create fd=<n>'.
 */

static char *file = "/lib/namespace";
static char *self = "/bin/cexecprobe";
static char *cname = "/env/cexecprobe.c";
static char *pname = "/env/cexecprobe.p";

static int
isopen(int fd)
{
	Dir *d;

	d = dirfstat(fd);
	if(d == nil)
		return 0;
	free(d);
	return 1;
}

static void
parent(void)
{
	int cfd, pfd;
	char cbuf[16], pbuf[16];
	char *args[4];

	cfd = open(file, OREAD|OCEXEC);
	if(cfd < 0){
		print("cexecprobe: FAIL open %s OCEXEC: %r\n", file);
		exits("open");
	}
	pfd = open(file, OREAD);
	if(pfd < 0){
		print("cexecprobe: FAIL open %s: %r\n", file);
		exits("open");
	}
	snprint(cbuf, sizeof cbuf, "%d", cfd);
	snprint(pbuf, sizeof pbuf, "%d", pfd);
	args[0] = "cexecprobe";
	args[1] = cbuf;
	args[2] = pbuf;
	args[3] = nil;
	exec(self, args);
	print("cexecprobe: FAIL exec %s: %r\n", self);
	exits("exec");
}

static void
child(char *cs, char *ps)
{
	int cfd, pfd;

	cfd = atoi(cs);
	pfd = atoi(ps);
	if(isopen(cfd)){
		print("cexecprobe: LEAK fd=%d\n", cfd);
		exits("leak");
	}
	if(!isopen(pfd)){
		print("cexecprobe: LOST fd=%d\n", pfd);
		exits("lost");
	}
	close(pfd);
	print("cexecprobe: ok\n");
	exits(nil);
}

static void
createparent(void)
{
	int cfd, efd, pfd;
	char cbuf[16], ebuf[16], pbuf[16];
	char *args[6];

	if(rfork(RFCENVG) < 0){
		print("cexecprobe: FAIL rfork RFCENVG: %r\n");
		exits("rfork");
	}
	cfd = create(cname, OWRITE|OCEXEC|OEXCL, 0666);
	if(cfd < 0){
		print("cexecprobe: FAIL create %s OCEXEC: %r\n", cname);
		exits("create");
	}
	pfd = create(pname, OWRITE|OEXCL, 0666);
	if(pfd < 0){
		print("cexecprobe: FAIL create %s: %r\n", pname);
		exits("create");
	}
	efd = create(cname, OWRITE|OCEXEC, 0666);
	if(efd < 0){
		print("cexecprobe: FAIL create existing %s OCEXEC: %r\n", cname);
		exits("create");
	}
	snprint(cbuf, sizeof cbuf, "%d", cfd);
	snprint(ebuf, sizeof ebuf, "%d", efd);
	snprint(pbuf, sizeof pbuf, "%d", pfd);
	args[0] = "cexecprobe";
	args[1] = "-C";
	args[2] = cbuf;
	args[3] = ebuf;
	args[4] = pbuf;
	args[5] = nil;
	exec(self, args);
	print("cexecprobe: FAIL exec %s: %r\n", self);
	exits("exec");
}

/* every arm is checked, so one run shows which arms leak */
static void
createchild(char *cs, char *es, char *ps)
{
	int cfd, efd, pfd;
	char *bad;

	cfd = atoi(cs);
	efd = atoi(es);
	pfd = atoi(ps);
	bad = nil;
	if(isopen(cfd)){
		print("cexecprobe: LEAK create fd=%d\n", cfd);
		bad = "leak";
	}
	if(isopen(efd)){
		print("cexecprobe: LEAK create-existing fd=%d\n", efd);
		bad = "leak";
	}
	if(!isopen(pfd)){
		print("cexecprobe: LOST create fd=%d\n", pfd);
		bad = "lost";
	}
	if(bad != nil)
		exits(bad);
	close(pfd);
	print("cexecprobe: create ok\n");
	exits(nil);
}

void
main(int argc, char *argv[])
{
	if(argc == 1)
		parent();
	if(argc == 2 && strcmp(argv[1], "-c") == 0)
		createparent();
	if(argc == 5 && strcmp(argv[1], "-C") == 0)
		createchild(argv[2], argv[3], argv[4]);
	if(argc != 3){
		fprint(2, "usage: cexecprobe [-c | ocexec-fd plain-fd]\n");
		exits("usage");
	}
	child(argv[1], argv[2]);
}
