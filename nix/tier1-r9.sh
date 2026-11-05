# nix/tier1-r9.sh — the r9-side tier-1 gate as a flake app (06-07,
# D-12: "the r9-side tier-1 gate is Harvey's composed smoke extended").
# Runs the SAME composed pipeline as nix/smoke-r9.sh (build → bake →
# DTB patch) but launches qemu under build/aarch64/tier1-r9.expect,
# which types ONE sweep line at the % prompt (r9's devcons serves
# reads) and asserts the marker set against the serial wire.  The
# smoke's own behavior is untouched.
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/aarch64/subset-build.sh, the ONE host
#      driver on both platforms (darwin: the lima namespace build;
#      linux: the same guest script natively under sudo unshare).
#      Skip with R9_SKIP_BUILD=1 for iteration — an escape hatch,
#      NEVER the default; the gate runs the default (always build).
#   2. bake — build/aarch64/mkimage.sh → build/aarch64/bootfs.paq
#      (Harvey's own mkpaqfs; r9's xtask is never invoked).  The bake
#      carries the tier-1 payload (06-07): /aarch64/bin/h* binaries,
#      /lib/tier1-sweep.rc, /lib/tier1/* fixed inputs.
#   3. DTB patch: a throwaway copy
#      of the package's selected DTB (virt-gicv3.dtb by default) gets
#      /chosen linux,initrd-start/-end as two 32-bit BE cells, high word
#      first (dtc has no 8-byte property type).  Mirrors r9's
#      xtask/src/config.rs prepare_initrd_dtb.
#   4. the gate — build/aarch64/tier1-r9.expect spawns qemu with serial
#      on stdio (-nographic) and asserts: staged boot → one typed line
#      `rc /lib/tier1-sweep.rc r9` → staged marker waits (float canary
#      T1-OK float-d01 on BOTH kernels, D-01) → T1-DONE → the whole-file
#      post-pass (every expected T1-OK, the T1-SKIP set EQUAL to the
#      known write-flow/build-chain list, zero T1-FAIL, zero panic).
#      Markers are the ONLY proof — the supervisor's exit status is
#      never trusted.
#
# Env contract:
#   R9_KERNEL_PKG  REQUIRED — the r9 kernel-virt package's store path;
#                  the flake app exports it from
#                  inputs.r9.packages.<system>.kernel-virt.  Kernel and
#                  DTB arrive ONLY via this nix-controlled, read-only
#                  store path (presence validated before
#                  launch).  No sibling-checkout path appears here by
#                  design.
#   R9_SKIP_BUILD  =1 skips step 1 (iteration hatch; see above).
#   R9_TIER1_LOG   default $HARVEY/build/aarch64/tier1-r9.log (a
#                  gitignored transient — a passing capture is copied
#                  into the phase dir as retained evidence by the plan's
#                  gate task).
#   R9_QEMU        default qemu-system-aarch64.
#   R9_ACCEL       auto (default) | hvf | kvm | tcg — auto picks hvf on
#                  darwin-aarch64 when qemu supports it, tcg otherwise.
#   R9_GICV2       =1 restores the v1.0 reference shape (gic-version=2,
#                  cortex-a72, tcg) — a bisection escape hatch.
#   KERNDATE       pinned-build timestamp override; derived
#                  from the HARVEY checkout's git log otherwise.
#
# Hygiene: the capture is rm -f'd BEFORE launch (a
# pre-seeded stale log cannot pass — it starts empty and only this
# run's boot writes it); the expect driver kills qemu's process group
# on every exit path; THIS script's EXIT trap sweeps any survivor via a
# bracket-fixed pkill keyed on this run's unique R9_RUN_TAG (exported
# below; the driver adds it to qemu's argv as -name) — never a
# kernel-name class, so a foreign r9 qemu (a dev's interactive boot-r9,
# a parallel CI job) is never matched.  The '[q]emu…' pattern cannot
# self-match the harness shell's or pkill's own argv.
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, dtc (fdtput), git, expect always;
# lima+openssh+rsync on darwin; util-linux+gnused+mount+binutils on
# linux.  Standalone use needs the same tools on PATH.
#
# usage: nix run .#boot-r9-tier1   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# Resolve a host grep once (D-02): the marker-set computation needs
# -o/-E, which plan9 grep lacks — but a hardcoded /usr/bin/grep breaks
# on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

# --- step 0: the kernel package contract (same as smoke-r9.sh) -------

