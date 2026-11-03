# nix/boot-r9.sh — THE one command (05-11, INT-01, D-10): compose the
# pinned r9 kernel — Harvey's flake input's packages.kernel-virt store
# paths (05-10's contract: kernel-virt.elf + aarch64/lib/virt-gicv2.dtb)
# — with Harvey's aarch64 userland, and boot to the interactive rc
# prompt on the qemu virt machine.  The pipeline, each step loud on
# failure:
#
#   1. userland build — build/aarch64/subset-build.sh, the ONE host
#      driver on both platforms (darwin: the lima namespace build;
#      linux: the same guest script natively under sudo unshare).
#      Skip with R9_SKIP_BUILD=1 for iteration — an escape hatch,
#      NEVER the default; INT-03's documented command uses the
#      default (always build).
#   2. bake — build/aarch64/mkimage.sh → build/aarch64/bootfs.paq
#      (Harvey's own mkpaqfs; r9's xtask is never invoked — D-11).
#   3. DTB patch — the Phase-4 recipe (D-01 amended): a throwaway copy
#      of the package's virt-gicv2.dtb gets /chosen linux,initrd-start/
#      -end as two 32-bit BE cells, high word first (dtc has no 8-byte
#      property type).  Mirrors r9's xtask/src/config.rs
#      prepare_initrd_dtb (lines 385-434) per D-11's "documented from
#      r9's config TOML".
#   4. launch — qemu argv values from r9's aarch64/lib/
#      config_virtexec.toml [qemu] (carried-forward locked shape):
#        qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72
#          -smp 1 -m 1024M -accel tcg -kernel <r9 ELF>
#          -dtb <patched copy>
#          -device loader,file=<bootfs.paq>,addr=0x48000000 -nographic
#      qemu runs in the FOREGROUND with stdio inherited — the user's
#      terminal IS the console (ctrl-a x to quit).  A foreground child
#      rather than exec so the EXIT trap reclaims the mktemp DTB dir
#      (same console semantics: qemu is the group's foreground process).
#
# Env contract:
#   R9_KERNEL_PKG  REQUIRED — the r9 kernel-virt package's store path;
#                  the flake app exports it from
#                  inputs.r9.packages.<system>.kernel-virt.  The kernel
#                  and DTB arrive ONLY via this nix-controlled,
#                  read-only store path (T-05-21: no caller-supplied
#                  kernel path is exec'd; presence is validated before
#                  launch).  No sibling-checkout path appears here by
#                  design (INT-04).
#   R9_SKIP_BUILD  =1 skips step 1 (iteration hatch; see above).
#   KERNDATE       pinned-build timestamp override (BUILD-04); derived
#                  from the HARVEY checkout's git log otherwise.
#
# Dev flow against a LOCAL r9 checkout (D-13 — dev-only, never the
# default):
#   nix run .#boot-r9 --override-input r9 git+file:///path/to/r9
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, dtc (fdtput), git always;
# lima+openssh+rsync on darwin; util-linux+gnused+mount+binutils on
# linux.  Standalone use needs the same tools on PATH.
#
# usage: nix run .#boot-r9   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the kernel package contract ----------------------------

[ -n "${R9_KERNEL_PKG:-}" ] || err "R9_KERNEL_PKG unset — run via the flake app (nix run .#boot-r9), which exports the r9 kernel-virt store path"
[ -d "$R9_KERNEL_PKG" ] || err "R9_KERNEL_PKG $R9_KERNEL_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_PKG/kernel-virt.elf"
if [ ! -f "$R9_KERNEL" ]; then
	# find fallback: the package's layout is the 05-10 contract, but
	# locate the ELF by name rather than failing blind on a layout drift
	R9_KERNEL=$(find "$R9_KERNEL_PKG" -name 'kernel-virt.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-virt.elf not found under $R9_KERNEL_PKG"

R9_DTB="$R9_KERNEL_PKG/aarch64/lib/virt-gicv2.dtb"
if [ ! -f "$R9_DTB" ]; then
	R9_DTB=$(find "$R9_KERNEL_PKG" -name 'virt-gicv2.dtb' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_DTB" ] && [ -f "$R9_DTB" ] || err "virt-gicv2.dtb not found under $R9_KERNEL_PKG"

echo "== r9 kernel package: $R9_KERNEL_PKG"
echo "   kernel: $R9_KERNEL"
echo "   dtb:    $R9_DTB"

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
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the documented command)"
else
	echo "== step 1/3: aarch64 userland build (build/aarch64/subset-build.sh)"
	sh "$HARVEY/build/aarch64/subset-build.sh" || err "userland build failed"
fi

# --- step 2: bake the initrd -----------------------------------------

echo "== step 2/3: bake bootfs.paq (build/aarch64/mkimage.sh)"
sh "$HARVEY/build/aarch64/mkimage.sh" || err "initrd bake failed"
INITRD="$HARVEY/build/aarch64/bootfs.paq"
[ -s "$INITRD" ] || err "$INITRD missing/empty after the bake"

# --- step 3: DTB patch + qemu launch ---------------------------------
# (the Phase-4 fdtput recipe — two 32-bit BE cells, high word first —
# and the locked virt argv; see the header for the r9 citations)

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/boot-r9.XXXXXX")
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

DTB="$TMPD/virt-patched.dtb"
# cp duplicates the store file's READ-ONLY mode (r--r--r--) — make the
# copy writable or fdtput fails EPERM (nix/setup.sh's install_tool
# chmod u+w precedent for store-derived files)
cp "$R9_DTB" "$DTB"
chmod u+w "$DTB"
SIZE=$(wc -c < "$INITRD" | tr -d ' ')
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

set -- qemu-system-aarch64 \
	-M virt,gic-version=2 -cpu cortex-a72 -smp 1 -m 1024M -accel tcg \
	-kernel "$R9_KERNEL" \
	-dtb "$DTB" \
	-device "loader,file=$INITRD,addr=0x48000000" \
	-nographic

# always print the assembled argv so captured gate logs are
# self-describing (run-r9.sh's discipline)
echo "== step 3/3: launching qemu — interactive on stdio (ctrl-a x to quit)"
echo "== qemu argv: $*"

set +e
"$@"
RC=$?
set -e
exit "$RC"
