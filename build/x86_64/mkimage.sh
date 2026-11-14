#!/bin/sh
# build/x86_64/mkimage.sh — bake build/x86_64/out/bootfs.paq (the 14-05
# MARKER image), build/x86_64/out/bootfs-chain.paq (the 14-06 BOOT-CHAIN
# image), build/x86_64/out/bootfs-tier.paq (the 14-08 TIER image — the
# chain tree + the tier-1 sweep payload), and, since 14-09,
# build/x86_64/out/bootfs-net.paq (the NET image — the chain tree + the
# net-gate payload: the ip-container binaries + the 6c C helpers + the
# /lib fixtures), and, since 15-03,
# build/x86_64/out/bootfs-services.paq (the SERVICES image — the chain
# tree + the tier-2 services sweep payload for the r9-x64 venue), and,
# since 18-01, build/x86_64/out/bootfs-substrate.paq (the SUBSTRATE
# image — the marker-image shape with randread as /amd64/init, the
# q35auth random substrate gate's own leg-1 marker), the
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
# 18-04 (AUTH-05, 15-D-16 carried): the NIC MAC class joins the seam
# grep — the qemu-default 52:54:00:* prefix may live ONLY in
# netaddr.rc's ether key (local.template's ether=@ETHER@ token is
# token-pure; a copied literal anywhere else in the fixtures reds the
# bake)
_stray=$("$GREP" -rn '52:54:00' "$ROOT_TREE/lib/" 2>/dev/null | "$GREP" -v 'netaddr\.rc' || true)
[ -z "$_stray" ] || err "NIC MAC literal outside netaddr.rc (the D-11 seam violated — the 18-04 ether key is the single home): $_stray"

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
	#      18-04 (AUTH-05) made the template two-consumer: it now also
	#      carries the auth composition row (ipnet=... authdom=
	#      @AUTHDOM@ auth=127.0.0.1) + the host tuple's ether=@ETHER@.
	#      THIS path (the services image) has NO auth domain — an
	#      authdom row without keys behind it would be a lie — so the
	#      auth row is STRIPPED (the only literal-keyed line: the row
	#      is identified by its unsubstituted @AUTHDOM@ token BEFORE
	#      substitution, never by renumbering) and the ether token
	#      substitutes from the seam's new ether key like every other
	#      venue constant.  The strip is asserted BOTH ways: zero
	#      authdom= in the output, zero leftover tokens.
	_ndbt="$ROOT_TREE/lib/ndb/local.template"
	[ -s "$_ndbt" ] || err "$_ndbt missing — the committed ndb token template (15-08, D-16)"
	. "$ROOT_TREE/lib/netaddr.rc"
	[ -n "${slirp_guestv4:-}" ] && [ -n "${slirp_maskv4:-}" ] && [ -n "${slirp_gwv4:-}" ] \
		|| err "netaddr.rc lacks a slirp_guestv4/slirp_maskv4/slirp_gwv4 seam key (the ndb substitution source)"
	[ -n "${ether:-}" ] || err "netaddr.rc lacks an ether seam key (the 18-04 NIC MAC's single home — the @ETHER@ substitution source)"
	mkdir -p "$_ps/lib/ndb"
	sed -e "/authdom=@AUTHDOM@/d" \
		-e "s/@GUESTV4@/$slirp_guestv4/g" -e "s/@MASKV4@/$slirp_maskv4/g" \
		-e "s/@GWV4@/$slirp_gwv4/g" -e "s/@ETHER@/$ether/g" "$_ndbt" > "$_ps/lib/ndb/local"
	if "$GREP" -q '@' "$_ps/lib/ndb/local"; then
		err "payload: /lib/ndb/local carries an unsubstituted token (the template names a token the seam substitution does not know)"
	fi
	for _v in "$slirp_guestv4" "$slirp_maskv4" "$slirp_gwv4" "$ether"; do
		"$GREP" -qF "$_v" "$_ps/lib/ndb/local" || err "payload: /lib/ndb/local lacks the seam value $_v (a template token went missing)"
	done
	if "$GREP" -v '^#' "$_ps/lib/ndb/local" | "$GREP" -q 'authdom='; then
		err "payload: /lib/ndb/local carries an authdom= data row (the services image has no auth domain — the 18-04 auth-row strip failed; comment prose mentioning authdom= is fine)"
	fi
	echo "payload manifest: /lib/ndb/local substituted from lib/ndb/local.template (the netaddr seam's slirp leg + ether; the 18-04 auth row stripped — no domain in this image) [$_pl]"

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

# ------------------------------------------------------------------
# 12. the CHURN bake (17-02, FLUSH-02's D-06 tier (b)): the chain
#     tree (8's manifest — boot(8)→init→rc boots the venue to the
#     interactive prompt) PLUS test + dc (the 14-09 net bake's utility
#     supply: the rc fixture's counter idiom needs dc backquote and
#     test is not a builtin) — /lib/churn-cats.rc rides the committed
#     skeleton (the netip-*.rc precedent: root-tree/lib is the shared
#     fixture home).  The composed churn gate (boot-r9-churn-x64)
#     types `rc /lib/churn-cats.rc' at the % prompt and bounds the
#     /bin/cat x 1400 fork+exec churn window's per-exit heap-marker
#     delta — the #44 real-load tier.  Existing sections untouched
#     (Pitfall 7); this one is purely additive.
CHURN_IMAGE="$OUT/bootfs-churn.paq"

