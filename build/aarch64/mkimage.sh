#!/bin/sh
# build/aarch64/mkimage.sh — bake build/aarch64/bootfs.paq, the paqfs
# root image for the r9 real boot chain.  Stages a
# scratch tree from the committed build/aarch64/root-tree/ skeleton
# plus the built binaries (subset-build.sh's out/ + aarch64/bin), then
# invokes the host mkpaqfs (.build/bin/mkpaqfs, built by
# build/aarch64/mkpaqfs-host.sh when missing).
#
# Image contract:
#   /boot/boot, /boot/paqfs        the pid-1 binary + its paqfs server
#   /aarch64/init                  execinit's target (/%s/init)
#   /aarch64/bin/<16 subset + stacksmoke>
#   /rc/lib/rcmain                 copied VERBATIM from rc/lib/rcmain at
#                                  bake time (single source of truth;
#                                  amd64 safety keys on image contents,
#                                  never shared-source edits)
#   /rc/bin/termrc                 scoped — committed skeleton
#   /lib/namespace                 scoped — committed skeleton
#   /adm/timezone/local            copied from the repo's adm/timezone
#                                  at bake time (init's cpenv consumer)
#   /usr/glenda/lib/profile        committed skeleton
#   empty dirs /root /env /proc /dev /srv /fd /bin /tmp /mnt
#                                  (bind/mount targets must
#                                  pre-exist; the image is read-only)
#   NO /boot/factotum              auth stub = absence:
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

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

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
[ -s "$OUT/netblast" ] || err "$OUT/netblast missing — run sh build/aarch64/subset-build.sh first"	# 07-04 D-08
# 08-03: the Phase-8 gate payloads (D-12) — the four full-tree binaries
# (dir/per-target installs + out/ harvest blocks in subset-build.sh) and
# the two compiled payloads (tcpblast/tcpecho, netblast shape)
for f in ipconfig ping udpecho aan tcpblast tcpecho; do
	[ -s "$OUT/$f" ] || err "$OUT/$f missing — run sh build/aarch64/subset-build.sh first"
done
SUBSET="rc grep cat cp date echo ls mkdir mv ps rm sed test wc"
SUBSET="$SUBSET dd"	# 07-04: dd joins the image (D-07's sweep writer); append form keeps the edit insertion-only
SUBSET="$SUBSET bind"	# 07-07: the net-sweep's `bind -a '#l' /net` execs /bin/bind (not an rc builtin)
for f in $SUBSET; do
	[ -f "$BIN/$f" ] || err "$BIN/$f missing — run sh build/aarch64/subset-build.sh first"
done
[ -f "$BIN/ip/ipconfig" ] || err "$BIN/ip/ipconfig missing — run sh build/aarch64/subset-build.sh first"
[ -f "$BIN/auth/factotum" ] || err "$BIN/auth/factotum missing — run sh build/aarch64/subset-build.sh first"
# 08-03: ping/udpecho install to bin/ip via the mkmany %.install rule;
# aan installs to bin/ via cmd's per-target rule
[ -f "$BIN/ip/ping" ] || err "$BIN/ip/ping missing — run sh build/aarch64/subset-build.sh first"
[ -f "$BIN/ip/udpecho" ] || err "$BIN/ip/udpecho missing — run sh build/aarch64/subset-build.sh first"
[ -f "$BIN/aan" ] || err "$BIN/aan missing — run sh build/aarch64/subset-build.sh first"
[ -f "$HARVEY/rc/lib/rcmain" ] || err "rc/lib/rcmain missing (ships verbatim)"
[ -f "$HARVEY/adm/timezone/local" ] || err "adm/timezone/local missing (the repo's tz data)"
# 08-04: the D-11 addressing seam bakes at /lib/netaddr.rc
[ -f "$HARVEY/build/aarch64/netaddr.rc" ] || err "build/aarch64/netaddr.rc missing (08-03's seam)"

