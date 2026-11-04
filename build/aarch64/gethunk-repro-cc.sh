#!/bin/sh
# gethunk-repro-cc.sh — timeout-gated regression harness for the cc frontend
# gethunk accumulate-when-contiguous fix (USPACE-01, phase 06 plan 01 task 1).
#
# The bug: cc/macbody's gethunk RESET `hunk = h; nhunk = nh;` on every call,
# so the while(nhunk < n) caller loops (dodefine, macdef's allocn growth, the
# expansion machinery) never terminate once n exceeds the largest single hunk
# (10L*NHUNK = 500000 bytes, sys/src/cmd/cc/cc.h:25) — a silent compile HANG
# on any single macro whose replacement text crosses the ceiling.
#
# PREREF (recorded pre-fix ref, Task 1 action step 1):
#   df4b1cb4ab5d7bc9f97bb7b4882933428336acda
# `archive` mode git-archives that ref's cc+6c+7c (plus 6l for the shared
# unixcompat.c mysbrk shim both compiler BUILDs compile, plus ld for
# ../ld/elf.h which 6l/l.h pulls in) and host-builds the PRISTINE 6c/7c with
# the in-tree BUILD scripts — the CI-durable teeth-proof that works from any
# later checkout.  `snapshot` mode instead copies the current hostbin pair
# (valid only while hostbin is still pre-fix).
#
#   sh build/aarch64/gethunk-repro-cc.sh snapshot   # capture pre-fix hostbin 6c/7c
#   sh build/aarch64/gethunk-repro-cc.sh archive    # build pristine 6c/7c from $PREREF
#   sh build/aarch64/gethunk-repro-cc.sh verify     # the gate (both directions)
#
# verify generates one C file holding a single macro whose replacement text
# exceeds 600KB, defined via `#define BIG (1,1,...,1)`, then a `#ifdef BIG`
# presence block, then runs `timeout 60 <bin> -FTVw bigmacro.c` for the
# pristine pair (assert the unbounded-loop signature: exit 124 = timeout
# kill on the hang, OR exit 1 with "out of memory" in the log = the loop
# burned sbrk to ENOMEM — the host-dependent fast terminus of the same
# loop; darwin's bounded sbrk arena reaches it well before the timeout,
# exactly like the 3.7MB donor-link incident's thunk-growth end-state) and
# the current hostbin pair (assert exit 0 + a non-empty object file — the
# fix).  Marker vocabulary: TEETH-OK / TEETH-FAIL / GREEN / RED <tool>,
# plus a TAP report (`ok`/`not ok` + `# tests/# pass/# fail`) for the TDD
# RED-evidence gate.  Exit 0 only when all four assertions hold; a pristine
# binary COMPILING (exit 0, or any error that is not the gethunk ENOMEM
# terminus) inside the timeout is a TEETH-FAIL — a gate without teeth
# certifies nothing.
#
# Input-shape notes (spike results, 2026-11-04):
# - The plan's sketched shape — a single >600KB string literal — cannot
#   reach gethunk at all: macdef routes alphabetic runs inside a string
#   through nextsym (identifier cap NSYMB=1500 → "symbol too large") and
#   the lexer caps string constants at STRINGSZ=200 ("string constant too
#   long").  The digit/comma replacement text has no alphabetic runs and no
#   string constant, so every byte flows through macdef's allocn growth
#   loop (the gethunk caller under test).
# - The plan's `char *p = BIG;` use line was dropped: a >600KB macro can
#   be DEFINED (hunk chain handles arbitrary sizes) but never EXPANDED —
#   macexpand writes into Io.b[BUFSIZ=16KB] with no output bound and the
#   expansion io layer's `short c` field truncates the length (observed:
#   "saw $end" syntax error at the use line on the FIXED compiler).  That
#   is a separate, pre-existing upstream limitation of the expansion path,
#   out of scope for USPACE-01 — the compile-hang landmine this gate
#   proves fires at DEFINE time (macdef's allocn loop), which the #define
#   line alone exercises.  The `#ifdef BIG` block keeps a real consumer
#   of the macro table entry so a corrupt define cannot pass silently.
#
# Never committed artifacts: everything lands under .build/gethunk-repro-cc/
# (gitignored scratch — `/.build/` in .gitignore).

set -eu

