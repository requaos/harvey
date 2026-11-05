#!/bin/sh
# build/aarch64/coverage-sweep.sh — USPACE-02 complete-reach proof (D-15).
#
# Regenerates build/aarch64/dir-coverage.txt: an objtype=aarch64
# `mk checkall` over sys/src/cmd + sys/src/games with the D-13 tier
# filters DISENGAGED (COVERAGE_SWEEP=1 — 06-02's passthrough, set only by
# this sweep; rc variables are environmental, so nested sub-mks inherit
# it exactly like objtype).  The sweep certifies the whole tree, never
# the allowlist to itself (Pitfall P6-1).
#
# Visitation is observed by a PATH-prepended mk shim logging
# COVERAGE-VISIT / COVERAGE-EXIT <full path> <status> for every sub-mk —
# the containers' recursion echo shapes are not uniform (cmd/ip/auth echo
# per-dir, upas recurses silently, cwfs cd-recurses, games/music echoes
# bare names), so echo text is never parsed.  A hang watchdog polls the
# shim log: a VISIT with no matching EXIT within $COVERAGE_WATCHDOG_MIN
# minutes (default 10, TCG-sized generous) is a wedged dir — WATCHDOG
# line, the wedged sub-mk is killed, the dir is recorded build=hang, and
# the report FAILS (06-01's gethunk fixes closed that class; a hang is a
# gate failure, never data).
#
# TWO PASSES: (1) the checkall recursion itself; (2) a second-chance
# visitation pass over any in-universe dir the recursion did not visit.
# Pass 2 exists because plan9port mk recipes abort at the first failing
# command (measured 2026-11-05: a container's `for(i in $DIRS) @{ cd $i;
# mk all }` loop stops at the first failing sibling — 06-02's documented
# strict abort-on-first-failure semantics), so dirs alphabetically behind
# a failing sibling are never reached while any sibling fails (expected
# until the 06-05 lib wave unblocks them).  Pass 2 visits each such dir
# with its own guarded `mk all`, so the report's reach claim is TOTAL and
# every dir's build state is recorded (Phase-10 backlog data).  The named
# excluded= set (dirs intentionally out of the recursion — commented-out
# upstream entries etc.) is NOT second-chance visited.
#
# Per-dir build=ok|fail|hang is recorded as DATA; the gate is REACH, not
# green: the report tail reconciles the find universe (find sys/src/cmd
# sys/src/games -name mkfile) against visited ∪ excluded as SETS — an
# in-universe dir neither visited nor excluded=-named, a stale exclusion
# (an excluded= line for a dir the recursion DID visit), or a phantom
# visit is a gate failure.
#
# Platform split (subset-build.sh shape): darwin drives the lima guest
# (vm-run.sh rsyncs the checkout and runs the guest script under
# nsrun.sh); linux runs the same guest script natively under nsrun.sh's
# sudo-unshare.  See the report's venue block for the host-independence
# statement + count-jitter disclosure.
#
# CI (06-08) regenerates and `git diff --exit-code`s the committed report
# (D-15): per-dir rows, excluded= lines, and the tail are deterministic
# on an unchanged tree; the header's authoring-run line is preserved
# verbatim across regenerations (it names the first committed run; the
# run record + logs live in 06-EVIDENCE.md).  Any later phase-6 plan
# whose work flips cmd+games build rows (06-05's lib wave unblocking
# cmds, 06-06's per-cmd fixes) re-baselines the report as its own step.
#
# usage: sh build/aarch64/coverage-sweep.sh   (from the repo root,
# inside the nix devshell; DIR_COVERAGE_OUT overrides the output path,
# COVERAGE_SWEEP_LOG the driver log, COVERAGE_WATCHDOG_MIN the watchdog)

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"
LOG="${COVERAGE_SWEEP_LOG:-$HARVEY/.build/coverage-sweep.log}"
OUT="${DIR_COVERAGE_OUT:-$HARVEY/build/aarch64/dir-coverage.txt}"
WATCHDOG_MIN="${COVERAGE_WATCHDOG_MIN:-10}"

err() { echo "error: $*" >&2; exit 1; }

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on NixOS-class
# hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -f "$HARVEY/sys/src/games/mkfile" ] || err "sys/src/games/mkfile missing"
"$GREP" -q 'checkall:V:' "$HARVEY/sys/src/games/mkfile" || err "sys/src/games/mkfile lacks the additive checkall target (06-04 Task 1)"
"$GREP" -q 'checkall:V:' "$HARVEY/sys/src/cmd/mkfile" || err "sys/src/cmd/mkfile lacks checkall (Phase-1/06-02 machinery)"

# Platform split: linux runs natively (sudo unshare via nsrun.sh);
# darwin drives the lima guest.  The guest script below and the host-side
# report generation are shared by both legs.
NATIVE_LINUX=
if [ "$(uname -s)" = "Linux" ]; then
	NATIVE_LINUX=1
fi

