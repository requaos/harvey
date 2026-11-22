#include <u.h>
#include <libc.h>

/*
 * fpprobe — user FPU/SSE register survival probe (r9 x86_64; the
 * build/aarch64/fpprobe.c twin).
 *
 * A user program's x87, MMX, XMM0-15 and MXCSR state must come back
 * unchanged from every syscall, yield, block and preemption, a fork
 * child must start with its parent's state, a fresh exec must start
 * from the default state (FCW 0x037F, MXCSR 0x1F80, every register and
 * the tag word zero), and a note handler must not change the state of
 * the code it interrupted.
 *
 * fpprobeasm.s moves the whole state as one FXSAVE image: fpload
 * restores a pattern image and saves it straight back (so bits the
 * hardware does not keep drop out of the expected image), fpstore saves
 * the live state.  Between the two only integer code and libc syscall
 * stubs run, none of which touch the FPU/SSE registers, so any
 * difference was made by the kernel.  Images are compared on the
 * user-visible fields: FCW, FSW, the abridged tag word, MXCSR, the 80
 * bits of each ST/MM register and XMM0-15.
 *
 * Legs (all five must pass for `fpprobe: ok'):
 *	fork	load a pattern, rfork(RFPROC|RFFDG); parent and child both
 *		store and compare (the child must inherit the state)
 *	exec	a child loads a pattern and execs `fpprobe -e'; the new image
 *		stores the state before anything else runs in main, and it
 *		must be the default state
 *	switch	-w workers (default 2) run at once, each with its own
 *		patterns, -n rounds (default 20) cycling five sub-legs between
 *		load and store: syscall (alarm(0) x50), yield (sleep(0) x50),
 *		block (sleep(1) x5), spin (-s integer iterations, default
 *		20000000 — the x86 tick is 10 ms) and errstr (x20); every round runs, and the first
 *		failure of each sub-leg is reported
 *	preempt	-w workers only spin (-p rounds, default 4, of -s
 *		iterations): none blocks, so the timer tick must preempt each
 *		in ring 3 and run the other
 *	note	a child with a notify handler loads a pattern and takes a
 *		note twice: written to its own /proc/N/note (delivered at the
 *		write's return) and an alarm that interrupts a blocking
 *		sleep (delivered at the sleep's return, after a switch
 *		away and back).  r9 x86_64 delivers notes only at a syscall
 *		boundary — an alarm cannot interrupt ring-3 code — so the
 *		aarch64 probe's spinning variant does not apply here.  The
 *		handler first stores what it started with (it must be a copy
 *		of the interrupted state), loads a different pattern, and
 *		returns with noted(NCONT); the interrupted code must then
 *		find its own pattern (9front's notify/noted FP save)
 *
 * usage: fpprobe [-n rounds] [-p rounds] [-s spin] [-w workers]
 * Prints `fpprobe: ok' and exits nil, or one `fpprobe: BAD <leg> ...'
 * line per failing check (the first differing field and the number of
 * differing bytes) and `fpprobe: FAIL <legs>', with a non-nil status.
 */

enum {
	Nfx = 512,	/* the FXSAVE image */
	Nleg = 5,
	Maxworker = 8,
};

/* fpprobeasm.s */
extern void	fpload(uchar *b);
extern void	fpstore(uchar *b);

static char *self = "/bin/fpprobe";
static char *legname[Nleg] = { "syscall", "yield", "block", "spin", "errstr" };
static int rounds = 20;
static int prounds = 4;
static long spinn = 20000000;
static int nworker = 2;
static long sink;
static uchar entryraw[Nfx+16];

static void
usage(void)
{
	fprint(2, "usage: fpprobe [-n rounds] [-p rounds] [-s spin] [-w workers]\n");
	exits("usage");
}

/* FXSAVE images must be 16-byte aligned; raw holds Nfx+16 bytes */
static uchar*
aligned(uchar *raw)
{
	return (uchar*)(((uintptr)raw + 15) & ~(uintptr)15);
}

