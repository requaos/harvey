#include <u.h>
#include <libc.h>
#include <draw.h>

/*
 * drawsmoke — the draw venue's bring-up probe (15-05, USPACE-08, D-04).
 * Plain libc over #i: NO libdraw.  Opens /dev/draw/new (the open itself
 * creates the client and fails if the screen image is not installed —
 * drawopen's Qctl case), checks the screen described back (1024x768
 * x8r8g8b8 through the raw 12x12 info read), allocates a solid fill
 * image and an opaque mask with raw 'b' messages, paints a rectangle
 * on the screen with a raw 'd' message, and reads the pixels back with
 * a raw 'r' message — the full client-side draw loop over the
 * kernel-local devdraw.  Prints DRAW-SMOKE-OK to #c/cons on success
 * (the serial capture is the gate wire; k10 console output fans to
 * BOTH the cga/vga screen and the serial consdev — putstrn0's loop).
 */

enum {
	Msgalloc	= 1+4+4+1+4+1+4*4+4*4+4,	/* 'b' */
	Msgdraw		= 1+4+4+4+4*4+2*4+2*4,	/* 'd' */
	Msgread		= 1+4+4*4,		/* 'r' */

	Infosize	= 12*12,			/* 12 fields x 12 chars */

	Fillid		= 1,				/* solid color image */
	Maskid		= 2,				/* all-opaque GREY1 mask */

	Fillval		= 0x000000ff,			/* blue in x8r8g8b8 */
};

/* the draw wire byte order comes from draw.h's own BG/BP macros — this
 * tree's are LITTLE-endian (BGSHORT p[0]|p[1]<<8), unlike stock Plan 9's
 * big-endian ones; using the header macros is the single source of
 * truth (measured on the first venue boot: hand-rolled big-endian
 * packing byte-reversed every field and the kernel parsed id 0x02000000) */

static void
fail(char *why)
{
	fprint(2, "drawsmoke: %s: %r\n", why);
	exits("drawsmoke");
}

/*
 * bounded single read: alarm-gated (atnotify catches the note so the
 * default terminate action never fires); returns -1 on timeout.
 */
static int
alarmed(void *v, char *s)
{
	USED(v);
	return strncmp(s, "alarm", 5) == 0;
}

static int
bread(int fd, char *buf, int len, int ms)
{
	int n;

	atnotify(alarmed, 1);
	alarm(ms);
	n = read(fd, buf, len);
	alarm(0);
	atnotify(alarmed, 0);
	if(n < 0)
		werrstr("timed out");
	return n;
}

/*
 * the synthetic-input probes (the 15-06 replay bootstrap, OQ-2):
 * #c/kbin writes must reach a #c/cons reader through the standard
 * cooked kbd path behind the eve-gate (the hostowner was set before
 * this process ran), and #m/mousein must drive mousetrack far enough
 * for a #m/mouse readback to carry the position.
 */
static void
kbinput(void)
{
	char line[128];
	int kfd, cfd, n;

	kfd = open("/dev/kbin", OWRITE);
	if(kfd < 0)
		fail("open /dev/kbin (eve-gate)");
	cfd = open("/dev/cons", OREAD);
	if(cfd < 0)
		fail("open /dev/cons for the kbin probe");
	if(write(kfd, "KBINPROBE\n", 10) != 10)
		fail("write /dev/kbin");
	n = bread(cfd, line, sizeof line - 1, 6000);
	if(n < 0)
		fail("kbin round trip");
	line[n] = 0;
	if(strncmp(line, "KBINPROBE", 9) != 0)
		fail("kbin readback mismatch");
	print("KBIN-OK\n");
	close(kfd);
	close(cfd);
}

static void
mouseinput(void)
{
	char line[128];
	int mfd, ifd, n;

	ifd = open("/dev/mousein", OWRITE);
	if(ifd < 0)
		fail("open /dev/mousein (eve-gate)");
	if(write(ifd, "M 512 384 0 0\n", 14) != 14)
		fail("write /dev/mousein");
	mfd = open("/dev/mouse", OREAD);
	if(mfd < 0)
		fail("open /dev/mouse for the mousein probe");
	n = bread(mfd, line, sizeof line - 1, 6000);
	if(n < 0)
		fail("mousein round trip");
	line[n] = 0;
	if(strstr(line, "512") == nil || strstr(line, "384") == nil)
		fail("mouse readback mismatch");
	print("MOUSEIN-OK\n");
	close(mfd);
	close(ifd);
}

/*
 * info fields are %11d space-padded groups of 12: [0] client id,
 * [2] chan, [4..7] the image rectangle.
 */
static long
infofield(uchar *info, int i)
{
	return strtol((char*)info + i*12, nil, 10);
}

