#!/bin/sh
# build/aarch64/repeat-gate.sh — run one arm64 composed gate K times on
# a chosen accelerator, keep every capture, and print a tally (D-02).
#
# Why: the HVF fork-child defect (`rc: pushword but no argv!`, WINDOWS
# #49) fires per fork, not per gate, so one green run proves nothing.
# D-02 needs a measured failure rate and a stated repeat count N; this
# harness is the instrument for both the pre-fix rate series and the
# post-fix N-green series.
#
# usage: build/aarch64/repeat-gate.sh <app> <count>
#   <app>    boot-r9-smoke | boot-r9-net-smoke | boot-r9-tier1 | boot-r9-cpu
#   <count>  number of runs (positive integer)
#
# Env contract:
#   R9_ACCEL         passed through to the app (default auto)
#   R9_SERIES_DIR    parent dir of the series (default
#                    $HARVEY/.build/hvf-series; .build/ is gitignored)
#   R9_OVERRIDE      a flake ref; adds `--override-input r9 <ref>` to
#                    every `nix run` (e.g. git+file:///…/r9)
#   R9_STOP_ON_FAIL  =1 stops at the first failing run
#   R9_SKIP_BUILD    =1 skips the userland build on every run; when
#                    unset, run 1 builds and runs 2..K set it to 1
#
# Each run is one `nix run .#<app> --no-write-lock-file` under bash
# (zsh does not word-split the flag list; the app scripts are bash).
# The app removes its capture before launch, so the harness points the
# app's capture variable straight at the series file.  Per app:
#   boot-r9-smoke, boot-r9-net-smoke  R9_SMOKE_LOG
#   boot-r9-tier1                     R9_TIER1_LOG
#   boot-r9-cpu                       R9_CPU_LOG (the app's default
#                                     capture is build/aarch64/cpu-r9.log;
#                                     20-17 added the cpu gate)
# The series files:
#   $R9_SERIES_DIR/<app>-<accel>-<stamp>/run-<i>.log   serial capture
#   $R9_SERIES_DIR/<app>-<accel>-<stamp>/run-<i>.out   stdout+stderr
#   $R9_SERIES_DIR/<app>-<accel>-<stamp>/series.tsv    one row per run
#
# Counting:
#   pass      runs whose `nix run` exited 0 (markers are the proof)
#   pushword  runs whose capture holds `pushword but no argv`
#   forks     capture lines matching `process [0-9]+ exited` (the r9
#             kernel prints one per reaped child), else the highest
#             pid seen in `process N` / `pid N` text; the method is
#             printed.  A failing run stops at the fire, so it adds
#             only the forks before it.
#
# Output: per-run RUN lines, a METHOD line, then exactly one final line
#   SERIES <app> accel=<a> runs=<k> pass=<p> fail=<f> pushword=<w> forks=<n>
# Exit 0 only when fail is 0; 2 on a usage error.

set -u

usage() {
	echo "usage: $0 boot-r9-smoke|boot-r9-net-smoke|boot-r9-tier1|boot-r9-cpu <count>" >&2
	exit 2
}

[ $# -eq 2 ] || usage
APP="$1"
COUNT="$2"
case "$APP" in
boot-r9-smoke|boot-r9-net-smoke)
	LOGVAR=R9_SMOKE_LOG ;;
boot-r9-tier1)
	LOGVAR=R9_TIER1_LOG ;;
boot-r9-cpu)
	# nix/cpu-r9.sh writes build/aarch64/cpu-r9.log unless R9_CPU_LOG
	# names another path
	LOGVAR=R9_CPU_LOG ;;
*)
	usage ;;
esac
case "$COUNT" in
''|*[!0-9]*)
	usage ;;
esac
[ "$COUNT" -ge 1 ] || usage

# the Harvey root, from this script's own path (build/aarch64/..)
HERE=$(cd "$(dirname "$0")" && pwd) || exit 1
HARVEY=$(cd "$HERE/../.." && pwd) || exit 1
[ -d "$HARVEY/sys/src" ] || { echo "error: $HARVEY is not the harvey checkout" >&2; exit 1; }

