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
# 14-08 (XEXEC-04) adds the r9-x64 execution leg — the ABI witness's
# SECOND half: the SAME /amd64/bin set the k10t1 kernel embeds (the
# witness manifest build-9k10t1.sh pinned; mkimage.sh's tier bake
# digest-verified before staging) executes on r9-x86_64, driven by the
# in-image sweep (build/x86_64/tier1-sweep.rc baked at /lib) typed at
# the % prompt.  The r9 leg runs when T1_R9_ISO names a composed tier
# ISO (r9's iso-builder over out/bootfs-tier.paq; the boot-r9-tier1-x64
# app automates the whole compose); T1_LEG=r9 runs ONLY the r9 leg
# (skipping the 9k boot).  The 9k arm's behavior without these env is
# byte-preserved.  The r9 marker contract mirrors the 9k arm's
# boundary-anchored shape with the expectations COMPUTED from
# build/x86_64/tiers/tier1-cmds.txt and the SKIP set extracted verbatim
# from the sweep's own SKIP lines (the committed file is the source of
# truth — the aarch64 r9 gate's rule, carried).
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
#   T1_R9_ISO         the composed r9 tier ISO — PRESENT runs the r9 leg
#                     after the 9k leg (the witness's both-halves run)
#   T1_LEG            "r9" runs ONLY the r9 leg (no 9k boot)
#   T1_R9_LOG         r9 serial capture   (default: $HARVEY/.build/tier-r9x64-serial.log)
#   T1_R9_RESULT      r9 result file      (default: $HARVEY/.build/tier-r9x64-result.txt)
#   T1_R9_BOOT_BUDGET r9 banner budget    (default: 120 KVM / 600 TCG)
#   T1_R9_SWEEP_BUDGET r9 sweep budget    (default: 600 KVM / 1500 TCG)
#
# Marker contract, 9k arm (asserted on the CR-normalized capture):
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
#
# Marker contract, r9 arm (the same boundary-anchored shape):
#   - the `r9 from the Internet` banner (the composed chain's boot
#     prints) is present (else FAIL no-banner);
#   - the expected OK set is COMPUTED from build/x86_64/tiers/
#     tier1-cmds.txt (driver-only exclusions: 9k/boot, stage/*,
#     cmd/paqfs:paqfs, cmd/cc; dir:target -> target; container ->
#     member) MINUS the SKIP-named members PLUS float-d01; the expected
#     SKIP set is extracted from tier1-sweep.rc's own `echo T1-SKIP`
#     lines — never a second hardcoded list;
#   - every OK member needs boundary-anchored `T1-OK m`; every SKIP
#     member needs boundary-anchored `T1-SKIP m`; the CONVERSE holds
#     too (an emitted SKIP outside the sweep's own declared set reds);
#   - zero T1-FAIL; zero case-insensitive `panic|trap:`; T1-DONE
#     present.
#   On any failure the marker-state digest plus the last 40 lines go to
#   stderr (06-10's CI step mirrors the digest into GITHUB_STEP_SUMMARY
#   — D-16's self-print convention: runner logs are auth-gated).
#
# Marker contract, services arm (15-02, USPACE-07 — asserted on the SAME
# 9k capture; the donor boot runs the services sweep after the tier-1
# sweep, both from the boot flow):
#   - the expected SVC-OK set is COMPUTED from the tier data (the
#     probe-subject entries verified present in
#     build/x86_64/tiers/tier2-services.txt — cmd/ndb is the resolver
#     pair's home, cs+dns ride its members) and the subject list the
#     committed services-sweep.rc actually probes;
#   - the expected SVC-SKIP set is extracted verbatim from the sweep's
#     own `echo SVC-SKIP' lines — never a second hardcoded list;
#   - every expected subject needs a boundary-anchored `SVC-OK m' OR a
#     declared `SVC-SKIP m'; the CONVERSE holds (an emitted SVC-SKIP
#     outside the sweep's declared set reds);
#   - zero SVC-FAIL; SVC-DONE present (the phase-B poll now waits for
#     SVC-DONE — the boot's LAST marker, after T1-DONE).
#
# Accel: /dev/kvm writable → -accel kvm -cpu host; else TCG (-accel tcg
# -cpu qemu64) with the larger budgets — probed EXACTLY ONCE per run and
# recorded in the result file.  Capture-before-start: the log is
# truncated, THEN qemu launches with -serial file: (no stale banner).
#
# 15-02: the phase build-tree lock — the harness boots the kernel the
# shared /amd64 tree produced (and 15-04's same-wave subset-build runs
# hold the SAME lock for their whole runs), so the 9k leg holds it from
# launch to classification (the 15-01 coupling contract; skipped for
# classify-only runs, which touch nothing shared).
#
# Boundary: amd64/9k + the x64 r9 leg.  aarch64 donor/r9 venues stay in
# build/aarch64/.

