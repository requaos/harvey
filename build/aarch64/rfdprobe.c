#include <u.h>
#include <libc.h>

/*
 * rfdprobe — the non-RFPROC fd-group split probe (20-07, inventory b4).
 *
 * A bare rfork(RFFDG) (copy the fd table in place) or rfork(RFCFDG)
 * (start with an empty one) re-groups the CALLER's file descriptors
 * without making a new process.  lib9p's postmountsrv does the first
 * and ignores the result, so a kernel that rejects it gives no visible
 * failure there; this probe checks the return value and proves the
 * split happened.
 *
 * The parent keeps one open fd.  Each phase forks a child with plain
 * rfork(RFPROC), so the child SHARES the parent's fd table, and the
 * child then splits it:
 *	rffdg	bare rfork(RFFDG), then close the kept fd in the now
 *		private copy; the parent's fd must survive
 *	rfcfdg	bare rfork(RFCFDG); the kept fd must be gone in the
 *		child and still open in the parent
 * A child reports only through its exit string (after RFCFDG it has no
 * fd 1 or 2 to print on).
 *
 * Prints `rfdprobe: ok' and exits nil when both phases pass; otherwise
 * one `rfdprobe: FAIL <rffdg|rfcfdg> <reason>' line per failing phase,
 * and exits with the first of them.
 *
 * -s (a diagnostic): fork one plain rfork(RFPROC) child that shares the
 * fd table and exits at once, wait for it, print `rfdprobe: share ok'
 * and exit; no bare rfork is made.  It separates the shared-fd-table
 * fork from the split itself when a reader of this process's output
 * never sees end of file (20-07).
 */

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

/*
 * Wait for the child; copy a failure reason into why and return -1,
 * or return 0 when the child exited nil and the parent's fd survived.
 */
static int
reap(int fd, char *why, int nwhy)
{
	Waitmsg *w;

	w = wait();
	if(w == nil){
		snprint(why, nwhy, "wait: %r");
		return -1;
	}
	if(w->msg[0] != '\0'){
		snprint(why, nwhy, "%s", w->msg);
		free(w);
		return -1;
	}
	free(w);
	if(!isopen(fd)){
		snprint(why, nwhy, "parent fd closed by child");
		return -1;
	}
	return 0;
}

static int
phase(char *name, int flag, int fd, char *why, int nwhy)
{
	char buf[ERRMAX+32];

	switch(rfork(RFPROC)){
	case -1:
		snprint(why, nwhy, "rfork(RFPROC): %r");
		return -1;
	case 0:
		if(rfork(flag) < 0){
			snprint(buf, sizeof buf, "%s: %r", name);
			exits(buf);
		}
		if(flag == RFFDG){
			close(fd);
			exits(nil);
		}
		if(isopen(fd))
			exits("rfcfdg: fd still open");
		exits(nil);
	}
	return reap(fd, why, nwhy);
}

void
main(int argc, char *argv[])
{
	char why[ERRMAX+64], first[ERRMAX+96];
	int fd, nfail, sflag;

	sflag = 0;
	ARGBEGIN{
	case 's':
		sflag = 1;
		break;
	default:
		fprint(2, "usage: rfdprobe [-s]\n");
		exits("usage");
	}ARGEND

	if(sflag){
		switch(rfork(RFPROC)){
		case -1:
			print("rfdprobe: FAIL share rfork(RFPROC): %r\n");
			exits("share");
		case 0:
			exits(nil);
		}
		if(reap(1, why, sizeof why) < 0){
			print("rfdprobe: FAIL share %s\n", why);
			exits("share");
		}
		print("rfdprobe: share ok\n");
		exits(nil);
	}

	fd = open("/dev/null", OREAD);
	if(fd < 0)
		fd = dup(1, -1);
	if(fd < 0 || !isopen(fd)){
		print("rfdprobe: FAIL setup no fd to keep: %r\n");
		exits("setup");
	}

	nfail = 0;
	first[0] = '\0';
	if(phase("rffdg", RFFDG, fd, why, sizeof why) < 0){
		print("rfdprobe: FAIL rffdg %s\n", why);
		snprint(first, sizeof first, "rfdprobe: FAIL rffdg %s", why);
		nfail++;
		/* a silent no-op split closed the shared fd; restore it for phase two */
		if(!isopen(fd)){
			fd = open("/dev/null", OREAD);
			if(fd < 0)
				fd = dup(1, -1);
		}
	}
	if(phase("rfcfdg", RFCFDG, fd, why, sizeof why) < 0){
		print("rfdprobe: FAIL rfcfdg %s\n", why);
		if(nfail == 0)
			snprint(first, sizeof first, "rfdprobe: FAIL rfcfdg %s", why);
		nfail++;
	}
	if(nfail > 0)
		exits(first);
	print("rfdprobe: ok\n");
	exits(nil);
}
