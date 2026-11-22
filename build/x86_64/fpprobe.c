#include <u.h>
#include <libc.h>
#include <ureg.h>

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
 * Legs (all six must pass for `fpprobe: ok'):
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
 *	note	a child with a notify handler takes notes five ways:
 *		sync	written to its own /proc/N/note (delivered at the
 *			write's return)
 *		sleep	an alarm interrupts a blocking sleep (delivered at
 *			the sleep's return, after a switch away and back)
 *		spin	an alarm interrupts integer code in ring 3
 *			(delivered on the interrupt return)
 *		regs	an alarm interrupts gprspin (fpprobeasm.s), which
 *			holds a sentinel in every general register it may
 *			use, CX and R11 included: noted(NCONT) must restore
 *			them all, so it cannot return through SYSRET (which
 *			loads CX and R11 with the return pc and flags)
 *		nsave	the handler retargets the saved pc at a trampoline
 *			and calls noted(NSAVE); the trampoline must start
 *			with the interrupted code's FP state, take a second
 *			note (NSAVE re-enables notes), restore the pc and
 *			noted(NRSTR) back to the program (notify(2))
 *		For the first three the handler first stores what it
 *		started with (it must be a copy of the interrupted state),
 *		loads a different pattern, and returns with noted(NCONT);
 *		the interrupted code must then find its own pattern
 *		(9front's notify/noted FP save)
 *	flags	RFLAGS bits user code may set with POPFQ — TF, DF, NT, AC —
 *		must never reach the kernel's own code and must come back
 *		unchanged (r9 x86_64 masks them on SYSCALL and clears DF on
 *		every interrupt entry); each sub-leg runs in its own child:
 *		ac	AC set across a syscall comes back set
 *		df	DF set across a pread and a pwrite of a pipe: the
 *			kernel's copies must still run forwards (data and
 *			guard bytes checked) and DF must come back set
 *		nt	NT set across blocking sleeps while two spinners
 *			are runnable: the scheduler resumes them through
 *			IRETQ, which faults if the kernel holds NT
 *		ntnoted	the handler sets NT and calls noted(NCONT): NOTED
 *			leaves through IRETQ
 *		ntimage	the handler sets NT in the saved flags; the resumed
 *			code then blocks and takes a second note
 *		dfirq	an alarm interrupts dfspin (fpprobeasm.s), which
 *			holds DF and sentinels: the note must arrive intact
 *			at the interrupted pc, every register must survive
 *			and DF must come back set
 *		tf	TF set across a syscall: the single-step trap must
 *			come in ring 3 after the syscall returns, killing
 *			the child with `sys: trap', never in the kernel
 *
 * usage: fpprobe [-n rounds] [-p rounds] [-s spin] [-w workers] [-F sublegs]
 * -F runs only the flags leg's comma-separated sub-legs (or `all').
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
static volatile long vsink;
static uchar entryraw[Nfx+16];

