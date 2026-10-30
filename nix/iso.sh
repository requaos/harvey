# Full ISO build via the qemu + expect path (build/build.bash).
# Boots the 9legacy ISO in qemu and builds Harvey inside the VM, so this
# works on macOS too (TCG emulation, slow — no KVM outside Linux).
# Wrapper provides: PLAN9; expect+qemu+curl+bzip2+gnutar+git on PATH.
HARVEY="${HARVEY:-$PWD}"

if [ ! -f "$HARVEY/build/build.bash" ]; then
  echo "error: $HARVEY does not look like the harvey checkout (missing build/build.bash)" >&2
  exit 1
fi

cd "$HARVEY/build"
exec bash build.bash
