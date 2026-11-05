#!/bin/sh
# boot-9k10t1-sweep.sh — the Harvey-kernel tier venue harness (06-09,
# G-06-1; maintainer direction 2026-11-05: on amd64/x86_64 the tier donor
# evidence comes from Harvey's OWN kernel, not 9front).
#
# Boots amd64/9k10t1.elf — k10cpu's proven device set with the 43-file
# tier embed (the amd64 tier-1 read-only set + the D-10 sweep) baked
# into devroot — under PLAIN qemu-system-x86_64 and asserts the marker
# set host-side from the serial capture.  The venue is self-contained:
# NO minimega (D-03), NO network devices, NO -append, NO QMP/gdb
# sockets, NO srv9, NO 9front tree anywhere — the sweep runs from the
# embedded root at boot (k10t1.rc IS /boot/boot) and pid 1 never exits
# (the boot script's trailing console block), so the harness kills qemu
# once T1-DONE lands.
#
# Usage (from the repo root, inside the nix devshell):
#   nix develop -c sh build/mm/boot-9k10t1-sweep.sh
#
# Env overrides:
#   HARVEY            repo root           (default: $PWD)
#   T1_KERNEL         kernel ELF          (default: $HARVEY/amd64/9k10t1.elf)
#   T1_QEMU           qemu-system-x86_64  (default: PATH lookup)
#   T1_BOOT_BUDGET    seconds to wait for the banner (default: 60 KVM / 600 TCG)
#   T1_SWEEP_BUDGET   seconds to wait for T1-DONE    (default: 300 KVM / 1500 TCG
#                                                    — 35 binaries under TCG, the
#                                                    donor venue's 1500s scale)
#   T1_LOG            serial capture      (default: $HARVEY/.build/tier-9k-serial.log)
#   T1_RESULT         result file         (default: $HARVEY/.build/tier-9k-result.txt)
#   T1_CLASSIFY_ONLY  classify an existing log and exit (no qemu) —
#                     teeth/triage hook (mirrors PP_CLASSIFY_ONLY)
#
# Marker contract (asserted on the CR-normalized capture):
#   - the `Plan 9` banner is present (else FAIL no-banner, exit 1);
#   - the expected marker set is COMPUTED from build/aarch64/tiers/
#     tier1-cmds.txt with exactly subset-exec.sh:803-814's awk + mapping
#     (the six driver-only exclusions stay excluded: 9k/boot, stage/init,
#     cmd/paqfs:paqfs, cmd/7c, cmd/7l, cmd/cc), MINUS stacksmoke (an
#     r9-era stack-growth test, never staged on this venue), PLUS
#     float-d01 (the read-only block's mandatory canary runs on every
#     venue) — D-13's data is the single source, never a second
#     hardcoded list.  selfhost-compile/selfhost/libtest-tdraw/
#     libtest-disktest are also required: their named T1-SKIP lines are
#     this venue's USPACE-04 honesty (the done criterion's 24 whitelisted
#     SKIPs) and an absent SKIP line must red the gate exactly like an
#     absent T1-OK;
#   - each expected marker m requires a boundary-anchored `T1-OK m` OR
#     (m in the sanctioned SKIP whitelist AND a boundary-anchored
#     `T1-SKIP m`) — anchor shape `T1-OK m([^A-Za-z0-9.-]|$)` (WR-06's
#     suggested fix: the unanchored substring form is the mk<mkdir /
#     cp<cpp false-green class);
#   - the sanctioned SKIP whitelist is a fixed enumerated list below
#     (24 names); the CONVERSE is asserted too — every emitted T1-SKIP
#     must be IN the whitelist (a new SKIP name reds the gate and forces
#     the conscious venue decision);
#   - zero T1-FAIL lines; zero case-insensitive `panic|trap:` lines
#     (the donor gate's invariant); T1-DONE present.
#   On any failure the marker-state digest plus the last 40 lines go to
#   stderr (06-10's CI step mirrors the digest into GITHUB_STEP_SUMMARY
#   — D-16's self-print convention: runner logs are auth-gated).
#
# Accel: /dev/kvm writable → -accel kvm -cpu host; else TCG (-accel tcg
# -cpu qemu64) with the larger budgets — probed EXACTLY ONCE per run and
# recorded in the result file.  Capture-before-start: the log is
# truncated, THEN qemu launches with -serial file: (no stale banner).
#
# Boundary: amd64/9k only.  aarch64 donor/r9 venues stay in
# build/aarch64/.

set -eu

HARVEY="${HARVEY:-$PWD}"
KERNEL="${T1_KERNEL:-$HARVEY/amd64/9k10t1.elf}"
LOG="${T1_LOG:-$HARVEY/.build/tier-9k-serial.log}"
RESULT="${T1_RESULT:-$HARVEY/.build/tier-9k-result.txt}"
CLASSIFY_ONLY="${T1_CLASSIFY_ONLY:-}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"

# Resolve a host grep once (the 06-02 idiom, D-02): the greps below need
# -q/-E, which plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