[ -n "${R9_KERNEL_PKG:-}" ] || err "R9_KERNEL_PKG unset — run via the flake app (nix run .#boot-r9-tier1), which exports the r9 kernel-virt store path"
[ -d "$R9_KERNEL_PKG" ] || err "R9_KERNEL_PKG $R9_KERNEL_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_PKG/kernel-virt.elf"
if [ ! -f "$R9_KERNEL" ]; then
	# find fallback: the package's layout is the published contract, but
	# locate the ELF by name rather than failing blind on a layout drift
	R9_KERNEL=$(find "$R9_KERNEL_PKG" -name 'kernel-virt.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-virt.elf not found under $R9_KERNEL_PKG"

# --- step 0b: machine/accel selection (same as smoke-r9.sh) ----------
# gicv3 is the default machine shape everywhere; accel prefers hvf on
# darwin-aarch64 (hvf rejects gicv2 on qemu 11.1.2), TCG elsewhere.
# R9_ACCEL forces the accelerator; R9_GICV2=1 restores the v1.0
# reference shape (gic-version=2 + cortex-a72 + tcg) for bisection.

if [ "${R9_GICV2:-0}" = "1" ]; then
	R9_ACCEL=tcg
	R9_MACHINE="virt,gic-version=2"
	R9_CPU=cortex-a72
	R9_DTB_NAME=virt-gicv2.dtb
else
	R9_ACCEL="${R9_ACCEL:-auto}"
	if [ "$R9_ACCEL" = "auto" ]; then
		R9_ACCEL=tcg
		if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ] \
			&& qemu-system-aarch64 -accel help 2>/dev/null | "$GREP" -qx 'hvf'; then
			R9_ACCEL=hvf
		fi
	fi
	R9_MACHINE="virt,gic-version=3"
	R9_DTB_NAME=virt-gicv3.dtb
	case "$R9_ACCEL" in
		hvf|kvm) R9_CPU=host ;;
		tcg) R9_CPU=cortex-a72 ;;
		*) err "R9_ACCEL=$R9_ACCEL: want auto|hvf|kvm|tcg" ;;
	esac
fi

R9_DTB_SRC="$R9_KERNEL_PKG/aarch64/lib/$R9_DTB_NAME"
if [ ! -f "$R9_DTB_SRC" ]; then
	R9_DTB_SRC=$(find "$R9_KERNEL_PKG" -name "$R9_DTB_NAME" -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_DTB_SRC" ] && [ -f "$R9_DTB_SRC" ] || err "$R9_DTB_NAME not found under $R9_KERNEL_PKG"

echo "== r9 kernel package: $R9_KERNEL_PKG"
echo "   kernel: $R9_KERNEL"
echo "   dtb:    $R9_DTB_SRC"
echo "   shape:  $R9_MACHINE accel=$R9_ACCEL cpu=$R9_CPU"

# --- provenance (KERNDATE; the nix/build.sh discipline) -------------
# Pinned build timestamp; override with KERNDATE=<epoch>.
# Derived host-side from the checkout's git commit; falls back to build
# time when git metadata is absent (non-reproducible; see
# build/REPRODUCIBILITY.md).  date(1) dialects differ (plan9port -n vs
# GNU/BSD +%s) — try both, keep digits only.
if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date -n 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the aarch64 userland ------------------------------------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4: aarch64 userland build (build/aarch64/subset-build.sh)"
	sh "$HARVEY/build/aarch64/subset-build.sh" || err "userland build failed"
fi

# --- step 2: bake the initrd -----------------------------------------

echo "== step 2/4: bake bootfs.paq (build/aarch64/mkimage.sh)"
sh "$HARVEY/build/aarch64/mkimage.sh" || err "initrd bake failed"
R9_INITRD="$HARVEY/build/aarch64/bootfs.paq"
[ -s "$R9_INITRD" ] || err "$R9_INITRD missing/empty after the bake"

# --- step 2b: the expected marker sets (computed, never a second
#     hardcoded list — subset-exec.sh's 06-06 rule).  The OK set: tier
#     entries map to marker names (basename; dir:target → target) minus
#     the never-swept members (the boot chain rides the 05-03 trace;
#     7c/7l/cc ride the canary markers) minus stacksmoke (its T1-OK is
#     the donor termrc's line; the r9 boot's own stacksmoke stage covers
#     it here) minus every SKIP-named member (the donor-guarded legs
#     emit T1-SKIP on r9) — plus the fixed markers float-d01 (D-01) and
#     libtest-tdraw.  The SKIP set is extracted VERBATIM from
#     tier1-sweep.rc's r9-venue SKIP lines (the file is the source of
#     truth). ---
T1_SKIP=$("$GREP" -oE '(^|[[:space:]])echo T1-SKIP [A-Za-z0-9.-]+' "$HARVEY/build/aarch64/tier1-sweep.rc" \
	| awk '{print $NF}' | sort -u | tr '\n' ' ')
T1_OK_ALL=$(
	awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/aarch64/tiers/tier1-cmds.txt" |
	while read -r e; do
		case "$e" in
		9k/boot|stage/init|cmd/paqfs:paqfs|cmd/7c|cmd/7l|cmd/cc) continue ;;
		stage/stacksmoke) continue ;;
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
R9_EXPECT_OK="$T1_OK float-d01 libtest-tdraw"
R9_EXPECT_SKIP="$T1_SKIP"
export R9_EXPECT_OK R9_EXPECT_SKIP
echo "== expected on r9: $(echo "$R9_EXPECT_OK" | wc -w | tr -d ' ') T1-OK markers + $(echo "$R9_EXPECT_SKIP" | wc -w | tr -d ' ') T1-SKIP markers (computed)"

