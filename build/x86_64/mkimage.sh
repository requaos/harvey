#!/bin/sh
# build/x86_64/mkimage.sh — bake build/x86_64/out/bootfs.paq (the 14-05
# MARKER image), build/x86_64/out/bootfs-chain.paq (the 14-06 BOOT-CHAIN
# image), build/x86_64/out/bootfs-tier.paq (the 14-08 TIER image — the
# chain tree + the tier-1 sweep payload), and, since 14-09,
# build/x86_64/out/bootfs-net.paq (the NET image — the chain tree + the
# net-gate payload: the ip-container binaries + the 6c C helpers + the
# /lib fixtures), and, since 15-03,
# build/x86_64/out/bootfs-services.paq (the SERVICES image — the chain
# tree + the tier-2 services sweep payload for the r9-x64 venue), the
# paqfs root
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
# Net-image contract (14-09, XEXEC-05 leg — the composed net gate's
# image; the aarch64 Phase-8 net manifest re-keyed to /amd64 paths):
#   the chain manifest (8's set) PLUS
#   /amd64/bin/ip/{ipconfig,ping,udpecho}
#                                the REAL net binaries (the tier build's
#                                ipconfig + its 14-09 net section)
#   /amd64/bin/{tcpecho,tcpblast,netblast}
#                                the 6c C-helper re-keys (out/ supply)
#   /amd64/bin/{grep,sed,dd,wc,sha1sum,test,bind,dc}
#                                the fixtures' utility set (test/bind
#                                are NOT rc builtins; dc is 16-02's
#                                tap-fixture burst counter)
#   /lib/netaddr.rc              the D-11 addressing seam (the ONLY
#                                place a venue address may live —
#                                asserted at bake time, both venue
#                                prefixes since 16-02)
#   /lib/netip-{loopback,static,dhcp,tcp,tap}.rc
#                                the in-guest net fixtures (netip-tap.rc
#                                is 16-02's NETIP-08 tap leg)
#   NO /boot/factotum            auth stub = absence (same rule)
#
# Payload contract (15-08, DESK-03 — the desktop payload Phases 18-19
# consume, staged so they never block on it).  NOT a sixth image: a
# shared staging section (stage_payload, section P below) that a bake
# contract DECLARES by invoking it on its staged tree — the services
# image (section 11) is the declaring contract this era.  The cargo is
# defined by ONE committed data file, build/x86_64/bootfs-payload.txt
# (the tier-allowlist pattern; no second hardcoded list anywhere):
#   /lib/font/bit/...            the WHOLE font tree — a BAKE-TIME
#                                copy from the repo's lib/font/bit
#                                (the adm/timezone rule above; never a
#                                committed duplicate under root-tree/)
#   /usr/glenda/lib/profile      committed skeleton — the D-17 trimmed
#                                cpu-aware profile (terminal case
#                                rio-free, cpu case intact; the shape
#                                is asserted on the staged file)
#   /lib/ndb/local               SUBSTITUTED at bake time from the
#                                committed token template
#                                root-tree/lib/ndb/local.template via
#                                the netaddr seam (D-16: tokens only,
#                                never a venue literal; zero leftover
#                                tokens asserted)
#   the manifest asserts          every listed path present + non-empty
#                                in the staged tree, the app-named
#                                fonts present, the count/size floors
#                                met — a miss FAILS the bake, and
#                                every bake PRINTS what it carried
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

# inputs (stage-build.sh is the producer — named loudly when absent).
# 17-02 adds the churn pair (churnmark/churnsem — the exec-loop payload
# and CR-03's RFMEM sem contender) to the MARKER image, staged beside
# init/smokesleep; the additive rule (existing manifests untouched).
for f in init smokesleep churnmark churnsem; do
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
#    fixed list; init is the leg-1 entry, smokesleep its source name).
#    17-02 stages the churn pair beside them (the additive rule): the
#    q35churn profile's kernel-side driver walks these by name.
cp "$STAGE_SRC/init" "$STAGE/amd64/init"
cp "$STAGE_SRC/smokesleep" "$STAGE/amd64/smokesleep"
cp "$STAGE_SRC/churnmark" "$STAGE/amd64/churnmark"
cp "$STAGE_SRC/churnsem" "$STAGE/amd64/churnsem"

# 4. pre-bake manifest: every mandated path exists
for p in amd64/init amd64/smokesleep amd64/churnmark amd64/churnsem; do
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

# 4a1. churn-pair identity (17-02): each churn binary is itself (the
#      rodata-grep class — churnmark prints its ready line from ring 3,
#      churnsem prints the generation marker the gate counts)
"$GREP" -q "churnmark: ready" "$STAGE/amd64/churnmark" \
	|| err "amd64/churnmark does not carry its marker string (re-run sh build/x86_64/stage-build.sh)"
"$GREP" -q "churngate: semgen" "$STAGE/amd64/churnsem" \
	|| err "amd64/churnsem does not carry its generation marker (re-run sh build/x86_64/stage-build.sh)"

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

