#!/bin/sh
# build/aarch64/subset-build.sh — the aarch64 shell-boot userland
# subset namespace build driver (plan 02-07 Task 1; TC-05's build half).
#
# Builds, in the lima guest's Plan 9 namespace with objtype=aarch64 and
# NO scratch anything (the committed wiring from plan 02-06 carries the
# whole build — aarch64/mkfile, aarch64/include/, CPUS, OS=...7):
#   1. libs in dependency order: libc (idempotent rerun), libbio,
#      libregexp, libip, libndb, libmp, libsec, libString, libthread,
#      lib9p, libauth, libauthsrv, libflate — abort on first failure,
#      dir named.
#      (The plan's named set — libip libmp libsec libauth libauthsrv —
#      is the declared-LIB surface; the full set above is the
#      #pragma-lib closure discovered at link time, exactly as the
#      plan's flagged assumptions anticipated: ls/ps/sed/wc/grep pull
#      bio.h → libbio; sed also regexp.h → libregexp; ipconfig also
#      bio.h + ndb.h → libbio/libndb; factotum's dat.h also String.h,
#      thread.h, 9p.h → libString/libthread/lib9p. libthread's
#      $objtype.$O member needs the in-tree aarch64.c port — imported
#      from the pinned donor's arm64.c, byte-verbatim.)
#   2. the command subset: the four directory commands (rc, grep,
#      ip/ipconfig, auth/factotum) and the twelve single-file commands
#      (cat cp date echo ls mkdir mv ps rm sed test wc) via cmd's
#      per-target install rule
#   3. rsync the resulting /aarch64/bin tree back to the host checkout's
#      gitignored aarch64/bin
#   4. the boot chain (05-02): boot(8) for aarch64 via
#      sys/src/9k/boot/mkfile.aarch64 (additive, objtype-gated;
#      hand-written bootr9.c bootconf — RESEARCH Pattern 2), init via
#      cmd's per-target install (lands at /aarch64/init), paqfs via its
#      dir's per-target install, and 05-01's stacksmoke — all harvested
#      to the gitignored build/aarch64/out/ with R_MAGIC asserts
#
# The libmp/libsec aarch64 stubs (empty-OFILES arch dirs, the riscv64
# pattern) let those libs' port+$objtype recursion resolve; the port
# dirs supply every symbol (research TC-05 row: all portable C).
# factotum's transitive crypto needs (libmp/libsec) resolve through the
# #pragma lib chain (auth.h/authsrv.h → libsec.h/mp.h) against the
# /aarch64/lib archives step 1 installs; anything beyond that is real
# drift — shim per D-13 discipline, never drop the command.
#
# If a listed command fails for aarch64-specific reasons (per-arch asm
# assumptions), that is a genuine port bug to fix in-tree
# (upstream-posture: this repo is the maintained fork) — not grounds to
# drop the command from the subset.
#
# Guest-state note: mutates the default guest dir harvey-build (the
# donor harness uses harvey-build-donor). vm-run.sh's rsync --delete
# keeps the guest copy faithful to the checkout; the subset tree is
# rebuilt idempotently each run and rsynced back to the host (the
# authoritative artifact).
#
# Wrapper/env provides: limactl + openssh + rsync on PATH (nix
# devshell on darwin), same as vm-run.sh.
#
# Platforms (05-11, D-10 — the compose app invokes this one driver on
# both hosts): darwin drives the lima guest as above; linux runs the
# SAME generated guest script natively under nsrun.sh's sudo-unshare
# namespace entry — no lima, no rsync (the namespace bind-mounts the
# real checkout, so artifacts land in place and the rsync-back steps
# are skipped).  The native leg bootstraps the host toolchain
# (.build/hostbin-linux-*) via nix run .#setup / .#toolchain when the
# 7c/ar sentinels are missing (vm-run.sh's guest-side equivalent).
#
# usage: sh build/aarch64/subset-build.sh   (from the repo root,
# inside the nix devshell)

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"
LOG="${SUBSET_BUILD_LOG:-$HARVEY/.build/subset-build.log}"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -f "$HARVEY/sys/src/libmp/aarch64/mkfile" ] || err "sys/src/libmp/aarch64/mkfile missing (plan 02-07 Task 1 stub)"
[ -f "$HARVEY/sys/src/libsec/aarch64/mkfile" ] || err "sys/src/libsec/aarch64/mkfile missing (plan 02-07 Task 1 stub)"
[ -d "$HARVEY/aarch64" ] || err "aarch64/ arch dir missing — plan 02-06 wiring is a precondition"

