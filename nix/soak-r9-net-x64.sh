# nix/soak-r9-net-x64.sh — the NETIP-08 tap-leg soak gate as a flake app
# (16-05, D-11/D-12/D-13): nix/smoke-r9-net-x64.sh's composed pipeline
# re-keyed onto the TAP venue — the L2-truth leg (HNET-03's
# tested-on-primary-host leg; the host's real ARP answer is the
# evidence NETIP-08 exists for).  The pipeline, each step loud on
# failure:
#
#   0a. net-mode parse — the --net=<mode> over R9_NET over the slirp
#       default contract, IDENTICAL to nix/boot-r9-x64.sh step 0c (=
#       form only, flag > env > default, venue-validated) — then THE
#       SLIRP REFUSAL (D-11's venue-honesty control, mechanical): mode
#       slirp — including the hermetic DEFAULT — errs immediately with
#       `slirp evidence not accepted', before ANY bake or boot.  This
#       gate's verdict leg is tap or nothing: slirp forgives L2 bugs
#       by design, and its captures carry the asserted NOT-L2-TRUTH
#       labels by contract.
#   0b. the flake contract: R9_KERNEL_X64_PKG + R9_ISO_BUILDER (the
#       14-07 contract) + R9_NETDEV_EMITTER/R9_NET_DOCTOR (16-04's)
#       + HOST_ECHO_X64 (this plan's peer) + accel selection (no
#       silent downgrade, the Phase-13 discipline).
#   0c. DOCTOR PREFLIGHT — "$R9_NET_DOCTOR" --mode tap FIRST: the
#       16-03 ONE implementation (read-only diagnose+print), any FAIL
#       aborts here with its per-issue remediation blocks inline —
#       BEFORE any bake, boot, or listener (T-16-14: a stale ACL
#       never reaches a tap boot).
#   0d. the seam parse: TAP_GWV4/BLASTPORT from the netaddr seam
#       EXACTLY the way the doctor's seam_init reads it (grep-eval of
#       the tap_gwv4/blastport keys — one seam, host-side too; the
#       peer binds the seam's bridge address, the guest dials it).
#   0e. the emitter argv: NETDEV_ARGV via "$R9_NETDEV_EMITTER" --mode
#       tap --pcap <evidence-dir>/netsoak.pcap — the pinned r9 TOML's
#       tap stanza + a filter-dump capture (retained with this run's
#       evidence; 16-08 consolidates pcap + log into the phase dir);
#       exported as R9_NETDEV_ARGV for the expect driver to split (no
#       netdev literal anywhere in this script — D-05).
#   0f. the host echo peer: "$HOST_ECHO_X64" $TAP_GWV4 $BLASTPORT as
#       a background CHILD of this script — waited for its
#       `hostecho: listening' marker before any build spends work,
#       torn down by the EXIT trap (dies with the gate; the r9 xtask
#       HostEcho lifecycle precedent, D-12; no daemon, no systemd).
#       The doctor's blastport-free check ran first (0c).
#   1. userland build — build/x86_64/stage-build.sh FIRST (mkimage's
#       input producer: the leg-1 marker pair + the boot chain — the
#       clean-checkout rule, 16-06's hosted-run discovery) then
#       build/x86_64/subset-build.sh (the tier driver
#       incl. the 14-09 net section).  Skip with R9_SKIP_BUILD=1 for
#       iteration — an escape hatch, NEVER the default; the GATE runs
#       the default.
#   2. bake — build/x86_64/mkimage.sh → out/bootfs-net.paq (the NET
#       image this gate boots: the chain tree + the ip-container
#       binaries + the C helpers + the /lib fixtures incl. 16-02's
#       netip-tap.rc — asserted present below).
#   3. compose — r9's exported iso-builder (R9_ISO_BUILDER: ONE
#       reproducibility implementation) builds the ISO from the pinned
#       kernel-x64 + the net bake as /boot/bootfs.paq.
#   4. the gate — build/x86_64/netsoak-r9.expect spawns qemu with the
#      composed ISO on -cdrom (q35) and the SPLIT emitter tap argv,
#      drives `rc /lib/netip-tap.rc 2048 8' (the tiered soak: baseline
#      2048 rounds, burst 8 x 512 — the gate's committed data, D-11),
#      asserts every fixture marker, counts `tcpblast: done'
#      occurrences (exactly 9) and zero `netip: FAIL', and fails
#      wedge-stalls LOUD with the capture tail.  Green-twice, the
#      kernel-fix loop, and the evidence/r9-SHA close-out are 16-08's
#      (the plan split: THIS plan builds and proves the machinery).
#
# Env contract:
#   R9_KERNEL_X64_PKG  REQUIRED — the r9 kernel-x64 package's store
#                      path; the flake app exports it.
#   R9_ISO_BUILDER    REQUIRED — r9's exported iso-builder BINARY.
#   R9_NETDEV_EMITTER REQUIRED — r9's netdev-args emitter bin (the tap
#                      argv + the pcap object come from its output).
#   R9_NET_DOCTOR     REQUIRED — the harvey-net-doctor app path
#                      (16-03/D-14; the tap preflight, ONE
#                      implementation consumed two ways).
#   HOST_ECHO_X64     REQUIRED — the committed host echo peer binary
#                      (the flake's hostEchoX64Pkg build of
#                      nix/host-echo.c; D-12).
#   HARVEY_NETADDR_SEAM optional — the netaddr seam file (the flake
#                      app exports the committed store path; the
#                      fallback below is the doctor's $HARVEY-relative
#                      shape — same bytes in a gate run).
#   R9_NET            default net mode when no --net flag (the boot
#                      script's contract; slirp — the default — is
#                      REFUSED here; want tap).
#   R9_SKIP_BUILD     =1 skips step 1 (iteration hatch; see above).
#   R9_SOAK_LOG       default $HARVEY/build/x86_64/netsoak-r9.log (a
#                      gitignored transient; the green runs retain
#                      per-run copies in the phase dir's evidence/ —
#                      16-08's consolidation).
#   R9_ACCEL          kvm (default) | tcg — no auto, no silent
#                      downgrade.
#   R9_CPU            override the cpu model (default: host under kvm,
#                      qemu64 under tcg).
#   KERNDATE          pinned-build timestamp override; derived from
#                      the HARVEY checkout's git log otherwise.
#
# Hygiene: the capture is rm -f'd BEFORE launch; the expect driver
# kills qemu's process group on every exit path; THIS script's EXIT
# trap sweeps any qemu survivor via a bracket-fixed pkill keyed on
# this run's unique R9_RUN_TAG (exported below; the driver adds it to
# qemu's argv as -name) AND kills the host echo peer child — the peer
# dies with the gate on every exit path.  The tag's r9x64soak- prefix
# differs from smoke-r9-x64.sh's r9x64smoke-, tier1's r9x64tier1-,
# and the net smoke's r9x64net- so the four gates' survivor sweeps
# can never cross-kill.  The evidence scratch dir (pcap + the peer's
# own log) is RETAINED past the run — it is this run's capture
# evidence; 16-08 copies it into the phase evidence dir.
#
# Wrapper provides (the flake app's runtimeInputs): PLAN9 with
# $PLAN9/bin LAST on PATH; qemu, git, expect, procps (the survivor
# sweep's pkill) always; util-linux+gnused+mount+binutils on linux
# (the namespace build's transport).  Standalone use needs the same
# tools on PATH.
#
# usage: nix run .#boot-r9-net-soak-x64 [-- --net=tap]   (from the repo root)