# 06-07 (D-12, USPACE-06): the tier-1 payload — the full sweep-referenced
# h* binary set (the 41 r9-runnable + 20 write-flow members; the write-flow
# binaries bake too — the sweep emits their named T1-SKIP lines from the
# venue guard this era, and the image is the ONE tier-1 payload for every
# later venue) + the sweep script + its fixed inputs as /lib data.
# hdrawtest/harctest are excluded BY DESIGN (the 06-05 faulting libmemdraw
# pair — never sweep-invoked); hstacksmoke is not sweep-referenced (the
# image's plain stacksmoke rides the termrc).  Producer: subset-build.sh
# (the tier-file loops) exactly as for the subset inputs above.
TIER1_BINS="cat cp date echo ls mkdir mv ps rm sed test wc rc grep awk"
TIER1_BINS="$TIER1_BINS bc sort tr uniq tail dd tar chmod tee basename sleep cmp comm fmt join look pr split strings sum md5sum sha1sum ed dc units cal touch time seq read du xd nm"
TIER1_BINS="$TIER1_BINS cpp mk yacc lex 7a 7c 7l"
for f in $TIER1_BINS; do
	[ -f "$BIN/$f" ] || err "$BIN/$f missing — run sh build/aarch64/subset-build.sh first (the tier-1 sweep payload)"
done
[ -f "$BIN/ip/ipconfig" ] || err "$BIN/ip/ipconfig missing — run sh build/aarch64/subset-build.sh first"
[ -f "$BIN/auth/factotum" ] || err "$BIN/auth/factotum missing — run sh build/aarch64/subset-build.sh first"
[ -f "$OUT/hdisktest" ] || err "$OUT/hdisktest missing — run sh build/aarch64/subset-build.sh first"
[ -f "$OUT/htdraw" ] || err "$OUT/htdraw missing — run sh build/aarch64/subset-build.sh first"
[ -f "$HARVEY/build/aarch64/tier1-sweep.rc" ] || err "build/aarch64/tier1-sweep.rc missing (the D-10 sweep)"
for f in tiny.y tiny.l tiny.mk tiny.s nm-input.7 hello.c; do
	[ -f "$HARVEY/build/aarch64/$f" ] || err "build/aarch64/$f missing (06-06 committed fixed input)"
done

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

# 2. empty mount-point dirs + staging parents
mkdir -p "$STAGE/root" "$STAGE/env" "$STAGE/proc" "$STAGE/dev" "$STAGE/srv" \
	"$STAGE/fd" "$STAGE/bin" "$STAGE/tmp" "$STAGE/mnt" \
	"$STAGE/boot" "$STAGE/aarch64/bin/ip" "$STAGE/aarch64/bin/auth" \
	"$STAGE/rc/lib" "$STAGE/rc/bin" "$STAGE/adm/timezone"
# 2a. /net (07-07, NETDRV-03): the net-sweep's `bind -a '#l' /net` needs
#     the baked mount-point dir — r9's sys_bind requires the target to
#     EXIST and the paqfs root is read-only this era (no runtime mkdir).
mkdir -p "$STAGE/net"

# 3. binaries
cp "$OUT/boot" "$STAGE/boot/boot"
cp "$OUT/paqfs" "$STAGE/boot/paqfs"
cp "$OUT/init" "$STAGE/aarch64/init"
for f in $SUBSET; do
	cp "$BIN/$f" "$STAGE/aarch64/bin/$f"
done
cp "$BIN/ip/ipconfig" "$STAGE/aarch64/bin/ip/ipconfig"
cp "$BIN/auth/factotum" "$STAGE/aarch64/bin/auth/factotum"
# 08-03: the Phase-8 gate binaries bake beside ipconfig (D-12)
cp "$BIN/ip/ping" "$STAGE/aarch64/bin/ip/ping"
cp "$BIN/ip/udpecho" "$STAGE/aarch64/bin/ip/udpecho"
cp "$BIN/aan" "$STAGE/aarch64/bin/aan"
cp "$OUT/stacksmoke" "$STAGE/aarch64/bin/stacksmoke"
cp "$OUT/netblast" "$STAGE/aarch64/bin/netblast"
# 08-03: the soak machinery + echo server bake beside netblast
cp "$OUT/tcpblast" "$STAGE/aarch64/bin/tcpblast"
cp "$OUT/tcpecho" "$STAGE/aarch64/bin/tcpecho"

