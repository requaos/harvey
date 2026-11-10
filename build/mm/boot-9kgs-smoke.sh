#!/bin/sh
# boot-9kgs-smoke.sh — the gs render smoke on the donor venue (15-07
# Task 3, USPACE-09, D-11): gs executes IN GUEST and renders the
# committed fixture to a verified non-empty bitmap FILE — the
# LP64-fossil proof beyond compile green that 753 files of ported
# unix C demand.
#
# Self-contained (the venue-harness shape, build-9kdraw.sh's clone):
#   1. BAKE — its OWN payload via the host mkpaqfs: /amd64/bin/gs (the
#      coverage sweep's harvest) + gs's PostScript library (lib/* -> the
#      -I search path; the INIT FILES only — the licensing boundary
#      stages no font payloads anywhere, ever) + the committed fixture
#      + rcmain + ramfs (the writable /tmp) + the render session baked
#      as lib/trace-session.rc — the name k10draw.rc's existing hook
#      sources.  Written as build/x86_64/out/bootfs-gs.paq: its OWN paq
#      name, no shared file with the trace rig, so a same-wave
#      bootfs-draw.paq bake can never satisfy this harness's freshness
#      check.
#   2. BOOT — the 15-05 draw donor kernel (amd64/9kdraw.elf) under
#      plain qemu: its -initrd module channel carries the payload (the
#      kernel is the incidental carrier, chosen for the channel; the
#      draw devices themselves are never used by the smoke — the FILE
#      output device only).  qemu registers -initrd by basename, and
#      k10draw.rc's channel contract names bootfs-draw.paq, so the boot
#      feeds it a scratch COPY at that fixed name — the payload itself
#      is this harness's own bootfs-gs.paq (fresh, name-keyed).
#      -m generous for gs's arena (1024).  The minimal utility set is
#      wc (the GS-BITS size line's `wc -c < /tmp/render.bit` — the
#      venue kernel's embedded root carries echo/cat/test/sleep/read/
#      rc/bind/paqfs only, no wc).
#   3. CLASSIFY — GS-EXIT-OK (gs's own exit status) + GS-RENDER-OK + the
#      GS-BITS size line on the serial capture, zero panic/trap lines;
#      the capture is copied to the phase evidence dir.
#
# The device: -sDEVICE=ppmraw (gdevpbm.c, in the committed ld.tr link
# set).  The plan's example named `-sDEVICE=bit', but gdevbit.o is not
# among the devices the committed fake-make products link (measured:
# ld.tr carries gdevpbm, not gdevbit); ppmraw is the same FILE-device
# class the plan names ("bit/bitrgb/ppmraw class FILE devices") — raw
# PPM bytes to -sOutputFile, no display, no draw device use.
#
# usage: nix develop -c sh build/mm/boot-9kgs-smoke.sh  (repo root)
# Env: HARVEY, GS_KERNEL (default amd64/9kdraw.elf), GS_MEM (default
#   1024), GS_BOOT_BUDGET/GS_SMOKE_BUDGET (s; default 60/600 KVM,
#   600/1800 TCG), GS_LOG (default .build/gs-serial.log)

set -eu

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

# System tools first (the devshell puts Harvey's plan9 hostbin tools
# ahead on PATH — the 15-01 measured shadowing class)
PATH="/run/current-system/sw/bin:$PATH"
export PATH LC_ALL=C

GREP=$(command -v /run/current-system/sw/bin/grep || command -v /usr/bin/grep || command -v grep) || err "no host grep"

