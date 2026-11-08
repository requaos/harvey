#!/bin/sh
# build/x86_64/stage-build.sh — stage the amd64 marker binaries (14-05,
# XEXEC-02's D-09 marker): compile the C list below natively on a Linux
# host under the Plan 9 mount namespace (objtype=amd64, the vendored
# 6c/6l — subset-build.sh's NATIVE_LINUX shape; there is NO lima leg:
# amd64 builds native-unshare only on this host class).  The staged
# tree lands in the gitignored build/x86_64/smoke-out/; mkimage.sh
# bakes it into bootfs.paq at build/x86_64/out/.
#
# The leg-1 staging rule (D-08/D-09): /amd64/init IS the marker —
# smokesleep is linked once and staged under both names, so the q35exec
# BOOT_ENTRY target is the purpose-built static marker binary and NOT
# the real init (the boot(8) chain is 14-06's leg).  mkimage.sh's
# init-identity guard pins exactly that.
#
# Every staged binary is S_MAGIC (0x8A97, BE) verified here before the
# namespace exit is trusted — the A1 real-binary proof point (the first
# live 6.out evidence on this host; 14-03's synthetic-header tests
# pinned the loader constants, this asserts them on real bytes).
#
# Idempotent: the libc install and every compile are re-run each time.
#
# usage: sh build/x86_64/stage-build.sh   (repo root, inside the nix
# devshell)

set -eu

HARVEY="${HARVEY:-$PWD}"
LOG="${STAGE_BUILD_LOG:-$HARVEY/.build/stage-build-x64.log}"
OUT="$HARVEY/build/x86_64/smoke-out"

# The C sources this script stages: NAME.c -> smoke-out/NAME (6c/6l).
# The marker set this era is the one marker binary (D-09's thin path);
# it is staged as init too (the rule above).
STAGE_SRCS="smokesleep"

err() { echo "error: $*" >&2; exit 1; }

# Resolve a host grep once (D-02): the greps below need -q/-x, which
# plan9 grep lacks — but a hardcoded /usr/bin/grep breaks on
# NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
for f in $STAGE_SRCS; do
	[ -f "$HARVEY/build/x86_64/$f.c" ] || err "build/x86_64/$f.c missing"
done
[ "$(uname -s)" = "Linux" ] || err "build/x86_64/stage-build.sh is native-linux only (sudo unshare; no lima leg — the aarch64 driver's darwin venue does not carry)"

# host toolchain for the namespace build (subset-build.sh's ensure,
# host-side).  HARVEY must be EXPORTED here: nsrun.sh's --wrap captures
# `export` output and re-sources it inside the namespace, and the guest
# script addresses "$HARVEY"/... paths.
export HARVEY
HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-linux-x86_64/bin}"
export HARVEY_LINUX_BIN
if [ ! -x "$HARVEY_LINUX_BIN/6c" ] || [ ! -x "$HARVEY_LINUX_BIN/ar" ]; then
	err "host toolchain missing ($HARVEY_LINUX_BIN/6c) — run 'nix run .#setup && nix run .#toolchain' first (the flake apps; amd64 leg of BUILDTOOLCHAIN)"
fi

# the devshell-env vars the guest script's mk invocations expect (the
# same exports subset-build.sh's native leg sets)
export FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/stage-build-x64.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

# namespace-side script (the single-committed-file discipline): written
# to a host tmp file, executed inside the Plan 9 mount namespace (either
# venue below): /sys is the checkout's sys, /amd64 the committed arch
# dir.  Never committed; the host driver regenerates it each run.
cat > "$TMPD/stage-build-x64-guest.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# stage-build-x64-guest.sh — namespace side of
# build/x86_64/stage-build.sh.  Runs inside the Plan 9 mount namespace:
# /sys is the checkout's sys, /amd64 the committed arch dir ($HARVEY is
# the checkout's own path under the sudo venue, /harvey under the
# userns-chroot venue — both binds name the same files).  Never
# committed; the host driver regenerates it each run.
set -e

fail() { echo "STAGE-BUILD-FAIL: $1" >&2; exit 1; }

