#!/bin/sh
# build/aarch64/subset-exec.sh — the tier-1 execution gate: the Harvey
# aarch64 tier-1 binaries (the D-09 membership: the v1.0 16-subset, the
# 06-03 tracer's cmd/awk, the 06-06 coreutils extension — bc sort tr
# uniq tail dd tar chmod tee basename sleep cmp comm fmt join look pr
# split strings sum md5sum sha1sum ed dc units cal touch time seq read
# du xd nm — and the build chain, all compiled by Harvey's vendored 7c
# and linked by 7l) EXECUTE on the 9front donor kernel under qemu -M
# virt TCG.
#
# VENUE SPLIT (06-10, G-06-1; maintainer direction 2026-11-05): this
# donor gate is the aarch64 LOCAL venue ONLY — driven by hand (darwin
# provisions the donor via donor-vm-build.sh/lima; native linux needs a
# natively-built donor tree, and no provisioning driver exists for it
# this era).  CI never runs it.  The x86_64 CI tier venue is Harvey's
# OWN kernel via the 06-09 k10t1 pair (build/mm/build-9k10t1.sh +
# build/mm/boot-9k10t1-sweep.sh) wired as phase6.yml's tier-9k job.
#
# 06-03 evolution (D-10): the 22 typed drive9 steps are replaced by the
# SOURCED in-guest sweep — build/aarch64/tier1-sweep.rc, staged into the
# donor kernel's devroot as /boot/tier1-sweep.rc via the CONF bootdir
# block (mkrootall strips only file-identified executables; text rides
# through) and run at boot by the staged termrc override whose tail is
# `exec rc -c '. /boot/tier1-sweep.rc donor'` (trace-termrc precedent —
# the donor's devcons fails /dev/cons reads by design, so typed
# per-binary interaction does not scale).  The override replaces the
# served rootfs's rc/bin/termrc for the run's duration; the cleanup trap
# restores it (the served root is shared gate scratch).  init's restart
# loop then brings up the pass-2 interactive rc (init.c: manual=1 →
# plain `rc`), which drive9's shell proof drives exactly as before.
#
# The gate stack, end to end: stage the tier-1 binaries (h-prefix) +
# the sweep + hello.c into the guest donor tree → marker-guarded
# idempotent CONF=qemu bootdir patch (self-healing: stale subset lines
# are dropped before the block is inserted) → targeted mkrootall rebake
# embeds them into the kernel's devroot as /boot/h* (mkpaqfs is NOT
# re-run — the bootfs.paq is unmounted before the shell; devroot
# survives) → boot the rebaked kernel with exactly boot-9qemu.sh's qemu
# invocation → the sweep emits T1-OK/T1-FAIL per binary + the D-01 float
# canary (T1-OK float-d01) + T1-DONE over serial → host asserts the
# marker set, zero T1-FAIL, zero panic|trap: lines.
#
# Platform split (06-03, Pitfall P6-4): darwin drives the lima guest for
# the donor rebake (ssh/rsync + nix develop); native linux runs the SAME
# self-re-entrant rebake script in the host's own namespace (sudo
# unshare) with the donor tree at .build/9front-donor — limactl is
# required only on the darwin leg.  The donor fetch + pin-verify is
# host-side on both legs.  The qemu boot/srv9/drive9 phase is host-side
# on both legs (it already was on darwin).  `--print-platform` dry-run
# prints the resolved venue and exits (dispatch proof for CI wiring).
#
# The srv9 root mount is served with --writable-prefix /tmp
# --writable-prefix /usr/glenda/tmp for this gate (and only this
# gate): lib/namespace binds /usr/glenda/tmp onto /tmp with MCREATE,
# giving the guest a writable hierarchical scratch for the sweep's
# write-flow round-trip (mkdir/cp/mv/rm).  The proven read-only
# harnesses never pass the flag.
#
# MARKER VOCABULARY (each asserted host-side, presence-only — never
# interleaving order; TCG-timing tolerant):
#   T1-OK <name>    the swept binary's fixed-input check passed
#   T1-FAIL <name>  it failed — the sweep CONTINUES (USPACE-04 empty
#                   edge: a failing entry never wedges or shortens the
#                   sweep); the host gate reds on any T1-FAIL
#   T1-SKIP <name>  write-flow entry skipped on a read-only-root venue
#                   (r9 this era); never emitted on the donor
#   T1-OK float-d01 D-01's mandatory canary: awk prints 0.333 for
#                   'BEGIN{printf "%.3f\n", 1.0/3.0}' — %e/%f/%g
#                   correctness is execution-asserted, not assumed
#   T1-OK stacksmoke  the staged termrc ran /boot/hstacksmoke green
#   T1-DONE         the sweep ran to completion (tail of
#                   tier1-sweep.rc, then exit — init's restart-loop
#                   sleep is captured before teardown)
#
# Swept check table (tier1-sweep.rc is the source of truth; fixed inputs
# re-express the v1.0 step table): echo sentinel, ls / non-empty, cat
# sentinel.txt, grep/sed/wc pipelines, date parseable, test -f, hrc
# eval (caret concat), ps lists the sweep's rc, ipconfig usage-level,
# factotum spawn+resident, awk field split, float canary, the 06-06
# coreutils blocks (sort/tr/uniq/tail round-trips, sum/md5sum/sha1sum/
# cmp known-content, ed/dc/units/cal usage+output markers, bc's A7
# shape-assert + T1-BCOBS observation, nm reading the committed baked
# nm-input.7), the donor-venue write-flow round-trips (mkdir/cp/mv/rm +
# dd/tar/tee/chmod/touch/split + look's generated sorted db), and the
# donor-venue build-chain evidence (cpp -D smoke, yacc tiny.y →
# y.tab.c/yyparse, lex tiny.l → lex.yy.c/yylex, mk tiny.mk echo).
#
# Invariant: zero panic/trap/sys: note lines in the capture (asserted
# host-side; the plan's fails_when).  BOOT_BUDGET discipline per
# boot-9qemu.sh (TCG is slow; raise the budget, never retry silently).
# Bake-vs-ufs per the README: bake for gates.  Idempotence: the CONF
# patch is marker-guarded AND self-healing, the staging is exact, the
# termrc override is restored by the trap, and the /tmp scratch
# round-trip removes what it creates — consecutive runs pass
# consecutively.
#
# Usage (from the repo root, inside the nix devshell):
#   sh build/aarch64/subset-exec.sh
#   sh build/aarch64/subset-exec.sh --print-platform   (dry dispatch proof)
#
# Env overrides: HARVEY, HARVEY_VM, QEMU_BIN, HARNESS_BIN, BOOT_BUDGET,
#   SRV9_PORT, DONOR_DIST_HOST (same meaning as run-gate.sh),
#   FORCE_NATIVE_LINUX=1 (dispatch proof only — the native leg still
#   needs a linux host's namespace+sudo to actually run).
#
# On failure the script halts non-zero and the guest serial log
# (.build/9front-dist/subset-exec.log) is the bisect surface — per the
# toolchain-first diagnostic rule, suspect our 7c/7l/libc/tier-1
# binaries before the donor kernel.

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build-donor}"
GUEST_DONOR="${DONOR_GUEST_DIR:-9front-donor}"
GUEST_DIST=9front-dist
DONOR="$HARVEY/.build/9front-donor"
DONOR_SHA=350266104f1fed81c78c3d05fa44f523bec0ae4d
DIST="${DONOR_DIST_HOST:-$HARVEY/.build/9front-dist}"
ROOTFS="${ROOTFS:-$DIST/srvroot}"
RUNLOG="${QEMU_LOG:-$DIST/subset-exec.log}"
BUILDLOG="$DIST/subset-rebake.log"
GATE_U="$DIST/9qemu-subset.u"
GATE_K="$DIST/9qemu-subset"
BOOT_BUDGET="${BOOT_BUDGET:-1500}"
SRV9_PORT="${SRV9_PORT:-1564}"
SRV9_GUEST_IP="${SRV9_GUEST_IP:-10.0.2.100}"

