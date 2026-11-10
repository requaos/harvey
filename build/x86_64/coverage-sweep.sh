#!/bin/sh
# build/x86_64/coverage-sweep.sh — the amd64 full-tree DIRS-coverage proof
# (15-07, USPACE-09, D-09): build/aarch64/coverage-sweep.sh re-keyed to
# objtype=amd64 — re-key, don't reinvent (the subset-build precedent).
#
# Regenerates build/x86_64/dir-coverage.txt: every sys/src/cmd and
# sys/src/games dir (every dir with an mkfile under the two roots), every
# sys/src/lib* library, the ape/lib substrate (the pcc/APE class's link
# prerequisite), every single-file command at the cmd root, and every
# mkmany-family container member (aux/ip/auth/games-style TARG lists
# whose own `all:` target skips the singles) — each VISITED, built under
# a per-dir budget, and verdicted build=ok|fail|hang.  COVERAGE_SWEEP=1
# is set for every mk: the six mk filter sites' allowlist arms disengage
# (the 15-01-verified escape), so the sweep certifies the WHOLE tree,
# never the allowlist to itself (Pitfall P6-1).  The aarch64 driver ran
# `mk checkall` and a second-chance pass; this amd64 re-key drives every
# universe dir DIRECTLY (per-dir clean + per-dir `mk all` under
# `timeout`), which subsumes both passes — plan9port mk's strict
# abort-at-first-failing-recipe semantics can never hide a sibling dir
# behind an earlier failure, and every dir's outcome is its own row.
#
# The watchdog re-key: the aarch64 /proc-walking watchdog does not carry
# to the userns chroot venue (no /proc inside the scaffold; host-side
# /proc cwd paths resolve through the tmpfs, not the chroot's /sys).
# The equivalent, simpler and venue-proof, is a per-invocation
# `timeout -k` budget: a wedged dir is killed at its budget, its EXIT
# marker carries the timeout status, and the parse classifies the row
# build=hang — a hang is a classified timeout digest, never a silent
# pass (T-15-18), and the run still completes with every other dir
# verdicted (the report never dies mid-inventory).
#
# Visitation is observed by a PATH-prepended mk shim (the aarch64
# protocol, unchanged) logging COVERAGE-VISIT / COVERAGE-EXIT <key>
# <status> for every nested sub-mk — the containers' recursion echo
# shapes are not uniform, so echo text is never parsed.  Driver-level
# passes (libs, dirs, singles, members) write their own marker pairs
# around each direct invocation; the shim covers whatever the
# invocation recurses into.  VISIT-with-no-EXIT still classifies hang
# (a killed sweep leaves a PARTIAL, classifiable dir-coverage.txt — the
# flagged-assumption contract: a partial file never passes as proof
# because the green gate requires the full universe with every row ok).
#
# The lib universe is driven per-lib with `mk clean` before `mk install`
# (fresh objects — the 06-03 anti-staleness decision, in-driver: a
# stale archive or a previously-built no-op can never earn a row) and
# every dir likewise cleans before `mk all`.
#
# The exclusion record lives in tier4-tail.txt as named `# exclude:
# <path> <reason>` comment lines (D-10: every exclusion re-derived
# against the actual tree, never carried from aarch64).  This driver
# reads that file when present: an excluded dir is exempt from the
# universe assertion, and a stale exclusion (an exclude= line for a dir
# the sweep visited anyway) fails the run.  With no tier4 file (the
# first run) the exclusion set is empty — everything must be visited.
#
# Venue: linux native only (the x64 discipline — no lima leg).  The
# userns chroot scaffold is the passwordless venue (subset-build.sh's
# proven shape) with three venue-shape additions measured necessary by
# the first runs: the hostbin toolchain symlinked into the chroot's
# /bin (pcc execs /bin/cpp, /bin/6c, /bin/6l by absolute path; awk for
# the #!/bin/awk -f generator scripts), and PATH ending in "." (Plan
# 9's default path; the tree's mkfiles invoke cwd-local generator
# scripts by bare name, which plan9port rc resolves through $path,
# never the cwd — the nsrun.sh/build-9kdraw.sh convention, re-keyed).
# The driver holds the phase build-tree lock
# (flock .build/amd64-tree.lock) for the whole run — it is the phase's
# whole-tree /amd64 writer and must serialize against the same-wave
# payload bakes (the 15-01 declared coupling).
#
# Tail steps: the gs harvest (cp the in-tree 6.gs to /amd64/bin/gs,
# magic-checked — the Task-3 render smoke's payload reads it there) and
# the droppings sweep (untracked-unignored files under sys/src are
# build droppings by construction and are removed; modified/deleted
# TRACKED files are reported loudly — a generator rewriting a committed
# file is a finding, never silently accepted).
#
# Output grammar (build/x86_64/dir-coverage.txt): DATA ROWS ONLY — one
# line per visited key, `<key> visited=N build=ok|fail|hang` (keys are
# repo-relative dir paths for dirs/libs, cmd-single:<name> for cmd-root
# singles, member:<dir>/<name> for container members).  The green proof
# contract is `grep -vc 'build=ok' == 0` plus ok-row count >= the cmd
# dir count: no header, no excluded= lines, no tail counts — the
# annotations that matter (fossil/venti's runtime-unverifiable note)
# ride as trailing `#` comments ON their rows, and the exclusion record
# lives in the tier4 data.  A row may legitimately be visited more than
# once (container recursion + the dir's own pass; the libs' clean and
# install sub-mks): the worst EXIT status wins.
#
# usage: nix develop -c sh build/x86_64/coverage-sweep.sh  (repo root)
# Env overrides: DIR_COVERAGE_OUT, COVERAGE_SWEEP_LOG,
#   COVERAGE_LIB_BUDGET / COVERAGE_DIR_BUDGET / COVERAGE_SINGLE_BUDGET
#   (seconds; defaults 900 / 1800 / 420 — generous, the aarch64
#   watchdog-minute class re-keyed per invocation)

