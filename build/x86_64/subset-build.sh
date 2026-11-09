#!/bin/sh
# build/x86_64/subset-build.sh — the amd64 tier-0/tier-1 userspace
# namespace build driver (14-08, XEXEC-04: the aarch64
# build/aarch64/subset-build.sh discipline re-keyed to objtype=amd64 —
# re-key, don't reinvent).  Builds, with objtype=amd64 under the Plan 9
# mount namespace (linux-native only: the 14-05 venue split — sudo
# unshare via nsrun.sh when the host grants passwordless sudo, the
# unprivileged user+mount namespace with the tmpfs chroot scaffold
# otherwise; there is NO lima leg on x64):
#
#   - the tier-0 library allowlist (build/x86_64/tiers/tier0-libs.txt)
#     with the D-07 fresh-archive rule (rm -f the target .a before
#     mk install — ar vu never prunes, the 02-10 staleness class) + a
#     T0-ART sha256 marker per lib;
#   - the tier-1 allowlist (build/x86_64/tiers/tier1-cmds.txt)
#     dispatched per entry form (cmd/<single> link-only per-target —
#     the 14-07 venue lesson: mkmany-family $BIN recipes that stage
#     /bin/cp die inside the userns chroot, so singles link via
#     `mk 6.<cmd>` and the driver's own cp harvests; cmd/<dir> dir
#     install; cmd/<container>/<dir> nested; cmd/<dir>:<target>
#     per-target install; 9k/boot + stage/init driver-only blocks)
#     with a T1-ART sha256 marker per artifact.
#   - the tier-2 services allowlist (15-01, USPACE-07's compile half:
#     build/x86_64/tiers/tier2-services.txt) with the 06-03
#     anti-staleness decision LANDED here — a per-entry fresh build
#     (mk <target>.clean / in-tree object rm before every build) so a
#     stale object can never earn a marker — and a T2-ART sha256
#     marker + 00008a97 magic check per harvested binary.
#
# Artifacts install to the namespace's /amd64 (the checkout's amd64/ —
# gitignored): /amd64/lib/*.a, /amd64/bin/*.  The k10t1 venue kernel
# embeds from /amd64/bin and the r9 tier image (mkimage.sh's tier bake)
# stages from the same paths — ONE build feeds BOTH venues (the
# identical-6.outs ABI witness, T-14-15).  The boot-chain driver-only
# entries additionally harvest to build/x86_64/out/ (the chain image's
# supply home, the 14-06 separation).
#
# Markers: T0-ART <lib> <sha256>, T1-ART <bin> <sha256>, TIER-BUILD-OK
# (mk exit status is never trusted — 02-12; artifact asserts + markers
# are the only gates).
#
# usage: sh build/x86_64/subset-build.sh   (repo root, inside the nix
# devshell or the flake app wrapper)

set -eu

HARVEY="${HARVEY:-$PWD}"
LOG="${SUBSET_BUILD_LOG:-$HARVEY/.build/subset-build-x64.log}"
TIER0="$HARVEY/build/x86_64/tiers/tier0-libs.txt"
TIER1="$HARVEY/build/x86_64/tiers/tier1-cmds.txt"

err() { echo "error: $*" >&2; exit 1; }

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on NixOS-class
# hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -f "$TIER0" ] || err "tier0 data file missing: $TIER0"
[ -f "$TIER1" ] || err "tier1 data file missing: $TIER1"
[ -f "$HARVEY/sys/src/9k/boot/mkfile.amd64" ] || err "sys/src/9k/boot/mkfile.amd64 missing (the 14-06 driver-only boot build)"
[ -d "$HARVEY/amd64" ] || err "amd64/ arch dir missing"
[ "$(uname -s)" = "Linux" ] || err "build/x86_64/subset-build.sh is native-linux only (sudo unshare / userns chroot; no lima leg — the aarch64 driver's darwin venue does not carry)"