STAGE_SRCS="smokesleep"
STAGE="$HARVEY/build/x86_64/smoke-out"

echo "== stage build provenance (Harvey's vendored toolchain):"
echo "   6c: $(command -v 6c)"
echo "   6l: $(command -v 6l)"
echo "   mk: $(command -v mk)"

# the namespace binds $HARVEY/amd64 at /amd64; mkdirs lays out the
# bin/lib tree libc's install needs (the subset-build.sh note)
cd "$HARVEY" && bash build/mkdirs || fail "mkdirs"

# ensure objtype=amd64 libc — idempotent rerun; everything staged here
# links /amd64/lib/libc.a
echo "== stage lib: libc (idempotent)"
(cd /sys/src/libc && objtype=amd64 mk install) || fail "libc"

mkdir -p "$STAGE"
for f in $STAGE_SRCS; do
	echo "== stage compile: build/x86_64/$f.c -> smoke-out/$f"
	(cd "$HARVEY/build/x86_64" && objtype=amd64 6c -FTVw "$f.c" && objtype=amd64 6l -o "$STAGE/$f" "$f.6" && rm -f "$f.6") || fail "$f"
done

# the leg-1 staging rule: the marker IS /amd64/init (D-08/D-09 — one
# binary, two names; mkimage.sh's identity guard pins it)
cp "$STAGE/smokesleep" "$STAGE/init"

echo "== staged tree ($STAGE):"
ls -l "$STAGE"

echo "STAGE-BUILD-OK"
GUEST_EOF

# The chroot scaffold for the passwordless venue (unshare -Ur -m): the
# mkfiles' </$objtype/mkfile> include needs /amd64 at the ROOT, and an
# unprivileged user namespace cannot create mountpoints under the
# parent-owned / — so build the fake root on a PRIVATE TMPFS and chroot
# into it (CAP_SYS_CHROOT holds in the userns; the mapped root is the
# invoking user — same uid, no added privilege, artifacts land owned
# right).
#
# SAFETY (measured the hard way): the scaffold is NEVER cleaned up with
# rm — a recursive delete walking bind mounts deletes THROUGH them into
# the source trees (an `rm -rf $scaffold` trap on a scaffold binding
# sys/amd64/rc erased those trees from the checkout once).  The tmpfs
# owns everything instead: when this shell exits, the user namespace
# and its mount namespace die, the tmpfs unmounts, and the scaffold
# vanishes wholesale — no cleanup path exists, by construction.
#
# Bind discipline (measured on this kernel): a plain bind of a
# directory whose subtree carries other mounts (/nix, /run, /dev) fails
# in a userns — bind the LEAF mounts/paths instead (/nix/store; the
# /run/current-system symlink recreated; /dev/null-class nodes one by
# one), and make /bin a real dir of usrmerge symlinks + the plan9port rc
# bind (nsrun's /bin/rc, on a creatable mountpoint).
cat > "$TMPD/ns-x64-userns.sh" <<'USERNS_EOF'
#!/usr/bin/env bash
# ns-x64-userns.sh — the passwordless venue's namespace side: the tmpfs
# chroot scaffold + the guest script.  Never committed; regenerated
# each run.  No cleanup trap — see the SAFETY note in the host driver.
set -e
NSX=$(mktemp -d "${TMPDIR:-/tmp}/ns-x64-root.XXXXXX")
# the scaffold IS a private tmpfs (mountable in a userns); everything
# below lives on it and dies with the namespace
mount -t tmpfs tmpfs "$NSX"

mkdir -p "$NSX"/{sys,amd64,rc,etc,tmp,harvey,nix/store,run,dev,usr,bin}
mount --bind "$HARVEY_SYS" "$NSX/sys"
mount --bind "$HARVEY_AMD64" "$NSX/amd64"
mount --bind "$HARVEY_RC" "$NSX/rc"
mount --bind /etc "$NSX/etc"
mount --bind /tmp "$NSX/tmp"
mount --bind "$HARVEY_REAL" "$NSX/harvey"
mount --bind /nix/store "$NSX/nix/store"
ln -sfn "$(readlink /run/current-system)" "$NSX/run/current-system"
ln -sfn ../run/current-system/sw/bin "$NSX/usr/bin"
for b in sh bash env cp mv rm ls cat mkdir touch sed grep find od; do
	ln -sfn "../run/current-system/sw/bin/$b" "$NSX/bin/$b"
