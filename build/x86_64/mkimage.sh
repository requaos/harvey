#!/bin/sh
# build/x86_64/mkimage.sh — bake build/x86_64/out/bootfs.paq (the 14-05
# MARKER image), build/x86_64/out/bootfs-chain.paq (the 14-06 BOOT-CHAIN
# image), and, since 14-08, build/x86_64/out/bootfs-tier.paq (the TIER
# image — the chain tree + the tier-1 sweep payload), the paqfs root
# images for the r9 x86_64 boots (D-04:
# the byte format carried VERBATIM from aarch64 — same header magic
# 529ab12b, same trailer 6b46e688, same in-tree mkpaqfs, same r9
# miniz-inflate reader).  Each stages a scratch tree from the committed
# build/x86_64/root-tree/ skeleton plus the built binaries, then invokes
# the host mkpaqfs (.build/bin/mkpaqfs, built by
# build/x86_64/mkpaqfs-host.sh when missing).
#
# Marker-image contract (D-08's staged leg 1 — the q35exec gate):
#   /amd64/init                  the smokesleep marker (the q35exec
#                                BOOT_ENTRY target) — NOT the real
#                                init
#   empty dirs /root /env /proc /dev /srv /fd /bin /tmp /mnt /net
#   NO /boot/factotum            auth stub = absence: its mere presence
#                                flips authentication() into the real
#                                factotum-exec path (Phase 18)
#   NO /boot/*, NO /rc/*         the chain's alone
#
# Chain-image contract (14-06, XEXEC-03 leg 2 — the q35shell gate; the
# aarch64 boot-chain manifest re-keyed to /amd64 paths):
#   /boot/boot, /boot/paqfs      boot(8) + its paqfs 9P server
#   /amd64/init                  the REAL init (execinit's /%s/init)
#   /amd64/bin/rc                init's fexec target
#   /rc/lib/rcmain               copied VERBATIM from rc/lib/rcmain at
#                                bake time (single source of truth; the
#                                cmp guard pins it — the rc-main that
#                                sets the '% ' prompt the gate asserts)
#   /rc/bin/termrc               scoped — committed skeleton
#   /lib/namespace               scoped — committed skeleton
#   /adm/timezone/local          copied from the repo's adm/timezone
#                                at bake time (init's cpenv consumer)
#   /usr/glenda/lib/profile      committed skeleton
#   empty dirs /root /env /proc /dev /srv /fd /bin /tmp /mnt /net
#   NO /boot/factotum            auth stub = absence (same rule)
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
# devshell; run stage-build.sh first — the smoke-out/ + out/ inputs)

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
# 14-06: the chain inputs (stage-build.sh's boot-chain section — out/ is
# the boot chain's home, the aarch64 separation; the marker owns
# smoke-out/init and the real init must never overwrite it)
CHAIN_OUT="$HARVEY/build/x86_64/out"
for f in boot init rc paqfs ls cat echo ps; do
	[ -s "$CHAIN_OUT/$f" ] || err "$CHAIN_OUT/$f missing — run sh build/x86_64/stage-build.sh first (the boot-chain section)"
done
[ -f "$HARVEY/rc/lib/rcmain" ] || err "rc/lib/rcmain missing (ships verbatim)"
[ -f "$HARVEY/adm/timezone/local" ] || err "adm/timezone/local missing (the repo's tz data)"
[ -f "$ROOT_TREE/rc/bin/termrc" ] || err "$ROOT_TREE/rc/bin/termrc missing — the committed chain skeleton (14-06)"
[ -f "$ROOT_TREE/lib/namespace" ] || err "$ROOT_TREE/lib/namespace missing — the committed chain skeleton (14-06)"
[ -f "$ROOT_TREE/usr/glenda/lib/profile" ] || err "$ROOT_TREE/usr/glenda/lib/profile missing — the committed chain skeleton (14-06)"

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

# 1. the committed skeleton (14-06 grew rcmain/termrc/namespace into the
#    root-tree — the CHAIN bake consumes them; the marker tree strips
#    the chain-only /rc + /usr subtrees so the 14-05 leg-1 contract
#    (NO /rc/*, chain files absent) keeps its letter)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE" && tar -xf -)
rm -rf "$STAGE/rc" "$STAGE/usr"

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

