#!/bin/sh
# boot-9kdraw-trace.sh — the 15-06 trace venue harness (USPACE-08,
# D-05/D-06/D-07): boots the draw donor with the TRACE payload and
# captures the scripted-interaction syscall traces.
#
# Boots the EXISTING venue artifacts (amd64/9kdraw.elf +
# build/x86_64/out/bootfs-draw.paq — build/mm/build-9kdraw.sh's
# products; this script only boots and reads, it never touches the
# /amd64 build tree — the same-wave lock discipline), waits for
# TRACE-VENUE-DONE (presence-only, deadline-polled, TCG-generous —
# never interleaving order), classifies, then produces BOTH evidence
# layers (D-06):
#   - the RAW per-pid framed fragment logs (extracted verbatim from
#     the capture's egress sections)
#   - the DISTILLED per-binary syscall tables (build/x86_64/
#     trace-distill.sh — the committed derivation path)
#
# The session set is whatever build-9kdraw.sh baked: the sidecar
# out/bootfs-draw.trace-sessions is the single source (one session
# name per line; "rejoin" marks the drawtest/arctest leg).  Every
# session is gated INDEPENDENTLY — a missing marker fails the run but
# never voids the other sessions' evidence (the gate prints exactly
# which markers are missing).
#
# Venue provenness rule (the flagged prohibition): the four bring-up
# markers (DRAW-SMOKE-OK FONT-CHANNEL-OK KBIN-OK MOUSEIN-OK) MUST be
# on the SAME capture as the sessions — a trace over an unproven venue
# measures the venue's brokenness, and no evidence is distilled from a
# capture lacking them.
#
# Usage (from the repo root, inside the nix devshell):
#   nix develop -c sh build/mm/boot-9kdraw-trace.sh
#
# Env overrides:
#   HARVEY           repo root (default $PWD)
#   TRACE_KERNEL     kernel ELF (default $HARVEY/amd64/9kdraw.elf)
#   TRACE_PAQ        payload paq (default $HARVEY/build/x86_64/out/bootfs-draw.paq)
#   TRACE_QEMU       qemu-system-x86_64 (default PATH lookup)
#   TRACE_MEM        guest memory (default 512)
#   TRACE_BUDGET     seconds to wait for TRACE-VENUE-DONE (default 1800 KVM / 3600 TCG)
#   TRACE_LOG        serial capture (default $HARVEY/.build/draw-trace-serial.log)
#   TRACE_EVIDENCE   evidence dir (default the phase 15 evidence dir)
#   TRACE_EVIDENCE_NAME  the committed capture's basename (default 15-06-trace-venue)
#   TRACE_MONITOR    a unix socket path: qemu's monitor listens there
#                    (screendump debugging of the replay geometry; unset
#                    = no monitor device)
#
# Exit: 0 iff every baked session completed (its SCRIPT-DONE marker),
# every egress landed (TRACE-EGRESS-DONE-<bin>), the rejoin (when
# baked) is green, the four bring-up markers are present, and both
# evidence layers distilled for every session.

set -eu

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

KERNEL="${TRACE_KERNEL:-$HARVEY/amd64/9kdraw.elf}"
PAQ="${TRACE_PAQ:-$HARVEY/build/x86_64/out/bootfs-draw.paq}"
SIDECAR="$HARVEY/build/x86_64/out/bootfs-draw.trace-sessions"
EVIDENCE="${TRACE_EVIDENCE:-$HARVEY/.planning/phases/15-userspace-tiers-bootfs-payload-amd64/evidence}"
EVNAME="${TRACE_EVIDENCE_NAME:-15-06-trace-venue}"

[ -s "$KERNEL" ] || err "$KERNEL missing — run 'nix develop -c sh build/mm/build-9kdraw.sh' first"
[ -s "$PAQ" ] || err "$PAQ missing — run 'nix develop -c sh build/mm/build-9kdraw.sh' first"
[ -f "$SIDECAR" ] || err "$SIDECAR missing — the paq was baked without a trace payload (re-run build-9kdraw.sh)"

SESSIONS=$(grep -v '^#' "$SIDECAR" | tr -s ' \n' ' ' | sed 's/^ *//; s/ *$//')
[ -n "$SESSIONS" ] || err "the sidecar lists no sessions"
echo "== sessions baked into the payload:$SESSIONS"