# 15-01: the phase build-tree lock — /amd64 is untracked shared state,
# and every later driver that writes or harvests it (15-02's venue
# scripts, 15-05's build-9kdraw.sh, 15-07's coverage-sweep.sh + the gs
# harness) takes this SAME lock (flock on .build/amd64-tree.lock), so
# same-wave parallel plans can never interleave /amd64 writers.  The fd
# stays open for the whole run — the lock releases at exit.
command -v flock >/dev/null 2>&1 || err "flock not found — the amd64 build-tree lock needs util-linux flock"
mkdir -p "$HARVEY/.build"
exec 9>"$HARVEY/.build/amd64-tree.lock"
flock 9 || err "cannot acquire the amd64 build-tree lock"
echo "== amd64 build-tree lock held: $HARVEY/.build/amd64-tree.lock"

# host toolchain for the namespace build (subset-build.sh's ensure,
# host-side).  HARVEY must be EXPORTED here: the userns venue's --wrap
# captures `export` output and the chroot scaffold re-roots it inside.
export HARVEY
HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-x86_64/bin}"
export HARVEY_LINUX_BIN
if [ ! -x "$HARVEY_LINUX_BIN/6c" ] || [ ! -x "$HARVEY_LINUX_BIN/ar" ]; then
	echo "== host toolchain missing — bootstrapping (nix run .#setup && nix run .#toolchain)"
	(cd "$HARVEY" && nix run .#setup && nix run .#toolchain) || err "host toolchain bootstrap failed"
fi

# the devshell-env vars the guest script's mk invocations expect
export FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/subset-build-x64.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

# namespace-side script (the single-committed-file discipline): written
# to a host tmp file, executed inside the Plan 9 mount namespace.  Never
# committed; the host driver regenerates it each run.
cat > "$TMPD/subset-build-x64-guest.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# subset-build-x64-guest.sh — namespace side of
# build/x86_64/subset-build.sh (14-08).  Runs inside the Plan 9 mount
# namespace: /sys is the checkout's sys, /amd64 the committed arch dir
# ($HARVEY is the checkout's own path under the sudo venue, /harvey
# under the userns-chroot venue).  Never committed; the host driver
# regenerates it each run.
set -e

fail() { echo "TIER-BUILD-FAIL: $1" >&2; exit 1; }

echo "== subset build provenance (Harvey's vendored toolchain):"
echo "   6c: $(command -v 6c)"
echo "   6a: $(command -v 6a)"
echo "   6l: $(command -v 6l)"
echo "   ar: $(command -v ar)"
echo "   mk: $(command -v mk)"

# nm shim (nix/build.sh's idiom, mirrored): host-toolchain generator
# sub-builds (cmd/awk's $cputype.maketab chain — G1) link with plan9port
# 9l, whose autolib execs bare `nm` on HOST ELF objects; with
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

# the namespace binds $HARVEY/amd64 at /amd64; mkdirs lays out the
# bin/lib tree it needs (the stage-build/subset-build note)
cd "$HARVEY" && bash build/mkdirs || fail "mkdirs"

# libc bootstrap (idempotent, line 1 of the tier-0 loop anyway — the
# aarch64 primacy rule, kept explicit so the loop never links against a
# half-installed libc on a fresh tree)
echo "== tier0 lib: libc (explicit bootstrap, idempotent)"
rm -f /amd64/lib/libc.a
(cd /sys/src/libc && objtype=amd64 mk install) || fail "lib libc (bootstrap)"
[ -s /amd64/lib/libc.a ] || fail "lib libc: no artifact /amd64/lib/libc.a"
echo "T0-ART libc $(sha256sum /amd64/lib/libc.a | cut -d' ' -f1)"

# tier-0 libraries: the append-only allowlist drives the sweep (libc is
# line 1 and just bootstrapped — the loop re-installs it idempotently).
# D-07 fresh-archive per lib: mksyslib's `ar vu $LIB $newprereq` rule is
# append-only and never prunes, so the target .a is deleted before
# repopulating.  Artifact assert + T0-ART sha256 marker per lib (mk
# exit status is never trusted — 02-12).
TIER0="$HARVEY/build/x86_64/tiers/tier0-libs.txt"
[ -f "$TIER0" ] || fail "tier0 data file missing: $TIER0"
while read -r line; do
	case "$line" in ''|'#'*) continue;; esac
	d="${line%%[ 	]*}"
	case "$d" in ''|'#'*) continue;; esac
	# liblex's archive is libl.a (the lex runtime's historical name);
	# the lib<dir-minus-lib> default holds for every other swept lib
	case "$d" in
	liblex)	lib="libl.a";;
	*)	lib="lib${d#lib}.a";;
	esac
	echo "== tier0 lib: $d"
	rm -f "/amd64/lib/$lib"
	(cd "/sys/src/$d" && objtype=amd64 mk install) || fail "lib $d"
	[ -s "/amd64/lib/$lib" ] || fail "lib $d: no artifact /amd64/lib/$lib"
	echo "T0-ART $d $(sha256sum "/amd64/lib/$lib" | cut -d' ' -f1)"
