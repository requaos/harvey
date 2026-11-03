#!/usr/bin/env bash
# build/aarch64/vm-run.sh — run a command inside the Harvey Plan 9
# mount namespace in the lima guest (linux-aarch64), from darwin.
#
# Mirror of nix/vm-build.sh, command-parameterized:
#   1. rsync this checkout to guest-local disk — the namespace build
#      bind-mounts $HARVEY subdirs onto /sys, /amd64, ... and
#      bind-mounting a virtiofs subdirectory silently yields an empty
#      tree, so this CANNOT run on the lima shared mount
#   2. ensure the guest toolchain (guest hostbin 7c + ar/iar via
#      nix run .#setup / .#toolchain on first use)
#   3. ssh the guest to run build/aarch64/nsrun.sh --wrap '<command>'
#      under the devshell env; nsrun.sh captures exports and does the
#      sudo unshare -m namespace entry (RUN_BUILD_IN_PRIVATE_NAMESPACE
#      pattern)
#
# usage: build/aarch64/vm-run.sh '<command>'
# The command runs as the repo user inside the namespace with the
# Harvey tree at /sys, /<arch>, ... (see nsrun.sh). The remote exit
# status is propagated.
#
# Wrapper/env provides: limactl + openssh + rsync on PATH (nix
# devshell on darwin); LIMA_YAML (defaulted below when unset).

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"
LIMA_YAML="${LIMA_YAML:-$HARVEY/nix/lima-harvey.yaml}"

if [ ! -d "$HARVEY/sys/src" ]; then
	echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2
	exit 1
fi
if [ $# -ne 1 ]; then
	echo "usage: $0 '<command>'" >&2
	exit 2
fi
CMD="$1"

# ensure the VM exists and is Running (nix/vm-build.sh shape; the
# devshell prepends Plan 9 tools, so call host grep explicitly —
# plan9 grep does not support -q/-x)
if ! limactl list -q 2>/dev/null | /usr/bin/grep -qx "$VM"; then
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

echo "== pushing checkout to guest ~/$GUEST_DIR"
rsync -a --delete -e "$RSYNC_RSH" \
	--exclude .git --exclude .build --exclude .planning --exclude graphify-out \
	--exclude 'result*' --exclude '9legacy.iso*' --exclude '*.tgz' --exclude 'build/harness/target' \
	"$HARVEY/" "$GUEST:$GUEST_DIR/"

# ensure the guest toolchain: .#setup populates the guest hostbin
# (pcc etc.), .#toolchain runs BUILDTOOLCHAIN (7a/7c/7l included) and
# the vendored 9cc build (iar, installed as ar). Sentinels: 7c + ar.
GHB="$GUEST_DIR/.build/hostbin-linux-aarch64/bin"
echo "== ensuring guest toolchain (7c, ar)"
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && if [ ! -x \"$GHB/7c\" ] || [ ! -x \"$GHB/ar\" ]; then nix run .#setup && nix run .#toolchain; fi"

# run the command in the guest namespace; %q-quote so the caller's
# command string survives exactly one remote shell evaluation and
# arrives at nsrun.sh as a single argv element.
QCMD=$(printf '%q' "$CMD")
echo "== running in guest namespace: $CMD"
set +e
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c bash build/aarch64/nsrun.sh --wrap $QCMD"
RC=$?
set -e
exit $RC