set -e

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src) — run from the repo root"

# --- step 0a: net-mode parse (--net flag > R9_NET > slirp default) ------
# IDENTICAL to nix/boot-r9-x64.sh step 0c (the contract's own words) —
# then this gate's OWN refusal: slirp evidence is not accepted, ever,
# including via the default.  The refusal is BEFORE any contract
# spend, bake, or boot (the venue-honesty control, mechanically
# asserted; a slirp soak must never even bake).

case "$(uname -s)" in
	Linux)	VENUE=linux ;;
	Darwin)	VENUE=darwin ;;
	*) err "uname $(uname -s): unsupported venue for --net (want linux|darwin)" ;;
esac

# the script's ONLY argument surface: --net=<mode>, the = form alone
NET_FLAG=
for ARG in "$@"; do
	case "$ARG" in
	--net=*)
		[ -z "$NET_FLAG" ] || err "duplicate --net ('$ARG' after '$NET_FLAG') — one net mode per run"
		NET_FLAG="$ARG"
		;;
	*) err "unknown argument '$ARG' — the accepted form is --net=<mode> (usage: nix run .#boot-r9-net-soak-x64 -- --net=tap)" ;;
	esac
done

if [ -n "$NET_FLAG" ]; then
	NET_MODE="${NET_FLAG#--net=}"
else
	NET_MODE="${R9_NET:-slirp}"
fi

