#!/bin/sh
# gethunk-repro-6l.sh — timeout-gated regression harness for the 6l linker
# gethunk accumulate-when-contiguous fix (USPACE-01, phase 06 plan 01 task 2).
#
# The bug: 6l/obj.c's gethunk RESET `hunk = h; nhunk = nh;` on every call,
# so 6l/unixcompat.c's malloc `while(nhunk < n) gethunk();` never terminates
# once n exceeds the largest single hunk (25L*NHUNK = 2500000 bytes,
# sys/src/cmd/6l/l.h:121) — a silent hang-class link failure on any single
# allocation larger than the ceiling.
#
# PREREF (recorded pre-6l-fix ref, Task 2 action step 1 — the cc/macbody fix
# commit; it predates the 6l edit and does not touch 6l):
#   2e3b37027efe1ee8ae0a7dc8c6fabbead1500a0a
#
# A4 input-shape spike VERDICT (2026-11-04, lima linux-aarch64 guest,
# pristine guest 6l): the plan's primary shape — a >=4MB initialized C array
# — has NO teeth: 6l streams its output data image through a small rolling
# buffer (asm.c datblk), so the array's 4MB never becomes one big linker
# allocation (pristine link completed, rc=0).  The plan's fallback shape — a
# single >2.5MB string literal — cannot be produced: cc's lexer caps string
# constants at yylval.sval ("string constant too long") and #define-side
# strings cap at NSYMB.  The shape that DOES route one >2.5MB allocation
# through gethunk is a giant ARCHIVE SYMBOL TABLE: objfile() "bangs the
# whole symbol file into memory" with one malloc(cnt) (6l/obj.c:520), so a
# .a whose __.SYMDEF section exceeds 2.5MB hangs the pristine 6l.  The gate
# therefore links a trivial main against a generated 250K-function archive
# (__.SYMDEF ≈ 4.5MB): pristine 6l observed -> "??none??: out of memory"
# abort (the unbounded-loop ENOMEM terminus), no output binary.
#
# Venue note (darwin hosts): macOS sbrk caps at exactly 4096KB per process
# (measured), so NEITHER direction of a >2.5MB-malloc gate can run natively
# on darwin — pre-fix the loop ENOMEMs at 4MB (fine for teeth), but the
# FIXED linker needs ~5MB of arena to accumulate past the 2.5MB ceiling, so
# GREEN is impossible there too.  The gate therefore runs on linux: natively
# when uname=Linux, in the lima guest (linux-aarch64) on darwin — the same
# platform split as subset-build.sh/vm-run.sh, minus the mount namespace
# (the link needs only committed amd64/lib/*.a via -L, no /sys layout).
#
#   sh build/aarch64/gethunk-repro-6l.sh snapshot   # capture pre-fix hostbin 6c/6l
#   sh build/aarch64/gethunk-repro-6l.sh archive    # build pristine 6c/6l from $PREREF
#   sh build/aarch64/gethunk-repro-6l.sh verify     # the gate (both directions)
#
# Modes build TWO pairs from source with the in-tree BUILD scripts (plan9port
# 9c/9l): the pristine pair from `git archive $PREREF` (archive-bin/) and the
# fixed pair from the CURRENT WORKING TREE (fixed-bin/) — building the fixed
# pair from the tree instead of trusting hostbin removes all hostbin
# staleness from the gate (the real hostbin is separately gated by Task 2's
# amd64-safety nix run .#toolchain/.#build leg).  snapshot mode copies the
# run-host's hostbin pair into pristine-bin/ as a fallback teeth source.
#
# verify generates the 250K-function archive + trivial main with the FIXED
# tools (input generation is not under test), then runs `timeout 120
# <6l-under-test> -o spike.out symain.6 symbig.a`: pristine must hit the
# unbounded-loop signature (exit 124 = timeout kill, OR "out of memory" in
# the log with no output binary = the ENOMEM terminus) and fixed must exit 0
# with a non-empty output.  Marker vocabulary: TEETH-OK / TEETH-FAIL /
# GREEN / RED 6l, plus a TAP report for the TDD RED-evidence gate.  Exit 0
# only when both assertions hold.
#
# GETHUNK_REPRO_HOSTBIN overrides the hostbin dir used by snapshot mode
# (evidence capture / CI matrix legs).
#
# Never committed artifacts: everything lands under .build/gethunk-repro-6l/
# (gitignored scratch — `/.build/` in .gitignore; guest side uses the
# guest-local .build/, which vm-run's rsync never crosses).

set -eu

: "${PLAN9:?run inside the nix devshell — plan9port must be provisioned (PLAN9 unset)}"

