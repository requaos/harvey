#!/bin/sh
# trace-distill.sh — the host-side raw->table distiller (15-06, D-06:
# raw per-binary trace logs + distilled syscall-set tables, BOTH
# committed; the table is what r9 kernel-growth plans cite, in the
# 05-03 measured-set format: syscall -> count -> args-shape notes).
#
# The committed derivation path (T-15-14's mitigation): re-running this
# script over a committed raw log MUST reproduce the table byte-for-
# byte — the table is derived evidence, reconstructible from the raw.
# (Proof: evidence/15-06-distill-repro.log in the phase evidence dir.)
#
# usage: trace-distill.sh <name> <raw-log> <out-table> [note ...]
#   <name>    the traced program (rio / acme / sam)
#   <raw-log> the per-pid framed fragment log (the __GSD_EGRESS_* /
#             __GSD_PID_* framed section extracted from the capture)
#   <out-table> the distilled table's path (stdout carries a summary)
#   [note ...] extra provenance lines copied into the table header
#
# Input grammar (tracesup's contract + the session driver's framing;
# the serial console doubles the CR of every newline — stripped first):
#   __GSD_PID_<n>__     start of pid n's fragment file
#   <pid> <text> <syscall> <args...>     an ENTRY fragment (syscallfmt)
#   ' = <ret> <errstr> <start> <stop>'   a RETURN fragment (sysretfmt)
# Output grammar (machine-parseable, tab-separated rows; every block is
# sorted deterministically — counts descending, names ascending — so
# re-runs over the same raw are byte-stable):
#   pid=<n> name=<text> fragments=<n>      one block per (pid, text):
#   <syscall>\t<count>\t<args-shape>         the per-pid rows (a pid whose
#                                            image changed mid-life — rc
#                                            pre-exec, rio post-exec —
#                                            gets one block per text)
#   BINARY name=<text> pids=<n> entries=<n>
#   B\t<syscall>\t<count>                  the per-BINARY aggregate (the
#   PATHS name=<text>                       measured set a kernel-growth
#   P\t<syscall>\t<count>\t<path>           plan cites; sam's covers BOTH
#                                            pids — sam + samterm, the
#                                            born-traced descendants)
#   TOTAL pids=<n> entries=<n> binaries=<n>
#   T\t<syscall>\t<count>                  the program-level union
# PATH rows collect the distinct quoted path arguments of the
# path-bearing syscalls (pure-digit path components normalized to N —
# /proc/37/args is /proc/N/args for every run; Bind/Mount/Unmount keep
# the target argument too).
#
# Exit: 0 iff at least one entry fragment parsed (an empty distillation
# is a failed distillation, never a quiet empty table).

set -eu

NAME="${1:?usage: trace-distill.sh <name> <raw-log> <out-table> [note...]}"
RAW="${2:?missing raw log}"
OUT="${3:?missing out table}"
shift 3 || true

[ -f "$RAW" ] || { echo "trace-distill: no raw log at $RAW" >&2; exit 1; }

GREP=$(command -v /usr/bin/grep || command -v grep) || { echo "trace-distill: no grep" >&2; exit 1; }

# the path-bearing syscalls whose quoted string arguments are collected
PATHSYS='^(Access|Bind|Chdir|Create|Exec|Fstat|Mount|Open|Remove|Stat|Unmount|Wstat)$'

# pass 1 (awk): parse the raw log, emit sort-keyed records; sort
# (LC_ALL=C, byte-deterministic); pass 2 (awk): strip keys, print the
# table body.  bwk-awk compatible (the devshell PATH resolves Harvey's
# vendored one-true-awk first).
T1=$(mktemp "${TMPDIR:-/tmp}/trace-distill.XXXXXX")
T2=$(mktemp "${TMPDIR:-/tmp}/trace-distill.XXXXXX")
trap 'rm -f "$T1" "$T2"' EXIT

