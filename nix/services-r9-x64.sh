# nix/services-r9-x64.sh — the r9-x64 SERVICES gate as a flake app
# (15-03, USPACE-07's r9 leg): the SAME composed pipeline as
# nix/tier1-r9-x64.sh (kernel contract → KERNDATE → userland build →
# bake → r9's iso-builder) but the bake carries the SERVICES payload
# (mkimage.sh's services section → out/bootfs-services.paq: the chain
# tree + the tier-1 h* helpers + the tier-2 services set computed from
# tiers/tier2-services.txt + the 14-09 net members + the sweep's
# /boot-side members + services-sweep.rc at /lib with the
# services-termrc override), and the launch runs under
# build/x86_64/services-r9.expect, which asserts the sweep's SVC
# marker contract against the serial wire and exits 0/1 for CI.
# tier1-r9-x64.sh's own behavior is untouched.
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/x86_64/stage-build.sh FIRST (mkimage's
#      input producer: the leg-1 marker pair + the boot chain — the
#      clean-checkout rule, 16-06's hosted-run discovery) then
#      build/x86_64/subset-build.sh (the tier driver:
#      tier-0 libs + tier-1 set + the tier-2 services set + the boot
#      chain, into /amd64 + out/; it holds the phase build-tree lock
#      .build/amd64-tree.lock itself — the 15-01 coupling contract vs
#      the same-wave 15-05/15-09 drivers, so parallel invocations
#      serialize on the lock and no unlocked /amd64 writer exists
#      anywhere in this gate).  Skip with R9_SKIP_BUILD=1 for iteration
#      — an escape hatch, NEVER the default; the GATE runs the default.
#   2. bake — build/x86_64/mkimage.sh (all five contracts, untouched)
#      → out/bootfs-services.paq (the SERVICES image this gate boots).
#   3. compose — r9's exported iso-builder (R9_ISO_BUILDER, the flake
#      input's packages.iso-builder: ONE reproducibility
#      implementation, D-05) builds the ISO from the pinned kernel-x64
#      + the services bake as /boot/bootfs.paq.
#   4. the gate — build/x86_64/services-r9.expect spawns qemu with the
#      composed ISO on -cdrom (q35, -nographic) and asserts: banner →
#      paqfs → version → the services sweep from the boot flow (the
#      services image's termrc runs it — no typed line) with the net
#      bring-up preceding the daemons → every subject's verdict →
#      SVC-DONE → the % prompt → the whole-capture post-pass (every
#      computed subject earned SVC-OK or its declared conditional
#      SVC-SKIP, the converse on every emitted SVC-SKIP, zero
#      SVC-FAIL, zero panic).  Markers are the ONLY proof — the
#      supervisor's exit status is never trusted.
#
# The expected marker sets are COMPUTED here (step 2b) from the
# committed tier data + the committed sweep script — never a second
# hardcoded list (the donor gate's compute_svc_expected discipline:
# each subject names the tier entry it rides, verified present;
# factotum rides its TIER-1 line; the declared SKIP set is grepped
# verbatim from the sweep's own echo lines).
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                      path; the flake app exports it from
#                      inputs.r9.packages.<system>.kernel-x64.
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY (the
#                      flake app exports <pkg>/bin/r9-iso-builder).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_SVC_LOG        default $HARVEY/build/x86_64/services-r9-x64.log
#                      (a gitignored transient — a passing copy lands
#                      in the phase dir's evidence/ as retained
#                      evidence by the plan's gate task).
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
# usage: nix run .#boot-r9-services-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# Resolve a host grep once (D-02): the marker-set computation needs
# -o/-E, which plan9 grep lacks — but a hardcoded /usr/bin/grep breaks
# on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

# --- step 0: the kernel-package + builder contract (same as smoke-r9-x64.sh)

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-services-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-services-x64), which exports r9's iso-builder script path"
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

# --- step 1: the amd64 userland (the TIER build — the services set) ----

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4a: stage the mkimage inputs (build/x86_64/stage-build.sh — the leg-1 marker pair smoke-out/{init,smokesleep} + the boot chain; mkimage's named producer, absent on a clean checkout: the 16-06 hosted-run discovery)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/4: amd64 tier build (build/x86_64/subset-build.sh — holds the phase build-tree lock itself)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake the bootfs images (the services bake is the payload) --

echo "== step 2/4: bake bootfs-services.paq (build/x86_64/mkimage.sh, the services section)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
SVC_PAQ="$HARVEY/build/x86_64/out/bootfs-services.paq"
[ -s "$SVC_PAQ" ] || err "$SVC_PAQ missing/empty after the bake (mkimage's services section)"

# --- step 2b: the expected marker sets (computed, never a second
#     hardcoded list — the donor gate's compute_svc_expected
#     discipline).  The OK set: the sweep's nine probe subjects, each
#     verified against the tier entry it rides (cmd/ndb is the
#     resolver pair's home — cs + dns are its probe subjects; factotum
#     rides its TIER-1 line, never a tier-2 member), minus every
#     SKIP-named member.  The declared SKIP set is extracted VERBATIM
#     from the committed services-sweep.rc's own `echo SVC-SKIP' lines
#     (the file is the source of truth — the sweep's skips are
#     CONDITIONAL, so this is the DECLARED set, not the expected
#     emitted set; the post-pass checks OK-or-emitted-declared-SKIP per
#     subject plus the converse on every emitted name). ---
SVC_T2="$HARVEY/build/x86_64/tiers/tier2-services.txt"
SVC_T1D="$HARVEY/build/x86_64/tiers/tier1-cmds.txt"
for e in cmd/mntgen cmd/ndb cmd/exportfs cmd/srv cmd/aux:listen cmd/auth/authsrv cmd/auth/keyfs; do
	"$GREP" -q "^${e}[[:space:]#]" "$SVC_T2" || err "svc expectation: tier-2 data lacks the probe-subject entry $e"
done
"$GREP" -q "^cmd/auth/factotum:factotum[[:space:]#]" "$SVC_T1D" || err "svc expectation: tier-1 data lacks cmd/auth/factotum:factotum (factotum rides its tier-1 line)"
# NOTE: `|| true` — the app wrapper runs `set -o pipefail` and grep
# exits 1 on ZERO matches (a sweep with no declared conditional SKIPs
# must compute an EMPTY set, not kill the driver).
SVC_SKIP=$({ "$GREP" -oE '(^|[[:space:]])echo SVC-SKIP [A-Za-z0-9.-]+' "$HARVEY/build/x86_64/services-sweep.rc" || true; } \
	| awk '{print $NF}' | sort -u | tr '\n' ' ')
SVC_OK_ALL="mntgen cs dns exportfs srv listen factotum keyfs authsrv"
SVC_OK=""
for m in $SVC_OK_ALL; do
	case " $SVC_SKIP" in
	*" $m "*) ;;
	*) SVC_OK="$SVC_OK $m" ;;
	esac
