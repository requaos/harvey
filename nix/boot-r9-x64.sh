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
#          <the emitter's netdev+device argv for NET_MODE — the
#           R9_NETDEV_EMITTER's output, D-05: no netdev literal here>
#          -nographic
#      NO DTB patch, NO qemu loader-device flag anywhere — the aarch64 delivery
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
# Net discipline (Phase 16, D-01): the net mode comes ONLY from
# --net=<mode> over R9_NET over the slirp default — never a silent
# downgrade.  An unknown mode is a usage error listing slirp|tap|vmnet;
# a cross-venue request (--net=vmnet on linux, --net=tap on darwin) is
# rejected at parse naming the venue's valid modes; the tap leg refuses
# to launch unless the net-doctor's tap checks pass first (D-03 — the
# doctor's per-issue remediations print inline in the failure, never
# auto-applied).
#
# System discipline (Phase 19, 19-09 — INT-05/the OQ-4 settlement):
# --system=cpu|terminal selects WHAT the ONE command boots, the same
# single-accepted-form discipline as --net (duplicate = error; the =
# form only; an unknown mode is a usage error naming exactly terminal
# and cpu — never a silent downgrade, never a fall-through to a default
# venue).  terminal (the DEFAULT, and the behavior with no flag at
# all) keeps the chain path byte-untouched: the chain paq, the
# no-append ISO compose — every existing gate rides it unchanged.
# cpu is the FULL system: the §15 image (mkimage's seventh contract —
# chain + the 18 auth suite + cmd/cpu + aux/listen + the real cpurc +
# tcp17010 + the font payload + §15's own bake-time p9sk1 domain) with
# the bootconf append (init=/amd64/init -c through the 19-01 iso-builder
# seam), so one command brings up net + auth + the cpu listener
# together (cpurc's fail-loud ladder: pairing -> ether -> keyfs ->
# authsrv -> factotum -> aux/listen).  cpu mode additionally runs the
# tier build (subset-build.sh) in step 1 — the §15 bake's named input
# producer — so the full system is genuinely ONE command off a clean
# checkout.  The frozen aarch64 boot-r9 app is NOT touched: the
# full-system mode lands here, on boot-r9-x64, only.
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
#   R9_NETDEV_EMITTER REQUIRED — r9's netdev-args emitter bin (the
#                     flake input's packages.netdev-args); the flake
#                     app exports it.  The qemu netdev+device argv
#                     tokens come ONLY from its output for the
#                     selected mode (D-05: the D-04 hostfwd remap and
#                     the NixOS tap helper path are pinned TOML data,
#                     never script text — no netdev literal here).
#   R9_NET_DOCTOR     REQUIRED for --net=tap — the harvey-net-doctor
#                     app path (16-03/D-14, read-only); the tap leg
#                     runs it FIRST and aborts on any FAIL with the
#                     per-issue remediation blocks inline (D-03).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                     downgrade (see above).
#   R9_CPU            override the cpu model (default: host under kvm,
#                     qemu64 under tcg).
#   R9_NET            default net mode when no --net flag:
#                     slirp|tap|vmnet (default slirp).  The flag wins
#                     over the env (the R9_ACCEL machine-contract
#                     precedent); venue-validated at parse.
#   R9_SYSTEM         default system mode when no --system flag:
#                     terminal|cpu (default terminal).  The flag wins
#                     over the env (the --net precedent); cpu is the
#                     full-system venue (19-09, INT-05).
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
# usage: nix run .#boot-r9-x64 [-- --net=slirp|tap|vmnet] [-- --system=terminal|cpu]   (from the repo root; defaults slirp/terminal — cpu is the full system: net + auth + cpu listener)

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
# a plain -x accepts DIRECTORIES too (the package root passes it —
# measured); the contract is the executable FILE <pkg>/bin/r9-iso-builder
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

# --- step 0c: net mode selection (--net flag > R9_NET > slirp) ---------