# 3b. 06-07 (D-12): the tier-1 sweep payload — h-prefixed binaries into
#     /aarch64/bin (the sweep invokes them as /bin/h* on r9 through the
#     namespace's /bin union), the sweep + fixed inputs as /lib data
#     (the paqfs image is read-only — data rides /lib, matching
#     /lib/net-sweep.rc's precedent)
mkdir -p "$STAGE/lib/tier1"
for f in $TIER1_BINS; do
	cp "$BIN/$f" "$STAGE/aarch64/bin/h$f"
done
cp "$BIN/ip/ipconfig" "$STAGE/aarch64/bin/hipconfig"
cp "$BIN/auth/factotum" "$STAGE/aarch64/bin/hfactotum"
cp "$OUT/htdraw" "$STAGE/aarch64/bin/htdraw"
cp "$OUT/hdisktest" "$STAGE/aarch64/bin/hdisktest"
cp "$HARVEY/build/aarch64/tier1-sweep.rc" "$STAGE/lib/tier1-sweep.rc"
# the known-content sentinel (the same bytes subset-exec.sh bakes — the
# sweep's wc/md5sum/sha1sum asserts key on them)
printf 'alpha bravo charlie\n__SUBSET_GREP_LINE__\n' > "$STAGE/lib/tier1/sentinel.txt"
for f in tiny.y tiny.l tiny.mk tiny.s nm-input.7 hello.c; do
	cp "$HARVEY/build/aarch64/$f" "$STAGE/lib/tier1/$f"
done

# 4. bake-time verbatim copies (rcmain: never edited, single source of
#    truth; timezone: the repo's data, consumed by init's cpenv)
cp "$HARVEY/rc/lib/rcmain" "$STAGE/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE/adm/timezone/local"
# 08-04: the D-11 addressing seam is baked verbatim at /lib/netaddr.rc
# (single source of truth — the root-tree netip sweeps source it)
cp "$HARVEY/build/aarch64/netaddr.rc" "$STAGE/lib/netaddr.rc"

# 5. pre-bake manifest: every mandated path exists, and /boot/factotum
#    is ABSENT (auth-stub-by-absence)
for p in boot/boot boot/paqfs aarch64/init aarch64/bin/stacksmoke \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile; do
	[ -f "$STAGE/$p" ] || err "manifest: $p missing from staged tree"
done

# 5b. 07-04 payload manifest (D-07/D-08): the net test payload must be
#     baked — the committed-skeleton tar copy carries the lib/ files,
#     and these asserts make an absent payload fail the bake loudly
for p in lib/test/arp.req lib/net-sweep.rc; do
	[ -f "$STAGE/$p" ] || err "manifest: $p missing from staged tree"
done
# 08-04 (NETIP-03): the loopback gate fixture + the D-11 seam it
# sources must be baked (same loudly-failing assert shape)
for p in lib/netip-loopback.rc lib/netaddr.rc; do
	[ -f "$STAGE/$p" ] || err "manifest: $p missing from staged tree"
done
[ -f "$STAGE/aarch64/bin/netblast" ] || err "manifest: aarch64/bin/netblast missing from staged tree"

# 5a. init identity: out/ was shared with the
# staged-init supply chain — the sharing ended (the smoke stage
# owns build/aarch64/smoke-out/ exclusively; out/ is the boot chain's
# alone), so the WRONG binary can never land here again.  The assertion
# stays as the permanent guard.  Prove the REAL init at bake time:
# the real init carries "init: starting /bin/rc"; the staged one carries
# "init: r9 EL0 alive" (grep on a.out binaries matches rodata strings;
# "$GREP" is the host grep resolved at the top of this script — plan9
# grep lacks -q).
"$GREP" -q "init: starting /bin/rc" "$OUT/init" \
	|| err "out/init is not the real init (staged-supply-chain pollution — re-run sh build/aarch64/subset-build.sh)"