case "$NET_MODE" in
	slirp)
		err "slirp evidence not accepted — the NETIP-08 soak verdict is the tap leg's (slirp is not L2 truth by contract and its captures say so); want --net=tap / R9_NET=tap; refusing before any bake or boot (D-11's venue-honesty control)"
		;;
	tap)
		[ "$VENUE" = linux ] || err "--net=tap on $VENUE: cross-venue (tap is the linux leg; $VENUE's valid net modes: slirp vmnet)"
		;;
	vmnet)
		[ "$VENUE" = darwin ] || err "--net=vmnet on $VENUE: cross-venue (vmnet is darwin's manual leg, HNET-04; $VENUE's valid net modes: slirp tap)"
		;;
	*) err "--net/R9_NET=$NET_MODE: want slirp|tap|vmnet (the valid net modes; this gate runs tap only)" ;;
esac

# --- step 0b: the flake contract + accel selection ----------------------

[ -n "${R9_KERNEL_X64_PKG:-}" ] || err "R9_KERNEL_X64_PKG unset — run via the flake app (nix run .#boot-r9-net-soak-x64), which exports the r9 kernel-x64 store path"
[ -d "$R9_KERNEL_X64_PKG" ] || err "R9_KERNEL_X64_PKG $R9_KERNEL_X64_PKG: not a directory (unrealised store path?)"

R9_KERNEL="$R9_KERNEL_X64_PKG/kernel-x64.elf"
if [ ! -f "$R9_KERNEL" ]; then
	R9_KERNEL=$(find "$R9_KERNEL_X64_PKG" -name 'kernel-x64.elf' -type f 2>/dev/null | head -1 || true)
fi
[ -n "$R9_KERNEL" ] && [ -f "$R9_KERNEL" ] || err "kernel-x64.elf not found under $R9_KERNEL_X64_PKG"

[ -n "${R9_ISO_BUILDER:-}" ] || err "R9_ISO_BUILDER unset — run via the flake app (nix run .#boot-r9-net-soak-x64), which exports r9's iso-builder script path"
[ -f "$R9_ISO_BUILDER" ] && [ -x "$R9_ISO_BUILDER" ] \
	|| err "R9_ISO_BUILDER $R9_ISO_BUILDER: not an executable file (want <pkg>/bin/r9-iso-builder)"

[ -n "${R9_NETDEV_EMITTER:-}" ] || err "R9_NETDEV_EMITTER unset — run via the flake app, which exports r9's netdev-args emitter path"
[ -f "$R9_NETDEV_EMITTER" ] && [ -x "$R9_NETDEV_EMITTER" ] \
	|| err "R9_NETDEV_EMITTER $R9_NETDEV_EMITTER: not an executable file (want <pkg>/bin/r9-netdev-args)"

[ -n "${R9_NET_DOCTOR:-}" ] || err "R9_NET_DOCTOR unset — run via the flake app, which exports the harvey-net-doctor path (the tap preflight's ONE implementation)"
[ -f "$R9_NET_DOCTOR" ] && [ -x "$R9_NET_DOCTOR" ] \
	|| err "R9_NET_DOCTOR $R9_NET_DOCTOR: not an executable file (want <pkg>/bin/harvey-net-doctor)"

[ -n "${HOST_ECHO_X64:-}" ] || err "HOST_ECHO_X64 unset — run via the flake app, which exports the committed host echo peer (hostEchoX64Pkg's bin/host-echo)"
[ -f "$HOST_ECHO_X64" ] && [ -x "$HOST_ECHO_X64" ] \
	|| err "HOST_ECHO_X64 $HOST_ECHO_X64: not an executable file (want <hostEchoX64Pkg>/bin/host-echo)"

R9_ACCEL="${R9_ACCEL:-kvm}"
case "$R9_ACCEL" in
	kvm)
		[ -e /dev/kvm ] || err "/dev/kvm absent and R9_ACCEL=$R9_ACCEL — no silent downgrade: set R9_ACCEL=tcg explicitly for the TCG fallback (the Phase-13 discipline)"
		R9_CPU="${R9_CPU:-host}"
		;;
	tcg)
		R9_CPU="${R9_CPU:-qemu64}"
		;;
	*) err "R9_ACCEL=$R9_ACCEL: want kvm|tcg" ;;
esac

echo "== r9 kernel package: $R9_KERNEL_X64_PKG"
echo "   kernel:        $R9_KERNEL"
echo "   iso-builder:   $R9_ISO_BUILDER"
echo "   netdev emitter: $R9_NETDEV_EMITTER"
echo "   net doctor:    $R9_NET_DOCTOR"
echo "   host peer:     $HOST_ECHO_X64"
echo "   shape:         q35 accel=$R9_ACCEL cpu=$R9_CPU net=$NET_MODE (slirp refused upstream of here)"

