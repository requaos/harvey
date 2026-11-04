#!/bin/sh
# build/aarch64/donor-ns-build.sh — build the pinned 9front donor kernel
# (CONF=qemu) INSIDE the donor tree in the lima guest's Linux mount
# namespace, using Harvey's vendored 7a/7c/7l.
#
# Runs in three phases (self-re-entrant; modeled on nsrun.sh, which is
# the command-parameterized form of sys/src/BUILD_SETUP_NAMESPACE):
#
#   donor-ns-build.sh              repo user, devshell env: capture
#                                  exports, re-enter as root under
#                                  sudo unshare -m
#   donor-ns-build.sh --ns U E     root, private mount namespace: bind
#                                  the donor tree into a Plan 9
#                                  namespace, su to U for the build
#   donor-ns-build.sh --build      repo user, inside the namespace: the
#                                  actual build (invoked by --ns only)
#
# Namespace binds (donor tree = $DONOR, default ~/9front-donor):
#   /sys     ← $DONOR/sys          donor mkfiles/includes
#   /arm64   ← $DONOR/arm64        donor arch dir (objtype=arm64 INSIDE
#                                  the donor tree — the donor's own
#                                  naming carve-out)
#   /aarch64 ← $DONOR/arm64        COMPATIBILITY ALIAS: Harvey's vendored
#                                  7a/7c/7l carry thestring=aarch64,
#                                  so their built-in
#                                  include search /aarch64/include and
#                                  library search /aarch64/lib must
#                                  resolve into the donor's arm64 dirs
#   /rc      ← $DONOR/rc           rc scripts the build needs
#   /lib     ← merged distro lib + $DONOR/lib (BUILD_SETUP_NAMESPACE
#              staging: root-owned 1777, trap-unwound)
#
# Toolchain on PATH (build phase):
#   1. $SCRATCH (~/9front-hostbin) — donor host helpers compiled from
#      donor sources: disk/mkfs, mkpaqfs, aux/data2s, aux/aout2uimage,
#      size, strip (the set the donor mkfiles invoke; discovered from
#      sys/src/9/{arm64/mkfile,port/portmkfile,boot/bootmkfile,
#      port/mkrootall} at execution time, per plan)
#   2. $HARVEY_LINUX_BIN — Harvey's guest hostbin (7a/7c/7l, iar as ar)
#      FIRST among toolchain tools: the donor kernel is compiled,
#      assembled, linked and archived by OUR tools. The build
#      logs `command -v 7c 7a 7l ar` as the provenance proof.
#   3. $PLAN9/bin ahead of the system dirs INSIDE this namespace build:
#      the donor mkfiles assume Plan 9 tool semantics (date -n for
#      KERNDATE, sed BREs, xd -1x). (The carried-forward "plan9port LAST"
#      rule governs Harvey host-tool builds on the host; a namespace
#      build is Plan 9 territory.)
#
# Build order (donor mkfiles are the authority):
#   A. host helpers into $SCRATCH (donor sources; 9cc-tree route for
#      mach.h consumers — size/strip/aout2uimage need arm64 crackhdr,
#      which only the vendored 9cc libmach has; pure
#      plan9port 9c/9l for mkpaqfs/mkfs/data2s)
#   B. donor libc for arm64: cd /sys/src/libc && mk install
#   C. kernel LIB list + bootdir deps: libmp libsec libflate libip
#      libdraw libmemdraw libmemlayer libauth libauthsrv
#   D. bootdir + bootfs binaries: single-file cmds (bind cat chmod dd
#      echo ls mkdir mntgen mount mv rm sleep srv test unmount xd init)
#      via cmd/mkfile's $BIN/% rules; dir cmds (rc sed grep
#      ip/ipconfig paqfs) via their mkfiles; factotum targeted
#      ($O.factotum only — mkmany install would also build fgui)
#   E. kernel: cd /sys/src/9/arm64 && mk CONF=qemu → 9qemu + 9qemu.u
#      (donor's own aux/aout2uimage — never imported)
#   F. dist assembly in ~/9front-dist: 9qemu{,.u} + srvroot/ (the root
#      fs served to the guest by `harness srv9` at boot time; see boot-9qemu.sh)
#
# Boundary: nothing from the donor tree is copied into
# Harvey's tracked tree; donor kernel sources are never patched. The ONE
# guest-copy exception, disclosed: bootmkfile's BOOTFSPROTOS block is
# replaced with its provably-identical CONF=qemu expansion (see the wrap
# phase) because plan9port's mk (and Harvey's own mk) mis-scan nested rc
# backquotes — a host-tool limitation, not donor drift. Kernel sources,
# libs, and the produced kernel image are unaffected.
#
# On intractable failure the plan requires a checkpoint:decision for
# the pinned-prebuilt fallback — not a silent patch, not a downgrade.
#
# usage: sh build/aarch64/donor-ns-build.sh   (from the guest repo dir,
#        under nix develop; normally driven by donor-vm-build.sh)

