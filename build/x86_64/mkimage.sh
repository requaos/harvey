#!/bin/sh
# build/x86_64/mkimage.sh — bake build/x86_64/out/bootfs.paq, the paqfs
# root image for the r9 x86_64 staged-exec boot (14-05, D-04: the byte
# format carried VERBATIM from aarch64 — same header magic 529ab12b,
# same trailer 6b46e688, same in-tree mkpaqfs, same r9 miniz-inflate
# reader).  Stages a scratch tree from the committed
# build/x86_64/root-tree/ skeleton plus the built marker binaries
# (stage-build.sh's smoke-out/), then invokes the host mkpaqfs
# (.build/bin/mkpaqfs, built by build/x86_64/mkpaqfs-host.sh when
# missing).
#
# Image contract (D-08's staged leg 1 — this is the MARKER image, not
# the boot-chain image):
#   /amd64/init                  the smokesleep marker (the q35exec
#                                BOOT_ENTRY target) — NOT the real
#                                init; the boot(8) chain is 14-06's leg
#   empty dirs /root /env /proc /dev /srv /fd /bin /tmp /mnt /net
#                                (bind/mount targets must pre-exist;
#                                the image is read-only)
#   NO /boot/factotum            auth stub = absence: its mere presence
#                                flips authentication() into the real
#                                factotum-exec path (Phase 18)
#   NO /boot/*, NO /rc/*         the boot chain + rcmain join at 14-06+
#
# Determinism (Pitfall 6, so 14-07's composed-ISO FOD can inherit): the
# staged tree's mtimes are pinned to KERNDATE and mkpaqfs's header time
# rides the same KERNDATE (the in-tree env override) — two bakes of one
# tree are byte-identical.  KERNDATE flows in from the caller (the
# boot-r9.sh provenance discipline: git %ct of the checkout, overridable
# KERNDATE=<epoch>); staging order is fixed by construction (the
# committed-skeleton tar + the ordered loops below).
#
# usage: sh build/x86_64/mkimage.sh   (repo root, inside the nix
# devshell; run stage-build.sh first — the smoke-out/ inputs)

set -eu

HARVEY="${HARVEY:-$PWD}"
ROOT_TREE="$HARVEY/build/x86_64/root-tree"
OUT="$HARVEY/build/x86_64/out"
STAGE_SRC="$HARVEY/build/x86_64/smoke-out"
IMAGE="$OUT/bootfs.paq"
MKPAQFS="$HARVEY/.build/bin/mkpaqfs"

err() { echo "error: $*" >&2; exit 1; }

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -d "$ROOT_TREE" ] || err "$ROOT_TREE missing — the committed image skeleton (14-05)"

# $PLAN9/bin LAST when plan9port is provisioned (project rule,
# BUILD_ON_UNIX) — matters only for the mkpaqfs-host.sh fallback below;
# the bake itself uses host tools only.
if [ -n "${PLAN9:-}" ]; then
	P9LAST=$(echo "$PATH" | sed "s|:$PLAN9/bin||g; s|^$PLAN9/bin:||; s|^$PLAN9/bin$||")
	PATH="$P9LAST:$PLAN9/bin"
	export PATH
fi

# the byte-format owner: Harvey's in-tree mkpaqfs built as a host binary
if [ ! -x "$MKPAQFS" ]; then
	echo "== mkpaqfs host binary missing — building via build/x86_64/mkpaqfs-host.sh"
	sh "$HARVEY/build/x86_64/mkpaqfs-host.sh" || err "mkpaqfs host build failed"
fi
[ -x "$MKPAQFS" ] || err "$MKPAQFS missing after mkpaqfs-host.sh"

# inputs (stage-build.sh is the producer — named loudly when absent)
for f in init smokesleep; do
	[ -s "$STAGE_SRC/$f" ] || err "$STAGE_SRC/$f missing — run sh build/x86_64/stage-build.sh first"
done