# ------------------------------------------------------------------
# 8. the CHAIN bake (14-06, XEXEC-03 leg 2 — the aarch64 boot-chain
#    manifest re-keyed to /amd64 paths).  A fresh staging tree; the
#    chain binaries come from out/ (stage-build.sh's boot-chain
#    section), rcmain verbatim from rc/lib/rcmain, the rc/lib +
#    timezone data from the repo.  Same KERNDATE determinism + the same
#    byte-format contract as the marker bake above.
CHAIN_IMAGE="$OUT/bootfs-chain.paq"

# 8a. chain-binary identity (the marker guard, INVERTED — the chain
#     image's /amd64/init IS the real init; grep matches rodata strings
#     on the a.out bytes)
"$GREP" -q "init: starting /bin/rc" "$CHAIN_OUT/init" \
	|| err "out/init is not the real init (the marker landed in the chain home — re-run sh build/x86_64/stage-build.sh)"
"$GREP" -q "smokesleep: interrupted" "$CHAIN_OUT/init" \
	&& err "out/init is the smokesleep marker (leg-1 supply pollution — re-run sh build/x86_64/stage-build.sh)"

STAGE2="$TMPD/root-chain"
mkdir -p "$STAGE2"

# 8b. the committed skeleton (termrc/namespace/profile — the chain
#     consumes the whole tree; the README stays, harmless)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE2" && tar -xf -)

# 8c. empty mount-point dirs + staging parents (the marker bake's
#     fixed-order shape)
mkdir -p "$STAGE2/root" "$STAGE2/env" "$STAGE2/proc" "$STAGE2/dev" "$STAGE2/srv" \
	"$STAGE2/fd" "$STAGE2/bin" "$STAGE2/tmp" "$STAGE2/mnt" \
	"$STAGE2/net" "$STAGE2/boot" "$STAGE2/amd64/bin" \
	"$STAGE2/rc/lib" "$STAGE2/rc/bin" "$STAGE2/adm/timezone"

# 8d. the chain binaries (deterministic staging order; the 14-07 sweep
#     set joins rc in amd64/bin — /bin binds /root/$cputype/bin, so the
#     smoke's ls /bin assertion finds them there)
cp "$CHAIN_OUT/boot" "$STAGE2/boot/boot"
cp "$CHAIN_OUT/paqfs" "$STAGE2/boot/paqfs"
cp "$CHAIN_OUT/init" "$STAGE2/amd64/init"
cp "$CHAIN_OUT/rc" "$STAGE2/amd64/bin/rc"
cp "$CHAIN_OUT/ls" "$STAGE2/amd64/bin/ls"
cp "$CHAIN_OUT/cat" "$STAGE2/amd64/bin/cat"
cp "$CHAIN_OUT/echo" "$STAGE2/amd64/bin/echo"
cp "$CHAIN_OUT/ps" "$STAGE2/amd64/bin/ps"

# 8e. bake-time verbatim copies (rcmain: never edited, single source of
#     truth — the rc-main that sets the '% ' prompt; timezone: the
#     repo's data, consumed by init's cpenv)
cp "$HARVEY/rc/lib/rcmain" "$STAGE2/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE2/adm/timezone/local"

# 8f. pre-bake manifest: every mandated chain path exists — PRINTED as
#     the staging manifest (the bake log is the gate's evidence)
for p in boot/boot boot/paqfs amd64/init amd64/bin/rc \
	amd64/bin/ls amd64/bin/cat amd64/bin/echo amd64/bin/ps \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile; do
	[ -f "$STAGE2/$p" ] || err "chain manifest: $p missing from staged tree"
	echo "chain manifest: /$p staged"
done
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE2/$p" ] || err "chain manifest: mount-point dir /$p missing"
done