# ------------------------------------------------------------------
# 10. the NET bake (14-09, XEXEC-05, D-07): the chain tree + the
#     net-gate payload — out/bootfs-net.paq.  The composed net gate
#     boots THIS image to the % prompt and drives the baked fixtures
#     through it (the aarch64 08-09 net-smoke's image shape re-keyed
#     to /amd64 paths): the chain manifest (8's set — boot(8), paqfs,
#     the real init, rc, the sweep set) PLUS the net binaries —
#     ipconfig + ping + udpecho from the ip container's amd64 path
#     (/amd64/bin/ip/, the tier build + its 14-09 net section), the
#     three 6c C helpers from out/ (tcpecho/tcpblast/netblast), and
#     the gate-utility set the fixtures' bodies exec (grep sed dd wc
#     sha1sum test bind dc — /bin/test and /bin/bind are NOT rc
#     builtins; dc is 16-02's netip-tap.rc burst counter)
#     — PLUS the /lib fixtures (netaddr.rc the D-11 seam + the five
#     netip-*.rc sweeps — netip-tap.rc joins with 16-02's tap leg —
#     riding the committed skeleton).
NET_IMAGE="$OUT/bootfs-net.paq"

# 10a. inputs (the tier build + its net section are the producers —
#      named loudly when absent, with the remediation)
for p in ip/ipconfig ip/ping ip/udpecho; do
	[ -s "$BIN/$p" ] || err "$BIN/$p missing — run sh build/x86_64/subset-build.sh first (the 14-09 net section)"
done
for f in grep sed dd wc sha1sum test bind dc paqfs rc ls cat echo ps; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first (the net gate's utility set; dc is 16-02's tap-fixture burst counter)"
done
[ -s "$HARVEY/amd64/init" ] || err "amd64/init missing — run sh build/x86_64/subset-build.sh first (stage/init)"
[ -s "$CHAIN_OUT/boot" ] || err "$CHAIN_OUT/boot missing — run sh build/x86_64/subset-build.sh first (9k/boot)"
for f in netblast tcpblast tcpecho; do
	[ -s "$CHAIN_OUT/$f" ] || err "$CHAIN_OUT/$f missing — run sh build/x86_64/subset-build.sh first (the 14-09 net helpers)"
done
for f in netaddr.rc netip-loopback.rc netip-static.rc netip-dhcp.rc netip-tcp.rc netip-tap.rc; do
	[ -f "$ROOT_TREE/lib/$f" ] || err "$ROOT_TREE/lib/$f missing — the committed net fixture (14-09; netip-tap.rc is 16-02's tap leg)"
done

# 10b. the D-11 single-seam discipline, asserted at bake time (T-14-17
#      carried mechanically; extended to the tap subnet by 16-02,
#      D-06): NO venue address literal may live in any root-tree
#      fixture EXCEPT netaddr.rc — one grep per venue prefix (slirp,
#      tap), both scoped to the fixtures directory and excluding the
#      seam by name, one err per stray class.  A stray elsewhere
#      re-couples the gates to one venue and reds the bake here, never
#      the eye later (the 15-07 comment-prose lesson: prose counts
#      too).
_stray=$("$GREP" -rn '10\.0\.2\.' "$ROOT_TREE/lib/" 2>/dev/null | "$GREP" -v 'netaddr\.rc' || true)
[ -z "$_stray" ] || err "venue address literal outside netaddr.rc (the D-11 seam violated): $_stray"
_stray=$("$GREP" -rn '192\.168\.122\.' "$ROOT_TREE/lib/" 2>/dev/null | "$GREP" -v 'netaddr\.rc' || true)
[ -z "$_stray" ] || err "venue address literal outside netaddr.rc (the D-11 seam violated): $_stray"

STAGE4="$TMPD/root-net"
mkdir -p "$STAGE4"

# 10c. the committed skeleton (termrc/namespace/profile — the standard
#     INTERACTIVE termrc this time: the net gate drives typed legs at
#     the % prompt, never a termrc override like the tier image's; the
#     lib/ fixtures ride the skeleton tar)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE4" && tar -xf -)

# 10d. empty mount-point dirs + staging parents (the chain set + the
#     ip container's home)
mkdir -p "$STAGE4/root" "$STAGE4/env" "$STAGE4/proc" "$STAGE4/dev" "$STAGE4/srv" \
	"$STAGE4/fd" "$STAGE4/bin" "$STAGE4/tmp" "$STAGE4/mnt" \
	"$STAGE4/net" "$STAGE4/boot" "$STAGE4/amd64/bin/ip" \
	"$STAGE4/rc/lib" "$STAGE4/rc/bin" "$STAGE4/adm/timezone"

# 10e. the chain binaries from THIS build's products (the tier bake's
#     9e discipline: BIN + /amd64/init + out/boot, never a stale out/
#     harvest for members that have a /amd64/bin home)
cp "$CHAIN_OUT/boot" "$STAGE4/boot/boot"
cp "$BIN/paqfs" "$STAGE4/boot/paqfs"
cp "$HARVEY/amd64/init" "$STAGE4/amd64/init"
for f in rc ls cat echo ps; do
	cp "$BIN/$f" "$STAGE4/amd64/bin/$f"
done

# 10f. the net payload: the ip container's binaries at /amd64/bin/ip
#     (ipconfig/ping/udpecho — where /bin's ip/ resolves through the
#     namespace bind), the C helpers + the utility set at /amd64/bin.
#     Deterministic staging order (the fixed lists).
for f in ipconfig ping udpecho; do
	cp "$BIN/ip/$f" "$STAGE4/amd64/bin/ip/$f"