done < "$TIER0"

# tier-1 commands: the allowlist, dispatched per entry form.  The
# 14-07 venue lesson rides the single-file dispatch: cmd/mkfile's
# $BIN/% rule stages /bin/cp as ._cp (a dynamic host binary with no
# interpreter inside the userns chroot), so singles link via
# `mk 6.<cmd>` and the DRIVER's cp harvests — never <cmd>.install.  Dir
# entries (rc/awk/grep/ipconfig/paqfs — mkone/mkmany mkfiles of their
# own with bare-cp install recipes) install normally.  A failing entry
# aborts the BUILD (fail) — the build side is not the sweep;
# USPACE-04's never-wedge edge belongs to tier1-sweep.rc.
TIER1="$HARVEY/build/x86_64/tiers/tier1-cmds.txt"
[ -f "$TIER1" ] || fail "tier1 data file missing: $TIER1"
mkdir -p "$HARVEY/build/x86_64/out"
while read -r line; do
	case "$line" in ''|'#'*) continue;; esac
	entry="${line%%[ 	]*}"
	case "$entry" in ''|'#'*) continue;; esac
	echo "== tier1 entry: $entry"
	case "$entry" in
	9k/boot)
		# boot(8) via the additive, objtype-gated mkfile.amd64
		# (the 14-06-proven build).  Build in-tree, harvest to out/
		# (gitignored, the chain image's supply home), then clean the
		# boot dir so the checkout stays pristine.
		(cd /sys/src/9k/boot && objtype=amd64 mk -f mkfile.amd64) || fail "boot(8) amd64 build"
		cp /sys/src/9k/boot/boot "$HARVEY/build/x86_64/out/boot" || fail "harvest boot to out/"
		(cd /sys/src/9k/boot && objtype=amd64 mk -f mkfile.amd64 clean) || fail "boot dir clean"
		art="$HARVEY/build/x86_64/out/boot"
		;;
	stage/init)
		# init installs via cmd's special $BIN/init rule (lands at
		# /amd64/init — never a mkmany $BIN path, so the chroot
		# lesson does not bite), harvested to out/ from there.
		(cd /sys/src/cmd && objtype=amd64 mk init.install) || fail "init.install"
		cp /amd64/init "$HARVEY/build/x86_64/out/init" || fail "harvest init to out/"
		art="$HARVEY/build/x86_64/out/init"
		;;
	cmd/cc)
		# the shared frontend: tier evidence is the cc.a6 archive the
		# 6c build links (Phase 15's toolchain tier; carried from the
		# aarch64 driver so the entry form needs no new dispatch).
		rm -f /sys/src/cmd/cc/cc.a6
		(cd /sys/src/cmd/cc && objtype=amd64 mk install) || fail "cmd cc"
		art=/sys/src/cmd/cc/cc.a6
		;;
	cmd/*:*)
		# dir:target — per-target install in the dir (the mkmany
		# %.install rule, a bare-cp recipe), never the whole dir TARG
		# (factotum's sibling fgui needs the out-of-tier graphics
		# stack; paqfs keeps mkpaqfs host-only).
		dir="${entry%%:*}"
		tgt="${entry##*:}"
		(cd "/sys/src/$dir" && objtype=amd64 mk "$tgt.install") || fail "cmd $entry"
		art="/amd64/bin/${dir#cmd/}"
		# paqfs is also harvested to out/ — the image bake names
		# out/paqfs (the boot chain's supply contract)
		if [ "$tgt" = "paqfs" ]; then
			cp /amd64/bin/paqfs "$HARVEY/build/x86_64/out/paqfs" || fail "harvest paqfs to out/"
		fi
		;;
	cmd/*)
		if [ -d "/sys/src/$entry" ]; then
			# dir entry: its own mkfile (mkone/mkmany family) —
			# install works on both venues (bare cp)
			(cd "/sys/src/$entry" && objtype=amd64 mk install) || fail "cmd $entry"
			art="/amd64/bin/${entry#cmd/}"
		else
			# single-file command: LINK-ONLY (mk 6.<cmd>) + the
			# driver's cp harvest (the 14-07 ._cp lesson), then the
			# targeted droppings rm — never a blanket cmd clean
			# (jpg's committed generated tables, the Phase-6
			# workaround)
			name="${entry#cmd/}"
			(cd /sys/src/cmd && objtype=amd64 mk "6.$name") || fail "cmd $entry"
			cp "/sys/src/cmd/6.$name" "/amd64/bin/$name" || fail "harvest $name"
			rm -f "/sys/src/cmd/6.$name" "/sys/src/cmd/$name.6"
			art="/amd64/bin/$name"
		fi
		;;
	*)
		fail "tier1 entry form not understood: $entry"
		;;
	esac
	[ -s "$art" ] || fail "$entry: no artifact $art"
	echo "T1-ART ${art##*/} $(sha256sum "$art" | cut -d' ' -f1)"