"$GREP" -q "init: r9 EL0 alive" "$OUT/init" \
	&& err "out/init is the STAGED init (re-run sh build/aarch64/subset-build.sh)"
for f in $SUBSET; do
	[ -f "$STAGE/aarch64/bin/$f" ] || err "manifest: aarch64/bin/$f missing"
done
[ -f "$STAGE/aarch64/bin/ip/ipconfig" ] || err "manifest: aarch64/bin/ip/ipconfig missing"
[ -f "$STAGE/aarch64/bin/auth/factotum" ] || err "manifest: aarch64/bin/auth/factotum missing"
# 08-03: the Phase-8 gate binaries are asserted pre-bake (T-08-05: a
# missing/stale payload fails the bake loudly)
[ -f "$STAGE/aarch64/bin/ip/ping" ] || err "manifest: aarch64/bin/ip/ping missing"
[ -f "$STAGE/aarch64/bin/ip/udpecho" ] || err "manifest: aarch64/bin/ip/udpecho missing"
[ -f "$STAGE/aarch64/bin/aan" ] || err "manifest: aarch64/bin/aan missing"
[ -f "$STAGE/aarch64/bin/tcpblast" ] || err "manifest: aarch64/bin/tcpblast missing"
[ -f "$STAGE/aarch64/bin/tcpecho" ] || err "manifest: aarch64/bin/tcpecho missing"
# 06-07 (D-12): every tier-1 payload path is asserted pre-bake (T-06-15:
# a stale bake would certify old binaries — presence of the just-staged
# paths is the tripwire)
for f in $TIER1_BINS; do
	[ -f "$STAGE/aarch64/bin/h$f" ] || err "manifest: aarch64/bin/h$f missing"
done
for p in aarch64/bin/hipconfig aarch64/bin/hfactotum aarch64/bin/htdraw aarch64/bin/hdisktest \
	lib/tier1-sweep.rc lib/tier1/sentinel.txt lib/tier1/tiny.y lib/tier1/tiny.l \
	lib/tier1/tiny.mk lib/tier1/tiny.s lib/tier1/nm-input.7 lib/tier1/hello.c; do
	[ -f "$STAGE/$p" ] || err "manifest: $p missing from staged tree"
done
for p in root env proc dev srv fd bin tmp mnt; do
	[ -d "$STAGE/$p" ] || err "manifest: mount-point dir /$p missing"
done
[ -d "$STAGE/net" ] || err "manifest: mount-point dir /net missing"	# 07-07 (see 2a)
[ ! -e "$STAGE/boot/factotum" ] || err "manifest: /boot/factotum present — D-02 auth-stub-by-absence violated"

# rcmain ships byte-verbatim (the amd64-safety constraint keys on image
# contents) — prove it at bake time
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain"

# 6. bake
rm -f "$IMAGE"
"$MKPAQFS" -o "$IMAGE" "$STAGE" || err "mkpaqfs failed"
[ -s "$IMAGE" ] || err "$IMAGE missing/empty after mkpaqfs"

# 7. the byte-format contract r9's reader consumes (the proven
#    checks): paqfs header magic 529ab12b (first 4 bytes) and trailer
#    magic 6b46e688 (the last 28-byte block's first 4 bytes)
magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d ' \n')
[ "$magic" = "529ab12b" ] || err "$IMAGE: bad header magic $magic (want 529ab12b)"
sz=$(wc -c < "$IMAGE" | tr -d ' ')
trailer=$(dd if="$IMAGE" bs=1 skip=$((sz - 28)) count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')
# 07-04: re-extract with od -j — Harvey's host dd (dash-pair arg
# syntax) shadows POSIX dd on the devshell PATH (the D-02
# hostbin-shadowing class, same as the grep fix), leaving trailer
# empty and the bake red; od is never shadowed (Plan 9 has no od)
trailer=$(od -An -tx1 -j $((sz - 28)) -N 4 "$IMAGE" | tr -d ' \n')
[ "$trailer" = "6b46e688" ] || err "$IMAGE: bad trailer magic $trailer (want 6b46e688)"

echo "== PASS: baked $IMAGE ($sz bytes; header $magic trailer $trailer)"
