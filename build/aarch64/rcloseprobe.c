#include <u.h>
#include <libc.h>

/*
 * rcloseprobe — the remove-on-close probe (ORCLOSE on local devices).
 *
 * A file opened or created ORCLOSE is removed when the last reference
 * to that open closes (the donor's srvclose and envclose).  lib9p's
 * postfd, rio and the plumber create their /srv posts
 * OWRITE|ORCLOSE|OCEXEC, so a server's post must go when the server
 * does.  Every leg runs, so one run shows each arm:
 *
 *	srv	create /srv/rcloseprobe.<pid> OWRITE|ORCLOSE|OCEXEC; after
 *		close(2) the name must be gone.
 *	dup	create .<pid>.d OWRITE|ORCLOSE and dup it: the first close
 *		must leave the name, the last one remove it.
 *	exit	a fork(2) child creates .<pid>.x OWRITE|ORCLOSE and exits
 *		without closing; after wait the name must be gone.
 *	env	in a fresh environment group (rfork(RFCENVG)):
 *		/env/rcloseprobe.c created OWRITE|ORCLOSE is gone after
 *		close; /env/rcloseprobe.p created plain stays; opening
 *		it OREAD|ORCLOSE (the open arm) removes it at close.
 *
 * Prints `rcloseprobe: ok' and exits nil; otherwise one line per bad
 * arm — `rcloseprobe: LEAK <leg> <name>' (still there after the last
 * close), `rcloseprobe: EARLY dup <name>' (removed while a dup was
 * open), `rcloseprobe: LOST env <name>' (a plain file went), or
 * `rcloseprobe: FAIL ...' — with a non-nil status.  Leaked /srv names
 * stay behind: r9 arm64 has no remove(2) yet.
 */

static char *bad;

static int
exists(char *name)
{
	Dir *d;

	d = dirstat(name);
	if(d == nil)
		return 0;
	free(d);
	return 1;
}

static int
mk(char *name, int mode)
{
	int fd;

	fd = create(name, mode, 0600);
	if(fd < 0){
		print("rcloseprobe: FAIL create %s: %r\n", name);
		exits("create");
	}
	if(!exists(name)){
		print("rcloseprobe: FAIL %s missing after create\n", name);
		exits("create");
	}
	return fd;
}

static void
gone(char *leg, char *name)
{
	if(exists(name)){
		print("rcloseprobe: LEAK %s %s\n", leg, name);
		bad = "leak";
	}
}

static void
srvleg(int pid)
{
	char name[64];

	snprint(name, sizeof name, "/srv/rcloseprobe.%d", pid);
	close(mk(name, OWRITE|ORCLOSE|OCEXEC));
	gone("srv", name);
}

static void
dupleg(int pid)
{
	char name[64];
	int fd, fd2;

	snprint(name, sizeof name, "/srv/rcloseprobe.%d.d", pid);
	fd = mk(name, OWRITE|ORCLOSE);
	fd2 = dup(fd, -1);
	if(fd2 < 0){
		print("rcloseprobe: FAIL dup: %r\n");
		exits("dup");
	}
	close(fd);
	if(!exists(name)){
		print("rcloseprobe: EARLY dup %s\n", name);
		bad = "early";
	}
	close(fd2);
	gone("dup", name);
}

static void
exitleg(int pid)
{
	char name[64];

	snprint(name, sizeof name, "/srv/rcloseprobe.%d.x", pid);
	switch(fork()){
	case -1:
		print("rcloseprobe: FAIL fork: %r\n");
		exits("fork");
	case 0:
		mk(name, OWRITE|ORCLOSE);
		exits(nil);	/* the exit drain closes it */
	}
	free(wait());
	gone("exit", name);
}

static void
envleg(void)
{
	char *cname, *pname;
	int fd;

	cname = "/env/rcloseprobe.c";
	pname = "/env/rcloseprobe.p";
	if(rfork(RFCENVG) < 0){
		print("rcloseprobe: FAIL rfork RFCENVG: %r\n");
		exits("rfork");
	}
	close(mk(cname, OWRITE|ORCLOSE));
	gone("env", cname);
	close(mk(pname, OWRITE));
	if(!exists(pname)){
		print("rcloseprobe: LOST env %s\n", pname);
		bad = "lost";
		return;
	}
	fd = open(pname, OREAD|ORCLOSE);
	if(fd < 0){
		print("rcloseprobe: FAIL open %s ORCLOSE: %r\n", pname);
		exits("open");
	}
	close(fd);
	gone("env-open", pname);
}

void
main(int argc, char *argv[])
{
	int pid;

	USED(argv);
	if(argc != 1){
		fprint(2, "usage: rcloseprobe\n");
		exits("usage");
	}
	bad = nil;
	pid = getpid();
	srvleg(pid);
	dupleg(pid);
	exitleg(pid);
	envleg();
	if(bad != nil)
		exits(bad);
	print("rcloseprobe: ok\n");
	exits(nil);
}
