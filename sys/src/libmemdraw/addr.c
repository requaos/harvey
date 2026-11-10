#include <u.h>
#include <libc.h>
#include <draw.h>
#include <memdraw.h>

/*
 * Wordaddr is deprecated.
 */
ulong*
wordaddr(Memimage *i, Point p)
{
	return (ulong*) ((uintptr)byteaddr(i, p) & ~(sizeof(ulong)-1));
}

uchar*
byteaddr(Memimage *i, Point p)
{
	uchar *a;

	/*
	 * The row offset must reach the pointer arithmetic as a SIGNED
	 * value: i->width is ulong, so for negative p.y the product wraps
	 * as a huge unsigned and, added to a 64-bit pointer, zero-extends
	 * instead of sign-extending — the address lands exactly 2^32 bytes
	 * out (memarc's negative-origin temporaries reached memsetl this
	 * way: the aarch64 wild write at fault addr base+4GiB).  Wrapping
	 * in int restores the 32-bit-pointer behavior on 64-bit targets.
	 */
	a = i->data->bdata+i->zero+(int)(sizeof(ulong)*p.y*i->width);

	if(i->depth < 8){
		/*
		 * We need to always round down,
		 * but C rounds toward zero.
		 */
		int np;
		np = 8/i->depth;
		if(p.x < 0)
			return a+(p.x-np+1)/np;
		else
			return a+p.x/np;
	}
	else
		return a+p.x*(i->depth/8);
}