done
for f in tcpecho tcpblast netblast; do
	cp "$CHAIN_OUT/$f" "$STAGE4/amd64/bin/$f"
done
for f in grep sed dd wc sha1sum test bind dc; do
	cp "$BIN/$f" "$STAGE4/amd64/bin/$f"
done

# 10g. bake-time verbatim copies (the chain bake's rule)
cp "$HARVEY/rc/lib/rcmain" "$STAGE4/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE4/adm/timezone/local"

# 10h. pre-bake manifest: the chain paths + the net payload + the
#     fixtures, PRINTED as the staging manifest (the bake log is the
#     gate's evidence — the plan's verify greps these lines)
for p in boot/boot boot/paqfs amd64/init amd64/bin/rc \
	amd64/bin/ls amd64/bin/cat amd64/bin/echo amd64/bin/ps \
	amd64/bin/ip/ipconfig amd64/bin/ip/ping amd64/bin/ip/udpecho \
	amd64/bin/tcpecho amd64/bin/tcpblast amd64/bin/netblast \
	amd64/bin/grep amd64/bin/sed amd64/bin/dd amd64/bin/wc \
	amd64/bin/sha1sum amd64/bin/test amd64/bin/bind amd64/bin/dc \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile lib/netaddr.rc lib/netip-loopback.rc \
	lib/netip-static.rc lib/netip-dhcp.rc lib/netip-tcp.rc \
	lib/netip-tap.rc; do
	[ -f "$STAGE4/$p" ] || err "net manifest: $p missing from staged tree"
	echo "net manifest: /$p staged"
done
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE4/$p" ] || err "net manifest: mount-point dir /$p missing"
done

# 10i. /boot/factotum ABSENCE (auth-stub-by-absence — the same D-02
#     rule as every bake above)
[ ! -e "$STAGE4/boot/factotum" ] || err "net manifest: /boot/factotum present — auth-stub-by-absence violated"

# 10j. rcmain ships byte-verbatim (the chain bake's cmp guard)
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE4/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain"

# 10k. determinism + bake (the chain bake's rule)
find "$STAGE4" -exec touch -h -d "@$KERNDATE" {} +
rm -f "$NET_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$NET_IMAGE" "$STAGE4" || err "mkpaqfs failed (net)"
[ -s "$NET_IMAGE" ] || err "$NET_IMAGE missing/empty after mkpaqfs"

# 10l. the byte-format contract (same header/trailer magic checks)
magic4=$(od -An -tx1 -N4 "$NET_IMAGE" | tr -d ' \n')
[ "$magic4" = "529ab12b" ] || err "$NET_IMAGE: bad header magic $magic4 (want 529ab12b)"
sz4=$(wc -c < "$NET_IMAGE" | tr -d ' ')
trailer4=$(od -An -tx1 -j $((sz4 - 28)) -N 4 "$NET_IMAGE" | tr -d ' \n')
[ "$trailer4" = "6b46e688" ] || err "$NET_IMAGE: bad trailer magic $trailer4 (want 6b46e688)"

echo "== PASS: baked $NET_IMAGE ($sz4 bytes; header $magic4 trailer $trailer4; KERNDATE $KERNDATE)"

# ------------------------------------------------------------------
# P. the DESK-03 PAYLOAD section (15-08 — D-13/D-14/D-15): the desktop
#    payload Phases 18-19 consume.  ONE shared staging function + ONE
#    committed manifest (build/x86_64/bootfs-payload.txt — plain data,
#    consumed by block name; NO second hardcoded list anywhere).  A
#    bake contract DECLARES the payload by calling stage_payload on
#    its staged tree AFTER the skeleton tar (D-13: an image that
#    declares it inherits the payload by construction, and a later
#    contract composes it without re-staging).  The function stages
#    the bake-time members (the font copy; /lib/ndb/local substituted
#    from the committed token template through the netaddr seam —
#    D-16), then asserts the WHOLE manifest against the staged tree
#    plus the D-17 profile shape — the asserts are the only authority
#    on payload completeness (T-15-19/T-15-20: a drifted or partial
#    copy, a leaked literal or a leftover token fails the bake HERE,
#    never the boot later).
PAYLOAD_MANIFEST="$HARVEY/build/x86_64/bootfs-payload.txt"

payload_block() {
	# payload_block <name> — print the data lines of one manifest
	# block ([name] ... up to the next [header]); `#' and blank lines
	# never print
	awk -v b="[$1]" '$0 == b { f = 1; next } /^\[/ { f = 0 } f && NF && $1 !~ /^#/ { print }' "$PAYLOAD_MANIFEST"
}