done < "$TIER1"

# 14-08: bind joins the install set — NOT a tier-1 member (never swept,
# no marker): the k10t1 donor embed names /amd64/bin/bind in its rootdir
# (k10t1's `bind '#p' /proc` boot plumbing), so the venue precondition
# needs it from THIS build (the aarch64 subset driver's 07-07
# insertion-only shape, re-keyed link-only per the 14-07 .$O-lesson:
# cmd/mkfile's $BIN recipe cp does not resolve in the userns chroot).
echo "== subset cmd: bind (link-only + harvest, the donor embed's member)"
(cd /sys/src/cmd && objtype=amd64 mk 6.bind) || fail "cmd bind (link-only)"
cp /sys/src/cmd/6.bind /amd64/bin/bind || fail "harvest bind"
rm -f /sys/src/cmd/6.bind /sys/src/cmd/bind.6
[ -s /amd64/bin/bind ] || fail "bind: no artifact /amd64/bin/bind"

# 14-09 (XEXEC-05, D-07): the NET-gate payload — NOT tier-1 members
# (never swept, no markers; the bind precedent): the ip container's
# link-only pair ping/udpecho (mkmany's $BIN/% recipe stages its cp as
# ._<name> inside the userns chroot — the 14-07 measured lesson, so
# singles link via `mk 6.<cmd>' and THIS script's cp harvests; the
# mkmany generic rules survive the tier filter — TARG only drives the
# install aggregation), the write-flow-excluded dd (the net fixtures'
# one-read discipline needs it; link-only for the same reason), and
# the three 6c C helpers from build/x86_64 (netblast/tcpblast/tcpecho
# — the 08-03 compiled-payload shape re-keyed), harvested to out/ (the
# NET bake's supply home, alongside boot/init/paqfs).
echo "== net cmd: ping (link-only + harvest, the ip container)"
(cd /sys/src/cmd/ip && objtype=amd64 mk 6.ping) || fail "cmd ip ping (link-only)"
cp /sys/src/cmd/ip/6.ping /amd64/bin/ip/ping || fail "harvest ping"
rm -f /sys/src/cmd/ip/6.ping /sys/src/cmd/ip/ping.6
[ -s /amd64/bin/ip/ping ] || fail "ping: no artifact /amd64/bin/ip/ping"

