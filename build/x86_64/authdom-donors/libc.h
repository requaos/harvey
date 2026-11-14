/*
 * libc.h — host-cc shim for the vendored donor sources and the
 * authdomain-gen generator (18-03, AUTH-01).  Donor files expect the
 * Plan 9 libc surface; this shim maps the small subset they and the
 * generator use onto the host C library.  The ARGBEGIN/ARGEND/ARGF/
 * EARGF macro block below is verbatim from sys/include/libc.h.
 *
 * Deliberately NOT mapped: errstr/%r (host errno + strerror instead —
 * the generator is host build tooling, not a Plan 9 citizen), and any
 * formatted verb beyond what printf provides; the generator's format
 * strings stay within the shared printf subset.
 */
#ifndef _AUTHDOM_SHIM_LIBC_H
#define _AUTHDOM_SHIM_LIBC_H

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

extern char *argv0;

/* plan9port's gcc-conformant forms (their libc.h:915-939): the ANSI
 * preprocessor splits multi-argument USED calls, so ARGEND below uses
 * one USED per expression under GCC semantics */
#define	SET(x)		((x)=0)
#define	USED(x)		((void)(x))

/* print family -> stdio */
#define	print(...)	printf(__VA_ARGS__)
#define	fprint(fd, ...)	fprintf((fd) == 2 ? stderr : stdout, __VA_ARGS__)
#define	snprint		snprintf

/* exits(0)/exits("") succeed; any other string is a failure status */
#define	exits(s)	exit((s) == nil ? 0 : *(const char*)(s) == 0 ? 0 : 1)

/* donor declarations the vendored .c files call without prototypes
 * (Plan 9 compilers need none; modern host compilers error) —
 * verbatim from sys/include/libc.h */
extern	int	encrypt(void*, void*, int);
extern	int	decrypt(void*, void*, int);
extern	char*	strecpy(char*, char*, char*);

#define	sysfatal(...)	do{ \
	fprintf(stderr, "%s: ", argv0 ? argv0 : "authdomain-gen"); \
	fprintf(stderr, __VA_ARGS__); \
	fprintf(stderr, "\n"); \
	exit(1); \
}while(0)

/* Plan 9 open modes map onto the host O_* bits (same values) */
#define	OREAD		O_RDONLY
#define	OWRITE		O_WRONLY
#define	ORDWR		O_RDWR
#define	OCEXEC		O_CLOEXEC

static inline int
createfile(char *file, int omode, uint perm)
{
	return open(file, omode|O_CREAT|O_TRUNC, perm);
}

/* Plan 9 create(2) under its real name would collide with nothing we
 * use; the generator calls createfile so the shim stays obvious. */
#define	create	createfile

/*
 * ARGBEGIN et al — verbatim from sys/include/libc.h; needs the u.h
 * shim's Rune and the chartorune below.
 */
#define	ARGBEGIN	for((argv0||(argv0=*argv)),argv++,argc--;\
			    argv[0] && argv[0][0]=='-' && argv[0][1];\
			    argc--, argv++) {\
				char *_args, *_argt;\
				Rune _argc;\
				_args = &argv[0][1];\
				if(_args[0]=='-' && _args[1]==0){\
					argc--; argv++; break;\
				}\
				_argc = 0;\
				while(*_args && (_args += chartorune(&_argc, _args)))\
				switch(_argc)
#define	ARGEND		SET(_argt);USED(_argt);USED(_argc);USED(_args);}USED(argv);USED(argc);
#define	ARGF()		(_argt=_args, _args="",\
				(*_argt? _argt: argv[1]? (argc--, *++argv): 0))
#define	EARGF(x)	(_argt=_args, _args="",\
				(*_argt? _argt: argv[1]? (argc--, *++argv): ((x), abort(), (char*)0)))

#define	ARGC()		_argc

/* chartorune — minimal UTF-8 decode; the flag scanner only ever sees
 * ASCII, so this is the stdlib-shaped reading (one rune, returns the
 * byte count).  Continuation bytes standing alone read as Runeerror. */
static inline int
chartorune(Rune *r, char *s)
{
	uchar c;

	c = (uchar)s[0];
	if(c < 0x80){
		*r = c;
		return 1;
	}
	if((c & 0xC0) == 0x80){
		*r = Runeerror;
		return 1;
	}
	if((c & 0xE0) == 0xC0 && ((uchar)s[1] & 0xC0) == 0x80){
		*r = ((c & 0x1F)<<6) | ((uchar)s[1] & 0x3F);
		return 2;
	}
	if((c & 0xF0) == 0xE0 && ((uchar)s[1] & 0xC0) == 0x80
	&& ((uchar)s[2] & 0xC0) == 0x80){
		*r = ((c & 0x0F)<<12) | (((uchar)s[1] & 0x3F)<<6)
			| ((uchar)s[2] & 0x3F);
		return 3;
	}
	if((c & 0xF8) == 0xF0 && ((uchar)s[1] & 0xC0) == 0x80
	&& ((uchar)s[2] & 0xC0) == 0x80 && ((uchar)s[3] & 0xC0) == 0x80){
		*r = ((c & 0x07)<<18) | (((uchar)s[1] & 0x3F)<<12)
			| (((uchar)s[2] & 0x3F)<<6) | ((uchar)s[3] & 0x3F);
		return 4;
	}
	*r = Runeerror;
	return 1;
}

#endif
