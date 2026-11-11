# nix/tier1-r9-x64.sh — the r9-x64 tier-1 gate as a flake app (14-08,
# XEXEC-04): the SAME composed pipeline as nix/smoke-r9-x64.sh (kernel
# contract → KERNDATE → userland build → bake → r9's iso-builder) but
# the build is the TIER build (build/x86_64/subset-build.sh), the bake
# carries the TIER payload (mkimage.sh's tier section →
# out/bootfs-tier.paq), and the launch runs under
# build/x86_64/tier1-r9.expect, which asserts the sweep's marker set
# against the serial wire and exits 0/1 for CI.  smoke-r9-x64's own
# behavior is untouched.
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/x86_64/stage-build.sh FIRST (mkimage's
#      input producer: the leg-1 marker pair + the boot chain — the
#      clean-checkout rule, 16-06's hosted-run discovery) then
#      build/x86_64/subset-build.sh, the tier driver
#      (objtype=amd64: the tier-0 libs + the tier-1 set + the boot
#      chain, into /amd64 + out/).  Linux-native only (unshare; no
#      lima leg on x64).  Skip with R9_SKIP_BUILD=1 for iteration — an
#      escape hatch, NEVER the default; the GATE runs the default.
#   2. bake — build/x86_64/mkimage.sh → out/bootfs.paq (untouched
#      contract) AND out/bootfs-chain.paq AND out/bootfs-tier.paq (the
#      TIER image this gate boots: the chain tree + the h* sweep set +
#      /lib/tier1-sweep.rc + the fixed inputs; the tier bake verifies
#      the donor venue's witness manifest when present — the
#      identical-6.outs ABI witness, one binary set, both kernels).
#   3. compose — r9's exported iso-builder (R9_ISO_BUILDER, the flake
#      input's packages.iso-builder: ONE reproducibility
#      implementation, D-05) builds the ISO from the pinned kernel-x64
#      + the tier bake as /boot/bootfs.paq.
#   4. the gate — build/x86_64/tier1-r9.expect spawns qemu with the
#      composed ISO on -cdrom (q35, -nographic) and asserts: banner →
#      paqfs → version → the sweep from the boot flow (the tier
#      image's termrc runs it — no typed line) with the float canary
#      T1-OK float-d01 (D-01: user SSE proven on BOTH kernels) →
#      T1-DONE → the % prompt → the whole-capture post-pass (every
#      expected T1-OK, the T1-SKIP set EQUAL to the sweep's own
#      declared list, zero T1-FAIL, zero panic).  Markers are the ONLY
#      proof — the supervisor's exit status is never trusted.
#
# The expected marker sets are COMPUTED here (step 2b) from the
# committed tier data + the committed sweep script — never a second
# hardcoded list (the aarch64 gate's rule, carried).
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                      path; the flake app exports it from
#                      inputs.r9.packages.<system>.kernel-x64.
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY (the
#                      flake app exports <pkg>/bin/r9-iso-builder).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_TIER1_LOG      default $HARVEY/build/x86_64/tier1-r9-x64.log (a
#                      gitignored transient — a passing copy lands in
#                      the phase dir's evidence/ as retained evidence
#                      by the plan's gate task).
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
# job) is never matched.  The '[q]emu…' pattern cannot self-match the
# harness shell's or pkill's own argv.
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, git, expect always; util-linux+
# gnused+mount+binutils on linux (the namespace build's transport).
# Standalone use needs the same tools on PATH (and PLAN9 exported).
#
# usage: nix run .#boot-r9-tier1-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# Resolve a host grep once (D-02): the marker-set computation needs
# -o/-E, which plan9 grep lacks — but a hardcoded /usr/bin/grep breaks
# on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

# --- step 0: the kernel-package + builder contract (same as smoke-r9-x64.sh)

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-tier1-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-tier1-x64), which exports r9's iso-builder script path"
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

# --- step 1: the amd64 userland (the TIER build) ------------------------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4a: stage the mkimage inputs (build/x86_64/stage-build.sh — the leg-1 marker pair smoke-out/{init,smokesleep} + the boot chain; mkimage's named producer, absent on a clean checkout: the 16-06 hosted-run discovery)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/4: amd64 tier build (build/x86_64/subset-build.sh)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake the bootfs images (the tier bake is the payload) ------

echo "== step 2/4: bake bootfs-tier.paq (build/x86_64/mkimage.sh, the tier section)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
TIER_PAQ="$HARVEY/build/x86_64/out/bootfs-tier.paq"
[ -s "$TIER_PAQ" ] || err "$TIER_PAQ missing/empty after the bake (mkimage's tier section)"

# --- step 2b: the expected marker sets (computed, never a second
#     hardcoded list — the aarch64 gate's rule, carried).  The OK set:
#     tier entries map to marker names (basename; dir:target -> target)
#     minus the driver-only members minus every SKIP-named member (the
#     donor-guarded legs emit T1-SKIP on r9) plus the mandatory float
#     canary.  The SKIP set is extracted VERBATIM from the committed
#     tier1-sweep.rc's SKIP lines (the file is the source of truth). ---
# NOTE: `|| true` — the app wrapper runs `set -o pipefail`, and grep
# exits 1 on ZERO matches: the 15-03 SKIP-flip emptied the sweep's SKIP
# block (ipconfig + factotum run live), and the bare pipeline killed
# the driver silently between the bake and the expectations print.
T1_SKIP=$({ "$GREP" -oE '(^|[[:space:]])echo T1-SKIP [A-Za-z0-9.-]+' "$HARVEY/build/x86_64/tier1-sweep.rc" || true; } \
	| awk '{print $NF}' | sort -u | tr '\n' ' ')
T1_OK_ALL=$(
	awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/x86_64/tiers/tier1-cmds.txt" |
	while read -r e; do
		case "$e" in
		9k/boot|stage/*|cmd/paqfs:paqfs|cmd/cc) continue ;;
		esac
		e="${e#cmd/}"
		case "$e" in *:*) e="${e##*:}" ;; esac
		echo "${e##*/}"
	done | sort -u | tr '\n' ' '
)
# drop every SKIP-named member from the OK set (the donor-guarded
# members emit T1-SKIP on r9, not T1-OK)
T1_OK=""
for m in $T1_OK_ALL; do
	case " $T1_SKIP" in
	*" $m "*) ;;
	*) T1_OK="$T1_OK $m" ;;
	esac
