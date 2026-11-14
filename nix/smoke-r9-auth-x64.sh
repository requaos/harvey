# nix/smoke-r9-auth-x64.sh — the composed AUTH gate as a flake app
# (18-04, AUTH-04/D-08 + AUTH-01's bake arm + the AUTH-05/07
# substrate — the net-smoke-x64 lineage): the SAME composed pipeline
# as nix/smoke-r9-net-x64.sh (kernel contract → KERNDATE → userland
# build → bake → r9's iso-builder) but the bake carries the AUTH
# payload (mkimage.sh's auth section §14 → out/bootfs-auth.paq: the
# chain tree + the auth-suite set computed from the tier data + the
# bake-time p9sk1 domain from authdomain-gen — invoked AT BAKE with
# the D-02 pairing assert over the staged copies) and the launch runs
# under build/x86_64/smoke-r9-auth.expect, which boots the image to
# the auth bring-up sweep (auth-termrc → `rc /lib/auth-sweep.rc r9',
# no typed legs) and asserts: the D-02 boot pairing banner with the
# DEMO label, keyfs's NON-interactive start (`N keys read', the
# nvram= env path), the sweep's AUTH-OK verdicts + AUTH-DONE, the
# never-appears post-pass for the exact getpass string, and zero
# AUTH-FAIL — and exits 0/1 for CI.  smoke-r9-net-x64's behavior is
# untouched (app-per-gate, one-image-per-gate — 14-06).
#
# VENUE + NETDEV (16-06's mechanism, carried): the venue stays FIXED
# slirp — hermetic, unprivileged, CI-able — and the qemu netdev+device
# argv flows from the SAME pinned TOML data the boot app consumes
# (R9_NETDEV_EMITTER captured once below, exported as R9_NETDEV_ARGV
# for the expect driver to split) with the D-04 hostfwd pair included:
# host 5670 -> guest 567 (the authsrv listener's Phase-19 drawterm
# entry — the gate observes the host-side listener from Task 2 on,
# 16-D-04 landing on a real listener day one, D-09).
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/x86_64/stage-build.sh FIRST (mkimage's
#      input producer) then build/x86_64/subset-build.sh, the tier
#      driver (objtype=amd64: the tier-0 libs + the tier-1 set + the
#      boot chain + the tier-2 auth suite incl. the 18-04 listen1
#      leaf).  Linux-native only (unshare; no lima leg on x64).  Skip
#      with R9_SKIP_BUILD=1 for iteration — an escape hatch, NEVER the
#      default; the GATE runs the default.
#   2. bake — build/x86_64/mkimage.sh → out/bootfs-auth.paq (the AUTH
#      image this gate boots; authdomain-gen is invoked INSIDE the
#      bake with the host cc — the app's runtimeInputs carry
#      stdenv.cc for exactly that; every other bake contract rides
#      along, untouched).
#   3. compose — r9's exported iso-builder (R9_ISO_BUILDER, the flake
#      input's packages.iso-builder: ONE reproducibility
#      implementation, D-05) builds the ISO from the pinned kernel-x64
#      + the auth bake as /boot/bootfs.paq.
#   4. the gate — build/x86_64/smoke-r9-auth.expect spawns qemu with
#      the composed ISO on -cdrom (q35, -nographic, the emitter's
#      slirp argv) and asserts the sweep's marker contract (see the
#      expect file's header).  Markers are the ONLY proof — the
#      supervisor's exit status is never trusted.
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                      path; the flake app exports it from
#                      inputs.r9.packages.<system>.kernel-x64.
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY (the
#                      flake app exports <pkg>/bin/r9-iso-builder).
#   R9_NETDEV_EMITTER REQUIRED — r9's netdev-args emitter bin (the
#                      flake input's packages.netdev-args); the flake
#                      app exports it.  This gate's slirp netdev+device
#                      argv comes ONLY from its output (D-05: the D-04
#                      hostfwd pair is pinned TOML data, never script
#                      text), captured once and exported to the driver
#                      as R9_NETDEV_ARGV.
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_AUTH_LOG       default $HARVEY/build/x86_64/auth-r9.log (a
#                      gitignored transient; the twice-green gate runs
#                      set per-run paths and retain BOTH captures in
#                      the phase dir's evidence/).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                      downgrade (the Phase-13 discipline).
#   R9_CPU            override the cpu model (default: host under kvm,
#                      qemu64 under tcg).
#   KERNDATE          pinned-build timestamp override; derived from
#                      the HARVEY checkout's git log otherwise.
#
# Hygiene: the capture is rm -f'd BEFORE launch (a pre-seeded stale log
# cannot pass — it starts empty and only this run's boot writes it);
# the expect driver kills qemu's process group on every exit path;
# THIS script's EXIT trap sweeps any survivor via a bracket-fixed
# pkill keyed on this run's unique R9_RUN_TAG (exported below; the
# driver adds it to qemu's argv as -name) — never a kernel-name class,
# so a foreign r9 qemu (a dev's interactive boot-r9-x64, a parallel CI
# job, a SIBLING gate) is never matched.  The '[q]emu…' pattern cannot
# self-match the harness shell's or pkill's own argv.  The r9x64auth-
# prefix differs from smoke-r9-x64.sh's r9x64smoke-, tier1's
# r9x64tier1-, the net gate's r9x64net-, and the services gate's own
# prefix so the gates' survivor sweeps can never cross-kill (the
# sibling-gate no-cross-kill rule).
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, git, expect, iproute2 (the driver's
# `exec ss'), procps (the pkill sweep) always; stdenv.cc (the
# authdomain-gen host build INSIDE the bake — the 18-03 vendored-donor
# venue's one dependency); util-linux+gnused+mount+binutils on linux
# (the namespace build's transport).  Standalone use needs the same
# tools on PATH (and PLAN9 exported — the 14-07 documented standalone
# contract).
#
# usage: nix run .#boot-r9-auth-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the kernel-package + builder contract (same as smoke-r9-net-x64.sh)

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-auth-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-auth-x64), which exports r9's iso-builder script path"
[ -f "$R9_ISO_BUILDER" ] && [ -x "$R9_ISO_BUILDER" ] \
	|| err "R9_ISO_BUILDER $R9_ISO_BUILDER: not an executable file (want <pkg>/bin/r9-iso-builder — a directory here means the app exported the package root, or the pin predates r9's iso-builder export)"

# the netdev argv source — the emitter contract check mirrors
# R9_ISO_BUILDER's -f/-x shape (the 16-04 boot app's idiom)
[ -n "${R9_NETDEV_EMITTER:-}" ] || err "R9_NETDEV_EMITTER unset — run via the flake app (nix run .#boot-r9-auth-x64), which exports r9's netdev-args emitter path (a pin predating the 16-04 advance lacks the export)"
[ -f "$R9_NETDEV_EMITTER" ] && [ -x "$R9_NETDEV_EMITTER" ] \
	|| err "R9_NETDEV_EMITTER $R9_NETDEV_EMITTER: not an executable file (want <pkg>/bin/r9-netdev-args)"

# --- step 0b: accel selection (no silent downgrade) --------------------

R9_ACCEL="${R9_ACCEL:-kvm}"
case "$R9_ACCEL" in
	kvm)
		[ -e /dev/kvm ] || err "/dev/kvm absent and R9_ACCEL=$R9_ACCEL — no silent downgrade: set R9_ACCEL=tcg explicitly for the TCG fallback (the Phase-13 discipline)"
		R9_CPU="${R9_CPU:-host}"
		;;
	tcg)
		R9_CPU="${R9_CPU:-qemu64}"
		;;
	*) err "R9_ACCEL=$R9_ACCEL: want kvm|tcg" ;;
