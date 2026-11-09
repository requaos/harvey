# nix/boot-r9-x64.sh — THE one command on x86_64: compose the
# pinned r9 kernel — Harvey's flake input's packages.kernel-x64 store
# path (the q35shell-config kernel ELF; 14-07 re-keyed the package to
# the full-chain profile) — with Harvey's amd64 userland, and boot to
# the interactive rc prompt on the qemu q35 machine off the composed
# GRUB ISO.  The pipeline, each step loud on failure:
#
#   1. userland build — build/x86_64/stage-build.sh, the 14-05/14-06
#      namespace driver (objtype=amd64: the marker set + the boot-chain
#      binaries harvested to out/).  Linux-native only (unshare; there
#      is no lima leg on x64).  Skip with R9_SKIP_BUILD=1 for iteration
#      — an escape hatch, NEVER the default; the documented command
#      uses the default (always build).
#   2. bake — build/x86_64/mkimage.sh → out/bootfs.paq (the leg-1
#      marker image, untouched contract) AND out/bootfs-chain.paq (the
#      CHAIN image this boot consumes: /boot/boot + paqfs + the real
#      /amd64/init + rc + rcmain + termrc/namespace/profile).
#   3. compose + launch — r9's exported iso-builder script
#      (R9_ISO_BUILDER, the flake input's packages.iso-builder: ONE
#      reproducibility implementation, D-05 — the pinned-date xorriso
#      pipeline, strip-all staging, the templated module2 emission)
#      builds the ISO from the kernel + the chain bake, then:
#        qemu-system-x86_64 -M q35 -accel kvm -cpu host -smp 1 -m 1024M
#          -cdrom <composed ISO>
#          -netdev user,id=n0 -device virtio-net-pci-non-transitional,netdev=n0
#          -nographic
#      NO DTB patch, NO -device loader anywhere — the aarch64 delivery
#      is deliberately not carried: GRUB delivers bootfs as an mb2
#      tag-3 module off the same ISO (14-05 D-03).  qemu runs in the
#      FOREGROUND with stdio inherited — the user's terminal IS the
#      console (ctrl-a x to quit).
#
# Accel discipline (Phase 13, carried): the accelerator comes ONLY from
# R9_ACCEL (kvm default) — never a silent downgrade.  A kvm request on
# a KVM-less host FAILS LOUDLY naming R9_ACCEL=tcg as the explicit
# fallback; TCG selects -cpu qemu64 (the hosted-runner shape).
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                     path; the flake app exports it from
#                     inputs.r9.packages.<system>.kernel-x64.  The
#                     kernel arrives ONLY via this nix-controlled,
#                     read-only store path (no caller-supplied kernel
#                     path is staged; presence validated before the
#                     builder runs).
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder script (the
#                     flake input's packages.iso-builder); the flake
#                     app exports it.  The composed ISO's bytes come
#                     from r9's ONE implementation, un-forked (D-05).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                     downgrade (see above).
#   R9_CPU            override the cpu model (default: host under kvm,
#                     qemu64 under tcg).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   KERNDATE          pinned-build timestamp override; derived from
#                     the HARVEY checkout's git log otherwise.
#
# Dev flow against a LOCAL r9 checkout (dev-only, never the default):
#   nix run .#boot-r9-x64 --override-input r9 git+file:///path/to/r9
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, git always; util-linux+gnused+mount+
# binutils on linux (the namespace build's transport).  Standalone use
# needs the same tools on PATH.
#
# usage: nix run .#boot-r9-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the kernel-package + builder contract --------------------

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	# find fallback: the package's layout is the published contract, but
	# locate the ELF by name rather than failing blind on a layout drift
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-x64), which exports r9's iso-builder script path"
[ -x "$R9_ISO_BUILDER" ] || err "R9_ISO_BUILDER $R9_ISO_BUILDER: not executable (the pin predates r9's iso-builder export? — 14-07)"

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
echo "   kernel:     $R9_KERNEL"
echo "   iso-builder: $R9_ISO_BUILDER"
echo "   shape:      q35 accel=$R9_ACCEL cpu=$R9_CPU"

# --- provenance (KERNDATE; the boot-r9.sh discipline) ------------------
# Pinned build timestamp; override with KERNDATE=<epoch>.  Derived
# host-side from the checkout's git commit; falls back to build time
# when git metadata is absent.  The bake embeds KERNDATE in the paqfs
# header and the staged mtimes — two bakes of one tree are
# byte-identical (the 14-05 determinism contract).
if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the amd64 userland ---------------------------------------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the documented command)"
else
	echo "== step 1/3: amd64 userland build (build/x86_64/stage-build.sh)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "userland build failed"
fi

# --- step 2: bake the bootfs images ------------------------------------

echo "== step 2/3: bake bootfs.paq + bootfs-chain.paq (build/x86_64/mkimage.sh)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
CHAIN_PAQ="$HARVEY/build/x86_64/out/bootfs-chain.paq"
[ -s "$CHAIN_PAQ" ] || err "$CHAIN_PAQ missing/empty after the bake (mkimage's chain section)"

# --- step 3: compose the ISO + launch qemu -----------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/boot-r9-x64.XXXXXX")
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

echo "== step 3/3: composing the ISO (r9's iso-builder: kernel + bootfs-chain.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$CHAIN_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
ISO="$TMPD/boot.iso"
[ -s "$ISO" ] || err "$ISO missing/empty after the iso-builder"

# D-10 carried: the standard boot speaks Ethernet — the always-on NIC
# rides every composed boot (the aarch64 argv re-keyed to -cdrom; the
# nic-bind post-pass of the smoke gate asserts the driver's bind line).
set -- qemu-system-x86_64 \
	-M q35 -cpu "$R9_CPU" -smp 1 -m 1024M -accel "$R9_ACCEL" \
	-cdrom "$ISO" \
	-netdev user,id=n0 \
	-device virtio-net-pci-non-transitional,netdev=n0 \
	-nographic

# always print the assembled argv so captured gate logs are
# self-describing (run-r9.sh's discipline)
echo "== launching qemu — interactive on stdio (ctrl-a x to quit)"
echo "== qemu argv: $*"

set +e
"$@"
RC=$?
set -e
exit "$RC"