set -eu

DONOR="${DONOR:-$HOME/9front-donor}"
SCRATCH="${DONOR_HOSTBIN:-$HOME/9front-hostbin}"
DIST="${DONOR_DIST:-$HOME/9front-dist}"
DONOR_SHA=350266104f1fed81c78c3d05fa44f523bec0ae4d

if [ "${1:-}" = "--build" ]; then
	# ---------------------------------------------------------------
	# build phase: repo user, inside the namespace
	# ---------------------------------------------------------------
	set -eu

	for t in 7c 7a 7l ar mk; do
		if ! command -v $t >/dev/null 2>&1; then
			echo "error: $t not on PATH (guest toolchain not ensured?)" >&2
			exit 1
		fi
	done

	mkdir -p "$SCRATCH" "$SCRATCH/disk" "$SCRATCH/aux"
	# hostbin first among toolchain tools, plan9port ahead of
	# system dirs for Plan 9 semantics (date -n, sed, xd)
	PATH="$SCRATCH:$HARVEY_LINUX_BIN:$PLAN9/bin:$PATH"
	export PATH
	objtype=arm64
	export objtype
	FORCERCFORMK=1
	export FORCERCFORMK

	# 7c wrapper: neutralize _Noreturn (C11 keyword used by the donor's
	# libc.h/thread.h and kernel port sources; Harvey's shared cc
	# frontend predates it). Two flags, both semantics-preserving for
	# this build:
	#   -D_Noreturn=  drop the keyword (annotated functions — exits,
	#     abort, threadexits... — never return anyway)
	#   -wB  demote "no return at end of function" from diag to warn:
	#     with the keyword dropped, control-flow analysis no longer
	#     knows a _Noreturn tail call never returns (donor libdraw/
	#     event.c estartfn/etimer/enote end in threadexits()). In the
	#     donor's own frontend BNORET drives no codegen (cc.h:406,
	#     cc.y:1158) — the diagnostic is the ONLY behavioral difference
	#     and the emitted code is identical.
	# The wrapper execs the real vendored 7c — no donor source edits
	# (vendor fidelity), no shared-frontend edits.
	cat > "$SCRATCH/7c" <<EOF
