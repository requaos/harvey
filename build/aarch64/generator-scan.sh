#!/bin/sh
# build/aarch64/generator-scan.sh — USPACE-03's mechanical red (06-04).
#
# Asserts the invariant: no build-then-run generator artifact is a
# Plan 9 aarch64 binary (R_MAGIC 00008c47 — 7c output can never RUN on
# the host at build time).  Consumes the committed audit
# (build/aarch64/generator-audit.txt):
#
#   1. runs=always rows: locate each artifact in the swept tree and
#      assert first-4-bytes via od — RED on 00008c47; pass 7f454c46
#      (host ELF) and 23212f (#! scripts); other magics print NOTE
#      (text scripts like 7l's ed-driven mkcname).  A MISSING
#      runs=always artifact is an audit-drift error (the tree moved
#      under the audit — re-confirm the row against the live mkfile).
#   2. Negative sweep: no file named 7.{rgbycc,rgbrgbv,maketab,genrtab,
#      pcode} exists anywhere in the tree — the name shape a $CC-built
#      (target) generator would take under the current idioms.  The
#      whitelist is EXACTLY 7.genarch (G6's guarded artifact), derived
#      from the audit file itself (T-06-08): if the audit's G6 row
#      drifts, the scan reds.
#   3. Build-log scan: `cannot execute|exec format error|Exec format
#      error` in the sweep/build log is RED (the historical symptom
#      class, PITFALLS Pitfall 2).
#
# Tree probing: the scan checks the tree the coverage sweep just BUILT.
# On linux that is the local checkout (the namespace build bind-mounts
# it).  On darwin the sweep builds in the lima guest's rsync copy
# (~/harvey-build), so the probes run over ssh — the script itself is
# host-side and fast either way.  In CI (06-08's wave0-host, linux) the
# local tree is the build tree.
#
# Prints GENERATOR-SCAN-OK on green.  Exit non-zero on any RED line or
# drift error.
#
# usage: sh build/aarch64/generator-scan.sh   (from the repo root,
# inside the nix devshell on darwin; GENERATOR_SCAN_LOG overrides the
# build-log path, GENERATOR_AUDIT the audit path, HARVEY_GUEST_DIR the
# lima guest checkout)

set -eu

HARVEY="${HARVEY:-$PWD}"
AUDIT="${GENERATOR_AUDIT:-$HARVEY/build/aarch64/generator-audit.txt}"
BUILDLOG="${GENERATOR_SCAN_LOG:-$HARVEY/.build/coverage-sweep.log}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"

err() { echo "error: $*" >&2; exit 1; }
note() { echo "NOTE: $*"; }

GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -f "$AUDIT" ] || err "audit file missing: $AUDIT"

# --- tree probe plumbing ---------------------------------------------------
# TREE_PROBE mode: local (linux) or guest (darwin lima).
# NOTE: every ssh probe is invoked with </dev/null — ssh consumes the
# caller's stdin otherwise, which silently drained the audit-rows while
# loop after its first row (measured 2026-11-05: only G1 was checked).
GUEST_MODE=
if [ "$(uname -s)" != "Linux" ]; then
	GUEST_MODE=1
	command -v limactl >/dev/null 2>&1 || err "limactl not found — run inside the nix devshell"
	if ! limactl list -q 2>/dev/null | "$GREP" -qx "$VM"; then
		err "lima VM '$VM' does not exist"
	fi
	status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
	[ "$status" = "Running" ] || err "lima VM '$VM' not running — start it (limactl start $VM); the scan probes the tree the sweep built"
	SSH_CFG="$HOME/.lima/$VM/ssh.config"
	GUEST="lima-$VM"
fi

# tree_test <repo-relative path>: exists?
tree_test() {
	if [ -n "$GUEST_MODE" ]; then
		ssh -F "$SSH_CFG" "$GUEST" "test -e '$GUEST_DIR/$1'" < /dev/null
	else
		[ -e "$HARVEY/$1" ]
	fi
}

# tree_magic <repo-relative path>: first 4 bytes, hex, no spaces
tree_magic() {
	if [ -n "$GUEST_MODE" ]; then
		ssh -F "$SSH_CFG" "$GUEST" "od -An -tx1 -N4 '$GUEST_DIR/$1' | tr -d ' \\n'" < /dev/null
	else
		od -An -tx1 -N4 "$HARVEY/$1" | tr -d ' \n'
	fi
}

# tree_find_7gen: repo-relative paths of the negative-sweep name set +
# the whitelisted 7.genarch
tree_find_7gen() {
	if [ -n "$GUEST_MODE" ]; then
		ssh -F "$SSH_CFG" "$GUEST" "cd '$GUEST_DIR' && find sys/src -type f \( -name '7.rgbycc' -o -name '7.rgbrgbv' -o -name '7.maketab' -o -name '7.genrtab' -o -name '7.pcode' -o -name '7.genarch' \) 2>/dev/null" < /dev/null
	else
		(cd "$HARVEY" && find sys/src -type f \( -name '7.rgbycc' -o -name '7.rgbrgbv' -o -name '7.maketab' -o -name '7.genrtab' -o -name '7.pcode' -o -name '7.genarch' \))
	fi
}