static void
put8(uchar *p, uvlong v)
{
	int i;

	for(i = 0; i < 8; i++)
		p[i] = v>>(8*i);
}

static uvlong
lcg(uvlong x)
{
	return x*0x5851f42d4c957f2dULL + 0x14057b7ef767814fULL;
}

/*
 * A valid FXSAVE image unique to (seed, round): FCW with every x87
 * exception masked and the precision/rounding fields varied, MXCSR with
 * every SSE exception masked plus rounding, FZ and sticky flags varied
 * (never DAZ, which old CPUs fault on), all eight ST registers tagged
 * valid with distinct contents, distinct XMM0-15.
 */
static void
pattern(uchar *b, int seed, int round)
{
	int i;
	uvlong x;
	ulong fcw, mx;

	for(i = 0; i < Nfx; i++)
		b[i] = 0;
	fcw = 0x3f | (seed&3)<<8 | ((seed>>2)+round&3)<<10;
	b[0] = fcw;
	b[1] = fcw>>8;
	b[4] = 0xff;
	mx = 0x1f80 | (seed+round&3)<<13 | (seed&1)<<15 | (seed*7+round&0x3f);
	b[24] = mx;
	b[25] = mx>>8;
	x = (uvlong)seed<<56 | (uvlong)round<<40 | 0x5a5a;
	for(i = 0; i < 8; i++){
		x = lcg(x);
		put8(b+32+16*i, x);
		b[40+16*i] = (x>>48) | 1;
		b[41+16*i] = x>>56;
	}
	for(i = 0; i < 16; i++){
		x = lcg(x);
		put8(b+160+16*i, x);
		x = lcg(x);
		put8(b+168+16*i, x);
	}
}

/* the default state an exec'd image must start with */
static void
dflt(uchar *b)
{
	int i;

	for(i = 0; i < Nfx; i++)
		b[i] = 0;
	b[0] = 0x7f;
	b[1] = 0x03;
	b[24] = 0x80;
	b[25] = 0x1f;
}

/* is byte i part of the compared user-visible state? */
static int
visible(int i)
{
	if(i < 5 || (i >= 24 && i < 28) || (i >= 160 && i < 416))
		return 1;
	if(i >= 32 && i < 160 && (i-32)%16 < 10)
		return 1;
	return 0;
}

static char*
field(int i, char *buf, int n)
{
	if(i < 2)
		return "fcw";
	if(i < 4)
		return "fsw";
	if(i == 4)
		return "ftw";
	if(i < 28)
		return "mxcsr";
	if(i < 160){
		snprint(buf, n, "st%d.byte%d", (i-32)/16, (i-32)%16);
		return buf;
	}
	snprint(buf, n, "xmm%d.byte%d", (i-160)/16, (i-160)%16);
	return buf;
}

static void
report(char *leg, int seed, int round, uchar *want, uchar *got, int i)
{
	int j, nbad;
	char buf[32];

	nbad = 0;
	for(j = 0; j < Nfx; j++)
		if(visible(j) && want[j] != got[j])
			nbad++;
	print("fpprobe: BAD %s seed=%d round=%d %s want=%02ux got=%02ux nbad=%d\n",
		leg, seed, round, field(i, buf, sizeof buf), want[i], got[i], nbad);
}

/* first differing visible byte, or -1 */
static int
differ(uchar *want, uchar *got)
{
	int i;

	for(i = 0; i < Nfx; i++)
		if(visible(i) && want[i] != got[i])
			return i;
	return -1;
}

static int
check(char *leg, int seed, int round, uchar *want, uchar *got)
{
	int i;

	i = differ(want, got);
	if(i < 0)
		return 0;
	report(leg, seed, round, want, got, i);
	return -1;
}