esac

# --- step 0c: the netdev argv — the emitter's slirp tokens (16-06) -------

# The venue stays FIXED slirp (the net gate's own D-02 note carried);
# the argv flows from the same pinned TOML data the boot app consumes,
# the D-04 hostfwd pair (host 5670 -> guest 567) included — Phase 19's
# drawterm dials this seam and the gate's hostfwd stage observes its
# host side from Task 2 on.  Resolved ONCE here, before any build
# spend, so an emitter failure is a named contract error — and
# exported as R9_NETDEV_ARGV for the expect driver to split.

# shellcheck disable=SC2312  # the rc rides the ||: an emitter failure is a named contract error (its stderr passed through above)
NETDEV_ARGV=$("$R9_NETDEV_EMITTER" --mode slirp) \
	|| err "the netdev emitter failed for mode slirp (its diagnostics are above; the argv comes only from the pinned r9 TOML — D-05)"
[ -n "$NETDEV_ARGV" ] || err "the netdev emitter printed no netdev argv for mode slirp"
export R9_NETDEV_ARGV="$NETDEV_ARGV"

echo "== r9 kernel package: $R9_KERNEL_X64_PKG"
echo "   kernel:        $R9_KERNEL"
echo "   iso-builder:   $R9_ISO_BUILDER"
echo "   netdev emitter: $R9_NETDEV_EMITTER"
echo "   netdev argv (slirp): $NETDEV_ARGV"
echo "   shape:         q35 accel=$R9_ACCEL cpu=$R9_CPU"

