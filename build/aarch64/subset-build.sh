#!/bin/sh
# build/aarch64/subset-build.sh — the arm64 tier-0/tier-1 userspace
# namespace build driver (06-03: the hardcoded v1.0 loops became
# tier-file loops in place — RESEARCH OQ-3 — so mkimage.sh and
# smoke-r9.sh inherit tier-1 growth with no call-site changes).
#
# Builds, with objtype=arm64: the tier-0 library allowlist
# (build/aarch64/tiers/tier0-libs.txt) with the D-07 fresh-archive rule
# (rm -f the target .a before mk install — ar vu never prunes, the 02-10
# staleness class) + a T0-ART sha256 marker per lib, then the tier-1
# allowlist (tiers/tier1-cmds.txt) dispatched per entry form
# (cmd/<single> per-target install; cmd/<dir> dir install;
# cmd/<container>/<dir> nested; cmd/<dir>:<target> per-target in the
# dir; 9k/boot + stage/<name> driver-only blocks) with a T1-ART sha256
# marker per artifact, harvested to the gitignored build/aarch64/out/
# with R_MAGIC asserts.  Platform split: darwin drives the lima guest;
# linux runs the SAME generated guest script natively under nsrun.sh's
# sudo-unshare — no lima, no rsync (the namespace bind-mounts the real
# checkout, so artifacts land in place).  out/ ownership: the rsync-back
# here is per-file (never --delete) — last writer wins against the
# staged-init supply chain.
#
# Markers: T0-ART <lib> <sha256>, T1-ART <bin> <sha256>, TIER-BUILD-OK
# (mk exit status is never trusted — 02-12; artifact asserts + markers
# are the only gates).
#
# usage: sh build/aarch64/subset-build.sh   (from the repo root,
# inside the nix devshell)

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"
LOG="${SUBSET_BUILD_LOG:-$HARVEY/.build/subset-build.log}"

err() { echo "error: $*" >&2; exit 1; }

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -f "$HARVEY/sys/src/libmp/arm64/mkfile" ] || err "sys/src/libmp/arm64/mkfile missing (plan 02-07 Task 1 stub)"
[ -f "$HARVEY/sys/src/libsec/arm64/mkfile" ] || err "sys/src/libsec/arm64/mkfile missing (plan 02-07 Task 1 stub)"
[ -d "$HARVEY/arm64" ] || err "arm64/ arch dir missing — plan 02-06 wiring is a precondition"

# Platform split: linux runs natively (sudo unshare via
# nsrun.sh); darwin drives the lima guest.  The guest script below and
# the host-side asserts are shared by both legs.
NATIVE_LINUX=
if [ "$(uname -s)" = "Linux" ]; then
	NATIVE_LINUX=1
fi