# Platform split (05-11, D-10): linux runs natively (sudo unshare via
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
	if ! limactl list -q 2>/dev/null | /usr/bin/grep -qx "$VM"; then
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

# guest-side script (the run-gate.sh single-committed-file discipline):
# written to a host tmp file, rsynced to the guest's /tmp, executed via
# vm-run.sh (which rsyncs the checkout, ensures the guest toolchain,
# and wraps the command in nsrun.sh's namespace entry).
cat > "$TMPD/subset-build-guest.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# subset-build-guest.sh — guest side of build/aarch64/subset-build.sh.
# Runs inside the Plan 9 mount namespace (nsrun.sh --wrap): /sys is the
# checkout's sys, /aarch64 the committed arch dir. Never committed;
# the host driver regenerates it each run.
set -e

fail() { echo "SUBSET-BUILD-FAIL: $1" >&2; exit 1; }

echo "== subset build provenance (Harvey's vendored toolchain):"
echo "   7c: $(command -v 7c)"
echo "   7a: $(command -v 7a)"
echo "   7l: $(command -v 7l)"
echo "   ar: $(command -v ar)"
echo "   mk: $(command -v mk)"

# the namespace binds $HARVEY/aarch64 at /aarch64; mkdirs lays out the
# bin/lib tree it needs (vm-run.sh, unlike nix/build.sh, does not run
# mkdirs first — 02-06 Deviation 2 note; git tracks no empty dirs)
cd "$HARVEY" && bash build/mkdirs || fail "mkdirs"

# libs in dependency order. libc first (idempotent rerun — 02-06
# already proved it green through the committed wiring), then the
# #pragma-lib closure the subset links against (discovered at link
# time per the plan's flagged assumptions): ls/ps/sed/wc/grep →
# libbio; sed → libregexp; ipconfig → libip + libndb; factotum →
# libauth + libauthsrv + libmp/libsec transitives + libString +
# libthread + lib9p.  05-02: paqfs adds libflate (flate.h's
# #pragma lib) to the closure.
for d in libc libbio libregexp libip libndb libmp libsec libString libthread lib9p libauth libauthsrv libflate; do
	echo "== subset lib: $d"
	(cd "/sys/src/$d" && objtype=aarch64 mk install) || fail "lib $d"
done

# the four directory commands. auth/factotum uses the per-target
# install rule (mkmany's %.install): the dir's TARG also carries fgui,
# factotum's GUI companion, which needs the out-of-scope graphics stack
# (libdraw/libcontrol) — fgui is not in the named subset, and building
# the GUI libs to satisfy it would violate the subset scoping (the
# plan's own single-file idiom applied at the dir level).
for d in rc grep ip/ipconfig; do
	echo "== subset cmd: $d"
	(cd "/sys/src/cmd/$d" && objtype=aarch64 mk install) || fail "cmd $d"
done
echo "== subset cmd: auth/factotum (per-target install)"
(cd /sys/src/cmd/auth/factotum && objtype=aarch64 mk factotum.install) || fail "cmd auth/factotum"

# the twelve single-file commands via cmd's per-target install rule
echo "== subset cmd: cat cp date echo ls mkdir mv ps rm sed test wc (per-target install)"
cd /sys/src/cmd
objtype=aarch64 mk cat.install cp.install date.install echo.install \
	ls.install mkdir.install mv.install ps.install rm.install \
	sed.install test.install wc.install || fail "cmd single-file set"

# 05-02 Task 1: the boot chain — boot(8) for aarch64 via the additive,
# objtype-gated mkfile.aarch64 (05-RESEARCH Pattern 2 / Pitfall 2: boot
# has no standalone mkfile; the amd64 path awk-generates the bootconf
# from a kernel config, and the hand-written bootr9.c is the generated
# equivalent here).  Build in-tree, harvest to build/aarch64/out/boot
# (gitignored), then clean the boot dir so the guest tree stays
# pristine (no *.7/libboot.a7/boot artifacts left behind).
echo "== boot chain: boot(8) aarch64 (05-02)"
(cd /sys/src/9k/boot && objtype=aarch64 mk -f mkfile.aarch64) || fail "boot(8) aarch64 build"
mkdir -p "$HARVEY/build/aarch64/out"
cp /sys/src/9k/boot/boot "$HARVEY/build/aarch64/out/boot" || fail "harvest boot to out/"
(cd /sys/src/9k/boot && objtype=aarch64 mk -f mkfile.aarch64 clean) || fail "boot dir clean"