# 8g. /boot/factotum ABSENCE (auth-stub-by-absence — the same D-02 rule
#     as the marker bake; the chain's authentication() takes the
#     glenda() stub path without it)
[ ! -e "$STAGE2/boot/factotum" ] || err "chain manifest: /boot/factotum present — auth-stub-by-absence violated"

# 8h. rcmain ships byte-verbatim (the aarch64 cmp guard, carried)
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE2/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain"

# 8i. determinism: pin every staged mtime to KERNDATE (the marker
#     bake's rule)
find "$STAGE2" -exec touch -h -d "@$KERNDATE" {} +

# 8j. bake
rm -f "$CHAIN_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$CHAIN_IMAGE" "$STAGE2" || err "mkpaqfs failed (chain)"
[ -s "$CHAIN_IMAGE" ] || err "$CHAIN_IMAGE missing/empty after mkpaqfs"

# 8k. the byte-format contract (same header/trailer magic checks)
magic2=$(od -An -tx1 -N4 "$CHAIN_IMAGE" | tr -d ' \n')
[ "$magic2" = "529ab12b" ] || err "$CHAIN_IMAGE: bad header magic $magic2 (want 529ab12b)"
sz2=$(wc -c < "$CHAIN_IMAGE" | tr -d ' ')
trailer2=$(od -An -tx1 -j $((sz2 - 28)) -N 4 "$CHAIN_IMAGE" | tr -d ' \n')
[ "$trailer2" = "6b46e688" ] || err "$CHAIN_IMAGE: bad trailer magic $trailer2 (want 6b46e688)"

echo "== PASS: baked $CHAIN_IMAGE ($sz2 bytes; header $magic2 trailer $trailer2; KERNDATE $KERNDATE)"

# ------------------------------------------------------------------
# 9. the TIER bake (14-08, XEXEC-04): the chain tree + the tier-1
#    sweep payload — out/bootfs-tier.paq.  The tier gate boots THIS
#    image to the % prompt and types ONE line (`rc /lib/tier1-sweep.rc
#    r9`), so it carries the chain manifest (8's set) PLUS the h*-
#    prefixed tier binaries into /amd64/bin (the sweep invokes them as
#    /bin/h* through the namespace's /bin union — the aarch64 3b
#    discipline) and the sweep script + fixed inputs under /lib.  The
#    h* staging set is COMPUTED from build/x86_64/tiers/tier1-cmds.txt
#    (the driver-only entries excluded) — the tier data is the single
#    source, never a second hardcoded list.  The BIN sources are the
#    SAME /amd64/bin set the k10t1 donor kernel embeds from; when the
#    donor venue's manifest (.build/9k10t1-tier-manifest.sha256,
#    written by build/mm/build-9k10t1.sh's r9 leg) is present every
#    member is digest-verified here — the identical-6.outs ABI witness
#    (T-14-15) is structural, not incidental.
TIER_IMAGE="$OUT/bootfs-tier.paq"
BIN="$HARVEY/amd64/bin"

# 9a. the witness manifest (both venues, one binary set): verify every
#     pinned digest still matches /amd64/bin BEFORE staging — a drifted
#     member means the donor kernel embedded different bytes than this
#     bake stages (the witness would be void).
WITNESS_MANIFEST="$HARVEY/.build/9k10t1-tier-manifest.sha256"
if [ -s "$WITNESS_MANIFEST" ]; then
	_wfail=""
	while read -r _wsha _wrel; do
		case "$_wsha" in ''|'#'*) continue ;; esac
		_want=$_wsha
		_got=$(sha256sum "$HARVEY/$_wrel" 2>/dev/null | cut -d' ' -f1)
		[ "$_got" = "$_want" ] || _wfail="$_wfail $_wrel"
	done < "$WITNESS_MANIFEST"
	[ -z "$_wfail" ] || err "the /amd64/bin set drifted from the donor venue's manifest:$_wfail — re-run build/mm/build-9k10t1.sh (the identical-6.outs witness requires ONE set)"
	echo "== witness manifest verified: $(wc -l < "$WITNESS_MANIFEST" | tr -d ' ') members match the donor venue's embed set"