# --- 0. audit self-consistency (T-06-08: the whitelist derives from the audit)
"$GREP" -q '^G6 site=.*generator=genarch artifact=7\.genarch .*proof=guard' "$AUDIT" \
	|| err "audit drift: G6 row no longer names artifact=7.genarch with a guard proof — the scan's whitelist has lost its basis"

BAD=0

# --- 1. runs=always artifact magic asserts ----------------------------------
# ERE [0-9]+, not [0-9]: the audit's maintenance rule numbers the next row
# G10 — a single-digit selector would silently skip double-digit rows (WR-03)
"$GREP" -E '^G[0-9]+ site=' "$AUDIT" > /tmp/gsd-genscan-rows.$$ || err "audit carries no G rows"
trap 'rm -f /tmp/gsd-genscan-rows.$$' EXIT
while read -r row; do
	# positional field extraction (the audit grammar is fixed field
	# order: G<n> site= generator= artifact= built-by= runs= proof=) via
	# awk — the devshell PATH puts Harvey's hostbin first and Plan 9's
	# sed silently fails \(\)\1 extractions (D-02 shadowing class).
	gn=$(printf '%s\n' "$row" | awk '{print $1}')
	site=$(printf '%s\n' "$row" | awk '{print substr($2, 6)}')
	artifact=$(printf '%s\n' "$row" | awk '{print substr($4, 10)}')
	runs=$(printf '%s\n' "$row" | awk '{print substr($6, 6)}')
	case "$runs" in
	always|every-*)
		;;
	*)
		echo "skip ($gn runs=$runs): $site"
		continue
		;;
	esac
	sitedir=$(dirname "${site%:*}")
	path="$sitedir/$artifact"
	if ! tree_test "$path"; then
		echo "RED: missing artifact for $gn ($row)" >&2
		echo "     audit drift — re-confirm the row against the live mkfile; if the sweep has not run, run sh build/aarch64/coverage-sweep.sh first" >&2
		BAD=1
		continue
	fi
	magic=$(tree_magic "$path")
	case "$magic" in
	00008c47)
		echo "RED: .7-magic generator artifact: $path ($gn — 7c output must never run on the host)"
		BAD=1
		;;
	7f454c46|23212f*)
		echo "ok: $gn $path magic=$magic"
		;;
	*)
		note "$gn $path magic=$magic (script/text or unclassified; not .7)"
		;;
	esac
done < /tmp/gsd-genscan-rows.$$

# --- 2. negative sweep: no 7.<generator> files (whitelist: exactly 7.genarch)
FOUND=$(tree_find_7gen || true)
GENARCH_SEEN=
if [ -n "$FOUND" ]; then
	printf '%s\n' "$FOUND" | while read -r f; do
		[ -n "$f" ] || continue
		case "${f##*/}" in
		7.genarch)
			echo "WHITELISTED: $f — G6's guarded artifact (proof: sys/src/cmd/gs/mkfile:149,164 — built and run only when objtype==cputype)"
			;;
		*)
			echo "RED: target-built generator in the tree: $f" 
			;;
		esac
	done > /tmp/gsd-genscan-neg.$$
	# the while ran in a subshell — re-read the results for the verdict
	cat /tmp/gsd-genscan-neg.$$
	if "$GREP" -q '^RED:' /tmp/gsd-genscan-neg.$$; then BAD=1; fi
	if "$GREP" -q '^WHITELISTED:' /tmp/gsd-genscan-neg.$$; then GENARCH_SEEN=1; fi
	rm -f /tmp/gsd-genscan-neg.$$
fi
if [ -z "$GENARCH_SEEN" ]; then
	echo "whitelist armed: 7.genarch (G6's guarded row; not present in the tree — expected under the current gs guard)"
fi

# --- 3. build-log exec-format scan ------------------------------------------
if [ -f "$BUILDLOG" ]; then
	if "$GREP" -E 'cannot execute|exec format error|Exec format error' "$BUILDLOG" > /tmp/gsd-genscan-log.$$ 2>/dev/null; then
		echo "RED: exec-format failure lines in $BUILDLOG:"
		head -10 /tmp/gsd-genscan-log.$$
		BAD=1
	fi
	rm -f /tmp/gsd-genscan-log.$$
else
	note "no build log at $BUILDLOG — exec-format scan skipped (set GENERATOR_SCAN_LOG)"
fi

if [ "$BAD" != 0 ]; then
	echo "GENERATOR-SCAN-FAIL" >&2
	exit 1
fi
echo "GENERATOR-SCAN-OK"