# 05-02 Task 2: init, paqfs, and stacksmoke join the image supply
# chain.  init installs via cmd's per-target rule — cmd/mkfile's
# special $BIN/init rule lands it at /aarch64/init (boot's execinit
# builds /$objtype/init), so harvest from there, not /aarch64/bin.
# paqfs installs per-target from its own dir (NEVER the dir's whole
# mkmany TARG — that would also build mkpaqfs for aarch64, which only
# the host needs).  stacksmoke is 05-01's D-15 deep-recursion binary
# (build/aarch64/stacksmoke.c), recompiled here so it ships in the
# real image too (D-15).
echo "== boot chain: init paqfs stacksmoke (05-02)"
(cd /sys/src/cmd && objtype=aarch64 mk init.install) || fail "init.install"
cp /aarch64/init "$HARVEY/build/aarch64/out/init" || fail "harvest init to out/"
(cd /sys/src/cmd/paqfs && objtype=aarch64 mk paqfs.install) || fail "paqfs.install"
cp /aarch64/bin/paqfs "$HARVEY/build/aarch64/out/paqfs" || fail "harvest paqfs to out/"
(cd "$HARVEY/build/aarch64" && objtype=aarch64 7c -FTVw stacksmoke.c \
	&& objtype=aarch64 7l -o "$HARVEY/build/aarch64/out/stacksmoke" stacksmoke.7 \
	&& rm -f stacksmoke.7) || fail "stacksmoke"

echo "== subset tree (/aarch64/bin):"
ls /aarch64/bin
echo "-- ip:"
ls /aarch64/bin/ip
echo "-- auth:"
ls /aarch64/bin/auth

echo "SUBSET-BUILD-OK"
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
	echo "error: guest subset build failed (rc=$RC); log: $LOG" >&2
	echo "hint: the log names the first failing mk step (SUBSET-BUILD-FAIL: <dir>)" >&2
	exit $RC
fi
/usr/bin/grep -q 'SUBSET-BUILD-OK' "$LOG" || err "guest build log lacks SUBSET-BUILD-OK"

if [ -z "$NATIVE_LINUX" ]; then
	# rsync the resulting /aarch64/bin tree back to the host checkout
	# (gitignored: /aarch64/*bin)
	echo "== pulling the subset tree back to host aarch64/bin"
	mkdir -p "$HARVEY/aarch64/bin"
	rsync -a --delete -e "$RSYNC_RSH" \
		"$GUEST:$GUEST_DIR/aarch64/bin/" "$HARVEY/aarch64/bin/"

	# 05-02: pull the boot-chain binaries back to the host's gitignored
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
		"$HARVEY/build/aarch64/out/"
else
	# native linux: the namespace bound the real checkout — the subset
	# tree and out/ binaries are already in place.
	echo "== native build: artifacts already in place (no rsync-back)"
fi

# assert the sixteen expected binaries on the host side
for f in rc grep cat cp date echo ls mkdir mv ps rm sed test wc; do
	[ -x "$HARVEY/aarch64/bin/$f" ] || err "aarch64/bin/$f missing after rsync-back"
done
[ -x "$HARVEY/aarch64/bin/ip/ipconfig" ] || err "aarch64/bin/ip/ipconfig missing after rsync-back"
[ -x "$HARVEY/aarch64/bin/auth/factotum" ] || err "aarch64/bin/auth/factotum missing after rsync-back"

# 05-02: every boot-chain binary must carry the arm64 a.out magic
# (R_MAGIC 0x8C47, BE)
for f in boot init paqfs stacksmoke; do
	[ -s "$HARVEY/build/aarch64/out/$f" ] || err "build/aarch64/out/$f missing after rsync-back"
	magic=$(od -An -tx1 -N4 "$HARVEY/build/aarch64/out/$f" | tr -d ' \n')
	[ "$magic" = "00008c47" ] || err "build/aarch64/out/$f: bad magic $magic (want 00008c47)"
done

echo "== PASS: aarch64 shell-boot subset built and installed ($(ls "$HARVEY/aarch64/bin" | wc -l | tr -d ' ') entries in aarch64/bin; log: $LOG)"