void
main(int, char *[])
{
	uchar info[Infosize+2];
	uchar msg[Msgalloc];
	uchar px[16], *p;
	char buf[512];
	char ctl[512];
	int vgafd, ctlfd, datafd, n, i;
	ulong got;

	/* the mode-set verb chain is load-bearing: vgactl's readback
	 * carries `type dispi` (the CMtype verb armed vgadispidev and
	 * its enable returned without error) and the size line */
	vgafd = open("/dev/vgactl", OREAD);
	if(vgafd < 0)
		fail("open /dev/vgactl");
	n = readn(vgafd, ctl, sizeof ctl - 1);
	if(n <= 0)
		fail("read /dev/vgactl");
	ctl[n] = 0;
	if(strncmp(ctl, "type dispi\n", 11) != 0)
		fail("vgactl type is not dispi");
	if(strstr(ctl, "size 1024x768x32 x8r8g8b8") == nil)
		fail("vgactl carries no 1024x768x32 size line");

	ctlfd = open("/dev/draw/new", ORDWR);
	if(ctlfd < 0)
		fail("open /dev/draw/new (no screen image installed?)");
	n = readn(ctlfd, info, Infosize+1);
	if(n < Infosize)
		fail("short info read");
	info[Infosize] = 0;
	/* the info fields are %11-padded (right-justified) — strtochan's
	 * own parse skips the leading spaces; match it */
	p = info + 2*12;
	while(*p == ' ')
		p++;
	if(strncmp((char*)p, "x8r8g8b8", 8) != 0)
		fail("screen chan is not x8r8g8b8");
	if(infofield(info, 4) != 0 || infofield(info, 5) != 0 ||
	   infofield(info, 6) != 1024 || infofield(info, 7) != 768)
		fail("screen is not 1024x768");

	snprint(buf, sizeof buf, "/dev/draw/%ld/data", infofield(info, 0));
	datafd = open(buf, ORDWR);
	if(datafd < 0)
		fail("open data fd");

	/* 'b' fill: x8r8g8b8, replicated, Fillval.  The solid-image idiom:
	 * R=(0,0,1,1) with the huge repl clipr libdraw itself passes */
	msg[0] = 'b';
	BPLONG(msg+1, Fillid);
	BPLONG(msg+5, 0);			/* screenid: not a screen */
	msg[9] = 0;				/* refresh */
	BPLONG(msg+10, XRGB32);
	msg[14] = 1;				/* repl */
	BPLONG(msg+15, 0);
	BPLONG(msg+19, 0);
	BPLONG(msg+23, 1);
	BPLONG(msg+27, 1);
	BPLONG(msg+31, -0x3FFFFFFF);
	BPLONG(msg+35, -0x3FFFFFFF);
	BPLONG(msg+39, 0x3FFFFFFF);
	BPLONG(msg+43, 0x3FFFFFFF);
	BPLONG(msg+47, Fillval);
	if(write(datafd, msg, Msgalloc) != Msgalloc)
		fail("alloc fill");

	/* 'b' mask: GREY1, replicated, all ones (the opaque mask) */
	msg[0] = 'b';
	BPLONG(msg+1, Maskid);
	BPLONG(msg+10, GREY1);
	BPLONG(msg+47, 1);
	if(write(datafd, msg, Msgalloc) != Msgalloc)
		fail("alloc mask");

	/* 'd': paint Rect(100,100,300,300) on the screen from the fill */
	msg[0] = 'd';
	BPLONG(msg+1, 0);			/* dst: the screen */
	BPLONG(msg+5, Fillid);
	BPLONG(msg+9, Maskid);
	BPLONG(msg+13, 100);
	BPLONG(msg+17, 100);
	BPLONG(msg+21, 300);
	BPLONG(msg+25, 300);
	if(write(datafd, msg, Msgdraw) != Msgdraw)
		fail("draw rectangle");

	/* 'r': unload 2x2 pixels from the painted interior */
	msg[0] = 'r';
	BPLONG(msg+1, 0);
	BPLONG(msg+5, 150);
	BPLONG(msg+9, 150);
	BPLONG(msg+13, 152);
	BPLONG(msg+17, 152);
	if(write(datafd, msg, Msgread) != Msgread)
		fail("read pixels request");
	n = readn(datafd, px, sizeof px);
	if(n != sizeof px)
		fail("short pixel read");

	p = px;
	for(i = 0; i < 4; i++){
		/* the memimage word byte order rides the same tree-local
		 * convention as the BG/BP macros — accept the fill color in
		 * either canonical byte order */
		got = (p[0]<<24)|(p[1]<<16)|(p[2]<<8)|p[3];
		if(got != Fillval && got != (p[0]|(p[1]<<8)|(p[2]<<16)|(p[3]<<24)))
			fail("pixel mismatch");
		p += 4;
	}

	print("DRAW-SMOKE-OK\n");
	kbinput();
	mouseinput();
	exits(nil);
}