/* wait for one child; -1 unless it exited nil */
static int
reap(char *leg)
{
	Waitmsg *w;
	int r;

	w = wait();
	if(w == nil){
		print("fpprobe: BAD %s wait: %r\n", leg);
		return -1;
	}
	r = 0;
	if(w->msg[0] != 0){
		print("fpprobe: BAD %s child %d: %s\n", leg, w->pid, w->msg);
		r = -1;
	}
	free(w);
	return r;
}

static int
forkleg(void)
{
	uchar wraw[Nfx+16], graw[Nfx+16], *want, *got;
	int pid, bad;

	want = aligned(wraw);
	got = aligned(graw);
	pattern(want, 7, 0);
	fpload(want);
	pid = rfork(RFPROC|RFFDG);
	fpstore(got);
	if(pid < 0){
		print("fpprobe: BAD fork rfork: %r\n");
		return -1;
	}
	bad = check(pid == 0? "fork-child": "fork-parent", 7, 0, want, got);
	if(pid == 0)
		exits(bad < 0? "bad": nil);
	if(reap("fork") < 0)
		bad = -1;
	return bad;
}

static int
execleg(void)
{
	uchar raw[Nfx+16], *b;
	char *args[3];
	int pid;

	pid = rfork(RFPROC|RFFDG);
	if(pid < 0){
		print("fpprobe: BAD exec rfork: %r\n");
		return -1;
	}
	if(pid == 0){
		args[0] = self;
		args[1] = "-e";
		args[2] = nil;
		b = aligned(raw);
		pattern(b, 9, 1);
		fpload(b);
		exec(self, args);
		print("fpprobe: BAD exec %s: %r\n", self);
		exits("exec");
	}
	return reap("exec");
}

/* the exec'd image: the state stored at entry must be the default */
static int
execcheck(uchar *e)
{
	uchar draw[Nfx+16], *d;

	d = aligned(draw);
	dflt(d);
	return check("exec", 9, 1, d, e);
}

/*
 * One switch-leg worker: every round runs (a failure does not stop
 * the worker, so each sub-leg is measured), and the first failure of
 * each sub-leg is reported.
 */
static int
work(int seed, int spinonly)
{
	uchar wraw[Nfx+16], graw[Nfx+16], *want, *got;
	char ebuf[ERRMAX];
	int r, i, leg, bad, badleg[Nleg];
	long n, acc;

	want = aligned(wraw);
	got = aligned(graw);
	strcpy(ebuf, "fpprobe");
	for(i = 0; i < Nleg; i++)
		badleg[i] = 0;
	bad = 0;
	for(r = 0; r < (spinonly? prounds: rounds); r++){
		leg = spinonly? 3: r % Nleg;
		pattern(want, seed, r);
		fpload(want);
		switch(leg){
		case 0:
			for(i = 0; i < 50; i++)
				alarm(0);
			break;
		case 1:
			for(i = 0; i < 50; i++)
				sleep(0);
			break;
		case 2:
			for(i = 0; i < 5; i++)
				sleep(1);
			break;
		case 3:
			acc = 0;
			for(n = 0; n < spinn; n++)
				acc += n ^ (acc>>3);
			sink = acc;
			break;
		case 4:
			for(i = 0; i < 20; i++)
				errstr(ebuf, sizeof ebuf);
			break;
		}
		fpstore(got);
		i = differ(want, got);
		if(i >= 0){
			if(badleg[leg] == 0)
				report(legname[leg], seed, r, want, got, i);
			badleg[leg]++;
			bad = -1;
		}
	}
	return bad;
}

/* run the workers at once; seeds differ per leg and per worker */
static int
workers(char *leg, int seed0, int spinonly)
{
	int i, n, pid, bad;

	bad = 0;
	for(n = 0; n < nworker; n++){
		pid = rfork(RFPROC|RFFDG);
		if(pid < 0){
			print("fpprobe: BAD %s rfork: %r\n", leg);
			bad = -1;
			break;
		}
		if(pid == 0)
			exits(work(seed0+n, spinonly) < 0? "bad": nil);
	}
	for(i = 0; i < n; i++)
		if(reap(leg) < 0)
			bad = -1;
	return bad;
}