stage_payload() {
	# stage_payload <staged-tree> <contract-label>
	_ps=$1
	_pl=$2
	[ -s "$PAYLOAD_MANIFEST" ] || err "$PAYLOAD_MANIFEST missing — the committed DESK-03 payload manifest (15-08)"
	[ -d "$HARVEY/lib/font/bit" ] || err "lib/font/bit missing (the D-14 font payload source)"

	# P1. the bake-time font copy: the WHOLE tree (D-14 — no
	#     exclusions; the 8e adm/timezone precedent, never a committed
	#     duplicate)
	mkdir -p "$_ps/lib/font"
	cp -R "$HARVEY/lib/font/bit" "$_ps/lib/font/" || err "payload: the lib/font/bit copy failed"

	# P2. the copy check: the staged tree carries exactly the source
	#     tree's file count (the committed floors below are the
	#     reviewable lower bound; this equality is what makes a
	#     partial copy impossible even after the tree grows past them)
	_scount=$(find "$HARVEY/lib/font/bit" -type f | wc -l | tr -d ' ')
	_fcount=$(find "$_ps/lib/font/bit" -type f | wc -l | tr -d ' ')
	[ "$_fcount" -eq "$_scount" ] || err "payload: staged lib/font/bit carries $_fcount files, the source tree $_scount (a partial copy)"

	# P2b. /lib/ndb/local from the committed token template (D-16):
	#      the netaddr seam is SOURCED (rc-syntax key=value lines are
	#      sh-compatible; a seam file that grows an rc-ism fails the
	#      bake loudly right here) and the template's tokens are
	#      substituted from its slirp-leg keys.  The template carries
	#      TOKENS only — zero venue literals, so 10b's seam grep over
	#      root-tree/lib stays clean by construction — and the
	#      substituted output is asserted BOTH ways (T-15-20): the
	#      seam's values present, zero leftover tokens.
	_ndbt="$ROOT_TREE/lib/ndb/local.template"
	[ -s "$_ndbt" ] || err "$_ndbt missing — the committed ndb token template (15-08, D-16)"
	. "$ROOT_TREE/lib/netaddr.rc"
	[ -n "${slirp_guestv4:-}" ] && [ -n "${slirp_maskv4:-}" ] && [ -n "${slirp_gwv4:-}" ] \
		|| err "netaddr.rc lacks a slirp_guestv4/slirp_maskv4/slirp_gwv4 seam key (the ndb substitution source)"
	mkdir -p "$_ps/lib/ndb"
	sed -e "s/@GUESTV4@/$slirp_guestv4/g" -e "s/@MASKV4@/$slirp_maskv4/g" \
		-e "s/@GWV4@/$slirp_gwv4/g" "$_ndbt" > "$_ps/lib/ndb/local"
	if "$GREP" -q '@' "$_ps/lib/ndb/local"; then
		err "payload: /lib/ndb/local carries an unsubstituted token (the template names a token the seam substitution does not know)"
	fi
	for _v in "$slirp_guestv4" "$slirp_maskv4" "$slirp_gwv4"; do
		"$GREP" -qF "$_v" "$_ps/lib/ndb/local" || err "payload: /lib/ndb/local lacks the seam value $_v (a template token went missing)"
	done
	echo "payload manifest: /lib/ndb/local substituted from lib/ndb/local.template (the netaddr seam's slirp leg) [$_pl]"

	# P3. [paths]: every listed path present + non-empty in the staged
	#     tree (a directory entry is a tree entry — it must carry a
	#     file; anything else must be a non-empty file)
	_pn=0
	for _p in $(payload_block paths); do
		if [ -d "$_ps/$_p" ]; then
			_tn=$(find "$_ps/$_p" -type f | wc -l | tr -d ' ')
			[ "$_tn" -ge 1 ] || err "payload manifest: /$_p missing from staged tree (an empty tree)"
			echo "payload manifest: /$_p staged (tree, $_tn files) [$_pl]"
		elif [ -s "$_ps/$_p" ]; then
			echo "payload manifest: /$_p staged [$_pl]"
		else
			err "payload manifest: /$_p missing from staged tree (or empty)"
		fi
		_pn=$((_pn + 1))
	done
	[ "$_pn" -ge 1 ] || err "payload manifest: the [paths] block is empty — the manifest parse failed"

	# P4. [fonts]: the app-named fonts (the defaults the GUI programs
	#     open by literal path) — each a non-empty staged file, each
	#     PRINTED
	_fn=0
	for _f in $(payload_block fonts); do
		[ -s "$_ps/$_f" ] || err "payload manifest: font /$_f missing from staged tree (or empty)"
		echo "payload manifest: font /$_f staged [$_pl]"
		_fn=$((_fn + 1))
	done
	[ "$_fn" -ge 1 ] || err "payload manifest: the [fonts] block is empty — the manifest parse failed"

	# P5. [floors]: the committed count/size floors over the staged
	#     font tree
	_ffloor=$(payload_block floors | awk '$1 == "font-files" { print $2 }')
	_bfloor=$(payload_block floors | awk '$1 == "font-bytes" { print $2 }')
	echo "$_ffloor" | "$GREP" -qE '^[0-9]+$' || err "payload manifest: the font-files floor is missing or non-numeric"
	echo "$_bfloor" | "$GREP" -qE '^[0-9]+$' || err "payload manifest: the font-bytes floor is missing or non-numeric"
	_fbytes=$(find "$_ps/lib/font/bit" -type f -printf '%s\n' | awk '{ s += $1 } END { printf "%d\n", s }')
	[ "$_fcount" -ge "$_ffloor" ] || err "payload manifest: /lib/font/bit carries $_fcount files, below the $_ffloor floor (D-14: the WHOLE tree ships)"
	[ "$_fbytes" -ge "$_bfloor" ] || err "payload manifest: /lib/font/bit carries $_fbytes bytes, below the $_bfloor floor (D-14: the WHOLE tree ships)"
	echo "payload manifest: /lib/font/bit $_fcount files $_fbytes bytes (floors: $_ffloor files, $_bfloor bytes) [$_pl]"

	# P6. the D-17 profile shape, asserted on the STAGED file: the
	#     terminal case carries NO rio line at all (rio must provably
	#     not start at boot on the serial-console venue — this assert
	#     is the proof), while the cpu case keeps its exec rio and its
	#     latin1.8 font (Phase 19 consumes that case unchanged).  The
	#     ranges anchor at line start so comment prose never opens one.
	_prof="$_ps/usr/glenda/lib/profile"
	"$GREP" -q '^case terminal' "$_prof" && "$GREP" -q '^case cpu' "$_prof" \
		|| err "payload: the staged profile lacks its terminal/cpu cases (D-17: the trimmed cpu-aware profile)"
	if awk '/^case terminal/,/^case cpu/' "$_prof" | "$GREP" -q 'rio'; then
		err "payload: the staged profile's terminal case mentions rio (D-17: rio must NOT start at boot)"
	fi
	awk '/^case cpu/,0' "$_prof" | "$GREP" -q 'exec rio' \
		|| err "payload: the staged profile's cpu case lost its exec rio (Phase 19 consumes it unchanged)"
	awk '/^case cpu/,0' "$_prof" | "$GREP" -qF 'pelm/latin1.8.font' \
		|| err "payload: the staged profile's cpu case lost its latin1.8 font (Phase 19 consumes it unchanged)"
	echo "payload manifest: /usr/glenda/lib/profile shape ok — terminal case rio-free, cpu case intact [$_pl]"
}