# 12a. inputs (the chain set from 8's checks still holds; the churn
#      additions named loudly).  churncats: the C churn driver staged
#      from smoke-out (the rc-fixture variant measured rc's own
#      userland pool corrupting past ~428 iterations — the C driver
#      keeps the load on the kernel's exec path; churn-cats.rc stays
#      staged as the cat input + the recorded rc-fixture shape).
for f in test dc; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first (the churn fixture's counter idiom)"
done
[ -s "$STAGE_SRC/churncats" ] || err "$STAGE_SRC/churncats missing — run sh build/x86_64/stage-build.sh first (the C churn driver)"
"$GREP" -q "churn: CATS-DONE" "$STAGE_SRC/churncats" \
	|| err "smoke-out/churncats does not carry its marker string (re-run sh build/x86_64/stage-build.sh)"
[ -f "$ROOT_TREE/lib/churn-cats.rc" ] || err "$ROOT_TREE/lib/churn-cats.rc missing (the committed churn fixture / cat input)"

STAGE6="$TMPD/root-churn"
mkdir -p "$STAGE6"

# 12b. the committed skeleton (the fixture rides it) + the chain
#      staging shape (9c/9d's construction: skeleton, mount-point
#      dirs, the chain binaries from THIS build's products)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE6" && tar -xf -)
mkdir -p "$STAGE6/root" "$STAGE6/env" "$STAGE6/proc" "$STAGE6/dev" "$STAGE6/srv" \
	"$STAGE6/fd" "$STAGE6/bin" "$STAGE6/tmp" "$STAGE6/mnt" \
	"$STAGE6/net" "$STAGE6/boot" "$STAGE6/amd64/bin" \
	"$STAGE6/rc/lib" "$STAGE6/rc/bin" "$STAGE6/adm/timezone"
cp "$CHAIN_OUT/boot" "$STAGE6/boot/boot"
cp "$BIN/paqfs" "$STAGE6/boot/paqfs"
cp "$STAGE_SRC/churncats" "$STAGE6/amd64/bin/churncats"
cp "$HARVEY/amd64/init" "$STAGE6/amd64/init"
for f in rc ls cat echo ps test dc; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first (the churn bake)"
	cp "$BIN/$f" "$STAGE6/amd64/bin/$f"
done
cp "$HARVEY/rc/lib/rcmain" "$STAGE6/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE6/adm/timezone/local"

# 12c. pre-bake manifest: the chain set + the churn additions + the
#      fixture (the staging manifest, printed as evidence)
for p in boot/boot boot/paqfs amd64/init amd64/bin/rc \
	amd64/bin/ls amd64/bin/cat amd64/bin/echo amd64/bin/ps \
	amd64/bin/test amd64/bin/dc amd64/bin/churncats \
	rc/lib/rcmain lib/churn-cats.rc adm/timezone/local \
	lib/namespace usr/glenda/lib/profile; do
	[ -f "$STAGE6/$p" ] || err "churn manifest: $p missing from staged tree"
done
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE6/$p" ] || err "churn manifest: mount-point dir /$p missing"
done
[ ! -e "$STAGE6/boot/factotum" ] || err "churn manifest: /boot/factotum present — auth-stub-by-absence violated"
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE6/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain (churn)"

# 12d. determinism + bake (the chain bake's rule; the per-file cap
#      assert rides too — the 15-07 measured hazard)
_maxf6=$(find "$STAGE6" -type f -printf '%s\n' | sort -n | tail -1)
[ "$_maxf6" -le 4194304 ] || err "churn bake: a staged file of $_maxf6 bytes exceeds mkpaqfs's 4194304-byte per-file cap"
find "$STAGE6" -exec touch -h -d "@$KERNDATE" {} +
rm -f "$CHURN_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$CHURN_IMAGE" "$STAGE6" || err "mkpaqfs failed (churn)"
[ -s "$CHURN_IMAGE" ] || err "$CHURN_IMAGE missing/empty after mkpaqfs"

# 12e. the byte-format contract (same header/trailer magic checks)
magic6=$(od -An -tx1 -N4 "$CHURN_IMAGE" | tr -d ' \n')
[ "$magic6" = "529ab12b" ] || err "$CHURN_IMAGE: bad header magic $magic6 (want 529ab12b)"
sz6=$(wc -c < "$CHURN_IMAGE" | tr -d ' ')
trailer6=$(od -An -tx1 -j $((sz6 - 28)) -N 4 "$CHURN_IMAGE" | tr -d ' \n')
[ "$trailer6" = "6b46e688" ] || err "$CHURN_IMAGE: bad trailer magic $trailer6 (want 6b46e688)"

echo "== PASS: baked $CHURN_IMAGE ($sz6 bytes; chain + test/dc + churncats + /lib/churn-cats.rc; header $magic6 trailer $trailer6; KERNDATE $KERNDATE)"

# ------------------------------------------------------------------
# 13. the SUBSTRATE bake (18-01, AUTH-02/D-05+D-07): the MARKER-image
#     shape (§1-6's construction verbatim — committed skeleton minus
#     the chain-only /rc+/usr subtrees, empty mount points, ONE
#     marker at /amd64/init, factotum-absence, KERNDATE determinism)
#     with randread as THIS image's /amd64/init — the D-08 leg-1 rule
#     applied per-image: the q35exec image's marker stays smokesleep
#     (untouched, §3-4a above), the substrate image's marker is the
#     entropy-read driver.  The r9 q35auth profile boots this paq; the
#     first ring-3 exec reads /dev/random twice and prints the D-07
#     distinctness evidence (`random: READS-OK`, `substrate: DONE`)
#     the xtask gate asserts beside the boot-facts armed-source line.
#     Purely additive (Pitfall 7): every earlier contract untouched.
SUBSTRATE_IMAGE="$OUT/bootfs-substrate.paq"

# 13a. input (stage-build.sh is the producer — named loudly when
#      absent) + the identity guards BEFORE any staging spend.
[ -s "$STAGE_SRC/randread" ] || err "$STAGE_SRC/randread missing — run sh build/x86_64/stage-build.sh first (the substrate marker)"
"$GREP" -q "random: READS-OK" "$STAGE_SRC/randread" \
	|| err "smoke-out/randread does not carry its marker string (re-run sh build/x86_64/stage-build.sh)"
"$GREP" -q "substrate: DONE" "$STAGE_SRC/randread" \
	|| err "smoke-out/randread does not carry its terminal marker (re-run sh build/x86_64/stage-build.sh)"
# 18-02: the devcap legs' markers (the #¤ fixture pair) — the binary
#      must carry all four or the gate's presence asserts redden.
for _capmark in "cap: POST-OK" "cap: USE-OK" "cap: ONESHOT-REJECT" "cap: HOSTOWNER-GATE"; do
	"$GREP" -q "$_capmark" "$STAGE_SRC/randread" \
		|| err "smoke-out/randread lacks the devcap marker '$_capmark' (re-run sh build/x86_64/stage-build.sh)"
done
"$GREP" -q "init: starting /bin/rc" "$STAGE_SRC/randread" \
	&& err "smoke-out/randread carries the REAL init's signature (stage-build staged the wrong binary)"

STAGE7="$TMPD/root-substrate"
mkdir -p "$STAGE7"

# 13b. the committed skeleton, the chain-only subtrees stripped (the
#      marker tree's own §1 shape) + the empty mount-point dirs
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE7" && tar -xf -)
rm -rf "$STAGE7/rc" "$STAGE7/usr"
mkdir -p "$STAGE7/root" "$STAGE7/env" "$STAGE7/proc" "$STAGE7/dev" "$STAGE7/srv" \
	"$STAGE7/fd" "$STAGE7/bin" "$STAGE7/tmp" "$STAGE7/mnt" \
	"$STAGE7/net" "$STAGE7/amd64"

# 13c. the marker (the image's whole payload: randread IS /amd64/init)
cp "$STAGE_SRC/randread" "$STAGE7/amd64/init"

# 13d. pre-bake manifest + the leg-1 identity + factotum absence (the
#      marker-image contract's own guard classes)
for p in amd64/init; do
	[ -f "$STAGE7/$p" ] || err "substrate manifest: $p missing from staged tree"
done
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE7/$p" ] || err "substrate manifest: mount-point dir /$p missing"
done
"$GREP" -q "random: READS-OK" "$STAGE7/amd64/init" \
	|| err "substrate: amd64/init is not the randread marker (re-run sh build/x86_64/stage-build.sh)"
"$GREP" -q "cap: POST-OK" "$STAGE7/amd64/init" \
	|| err "substrate: amd64/init carries the entropy marker but not the devcap legs (re-run sh build/x86_64/stage-build.sh)"
[ ! -e "$STAGE7/boot/factotum" ] || err "substrate manifest: /boot/factotum present — auth-stub-by-absence violated"

# 13e. determinism + bake (the marker bake's rule; the per-file cap
#      assert rides too — the 15-07 measured hazard)
_maxf7=$(find "$STAGE7" -type f -printf '%s\n' | sort -n | tail -1)
[ "$_maxf7" -le 4194304 ] || err "substrate bake: a staged file of $_maxf7 bytes exceeds mkpaqfs's 4194304-byte per-file cap"
find "$STAGE7" -exec touch -h -d "@$KERNDATE" {} +
rm -f "$SUBSTRATE_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$SUBSTRATE_IMAGE" "$STAGE7" || err "mkpaqfs failed (substrate)"
[ -s "$SUBSTRATE_IMAGE" ] || err "$SUBSTRATE_IMAGE missing/empty after mkpaqfs"

# 13f. the byte-format contract (same header/trailer magic checks)
magic7=$(od -An -tx1 -N4 "$SUBSTRATE_IMAGE" | tr -d ' \n')
[ "$magic7" = "529ab12b" ] || err "$SUBSTRATE_IMAGE: bad header magic $magic7 (want 529ab12b)"
sz7=$(wc -c < "$SUBSTRATE_IMAGE" | tr -d ' ')
trailer7=$(od -An -tx1 -j $((sz7 - 28)) -N 4 "$SUBSTRATE_IMAGE" | tr -d ' \n')
[ "$trailer7" = "6b46e688" ] || err "$SUBSTRATE_IMAGE: bad trailer magic $trailer7 (want 6b46e688)"

echo "== PASS: baked $SUBSTRATE_IMAGE ($sz7 bytes; skeleton + randread as /amd64/init; header $magic7 trailer $trailer7; KERNDATE $KERNDATE)"

# ------------------------------------------------------------------
# 14. the AUTH bake (18-04, AUTH-04/D-08 — the SIXTH contract, the
#     section the wave-1 numbering note pinned: 18-01's substrate took
#     §13, so this auth contract is §14; the plan's own "§13" refs
#     predate that landing): the chain tree + the auth-suite payload
#     computed from the tier data + the bake-time p9sk1 domain from
#     authdomain-gen (18-03) — out/bootfs-auth.paq.  The auth image
#     boots the chain to the auth bring-up sweep (auth-sweep.rc baked
#     at /lib/auth-sweep.rc, auth-termrc staged as rc/bin/termrc — the
#     services contract's 11l override shape): the D-02 BOOT pairing
#     check over the staged /adm/{nvram,keys,domain.manifest} +
#     /lib/ndb/auth, then NON-interactive keyfs (the nvram= env path,
#     D-03), then (18-04 Tasks 2-3) the listener topology + cs +
#     factotum.  The services image's sweep semantics are untouched
#     (D-08); one-image-per-gate intact — purely additive (Pitfall 7).
#
#     The domain material (D-01/D-02): authdomain-gen is INVOKED AT
#     BAKE (host cc over the vendored donor files — the 18-03 venue,
#     the committed self-test's build line); absent /authdomain.local
#     (the repo-root default, gitignored) => ephemeral DEMO material,
#     so a clean checkout bakes green on presence-based gates.  The
#     pairing is asserted over the STAGED COPIES (manifest digests
#     re-verified — the bake REFUSES on mismatch) and re-verified in
#     the guest before keyfs (the sweep's leg 1).  The auth image is
#     NOT byte-reproducible across bakes by design (D-01); KERNDATE
#     pins the deterministic layer while per-bake content varies —
#     both true at once (Pitfall 10).
AUTH_IMAGE="$OUT/bootfs-auth.paq"

# 14a. the sweep + override inputs + the auth-suite tier entries (the
#      11a probe-subject assert discipline: every staged member names
#      the tier entry it rides — a missing entry means the data and
#      the bake diverged, red HERE never in the guest; artifacts are
#      then computed through the entry->artifact mapping, never a
#      hardcoded binary list)
[ -f "$HARVEY/build/x86_64/auth-sweep.rc" ] || err "build/x86_64/auth-sweep.rc missing (the committed auth bring-up sweep, 18-04)"
[ -f "$HARVEY/build/x86_64/auth-termrc" ] || err "build/x86_64/auth-termrc missing (the auth image's termrc override)"
AUTH_T2="$HARVEY/build/x86_64/tiers/tier2-services.txt"
AUTH_T1D="$HARVEY/build/x86_64/tiers/tier1-cmds.txt"
for e in cmd/mntgen cmd/ndb cmd/exportfs cmd/srv cmd/aux:listen1 \
	cmd/auth/as cmd/auth/authsrv cmd/auth/changeuser cmd/auth/debug \
	cmd/auth/keyfs cmd/auth/secstore; do
	"$GREP" -qE "^$e([[:space:]]|#|$)" "$AUTH_T2" \
		|| err "auth bake: tier-2 data lacks the auth-suite entry $e (the bake's staging set and the tier data diverged)"
done
for e in cmd/cat cmd/echo cmd/ls cmd/test cmd/sleep cmd/sha1sum cmd/auth/factotum:factotum; do
	"$GREP" -qE "^$e([[:space:]]|#|$)" "$AUTH_T1D" \
		|| err "auth bake: tier-1 data lacks the helper entry $e (the sweep's helper vocabulary)"
done

# 14b. the auth-suite staging set, COMPUTED from the tier data (11b's
#      resolver verbatim: file entries stage themselves, dir entries
#      stage their whole installed member tree, container-leaf
#      entries stage the driver-harvested bin-root target; duplicate
#      h* names are a bake error — the mapping must be unambiguous)
AUTH_HLIST="$TMPD/auth-hlist"
: > "$AUTH_HLIST"
auth_stage() {
	# auth_stage <abs-src> <h-name> — record one h* member
	_src=$1
	_h=$2
	if "$GREP" -q "^$_h " "$AUTH_HLIST"; then
		err "auth bake: duplicate h* name $_h (two tier entries map to it — the staging mapping is ambiguous)"
	fi
	echo "$_h $_src" >> "$AUTH_HLIST"
}
for entry in cmd/mntgen cmd/ndb cmd/exportfs cmd/srv cmd/aux:listen1 \
	cmd/auth/as cmd/auth/authsrv cmd/auth/changeuser cmd/auth/debug \
	cmd/auth/keyfs cmd/auth/secstore; do
	case "$entry" in
	*:*)	tgt="${entry##*:}"; rel="${entry%%:*}"; rel="${rel#cmd/}" ;;
	*)	tgt=""; rel="${entry#cmd/}" ;;
	esac
	if [ -n "$tgt" ]; then
		# container leaf (cmd/aux:listen1 — 18-04 Task 2): the tier
		# driver harvests $tgt at the bin root
		[ -f "$BIN/$tgt" ] || err "auth bake: $BIN/$tgt missing — run sh build/x86_64/subset-build.sh first (tier-2 $entry)"
		auth_stage "$BIN/$tgt" "h$tgt"
	elif [ -d "$BIN/$rel" ]; then
		for f in $(find "$BIN/$rel" -type f | sort); do
			auth_stage "$f" "h${f##*/}"
		done
	elif [ -f "$BIN/$rel" ]; then
		# a dir entry whose mkfile installs SEVERAL members FLAT
		# beside the entry's own name (cmd/auth/secstore: `TARG =
		# secstore secstored secuser aescbc' -> /amd64/bin/auth/*) —
		# the member set is the mkfile's own multi-word TARG line
		# (the authority on what the entry builds; a SINGLE-word
		# TARG is just a file entry — cmd/exportfs installs alone at
		# the bin root — and stages the found file, the 11b rule)
		_mkf="$HARVEY/sys/src/$entry/mkfile"
		_targw=""
		if [ -f "$_mkf" ]; then
			_targw=$(awk '/^TARG[[:space:]]*=/ { sub(/#.*/, ""); sub(/^[^=]*=/, ""); for (i = 1; i <= NF; i++) print $i }' "$_mkf" | wc -l | tr -d ' ')
		fi
		if [ "${_targw:-0}" -gt 1 ]; then
			_parent="${rel%/*}"
			for m in $(awk '/^TARG[[:space:]]*=/ { sub(/#.*/, ""); sub(/^[^=]*=/, ""); for (i = 1; i <= NF; i++) print $i }' "$_mkf"); do
				[ -f "$BIN/$_parent/$m" ] || err "auth bake: $BIN/$_parent/$m missing — run sh build/x86_64/subset-build.sh first (tier-2 $entry's mkfile TARG member)"
				auth_stage "$BIN/$_parent/$m" "h$m"
			done
		else
			auth_stage "$BIN/$rel" "h${rel##*/}"
		fi
	else
		# the member mkfile's BIN disagreement (subset-build's own
		# table): some dirs install at the bin ROOT
		base="${rel##*/}"
		[ -f "$BIN/$base" ] || err "auth bake: tier-2 entry $entry has no artifact at $BIN/$rel or $BIN/$base — run sh build/x86_64/subset-build.sh first"
		auth_stage "$BIN/$base" "h$base"
	fi
