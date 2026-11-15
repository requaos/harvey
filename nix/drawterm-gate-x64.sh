# nix/drawterm-gate-x64.sh — the -G interop gate as a flake app
# (19-08, DESK-06's CI-able proof + CPU-04's serial evidence + DESK-04's
# live encrypted proof per D-15 — the gate IS the probe): the SAME
# composed pipeline as nix/smoke-r9-auth-x64.sh re-keyed onto the §15
# cpu image (19-07's bootfs-cpu.paq) and the TWO-subtree expect gate
# build/x86_64/drawterm-gate.expect:
#
#   1. userland build — stage-build.sh + subset-build.sh (the auth
#      gate's step 1 verbatim; the §15 bake consumes the same tier
#      inputs incl. cmd/cpu, cmd/aux:listen, cmd/sed).  Linux-native
#      only.  R9_SKIP_BUILD=1 is the iteration hatch, NEVER the
#      default; the GATE runs the default.
#   2. bake — mkimage.sh (ALL contracts; §15 bakes LAST, so
#      out/auth-creds.txt is the §15 pair — the 19-08 parse contract)
#      with the output tee'd to out/drawterm-gate-bake.log; post-bake
#      asserts: bootfs-cpu.paq non-empty, the §15 pairing line, and
#      the creds copy present with both line shapes.
#   3. creds read — out/auth-creds.txt parsed LOUDLY (user= then
#      password=, CR/LF stripped, non-empty or an error NAMING THE
#      PATH — the empty-creds abort fires BEFORE any compose or
#      spawn; the flagged DESK-06/empty edge), exported as
#      R9_DEMO_USER/R9_DEMO_PW (the expect's -O spec + feedstage).
#   4. compose — r9's iso-builder WITH the cpu append parameter
#      (19-01's seam: --append=init=/amd64/init -c; boot(8)'s execinit
#      honors it, init -c runs the real cpurc) over the pinned
#      kernel-x64 + bootfs-cpu.paq as /boot/bootfs.paq.
#   5. the gate — drawterm-gate.expect spawns qemu (the §15 image
#      under the emitter's slirp argv — the D-04 hostfwd pair
#      17010/5670 rides the pinned TOML data) AND drawterm -G -O on a
#      pty (DRAWTERM_BIN: the 19-06 package binary), drives the
#      password feedstage through the p9any -> p9sk1 exchange, and
#      asserts the encrypted session's markers (see the expect
#      header).  Markers are the ONLY proof.
#
# Venue (D-14, user override): the REQUIRED green witness is LOCAL
# KVM, green twice; hosted CI runs this gate best-effort only.  The
# accel discipline is the auth driver's verbatim (flag > env >
# default; NO silent downgrade — a KVM-less venue fails loudly unless
# TCG was selected explicitly via R9_ACCEL=tcg).
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                      path (the flake app exports it).
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY.
#   R9_NETDEV_EMITTER REQUIRED — r9's netdev-args emitter bin (the
#                      slirp argv with the D-04 hostfwd pair comes
#                      ONLY from its output, captured once and
#                      exported as R9_NETDEV_ARGV).
#   DRAWTERM_BIN      REQUIRED — the 19-06 drawterm package binary
#                      (the flake app exports the package path; the
#                      expect spawns it on a pty).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; not the gate).
#   R9_DT_LOG         default $HARVEY/build/x86_64/out/drawterm-gate.log
#                      (gitignored out/; the twice-green runs set
#                      per-run paths and retain BOTH captures in the
#                      phase dir's evidence/).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                      downgrade (the Phase-13 discipline).
#   R9_CPU            override the cpu model (default: host under kvm,
#                      qemu64 under tcg).
#   KERNDATE          pinned-build timestamp override; derived from
#                      the HARVEY checkout's git log otherwise.
#
# Hygiene: the capture is rm -f'd BEFORE launch; the expect driver
# kills BOTH process groups (qemu's and drawterm's) on every exit
# path; THIS script's EXIT trap sweeps any survivor via bracket-fixed
# pkills keyed on this run's UNIQUE tags — qemu's -name R9_RUN_TAG and
# drawterm's argv[0] R9_DT_TAG (the expect spawns drawterm via bash's
# `exec -a' so the tag rides argv[0]; drawterm rejects extra argv
# operands).  The r9x64dtgate- prefix is this gate's OWN (the
# sibling-gate no-cross-kill rule), and the argv[0]-keyed drawterm
# sweep can never kill a foreign drawterm session (a dev's
# `nix run .#drawterm' has a normal argv) — the second-subtree hazard
# the 19-PATTERNS warning names.
#
# usage: nix run .#drawterm-gate-x64   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0: the kernel-package + builder contract (the auth gate's pin surface verbatim)

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#drawterm-gate-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#drawterm-gate-x64), which exports r9's iso-builder script path"
[ -f "$R9_ISO_BUILDER" ] && [ -x "$R9_ISO_BUILDER" ] \
	|| err "R9_ISO_BUILDER $R9_ISO_BUILDER: not an executable file (want <pkg>/bin/r9-iso-builder — a directory here means the app exported the package root, or the pin predates r9's iso-builder export)"