# --- run scratch + survivor sweep trap (installed BEFORE the peer starts,
#     so teardown covers it from birth) -----------------------------------

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/soak-r9-net-x64.XXXXXX")
# the RETAINED evidence scratch: the pcap capture + the peer's own log
# (this run's evidence; 16-08 consolidates into the phase evidence dir)
EVIDD=$(mktemp -d "${TMPDIR:-/tmp}/netsoak-r9-x64.XXXXXX")
# The per-run unique tag — the driver adds it to qemu's argv (-name)
# and this run's survivor sweep keys on it.  The r9x64soak- prefix
# differs from every sibling gate's tag so the sweeps never
# cross-kill (a foreign r9 qemu — a dev's interactive boot, a parallel
# gate — is never matched; the pattern is bracket-fixed so pkill
# cannot self-match this shell's own argv either).
R9_RUN_TAG="r9x64soak-$$-$(date +%s)"
export R9_RUN_TAG
PEER_PID=
# shellcheck disable=SC2329  # invoked via trap below
cleanup() {
	status=$?
	# the expect driver kills qemu's process group on every exit path;
	# this trap sweeps any survivor keyed on THIS run's unique tag —
	# never a kernel-name class — AND kills the host echo peer child:
	# the peer dies with the gate on EVERY exit path (D-12's lifecycle
	# rule; the trap is installed before the peer starts).
	pkill -f "[q]emu-system-x86_64.*${R9_RUN_TAG}" 2>/dev/null || true
	if [ -n "${PEER_PID:-}" ]; then
		kill "$PEER_PID" 2>/dev/null || true
	fi
	rm -rf "$TMPD"
	echo "== soak evidence scratch retained: $EVIDD (netsoak.pcap + hostecho.log — 16-08 consolidates into the phase evidence dir)"
	exit "$status"
}
trap cleanup EXIT

# --- step 0c: the doctor preflight (tap) — FIRST, before any bake/boot --

DOCTOR_RC=0
# shellcheck disable=SC2312  # the captured rc is the point: FAIL => abort
DOCTOR_OUT=$(HARVEY="$HARVEY" "$R9_NET_DOCTOR" --mode tap) || DOCTOR_RC=$?
printf '%s\n' "$DOCTOR_OUT"
if [ "$DOCTOR_RC" -ne 0 ]; then
	err "tap prereqs unmet — the doctor's findings + per-issue remediation blocks are above; full report: nix run .#net-doctor -- --mode tap (the doctor is read-only: the human applies the remediations — the exact 'allow br0' line etc. — then 16-08 runs the gate; no silent downgrade, ever)"
fi
echo "== doctor preflight PASS (tap mode)"

# --- step 0d: the seam parse (the doctor's seam_init shape) --------------

SEAM_PATH="${HARVEY_NETADDR_SEAM:-$HARVEY/build/x86_64/root-tree/lib/netaddr.rc}"
[ -f "$SEAM_PATH" ] || err "the netaddr seam is missing: $SEAM_PATH — run from the repo root or set HARVEY/HARVEY_NETADDR_SEAM (the peer binds the seam's tap_gwv4, the guest dials it)"
# eval the grep-extracted key assignments (committed repo data — the
# trusted seam, not probe output), exactly the doctor's read
eval "$(grep -E '^(tap_gwv4|blastport)=' "$SEAM_PATH" || true)"
[ -n "${tap_gwv4:-}" ] || err "seam $SEAM_PATH: no tap_gwv4 key (16-02's tap leg expected)"
[ -n "${blastport:-}" ] || err "seam $SEAM_PATH: no blastport key"
TAP_GWV4=$tap_gwv4
BLASTPORT=$blastport
echo "== seam: tap_gwv4=$TAP_GWV4 blastport=$BLASTPORT ($SEAM_PATH)"

# --- step 0e: the emitter argv (tap + the retained pcap capture) --------

# shellcheck disable=SC2312  # the rc rides the ||: an emitter failure is a named contract error (its stderr passed through above)
NETDEV_ARGV=$("$R9_NETDEV_EMITTER" --mode tap --pcap "$EVIDD/netsoak.pcap") \
	|| err "the netdev emitter failed for mode tap (its diagnostics are above; the argv comes only from the pinned r9 TOML — D-05)"
[ -n "$NETDEV_ARGV" ] || err "the netdev emitter printed no netdev argv for mode tap"
export R9_NETDEV_ARGV="$NETDEV_ARGV"
echo "== netdev argv (emitter, tap): $NETDEV_ARGV"
echo "== pcap capture: $EVIDD/netsoak.pcap"