done
_nauth=$(wc -l < "$AUTH_HLIST" | tr -d ' ')
[ "$_nauth" -ge 1 ] || err "the auth-suite h* staging set is empty — the tier data parse failed"
# every sweep subject must be in the computed set (hfactotum rides the
# tier-1 helper leg at 14c/14i, not this list; hdebug is the 18-05
# leg-7 subject, hauthprobe is the 14i3 host-side build)
for h in hmntgen hcs hcsquery hkeyfs hauthsrv hsecstored hlisten1 hdebug; do
	"$GREP" -q "^$h " "$AUTH_HLIST" || err "auth bake: sweep subject $h missing from the computed auth-suite set (the resolver lost it)"
done

# 14c. the tier-1 helper artifacts (the sweep's $B/h* vocabulary — the
#      entries asserted at 14a; the artifacts named loudly with the
#      remediation) + the unprefixed utility supply (bind — NOT an rc
#      builtin; the 14-09 net-section supply, the services bake's own
#      11j line) + the chain inputs (the 11c checks)
for rel in cat echo ls test sleep sha1sum auth/factotum; do
	[ -f "$BIN/$rel" ] || err "$BIN/$rel missing — run sh build/x86_64/subset-build.sh first (the auth sweep's tier-1 helper set)"
done
[ -s "$BIN/bind" ] || err "$BIN/bind missing — run sh build/x86_64/subset-build.sh first (the sweep's loopback bring-up)"
[ -s "$BIN/auth/authsrv" ] || err "$BIN/auth/authsrv missing — run sh build/x86_64/subset-build.sh first (the listen1 exec target)"
[ -s "$BIN/rc" ] || err "$BIN/rc missing — run sh build/x86_64/subset-build.sh first"
[ -s "$HARVEY/amd64/init" ] || err "amd64/init missing — run sh build/x86_64/subset-build.sh first (stage/init)"
[ -s "$CHAIN_OUT/boot" ] || err "$CHAIN_OUT/boot missing — run sh build/x86_64/subset-build.sh first (9k/boot)"
[ -s "$BIN/paqfs" ] || err "$BIN/paqfs missing — run sh build/x86_64/subset-build.sh first"

