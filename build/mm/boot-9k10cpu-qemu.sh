# boot-9k10cpu-qemu.sh — the USPACE-10 pool-panic re-test harness
# (phase 06 plan 08, D-04): boot amd64/9k10cpu.elf under PLAIN qemu
# (minimega-free — D-03) with the serial capture attached at launch,
# deadline-wait for the `Plan 9` banner, then classify the WHOLE
# captured log against the recorded 01-04 incident signature set and
# write a verdict file.
#
# The re-test's origin: the v1.0 9k-amd64 kernel booted to the banner,
# then the embedded-root boot process died — "bad magic", "panic: pool
# panic", "boot 1: suicide: sys: trap: fault read addr=0x0" (v1.0
# phase-01 deferred-items #2).  Phase 2 root-caused the same signature
# on the donor kernel to cc/pswt.c's LP64 switch-sort miscompile (fixed
# 7efff3aa3).  This harness re-tests 9k-amd64 built with the pswt-fixed
# 6c and RECORDS THE VERDICT EITHER WAY — a FAIL verdict closes
# USPACE-10 with information (D-04).
#
# Usage (from the repo root):
#   sh build/mm/boot-9k10cpu-qemu.sh
#
# Env overrides:
#   HARVEY             repo root            (default: $PWD)
#   PP_KERNEL          kernel ELF           (default: $HARVEY/amd64/9k10cpu.elf)
#   PP_QEMU            qemu-system-x86_64   (default: PATH lookup)
#   PP_BOOT_BUDGET     seconds to wait for the banner (default: 60 KVM / 600 TCG)
#   PP_CONTINUE_BUDGET post-banner observation window (default: 120 KVM / 600 TCG)
#   PP_LOG             serial capture       (default: $HARVEY/.build/poolpanic-serial.log)
#   VERDICT_OUT        verdict file         (default: $HARVEY/.build/poolpanic-verdict.txt)
#   PP_CLASSIFY_ONLY   classify an existing log and exit (no qemu) —
#                      teeth/triage hook
#
# Verdict contract (locked by D-04):
#   - The verdict is produced from the captured serial log and recorded
#     EITHER WAY; the harness NEVER gates on PASS.
#   - Exit 0 iff a verdict was PRODUCED: the banner was seen AND the
#     classification was written.  No banner within budget — including
#     an EMPTY capture — records VERDICT=FAIL no-banner and exits
#     non-zero: the CI leg never greens on an empty log.
#   - Classification scans the WHOLE log (never a post-banner tail), so
#     an interleaved panic is still caught.
#   - Signature set (the recorded 01-04 incident): "bad magic",
#     "panic", "suicide: sys: trap".  ("pool panic" does NOT exist
#     verbatim in the 9k tree — the robust set is used.)
#   - Healthy continuation markers — the prints the PRODUCTION boot
#     binary actually emits past the 01-04 panic point: "root is from"
#     (boot.c:342's method prompt — the panicked boot died before it),
#     "version..." (boot.c:139, after a rootfs connection), "argc="
#     (boot.c:69, DEBUG-gated builds only).  Any one suffices.
#   - Verdicts: PASS no-panic-signature (boot-continues|banner-only) /
#     FAIL pool-panic-signature / FAIL no-banner.
#
# Accel: /dev/kvm writable → -accel kvm -cpu host; else TCG
# (-accel tcg -cpu qemu64) with the larger budgets — probed EXACTLY
# ONCE per run and recorded in the verdict file; the classification
# assertion set is identical on both paths.
#
# Boot proof: k10 enables COM1 unconditionally (i8250console("0"),
# sys/src/9k/k10/main.c:182) and prints "\nPlan 9" (main.c:191).  The
# banner grep, not the timer, is the source of truth.  qemu's
# `-serial file:` chardev is attached at launch and truncates by
# default — combined with the explicit truncation below, the capture
# can never hold a stale banner (capture-before-start discipline).
#
# Boundary: amd64/9k only.  aarch64/r9 boots stay in build/aarch64/.

set -eu