set -eu

# System tools FIRST (the 15-01 recorded pattern: the devshell puts
# Harvey's hostbin plan9 tools ahead on PATH, and plan9 ls/sed/awk/rm
# garble the host-side computations — measured on the first run: a
# 0-member extraction and unsorted comm inputs).  The toolchain itself
# is addressed $HARVEY_LINUX_BIN-absolute, so this pin changes nothing
# for the namespace build.  LC_ALL=C pins collation for sort/comm.
PATH="/run/current-system/sw/bin:$PATH"
export PATH LC_ALL=C

HARVEY="${HARVEY:-$PWD}"
LOG="${COVERAGE_SWEEP_LOG:-$HARVEY/.build/coverage-sweep-x64.log}"
OUT="${DIR_COVERAGE_OUT:-$HARVEY/build/x86_64/dir-coverage.txt}"
TIER4="$HARVEY/build/x86_64/tiers/tier4-tail.txt"
LIB_BUDGET="${COVERAGE_LIB_BUDGET:-900}"
DIR_BUDGET="${COVERAGE_DIR_BUDGET:-1800}"
SINGLE_BUDGET="${COVERAGE_SINGLE_BUDGET:-420}"

err() { echo "error: $*" >&2; exit 1; }

# Resolve host tools once (D-02: plan9port grep/tr lack -q/-E/-d on the
# devshell PATH — absolute system paths; NixOS-class hosts have no
# /usr/bin/grep, so fall back to PATH).
GREP=$(command -v /run/current-system/sw/bin/grep || command -v /usr/bin/grep || command -v grep) || err "no host grep found"
TIMEOUT_BIN=$(command -v /run/current-system/sw/bin/timeout || command -v /usr/bin/timeout || command -v timeout) || err "no host timeout found (coreutils)"

[ "$(uname -s)" = "Linux" ] || err "coverage-sweep.sh is linux-native only (userns chroot venue; no lima leg on x64)"
[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -f "$HARVEY/sys/src/games/mkfile" ] || err "sys/src/games/mkfile missing"

# the phase build-tree lock (the 15-01 declared coupling — the sweep is
# the whole-tree /amd64 writer; same-wave payload bakes serialize here)
command -v flock >/dev/null 2>&1 || err "flock not found — the amd64 build-tree lock needs util-linux flock"
mkdir -p "$HARVEY/.build"
exec 9>"$HARVEY/.build/amd64-tree.lock"
flock 9 || err "cannot acquire the amd64 build-tree lock"
echo "== amd64 build-tree lock held: $HARVEY/.build/amd64-tree.lock"