# ------------------------------------------------------------------
# 11. the SERVICES bake (15-03, USPACE-07's r9 leg): the chain tree +
#     the services sweep payload — out/bootfs-services.paq.  The
#     services image boots on r9-x86_64 through the composed ISO and
#     runs the committed services sweep (15-02's donor-proven
#     build/x86_64/services-sweep.rc, baked UNCHANGED at
#     /lib/services-sweep.rc) from the boot flow (services-termrc
#     staged as rc/bin/termrc — the tier bake's 9g override shape).
#     Composition (the 15-03 bake contract):
#       - the chain manifest (8's set: boot(8), paqfs, the real init,
#         rc + the core set, rcmain/termrc/namespace/profile skeleton)
#       - the tier-1 h* helper payload (9's computed set — the sweep's
#         $B/h{test,sleep,ls,cat,echo,cmp,...} helper vocabulary,
#         INCLUDING hfactotum from factotum's tier-1 line)
#       - the tier-2 services payload COMPUTED from
#         tiers/tier2-services.txt (never a second hardcoded list):
#         every /amd64/bin artifact each entry governs — a file entry
#         stages itself, a directory entry stages its whole installed
#         member tree, a dir entry whose member mkfile installs flat
#         (subset-build's own BIN-disagreement table: ftpfs/snoopy at
#         the bin root) stages its basename artifact.  Duplicate h*
#         names are a bake error (the mapping must be unambiguous).
#       - the 14-09 net members (the section-10 subset the sweep's
#         vocabulary names: the ip trio + the utility set — `bind'
#         unprefixed is the sweep's own call; the /lib net fixtures
#         ride the committed skeleton tar)
#       - the sweep's /boot-side members (the paq's boot/ rides /boot
#         through the namespace's `bind -a /root /' union — the donor
#         venue's devroot embed equivalents): the byte-exact sentinel
#         (digest-pinned here, same as 9f), rcmain (verbatim, the
#         srv -e child's /rc/lib bootstrap source), and the
#         tcp9901/tcp9902 staged service-name copies (the listener's
#         per-connection programs — echo and authsrv under their
#         service names, the donor's staged-copy trick)
#       - hsvctcpecho + hmkdir: the sweep's compiled one-shot client
#         and the keyfs probe's DMDIR-create client, built HOST-SIDE
#         6c/6l link-only (the donor venue's own staging discipline:
#         relative -I paths from the repo root, 6l -L to the
#         checkout's amd64/lib)
#       - the DESK-03 payload (section P's stage_payload, 11e2): the
#         WHOLE lib/font/bit tree as a bake-time copy + the skeleton's
#         D-17 profile + /lib/ndb/local substituted from the token
#         template, asserted against build/x86_64/bootfs-payload.txt —
#         this image is the payload-declaring contract (the image
#         Phases 18-19 consume)
#       - NO /boot/factotum (auth-stub-by-absence — hfactotum in
#         /amd64/bin is the sweep payload, not the boot auth stub)
SVC_IMAGE="$OUT/bootfs-services.paq"

# 11a. the sweep + override inputs (named loudly, with remediation)
[ -f "$HARVEY/build/x86_64/services-sweep.rc" ] || err "build/x86_64/services-sweep.rc missing (the committed services sweep, 15-02)"
[ -f "$HARVEY/build/x86_64/services-termrc" ] || err "build/x86_64/services-termrc missing (the services image's termrc override)"
# the probe-subject entries verified present in the tier data (the
# donor gate's compute_svc_expected discipline: each subject names the
# tier entry it rides — factotum rides its TIER-1 line, never a
# tier-2 member); a missing entry means the data and the sweep
# diverged — red HERE, never in the guest
SVC_T2="$HARVEY/build/x86_64/tiers/tier2-services.txt"
SVC_T1D="$HARVEY/build/x86_64/tiers/tier1-cmds.txt"
for e in cmd/mntgen cmd/ndb cmd/exportfs cmd/srv cmd/aux:listen cmd/auth/authsrv cmd/auth/keyfs; do
	"$GREP" -q "^$e[[:space:]#]" "$SVC_T2" || err "services bake: tier-2 data lacks the probe-subject entry $e (the sweep and the data diverged)"