HARVEY="${HARVEY:-$PWD}"
KERNEL="${PP_KERNEL:-$HARVEY/amd64/9k10cpu.elf}"
LOG="${PP_LOG:-$HARVEY/.build/poolpanic-serial.log}"
VERDICT_OUT="${VERDICT_OUT:-$HARVEY/.build/poolpanic-verdict.txt}"
CLASSIFY_ONLY="${PP_CLASSIFY_ONLY:-}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"

# Resolve a host grep once (the 06-02 idiom, D-02): the greps below
# need -q/-F, which plan9 grep lacks — but a hardcoded /usr/bin/grep
# breaks on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

mkdir -p "$(dirname "$LOG")" "$(dirname "$VERDICT_OUT")"

COMMIT=$(git -C "$HARVEY" rev-parse HEAD 2>/dev/null || echo unknown)

# Resolve an ISO-capable date by probe, not by name: the devshell PATH
# puts Harvey's hostbin first, and Plan 9's date prints the epoch for
# -u +%Y-%m-%d (measured 2026-11-05 — the D-02 hostbin-shadowing class).
DATE=""
for c in gdate /bin/date date; do
	p=$(command -v "$c" 2>/dev/null || true)
	[ -n "$p" ] || continue
	out=$("$p" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)
	case "$out" in
	[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*)
		DATE="$out"; break;;
	esac
done
[ -n "$DATE" ] || DATE="unknown"

# healthy_continuation <log>: true iff the log carries a marker that
# boot.c ran PAST the 01-04 panic point (the production build's prints:
# the "root is from" method prompt; "version..." post-connection;
# "argc=" only in DEBUG builds).
healthy_continuation() {
	_log=$1
	"$GREP" -qF 'root is from' "$_log" 2>/dev/null && return 0
	"$GREP" -q 'version\.\.\.' "$_log" 2>/dev/null && return 0
	"$GREP" -q 'argc=' "$_log" 2>/dev/null && return 0
	return 1
}

# classify_log <log> <accel>: scan the WHOLE log, write the verdict
# file, print the verdict.  Returns 0 iff a verdict was produced
# (banner seen + classification written); 1 when no banner appeared
# (the verdict file still records FAIL no-banner).
classify_log() {
	_log=$1
	_accel=$2
	banner=no
	sigs=""
	healthy=no

	if [ -s "$_log" ] && "$GREP" -q 'Plan 9' "$_log"; then
		banner=yes
	fi

	if [ "$banner" = yes ]; then
		for sig in 'bad magic' 'panic' 'suicide: sys: trap'; do
			if "$GREP" -qF "$sig" "$_log"; then
				sigs="${sigs}${sigs:+; }$sig"
			fi
		done
		if healthy_continuation "$_log"; then
			healthy=yes
		fi
	fi

	if [ "$banner" = no ]; then
		verdict="FAIL no-banner"
	elif [ -n "$sigs" ]; then
		verdict="FAIL pool-panic-signature"
	elif [ "$healthy" = yes ]; then
		verdict="PASS no-panic-signature boot-continues"
	else
		verdict="PASS no-panic-signature banner-only"
	fi

	{
		echo "VERDICT=$verdict"
		echo "banner=$banner"
		echo "signatures=${sigs:-none}"
		echo "healthy_markers=$healthy"
		echo "accel=$_accel"
		echo "kernel=$KERNEL"
		echo "log=$_log"
		echo "commit=$COMMIT"
		echo "date=$DATE"
	} > "$VERDICT_OUT"

	echo "== VERDICT=$verdict"
	echo "   banner=$banner signatures=${sigs:-none} healthy_markers=$healthy accel=$_accel"
	echo "   verdict file: $VERDICT_OUT"

	[ "$banner" = yes ]
}

# Teeth/triage hook: classify an existing capture, no qemu.
if [ -n "$CLASSIFY_ONLY" ]; then
	[ -f "$CLASSIFY_ONLY" ] || err "PP_CLASSIFY_ONLY target missing: $CLASSIFY_ONLY"
	echo "== classify-only: $CLASSIFY_ONLY"
	classify_log "$CLASSIFY_ONLY" "classify-only"
	exit $?
fi

QEMU="${PP_QEMU:-}"
if [ -z "$QEMU" ]; then
	QEMU=$(command -v qemu-system-x86_64 || true)