# The sanctioned SKIP whitelist (fixed, enumerated — 24 names): the
# write-flow / build-chain / selfhost / ipconfig / factotum entries this
# venue honestly cannot run (embedded read-only root; no writable
# scratch, no toolchain payloads, no network/auth), plus the two libtest
# markers (no libtest binaries are staged — the amd64 libtest build
# machinery is out of this gap's scope).  NEVER an unearned T1-OK
# (USPACE-04).
SKIPLIST="mkdir cp mv rm bc dd tar tee chmod touch split look ed cpp yacc lex mk 7a selfhost-compile selfhost ipconfig factotum libtest-tdraw libtest-disktest"

# The expected marker set — computed from the D-13 tier data with
# EXACTLY subset-exec.sh:803-814's awk + mapping (six driver-only
# exclusions kept), MINUS stacksmoke (an r9-era stack-growth test,
# never staged on this venue), PLUS float-d01 (the read-only block runs
# it on every venue) and the four markers whose evidence is the named
# SKIP on this venue (selfhost-compile, selfhost — the excluded
# cmd/7c+cmd/7l entries' D-11 markers — and libtest-tdraw,
# libtest-disktest): an absent SKIP line reds the gate exactly like an
# absent T1-OK.
compute_expected() {
	EXPECTED=$(
		awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/aarch64/tiers/tier1-cmds.txt" |
		while read -r e; do
			case "$e" in
			9k/boot|stage/init|cmd/paqfs:paqfs|cmd/7c|cmd/7l|cmd/cc) continue ;;
			stage/stacksmoke) continue ;;
			esac
			e="${e#cmd/}"
			case "$e" in *:*) e="${e##*:}" ;; esac
			echo "${e##*/}"
		done
	)
	echo "$EXPECTED float-d01 selfhost-compile selfhost libtest-tdraw libtest-disktest"
}