done
"$GREP" -q "^cmd/auth/factotum:factotum[[:space:]#]" "$SVC_T1D" || err "services bake: tier-1 data lacks cmd/auth/factotum:factotum (factotum rides its tier-1 line)"

# 11b. the tier-2 h* staging set, COMPUTED from the tier data (the
#      resolver consults the built tree: file entries stage
#      themselves, dir entries stage their whole member tree, flat-
#      installing dir entries stage their basename artifact).  The
#      tier-1 helper set reuses 9b's TIER1_RELS computation verbatim.
SVC_HLIST="$TMPD/svc-hlist"
: > "$SVC_HLIST"
svc_stage() {
	# svc_stage <abs-src> <h-name> — record one h* member; a duplicate
	# h-name from two sources is a bake error (ambiguous mapping)
	_src=$1
	_h=$2
	if "$GREP" -q "^$_h " "$SVC_HLIST"; then
		err "services bake: duplicate h* name $_h (two tier entries map to it — the staging mapping is ambiguous)"
	fi
	echo "$_h $_src" >> "$SVC_HLIST"
}
while read -r line; do
	case "$line" in ''|'#'*) continue ;; esac
	entry="${line%%[	 ]*}"
	case "$entry" in ''|'#'*) continue ;; esac
	case "$entry" in
	cmd/*) ;;
	*) continue ;;
	esac
	case "$entry" in
	*:*)	tgt="${entry##*:}"; rel="${entry%%:*}"; rel="${rel#cmd/}" ;;
	*)	tgt=""; rel="${entry#cmd/}" ;;
	esac
	if [ -n "$tgt" ]; then
		# container leaf (cmd/aux:listen): the tier driver harvests
		# $tgt at the bin root
		[ -f "$BIN/$tgt" ] || err "services bake: $BIN/$tgt missing — run sh build/x86_64/subset-build.sh first (tier-2 $entry)"
		svc_stage "$BIN/$tgt" "h$tgt"
	elif [ -f "$BIN/$rel" ]; then
		svc_stage "$BIN/$rel" "h${rel##*/}"
	elif [ -d "$BIN/$rel" ]; then
		for f in $(find "$BIN/$rel" -type f | sort); do
			svc_stage "$f" "h${f##*/}"
		done
	else
		# the member mkfile's BIN disagreement (subset-build's own
		# table): ftpfs/snoopy install at the bin ROOT
		base="${rel##*/}"
		[ -f "$BIN/$base" ] || err "services bake: tier-2 entry $entry has no artifact at $BIN/$rel or $BIN/$base — run sh build/x86_64/subset-build.sh first"
		svc_stage "$BIN/$base" "h$base"
	fi
done < "$SVC_T2"
_nsvc=$(wc -l < "$SVC_HLIST" | tr -d ' ')
[ "$_nsvc" -ge 1 ] || err "the tier-2 h* staging set is empty — the tier data parse failed"
# every probe subject must be in the computed set (the sweep's probe
# record consumes exactly these)
for h in hmntgen hcs hcsquery hdns hdnsquery hexportfs hsrv hlisten hkeyfs hauthsrv; do
	"$GREP" -q "^$h " "$SVC_HLIST" || err "services bake: probe subject $h missing from the computed tier-2 set (the resolver lost it)"
done

# 11c. the net members + the utility set (the section-10 subset: the
#      ip trio + the utility set — bind unprefixed is the sweep's own
#      vocabulary)
for p in ip/ipconfig ip/ping ip/udpecho; do
	[ -s "$BIN/$p" ] || err "$BIN/$p missing — run sh build/x86_64/subset-build.sh first (the 14-09 net section)"
done
for f in grep sed dd wc sha1sum test bind; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first (the utility set)"
done
[ -s "$HARVEY/amd64/init" ] || err "amd64/init missing — run sh build/x86_64/subset-build.sh first (stage/init)"
[ -s "$CHAIN_OUT/boot" ] || err "$CHAIN_OUT/boot missing — run sh build/x86_64/subset-build.sh first (9k/boot)"

# 11d. the host toolchain for the two host-side builds (the donor
#      venue's own staging discipline; subset-build bootstraps it, a
#      standalone bake names the remediation)
SVC_NS_HBIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-x86_64/bin}"
[ -x "$SVC_NS_HBIN/6c" ] && [ -x "$SVC_NS_HBIN/6l" ] \
	|| err "$SVC_NS_HBIN/{6c,6l} missing — run 'nix run .#setup && nix run .#toolchain' first (the hsvctcpecho/hmkdir host-side builds)"

STAGE5="$TMPD/root-svc"
mkdir -p "$STAGE5"

# 11e. the committed skeleton (the chain bake's shape — the /lib net
#      fixtures ride the skeleton tar)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE5" && tar -xf -)

