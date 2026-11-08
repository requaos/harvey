set -e	# never link stale objects after a failed compile

# 9l's autolib scans HOST ELF objects with bare `nm`; with hostbin on
# PATH that resolves to Harvey's ken-format nm ("Can't read header" →
# silently broken autolib → undefined Binit/Bputc/... at link). Shadow
# with the system nm for the duration (same fix as nix/toolchain.sh).
SHIMD=$(mktemp -d "${TMPDIR:-/tmp}/harvey-nm-shim.XXXXXX")
# system rm via the hostbin-stripped PATH (the _HOSTNM idiom): a bare
# /bin/rm fails on NixOS-class hosts (/bin holds only sh), and a bare
# `rm` on PATH would resolve to hostbin's guest-built one
_SYSRM=$(PATH="$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$')" command -v rm 2>/dev/null || echo rm)
trap '"$_SYSRM" -rf "$SHIMD"' EXIT

_HOSTNM=$(PATH="$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$//')" command -v nm 2>/dev/null || true)
if [ -n "$_HOSTNM" ]; then
	ln -sf "$_HOSTNM" "$SHIMD/nm"
	PATH="$SHIMD:$PATH"
	export PATH
fi
$PLAN9/bin/yacc -D1 -d a.y
9c -O0 -Wno-maybe-uninitialized -g -I . *.c
9l -o 7a *.o
cp 7a $HARVEY_LINUX_BIN
