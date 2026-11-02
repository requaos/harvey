#!/bin/sh
# build/aarch64/mkpaqfs-host.sh — build Harvey's in-tree mkpaqfs
# (sys/src/cmd/paqfs/mkpaqfs.c, NOT the 9front donor's copy) as a host
# binary at .build/bin/mkpaqfs, using the plan9port 9c/9l recipe proven
# by Phase 2's donor-ns-build.sh (lines 240-243).  Run from the repo
# root inside the nix devshell:
#
#     nix develop -c sh build/aarch64/mkpaqfs-host.sh
#
# PATH discipline: "$PLAN9/bin" goes LAST (project rule, BUILD_ON_UNIX) —
# the devshell's own tools stay ahead and plan9port supplies only what
# the host lacks.  .build/ is gitignored: the binary is a host artifact
# and is never committed.  Phase 4 plan 04-01 Task 2 uses this binary to
# bake the paqfs fixture that r9's 04-02 reader parses (D-02).

set -eu

: "${PLAN9:?run inside the nix devshell — plan9port must be provisioned (PLAN9 unset)}"

HARVEY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$HARVEY_ROOT"

# $PLAN9/bin LAST: strip any existing occurrence, then append.
P9LAST=$(echo "$PATH" | sed "s|:$PLAN9/bin||g; s|^$PLAN9/bin:||; s|^$PLAN9/bin$||")
PATH="$P9LAST:$PLAN9/bin"
export PATH

mkdir -p .build/bin
SCRATCH=$(mktemp -d .build/mkpaqfs.XXXXXX)
trap 'rm -rf "$SCRATCH"' EXIT

echo "mkpaqfs-host: [9c] compile sys/src/cmd/paqfs/mkpaqfs.c"
if ! (cd "$SCRATCH" && "$PLAN9/bin/9c" -O0 -I"$HARVEY_ROOT/sys/src/cmd/paqfs" \
	-c "$HARVEY_ROOT/sys/src/cmd/paqfs/mkpaqfs.c"); then
	echo "mkpaqfs-host: 9c compile step failed" >&2
	exit 1
fi

echo "mkpaqfs-host: [9l] link .build/bin/mkpaqfs (-lflate -lsec -lmp -lbio -l9)"
if ! (cd "$SCRATCH" && "$PLAN9/bin/9l" -o "$HARVEY_ROOT/.build/bin/mkpaqfs" mkpaqfs.o \
	-lflate -lsec -lmp -lbio -l9); then
	echo "mkpaqfs-host: 9l link step failed" >&2
	exit 1
fi

echo "mkpaqfs-host: built .build/bin/mkpaqfs from sys/src/cmd/paqfs/mkpaqfs.c"
