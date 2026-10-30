# Populate the harvey host-tool bin dir per BUILD_ON_UNIX.
# Wrapper provides: PLAN9; plan9port+coreutils on PATH.
HARVEY="${HARVEY:-$PWD}"

if [ ! -d "$HARVEY/sys/src" ]; then
  echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2
  exit 1
fi

# host-tool bin is per-OS/arch: this checkout may be shared with the lima
# build VM (or other hosts), and guest binaries must not clobber host ones
_hb_os=$(uname -s); _hb_os=${_hb_os,,}
_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
export HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin}"
mkdir -p "$HARVEY_LINUX_BIN"

# rm+copy (never follow symlinks into the read-only nix store) and make
# writable so later build steps (e.g. cmd/BUILD cp'ing the real pcc) can
# overwrite these bootstrap copies.
install_tool() {
  rm -f "$HARVEY_LINUX_BIN/$2"
  cp "$1" "$HARVEY_LINUX_BIN/$2"
  chmod u+w "$HARVEY_LINUX_BIN/$2"
}

# pcc bootstrap: plan9port's 9c driver (NOT a symlink — sys/src/cmd/BUILD
# later compiles Harvey's own pcc.c and cp's over this)
install_tool "$PLAN9/bin/9c" pcc

# plan9 userland tools the mkfiles expect next to the toolchain
for t in sed yacc lex awk date dd rm basename ls; do
  install_tool "$PLAN9/bin/$t" "$t"
done

# size(1) is not needed but is invoked; stub it (from BUILD_IN_DOCKER).
# NB: can't copy coreutils' true(1) — nixpkgs links it into the multicall
# binary, which then errors on argv[0]=="size".
rm -f "$HARVEY_LINUX_BIN/size"
printf '#!/bin/sh\nexit 0\n' > "$HARVEY_LINUX_BIN/size"
chmod +x "$HARVEY_LINUX_BIN/size"

echo "harvey host bin ready: $HARVEY_LINUX_BIN"
ls "$HARVEY_LINUX_BIN"
