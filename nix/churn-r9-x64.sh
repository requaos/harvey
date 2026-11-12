# nix/churn-r9-x64.sh — the 17-02 composed churn gate as a flake app
# (D-06 tier (b)): nix/smoke-r9-x64.sh's composed pipeline re-keyed
# onto the CHURN venue — NET-FREE by design (no doctor preflight, no
# netdev emitter, no host peer: the churn load touches no net device,
# so the tap/slirp machinery of the soak app has no role here).  The
# pipeline, each step loud on failure:
#
#   0. the flake contract: R9_KERNEL_X64_PKG + R9_ISO_BUILDER (the
#      14-07 contract) + accel selection (no silent downgrade, the
#      Phase-13 discipline).  The kernel package is the q35churnshell
#      build since this plan's r9-side re-point — the composed venue's
#      kernel carries the per-exit churngate heap marker through the
#      same dev_churn cfg gate as the r9-side tier (the bounded-memory
#      mechanism this gate's window post-pass consumes; the flag
#      assumption's PREFERRED arm, the choice recorded in the SUMMARY).
#   1. userland build — build/x86_64/stage-build.sh FIRST (mkimage's
#      input producer) then build/x86_64/subset-build.sh (the tier
#      driver: the chain binaries + test + dc ride /amd64/bin).  Skip
#      with R9_SKIP_BUILD=1 for iteration — an escape hatch, NEVER the
#      default; the GATE runs the default.
#   2. bake — build/x86_64/mkimage.sh → out/bootfs-churn.paq (the
#      CHURN bake, mkimage section 12: the chain tree + test + dc +
#      /lib/churn-cats.rc riding the committed skeleton — asserted
#      present below).
#   3. compose — r9's exported iso-builder (R9_ISO_BUILDER: ONE
#      reproducibility implementation) builds the ISO from the pinned
#      kernel-x64 + the churn bake as /boot/bootfs.paq.
#   4. the gate — build/x86_64/churn-r9.expect spawns qemu with the
#      composed ISO on -cdrom (q35, net-free), drives `rc
#      /lib/churn-cats.rc' (the /bin/cat x 1400 fork+exec churn at the
#      #44 repro shape), asserts every fixture marker, the exact-count
#      contract (one CATS-DONE 1400), zero churn: FAIL, and the
#      bounded-memory window (the per-exit heap markers between BEFORE
#      and AFTER, the delta over the window's exit count against the
#      committed bound), and fails wedge-stalls LOUD with the capture
#      tail.
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                      path; the flake app exports it.
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY.
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_CHURN_LOG      default $HARVEY/build/x86_64/churn-r9.log (a
#                      gitignored transient; green runs retain per-run
#                      copies as evidence).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                      downgrade.
#   R9_CPU            override the cpu model (default: host under kvm,
#                      qemu64 under tcg).
#   KERNDATE          pinned-build timestamp override; derived from
#                      the HARVEY checkout's git log otherwise.
#
# Hygiene: the capture is rm -f'd BEFORE launch; the expect driver
# kills qemu's process group on every exit path; THIS script's EXIT
# trap sweeps any qemu survivor via a bracket-fixed pkill keyed on
# this run's unique R9_RUN_TAG (exported below; the driver adds it to
# qemu's argv as -name).  The tag's r9x64churn- prefix differs from
# every sibling gate's (r9x64smoke-, r9x64tier1-, r9x64net-,
# r9x64soak-) so the sweeps can never cross-kill.
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, git, expect, procps (the survivor
# sweep's pkill) always; util-linux+gnused+mount+binutils on linux
# (the namespace build's transport).  Standalone use needs the same
# tools on PATH.
#
# usage: nix run .#boot-r9-churn-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the flake contract + accel selection ------------------------

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-churn-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-churn-x64), which exports r9's iso-builder script path"
[ -f "$R9_ISO_BUILDER" ] && [ -x "$R9_ISO_BUILDER" ] \
	|| err "R9_ISO_BUILDER $R9_ISO_BUILDER: not an executable file (want <pkg>/bin/r9-iso-builder)"

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
echo "   shape:       q35 accel=$R9_ACCEL cpu=$R9_CPU net-free (the churn venue)"

# --- run scratch + survivor sweep trap -----------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/churn-r9-x64.XXXXXX")
R9_RUN_TAG="r9x64churn-$$-$(date +%s)"
export R9_RUN_TAG
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills qemu's process group on every exit path;
	# this trap sweeps any survivor keyed on THIS run's unique tag
	pkill -f "[q]emu-system-x86_64.*${R9_RUN_TAG}" 2>/dev/null || true
	rm -rf "$TMPD"
	exit "$status"
}
trap cleanup EXIT

# --- provenance (KERNDATE; the boot-r9-x64.sh discipline) ---------------

if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! echo "$KERNDATE" | grep -qE '^[0-9]+$'; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the amd64 userland (the chain + test/dc) -------------------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4a: stage the mkimage inputs (build/x86_64/stage-build.sh)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/4: amd64 tier build (build/x86_64/subset-build.sh — the chain binaries + test + dc)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake the CHURN image ----------------------------------------

echo "== step 2/4: bake bootfs-churn.paq (build/x86_64/mkimage.sh, section 12)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
CHURN_PAQ="$HARVEY/build/x86_64/out/bootfs-churn.paq"
[ -s "$CHURN_PAQ" ] || err "$CHURN_PAQ missing/empty after the bake (mkimage's churn section)"

# --- step 3: compose the ISO ---------------------------------------------

echo "== step 3/4: composing the ISO (r9's iso-builder: kernel + bootfs-churn.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$CHURN_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 4: the expect-driven churn gate ---------------------------------

R9_CHURN_LOG="${R9_CHURN_LOG:-$HARVEY/build/x86_64/churn-r9.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence — it starts empty and only this run's boot writes it; the
# driver rm -f's it again belt-and-braces)
rm -f "$R9_CHURN_LOG"

echo "== step 4/4: the churn gate (build/x86_64/churn-r9.expect — /bin/cat x 1400 via rc /lib/churn-cats.rc, the bounded-memory window)"
echo "== capture: $R9_CHURN_LOG"

export R9_ISO R9_CHURN_LOG R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/churn-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "churn gate FAILED (the driver named the stage + printed the capture tail; capture: $R9_CHURN_LOG)"
fi
echo "== churn gate PASS — capture retained at $R9_CHURN_LOG"
exit 0