if [ -n "$NATIVE_LINUX" ]; then
	# host toolchain for the namespace build (the vm-run.sh guest-side
	# ensure, host-side).  HARVEY must be EXPORTED here: nsrun.sh's
	# --wrap captures `export` output and re-sources it inside the
	# namespace, and the guest script addresses "$HARVEY"/... paths.
	export HARVEY
	_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
	HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-$_hb_arch/bin}"
	export HARVEY_LINUX_BIN
	if [ ! -x "$HARVEY_LINUX_BIN/7c" ] || [ ! -x "$HARVEY_LINUX_BIN/ar" ]; then
		echo "== host toolchain missing — bootstrapping (nix run .#setup && nix run .#toolchain)"
		(cd "$HARVEY" && nix run .#setup && nix run .#toolchain) || err "host toolchain bootstrap failed"
	fi
	# the devshell-env vars the guest script's mk invocations expect
	# (the lima guest gets these from nix develop's shellHook)
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

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/subset-build.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

# guest-side script: written to a host tmp file, rsynced to the
# guest's /tmp, executed via vm-run.sh (which rsyncs the checkout,
# ensures the guest toolchain, and wraps the command in nsrun.sh's
# namespace entry).
cat > "$TMPD/subset-build-guest.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# subset-build-guest.sh — guest side of build/aarch64/subset-build.sh.
# Runs inside the Plan 9 mount namespace (nsrun.sh --wrap): /sys is the
# checkout's sys, /arm64 the committed arch dir. Never committed;
# the host driver regenerates it each run.
set -e

fail() { echo "TIER-BUILD-FAIL: $1" >&2; exit 1; }

echo "== subset build provenance (Harvey's vendored toolchain):"
echo "   7c: $(command -v 7c)"
echo "   7a: $(command -v 7a)"
echo "   7l: $(command -v 7l)"
echo "   ar: $(command -v ar)"
echo "   mk: $(command -v mk)"

# nm shim (nix/build.sh:16-32's idiom, mirrored): host-toolchain
# generator sub-builds (cmd/awk's $cputype.maketab chain — G1) link with
# plan9port 9l, whose autolib execs bare `nm` on HOST ELF objects; with
# $HARVEY_LINUX_BIN first on the devshell PATH that resolves to Harvey's
# ken-format nm, which fails "Can't read header" and silently breaks
# autolib (undefined Bopen/Brdline/Blinelen at link — observed).  Shadow
# it with the wrapper PATH's (binutils) nm for the duration.  Nothing in
# the Plan 9 build itself calls nm, so the shim is safe to leave in
# place for the whole script.
_P9NM_PATH=$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$//')
_NM_HOSTNM=$(PATH="$_P9NM_PATH" command -v nm 2>/dev/null || true)
if [ -n "$_NM_HOSTNM" ]; then
	_NM_SHIMDIR=$(mktemp -d)
	ln -sf "$_NM_HOSTNM" "$_NM_SHIMDIR/nm"
	export PATH="$_NM_SHIMDIR:$PATH"
	echo "== nm shim: $_NM_SHIMDIR/nm -> $_NM_HOSTNM (9l autolib shadow)"
fi

# the namespace binds $HARVEY/arm64 at /arm64; mkdirs lays out the
# bin/lib tree it needs (vm-run.sh, unlike nix/build.sh, does not run
# mkdirs first; git tracks no empty dirs)
cd "$HARVEY" && bash build/mkdirs || fail "mkdirs"

# tier-0 libraries: the D-13 append-only allowlist drives the sweep.
# D-07 fresh-archive per lib: mksyslib's `ar vu $LIB $newprereq` rule is
# append-only and never prunes (the 02-10 staleness class — a stale
# alphaobj.6 duplicate-symbol'd Phase 2), so the target .a is deleted
# before repopulating.  Artifact assert + T0-ART sha256 marker per lib
# (mk exit status is never trusted — 02-12).  libc stays first-class:
# tier0-libs.txt line 1 and build_arm64's explicit bootstrap both keep
# its primacy.
TIER0="$HARVEY/build/aarch64/tiers/tier0-libs.txt"
[ -f "$TIER0" ] || fail "tier0 data file missing: $TIER0"
while read -r line; do
	case "$line" in ''|'#'*) continue;; esac
	d="${line%%[ 	]*}"
	case "$d" in ''|'#'*) continue;; esac
	# 06-05: liblex's archive is libl.a — the lex runtime's historical
	# name (consumers link it by that name; the lib<dir-minus-lib>
	# default holds for every other swept lib)
	case "$d" in
	liblex)	lib="libl.a";;
	*)	lib="lib${d#lib}.a";;
	esac
	echo "== tier0 lib: $d"
	rm -f "/arm64/lib/$lib"
	(cd "/sys/src/$d" && objtype=arm64 mk install) || fail "lib $d"
	[ -s "/arm64/lib/$lib" ] || fail "lib $d: no artifact /arm64/lib/$lib"
	echo "T0-ART $d $(sha256sum "/arm64/lib/$lib" | cut -d' ' -f1)"
done < "$TIER0"

