#!/bin/sh
# sys/src/cmd/nm.BUILD — build the host nm and install it to
# $HARVEY_LINUX_BIN.
#
# Route (plan 02-03's documented fallback, taken): host cc against the
# vendored 9-cc tree (sys/src/cmd/unix/9cc) — its include/, lib9/ and
# libbio/ archives, and ITS libmach, extended in plan 02-03 with the
# pinned 9front donor's arm64 (7-format) support (libmach/7obj.c +
# 7.c + ureg7.h + cmd/7c/7.out.h, the [ObjArm64] parser-table row, the
# R_MAGIC exectab entry, the FARM64 boot case). plan9port is not used
# at all here.
#
# Why not the other routes:
#   * 9c: forces -I$PLAN9/include ahead of user -I flags; plan9port's
#     mach.h lacks the object-file API (Sym, objtype, readar, ...) —
#     see the NOTE at the head of unix/9cc/BUILD.
#   * Harvey's in-tree sys/src/libmach with host cc: cannot compile at
#     all — executable.c embeds Ehdr/E64hdr typedef-name members whose
#     promoted field names collide (Plan 9-compiler-only construct;
#     20 errors under host clang, A/B-proven pre-existing in 02-02).
#     nm needs crackhdr() for the executable path, so there is no
#     libmach subset route around executable.c. The 9cc tree carries
#     the same libmach lineage ported for unix hosts; the arm64
#     additions are the same pinned-donor sources (parser body and
#     exectab entry byte-identical to sys/src/libmach's 7obj.c /
#     executable.c entries).
#
# nm.c itself is compiled unmodified: it includes <u.h> <libc.h>
# <ar.h> <bio.h> <mach.h>, so a per-build shim dir maps u.h/libc.h
# onto the 9cc lib9.h umbrella (ar.h/bio.h/mach.h come from the 9cc
# tree directly).
#
# usage: (cd $HARVEY/sys/src/cmd && sh nm.BUILD)   (see BUILDTOOLCHAIN)

set -e

case "`uname -s`" in
	Darwin)	OSTYPE=darwin ;;
	Linux)	OSTYPE=linux ;;
	*)	echo "nm: unsupported host OS `uname -s`"; exit 1 ;;
esac

HARVEY="${HARVEY:-$(cd "$(dirname "$0")/../../.." && pwd)}"
ARCH=$(uname -m); [ "$ARCH" = "arm64" ] && ARCH=aarch64
HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-$OSTYPE-$ARCH/bin}"

ROOT=$HARVEY/sys/src/cmd/unix/9cc
OBJDIR=$ROOT/obj.$OSTYPE

# bootstrap the 9cc archives on a fresh tree (BUILDTOOLCHAIN runs this
# before toolchain.sh's 9cc line); otherwise reuse them
if [ ! -f "$OBJDIR/libmach.a" ]; then
	(cd "$ROOT" && sh BUILD)
fi

CC=${CC:-cc}

SHIMDIR=$(mktemp -d "${TMPDIR:-/tmp}/nm-shim.XXXXXX")
# system rm (not a hardcoded /bin/rm — NixOS-class hosts keep only sh in
# /bin, and the trap's failure poisons the exit status mid-toolchain)
_SYSRM=$(command -v rm 2>/dev/null || echo rm)
trap '"$_SYSRM" -rf "$SHIMDIR"' EXIT
echo '#include <lib9.h>' > "$SHIMDIR/u.h"
echo '/* lib9.h already included via u.h */' > "$SHIMDIR/libc.h"
IFLAGS="-I$SHIMDIR -I$ROOT/include -I$ROOT/lib9/$OSTYPE -I$ROOT -I$ROOT/cmd"

$CC -O0 -g $IFLAGS -c $HARVEY/sys/src/cmd/nm.c -o nm.o
$CC -O0 -g -o nm nm.o $OBJDIR/libmach.a $OBJDIR/libbio.a $OBJDIR/lib9.a -lm
cp nm $HARVEY_LINUX_BIN/nm