echo "== net cmd: udpecho (link-only + harvest, the ip container)"
(cd /sys/src/cmd/ip && objtype=amd64 mk 6.udpecho) || fail "cmd ip udpecho (link-only)"
cp /sys/src/cmd/ip/6.udpecho /amd64/bin/ip/udpecho || fail "harvest udpecho"
rm -f /sys/src/cmd/ip/6.udpecho /sys/src/cmd/ip/udpecho.6
[ -s /amd64/bin/ip/udpecho ] || fail "udpecho: no artifact /amd64/bin/ip/udpecho"

echo "== net cmd: dd (link-only + harvest, the one-read discipline)"
(cd /sys/src/cmd && objtype=amd64 mk 6.dd) || fail "cmd dd (link-only)"
cp /sys/src/cmd/6.dd /amd64/bin/dd || fail "harvest dd"
rm -f /sys/src/cmd/6.dd /sys/src/cmd/dd.6
[ -s /amd64/bin/dd ] || fail "dd: no artifact /amd64/bin/dd"

for h in netblast tcpblast tcpecho; do
	echo "== net helper: build/x86_64/$h.c -> out/$h (6c/6l)"
	(cd "$HARVEY/build/x86_64" && objtype=amd64 6c -FTVw "$h.c" && objtype=amd64 6l -o "$HARVEY/build/x86_64/out/$h" "$h.6" && rm -f "$h.6") || fail "net helper $h"
	[ -s "$HARVEY/build/x86_64/out/$h" ] || fail "net helper $h: no artifact out/$h"
done