# the tier-1 swept binaries: guest-staging name → /boot name (h-prefix)
SUBSET_FLAT="cat cp date echo ls mkdir mv ps rm sed test wc rc grep"
SUBSET_NAMED="ip/ipconfig auth/factotum"
# 06-06 (USPACE-06, D-09): the researcher-proposed coreutils extension
# + the four build-chain members with per-tool fixed-input checks.  All
# install flat into /aarch64/bin and stage h*-prefixed.  (dd already
# rode the 07-04 image block; its tier-1 gate membership lands here.)
SUBSET_CORE="bc sort tr uniq tail dd tar chmod tee basename sleep cmp comm fmt join look pr split strings sum md5sum sha1sum ed dc units cal touch time seq read du xd nm"
SUBSET_CHAIN="cpp mk yacc lex"
# 06-06 Task 2 (D-11 self-host canary): the v1.0-green target toolchain
# binaries stage h*-prefixed too — the sweep compiles the committed
# hello.c IN THE GUEST with /boot/h7c + /boot/h7l and runs the product
# from the srv9 writable prefix; /boot/h7a assembles the committed
# tiny.s (7c -FTVw emits .7 directly, so 7a gets its own input).
SUBSET_SELFHOST="7a 7c 7l"
# 06-06 committed fixed inputs (staged as bootdir DATA): yacc/lex/mk
# execution-evidence inputs + nm's baked object (produced at authoring
# time by the build venue's host 7c over the committed hello.c) + 7a's
# assemble stub.
SUBSET_DATA="tiny.y tiny.l tiny.mk nm-input.7 tiny.s"

# Platform split (06-03, Pitfall P6-4): linux runs the donor rebake in
# the host's own mount namespace (the self-re-entrant script's
# wrap→--ns→--build shape); darwin drives the lima guest.  limactl is
# required only on the darwin leg.
NATIVE_LINUX=
if [ "$(uname -s)" = "Linux" ] || [ "${FORCE_NATIVE_LINUX:-0}" = "1" ]; then
	NATIVE_LINUX=1
fi

# --print-platform: dry dispatch proof (no preconditions, no VM dance) —
# 06-08's CI wiring and native-linux smoke checks use this to prove the
# split routes per uname.
if [ "${1:-}" = "--print-platform" ]; then
	if [ -n "$NATIVE_LINUX" ]; then
		echo "platform=native-linux venue=nsrun-sudo-unshare donor=$DONOR dist=$DIST limactl=not-required"
	else
		echo "platform=darwin venue=lima guest=$VM donor=$DONOR dist=$DIST limactl=required"
	fi
	exit 0
fi

err() { echo "error: $*" >&2; exit 1; }

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