[ -n "${R9_NETDEV_EMITTER:-}" ] || err "R9_NETDEV_EMITTER unset — run via the flake app (nix run .#drawterm-gate-x64), which exports r9's netdev-args emitter path (a pin predating the 16-04 advance lacks the export)"
[ -f "$R9_NETDEV_EMITTER" ] && [ -x "$R9_NETDEV_EMITTER" ] \
	|| err "R9_NETDEV_EMITTER $R9_NETDEV_EMITTER: not an executable file (want <pkg>/bin/r9-netdev-args)"

[ -n "${DRAWTERM_BIN:-}" ] || err "DRAWTERM_BIN unset — run via the flake app (nix run .#drawterm-gate-x64), which exports the 19-06 drawterm package binary"
[ -f "$DRAWTERM_BIN" ] && [ -x "$DRAWTERM_BIN" ] \
	|| err "DRAWTERM_BIN $DRAWTERM_BIN: not an executable file (want the drawterm package's bin/drawterm)"

# --- step 0b: accel selection (no silent downgrade; KVM is the
#     required venue per D-14 — TCG is the explicit best-effort leg) --

R9_ACCEL="${R9_ACCEL:-kvm}"
case "$R9_ACCEL" in
	kvm)
		[ -e /dev/kvm ] || err "/dev/kvm absent and R9_ACCEL=$R9_ACCEL — no silent downgrade: set R9_ACCEL=tcg explicitly for the TCG fallback (the Phase-13 discipline; KVM is this gate's required venue per D-14)"
		R9_CPU="${R9_CPU:-host}"
		;;
	tcg)
		R9_CPU="${R9_CPU:-qemu64}"
		;;
	*) err "R9_ACCEL=$R9_ACCEL: want kvm|tcg" ;;
esac

# --- step 0c: the netdev argv — the emitter's slirp tokens (16-06) -------

# The D-04 hostfwd pair (host 17010 -> guest 17010, host 5670 ->
# guest 567) rides the pinned TOML data; the drawterm session dials
# exactly this pair.  Resolved ONCE here, before any build spend, so
# an emitter failure is a named contract error — exported as
# R9_NETDEV_ARGV for the expect driver to split.

NETDEV_ARGV=$("$R9_NETDEV_EMITTER" --mode slirp) \
	|| err "the netdev emitter failed for mode slirp (its diagnostics are above; the argv comes only from the pinned r9 TOML — D-05)"
[ -n "$NETDEV_ARGV" ] || err "the netdev emitter printed no netdev argv for mode slirp"
export R9_NETDEV_ARGV="$NETDEV_ARGV"

echo "== r9 kernel package: $R9_KERNEL_X64_PKG"
echo "   kernel:         $R9_KERNEL"
echo "   iso-builder:    $R9_ISO_BUILDER"
echo "   netdev emitter: $R9_NETDEV_EMITTER"
echo "   drawterm:       $DRAWTERM_BIN"
echo "   netdev argv (slirp): $NETDEV_ARGV"
echo "   dial contract:  cpu=127.0.0.1 auth=tcp!127.0.0.1!5670 (the committed hostfwd pair's loopback side — the expect's -O spec; never widened)"
echo "   shape:          q35 accel=$R9_ACCEL cpu=$R9_CPU"

# --- provenance (KERNDATE; the boot-r9-x64.sh discipline) --------------