# tier-1 commands + boot chain: the D-13 allowlist, dispatched per entry
# form — cmd/<single> → cmd's per-target install rule; cmd/<dir> → dir
# mk install; cmd/<container>/<dir> → nested dir install;
# cmd/<dir>:<target> → per-target install in the dir (factotum/paqfs
# precedent — never the dir's whole TARG: factotum's sibling fgui needs
# the out-of-tier graphics stack); 9k/boot → the additive objtype-gated
# mkfile.arm64 build+harvest+clean; stage/<name> → the staged-compile
# blocks (init.install / stacksmoke 7c+7l).  T1-ART sha256 marker per
# entry's artifact.  A failing entry aborts the BUILD (fail) — the
# build side is not the sweep; USPACE-04's never-wedge edge belongs to
# tier1-sweep.rc.
TIER1="$HARVEY/build/aarch64/tiers/tier1-cmds.txt"
[ -f "$TIER1" ] || fail "tier1 data file missing: $TIER1"
mkdir -p "$HARVEY/build/aarch64/out"
while read -r line; do
	case "$line" in ''|'#'*) continue;; esac
	entry="${line%%[ 	]*}"
	case "$entry" in ''|'#'*) continue;; esac
	echo "== tier1 entry: $entry"
	case "$entry" in
	9k/boot)
		# boot(8) for arm64 via the additive, objtype-gated
		# mkfile.arm64 (boot has no standalone mkfile; the amd64 path
		# awk-generates the bootconf from a kernel config, and the
		# hand-written bootr9.c is the generated equivalent here).
		# Build in-tree, harvest to out/ (gitignored), then clean the
		# boot dir so the guest tree stays pristine (no *.7/libboot.a7
		# left behind).
		(cd /sys/src/9k/boot && objtype=arm64 mk -f mkfile.arm64) || fail "boot(8) arm64 build"
		cp /sys/src/9k/boot/boot "$HARVEY/build/aarch64/out/boot" || fail "harvest boot to out/"
		(cd /sys/src/9k/boot && objtype=arm64 mk -f mkfile.arm64 clean) || fail "boot dir clean"
		art="$HARVEY/build/aarch64/out/boot"
		;;
	stage/init)
		# init installs via cmd's per-target rule — cmd/mkfile's
		# special $BIN/init rule lands it at /arm64/init (boot's
		# execinit builds /$objtype/init), so harvest from there, not
		# /arm64/bin.
		(cd /sys/src/cmd && objtype=arm64 mk init.install) || fail "init.install"
		cp /arm64/init "$HARVEY/build/aarch64/out/init" || fail "harvest init to out/"
		art="$HARVEY/build/aarch64/out/init"
		;;
	stage/stacksmoke)
		# the deep-recursion binary (build/aarch64/stacksmoke.c),
		# recompiled here so it ships in the real image too.
		(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw stacksmoke.c \
			&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/stacksmoke" stacksmoke.7 \
			&& rm -f stacksmoke.7) || fail "stacksmoke"
		art="$HARVEY/build/aarch64/out/stacksmoke"
		;;
	cmd/cc)
		# the shared frontend: tier evidence is the cc.a7 archive the
		# 7c build links.  Fresh-archive hygiene mirrors D-07 (mklib's
		# ar vu is the same never-prune rule).
		rm -f /sys/src/cmd/cc/cc.a7
		(cd /sys/src/cmd/cc && objtype=arm64 mk install) || fail "cmd cc"
		art=/sys/src/cmd/cc/cc.a7
		;;
	cmd/*:*)
		# dir:target — per-target install in the dir (the mkmany
		# %.install rule), never the whole dir TARG.
		dir="${entry%%:*}"
		tgt="${entry##*:}"
		(cd "/sys/src/$dir" && objtype=arm64 mk "$tgt.install") || fail "cmd $entry"
		art="/arm64/bin/${dir#cmd/}"
		# paqfs is also harvested to out/ — mkimage.sh's manifest names
		# out/paqfs (the boot chain's image supply contract).
		if [ "$tgt" = "paqfs" ]; then
			cp /arm64/bin/paqfs "$HARVEY/build/aarch64/out/paqfs" || fail "harvest paqfs to out/"
		fi
		;;
	cmd/*)
		# dir vs single-file: a dir entry recurses its own mkfile; a
		# single builds via cmd's per-target install rule.
		if [ -d "/sys/src/$entry" ]; then
			(cd "/sys/src/$entry" && objtype=arm64 mk install) || fail "cmd $entry"
		else
			(cd /sys/src/cmd && objtype=arm64 mk "${entry#cmd/}.install") || fail "cmd $entry"
		fi
		art="/arm64/bin/${entry#cmd/}"
		;;
	*)
		fail "tier1 entry form not understood: $entry"
		;;
	esac
	[ -s "$art" ] || fail "$entry: no artifact $art"
	echo "T1-ART ${art##*/} $(sha256sum "$art" | cut -d' ' -f1)"
