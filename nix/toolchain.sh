# Build the Plan 9 cross toolchain (6a/6c/6l, 8a/8c/8l, cpp, aux) and pcc.
# Wrapper provides: PLAN9; plan9port+bash on PATH.
HARVEY="${HARVEY:-$PWD}"
export HARVEY
# host-tool bin is per-OS/arch: this checkout may be shared with the lima
# build VM (or other hosts), and guest binaries must not clobber host ones
_hb_os=$(uname -s); _hb_os=${_hb_os,,}
_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
export HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin}"
# Wrapper PATH (no hostbin/shim) for the vendored 9cc build below: 9cc/BUILD
# invokes bare `ar`, and once iar is installed as $HARVEY_LINUX_BIN/ar the
# hostbin prepend would resolve `ar` to iar — which writes Plan 9-format
# archives that GNU ld rejects ("archive has no index"). 9cc/BUILD needs
# nothing from hostbin, so run it with the wrapper PATH (GNU ar).
_WRAP_PATH="$PATH"
export PATH="$HARVEY_LINUX_BIN:$PATH"

if [ ! -x "$HARVEY_LINUX_BIN/pcc" ]; then
  echo "error: $HARVEY_LINUX_BIN not populated — run 'nix run .#setup' first" >&2
  exit 1
fi

# 6c/BUILD and 8c/BUILD link with -static, which works with neither modern
# Apple ld (no crt0.o) nor nix's glibc toolchain (no static libc). Shim 9l
# to drop -static on all platforms.
SHIMDIR="$(mktemp -d "${TMPDIR:-/tmp}/harvey-9l-shim.XXXXXX")"
cat > "$SHIMDIR/9l" << 'SHIM'
#!/usr/bin/env bash
args=()
for a in "$@"; do
  [ "$a" = "-static" ] || args+=("$a")
done
exec "${PLAN9:?}/bin/9l" "${args[@]}"
SHIM
chmod +x "$SHIMDIR/9l"
# plan9port's 9l autolib calls bare `nm` on HOST ELF objects; with
# $HARVEY_LINUX_BIN on PATH that resolves to Harvey's nm (nm.BUILD, plan
# 02-03), which reads ken-format objects only and fails ("Can't read
# header"), silently breaking autolib (undefined Binit/Bputc/... at link).
# Shadow it with the wrapper PATH's (binutils) nm for the duration.
_HOSTNM=$(PATH="$_WRAP_PATH" command -v nm 2>/dev/null || true)
if [ -n "$_HOSTNM" ]; then
  ln -sf "$_HOSTNM" "$SHIMDIR/nm"
fi
export PATH="$SHIMDIR:$PATH"
# /bin/rm explicitly: $HARVEY_LINUX_BIN may hold guest-built Linux binaries
trap '/bin/rm -rf "$SHIMDIR"' EXIT

(cd "$HARVEY/sys/src" && sh BUILDTOOLCHAIN)
(cd "$HARVEY/sys/src/cmd" && bash BUILD)
# vendored 9-cc subset (sys/src/cmd/unix/9cc) — builds iar, installs as ar
(cd "$HARVEY/sys/src/cmd/unix/9cc" && PATH="$_WRAP_PATH" sh BUILD)

echo "harvey toolchain built into $HARVEY_LINUX_BIN"