set -eu

HARVEY="${HARVEY:-$PWD}"
KERNEL="${T1_KERNEL:-$HARVEY/amd64/9k10t1.elf}"
LOG="${T1_LOG:-$HARVEY/.build/tier-9k-serial.log}"
RESULT="${T1_RESULT:-$HARVEY/.build/tier-9k-result.txt}"
CLASSIFY_ONLY="${T1_CLASSIFY_ONLY:-}"
R9_LOG="${T1_R9_LOG:-$HARVEY/.build/tier-r9x64-serial.log}"
R9_RESULT="${T1_R9_RESULT:-$HARVEY/.build/tier-r9x64-result.txt}"
R9_ISO="${T1_R9_ISO:-}"
LEG="${T1_LEG:-9k}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"

# 15-02: the phase build-tree lock (see the header note) — held from
# here to exit, EXCEPT classify-only runs (no qemu, no shared-tree
# reads).  Blocking is by design: same-wave /amd64 writers serialize.
CLASSIFY_ONLY="${T1_CLASSIFY_ONLY:-}"
if [ -z "$CLASSIFY_ONLY" ]; then
	command -v flock >/dev/null 2>&1 || err "flock not found — the amd64 build-tree lock needs util-linux flock"
	mkdir -p "$HARVEY/.build"
	exec 9>"$HARVEY/.build/amd64-tree.lock"
	flock 9 || err "cannot acquire the amd64 build-tree lock"
	echo "== amd64 build-tree lock held: $HARVEY/.build/amd64-tree.lock"
fi

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

# 15-02: the services-sweep expected SKIP set, extracted VERBATIM from
# the committed sweep's own `echo SVC-SKIP' lines (the r9-arm rule,
# carried; catches a stale embedded sweep diverging from the committed
# one).  The donor sweep declares its conditional SKIPs as literal
# `echo SVC-SKIP <name>' lines inside probe arms — this reads exactly
# those.
compute_svc_skip() {
	"$GREP" -oE '(^|[[:space:]])echo SVC-SKIP [A-Za-z0-9.-]+' "$HARVEY/build/x86_64/services-sweep.rc" \
		| awk '{print $NF}' | sort -u
}

# 15-02: the services-sweep expected OK set — COMPUTED from the tier
# data (the probe-subject entries verified present; never a second
# hardcoded membership): each subject names the tier entry it rides
# (cmd/ndb is the resolver pair's home — cs + dns are its probe
# subjects), factotum rides the TIER-1 line (cmd/auth/factotum:factotum
# — never a tier-2 member).  Grows with the sweep's probe set (the
# committed sweep is the probe record).
SVC_T2="$HARVEY/build/x86_64/tiers/tier2-services.txt"
SVC_T1="$HARVEY/build/x86_64/tiers/tier1-cmds.txt"
compute_svc_expected() {
	for e in cmd/mntgen cmd/ndb cmd/exportfs cmd/srv cmd/aux:listen; do
		"$GREP" -q "^$e[[:space:]#]" "$SVC_T2" || err "svc expectation: tier-2 data lacks the probe-subject entry $e"
	done
	echo "mntgen cs dns exportfs srv listen"
}