# ---- preconditions (read-only) ------------------------------------
[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
# donor pin gate: host-side on BOTH legs (the single supply-chain input)
actual=$(git -C "$DONOR" rev-parse HEAD 2>/dev/null || echo missing)
[ "$actual" = "$DONOR_SHA" ] || err "donor pin mismatch: want $DONOR_SHA, have $actual"
[ -s "$DIST/9qemu.u" ] || err "$DIST/9qemu.u missing — run sh build/aarch64/donor-vm-build.sh first"
[ -d "$ROOTFS/arm64/bin" ] || err "$ROOTFS incomplete — run sh build/aarch64/donor-vm-build.sh first"
for f in $SUBSET_FLAT $SUBSET_CORE $SUBSET_CHAIN; do
	[ -x "$HARVEY/aarch64/bin/$f" ] || err "aarch64/bin/$f missing — run sh build/aarch64/subset-build.sh first"
done
for f in $SUBSET_NAMED; do
	[ -x "$HARVEY/aarch64/bin/$f" ] || err "aarch64/bin/$f missing — run sh build/aarch64/subset-build.sh first"
done
# 06-03 tracer additions: the awk binary, the committed sweep + canary
# source, and the staged stacksmoke (the termrc override runs it)
[ -x "$HARVEY/aarch64/bin/awk" ] || err "aarch64/bin/awk missing — run sh build/aarch64/subset-build.sh first"
[ -s "$HARVEY/build/aarch64/out/stacksmoke" ] || err "build/aarch64/out/stacksmoke missing — run sh build/aarch64/subset-build.sh first"
[ -f "$HARVEY/build/aarch64/tier1-sweep.rc" ] || err "build/aarch64/tier1-sweep.rc missing (06-03 committed sweep)"
[ -f "$HARVEY/build/aarch64/hello.c" ] || err "build/aarch64/hello.c missing (06-06 self-host canary source, staged as data)"
# 06-06: the committed fixed inputs (06-06 Task 1)
for f in $SUBSET_DATA; do
	[ -f "$HARVEY/build/aarch64/$f" ] || err "build/aarch64/$f missing (06-06 committed fixed input)"
done
# 06-06 Task 2 (D-11): the canary's toolchain binaries + the guest-side
# compile's header/libc inputs (staged into the srv9-served root below)
for f in $SUBSET_SELFHOST; do
	[ -x "$HARVEY/aarch64/bin/$f" ] || err "aarch64/bin/$f missing — run sh build/aarch64/subset-build.sh first"
done
[ -d "$HARVEY/aarch64/include" ] || err "aarch64/include missing (the committed arch headers — 02-06 wiring is a precondition)"
[ -s "$HARVEY/aarch64/lib/libc.a" ] || err "aarch64/lib/libc.a missing — run sh build/aarch64/subset-build.sh first"
# 06-05: the tier-0 lib test binaries (D-06 — built per-target by
# subset-build.sh, staged below, run by the sweep's libtest block)
for f in hdrawtest harctest htdraw hdisktest; do
	[ -s "$HARVEY/build/aarch64/out/$f" ] || err "build/aarch64/out/$f missing — run sh build/aarch64/subset-build.sh first"
done

if [ -z "$NATIVE_LINUX" ]; then
	command -v limactl >/dev/null 2>&1 || err "limactl not found — run inside the nix devshell"
	if ! limactl list -q 2>/dev/null | "$GREP" -qx "$VM"; then
		err "lima VM '$VM' does not exist"
	fi
	status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
	if [ "$status" != "Running" ]; then
		limactl start "$VM"
	fi
else
	# native linux: the rebake re-enters via sudo unshare — the host
	# toolchain bin dir rides the exports into the namespace (the
	# subset-build.sh native-leg env shape)
	export HARVEY
	_hx_arch=$(uname -m); [ "$_hx_arch" = "arm64" ] && _hx_arch=aarch64
	HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-$_hx_arch/bin}"
	export HARVEY_LINUX_BIN
	[ -x "$HARVEY_LINUX_BIN/7c" ] || err "host toolchain missing ($HARVEY_LINUX_BIN/7c) — run nix run .#setup && nix run .#toolchain"
fi

QEMU_BIN="${QEMU_BIN:-}"
if [ -z "$QEMU_BIN" ]; then
	QEMU_BIN=$(command -v qemu-system-aarch64 || true)
fi
[ -n "$QEMU_BIN" ] && [ -x "$QEMU_BIN" ] || err "qemu-system-aarch64 not found — run inside the nix devshell or set QEMU_BIN"
"$QEMU_BIN" --version >/dev/null 2>&1 || err "$QEMU_BIN not runnable"

HARNESS_BIN="${HARNESS_BIN:-}"
if [ -z "$HARNESS_BIN" ]; then
	HARNESS_BIN=$(command -v harness || true)
fi
[ -n "$HARNESS_BIN" ] && [ -x "$HARNESS_BIN" ] || \
	err "harness binary not found — set HARNESS_BIN or run inside the nix devshell (which exports it)"

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

# ensure the writable scratch targets exist in the served root (the
# /tmp bind target must exist for lib/namespace's bind -c to succeed)
mkdir -p "$ROOTFS/tmp" "$ROOTFS/usr/glenda/tmp"
# start each run from a clean scratch (idempotence evidence) — the
# sweep's write-flow round-trips + build-chain outputs + the 06-06
# canary products are all removed.  The guest's /tmp is lib/namespace's
# MCREATE bind of /usr/glenda/tmp, so BOTH branches are cleaned
# (measured 06-06: a stale bc-bin on the usr/glenda/tmp branch broke
# the next run's shim setup)
for scratch in "$ROOTFS/tmp" "$ROOTFS/usr/glenda/tmp"; do
	rm -rf "$scratch/subset" "$scratch/tier1" "$scratch/bc-bin"
	rm -f	"$scratch/y.tab.c" "$scratch/lex.yy.c" "$scratch/cpp-in.c" \
		"$scratch/hello" "$scratch/hello.7" "$scratch/hello.out" "$scratch/tiny.7"
done