done
R9_EXPECT_SVC_OK="$SVC_OK"
R9_EXPECT_SVC_SKIP="$SVC_SKIP"
export R9_EXPECT_SVC_OK R9_EXPECT_SVC_SKIP
echo "== expected on r9: $(echo "$R9_EXPECT_SVC_OK" | wc -w | tr -d ' ') SVC-OK subjects + $(echo "$R9_EXPECT_SVC_SKIP" | wc -w | tr -d ' ') declared conditional SVC-SKIP names (computed)"

# --- step 3: compose the ISO -------------------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/services-r9-x64.XXXXXX")
# The per-run unique tag — exported so services-r9.expect adds it to
# qemu's argv (-name), and this run's survivor sweep (cleanup below)
# keys on it.  The sweep NEVER matches a kernel-name class.
R9_RUN_TAG="r9x64svc-$$-$(date +%s)"
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

echo "== step 3/4: composing the ISO (r9's iso-builder: kernel + bootfs-services.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$SVC_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 4: the expect-driven services gate ----------------------------

R9_SVC_LOG="${R9_SVC_LOG:-$HARVEY/build/x86_64/services-r9-x64.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence — it starts empty and only this run's boot writes it; the
# driver rm -f's it again belt-and-braces)
rm -f "$R9_SVC_LOG"

echo "== step 4/4: the services gate on r9 (build/x86_64/services-r9.expect)"
echo "== capture: $R9_SVC_LOG"

export R9_ISO R9_SVC_LOG R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/services-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "services r9-x64 gate FAILED (the driver named the stage on stderr; capture: $R9_SVC_LOG)"
fi
echo "== services r9-x64 gate PASS — capture retained at $R9_SVC_LOG"
exit 0