#!/bin/sh
exec "$HARVEY_LINUX_BIN/7c" -D_Noreturn= -wB "\$@"
EOF
	chmod +x "$SCRATCH/7c"

	echo "== D-07 provenance (donor kernel is built by Harvey's tools):"
	echo "   7c: $HARVEY_LINUX_BIN/7c (via $SCRATCH/7c -D_Noreturn= -wB wrapper)"
	echo "   7a: $(command -v 7a)"
	echo "   7l: $(command -v 7l)"
	echo "   ar: $(command -v ar)"
	echo "   mk: $(command -v mk)"

	# ---- A. host helper tools -------------------------------------
	NINE_CC="$HARVEY/sys/src/cmd/unix/9cc"
	OBJDIR="$NINE_CC/obj.linux"
	if [ ! -f "$OBJDIR/libmach.a" ]; then
		echo "== A0. bootstrapping vendored 9cc archives (libmach etc.)"
		(cd "$NINE_CC" && sh BUILD)
	fi
	SHIM="$(mktemp -d)"
	trap '/bin/rm -rf "$SHIM"' EXIT
	echo '#include <lib9.h>' > "$SHIM/u.h"
	echo '/* lib9.h already included via u.h */' > "$SHIM/libc.h"
	# 9cc-tree include route (the nm.BUILD precedent): its
	# libmach is the only host libmach with arm64 (7-format) support
	IFLAGS="-I$SHIM -I$NINE_CC/include -I$NINE_CC/lib9/linux -I$NINE_CC -I$NINE_CC/cmd"

	# plan9port's 9l autolib calls bare `nm` on HOST ELF objects;
	# with $HARVEY_LINUX_BIN on PATH that is Harvey's ken-format nm
	# ("Can't read header" → silently broken autolib). All 9c/9l
	# helper builds run with hostbin stripped from PATH (same fix as
	# nix/toolchain.sh's nm shim; 9cc-route tools link with $CC
	# directly and are unaffected). Used in steps A and D.
	# NOTE: single-sed transform — at this point PATH prefers
	# plan9port, whose tr does not translate ':'->'\n' the GNU way.
	P9PATH=$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$//')

	need_helpers=0
	for h in size strip disk/mkfs mkpaqfs aux/data2s aux/aout2uimage mkrunetype-host mpc; do
		[ -x "$SCRATCH/$h" ] || need_helpers=1
	done

	if [ "$need_helpers" = 1 ]; then
		echo "== A. building donor host helpers into $SCRATCH"
		CC="${CC:-cc}"

		# mach.h consumers via the 9cc tree (arm64 crackhdr)
		echo "   size (9cc libmach route)"
		$CC -O0 -g $IFLAGS -c "$DONOR/sys/src/cmd/size.c" -o "$SHIM/size.o"
		$CC -O0 -g -o "$SCRATCH/size" "$SHIM/size.o" \
			"$OBJDIR/libmach.a" "$OBJDIR/libbio.a" "$OBJDIR/lib9.a" -lm

		echo "   strip (9cc libmach route)"
		$CC -O0 -g $IFLAGS -c "$DONOR/sys/src/cmd/strip.c" -o "$SHIM/strip.o"
		$CC -O0 -g -o "$SCRATCH/strip" "$SHIM/strip.o" \
			"$OBJDIR/libmach.a" "$OBJDIR/libbio.a" "$OBJDIR/lib9.a" -lm

		# aout2uimage needs crackhdr (9cc) AND mkcrctab/blockcrc
		# (flate.h; plan9port libflate — its crc.o is self-contained
		# except p9malloc, a plan9port-lib9 name the 9cc lib9 lacks;
		# 9cc's lib9.h likewise declares _assert (its assert macro)
		# without an implementation in the vendored subset. p9bridge.c
		# bridges both to libc — a host-compat shim in the unixcompat.c
		# tradition; no donor or vendored source is modified).
		# plan9port's flate.h needs AUTOLIB() (a plan9port u.h-ism the
		# 9cc lib9.h umbrella lacks) and uint32 (9cc spells it u32int) —
		# neutralize both with -D. The remaining -Duint32=u32int mismatch
		# is in the DONOR source: it holds the crc table as ulong* (Plan
		# 9 LP64: ulong is 4 bytes there); plan9port's crc.o treats it as
		# u32int* (also 4 bytes) — the pointer value round-trips opaque,
		# so downgrading the gcc-14 pointer-type error is safe here.
		echo "   aux/aout2uimage (9cc libmach + plan9port flate)"
		cat > "$SHIM/p9bridge.c" <<-'EOT'
			#include <stdio.h>
			#include <stdlib.h>
			void _assert(char *x) { fprintf(stderr, "assertion failed\n"); abort(); }
			void *p9malloc(long n) { return malloc(n); }
		EOT
		$CC -O0 -c "$SHIM/p9bridge.c" -o "$SHIM/p9bridge.o"
		$CC -O0 -g $IFLAGS -I"$PLAN9/include" '-DAUTOLIB(x)=' \
			-Duint32=u32int -Wno-incompatible-pointer-types \
			-c "$DONOR/sys/src/cmd/aux/aout2uimage.c" -o "$SHIM/aout2uimage.o"
		$CC -O0 -g -o "$SCRATCH/aux/aout2uimage" \
			"$SHIM/aout2uimage.o" "$SHIM/p9bridge.o" \
			"$OBJDIR/libmach.a" "$OBJDIR/libbio.a" "$OBJDIR/lib9.a" \
			"$PLAN9/lib/libflate.a" -lm

		# pure plan9port tools (all 9c builds get -O0: the nix
		# cc-wrapper's -D_FORTIFY_SOURCE=3 is inert without optimization,
		# and donor helper code is decades-old Plan 9 C written for a
		# libc without bounds checks — e.g. mklatin.c has a genuine
		# 1-byte heap overflow vs the current /lib/keyboard (3-char
		# sequences vs MAXLD=2), silent on Plan 9, fatal under fortify;
		# upstream donor-data/tool drift, not ours to patch)
		echo "   aux/data2s (plan9port 9c)"
		(export PATH="$P9PATH"; cd "$SHIM" && "$PLAN9/bin/9c" -O0 -c "$DONOR/sys/src/cmd/aux/data2s.c" &&
			"$PLAN9/bin/9l" -o "$SCRATCH/aux/data2s" data2s.o)

		echo "   mkrunetype-host (plan9port 9c; runs in the guest in step B)"
		(export PATH="$P9PATH"; cd "$SHIM" && "$PLAN9/bin/9c" -O0 -c "$DONOR/sys/src/libc/ucd/mkrunetype.c" &&
			"$PLAN9/bin/9l" -o "$SCRATCH/mkrunetype-host" mkrunetype.o)

		# mpc: the donor's mp-expression compiler (guest-native binary).
		# libsec/port regenerates jacobian.c from jacobian.mp and
		# libauthsrv regenerates {msqrt,decaf,edwards,elligator2,
		# spake2ee,ed448}.mpc at build time; mk deletes partial targets
		# on failure, so no stale-file cleanup is needed once mpc is on
		# PATH (scratch bin is first).
		echo "   mpc (plan9port yacc + 9c; feeds libsec/libauthsrv generators)"
		(export PATH="$P9PATH"; cd "$SHIM" && "$PLAN9/bin/yacc" -D1 -d "$DONOR/sys/src/cmd/mpc.y" &&
			"$PLAN9/bin/9c" -O0 -c y.tab.c &&
			"$PLAN9/bin/9l" -o "$SCRATCH/mpc" y.tab.o -lmp -lbio -l9)

		echo "   mkpaqfs (plan9port 9c + flate/mp/sec)"
		(export PATH="$P9PATH"; cd "$SHIM" && "$PLAN9/bin/9c" -O0 -I"$DONOR/sys/src/cmd/paqfs" \
			-c "$DONOR/sys/src/cmd/paqfs/mkpaqfs.c" &&
			"$PLAN9/bin/9l" -o "$SCRATCH/mkpaqfs" mkpaqfs.o \
			-lflate -lsec -lmp -lbio -l9)

		echo "   disk/mkfs (harness-side: the Rust harness's mkfs9 subcommand)"
		# mkfs is NOT built from donor sources. Every host build route for
		# the donor's mkfs.c is broken on a unix host: plan9port's libdisk
		# rdproto mangles relative proto source paths; the donor proto.c
		# route then dies on plan9port lib9's dirfwstat silently ignoring
		# nd.name (no rename — the temp+rename idiom leaves read-only
		# __mkfstmp files; reproduced on host and guest). The Rust harness
		# (build/harness) implements the exact proto
		# semantics CONF=qemu needs (see src/mkfs9.rs's header). Installed
		# as disk/mkfs in the scratch bin (always, after the if-block — it
		# tracks repo edits).
	else
		echo "== A. host helpers cached in $SCRATCH (skip)"
	fi

	# the harness mkfs9 is always (re)installed — cheap (nix cache hits),
	# and tracks repo edits even when the compiled helpers are cached.
	# The guest's disk/mkfs is a thin wrapper exec'ing the compiled
	# aarch64-linux harness from the flake package; --out-link gcroot-pins
	# the store path in the guest scratch.
	nix build "$HARVEY#harness" --out-link "$SCRATCH/harness-pkg"
	cat > "$SCRATCH/disk/mkfs" <<EOF