done < "$TIER1"

# 07-04: dd joins the image (D-07 names dd as the sweep's writer) —
# dd.c is single-file, u.h+libc.h only, so no new libs enter the
# closure.  Separate additive line (not folded into the tier-1 loop) so
# this phase's edits stay insertion-only against the parallel Phase 6
# tier machinery touching the same regions.  (dd appends to
# tier1-cmds.txt when its Phase-6 execution gate passes — 06-06; the
# 07-04 net venue already proved it on the donor.)
echo "== subset cmd: dd (per-target install, 07-04)"
(cd /sys/src/cmd && objtype=arm64 mk dd.install) || fail "cmd dd (per-target install)"

# 07-07: bind joins the image — the net-sweep's `bind -a '#l' /net`
# forks/execs /bin/bind (bind is NOT an rc builtin; the boot chain's own
# binds are init's /lib/namespace interpretation, a different mechanism).
# bind.c is single-file, u.h+libc.h only.  Same insertion-only shape as dd.
echo "== subset cmd: bind (per-target install, 07-07)"
(cd /sys/src/cmd && objtype=arm64 mk bind.install) || fail "cmd bind (per-target install)"

# 07-04: netblast, the D-08 TX-bulk generator, joins the image supply
# chain beside stacksmoke (same compile/harvest shape)
echo "== boot chain: netblast (07-04, D-08)"
(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw netblast.c \
	&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/netblast" netblast.7 \
	&& rm -f netblast.7) || fail "netblast"

# 08-03: the Phase-8 gate binaries (NETIP-03..07) build from the full
# tree as Phase-8-owned payload rules (D-12 — NOT tier-allowlist
# appends; the Phase 6 tier data files stay untouched).  Each binary is
# harvested to out/ beside netblast so the host-side magic contract and
# mkimage.sh's manifest asserts name it.  ipconfig is also a tier-1
# entry (the v1.0 closure) — this block's re-install is idempotent
# (mk sees it up-to-date); the harvest-to-out/ is the new payload
# surface.  Insertion-only beside the 07-04/07-07 blocks per the same
# Phase-6 collision-avoidance rule (07-04 precedent).
echo "== subset cmd: ipconfig (dir install + out/ harvest, 08-03)"
(cd /sys/src/cmd/ip/ipconfig && objtype=arm64 mk install) || fail "cmd ip/ipconfig (dir install)"
cp /arm64/bin/ip/ipconfig "$HARVEY/build/aarch64/out/ipconfig" || fail "harvest ipconfig to out/"

echo "== subset cmd: ping (per-target install + out/ harvest, 08-03)"
(cd /sys/src/cmd/ip && objtype=arm64 mk ping.install) || fail "cmd ip ping (per-target install)"
cp /arm64/bin/ip/ping "$HARVEY/build/aarch64/out/ping" || fail "harvest ping to out/"

echo "== subset cmd: udpecho (per-target install + out/ harvest, 08-03)"
(cd /sys/src/cmd/ip && objtype=arm64 mk udpecho.install) || fail "cmd ip udpecho (per-target install)"
cp /arm64/bin/ip/udpecho "$HARVEY/build/aarch64/out/udpecho" || fail "harvest udpecho to out/"

# 08-03: aan links libthread + libauth via #pragma autolib off the
# tier-0 archives the loop above just rebuilt (Phase 2 landed
# libthread's arm64 port; the closure is tier-0-complete).
echo "== subset cmd: aan (per-target install + out/ harvest, 08-03)"
(cd /sys/src/cmd && objtype=arm64 mk aan.install) || fail "cmd aan (per-target install)"
cp /arm64/bin/aan "$HARVEY/build/aarch64/out/aan" || fail "harvest aan to out/"

# 20-07: ramfs joins the image as the r9 writable venue under
# measurement (D-09; /lib/writeprobe.rc mounts it on the baked /n/wp).
# NOT a tier-list member — tiers/tier1-cmds.txt feeds three computed
# expected-marker sets, and nothing emits a T1-OK ramfs.  Same
# per-target install shape as dd and aan; the whole arm64/bin tree is
# pulled back below.
echo "== subset cmd: ramfs (per-target install, 20-07 r9 writable venue)"
(cd /sys/src/cmd && objtype=arm64 mk ramfs.install) || fail "cmd ramfs (per-target install)"

# 08-03: tcpblast + tcpecho — the NETIP-08 bidirectional soak machinery
# (D-15: slirp proof now, the tap truth verdict is Phase 9's joint gate)
# and the NETIP-03 tcp/7 echo server.  New payload sources living beside
# netblast.c; same 7c -FTVw + 7l compile/harvest shape as netblast.
echo "== boot chain: tcpblast (08-03, NETIP-08/D-15)"
(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw tcpblast.c \
	&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/tcpblast" tcpblast.7 \
	&& rm -f tcpblast.7) || fail "tcpblast"
echo "== boot chain: tcpecho (08-03, NETIP-03)"
(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw tcpecho.c \
	&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/tcpecho" tcpecho.7 \
	&& rm -f tcpecho.7) || fail "tcpecho"
# 20-02: forkstress — the fork-image integrity stressor (WINDOWS #49
# reproducer, rc out of the picture).  Baked into the image; no gate
# calls it yet (20-03 wires it).  Same 7c -FTVw + 7l shape as tcpblast.
echo "== boot chain: forkstress (20-02, WINDOWS #49 reproducer)"
(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw forkstress.c \
	&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/forkstress" forkstress.7 \
	&& rm -f forkstress.7) || fail "forkstress"
# 20-07: rfdprobe — the bare rfork(RFFDG)/rfork(RFCFDG) fd-group split
# probe (inventory b4), run by /lib/writeprobe.rc's fdsplit step.  Baked
# into the image; no gate calls it.  Same 7c -FTVw + 7l shape.
echo "== boot chain: rfdprobe (20-07, b4 non-RFPROC fd split probe)"
(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw rfdprobe.c \
	&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/rfdprobe" rfdprobe.7 \
	&& rm -f rfdprobe.7) || fail "rfdprobe"
# 20-07: brkprobe — the lone-member RFMEM brk growth probe (D-09).
# Baked into the image; no gate calls it.  Same 7c -FTVw + 7l shape.
echo "== boot chain: brkprobe (20-07, lone-member RFMEM brk probe)"
(cd "$HARVEY/build/aarch64" && objtype=arm64 7c -FTVw brkprobe.c \
	&& objtype=arm64 7l -o "$HARVEY/build/aarch64/out/brkprobe" brkprobe.7 \
	&& rm -f brkprobe.7) || fail "brkprobe"

# 06-05: tier-0 lib test binaries (D-06 — in-tree lib tests run on the
# donor where they exist; subset-exec.sh stages them h*-style and the
# sweep's libtest markers are the libs' exec=TEST:donor evidence).
# Built per-target AFTER the tier-0 loop so each tests against the fresh
# archive; harvested to out/ (gitignored) and cleaned from the lib dirs
# so the guest tree stays pristine.  liboventi's $O.vttest is a stale
# mkfile target (no vttest.c exists) — documented in 06-EVIDENCE.md,
# never built.  libdisk's $O.test + libmemdraw's $O.drawtest/$O.arctest
# are the in-tree targets; libdraw's $O.test is the additive rule this
# wave adds (test.c had no rule).
echo "== tier-0 lib test binaries (06-05, D-06)"
(cd /sys/src/libmemdraw && objtype=arm64 mk 7.drawtest 7.arctest) || fail "libmemdraw test binaries"
cp /sys/src/libmemdraw/7.drawtest "$HARVEY/build/aarch64/out/hdrawtest" || fail "harvest hdrawtest"
cp /sys/src/libmemdraw/7.arctest "$HARVEY/build/aarch64/out/harctest" || fail "harvest harctest"
rm -f /sys/src/libmemdraw/7.drawtest /sys/src/libmemdraw/7.arctest \
	/sys/src/libmemdraw/drawtest.7 /sys/src/libmemdraw/arctest.7
(cd /sys/src/libdraw && objtype=arm64 mk 7.test) || fail "libdraw test binary"
cp /sys/src/libdraw/7.test "$HARVEY/build/aarch64/out/htdraw" || fail "harvest htdraw"
rm -f /sys/src/libdraw/7.test /sys/src/libdraw/test.7
(cd /sys/src/libdisk && objtype=arm64 mk 7.test) || fail "libdisk test binary"
cp /sys/src/libdisk/7.test "$HARVEY/build/aarch64/out/hdisktest" || fail "harvest hdisktest"
rm -f /sys/src/libdisk/7.test /sys/src/libdisk/test.7

echo "== tier tree (/arm64/bin):"
ls /arm64/bin
echo "-- ip:"
ls /arm64/bin/ip
echo "-- auth:"
ls /arm64/bin/auth

echo "TIER-BUILD-OK"
GUEST_EOF

mkdir -p "$HARVEY/.build"
set +e
if [ -n "$NATIVE_LINUX" ]; then
	echo "== running the subset build natively (sudo unshare namespace; log: $LOG)"
	# hostbin FIRST so the namespace's mk/7a/7c/7l/ar resolve (the
	# devshell's PATH shape); nsrun.sh's su line appends /rc/bin:.
	# itself.
	export PATH="$HARVEY_LINUX_BIN:$PATH"
	bash "$HARVEY/build/aarch64/nsrun.sh" --wrap "bash $TMPD/subset-build-guest.sh" > "$LOG" 2>&1
else
	echo "== pushing the guest subset-build script"
	rsync -a -e "$RSYNC_RSH" "$TMPD/subset-build-guest.sh" "$GUEST:/tmp/gsd-subset-build-guest.sh"
	echo "== running the subset build in the guest namespace (log: $LOG)"
	sh "$HARVEY/build/aarch64/vm-run.sh" 'bash /tmp/gsd-subset-build-guest.sh' > "$LOG" 2>&1
fi
RC=$?
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: guest tier build failed (rc=$RC); log: $LOG" >&2
	echo "hint: the log names the first failing mk step (TIER-BUILD-FAIL: <entry>)" >&2
	exit $RC
fi
"$GREP" -q 'TIER-BUILD-OK' "$LOG" || err "guest build log lacks TIER-BUILD-OK"

if [ -z "$NATIVE_LINUX" ]; then
	# rsync the resulting /arm64/bin tree back to the host checkout
	# (gitignored: /arm64/*bin)
	echo "== pulling the subset tree back to host arm64/bin"
	mkdir -p "$HARVEY/arm64/bin"
	rsync -a --delete -e "$RSYNC_RSH" \
		"$GUEST:$GUEST_DIR/arm64/bin/" "$HARVEY/arm64/bin/"

	# 06-05: pull the tier-0 library archives back too (gitignored:
	# /arm64/lib) — the 06-05 artifact gate asserts host-side
	# $HARVEY/arm64/lib/*.a, and on darwin nothing else lands them
	# host-side.  --delete mirrors the guest exactly; the D-07
	# fresh-archive rule makes the guest set the truth.
	echo "== pulling the tier-0 library archives back to host arm64/lib"
	mkdir -p "$HARVEY/arm64/lib"
	rsync -a --delete -e "$RSYNC_RSH" \
		"$GUEST:$GUEST_DIR/arm64/lib/" "$HARVEY/arm64/lib/"

	# Pull the boot-chain binaries back to the host's gitignored
	# build/aarch64/out/.  Individual-file sync (no --delete):
	# stage-build.sh owns out/ wholesale for the staged-init supply chain
	# (--delete there) — last writer wins; mkimage.sh's manifest assert
	# names subset-build.sh as the fix when its inputs are absent.
	echo "== pulling the boot-chain binaries back to host build/aarch64/out"
	mkdir -p "$HARVEY/build/aarch64/out"
	rsync -a -e "$RSYNC_RSH" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/boot" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/init" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/paqfs" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/stacksmoke" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/netblast" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/ipconfig" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/ping" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/udpecho" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/aan" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/tcpblast" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/tcpecho" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/forkstress" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/rfdprobe" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/brkprobe" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/hdrawtest" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/harctest" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/htdraw" \
		"$GUEST:$GUEST_DIR/build/aarch64/out/hdisktest" \
		"$HARVEY/build/aarch64/out/"
else
	# native linux: the namespace bound the real checkout — the subset
	# tree and out/ binaries are already in place.
	echo "== native build: artifacts already in place (no rsync-back)"
fi

# assert the sixteen expected binaries on the host side
for f in rc grep cat cp date echo ls mkdir mv ps rm sed test wc; do
	[ -x "$HARVEY/arm64/bin/$f" ] || err "arm64/bin/$f missing after rsync-back"
done
# 07-04: the seventeenth — dd (D-07's sweep writer)
[ -x "$HARVEY/arm64/bin/dd" ] || err "arm64/bin/dd missing after rsync-back"
# 07-07: the eighteenth — bind (the net-sweep's `bind -a '#l' /net`)
[ -x "$HARVEY/arm64/bin/bind" ] || err "arm64/bin/bind missing after rsync-back"
# 20-07: ramfs (the writable venue under measurement; not a tier member)
[ -x "$HARVEY/arm64/bin/ramfs" ] || err "arm64/bin/ramfs missing after rsync-back"
[ -x "$HARVEY/arm64/bin/ip/ipconfig" ] || err "arm64/bin/ip/ipconfig missing after rsync-back"
[ -x "$HARVEY/arm64/bin/auth/factotum" ] || err "arm64/bin/auth/factotum missing after rsync-back"
# 06-03: the tracer's additions — awk (G1 generator path) and the
# tier-file-driven guest build chain (7a/7c/7l as arm64 targets)
[ -x "$HARVEY/arm64/bin/awk" ] || err "arm64/bin/awk missing after rsync-back"
magic=$(od -An -tx1 -N4 "$HARVEY/arm64/bin/awk" | tr -d ' \n')
[ "$magic" = "00008c47" ] || err "arm64/bin/awk: bad magic $magic (want 00008c47)"
for t in 7a 7c 7l; do
	[ -x "$HARVEY/arm64/bin/$t" ] || err "arm64/bin/$t missing after rsync-back"
done

# Every boot-chain binary must carry the arm64 a.out magic
# (R_MAGIC 0x8C47, BE)
for f in boot init paqfs stacksmoke; do
	[ -s "$HARVEY/build/aarch64/out/$f" ] || err "build/aarch64/out/$f missing after rsync-back"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/aarch64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008c47" ] || err "build/aarch64/out/$f: bad magic $magic (want 00008c47)"
done
# 07-04: netblast carries the same magic contract
[ -s "$HARVEY/build/aarch64/out/netblast" ] || err "build/aarch64/out/netblast missing after rsync-back"
magic=$(od -An -tx1 -N4 "$HARVEY/build/aarch64/out/netblast" | tr -d ' \n')
[ "$magic" = "00008c47" ] || err "build/aarch64/out/netblast: bad magic $magic (want 00008c47)"
# 08-03: the six Phase-8 gate binaries (and 20-02's forkstress) carry
# the same magic contract
for f in ipconfig ping udpecho aan tcpblast tcpecho forkstress; do
	[ -s "$HARVEY/build/aarch64/out/$f" ] || err "build/aarch64/out/$f missing after rsync-back"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/aarch64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008c47" ] || err "build/aarch64/out/$f: bad magic $magic (want 00008c47)"
done
# 20-07: the group-B measurement probes carry the same magic contract
for f in rfdprobe brkprobe; do
	[ -s "$HARVEY/build/aarch64/out/$f" ] || err "build/aarch64/out/$f missing after rsync-back"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/aarch64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008c47" ] || err "build/aarch64/out/$f: bad magic $magic (want 00008c47)"
done
# 06-05: the tier-0 lib test binaries carry the same magic contract
for f in hdrawtest harctest htdraw hdisktest; do
	[ -s "$HARVEY/build/aarch64/out/$f" ] || err "build/aarch64/out/$f missing after rsync-back"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/aarch64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008c47" ] || err "build/aarch64/out/$f: bad magic $magic (want 00008c47)"
done

echo "== PASS: arm64 tier-0/tier-1 set built and installed ($(ls "$HARVEY/arm64/bin" | wc -l | tr -d ' ') entries in arm64/bin; log: $LOG)"