: "${PLAN9:?run inside the nix devshell — plan9port must be provisioned (PLAN9 unset)}"

HARVEY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$HARVEY_ROOT"
MODE="${1:?usage: gethunk-repro-cc.sh snapshot|archive|verify}"

PREREF=df4b1cb4ab5d7bc9f97bb7b4882933428336acda

# $PLAN9/bin LAST (BUILD_ON_UNIX discipline; bquote-repro.sh's shape).
P9LAST=$(echo "$PATH" | sed "s|:$PLAN9/bin||g; s|^$PLAN9/bin:||; s|^$PLAN9/bin$||")
PATH="$P9LAST:$PLAN9/bin"
# hostbin stripped from PATH entirely: the binaries under test are always
# addressed by absolute path, and 9l's autolib runs bare `nm` on host
# objects — with hostbin on PATH that resolves to Harvey's ken-format nm
# ("Can't read header" → silently broken autolib → undefined Binit/Bwrite/
# zaddr at link; nix/toolchain.sh's nm-shadow comment).  The devshell puts
# hostbin FIRST, so remove every hostbin element here — with a pure-sh
# loop, because hostbin's Plan 9-dialect sed/grep would otherwise win the
# lookup and reject the filter expressions.
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

_hb_os=$(uname -s | tr 'A-Z' 'a-z')
_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
# The "fixed" candidate pair lives in hostbin by default; the env override
# exists so the gate can be driven against any binary dir (CI matrix legs,
# RED-evidence capture against the pristine snapshot).
HOSTBIN="${GETHUNK_REPRO_HOSTBIN:-$HARVEY_ROOT/.build/hostbin-$_hb_os-$_hb_arch/bin}"

SCRATCH="$HARVEY_ROOT/.build/gethunk-repro-cc"
mkdir -p "$SCRATCH"

# timeout(1) from coreutils; gtimeout is the non-nix macOS spelling.
TIMEOUT=$(command -v timeout || command -v gtimeout || true)
[ -n "$TIMEOUT" ] || { echo "error: timeout(1) not found — run inside the nix devshell" >&2; exit 1; }

# The generated repro input: one #define whose replacement text exceeds 600KB
# (the 500000-byte single-hunk ceiling is crossed during macdef's allocn
# growth at DEFINE time), then a #ifdef presence block as a safe consumer
# (full expansion of a >16KB macro cannot flow through Io.b — see header).
gen_input() {
	GEN="$SCRATCH/input"
	rm -rf "$GEN"
	mkdir -p "$GEN"
	{
		printf '#define BIG (1'
		i=0
		while [ $i -lt 300000 ]; do
			printf ',1'
			i=$((i + 1))
		done
		printf ')\n\n#ifdef BIG\nint big_defined = 1;\n#endif\n'
	} > "$GEN/bigmacro.c"
}

case "$MODE" in

snapshot)
	# Copy the CURRENT hostbin 6c/7c — valid only while hostbin is pre-fix
	# (the task runs this BEFORE the toolchain rebuild).
	mkdir -p "$SCRATCH/pristine-bin"
	[ -x "$HOSTBIN/6c" ] && [ -x "$HOSTBIN/7c" ] || {
		echo "error: hostbin 6c/7c missing — run 'nix run .#toolchain' first" >&2
		exit 1
	}
	cp "$HOSTBIN/6c" "$HOSTBIN/7c" "$SCRATCH/pristine-bin/"
	echo "snapshot: pristine 6c/7c copied from $HOSTBIN"
	;;

archive)
	# The CI-durable teeth-proof: build the recorded pre-fix ref's cc+6c+7c
	# straight from git — the working tree stays untouched.
	SRC="$SCRATCH/archive-src"
	rm -rf "$SRC" "$SCRATCH/archive-bin"
	mkdir -p "$SRC" "$SCRATCH/archive-bin"
	git archive "$PREREF" sys/src/cmd/cc sys/src/cmd/6c sys/src/cmd/6l sys/src/cmd/7c sys/src/cmd/ld \
		| tar -x -C "$SRC"

	# 6c/BUILD links with 9l -static, which works with neither modern Apple
	# ld nor nix's glibc toolchain — the nix/toolchain.sh shim, replicated:
	# drop -static, delegate to the real 9l.
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
	export PATH

	# The in-tree BUILD scripts host-build with plan9port 9c/9l and `cp` the
	# result into $HARVEY_LINUX_BIN — point that at the scratch archive-bin.
	HARVEY_LINUX_BIN="$SCRATCH/archive-bin"
	export HARVEY_LINUX_BIN
	for t in 6c 7c; do
		echo "== [archive] host-build pristine $t from $PREREF"
		(cd "$SRC/sys/src/cmd/$t" && sh BUILD)
		[ -x "$SCRATCH/archive-bin/$t" ] || {
			echo "error: archive build of $t produced no binary" >&2
			exit 1
		}
	done
	echo "archive: pristine 6c/7c built from $PREREF into $SCRATCH/archive-bin"
	;;