QEMU="${TRACE_QEMU:-}"
if [ -z "$QEMU" ]; then
	QEMU=$(command -v qemu-system-x86_64 || true)
fi
[ -n "$QEMU" ] && [ -x "$QEMU" ] || err "qemu-system-x86_64 not found — run inside the nix devshell or set TRACE_QEMU"
TRACE_MEM="${TRACE_MEM:-512}"

GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

# accel probe (once): KVM iff /dev/kvm writable, else TCG
ACCEL=kvm
ACCEL_ARGS="-accel kvm -cpu host"
if [ -w /dev/kvm ]; then
	:
else
	ACCEL=tcg
	ACCEL_ARGS="-accel tcg -cpu qemu64"
fi
BUDGET="${TRACE_BUDGET:-}"
if [ -z "$BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then BUDGET=3600; else BUDGET=1800; fi
fi

mkdir -p "$EVIDENCE"
BOOTLOG="${TRACE_LOG:-$HARVEY/.build/draw-trace-serial.log}"
mkdir -p "$(dirname "$BOOTLOG")"

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

MON_ARGS=""
if [ -n "${TRACE_MONITOR:-}" ]; then
	rm -f "$TRACE_MONITOR"
	MON_ARGS="-monitor unix:$TRACE_MONITOR,server,nowait"
fi

: > "$BOOTLOG"
echo "== trace leg: mode $ACCEL (banner budget 120s, session budget ${BUDGET}s)"
echo "== launching: $QEMU -kernel $KERNEL -initrd $PAQ -append -v -vga std -m $TRACE_MEM $ACCEL_ARGS -display none -no-reboot -serial file:$BOOTLOG ${MON_ARGS:+(monitor: $TRACE_MONITOR)}"
QEMU_PID=""
cleanup() {
	status=$?
	[ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
	exit $status
}
trap cleanup EXIT
# SC2086: ACCEL_ARGS/MON_ARGS are intentionally word-split (fixed argv
# fragments, never filenames).
# shellcheck disable=SC2086
"$QEMU" -kernel "$KERNEL" -initrd "$PAQ" -append -v -vga std -m "$TRACE_MEM" $ACCEL_ARGS -display none -no-reboot -serial "file:$BOOTLOG" $MON_ARGS &
QEMU_PID=$!

# Phase A: deadline-wait for the banner
elapsed=0
found=1
while [ "$elapsed" -lt 120 ]; do
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		echo "== qemu exited before the banner (${elapsed}s) — classifying what was captured"
		break
	fi
	if "$GREP" -q 'Plan 9' "$BOOTLOG" 2>/dev/null; then
		found=0
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
done

# Phase B: poll for TRACE-VENUE-DONE within the budget; early-break on
# the panic signature or qemu death
if [ "$found" -eq 0 ]; then
	echo "== banner captured at ${elapsed}s — waiting for TRACE-VENUE-DONE (budget ${BUDGET}s)"
	celapsed=0
	while [ "$celapsed" -lt "$BUDGET" ]; do
		if "$GREP" -q 'TRACE-VENUE-DONE' "$BOOTLOG" 2>/dev/null; then
			echo "== TRACE-VENUE-DONE observed at +${celapsed}s"
			break
		fi
		if "$GREP" -qF 'panic' "$BOOTLOG" 2>/dev/null || \
		   "$GREP" -qF 'sys: trap' "$BOOTLOG" 2>/dev/null; then
			echo "== signature line observed at +${celapsed}s — classifying the failure capture"
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

# stop qemu and reap it so the chardev's buffered writes flush
if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
	kill "$QEMU_PID" 2>/dev/null || true
fi
wait "$QEMU_PID" 2>/dev/null || true
QEMU_PID=""
sleep 2

# --- classify ---------------------------------------------------------
# the venue provenness rule FIRST: no four markers, no distillation
RC=0
"$GREP" -q 'Plan 9' "$BOOTLOG" || { echo "TRACE-GATE-FAIL: no banner"; RC=1; }
for m in DRAW-SMOKE-OK FONT-CHANNEL-OK KBIN-OK MOUSEIN-OK; do
	"$GREP" -q "$m" "$BOOTLOG" || { echo "TRACE-GATE-FAIL: bring-up marker $m missing (venue unproven — no evidence distilled)"; RC=1; }
done
PROVEN=0
if [ "$RC" -eq 0 ]; then
	PROVEN=1
fi

# the session markers (each gated independently)
SESSION_MARKER_rio=RIO-SCRIPT-DONE
SESSION_MARKER_acme=ACME-SCRIPT-DONE
SESSION_MARKER_sam=SAM-SCRIPT-DONE
for s in $SESSIONS; do
	case "$s" in
	rejoin)
		"$GREP" -q 'DRAWTEST-OK' "$BOOTLOG" || { echo "TRACE-GATE-FAIL: DRAWTEST-OK missing (the 15-09 re-join — root-cause, never skip)"; RC=1; }
		"$GREP" -q 'ARCTEST-OK' "$BOOTLOG" || { echo "TRACE-GATE-FAIL: ARCTEST-OK missing (the 15-09 re-join — root-cause, never skip)"; RC=1; }
		;;
	rio|acme|sam)
		m=$(eval "echo \$SESSION_MARKER_$s")
		"$GREP" -q "$m" "$BOOTLOG" || { echo "TRACE-GATE-FAIL: $m missing ($s's script did not complete — D-07)"; RC=1; }
		"$GREP" -q "TRACE-EGRESS-DONE-$s" "$BOOTLOG" || { echo "TRACE-GATE-FAIL: TRACE-EGRESS-DONE-$s missing ($s's fragments never egressed)"; RC=1; }
		;;
	*)
		err "unknown session '$s' in $SIDECAR"
		;;
	esac
