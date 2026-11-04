#!/usr/bin/env bash
# build/aarch64/pre-gate-build.sh — the riscv64-vaporware pre-gate:
# compile libc for aarch64 and link a hello-world Plan 9 binary using
# the COMMITTED mkfiles, with the pre-gate arch scaffolding
# (aarch64/mkfile + aarch64/include/{u.h,ureg.h}) injected into the
# DISPOSABLE GUEST COPY ONLY. The committed tree gains the linked
# binary (build/aarch64/hello.7.out) but no arch scaffolding —
# aarch64/, CPUS, pcc.c all landed post-gate.
#
# OBSOLETE: the arch scaffolding is now committed (aarch64/
# mkfile, include/{u.h,ureg.h}, ABI.md), so the guest-scratch injection
# this script exists to perform is already wired in. The script refuses
# to run on a current tree (the guard below, exit 2); use
# objtype=aarch64 mk in the namespace instead. Kept committed as the
# historical record of how hello.7.out was produced pre-gate.
#
# Steps:
#   1. pin-verify .build/9front-donor (the single supply-chain
#      input)
#   2. rsync this checkout to the lima guest (vm-run.sh exclusion set)
#      and ensure the guest toolchain (7a/7c/7l, iar)
#   3. guest-only scratch injection: aarch64/mkfile (the known 5-line
#      objtype file — now committed
#      identically) + aarch64/include/{u.h,ureg.h} copied from the
#      pinned donor (the committed copies assert sha256
#      equality with the copies used here) + aarch64/lib/
#   4. namespace build via nsrun.sh (which conditionally binds
#      /aarch64 now that the guest copy has it):
#        cd /sys/src/libc && objtype=aarch64 mk nuke && mk install
#      runs the COMMITTED libc mkfiles (PORTDIRS 9sys 9syscall fmt
#      port + aarch64) — the new 9syscall `case aarch64` block
#      generates every SVC stub and 7a assembles them into
#      /aarch64/lib/libc.a — then 7c/7l build the gate program
#      (7l resolves the libc.a pragma via /aarch64/lib)
#   5. pull hello.7.out back to the host checkout (committed gate
#      evidence — this precedes any arch scaffolding)
#   6. assert the host checkout gained no aarch64/ dir
#
# Guest-state partitioning: mutates the default guest dir
# harvey-build only (the donor build uses
# harvey-build-donor); the guest copy is disposable — the next
# rsync --delete removes the scratch injection.
#
# Wrapper/env provides: limactl + openssh + rsync on PATH (nix
# devshell on darwin), same as vm-run.sh.
#
# usage: bash build/aarch64/pre-gate-build.sh   (from the repo root,
# inside the nix devshell)

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"
DONOR="$HARVEY/.build/9front-donor"
DONOR_SHA=350266104f1fed81c78c3d05fa44f523bec0ae4d
LOG="$HARVEY/build/aarch64/pre-gate-build.log"

# Resolve a host grep once (D-02): the VM-listing grep below needs
# -q/-x, which plan9 grep lacks — but a hardcoded /usr/bin/grep breaks
# on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || { echo "error: no host grep found" >&2; exit 1; }

if [ ! -d "$HARVEY/sys/src" ]; then
	echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2
	exit 1
fi

# obsolescence guard: the arch scaffolding is committed, so the
# guest-scratch injection below is already wired in — running this
# script would only rebuild what the namespace build does directly.
if [ -e "$HARVEY/aarch64/mkfile" ]; then
	echo "pre-gate-build.sh is obsolete post-02-06 (aarch64/ is committed); use objtype=aarch64 mk in the namespace" >&2
	exit 2
fi

# 1. donor pin gate
actual=$(git -C "$DONOR" rev-parse HEAD 2>/dev/null || echo missing)
if [ "$actual" != "$DONOR_SHA" ]; then
	echo "error: donor pin mismatch: want $DONOR_SHA, have $actual" >&2
	exit 1
fi
echo "== donor pin verified ($DONOR_SHA)"