verify)
	# Pristine pair: the archive build is preferred (CI-durable — works from
	# any later checkout); the snapshot pair is the fallback (and the only
	# option before the archive has ever been built).
	if [ -x "$SCRATCH/archive-bin/6c" ] && [ -x "$SCRATCH/archive-bin/7c" ]; then
		PRIS="$SCRATCH/archive-bin"
		echo "== verify: pristine pair from archive($PREREF)"
	elif [ -x "$SCRATCH/pristine-bin/6c" ] && [ -x "$SCRATCH/pristine-bin/7c" ]; then
		PRIS="$SCRATCH/pristine-bin"
		echo "== verify: pristine pair from snapshot"
	else
		echo "error: no pristine pair — run 'snapshot' (pre-rebuild) or 'archive' first" >&2
		exit 2
	fi
	[ -x "$HOSTBIN/6c" ] && [ -x "$HOSTBIN/7c" ] || {
		echo "error: hostbin 6c/7c missing — run 'nix run .#toolchain' first" >&2
		exit 2
	}
	gen_input
	GEN="$SCRATCH/input"

	fails=0
	t=1
	for tool in 6c 7c; do
		LOG="$SCRATCH/verify-pristine-$tool.log"
		set +e
		(cd "$GEN" && "$TIMEOUT" 60 "$PRIS/$tool" -FTVw bigmacro.c) > "$LOG" 2>&1
		RC=$?
		set -e
		# The unbounded gethunk loop ends two ways: a timeout kill (124) on
		# hosts where sbrk keeps growing, or "out of memory" (rc=1) once the
		# loop burns sbrk to ENOMEM — darwin's bounded sbrk arena reaches the
		# second terminus fast.  Both prove the teeth; only a CLEAN compile
		# (or an unrelated error) is a TEETH-FAIL.
		if [ $RC -eq 124 ]; then
			echo "TEETH-OK $tool (timeout hang)"
			echo "ok $t - pristine $tool hang signature (teeth)"
		elif [ $RC -eq 1 ] && grep -q 'out of memory' "$LOG"; then
			echo "TEETH-OK $tool (gethunk ENOMEM terminus)"
			echo "ok $t - pristine $tool hang signature (teeth)"
		else
			echo "TEETH-FAIL $tool (rc=$RC, wanted 124 or gethunk ENOMEM; log: $LOG)"
			echo "not ok $t - pristine $tool hang signature (teeth)"
			fails=$((fails + 1))
		fi
		t=$((t + 1))
	done
	for tool in 6c 7c; do
		LOG="$SCRATCH/verify-fixed-$tool.log"
		rm -f "$GEN/bigmacro.${tool%c}"
		set +e
		(cd "$GEN" && "$TIMEOUT" 60 "$HOSTBIN/$tool" -FTVw bigmacro.c) > "$LOG" 2>&1
		RC=$?
		set -e
		if [ $RC -eq 0 ] && [ -s "$GEN/bigmacro.${tool%c}" ]; then
			echo "GREEN $tool"
			echo "ok $t - fixed $tool compiles within 60s"
		else
			echo "RED $tool (rc=$RC, object bigmacro.${tool%c} $([ -s "$GEN/bigmacro.${tool%c}" ] && echo present || echo missing); log: $LOG)"
			echo "not ok $t - fixed $tool compiles within 60s"
			fails=$((fails + 1))
		fi
		t=$((t + 1))
	done
	echo "# tests 4"
	echo "# pass $((4 - fails))"
	echo "# fail $fails"
	[ $fails -eq 0 ]
	;;

*)
	echo "usage: gethunk-repro-cc.sh snapshot|archive|verify" >&2
	exit 2
	;;
esac
