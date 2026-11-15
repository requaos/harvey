# nix/smoke-r9-x64.sh — the COMPOSED smoke gate as a flake app (14-07,
# XEXEC-03; extended 19-09/INT-05 with the cpu-chain leg): the SAME
# composed pipeline as nix/boot-r9-x64.sh (kernel contract → KERNDATE
# → userland build → bake → r9's iso-builder) but launched under
# build/x86_64/smoke-r9.expect, which drives the full command sweep
# against the serial wire AND (since 19-09) the full-system cpu chain
# in ONE composed gate, and exits 0/1 for CI.  boot-r9-x64's own
# behavior is untouched.
#
# The pipeline, each step loud on failure:
#
#   1. userland build — build/x86_64/stage-build.sh, the 14-05/14-06
#      namespace driver (objtype=amd64: the marker set + the boot-chain
#      binaries + the 14-07 sweep set ls/cat/echo/ps, harvested to
#      out/), THEN build/x86_64/subset-build.sh, the tier driver (the
#      §15 bake's named input producer: cmd/cpu, aux/listen, sed,
#      ipconfig — 19-09).  Linux-native only (unshare; no lima leg on
#      x64).  Skip with R9_SKIP_BUILD=1 for iteration — an escape
#      hatch, NEVER the default; the GATE runs the default.
#   2. bake — build/x86_64/mkimage.sh → out/bootfs.paq (the leg-1
#      marker image, contract untouched) AND out/bootfs-chain.paq (the
#      CHAIN image with the sweep set the chain leg drives) AND
#      out/bootfs-cpu.paq (§15's cpu image the cpu-chain leg boots —
#      every mkimage run bakes ALL contracts).
#   3. compose the CHAIN ISO — r9's exported iso-builder (R9_ISO_BUILDER,
#      the flake input's packages.iso-builder: ONE reproducibility
#      implementation, D-05) builds the ISO from the pinned kernel-x64
#      + the chain bake as /boot/bootfs.paq.
#   4. compose the CPU ISO — the same iso-builder WITH the bootconf
#      append parameter (19-01's seam: --append=init=/amd64/init -c)
#      over bootfs-cpu.paq as /boot/bootfs.paq.
#   5. smoke — build/x86_64/smoke-r9.expect spawns qemu TWICE (one
#      gate, two legs): the chain leg (the composed chain ISO on
#      -cdrom, q35, -nographic) asserts banner → paqfs/version → the
#      %  prompt → echo round-trip → empty-line safety → ls /bin
#      subset → ps → cat /lib/namespace → DEL safety → exit → init
#      restart → the whole-capture post-passes — UNTOUCHED; then the
#      CPU-CHAIN leg (the cpu ISO under the emitter's slirp argv, the
#      D-04 hostfwd pair included) asserts the §15 boot with the
#      bootconf append, the host-side hostfwd observation (17010 +
#      5670), the cpurc ladder in order through LISTEN-17010 and DONE,
#      zero FAIL, and the desktop-absent-at-boot proof (DESK-02's
#      backstop in the standing gate — see the expect header for the
#      honest scope boundary vs 19-08's drawterm gate).  Markers are
#      the ONLY proof — the supervisor's exit status is never trusted.
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                     path (the flake app exports it from
#                     inputs.r9.packages.<system>.kernel-x64).
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY (the
#                     flake app exports <pkg>/bin/r9-iso-builder).
#   R9_NETDEV_EMITTER REQUIRED (19-09) — r9's netdev-args emitter bin
#                     (the cpu leg's slirp argv with the D-04 hostfwd
#                     pair comes ONLY from its output, captured once
#                     and exported as R9_NETDEV_ARGV).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_SMOKE_LOG      default $HARVEY/build/x86_64/smoke-r9.log (the
#                     chain leg's capture; a gitignored transient —
#                     the twice-green gate run sets per-run paths and
#                     retains BOTH legs' captures as evidence).
#   R9_CPU_LOG        default $HARVEY/build/x86_64/smoke-r9-cpu.log
#                     (the cpu-chain leg's capture; same discipline).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                     downgrade (the Phase-13 discipline).
#   R9_CPU            override the cpu model (default: host under kvm,
#                     qemu64 under tcg).
#   KERNDATE          pinned-build timestamp override; derived from
#                     the HARVEY checkout's git log otherwise.
#
# Hygiene: BOTH captures are rm -f'd BEFORE launch (a pre-seeded stale
# log cannot pass — each starts empty and only this run's boot writes
# it); the expect driver kills the live spawn's process group on every
# exit path; THIS script's EXIT trap sweeps any survivor via a
# bracket-fixed pkill keyed on this run's unique R9_RUN_TAG (exported
# below; the driver adds it to BOTH spawns' argv as -name) — never a
# kernel-name class, so a foreign r9 qemu (a dev's interactive
# boot-r9-x64, a parallel CI job) is never matched.  The '[q]emu…'
# pattern cannot self-match the harness shell's or pkill's own argv.
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

# --- step 0c: the netdev argv — the emitter's slirp tokens (19-09) ------
# The cpu-chain leg's qemu rides the emitter's slirp argv so the D-04
# hostfwd pair (host 17010 -> guest 17010, host 5670 -> guest 567) is
# pinned r9 TOML data, never script text (16-06's mechanism, carried):
# captured ONCE here, before any build spend, so an emitter failure is
# a named contract error — and exported as R9_NETDEV_ARGV for the
# expect driver to split.  The CHAIN leg's own spawn keeps its
# hostfwd-free netdev shape (untouched — its nic-bind stage wants the
# NIC, not the pair).

[ -n "${R9_NETDEV_EMITTER:-}" ] || err "R9_NETDEV_EMITTER unset — run via the flake app (nix run .#boot-r9-smoke-x64), which exports r9's netdev-args emitter path (the cpu-chain leg's slirp argv)"
[ -f "$R9_NETDEV_EMITTER" ] && [ -x "$R9_NETDEV_EMITTER" ] \
	|| err "R9_NETDEV_EMITTER $R9_NETDEV_EMITTER: not an executable file (want <pkg>/bin/r9-netdev-args)"

# shellcheck disable=SC2312  # the rc rides the ||: an emitter failure is a named contract error (its stderr passed through above)
NETDEV_ARGV=$("$R9_NETDEV_EMITTER" --mode slirp) \
	|| err "the netdev emitter failed for mode slirp (its diagnostics are above; the argv comes only from the pinned r9 TOML — D-05)"
[ -n "$NETDEV_ARGV" ] || err "the netdev emitter printed no netdev argv for mode slirp"
export R9_NETDEV_ARGV="$NETDEV_ARGV"

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

# --- step 1: the amd64 userland (the stage set + the tier build) -------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/5a: stage the mkimage inputs (build/x86_64/stage-build.sh)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/5: amd64 tier build (build/x86_64/subset-build.sh — the §15 bake's input producer: cmd/cpu, aux/listen, sed, ipconfig)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake the bootfs images (all contracts) ---------------------

echo "== step 2/5: bake the bootfs images (build/x86_64/mkimage.sh — all contracts incl. §15's bootfs-cpu.paq, the cpu-chain leg's image)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
CHAIN_PAQ="$HARVEY/build/x86_64/out/bootfs-chain.paq"
[ -s "$CHAIN_PAQ" ] || err "$CHAIN_PAQ missing/empty after the bake (mkimage's chain section)"
CPU_PAQ="$HARVEY/build/x86_64/out/bootfs-cpu.paq"
[ -s "$CPU_PAQ" ] || err "$CPU_PAQ missing/empty after the bake (mkimage's §15 cpu section — the cpu-chain leg's image)"

# --- step 3+4: compose the TWO ISOs (chain, then cpu with the append) ---

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/smoke-r9-x64.XXXXXX")
TMPD2=$(mktemp -d "${TMPDIR:-/tmp}/smoke-r9-x64-cpu.XXXXXX")
# The per-run unique tag — exported so smoke-r9.expect adds it to BOTH
# spawns' argv (-name), and this run's survivor sweep (cleanup below)
# keys on it.  The sweep NEVER matches a kernel-name class: a foreign
# r9 qemu (a dev's interactive boot-r9-x64 uses the same kernel; a
# parallel CI job on a shared runner) must never be killed by this
# gate's teardown.
R9_RUN_TAG="r9x64smoke-$$-$(date +%s)"
export R9_RUN_TAG
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills the live spawn's process group on every
	# exit path; this trap sweeps any survivor of EITHER leg.  the
	# pattern is bracket-fixed ([q]emu) so pkill cannot self-match this
	# shell's or its own argv, and keyed on THIS run's unique -name tag
	# — never on the kernel-path class.
	pkill -f "[q]emu-system-x86_64.*${R9_RUN_TAG}" 2>/dev/null || true
	rm -rf "$TMPD" "$TMPD2"
	exit "$status"
}
trap cleanup EXIT

echo "== step 3/5: composing the CHAIN ISO (r9's iso-builder: kernel + bootfs-chain.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$CHAIN_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

echo "== step 4/5: composing the CPU ISO (r9's iso-builder: kernel + bootfs-cpu.paq as /boot/bootfs.paq + the bootconf append init=/amd64/init -c — 19-01's seam)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD2" --append="init=/amd64/init -c" "$CPU_PAQ" bootfs.paq \
	|| err "iso-builder failed for the cpu ISO (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_CPU_ISO="$TMPD2/boot.iso"
[ -s "$R9_CPU_ISO" ] || err "$R9_CPU_ISO missing/empty after the iso-builder"

# --- step 5: the expect-driven smoke (the chain leg + the cpu-chain leg) --

R9_SMOKE_LOG="${R9_SMOKE_LOG:-$HARVEY/build/x86_64/smoke-r9.log}"
R9_CPU_LOG="${R9_CPU_LOG:-$HARVEY/build/x86_64/smoke-r9-cpu.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh captures per run BEFORE launch (a pre-seeded stale log is dead
# evidence — each starts empty and only its leg's boot writes it; the
# driver rm -f's them again belt-and-braces)
rm -f "$R9_SMOKE_LOG" "$R9_CPU_LOG"

echo "== step 5/5: the composed smoke (build/x86_64/smoke-r9.expect — the chain leg + the cpu-chain leg)"
echo "== captures: $R9_SMOKE_LOG + $R9_CPU_LOG"

export R9_ISO R9_CPU_ISO R9_SMOKE_LOG R9_CPU_LOG R9_QEMU R9_NETDEV_ARGV
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/smoke-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "smoke FAILED (the driver named the stage on stderr; captures: $R9_SMOKE_LOG + $R9_CPU_LOG)"
fi
echo "== smoke PASS (chain leg + cpu-chain leg) — captures retained at $R9_SMOKE_LOG + $R9_CPU_LOG"
exit 0
