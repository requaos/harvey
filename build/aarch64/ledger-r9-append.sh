#!/bin/sh
# ledger-r9-append.sh — 06-07 one-off: append the r9-venue tier1.ledger
# lines (D-14; last-line-per-dir-wins — the dir's history then carries
# BOTH the donor and the r9 evidence).  exec vocabulary per the plan:
# T1-OK:r9 per r9-runnable entry, SKIP:<measured-reason> for the
# donor-guarded set (write-flow/build-chain → r9-no-writable-fs;
# ipconfig → r9-no-devrandom; factotum → r9-no-auth-era — both measured
# at the r9 gate, recorded in 06-EVIDENCE.md).
#
# usage: sh build/aarch64/ledger-r9-append.sh <gate-commit-40hex>  (from the repo root)
set -eu

HARVEY="${HARVEY:-$PWD}"
LEDGER="$HARVEY/build/aarch64/markers/tier1.ledger"
TIERFILE="$HARVEY/build/aarch64/tiers/tier1-cmds.txt"
SWEEP="$HARVEY/build/aarch64/tier1-sweep.rc"
COMMIT="${1:?usage: ledger-r9-append.sh <gate-commit-40hex>}"
EVIDENCE=".planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-07-tier1-r9.log"
DATE=2026-11-05

# Resolve a host grep once (D-02): the greps below need -oE, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || { echo "error: no host grep found" >&2; exit 1; }

# sha256sum is linux-only; darwin's spelling is shasum -a 256
# (run-gate.sh:89-95's idiom)
sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

# the SKIP set, extracted verbatim from the sweep's r9-venue SKIP lines
SKIP=$("$GREP" -oE '(^|[[:space:]])echo T1-SKIP [A-Za-z0-9.-]+' "$SWEEP" | awk '{print $NF}' | sort -u | tr '\n' ' ')

# entry → (dir, bin, artifact) mapping mirrors the existing ledger lines
emit() {
	dir="$1"; bin="$2"; art="$3"
	if [ "$bin" = "cc.a7" ]; then
		# cc.a7 is a build TRANSIENT (linked into 7c, then cleaned) —
		# reuse the ledger's latest cmd/cc sha256 (7c's sha256 is
		# unchanged since 06-06's gate, so the archive is provably
		# unchanged; the r9 line is a SKIP — the archive wasn't run).
		sha=$("$GREP" 'dir=cmd/cc ' "$LEDGER" | tail -1 | "$GREP" -oE 'sha256=[a-f0-9]+' | cut -d= -f2)
		[ -n "$sha" ] || { echo "error: no prior cmd/cc sha256 in the ledger" >&2; exit 1; }
	else
		[ -f "$HARVEY/$art" ] || { echo "error: artifact $art missing" >&2; exit 1; }
		sha=$(sha256 "$HARVEY/$art")
	fi
	case " $SKIP " in
	*" $bin "*)
		case "$bin" in
		ipconfig) exec=SKIP:r9-no-devrandom ;;
		factotum) exec=SKIP:r9-no-auth-era ;;
		*) exec=SKIP:r9-no-writable-fs ;;
		esac ;;
	*) exec=T1-OK:r9 ;;
	esac
	# the build chain's venue: the self-host canary is donor-guarded
	# (r9 has no writable /tmp this era) — 7c/7l/cc's markers ride the
	# canary's SKIP lines, not their own names; 7a has its own.
	case "$bin" in
	7c|7l|cc.a7) exec=SKIP:r9-no-writable-fs ;;
	esac
	echo "tier=1 dir=$dir bin=$bin sha256=$sha exec=$exec evidence=$EVIDENCE commit=$COMMIT date=$DATE" >> "$LEDGER"
}

# plain pipe, not < <(...): the script runs under /bin/sh (dash on the
# CI host), which has no process substitution (WR-07).  The loop only
# reads the tier file and appends to the ledger — no state crosses the
# subshell boundary; an emit failure exits the subshell non-zero and
# set -e stops the parent the same as before.
awk 'NF && $1 !~ /^#/ { print $1 }' "$TIERFILE" | while IFS= read -r line; do
	case "$line" in ''|'#'*) continue ;; esac
	e="$line"
	case "$e" in
	# driver-only entries (never swept by name; their BOOT:donor lines
	# stand — their r9 evidence is the composed boot, recorded in
	# 06-EVIDENCE.md, no new ledger vocabulary this plan)
	9k/boot|stage/init|cmd/paqfs:paqfs) continue ;;
	esac
	bin="${e##*/}"
	case "$e" in *:*) bin="${e##*:}" ;; esac
	# artifact path per entry form (the existing ledger's conventions)
	case "$e" in
	stage/stacksmoke) art="build/aarch64/out/stacksmoke" ;;
	cmd/ip/*) art="aarch64/bin/ip/$bin" ;;
	cmd/auth/*) art="aarch64/bin/auth/$bin" ;;
	cmd/cc) bin="cc.a7"; art="aarch64/lib/cc.a7" ;;
	*) art="aarch64/bin/$bin" ;;
	esac
	emit "$e" "$bin" "$art"
done

echo "== appended $(awk 'NF && $1 !~ /^#/' "$TIERFILE" | wc -l | tr -d ' ') r9-venue lines to $LEDGER"