# 14d. authdomain-gen — INVOKED AT BAKE (D-01): the host cc over the
#      vendored donor algorithm files (the 18-03 venue; the committed
#      self-test's build line is the reference invocation).  The flake
#      app carries stdenv.cc for this; a standalone bake needs cc on
#      PATH (the devshell provides it).
AUTH_CC=""
for _c in cc gcc; do
	if command -v "$_c" >/dev/null 2>&1; then AUTH_CC="$_c"; break; fi
done
[ -n "$AUTH_CC" ] || err "no host C compiler for authdomain-gen — run via the flake app (nix run .#boot-r9-auth-x64, whose runtimeInputs carry stdenv.cc)"
AUTH_GEN="$TMPD/authdomain-gen"
# shellcheck disable=SC2086  # the donors glob is a word list by construction
"$AUTH_CC" -O2 -Wno-unknown-pragmas -I"$HARVEY/build/x86_64/authdom-donors" \
	-o "$AUTH_GEN" "$HARVEY/build/x86_64/authdomain-gen.c" \
	"$HARVEY"/build/x86_64/authdom-donors/*.c \
	|| err "authdomain-gen host build failed (the 18-03 vendored-donor venue)"

STAGE8="$TMPD/root-auth"
mkdir -p "$STAGE8"

# 14e. the committed skeleton (the chain bake's shape — the /lib net
#      fixtures ride the skeleton tar; the ndb template rides it too)
(cd "$ROOT_TREE" && tar -cf - .) | (cd "$STAGE8" && tar -xf -)

# 14f. the bake-time p9sk1 domain: generate (DEMO on the absent repo-
#      root /authdomain.local — the generator's own default, hence the
#      $HARVEY cwd), stage the paired unit at its guest homes, then
#      the D-02 BAKE ARM — authdomain-gen -V over the STAGED COPIES
#      (manifest digests re-verified; the bake REFUSES on mismatch).
AUTHDOM_STAGE="$TMPD/authdom-stage"
(cd "$HARVEY" && "$AUTH_GEN" -o "$AUTHDOM_STAGE") \
	|| err "authdomain-gen -o failed (the bake-time domain generate)"
mkdir -p "$STAGE8/adm" "$STAGE8/lib/ndb"
cp "$AUTHDOM_STAGE/nvram" "$STAGE8/adm/nvram"
cp "$AUTHDOM_STAGE/keys" "$STAGE8/adm/keys"
cp "$AUTHDOM_STAGE/manifest" "$STAGE8/adm/domain.manifest"
cp "$AUTHDOM_STAGE/ndb-auth" "$STAGE8/lib/ndb/auth"
_nb=$(wc -c < "$STAGE8/adm/nvram" | tr -d ' ')
[ "$_nb" -eq 112 ] || err "auth bake: staged /adm/nvram is $_nb bytes, want 112 (the 109-byte Nvrsafe + the 6c guest-ABI tail pad — readnvram reads sizeof(Nvrsafe)==112 on the guest)"
[ -s "$STAGE8/adm/keys" ] || err "auth bake: staged /adm/keys is empty"
[ -s "$STAGE8/adm/domain.manifest" ] || err "auth bake: staged /adm/domain.manifest is empty"
[ -s "$STAGE8/lib/ndb/auth" ] || err "auth bake: staged /lib/ndb/auth is empty"
AUTH_VDIR="$TMPD/auth-verify"
mkdir -p "$AUTH_VDIR"
cp "$STAGE8/adm/nvram" "$AUTH_VDIR/nvram"
cp "$STAGE8/adm/keys" "$AUTH_VDIR/keys"
cp "$STAGE8/lib/ndb/auth" "$AUTH_VDIR/ndb-auth"
cp "$STAGE8/adm/domain.manifest" "$AUTH_VDIR/manifest"
# the teeth seam (the 15-08 discipline): AUTHBAKE_DOCTOR=nvram|keys|
# ndb-auth flips the first byte of the named STAGED COPY's scratch
# verify-dir twin AFTER staging and BEFORE the verify arm — the
# negative-control run (`AUTHBAKE_DOCTOR=nvram sh build/x86_64/
# mkimage.sh') must exit nonzero AT the pairing assert below, proving
# the bake's own refusal path (never only the generator's self-test).
if [ -n "${AUTHBAKE_DOCTOR:-}" ]; then
	case "$AUTHBAKE_DOCTOR" in
	nvram|keys|ndb-auth)
		_f="$AUTH_VDIR/$AUTHBAKE_DOCTOR"
		{ printf 'c'; tail -c +2 "$_f"; } > "$_f.d" && mv "$_f.d" "$_f" \
			|| err "auth bake: the AUTHBAKE_DOCTOR byte-flip failed"
		echo "== AUTH TEETH: doctored the staged $AUTHBAKE_DOCTOR copy — the pairing assert below MUST refuse" ;;
	*) err "AUTHBAKE_DOCTOR=$AUTHBAKE_DOCTOR: want nvram|keys|ndb-auth" ;;
	esac
fi
"$AUTH_GEN" -V "$AUTH_VDIR" \
	|| err "auth bake: the D-02 pairing assert REFUSED the staged copies (authdomain-gen -V nonzero — the bake refuses)"
echo "== auth pairing verified over the staged copies (authdomain-gen -V over the bake's own scratch twin)"

# 14f2. the DEMO sentinel feed: the generator's LAST user's password
#       (D-12's plain probe user — DEMO's norbert), a single
#       newline-terminated line the bake stages read-only at
#       /boot/authfeed.txt — 18-05's interactive prompt feeds consume
#       it (the generator's manifest deliberately carries no
#       passwords; this is the same run's convenience copy, NOT a
#       pairing member).  Single line + trailing newline, asserted.
mkdir -p "$STAGE8/boot"
[ -s "$AUTHDOM_STAGE/feed" ] || err "auth bake: the generator emitted no feed artifact (the 18-05 sentinel feed)"
_feedlines=$(wc -l < "$AUTHDOM_STAGE/feed" | tr -d ' ')
[ "$_feedlines" -eq 1 ] || err "auth bake: the feed artifact is $_feedlines lines, want exactly 1"
[ "$(tail -c 1 "$AUTHDOM_STAGE/feed" | od -An -tx1 | tr -d ' \n')" = "0a" ] \
	|| err "auth bake: the feed artifact is not newline-terminated (the Brdline discipline)"
cp "$AUTHDOM_STAGE/feed" "$STAGE8/boot/authfeed.txt"

# 14f3. /lib/ndb/local — the AUTH-05 composition through the seam: the
#       committed token template's FIVE tokens substitute at bake —
#       the four seam-owned ones (@GUESTV4@/@MASKV4@/@GWV4@/@ETHER@)
#       from netaddr.rc and @AUTHDOM@ from THIS generator run's own -i
#       output (never a seam value: the domain is per-bake paired
#       material — a seam key would be a second source violating
#       D-02's pairing).  Asserted both ways (zero leftover tokens,
#       every value present) + the trailing newline (libndb's Brdline
#       drops an unterminated final line whole).
AUTHDOM_VAL=$( ("$AUTH_GEN" -i "$AUTHDOM_STAGE") 2>/dev/null | awk '$1 == "authdom:" { print $2 }' )
[ -n "$AUTHDOM_VAL" ] || err "auth bake: authdomain-gen -i printed no authdom token (the @AUTHDOM@ substitution source)"
. "$ROOT_TREE/lib/netaddr.rc"
[ -n "${ether:-}" ] || err "netaddr.rc lacks an ether seam key (the @ETHER@ substitution source)"
sed -e "s/@GUESTV4@/$slirp_guestv4/g" -e "s/@MASKV4@/$slirp_maskv4/g" \
	-e "s/@GWV4@/$slirp_gwv4/g" -e "s/@ETHER@/$ether/g" \
	-e "s/@AUTHDOM@/$AUTHDOM_VAL/g" "$ROOT_TREE/lib/ndb/local.template" > "$STAGE8/lib/ndb/local"
if "$GREP" -q '@' "$STAGE8/lib/ndb/local"; then
	err "auth bake: /lib/ndb/local carries an unsubstituted token (the template names a token the auth substitution does not know)"
fi
for _v in "$slirp_guestv4" "$slirp_maskv4" "$slirp_gwv4" "$ether" "$AUTHDOM_VAL" "127.0.0.1"; do
	"$GREP" -qF "$_v" "$STAGE8/lib/ndb/local" || err "auth bake: /lib/ndb/local lacks the value $_v (a template token went missing)"
done
# 18-05: the SERVICE-NAME row — cs's ipserv translates an alpha service
# name via ndbgetvalue(db, "tcp", <name>, "port") (cs.c:1265-1316), so
# dial(netmkaddr(addr, nil, "ticket")) — auth/debug's own dial form AND
# authprobe's — needs a `tcp=ticket port=567' row or cs answers `can't
# translate service' and every probe dial reds.  567 is the donor
# protocol constant (D-09's tcp!*!567), not a venue address.  Appended
# at THIS compose only (the services image keeps its semantics —
# D-08's minimality), asserted present.
printf 'tcp=ticket port=567\n' >> "$STAGE8/lib/ndb/local"
"$GREP" -q '^tcp=ticket port=567$' "$STAGE8/lib/ndb/local" \
	|| err "auth bake: the tcp=ticket service row missing from the composed /lib/ndb/local"
[ "$(tail -c 1 "$STAGE8/lib/ndb/local" | od -An -tx1 | tr -d ' \n')" = "0a" ] \
	|| err "auth bake: /lib/ndb/local is not newline-terminated (libndb's Brdline drops an unterminated final line whole)"
echo "== auth ndb: /lib/ndb/local composed from local.template (the seam's four tokens + @AUTHDOM@=$AUTHDOM_VAL from the generator run + the tcp=ticket service row for the probe dials)"

# 14g. empty mount-point dirs + staging parents (the chain set + the
#      domain's /adm + the /lib/ndb home)
mkdir -p "$STAGE8/root" "$STAGE8/env" "$STAGE8/proc" "$STAGE8/dev" "$STAGE8/srv" \
	"$STAGE8/fd" "$STAGE8/bin" "$STAGE8/tmp" "$STAGE8/mnt" \
	"$STAGE8/net" "$STAGE8/boot" "$STAGE8/amd64/bin" \
	"$STAGE8/rc/lib" "$STAGE8/rc/bin" "$STAGE8/adm/timezone" "$STAGE8/adm" \
	"$STAGE8/lib/ndb"

# 14h. the chain binaries from THIS build's products (the 9e/11g
#      discipline: BIN + /amd64/init + out/boot, never a stale out/
#      harvest for members that have a /amd64/bin home)
cp "$CHAIN_OUT/boot" "$STAGE8/boot/boot"
cp "$BIN/paqfs" "$STAGE8/boot/paqfs"
cp "$HARVEY/amd64/init" "$STAGE8/amd64/init"
for f in rc ls cat echo ps; do
	[ -s "$BIN/$f" ] || err "$BIN/$f missing — run sh build/x86_64/subset-build.sh first"
	cp "$BIN/$f" "$STAGE8/amd64/bin/$f"
done

# 14i. the auth-suite payload (the computed 14b set) + the tier-1
#      helper vocabulary + the unprefixed utility supply + the
#      listen1 exec target (authsrv at its donor-default exec path —
#      the sweep's `listen1 -t tcp!*!567 /amd64/bin/authsrv -d' names
#      the UNPREFIXED path, so the image carries it there; hauthsrv
#      stays the sweep's own vocabulary name)
while read -r _h _src; do
	cp "$_src" "$STAGE8/amd64/bin/$_h"
done < "$AUTH_HLIST"
for rel in cat echo ls test sleep sha1sum auth/factotum; do
	cp "$BIN/$rel" "$STAGE8/amd64/bin/h${rel##*/}"