else
	echo "== witness manifest absent (build/mm/build-9k10t1.sh not run) — the tier bake proceeds; the both-venues witness is NOT structural this run"
fi

# 9b. the h* staging set, computed from the tier data (the same
#     entry->name mapping the venue gates' expectations use)
TIER1_RELS=$(
	awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/x86_64/tiers/tier1-cmds.txt" |
	while read -r e; do
		case "$e" in
		9k/boot|stage/*|cmd/paqfs:paqfs|cmd/cc) continue ;;
		esac
		case "$e" in *:*) e="${e%%:*}" ;; esac
		echo "${e#cmd/}"
	done
)
[ -n "$TIER1_RELS" ] || err "the tier-1 h* staging set is empty — the tier data parse failed"
[ -f "$HARVEY/build/x86_64/tier1-sweep.rc" ] || err "build/x86_64/tier1-sweep.rc missing (the in-guest sweep)"
[ -f "$HARVEY/build/x86_64/nm-input.6" ] || err "build/x86_64/nm-input.6 missing (the committed nm fixture — reproduce with: objtype=amd64 6c -FTVw -Isys/include -Iamd64/include \$HARVEY/build/x86_64/hello.c)"
[ -s "$BIN/rc" ] || err "$BIN/rc missing — run sh build/x86_64/subset-build.sh first (the tier build)"
[ -s "$HARVEY/amd64/init" ] || err "$HARVEY/amd64/init missing — run sh build/x86_64/subset-build.sh first (stage/init)"
[ -s "$CHAIN_OUT/boot" ] || err "$CHAIN_OUT/boot missing — run sh build/x86_64/subset-build.sh first (9k/boot)"
[ -s "$BIN/paqfs" ] || err "$BIN/paqfs missing — run sh build/x86_64/subset-build.sh first"

STAGE3="$TMPD/root-tier"
mkdir -p "$STAGE3"

# 9c. the committed skeleton (the chain bake's shape — the tier image
#     is the chain image plus the payload)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE3" && tar -xf -)

# 9d. empty mount-point dirs + staging parents (the chain set)
mkdir -p "$STAGE3/root" "$STAGE3/env" "$STAGE3/proc" "$STAGE3/dev" "$STAGE3/srv" \
	"$STAGE3/fd" "$STAGE3/bin" "$STAGE3/tmp" "$STAGE3/mnt" \
	"$STAGE3/net" "$STAGE3/boot" "$STAGE3/amd64/bin" \
	"$STAGE3/rc/lib" "$STAGE3/rc/bin" "$STAGE3/adm/timezone" "$STAGE3/lib/tier1"

# 9e. the chain binaries from THIS build's products (BIN + /amd64/init
#     + out/boot — the same set subset-build just installed; never a
#     stale out/ harvest for members that have a /amd64/bin home)
cp "$CHAIN_OUT/boot" "$STAGE3/boot/boot"
cp "$BIN/paqfs" "$STAGE3/boot/paqfs"
cp "$HARVEY/amd64/init" "$STAGE3/amd64/init"
for f in rc ls cat echo ps; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first"
	cp "$BIN/$f" "$STAGE3/amd64/bin/$f"
done

# 9f. the tier-1 sweep payload: h-prefixed copies (the sweep's /bin/h*
#     vocabulary), the sweep script, the sentinel (byte-exact — the
#     digests the sweep asserts are pinned HERE at bake time), and the
#     nm fixture
for rel in $TIER1_RELS; do
	[ -f "$BIN/$rel" ] || err "$BIN/$rel missing — run sh build/x86_64/subset-build.sh first (the tier-1 sweep payload)"
	cp "$BIN/$rel" "$STAGE3/amd64/bin/h${rel##*/}"
