# nix/smoke-r9.sh — 05-12's packaged smoke (INT-02, D-12): the
# expect-style smoke as a flake app.  Runs the SAME composed pipeline
# as nix/boot-r9.sh (build → bake → DTB patch — INT-01's composition)
# but launches qemu under build/aarch64/smoke-r9.expect, which drives
# the full D-09 sweep against the serial wire and exits 0/1 for CI.
# boot-r9's own behavior is untouched.
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/aarch64/subset-build.sh, the ONE host
#      driver on both platforms (darwin: the lima namespace build;
#      linux: the same guest script natively under sudo unshare).
#      Skip with R9_SKIP_BUILD=1 for iteration — an escape hatch,
#      NEVER the default; the gate runs the default (always build).
#   2. bake — build/aarch64/mkimage.sh → build/aarch64/bootfs.paq
#      (Harvey's own mkpaqfs; r9's xtask is never invoked — D-11).
#   3. DTB patch — the Phase-4 recipe (D-01 amended): a throwaway copy
#      of the package's virt-gicv2.dtb gets /chosen linux,initrd-start/
#      -end as two 32-bit BE cells, high word first (dtc has no 8-byte
#      property type).  Mirrors r9's xtask/src/config.rs
#      prepare_initrd_dtb (lines 385-434) per D-11.
#   4. smoke — build/aarch64/smoke-r9.expect spawns qemu with serial on
#      stdio (-nographic, the build/build.bash-proven shape; A6) and
#      asserts: banner → boot prints → stacksmoke → the %  prompt →
#      echo r9shell7 → ls /bin subset → ps → cat /lib/namespace → DEL
#      safety → exit → restart.  Markers are the ONLY proof — the
#      supervisor's exit status is never trusted (D-16).
#
# Env contract:
#   R9_KERNEL_PKG  REQUIRED — the r9 kernel-virt package's store path;
#                  the flake app exports it from
#                  inputs.r9.packages.<system>.kernel-virt.  Kernel and
#                  DTB arrive ONLY via this nix-controlled, read-only
#                  store path (T-05-21; presence validated before
#                  launch).  No sibling-checkout path appears here by
#                  design (INT-04).
#   R9_SKIP_BUILD  =1 skips step 1 (iteration hatch; see above).
#   R9_SMOKE_LOG   default $HARVEY/build/aarch64/smoke-r9.log (a
#                  gitignored transient — a passing capture is copied
#                  into the phase dir as retained evidence by the plan's
#                  gate task).
#   R9_QEMU        default qemu-system-aarch64.
#   KERNDATE       pinned-build timestamp override (BUILD-04); derived
#                  from the HARVEY checkout's git log otherwise.
#
# Hygiene (D-16, Pitfall 10): the capture is rm -f'd BEFORE launch (a
# pre-seeded stale log cannot pass — it starts empty and only this
# run's boot writes it); the expect driver kills qemu's process group
# on every exit path; THIS script's EXIT trap sweeps any survivor via a
# bracket-fixed pkill keyed on this run's kernel-path argv — the
# pattern '[q]emu…' cannot self-match the harness shell's or pkill's
# own argv (Phase-3 carried discipline).
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, dtc (fdtput), git, expect always;
# lima+openssh+rsync on darwin; util-linux+gnused+mount+binutils on
# linux.  Standalone use needs the same tools on PATH.
#
# usage: nix run .#boot-r9-smoke   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the kernel package contract (same as boot-r9.sh) --------

[ -n "${R9_KERNEL_PKG:-}" ] || err "R9_KERNEL_PKG unset — run via the flake app (nix run .#boot-r9-smoke), which exports the r9 kernel-virt store path"
[ -d "$R9_KERNEL_PKG" ] || err "R9_KERNEL_PKG $R9_KERNEL_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_PKG/kernel-virt.elf"
if [ ! -f "$R9_KERNEL" ]; then
	# find fallback: the package's layout is the 05-10 contract, but
	# locate the ELF by name rather than failing blind on a layout drift
	R9_KERNEL=$(find "$R9_KERNEL_PKG" -name 'kernel-virt.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-virt.elf not found under $R9_KERNEL_PKG"

R9_DTB_SRC="$R9_KERNEL_PKG/aarch64/lib/virt-gicv2.dtb"
if [ ! -f "$R9_DTB_SRC" ]; then
	R9_DTB_SRC=$(find "$R9_KERNEL_PKG" -name 'virt-gicv2.dtb' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_DTB_SRC" ] && [ -f "$R9_DTB_SRC" ] || err "virt-gicv2.dtb not found under $R9_KERNEL_PKG"

echo "== r9 kernel package: $R9_KERNEL_PKG"
echo "   kernel: $R9_KERNEL"
echo "   dtb:    $R9_DTB_SRC"

# --- provenance (KERNDATE; the nix/build.sh discipline) -------------
# Pinned build timestamp (BUILD-04); override with KERNDATE=<epoch>.
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

# --- step 3: DTB patch (the Phase-4 fdtput recipe; see the header) ---

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/smoke-r9.XXXXXX")
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills qemu's process group on every exit path;
	# this trap sweeps any survivor.  the pattern is bracket-fixed
	# ([q]emu) so pkill cannot self-match this shell's or its own argv,
	# and keyed on this run's kernel path so a foreign qemu (a dev's
	# interactive boot-r9 uses the same kernel, but never concurrently
	# with the gate) is the only match class.
	pkill -f '[q]emu-system-aarch64.*kernel-virt\.elf' 2>/dev/null || true
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

# --- step 4: the expect-driven smoke ----------------------------------

R9_SMOKE_LOG="${R9_SMOKE_LOG:-$HARVEY/build/aarch64/smoke-r9.log}"
R9_QEMU="${R9_QEMU:-qemu-system-aarch64}"

# fresh capture per run BEFORE launch (Pitfall 10 / T-05-22: a
# pre-seeded stale log is dead evidence — it starts empty and only this
# run's boot writes it; the driver rm -f's it again belt-and-braces)
rm -f "$R9_SMOKE_LOG"

echo "== step 4/4: smoke (build/aarch64/smoke-r9.expect)"
echo "== capture: $R9_SMOKE_LOG"

export R9_KERNEL R9_INITRD R9_SMOKE_LOG R9_QEMU
R9_DTB="$DTB"
export R9_DTB

set +e
expect "$HARVEY/build/aarch64/smoke-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "smoke FAILED (the driver named the stage on stderr; capture: $R9_SMOKE_LOG)"
fi
echo "== smoke PASS — capture retained at $R9_SMOKE_LOG"
exit 0
