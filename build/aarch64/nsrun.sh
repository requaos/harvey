#!/usr/bin/env bash
# build/aarch64/nsrun.sh — run an arbitrary command inside the Harvey
# Plan 9 mount namespace on a Linux host (the lima guest on darwin).
#
# This is the command-parameterized form of
# sys/src/BUILD_SETUP_NAMESPACE + sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE:
# same bind set, same merged-/lib staging, but the tail runs a
# caller-supplied command instead of ./BUILD.
#
# Modes:
#   nsrun.sh --wrap '<command>'          guest-side wrapper, run as the
#       repo user in the devshell env (vm-run.sh does this). Captures
#       the exports (sudo/su reset env), re-enters as root under a
#       private mount namespace, propagates the command's exit status.
#   nsrun.sh <user> <exports-file> '<command>'
#       root, inside the namespace: bind the Harvey tree and su the
#       command to <user>. Never invoked by hand — see --wrap.
#
# If $HARVEY/aarch64 exists it is additionally bound at /aarch64
# (pre-gate the dir exists only in scratch copies; post-gate it is
# committed — the same script serves both).

set -u

if [ "${1:-}" = "--wrap" ]; then
	# guest-side wrapper (repo user, devshell env provides
	# PLAN9/HARVEY/HARVEY_LINUX_BIN/PATH)
	set -e
	CMD="${2:?usage: nsrun.sh --wrap '<command>'}"
	EXPORTS=/tmp/nsrun-exports.$$
	export > "$EXPORTS"
	set +e
	sudo unshare -m bash "$HARVEY/build/aarch64/nsrun.sh" "$USER" "$EXPORTS" "$CMD"
	RC=$?
	rm -f "$EXPORTS"
	exit $RC
fi

# root, inside the private mount namespace.
BUILD_USER="${1:?usage: nsrun.sh <user> <exports-file> '<command>'}"
ENVFILE="${2:?usage: nsrun.sh <user> <exports-file> '<command>'}"
CMD="${3:?usage: nsrun.sh <user> <exports-file> '<command>'}"

# fail hard on any setup error: an unchecked bind/staging failure leaves
# a partial namespace and the command then dies later with misleading
# missing-include errors. (The --wrap branch above sets -e itself; the
# su capture at the bottom re-disables it around the deliberate status
# capture.)
set -e

# captured devshell exports: HARVEY, HARVEY_LINUX_BIN, PLAN9, PATH, ...
. "$ENVFILE"

cd "$HARVEY/sys/src"

# /sys from the checkout (same as BUILD_SETUP_NAMESPACE's `bind ..`).
mount --bind .. /sys

# per-arch dirs (no for loop — keep it shell-agnostic)
mkdir -p /arm
mount --bind $HARVEY/arm /arm

mkdir -p /amd64
mount --bind $HARVEY/amd64 /amd64

mkdir -p /386
mount --bind $HARVEY/386 /386

mkdir -p /mips
mount --bind $HARVEY/mips /mips

mkdir -p /mips64
mount --bind $HARVEY/mips64 /mips64

mkdir -p /power
mount --bind $HARVEY/power /power

mkdir -p /power64
mount --bind $HARVEY/power64 /power64

mkdir -p /riscv
mount --bind $HARVEY/riscv /riscv

mkdir -p /riscv64
mount --bind $HARVEY/riscv64 /riscv64

mkdir -p /sparc
mount --bind $HARVEY/sparc /sparc

mkdir -p /acme
mount --bind $HARVEY/acme /acme

mkdir -p /rc
mount --bind $HARVEY/rc /rc

# mk recipes backquote rc scripts whose shebang is #!/bin/rc (membername in
# the boot mkfiles: 9k/mk/bootmkfile, 9/boot/bootmkfile, 9k/boot/mkfile.aarch64).
# The namespace shares the distro /bin, which has no rc on a fresh host — the
# legacy docker path provided it globally (build/Dockerfile: cp $PLAN9/bin/rc
# /bin/rc).  Bind the wrapper's rc over /bin/rc here; the mount namespace is
# private, and if the mountpoint had to be created it is an inert empty file
# on the host — the same class as the /arm, /386, ... mountpoint dirs above.
[ -x "$PLAN9/bin/rc" ] || { echo "error: nsrun: $PLAN9/bin/rc not executable — run via the nix devshell/app wrapper, which exports PLAN9" >&2; exit 1; }
[ -e /bin/rc ] || touch /bin/rc
mount --bind "$PLAN9/bin/rc" /bin/rc

mkdir -p /mail
mount --bind $HARVEY/mail /mail

# /lib must show harvey's lib while keeping the distro runtime
# reachable. A plain bind of $HARVEY/lib over /lib (usrmerge:
# -> /usr/lib) hides the loader + libselinux/libpam/... and every
# distro binary then fails to exec. Stage a merged copy FIRST (while
# /lib is still intact — cp itself needs the loader), then bind it
# over. All of this vanishes when the mount namespace exits.
if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
NSLIB=/tmp/nslib.$$
mkdir -p $NSLIB
cp -a "$LIBREAL"/. $NSLIB/
cp -a $HARVEY/lib/. $NSLIB/
# cp -a of the checkout's lib/. makes NSLIB owned by the repo owner;
# with the sticky bit below that triggers fs.protected_symlinks on the
# root-owned loader symlink (ld-linux-aarch64.so.1 ->
# aarch64-linux-gnu/...): non-root execve of any distro binary then
# fails EACCES. Keep the staged dir root-owned (dir-owner ==
# symlink-owner).
chown 0:0 $NSLIB
chmod 1777 $NSLIB	# build runs as non-root; allow mkdir /lib/audio etc.
mount --bind $NSLIB "$LIBREAL"

mkdir -p /unix
mount --bind $HARVEY/unix /unix

mkdir -p /usr/glenda
mount --bind $HARVEY/usr/glenda /usr/glenda

# post-gate the aarch64 arch dir is committed and rsynced to the
# guest; pre-gate it exists only in scratch copies. Either way, bind
# it only when present.
if [ -d "$HARVEY/aarch64" ]; then
	mkdir -p /aarch64
	mount --bind "$HARVEY/aarch64" /aarch64
fi

# unwind the staged /lib even if the command fails
unwind() {
	umount "$LIBREAL" 2>/dev/null || true
	rm -rf "$NSLIB"
}
trap unwind EXIT

# su resets PATH (login.defs ENV_PATH) — re-source the captured exports
# inside the su shell (Phase 1 su-proof env pattern: BUILD's
# `. buildnamespace`), with the /rc/bin:. tail the rc side of the
# build expects.
set +e
su -c ". '$ENVFILE'; export PATH=\"\$PATH:/rc/bin:.\"; $CMD" "$BUILD_USER"
RC=$?
exit $RC
