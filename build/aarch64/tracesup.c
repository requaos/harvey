/*
 * tracesup — trace supervisor for the tier-1 measure-first run
 * (06-07): step-trace one root process and every born-traced
 * descendant, writing each pid's fragment stream to outdir/<pid>,
 * one newline-framed fragment per line.
 *
 * This is the 05-03 rc traceloop/fragprint shape moved into one C
 * program: no per-fragment forks (the rc cat|sed pair per fragment
 * dominated any tier-scale run) and one file per pid kills the
 * mid-line gluing the __GSD_FRAG_ tag prefix defended against (the
 * donor's entry fragments carry no trailing newline).  Born-traced
 * inheritance (donor sysproc.c:155: a Proc_tracesyscall process's
 * fork children carry the same procctl) makes every sweep binary
 * self-stop at its first syscall with the entry fragment pending in
 * /proc/N/syscall; the supervisor arms each exactly once.
 *
 * Arming discipline (pidwait.c's rule):
 *   - the ROOT pid is already Stopped when tracesup starts (the
 *     termrc wrapper's spin-window + `echo stop`): its loop writes
 *     startsyscall FIRST — the stop was a Proc_stopme stop in a
 *     syscall-free spin, so no syscall fragment is pending.
 *   - a born-traced child is discovered Stopped with its entry
 *     fragment already pending: its loop reads the pending fragment
 *     BEFORE the first startsyscall resume (a stop write would race
 *     Proc_tracesyscall away and silently drop it).
 * Every read is pread(...,0) — devproc replaces p->syscalltrace at
 * each stop.  Each loop is its own rfork'd (untraced) process
 * because the startsyscall write BLOCKS until the target's next
 * stop; the supervisor parent only polls /proc and arms newcomers.
 *
 * Teardown: the root loop ends on Eprocdied (the sweep's exit) and
 * posts outdir/_rootdone; the parent then kill+starts every remaining
 * armed pid (05-03's watchdog shape — kill pends, start delivers),
 * writes outdir/_done, and exits.  The host reads the per-pid files
 * off the srv9-served root after the run.
 *
 * Plan 9 C: built by Harvey's vendored 7c/7l in the lima guest
 * namespace (harness trace-syscalls --tier1), staged into the donor
 * kernel's CONF=qemu bootdir as /boot/tracesup.
 *
 * usage: tracesup [-v] rootpid outdir
 */
#include <u.h>
#include <libc.h>
#include <bio.h>

enum {
	FRAGMAX = 8192,		/* one fragment read buffer */
	POLLMS  = 50,		/* /proc scan cadence */
};

int	verbose;

/*
 * One traced pid's step loop.  Ends when a startsyscall write fails
 * (Eprocdied — the target exited).  Never prints on the wire; the
 * fragments are the product.
 */
void
loopchild(int pid, int born, char *outdir)
{
	char ctl[64], sysc[64], out[256], frag[FRAGMAX];
	int cfd, sfd, ofd, n;
	Biobuf b;

	snprint(ctl, sizeof ctl, "/proc/%d/ctl", pid);
	snprint(sysc, sizeof sysc, "/proc/%d/syscall", pid);
	snprint(out, sizeof out, "%s/%d", outdir, pid);
	cfd = open(ctl, OWRITE);
	if(cfd < 0)
		exits(nil);	/* died between discovery and arm */
	sfd = open(sysc, OREAD);
	if(sfd < 0)
		exits(nil);
	ofd = create(out, OWRITE, 0664);
	if(ofd < 0)
		exits(nil);
	if(Binit(&b, ofd, OWRITE) == Beof)
		exits(nil);
	if(born){
		/* the born-traced self-stop left the entry fragment pending */
		n = pread(sfd, frag, sizeof frag - 1, 0);
		if(n > 0){
			Bwrite(&b, frag, n);
			Bwrite(&b, "\n", 1);
		}
	}
	for(;;){
		if(write(cfd, "startsyscall", 12) != 12)
			break;	/* Eprocdied: the target exited */
		n = pread(sfd, frag, sizeof frag - 1, 0);
		if(n <= 0)
			continue;	/* defensive: never invent a fragment */
		Bwrite(&b, frag, n);
		Bwrite(&b, "\n", 1);
	}
	Bflush(&b);
	Bterm(&b);
	close(ofd);
	close(sfd);
	close(cfd);
	if(!born){
		/* the root's exit ends the run — post the sentinel */
		snprint(out, sizeof out, "%s/_rootdone", outdir);
		ofd = create(out, OWRITE, 0664);
		if(ofd >= 0)
			close(ofd);
	}
	exits(nil);
}

/* /proc dir listing with the fd closed (the poll loop runs for hours) */
int
procdirs(Dir **dp)
{
	int fd, n;

	fd = open("/proc", OREAD);
	if(fd < 0)
		return -1;
	n = dirreadall(fd, dp);
	close(fd);
	return n;
}

/* read token 0 (name) and token 2 (state) of /proc/pid/status */
int
readstate(int pid, char *state, int nstate)
{
	char buf[256], path[64], *f[4];
	int fd, n;

	snprint(path, sizeof path, "/proc/%d/status", pid);
	fd = open(path, OREAD);
	if(fd < 0)
		return -1;
	n = read(fd, buf, sizeof buf - 1);
	close(fd);
	if(n <= 0)
		return -1;
	buf[n] = '\0';
	if(tokenize(buf, f, nelem(f)) < 3)
		return -1;
	if(strlen(f[2]) >= nstate)
		return -1;
	strcpy(state, f[2]);
	return 0;
}