done
cp "$BIN/bind" "$STAGE8/amd64/bin/bind"
cp "$BIN/auth/authsrv" "$STAGE8/amd64/bin/authsrv"
magic=$(od -An -tx1 -N4 "$STAGE8/amd64/bin/authsrv" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "authsrv exec-path copy: bad magic $magic (want 00008a97)"

# 14i2. hsvctcpecho — the connect-only client (the 11k host-side 6c/6l
#       build copied verbatim: the sweep's authsrv-listen probe dials
#       127.0.0.1!567 and proves the accept — a dial to an announced
#       port is accepted while an unannounced one refuses; authsrv
#       itself stays handshake-silent by design, 18-05's exchanges are
#       the ticket traffic)
(	cd "$HARVEY" && \
	"$SVC_NS_HBIN/6c" -FTVw -o "$STAGE8/.svctcpecho.6" -Isys/include -Iamd64/include build/x86_64/svctcpecho.c && \
	"$SVC_NS_HBIN/6l" -o "$STAGE8/amd64/bin/hsvctcpecho" -L "$HARVEY/amd64/lib" "$STAGE8/.svctcpecho.6" && \
	rm -f "$STAGE8/.svctcpecho.6"
) || err "hsvctcpecho host-side build failed (auth)"
magic=$(od -An -tx1 -N4 "$STAGE8/amd64/bin/hsvctcpecho" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "hsvctcpecho: bad magic $magic (want 00008a97)"

# 14i3. hauthprobe — the 18-05 speaksfor leg-2 client (AUTH-06/D-13):
#       the same 6c/6l block shape; libauthsrv rides the #pragma-lib
#       autolib record <authsrv.h> plants in the .6 (6l resolves it
#       through the -L checkout lib path), so the link line itself is
#       unchanged from the svctcpecho block.  Staged /amd64/bin/
#       hauthprobe; the sweep's probe window runs its pass and deny
#       arms (one attempt each — Pitfall 4).
(	cd "$HARVEY" && \
		"$SVC_NS_HBIN/6c" -FTVw -o "$STAGE8/.authprobe.6" -Isys/include -Iamd64/include build/x86_64/authprobe.c && \
		"$SVC_NS_HBIN/6l" -o "$STAGE8/amd64/bin/hauthprobe" -L "$HARVEY/amd64/lib" "$STAGE8/.authprobe.6" && \
		rm -f "$STAGE8/.authprobe.6"
	) || err "hauthprobe host-side build failed (auth)"
magic=$(od -An -tx1 -N4 "$STAGE8/amd64/bin/hauthprobe" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "hauthprobe: bad magic $magic (want 00008a97)"

# 14j. the sweep at /lib + the termrc OVERRIDE (the 11l rule: the auth
#      image runs the sweep from the boot flow, no typed interaction)
#      + the bake-time verbatim copies (the chain bake's 11n rule)
cp "$HARVEY/build/x86_64/auth-sweep.rc" "$STAGE8/lib/auth-sweep.rc"
cp "$HARVEY/build/x86_64/auth-termrc" "$STAGE8/rc/bin/termrc"
cp "$HARVEY/rc/lib/rcmain" "$STAGE8/rc/lib/rcmain"
cp "$HARVEY/adm/timezone/local" "$STAGE8/adm/timezone/local"

# 14k. pre-bake manifest: the chain paths + the domain artifacts + the
#      payload, PRINTED as the staging manifest (the bake log is the
#      gate's evidence — the plan's verify greps these lines)
for p in boot/boot boot/paqfs amd64/init amd64/bin/rc \
	amd64/bin/ls amd64/bin/cat amd64/bin/echo amd64/bin/ps \
	amd64/bin/bind amd64/bin/authsrv amd64/bin/hsvctcpecho \
	amd64/bin/hauthprobe \
	rc/lib/rcmain rc/bin/termrc lib/namespace adm/timezone/local \
	usr/glenda/lib/profile adm/nvram adm/keys adm/domain.manifest \
	lib/ndb/auth lib/ndb/local lib/auth-sweep.rc boot/authfeed.txt; do
	[ -f "$STAGE8/$p" ] || err "auth manifest: $p missing from staged tree"
	echo "auth manifest: /$p staged"
done
_nh=0
while read -r _h _src; do
	[ -f "$STAGE8/amd64/bin/$_h" ] || err "auth manifest: amd64/bin/$_h missing from staged tree"
	_nh=$((_nh + 1))
done < "$AUTH_HLIST"
echo "auth manifest: ${_nh} h* sweep binaries staged (the auth-suite set computed from tiers/tier2-services.txt + the tier-1 helpers: $_nauth tier-2 members)"
for p in root env proc dev srv fd bin tmp mnt net; do
	[ -d "$STAGE8/$p" ] || err "auth manifest: mount-point dir /$p missing"
done

# 14l. /boot/factotum ABSENCE (auth-stub-by-absence — the same D-02
#      rule as every bake above; hfactotum in /amd64/bin is the sweep
#      payload, NOT the boot auth stub).  NO writable /sys/log is ever
#      staged or bound (Pitfall 6: syslog's #c/cons fallback IS the
#      AUTH-07 serial mechanism — a writable log file silently kills
#      it); the manifest above carries no sys/log member by design.
[ ! -e "$STAGE8/boot/factotum" ] || err "auth manifest: /boot/factotum present — auth-stub-by-absence violated"
[ ! -e "$STAGE8/sys/log" ] || err "auth manifest: a /sys/log tree is staged — Pitfall 6 (the syslog console fallback IS the serial-visibility mechanism; a writable log file silently kills it)"

# 14m. rcmain ships byte-verbatim (the chain bake's cmp guard)
cmp -s "$HARVEY/rc/lib/rcmain" "$STAGE8/rc/lib/rcmain" || err "staged rcmain diverges from rc/lib/rcmain (auth)"

# 14n. determinism + bake (the chain bake's rule; the per-file cap
#      assert rides too — the 15-07 measured hazard; the mkpaqfs
#      failure itself is the fail-on-any-diagnostic backstop)
_maxf8=$(find "$STAGE8" -type f -printf '%s\n' | sort -n | tail -1)
[ "$_maxf8" -le 4194304 ] || err "auth bake: a staged file of $_maxf8 bytes exceeds mkpaqfs's 4194304-byte per-file cap"
find "$STAGE8" -exec touch -h -d "@$KERNDATE" {} +
rm -f "$AUTH_IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$AUTH_IMAGE" "$STAGE8" || err "mkpaqfs failed (auth)"
[ -s "$AUTH_IMAGE" ] || err "$AUTH_IMAGE missing/empty after mkpaqfs"

# 14o. the byte-format contract (same header/trailer magic checks)
magic8=$(od -An -tx1 -N4 "$AUTH_IMAGE" | tr -d ' \n')
[ "$magic8" = "529ab12b" ] || err "$AUTH_IMAGE: bad header magic $magic8 (want 529ab12b)"
sz8=$(wc -c < "$AUTH_IMAGE" | tr -d ' ')
trailer8=$(od -An -tx1 -j $((sz8 - 28)) -N 4 "$AUTH_IMAGE" | tr -d ' \n')
[ "$trailer8" = "6b46e688" ] || err "$AUTH_IMAGE: bad trailer magic $trailer8 (want 6b46e688)"

echo "== PASS: baked $AUTH_IMAGE ($sz8 bytes; chain + auth suite + the paired p9sk1 domain; header $magic8 trailer $trailer8; KERNDATE $KERNDATE)"
