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

# abort on the first failing step: without this, a failed library
# compile leaves the exit status to the final iar link, which succeeds
# against a stale archive from a previous run — the silent-staleness
# class the per-phase BUILDs (7a/7c/7l, nm) all guard against with -e.
set -e

# bare `ar` below must be the host (binutils/llvm) ar, never iar: once
# iar is installed as $HARVEY_LINUX_BIN/ar and hostbin is on PATH (the
# devshell prepends it), `ar` would resolve to iar, whose Plan 9-format
# archives carry no ELF index — the iar link then fails with GNU ld's
# "archive has no index". This BUILD needs nothing from hostbin
# (nix/toolchain.sh runs it on the wrapper PATH for the same reason);
# strip hostbin entries from PATH here so direct invocations are safe.
PATH=$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$//')
export PATH

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