done
for d in null zero urandom random; do
	touch "$NSX/dev/$d"
	mount --bind "/dev/$d" "$NSX/dev/$d"
done
touch "$NSX/bin/rc"
mount --bind "$PLAN9/bin/rc" "$NSX/bin/rc"

export HARVEY=/harvey
# the hostbin path re-rooted for inside the chroot (the checkout is at
# /harvey there), prepended to PATH so the namespace's mk/6c/6l/ar
# resolve — the same hostbin-FIRST shape the sudo venue exports
INNER_BIN="/harvey${HARVEY_LINUX_BIN#"$HARVEY_REAL"}"
exec chroot "$NSX" /usr/bin/env \
	HARVEY=/harvey \
	HARVEY_LINUX_BIN="$INNER_BIN" \
	PLAN9="$PLAN9" \
	PATH="$INNER_BIN:$PATH" \
	HOME="$HOME" \
	FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix \
	bash "$1"
USERNS_EOF

mkdir -p "$HARVEY/.build"

# venue split: the documented sudo-unshare namespace (nsrun.sh --wrap,
# real root, the su drop) when the host grants passwordless sudo; the
# unprivileged user+mount namespace with a chroot scaffold otherwise
# (CI/agent venues — same binds, no privilege, same uid).
set +e
if sudo -n true 2>/dev/null; then
	echo "== running the stage build in the namespace (sudo unshare; log: $LOG)"
	# hostbin FIRST so the namespace's mk/6c/6l/ar resolve (the
	# devshell's PATH shape; nsrun.sh's su line appends /rc/bin:. itself).
	export PATH="$HARVEY_LINUX_BIN:$PATH"
	bash "$HARVEY/build/aarch64/nsrun.sh" --wrap "bash $TMPD/stage-build-x64-guest.sh" > "$LOG" 2>&1
	RC=$?
else
	echo "== no passwordless sudo — running the stage build in an unprivileged user namespace (unshare -Ur -m chroot scaffold; log: $LOG)"
	HARVEY_SYS="$HARVEY/sys" HARVEY_AMD64="$HARVEY/amd64" HARVEY_RC="$HARVEY/rc" \
	HARVEY_REAL="$HARVEY" HARVEY_LINUX_BIN="$HARVEY_LINUX_BIN" \
	PATH="$HARVEY_LINUX_BIN:$PATH" \
	unshare -Ur -m bash "$TMPD/ns-x64-userns.sh" "$TMPD/stage-build-x64-guest.sh" > "$LOG" 2>&1
	RC=$?
fi
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: namespace stage build failed (rc=$RC); log: $LOG" >&2
	echo "hint: the log names the first failing step (STAGE-BUILD-FAIL: <name>)" >&2
	exit $RC
fi
"$GREP" -q 'STAGE-BUILD-OK' "$LOG" || err "stage build log lacks STAGE-BUILD-OK"

# every staged binary must carry the amd64 a.out magic (S_MAGIC
# 0x8A97, BE) — the A1 real-binary proof, asserted on real 6.out bytes
# and printed as evidence
for f in $STAGE_SRCS init; do
	[ -s "$OUT/$f" ] || err "build/x86_64/smoke-out/$f missing after stage"
	magic=$(od -An -tx1 -N4 "$OUT/$f" | tr -d ' \n')
	[ "$magic" = "00008a97" ] || err "build/x86_64/smoke-out/$f: bad magic $magic (want 00008a97)"
	echo "stage: $f magic 00008a97 verified (amd64 S_MAGIC, A1 real-binary proof)"
done

echo "== PASS: staged $(ls "$OUT" | tr '\n' ' ')into build/x86_64/smoke-out (log: $LOG)"