static void
usage(void)
{
	fprint(2, "usage: fpprobe [-n rounds] [-p rounds] [-s spin] [-w workers] [-F sublegs]\n");
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
enum {
	Mwrite,	/* the note is written to our own /proc/N/note */
	Msleep,	/* an alarm interrupts a blocking sleep */
	Mspin,	/* an alarm interrupts integer code */
};
static uchar nraw[4][Nfx+16];
static uchar *hpat, *hentry, *hnow, *tentry;
static volatile int nseen, nsave, nested, tramped, nsavefail;
static uintptr savedpc;
static int nfdg;
static uvlong gregs[16];	/* gprspin: [0] the handler's flag, [1..12] the registers */

/* fpprobeasm.s */
extern void	gprspin(uvlong *b);

static void
copyfx(uchar *dst, uchar *src)
{
	int i;

	for(i = 0; i < Nfx; i++)
		dst[i] = src[i];
}

/* the NSAVE trampoline: entered at the retargeted pc on the handler's stack */
static void
tramp(void *u, char *msg)
{
	struct Ureg *ur;

	USED(msg);
	fpstore(tentry);	/* first: NSAVE must have restored the interrupted state */
	ur = u;
	tramped++;
	write(nfdg, "fpprobe2", 8);	/* notes are enabled again: this one nests */
	ur->ip = savedpc;
	noted(NRSTR);
}

static void
nhandler(void *u, char *msg)
{
	struct Ureg *ur;

	fpstore(hnow);	/* first: the state the handler started with */
	ur = u;
	if(strcmp(msg, "fpprobe2") == 0){
		nested++;
		noted(NCONT);
	}
	if(strcmp(msg, "alarm") != 0 && strcmp(msg, "fpprobe") != 0)
		noted(NDFLT);
	copyfx(hentry, hnow);
	gregs[0] = 1;
	fpload(hpat);
	nseen++;
	if(nsave){
		savedpc = ur->ip;
		ur->ip = (uintptr)tramp;
		noted(NSAVE);
		nsavefail = 1;	/* noted returned: NSAVE was refused */
		ur->ip = savedpc;
	}
	noted(NCONT);
}

/*
 * One FP note round: load seed's pattern, take a note, compare.  The
 * synchronous note is written through an fd opened beforehand, so only
 * the write stub runs inside the window.
 */
static int
noteround(char *leg, int seed, int mode)
{
	uchar wraw[Nfx+16], graw[Nfx+16], *want, *got;
	long i;
	int bad;

	want = aligned(wraw);
	got = aligned(graw);
	pattern(want, seed, 0);
	nseen = 0;
	fpload(want);
	switch(mode){
	case Mwrite:
		write(nfdg, "fpprobe", 7);
		break;
	case Msleep:
		alarm(50);
		for(i = 0; i < 20 && nseen == 0; i++)
			sleep(1000);
		break;
	case Mspin:
		alarm(50);
		for(i = 0; i < 200000000 && nseen == 0; i++)
			vsink += i;
		break;
	}
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

/* the register round: every register gprspin uses survives an async note */
static int
regsround(void)
{
	static char *name[] = { "ax", "bx", "cx", "dx", "si", "di", "r8", "r9", "r10", "r11", "r12" };
	static uvlong want[] = {
		0x1111111111111101ULL, 0x1111111111111102ULL, 0x1111111111111103ULL,
		0x1111111111111104ULL, 0x1111111111111105ULL, 0x1111111111111106ULL,
		0x1111111111111108ULL, 0x1111111111111109ULL, 0x111111111111110aULL,
		0x111111111111110bULL, 0x111111111111110cULL,
	};
	int i, bad;

	gregs[0] = 0;
	nseen = 0;
	alarm(50);
	gprspin(gregs);
	if(nseen != 1){
		print("fpprobe: BAD note-regs handler ran %d times\n", nseen);
		return -1;
	}
	bad = 0;
	for(i = 0; i < nelem(want); i++)
		if(gregs[1+i] != want[i]){
			print("fpprobe: BAD note-regs %s want=%llux got=%llux\n", name[i], want[i], gregs[1+i]);
			bad = -1;
		}
	return bad;
}

/* the NSAVE round: trampoline, a nested note, NRSTR back */
static int
nsaveround(void)
{
	uchar wraw[Nfx+16], graw[Nfx+16], *want, *got;
	int bad;

	want = aligned(wraw);
	got = aligned(graw);
	pattern(want, 24, 0);
	nseen = nested = tramped = nsavefail = 0;
	nsave = 1;
	fpload(want);
	write(nfdg, "fpprobe", 7);
	fpstore(got);
	nsave = 0;
	if(nsavefail){
		print("fpprobe: BAD note-nsave noted(NSAVE) refused\n");
		return -1;
	}
	if(nseen != 1 || tramped != 1 || nested != 1){
		print("fpprobe: BAD note-nsave handler %d trampoline %d nested %d (want 1 1 1)\n", nseen, tramped, nested);
		return -1;
	}
	bad = check("note-nsave", 24, 0, want, got);
	if(check("note-tramp-entry", 24, 0, want, tentry) < 0)
		bad = -1;
	return bad;
}

static int
noteleg(void)
{
	char path[64];
	int pid, bad;

	pid = rfork(RFPROC|RFFDG);
	if(pid < 0){
		print("fpprobe: BAD note rfork: %r\n");
		return -1;
	}
	if(pid != 0)
		return reap("note");
	hpat = aligned(nraw[0]);
	hentry = aligned(nraw[1]);
	hnow = aligned(nraw[2]);
	tentry = aligned(nraw[3]);
	pattern(hpat, 21, 0);
	snprint(path, sizeof path, "/proc/%d/note", getpid());
	nfdg = open(path, OWRITE);
	if(nfdg < 0){
		print("fpprobe: BAD note open %s: %r\n", path);
		exits("bad");
	}
	if(notify(nhandler) < 0){
		print("fpprobe: BAD note notify: %r\n");
		exits("bad");
	}
	bad = 0;
	if(noteround("note-sync", 22, Mwrite) < 0)
		bad = -1;
	if(noteround("note-sleep", 23, Msleep) < 0)
		bad = -1;
	if(noteround("note-spin", 25, Mspin) < 0)
		bad = -1;
	if(regsround() < 0)
		bad = -1;
	if(nsaveround() < 0)
		bad = -1;
	exits(bad < 0? "bad": nil);
	return 0;
}

/* the flags leg: RFLAGS bits and the system call numbers it uses */
enum {
	Ftf = 1<<8,
	Fdf = 1<<10,
	Fnt = 1<<14,
	Fac = 1<<18,

	/* /sys/src/libc/9syscall/sys.h */
	Sysalarm = 6,
	Syssleep = 17,
	Sysnoted = 29,
	Syspread = 50,
	Syspwrite = 51,

	Ndf = 1024,	/* df: bytes copied */
	Nguard = 64,	/* df: guard bytes on each side */
	Guard = 0xa5,

	Mntnoted = 0,	/* the flags note handler's modes */
	Mntimage,
	Mdfirq,
};

/* fpprobeasm.s; flagcall reads fcnr and fcset and writes fcout */
extern uvlong	flagcall(uvlong a0, uvlong a1, uvlong a2, uvlong a3);
extern uvlong	getflags(void);
extern void	clrflags(uvlong bits);
extern void	cldf(void);
extern void	dfspin(uvlong *b);
uvlong fcnr, fcset, fcout;

static int fmode, fnfd;
static volatile int fseen, frefused;
static uintptr fip;

static void
bpattern(uchar *b, int n, int seed)
{
	uvlong x;
	int i;

	x = seed;
	for(i = 0; i < n; i++){
		x = lcg(x);
		b[i] = x>>56;
	}
}

/* got holds Nguard guard bytes, the Ndf copied bytes, Nguard guard bytes */
static int
dfcheck(char *what, uchar *want, uchar *got)
{
	int i, first, nbad;
	uchar w;

	first = -1;
	nbad = 0;
	for(i = 0; i < Nguard+Ndf+Nguard; i++){
		if(i < Nguard || i >= Nguard+Ndf)
			w = Guard;
		else
			w = want[i-Nguard];
		if(got[i] != w){
			if(first < 0)
				first = i;
			nbad++;
		}
	}
	if(nbad == 0)
		return 0;
	print("fpprobe: BAD flags-df %s byte %d (guard %d, data %d) want=%02ux got=%02ux nbad=%d\n",
		what, first-Nguard, Nguard, Ndf, first < Nguard || first >= Nguard+Ndf? Guard: want[first-Nguard],
		got[first], nbad);
	return -1;
}

static int
fac(void)
{
	vlong r;

	fcnr = Sysalarm;
	fcset = Fac;
	r = flagcall(0, 0, 0, 0);
	if(r < 0 || (fcout & Fac) == 0){
		print("fpprobe: BAD flags-ac r=%lld rflags=%llux (AC not handed back)\n", r, fcout);
		return -1;
	}
	return 0;
}

static int
fdf(void)
{
	static uchar want[Ndf], got[Nguard+Ndf+Nguard];
	int p[2], bad;
	vlong r;

	if(pipe(p) < 0){
		print("fpprobe: BAD flags-df pipe: %r\n");
		return -1;
	}
	bad = 0;
	/* in normally, out with DF set */
	bpattern(want, Ndf, 31);
	if(write(p[0], want, Ndf) != Ndf){
		print("fpprobe: BAD flags-df write: %r\n");
		return -1;
	}
	memset(got, Guard, sizeof got);
	fcnr = Syspread;
	fcset = Fdf;
	r = flagcall(p[1], (uintptr)(got+Nguard), Ndf, ~0ULL);
	if(r != Ndf || (fcout & Fdf) == 0){
		print("fpprobe: BAD flags-df pread r=%lld rflags=%llux\n", r, fcout);
		bad = -1;
	}
	if(dfcheck("pread", want, got) < 0)
		bad = -1;
	/* in with DF set, out normally */
	bpattern(want, Ndf, 32);
	fcnr = Syspwrite;
	fcset = Fdf;
	r = flagcall(p[0], (uintptr)want, Ndf, ~0ULL);
	if(r != Ndf || (fcout & Fdf) == 0){
		print("fpprobe: BAD flags-df pwrite r=%lld rflags=%llux\n", r, fcout);
		bad = -1;
	}
	memset(got, Guard, sizeof got);
	if(readn(p[1], got+Nguard, Ndf) != Ndf){
		print("fpprobe: BAD flags-df read: %r\n");
		return -1;
	}
	if(dfcheck("pwrite", want, got) < 0)
		bad = -1;
	close(p[0]);
	close(p[1]);
	return bad;
}

static int
fnt(void)
{
	int i, n, pid, bad;
	long k, acc;
	vlong r;

	/* two pure spinners keep the scheduler resuming through IRETQ */
	for(n = 0; n < 2; n++){
		pid = rfork(RFPROC|RFFDG);
		if(pid < 0){
			print("fpprobe: BAD flags-nt rfork: %r\n");
			return -1;
		}
		if(pid == 0){
			acc = 0;
			for(k = 0; k < spinn; k++)
				acc += k ^ (acc>>3);
			sink = acc;
			exits(nil);
		}
	}
	bad = 0;
	for(i = 0; i < 20; i++){
		fcnr = Syssleep;
		fcset = Fnt;
		r = flagcall(1, 0, 0, 0);
		if((r != 0 || (fcout & Fnt) == 0) && bad == 0){
			print("fpprobe: BAD flags-nt sleep %d r=%lld rflags=%llux\n", i, r, fcout);
			bad = -1;
		}
	}
	for(n = 0; n < 2; n++)
		if(reap("flags-nt") < 0)
			bad = -1;
	return bad;
}

static void
fhandler(void *u, char *msg)
{
	struct Ureg *ur;

	cldf();	/* dfirq interrupted code holding DF: keep it out of here */
	ur = u;
	fseen++;
	if(strcmp(msg, fmode == Mdfirq? "alarm": "fpprobe") != 0){
		print("fpprobe: BAD flags handler note %.32s\n", msg);
		exits("bad");
	}
	switch(fmode){
	case Mntnoted:
		fcnr = Sysnoted;
		fcset = Fnt;
		flagcall(NCONT, 0, 0, 0);
		frefused = 1;	/* noted returned: refused */
		break;
	case Mntimage:
		if(fseen == 1)
			ur->flags |= Fnt;
		break;
	case Mdfirq:
		fip = ur->ip;
		gregs[0] = 1;
		break;
	}
	noted(NCONT);
}

static int
fsetup(char *leg, int mode)
{
	char path[64];

	fmode = mode;
	fseen = frefused = 0;
	snprint(path, sizeof path, "/proc/%d/note", getpid());
	fnfd = open(path, OWRITE);
	if(fnfd < 0){
		print("fpprobe: BAD flags-%s open %s: %r\n", leg, path);
		return -1;
	}
	if(notify(fhandler) < 0){
		print("fpprobe: BAD flags-%s notify: %r\n", leg);
		return -1;
	}
	return 0;
}

static int
fntnoted(void)
{
	if(fsetup("ntnoted", Mntnoted) < 0)
		return -1;
	write(fnfd, "fpprobe", 7);
	if(fseen != 1 || frefused){
		print("fpprobe: BAD flags-ntnoted handler ran %d times%s\n", fseen, frefused? ", noted refused": "");
		return -1;
	}
	return 0;
}

static int
fntimage(void)
{
	if(fsetup("ntimage", Mntimage) < 0)
		return -1;
	write(fnfd, "fpprobe", 7);	/* the handler sets NT in the saved flags */
	sleep(1);			/* ring 3 may now hold NT: block */
	write(fnfd, "fpprobe", 7);	/* and a second NOTED through IRETQ */
	clrflags(Fnt);
	if(fseen != 2){
		print("fpprobe: BAD flags-ntimage handler ran %d times (want 2)\n", fseen);
		return -1;
	}
	return 0;
}

static int
fdfirq(void)
{
	int i, bad;

	if(fsetup("dfirq", Mdfirq) < 0)
		return -1;
	gregs[0] = 0;
	alarm(50);
	dfspin(gregs);
	if(fseen != 1){
		print("fpprobe: BAD flags-dfirq handler ran %d times\n", fseen);
		return -1;
	}
	bad = 0;
	if(fip < (uintptr)dfspin || fip >= (uintptr)dfspin+0x100){
		print("fpprobe: BAD flags-dfirq saved pc %#p not in dfspin %#p\n", (void*)fip, (void*)dfspin);
		bad = -1;
	}
	for(i = 1; i <= 11; i++)
		if(gregs[i] != 0x2222222222222200ULL+i+(i>6)){
			print("fpprobe: BAD flags-dfirq register %d want=%llux got=%llux\n",
				i, 0x2222222222222200ULL+i+(i>6), gregs[i]);
			bad = -1;
		}
	if((gregs[13] & Fdf) == 0){
		print("fpprobe: BAD flags-dfirq rflags=%llux (DF not handed back)\n", gregs[13]);
		bad = -1;
	}
	return bad;
}

static int
ftf(void)
{
	fcnr = Sysalarm;
	fcset = Ftf;
	flagcall(0, 0, 0, 0);
	print("fpprobe: BAD flags-tf no single-step trap after the system call\n");
	return -1;
}

static struct {
	char	*name;
	int	(*fn)(void);
	char	*want;	/* the child's exit status must contain this; nil: exit nil */
} flagsubs[] = {
	"ac",		fac,		nil,
	"df",		fdf,		nil,
	"nt",		fnt,		nil,
	"ntnoted",	fntnoted,	nil,
	"ntimage",	fntimage,	nil,
	"dfirq",	fdfirq,		nil,
	"tf",		ftf,		"sys: trap",
};

static int
flagsub(int i)
{
	Waitmsg *w;
	int pid, r;

	pid = rfork(RFPROC|RFFDG);
	if(pid < 0){
		print("fpprobe: BAD flags-%s rfork: %r\n", flagsubs[i].name);
		return -1;
	}
	if(pid == 0)
		exits(flagsubs[i].fn() < 0? "bad": nil);
	w = wait();
	if(w == nil){
		print("fpprobe: BAD flags-%s wait: %r\n", flagsubs[i].name);
		return -1;
	}
	r = 0;
	if(flagsubs[i].want == nil? w->msg[0] != 0: strstr(w->msg, flagsubs[i].want) == nil){
		print("fpprobe: BAD flags-%s child %d: %s\n", flagsubs[i].name, w->pid, w->msg[0]? w->msg: "exited nil");
		r = -1;
	}
	free(w);
	return r;
}

/* the sub-legs named in sel (comma-separated, or "all") */
static int
flagsleg(char *sel)
{
	char buf[128], *f[nelem(flagsubs)+1];
	int i, j, n, bad;

	strecpy(buf, buf+sizeof buf, sel);
	n = getfields(buf, f, nelem(f), 1, ",");
	for(j = 0; j < n; j++){
		if(strcmp(f[j], "all") == 0)
			continue;
		for(i = 0; i < nelem(flagsubs); i++)
			if(strcmp(f[j], flagsubs[i].name) == 0)
				break;
		if(i == nelem(flagsubs)){
			fprint(2, "fpprobe: unknown flags sub-leg %s\n", f[j]);
			exits("usage");
		}
	}
	bad = 0;
	for(i = 0; i < nelem(flagsubs); i++){
		for(j = 0; j < n; j++)
			if(strcmp(f[j], "all") == 0 || strcmp(f[j], flagsubs[i].name) == 0)
				break;
		if(j < n && flagsub(i) < 0)
			bad = -1;
	}
	return bad;
}

void
main(int argc, char *argv[])
{
	uchar *e;
	int eflag;
	char fails[64], *fsel;

	/* first: the FPU/SSE state this image started with */
	e = aligned(entryraw);
	fpstore(e);

	eflag = 0;
	fsel = nil;
	ARGBEGIN{
	case 'e':
		eflag = 1;
		break;
	case 'F':
		fsel = EARGF(usage());
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
	if(fsel != nil){
		if(flagsleg(fsel) < 0){
			print("fpprobe: FAIL flags\n");
			exits("fail");
		}
		print("fpprobe: ok\n");
		exits(nil);
	}
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
	if(flagsleg("all") < 0)
		strcat(fails, " flags");
	if(fails[0] == 0){
		print("fpprobe: ok\n");
		exits(nil);
	}
	print("fpprobe: FAIL%s\n", fails);
	exits("fail");
}
