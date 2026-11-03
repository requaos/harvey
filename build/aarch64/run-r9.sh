#!/bin/sh
# build/aarch64/run-r9.sh — dev-time qemu launcher: r9 kernel + the
# Harvey real-chain paqfs image on the virt machine (05-02 Task 3; the
# 05-04..05-09 gates drive this).  Assembles the full qemu argv (loader
# device + fdtput-patched DTB per the Phase-4 recipe, D-01 amended)
# around an explicitly-supplied kernel ELF.
#
# Interface (env):
#   R9_KERNEL   REQUIRED — path to the r9 aarch64 kernel ELF.  No
#               default by design (D-10/D-11): the shipped composition
#               resolves the kernel from the flake input (05-11), and no
#               script in this phase may grow an implicit
#               sibling-checkout assumption.
#   R9_DTB      REQUIRED — path to the virt DTB (the r9 package's
#               virt-gicv2.dtb).  Required alongside R9_KERNEL for the
#               same reason; the flake app passes both.
#   R9_INITRD   default $HARVEY/build/aarch64/bootfs.paq — baked via
#               build/aarch64/mkimage.sh first when absent.
#   QEMU_BIN    default qemu-system-aarch64 (PATH lookup).
#
# Modes:
#   default         interactive: qemu -nographic, serial on stdio
#   --log FILE      gate mode: serial to FILE, -display none; FILE is
#                   removed first (Pitfall 10 / D-16: a stale log
#                   satisfies the next run's marker wait with dead
#                   evidence)
#
# qemu argv (values from ../r9/aarch64/lib/config_virtexec.toml's
# [qemu] — carried-forward locked shape):
#   qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -smp 1
#     -m 1024M -accel tcg -kernel $R9_KERNEL -dtb <patched copy>
#     -device loader,file=$R9_INITRD,addr=0x48000000
#
# Hygiene (D-16): fresh log per --log run; on exit the spawned qemu's
# process group is killed (setsid leg) with a lone-pid fallback.  On
# darwin there is no setsid(1) — ad-hoc gate kills there use
#   pkill -f '[q]emu-system-aarch64.*…'
# with the bracket-fixed pattern so pkill cannot self-match the harness
# shell argv (Phase-3 carried discipline).
#
# usage: R9_KERNEL=… R9_DTB=… build/aarch64/run-r9.sh [--log FILE]

set -eu

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"

# required-env contract — no implicit sibling-checkout defaults
[ -n "${R9_KERNEL:-}" ] || err "R9_KERNEL unset — path to the r9 aarch64 kernel ELF (required; no default by design)"
[ -n "${R9_DTB:-}" ] || err "R9_DTB unset — path to the virt DTB (required; the flake app passes it from the r9 package)"
[ -f "$R9_KERNEL" ] || err "R9_KERNEL $R9_KERNEL: kernel file does not exist"
[ -f "$R9_DTB" ] || err "R9_DTB $R9_DTB: dtb file does not exist"

R9_INITRD="${R9_INITRD:-$HARVEY/build/aarch64/bootfs.paq}"
if [ ! -f "$R9_INITRD" ]; then
	echo "== R9_INITRD $R9_INITRD missing — baking via build/aarch64/mkimage.sh"
	sh "$HARVEY/build/aarch64/mkimage.sh" || err "initrd bake failed"
fi
[ -f "$R9_INITRD" ] || err "R9_INITRD $R9_INITRD still missing after bake"

QEMU_BIN="${QEMU_BIN:-qemu-system-aarch64}"
command -v "$QEMU_BIN" >/dev/null 2>&1 || err "qemu-system-aarch64 not found on PATH (set QEMU_BIN)"

# fdtput (from dtc) patches the DTB /chosen initrd properties — supplied
# by the devshell/flake (the r9 devshell ships dtc today; 05-11's
# compose app carries it in runtimeInputs)
command -v fdtput >/dev/null 2>&1 || err "fdtput not found — install/supply dtc (the devshell provides it)"

LOG=""
if [ "${1:-}" = "--log" ]; then
	LOG="${2:?usage: run-r9.sh [--log FILE]}"
	rm -f "$LOG"
elif [ $# -gt 0 ]; then
	err "usage: run-r9.sh [--log FILE]"
fi

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/run-r9.XXXXXX")
QEMU_PID=""

cleanup() {
	status=$?
	# kill the spawned qemu's process group; qemu is a group leader on
	# the setsid leg, so the group is exactly the qemu subtree.  The
	# lone-pid fallback covers the no-setsid case (darwin); see the
	# header for the gates' bracket-fixed pkill pattern there.
	if [ -n "$QEMU_PID" ]; then
		kill -KILL -- "-$QEMU_PID" 2>/dev/null || kill -KILL "$QEMU_PID" 2>/dev/null || true
	fi
	rm -rf "$TMPD"
	exit $status
}
trap cleanup EXIT

# DTB patch (Phase-4 recipe, D-01 amended): a throwaway copy gets
# /chosen linux,initrd-start/end.  The kernel's property_value_as_u64
# reads each property as one 8-byte BE cell; dtc has no 8-byte property
# type, so each u64 is written as two 32-bit cells, high word first.
DTB="$TMPD/virt-patched.dtb"
cp "$R9_DTB" "$DTB"
SIZE=$(wc -c < "$R9_INITRD" | tr -d ' ')
START=$((0x48000000))
END=$((START + SIZE))
fdtput -t x "$DTB" /chosen linux,initrd-start \
	$(printf '0x%x' $((START >> 32))) $(printf '0x%x' $((START & 0xffffffff)))
fdtput -t x "$DTB" /chosen linux,initrd-end \
	$(printf '0x%x' $((END >> 32))) $(printf '0x%x' $((END & 0xffffffff)))

set -- "$QEMU_BIN" \
	-M virt,gic-version=2 -cpu cortex-a72 -smp 1 -m 1024M -accel tcg \
	-kernel "$R9_KERNEL" \
	-dtb "$DTB" \
	-device "loader,file=$R9_INITRD,addr=0x48000000"
if [ -n "$LOG" ]; then
	set -- "$@" -display none -serial "file:$LOG"
else
	set -- "$@" -nographic
fi

# always print the assembled argv so captured gate logs are
# self-describing
echo "== qemu argv: $*"

if command -v setsid >/dev/null 2>&1; then
	setsid "$@" &
else
	"$@" &
fi
QEMU_PID=$!

wait "$QEMU_PID"