fi
[ -n "$QEMU" ] && [ -x "$QEMU" ] || err "qemu-system-x86_64 not found — run inside the nix devshell or set PP_QEMU"

[ -f "$KERNEL" ] || err "$KERNEL missing — run 'nix run .#build' first (the pswt-fixed 6c is the point of the re-test)"

# Accel probe: exactly once per run.  KVM iff /dev/kvm is writable,
# else TCG with the larger budgets (boot-9k10cpu.sh's MM_TCG
# discipline, minus minimega).
ACCEL=kvm
ACCEL_ARGS="-accel kvm -cpu host"
if [ -w /dev/kvm ]; then
	:
else
	ACCEL=tcg
	ACCEL_ARGS="-accel tcg -cpu qemu64"
fi

BUDGET="${PP_BOOT_BUDGET:-}"
if [ -z "$BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then BUDGET=600; else BUDGET=60; fi
fi
CONTINUE_BUDGET="${PP_CONTINUE_BUDGET:-}"
if [ -z "$CONTINUE_BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then CONTINUE_BUDGET=600; else CONTINUE_BUDGET=120; fi
fi

QEMU_PID=""
cleanup() {
	status=$?
	[ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
	exit $status
}
trap cleanup EXIT

# Capture-before-start: truncate the log, THEN launch qemu with the
# serial chardev file-attached.  -no-reboot: a triple fault exits qemu
# instead of looping, which the kill -0 poll below catches.
: > "$LOG"
echo "== mode: $ACCEL (banner budget ${BUDGET}s, continue window ${CONTINUE_BUDGET}s)"
echo "== launching: $QEMU -kernel $KERNEL -m 512 $ACCEL_ARGS -display none -no-reboot -serial file:$LOG"
# SC2086: ACCEL_ARGS is intentionally word-split (two fixed args).
# shellcheck disable=SC2086
"$QEMU" -kernel "$KERNEL" -m 512 $ACCEL_ARGS -display none -no-reboot -serial "file:$LOG" &
QEMU_PID=$!

# Deadline-wait for the banner (SECONDS-free: portable under dash).
echo "== waiting for 'Plan 9' banner (budget ${BUDGET}s)"
elapsed=0
found=1
while [ "$elapsed" -lt "$BUDGET" ]; do
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		echo "== qemu exited before the banner (${elapsed}s) — classifying what was captured"
		break
	fi
	if "$GREP" -q 'Plan 9' "$LOG" 2>/dev/null; then
		found=0
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
done

# Post-banner observation window: the recorded incident printed its
# signature AFTER the banner (boot process start), and the healthy
# markers print later still — classify only after giving the log a
# fair window.  Break early on the first signature line (the FAIL
# classification is then locked) or when both healthy markers have
# printed (boot continued well past the pool-panic point).
if [ "$found" -eq 0 ]; then
	echo "== banner captured at ${elapsed}s — observing for ${CONTINUE_BUDGET}s (signature set + healthy continuation markers)"
	celapsed=0
	while [ "$celapsed" -lt "$CONTINUE_BUDGET" ]; do
		if "$GREP" -qF 'bad magic' "$LOG" 2>/dev/null || \
		   "$GREP" -qF 'panic' "$LOG" 2>/dev/null || \
		   "$GREP" -qF 'suicide: sys: trap' "$LOG" 2>/dev/null; then
			echo "== signature line observed at +${celapsed}s"
			break
		fi
		if healthy_continuation "$LOG"; then
			echo "== healthy continuation marker observed at +${celapsed}s"
			break
		fi
		if ! kill -0 "$QEMU_PID" 2>/dev/null; then
			echo "== qemu exited at +${celapsed}s — classifying the final log"
			break
		fi
		sleep 5
		celapsed=$((celapsed + 5))
	done
fi

# Stop qemu and reap it before classifying, so the chardev's buffered
# writes flush to the capture.
if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
	kill "$QEMU_PID" 2>/dev/null || true
fi
wait "$QEMU_PID" 2>/dev/null || true
QEMU_PID=""
sleep 2

classify_log "$LOG" "$ACCEL"
exit $?