# --- step 0f: the host echo peer (a gate-owned child; dies with the gate)

"$HOST_ECHO_X64" "$TAP_GWV4" "$BLASTPORT" >"$EVIDD/hostecho.log" 2>&1 &
PEER_PID=$!
# wait for its listening marker before any build spends work — a bind
# failure (address gone, port taken the instant after the doctor's
# check) surfaces HERE, loudly, with the peer's own log
PEER_WAIT=0
while ! grep -q 'hostecho: listening' "$EVIDD/hostecho.log" 2>/dev/null; do
	if ! kill -0 "$PEER_PID" 2>/dev/null; then
		err "the host echo peer exited early — its log: $EVIDD/hostecho.log (bind/listen failure? the doctor's blastport-free check passed moments ago)"
	fi
	PEER_WAIT=$((PEER_WAIT + 1))
	[ "$PEER_WAIT" -gt 100 ] && err "the host echo peer did not announce listening within ~10s — log: $EVIDD/hostecho.log"
	sleep 0.1
done
echo "== host echo peer up: pid $PEER_PID at $TAP_GWV4:$BLASTPORT (dies with this gate)"

# --- provenance (KERNDATE; the boot-r9-x64.sh discipline) ---------------

if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi
export KERNDATE

# --- step 1: the amd64 userland (the tier build + its net section) ------

if [ "${R9_SKIP_BUILD:-0}" = "1" ]; then
	echo "== R9_SKIP_BUILD=1 — skipping the userland build (iteration hatch; not the gate)"
else
	echo "== step 1/4a: stage the mkimage inputs (build/x86_64/stage-build.sh — the leg-1 marker pair smoke-out/{init,smokesleep} + the boot chain; mkimage's named producer, absent on a clean checkout: the 16-06 hosted-run discovery)"
	sh "$HARVEY/build/x86_64/stage-build.sh" || err "stage build failed"
	echo "== step 1/4: amd64 tier + net build (build/x86_64/subset-build.sh)"
	sh "$HARVEY/build/x86_64/subset-build.sh" || err "tier build failed"
fi

# --- step 2: bake the bootfs images (the net bake is the payload) --------

echo "== step 2/4: bake bootfs-net.paq (build/x86_64/mkimage.sh, the net section)"
sh "$HARVEY/build/x86_64/mkimage.sh" || err "bootfs bake failed"
NET_PAQ="$HARVEY/build/x86_64/out/bootfs-net.paq"
[ -s "$NET_PAQ" ] || err "$NET_PAQ missing/empty after the bake (mkimage's net section)"

# --- step 3: compose the ISO ---------------------------------------------

echo "== step 3/4: composing the ISO (r9's iso-builder: kernel + bootfs-net.paq as /boot/bootfs.paq)"
"$R9_ISO_BUILDER" "$R9_KERNEL" "$TMPD" "$NET_PAQ" bootfs.paq \
	|| err "iso-builder failed (the kernel/builder contract is r9's; R9_KERNEL_X64_PKG/R9_ISO_BUILDER name this run's inputs)"
R9_ISO="$TMPD/boot.iso"
[ -s "$R9_ISO" ] || err "$R9_ISO missing/empty after the iso-builder"

# --- step 4: the expect-driven soak gate ----------------------------------

R9_SOAK_LOG="${R9_SOAK_LOG:-$HARVEY/build/x86_64/netsoak-r9.log}"
R9_QEMU="${R9_QEMU:-qemu-system-x86_64}"

# fresh capture per run BEFORE launch (a pre-seeded stale log is dead
# evidence — it starts empty and only this run's boot writes it; the
# driver rm -f's it again belt-and-braces)
rm -f "$R9_SOAK_LOG"

echo "== step 4/4: the soak gate (build/x86_64/netsoak-r9.expect — baseline 2048 + burst 8x512 via rc /lib/netip-tap.rc)"
echo "== capture: $R9_SOAK_LOG"

export R9_ISO R9_SOAK_LOG R9_QEMU
export R9_MACHINE=q35 R9_CPU R9_ACCEL

set +e
expect "$HARVEY/build/x86_64/netsoak-r9.expect"
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
	err "soak gate FAILED (the driver named the stage + printed the capture tail; capture: $R9_SOAK_LOG, peer log: $EVIDD/hostecho.log)"
fi
echo "== soak gate PASS — capture retained at $R9_SOAK_LOG; pcap + peer log at $EVIDD"
exit 0