# 11e2. the DESK-03 payload declaration (15-08): the services image
#       carries the desktop payload — the whole font tree copied at
#       bake time + /lib/ndb/local substituted from the token template
#       + the manifest and profile-shape asserts over the staged tree
#       (section P; the profile rode the skeleton tar above)
stage_payload "$STAGE5" services

# 11f. empty mount-point dirs + staging parents (the chain set + the
#      ip container's home + the /boot service-program home)
mkdir -p "$STAGE5/root" "$STAGE5/env" "$STAGE5/proc" "$STAGE5/dev" "$STAGE5/srv" \
	"$STAGE5/fd" "$STAGE5/bin" "$STAGE5/tmp" "$STAGE5/mnt" \
	"$STAGE5/net" "$STAGE5/boot" "$STAGE5/amd64/bin/ip" \
	"$STAGE5/rc/lib" "$STAGE5/rc/bin" "$STAGE5/adm/timezone"

# 11g. the chain binaries from THIS build's products (the tier bake's
#      9e discipline: BIN + /amd64/init + out/boot, never a stale out/
#      harvest for members that have a /amd64/bin home)
cp "$CHAIN_OUT/boot" "$STAGE5/boot/boot"
cp "$BIN/paqfs" "$STAGE5/boot/paqfs"
cp "$HARVEY/amd64/init" "$STAGE5/amd64/init"
for f in rc ls cat echo ps; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first"
	cp "$BIN/$f" "$STAGE5/amd64/bin/$f"
done

# 11h. the tier-1 h* helper payload (9f's discipline over 9b's
#      computed set — the sweep's helper vocabulary; hfactotum rides
#      here from factotum's tier-1 line)
for rel in $TIER1_RELS; do
	[ -f "$BIN/$rel" ] || err "$BIN/$rel missing — run sh build/x86_64/subset-build.sh first (the tier-1 helper payload)"
	cp "$BIN/$rel" "$STAGE5/amd64/bin/h${rel##*/}"
done

# 11i. the tier-2 services payload (the computed 11b set)
while read -r _h _src; do
	cp "$_src" "$STAGE5/amd64/bin/$_h"
done < "$SVC_HLIST"

# 11j. the net members + the utility set
for f in ipconfig ping udpecho; do
	cp "$BIN/ip/$f" "$STAGE5/amd64/bin/ip/$f"
done
for f in grep sed dd wc sha1sum test bind; do
	cp "$BIN/$f" "$STAGE5/amd64/bin/$f"
done

