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
rm -f *.o

(cd ../cc; $PLAN9/bin/yacc -D1 -d cc.y)
9c -g -I . -I ../cc -O0 \
	-Wno-parentheses \
	-Wno-missing-braces \
	-Wno-switch \
	-Wno-comment \
	-Wno-sign-compare \
	-Wno-unknown-pragmas \
	-Wno-misleading-indentation \
	-Wno-stringop-truncation \
	-Wno-stringop-overflow \
	-Wno-format-truncation \
	-fno-omit-frame-pointer \
	-fsigned-char \
	-fcommon \
	-Wno-char-subscripts  \
	-Wno-builtin-declaration-mismatch \
	-Wno-implicit-function-declaration \
	-Wno-int-conversion \
	-Wno-maybe-uninitialized \
	-Wno-incompatible-pointer-types \
	-DRunemask=0x1FFFFF \
	../cc/acid.c \
	../cc/bits.c \
	../cc/com64.c \
	../cc/com.c \
	../6l/unixcompat.c \
	../cc/dcl.c \
	../cc/dpchk.c \
	../cc/funct.c \
	../cc/lex.c \
	../cc/mac.c \
	../cc/pgen.c \
	../cc/pickle.c \
	../cc/pswt.c \
	../cc/scon.c \
	../cc/sub.c \
	../cc/y.tab.c \
	cgen.c \
	enam.c \
	list.c \
	machcap.c \
	mul.c \
	peep.c \
	reg.c \
	sgen.c \
	swt.c \
	txt.c \
&& 9l -o 7c -g *.o
cp 7c $HARVEY_LINUX_BIN
