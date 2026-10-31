#include	"l.h"

/*
 * Harvey links statically; the donor's dynamic-link-module support
 * (dyn.c) is not built. asm.c/asmout.c still reference asmdyn and
 * dynreloc, so this file satisfies them.
 *
 * dynreloc is reached from asmout.c even on static links (C_ADDR
 * operands, brdist): in the donor it records relocation entries that
 * asmdyn only writes out in dlm mode, so a no-op is output-equivalent
 * for static links. asmdyn is only called under if(dlm); if dynamic
 * mode is ever triggered, fail loud rather than emit a broken image.
 */

void
dynreloc(Sym *s, long v, int abs)
{
	USED(s);
	USED(v);
	USED(abs);
}

void
asmdyn(void)
{
	diag("7l: dynamic link modules not supported");
	errorexit();
}