# the venue names the valid modes (D-01): linux's legs are slirp+tap,
# darwin's are slirp+vmnet (the manual leg, HNET-04) — a cross-venue
# request is a usage error HERE, never an obscure failure inside qemu
case "$(uname -s)" in
	Linux)	VENUE=linux ;;
	Darwin)	VENUE=darwin ;;
	*) err "uname $(uname -s): unsupported venue for --net (want linux|darwin)" ;;
esac

# the script's argument surface: --net=<mode> and --system=<mode>, the
# = forms alone (--net tap / --system cpu are NOT accepted — one
# accepted form per flag, no ambiguity; duplicates are errors)
NET_FLAG=
SYSTEM_FLAG=
for ARG in "$@"; do
	case "$ARG" in
	--net=*)
		[ -z "$NET_FLAG" ] || err "duplicate --net ('$ARG' after '$NET_FLAG') — one net mode per boot"
		NET_FLAG="$ARG"
		;;
	--system=*)
		[ -z "$SYSTEM_FLAG" ] || err "duplicate --system ('$ARG' after '$SYSTEM_FLAG') — one system mode per boot"
		SYSTEM_FLAG="$ARG"
		;;
	*) err "unknown argument '$ARG' — the accepted forms are --net=<mode> and --system=<mode> (usage: nix run .#boot-r9-x64 -- --net=slirp|tap|vmnet --system=terminal|cpu)" ;;
	esac
done

if [ -n "$NET_FLAG" ]; then
	NET_MODE="${NET_FLAG#--net=}"
else
	NET_MODE="${R9_NET:-slirp}"
fi

case "$NET_MODE" in
	slirp)	;;
	tap)
		[ "$VENUE" = linux ] || err "--net=tap on $VENUE: cross-venue (tap is the linux leg; $VENUE's valid net modes: slirp vmnet)"
		;;
	vmnet)
		[ "$VENUE" = darwin ] || err "--net=vmnet on $VENUE: cross-venue (vmnet is darwin's manual leg, HNET-04; $VENUE's valid net modes: slirp tap)"
		;;
	*) err "--net/R9_NET=$NET_MODE: want slirp|tap|vmnet (the valid net modes)" ;;
esac

# --- step 0d: system mode selection (--system flag > R9_SYSTEM > terminal)

# 19-09 (INT-05, the OQ-4 settlement): cpu boots the FULL system off
# the §15 image with the bootconf append; terminal — the default, and
# the no-flag behavior — keeps the chain path byte-untouched.  The
# --net discipline verbatim: the = form only, duplicates already
# rejected at parse, unknown modes are usage errors NAMING THE VALID
# SET — no silent downgrade, no fall-through to a default venue.
if [ -n "$SYSTEM_FLAG" ]; then
	SYSTEM_MODE="${SYSTEM_FLAG#--system=}"
else
	SYSTEM_MODE="${R9_SYSTEM:-terminal}"
fi

case "$SYSTEM_MODE" in
	terminal)	;;
	cpu)	;;
	*) err "--system/R9_SYSTEM=$SYSTEM_MODE: want terminal|cpu (the valid system modes)" ;;
esac

# the netdev argv comes ONLY from r9's emitter (D-05) — the contract
# check mirrors R9_ISO_BUILDER's -f/-x shape
[ -n "${R9_NETDEV_EMITTER:-}" ] || err "R9_NETDEV_EMITTER unset — run via the flake app (nix run .#boot-r9-x64), which exports r9's netdev-args emitter path (a pin predating the 16-04 advance lacks the export)"
[ -f "$R9_NETDEV_EMITTER" ] && [ -x "$R9_NETDEV_EMITTER" ] \
	|| err "R9_NETDEV_EMITTER $R9_NETDEV_EMITTER: not an executable file (want <pkg>/bin/r9-netdev-args)"