# 06-06: srv9-served-root staging — the guest has no /sys tree at all,
# but the build-chain tools open their skeletons by compiled-in
# absolute paths (yacc's PARSER=/sys/lib/yaccpar, yacc.c:16; lex's
# /sys/lib/lex/ncform, lex/lmain.c:17).  Stage Harvey's (the matching
# skeletons for our vendored tools) into the served root — additive,
# read-only from the guest side.
mkdir -p "$ROOTFS/sys/lib/lex"
cp "$HARVEY/sys/lib/yaccpar" "$ROOTFS/sys/lib/yaccpar"
cp "$HARVEY/sys/lib/lex/ncform" "$ROOTFS/sys/lib/lex/ncform"
# 06-06 Task 2 (D-11 canary): the in-guest 7c/7l resolve headers and
# autolib via the compiled-in thestring=aarch64 — /aarch64/include and
# /aarch64/lib/libc.a must exist IN THE SERVED ROOT (7l autolibs libc.a
# via libc.h's #pragma lib).  Stage Harvey's committed arch include
# tree + the freshly built libc.a (subset-build's tier-0 fresh-archive
# product, rsynced back host-side on the darwin leg).  The compiler's
# include search also covers /sys/include (measured on the donor:
# u.h resolves from /aarch64/include, then libc.h is wanted from
# /sys/include) — stage the committed sys/include tree as well.
rm -rf "$ROOTFS/aarch64/include" "$ROOTFS/sys/include"
mkdir -p "$ROOTFS/aarch64/lib" "$ROOTFS/sys"
cp -R "$HARVEY/aarch64/include" "$ROOTFS/aarch64/include"
cp -R "$HARVEY/sys/include" "$ROOTFS/sys/include"
cp "$HARVEY/aarch64/lib/libc.a" "$ROOTFS/aarch64/lib/libc.a"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/subset-exec.XXXXXX")
TERMRC_ORIG="$TMPD/termrc.orig"
SRV9_PID=""
QEMU_PID=""
POKE_PID=""
cleanup() {
	status=$?
	[ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
	[ -n "$SRV9_PID" ] && kill "$SRV9_PID" 2>/dev/null || true
	[ -n "$POKE_PID" ] && kill "$POKE_PID" 2>/dev/null || true
	# restore the served rootfs's termrc BEFORE dropping TMPD (the
	# override lives only for the run's duration; the served root is
	# shared gate scratch — a stranded override would rewrite the
	# donor venue's boot behavior for every other consumer)
	if [ -f "$TERMRC_ORIG" ]; then
		cp "$TERMRC_ORIG" "$ROOTFS/rc/bin/termrc" 2>/dev/null || true
	fi
	rm -rf "$TMPD"
	exit $status
}
trap cleanup EXIT

# the known-content file baked into the guest as /boot/sentinel.txt
# (deterministic wc counts: 2 lines, 4 words, 41 bytes)
printf 'alpha bravo charlie\n__SUBSET_GREP_LINE__\n' > "$TMPD/sentinel.txt"

# ---- 1. stage the tier-1 binaries + sweep data into the donor tree --
# h-prefix renaming: the guest's own binaries stay distinguishable from
# Harvey's under test.  tier1-sweep.rc and hello.c ride as DATA, as do
# the 06-06 committed fixed inputs (tiny.y/tiny.l/tiny.mk/nm-input.7 —
# nm-input.7 is a .7 OBJECT; mkrootall strips only file-identified
# executables, so an unstripped object rides through as data).
echo "== staging the tier-1 binaries + tier1-sweep.rc + fixed inputs into the donor tree (arm64/bin/subset/)"
if [ -n "$NATIVE_LINUX" ]; then
	# native leg: the donor tree is the host's own .build checkout —
	# stage in place (no lima, no rsync)
	mkdir -p "$DONOR/arm64/bin/subset"
	for f in $SUBSET_FLAT $SUBSET_CORE $SUBSET_CHAIN; do
		cp "$HARVEY/aarch64/bin/$f" "$DONOR/arm64/bin/subset/h$f"
	done
	cp "$HARVEY/aarch64/bin/ip/ipconfig" "$DONOR/arm64/bin/subset/hipconfig"
	cp "$HARVEY/aarch64/bin/auth/factotum" "$DONOR/arm64/bin/subset/hfactotum"
	cp "$HARVEY/aarch64/bin/awk" "$DONOR/arm64/bin/subset/hawk"
	cp "$HARVEY/build/aarch64/out/stacksmoke" "$DONOR/arm64/bin/subset/hstacksmoke"
	cp "$TMPD/sentinel.txt" "$DONOR/arm64/bin/subset/sentinel.txt"
	cp "$HARVEY/build/aarch64/tier1-sweep.rc" "$DONOR/arm64/bin/subset/tier1-sweep.rc"
	cp "$HARVEY/build/aarch64/hello.c" "$DONOR/arm64/bin/subset/hello.c"
	for f in $SUBSET_DATA; do
		cp "$HARVEY/build/aarch64/$f" "$DONOR/arm64/bin/subset/$f"
	done
	# 06-06 Task 2 (D-11): the canary's toolchain binaries
	for f in $SUBSET_SELFHOST; do
		cp "$HARVEY/aarch64/bin/$f" "$DONOR/arm64/bin/subset/h$f"
	done
	# 06-05: the tier-0 lib test binaries (D-06)
	for f in hdrawtest harctest htdraw hdisktest; do
		cp "$HARVEY/build/aarch64/out/$f" "$DONOR/arm64/bin/subset/$f"
	done
else
	ssh -F "$SSH_CFG" "$GUEST" "mkdir -p $GUEST_DONOR/arm64/bin/subset"
	for f in $SUBSET_FLAT $SUBSET_CORE $SUBSET_CHAIN; do
		rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/$f" "$GUEST:$GUEST_DONOR/arm64/bin/subset/h$f"
	done
	rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/ip/ipconfig" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hipconfig"
	rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/auth/factotum" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hfactotum"
	rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/awk" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hawk"
	rsync -a -e "$RSYNC_RSH" "$HARVEY/build/aarch64/out/stacksmoke" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hstacksmoke"
	rsync -a -e "$RSYNC_RSH" "$TMPD/sentinel.txt" "$GUEST:$GUEST_DONOR/arm64/bin/subset/sentinel.txt"
	rsync -a -e "$RSYNC_RSH" "$HARVEY/build/aarch64/tier1-sweep.rc" "$GUEST:$GUEST_DONOR/arm64/bin/subset/tier1-sweep.rc"
	rsync -a -e "$RSYNC_RSH" "$HARVEY/build/aarch64/hello.c" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hello.c"
	for f in $SUBSET_DATA; do
		rsync -a -e "$RSYNC_RSH" "$HARVEY/build/aarch64/$f" "$GUEST:$GUEST_DONOR/arm64/bin/subset/$f"
	done
	# 06-06 Task 2 (D-11): the canary's toolchain binaries
	for f in $SUBSET_SELFHOST; do
		rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/$f" "$GUEST:$GUEST_DONOR/arm64/bin/subset/h$f"
	done
	# 06-05: the tier-0 lib test binaries (D-06)
	for f in hdrawtest harctest htdraw hdisktest; do
		rsync -a -e "$RSYNC_RSH" "$HARVEY/build/aarch64/out/$f" "$GUEST:$GUEST_DONOR/arm64/bin/subset/$f"
	done
fi

# ---- 2. CONF bootdir patch (marker-guarded, self-healing) + rebake --
# the bootdir block: the h* binaries as /boot/h*, the sweep + canary
# source as data (text rides through mkrootall's executable strip).
cat > "$TMPD/subset-bootdir.txt" <<'EOF'
	/$objtype/bin/subset/hrc	hrc
	/$objtype/bin/subset/hgrep	hgrep
	/$objtype/bin/subset/hcat	hcat
	/$objtype/bin/subset/hcp	hcp
	/$objtype/bin/subset/hdate	hdate
	/$objtype/bin/subset/hecho	hecho
	/$objtype/bin/subset/hls	hls
	/$objtype/bin/subset/hmkdir	hmkdir
	/$objtype/bin/subset/hmv	hmv
	/$objtype/bin/subset/hps	hps
	/$objtype/bin/subset/hrm	hrm
	/$objtype/bin/subset/hsed	hsed
	/$objtype/bin/subset/htest	htest
	/$objtype/bin/subset/hwc	hwc
	/$objtype/bin/subset/hipconfig	hipconfig
	/$objtype/bin/subset/hfactotum	hfactotum
	/$objtype/bin/subset/hawk	hawk
	/$objtype/bin/subset/hstacksmoke	hstacksmoke
	/$objtype/bin/subset/sentinel.txt	sentinel.txt
	/$objtype/bin/subset/tier1-sweep.rc	tier1-sweep.rc
	/$objtype/bin/subset/hello.c	hello.c
	/$objtype/bin/subset/hdrawtest	hdrawtest
	/$objtype/bin/subset/harctest	harctest
	/$objtype/bin/subset/htdraw	htdraw
	/$objtype/bin/subset/hdisktest	hdisktest
	/$objtype/bin/subset/hbc	hbc
	/$objtype/bin/subset/hsort	hsort
	/$objtype/bin/subset/htr	htr
	/$objtype/bin/subset/huniq	huniq
	/$objtype/bin/subset/htail	htail
	/$objtype/bin/subset/hdd	hdd
	/$objtype/bin/subset/htar	htar
	/$objtype/bin/subset/hchmod	hchmod
	/$objtype/bin/subset/htee	htee
	/$objtype/bin/subset/hbasename	hbasename
	/$objtype/bin/subset/hsleep	hsleep
	/$objtype/bin/subset/hcmp	hcmp
	/$objtype/bin/subset/hcomm	hcomm
	/$objtype/bin/subset/hfmt	hfmt
	/$objtype/bin/subset/hjoin	hjoin
	/$objtype/bin/subset/hlook	hlook
	/$objtype/bin/subset/hpr	hpr
	/$objtype/bin/subset/hsplit	hsplit
	/$objtype/bin/subset/hstrings	hstrings
	/$objtype/bin/subset/hsum	hsum
	/$objtype/bin/subset/hmd5sum	hmd5sum
	/$objtype/bin/subset/hsha1sum	hsha1sum
	/$objtype/bin/subset/hed	hed
	/$objtype/bin/subset/hdc	hdc
	/$objtype/bin/subset/hunits	hunits
	/$objtype/bin/subset/hcal	hcal
	/$objtype/bin/subset/htouch	htouch
	/$objtype/bin/subset/htime	htime
	/$objtype/bin/subset/hseq	hseq
	/$objtype/bin/subset/hread	hread
	/$objtype/bin/subset/hdu	hdu
	/$objtype/bin/subset/hxd	hxd
	/$objtype/bin/subset/hnm	hnm
	/$objtype/bin/subset/hcpp	hcpp
	/$objtype/bin/subset/hmk	hmk
	/$objtype/bin/subset/hyacc	hyacc
	/$objtype/bin/subset/hlex	hlex
	/$objtype/bin/subset/tiny.y	tiny.y
	/$objtype/bin/subset/tiny.l	tiny.l
	/$objtype/bin/subset/tiny.mk	tiny.mk
	/$objtype/bin/subset/nm-input.7	nm-input.7
	/$objtype/bin/subset/h7a	h7a
	/$objtype/bin/subset/h7c	h7c
	/$objtype/bin/subset/h7l	h7l
	/$objtype/bin/subset/tiny.s	tiny.s
EOF

cat > "$TMPD/subset-ns-rebake.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# subset-ns-rebake.sh — rebake side of subset-exec.sh (self-re-entrant:
# wrap -> --ns -> --build, the run-gate.sh gate-ns-rebuild.sh shape).
# Lives in the guest's /tmp on darwin (never committed); on native
# linux the same script runs in the host's own namespace with
# DONOR/SCRATCH/DIST/BOOTDIR_TXT exported by the host driver.
set -eu

DONOR="${DONOR:-$HOME/9front-donor}"
SCRATCH="${DONOR_HOSTBIN:-$HOME/9front-hostbin}"
DIST="${DONOR_DIST:-$HOME/9front-dist}"
BOOTDIR_TXT="${BOOTDIR_TXT:-/tmp/gsd-subset-bootdir.txt}"

if [ "${1:-}" = "--build" ]; then
	set -eu
	PATH="$SCRATCH:$HARVEY_LINUX_BIN:$PLAN9/bin:$PATH"
	export PATH
	objtype=arm64
	export objtype
	FORCERCFORMK=1
	export FORCERCFORMK

	echo "== tier-1 rebake provenance (donor kernel relinked by Harvey's tools):"
	echo "   7c: $(command -v 7c)"
	echo "   7a: $(command -v 7a)"
	echo "   7l: $(command -v 7l)"
	echo "   ar: $(command -v ar)"
	echo "   mk: $(command -v mk)"

	cd /sys/src/9/arm64
	# force regeneration of everything derived from the CONF/bootdir:
	# mkdevc (qemu.c), mkrootall/mkrootc (root.s/rootc.c — the subset
	# embed), the link, and the uImage wrap. All other objects are
	# cached from the prior build.
	rm -f qemu.c qemu.7 qemu.root.s qemu.root.7 qemu.rootc.c qemu.rootc.7 9qemu 9qemu.u
	mk 'CONF=qemu'

	[ -s 9qemu ] && [ -s 9qemu.u ] || { echo "error: relink produced no kernel" >&2; exit 1; }
	mkdir -p "$DIST"
	cp 9qemu "$DIST/9qemu-subset"
	cp 9qemu.u "$DIST/9qemu-subset.u"
	echo "== tier-1 gate kernel assembled: $DIST/9qemu-subset{,.u}"
	exit 0
fi

if [ "${1:-}" = "--ns" ]; then
	set -u
	BUILD_USER="${2:?internal}"
	ENVFILE="${3:?internal}"
	. "$ENVFILE"

	[ -d "$DONOR/sys/src/9/arm64" ] || {
		echo "error: $DONOR does not look like the 9front donor checkout" >&2
		exit 1
	}

	mount --bind "$DONOR/sys" /sys
	mkdir -p /arm64
	mount --bind "$DONOR/arm64" /arm64
	mkdir -p /aarch64
	mount --bind "$DONOR/arm64" /aarch64
	mkdir -p /rc
	mount --bind "$DONOR/rc" /rc

	if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
	NSLIB=/tmp/subsetlib.$$
	mkdir -p "$NSLIB"
	cp -a "$LIBREAL"/. "$NSLIB/"
	cp -a "$DONOR/lib"/. "$NSLIB/" 2>/dev/null || true
	chown 0:0 "$NSLIB"
	chmod 1777 "$NSLIB"
	mount --bind "$NSLIB" "$LIBREAL"

	unwind() {
		umount "$LIBREAL" 2>/dev/null || true
		rm -rf "$NSLIB"
	}
	trap unwind EXIT

	set +e
	su -c ". '$ENVFILE'; bash '$0' --build" "$BUILD_USER"
	RC=$?
	exit $RC
fi

# wrap phase: repo user, devshell env (nix develop -c)
set -eu

CONF="$DONOR/sys/src/9/arm64/qemu"
# 06-05: the patch is ALWAYS applied — the self-healing awk drops every
# prior subset bootdir line before inserting the current block, so reruns
# converge from any state.  The old `grep -qF tier1-sweep.rc` skip-guard
# treated a stale (06-03-era) block as current and silently never landed
# newer members (observed 2026-11-05: the libtest h* lines missing at
# rebake → 'file does not exist' T1-FAIL libtest-*).
echo "== refreshing the tier-1 bootdir block in the donor-copy CONF=qemu (drop+insert, converges from any prior state)"
# self-healing (06-03): stale subset bootdir lines from ANY prior
# block version are dropped before the current block is inserted,
# so the patch converges from every prior state instead of
# duplicating.  (Guest scratch — the host .build donor checkout is
# only ever mutated by this disclosed patch class.)
awk -v bf="$BOOTDIR_TXT" '
	/\$objtype\/bin\/subset\// { next }
	/^bootdir$/ { inbd=1; print; next }
	inbd && /^[^ \t]/ {
		while ((getline l < bf) > 0) print l
		inbd=0; print; next
	}
	{ print }
	END {
		if (inbd)
			while ((getline l < bf) > 0) print l
	}
' "$CONF" > "$CONF.tier1"
mv "$CONF.tier1" "$CONF"
echo "== donor CONF bootdir now:"
sed -n '/^bootdir/,$p' "$CONF"

# assert the staged files (25 v1.0/06-03/06-05 + 37 h* 06-06 binaries +
# 4 06-06 data files + 3 canary h7* + tiny.s = 70).  NOTE: this runs
# inside the generated guest script — it must stay a LITERAL list (the
# host-side SUBSET_* variables are not exported across the ssh/
# namespace boundary; measured 2026-11-05: unbound-variable abort)
for f in hrc hgrep hcat hcp hdate hecho hls hmkdir hmv hps hrm hsed htest hwc hipconfig hfactotum hawk hstacksmoke hdrawtest harctest htdraw hdisktest sentinel.txt tier1-sweep.rc hello.c hbc hsort htr huniq htail hdd htar hchmod htee hbasename hsleep hcmp hcomm hfmt hjoin hlook hpr hsplit hstrings hsum hmd5sum hsha1sum hed hdc hunits hcal htouch htime hseq hread hdu hxd hnm hcpp hmk hyacc hlex tiny.y tiny.l tiny.mk nm-input.7 h7a h7c h7l tiny.s; do
	[ -s "$DONOR/arm64/bin/subset/$f" ] || {
		echo "error: staged tier-1 file missing: $DONOR/arm64/bin/subset/$f" >&2
		exit 1
	}
done

# 06-06: the donor kernel's devroot caps /boot at Nbootfiles=32
# (sys/src/9/port/devroot.c:13); the full tier-1 bootdir now embeds 70
# subset files (25 + 37 h* + 4 fixed inputs + 3 canary h7* + tiny.s —
# the literal assert list above is the source of truth), so the cap
# is raised in the donor-COPY tree (guest scratch — the same disclosed
# patch class as the CONF bootdir block; the donor is the execution
# venue, not the artifact under test, and the pin gate keys on HEAD,
# not the working tree).  Idempotent: the substitution normalizes any
# prior value, so a fresh clone converges on the next run.
DEVROOT="$DONOR/sys/src/9/port/devroot.c"
# plan9-dialect-safe in-place edit: the devshell's hostbin sed is
# Harvey's (Plan 9 dialect — no -i; measured 2026-11-05), so filter to
# a temp file and mv
sed 's/Nbootfiles = [0-9][0-9]*/Nbootfiles = 128/' "$DEVROOT" > "$DEVROOT.t1" && mv "$DEVROOT.t1" "$DEVROOT"
grep -q 'Nbootfiles = 128' "$DEVROOT" || {
	echo "error: donor devroot Nbootfiles raise did not land" >&2
	exit 1
}
echo "== donor devroot /boot cap raised to Nbootfiles=128 (70-entry tier-1 bootdir)"

mkdir -p "$DIST"
export DONOR SCRATCH DIST
EXPORTS=/tmp/subset-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m bash "$0" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
GUEST_EOF

if [ -n "$NATIVE_LINUX" ]; then
	echo "== targeted donor kernel rebake in the host's own namespace (log: $BUILDLOG)"
	mkdir -p "$DIST"
	export DONOR DIST
	export DONOR_HOSTBIN="${DONOR_HOSTBIN:-$HARVEY/.build/9front-hostbin}"
	export BOOTDIR_TXT="$TMPD/subset-bootdir.txt"
	set +e
	bash "$TMPD/subset-ns-rebake.sh" > "$BUILDLOG" 2>&1
	RC=$?
	set -e
	cat "$BUILDLOG"
	if [ $RC -ne 0 ]; then
		echo "error: native rebake failed (rc=$RC); log: $BUILDLOG" >&2
		echo "hint: the native leg needs a natively-built donor tree + host helpers" >&2
		echo "      (no provisioning driver exists for the native leg this era; darwin: donor-vm-build.sh)" >&2
		exit $RC
	fi
else
	rsync -a -e "$RSYNC_RSH" "$TMPD/subset-bootdir.txt" "$GUEST:/tmp/gsd-subset-bootdir.txt"
	rsync -a -e "$RSYNC_RSH" "$TMPD/subset-ns-rebake.sh" "$GUEST:/tmp/gsd-subset-ns-rebake.sh"

	echo "== targeted donor kernel rebake in the guest namespace (log: $BUILDLOG)"
	mkdir -p "$DIST"
	set +e
	ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c bash /tmp/gsd-subset-ns-rebake.sh" > "$BUILDLOG" 2>&1
	RC=$?
	set -e
	cat "$BUILDLOG"
	if [ $RC -ne 0 ]; then
		echo "error: guest rebake failed (rc=$RC); log: $BUILDLOG" >&2
		exit $RC
	fi

	echo "== pulling the tier-1 gate kernel back to $DIST"
	rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIST/9qemu-subset" "$GATE_K"
	rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIST/9qemu-subset.u" "$GATE_U"
fi
[ -s "$GATE_U" ] || err "$GATE_U missing/empty after the rebake leg"

# ---- 2b. the staged termrc override (D-10: sourced sweep, never typed)
# The override replaces the served rootfs's rc/bin/termrc for the run's
# duration; the cleanup trap restores it.  The override's tail execs
# the sourced sweep; init's restart loop then brings up the pass-2
# interactive rc that drive9's shell proof drives.  Self-heal: if a
# killed run left the override in place, restore the donor's file from
# the pristine donor checkout first (the dist assembly copies it
# verbatim — donor-ns-build.sh's srvroot step).
if [ -f "$ROOTFS/rc/bin/termrc" ] && "$GREP" -qF 'tier1-sweep.rc' "$ROOTFS/rc/bin/termrc"; then
	echo "== served termrc still carries a stranded 06-03 override — restoring the donor's first"
	cp "$DONOR/rc/bin/termrc" "$ROOTFS/rc/bin/termrc"
fi
cp "$ROOTFS/rc/bin/termrc" "$TERMRC_ORIG"
# TIER1_TERMCMD (diagnostic hook): when set, the staged override's tail
# execs it instead of the sweep — for gated boot diagnostics (06-03's
# awkprobe run used it).  Unset in all gate flows.
TERMCMD="${TIER1_TERMCMD:-. /boot/tier1-sweep.rc donor}"
cat > "$TMPD/tier1-termrc" <<TERMRC_EOF
#!/bin/rc
# 06-03 tier-1 gate termrc override — staged over the served rootfs's
# /rc/bin/termrc for the gate run's duration (subset-exec.sh restores
# it on exit).  trace-termrc precedent: the sweep is SOURCED, never
# typed per-binary (the donor's devcons fails /dev/cons reads by
# design; console input is kbdfs-served).  stacksmoke runs first so its
# marker evidences our staged binary before the sweep proper; the final
# exec sources the tier-1 sweep.  When the sweep's rc exits, init's
# restart loop (manual=1) brings up the interactive pass-2 rc — the
# driver's shell proof lands there.
/boot/hstacksmoke
s=\$status
if(~ \$s '') echo T1-OK stacksmoke
if(! ~ \$s '') echo T1-FAIL stacksmoke
exec rc -c '$TERMCMD'
TERMRC_EOF
cp "$TMPD/tier1-termrc" "$ROOTFS/rc/bin/termrc"
echo "== staged the tier-1 termrc override into the served rootfs (restored on exit)"

# ---- 3. boot (boot-9qemu.sh discipline) — the sweep runs at boot ----

# serve the root fs (9P2000) with the writable /tmp scratch unlocked
# for THIS gate only (see header)
echo "== serving $ROOTFS on 127.0.0.1:$SRV9_PORT (9P2000; writable prefixes /tmp, /usr/glenda/tmp)"
"$HARNESS_BIN" srv9 serve --root "$ROOTFS" --host 127.0.0.1 --port "$SRV9_PORT" \
	--writable-prefix /tmp --writable-prefix /usr/glenda/tmp \
	> "$TMPD/srv9.log" 2>&1 &
SRV9_PID=$!
# poll for the 'srv9: serving' line the Rust server prints after listen()
i=0
while ! "$GREP" -q 'srv9: serving' "$TMPD/srv9.log" 2>/dev/null; do
	i=$((i + 1))
	if [ $i -gt 60 ]; then
		cat "$TMPD/srv9.log" >&2 || true
		err "srv9 did not start listening on 127.0.0.1:$SRV9_PORT"
	fi
	if ! kill -0 "$SRV9_PID" 2>/dev/null; then
		cat "$TMPD/srv9.log" >&2 || true
		err "srv9 exited during startup"
	fi
	sleep 1
done

# dump the DTB with the -append baked in, then launch qemu PAUSED with
# it pre-placed at 0x40000000 (boot-9qemu.sh drift accommodation 1)
APPEND="bootargs=tcp fs=$SRV9_GUEST_IP user=glenda console=0"
DTB="$TMPD/virt.dtb"
"$QEMU_BIN" \
	-M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72 -m 1G \
	-kernel "$GATE_U" \
	-append "$APPEND" \
	-machine "dumpdtb=$DTB" -display none -S &
DUMPPID=$!
sleep 2
kill $DUMPPID 2>/dev/null || true
wait $DUMPPID 2>/dev/null || true
[ -s "$DTB" ] || err "qemu dumpdtb produced no DTB"

echo "== launching qemu (TCG; -M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72; kernel $GATE_U)"
"$QEMU_BIN" \
	-M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72 -accel tcg -smp 1 -m 1G \
	-kernel "$GATE_U" \
	-append "$APPEND" \
	-device "loader,file=$DTB,addr=0x40000000" \
	-netdev "user,id=n0,guestfwd=tcp:$SRV9_GUEST_IP:564-tcp:127.0.0.1:$SRV9_PORT" \
	-device virtio-net-pci-non-transitional,netdev=n0 \
	-chardev "socket,id=ser0,path=$TMPD/serial.sock,server=on,wait=off" \
	-serial chardev:ser0 \
	-qmp "unix:$TMPD/qmp.sock,server=on,wait=off" \
	-gdb "unix:$TMPD/gdb.sock,server=on,wait=off" \
	-S -display none \
	> "$TMPD/qemu.err" 2>&1 &
QEMU_PID=$!

sleep 2
if ! kill -0 "$QEMU_PID" 2>/dev/null; then
	cat "$TMPD/qemu.err" >&2 || true
	err "qemu exited during launch (see above)"
fi

# wake the GIC redistributor (boot-9qemu.sh drift accommodation 2)
if [ "${WAKE_POKE:-1}" != "0" ]; then
	"$HARNESS_BIN" gdbpoke9 --sock "$TMPD/gdb.sock" \
		--watch-file "$RUNLOG" --watch-str "bootargs is" \
		--deadline "$BOOT_BUDGET" \
		> "$TMPD/gdbpoke.log" 2>&1 &
	POKE_PID=$!
else
	POKE_PID=""
fi

# attach the capture BEFORE the guest runs, resume via QMP, drive the
# boot.  No --steps table (06-03, D-10): the sweep runs at boot via the
# staged termrc override — drive9's boot drive (bootargs answer, shell
# probe, term% prompt proof) lands on the pass-2 interactive rc that
# init's restart loop brings up after the sweep's exit.  The budget is
# the wedge watchdog: no shell within BOOT_BUDGET ⇒ the sweep wedged.
echo "== driving boot + tier-1 sourced sweep (budget ${BOOT_BUDGET}s; log: $RUNLOG)"
set +e
"$HARNESS_BIN" drive9 --serial "$TMPD/serial.sock" --qmp "$TMPD/qmp.sock" \
	--log "$RUNLOG" --budget "$BOOT_BUDGET"
RC=$?
set -e
if [ -n "$POKE_PID" ]; then
	wait "$POKE_PID" 2>/dev/null || true
	if [ -s "$TMPD/gdbpoke.log" ]; then
		"$GREP" -q 'poked' "$TMPD/gdbpoke.log" || {
			cat "$TMPD/gdbpoke.log" >&2
			err "GICR WAKER wake poke failed — redistributor asleep; see boot-9qemu.sh header drift note 2"
		}
	fi
fi
if [ $RC -ne 0 ]; then
	echo "error: tier-1 gate run failed within ${BOOT_BUDGET}s — last log lines:" >&2
	tail -n 40 "$RUNLOG" >&2 || true
	echo "hint: the guest log is the bisect surface (toolchain-first diagnostic rule):" >&2
	echo "      suspect our 7c/7l/libc/tier-1 binaries before the donor kernel" >&2
	# 06-03: the sweep runs guest-side regardless of the drive's fate —
	# report its full marker state for triage before exiting (a
	# userspace fault trips drive9's panic fast-fail but never stops
	# the sweep — USPACE-04's never-wedge edge)
	echo "== sweep marker state at failure:" >&2
	"$GREP" -oE 'T1-(OK|FAIL|SKIP) [A-Za-z0-9.-]+|T1-DONE' "$RUNLOG" >&2 || true
	exit 1
fi

# ---- 4. assertions (defense in depth; the driver already proved boot)
"$GREP" -qiE '9front|Plan 9' "$RUNLOG" || err "captured log lacks the 9front/Plan 9 banner"
"$GREP" -q 'term% ' "$RUNLOG" || err "captured log lacks the rc prompt signature"
"$GREP" -q 'stacksmoke: depth 64 ok' "$RUNLOG" || err "captured log lacks the stacksmoke marker"
# the tier-1 swept marker set (presence-based, never interleaving
# order — tier1-sweep.rc's check table is the source of truth).
# 06-06: the expected set is COMPUTED from the D-13 tier file (never a
# second hardcoded list to rot): every entry maps to its marker name
# (basename; dir:target maps to the target) EXCEPT the entries whose
# execution evidence lives elsewhere: 9k/boot + stage/init +
# cmd/paqfs:paqfs (BOOT:donor via the 05-03 real-chain trace — never
# swept by name) and cmd/7c cmd/7l cmd/cc (the D-11 canary markers —
# selfhost-compile/selfhost asserted beside the computed set; cmd/7a
# carries its own T1-OK 7a marker from the tiny.s assemble).  On the donor venue every
# member — including the write-flow and build-chain entries — is an
# ordinary expected-set member (T1-SKIP lines only exist for r9).
EXPECTED=$(
	awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/aarch64/tiers/tier1-cmds.txt" |
	while read -r e; do
		case "$e" in
		9k/boot|stage/init|cmd/paqfs:paqfs|cmd/7c|cmd/7l|cmd/cc) continue ;;
		stage/stacksmoke) echo stacksmoke; continue ;;
		esac
		e="${e#cmd/}"
		case "$e" in *:*) e="${e##*:}" ;; esac
		echo "${e##*/}"
	done
)
echo "== expected T1-OK marker set (computed from tier1-cmds.txt): $(echo $EXPECTED | wc -w | tr -d ' ') members + float-d01 + libtest ×2 + selfhost ×2"
for m in $EXPECTED float-d01 libtest-tdraw libtest-disktest selfhost-compile selfhost; do
	"$GREP" -q "T1-OK $m" "$RUNLOG" || err "captured log lacks T1-OK $m"
done
"$GREP" -q 'T1-DONE' "$RUNLOG" || err "captured log lacks T1-DONE (the sweep did not run to completion)"
# USPACE-04 honesty: a failing entry must red the gate (the sweep's
# never-wedge edge is about continuation, not about passing)
if "$GREP" -q 'T1-FAIL' "$RUNLOG"; then
	err "captured log contains a T1-FAIL line — a swept binary failed"
fi
if "$GREP" -qiE 'panic|trap:' "$RUNLOG"; then
	err "captured log contains a kernel fault line"
fi

echo "== PASS: the tier-1 set executed on the 9front donor kernel (T1-DONE; float canary 0.333 green); log: $RUNLOG"