# host grep: hostbin's Plan 9 grep lacks -E/-c semantics we rely on
GREP=$(command -v /usr/bin/grep || command -v grep) || { echo "error: no host grep" >&2; exit 1; }

ACCEL="${R9_ACCEL:-auto}"
STAMP=$(date +%Y%m%dT%H%M%S)
SDIR="${R9_SERIES_DIR:-$HARVEY/.build/hvf-series}/$APP-$ACCEL-$STAMP"
mkdir -p "$SDIR" || exit 1
TSV="$SDIR/series.tsv"
printf 'run\trc\tpushword\tforks\tmethod\tsecs\n' > "$TSV"

SKIP0="${R9_SKIP_BUILD:-0}"

# forks in one capture: "<n> <method>"
countforks() {
	n=$("$GREP" -acE 'process [0-9]+ exited' "$1" 2>/dev/null)
	[ -n "$n" ] || n=0
	if [ "$n" -gt 0 ]; then
		echo "$n exited-lines"
		return
	fi
	n=$("$GREP" -aoE '(process|pid)[ =][0-9]+' "$1" 2>/dev/null \
		| "$GREP" -oE '[0-9]+' | sort -n | tail -1)
	[ -n "$n" ] || n=0
	echo "$n max-pid"
}

echo "== series $APP accel=$ACCEL runs=$COUNT dir=$SDIR"
[ -n "${R9_OVERRIDE:-}" ] && echo "== override: r9 <- $R9_OVERRIDE"

runs=0
pass=0
fail=0
pw=0
forks=0
methods=""
i=1
while [ "$i" -le "$COUNT" ]; do
	LOG="$SDIR/run-$i.log"
	OUT="$SDIR/run-$i.out"
	if [ "$SKIP0" = "1" ] || [ "$i" -gt 1 ]; then
		skip=1
	else
		skip=0
	fi
	t0=$(date +%s)
	if [ -n "${R9_OVERRIDE:-}" ]; then
		(cd "$HARVEY" && env R9_ACCEL="$ACCEL" R9_SKIP_BUILD="$skip" "$LOGVAR=$LOG" \
			bash -c 'exec nix run "$@"' bash ".#$APP" --no-write-lock-file \
			--override-input r9 "$R9_OVERRIDE") > "$OUT" 2>&1
	else
		(cd "$HARVEY" && env R9_ACCEL="$ACCEL" R9_SKIP_BUILD="$skip" "$LOGVAR=$LOG" \
			bash -c 'exec nix run "$@"' bash ".#$APP" --no-write-lock-file) > "$OUT" 2>&1
	fi
	rc=$?
	t1=$(date +%s)
	secs=$((t1 - t0))
	# a run that died before the driver started leaves no capture;
	# keep the file so the run-<i>.log count always equals runs
	[ -f "$LOG" ] || : > "$LOG"
	if "$GREP" -aq 'pushword but no argv' "$LOG"; then
		w=1
	else
		w=0
	fi
	set -- $(countforks "$LOG")
	f="$1"
	m="$2"
	case " $methods " in
	*" $m "*) ;;
	*) methods="$methods $m" ;;
	esac
	runs=$((runs + 1))
	pw=$((pw + w))
	forks=$((forks + f))
	if [ "$rc" -eq 0 ]; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
	fi
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$i" "$rc" "$w" "$f" "$m" "$secs" >> "$TSV"
	echo "RUN $i rc=$rc pushword=$w forks=$f method=$m secs=$secs"
	if [ "$rc" -ne 0 ] && [ "${R9_STOP_ON_FAIL:-0}" = "1" ]; then
		echo "== R9_STOP_ON_FAIL=1: stopping after run $i"
		break
	fi
	i=$((i + 1))
done

echo "METHOD forks counted by:$methods"
echo "SERIES $APP accel=$ACCEL runs=$runs pass=$pass fail=$fail pushword=$pw forks=$forks"
[ "$fail" -eq 0 ]