if [ -n "$NATIVE_LINUX" ]; then
	# HARVEY must be EXPORTED here: nsrun.sh's --wrap captures `export`
	# output and re-sources it inside the namespace.
	export HARVEY
	_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
	HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-$_hb_arch/bin}"
	export HARVEY_LINUX_BIN
	if [ ! -x "$HARVEY_LINUX_BIN/7c" ] || [ ! -x "$HARVEY_LINUX_BIN/ar" ]; then
		echo "== host toolchain missing — bootstrapping (nix run .#setup && nix run .#toolchain)"
		(cd "$HARVEY" && nix run .#setup && nix run .#toolchain) || err "host toolchain bootstrap failed"
	fi
	export FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix
else
	command -v limactl >/dev/null 2>&1 || err "limactl not found — run inside the nix devshell"
	if ! limactl list -q 2>/dev/null | "$GREP" -qx "$VM"; then
		err "lima VM '$VM' does not exist"
	fi
	status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
	if [ "$status" != "Running" ]; then
		limactl start "$VM"
	fi
fi

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/coverage-sweep.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

# The measured in-universe exclusion set (06-04 authoring): dirs with a
# mkfile that the checkall recursion intentionally never visits, each
# with its cited reason.  Shared with the guest script (the second-chance
# pass skips exactly these) and emitted into the report.  CI regen + diff
# keeps this table honest: a tree change that invalidates an entry reds
# the reconciliation.
cat > "$TMPD/exclusions.txt" <<'EOF'
sys/src/cmd/aux/antiword|upstream-omitted|not in aux/mkfile's DIRS (mnihongo flashfs gps na vga realemu)
sys/src/cmd/cwfs/9netics32.16k|upstream-omitted|cwfs/mkfile's default recursion enters only cwfs/cwfs (`cd cwfs && mk all`)
sys/src/cmd/cwfs/9netics64.8k|upstream-omitted|cwfs/mkfile's default recursion enters only cwfs/cwfs (`cd cwfs && mk all`)
sys/src/cmd/cwfs/choline|upstream-omitted|cwfs/mkfile's default recursion enters only cwfs/cwfs (`cd cwfs && mk all`)
sys/src/cmd/cwfs/emelie|upstream-omitted|cwfs/mkfile's default recursion enters only cwfs/cwfs (`cd cwfs && mk all`)
sys/src/cmd/cwfs/fs|upstream-omitted|cwfs/mkfile's default recursion enters only cwfs/cwfs (`cd cwfs && mk all`)
sys/src/cmd/cwfs/fs64|upstream-omitted|cwfs/mkfile's default recursion enters only cwfs/cwfs (`cd cwfs && mk all`)
sys/src/cmd/postscript/picpack|upstream-disabled|commented out of postscript/mkfile's TARGETS (UNIX remnants)
sys/src/cmd/postscript/postbgi|upstream-disabled|commented out of postscript/mkfile's TARGETS (UNIX remnants)
sys/src/cmd/postscript/postdaisy|upstream-disabled|commented out of postscript/mkfile's TARGETS (UNIX remnants)
sys/src/cmd/postscript/postdmd|upstream-disabled|commented out of postscript/mkfile's TARGETS (UNIX remnants)
sys/src/cmd/postscript/postmd|upstream-disabled|commented out of postscript/mkfile's TARGETS (UNIX remnants)
sys/src/cmd/postscript/trofftable|upstream-disabled|commented out of postscript/mkfile's TARGETS (UNIX remnants)
sys/src/cmd/tcs/font|upstream-omitted|tcs/mkfile has no font recursion (mkone shape; nothing references font)
sys/src/games/blabs|upstream-disabled|commented out of games/mkfile's DIRS
EOF

# Guest-ready form: plain namespace-absolute paths, one per line.  Field
# extraction uses awk index/substr — the namespace's PATH puts Harvey's
# hostbin first, and Plan 9's sed garbles on `|` inside a /-delimited
# pattern (measured 2026-11-05; the same D-02 shadowing class as 07-04's
# dd incident).
awk '{ i = index($0, "|"); if (i > 1) print substr($0, 1, i-1) }' "$TMPD/exclusions.txt" > "$TMPD/excluded-paths.txt"
sed 's|^|/|' "$TMPD/excluded-paths.txt" > "$TMPD/excluded-nspaths.txt"

# guest-side script: written to a host tmp file; on darwin rsynced to the
# guest's /tmp and executed via vm-run.sh (which rsyncs the checkout,
# ensures the guest toolchain, and wraps the command in nsrun.sh's
# namespace entry); on linux executed natively under nsrun.sh --wrap.
cat > "$TMPD/coverage-sweep-guest.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# coverage-sweep-guest.sh — guest side of build/aarch64/coverage-sweep.sh
# (06-04).  Runs inside the Plan 9 mount namespace (nsrun.sh --wrap):
# /sys is the checkout's sys, /aarch64 the committed arch dir.  Never
# committed; the host driver regenerates it each run.
set -e

fail() { echo "COVERAGE-SWEEP-FAIL: $1" >&2; exit 1; }

WATCHDOG_SECS=$(( ${COVERAGE_WATCHDOG_MIN:-10} * 60 ))
EXCL="${COVERAGE_EXCL:-/tmp/gsd-coverage-excluded-nspaths.txt}"
[ -f "$EXCL" ] || fail "exclusion list missing: $EXCL"

echo "== coverage sweep provenance (Harvey's vendored toolchain):"
echo "   7c: $(command -v 7c)"
echo "   7a: $(command -v 7a)"
echo "   7l: $(command -v 7l)"
echo "   ar: $(command -v ar)"
echo "   mk: $(command -v mk)"
echo "   rc: $(command -v rc)"
echo "   objtype=aarch64 cputype=${cputype:-<unset>} COVERAGE_SWEEP=1"
echo "   watchdog: ${WATCHDOG_SECS}s per open VISIT"

# nm shim (nix/build.sh:16-32's idiom, mirrored from subset-build.sh):
# host-toolchain generator sub-builds (cmd/awk's $cputype.maketab chain —
# G1) link with plan9port 9l, whose autolib execs bare `nm` on HOST ELF
# objects; with $HARVEY_LINUX_BIN first on the devshell PATH that resolves
# to Harvey's ken-format nm, which fails "Can't read header" and silently
# breaks autolib.  Shadow it with the wrapper PATH's (binutils) nm for the
# duration.
_P9NM_PATH=$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$//')
_NM_HOSTNM=$(PATH="$_P9NM_PATH" command -v nm 2>/dev/null || true)
if [ -n "$_NM_HOSTNM" ]; then
	_NM_SHIMDIR=$(mktemp -d)
	ln -sf "$_NM_HOSTNM" "$_NM_SHIMDIR/nm"
	export PATH="$_NM_SHIMDIR:$PATH"
	echo "== nm shim: $_NM_SHIMDIR/nm -> $_NM_HOSTNM (9l autolib shadow)"
fi

# the namespace binds $HARVEY/aarch64 at /aarch64; mkdirs lays out the
# bin/lib tree it needs (vm-run.sh does not run mkdirs first).
cd "$HARVEY" && bash build/mkdirs || fail "mkdirs"

# libs prebuild, UNFILTERED (COVERAGE_SWEEP=1 disengages the D-13 LIBS
# filter at sys/src/mkfile) so cmd per-dir build data reflects cmd
# sources, not missing archives.  Best-effort by design: the libs target's
# rc loop continues past per-lib failures (a lib failure is data, not an
# abort — the report covers cmd+games), and the shim is NOT yet on PATH,
# so the prebuild stays out of the coverage log.
echo "== libs prebuild (objtype=aarch64 COVERAGE_SWEEP=1 mk libs; best-effort)"
(cd /sys/src && objtype=aarch64 COVERAGE_SWEEP=1 mk libs) || true

# --- the visitation shim -------------------------------------------------
# A scratch dir holding an executable `mk` rc script: appends
# COVERAGE-VISIT <pwd> to $COVERAGE_LOG, runs the real mk with the same
# args and captures its exit status, appends COVERAGE-EXIT <pwd> <status>,
# and exits with that status.  Prepended to PATH scoped around the sweep
# invocations only (the libs prebuild stays out of the log).
SHIMD=$(mktemp -d)
REAL_MK=$(command -v mk) || fail "no mk on PATH"
RC_BIN=$(command -v rc) || fail "no rc on PATH"
COVERAGE_LOG=$(mktemp /tmp/coverage-log.XXXXXX)
export COVERAGE_LOG
{
	printf '#!%s\n' "$RC_BIN"
	printf '%s\n' '# 06-04 coverage shim: every sub-mk announces itself with its full'
	printf '%s\n' '# path (container echo shapes are not uniform, so the recursion’s own'
	printf '%s\n' '# echo text is never parsed).  COVERAGE-VISIT/COVERAGE-EXIT lines only.'
	printf '%s\n' 'pwd=`{pwd}'
	printf 'echo COVERAGE-VISIT $pwd >> %s\n' "$COVERAGE_LOG"
	printf '%s $*\n' "$REAL_MK"
	# plan9port rc leaves $status EMPTY on success — normalize to an
	# explicit 0 so the log's EXIT lines always carry a status field.
	printf '%s\n' 'st=$status'
	printf '%s\n' 'if(~ $"st '"''"') st=0'
	printf 'echo COVERAGE-EXIT $pwd $st >> %s\n' "$COVERAGE_LOG"
	printf '%s\n' 'exit $st'
} > "$SHIMD/mk"
chmod +x "$SHIMD/mk"
echo "== mk shim: $SHIMD/mk (real mk: $REAL_MK; log: $COVERAGE_LOG)"

# --- the sweep -----------------------------------------------------------
# The roots' own VISIT/EXIT lines are written by this driver body (the
# top-level mk is the REAL mk so the watchdog never sees a whole-sweep-long
# open VISIT; the roots are in the find universe and must carry rows).
# mk exit status is never trusted (02-12) — the per-dir EXIT statuses are
# the data; checkall's aggregate exit is recorded for the root row only.
run_sweeps() {
	set +e
	echo "COVERAGE-VISIT /sys/src/cmd" >> "$COVERAGE_LOG"
	(cd /sys/src/cmd && PATH="$SHIMD:$PATH" COVERAGE_SWEEP=1 objtype=aarch64 "$REAL_MK" checkall)
	st=$?
	echo "COVERAGE-EXIT /sys/src/cmd $st" >> "$COVERAGE_LOG"
	echo "== cmd checkall aggregate exit: $st (per-dir failures are data)"
	echo "COVERAGE-VISIT /sys/src/games" >> "$COVERAGE_LOG"
	(cd /sys/src/games && PATH="$SHIMD:$PATH" COVERAGE_SWEEP=1 objtype=aarch64 "$REAL_MK" checkall)
	st=$?
	echo "COVERAGE-EXIT /sys/src/games $st" >> "$COVERAGE_LOG"
	echo "== games checkall aggregate exit: $st (per-dir failures are data)"

	# --- pass 2: second-chance visitation -------------------------------
	# plan9port mk recipes abort at the first failing command (measured
	# 2026-11-05), so a container's recursion stops at its first failing
	# sibling — dirs behind it were never visited.  Visit each remaining
	# in-universe dir with its own guarded `mk all` so reach is TOTAL and
	# every dir's build state is recorded.  The named exclusions (dirs
	# intentionally out of the recursion) are skipped here by design.
	find /sys/src/cmd /sys/src/games -name mkfile | sed 's|/mkfile$||' | LC_ALL=C sort > /tmp/coverage-universe.txt
	awk '/^COVERAGE-VISIT /{print $2}' "$COVERAGE_LOG" | LC_ALL=C sort -u > /tmp/coverage-visited.txt
	LC_ALL=C sort -u /tmp/coverage-visited.txt "$EXCL" > /tmp/coverage-covered.txt
	comm -23 /tmp/coverage-universe.txt /tmp/coverage-covered.txt > /tmp/coverage-second-chance.txt
	n=$(wc -l < /tmp/coverage-second-chance.txt | tr -d ' ')
	echo "== second-chance visitation: $n dirs the container recursion failure-aborted past"
	while read -r d; do
		[ -n "$d" ] || continue
		echo "SECOND-CHANCE $d" >> "$COVERAGE_LOG"
		echo "== second chance: $d"
		# invoke BARE mk (the shim, via PATH) so the dir's own visit is
		# logged — $REAL_MK would only log nested sub-mks, and a leaf
		# dir runs none.
		(cd "$d" && PATH="$SHIMD:$PATH" COVERAGE_SWEEP=1 objtype=aarch64 mk all)
		# per-dir failures are data; never abort the pass
	done < /tmp/coverage-second-chance.txt
	return 0
}

# --- the hang watchdog ---------------------------------------------------
# Poll the shim log: a dir with more VISITs than EXITs is open.  Fire on
# the leaf-most open dir (a parent with an open descendant is merely
# waiting) once it has been open for WATCHDOG_SECS: WATCHDOG line, then
# kill the wedged sub-mk's NON-rc processes (cwd under the dir) so the
# shim lives to write its EXIT line and the container's loop continues.
# Escalation: a dir still open ESCALATE_SECS after the first kill loses
# its rc processes too (the container's remaining iteration is sacrificed;
# the report fails on the WATCHDOG line either way).
ESCALATE_SECS=120
kill_dir() {  # $1 dir, $2 signal, $3 norc|all
	for p in /proc/[0-9]*; do
		pid=${p#/proc/}
		c=$(readlink "$p/cwd" 2>/dev/null) || continue
		case "$c" in "$1"|"$1"/*) ;; *) continue;; esac
		if [ "$3" = norc ]; then
			comm=$(cat "$p/comm" 2>/dev/null || echo "")
			[ "$comm" = rc ] && continue
		fi
		kill -"$2" "$pid" 2>/dev/null || true
	done
}

watchdog() {  # $1 = sweep pid
	local sweep_pid=$1
	declare -A open_since wedged
	while kill -0 "$sweep_pid" 2>/dev/null; do
		sleep 15
		[ -f "$COVERAGE_LOG" ] || continue
		opens=$(awk '
			/^COVERAGE-VISIT / { v[$2]++ }
			/^COVERAGE-EXIT /  { e[$2]++ }
			END { for (d in v) if (v[d] - e[d] > 0) print d }
		' "$COVERAGE_LOG")
		now=$SECONDS
		for d in $opens; do
			case "$d" in /sys/src/cmd|/sys/src/games) continue;; esac
			# leaf-most open only: skip d if another open dir is under it
			leafmost=1
			for o in $opens; do
				case "$o" in "$d"/*) leafmost=0; break;; esac
			done
			[ "$leafmost" = 1 ] || continue
			if [ -z "${open_since[$d]:-}" ]; then
				open_since[$d]=$now
				continue
			fi
			age=$(( now - open_since[$d] ))
			if [ -z "${wedged[$d]:-}" ]; then
				[ "$age" -gt "$WATCHDOG_SECS" ] || continue
				wedged[$d]=1
				echo "WATCHDOG $d" >> "$COVERAGE_LOG"
				echo "== WATCHDOG: $d open ${age}s — killing the wedged sub-mk (non-rc)" >&2
				kill_dir "$d" TERM norc
				sleep 2
				kill_dir "$d" KILL norc
			elif [ "${wedged[$d]}" = 1 ] && [ "$age" -gt $(( WATCHDOG_SECS + ESCALATE_SECS )) ]; then
				wedged[$d]=2
				echo "WATCHDOG $d escalate" >> "$COVERAGE_LOG"
				echo "== WATCHDOG: $d still open after kill — escalating (all processes)" >&2
				kill_dir "$d" TERM all
				sleep 2
				kill_dir "$d" KILL all
			fi
		done
	done
}

run_sweeps &
SWEEP_PID=$!
watchdog "$SWEEP_PID"
wait "$SWEEP_PID"

echo "== sweep complete: $(awk '/^COVERAGE-VISIT/{n++}END{print n+0}' "$COVERAGE_LOG") visits, $(awk '/^COVERAGE-EXIT/{n++}END{print n+0}' "$COVERAGE_LOG") exits, $(awk '/^WATCHDOG/{n++}END{print n+0}' "$COVERAGE_LOG") watchdog fires, $(wc -l < /tmp/coverage-second-chance.txt | tr -d ' ') second-chance visits"

# the reach evidence FIRST (retained in the driver log even if a later
# check fails — failure triage needs it)
echo "COVERAGE-LOG-BEGIN"
cat "$COVERAGE_LOG"
echo "COVERAGE-LOG-END"

# --- Wave-0 blocker re-verification (06-04 task step 4) ------------------
# jpg's Phase-1 generator fix (7be7e98c8) re-verified host-correct for the
# aarch64 sweep: FORCE the generator chain (the committed ycbcr.h/rgbv.h
# can satisfy mk without it) and prove the freshly produced generators are
# host ELF and the headers regenerate.  Runs WITHOUT the shim (the reach
# log is complete above; guest tree is a scratch rsync copy, self-healing
# on the next vm-run).
echo "== wave-0 blocker re-verification: jpg generator chain (forced)"
(cd /sys/src/cmd/jpg && rm -f ycbcr.h rgbv.h unix.rgbycc unix.rgbrgbv \
	&& objtype=aarch64 COVERAGE_SWEEP=1 mk ycbcr.h rgbv.h) || fail "jpg generator chain (ycbcr.h/rgbv.h)"
for f in /sys/src/cmd/jpg/unix.rgbycc /sys/src/cmd/jpg/unix.rgbrgbv; do
	[ -x "$f" ] || fail "jpg generator missing: $f"
	m=$(od -An -tx1 -N4 "$f" | tr -d ' \n')
	echo "BLOCKER-CHECK $f magic=$m"
done
for f in /sys/src/cmd/jpg/ycbcr.h /sys/src/cmd/jpg/rgbv.h; do
	if [ -s "$f" ]; then echo "BLOCKER-CHECK $f present"; else echo "BLOCKER-CHECK $f MISSING"; fi
done
GUEST_EOF

mkdir -p "$HARVEY/.build"
set +e
if [ -n "$NATIVE_LINUX" ]; then
	echo "== running the coverage sweep natively (sudo unshare namespace; log: $LOG)"
	# hostbin FIRST so the namespace's mk/7a/7c/7l/ar resolve (the
	# devshell's PATH shape); nsrun.sh's su line appends /rc/bin:. itself.
	export PATH="$HARVEY_LINUX_BIN:$PATH"
	# pcc execs cpp by the ABSOLUTE /bin/cpp (pcc.c's doexec) — on a clean
	# host /bin/cpp is the distro's gcc driver (or absent), which dies on
	# its own cc1 inside the namespace (x86_64 runner evidence: 9 ×
	# 'cannot execute cc1' execvp errors, caught by the generator scan's
	# exec-failure sweep-grep). nix/build.sh installs Harvey's cpp for the
	# full build; the native-linux sweep needs the same provisioning.
	if [ -x "$HARVEY_LINUX_BIN/cpp" ]; then
		sudo cp "$HARVEY_LINUX_BIN/cpp" /bin/cpp || err "could not provision /bin/cpp (Harvey's)"
	else
		err "hostbin cpp missing — the toolchain bootstrap above should have built it"
	fi
	export COVERAGE_WATCHDOG_MIN="$WATCHDOG_MIN"
	export COVERAGE_EXCL="$TMPD/excluded-nspaths.txt"
	bash "$HARVEY/build/aarch64/nsrun.sh" --wrap "bash $TMPD/coverage-sweep-guest.sh" > "$LOG" 2>&1
else
	echo "== pushing the guest coverage-sweep script"
	rsync -a -e "$RSYNC_RSH" "$TMPD/coverage-sweep-guest.sh" "$GUEST:/tmp/gsd-coverage-sweep-guest.sh"
	rsync -a -e "$RSYNC_RSH" "$TMPD/excluded-nspaths.txt" "$GUEST:/tmp/gsd-coverage-excluded-nspaths.txt"
	echo "== running the coverage sweep in the guest namespace (log: $LOG)"
	sh "$HARVEY/build/aarch64/vm-run.sh" "COVERAGE_WATCHDOG_MIN=$WATCHDOG_MIN COVERAGE_EXCL=/tmp/gsd-coverage-excluded-nspaths.txt bash /tmp/gsd-coverage-sweep-guest.sh" > "$LOG" 2>&1
fi
RC=$?
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: guest coverage sweep failed (rc=$RC); log: $LOG" >&2
	exit $RC
fi
"$GREP" -q 'COVERAGE-LOG-BEGIN' "$LOG" || err "driver log lacks COVERAGE-LOG-BEGIN (sweep did not complete)"
"$GREP" -q 'COVERAGE-LOG-END' "$LOG" || err "driver log lacks COVERAGE-LOG-END (sweep did not complete)"

# --- extract + retain the reach evidence --------------------------------
# (awk, not sed: the devshell PATH puts Harvey's hostbin first and Plan
# 9's sed garbles the {/pat/!p} group form — D-02 shadowing class)
awk '/^COVERAGE-LOG-BEGIN$/{f=1;next} /^COVERAGE-LOG-END$/{f=0} f' "$LOG" > "$TMPD/coverage-log.txt"
[ -s "$TMPD/coverage-log.txt" ] || err "extracted coverage log is empty"
cp "$TMPD/coverage-log.txt" "$HARVEY/.build/coverage-log.txt"

# WATCHDOG absence is a hard gate (a wedged dir means the gethunk class is
# not closed — the report must fail, per the plan's fails_when).
if "$GREP" -q '^WATCHDOG' "$TMPD/coverage-log.txt"; then
	echo "error: WATCHDOG fired — a dir wedged under the sweep:" >&2
	"$GREP" '^WATCHDOG' "$TMPD/coverage-log.txt" >&2
	err "hang detected; see $LOG"
fi

# --- Wave-0 blocker gates (jpg host-ELF generators) ----------------------
"$GREP" -q '^BLOCKER-CHECK /sys/src/cmd/jpg/unix.rgbycc magic=7f454c46$' "$LOG" || err "jpg's unix.rgbycc is not host ELF (see $LOG) — the Phase-1 fix (7be7e98c8) does not hold"
"$GREP" -q '^BLOCKER-CHECK /sys/src/cmd/jpg/unix.rgbrgbv magic=7f454c46$' "$LOG" || err "jpg's unix.rgbrgbv is not host ELF (see $LOG)"
"$GREP" -q '^BLOCKER-CHECK /sys/src/cmd/jpg/ycbcr.h present$' "$LOG" || err "jpg's ycbcr.h not produced"
"$GREP" -q '^BLOCKER-CHECK /sys/src/cmd/jpg/rgbv.h present$' "$LOG" || err "jpg's rgbv.h not produced"

# --- parse: one row per unique in-universe pwd ----------------------------
# Log paths are namespace-absolute (/sys/src/...); strip the leading slash
# to the repo-relative form.  build=hang iff a WATCHDOG line names the dir;
# else fail iff any EXIT carried a non-zero status; else ok.  visited=N is
# the raw visit count (cc is visited twice by construction — checkall's
# `for(i in cc $ALLDIRS)` with cc present in ALLDIRS; awk/jtagfs/spell also
# pick up their objtype=$cputype generator sub-mks; second-chance visits
# add one each).
awk '
/^COVERAGE-VISIT / {
	d = $2; sub(/^\//, "", d); visits[d]++
}
/^COVERAGE-EXIT / {
	d = $2; sub(/^\//, "", d); st = $3
	if (st != "" && st != "0") worst[d] = 1
	else if (!(d in worst)) worst[d] = 0
}
/^WATCHDOG / {
	d = $2; sub(/^\//, "", d); hang[d] = 1
}
END {
	for (d in visits) {
		b = "ok"
		if (d in hang) b = "hang"
		else if (!(d in worst)) b = "hang"   # VISIT with no EXIT: truncated/died
		else if (worst[d]) b = "fail"
		print d " visited=" visits[d] " build=" b
	}
}
' "$TMPD/coverage-log.txt" | LC_ALL=C sort > "$TMPD/rows.txt"
[ -s "$TMPD/rows.txt" ] || err "no visitation rows parsed from the coverage log"

awk '{print $1}' "$TMPD/rows.txt" > "$TMPD/visited.txt"

# --- the find universe + set reconciliation -------------------------------
(cd "$HARVEY" && find sys/src/cmd sys/src/games -name mkfile | sed 's|/mkfile$||' | LC_ALL=C sort) > "$TMPD/universe.txt"
UNIVERSE_N=$(wc -l < "$TMPD/universe.txt" | tr -d ' ')

# excluded-paths.txt was computed at exclusion-table write time (awk
# index/substr — Plan 9 awk/sed dialect safety; see the write site)
LC_ALL=C sort -u "$TMPD/excluded-paths.txt" > "$TMPD/excluded-paths-sorted.txt"
mv "$TMPD/excluded-paths-sorted.txt" "$TMPD/excluded-paths.txt"

comm -23 "$TMPD/universe.txt" "$TMPD/visited.txt" > "$TMPD/unvisited.txt"
comm -13 "$TMPD/universe.txt" "$TMPD/visited.txt" > "$TMPD/phantoms.txt"
comm -12 "$TMPD/excluded-paths.txt" "$TMPD/visited.txt" > "$TMPD/stale.txt"

RECON_OK=1
if ! diff -q "$TMPD/unvisited.txt" "$TMPD/excluded-paths.txt" >/dev/null; then
	RECON_OK=0
	echo "error: in-universe dirs neither visited nor excluded=-named (or exclusion-table drift):" >&2
	diff "$TMPD/excluded-paths.txt" "$TMPD/unvisited.txt" >&2 || true
fi
if [ -s "$TMPD/phantoms.txt" ]; then
	RECON_OK=0
	echo "error: phantom visits (visited dirs outside the find universe):" >&2
	cat "$TMPD/phantoms.txt" >&2
fi
if [ -s "$TMPD/stale.txt" ]; then
	RECON_OK=0
	echo "error: stale exclusions (excluded= lines for dirs the recursion DID visit):" >&2
	cat "$TMPD/stale.txt" >&2
fi
[ "$RECON_OK" = 1 ] || err "set reconciliation failed (universe != visited ∪ excluded)"

VISITED_N=$(wc -l < "$TMPD/visited.txt" | tr -d ' ')
EXCLUDED_N=$(wc -l < "$TMPD/excluded-paths.txt" | tr -d ' ')

# --- the committed report (D-15) ------------------------------------------
# authoring-run line: preserved verbatim across regenerations when the
# committed report already carries one (byte-stability on an unchanged
# tree); written from the current run only at first authoring.
AUTHORING_LINE=""
if [ -f "$HARVEY/build/aarch64/dir-coverage.txt" ]; then
	AUTHORING_LINE=$(awk '/^# authoring-run: /{sub(/^# authoring-run: /,""); print; exit}' "$HARVEY/build/aarch64/dir-coverage.txt")
fi
if [ -z "$AUTHORING_LINE" ]; then
	# resolve an ISO-capable date by probe, not by name: the devshell
	# PATH puts Harvey's hostbin first, and Plan 9's date prints the
	# epoch for `-u +%Y-%m-%d` (measured 2026-11-05 — the same D-02
	# hostbin-shadowing class as the sed/awk dialects).
	DATE_BIN=""
	for c in gdate /bin/date date; do
		p=$(command -v "$c" 2>/dev/null || true)
		[ -n "$p" ] || continue
		out=$("$p" -u +%Y-%m-%d 2>/dev/null || true)
		case "$out" in
		[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
			DATE_BIN="$p"; RUN_DATE="$out"; break;;
		esac
	done
	[ -n "$DATE_BIN" ] || err "no ISO-capable date found (tried gdate, /bin/date, date)"
	AUTHORING_LINE="commit $(git -C "$HARVEY" rev-parse HEAD) $RUN_DATE (run record + logs: 06-EVIDENCE.md)"
fi

# measured per-dir states woven into the notes (deterministic per tree)
row_state() {  # $1 = row path
	awk -v d="$1" '$1 == d {print $2, $3}' "$TMPD/rows.txt"
}
MAHJONGG_STATE=$(row_state sys/src/games/mahjongg)
A4_STATE=$(row_state sys/src/cmd/4a)
GS_STATE=$(row_state sys/src/cmd/gs)
JPG_STATE=$(row_state sys/src/cmd/jpg)

{
cat <<EOF
# dir-coverage.txt — USPACE-02 complete-reach report (D-15, 06-04)
#
# generator: build/aarch64/coverage-sweep.sh — objtype=aarch64
#   COVERAGE_SWEEP=1 (the D-13 tier filters disengaged at every depth;
#   only this sweep sets it).  Two passes: (1) \`mk checkall\` over
#   sys/src/cmd + sys/src/games; (2) a second-chance visitation pass
#   over any in-universe dir the recursion did not visit (plan9port mk
#   recipes abort at the first failing command — measured 2026-11-05 —
#   so a container's loop stops at its first failing sibling; pass 2
#   gives each such dir its own guarded \`mk all\`; the coverage log's
#   SECOND-CHANCE lines name them).  Visitation observed by a
#   PATH-prepended mk shim logging COVERAGE-VISIT/COVERAGE-EXIT with
#   full paths for every sub-mk (the recursion echo shapes are not
#   uniform — ip/auth echo per-dir, upas recurses silently, cwfs
#   cd-recurses, games/music echoes bare names — so echo text is never
#   parsed).  Hang watchdog: a VISIT with no matching EXIT within
#   ${WATCHDOG_MIN} min is a wedged dir — WATCHDOG line, build=hang, the
#   report FAILS (06-01's gethunk fixes closed that class; a hang is a
#   gate failure, never data).
# venue: linux namespace build (lima guest on darwin hosts;
#   native sudo-unshare on linux hosts).  The reach set + per-dir
#   build verdicts are host-independent — proven identical on
#   linux-aarch64 (authoring venue) and linux-x86_64 (06-08's
#   hosted wave0-host leg).  Per-dir visit COUNTS jitter with
#   watchdog/second-chance timing across host classes
#   (measurement noise, not drift): the CI drift gate diffs
#   count-normalized copies, and the counts stay embedded as
#   data (jpg's note line included — the count is information,
#   the gate tolerates it).
# authoring-run: $AUTHORING_LINE
#   ^ preserved verbatim across regenerations; it names the first
#   committed run.  Everything below this header is regenerated and
#   deterministic on an unchanged tree — 06-08's CI job regenerates and
#   \`git diff --exit-code\`s (D-15).  Run records + logs: 06-EVIDENCE.md.
# re-baseline standing rule: any later phase-6 plan whose work flips
#   cmd+games build rows (06-05's lib wave unblocking cmds, 06-06's
#   per-cmd fixes) regenerates and commits this file as its own step.
# row grammar:
#   <path> visited=N build=ok|fail|hang — per-dir reach + build data
#     (N counts sub-mk visits; cc is visited twice by construction —
#     checkall's \`for(i in cc \$ALLDIRS)\` with cc present in ALLDIRS;
#     awk/jtagfs/spell also pick up their objtype=\$cputype generator
#     sub-mks; second-chance visits add one each).  build=fail rows are
#     Phase-10 backlog DATA, not gate failures.  The two root rows
#     (sys/src/cmd, sys/src/games) carry the checkall aggregate exit:
#     non-zero whenever any child failed (mk exit status is never
#     trusted — 02-12 — the per-dir rows are the data).
#   excluded=<NOMK|upstream-omitted|upstream-disabled|decision> <path>
#     <reason> — every in-universe dir the recursion never visits (the
#     reconciliation below makes a silent drop impossible), then
#     boundary \`decision\` lines documenting the out-of-universe
#     exclusions (NOT part of the reconciliation).
#
# notes — Wave-0 blocker verdicts re-verified this run (06-04 task
#   step 4):
#   jpg ($JPG_STATE): ycbcr.h/rgbv.h force-regenerated by host-ELF
#     unix.rgbycc/unix.rgbrgbv — the Phase-1 fix (7be7e98c8) holds for
#     the aarch64 sweep; the run removed the committed headers +
#     generators in the scratch guest tree, rebuilt via the mkfile's
#     own rules, and asserted magic 7f454c46 on both generator
#     binaries (BLOCKER-CHECK lines in the run log).
#   mahjongg ($MAHJONGG_STATE): verified non-issue as a structural
#     blocker — compiled clean in the Phase-1 sweep
#     (01-01-SUMMARY.md:156); the row below is this run's fresh data.
#   4a ($A4_STATE): builds as an amd64 target (01-01-SUMMARY.md:150 +
#     PITFALLS notorious-dirs); as an aarch64 *target* it is excluded
#     by decision — toolchain letters are host tools via
#     BUILDTOOLCHAIN only — but it is VISITED and recorded here like
#     every cmd dir.
#   gs ($GS_STATE): tier-excluded by decision but VISITED by this
#     sweep — default.aarch64.h is absent so its build=fail row is
#     expected data; its guarded genarch generator is audit row G6
#     (build/aarch64/generator-audit.txt).
EOF
cat "$TMPD/rows.txt"
echo "#"
# in-universe exclusions (sorted by path), then boundary decision lines
LC_ALL=C sort "$TMPD/exclusions.txt" | while IFS='|' read -r p k r; do
	echo "excluded=$k $p $r"
done
cat <<'EOF'
excluded=decision sys/src/ape subsystem outside the cmd+games universe (milestone decision; one of the three other sys/src/mkfile recursion members) — not part of the reconciliation
excluded=decision sys/src/nboot boot media outside the cmd+games universe (efiboot.fat explicit-only since Phase-1 76c55c91a) — not part of the reconciliation
excluded=decision sys/src/acme subsystem outside the cmd+games universe (one of the three other sys/src/mkfile recursion members) — not part of the reconciliation
EOF
echo "#"
cat <<EOF
universe_count=$UNIVERSE_N
visited_count=$VISITED_N
excluded_count=$EXCLUDED_N
reconciliation: universe == visited ∪ excluded exactly; zero phantom visits; zero stale exclusions — CLOSED
EOF
} > "$OUT"

echo "== wrote $OUT ($VISITED_N visited rows, $EXCLUDED_N in-universe exclusions, universe $UNIVERSE_N)"
echo "COVERAGE-SWEEP-OK"
