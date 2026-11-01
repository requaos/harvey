# darwin: run the Linux namespace kernel build inside a lima VM.
#
# The kernel build (sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE) bind-mounts
# $HARVEY subdirs onto /sys, /amd64, /386, /rc, ... — and bind-mounting a
# virtiofs subdirectory silently yields an empty tree, so this CANNOT run
# on the lima shared mount. Instead we rsync the checkout to guest-local
# disk, build there, and rsync the artifacts (amd64/, 386/, aarch64/) back.
#
# Wrapper provides: LIMA_YAML; lima + openssh + rsync on PATH.
HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="harvey-build"

if [ ! -d "$HARVEY/sys/src" ]; then
  echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2
  exit 1
fi

# Pinned kernel timestamp (BUILD-04); override with KERNDATE=<epoch>.
# Computed host-side: the rsync below excludes .git, so the guest checkout
# has no git metadata to derive from. Falls back to build time when git
# metadata is absent (non-reproducible; see build/REPRODUCIBILITY.md).
if [ -z "${KERNDATE:-}" ]; then
	KERNDATE=$(cd "$HARVEY" && git log -1 --format=%ct 2>/dev/null) || KERNDATE=
fi
# Numeric validation: date(1) dialects differ (plan9port -n vs GNU/BSD +%s).
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date -n 2>/dev/null) || KERNDATE=
fi
if ! [[ "$KERNDATE" =~ ^[0-9]+$ ]]; then
	KERNDATE=$(date +%s)
fi

# NOTE: $PLAN9/bin is last in PATH (wrapper), so host tools win; call host
# grep explicitly — plan9 grep does not support -q/-x.
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
  --exclude 'result*' --exclude '9legacy.iso*' --exclude '*.tgz' \
  "$HARVEY/" "$GUEST:$GUEST_DIR/"

echo "== building in guest (native linux)"
# shellcheck disable=SC2016
ssh -F "$SSH_CFG" "$GUEST" "KERNDATE=$KERNDATE bash -lc 'set -e; cd \"$GUEST_DIR\" && nix run .#setup && nix run .#toolchain && nix run .#build'" || {
	RC=$?
	echo "error: guest build failed (rc=$RC) — refusing to rsync artifacts back" >&2
	exit $RC
}

echo "== pulling artifacts back (amd64/, 386/, aarch64/)"
for d in amd64 386 aarch64; do
  rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIR/$d/" "$HARVEY/$d/"
done

echo "harvey VM build complete; artifacts synced into $HARVEY/{amd64,386,aarch64}"