in_svcskip() {
	case " $(compute_svc_skip | tr '\n' ' ') " in
	*" $1 "*) return 0 ;;
	esac
	return 1
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
	_badsvcskip=""
	_ok=0
	_skip=0
	_skiplibtest=0
	_svcok=0
	_svcskip=0
	_nsvcfail=0
	for m in $(compute_expected); do
		if "$GREP" -qE 'T1-OK '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_ok=$((_ok + 1))
			continue
		fi
		if in_whitelist "$m" && "$GREP" -qE 'T1-SKIP '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_skip=$((_skip + 1))
			case "$m" in
			libtest-*) _skiplibtest=$((_skiplibtest + 1)) ;;
			esac
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

	# 15-02: the services-sweep contract on the same capture — the
	# computed OK set (boundary-anchored), the SKIP set both directions,
	# zero SVC-FAIL, SVC-DONE present
	for m in $(compute_svc_expected); do
		if "$GREP" -qE 'SVC-OK '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_svcok=$((_svcok + 1))
			continue
		fi
		if in_svcskip "$m" && "$GREP" -qE 'SVC-SKIP '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_svcskip=$((_svcskip + 1))
			continue
		fi
		_missing="$_missing svc:$m"
		_fails=1
	done
	for s in $("$GREP" -oE 'SVC-SKIP [A-Za-z0-9.-]+' "$_norm" | awk '{print $2}' | sort -u); do
		if ! in_svcskip "$s"; then
			_badsvcskip="$_badsvcskip $s"
			_fails=1
		fi
	done
	if "$GREP" -q 'SVC-FAIL' "$_norm"; then
		_nsvcfail=$("$GREP" -c 'SVC-FAIL' "$_norm" || true)
		_fails=1
	fi
	if "$GREP" -q 'SVC-DONE' "$_norm"; then
		:
	else
		_missing="$_missing svc:SVC-DONE"
		_fails=1
	fi

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
		[ -z "$_badsvcskip" ] || echo "   undeclared SVC-SKIP names:$_badsvcskip" >&2
		[ "$_nfail" = 0 ] || echo "   T1-FAIL lines: $_nfail" >&2
		[ "$_nsvcfail" = 0 ] || echo "   SVC-FAIL lines: $_nsvcfail" >&2
		[ -z "$_fault" ] || echo "   kernel fault lines present (panic|trap:)" >&2
		[ "$_done" = yes ] || echo "   T1-DONE absent (the sweep did not run to completion)" >&2
		echo "   marker-state digest:" >&2
		"$GREP" -oE 'T1-(OK|FAIL|SKIP) [A-Za-z0-9.-]+|T1-DONE|SVC-(OK|FAIL|SKIP) [A-Za-z0-9.-]+|SVC-DONE' "$_norm" >&2 || true
		echo "   last 40 lines of $_log:" >&2
		tail -40 "$_norm" >&2
		{
			echo "verdict=FAIL"
			echo "ok=$_ok"
			echo "skip=$_skip"
			echo "fail=$_nfail"
			echo "done=$_done"
			echo "svc_ok=$_svcok"
			echo "svc_skip=$_svcskip"
			echo "svc_fail=$_nsvcfail"
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
		echo "skip_venue=$((_skip - _skiplibtest))"
		echo "skip_libtest=$_skiplibtest"
		echo "fail=0"
		echo "done=$_done"
		echo "svc_ok=$_svcok"
		echo "svc_skip=$_svcskip"
		echo "svc_fail=0"
		echo "accel=$_accel"
		echo "kernel=$KERNEL"
		echo "log=$_log"
		echo "commit=$COMMIT"
		echo "date=$DATE"
	} > "$RESULT"
	echo "== T1-VENUE-PASS ok=$_ok skip=$((_skip - _skiplibtest))+$((_skiplibtest))libtest fail=0 done=yes svc=$_svcok/$_svcskip ok/skip fail=0 accel=$_accel commit=$COMMIT"
	echo "   ok markers (D-16 self-print — the capture is the authority, this is the runner-visible digest):"
	"$GREP" -oE 'T1-OK [A-Za-z0-9.-]+' "$_norm" | sort -u
	echo "   services ok markers (D-16 self-print):"
	"$GREP" -oE 'SVC-(OK|SKIP) [A-Za-z0-9.-]+' "$_norm" | sort -u
	echo "   result file: $RESULT"
	rm -f "$_norm"
	return 0
}

# --- the r9-x64 arm (14-08): computed expectations + its own classifier --

# The r9-venue expected SKIP set, extracted VERBATIM from the x64
# sweep's own `echo T1-SKIP` lines (the committed file is the source of
# truth — the aarch64 r9 gate's rule, carried; catches a stale baked
# sweep diverging from the committed one).
compute_r9_skip() {
	"$GREP" -oE '(^|[[:space:]])echo T1-SKIP [A-Za-z0-9.-]+' "$HARVEY/build/x86_64/tier1-sweep.rc" \
		| awk '{print $NF}' | sort -u
}

# The r9-venue expected OK set: the x64 tier data's members minus the
# driver-only exclusions minus the SKIP-named members PLUS the
# mandatory float canary — computed, never a second hardcoded list.
compute_expected_r9() {
	_skipset="$(compute_r9_skip | tr '\n' ' ')"
	awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/x86_64/tiers/tier1-cmds.txt" |
	while read -r e; do
		case "$e" in
		9k/boot|stage/*|cmd/paqfs:paqfs|cmd/cc) continue ;;
		esac
		e="${e#cmd/}"
		case "$e" in *:*) e="${e##*:}" ;; esac
		m="${e##*/}"
		case " $_skipset " in
		*" $m "*) continue ;;
		esac
		echo "$m"
	done
	echo "float-d01"
}