# tier-2 services (15-01, USPACE-07's compile half): the allowlist,
# dispatched per entry form with the 06-03 anti-staleness decision
# LANDED HERE (tier-2 is the first mass cmd wave since the toolchain
# fixes): a per-entry fresh build — `mk <target>.clean` / the in-tree
# object rm BEFORE every build — so a stale object can never earn a
# marker (mk's freshness graph never names the toolchain; the
# donor-vm-build step-4b precedent, the tier-0 D-07 fresh-archive
# sibling).  T2-ART <bin> <sha256> per harvested binary, each
# magic-checked 00008a97 (mk exit status is never trusted — artifact
# asserts are the only gates).  A dir entry yields one marker per
# binary the dir installed (>= 1); the entry forms: cmd/<dir> (whole
# dir — its own or no filter governs members), cmd/<single> and
# cmd/<container>/<single> (link-only + driver cp harvest), and the
# container leaf cmd/<container>:<target> (per-target clean + link-only
# + driver cp — aux's aggregate install never installs TARG members,
# and the leaf filter in the container's mkfile scopes the default
# build).
TIER2="$HARVEY/build/x86_64/tiers/tier2-services.txt"
[ -f "$TIER2" ] || fail "tier2 data file missing: $TIER2"
t2art() {
	f="$1"
	[ -s "$f" ] || fail "tier2: no artifact $f"
	magic=$(od -An -tx1 -N4 "$f" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || fail "tier2 ${f##*/}: bad magic $magic (want 00008a97 — amd64 S_MAGIC)"
	echo "T2-ART ${f##*/} $(sha256sum "$f" | cut -d' ' -f1)"
}
while read -r line; do
	case "$line" in ''|'#'*) continue;; esac
	entry="${line%%[ 	]*}"
	case "$entry" in ''|'#'*) continue;; esac
	echo "== tier2 entry: $entry"
	case "$entry" in
	cmd/*:*)
		# container leaf (cmd/aux:<target>): per-target clean (the
		# mkmany %.clean removes <t>.6/6.<t>/<t> in-tree — fresh
		# objects), link-only in the container, driver cp harvest
		# to /amd64/bin/<target>, then the droppings rm.
		dir="${entry%%:*}"
		tgt="${entry##*:}"
		(cd "/sys/src/$dir" && objtype=amd64 mk "$tgt.clean") || fail "tier2 clean $entry"
		rm -f "/amd64/bin/$tgt"
		(cd "/sys/src/$dir" && objtype=amd64 mk "6.$tgt") || fail "tier2 $entry"
		cp "/sys/src/$dir/6.$tgt" "/amd64/bin/$tgt" || fail "tier2 harvest $tgt"
		rm -f "/sys/src/$dir/6.$tgt" "/sys/src/$dir/$tgt.6"
		t2art "/amd64/bin/$tgt"
		;;
	cmd/*)
		if [ -d "/sys/src/$entry" ]; then
			# dir entry: whole-dir clean (fresh objects), install,
			# one marker per installed binary — located by mtime
			# against a pre-install stamp, because member mkfiles
			# disagree about BIN (ndb/dial -> bin/<dir>; ppp/dhcpd/
			# imap4d -> bin/ip; ftpfs/snoopy/exportfs -> bin root;
			# httpd -> bin/ip/httpd) — then clean again (droppings —
			# the checkout IS the build tree; never blanket).
			(cd "/sys/src/$entry" && objtype=amd64 mk clean) || fail "tier2 clean $entry"
			stamp=$(mktemp)
			(cd "/sys/src/$entry" && objtype=amd64 mk install) || { rm -f "$stamp"; fail "tier2 $entry"; }
			found=0
			for f in $(find /amd64/bin -type f -newer "$stamp" | sort); do
				t2art "$f"
				found=$((found+1))
			done
			rm -f "$stamp"
			[ "$found" -ge 1 ] || fail "tier2 $entry: no artifacts installed under /amd64/bin"
			(cd "/sys/src/$entry" && objtype=amd64 mk clean) || fail "tier2 droppings clean $entry"
		else
			# single-file command, cmd/<single> or nested
			# cmd/<container>/<single>: the 06-09 both-delete rule
			# (in-tree 6.<name>/<name>.6 AND the installed copy) —
			# then link-only + driver cp harvest (the 14-07
			# lesson, nested-container aware).
			name="${entry#cmd/}"
			base="${name##*/}"
			if [ "$name" = "$base" ]; then
				srcdir=/sys/src/cmd
			else
				srcdir="/sys/src/cmd/${name%/*}"
			fi
			rm -f "$srcdir/6.$base" "$srcdir/$base.6" "/amd64/bin/$name"
			(cd "$srcdir" && objtype=amd64 mk "6.$base") || fail "tier2 $entry"
			cp "$srcdir/6.$base" "/amd64/bin/$name" || fail "tier2 harvest $name"
			rm -f "$srcdir/6.$base" "$srcdir/$base.6"
			t2art "/amd64/bin/$name"
		fi
		;;
	*)
		fail "tier2 entry form not understood: $entry"
		;;
	esac
done < "$TIER2"

# dir-build droppings (the checkout IS the build tree): mkone clean
# removes the *.$O/y.tab.* class; rc's x.tab.h is its one documented
# gap; awk's generated grammar/table files (awkgram.c proctab.c) are
# build products (the committed set is the .y + maketab.c sources);
# grep's y.tab.* is mkone-clean's; units' yacc products (units.c
# units.tab.h from units.y) belong to the same generated class.  The
# singles' own droppings (6.<cmd> + <cmd>.6) are rm'd at dispatch.
# TARGETED, never blanket (jpg's committed generated tables, the
# Phase-6 workaround).
(cd /sys/src/cmd/rc && objtype=amd64 mk clean && rm -f x.tab.h) || fail "rc clean"
(cd /sys/src/cmd/awk && objtype=amd64 mk clean && rm -f awkgram.c proctab.c y.tab.c y.tab.h maketab.6 unix.maketab 6.maketab maketab) || fail "awk clean"
(cd /sys/src/cmd/grep && objtype=amd64 mk clean) || fail "grep clean"
(cd /sys/src/cmd/paqfs && objtype=amd64 mk clean) || fail "paqfs clean"
(cd /sys/src/cmd/ip/ipconfig && objtype=amd64 mk clean) || fail "ipconfig clean"
(cd /sys/src/cmd/auth/factotum && objtype=amd64 mk clean) || fail "factotum clean"
# 15-01 tier-2: auth's internal archive — built as the lib.$O.a prereq
# of every auth single, removed at run end so EVERY run rebuilds it
# fresh (the 06-03 rule at run granularity for the one shared in-tree
# archive; within a run mk's own graph governs it)
rm -f /sys/src/cmd/auth/lib.6.a
(cd /sys/src/cmd/auth/lib && objtype=amd64 mk clean) || fail "auth/lib clean"
rm -f /sys/src/cmd/units.c /sys/src/cmd/units.tab.h /sys/src/cmd/6.init