done
if "$GREP" -qiE 'panic|sys: trap' "$BOOTLOG"; then
	echo "TRACE-GATE-FAIL: panic/trap lines in the capture"
	RC=1
fi

# --- the evidence layers (D-06) ---------------------------------------
# raw: the per-pid framed egress section, extracted verbatim; table:
# the distiller's output over that raw.  Only for proven venues, only
# for sessions whose egress actually landed (an incomplete session's
# evidence is the capture itself, not a hollow table).
COMMIT=$(git -C "$HARVEY" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ "$PROVEN" -eq 1 ]; then
	for s in $SESSIONS; do
		case "$s" in
		rio|acme|sam)
			b="$BOOTLOG"
			if "$GREP" -q "__GSD_EGRESS_BEGIN_$s" "$BOOTLOG" && \
			   "$GREP" -q "__GSD_EGRESS_END_$s" "$BOOTLOG"; then
				sed -n "/__GSD_EGRESS_BEGIN_$s/,/__GSD_EGRESS_END_$s/p" "$b" > "$EVIDENCE/15-06-$s-raw.txt"
				if [ -s "$EVIDENCE/15-06-$s-raw.txt" ]; then
					sh "$HARVEY/build/x86_64/trace-distill.sh" "$s" \
						"$EVIDENCE/15-06-$s-raw.txt" \
						"$EVIDENCE/15-06-$s-table.txt" \
						"run: commit=$COMMIT date=$DATE accel=$ACCEL" \
						|| { echo "TRACE-GATE-FAIL: $s distillation produced nothing"; RC=1; }
				else
					echo "TRACE-GATE-FAIL: $s raw extraction is empty"
					RC=1
				fi
			else
				echo "TRACE-GATE-FAIL: $s egress markers absent — no raw extracted"
				RC=1
			fi
			;;
		esac
	done
	# the capture itself is evidence (bring-up + sessions + rejoin on
	# one wire — the provenness rule's proof)
	cp "$BOOTLOG" "$EVIDENCE/$EVNAME.log"
	ls -l "$EVIDENCE/15-06-"* "$EVIDENCE/$EVNAME.log" 2>/dev/null || true
fi

if [ "$RC" -eq 0 ]; then
	echo "TRACE-GATE-PASS: sessions ($SESSIONS) complete, egress green, four bring-up markers present, zero panic/trap, accel=$ACCEL"
else
	echo "TRACE-GATE-FAIL: see the marker lines above (capture: $BOOTLOG)"
fi

# the capture is the gate's evidence — cat it to THIS script's stdout so
# the run log the plan's verify greps (/tmp/*.log) carries the markers
# themselves, not only the classification lines
echo "== serial capture ($BOOTLOG):"
cat "$BOOTLOG"
exit "$RC"
