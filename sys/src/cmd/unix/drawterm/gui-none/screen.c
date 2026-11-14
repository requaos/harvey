/*
 * gui-none: the no-window backend (19-06, amended D-03).  Built for
 * -G stdio sessions and hosts with no graphics stack at all: no X11,
 * no Carbon.  There is no screen, so every screen/window entry point
 * fails LOUDLY the moment it is called — a windowed run against this
 * backend dies at startup with a named complaint, never a silent
 * nothing (T-19-14).  The Memimage operators stay real: they are the
 * plain in-memory libmemdraw implementations with no backing store,
 * so anything that links libmemdraw keeps working unchanged.
 */

#include "u.h"
#include "lib.h"
#include "dat.h"
#include "fns.h"
#include "error.h"

#include <draw.h>
#include <memdraw.h>
#include "screen.h"

	Memimage *gscreen;	/* nil forever: there is no screen */
	Screeninfo screen;

static void
noscreen(char *what)
{
	iprint("drawterm: gui-none: %s called but this build has no screen; use -G for the stdio session\n", what);
	exit(1);
}

void
screeninit(void)
{
	noscreen("screeninit");
}

uchar*
attachscreen(Rectangle *r, ulong *chan, int *depth, int *width, int *softscreen, void **X)
{
	USED(r);
	USED(chan);
	USED(depth);
	USED(width);
	USED(softscreen);
	USED(X);
	noscreen("attachscreen");
	return nil;
}

void
flushmemscreen(Rectangle r)
{
	noscreen("flushmemscreen");
}

void
mouseset(Point xy)
{
	noscreen("mouseset");
}

void
setcursor(void)
{
	noscreen("setcursor");
}

void
cursorarrow(void)
{
	noscreen("cursorarrow");
}

void
getcolor(ulong i, ulong *r, ulong *g, ulong *b)
{
	USED(i);
	USED(r);
	USED(g);
	USED(b);
	noscreen("getcolor");
}

void
setcolor(ulong i, ulong r, ulong g, ulong b)
{
	USED(i);
	USED(r);
	USED(g);
	USED(b);
	noscreen("setcolor");
}

/*
 *  No clipboard on this backend: reads are empty, writes are
 *  dropped.  (An absent clipboard is an honest capability gap, not
 *  a silent window failure.)
 */
char*
clipread(void)
{
	return strdup("");
}

int
clipwrite(char *buf)
{
	USED(buf);
	return 0;
}

/*
 *  Memimage ops: the libmemdraw in-memory implementations,
 *  unchanged — no backing store to synchronize.
 */
Memimage*
allocmemimage(Rectangle r, ulong chan)
{
	return _allocmemimage(r, chan);
}

void
freememimage(Memimage *m)
{
	_freememimage(m);
}

void
memfillcolor(Memimage *m, ulong val)
{
	_memfillcolor(m, val);
}

int
loadmemimage(Memimage *i, Rectangle r, uchar *data, int ndata)
{
	return _loadmemimage(i, r, data, ndata);
}

int
cloadmemimage(Memimage *i, Rectangle r, uchar *data, int ndata)
{
	return _cloadmemimage(i, r, data, ndata);
}

ulong
pixelbits(Memimage *m, Point p)
{
	return _pixelbits(m, p);
}

void
memimageinit(void)
{
	_memimageinit();
}

void
memimagedraw(Memimage *dst, Rectangle r, Memimage *src, Point sp, Memimage *mask, Point mp, int op)
{
	Memdrawparam *par;

	par = _memimagedrawsetup(dst, r, src, sp, mask, mp, op);
	if(par == nil)
		return;
	_memimagedraw(par);
}
