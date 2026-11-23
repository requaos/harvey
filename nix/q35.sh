# nix/q35.sh — build and boot Harvey's own 9k kernel on q35 (D-26).
#
# The one Harvey command Phase 1 delivers (D-08 narrowed by D-20 and
# settled by D-26): no r9 input, no composed image, no siblings.  It
# builds amd64/9k10cpu.elf through Harvey's existing platform build (the
# same script the `build` app runs: nix/build.sh on Linux, nix/vm-build.sh
# on darwin) when the kernel is absent or --build is given, records the
# kernel's sha256, then launches it under `qemu-system-x86_64 -M q35` with
# virtio-net and a serial capture, classifying the `root is from (tcp)[tcp]:`
# prompt with the S5 signature check (spikes/s5/boot-q35.sh, the harness
# that proved the Mac TCG and x86_64 KVM legs).
#
# The launch half is read-only toward the checkout: the serial capture
# goes to .build/ (gitignored) and nothing else is written.  The build
# half is Harvey's own; it needs `nix run .#setup` and `nix run .#toolchain`
# to have populated the host bin (nix/build.sh names the missing tool).
#
# Acceleration is never downgraded silently (D-13's discipline, carried
# from S5): KVM is used when /dev/kvm is writable; on a host without it
# the caller must say HARVEY_Q35_ACCEL=tcg explicitly.  There is no
# implicit TCG fallback.
#
# Usage (from the Harvey checkout root):
#   nix run .#q35                 # build if needed, then boot
#   nix run .#q35 -- --build      # force a kernel build first
#   nix run .#q35 -- --no-build   # boot the existing kernel only
#   HARVEY_Q35_ACCEL=tcg nix run .#q35 -- --no-build   # e.g. a Mac host
#
# Environment:
#   HARVEY              checkout root (default: git toplevel of PWD, else PWD)
#   HARVEY_Q35_ACCEL    kvm | tcg  (default: kvm when /dev/kvm is writable;
#                                  required explicitly otherwise)
#   HARVEY_Q35_LOG      serial capture (default: $HARVEY/.build/q35-serial.log)
#   HARVEY_Q35_BOOT_BUDGET    seconds to wait for the banner (600 tcg / 60 kvm)
#   HARVEY_Q35_PROMPT_BUDGET  seconds after the banner (600 tcg / 120 kvm)
#   HARVEY_Q35_QEMU     qemu-system-x86_64 (default: PATH lookup; the app's
#                       runtimeInputs put nixpkgs' qemu on PATH)
#
# Output contract:
#   Q35-KERNEL <path> sha256=<hex> bytes=<n>
#   Q35-LOG <path>
#   Q35-BANNER <yes|no>
#   Q35-PROMPT <the `root is from` line, or none>
#   Q35-SIGS <space-free list separated by ;, or none>
#   Q35-BANNER_SECONDS <n>
#   Q35-PROMPT_SECONDS <n>   (from launch, not from the banner)
#   Q35-RESULT machine=q35 accel=<a> banner=<yes|no> prompt=<yes|no> sigs=<list|none>
#
# Exit 0 iff the banner and the prompt were seen and no S5 signature
# matched; exit 2 on a configuration/runtime error (named `q35: error:`).

set -eu

err() {
	echo "q35: error: $*" >&2
	exit 2
}

BUILD_MODE=auto
for arg in "$@"; do
	case "$arg" in
	--build) BUILD_MODE=force ;;
	--no-build) BUILD_MODE=never ;;
	-h | --help)
		sed -n 's/^# \{0,1\}//p' "$0" | sed -n '/^Usage (from the Harvey checkout root):/,/^HARVEY_Q35_QEMU/p'
		exit 0
		;;
	*)
		err "bad-argument '$arg' (usage: nix run .#q35 -- [--build|--no-build])"
		;;
	esac
done

HARVEY="${HARVEY:-$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)}"
[ -d "$HARVEY/sys/src" ] ||
	err "not-a-checkout: HARVEY=$HARVEY has no sys/src (run from the Harvey checkout root or set HARVEY)"
KERNEL="$HARVEY/amd64/9k10cpu.elf"

# --- the build half (Harvey's own platform build) ----------------------
if [ "$BUILD_MODE" != never ] && { [ "$BUILD_MODE" = force ] || [ ! -f "$KERNEL" ]; }; then
	os=$(uname -s)
	case "$os" in
	Linux) build_script=nix/build.sh ;;
	Darwin) build_script=nix/vm-build.sh ;;
	*) err "unsupported-host '$os': Harvey's kernel build is Linux-native or the darwin lima VM" ;;
	esac
	[ -f "$HARVEY/$build_script" ] ||
		err "build-script-missing: $HARVEY/$build_script"
	echo "q35: building the kernel through $build_script (Harvey's platform build)"
	if ! (cd "$HARVEY" && bash "$HARVEY/$build_script"); then
		err "build-failed: $build_script exited non-zero — no kernel to boot"
	fi
fi
[ -f "$KERNEL" ] ||
	err "kernel-missing: $KERNEL (run with --build; setup and toolchain must have run first)"

kernel_sha=$(sha256sum "$KERNEL" | cut -d' ' -f1)
kernel_bytes=$(wc -c <"$KERNEL" | tr -d ' ')
echo "Q35-KERNEL $KERNEL sha256=$kernel_sha bytes=$kernel_bytes"

# --- acceleration (never a silent downgrade) ---------------------------
if [ -w /dev/kvm ]; then
	ACCEL="${HARVEY_Q35_ACCEL:-kvm}"
else
	[ -n "${HARVEY_Q35_ACCEL:-}" ] ||
		err "accel-unavailable: /dev/kvm is not writable on this host; set HARVEY_Q35_ACCEL=tcg explicitly (no silent TCG downgrade)"
	ACCEL="$HARVEY_Q35_ACCEL"