# 2. VM up + rsync (vm-run.sh shape; the devshell prepends Plan 9
#    tools, so use the resolved host grep)
if ! limactl list -q 2>/dev/null | "$GREP" -qx "$VM"; then
	echo "error: lima VM '$VM' does not exist" >&2
	exit 1
fi
status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
if [ "$status" != "Running" ]; then
	limactl start "$VM"
fi

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

echo "== pushing checkout to guest ~/$GUEST_DIR"
rsync -a --delete -e "$RSYNC_RSH" \
	--exclude .git --exclude .build --exclude .planning --exclude graphify-out \
	--exclude 'result*' --exclude '9legacy.iso*' --exclude '*.tgz' --exclude 'build/harness/target' \
	"$HARVEY/" "$GUEST:$GUEST_DIR/"

# ensure the guest toolchain: .#setup populates the guest hostbin,
# .#toolchain runs BUILDTOOLCHAIN (7a/7c/7l included) and the vendored
# 9cc build (iar, installed as ar). Sentinels: 7c + ar.
GHB="$GUEST_DIR/.build/hostbin-linux-aarch64/bin"
echo "== ensuring guest toolchain (7c, ar)"
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && if [ ! -x \"$GHB/7c\" ] || [ ! -x \"$GHB/ar\" ]; then nix run .#setup && nix run .#toolchain; fi"

# always rebuild iar in the guest: the sentinel check above skips
# stale binaries, and iar must track the vendored 9cc libmach sources
# (its .7-object SYMDEF support landed with this plan). Cheap and
# idempotent (~seconds).
echo "== rebuilding guest iar (ar) from vendored 9cc"
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c sh -c 'cd sys/src/cmd/unix/9cc && sh BUILD'"

# 3. guest-only scratch injection — these files exist ONLY in the
#    disposable guest tree, never in the committed checkout.
echo "== injecting guest-scratch aarch64/ scaffolding (guest copy only)"
ssh -F "$SSH_CFG" "$GUEST" "mkdir -p $GUEST_DIR/aarch64/include $GUEST_DIR/aarch64/lib"
rsync -e "$RSYNC_RSH" "$DONOR/arm64/include/u.h" "$DONOR/arm64/include/ureg.h" \
	"$GUEST:$GUEST_DIR/aarch64/include/"
ssh -F "$SSH_CFG" "$GUEST" "cat > $GUEST_DIR/aarch64/mkfile" <<'EOF'
</sys/src/mkfile.proto

CC=7c
LD=7l
AS=7a
O=7
EOF

# 4. namespace build. /build is not a namespace bind, so the compile
#    runs from the real guest path ($HARVEY is re-sourced by
#    nsrun.sh's su tail); /sys and /aarch64 are the Plan 9 absolutes.
CMD='cd /sys/src/libc && objtype=aarch64 mk nuke && objtype=aarch64 mk install && cd "$HARVEY/build/aarch64" && 7c -FVw hello.c && 7l -o /aarch64/hello.7.out hello.7'
QCMD=$(printf '%q' "$CMD")
echo "== running in guest namespace: $CMD"
set +e
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c bash build/aarch64/nsrun.sh --wrap $QCMD" > "$LOG" 2>&1
RC=$?
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: guest namespace build failed (rc=$RC); log: $LOG" >&2
	exit $RC
fi

# 5. pull the gate evidence binary back to the host checkout
echo "== pulling hello.7.out back to host"
rsync -e "$RSYNC_RSH" "$GUEST:$GUEST_DIR/aarch64/hello.7.out" \
	"$HARVEY/build/aarch64/hello.7.out"

# 6. the committed tree must stay scaffolding-free
if [ -e "$HARVEY/aarch64" ]; then
	echo "error: aarch64/ leaked into the committed tree" >&2
	exit 1
fi
[ -s "$HARVEY/build/aarch64/hello.7.out" ] || {
	echo "error: hello.7.out missing/empty on the host" >&2
	exit 1
}
echo "== pre-gate build OK: build/aarch64/hello.7.out (log: $LOG)"
