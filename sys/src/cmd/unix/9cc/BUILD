#!/bin/sh
# Build the vendored 9-cc host tools (see README) and install iar as
# $HARVEY_LINUX_BIN/ar.
#
# NOTE: built with the host cc directly, NOT 9c — 9c forces
# -I$PLAN9/include ahead of ours and plan9port's lib9.h/mach.h lack the
# object-file API (Sym, objtype, readar, ...) this tree provides.

case "`uname -s`" in
	Darwin)	OSTYPE=darwin ;;
	Linux)	OSTYPE=linux ;;
	*)	echo "9cc: unsupported host OS `uname -s`"; exit 1 ;;
esac

ROOT=`pwd`
IFLAGS="-I$ROOT/include -I$ROOT/lib9/$OSTYPE -I$ROOT -I$ROOT/cmd"
OBJDIR=$ROOT/obj.$OSTYPE

mkdir -p $OBJDIR

CC=${CC:-cc}
# -Wno-error=format-security: nix's devshell cc wrapper injects
# -Werror=format-security, which errors out as "ignored" against this
# tree's -Wno-format. The vendored code is decades-old Plan 9 C; the
# hardening diagnostic is not actionable here.
CFLAGS="-O -Wno-implicit-function-declaration -Wno-implicit-int -Wno-deprecated-declarations -Wno-format -Wno-error=format-security $IFLAGS"

# lib9 (posix shim)
(cd lib9 && $CC -c $CFLAGS *.c && ar rv $OBJDIR/lib9.a *.o && rm -f *.o)
# libbio
(cd libbio && $CC -c $CFLAGS *.c && ar rv $OBJDIR/libbio.a *.o && rm -f *.o)
# libmach (needs cmd/*.out.h via $ROOT)
(cd libmach && $CC -c $CFLAGS *.c && ar rv $OBJDIR/libmach.a *.o && rm -f *.o)

# iar
(cd iar && $CC $CFLAGS -o iar ar.c posix.c $OBJDIR/libmach.a $OBJDIR/libbio.a $OBJDIR/lib9.a -lm && \
	cp iar $HARVEY_LINUX_BIN/ar)