HARVEY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$HARVEY_ROOT"

PREREF=2e3b37027efe1ee8ae0a7dc8c6fabbead1500a0a

VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"

# Resolve a host grep once (D-02): the VM-listing grep in run_darwin
# needs -q/-x, which plan9 grep lacks — but a hardcoded /usr/bin/grep
# breaks on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || { echo "error: no host grep found" >&2; exit 1; }

usage() {
	echo "usage: gethunk-repro-6l.sh snapshot|archive|verify" >&2
	echo "       (internal: --guest snapshot|archive|verify)" >&2
	exit 2
}

MODE="${1:-}"
[ -n "$MODE" ] || usage

# ---------------------------------------------------------------------------
# linux-side implementation (run natively on linux, or in the lima guest)
# ---------------------------------------------------------------------------

run_linux() {
	mode="$1"

	# $PLAN9/bin LAST (BUILD_ON_UNIX discipline); hostbin stripped with a
	# pure-sh loop — 9l's autolib runs bare `nm` on host objects and
	# Harvey's ken-format hostbin nm breaks it (nix/toolchain.sh comment),
	# and hostbin's Plan 9-dialect sed/grep must not win lookups either.
	P9LAST=$(echo "$PATH" | sed "s|:$PLAN9/bin||g; s|^$PLAN9/bin:||; s|^$PLAN9/bin$||")
	PATH="$P9LAST:$PLAN9/bin"
	NP=""
	OLDIFS=$IFS
	IFS=:
	for p in $PATH; do
		case "$p" in
			*/.build/hostbin-*/bin) ;;
			*) NP="${NP:+$NP:}$p" ;;
		esac
	done
	IFS=$OLDIFS
	PATH="$NP"
	export PATH

	_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
	HOSTBIN="${GETHUNK_REPRO_HOSTBIN:-$HARVEY_ROOT/.build/hostbin-linux-$_hb_arch/bin}"

	SCRATCH="$HARVEY_ROOT/.build/gethunk-repro-6l"
	mkdir -p "$SCRATCH"

	TIMEOUT=$(command -v timeout || true)
	[ -n "$TIMEOUT" ] || { echo "error: timeout(1) not found — run inside the nix devshell" >&2; exit 1; }

	# Build 6c+6l from the source tree at $1 into the bin dir $2, using the
	# in-tree BUILD scripts verbatim (9l -static shim per nix/toolchain.sh).
	build_pair() {
		srcd="$1"
		outd="$2"
		mkdir -p "$outd"
		SHIMD="$SCRATCH/shim"
		rm -rf "$SHIMD"
		mkdir -p "$SHIMD"
		cat > "$SHIMD/9l" <<'SHIM'
#!/usr/bin/env bash
args=()
for a in "$@"; do
  [ "$a" = "-static" ] || args+=("$a")
done
exec "${PLAN9:?}/bin/9l" "${args[@]}"
SHIM
		chmod +x "$SHIMD/9l"
		PATH="$SHIMD:$PATH"
		HARVEY_LINUX_BIN="$outd"
		export PATH HARVEY_LINUX_BIN
		for t in 6c 6l; do
			echo "== build $t from $srcd -> $outd"
			(cd "$srcd/sys/src/cmd/$t" && sh BUILD)
			[ -x "$outd/$t" ] || {
				echo "error: build of $t from $srcd produced no binary" >&2
				exit 1
			}
		done
	}

	# The gate input: a trivial main referencing f000000, and a 250K-function
	# archive whose __.SYMDEF section (~4.5MB) exceeds the 2.5MB single-hunk
	# ceiling — the archive load's whole-symtab bang-malloc (6l/obj.c:520)
	# is the gethunk caller under test.  Generated with the FIXED tools.
	gen_input() {
		GEN="$SCRATCH/input"
		mkdir -p "$GEN"
		# the link's entry point comes from libc — u.h/libc.h's #pragma lib
		# makes 6l search it (-L names the committed amd64/lib)
		printf '#include <u.h>\n#include <libc.h>\nextern int f000000(void);\nvoid main(void){ f000000(); }\n' > "$GEN/symain.c"
		(cd "$GEN" && "$FIXBIN/6c" -FTVw -I"$HARVEY_ROOT/amd64/include" -I"$HARVEY_ROOT/sys/include" -o symain.6 symain.c)
		if [ ! -f "$GEN/symbig.a" ]; then
			echo "== generating 250K-function archive (one-off input build)"
			i=0
			{
				while [ $i -lt 250000 ]; do
					printf 'int f%06d(void){return 1;}\n' $i
					i=$((i + 1))
				done
			} > "$GEN/symbig.c"
			(cd "$GEN" && "$FIXBIN/6c" -FTVw -I"$HARVEY_ROOT/amd64/include" -I"$HARVEY_ROOT/sys/include" -o symbig.6 symbig.c)
			rm -f "$GEN/symbig.a"
			[ -x "$HOSTBIN/ar" ] || { echo "error: $HOSTBIN/ar missing — run the toolchain build first" >&2; exit 1; }
			(cd "$GEN" && "$HOSTBIN/ar" rv symbig.a symbig.6 >/dev/null)
			[ -s "$GEN/symbig.a" ] || { echo "error: archive generation failed" >&2; exit 1; }
		fi
		GEN="$SCRATCH/input"
	}

	case "$mode" in
	snapshot)
		mkdir -p "$SCRATCH/pristine-bin"
		[ -x "$HOSTBIN/6c" ] && [ -x "$HOSTBIN/6l" ] || {
			echo "error: hostbin 6c/6l missing ($HOSTBIN)" >&2
			exit 1
		}
		cp "$HOSTBIN/6c" "$HOSTBIN/6l" "$SCRATCH/pristine-bin/"
		echo "snapshot: pristine 6c/6l copied from $HOSTBIN"
		;;
	archive)
		# git archive needs .git — extract when present (native linux leg);
		# the darwin driver pre-extracts host-side and rsyncs the tree in.
		SRC="$SCRATCH/archive-src"
		if [ -d .git ]; then
			rm -rf "$SRC"
			mkdir -p "$SRC"
			git archive "$PREREF" sys/src/cmd/cc sys/src/cmd/6c sys/src/cmd/6l sys/src/cmd/ld \
				| tar -x -C "$SRC"
		fi
		[ -d "$SRC/sys/src/cmd/6l" ] || {
			echo "error: $SRC missing — run 'archive' (host extracts $PREREF via git archive first)" >&2
			exit 1
		}
		build_pair "$SRC" "$SCRATCH/archive-bin"
		echo "archive: pristine 6c/6l built from $PREREF into $SCRATCH/archive-bin"
		;;
	verify)
		# pristine pair: archive build preferred (CI-durable), snapshot fallback
		if [ -x "$SCRATCH/archive-bin/6l" ]; then
			PRIS="$SCRATCH/archive-bin"
			echo "== verify: pristine 6l from archive($PREREF)"
		elif [ -x "$SCRATCH/pristine-bin/6l" ]; then
			PRIS="$SCRATCH/pristine-bin"
			echo "== verify: pristine 6l from snapshot"
		else
			echo "error: no pristine 6l — run 'archive' (or 'snapshot') first" >&2
			exit 2
		fi
		# fixed pair: built fresh from the working tree every run — the gate
		# never trusts hostbin staleness.
		if [ ! -x "$SCRATCH/fixed-bin/6l" ] || [ "$HARVEY_ROOT/sys/src/cmd/6l/obj.c" -nt "$SCRATCH/fixed-bin/6l" ]; then
			build_pair "$HARVEY_ROOT" "$SCRATCH/fixed-bin"
		fi
		FIXBIN="$SCRATCH/fixed-bin"
		gen_input
		GEN="$SCRATCH/input"

		fails=0
		t=1
		LOG="$SCRATCH/verify-pristine-6l.log"
		rm -f "$GEN/spike-pristine.out"
		set +e
		(cd "$GEN" && "$TIMEOUT" 120 "$PRIS/6l" -L "$HARVEY_ROOT/amd64/lib" -o spike-pristine.out symain.6 symbig.a) > "$LOG" 2>&1
		RC=$?
		set -e
		# Unbounded gethunk loop termini: timeout kill (124) on hosts with
		# deep sbrk, or "out of memory" (the loop burned sbrk to ENOMEM) —
		# both prove the teeth; a CLEAN link (exit 0 + output) is TEETH-FAIL.
		if [ $RC -eq 124 ]; then
			echo "TEETH-OK 6l (timeout hang)"
			echo "ok $t - pristine 6l hang signature (teeth)"
		elif grep -q 'out of memory' "$LOG" && [ ! -e "$GEN/spike-pristine.out" ]; then
			echo "TEETH-OK 6l (gethunk ENOMEM terminus)"
			echo "ok $t - pristine 6l hang signature (teeth)"
		else
			echo "TEETH-FAIL 6l (rc=$RC, wanted 124 or gethunk ENOMEM; log: $LOG)"
			echo "not ok $t - pristine 6l hang signature (teeth)"
			fails=$((fails + 1))
		fi
		t=$((t + 1))
		LOG="$SCRATCH/verify-fixed-6l.log"
		rm -f "$GEN/spike-fixed.out"
		set +e
		(cd "$GEN" && "$TIMEOUT" 120 "$FIXBIN/6l" -L "$HARVEY_ROOT/amd64/lib" -o spike-fixed.out symain.6 symbig.a) > "$LOG" 2>&1
		RC=$?
		set -e
		if [ $RC -eq 0 ] && [ -s "$GEN/spike-fixed.out" ]; then
			echo "GREEN 6l"
			echo "ok $t - fixed 6l links 4MB-symtab archive within 120s"
		else
			echo "RED 6l (rc=$RC, output $([ -s "$GEN/spike-fixed.out" ] && echo present || echo missing); log: $LOG)"
			echo "not ok $t - fixed 6l links 4MB-symtab archive within 120s"
			# Print the failing link's own tail — the RED line alone is
			# undiagnosable on a host the reporter can't log in to.
			echo "--- verify-fixed-6l.log (tail 30):"
			tail -30 "$LOG"
			echo "---"
			fails=$((fails + 1))
		fi
		t=$((t + 1))
		echo "# tests 2"
		echo "# pass $((2 - fails))"
		echo "# fail $fails"
		[ $fails -eq 0 ]
		;;
	*)
		usage
		;;
	esac
}