# the tap leg gates on the doctor FIRST (D-03): read-only checks, the
# per-issue remediation blocks printed inline on failure — never
# auto-fixed, never a fall-through to qemu
if [ "$NET_MODE" = tap ]; then
	[ -n "${R9_NET_DOCTOR:-}" ] || err "R9_NET_DOCTOR unset — run via the flake app (nix run .#boot-r9-x64), which exports the harvey-net-doctor path (the tap leg's D-03 gate)"
	[ -f "$R9_NET_DOCTOR" ] && [ -x "$R9_NET_DOCTOR" ] \
		|| err "R9_NET_DOCTOR $R9_NET_DOCTOR: not an executable file (want <pkg>/bin/harvey-net-doctor)"
	DOCTOR_RC=0
	# shellcheck disable=SC2312  # the captured rc is the point: FAIL => print + abort
	DOCTOR_OUT=$(HARVEY="$HARVEY" "$R9_NET_DOCTOR" --mode tap) || DOCTOR_RC=$?
	if [ "$DOCTOR_RC" -ne 0 ]; then
		printf '%s\n' "$DOCTOR_OUT" >&2
		err "tap prereqs unmet — the doctor's findings + per-issue remediation blocks are above; full report: nix run .#net-doctor -- --mode tap (the doctor is read-only: the human applies the remediations, then retries — no silent downgrade, ever)"
	fi
	printf '%s\n' "$DOCTOR_OUT"
fi

# shellcheck disable=SC2312  # the rc rides the ||: an emitter failure is a named contract error (its stderr passed through above)
NETDEV_ARGV=$("$R9_NETDEV_EMITTER" --mode "$NET_MODE") \
	|| err "the netdev emitter failed for mode $NET_MODE (its diagnostics are above; the argv comes only from the pinned r9 TOML — D-05)"
[ -n "$NETDEV_ARGV" ] || err "the netdev emitter printed no netdev argv for mode $NET_MODE"

echo "== r9 kernel package: $R9_KERNEL_X64_PKG"
echo "   kernel:     $R9_KERNEL"
echo "   iso-builder: $R9_ISO_BUILDER"
echo "   netdev emitter: $R9_NETDEV_EMITTER"
echo "   shape:      q35 accel=$R9_ACCEL cpu=$R9_CPU net=$NET_MODE"
echo "   system:     $SYSTEM_MODE"
if [ "$SYSTEM_MODE" = cpu ]; then
	echo "   full system: net + auth + cpu listener together (the §15 image + the bootconf append; cpurc's ladder brings the listeners up — D-07's session recipe can dial 127.0.0.1:17010/5670 once LISTEN-17010 prints)"
else
	echo "   terminal:   the chain image, no append (the existing gates' path)"
fi

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
	if [ "$SYSTEM_MODE" = cpu ]; then
		# cpu's §15 bake consumes the tier outputs (cmd/cpu,
		# aux/listen, sed, ipconfig — mkimage names subset-build.sh
		# as their producer); without this the full system is two
		# commands off a clean checkout, not ONE
		echo "== step 1/3b: amd64 tier build (build/x86_64/subset-build.sh — the §15 bake's input producer)"
		sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
	fi
fi

# --- step 2: bake the bootfs images + select by system mode -------------