/* the note leg's handler state (the handler runs in the same process) */
static uchar nraw[2][Nfx+16];
static uchar *hpat, *hentry;
static volatile int nseen;

static void
nhandler(void *u, char *msg)
{
	USED(u);
	fpstore(hentry);	/* first: the state the handler started with */
	if(strcmp(msg, "alarm") != 0 && strcmp(msg, "fpprobe") != 0)
		noted(NDFLT);
	fpload(hpat);
	nseen++;
	noted(NCONT);
}

/*
 * One note round: load seed's pattern, take a note, compare.  The
 * synchronous note is written through an fd opened beforehand, so only
 * the write stub runs inside the window.
 */
static int
noteround(char *leg, int seed, int nfd)
{
	uchar wraw[Nfx+16], graw[Nfx+16], *want, *got;
	long i;
	int bad;

	want = aligned(wraw);
	got = aligned(graw);
	pattern(want, seed, 0);
	nseen = 0;
	fpload(want);
	if(nfd < 0){
		alarm(50);
		for(i = 0; i < 20 && nseen == 0; i++)
			sleep(1000);
	}else
		write(nfd, "fpprobe", 7);
	fpstore(got);
	if(nseen != 1){
		print("fpprobe: BAD %s handler ran %d times\n", leg, nseen);
		return -1;
	}
	bad = check(leg, seed, 0, want, got);
	if(check("note-entry", seed, 0, want, hentry) < 0)
		bad = -1;
	return bad;
}

static int
noteleg(void)
{
	char path[64];
	int pid, bad, nfd;

	pid = rfork(RFPROC|RFFDG);
	if(pid < 0){
		print("fpprobe: BAD note rfork: %r\n");
		return -1;
	}
	if(pid != 0)
		return reap("note");
	hpat = aligned(nraw[0]);
	hentry = aligned(nraw[1]);
	pattern(hpat, 21, 0);
	snprint(path, sizeof path, "/proc/%d/note", getpid());
	nfd = open(path, OWRITE);
	if(nfd < 0){
		print("fpprobe: BAD note open %s: %r\n", path);
		exits("bad");
	}
	if(notify(nhandler) < 0){
		print("fpprobe: BAD note notify: %r\n");
		exits("bad");
	}
	bad = 0;
	if(noteround("note-sync", 22, nfd) < 0)
		bad = -1;
	if(noteround("note-alarm", 23, -1) < 0)
		bad = -1;
	exits(bad < 0? "bad": nil);
	return 0;
}

void
main(int argc, char *argv[])
{
	uchar *e;
	int eflag;
	char fails[64];

	/* first: the FPU/SSE state this image started with */
	e = aligned(entryraw);
	fpstore(e);

	eflag = 0;
	ARGBEGIN{
	case 'e':
		eflag = 1;
		break;
	case 'n':
		rounds = atoi(EARGF(usage()));
		break;
	case 'p':
		prounds = atoi(EARGF(usage()));
		break;
	case 's':
		spinn = atol(EARGF(usage()));
		break;
	case 'w':
		nworker = atoi(EARGF(usage()));
		if(nworker < 1 || nworker > Maxworker)
			usage();
		break;
	default:
		usage();
	}ARGEND
	if(argc != 0)
		usage();
	if(eflag)
		exits(execcheck(e) < 0? "bad": nil);

	fails[0] = 0;
	if(forkleg() < 0)
		strcat(fails, " fork");
	if(execleg() < 0)
		strcat(fails, " exec");
	if(workers("switch", 1, 0) < 0)
		strcat(fails, " switch");
	if(workers("preempt", 1+Maxworker, 1) < 0)
		strcat(fails, " preempt");
	if(noteleg() < 0)
		strcat(fails, " note");
	if(fails[0] == 0){
		print("fpprobe: ok\n");
		exits(nil);
	}
	print("fpprobe: FAIL%s\n", fails);
	exits("fail");
}
