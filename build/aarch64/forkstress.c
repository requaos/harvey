#include <u.h>
#include <libc.h>

/*
 * forkstress — fork-image integrity stressor (20-02, WINDOWS #49).
 *
 * The HVF `rc: pushword but no argv!` abort fires in a freshly forked
 * child whose parent held a valid argv, so the child's memory image
 * appears to differ from the parent's at fork.  This program takes rc
 * out of the picture: before every fork the parent writes a pattern
 * that depends on the iteration into a data array, a bss array, a heap
 * array and a stack array; the child re-reads all four and reports the
 * first word that differs in each segment, together with what the wrong
 * word looks like (zero, the previous iteration's pattern, or other).
 * The parent waits and counts a non-empty exit status (a mismatch or a
 * trap) as a failure.
 *
 * The trigger (20-03, from the 20-02 root cause): the defect was a stale
 * TTBR0 switch that left a fork child running on its PARENT's physical
 * pages.  A child on its parent's pages still reads the right bytes
 * unless the parent changes them between fork and the child's first
 * run, and rc does exactly that (poplist before Waitfor).  So after
 * fork returns, the parent overwrites all four arrays with a second
 * pattern before it waits.  A correct child still sees the pre-fork
 * pattern in its own copy; a child on the parent's pages sees the
 * second pattern, counted as `parent` in the DETAIL line.
 *
 * usage: forkstress [-n forks]	(default 200)
 * Prints `forkstress: ok N forks` and exits nil only when no child
 * failed; otherwise `forkstress: FAIL F of N forks`.
 */

enum {
	Nword = 16*1024,	/* 64 KiB, 16 pages, per static segment */
	Nstack = 4*1024,	/* 16 KiB, 4 pages, of live stack */
	Pagemask = 4096-1,
	Nseg = 4,	/* data, bss, heap, stack; seg+Nseg is the parent's post-fork pattern */
};

u32int data[Nword] = { 1 };	/* initialised, so it lands in the data segment */
u32int bss[Nword];

static u32int
pattern(int seg, int k, int i)
{
	return ((u32int)k+1)*0x9e3779b1 ^ (u32int)i*0x01000193 ^ ((u32int)seg+1)*0x5bd1e995;
}

static void
fill(u32int *a, int n, int seg, int k)
{
	int i;

	for(i = 0; i < n; i++)
		a[i] = pattern(seg, k, i);
}

/*
 * Compare a against iteration k's pattern; on a difference print the
 * first bad word and a summary of the bad words, and return 1.
 */
static int
check(char *name, u32int *a, int n, int seg, int k)
{
	int i, first, last, nbad, nzero, nstale, nparent;
	u32int want, got;

	first = -1;
	last = -1;
	nbad = 0;
	nzero = 0;
	nstale = 0;
	nparent = 0;
	for(i = 0; i < n; i++){
		want = pattern(seg, k, i);
		got = a[i];
		if(got == want)
			continue;
		if(first < 0)
			first = i;
		last = i;
		nbad++;
		if(got == 0)
			nzero++;
		else if(got == pattern(seg+Nseg, k, i))
			nparent++;
		else if(k > 0 && got == pattern(seg, k-1, i))
			nstale++;
	}
	if(nbad == 0)
		return 0;
	print("forkstress: MISMATCH seg=%s addr=%p want=%#.8ux got=%#.8ux\n",
		name, &a[first], pattern(seg, k, first), a[first]);
	print("forkstress: DETAIL seg=%s fork=%d nbad=%d zero=%d parent=%d stale=%d other=%d first=%p last=%p pageoff=%#ux\n",
		name, k, nbad, nzero, nparent, nstale, nbad-nzero-nparent-nstale,
		&a[first], &a[last], (uint)((uintptr)&a[first] & Pagemask));
	return 1;
}

static void
usage(void)
{
	fprint(2, "usage: forkstress [-n forks]\n");
	exits("usage");
}

void
main(int argc, char *argv[])
{
	u32int stk[Nstack];
	u32int *heap;
	Waitmsg *w;
	int k, n, bad, nfail;

	n = 200;
	ARGBEGIN{
	case 'n':
		n = atoi(EARGF(usage()));
		break;
	default:
		usage();
	}ARGEND
	if(argc != 0 || n < 1)
		usage();

	heap = malloc(Nword*sizeof(u32int));
	if(heap == nil)
		sysfatal("malloc: %r");
	print("forkstress: start %d forks data=%p bss=%p heap=%p stack=%p\n",
		n, data, bss, heap, stk);

	nfail = 0;
	for(k = 0; k < n; k++){
		fill(data, Nword, 0, k);
		fill(bss, Nword, 1, k);
		fill(heap, Nword, 2, k);
		fill(stk, Nstack, 3, k);
		switch(fork()){
		case -1:
			print("forkstress: fork %d failed: %r\n", k);
			exits("fork");
		case 0:
			bad = 0;
			bad += check("data", data, Nword, 0, k);
			bad += check("bss", bss, Nword, 1, k);
			bad += check("heap", heap, Nword, 2, k);
			bad += check("stack", stk, Nstack, 3, k);
			if(bad > 0)
				exits("mismatch");
			exits(nil);
		}
		/* the trigger: change the parent's copy before the child runs */
		fill(data, Nword, 0+Nseg, k);
		fill(bss, Nword, 1+Nseg, k);
		fill(heap, Nword, 2+Nseg, k);
		fill(stk, Nstack, 3+Nseg, k);
		w = wait();
		if(w == nil){
			print("forkstress: wait after fork %d failed: %r\n", k);
			exits("wait");
		}
		if(w->msg[0] != 0){
			nfail++;
			print("forkstress: child %d of fork %d failed: %s\n", w->pid, k, w->msg);
		}
		free(w);
	}
	if(nfail > 0){
		print("forkstress: FAIL %d of %d forks\n", nfail, n);
		exits("mismatch");
	}
	print("forkstress: ok %d forks\n", n);
	exits(nil);
}