# in_whitelist <name>: fixed-list membership (space-padded exact word)
in_whitelist() {
	case " $SKIPLIST " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# classify_log <log> <accel>: CR-normalize a copy of the log and assert
# the full marker contract on it.  Returns 0 on T1-VENUE-PASS, 1 on any
# failure (the marker-state digest + last 40 lines go to stderr).
classify_log() {
	_log=$1
	_accel=$2
	_norm=$(mktemp "${TMPDIR:-/tmp}/t1-norm.XXXXXX") || err "mktemp failed"
	tr -d '\r' < "$_log" > "$_norm" 2>/dev/null || true

	if [ ! -s "$_norm" ] || ! "$GREP" -q 'Plan 9' "$_norm"; then
		echo "FAIL no-banner" >&2
		{
			echo "verdict=FAIL no-banner"
			echo "accel=$_accel"
			echo "kernel=$KERNEL"
			echo "log=$_log"
			echo "commit=$COMMIT"
			echo "date=$DATE"
		} > "$RESULT"
		rm -f "$_norm"
		return 1
	fi

	_fails=0
	_missing=""
	_badskip=""
	_ok=0
	_skip=0
	for m in $(compute_expected); do
		if "$GREP" -qE 'T1-OK '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_ok=$((_ok + 1))
			continue
		fi
		if in_whitelist "$m" && "$GREP" -qE 'T1-SKIP '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_skip=$((_skip + 1))
			continue
		fi
		_missing="$_missing $m"
		_fails=1
	done

	# converse: every emitted T1-SKIP must be whitelisted (a new SKIP
	# name reds the gate — the conscious-venue-decision tripwire)
	for s in $("$GREP" -oE 'T1-SKIP [A-Za-z0-9.-]+' "$_norm" | awk '{print $2}' | sort -u); do
		if ! in_whitelist "$s"; then
			_badskip="$_badskip $s"
			_fails=1
		fi
	done

	_nfail=0
	if "$GREP" -q 'T1-FAIL' "$_norm"; then
		_nfail=$("$GREP" -c 'T1-FAIL' "$_norm" || true)
		_fails=1
	fi
	_fault=""
	if "$GREP" -qiE 'panic|trap:' "$_norm"; then
		_fault="yes"
		_fails=1
	fi
	_done=no
	if "$GREP" -q 'T1-DONE' "$_norm"; then
		_done=yes
	else
		_fails=1
	fi

	if [ "$_fails" -ne 0 ]; then
		echo "== T1-VENUE-FAIL" >&2
		[ -z "$_missing" ] || echo "   missing markers:$_missing" >&2
		[ -z "$_badskip" ] || echo "   unwhitelisted T1-SKIP names:$_badskip" >&2
		[ "$_nfail" = 0 ] || echo "   T1-FAIL lines: $_nfail" >&2
		[ -z "$_fault" ] || echo "   kernel fault lines present (panic|trap:)" >&2
		[ "$_done" = yes ] || echo "   T1-DONE absent (the sweep did not run to completion)" >&2
		echo "   marker-state digest:" >&2
		"$GREP" -oE 'T1-(OK|FAIL|SKIP) [A-Za-z0-9.-]+|T1-DONE' "$_norm" >&2 || true
		echo "   last 40 lines of $_log:" >&2
		tail -40 "$_norm" >&2
		{
			echo "verdict=FAIL"
			echo "ok=$_ok"
			echo "skip=$_skip"
			echo "fail=$_nfail"
			echo "done=$_done"
			echo "accel=$_accel"
			echo "kernel=$KERNEL"
			echo "log=$_log"
			echo "commit=$COMMIT"
			echo "date=$DATE"
		} > "$RESULT"
		rm -f "$_norm"
		return 1
	fi

	{
		echo "verdict=PASS"
		echo "ok=$_ok"
		echo "skip=$_skip"
		echo "fail=0"
		echo "done=$_done"
		echo "accel=$_accel"
		echo "kernel=$KERNEL"
		echo "log=$_log"
		echo "commit=$COMMIT"
		echo "date=$DATE"
	} > "$RESULT"
	echo "== T1-VENUE-PASS ok=$_ok skip=$_skip fail=0 done=yes accel=$_accel commit=$COMMIT"
	echo "   result file: $RESULT"
	rm -f "$_norm"
	return 0
}

COMMIT=$(git -C "$HARVEY" rev-parse HEAD 2>/dev/null || echo unknown)

# Resolve an ISO-capable date by probe, not by name: the devshell PATH
# puts Harvey's hostbin first, and Plan 9's date prints the epoch for
# -u +%Y-%m-%d (the D-02 hostbin-shadowing class).
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

mkdir -p "$(dirname "$LOG")" "$(dirname "$RESULT")"

# Teeth/triage hook: classify an existing capture, no qemu.
if [ -n "$CLASSIFY_ONLY" ]; then
	[ -f "$CLASSIFY_ONLY" ] || err "T1_CLASSIFY_ONLY target missing: $CLASSIFY_ONLY"
	echo "== classify-only: $CLASSIFY_ONLY"
	classify_log "$CLASSIFY_ONLY" "classify-only"
	exit $?
fi

QEMU="${T1_QEMU:-}"
if [ -z "$QEMU" ]; then
	QEMU=$(command -v qemu-system-x86_64 || true)
fi
[ -n "$QEMU" ] && [ -x "$QEMU" ] || err "qemu-system-x86_64 not found — run inside the nix devshell or set T1_QEMU"

[ -f "$KERNEL" ] || err "$KERNEL missing — run build/mm/build-9k10t1.sh first (the venue kernel carries the tier embed)"

# Accel probe: exactly once per run.  KVM iff /dev/kvm is writable, else
# TCG with the larger budgets.
ACCEL=kvm
ACCEL_ARGS="-accel kvm -cpu host"
if [ -w /dev/kvm ]; then
	:
else
	ACCEL=tcg
	ACCEL_ARGS="-accel tcg -cpu qemu64"
fi

BUDGET="${T1_BOOT_BUDGET:-}"
if [ -z "$BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then BUDGET=600; else BUDGET=60; fi
fi
SWEEP_BUDGET="${T1_SWEEP_BUDGET:-}"
if [ -z "$SWEEP_BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then SWEEP_BUDGET=1500; else SWEEP_BUDGET=300; fi
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
# instead of looping, which the kill -0 poll below catches.  The venue
# is self-contained: no network devices, no -append, no QMP/gdb sockets.
: > "$LOG"
echo "== mode: $ACCEL (banner budget ${BUDGET}s, sweep budget ${SWEEP_BUDGET}s)"
echo "== launching: $QEMU -kernel $KERNEL -m 512 $ACCEL_ARGS -display none -no-reboot -serial file:$LOG"
# SC2086: ACCEL_ARGS is intentionally word-split (two fixed args).
# shellcheck disable=SC2086
"$QEMU" -kernel "$KERNEL" -m 512 $ACCEL_ARGS -display none -no-reboot -serial "file:$LOG" &
QEMU_PID=$!

# Phase A: deadline-wait for the banner (SECONDS-free: portable under
# dash); break if qemu dies.
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

# Phase B: poll for T1-DONE within the sweep budget; early-break on the
# poolpanic harness's signature set (the FAIL is then locked at classify
# time) or if qemu dies.
if [ "$found" -eq 0 ]; then
	echo "== banner captured at ${elapsed}s — sweeping (budget ${SWEEP_BUDGET}s)"
	celapsed=0
	while [ "$celapsed" -lt "$SWEEP_BUDGET" ]; do
		if "$GREP" -q 'T1-DONE' "$LOG" 2>/dev/null; then
			echo "== T1-DONE observed at +${celapsed}s"
			break
		fi
		if "$GREP" -qF 'bad magic' "$LOG" 2>/dev/null || \
		   "$GREP" -qF 'panic' "$LOG" 2>/dev/null || \
		   "$GREP" -qF 'suicide: sys: trap' "$LOG" 2>/dev/null; then
			echo "== signature line observed at +${celapsed}s"
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