if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the amd64 userland (the tier build + the cpu suite) -------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/5a: stage the mkimage inputs (build/x86_64/stage-build.sh)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/5: amd64 tier build (build/x86_64/subset-build.sh — the §15 bake's inputs incl. cmd/cpu + aux/listen + sed)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake (ALL contracts; §15 last, so out/auth-creds.txt is
#     the §15 pair) + post-bake asserts over the bake log ---------------

OUTD="$HARVEY/build/x86_64/out"
BAKE_LOG="$OUTD/drawterm-gate-bake.log"
echo "== step 2/5: bake (build/x86_64/mkimage.sh — §15 composes the cpu image; log tee'd to $BAKE_LOG)"
mkdir -p "$OUTD"
rm -f "$BAKE_LOG"
sh "$HARVEY/build/x86_64/mkimage.sh" 2>&1 | tee "$BAKE_LOG" || err "bootfs bake failed (the bake log is at $BAKE_LOG)"

CPU_PAQ="$OUTD/bootfs-cpu.paq"
[ -s "$CPU_PAQ" ] || err "$CPU_PAQ missing/empty after the bake (mkimage's §15 cpu section)"
grep -q 'bootfs-cpu.paq' "$BAKE_LOG" \
	|| err "the bake log names no bootfs-cpu.paq PASS line (the §15 bake did not complete its cpu contract — see $BAKE_LOG)"
grep -q 'cpu pairing verified' "$BAKE_LOG" \
	|| err "the bake log carries no §15 pairing line (cpu pairing verified — see $BAKE_LOG)"
echo "== post-bake asserts ok: bootfs-cpu.paq present, the §15 pairing line in the bake log"

# --- step 3: the creds read (D-12; BEFORE any compose or spawn) --------
# §15's host-side copy is the SURVIVING out/auth-creds.txt (§15 bakes
# after §14): exactly two lines, user= then password= (the 19-07 emit
# contract).  The parse is loud on every failure shape — a missing or
# empty credential aborts HERE, naming the path, never a silent skip
# and never a half-spawned venue (the flagged DESK-06/empty edge).
R9_CREDS_FILE="$OUTD/auth-creds.txt"
[ -s "$R9_CREDS_FILE" ] || err "$R9_CREDS_FILE missing/empty after the bake (mkimage 15h's host-side creds copy — the D-12 parse contract; the gate cannot measure without it)"
grep -q '^user=' "$R9_CREDS_FILE" || err "$R9_CREDS_FILE: no user= line (the 19-08 parse contract)"
grep -q '^password=' "$R9_CREDS_FILE" || err "$R9_CREDS_FILE: no password= line (the 19-08 parse contract)"
R9_DEMO_USER=$(sed -n 's/^user=//p' "$R9_CREDS_FILE" | tr -d '\r\n')
R9_DEMO_PW=$(sed -n 's/^password=//p' "$R9_CREDS_FILE" | tr -d '\r\n')
[ -n "$R9_DEMO_USER" ] || err "$R9_CREDS_FILE: the user= line parsed empty (empty creds — aborting before any spawn, naming the path)"
[ -n "$R9_DEMO_PW" ] || err "$R9_CREDS_FILE: the password= line parsed empty (empty creds — aborting before any spawn, naming the path)"
export R9_DEMO_USER R9_DEMO_PW R9_CREDS_FILE
echo "== step 3/5: creds read ok (user=$R9_DEMO_USER; the password is never printed)"

# --- step 4: compose the ISO WITH the cpu append (19-01's seam) --------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/drawterm-gate-x64.XXXXXX")
# The per-run unique tags: qemu's -name (R9_RUN_TAG) and drawterm's
# argv[0] (R9_DT_TAG — the expect spawns drawterm via bash's `exec -a'
# carrying it).  Both sweeps below key on them; the r9x64dtgate-
# prefix is this gate's OWN (the sibling-gate no-cross-kill rule — it
# differs from every other x64 gate's tag, and the argv[0]-keyed
# drawterm sweep cannot match a foreign drawterm's normal argv).
R9_RUN_TAG="r9x64dtgate-$$-$(date +%s)"
R9_DT_TAG="r9x64dtgate-dt-$$-$(date +%s)"
export R9_RUN_TAG R9_DT_TAG
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills BOTH process groups on every exit path;
	# this trap sweeps any survivor.  both patterns are keyed on THIS
	# run's unique tags — never on a kernel-name or binary-name class,
	# so a foreign r9 qemu (a dev's interactive boot, a sibling gate)
	# or a foreign drawterm session is never cross-killed.
	pkill -f "[q]emu-system-x86_64.*${R9_RUN_TAG}" 2>/dev/null || true
	pkill -f "^${R9_DT_TAG} " 2>/dev/null || true
	rm -rf "$TMPD"
	exit "$status"
}
trap cleanup EXIT

echo "== step 4/5: composing the ISO (r9's iso-builder: kernel + bootfs-cpu.paq as /boot/bootfs.paq + the init append)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" --append="init=/amd64/init -c" "$CPU_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 5: the expect-driven -G interop gate ---------------------------

R9_DT_LOG="${R9_DT_LOG:-$OUTD/drawterm-gate.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence; the driver rm -f's it again belt-and-braces)
rm -f "$R9_DT_LOG"

echo "== step 5/5: the -G interop gate (build/x86_64/drawterm-gate.expect)"
echo "== capture: $R9_DT_LOG"

export R9_ISO R9_SMOKE_LOG="$R9_DT_LOG" R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/drawterm-gate.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "drawterm-gate FAILED (rc=$RC — the driver named the stage on stderr; capture: $R9_DT_LOG)"
fi
echo "== drawterm-gate PASS — capture retained at $R9_DT_LOG"
exit 0