# THE IMAGE-SELECTION SEAM (19-09): every mkimage run bakes ALL
# contracts (§15's bootfs-cpu.paq included); the system mode picks
# WHICH paq becomes this boot's /boot/bootfs.paq.  cpu additionally
# asserts §15's manifest PASS line from the bake log (the drawterm
# gate's tee discipline: the grep is the teeth — a failed bake prints
# no §15 PASS line, and the pipeline rc alone would not catch it under
# the tee); terminal keeps the bake invocation byte-identical to the
# pre-19-09 shape (the rc propagates directly, no tee).
CHAIN_PAQ="$HARVEY/build/x86_64/out/bootfs-chain.paq"
CPU_PAQ="$HARVEY/build/x86_64/out/bootfs-cpu.paq"
if [ "$SYSTEM_MODE" = cpu ]; then
	BAKE_LOG=$(mktemp "${TMPDIR:-/tmp}/boot-r9-x64-bake.XXXXXX")
	echo "== step 2/3: bake the bootfs images (build/x86_64/mkimage.sh — log tee'd to $BAKE_LOG; §15's bootfs-cpu.paq is the selection)"
	# shellcheck disable=SC2312  # the rc rides the ||: a bake failure is caught by the §15 PASS-line grep below (tee masks the pipeline rc — the drawterm-gate discipline)
	sh "$HARVEY/build/x86_64/mkimage.sh" 2>&1 | tee "$BAKE_LOG" || true
	grep -q 'PASS: baked.*bootfs-cpu.paq' "$BAKE_LOG" \
		|| { rm -f "$BAKE_LOG"; err "the bake log names no §15 bootfs-cpu.paq PASS line (the §15 bake did not complete its cpu contract — the bake output is above; the §15 manifest lines are the image's own content record)"; }
	rm -f "$BAKE_LOG"
	[ -s "$CPU_PAQ" ] || err "$CPU_PAQ missing/empty after the bake (mkimage's §15 cpu section — the full-system image)"
	BOOT_PAQ="$CPU_PAQ"
else
	echo "== step 2/3: bake bootfs.paq + bootfs-chain.paq (build/x86_64/mkimage.sh)"
	sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
	[ -s "$CHAIN_PAQ" ] || err "$CHAIN_PAQ missing/empty after the bake (mkimage's chain section)"
	BOOT_PAQ="$CHAIN_PAQ"
fi

# --- step 3: compose the ISO + launch qemu -----------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/boot-r9-x64.XXXXXX")
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

if [ "$SYSTEM_MODE" = cpu ]; then
	# the bootconf append (19-01's seam): GRUB's -append carries
	# init=/amd64/init -c, the kernel's bootconf parse seeds it into
	# the ROOT env group, boot(8)'s execinit honors it, init -c runs
	# the real cpurc — the service=cpu identity arrives through the
	# BOOT PROTOCOL, never file content
	echo "== step 3/3: composing the ISO (r9's iso-builder: kernel + bootfs-cpu.paq as /boot/bootfs.paq + the bootconf append init=/amd64/init -c)"
	"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" --append="init=/amd64/init -c" "$BOOT_PAQ" bootfs.paq \
		|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
else
	echo "== step 3/3: composing the ISO (r9's iso-builder: kernel + bootfs-chain.paq as /boot/bootfs.paq)"
	"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$BOOT_PAQ" bootfs.paq \
		|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
fi
ISO="$TMPD/boot.iso"
[ -s "$ISO" ] || err "$ISO missing/empty after the iso-builder"

# D-10 carried: the standard boot speaks Ethernet — the always-on NIC
# rides every composed boot (the aarch64 argv re-keyed to -cdrom; the
# nic-bind post-pass of the smoke gate asserts the driver's bind line).
# 16-04 (D-05): the netdev+device tokens are the emitter's output for
# NET_MODE, word-split unquoted — the emitter prints space-separated
# tokens containing no spaces; NO netdev literal lives in this script.
# shellcheck disable=SC2086  # the word-split IS the argv
set -- qemu-system-x86_64 \
	-M q35 -cpu "$R9_CPU" -smp 1 -m 1024M -accel "$R9_ACCEL" \
	-cdrom "$ISO" \
	$NETDEV_ARGV \
	-nographic

# always print the assembled argv so captured gate logs are
# self-describing (run-r9.sh's discipline); the launching line names
# the selected system so a human terminal shows which venue is up
echo "== launching qemu — system=$SYSTEM_MODE, interactive on stdio (ctrl-a x to quit)"
echo "== qemu argv: $*"

set +e
"$@"
RC=$?
set -e
exit "$RC"