awk -v pathsys="$PATHSYS" '
function shape_of(    i, s) {
	s = ""
	for(i = 4; i <= NF; i++)
		s = s (i > 4 ? " " : "") $i
	return substr(s, 1, 72)
}
# quoted strings on the line -> path arguments (the first, plus the
# target for the bind/mount class where it matters as much)
function path_of(sys,    s, n, p, out, want) {
	s = $0
	out = ""
	want = (sys == "Bind" || sys == "Mount" || sys == "Unmount") ? 2 : 1
	n = 0
	while (match(s, /"[^"]*"/)) {
		n++
		if (n <= want) {
			p = substr(s, RSTART+1, RLENGTH-2)
			gsub(/\/[0-9][0-9]*/, "/N", p)	# /proc/37/ -> /proc/N/
			sub(/\.[0-9]+$/, ".N", p)	# /srv/rio.sys.30 -> .N
			out = out (n > 1 ? " " : "") p
		}
		s = substr(s, RSTART+RLENGTH)
	}
	return out
}
{
	sub(/\r$/, "")
}
/^[0-9]+ [^ ]+ [A-Za-z_][A-Za-z_0-9]*[ ]/ {
	pid = $1; txt = $2; sys = $3
	key = pid SUBSEP txt
	curkey = key
	if (!(key in seen)) { order[++nkeys] = key; seen[key] = 1 }
	if (!((txt, pid) in bseen)) { bseen[txt, pid] = 1; bpids[txt]++ }
	frag[key]++
	row[key, sys]++
	if (!((key, sys) in shseen)) {
		shseen[key, sys] = 1
		shape[key, sys] = shape_of()
	}
	brow[txt, sys]++
	bent[txt]++
	if (sys ~ pathsys) {
		p = path_of(sys)
		if (p != "") {
			pkey = txt "\t" sys "\t" p
			if (!(pkey in pseen)) {
				pseen[pkey] = 1
				pord[++npord] = pkey
			}
			pcnt[pkey]++
		}
	}
	tot[sys]++
	tote++
	next
}
(/^ = / || /^ 0x/) && curkey != "" {
	frag[curkey]++
	next
}
END {
	if (tote == 0) {
		print "trace-distill: no entry fragments parsed" > "/dev/stderr"
		exit 1
	}
	nbin = 0
	for (b in bent)
		nbin++
	for (i = 1; i <= nkeys; i++) {
		split(order[i], a, SUBSEP)
		printf "K2\t%08d\t%s\t%s\t00000000\tHEADER\t%d\t\n", a[1]+0, a[1], a[2], frag[order[i]]
	}
	for (k in row) {
		split(k, a, SUBSEP)
		printf "K2\t%08d\t%s\t%s\t%08d\t%s\t%d\t%s\n", a[1]+0, a[1], a[2], 99999999-row[k], a[3], row[k], shape[k]
	}
	for (b in bent) {
		printf "K3\t%s\t%d\t%d\n", b, bpids[b], bent[b]
	}
	for (k in brow) {
		split(k, a, SUBSEP)
		printf "K4\t%s\t%08d\t%s\t%d\n", a[1], 99999999-brow[k], a[2], brow[k]
	}
	for (i = 1; i <= npord; i++) {
		split(pord[i], a, "\t")
		printf "K5\t%s\t%s\t%08d\t%s\t%s\t%d\t%s\n", a[1], a[2], 99999999-pcnt[pord[i]], a[1], a[2], pcnt[pord[i]], a[3]
	}
	for (s in tot)
		printf "K6\t%08d\t%s\t%d\n", 99999999-tot[s], s, tot[s]
	printf "K0\t%d\t%d\t%d\n", nkeys, tote, nbin
}' "$RAW" | LC_ALL=C sort > "$T1"

awk -F'\t' '
$1 == "K0" { npids = $2; nent = $3; nbin = $4; next }
$1 == "K2" { if ($6 == "HEADER") { print "pid=" $3 " name=" $4 " fragments=" $7; curpid = $3; curtxt = $4; next }
	     if ($3 != curpid || $4 != curtxt) { print "pid=" $3 " name=" $4 " fragments=?"; curpid = $3; curtxt = $4 }
	     print $6 "\t" $7 "\t" $8; next }
$1 == "K3" { print "BINARY name=" $2 " pids=" $3 " entries=" $4; next }
$1 == "K4" { print "B\t" $4 "\t" $5; next }
$1 == "K5" { if ($5 != curbin) { print "PATHS name=" $5; curbin = $5 }
	     print "P\t" $6 "\t" $7 "\t" $8; next }
$1 == "K6" { if (havetot == 0) { print "TOTAL pids=" npids " entries=" nent " binaries=" nbin; havetot = 1 }
	     print "T\t" $3 "\t" $4; next }
' "$T1" > "$T2"

NBIN=$($GREP -c '^BINARY' "$T2" || true)
NTOT=$($GREP -c '^T	' "$T2" || true)
[ "$NTOT" -gt 0 ] || { echo "trace-distill: empty TOTAL block" >&2; exit 1; }

{
	echo "# 15-06 $NAME distilled syscall table — the 05-03 measured-set format"
	echo "# derived from $RAW by build/x86_64/trace-distill.sh (the committed"
	echo "# derivation path — re-running it over the raw reproduces this file)"
	echo "# venue: k10draw draw donor (amd64 9k kernel), scripted-interaction"
	echo "# replay via /dev/mousein + /dev/kbin, tracesup born-traced arming"
	for n in "$@"; do
		echo "# $n"
	done
	echo "# row grammar: <syscall>\\t<count>\\t<args-shape (first sample)>"
	echo "#              B<TAB>syscall<TAB>count = per-binary aggregate"
	echo "#              P<TAB>syscall<TAB>count<TAB>path = distinct path args (digits->N)"
	echo "#              T<TAB>syscall<TAB>count = program-level union"
	cat "$T2"
} > "$OUT"

echo "trace-distill: $NAME -> $OUT ($($GREP -c '^pid=' "$OUT") pid blocks, $NBIN binaries, $NTOT syscalls in the measured set)"
