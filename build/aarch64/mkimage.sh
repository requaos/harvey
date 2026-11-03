#!/bin/sh
# build/aarch64/mkimage.sh — bake build/aarch64/bootfs.paq, the paqfs
# root image for the r9 real boot chain (05-02 Task 2).  Stages a
# scratch tree from the committed build/aarch64/root-tree/ skeleton
# plus the built binaries (subset-build.sh's out/ + aarch64/bin), then
# invokes the host mkpaqfs (.build/bin/mkpaqfs, built by
# build/aarch64/mkpaqfs-host.sh when missing — the 04-01 recipe).
#
# Image contract (05-02 must_haves; D-02/D-05/D-08; RESEARCH Pitfalls
# 1/6/8):
#   /boot/boot, /boot/paqfs        the pid-1 binary + its paqfs server
#   /aarch64/init                  execinit's target (/%s/init, Pitfall 1)
#   /aarch64/bin/<16 subset + stacksmoke>
#   /rc/lib/rcmain                 copied VERBATIM from rc/lib/rcmain at
#                                  bake time (single source of truth;
#                                  amd64 safety keys on image contents,
#                                  never shared-source edits)
#   /rc/bin/termrc                 scoped (D-05) — committed skeleton
#   /lib/namespace                 scoped (D-08) — committed skeleton
#   /adm/timezone/local            copied from the repo's adm/timezone
#                                  at bake time (init's cpenv consumer)
#   /usr/glenda/lib/profile        committed skeleton
#   empty dirs /root /env /proc /dev /srv /fd /bin /tmp /mnt
#                                  (Pitfall 8: bind/mount targets must
#                                  pre-exist; the image is read-only)
#   NO /boot/factotum              auth stub = absence (D-02, Pitfall 6):
#                                  its mere presence flips
#                                  authentication() into the real
#                                  factotum-exec path
#
# usage: sh build/aarch64/mkimage.sh   (repo root, inside the nix
# devshell; run subset-build.sh first — the out/ + aarch64/bin inputs)

set -eu

HARVEY="${HARVEY:-$PWD}"
ROOT_TREE="$HARVEY/build/aarch64/root-tree"
OUT="$HARVEY/build/aarch64/out"
BIN="$HARVEY/aarch64/bin"
IMAGE="$HARVEY/build/aarch64/bootfs.paq"
MKPAQFS="$HARVEY/.build/bin/mkpaqfs"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -d "$ROOT_TREE" ] || err "$ROOT_TREE missing — the committed image skeleton (05-02)"

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
	echo "== mkpaqfs host binary missing — building via build/aarch64/mkpaqfs-host.sh"
	sh "$HARVEY/build/aarch64/mkpaqfs-host.sh" || err "mkpaqfs host build failed"
fi
[ -x "$MKPAQFS" ] || err "$MKPAQFS missing after mkpaqfs-host.sh"

# inputs (subset-build.sh is the producer — named loudly when absent)
for f in boot init paqfs stacksmoke; do
	[ -s "$OUT/$f" ] || err "$OUT/$f missing — run sh build/aarch64/subset-build.sh first"
done
SUBSET="rc grep cat cp date echo ls mkdir mv ps rm sed test wc"
for f in $SUBSET; do
	[ -f "$BIN/$f" ] || err "$BIN/$f missing — run sh build/aarch64/subset-build.sh first"
done
[ -f "$BIN/ip/ipconfig" ] || err "$BIN/ip/ipconfig missing — run sh build/aarch64/subset-build.sh first"
[ -f "$BIN/auth/factotum" ] || err "$BIN/auth/factotum missing — run sh build/aarch64/subset-build.sh first"
[ -f "$HARVEY/rc/lib/rcmain" ] || err "rc/lib/rcmain missing (ships verbatim)"
[ -f "$HARVEY/adm/timezone/local" ] || err "adm/timezone/local missing (the repo's tz data)"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/mkimage.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

STAGE="$TMPD/root"
mkdir -p "$STAGE"

# 1. the committed skeleton (lib/namespace, rc/bin/termrc,
#    usr/glenda/lib/profile)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE" && tar -xf -)

# 2. empty mount-point dirs (Pitfall 8) + staging parents
mkdir -p "$STAGE/root" "$STAGE/env" "$STAGE/proc" "$STAGE/dev" "$STAGE/srv" \
	"$STAGE/fd" "$STAGE/bin" "$STAGE/tmp" "$STAGE/mnt" \
	"$STAGE/boot" "$STAGE/aarch64/bin/ip" "$STAGE/aarch64/bin/auth" \
	"$STAGE/rc/lib" "$STAGE/rc/bin" "$STAGE/adm/timezone"

# 3. binaries
cp "$OUT/boot" "$STAGE/boot/boot"
cp "$OUT/paqfs" "$STAGE/boot/paqfs"
cp "$OUT/init" "$STAGE/aarch64/init"
for f in $SUBSET; do
	cp "$BIN/$f" "$STAGE/aarch64/bin/$f"
done
cp "$BIN/ip/ipconfig" "$STAGE/aarch64/bin/ip/ipconfig"
cp "$BIN/auth/factotum" "$STAGE/aarch64/bin/auth/factotum"
cp "$OUT/stacksmoke" "$STAGE/aarch64/bin/stacksmoke"

# 4. bake-time verbatim copies (rcmain: never edited, single source of
#    truth; timezone: the repo's data, consumed by init's cpenv)
cp "$HARVEY/rc/lib/rcmain" "$STAGE/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE/adm/timezone/local"

# 5. pre-bake manifest: every mandated path exists, and /boot/factotum
#    is ABSENT (D-02 auth-stub-by-absence)
for p in boot/boot boot/paqfs aarch64/init aarch64/bin/stacksmoke \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile; do
	[ -f "$STAGE/$p" ] || err "manifest: $p missing from staged tree"
done
for f in $SUBSET; do
	[ -f "$STAGE/aarch64/bin/$f" ] || err "manifest: aarch64/bin/$f missing"
done
[ -f "$STAGE/aarch64/bin/ip/ipconfig" ] || err "manifest: aarch64/bin/ip/ipconfig missing"
[ -f "$STAGE/aarch64/bin/auth/factotum" ] || err "manifest: aarch64/bin/auth/factotum missing"
for p in root env proc dev srv fd bin tmp mnt; do
	[ -d "$STAGE/$p" ] || err "manifest: mount-point dir /$p missing"
done
[ ! -e "$STAGE/boot/factotum" ] || err "manifest: /boot/factotum present — D-02 auth-stub-by-absence violated"

# rcmain ships byte-verbatim (the amd64-safety constraint keys on image
# contents) — prove it at bake time
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain"

# 6. bake
rm -f "$IMAGE"
"$MKPAQFS" -o "$IMAGE" "$STAGE" || err "mkpaqfs failed"
[ -s "$IMAGE" ] || err "$IMAGE missing/empty after mkpaqfs"

# 7. the byte-format contract r9's reader consumes (04-01's proven
#    checks): paqfs header magic 529ab12b (first 4 bytes) and trailer
#    magic 6b46e688 (the last 28-byte block's first 4 bytes)
magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d ' \n')
[ "$magic" = "529ab12b" ] || err "$IMAGE: bad header magic $magic (want 529ab12b)"
sz=$(wc -c < "$IMAGE" | tr -d ' ')
trailer=$(dd if="$IMAGE" bs=1 skip=$((sz - 28)) count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
[ "$trailer" = "6b46e688" ] || err "$IMAGE: bad trailer magic $trailer (want 6b46e688)"

echo "== PASS: baked $IMAGE ($sz bytes; header $magic trailer $trailer)"