in_r9skip() {
	case " $(compute_r9_skip | tr '\n' ' ') " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# classify_log_r9 <log> <accel>: the r9 marker contract on the
# CR-normalized copy — banner, computed OK set (boundary-anchored),
# the SKIP set both ways, zero FAIL/panic, T1-DONE; digest on failure.
classify_log_r9() {
	_log=$1
	_accel=$2
	_norm=$(mktemp "${TMPDIR:-/tmp}/t1r9-norm.XXXXXX") || err "mktemp failed"
	tr -d '\r' < "$_log" > "$_norm" 2>/dev/null || true

	if [ ! -s "$_norm" ] || ! "$GREP" -q 'r9 from the Internet' "$_norm"; then
		echo "FAIL no-banner (r9)" >&2
		{
			echo "verdict=FAIL no-banner"
			echo "accel=$_accel"
			echo "iso=$R9_ISO"
			echo "log=$_log"
			echo "commit=$COMMIT"
			echo "date=$DATE"
		} > "$R9_RESULT"
		rm -f "$_norm"
		return 1
	fi

	_fails=0
	_missing=""
	_badskip=""
	_ok=0
	_skip=0
	for m in $(compute_expected_r9); do
		if "$GREP" -qE 'T1-OK '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_ok=$((_ok + 1))
			continue
		fi
		_missing="$_missing $m"
		_fails=1
	done
	for m in $(compute_r9_skip); do
		if "$GREP" -qE 'T1-SKIP '"$m"'([^A-Za-z0-9.-]|$)' "$_norm"; then
			_skip=$((_skip + 1))
			continue
		fi
		_missing="$_missing T1-SKIP:$m"
		_fails=1
	done

	# converse: every emitted T1-SKIP must be in the sweep's own declared
	# set (a stale or drifted baked sweep reds here)
	for s in $("$GREP" -oE 'T1-SKIP [A-Za-z0-9.-]+' "$_norm" | awk '{print $2}' | sort -u); do
		if ! in_r9skip "$s"; then
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
		echo "== T1-R9X64-FAIL" >&2
		[ -z "$_missing" ] || echo "   missing markers:$_missing" >&2
		[ -z "$_badskip" ] || echo "   undeclared T1-SKIP names:$_badskip" >&2
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
			echo "iso=$R9_ISO"
			echo "log=$_log"
			echo "commit=$COMMIT"
			echo "date=$DATE"
		} > "$R9_RESULT"
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
		echo "iso=$R9_ISO"
		echo "log=$_log"
		echo "commit=$COMMIT"
		echo "date=$DATE"
	} > "$R9_RESULT"
	echo "== T1-R9X64-PASS ok=$_ok skip=$_skip fail=0 done=yes accel=$_accel commit=$COMMIT"
	echo "   ok markers (D-16 self-print — the capture is the authority, this is the runner-visible digest):"
	"$GREP" -oE 'T1-OK [A-Za-z0-9.-]+' "$_norm" | sort -u
	echo "   result file: $R9_RESULT"
	rm -f "$_norm"
	return 0
}