# --- step 3: DTB patch (the Phase-4 fdtput recipe; see the header) ---

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/tier1-r9.XXXXXX")
# The per-run unique tag — exported so tier1-r9.expect adds it to
# qemu's argv (-name), and this run's survivor sweep (cleanup below)
# keys on it.  The sweep NEVER matches a kernel-name class: a foreign
# r9 qemu (a dev's interactive boot-r9 uses the same kernel; a parallel
# CI job on a shared runner) must never be killed by this gate's
# teardown.
R9_RUN_TAG="r9tier1-$$-$(date +%s)"
export R9_RUN_TAG
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills qemu's process group on every exit path;
	# this trap sweeps any survivor.  the pattern is bracket-fixed
	# ([q]emu) so pkill cannot self-match this shell's or its own argv,
	# and keyed on THIS run's unique -name tag — never on the
	# kernel-path class.
	pkill -f "[q]emu-system-aarch64.*${R9_RUN_TAG}" 2>/dev/null || true
	rm -rf "$TMPD"
	exit "$status"
}
trap cleanup EXIT

DTB="$TMPD/virt-patched.dtb"
# cp duplicates the store file's READ-ONLY mode (r--r--r--) — make the
# copy writable or fdtput fails EPERM (nix/setup.sh's install_tool
# chmod u+w precedent for store-derived files)
cp "$R9_DTB_SRC" "$DTB"
chmod u+w "$DTB"
SIZE=$(wc -c < "$R9_INITRD" | tr -d ' ')
START=$((0x48000000))
END=$((START + SIZE))
HI=$(printf '0x%x' $((START >> 32)))
LO=$(printf '0x%x' $((START & 0xffffffff)))
fdtput -t x "$DTB" /chosen linux,initrd-start "$HI" "$LO" \
	|| err "fdtput linux,initrd-start patch failed"
HI=$(printf '0x%x' $((END >> 32)))
LO=$(printf '0x%x' $((END & 0xffffffff)))
fdtput -t x "$DTB" /chosen linux,initrd-end "$HI" "$LO" \
	|| err "fdtput linux,initrd-end patch failed"

# --- step 4: the expect-driven tier-1 gate ---------------------------

R9_TIER1_LOG="${R9_TIER1_LOG:-$HARVEY/build/aarch64/tier1-r9.log}"
R9_QEMU="${R9_QEMU:-qemu-system-aarch64}"

# fresh capture per run BEFORE launch (a
# pre-seeded stale log is dead evidence — it starts empty and only this
# run's boot writes it; the driver rm -f's it again belt-and-braces)
rm -f "$R9_TIER1_LOG"

echo "== step 4/4: the tier-1 gate on r9 (build/aarch64/tier1-r9.expect)"
echo "== capture: $R9_TIER1_LOG"

export R9_KERNEL R9_INITRD R9_TIER1_LOG R9_QEMU
R9_DTB="$DTB"
export R9_DTB
# The selected machine shape for the expect driver's spawn argv.
export R9_MACHINE R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/aarch64/tier1-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "tier-1 r9 gate FAILED (the driver named the stage on stderr; capture: $R9_TIER1_LOG)"
fi
echo "== tier-1 r9 gate PASS — capture retained at $R9_TIER1_LOG"
exit 0
