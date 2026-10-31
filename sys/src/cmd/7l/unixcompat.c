#include	"l.h"

/*
 * Host-build compatibility shim for the vendored 9front 7l (Harvey).
 * The donor sources use malloc/calloc directly and get the my* host-OS
 * wrappers from ../cc/compat on Plan 9; for the unix host build this
 * file supplies both, self-contained (7l's l.h carries no EXTERN hunk
 * declarations — the donor keeps its allocator static inside its own
 * cc/compat, so the hunk storage lives here).
 *
 * Pitfall A: gethunk MUST call mysbrk (which calls sbrk), never
 * malloc — malloc→gethunk→malloc is infinite recursion and dies on
 * the stack guard (reproduced in phase-2 research; model:
 * 6l/obj.c gethunk → mysbrk).
 */

static	char*	hunk;
static	long	nhunk;
static	long	thunk;

void*
mysbrk(ulong size)
{
	return sbrk(size);
}

void
gethunk(void)
{
	char *h;
	long nh;

	nh = NHUNK;
	if(thunk >= 5L*NHUNK) {
		nh = 5L*NHUNK;
		if(thunk >= 25L*NHUNK)
			nh = 25L*NHUNK;
	}
	h = mysbrk(nh);
	if(h == (char*)-1) {
		diag("out of memory");
		errorexit();
	}
	/*
	 * Merge with the current hunk when contiguous (consecutive sbrk
	 * calls return contiguous addresses while nothing else interleaves
	 * the break) — REQUIRED for malloc()'s `while(nhunk < n)` loop to
	 * terminate for n larger than the largest single hunk. 9front's
	 * cc/compat accumulates unconditionally (nhunk += nh) because it
	 * grows one arena with brk; with sbrk the merge must be conditional.
	 * Without it, malloc(n > 25L*NHUNK) loops gethunk forever (observed:
	 * the arm64 donor-kernel link allocates 3.7MB for the embedded
	 * bootfs data → thunk reached 88TB before sbrk returned ENOMEM).
	 */
	if(h == hunk + nhunk)
		nhunk += nh;
	else {
		hunk = h;
		nhunk = nh;
	}
	thunk += nh;
}

/*
 * fake malloc
 */
void*
malloc(ulong n)
{
	void *p;

	while(n & 7)
		n++;
	while(nhunk < n)
		gethunk();
	p = hunk;
	nhunk -= n;
	hunk += n;
	return p;
}

void
free(void *p)
{
	USED(p);
}

void*
calloc(ulong m, ulong n)
{
	void *p;

	n *= m;
	p = malloc(n);
	memset(p, 0, n);
	return p;
}

void*
realloc(void*_, ulong __)
{
	fprint(2, "realloc called\n");
	abort();
	return 0;
}

void
setmalloctag(void *v, ulong pc)
{
	USED(v);
	USED(pc);
}

int
fileexists(char *s)
{
	uchar dirbuf[400];
	int stat(const char *pathname, void *_/*struct stat *statbuf*/);

	/* it's fine if stat result doesn't fit in dirbuf, since even then the file exists */
	return stat(s, dirbuf) >= 0;
}

int
myaccess(char *f)
{
	return access(f, AEXIST);
}

int
mycreat(char *n, int p)
{

	return create(n, 1, p);
}

int
mywait(int *s)
{
	int p;
	Waitmsg *w;

	if((w = wait()) == nil)
		return -1;
	else{
		p = w->pid;
		*s = 0;
		if(w->msg[0])
			*s = 1;
		free(w);
		return p;
	}
}

int
mydup(int f1, int f2)
{
	return dup(f1,f2);
}

int
mypipe(int *fd)
{
	return pipe(fd);
}

int
systemtype(int sys)
{

	switch (sys) {
		case Plan9:
		case Unix:
			return 1;
		default:
			return 0;
	}
}

int
pathchar(void)
{
	return '/';
}

char*
mygetwd(char *path, int len)
{
	return getwd(path, len);
}

int
myexec(char *path, char *argv[])
{
	return exec(path, argv);
}

int
myfork(void)
{
	return fork();
}
