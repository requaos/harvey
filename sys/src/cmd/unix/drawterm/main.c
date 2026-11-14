#include "u.h"
#include "lib.h"
#include "kern/dat.h"
#include "kern/fns.h"
#include "user.h"

#include "drawterm.h"

char *argv0;
char *user;

extern int errfmt(Fmt*);
void
sizebug(void)
{
	/*
	 * Needed by various parts of the code.
	 * This is a huge bug.
	 */
	assert(sizeof(char)==1);
	assert(sizeof(short)==2);
	assert(sizeof(ushort)==2);
	assert(sizeof(int)==4);
	assert(sizeof(uint)==4);
	assert(sizeof(long)==4);
	assert(sizeof(ulong)==4);
	assert(sizeof(vlong)==8);
	assert(sizeof(uvlong)==8);
}

int
main(int argc, char **argv)
{
	eve = getuser();
	if(eve == nil)
		eve = "drawterm";

	sizebug();

	/*
	 * -G/-O pre-scan: Gflag and -O validation must be settled
	 * before screeninit opens a display (a usage error on a
	 * headless run has to say usage, not die at the display open).
	 */
	earlyflags(argc, argv);

	osinit();
	procinit0();
	printinit();
	if(Gflag)
		gconsinit();
	else
		screeninit();

	chandevreset();
	chandevinit();
	quotefmtinstall();

	if(bind("#c", "/dev", MBEFORE) < 0)
		panic("bind #c: %r");
	if(!Gflag){
		/* mouse and draw exist only with a window behind them */
		if(bind("#m", "/dev", MBEFORE) < 0)
			panic("bind #m: %r");
		if(bind("#i", "/dev", MBEFORE) < 0)
			panic("bind #i: %r");
	}
	if(bind("#I", "/net", MBEFORE) < 0)
		panic("bind #I: %r");
	if(bind("#U", "/", MAFTER) < 0)
		panic("bind #U: %r");
	bind("#A", "/dev", MAFTER);

	if(open("/dev/cons", OREAD) != 0)
		panic("open0: %r");
	if(open("/dev/cons", OWRITE) != 1)
		panic("open1: %r");
	if(open("/dev/cons", OWRITE) != 2)
		panic("open2: %r");

	cpumain(argc, argv);
	return 0;
}

char*
getkey(char *user, char *dom)
{
	char buf[1024];

	snprint(buf, sizeof buf, "%s@%s password", user, dom);
	return readcons(buf, nil, 1);
}

char*
findkey(char **puser, char *dom)
{
	char buf[1024], *f[50], *p, *ep, *nextp, *pass, *user;
	int nf, haveproto,  havedom, i;

	for(p=secstorebuf; *p; p=nextp){
		nextp = strchr(p, '\n');
		if(nextp == nil){
			ep = p+strlen(p);
			nextp = "";
		}else{
			ep = nextp++;
		}
		if(ep-p >= sizeof buf){
			print("warning: skipping long line in secstore factotum file\n");
			continue;
		}
		memmove(buf, p, ep-p);
		buf[ep-p] = 0;
		nf = tokenize(buf, f, nelem(f));
		if(nf == 0 || strcmp(f[0], "key") != 0)
			continue;
		pass = nil;
		haveproto = havedom = 0;
		user = nil;
		for(i=1; i<nf; i++){
			if(strncmp(f[i], "user=", 5) == 0)
				user = f[i]+5;
			if(strncmp(f[i], "!password=", 10) == 0)
				pass = f[i]+10;
			if(strncmp(f[i], "dom=", 4) == 0 && strcmp(f[i]+4, dom) == 0)
				havedom = 1;
			if(strcmp(f[i], "proto=p9sk1") == 0)
				haveproto = 1;
		}
	if(!haveproto || !havedom || !pass || !user)
		continue;
	*puser = strdup(user);
	pass = strdup(pass);
	memset(buf, 0, sizeof buf);
	return pass;
	}
	return nil;
}

