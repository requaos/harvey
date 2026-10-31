# Full kernel build inside a private mount namespace (Linux only).
# Mirrors build/BUILD_IN_DOCKER + sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE.
# Wrapper provides: PLAN9; plan9port+bash+util-linux+sudo+gnused+mount on PATH.
HARVEY="${HARVEY:-$PWD}"
export HARVEY
_hb_os=$(uname -s); _hb_os=${_hb_os,,}
_hb_arch=$(uname -m); [ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64
export HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin}"
export PATH="$HARVEY_LINUX_BIN:$PATH:/rc/bin:."
export USER="${USER:-root}"
export objtype=amd64
export cputype=unix
export FORCERCFORMK=1
export CGO_ENABLED=0

for t in pcc cpp ar; do
  if [ ! -x "$HARVEY_LINUX_BIN/$t" ]; then
    echo "error: $HARVEY_LINUX_BIN/$t missing — run 'nix run .#setup' then 'nix run .#toolchain' first" >&2
    exit 1
  fi
done

# mkfile fixups from build/BUILD_IN_DOCKER (idempotent; edit in-tree files).
# GNU_SED (absolute, from wrapper): $HARVEY_LINUX_BIN shadows `sed` with
# plan9 sed, which has no -i.
"$GNU_SED" -i 's|aux/mklatinkbd|mklatinkbd|' \
  "$HARVEY/sys/src/9/port/portmkfile" "$HARVEY/sys/src/9k/mk/portmkfile"
"$GNU_SED" -i 's|aux/data2s|data2s|' \
  "$HARVEY/sys/src/9/port/mkroot" "$HARVEY/sys/src/9/port/mkrootall" \
  "$HARVEY/sys/src/9k/mk/mkroot" "$HARVEY/sys/src/9k/mk/mkrootall"

# bind mounts + mk install need the per-arch output dirs to exist
bash "$HARVEY/build/mkdirs"

# Userland preflight (Pitfall 2): the kernel rootdir embedding
# (9k/mk/parse -> mkrootall) consumes /amd64/bin/{ip/ipconfig,
# auth/factotum, fossil/fossil, venti/venti} at kernel link time and fails
# late with a misleading "don't know how to make" when one is missing.
# Armed by the amd64/.userland-ok sentinel, which is written at the end of
# this script once a build has left all four binaries in place; until then
# the check stays inert so a clean-checkout or repairing run is never
# blocked by state the build itself is about to produce.
if [ -f "$HARVEY/amd64/.userland-ok" ]; then
  for f in amd64/bin/ip/ipconfig amd64/bin/auth/factotum \
           amd64/bin/fossil/fossil amd64/bin/venti/venti; do
    if [ ! -x "$HARVEY/$f" ]; then
      echo "preflight: $f missing — cmd chain incomplete" >&2
      exit 1
    fi
  done
fi

# pcc execs cpp as /bin/cpp; rc scripts use /bin/bind (both absolute paths).
# sudo must be the setuid system sudo (a nix-store sudo cannot be setuid).
SUDO=${SUDO:-/usr/bin/sudo}
[ -x "$SUDO" ] || SUDO=sudo
"$SUDO" cp "$HARVEY_LINUX_BIN/cpp" /bin/cpp
"$SUDO" cp "$HARVEY/build/bind" /bin/bind
"$SUDO" cp "$PLAN9/bin/rc" /bin/rc
# pcc also execs the compilers/linkers by absolute /bin path (pcc.c:
# doexec(smprint("/bin/%s", ot->cc)) etc.)
for t in 6a 6c 6l 8a 8c 8l; do
  [ -x "$HARVEY_LINUX_BIN/$t" ] && "$SUDO" cp "$HARVEY_LINUX_BIN/$t" "/bin/$t"
done

(cd "$HARVEY/sys/src" && bash RUN_BUILD_IN_PRIVATE_NAMESPACE)

# Arm the userland preflight (above) once a build has left all four
# kernel-critical binaries in place.
for f in amd64/bin/ip/ipconfig amd64/bin/auth/factotum \
         amd64/bin/fossil/fossil amd64/bin/venti/venti; do
  [ -x "$HARVEY/$f" ] || exit 0
done
touch "$HARVEY/amd64/.userland-ok"