# --- provenance (KERNDATE; the boot-r9-x64.sh discipline) --------------

if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the amd64 userland (the tier build + its auth suite) ------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4a: stage the mkimage inputs (build/x86_64/stage-build.sh — the leg-1 marker pair + the boot chain; mkimage's named producer)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/4: amd64 tier build (build/x86_64/subset-build.sh — the tier-2 auth suite rides the tier data)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake the bootfs images (the auth bake is the payload) ------

echo "== step 2/4: bake bootfs-auth.paq (build/x86_64/mkimage.sh, the auth section — authdomain-gen invoked at bake with the D-02 pairing assert)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
AUTH_PAQ="$HARVEY/build/x86_64/out/bootfs-auth.paq"
[ -s "$AUTH_PAQ" ] || err "$AUTH_PAQ missing/empty after the bake (mkimage's auth section)"

# --- step 3: compose the ISO -------------------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/smoke-r9-auth-x64.XXXXXX")
# The per-run unique tag — exported so smoke-r9-auth.expect adds it to
# qemu's argv (-name), and this run's survivor sweep (cleanup below)
# keys on it.  The sweep NEVER matches a kernel-name class: a foreign
# r9 qemu (a dev's interactive boot-r9-x64 uses the same kernel; a
# parallel CI job on a shared runner; the SIBLING gates' qemu) must
# never be killed by this gate's teardown.  The r9x64auth- prefix
# differs from the sibling x64 gates' tags for exactly that reason.
R9_RUN_TAG="r9x64auth-$$-$(date +%s)"
export R9_RUN_TAG
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills qemu's process group on every exit path;
	# this trap sweeps any survivor.  the pattern is bracket-fixed
	# ([q]emu) so pkill cannot self-match this shell's or its own argv,
	# and keyed on THIS run's unique -name tag — never on the
	# kernel-path class.
	pkill -f "[q]emu-system-x86_64.*${R9_RUN_TAG}" 2>/dev/null || true
	rm -rf "$TMPD"
	exit "$status"
}
trap cleanup EXIT

echo "== step 3/4: composing the ISO (r9's iso-builder: kernel + bootfs-auth.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$AUTH_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 4: the expect-driven composed auth gate ------------------------

R9_AUTH_LOG="${R9_AUTH_LOG:-$HARVEY/build/x86_64/auth-r9.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence — it starts empty and only this run's boot writes it; the
# driver rm -f's it again belt-and-braces)
rm -f "$R9_AUTH_LOG"

echo "== step 4/4: composed auth gate (build/x86_64/smoke-r9-auth.expect)"
echo "== capture: $R9_AUTH_LOG"

export R9_ISO R9_SMOKE_LOG="$R9_AUTH_LOG" R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/smoke-r9-auth.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "composed auth gate FAILED (the driver named the stage on stderr; capture: $R9_AUTH_LOG)"
fi
echo "== composed auth gate PASS — capture retained at $R9_AUTH_LOG"
exit 0