int
inset(int *set, int n, int pid)
{
	int i;

	for(i = 0; i < n; i++)
		if(set[i] == pid)
			return 1;
	return 0;
}

void
usage(void)
{
	fprint(2, "usage: tracesup [-v] rootpid outdir\n");
	exits("usage");
}

void
main(int argc, char *argv[])
{
	char path[256], state[32];
	Dir *dirs;
	int *preexist, *armed, *kids;
	int npre, narmed, nkids, i, n, pid, rootpid, me, ofd, kid;
	long deadline;

	verbose = 0;
	ARGBEGIN{
	case 'v':
		verbose = 1;
		break;
	default:
		usage();
	}ARGEND
	if(argc != 2)
		usage();
	rootpid = atoi(argv[0]);
	if(rootpid <= 0)
		usage();

	me = getpid();
	if(create(argv[1], OREAD, DMDIR|0775) < 0)
		if(access(argv[1], AEXIST) < 0)
			sysfatal("tracesup: create %s: %r", argv[1]);

	/* snapshot: every pid alive now is never armed as a child (the
	 * donor's own rc/init/kbdfs, the termrc shell, tracesup itself);
	 * the root pid exists at snapshot time too — it is armed
	 * explicitly, born=0 (the Proc_stopme stop has no pending
	 * fragment). */
	preexist = nil;
	npre = 0;
	armed = nil;
	narmed = 0;
	nkids = 0;
	n = procdirs(&dirs);
	if(n > 0){
		preexist = malloc(n * sizeof(int));
		for(i = 0; i < n; i++){
			pid = atoi(dirs[i].name);
			if(pid > 0)
				preexist[npre++] = pid;
		}
		free(dirs);
	}
	if(verbose)
		fprint(2, "tracesup: root=%d outdir=%s preexisting=%d\n",
			rootpid, argv[1], npre);

	/* arm the root */
	kid = rfork(RFPROC|RFFDG|RFREND|RFNOWAIT);
	if(kid == 0){
		loopchild(rootpid, 0, argv[1]);
		exits(nil);	/* loopchild never returns */
	}
	armed = malloc((npre + 4096) * sizeof(int));
	kids = malloc((npre + 4096) * sizeof(int));
	armed[narmed++] = rootpid;
	armed[narmed++] = me;
	kids[nkids++] = kid;

	/* poll for born-traced children until the root loop posts the
	 * sentinel; give up after four hours (the host budget is the real
	 * watchdog — this bound only keeps a wedged guest from holding a
	 * supervisor forever) */
	deadline = time(nil) + 4*60*60;
	snprint(path, sizeof path, "%s/_rootdone", argv[1]);
	while(access(path, AEXIST) < 0){
		if(time(nil) > deadline)
			exits("timeout");
		sleep(POLLMS);
		n = procdirs(&dirs);
		if(n <= 0)
			continue;
		for(i = 0; i < n; i++){
			pid = atoi(dirs[i].name);
			if(pid <= 0)
				continue;
			if(inset(armed, narmed, pid) || inset(preexist, npre, pid))
				continue;
			if(readstate(pid, state, sizeof state) < 0)
				continue;	/* died mid-scan */
			if(strcmp(state, "Stopped") != 0)
				continue;	/* not a born-traced self-stop */
			/* arm: one untraced loop process per traced pid */
			kid = rfork(RFPROC|RFFDG|RFREND|RFNOWAIT);
			if(kid == 0){
				loopchild(pid, 1, argv[1]);
				exits(nil);	/* loopchild never returns */
			}
			armed[narmed++] = pid;
			kids[nkids++] = kid;
			if(verbose)
				fprint(2, "tracesup: armed born-traced pid %d\n", pid);
		}
		free(dirs);
	}

	/* teardown: kill+start every remaining armed non-root pid (kill
	 * pends, start delivers — 05-03's watchdog shape); dead already is
	 * fine */
	for(i = 0; i < narmed; i++){
		pid = armed[i];
		if(pid == rootpid || pid == me)
			continue;
		snprint(path, sizeof path, "/proc/%d/ctl", pid);
		ofd = open(path, OWRITE);
		if(ofd < 0)
			continue;
		write(ofd, "kill", 4);
		close(ofd);
		ofd = open(path, OWRITE);
		if(ofd < 0)
			continue;
		write(ofd, "start", 5);
		close(ofd);
	}
	/* drain: the killed targets' loops end on Eprocdied and flush their
	 * Bio buffers — wait for every loop child to exit (bounded) BEFORE
	 * the _done summary, or a daemon's tail fragments could linger
	 * unflushed when the host reads the files */
	deadline = time(nil) + 30;
	for(i = 0; i < nkids;){
		snprint(path, sizeof path, "/proc/%d", kids[i]);
		if(access(path, AEXIST) < 0){
			i++;
			continue;
		}
		if(time(nil) > deadline)
			break;	/* bounded — the host budget is the real watchdog */
		sleep(POLLMS);
	}
	snprint(path, sizeof path, "%s/_done", argv[1]);
	ofd = create(path, OWRITE, 0664);
	if(ofd >= 0){
		fprint(ofd, "tracesup done root=%d armed=%d\n", rootpid, narmed);
		close(ofd);
	}
	if(verbose)
		fprint(2, "tracesup: done; %d pids armed\n", narmed);
	exits(nil);
}