[ "$(uname -s)" = "Linux" ] || err "the gs smoke boots a linux-native qemu venue"
[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout"
[ -n "${PLAN9:-}" ] && [ -x "$PLAN9/bin/rc" ] || err "\$PLAN9/bin/rc missing — run inside the nix devshell (nix develop -c sh ...)"

# --- preconditions (named remediation, never assumed) ------------------
KERNEL="${GS_KERNEL:-$HARVEY/amd64/9kdraw.elf}"
[ -s "$KERNEL" ] || err "amd64/9kdraw.elf missing — run nix develop -c sh build/mm/build-9kdraw.sh first (the 15-05 draw donor venue)"
[ -s "$HARVEY/amd64/bin/gs" ] || err "amd64/bin/gs missing — the coverage sweep harvests it (nix develop -c sh build/x86_64/coverage-sweep.sh, green)"
FIXTURE="$HARVEY/build/x86_64/gs-render.ps"
[ -s "$FIXTURE" ] || err "the committed fixture is missing: $FIXTURE"
GSLIB="$HARVEY/sys/src/cmd/gs/lib"
[ -f "$GSLIB/gs_init.ps" ] || err "gs's init library missing: $GSLIB/gs_init.ps (the -I search path needs it)"
MKPAQFS="$HARVEY/.build/bin/mkpaqfs"
if [ ! -x "$MKPAQFS" ]; then
	echo "== mkpaqfs host binary missing — building via build/x86_64/mkpaqfs-host.sh"
	sh "$HARVEY/build/x86_64/mkpaqfs-host.sh" || err "mkpaqfs host build failed"
fi
[ -x "$MKPAQFS" ] || err "$MKPAQFS missing after mkpaqfs-host.sh"

# 15-01's phase build-tree lock: the bake HARVESTS /amd64/bin/gs — a
# same-wave payload bake or tier driver must never interleave
command -v flock >/dev/null 2>&1 || err "flock not found — the amd64 build-tree lock needs util-linux flock"
mkdir -p "$HARVEY/.build"
exec 9>"$HARVEY/.build/amd64-tree.lock"
flock 9 || err "cannot acquire the amd64 build-tree lock"
echo "== amd64 build-tree lock held: $HARVEY/.build/amd64-tree.lock"

# --- the ramfs scratch server (build-9kdraw's staging shape; mntgen is
# read-only on this tree — the writable /tmp the render output needs).
# NS_HBIN is build-9kdraw.sh's computed discipline verbatim (the
# hostbin dir is hostbin-linux-<arch>, not hostbin-<arch>).
_ha=$(uname -m); [ "$_ha" = "arm64" ] && _ha=aarch64
NS_HBIN="$HARVEY/.build/hostbin-linux-$_ha/bin"
[ -x "$NS_HBIN/6c" ] || err "$NS_HBIN/6c missing — run 'nix run .#setup && nix run .#toolchain' first"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/gs-smoke-stage.XXXXXX")
(	cd "$HARVEY" && \
	"$NS_HBIN/6c" -FTVw -o "$STAGE/ramfs.6" -Isys/include -Iamd64/include sys/src/cmd/ramfs.c && \
	"$NS_HBIN/6l" -o "$STAGE/ramfs" -L "$HARVEY/amd64/lib" "$STAGE/ramfs.6" && \
	rm -f "$STAGE/ramfs.6"
) || err "ramfs host-side build failed"
magic=$(od -An -tx1 -N4 "$STAGE/ramfs" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "ramfs: bad magic $magic (want 00008a97)"

# --- the bake: bootfs-gs.paq (THIS harness's own, name-keyed) ----------
OUT="$HARVEY/build/x86_64/out"
PSTAGE="$OUT/gspaq-stage"
IMAGE="$OUT/bootfs-gs.paq"
rm -rf "$PSTAGE"
mkdir -p "$PSTAGE/amd64/bin" "$PSTAGE/sys/lib/ghostscript" "$PSTAGE/lib" "$PSTAGE/rc/lib"

cp "$HARVEY/amd64/bin/gs" "$PSTAGE/amd64/bin/gs"
cp "$STAGE/ramfs" "$PSTAGE/amd64/bin/ramfs"
rm -rf "$STAGE"
# the minimal utility set: wc (the session's size line).  The venue
# kernel's embedded root has no wc, and without it the GS-BITS line can
# never carry a byte count (the tier-1 driver installs it at
# /amd64/bin/wc — named remediation, never assumed)
[ -s "$HARVEY/amd64/bin/wc" ] || err "amd64/bin/wc missing — the tier-1 driver installs it (nix develop -c sh build/x86_64/subset-build.sh)"
magic=$(od -An -tx1 -N4 "$HARVEY/amd64/bin/wc" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "amd64/bin/wc: bad magic $magic (want 00008a97)"
cp "$HARVEY/amd64/bin/wc" "$PSTAGE/amd64/bin/wc"
# gs's PostScript INIT FILES (the -I path content).  The lib/ dir
# carries .ps init code only w.r.t. this staging — the licensed bitmap
# payloads live elsewhere in the gs tree and are never staged (D-11 /
# DESK-03: the staged typeface set is lib/font/bit only).
cp "$GSLIB"/*.ps "$PSTAGE/sys/lib/ghostscript/" 2>/dev/null || true
[ -f "$PSTAGE/sys/lib/ghostscript/gs_init.ps" ] || err "gs_init.ps missing from the staged init library"
# the init chain's non-.ps opens: two UNCONDITIONAL `.runlibfile' reads
# of plain-text config tables — gs_fntem.ps:27 (xlatmap) and
# gs_fapi.ps:59 (FAPIconfig); gconfig.h registers both as init files in
# this build.  Measured on the fourth boot: without xlatmap the init
# unwinds "Unrecoverable error: undefined in .uninstallpagedevice"
# with gs_fntem.ps on the operand stack.  These are name/path tables
# (1750 and 778 bytes of text) — never typeface payloads; the Fontmap
# family and every font dir stay unstaged (the measured-minimal set:
# a file joins this list only when a boot proves the init opens it).
for f in xlatmap FAPIconfig; do
	[ -s "$GSLIB/$f" ] || err "gs init config table missing: $GSLIB/$f"
	cp "$GSLIB/$f" "$PSTAGE/sys/lib/ghostscript/$f"
done
NLIB=$(find "$PSTAGE/sys/lib/ghostscript" -type f | wc -l | tr -d ' ')
[ "$NLIB" -ge 100 ] || err "staged gs init library suspiciously small: $NLIB files"
cp "$FIXTURE" "$PSTAGE/lib/gs-render.ps"
cp "$HARVEY/rc/lib/rcmain" "$PSTAGE/rc/lib/rcmain"

# the render session — baked as lib/trace-session.rc, the hook
# k10draw.rc already sources when present (the venue's payload-session
# contract; no kernel change, no venue-script change)
cat > "$PSTAGE/lib/trace-session.rc" <<'SESSIONEOF'
# trace-session.rc — the gs render session (BAKED by
# build/mm/boot-9kgs-smoke.sh; runs in a child rc from k10draw.rc after
# the venue's four-marker bring-up gate).  rc dialect discipline (the
# 15-02 measured forms): flat ladders, ^ concatenation, no fd-dup
# redirects, no bare = in patterns.
#
# D-11's letter: render, bitmap FILE, no display — the FILE output
# device only (ppmraw), never the plan9 display device, never the draw
# device.  -I names the staged init library's search path (the in-guest
# /sys is the read-only devroot; the payload's tree rides /mnt).
#
# The two =-bearing switches are QUOTED: Harvey's rc lexer (lex.c
# wordchr) ends a word at every bare =, so an unquoted -sDEVICE=ppmraw
# lexes WORD = WORD and the whole sourced file dies "token '=sDEVICE':
# syntax error" (measured on this harness's first boot; plan9port's rc
# accepts the bare form, so a host-side rc check never sees it).
# /bin/gs is invoked by ABSOLUTE PATH: rc's Execute prints only the
# LAST path candidate's errstr, which masks the real /bin/gs failure
# behind "./gs file does not exist" (measured on the second boot).
if (test -e /bin/gs && test -x /bin/gs)
	echo GS-BIN-PRESENT
if not
	echo GS-BIN-MISSING
/bin/gs -q -dNOPAUSE -dBATCH '-sDEVICE=ppmraw' '-sOutputFile=/tmp/render.bit' -I/mnt/sys/lib/ghostscript /lib/gs-render.ps
# gs's exit status is PART of the verdict: ppmraw writes its header and
# rows incrementally, so a gs that dies mid-render still leaves a
# non-empty file — a bitmap alone is not a render.  $status is captured
# on the very next line (any later command overwrites it); the empty
# string is rc's success status.
gsstatus=$status
if (~ $gsstatus '')
	echo GS-EXIT-OK
if not
	echo GS-EXIT-FAIL $gsstatus
if (test -s /tmp/render.bit) {
	gsbits=`{wc -c < /tmp/render.bit}
	echo GS-BITS $gsbits
}
if (~ $gsstatus '' && test -s /tmp/render.bit)
	echo GS-RENDER-OK
if not
	echo GS-RENDER-FAIL
echo GS-SMOKE-DONE
SESSIONEOF

# the bake manifest (printed — the bake log is the evidence)
for p in amd64/bin/gs amd64/bin/ramfs amd64/bin/wc lib/gs-render.ps lib/trace-session.rc rc/lib/rcmain; do
	[ -s "$PSTAGE/$p" ] || err "paq manifest: $p missing/empty"
	echo "paq manifest: /$p staged"
done
echo "paq manifest: /sys/lib/ghostscript staged ($NLIB init files)"

# KERNDATE determinism (the mkimage rule)
KERNDATE=$(git -C "$HARVEY" log -1 --format=%ct 2>/dev/null || date +%s)
find "$PSTAGE" -exec touch -h -d "@$KERNDATE" {} +
mkdir -p "$OUT"
rm -f "$IMAGE"
# the paq blocksize: mkpaqfs caps every file at blocksize/4 pointer
# slots x blocksize bytes (blocksize^2/4), and a file past the cap is
# only WARNED about and silently DROPPED from the image (measured on
# this harness's third boot: at the 4096 default the cap is 4 MiB, the
# 15.5 MB gs vanished from the paq and the guest had no /bin/gs).
# 16384 lifts the cap to 64 MiB; paqfs reads the blocksize from the
# header (MaxBlockSize is 512K).  The fit is asserted, and ANY mkpaqfs
# diagnostic fails the bake — a warned file is a dropped file.
PAQBS="${GS_PAQ_BLOCKSIZE:-16384}"
gsbytes=$(wc -c < "$PSTAGE/amd64/bin/gs" | tr -d ' ')
[ "$gsbytes" -le $((PAQBS * PAQBS / 4)) ] || err "gs ($gsbytes bytes) exceeds the paq per-file cap at blocksize $PAQBS ($((PAQBS * PAQBS / 4)) bytes) — raise GS_PAQ_BLOCKSIZE"
PAQERR=$(mktemp "${TMPDIR:-/tmp}/gs-smoke-paqerr.XXXXXX")
KERNDATE="$KERNDATE" "$MKPAQFS" -b "$PAQBS" -o "$IMAGE" "$PSTAGE" 2> "$PAQERR" || { cat "$PAQERR" >&2; rm -f "$PAQERR"; err "mkpaqfs failed"; }
if [ -s "$PAQERR" ]; then
	cat "$PAQERR" >&2
	rm -f "$PAQERR"
	err "mkpaqfs emitted diagnostics — a warned file is DROPPED from the image (never a partial bake)"
fi
rm -f "$PAQERR"
echo "paq manifest: blocksize $PAQBS (per-file cap $((PAQBS * PAQBS / 4)) bytes; gs is $gsbytes)"
[ -s "$IMAGE" ] || err "$IMAGE missing/empty after mkpaqfs"
magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d ' \n')
[ "$magic" = "529ab12b" ] || err "$IMAGE: bad header magic $magic (want 529ab12b)"
sz=$(wc -c < "$IMAGE" | tr -d ' ')
trailer=$(od -An -tx1 -j $((sz - 28)) -N 4 "$IMAGE" | tr -d ' \n')
[ "$trailer" = "6b46e688" ] || err "$IMAGE: bad trailer magic $trailer (want 6b46e688)"
rm -rf "$PSTAGE"
echo "== bake OK: $IMAGE ($sz bytes; header $magic trailer $trailer) — this harness's OWN paq, name-keyed"

# --- the boot leg -------------------------------------------------------
QEMU="${GS_QEMU:-}"
if [ -z "$QEMU" ]; then
	QEMU=$(command -v qemu-system-x86_64 || true)
fi
[ -n "$QEMU" ] && [ -x "$QEMU" ] || err "qemu-system-x86_64 not found — run inside the nix devshell or set GS_QEMU"
MEM="${GS_MEM:-1024}"
BOOTLOG="${GS_LOG:-$HARVEY/.build/gs-serial.log}"

# accel probe (once): KVM iff /dev/kvm writable, else TCG
ACCEL=kvm
ACCEL_ARGS="-accel kvm -cpu host"
if [ -w /dev/kvm ]; then
	:
else
	ACCEL=tcg
	ACCEL_ARGS="-accel tcg -cpu qemu64"
fi
BUDGET="${GS_BOOT_BUDGET:-}"
if [ -z "$BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then BUDGET=600; else BUDGET=60; fi
fi
SMOKE_BUDGET="${GS_SMOKE_BUDGET:-}"
if [ -z "$SMOKE_BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then SMOKE_BUDGET=1800; else SMOKE_BUDGET=600; fi
fi

# the module-name contract: qemu registers -initrd by BASENAME and
# k10draw.rc's channel names bootfs-draw.paq — feed it a scratch COPY
# at that fixed name (this harness's payload is bootfs-gs.paq; the
# scratch copy dies with the run)
BOOTDIR=$(mktemp -d "${TMPDIR:-/tmp}/gs-smoke-boot.XXXXXX")
cp "$IMAGE" "$BOOTDIR/bootfs-draw.paq"

: > "$BOOTLOG"
echo "== gs leg: mode $ACCEL (banner ${BUDGET}s, marker ${SMOKE_BUDGET}s), -m $MEM"
echo "== launching: $QEMU -kernel $KERNEL -initrd $BOOTDIR/bootfs-draw.paq -m $MEM $ACCEL_ARGS -display none -no-reboot -serial file:$BOOTLOG"
QEMU_PID=""
cleanup() {
	status=$?
	[ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
	rm -rf "$BOOTDIR"
	exit "$status"
}
trap cleanup EXIT
# shellcheck disable=SC2086
"$QEMU" -kernel "$KERNEL" -initrd "$BOOTDIR/bootfs-draw.paq" -m "$MEM" $ACCEL_ARGS -display none -no-reboot -serial "file:$BOOTLOG" &
QEMU_PID=$!

# Phase A: deadline-wait for the banner
elapsed=0
found=1
while [ "$elapsed" -lt "$BUDGET" ]; do
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		echo "== qemu exited before the banner (${elapsed}s) — classifying what was captured"
		break
	fi
	if "$GREP" -q 'Plan 9' "$BOOTLOG" 2>/dev/null; then
		found=0
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
done

# Phase B: the completion marker / panic signature / qemu death
if [ "$found" -eq 0 ]; then
	echo "== banner captured at ${elapsed}s — waiting for GS-SMOKE-DONE (budget ${SMOKE_BUDGET}s)"
	celapsed=0
	while [ "$celapsed" -lt "$SMOKE_BUDGET" ]; do
		if "$GREP" -q 'GS-SMOKE-DONE' "$BOOTLOG" 2>/dev/null; then
			echo "== GS-SMOKE-DONE observed at +${celapsed}s"
			break
		fi
		if "$GREP" -qF 'panic' "$BOOTLOG" 2>/dev/null || \
		   "$GREP" -qF 'sys: trap' "$BOOTLOG" 2>/dev/null; then
			echo "== signature line observed at +${celapsed}s"
			break
		fi
		# an rc parse error kills the sourced session whole — no
		# completion marker will ever follow; classify now instead of
		# burning the marker budget (measured: the first boot waited
		# the full 600s behind exactly this)
		if "$GREP" -qF 'syntax error' "$BOOTLOG" 2>/dev/null; then
			echo "== rc syntax error observed at +${celapsed}s — the session never ran"
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

if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
	kill "$QEMU_PID" 2>/dev/null || true
fi
wait "$QEMU_PID" 2>/dev/null || true
QEMU_PID=""
sleep 2

# classify: GS-EXIT-OK + GS-RENDER-OK + the GS-BITS size line + zero
# panic/trap.  GS-RENDER-OK is only printed when gs exited clean AND the
# bitmap is non-empty; GS-EXIT-OK is asserted by name as well so a
# partial render (bitmap present, gs failed) reds with its own message
# rather than as a generic missing marker.
RC=0
"$GREP" -q 'Plan 9' "$BOOTLOG" || { echo "GS-GATE-FAIL: no banner"; RC=1; }
"$GREP" -q 'GS-EXIT-OK' "$BOOTLOG" || { echo "GS-GATE-FAIL: gs did not exit clean (no GS-EXIT-OK; a GS-EXIT-FAIL line carries its status — a partial bitmap is not a render)"; RC=1; }
"$GREP" -q 'GS-RENDER-OK' "$BOOTLOG" || { echo "GS-GATE-FAIL: missing GS-RENDER-OK (gs failed to render — the capture's gs error lines classify it; a typeface-referencing fixture is the first suspect)"; RC=1; }
"$GREP" -qE 'GS-BITS [1-9][0-9]*' "$BOOTLOG" || { echo "GS-GATE-FAIL: no GS-BITS size line (the bitmap was empty or never created)"; RC=1; }
if "$GREP" -qiE 'panic|sys: trap' "$BOOTLOG"; then
	echo "GS-GATE-FAIL: panic/trap lines in the capture"
	RC=1
fi
if [ "$RC" -eq 0 ]; then
	BITBYTES=$("$GREP" -oE 'GS-BITS [0-9]+' "$BOOTLOG" | head -1 | awk '{print $2}')
	echo "GS-GATE-PASS: GS-EXIT-OK + GS-RENDER-OK + GS-BITS $BITBYTES bytes (gs exited clean, non-empty bitmap on the FILE device), zero panic/trap, accel=$ACCEL, -m $MEM"
fi

# the capture is the gate's evidence — cat it and retain a copy in the
# phase evidence dir
echo "== serial capture ($BOOTLOG):"
cat "$BOOTLOG"
EVID="$HARVEY/.planning/phases/15-userspace-tiers-bootfs-payload-amd64/evidence"
mkdir -p "$EVID"
cp "$BOOTLOG" "$EVID/15-07-gs-smoke.log"
echo "== capture retained: $EVID/15-07-gs-smoke.log"
exit "$RC"
