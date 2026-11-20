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
 * Prints `cexecprobe: ok' and exits nil; otherwise
 * `cexecprobe: LEAK fd=<n>' (the OCEXEC fd crossed exec),
 * `cexecprobe: LOST fd=<n>' (the plain fd did not), or
 * `cexecprobe: FAIL ...', with a non-nil status.
 */

static char *file = "/lib/namespace";
static char *self = "/bin/cexecprobe";

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

void
main(int argc, char *argv[])
{
	if(argc == 1)
		parent();
	if(argc != 3){
		fprint(2, "usage: cexecprobe [ocexec-fd plain-fd]\n");
		exits("usage");
	}
	child(argv[1], argv[2]);
}