# ---------------------------------------------------------------------------
# darwin driver: everything above runs in the lima linux-aarch64 guest
# (macOS sbrk's 4096KB arena cannot host a >2.5MB-malloc gate — see header).
# ---------------------------------------------------------------------------

run_darwin() {
	mode="$1"
	command -v limactl >/dev/null 2>&1 || {
		echo "error: limactl not found — run inside the nix devshell" >&2
		exit 1
	}
	if ! limactl list -q 2>/dev/null | "$GREP" -qx "$VM"; then
		echo "error: lima VM '$VM' does not exist" >&2
		exit 1
	fi
	status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
	if [ "$status" != "Running" ]; then
		limactl start "$VM"
	fi

	SSH_CFG="$HOME/.lima/$VM/ssh.config"
	GUEST="lima-$VM"
	RSYNC_RSH="ssh -F $SSH_CFG"
	GSCRATCH="$GUEST_DIR/.build/gethunk-repro-6l"

	# Every guest leg needs the current tree (this script itself lives in
	# it): push first (vm-run.sh's rsync shape), then ensure the guest
	# toolchain (sentinels 7c + ar — the generator side needs iar for the
	# archive's __.SYMDEF).
	echo "== pushing checkout to guest ~/$GUEST_DIR"
	rsync -a --delete -e "$RSYNC_RSH" \
		--exclude .git --exclude .build --exclude .planning --exclude graphify-out \
		--exclude 'result*' --exclude '9legacy.iso*' --exclude '*.tgz' --exclude 'build/harness/target' \
		"$HARVEY_ROOT/" "$GUEST:$GUEST_DIR/"
	GHB="$GUEST_DIR/.build/hostbin-linux-aarch64/bin"
	ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && if [ ! -x \"$GHB/7c\" ] || [ ! -x \"$GHB/ar\" ]; then nix run .#setup && nix run .#toolchain; fi"

	case "$mode" in
	snapshot)
		ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c sh build/aarch64/gethunk-repro-6l.sh --guest snapshot"
		;;
	archive)
		# git archive needs .git — extract on the host, push the pristine
		# tree, build guest-side.
		SRC="$HARVEY_ROOT/.build/gethunk-repro-6l/archive-src"
		rm -rf "$SRC"
		mkdir -p "$SRC"
		git archive "$PREREF" sys/src/cmd/cc sys/src/cmd/6c sys/src/cmd/6l sys/src/cmd/ld \
			| tar -x -C "$SRC"
		rsync -a --delete -e "$RSYNC_RSH" "$SRC/" "$GUEST:$GSCRATCH/archive-src/"
		ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c sh build/aarch64/gethunk-repro-6l.sh --guest archive"
		;;
	verify)
		ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c sh build/aarch64/gethunk-repro-6l.sh --guest verify"
		;;
	*)
		usage
		;;
	esac
}

case "$MODE" in
--guest)
	shift
	run_linux "${1:-}"
	;;
snapshot|archive|verify)
	if [ "$(uname -s)" = "Linux" ]; then
		run_linux "$MODE"
	else
		run_darwin "$MODE"
	fi
	;;
*)
	usage
	;;
esac