#!/bin/sh
exec "$SCRATCH/harness-pkg/bin/harness" mkfs9 "\$@"
EOF
	chmod 755 "$SCRATCH/disk/mkfs"

	# ---- B. donor libc for arm64 ----------------------------------
	echo "== B. donor libc (objtype=arm64)"
	# ucd/mkfile's $DATA rule evals /$cputype/mkfile and runs the
	# mkrunetype generator BUILT WITH THE TARGET toolchain — upstream's
	# trick is that $cputype on a native Plan 9 build host names the
	# HOST arch (amd64 host → CC=6c → native binary). Our guest is
	# linux-aarch64: no /$cputype/mkfile produces a runnable binary.
	# So the generator is built host-side (plan9port 9c, same class as
	# the other donor host helpers) and run here against the namespace's
	# /lib/ucd; the generated files are then newer than $UCD and the mk
	# rule is skipped. Data files land in the guest's donor copy only
	# (the donor generates them at build time; nothing enters Harvey's
	# tracked tree).
	if [ ! -s "$DONOR/sys/src/libc/ucd/runenormdata" ]; then
		echo "   ucd: generating runetype tables with host-built mkrunetype"
		(cd /sys/src/libc/ucd && "$SCRATCH/mkrunetype-host")
	fi
	(cd /sys/src/libc && mk install)

	# ---- C. kernel libs + bootdir dep libs -------------------------
	# kernel LIB list (donor arm64/mkfile:62-69): memlayer memdraw draw
	# ip sec mp + libc (B); paqfs adds flate; factotum adds auth/authsrv
	# + 9p + String; the proto-named fs/disk cmds add disk; cmd autolib
	# footprint (7l resolves #pragma lib from /arm64/lib) adds bio, ndb
	# (ipconfig/secstore), 9p (hjfs/nusb/factotum), thread (factotum/
	# hjfs/mntgen/nusb), avl (gefs/cwfs64x), regexp (sed/awk).
	for l in libmp libsec libflate libip libdraw libmemdraw libmemlayer libauth libauthsrv libdisk libbio libndb lib9p libString libthread libavl libregexp; do
		echo "== C. $l (objtype=arm64)"
		(cd "/sys/src/$l" && mk install)
	done

	# ---- D. bootdir + bootfs binaries (target, arm64) --------------
	# The bootfs rule's prereq list is `{disk/mkfs -aos / $BOOTFSPROTOS}`
	# — every file named by bootfs.proto + disk.proto + devusb.proto
	# (the CONF has dev sd and usb) becomes a HARD mk prerequisite, so
	# all of these must exist, not just the ones the boot path executes.
	echo "== D. target binaries for the bootfs/rootfs (full proto set)"
	(cd /sys/src/cmd && for c in bind cat chmod dd echo ls mkdir mntgen mount mv rm sed sleep srv test tlsclient unmount xd init; do
		echo "   cmd/$c.c"
		mk "/arm64/bin/$c"
	done)
	for d in rc grep ip/ipconfig paqfs cfs dossrv 9660srv gefs hjfs cwfs; do
		echo "   cmd/$d"
		(cd "/sys/src/cmd/$d" && mk install)
	done
	# awk: proctab.c is generated by running maketab (donor mkfile's
	# $cputype trick = host toolchain on a native Plan 9 host). Plant a
	# guest-native unix.maketab (plan9port 9c) — mk runs it to generate
	# proctab.c. yacc runs first so y.tab.h exists; the sleep makes the
	# plant strictly newer than y.tab.h at plan9port mk's 1-second
	# freshness granularity (equal-second mtimes get the plant rebuilt
	# with 7c by the broken /unix/mkfile rule — verified empirically).
	echo "   cmd/awk (host-built maketab generator planted as unix.maketab)"
	(cd /sys/src/cmd/awk && "$PLAN9/bin/yacc" -o awkgram.c -d awkgram.y)
	sleep 2
	(export PATH="$P9PATH"; cd "$SHIM" && "$PLAN9/bin/9c" -O0 -c "$DONOR/sys/src/cmd/awk/maketab.c" &&
		"$PLAN9/bin/9l" -o maketab-host maketab.o -lbio -l9 &&
		cp maketab-host "$DONOR/sys/src/cmd/awk/unix.maketab")
	(cd "/sys/src/cmd/awk" && mk install)
	# targeted mkmany/dir builds (avoid building entire dirs)
	echo "   cmd/auth/factotum (targeted: factotum only, not fgui)"
	(cd /sys/src/cmd/auth/factotum && mk '7.factotum')
	mkdir -p /arm64/bin/auth
	cp /sys/src/cmd/auth/factotum/7.factotum /arm64/bin/auth/factotum
	echo "   cmd/auth/secstore (targeted: secstore only)"
	(cd /sys/src/cmd/auth/secstore && mk secstore.install)
	echo "   cmd/aux: kbdfs wpa"
	(cd /sys/src/cmd/aux && mk wpa.install)
	# kbdfs lives only in aux/kbdfs/ (aux/mkfile's kbdfs entry is stale
	# — there is no aux/kbdfs.c); its latin1.h is generated by mklatin,
	# the same $cputype host-generator pattern as awk. Plant a
	# guest-native mklatin.unix (strictly newer than mklatin.c — same
	# 1-second mk granularity fix).
	(export PATH="$P9PATH"; cd "$SHIM" && "$PLAN9/bin/9c" -O0 -c "$DONOR/sys/src/cmd/aux/kbdfs/mklatin.c" &&
		"$PLAN9/bin/9l" -o mklatin-host mklatin.o -lbio -l9 &&
		sleep 2 &&
		cp mklatin-host "$DONOR/sys/src/cmd/aux/kbdfs/mklatin.unix")
	(cd /sys/src/cmd/aux/kbdfs && mk install)
	echo "   cmd/ndb: dnsgetip"
	(cd /sys/src/cmd/ndb && mk dnsgetip.install)
	echo "   cmd/disk: cryptsetup"
	(cd /sys/src/cmd/disk && mk cryptsetup.install)
	echo "   cmd/disk/prep: fdisk edisk prep"
	(cd /sys/src/cmd/disk/prep && mk install)
	echo "   cmd/nusb: lib, kb, usbd, ether, disk"
	(cd /sys/src/cmd/nusb/lib && mk install)
	(cd /sys/src/cmd/nusb/kb && mk install)
	(cd /sys/src/cmd/nusb/usbd && mk install)
	(cd /sys/src/cmd/nusb/ether && mk install)
	(cd /sys/src/cmd/nusb/disk && mk install)

	# ---- E. kernel --------------------------------------------------
	echo "== E. donor kernel: cd /sys/src/9/arm64 && mk CONF=qemu"
	# systab.h is generated by the donor's mksystab, which uses sam -d
	# batch scripts; plan9port's sam (pinned snapshot) drifts on exactly
	# one entry: `[SYSR1] SYSsysr1,` where the donor's intent (and its
	# own declarations section) is `sysr1` — sysproc.c:1408 then fails
	# with "name not declared: SYSsysr1". Pre-generate systab.h with the
	# donor's generator and correct the single drifted entry; mk then
	# sees systab.h as fresh vs sys.h/mksystab and skips regeneration.
	# (systab.h is a build artifact in the guest copy, not a donor
	# source edit; the correction is asserted to hit exactly one line.)
	if [ ! -s "$DONOR/sys/src/9/port/systab.h" ] || grep -q 'SYSsysr1' "$DONOR/sys/src/9/port/systab.h"; then
		(cd /sys/src/9/arm64 && rc ../port/mksystab > ../port/systab.h.stage)
		n=$(grep -c 'SYSsysr1' "$DONOR/sys/src/9/port/systab.h.stage" || true)
		if [ "$n" != "1" ]; then
			echo "error: systab.h generation drifted unexpectedly (SYSsysr1 count=$n)" >&2
			exit 1
		fi
		sed 's/SYSsysr1/sysr1/' "$DONOR/sys/src/9/port/systab.h.stage" > "$DONOR/sys/src/9/port/systab.h"
		rm -f "$DONOR/sys/src/9/port/systab.h.stage"
	fi
	(cd /sys/src/9/arm64 && mk 'CONF=qemu')

	# ---- F. dist assembly -------------------------------------------
	echo "== F. assembling $DIST"
	rm -rf "$DIST"
	mkdir -p "$DIST"
	cp /sys/src/9/arm64/9qemu /sys/src/9/arm64/9qemu.u "$DIST/"

	# srvroot: the root fs harness srv9 serves to the booting guest.
	# arm64/init + arm64/bin are the 7c/7l-built target binaries; the
	# rest is donor scripts/data + the empty dirs newns/termrc expect.
	SR="$DIST/srvroot"
	mkdir -p "$SR/arm64/bin/ip" "$SR/bin" "$SR/dev" "$SR/fd" "$SR/env" \
		"$SR/proc" "$SR/shr" "$SR/srv" "$SR/mnt" "$SR/mnt/exportfs" \
		"$SR/n" "$SR/net" "$SR/mail" "$SR/acme" "$SR/adm" "$SR/tmp" \
		"$SR/lib" "$SR/rc/lib" "$SR/rc/bin" \
		"$SR/usr/glenda/lib" "$SR/usr/glenda/tmp"
	cp /arm64/init "$SR/arm64/init"
	for c in bind cat chmod dd echo grep ls mkdir mntgen mount mv rm sed sleep srv test unmount xd rc; do
		cp "/arm64/bin/$c" "$SR/arm64/bin/$c"
	done
	cp /arm64/bin/ip/ipconfig "$SR/arm64/bin/ip/ipconfig"
	cp "$DONOR/lib/namespace" "$SR/lib/namespace"
	cp "$DONOR/rc/lib/rcmain" "$SR/rc/lib/rcmain"
	cp "$DONOR/rc/bin/termrc" "$SR/rc/bin/termrc"
	echo '# empty profile for the 02-04 harness boot' > "$SR/usr/glenda/lib/profile"

	echo "== donor build complete: $DIST/9qemu{,.u} + srvroot/"
	exit 0