# KERNDATE from the caller; the boot-r9.sh provenance derivation when
# absent (git %ct of the checkout; wall clock only without git metadata)
if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! echo "$KERNDATE" | "$GREP" -qE '^[0-9]+$'; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/mkimage-x64.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

STAGE="$TMPD/root"
mkdir -p "$STAGE"

# 1. the committed skeleton (this era: the documented placeholder tree —
#    14-06+ grows rcmain/termrc/namespace into it)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE" && tar -xf -)

# 2. empty mount-point dirs + staging parents (fixed order)
mkdir -p "$STAGE/root" "$STAGE/env" "$STAGE/proc" "$STAGE/dev" "$STAGE/srv" \
	"$STAGE/fd" "$STAGE/bin" "$STAGE/tmp" "$STAGE/mnt" \
	"$STAGE/net" "$STAGE/amd64"
# /net: the future net-sweep bind target — r9's sys_bind requires the
# target to EXIST and the paqfs root is read-only this era (the 07-07
# aarch64 note, carried).

# 3. the marker binaries (deterministic staging order: the loop is the
#    fixed list; init is the leg-1 entry, smokesleep its source name)
cp "$STAGE_SRC/init" "$STAGE/amd64/init"
cp "$STAGE_SRC/smokesleep" "$STAGE/amd64/smokesleep"

# 4. pre-bake manifest: every mandated path exists
for p in amd64/init amd64/smokesleep; do
	[ -f "$STAGE/$p" ] || err "manifest: $p missing from staged tree"
done
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE/$p" ] || err "manifest: mount-point dir /$p missing"
done

# 4a. init identity (the aarch64 guard, re-keyed for the staged leg):
# /amd64/init must BE the marker — grep matches the marker's rodata
# strings on the a.out bytes; the REAL init's signature must NOT ride
# (it arrives with 14-06's boot chain and would hang leg 1's gate).
"$GREP" -q "smokesleep: interrupted" "$STAGE/amd64/init" \
	|| err "amd64/init is not the smokesleep marker (re-run sh build/x86_64/stage-build.sh)"
"$GREP" -q "init: starting /bin/rc" "$STAGE/amd64/init" \
	&& err "amd64/init is the REAL init (leg 1 stages the marker — re-run sh build/x86_64/stage-build.sh)"

# 4b. /boot/factotum ABSENCE (auth-stub-by-absence, D-02 carried: auth
#     is Phase 18; its mere presence flips authentication() live)
[ ! -e "$STAGE/boot/factotum" ] || err "manifest: /boot/factotum present — auth-stub-by-absence violated"

# 5. determinism: pin every staged mtime to KERNDATE (mkpaqfs embeds
#    each entry's mtime; the header time rides the same KERNDATE env)
find "$STAGE" -exec touch -h -d "@$KERNDATE" {} +

# 6. bake
mkdir -p "$OUT"
rm -f "$IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$IMAGE" "$STAGE" || err "mkpaqfs failed"
[ -s "$IMAGE" ] || err "$IMAGE missing/empty after mkpaqfs"

# 7. the byte-format contract r9's reader consumes (the proven checks,
#    carried verbatim from the aarch64 bake): paqfs header magic
#    529ab12b (first 4 bytes) and trailer magic 6b46e688 (the last
#    28-byte block's first 4 bytes)
magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d ' \n')
[ "$magic" = "529ab12b" ] || err "$IMAGE: bad header magic $magic (want 529ab12b)"
sz=$(wc -c < "$IMAGE" | tr -d ' ')
# od -j (not dd): Harvey's host dd (dash-pair arg syntax) shadows POSIX
# dd on the devshell PATH (the D-02 hostbin-shadowing class); od is
# never shadowed (Plan 9 has no od)
trailer=$(od -An -tx1 -j $((sz - 28)) -N 4 "$IMAGE" | tr -d ' \n')
[ "$trailer" = "6b46e688" ] || err "$IMAGE: bad trailer magic $trailer (want 6b46e688)"

echo "== PASS: baked $IMAGE ($sz bytes; header $magic trailer $trailer; KERNDATE $KERNDATE)"