done
R9_EXPECT_OK="$T1_OK float-d01"
R9_EXPECT_SKIP="$T1_SKIP"
export R9_EXPECT_OK R9_EXPECT_SKIP
echo "== expected on r9: $(echo "$R9_EXPECT_OK" | wc -w | tr -d ' ') T1-OK markers + $(echo "$R9_EXPECT_SKIP" | wc -w | tr -d ' ') T1-SKIP markers (computed)"

# --- step 3: compose the ISO -------------------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/tier1-r9-x64.XXXXXX")
# The per-run unique tag — exported so tier1-r9.expect adds it to
# qemu's argv (-name), and this run's survivor sweep (cleanup below)
# keys on it.  The sweep NEVER matches a kernel-name class.
R9_RUN_TAG="r9x64tier1-$$-$(date +%s)"
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

echo "== step 3/4: composing the ISO (r9's iso-builder: kernel + bootfs-tier.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$TIER_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 4: the expect-driven tier-1 gate ------------------------------

R9_TIER1_LOG="${R9_TIER1_LOG:-$HARVEY/build/x86_64/tier1-r9-x64.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence — it starts empty and only this run's boot writes it; the
# driver rm -f's it again belt-and-braces)
rm -f "$R9_TIER1_LOG"

echo "== step 4/4: the tier-1 gate on r9 (build/x86_64/tier1-r9.expect)"
echo "== capture: $R9_TIER1_LOG"

export R9_ISO R9_TIER1_LOG R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/tier1-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "tier-1 r9-x64 gate FAILED (the driver named the stage on stderr; capture: $R9_TIER1_LOG)"
fi
echo "== tier-1 r9-x64 gate PASS — capture retained at $R9_TIER1_LOG"
exit 0