fi
case "$ACCEL" in
kvm)
	[ -w /dev/kvm ] ||
		err "kvm-unavailable: HARVEY_Q35_ACCEL=kvm requires a writable /dev/kvm"
	CPU=host
	;;
tcg) CPU=qemu64 ;;
*) err "bad-accel: HARVEY_Q35_ACCEL must be tcg or kvm, got '$ACCEL'" ;;
esac

BOOT_BUDGET="${HARVEY_Q35_BOOT_BUDGET:-}"
[ -n "$BOOT_BUDGET" ] || {
	if [ "$ACCEL" = tcg ]; then BOOT_BUDGET=600; else BOOT_BUDGET=60; fi
}
PROMPT_BUDGET="${HARVEY_Q35_PROMPT_BUDGET:-}"
[ -n "$PROMPT_BUDGET" ] || {
	if [ "$ACCEL" = tcg ]; then PROMPT_BUDGET=600; else PROMPT_BUDGET=120; fi
}

QEMU_NAME="${HARVEY_Q35_QEMU:-qemu-system-x86_64}"
QEMU=$(command -v "$QEMU_NAME" 2>/dev/null || true)
[ -n "$QEMU" ] ||
	err "qemu-missing: '$QEMU_NAME' is not on PATH (the app's runtimeInputs carry nixpkgs' qemu)"

LOG="${HARVEY_Q35_LOG:-$HARVEY/.build/q35-serial.log}"
mkdir -p "$(dirname -- "$LOG")"
echo "Q35-LOG $LOG"

# --- the launch (capture-before-start, kill/reap on every exit) --------
# POSIX sh has no arrays; `set --` builds the argv.
set -- -M q35 -accel "$ACCEL" -cpu "$CPU" -m 512 -kernel "$KERNEL" \
	-display none -no-reboot -serial "file:$LOG" \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0

QEMU_PID=""
stop_qemu() {
	if [ -n "$QEMU_PID" ]; then
		if kill -0 "$QEMU_PID" 2>/dev/null; then
			kill "$QEMU_PID" 2>/dev/null || true
		fi
		wait "$QEMU_PID" 2>/dev/null || true
		QEMU_PID=""
	fi
}
cleanup() {
	status=$?
	trap - EXIT INT TERM HUP
	stop_qemu
	exit "$status"
}
trap cleanup EXIT INT TERM HUP

: >"$LOG"
printf 'Q35-CMD:'
for arg in "$QEMU" "$@"; do
	printf ' %s' "$arg"
done
printf '\n'
echo "q35: launching qemu-system-x86_64 -M q35 -accel $ACCEL (serial capture: $LOG)"
"$QEMU" "$@" &
QEMU_PID=$!

banner=no
banner_seconds="$BOOT_BUDGET"
elapsed=0
while [ "$elapsed" -lt "$BOOT_BUDGET" ]; do
	if grep -aq 'Plan 9' "$LOG" 2>/dev/null; then
		banner=yes
		banner_seconds=$elapsed
		break
	fi
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		banner_seconds=$elapsed
		break
	fi
	sleep 1
	elapsed=$((elapsed + 1))
done
if [ "$banner" = no ] && grep -aq 'Plan 9' "$LOG" 2>/dev/null; then
	banner=yes
fi

prompt=no
prompt_seconds="$banner_seconds"
sigs=""
if [ "$banner" = yes ]; then
	celapsed=0
	while [ "$celapsed" -lt "$PROMPT_BUDGET" ]; do
		if grep -aqF 'root is from' "$LOG" 2>/dev/null; then
			prompt=yes
			prompt_seconds=$((banner_seconds + celapsed))
			break
		fi
		for sig in 'bad magic' 'panic' 'suicide: sys: trap'; do
			if grep -aqF "$sig" "$LOG" 2>/dev/null; then
				sigs="${sigs}${sigs:+; }$sig"
			fi
		done
		if [ -n "$sigs" ]; then
			prompt_seconds=$((banner_seconds + celapsed))
			break
		fi
		if ! kill -0 "$QEMU_PID" 2>/dev/null; then
			prompt_seconds=$((banner_seconds + celapsed))
			break
		fi
		sleep 1
		celapsed=$((celapsed + 1))
	done
	if [ "$prompt" = no ] && grep -aqF 'root is from' "$LOG" 2>/dev/null; then
		prompt=yes
	fi
	# The final whole-capture signature scan (the 01-04 discipline).
	for sig in 'bad magic' 'panic' 'suicide: sys: trap'; do
		case "$sigs" in
		*"$sig"*) : ;;
		*)
			if grep -aqF "$sig" "$LOG" 2>/dev/null; then
				sigs="${sigs}${sigs:+; }$sig"
			fi
			;;
		esac
	done
fi

# Stop and reap before reading the capture, so buffered writes flush.
stop_qemu
sleep 1

prompt_line=$( (grep -aF 'root is from' "$LOG" 2>/dev/null || true) | tail -n 1 | tr -d '\r')
[ -n "$prompt_line" ] || prompt_line=none
[ -n "$sigs" ] || sigs=none

echo "Q35-BANNER $banner"
echo "Q35-PROMPT $prompt_line"
echo "Q35-SIGS $sigs"
echo "Q35-BANNER_SECONDS $banner_seconds"
echo "Q35-PROMPT_SECONDS $prompt_seconds"
echo "Q35-RESULT machine=q35 accel=$ACCEL banner=$banner prompt=$prompt sigs=$sigs"

[ "$banner" = yes ] && [ "$prompt" = yes ] && [ "$sigs" = none ]