# 11k. the two host-side builds: hsvctcpecho (the sweep's one-shot
#      loopback tcp client) + hmkdir (the keyfs probe's DMDIR-create
#      client; mkdir is not a tier member on x64 — the write-flow
#      class) — 6c with relative -I paths from the repo root, 6l -L to
#      the checkout's amd64/lib (the donor venue's nm-input.6
#      discipline)
(	cd "$HARVEY" && \
	"$SVC_NS_HBIN/6c" -FTVw -o "$STAGE5/.svctcpecho.6" -Isys/include -Iamd64/include build/x86_64/svctcpecho.c && \
	"$SVC_NS_HBIN/6l" -o "$STAGE5/amd64/bin/hsvctcpecho" -L "$HARVEY/amd64/lib" "$STAGE5/.svctcpecho.6" && \
	rm -f "$STAGE5/.svctcpecho.6"
) || err "hsvctcpecho host-side build failed"
magic=$(od -An -tx1 -N4 "$STAGE5/amd64/bin/hsvctcpecho" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "hsvctcpecho: bad magic $magic (want 00008a97)"
(	cd "$HARVEY" && \
	"$SVC_NS_HBIN/6c" -FTVw -o "$STAGE5/.mkdir.6" -Isys/include -Iamd64/include sys/src/cmd/mkdir.c && \
	"$SVC_NS_HBIN/6l" -o "$STAGE5/amd64/bin/hmkdir" -L "$HARVEY/amd64/lib" "$STAGE5/.mkdir.6" && \
	rm -f "$STAGE5/.mkdir.6"
) || err "hmkdir host-side build failed"
magic=$(od -An -tx1 -N4 "$STAGE5/amd64/bin/hmkdir" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "hmkdir: bad magic $magic (want 00008a97)"

# 11l. the sweep at /lib + the termrc OVERRIDE (the tier bake's 9g
#      rule: the services image runs the sweep from the boot flow, no
#      typed interaction)
cp "$HARVEY/build/x86_64/services-sweep.rc" "$STAGE5/lib/services-sweep.rc"
cp "$HARVEY/build/x86_64/services-termrc" "$STAGE5/rc/bin/termrc"

# 11m. the /boot-side members (the donor venue's devroot-embed
#      equivalents, riding the paq's boot/ through the namespace's
#      /root union): rcmain verbatim, the digest-pinned sentinel, and
#      the tcpNNNN staged service-name copies (listen execes
#      servdir/<proto><port> per connection)
cp "$HARVEY/rc/lib/rcmain" "$STAGE5/boot/rcmain"
printf 'alpha bravo charlie\n__SUBSET_GREP_LINE__\n' > "$STAGE5/boot/sentinel.txt"
_md5=$(md5sum "$STAGE5/boot/sentinel.txt" | cut -d' ' -f1)
_sha1=$(sha1sum "$STAGE5/boot/sentinel.txt" | cut -d' ' -f1)
[ "$_md5" = "6c3d57e94871f9606c5b63c315e76135" ] || err "sentinel md5 drift: $_md5 (want 6c3d57e94871f9606c5b63c315e76135) — the sweep's pinned assert would red in the guest"
[ "$_sha1" = "893404a2c36b54f5c7874070d1acefe38f7ce652" ] || err "sentinel sha1 drift: $_sha1 (want 893404a2c36b54f5c7874070d1acefe38f7ce652)"
cp "$BIN/echo" "$STAGE5/boot/tcp9901"
cp "$BIN/auth/authsrv" "$STAGE5/boot/tcp9902"

# 11n. bake-time verbatim copies (the chain bake's rule)
cp "$HARVEY/rc/lib/rcmain" "$STAGE5/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE5/adm/timezone/local"

# 11o. pre-bake manifest: the chain paths + the payload + the
#      /boot-side members, PRINTED as the staging manifest (the bake
#      log is the gate's evidence — the plan's verify greps these
#      lines)
for p in boot/boot boot/paqfs boot/rcmain boot/sentinel.txt \
	boot/tcp9901 boot/tcp9902 amd64/init amd64/bin/rc \
	amd64/bin/ls amd64/bin/cat amd64/bin/echo amd64/bin/ps \
	amd64/bin/ip/ipconfig amd64/bin/ip/ping amd64/bin/ip/udpecho \
	amd64/bin/grep amd64/bin/sed amd64/bin/dd amd64/bin/wc \
	amd64/bin/sha1sum amd64/bin/test amd64/bin/bind \
	amd64/bin/hsvctcpecho amd64/bin/hmkdir \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile lib/netaddr.rc lib/netip-loopback.rc \
	lib/netip-static.rc lib/netip-dhcp.rc lib/netip-tcp.rc \
	lib/services-sweep.rc; do
	[ -f "$STAGE5/$p" ] || err "services manifest: $p missing from staged tree"
	echo "services manifest: /$p staged"
done
_nh=0
while read -r _h _src; do
	[ -f "$STAGE5/amd64/bin/$_h" ] || err "services manifest: amd64/bin/$_h missing from staged tree"
	_nh=$((_nh + 1))
done < "$SVC_HLIST"
for rel in $TIER1_RELS; do
	[ -f "$STAGE5/amd64/bin/h${rel##*/}" ] || err "services manifest: amd64/bin/h${rel##*/} missing from staged tree"
	_nh=$((_nh + 1))
done
echo "services manifest: ${_nh} h* sweep binaries staged (tier-1 helpers + the tier-2 set computed from tiers/tier2-services.txt: $_nsvc tier-2 members)"
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE5/$p" ] || err "services manifest: mount-point dir /$p missing"
done

# 11p. /boot/factotum ABSENCE (auth-stub-by-absence — the same D-02
#      rule as every bake above; boot/rcmain is the rcmain copy, NOT
#      an auth stub)
[ ! -e "$STAGE5/boot/factotum" ] || err "services manifest: /boot/factotum present — auth-stub-by-absence violated"

# 11q. rcmain ships byte-verbatim BOTH copies (the chain bake's cmp
#      guard)
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE5/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain"
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE5/boot/rcmain" || err "staged /boot/rcmain diverges from rc/lib/rcmain"

# 11r. determinism + bake (the chain bake's rule), preceded by the
#      mkpaqfs per-file cap assert (the 15-07 measured hazard: mkpaqfs
#      silently DROPS any file past blocksize^2/4 — 4194304 bytes at
#      the 4096 default — warning but exiting 0): every staged file
#      must fit the default blocksize, so a silent drop cannot happen
#      (grow to a -b blocksize HERE, in the same commit as the member
#      that needs it, never by trusting the warn)
_maxf=$(find "$STAGE5" -type f -printf '%s\n' | sort -n | tail -1)
[ "$_maxf" -le 4194304 ] || err "services bake: a staged file of $_maxf bytes exceeds mkpaqfs's 4194304-byte per-file cap (blocksize^2/4 at the 4096 default) — it would be silently DROPPED from the image"
find "$STAGE5" -exec touch -h -d "@$KERNDATE" {} +
rm -f "$SVC_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$SVC_IMAGE" "$STAGE5" || err "mkpaqfs failed (services)"
[ -s "$SVC_IMAGE" ] || err "$SVC_IMAGE missing/empty after mkpaqfs"

# 11s. the byte-format contract (same header/trailer magic checks)
magic5=$(od -An -tx1 -N4 "$SVC_IMAGE" | tr -d ' \n')
[ "$magic5" = "529ab12b" ] || err "$SVC_IMAGE: bad header magic $magic5 (want 529ab12b)"
sz5=$(wc -c < "$SVC_IMAGE" | tr -d ' ')
trailer5=$(od -An -tx1 -j $((sz5 - 28)) -N 4 "$SVC_IMAGE" | tr -d ' \n')
[ "$trailer5" = "6b46e688" ] || err "$SVC_IMAGE: bad trailer magic $trailer5 (want 6b46e688)"

echo "== PASS: baked $SVC_IMAGE ($sz5 bytes; ${_nh} h* binaries; header $magic5 trailer $trailer5; KERNDATE $KERNDATE)"