fi

if [ "${1:-}" = "--ns" ]; then
	# ---------------------------------------------------------------
	# ns phase: root, inside the private mount namespace
	# ---------------------------------------------------------------
	set -u
	BUILD_USER="${2:?internal: donor-ns-build.sh --ns <user> <exports>}"
	ENVFILE="${3:?internal: donor-ns-build.sh --ns <user> <exports>}"

	# captured devshell exports: HARVEY, HARVEY_LINUX_BIN, PLAN9, PATH...
	. "$ENVFILE"

	[ -d "$DONOR/sys/src/9/arm64" ] || {
		echo "error: $DONOR does not look like the 9front donor checkout" >&2
		exit 1
	}

	# /sys from the DONOR tree (not Harvey's)
	mount --bind "$DONOR/sys" /sys

	# donor arch dir at its own name AND at the /aarch64 alias our
	# thestring=aarch64 tools require (see header)
	mkdir -p /arm64
	mount --bind "$DONOR/arm64" /arm64
	mkdir -p /aarch64
	mount --bind "$DONOR/arm64" /aarch64
	# NOTE: $DONOR/arm64/{lib,bin*} are created in the wrap phase (as the
	# repo user) — the build runs under su and cannot write root-owned
	# dirs. Repair ownership here for dirs left root-owned by earlier
	# runs of this script.
	mkdir -p $DONOR_BINDIRS
	chown "$BUILD_USER" $DONOR_BINDIRS 2>/dev/null || true

	mkdir -p /rc
	mount --bind "$DONOR/rc" /rc

	# merged /lib (distro runtime + donor lib), BUILD_SETUP_NAMESPACE
	# pattern: stage while /lib is intact, keep root-owned, bind over
	if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
	NSLIB=/tmp/dnslib.$$
	mkdir -p "$NSLIB"
	cp -a "$LIBREAL"/. "$NSLIB/"
	cp -a "$DONOR/lib"/. "$NSLIB/" 2>/dev/null || true
	chown 0:0 "$NSLIB"
	chmod 1777 "$NSLIB"
	mount --bind "$NSLIB" "$LIBREAL"

	unwind() {
		umount "$LIBREAL" 2>/dev/null || true
		rm -rf "$NSLIB"
	}
	trap unwind EXIT

	# su resets PATH (login.defs ENV_PATH) — re-source the captured
	# exports inside the su shell (the su-proof env pattern)
	set +e
	su -c ". '$ENVFILE'; sh '$HARVEY/build/aarch64/donor-ns-build.sh' --build" "$BUILD_USER"
	RC=$?
	exit $RC
