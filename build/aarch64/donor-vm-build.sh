#!/bin/sh
# build/aarch64/donor-vm-build.sh — host driver for the donor
# kernel build: the pinned 9front checkout (350266104f1fed81c78c3d05fa44
# f523bec0ae4d) builds its own CONF=qemu arm64 kernel IN THE DONOR TREE
# inside the lima guest's Linux mount namespace, with Harvey's vendored
# 7a/7c/7l + iar on PATH (provenance logged via `command -v`).
#
# Steps (vm-run.sh/pre-gate-build.sh machinery):
#   1. ensure .build/9front-donor at the pin (fetch + hard rev-parse
#      gate — the single supply-chain input)
#   2. ensure lima VM 'harvey' is Running
#   3. rsync this checkout to guest dir harvey-build-donor — DISTINCT
#      from vm-run.sh's default harvey-build, which the
#      pre-gate build owns and mutates with guest-only scratch
#      injection; the second checkout makes same-run namespace
#      builds race-free under parallel execution (declared
#      guest-state partitioning)
#   4. ensure the guest toolchain inside harvey-build-donor (first run
#      builds hostbin there via nix run .#setup / .#toolchain; cached
#      across reruns — .build is rsync-excluded), then rebuild iar so
#      it tracks the vendored 9cc sources
#   5. rsync the donor checkout separately to guest dir 9front-donor
#      (vm-run's exclusion set drops .build, so the donor needs its own
#      rsync line; plain -a, no --delete: the build's outputs live in
#      the guest donor tree, keeping reruns incremental)
#   6. ssh the guest to run build/aarch64/donor-ns-build.sh, which
#      self-wraps into sudo unshare -m (RUN_BUILD_IN_PRIVATE_NAMESPACE
#      shape) and builds: host helpers, donor libc + kernel LIBs,
#      bootdir/bootfs binaries, then mk CONF=qemu → 9qemu + 9qemu.u,
#      then assembles ~/9front-dist (kernel + srvroot/)
#   7. rsync the guest's 9front-dist back to .build/9front-dist/ on the
#      host; propagate exit status
#
# The full guest build transcript (including the provenance lines)
# is captured to .build/9front-dist/donor-build.log and echoed at the
# end; a failed run exits non-zero with the log intact (the pre-gate
# capture-then-cat pattern — POSIX sh has no pipefail).
#
# Boundary: the donor kernel and tree never enter Harvey's
# tracked tree; .build/ is gitignored; only this harness is committed.
#
# Wrapper/env provides: limactl + openssh + rsync on PATH (nix devshell
# on darwin), same as vm-run.sh.
#
# usage: sh build/aarch64/donor-vm-build.sh   (from the repo root,
#        inside the nix devshell)

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build-donor}"
GUEST_DONOR="${DONOR_GUEST_DIR:-9front-donor}"
GUEST_DIST=9front-dist
LIMA_YAML="${LIMA_YAML:-$HARVEY/nix/lima-harvey.yaml}"
DONOR="$HARVEY/.build/9front-donor"
DONOR_SHA=350266104f1fed81c78c3d05fa44f523bec0ae4d
DIST="$HARVEY/.build/9front-dist"
LOG="$DIST/donor-build.log"

if [ ! -d "$HARVEY/sys/src" ]; then
	echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2
	exit 1
fi
mkdir -p "$DIST"

# Resolve a host grep once (D-02): the VM-listing grep below needs
# -q/-x, which plan9 grep lacks — but a hardcoded /usr/bin/grep breaks
# on NixOS-class hosts, so fall back to PATH.
GREP=$(command -v /usr/bin/grep || command -v grep) || { echo "error: no host grep found" >&2; exit 1; }

# 1. donor pin gate (fetch if missing)
if [ ! -d "$DONOR/.git" ]; then
	echo "== cloning 9front donor at $DONOR_SHA"
	mkdir -p "$DONOR"
	git -C "$DONOR" init -q
	git -C "$DONOR" remote add origin https://github.com/9front/9front.git 2>/dev/null || true
	git -C "$DONOR" fetch -q --depth 1 origin "$DONOR_SHA"
	git -C "$DONOR" checkout -q FETCH_HEAD
fi
actual=$(git -C "$DONOR" rev-parse HEAD 2>/dev/null || echo missing)
if [ "$actual" != "$DONOR_SHA" ]; then
	echo "error: donor pin mismatch: want $DONOR_SHA, have $actual" >&2
	exit 1
fi
echo "== donor pin verified ($DONOR_SHA)"

# 2. VM up (vm-run.sh shape; the devshell prepends Plan 9 tools, so
#    use the resolved host grep — plan9 grep has no -q/-x)
if ! limactl list -q 2>/dev/null | "$GREP" -qx "$VM"; then
	echo "creating lima VM '$VM' (first run downloads the guest image + nix)..."
	limactl start --name="$VM" --tty=false "$LIMA_YAML"
else
	status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
	if [ "$status" != "Running" ]; then
		limactl start "$VM"
	fi
