#include <u.h>
#include <libc.h>

/*
 * stacksmoke — the staged stack-growth smoke: force multiple
 * demand-paged stack page-ins on r9 before rc's parser ever depends on
 * stack growth.  A recursion of depth 64, each frame carrying a
 * 256-byte local array written through a real assignment loop (so 7c
 * cannot optimize the frames away), holds ~16 KiB of live stack below
 * the two eager seed pages; the kernel's "fault: stack growth" lines
 * are the page-in evidence.  The checksum accumulates into a plain
 * static so the unwind prints one marker line through the real pwrite
 * path.  No notes, no alarm, no sleeps.
 */

enum { DEPTH = 64, FRAMESZ = 256 };

static ulong sum;

static void
recur(int depth)
{
	uchar frame[FRAMESZ];
	int i;

	for(i = 0; i < FRAMESZ; i++)
		frame[i] = depth + i;	/* fault the page, keep the frame live */
	if(depth > 1)
		recur(depth - 1);
	for(i = 0; i < FRAMESZ; i++)
		sum += frame[i];
}

void
main(int, char*[])
{
	recur(DEPTH);
	print("stacksmoke: depth 64 ok, checksum %lud\n", sum);
	exits(nil);
}