fi

# -------------------------------------------------------------------
# wrap phase: repo user, devshell env
# -------------------------------------------------------------------
# resolve DONOR/SCRATCH/DIST defaults against the USER's home and export
# them BEFORE capturing — the --ns phase runs as root ($HOME=/root) and
# must inherit the user's paths through the exports file
export DONOR SCRATCH DIST DONOR_BINDIRS
# the donor tree ships arm64/include but no lib/ or bin/ — the build
# installs /arm64/lib/*.a and /arm64/bin/*; create them here (as the
# repo user, so the su'd build can write them; they persist in the
# guest's donor copy across runs). The bin subdirs mirror the cmd
# mkfiles' BIN=/$objtype/bin/<sub> install targets (their cp has no
# mkdir — on a native 9front system these dirs exist in the dist).
DONOR_BINDIRS="$DONOR/arm64/lib $DONOR/arm64/bin $DONOR/arm64/bin/ip $DONOR/arm64/bin/ndb $DONOR/arm64/bin/auth $DONOR/arm64/bin/aux $DONOR/arm64/bin/disk $DONOR/arm64/bin/nusb"
mkdir -p $DONOR_BINDIRS

# --- guest-copy mkfile compat shim (DISCLOSED; the host checkout at
# .build/9front-donor stays byte-pristine at the pin) ---------------
# plan9port's mk (0-unstable-2025-11-10, flake-pinned) mis-scans NESTED
# rc backquotes: bootmkfile:16-19 computes BOOTFSPROTOS with
# `{basename $j .proto}` nested inside `{for(j in ../boot/*.proto){...}}`,
# and naive first-`}` extraction corrupts the mkfile text (verified
# empirically: rc gets an unclosed backquote → "/dev/stdin: token EOF",
# then mk's graph is mangled into a false cycle at qemu.root.7).
# 9front's own mk counts braces (donor sys/src/cmd/mk/lex.c bquote);
# Harvey's in-tree mk shares the naive form.
# For CONF=qemu the expression provably evaluates to the three protos
# below: qemu.bootfs.proto absent → ../boot/bootfs.proto; CONF has dev
# `sd` (devsd.$O ∈ $OBJ) → ../boot/disk.proto; CONF has dev `usb`
# (devusb.$O ∈ $OBJ) → ../boot/devusb.proto; ether4330/etheriwl/
# etherrt2860/etherwpi.$O ∉ $OBJ → nothing else. The guest copy gets the
# literal list; the kernel image is unaffected (same protos → same
# bootfs.paq content). Applied to the disposable guest copy ONLY.
BMK="$DONOR/sys/src/9/boot/bootmkfile"
SHIMMED='BOOTFSPROTOS=../boot/bootfs.proto ../boot/disk.proto ../boot/devusb.proto'
if grep -qF "$SHIMMED" "$BMK"; then
	: # already shimmed (idempotent reruns)
elif grep -qF '{for(j in ../boot/*.proto){~ `{basename $j .proto}' "$BMK"; then
	echo "== applying BOOTFSPROTOS mk-compat shim to guest donor copy (see donor-ns-build.sh header)"
	{
		sed -n '1,15p' "$BMK"
		echo "$SHIMMED	# shimmed by build/aarch64/donor-ns-build.sh (nested-backquote mk limitation; semantics identical for CONF=qemu)"
		sed -n '20,$p' "$BMK"
	} > "$BMK.shimmed"
	mv "$BMK.shimmed" "$BMK"
else
	echo "error: $BMK does not match the pinned CONF=qemu BOOTFSPROTOS block — donor drift?" >&2
	exit 1
fi

EXPORTS=/tmp/donor-ns-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m sh "$HARVEY/build/aarch64/donor-ns-build.sh" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