done
cp "$HARVEY/build/x86_64/tier1-sweep.rc" "$STAGE3/lib/tier1-sweep.rc"
printf 'alpha bravo charlie\n__SUBSET_GREP_LINE__\n' > "$STAGE3/lib/tier1/sentinel.txt"
_md5=$(md5sum "$STAGE3/lib/tier1/sentinel.txt" | cut -d' ' -f1)
_sha1=$(sha1sum "$STAGE3/lib/tier1/sentinel.txt" | cut -d' ' -f1)
[ "$_md5" = "6c3d57e94871f9606c5b63c315e76135" ] || err "sentinel md5 drift: $_md5 (want 6c3d57e94871f9606c5b63c315e76135) — the sweep's pinned assert would red in the guest"
[ "$_sha1" = "893404a2c36b54f5c7874070d1acefe38f7ce652" ] || err "sentinel sha1 drift: $_sha1 (want 893404a2c36b54f5c7874070d1acefe38f7ce652)"
cp "$HARVEY/build/x86_64/nm-input.6" "$STAGE3/lib/tier1/nm-input.6"

# 9g. bake-time verbatim copies (the chain bake's rule), plus the tier
#     termrc OVERRIDE: the skeleton's rc/bin/termrc is replaced by the
#     committed build/x86_64/tier-termrc — the tier image runs the
#     sweep from the boot flow (the donor venue's k10t1.rc shape), no
#     typed interaction
cp "$HARVEY/rc/lib/rcmain" "$STAGE3/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE3/adm/timezone/local"
[ -f "$HARVEY/build/x86_64/tier-termrc" ] || err "build/x86_64/tier-termrc missing (the tier image's termrc override)"
cp "$HARVEY/build/x86_64/tier-termrc" "$STAGE3/rc/bin/termrc"

# 9h. pre-bake manifest: the chain paths + the h* payload, PRINTED as
#     the staging manifest (the bake log is the gate's evidence)
for p in boot/boot boot/paqfs amd64/init amd64/bin/rc \
	amd64/bin/ls amd64/bin/cat amd64/bin/echo amd64/bin/ps \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile lib/tier1-sweep.rc lib/tier1/sentinel.txt \
	lib/tier1/nm-input.6; do
	[ -f "$STAGE3/$p" ] || err "tier manifest: $p missing from staged tree"
	echo "tier manifest: /$p staged"
done
_nh=0
for rel in $TIER1_RELS; do
	[ -f "$STAGE3/amd64/bin/h${rel##*/}" ] || err "tier manifest: amd64/bin/h${rel##*/} missing from staged tree"
	_nh=$((_nh + 1))
done
echo "tier manifest: ${_nh} h* sweep binaries staged (computed from tiers/tier1-cmds.txt)"
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE3/$p" ] || err "tier manifest: mount-point dir /$p missing"
done

# 9i. /boot/factotum ABSENCE (auth-stub-by-absence — the same D-02
#     rule; hfactotum in /amd64/bin is the sweep payload, NOT the
#     /boot auth stub)
[ ! -e "$STAGE3/boot/factotum" ] || err "tier manifest: /boot/factotum present — auth-stub-by-absence violated"

# 9j. rcmain ships byte-verbatim (the chain bake's cmp guard)
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE3/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain"

# 9k. determinism + bake (the chain bake's rule)
find "$STAGE3" -exec touch -h -d "@$KERNDATE" {} +
rm -f "$TIER_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$TIER_IMAGE" "$STAGE3" || err "mkpaqfs failed (tier)"
[ -s "$TIER_IMAGE" ] || err "$TIER_IMAGE missing/empty after mkpaqfs"

# 9l. the byte-format contract (same header/trailer magic checks)
magic3=$(od -An -tx1 -N4 "$TIER_IMAGE" | tr -d ' \n')
[ "$magic3" = "529ab12b" ] || err "$TIER_IMAGE: bad header magic $magic3 (want 529ab12b)"
sz3=$(wc -c < "$TIER_IMAGE" | tr -d ' ')
trailer3=$(od -An -tx1 -j $((sz3 - 28)) -N 4 "$TIER_IMAGE" | tr -d ' \n')
[ "$trailer3" = "6b46e688" ] || err "$TIER_IMAGE: bad trailer magic $trailer3 (want 6b46e688)"

echo "== PASS: baked $TIER_IMAGE ($sz3 bytes; ${_nh} h* binaries; header $magic3 trailer $trailer3; KERNDATE $KERNDATE)"
