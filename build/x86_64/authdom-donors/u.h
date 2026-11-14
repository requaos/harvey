/*
 * u.h — host-cc shim for the vendored donor sources (18-03, AUTH-01).
 * The donor algorithm files (passtokey.c, nvcsum.c, crypt.c, des*.c,
 * sha1*.c, strecpy.c) are byte-verbatim Harvey tree sources that nor-
 * mally compile under the Plan 9 compilers against /amd64/include/u.h.
 * This shim supplies the same type vocabulary to the host compiler.
 *
 * Widths: ulong/uint/ushort keep their HOST widths (glibc already
 * typedefs these names; identical typedefs are legal, differing ones
 * are errors).  Plan 9's long is 32 bits, the host's is 64 — verified
 * harmless for the vendored set: the DES code does all its arithmetic
 * in u32int locals with explicit masks and only stores values that
 * fit 32 bits into ulong arrays, and the SHA-1 code counts bits in
 * uvlong.  plan9port makes the same choice on LP64 hosts.
 */
#ifndef _AUTHDOM_SHIM_U_H
#define _AUTHDOM_SHIM_U_H

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef long long vlong;
typedef unsigned long long uvlong;
typedef unsigned int u32int;
typedef unsigned long long u64int;
typedef int s32int;
typedef unsigned short Rune;		/* Plan 9 runes are 16 bits */
typedef unsigned long long uintptr;
typedef unsigned long usize;

enum
{
	Runeerror	= 0xFFFD,
	UTFmax		= 4,
};

#define	nil		((void*)0)
#define	nelem(x)	(sizeof(x)/sizeof((x)[0]))

#endif