echo "== tier tree (/amd64/bin):"
ls /amd64/bin
echo "-- ip:"
ls /amd64/bin/ip
echo "-- auth:"
ls /amd64/bin/auth

echo "TIER-BUILD-OK"
GUEST_EOF

# The chroot scaffold for the passwordless venue (unshare -Ur -m): the
# 14-05 stage-build scaffold, carried verbatim in shape — the tmpfs root
# owns everything (never rm'd; dies with the namespace), leaf binds only,
# /bin a usrmerge symlink farm + the plan9port rc bind.
cat > "$TMPD/ns-x64-userns.sh" <<'USERNS_EOF'
#!/usr/bin/env bash
# ns-x64-userns.sh — the passwordless venue's namespace side: the tmpfs
# chroot scaffold + the guest script.  Never committed; regenerated each
# run.  No cleanup trap — the tmpfs IS the cleanup (dies with the
# namespace; an rm -rf would walk THROUGH the bind mounts into the
# source trees — measured once, never again).
set -e
NSX=$(mktemp -d "${TMPDIR:-/tmp}/ns-x64-root.XXXXXX")
mount -t tmpfs tmpfs "$NSX"

mkdir -p "$NSX"/{sys,amd64,rc,etc,tmp,harvey,unix,nix/store,run,dev,usr,bin}
mount --bind "$HARVEY_SYS" "$NSX/sys"
mount --bind "$HARVEY_AMD64" "$NSX/amd64"
mount --bind "$HARVEY_RC" "$NSX/rc"
# /unix — the host-toolchain mkfile (unix/mkfile's CC=9c/LD=9l, the
# plan9port wrappers on PATH): awk's maketab host generator builds with
# it (cmd/awk's objtype=$cputype mk maketab.$cputype)
mount --bind "$HARVEY_UNIX" "$NSX/unix"
# the per-arch dirs (nsrun.sh's bind set — libmach's v.c includes
# /mips/include/ureg.h etc. by absolute path, so every arch dir the
# tree names must exist at the chroot root)
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
exec chroot "$NSX" /usr/bin/env \
	HARVEY=/harvey \
	HARVEY_LINUX_BIN="$INNER_BIN" \
	PLAN9="$PLAN9" \
	PATH="$INNER_BIN:/rc/bin:$PATH" \
	HOME="$HOME" \
	FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix \
	bash "$1"
USERNS_EOF

mkdir -p "$HARVEY/.build"

# venue split: the documented sudo-unshare namespace (nsrun.sh --wrap)
# when the host grants passwordless sudo; the unprivileged user+mount
# namespace with the chroot scaffold otherwise (the 14-05 discipline).
set +e
if sudo -n true 2>/dev/null; then
	echo "== running the subset build in the namespace (sudo unshare; log: $LOG)"
	# hostbin FIRST so the namespace's mk/6a/6c/6l/ar resolve (the
	# devshell's PATH shape; nsrun.sh's su line appends /rc/bin:. itself)
	export PATH="$HARVEY_LINUX_BIN:$PATH"
	bash "$HARVEY/build/aarch64/nsrun.sh" --wrap "bash $TMPD/subset-build-x64-guest.sh" > "$LOG" 2>&1
	RC=$?