# host toolchain for the namespace build.  HARVEY must be EXPORTED: the
# userns venue's --wrap captures `export` output and the chroot scaffold
# re-roots it inside.
export HARVEY
HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-x86_64/bin}"
export HARVEY_LINUX_BIN
if [ ! -x "$HARVEY_LINUX_BIN/6c" ] || [ ! -x "$HARVEY_LINUX_BIN/ar" ]; then
	echo "== host toolchain missing — bootstrapping (nix run .#setup && nix run .#toolchain)"
	(cd "$HARVEY" && nix run .#setup && nix run .#toolchain) || err "host toolchain bootstrap failed"
fi
[ -x "$HARVEY_LINUX_BIN/pcc" ] || err "$HARVEY_LINUX_BIN/pcc missing — the pcc/APE class needs it (re-run nix run .#toolchain)"
[ -x "$HARVEY_LINUX_BIN/cpp" ] || err "$HARVEY_LINUX_BIN/cpp missing — pcc execs /bin/cpp; the scaffold binds this over /bin/cpp"
[ -n "${PLAN9:-}" ] && [ -x "$PLAN9/bin/rc" ] || err "\$PLAN9/bin/rc missing — run inside the nix devshell (nix develop -c sh ...)"
export FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/coverage-sweep-x64.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

# --- host-side computations (the universes the proof asserts) ----------
# DIRS universe: every dir with an mkfile under the two roots, minus the
# roots themselves (their singles are the SINGLES/MEMBERS passes; a
# single `mk all` at the root would be one unbounded invocation).
(cd "$HARVEY" && find sys/src/cmd sys/src/games -name mkfile | sed 's|/mkfile$||' | LC_ALL=C sort) \
	| "$GREP" -vx -e sys/src/cmd -e sys/src/games > "$TMPD/universe.txt" \
	|| err "universe computation failed"
UNIVERSE_N=$(wc -l < "$TMPD/universe.txt" | tr -d ' ')

# LIB universe: the sys/src/lib* dirs (ALLLIBS is exactly these — the
# sys/src/mkfile LIBS filter's unfiltered set).
ls -d "$HARVEY"/sys/src/lib* | sed "s|^$HARVEY/||" | LC_ALL=C sort > "$TMPD/libuniverse.txt"
LIB_N=$(wc -l < "$TMPD/libuniverse.txt" | tr -d ' ')

# the re-derived exclusion record (tier4's named `# exclude:` comments;
# empty until Task 2 authors them — the first run proves the raw tree)
EXCL_N=0
if [ -f "$TIER4" ]; then
	awk '/^# exclude: /{print $2}' "$TIER4" | LC_ALL=C sort -u > "$TMPD/excluded.txt"
	EXCL_N=$(wc -l < "$TMPD/excluded.txt" | tr -d ' ')
else
	: > "$TMPD/excluded.txt"
fi

# stale-exclusion check: an exclude= entry for a path the sweep visits
# anyway (or that is not in any universe) is drift, not policy
while read -r x; do
	[ -n "$x" ] || continue
	if "$GREP" -qx "$x" "$TMPD/universe.txt" || "$GREP" -qx "$x" "$TMPD/libuniverse.txt"; then
		:
	else
		err "tier4 exclusion '$x' is not a universe member (stale exclusion record — re-derive, D-10)"
	fi
done < "$TMPD/excluded.txt"

# SINGLES: the cmd root's own *.[cy] commands (cmd/mkfile's ALLTARG
# rule, mirrored host-side: ls *.[cy], drop *.tab.c generated tables)
ls "$HARVEY"/sys/src/cmd/*.c "$HARVEY"/sys/src/cmd/*.y 2>/dev/null \
	| sed 's|.*/||; s|\.[cy]$||' | LC_ALL=C sort -u > "$TMPD/singles.txt"
SINGLES_N=$(wc -l < "$TMPD/singles.txt" | tr -d ' ')

# MEMBERS: the literal TARG/ALLTARG lists of the MKMANY-family dirs
# only.  mkmany defines the per-member `$O.%` link rules, so `mk
# 6.<member>` is the member's build; mkone dirs make only $O.out and
# have NO 6.<TARG> target (a members pass there is a structural
# "don't know how to make" — measured: 130+ false fails on run 3).
# The mkmany containers' own `all:` overrides skip their TARG singles
# (aux/ip/auth/games-class), which is exactly the coverage hole this
# pass closes.  Lines: <dir>:<mbr>
: > "$TMPD/members.txt"
while read -r d; do
	m="$d/mkfile"
	[ -f "$HARVEY/$m" ] || continue
	"$GREP" -q 'cmd/mkmany' "$HARVEY/$m" || continue
	awk -v dir="$d" '
		function emit(s) {
			# strip mk variable references ($NAME, ${NAME}) — they are not
			# members (replica: $SCRIPTS) — and trailing # comments
			# (auth/secstore: "TARG = ... aescbc  # descbc" — the commented
			# member is deliberately excluded upstream, never a member)
			gsub(/\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/, "", s)
			sub(/[ \t]*#.*/, "", s)
			n=split(s,a,/[^A-Za-z0-9._-]+/)
			for(i=1;i<=n;i++) if(length(a[i])) print dir ":" a[i]
			return n > 0
		}
		/^(ALLTARG|TARG)[ \t]*=/ {
			if (inblk) inblk=0
			val=$0; sub(/^[^=]*=[ \t]*/,"",val)
			if (val ~ /`\{/) next
			inblk=1
			emit(val)
			if (val !~ /\\[ \t]*$/) inblk=0
			next
		}
		inblk && /^[ \t]*#/ { inblk=0; next }
		inblk && /^[A-Za-z%$]/ { inblk=0; next }
		inblk {
			line=$0
			emit(line)
			if (line !~ /\\[ \t]*$/) inblk=0
			next
		}
	' "$HARVEY/$m" >> "$TMPD/members.txt"
done < "$TMPD/universe.txt"
LC_ALL=C sort -u "$TMPD/members.txt" -o "$TMPD/members.txt"
MEMBERS_N=$(wc -l < "$TMPD/members.txt" | tr -d ' ')

CMD_D=$(cd "$HARVEY" && ls -d sys/src/cmd/*/ | wc -l | tr -d ' ')
echo "== universes: $UNIVERSE_N dirs (+$CMD_D cmd top-level), $LIB_N libs, $SINGLES_N singles, $MEMBERS_N members, $EXCL_N exclusions"

# --- Harvey's own yacc, ahead of the guest PATH -------------------------
# The venue's default yacc is the plan9port copy (nix/setup.sh installs
# it into hostbin), whose output DRIFTS committed yacc products: it
# emits `static const' yy tables the tree's yacc does not (measured on
# run 3: eqn/eqn.c — the tree's one committed yacc product — was
# rewritten with 57 insertions from a regeneration).  The tree's own
# yacc (sys/src/cmd/yacc.c, host-built with the plan9port 9c/9l
# wrappers + the binutils nm shim, the toolchain.sh discipline)
# reproduces the committed eqn.c byte-for-byte (in-namespace the #line
# paths match too).  Install it in a shim dir the chroot PATH prepends.
YACC_SHIM="$TMPD/yaccshim"
mkdir -p "$YACC_SHIM"
_WRAP_PATH=$(echo "$PATH" | sed 's|[^:]*hostbin-[^:]*/bin:\{0,1\}||g')
_HOSTNM=$(PATH="$_WRAP_PATH" command -v nm 2>/dev/null || true)
if [ -n "$_HOSTNM" ]; then
	ln -sf "$_HOSTNM" "$YACC_SHIM/nm"
fi
(	cd "$HARVEY/sys/src/cmd" && \
	PATH="$YACC_SHIM:$_WRAP_PATH" 9c yacc.c && \
	PATH="$YACC_SHIM:$_WRAP_PATH" 9l -o "$YACC_SHIM/yacc" yacc.o -lbio && \
	rm -f yacc.o
) || err "harvey yacc host build failed (the venue yacc shim)"
[ -x "$YACC_SHIM/yacc" ] || err "harvey yacc shim missing after build"
rm -f "$YACC_SHIM/nm"
echo "== harvey yacc shim: $YACC_SHIM/yacc (the committed yacc products regenerate byte-identically)"

# --- the guest script (runs inside the Plan 9 namespace) ---------------
cat > "$TMPD/coverage-sweep-x64-guest.sh" <<GUEST_EOF
#!/usr/bin/env bash
# coverage-sweep-x64-guest.sh — namespace side of
# build/x86_64/coverage-sweep.sh (15-07).  Runs inside the Plan 9 mount
# namespace chroot: /sys is the checkout's sys, /amd64 the arch dir,
# \$HARVEY is /harvey.  Never committed; the host driver regenerates it.
set -u

fail() { echo "COVERAGE-SWEEP-FAIL: \$1" >&2; exit 1; }

echo "== coverage sweep provenance (Harvey's vendored toolchain):"
echo "   6c: \$(command -v 6c)"
echo "   6a: \$(command -v 6a)"
echo "   6l: \$(command -v 6l)"
echo "   pcc: \$(command -v pcc)"
echo "   ar: \$(command -v ar)"
echo "   mk: \$(command -v mk)"
echo "   rc: \$(command -v rc)"
echo "   timeout: $TIMEOUT_BIN"
echo "   objtype=amd64 cputype=\${cputype:-<unset>} COVERAGE_SWEEP=1"
echo "   budgets: lib=${LIB_BUDGET}s dir=${DIR_BUDGET}s single=${SINGLE_BUDGET}s"

# nm shim (the subset-build idiom): host-toolchain generator sub-builds
# (awk's \$cputype.maketab chain) link with plan9port 9l, whose autolib
# execs bare \`nm\` on HOST ELF objects; with \$HARVEY_LINUX_BIN first on
# PATH that resolves to Harvey's ken-format nm and silently breaks
# autolib.  Shadow it with the wrapper PATH's (binutils) nm.
_P9NM_PATH=\$(echo "\$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*\$//')
_NM_HOSTNM=\$(PATH="\$_P9NM_PATH" command -v nm 2>/dev/null || true)
if [ -n "\$_NM_HOSTNM" ]; then
	_NM_SHIMDIR=\$(mktemp -d)
	ln -sf "\$_NM_HOSTNM" "\$_NM_SHIMDIR/nm"
	export PATH="\$_NM_SHIMDIR:\$PATH"
	echo "== nm shim: \$_NM_SHIMDIR/nm -> \$_NM_HOSTNM (9l autolib shadow)"
fi

COVERAGE_LOG="$TMPD/coverage-log.txt"
: > "\$COVERAGE_LOG"
echo "== coverage log: \$COVERAGE_LOG"

# the namespace binds \$HARVEY/amd64 at /amd64; mkdirs lays out the
# bin/lib tree it needs
cd "\$HARVEY" && bash build/mkdirs || fail "mkdirs"

# libc bootstrap (the aarch64 primacy rule: everything links it — the
# lib pass re-installs it idempotently, this guarantees the archive
# exists before any other lib links against it)
echo "== libc bootstrap (fresh archive)"
rm -f /amd64/lib/libc.a
(cd /sys/src/libc && COVERAGE_SWEEP=1 objtype=amd64 mk install) || fail "libc bootstrap"
[ -s /amd64/lib/libc.a ] || fail "libc bootstrap: no /amd64/lib/libc.a"

# --- the visitation shim ------------------------------------------------
SHIMD=\$(mktemp -d)
REAL_MK=\$(command -v mk) || fail "no mk on PATH"
RC_BIN=\$(command -v rc) || fail "no rc on PATH"
{
	printf '#!%s\n' "\$RC_BIN"
	printf '%s\n' '# 15-07 coverage shim (the aarch64 protocol): every sub-mk announces'
	printf '%s\n' '# itself; COVERAGE-VISIT/COVERAGE-EXIT lines only, echo text never parsed.'
	printf '%s\n' 'pwd=\`{pwd}'
	printf 'echo COVERAGE-VISIT \$pwd >> %s\n' "\$COVERAGE_LOG"
	printf '%s \$*\n' "\$REAL_MK"
	# plan9port rc leaves \$status EMPTY on success — normalize to 0
	printf '%s\n' 'st=\$status'
	printf '%s\n' 'if(~ \$"st '"''"') st=0'
	printf 'echo COVERAGE-EXIT \$pwd \$st >> %s\n' "\$COVERAGE_LOG"
	printf '%s\n' 'exit \$st'
} > "\$SHIMD/mk"
chmod +x "\$SHIMD/mk"
echo "== mk shim: \$SHIMD/mk (real mk: \$REAL_MK)"

# errfile helper: on a failing invocation, capture the first error lines
# into the coverage log as a machine-greppable digest (the capture never
# lies; the histogram is Task 2's worklist)
digest() {  # \$1 key, \$2 outfile — the digest lands in the coverage log
	# AND on stdout (the durable .build driver log) so post-mortems never
	# depend on the tmpfs coverage log surviving
	{
		echo "COVERAGE-ERR \$1"
		head -8 "\$2" | sed 's/^/COVERAGE-ERR /'
	} | tee -a "\$COVERAGE_LOG"
}

ERRCAP=\$(mktemp /tmp/cov-err.XXXXXX)

# --- PASS A: the lib universe (per-lib clean + install, fresh objects) --
echo "== PASS A: lib universe (\$(wc -l < $TMPD/libuniverse.txt | tr -d ' ') libs)"
n=0
while read -r lib; do
	[ -n "\$lib" ] || continue
	n=\$((n+1))
	echo "== [A \$n] lib \$lib"
	echo "COVERAGE-VISIT /\$lib" >> "\$COVERAGE_LOG"
	(cd "/\$lib" && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 mk clean) > "\$ERRCAP" 2>&1 || true
	st=0
	(cd "/\$lib" && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 \\
		"$TIMEOUT_BIN" -k 30 "$LIB_BUDGET" mk install) > "\$ERRCAP" 2>&1 || st=\$?
	echo "COVERAGE-EXIT /\$lib \$st" >> "\$COVERAGE_LOG"
	[ "\$st" = 0 ] || digest "lib:\$lib" "\$ERRCAP"
done < "$TMPD/libuniverse.txt"

# --- PASS B: the ape/lib substrate (the pcc/APE class link closure) -----
echo "== PASS B: ape/lib (pcc -lap and friends link against /amd64/lib/ape)"
echo "COVERAGE-VISIT /sys/src/ape/lib" >> "\$COVERAGE_LOG"
st=0
(cd /sys/src/ape/lib && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 \\
	"$TIMEOUT_BIN" -k 60 1800 "\$REAL_MK" all) > "\$ERRCAP" 2>&1 || st=\$?
echo "COVERAGE-EXIT /sys/src/ape/lib \$st" >> "\$COVERAGE_LOG"
[ "\$st" = 0 ] || digest "ape:lib" "\$ERRCAP"

# --- PASS C: the dir universe (per-dir clean + all, fresh objects) ------
echo "== PASS C: dir universe (\$(wc -l < $TMPD/universe.txt | tr -d ' ') dirs)"
n=0
while read -r d; do
	[ -n "\$d" ] || continue
	n=\$((n+1))
	echo "== [C \$n] dir \$d"
	echo "COVERAGE-VISIT /\$d" >> "\$COVERAGE_LOG"
	(cd "/\$d" && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 mk clean) > "\$ERRCAP" 2>&1 || true
	st=0
	(cd "/\$d" && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 \\
		"$TIMEOUT_BIN" -k 30 "$DIR_BUDGET" mk all) > "\$ERRCAP" 2>&1 || st=\$?
	echo "COVERAGE-EXIT /\$d \$st" >> "\$COVERAGE_LOG"
	[ "\$st" = 0 ] || digest "dir:\$d" "\$ERRCAP"
done < "$TMPD/universe.txt"

# --- PASS D: singles + container members (link-only, per-target) --------
echo "== PASS D: cmd-root singles (\$(wc -l < $TMPD/singles.txt | tr -d ' ') targets)"
n=0
while read -r s; do
	[ -n "\$s" ] || continue
	n=\$((n+1))
	echo "== [D-s \$n] single \$s"
	echo "COVERAGE-VISIT cmd-single:\$s" >> "\$COVERAGE_LOG"
	st=0
	(cd /sys/src/cmd && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 \\
		"$TIMEOUT_BIN" -k 20 "$SINGLE_BUDGET" "\$REAL_MK" "6.\$s") > "\$ERRCAP" 2>&1 || st=\$?
	rm -f "/sys/src/cmd/6.\$s" "/sys/src/cmd/\$s.6"
	echo "COVERAGE-EXIT cmd-single:\$s \$st" >> "\$COVERAGE_LOG"
	[ "\$st" = 0 ] || digest "single:\$s" "\$ERRCAP"
done < "$TMPD/singles.txt"

echo "== PASS D: container members (\$(wc -l < $TMPD/members.txt | tr -d ' ') targets)"
n=0
while read -r m; do
	[ -n "\$m" ] || continue
	n=\$((n+1))
	dir=\${m%%:*}
	tgt=\${m##*:}
	echo "== [D-m \$n] member \$m"
	echo "COVERAGE-VISIT member:\$m" >> "\$COVERAGE_LOG"
	st=0
	(cd "/\$dir" && PATH="\$SHIMD:\$PATH" COVERAGE_SWEEP=1 objtype=amd64 \\
		"$TIMEOUT_BIN" -k 20 "$SINGLE_BUDGET" "\$REAL_MK" "6.\$tgt") > "\$ERRCAP" 2>&1 || st=\$?
	rm -f "/\$dir/6.\$tgt" "/\$dir/\$tgt.6"
	echo "COVERAGE-EXIT member:\$m \$st" >> "\$COVERAGE_LOG"
	[ "\$st" = 0 ] || digest "member:\$m" "\$ERRCAP"
done < "$TMPD/members.txt"

rm -f "\$ERRCAP"
echo "== sweep body complete: \$(awk '/^COVERAGE-VISIT /{n++}END{print n+0}' "\$COVERAGE_LOG") visits, \$(awk '/^COVERAGE-EXIT /{n++}END{print n+0}' "\$COVERAGE_LOG") exits"
GUEST_EOF

# --- the userns chroot scaffold (subset-build's shape + the cpp bind) --
cat > "$TMPD/ns-x64-userns.sh" <<'USERNS_EOF'
#!/usr/bin/env bash
# ns-x64-userns.sh — the passwordless venue's namespace side (the
# subset-build scaffold + /bin/cpp for pcc).  Never committed;
# regenerated each run.  No cleanup trap — the tmpfs IS the cleanup.
set -e
NSX=$(mktemp -d "${TMPDIR:-/tmp}/ns-x64-cov-root.XXXXXX")
mount -t tmpfs tmpfs "$NSX"

mkdir -p "$NSX"/{sys,amd64,rc,lib,etc,tmp,harvey,unix,nix/store,run,dev,usr,bin}
# plan9port ed creates its scratch file under /var/tmp (measured:
# every ed-driven generator died '?TMP' without it) — the mkcname/
# mkenam scripts ride ed
mkdir -p "$NSX/var/tmp"
mount --bind "$HARVEY_SYS" "$NSX/sys"
mount --bind "$HARVEY_AMD64" "$NSX/amd64"
mount --bind "$HARVEY_RC" "$NSX/rc"
mount --bind "$HARVEY_LIB" "$NSX/lib"
mount --bind "$HARVEY_UNIX" "$NSX/unix"
for a in 386 aarch64 arm mips mips64 power power64 riscv riscv64 sparc acme; do
	mkdir -p "$NSX/$a"
	mount --bind "$HARVEY_REAL/$a" "$NSX/$a"
done
mount --bind /etc "$NSX/etc"
mount --bind /tmp "$NSX/tmp"
mount --bind "$HARVEY_REAL" "$NSX/harvey"
mount --bind /nix/store "$NSX/nix/store"
ln -sfn "$(readlink /run/current-system)" "$NSX/run/current-system"
ln -sfn ../run/current-system/sw/bin "$NSX/usr/bin"
for b in sh bash env cp mv rm ls cat mkdir touch sed grep find od tr; do
	ln -sfn "../run/current-system/sw/bin/$b" "$NSX/bin/$b"
done
for d in null zero urandom random; do
	touch "$NSX/dev/$d"
	mount --bind "/dev/$d" "$NSX/dev/$d"
done
touch "$NSX/bin/rc"
mount --bind "$PLAN9/bin/rc" "$NSX/bin/rc"

export HARVEY=/harvey
INNER_BIN="/harvey${HARVEY_LINUX_BIN#"$HARVEY_REAL"}"
# pcc execs its whole pipeline by ABSOLUTE path (pcc.c: /bin/cpp piped
# into /bin/<cc>, then /bin/<ld> to link) — the same absolute-path class
# as /bin/rc.  Measured on the first runs: with only cpp present every
# pcc compile died "exec failed" on /bin/6c (and cpp then died on the
# closed pipe).  Symlink the hostbin toolchain into the chroot's /bin so
# the pcc/APE class compiles AND links on this venue.  awk rides the
# same farm: generator scripts carry a #!/bin/awk -f shebang
# (abaco/charsets.awk), and the Plan 9 dialect is the one they expect.
for t in cpp 6c 6l 6a awk; do
	ln -sfn "$INNER_BIN/$t" "$NSX/bin/$t"
done
# PATH ends in "." — Plan 9's default path is (. /bin), and the tree's
# mkfiles invoke cwd-local generator scripts by BARE name (`rc mkenam',
# `mkscsierrs >scsierrs.c', `mkface andrew').  plan9port rc resolves a
# bare script name through $path (built from PATH), never the cwd, so
# without the trailing "." those recipes die "can't open".  The venue
# convention already carries it (nsrun.sh's su line, build-9kdraw.sh's
# scaffold); the subset-build scaffold this file was re-keyed from never
# needed it (the tier builds invoke no cwd-local script).
exec chroot "$NSX" /usr/bin/env \
	HARVEY=/harvey \
	HARVEY_LINUX_BIN="$INNER_BIN" \
	PLAN9="$PLAN9" \
	PATH="$YACC_SHIM:$INNER_BIN:/rc/bin:$PATH:." \
	HOME="$HOME" \
	FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix \
	bash "$1"
USERNS_EOF

# --- run (venue split; this host: the userns chroot) --------------------
set +e
if sudo -n true 2>/dev/null; then
	echo "== running the coverage sweep in the namespace (sudo unshare; log: $LOG)"
	export PATH="$YACC_SHIM:$HARVEY_LINUX_BIN:$PATH"
	bash "$HARVEY/build/aarch64/nsrun.sh" --wrap "bash $TMPD/coverage-sweep-x64-guest.sh" > "$LOG" 2>&1
	RC=$?
else
	echo "== no passwordless sudo — coverage sweep in an unprivileged user namespace (unshare -Ur -m chroot scaffold; log: $LOG)"
	HARVEY_SYS="$HARVEY/sys" HARVEY_AMD64="$HARVEY/amd64" HARVEY_RC="$HARVEY/rc" HARVEY_LIB="$HARVEY/lib" \
	HARVEY_UNIX="$HARVEY/unix" HARVEY_REAL="$HARVEY" HARVEY_LINUX_BIN="$HARVEY_LINUX_BIN" \
	YACC_SHIM="$YACC_SHIM" \
	PATH="$HARVEY_LINUX_BIN:$PATH" \
	unshare -Ur -m bash "$TMPD/ns-x64-userns.sh" "$TMPD/coverage-sweep-x64-guest.sh" > "$LOG" 2>&1
	RC=$?
fi
set -e
tail -30 "$LOG" || true
if [ $RC -ne 0 ]; then
	echo "error: namespace coverage sweep failed (rc=$RC); log: $LOG" >&2
	exit $RC
fi
"$GREP" -q 'sweep body complete' "$LOG" || err "driver log lacks 'sweep body complete' (the guest script died early — rig failure, not an inventory)"

COVLOG="$TMPD/coverage-log.txt"
[ -s "$COVLOG" ] || err "coverage log is empty (rig failure — nothing visited)"
cp "$COVLOG" "$HARVEY/.build/coverage-log-x64-last.txt"
VISITS=$(awk '/^COVERAGE-VISIT /{n++}END{print n+0}' "$COVLOG")
EXITS=$(awk '/^COVERAGE-EXIT /{n++}END{print n+0}' "$COVLOG")
echo "== coverage log: $VISITS VISIT / $EXITS EXIT markers (copy: .build/coverage-log-x64-last.txt)"

# the reach evidence on the driver's OWN stdout (the aarch64 driver's
# shape: the plan's verify greps THIS stream for the VISIT/EXIT markers)
echo "COVERAGE-LOG-BEGIN"
cat "$COVLOG"
echo "COVERAGE-LOG-END"

# --- the gs harvest (the Task-3 smoke's payload reads /amd64/bin/gs;
# mkone's `all` product is $O.out = 6.out, never 6.<TARG>) -----------
if [ -s "$HARVEY/sys/src/cmd/gs/6.out" ]; then
	mkdir -p "$HARVEY/amd64/bin"
	cp "$HARVEY/sys/src/cmd/gs/6.out" "$HARVEY/amd64/bin/gs" || err "gs harvest cp failed"
	magic=$(od -An -tx1 -N4 "$HARVEY/amd64/bin/gs" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || err "harvested gs: bad magic $magic (want 00008a97)"
	echo "COVERAGE-HARVEST-GS /amd64/bin/gs ok (magic 00008a97)"
else
	echo "COVERAGE-HARVEST-GS-ABSENT (gs did not build this run — expected on the red map)"
fi

# --- parse: one row per key, worst status wins --------------------------
# exit statuses: 0 ok; 124/137 (timeout/kill) hang; other nonzero fail;
# a VISIT with no EXIT is a killed invocation — hang.  Worst class wins
# across a key's visits (container recursion + own pass; clean + install).
awk '
/^COVERAGE-VISIT / { v[$2]++ }
/^COVERAGE-EXIT / {
	d = $2; st = $3 + 0
	if (!(d in cls)) cls[d] = "ok"
	if (st == 124 || st == 137) cls[d] = "hang"
	else if (st != 0) cls[d] = "fail"
	exited[d] = 1
}
END {
	for (d in v) {
		b = "ok"
		n = v[d]
		if (!(d in exited)) b = "hang"
		else if (d in cls) b = cls[d]
		sub(/^\//, "", d)
		print d " visited=" n " build=" b
	}
}
' "$COVLOG" | LC_ALL=C sort > "$TMPD/rows.txt"
[ -s "$TMPD/rows.txt" ] || err "no visitation rows parsed from the coverage log"
ROWS_N=$(wc -l < "$TMPD/rows.txt" | tr -d ' ')

# --- the report (DATA ROWS ONLY — the green contract) -------------------
# written BEFORE the assertions: the classified inventory is the data a
# rig-level assertion failure must never destroy (a partial file never
# passes as proof — the green gate below is the proof's teeth)
cp "$TMPD/rows.txt" "$OUT"
OK_N=$("$GREP" -c 'build=ok' "$OUT" || true)
BAD_N=$("$GREP" -vc 'build=ok' "$OUT" || true)
echo "== wrote $OUT ($ROWS_N rows: $OK_N ok, $BAD_N not-ok; universe $UNIVERSE_N dirs + $LIB_N libs)"

# --- universe assertions (the full-set proof; T-15-16) ------------------
# every dir-universe and lib-universe member must carry a row unless
# tier4's re-derived exclusion names it; the stale-exclusion converse
# ran above.  Missing rows = an unvisited dir silently dropped = fail.
awk '{print $1}' "$TMPD/rows.txt" > "$TMPD/visited-keys.txt"
LC_ALL=C sort -u "$TMPD/visited-keys.txt" -o "$TMPD/visited-keys.txt"
cat "$TMPD/universe.txt" "$TMPD/libuniverse.txt" | LC_ALL=C sort -u > "$TMPD/must.txt"
LC_ALL=C sort -u "$TMPD/excluded.txt" -o "$TMPD/excluded.txt"
# universe + libs minus excluded (comm against sorted excluded)
comm -23 "$TMPD/must.txt" "$TMPD/excluded.txt" > "$TMPD/required.txt"
comm -23 "$TMPD/required.txt" "$TMPD/visited-keys.txt" > "$TMPD/missing.txt"
if [ -s "$TMPD/missing.txt" ]; then
	echo "error: universe dirs with no visitation row (the proof is not full — D-09):" >&2
	head -30 "$TMPD/missing.txt" >&2
	err "missing rows: $(wc -l < "$TMPD/missing.txt" | tr -d ' ') dirs"
fi
comm -12 "$TMPD/excluded.txt" "$TMPD/visited-keys.txt" > "$TMPD/stalevisited.txt"
if [ -s "$TMPD/stalevisited.txt" ]; then
	echo "error: tier4-excluded dirs the sweep visited anyway (stale exclusion record):" >&2
	cat "$TMPD/stalevisited.txt" >&2
	err "stale exclusions"
fi

# --- the droppings sweep (the checkout IS the build tree) ---------------
# untracked-unignored files under sys/src are build droppings — remove;
# modified/deleted TRACKED files are reported loudly (a generator
# rewriting a committed file is a finding, never silently accepted)
git -C "$HARVEY" status --porcelain -z -- sys/src | while IFS= read -r -d '' ent; do
	tag=$(printf '%s' "$ent" | cut -c1-2)   # XY (porcelain), path after "XY "
	path=${ent#???}
	case "$tag" in
	"??") rm -rf "$HARVEY/$path" && echo "droppings: removed $path" ;;
	*)  echo "SWEEP-WARNING: tracked file $tag $path (investigate — generator or build rewriting committed state)" ;;
	esac
done

# --- the green gate (Task 2's terminal state; Task 1 reds by design) ----
if [ "$BAD_N" -eq 0 ]; then
	echo "COVERAGE-SWEEP-OK"
	exit 0
fi
echo "coverage: $BAD_N rows not build=ok (the classified red map — Task 2's worklist)" >&2
exit 1
