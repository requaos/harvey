#include <u.h>
#include <libc.h>

/*
 * brkprobe — the lone-member RFMEM brk probe (20-07, D-09).
 *
 * r9 moves an RFMEM family's break family-wide: grown pages are mapped
 * into every member at brk time.  A family whose other members have
 * exited is treated as a private proc: only the end moves, and the new
 * pages are left to the demand pager.  x86_64 had to map that growth
 * eagerly; this probe measures whether aarch64 needs the same.
 *
 * Phase lone: fork an RFMEM child that exits at once, wait for it (the
 * parent is now the lone member of what was a family), grow the break
 * by Grow bytes with sbrk, write one byte in every page of the new
 * range and read them all back.
 *
 * Phase family (the control): fork an RFMEM child that stays alive,
 * grow and touch the range in the parent, then let the child check
 * the parent's bytes and write its own; the parent checks the child's.
 *
 * Phase plain (-p, a control, not run by default): the same growth and
 * touch with no fork at all, so a failure there is not about RFMEM.
 *
 * usage: brkprobe [-lfp]	(-l lone only, -f family only, -p plain
 * only; default: lone then family)
 *
 * Prints `brkprobe: ok <bytes>' and exits nil when the phases pass;
 * otherwise `brkprobe: MISMATCH addr=<hex> ...' or `brkprobe: FAIL ...'
 * and a non-nil status.  A fault kills the process with the kernel's
 * note instead.
 */

enum {
	Grow = 8*1024*1024,
	Page = 4096,
	Spins = 1000,	/* child waits at most Spins*10 ms for the parent */
};

/* shared with the RFMEM child (Data/Bss are family-wide) */
volatile int grown;
uchar *volatile region;

/*
 * The byte written at offset off by writer who.  The & 0xff is
 * load-bearing: measured on arm64 (20-07), 7c does not narrow a uchar
 * function result, so without it a pattern value above 0xff compared
 * unequal to the byte stored in memory.
 */
static uchar
pat(ulong off, int who)
{
	return ((off/Page)*31 + who*0x5a + 1) & 0xff;
}

static void
touch(uchar *p, ulong n, ulong skew, int who)
{
	ulong i;

	for(i = 0; i < n; i += Page)
		p[i+skew] = pat(i, who);
}

/* return the offset of the first bad byte, or -1 */
static long
verify(uchar *p, ulong n, ulong skew, int who)
{
	ulong i;

	for(i = 0; i < n; i += Page)
		if(p[i+skew] != pat(i, who))
			return i+skew;
	return -1;
}

static uchar*
grow(char *phase)
{
	uchar *p;

	p = sbrk(Grow);
	if(p == (uchar*)-1){
		print("brkprobe: FAIL %s sbrk(%d): %r\n", phase, Grow);
		exits("sbrk");
	}
	return p;
}

static void
reap(char *phase)
{
	Waitmsg *w;

	w = wait();
	if(w == nil){
		print("brkprobe: FAIL %s wait: %r\n", phase);
		exits("wait");
	}
	if(w->msg[0] != '\0'){
		print("brkprobe: FAIL %s child: %s\n", phase, w->msg);
		exits("child");
	}
	free(w);
}

static void
lone(void)
{
	uchar *p;
	long bad;

	switch(rfork(RFPROC|RFMEM)){
	case -1:
		print("brkprobe: FAIL lone rfork: %r\n");
		exits("rfork");
	case 0:
		exits(nil);
	}
	reap("lone");
	p = grow("lone");
	touch(p, Grow, 0, 1);
	bad = verify(p, Grow, 0, 1);
	if(bad >= 0){
		print("brkprobe: MISMATCH addr=%#p phase=lone page=%ld want=%#.2ux got=%#.2ux\n",
			p+bad, bad/Page, pat(bad, 1), p[bad]);
		exits("mismatch");
	}
	print("brkprobe: phase lone ok %d (break %#p..%#p)\n", Grow, p, p+Grow);
}

static void
family(void)
{
	char buf[64];
	uchar *p;
	long bad;
	int i;

	grown = 0;
	region = nil;
	switch(rfork(RFPROC|RFMEM)){
	case -1:
		print("brkprobe: FAIL family rfork: %r\n");
		exits("rfork");
	case 0:
		for(i = 0; i < Spins && grown == 0; i++)
			sleep(10);
		if(grown == 0)
			exits("family: parent never grew");
		bad = verify(region, Grow, 0, 2);
		if(bad >= 0){
			snprint(buf, sizeof buf, "family: child MISMATCH addr=%#p", region+bad);
			exits(buf);
		}
		touch(region, Grow, 1, 3);
		exits(nil);
	}
	p = grow("family");
	touch(p, Grow, 0, 2);
	region = p;
	grown = 1;
	reap("family");
	bad = verify(p, Grow, 1, 3);
	if(bad >= 0){
		print("brkprobe: MISMATCH addr=%#p phase=family (child's bytes) want=%#.2ux got=%#.2ux\n",
			p+bad, pat(bad-1, 3), p[bad]);
		exits("mismatch");
	}
	print("brkprobe: phase family ok %d (break %#p..%#p)\n", Grow, p, p+Grow);
}

static void
plain(void)
{
	uchar *p;
	long bad;

	p = grow("plain");
	touch(p, Grow, 0, 4);
	bad = verify(p, Grow, 0, 4);
	if(bad >= 0){
		print("brkprobe: MISMATCH addr=%#p phase=plain page=%ld want=%#.2ux got=%#.2ux\n",
			p+bad, bad/Page, pat(bad, 4), p[bad]);
		exits("mismatch");
	}
	print("brkprobe: phase plain ok %d (break %#p..%#p)\n", Grow, p, p+Grow);
}

static void
usage(void)
{
	fprint(2, "usage: brkprobe [-lfp]\n");
	exits("usage");
}

void
main(int argc, char *argv[])
{
	int lflag, fflag, pflag;

	lflag = 0;
	fflag = 0;
	pflag = 0;
	ARGBEGIN{
	case 'l':
		lflag = 1;
		break;
	case 'f':
		fflag = 1;
		break;
	case 'p':
		pflag = 1;
		break;
	default:
		usage();
	}ARGEND
	if(lflag == 0 && fflag == 0 && pflag == 0){
		lflag = 1;
		fflag = 1;
	}
	print("brkprobe: start break=%#p\n", sbrk(0));
	if(pflag)
		plain();
	if(lflag)
		lone();
	if(fflag)
		family();
	print("brkprobe: ok %d\n", Grow);
	exits(nil);
}
