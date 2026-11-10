/*
 * vgadispi — a VGAdev for the qemu std-vga VBE DISPI interface
 * (15-05, USPACE-08, D-04 route 1).
 *
 * The venue is qemu-only by definition (the draw donor boots under
 * `-kernel ... -vga std`), so the mode-set rides the VBE DISPI
 * register pair at I/O ports 0x1CE/0x1CF — no BIOS, no realmode
 * trampoline (the vgavesa route would open /dev/realmode, which no
 * k10 kernel serves).  The linear frame buffer maps through the
 * in-tree vgalinearpci() (the std-vga exposes a 16MB BAR0 at
 * display-class PCI), and the soft-screen discipline is vgavesa.c's:
 * the LFB is mapped once to learn the aperture, then the screen is a
 * kernel-allocated image whose flush copies the dirty rectangle to
 * the LFB (screensize()'s paddr==0 path).
 */
#include "u.h"
#include "../port/lib.h"
#include "mem.h"
#include "dat.h"
#include "fns.h"
#include "io.h"
#include "../port/error.h"

#define	Image	IMAGE
#include <draw.h>
#include <memdraw.h>
#include <cursor.h>
#include "screen.h"

#define	BI2WD		32			/* bits per word */
#define	BY2WD		4			/* bytes per word */

enum {
	Dispiidx	= 0x1CE,		/* VBE DISPI index register */
	Dispidata	= 0x1CF,		/* VBE DISPI data register */

	Did		= 0,		/* ID */
	Dxres		= 1,		/* X resolution */
	Dyres		= 2,		/* Y resolution */
	Dbpp		= 3,		/* bits per pixel */
	Denable		= 4,		/* enable */
	Dbank		= 5,		/* bank */
	Dvwidth		= 6,		/* virtual width */
	Dvheight	= 7,		/* virtual height */
	Dxoff		= 8,		/* X offset */
	Dyoff		= 9,		/* Y offset */

	Denabled	= 0x01,		/* enabled */
	Dlinear		= 0x02,		/* linear frame buffer */

	Dispiid		= 0xB0C0,	/* qemu reports 0xB0C0..0xB0C5 */
	Dispiidmask	= 0xFFF0,

	Xres		= 1024,
	Yres		= 768,
	Bpp		= 32,
};

static void *hardscreen;

static ushort
dispir(int reg)
{
	outs(Dispiidx, reg);
	return ins(Dispidata);
}

static void
dispiw(int reg, ushort val)
{
	outs(Dispiidx, reg);
	outs(Dispidata, val);
}

static void
dispienable(VGAscr*)
{
	static int ports;

	if((dispir(Did) & Dispiidmask) != Dispiid)
		error("no vbe dispi vga");
	if(ports == 0){
		if(ioalloc(Dispiidx, 2, 0, "dispi") < 0)
			error("dispi ports already allocated");
		ports = 1;
	}

	/* disable while reconfiguring, then geometry, then enable|linear */
	dispiw(Denable, 0);
	dispiw(Dbank, 0);
	dispiw(Dxres, Xres);
	dispiw(Dyres, Yres);
	dispiw(Dbpp, Bpp);
	dispiw(Dvwidth, Xres);
	dispiw(Dvheight, Yres);
	dispiw(Dxoff, 0);
	dispiw(Dyoff, 0);
	dispiw(Denable, Denabled|Dlinear);
}

static void
dispilinear(VGAscr *scr, int, int)
{
	Pcidev *pci;

	if(hardscreen) {
		scr->vaddr = 0;
		scr->paddr = scr->apsize = 0;
		return;
	}

	/* the std-vga carries no driver-specific id worth pinning: any
	 * display-class device is the card we just programmed */
	pci = nil;
	while((pci = pcimatch(pci, 0, 0)) != nil){
		if(pci->ccrb == Pcibcdisp)
			break;
	}
	if(pci == nil)
		error("pci video card not found");

	scr->pci = pci;
	vgalinearpci(scr);
	if(scr->apsize)
		addvgaseg("dispiscreen", scr->paddr, scr->apsize);

	/* the vgavesa soft-screen discipline: keep the LFB only as the
	 * flush destination so screensize() allocates a kernel image */
	hardscreen = scr->vaddr;
	scr->vaddr = 0;
	scr->paddr = scr->apsize = 0;
}

static void
dispiflush(VGAscr *scr, Rectangle r)
{
	int t, w, wid, off;
	ulong *hp, *sp, *esp;

	if(hardscreen == nil)
		return;
	if(rectclip(&r, scr->gscreen->r) == 0)
		return;
	sp = (ulong*)(scr->gscreendata->bdata + scr->gscreen->zero);
	t = (r.max.x * scr->gscreen->depth + 2*BI2WD-1) / BI2WD;
	w = (r.min.x * scr->gscreen->depth) / BI2WD;
	w = (t - w) * BY2WD;
	wid = scr->gscreen->width;
	off = r.min.y * wid + (r.min.x * scr->gscreen->depth) / BI2WD;

	hp = hardscreen;
	hp += off;
	sp += off;
	esp = sp + Dy(r) * wid;
	while(sp < esp){
		memmove(hp, sp, w);
		hp += wid;
		sp += wid;
	}
}

VGAdev vgadispidev = {
	"dispi",
	dispienable,	/* enable */
	0,		/* disable */
	0,		/* page */
	dispilinear,	/* linear */
	0,		/* drawinit */
	0,		/* fill */
	0,		/* ovlctl */
	0,		/* ovlwrite */
	dispiflush,	/* flush */
};
