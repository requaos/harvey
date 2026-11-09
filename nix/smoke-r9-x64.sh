# nix/smoke-r9-x64.sh — the COMPOSED smoke gate as a flake app (14-07,
# XEXEC-03): the SAME composed pipeline as nix/boot-r9-x64.sh (kernel
# contract → KERNDATE → userland build → bake → r9's iso-builder) but
# launched under build/x86_64/smoke-r9.expect, which drives the full
# command sweep against the serial wire and exits 0/1 for CI.
# boot-r9-x64's own behavior is untouched.
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/x86_64/stage-build.sh, the 14-05/14-06
#      namespace driver (objtype=amd64: the marker set + the boot-chain
#      binaries + the 14-07 sweep set ls/cat/echo/ps, harvested to
#      out/).  Linux-native only (unshare; no lima leg on x64).  Skip
#      with R9_SKIP_BUILD=1 for iteration — an escape hatch, NEVER the
#      default; the GATE runs the default (always build).
#   2. bake — build/x86_64/mkimage.sh → out/bootfs.paq (the leg-1
#      marker image, contract untouched) AND out/bootfs-chain.paq (the
#      CHAIN image with the sweep set this gate drives).
#   3. compose — r9's exported iso-builder (R9_ISO_BUILDER, the flake
#      input's packages.iso-builder: ONE reproducibility
#      implementation, D-05) builds the ISO from the pinned kernel-x64
#      + the chain bake as /boot/bootfs.paq.
#   4. smoke — build/x86_64/smoke-r9.expect spawns qemu with the
#      composed ISO on -cdrom (q35, -nographic) and asserts: banner →
#      paqfs/version (boot(8)'s prints) → the %  prompt → echo
#      round-trip → empty-line safety → ls /bin subset → ps → cat
#      /lib/namespace → DEL safety → exit → init restart → the
#      whole-capture post-passes.  Markers are the ONLY proof — the
#      supervisor's exit status is never trusted.
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                     path (the flake app exports it from
#                     inputs.r9.packages.<system>.kernel-x64).
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY (the
#                     flake app exports <pkg>/bin/r9-iso-builder).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_SMOKE_LOG      default $HARVEY/build/x86_64/smoke-r9.log (a
#                     gitignored transient; the twice-green gate run
#                     sets per-run paths and retains BOTH captures as
#                     evidence).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                     downgrade (the Phase-13 discipline).
#   R9_CPU            override the cpu model (default: host under kvm,
#                     qemu64 under tcg).
#   KERNDATE          pinned-build timestamp override; derived from
#                     the HARVEY checkout's git log otherwise.
#
# Hygiene: the capture is rm -f'd BEFORE launch (a pre-seeded stale log
# cannot pass — it starts empty and only this run's boot writes it);
# the expect driver kills qemu's process group on every exit path;
# THIS script's EXIT trap sweeps any survivor via a bracket-fixed
# pkill keyed on this run's unique R9_RUN_TAG (exported below; the
# driver adds it to qemu's argv as -name) — never a kernel-name class,
# so a foreign r9 qemu (a dev's interactive boot-r9-x64, a parallel CI
# job) is never matched.  The '[q]emu…' pattern cannot self-match the
# harness shell's or pkill's own argv.
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, git, expect always; util-linux+
# gnused+mount+binutils on linux (the namespace build's transport).
# Standalone use needs the same tools on PATH (and PLAN9 exported).
#
# usage: nix run .#boot-r9-smoke-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the kernel-package + builder contract (same as boot-r9-x64.sh)

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-smoke-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-smoke-x64), which exports r9's iso-builder script path"
[ -f "$R9_ISO_BUILDER" ] && [ -x "$R9_ISO_BUILDER" ] \
	|| err "R9_ISO_BUILDER $R9_ISO_BUILDER: not an executable file (want <pkg>/bin/r9-iso-builder — a directory here means the app exported the package root, or the pin predates r9's iso-builder export)"

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

echo "== r9 kernel package: $R9_KERNEL_X64_PKG"
echo "   kernel:      $R9_KERNEL"
echo "   iso-builder: $R9_ISO_BUILDER"
echo "   shape:       q35 accel=$R9_ACCEL cpu=$R9_CPU"

# --- provenance (KERNDATE; the boot-r9-x64.sh discipline) --------------

if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the amd64 userland ---------------------------------------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4: amd64 userland build (build/x86_64/stage-build.sh)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "userland build failed"
fi

# --- step 2: bake the bootfs images ------------------------------------

echo "== step 2/4: bake bootfs.paq + bootfs-chain.paq (build/x86_64/mkimage.sh)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
CHAIN_PAQ="$HARVEY/build/x86_64/out/bootfs-chain.paq"
[ -s "$CHAIN_PAQ" ] || err "$CHAIN_PAQ missing/empty after the bake (mkimage's chain section)"

# --- step 3: compose the ISO -------------------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/smoke-r9-x64.XXXXXX")
# The per-run unique tag — exported so smoke-r9.expect adds it to
# qemu's argv (-name), and this run's survivor sweep (cleanup below)
# keys on it.  The sweep NEVER matches a kernel-name class: a foreign
# r9 qemu (a dev's interactive boot-r9-x64 uses the same kernel; a
# parallel CI job on a shared runner) must never be killed by this
# gate's teardown.
R9_RUN_TAG="r9x64smoke-$$-$(date +%s)"
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

echo "== step 3/4: composing the ISO (r9's iso-builder: kernel + bootfs-chain.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$CHAIN_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 4: the expect-driven smoke ------------------------------------

R9_SMOKE_LOG="${R9_SMOKE_LOG:-$HARVEY/build/x86_64/smoke-r9.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence — it starts empty and only this run's boot writes it; the
# driver rm -f's it again belt-and-braces)
rm -f "$R9_SMOKE_LOG"

echo "== step 4/4: smoke (build/x86_64/smoke-r9.expect)"
echo "== capture: $R9_SMOKE_LOG"

export R9_ISO R9_SMOKE_LOG R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/smoke-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "smoke FAILED (the driver named the stage on stderr; capture: $R9_SMOKE_LOG)"
fi
echo "== smoke PASS — capture retained at $R9_SMOKE_LOG"
exit 0
