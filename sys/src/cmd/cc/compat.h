/*
 * functions shared by compilers, linkers and assemblers.
 * Additive Harvey header (Phase 2, 02-01): 9front ships this as
 * sys/src/cmd/cc/compat.h; Harvey's definitions live in cc/compat.
 * Declarations here match Harvey's cc/compat + lexbody/macbody —
 * note mysbrk(ulong); a wrong signature is a hard error.
 */

#ifndef	EXTERN
#define EXTERN	extern
#endif

enum
{
	Plan9	= 1<<0,
	Unix	= 1<<1,
	Windows	= 1<<2
};
EXTERN	int	systemtype(int);
EXTERN	int	pathchar(void);

EXTERN	int	myaccess(char*);
EXTERN	void*	mysbrk(ulong);
EXTERN	int	mywait(int*);
EXTERN	int	mycreat(char*, int);
EXTERN	char*	mygetwd(char*, int);
EXTERN	int	myexec(char*, char*[]);
EXTERN	int	mydup(int, int);
EXTERN	int	myfork(void);
EXTERN	int	mypipe(int*);

EXTERN	void*	alloc(long n);
EXTERN	void*	allocn(void *p, long on, long n);
