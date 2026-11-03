/*
 * pidwait — trace-rig helper (05-03 Task 1): watch /proc for the first
 * process whose status name (field 0, the ps(1) "text" field) matches a
 * given name, print its pid on stdout, and exit.  rc collects it with a
 * backquote (cpid = `{pidwait ...}) — NOT via $status: the kernel
 * decorates a non-empty exit string into "name pid: status" (pexit), so
 * exits(pid) is unusable for passing the value.
 *
 * -w	wait until the match is also in state Stopped.  The children of
 *	a traced parent are born traced (donor sysproc.c:155) and
 *	self-stop at their first syscall with the entry fragment pending
 *	in /proc/N/syscall; -w waits for exactly that state so the
 *	traceloop can read the pending fragment BEFORE the first
 *	startsyscall resume (a plain `echo stop` would overwrite
 *	procctl and silently drop the entry fragment — and dup is a
 *	required measured name).
 *
 * Exclusions (argv[2..]) are pids never matched — the donor's own
 * same-named processes, the tracer's loops, and so on.  Accepts bare
 * pid digits or /proc/N paths (the prefix is stripped).  pidwait never
 * matches itself.  Candidates that die between the directory read and
 * the status read are skipped.  Gives up after an hour: prints nothing
 * and exits("timeout") — the caller's empty-list guard catches it.
 *
 * Plan 9 C: built by Harvey's vendored 7c/7l in the lima guest
 * namespace (trace-syscalls.py --boot-chain), staged into the donor
 * kernel's CONF=qemu bootdir as /boot/pidwait.
 */
#include <u.h>
#include <libc.h>

int	waitstop;
int	verbose;

int
pidof(char *s)
{
	if(strncmp(s, "/proc/", 6) == 0)
		s += 6;
	return atoi(s);
}

int
excluded(int pid, char **list, int n)
{
	int i;

	for(i = 0; i < n; i++)
		if(pidof(list[i]) == pid)
			return 1;
	return 0;
}

/*
 * read tokens 0 (name) and 2 (state) of /proc/pid/status
 * (devproc's status: name user state ... — ps.c's tokens 0 and 2)
 */
int
readstatus(int pid, char *name, int nname, char *state, int nstate)
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
	if(strlen(f[0]) >= nname || strlen(f[2]) >= nstate)
		return -1;
	strcpy(name, f[0]);
	strcpy(state, f[2]);
	return 0;
}

void
usage(void)
{
	fprint(2, "usage: pidwait [-wv] name [excludepid ...]\n");
	exits("usage");
}

void
main(int argc, char *argv[])
{
	char *name, pname[64], pstate[64], pidbuf[16];
	Dir *dirs;
	long deadline;
	int fd, i, n, me, pid;

	waitstop = 0;
	verbose = 0;
	ARGBEGIN{
	case 'w':
		waitstop = 1;
		break;
	case 'v':
		verbose = 1;
		break;
	default:
		usage();
	}ARGEND
	if(argc < 1)
		usage();
	name = argv[0];
	argv++;
	argc--;

	me = getpid();
	deadline = time(nil) + 3600;
	for(;;){
		if(time(nil) > deadline)
			exits("timeout");
		fd = open("/proc", OREAD);
		if(fd < 0)
			sysfatal("pidwait: open /proc: %r");
		n = dirreadall(fd, &dirs);
		close(fd);
		if(n < 0)
			sysfatal("pidwait: dirreadall /proc: %r");
		for(i = 0; i < n; i++){
			pid = atoi(dirs[i].name);
			if(pid <= 0 || pid == me)
				continue;
			if(excluded(pid, argv, argc))
				continue;
			if(readstatus(pid, pname, sizeof pname, pstate, sizeof pstate) < 0)
				continue;	/* died mid-scan */
			if(strcmp(pname, name) != 0)
				continue;
			if(waitstop && strcmp(pstate, "Stopped") != 0)
				continue;	/* born-traced self-stop pending */
			snprint(pidbuf, sizeof pidbuf, "%d", pid);
			print("%s\n", pidbuf);
			if(verbose)
				fprint(2, "pidwait: %s is %d (%s)\n", name, pid, pstate);
			exits(pidbuf);
		}
		free(dirs);
		sleep(1);
	}
}