/*
 * -G: the no-window stdio session (19-06, D-04).  The invoking
 * terminal IS the console: stdin feeds /dev/cons, console output
 * writes the real stdout, and drawterm puts its own tty into raw
 * mode (restored on every exit through atexit).  The gui backends
 * stay untouched for windowed use; a gui-none build never reaches
 * them on the -G path.
 */

/* OS-level calls from here down: the kern name mapping stops at
 * this line (write/atexit are the host's) */
#undef write
#undef read
#undef atexit

#ifndef WINDOWS
#include <termios.h>

static struct termios gtty;
static int gttyset;
#endif

/* console output for -G: the real stdout */
static void
gconsputs(char *s, int n)
{
	write(1, s, n);
}

void
gconsrestore(void)
{
#ifndef WINDOWS
	if(gttyset){
		gttyset = 0;
		tcsetattr(0, TCSAFLUSH, &gtty);
	}
#endif
}

/*
 *  stdin reader: bytes in, runes to the keyboard queue.  \r arrives
 *  as \n (the XK_Return -> '\n' precedent in the gui backends); a
 *  rune split across reads is carried, not judged.
 */
static void
gconsread(void *arg)
{
	char buf[UTFmax+128];
	int n, got, m, len;
	Rune r;

	USED(arg);
	got = 0;
	for(;;){
		/* real stdin (OS read): blocking here in the kproc is
		 * the xproc shape — the reader thread owns fd 0 */
		n = read(0, buf+got, sizeof(buf)-got-UTFmax);
		if(n <= 0)
			return;		/* stdin EOF: the session rides on */
		n += got;
		/* NUL slack: chartorune may look ahead past a truncated
		 * or malformed sequence's real extent */
		memset(buf+n, 0, UTFmax);
		m = 0;
		while(m < n){
			len = 1;
			if((buf[m] & 0xE0) == 0xC0)
				len = 2;
			else if((buf[m] & 0xF0) == 0xE0)
				len = 3;
			else if((buf[m] & 0xF8) == 0xF0)
				len = 4;
			if(len > n-m)
				break;	/* partial rune: carry */
			m += chartorune(&r, buf+m);
			if(r == '\r')
				r = '\n';
			kbdputc(kbdq, r);
		}
		got = n-m;
		memmove(buf, buf+m, got);
	}
}

void
gconsinit(void)
{
#ifndef WINDOWS
	struct termios raw;
#endif

	if(screenputs == 0)
		screenputs = gconsputs;
#ifndef WINDOWS
	if(!gttyset && isatty(0) && tcgetattr(0, &gtty) == 0){
		gttyset = 1;
		atexit(gconsrestore);
		raw = gtty;
		/* raw input, cooked output kept (\n still renders as
		 * CRLF); ISIG off so ^C is a byte for the remote side */
		raw.c_lflag &= ~(ECHO|ICANON|IEXTEN|ISIG);
		raw.c_iflag &= ~(BRKINT|ICRNL|INPCK|ISTRIP|IXON);
		raw.c_cc[VMIN] = 1;
		raw.c_cc[VTIME] = 0;
		tcsetattr(0, TCSANOW, &raw);
	}
#endif
	kproc("gcons", gconsread, nil);
}

/*
 *  -G session exit: restore the terminal and exit for real — the
 *  remote side's exit must end the local process (the status string
 *  becomes the exit status), never the windowed park.
 */
void
gconsexit(char *s)
{
	char *bye;

	bye = "\ngoodbye\n";
	write(1, bye, strlen(bye));
	gconsrestore();
	exit(s != nil && *s != 0 ? 1 : 0);
}

/*
 *  usage exit before any gui init: fd 2 is still the real stderr
 *  (the internal console does not exist yet), so the message must
 *  reach the host stream directly.
 */
void
argusage(void)
{
	char buf[256];
	int n;

	n = snprint(buf, sizeof buf, "%s\n", usagestr);
	write(2, buf, n);
	exit(2);
}