else
	echo "== no passwordless sudo — running the subset build in an unprivileged user namespace (unshare -Ur -m chroot scaffold; log: $LOG)"
	HARVEY_SYS="$HARVEY/sys" HARVEY_AMD64="$HARVEY/amd64" HARVEY_RC="$HARVEY/rc" \
	HARVEY_UNIX="$HARVEY/unix" HARVEY_REAL="$HARVEY" HARVEY_LINUX_BIN="$HARVEY_LINUX_BIN" \
	PATH="$HARVEY_LINUX_BIN:$PATH" \
	unshare -Ur -m bash "$TMPD/ns-x64-userns.sh" "$TMPD/subset-build-x64-guest.sh" > "$LOG" 2>&1
	RC=$?
fi
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: namespace tier build failed (rc=$RC); log: $LOG" >&2
	echo "hint: the log names the first failing step (TIER-BUILD-FAIL: <entry>)" >&2
	exit $RC
fi
"$GREP" -q 'TIER-BUILD-OK' "$LOG" || err "tier build log lacks TIER-BUILD-OK"

# host-side artifact spot-checks (the marker asserts ran namespace-side;
# these pin the same artifacts through the checkout's own paths)
T0_COUNT=$("$GREP" -c '^T0-ART ' "$LOG") || true
T1_COUNT=$("$GREP" -c '^T1-ART ' "$LOG") || true
echo "== markers: $T0_COUNT T0-ART, $T1_COUNT T1-ART (log: $LOG)"
for f in rc awk ls cat echo ps grep sed nm; do
	[ -x "$HARVEY/amd64/bin/$f" ] || err "amd64/bin/$f missing after the tier build"
	magic=$(od -An -tx1 -N4 "$HARVEY/amd64/bin/$f" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || err "amd64/bin/$f: bad magic $magic (want 00008a97 — amd64 S_MAGIC)"
done
[ -x "$HARVEY/amd64/bin/ip/ipconfig" ] || err "amd64/bin/ip/ipconfig missing after the tier build"
[ -x "$HARVEY/amd64/bin/auth/factotum" ] || err "amd64/bin/auth/factotum missing after the tier build"
# 14-09: the net-gate payload spot-checks (the magic class)
for f in ip/ping ip/udpecho dd bind; do
	[ -x "$HARVEY/amd64/bin/$f" ] || err "amd64/bin/$f missing after the tier build (the 14-09 net section)"
	magic=$(od -An -tx1 -N4 "$HARVEY/amd64/bin/$f" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || err "amd64/bin/$f: bad magic $magic (want 00008a97)"
done
for f in netblast tcpblast tcpecho; do
	[ -s "$HARVEY/build/x86_64/out/$f" ] || err "build/x86_64/out/$f missing after the tier build (the 14-09 net helpers)"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/x86_64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || err "build/x86_64/out/$f: bad magic $magic (want 00008a97)"
done
# 15-01: the tier-2 tracer's host-side spot-check (the T2-ART marker
# asserts ran namespace-side; this pins the same artifact through the
# checkout's own path)
[ -x "$HARVEY/amd64/bin/listen" ] || err "amd64/bin/listen missing after the tier build (the 15-01 tier-2 tracer)"
magic=$(od -An -tx1 -N4 "$HARVEY/amd64/bin/listen" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "amd64/bin/listen: bad magic $magic (want 00008a97)"
for f in boot init paqfs; do
	[ -s "$HARVEY/build/x86_64/out/$f" ] || err "build/x86_64/out/$f missing after the tier build"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/x86_64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || err "build/x86_64/out/$f: bad magic $magic (want 00008a97)"
done

echo "== PASS: amd64 tier-0/tier-1 set built and installed ($(ls "$HARVEY/amd64/bin" | wc -l | tr -d ' ') entries in amd64/bin; log: $LOG)"
