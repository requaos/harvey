#include <u.h>
#include <libc.h>

/*
 * fpprobe — user FP/SIMD register survival probe (r9 aarch64).
 *
 * A user program's q0..q31, FPCR and FPSR must come back unchanged from
 * every syscall, yield, block and preemption, a fork child must start
 * with its parent's values, and a fresh exec must start from zero.  The
 * kernel must neither use these registers behind the program's back nor
 * leave another process's values in them.
 *
 * fpprobeasm.s loads all 32 q registers plus FPCR and FPSR from a
 * pattern buffer (reading the two control registers back, so bits the
 * hardware does not implement drop out of the expected value) and
 * stores them again.  Between the load and the store only integer code
 * and libc syscall stubs run, none of which touch FP/SIMD registers, so
 * any difference was made by the kernel.
 *
 * Legs (all four must pass for `fpprobe: ok'):
 *	fork	load a pattern, rfork(RFPROC|RFFDG); parent and child both
 *		store and compare (the child must inherit the registers)
 *	exec	a child loads a pattern and execs `fpprobe -e'; the new image
 *		stores the registers before anything else runs in main, and
 *		every word must be zero (q0..q31, FPCR, FPSR)
 *	switch	-w workers (default 2) run at once, each with its own
 *		patterns, -n rounds (default 20) cycling five sub-legs between
 *		load and store: syscall (alarm(0) x50, plain trap entry and
 *		return), yield (sleep(0) x50, r9's reschedule path), block
 *		(sleep(1) x5, sched() and a swtch resume), spin (-s integer
 *		iterations at EL0, default 2000000; see preempt) and errstr
 *		(x20, the kernel copies a buffer both ways); every
 *		round runs, and the first failure of each sub-leg is reported
 *	preempt	-w workers only spin (-p rounds, default 8, of -s iterations):
 *		none blocks, so the timer tick must preempt each at EL0 and
 *		run the other (a woken sleeper never preempts a spinner on
 *		r9 — it resumes only from the sched loop — so the switch
 *		leg's spin rarely overlaps a peer)
 *
 * usage: fpprobe [-n rounds] [-p rounds] [-s spin] [-w workers]
 * Prints `fpprobe: ok' and exits nil, or one `fpprobe: BAD <leg> ...'
 * line per failing check (the first differing word and the number of
 * differing words) and `fpprobe: FAIL <legs>', with a non-nil status.
 */

enum {
	Nw = 66,	/* q0..q31 as 64 words, then fpcr, fpsr */
	Wfpcr = 64,
	Wfpsr = 65,
	Nleg = 5,
	Maxworker = 8,
};

/* fpprobeasm.s */
extern void	fpload(uvlong *b);
extern void	fpstore(uvlong *b);

static char *self = "/bin/fpprobe";
static char *legname[Nleg] = { "syscall", "yield", "block", "spin", "errstr" };
static int rounds = 20;
static int prounds = 8;
static long spinn = 2000000;
static int nworker = 2;
static long sink;
static uvlong entryraw[Nw+2];

static void
usage(void)
{
	fprint(2, "usage: fpprobe [-n rounds] [-p rounds] [-s spin] [-w workers]\n");
	exits("usage");
}

/* the ldp/stp q pairs want a 16-byte aligned buffer; raw holds Nw+2 words */
static uvlong*
aligned(uvlong *raw)
{
	return (uvlong*)(((uintptr)raw + 15) & ~(uintptr)15);
}

/*
 * A pattern unique to (seed, round): 64 vector words from an LCG, FPCR
 * with AHP, DN, FZ and RMode set from the seed and round, and FPSR with
 * a mix of the QC, IDC and IXC..IOC cumulative bits.
 */
static void
pattern(uvlong *b, int seed, int round)
{
	int i;
	uvlong x;

	x = (uvlong)seed<<56 | (uvlong)round<<40 | 0x5a5a;
	for(i = 0; i < Wfpcr; i++){
		x = x*0x5851f42d4c957f2dULL + 0x14057b7ef767814fULL;
		b[i] = x ^ (uvlong)i;
	}
	b[Wfpcr] = (uvlong)(round&3)<<22 | (uvlong)(seed&1)<<24
		| (uvlong)((seed>>1)&1)<<25 | (uvlong)((round>>2)&1)<<26;
	b[Wfpsr] = (uvlong)((seed+round)&1)<<27 | (uvlong)((seed*7+round)&0x9f);
}

static void
report(char *leg, int seed, int round, uvlong *want, uvlong *got, int i)
{
	int j, nbad;

	nbad = 0;
	for(j = 0; j < Nw; j++)
		if(want[j] != got[j])
			nbad++;
	if(i < Wfpcr)
		print("fpprobe: BAD %s seed=%d round=%d q%d.%s want=%llux got=%llux nbad=%d\n",
			leg, seed, round, i/2, (i&1)? "hi": "lo", want[i], got[i], nbad);
	else
		print("fpprobe: BAD %s seed=%d round=%d %s want=%llux got=%llux nbad=%d\n",
			leg, seed, round, i == Wfpcr? "fpcr": "fpsr", want[i], got[i], nbad);
}

static int
check(char *leg, int seed, int round, uvlong *want, uvlong *got)
{
	int i;

	for(i = 0; i < Nw; i++)
		if(want[i] != got[i]){
			report(leg, seed, round, want, got, i);
			return -1;
		}
	return 0;
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
	uvlong wraw[Nw+2], graw[Nw+2], *want, *got;
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
	uvlong raw[Nw+2], *b;
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

/* the exec'd image: every word stored at entry must be zero */
static int
execcheck(uvlong *e)
{
	uvlong zero[Nw];
	int i;

	for(i = 0; i < Nw; i++)
		zero[i] = 0;
	return check("exec", 9, 1, zero, e);
}

/*
 * One switch-leg worker: every round runs (a failure does not stop
 * the worker, so each sub-leg is measured), and the first failure of
 * each sub-leg is reported.
 */
static int
work(int seed, int spinonly)
{
	uvlong wraw[Nw+2], graw[Nw+2], *want, *got;
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
		for(i = 0; i < Nw; i++)
			if(want[i] != got[i])
				break;
		if(i < Nw){
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

void
main(int argc, char *argv[])
{
	uvlong *e;
	int eflag;
	char fails[64];

	/* first: the FP/SIMD state this image started with */
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
	if(fails[0] == 0){
		print("fpprobe: ok\n");
		exits(nil);
	}
	print("fpprobe: FAIL%s\n", fails);
	exits("fail");
}