fi

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

# 3. push the checkout to the donor-dedicated guest dir
echo "== pushing checkout to guest ~/$GUEST_DIR"
rsync -a --delete -e "$RSYNC_RSH" \
	--exclude .git --exclude .build --exclude .planning --exclude graphify-out \
	--exclude 'result*' --exclude '9legacy.iso*' --exclude '*.tgz' --exclude 'build/harness/target' \
	"$HARVEY/" "$GUEST:$GUEST_DIR/"

# 4. guest toolchain (7a/7c/7l + iar). Sentinels: 7c + ar. Then always
#    rebuild 7a/7c/7l + iar so the guest tools track the vendored sources
#    (the sentinel path skips BUILDTOOLCHAIN entirely;
#    each is seconds, idempotent, and must not go stale).
GHB="$GUEST_DIR/.build/hostbin-linux-aarch64/bin"
echo "== ensuring guest toolchain (7c, ar) in ~/$GUEST_DIR"
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && if [ ! -x \"$GHB/7c\" ] || [ ! -x \"$GHB/ar\" ]; then nix run .#setup && nix run .#toolchain; fi"
echo "== rebuilding guest 7a/7c/7l + iar (ar) from vendored sources"
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c sh -c 'for t in 7a 7c 7l; do (cd sys/src/cmd/\$t && sh BUILD) || exit 1; done' && nix develop -c sh -c 'cd sys/src/cmd/unix/9cc && sh BUILD'"

# 4b. the toolchain is rebuilt unconditionally above, but mk's freshness
#     graph does not name the toolchain binaries as prerequisites — donor
#     objects compiled by a previous toolchain would be relinked STALE
#     (observed: pool.7 survived the pswt.c LP64 fix
#     and the donor kernel's blockcheck panic persisted byte-identical).
#     Sweep compiler outputs from the guest donor tree: *.7 objects, the
#     $O.<name> linked intermediates (7.paqfs, 7.rc, ... — mk sees them
#     fresh vs unchanged sources and skips recompiles even when /arm64/
#     bin was cleaned), and the installed arm64/{lib,bin,init}. Tracked
#     donor sources are excluded: 7c/7.out.h + libmach/7.c from the 7.*
#     arm, and the awk test fixtures cmd/awk/test/{p.7,expected.p.7}
#     from the *.7 arm. Planted generators (unix.maketab, mklatin.unix),
#     the corrected systab.h and the ucd tables are all named
#     differently and survive.
echo "== sweeping stale donor compiler outputs in ~/$GUEST_DONOR"
ssh -F "$SSH_CFG" "$GUEST" "find \"$GUEST_DONOR/sys/src\" -name '*.7' ! -path '*/cmd/awk/test/*' -delete; find \"$GUEST_DONOR/sys/src\" -name '7.*' ! -name '7.out.h' ! -name '7.c' -delete; rm -rf \"$GUEST_DONOR/arm64/lib\" \"$GUEST_DONOR/arm64/bin\" \"$GUEST_DONOR/arm64/init\""

# 5. push the donor checkout (no --delete: guest build outputs live in
#    the tree, so reruns are incremental; the pin is immutable)
echo "== pushing donor checkout to guest ~/$GUEST_DONOR"
rsync -a -e "$RSYNC_RSH" --exclude .git \
	"$DONOR/" "$GUEST:$GUEST_DONOR/"

# 6. the in-donor-tree namespace build. Transcript → the log;
#    exit status propagated after the cat so the provenance proof and
#    the artifacts always come from the same run.
echo "== running donor build in guest namespace (log: $LOG)"
set +e
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c sh build/aarch64/donor-ns-build.sh" > "$LOG" 2>&1
RC=$?
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: guest donor build failed (rc=$RC); log: $LOG" >&2
	echo "hint: the log names the first failing mk target; per D-07 an intractable" >&2
	echo "      donor build is a checkpoint:decision (pinned-prebuilt fallback), not" >&2
	echo "      a patch invitation — do not edit donor sources" >&2
	exit $RC
fi

# 7. pull the artifacts back (kernel + srvroot). --delete keeps the dist
#    faithful to the guest build; the logs are host-side products, so
#    exclude them from deletion.
echo "== pulling 9front-dist back to host .build/9front-dist"
rsync -a --delete -e "$RSYNC_RSH" \
	--exclude donor-build.log --exclude boot-9qemu.log \
	"$GUEST:$GUEST_DIST/" "$DIST/"

[ -s "$DIST/9qemu" ] || { echo "error: $DIST/9qemu missing/empty after rsync" >&2; exit 1; }
[ -s "$DIST/9qemu.u" ] || { echo "error: $DIST/9qemu.u missing/empty after rsync" >&2; exit 1; }
[ -d "$DIST/srvroot/arm64/bin" ] || { echo "error: $DIST/srvroot incomplete after rsync" >&2; exit 1; }
echo "== donor build OK: $DIST/9qemu{,.u} + srvroot/ (log: $LOG)"