# run_r9_leg: boot the composed tier ISO under qemu q35, wait banner →
# T1-DONE, classify.  The tier image's termrc (build/x86_64/tier-termrc
# staged as rc/bin/termrc) runs the sweep from the boot flow — the
# donor venue's k10t1.rc shape, no typed interaction; the serial file
# captures the sweep, and the % prompt follows T1-DONE.
run_r9_leg() {
	[ -n "$R9_ISO" ] || err "T1_R9_ISO unset — the r9 leg needs the composed tier ISO (r9's iso-builder over build/x86_64/out/bootfs-tier.paq; the boot-r9-tier1-x64 app automates it)"
	[ -f "$R9_ISO" ] || err "T1_R9_ISO target missing: $R9_ISO"
	mkdir -p "$(dirname "$R9_LOG")" "$(dirname "$R9_RESULT")"

	R9_ACCEL=kvm
	R9_ACCEL_ARGS="-accel kvm -cpu host"
	if [ -w /dev/kvm ]; then
		:
	else
		R9_ACCEL=tcg
		R9_ACCEL_ARGS="-accel tcg -cpu qemu64"
	fi
	R9_BUDGET="${T1_R9_BOOT_BUDGET:-}"
	if [ -z "$R9_BUDGET" ]; then
		if [ "$R9_ACCEL" = tcg ]; then R9_BUDGET=600; else R9_BUDGET=120; fi
	fi
	R9_SWEEP="${T1_R9_SWEEP_BUDGET:-}"
	if [ -z "$R9_SWEEP" ]; then
		if [ "$R9_ACCEL" = tcg ]; then R9_SWEEP=1500; else R9_SWEEP=600; fi
	fi

	: > "$R9_LOG"
	echo "== r9 leg: mode $R9_ACCEL (banner budget ${R9_BUDGET}s, sweep budget ${R9_SWEEP}s)"
	echo "== r9 leg: launching: $QEMU -M q35 -m 1024M $R9_ACCEL_ARGS -cdrom $R9_ISO -display none -no-reboot -serial file:$R9_LOG"
	# SC2086: ACCEL_ARGS is intentionally word-split (two fixed args).
	# shellcheck disable=SC2086
	"$QEMU" -M q35 -m 1024M $R9_ACCEL_ARGS -cdrom "$R9_ISO" -display none -no-reboot -serial "file:$R9_LOG" &
	R9_PID=$!

	elapsed=0
	found=1
	while [ "$elapsed" -lt "$R9_BUDGET" ]; do
		if ! kill -0 "$R9_PID" 2>/dev/null; then
			echo "== r9 leg: qemu exited before the banner (${elapsed}s) — classifying what was captured"
			break
		fi
		if "$GREP" -q 'r9 from the Internet' "$R9_LOG" 2>/dev/null; then
			found=0
			break
		fi
		sleep 5
		elapsed=$((elapsed + 5))
	done

	if [ "$found" -eq 0 ]; then
		echo "== r9 leg: banner captured at ${elapsed}s — sweeping (budget ${R9_SWEEP}s)"
		celapsed=0
		while [ "$celapsed" -lt "$R9_SWEEP" ]; do
			if "$GREP" -q 'T1-DONE' "$R9_LOG" 2>/dev/null; then
				echo "== r9 leg: T1-DONE observed at +${celapsed}s"
				break
			fi
			if "$GREP" -qF 'panic' "$R9_LOG" 2>/dev/null || \
			   "$GREP" -qF 'sys: trap' "$R9_LOG" 2>/dev/null || \
			   "$GREP" -qF 'T1-FAIL' "$R9_LOG" 2>/dev/null; then
				echo "== r9 leg: signature line observed at +${celapsed}s"
				break
			fi
			if ! kill -0 "$R9_PID" 2>/dev/null; then
				echo "== r9 leg: qemu exited at +${celapsed}s — classifying the final log"
				break
			fi
			sleep 5
			celapsed=$((celapsed + 5))
		done
	fi

	if [ -n "$R9_PID" ] && kill -0 "$R9_PID" 2>/dev/null; then
		kill "$R9_PID" 2>/dev/null || true
	fi
	wait "$R9_PID" 2>/dev/null || true
	sleep 2

	classify_log_r9 "$R9_LOG" "$R9_ACCEL"
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

# run_9k_leg: the 06-09 donor leg, body verbatim — boots the venue
# kernel, waits banner → T1-DONE, classifies.
run_9k_leg() {
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

	# Phase B: poll for SVC-DONE within the sweep budget — the boot's
	# LAST marker (15-02: the services sweep runs after the tier-1
	# sweep, so SVC-DONE implies T1-DONE landed; T1-DONE stays
	# independently asserted at classify time).  Early-break on the
	# poolpanic harness's signature set (the FAIL is then locked at
	# classify time), a classified SVC-FAIL, or if qemu dies.
	if [ "$found" -eq 0 ]; then
		echo "== banner captured at ${elapsed}s — sweeping (budget ${SWEEP_BUDGET}s)"
		celapsed=0
		while [ "$celapsed" -lt "$SWEEP_BUDGET" ]; do
			if "$GREP" -q 'SVC-DONE' "$LOG" 2>/dev/null; then
				echo "== SVC-DONE observed at +${celapsed}s"
				break
			fi
			if "$GREP" -qF 'bad magic' "$LOG" 2>/dev/null || \
			   "$GREP" -qF 'panic' "$LOG" 2>/dev/null || \
			   "$GREP" -qF 'suicide: sys: trap' "$LOG" 2>/dev/null || \
			   "$GREP" -qF 'SVC-FAIL' "$LOG" 2>/dev/null; then
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
}

# --- leg dispatch: T1_LEG selects (9k default | r9); T1_R9_ISO adds the
#     r9 leg after a green 9k leg (the witness's both-halves run).  The
#     exit status reflects every leg that ran.
RC_MAIN=0
if [ "$LEG" = "r9" ]; then
	run_r9_leg || RC_MAIN=$?
else
	run_9k_leg || RC_MAIN=$?
	if [ -n "$R9_ISO" ] && [ "$RC_MAIN" -eq 0 ]; then
		run_r9_leg || RC_MAIN=$?
	fi
fi
exit "$RC_MAIN"
