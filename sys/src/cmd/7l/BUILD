#!/bin/sh
# cnam.c is generated per-build from l.h's C_* enum (host ed; proven on
# BSD ed). enam.c is committed in ../7c (6c precedent).
set -e	# never link stale objects after a failed compile

# 9l's autolib scans HOST ELF objects with bare `nm`; with hostbin on
# PATH that resolves to Harvey's ken-format nm ("Can't read header" →
# silently broken autolib → undefined Binit/Bputc/... at link). Shadow
# with the system nm for the duration (same fix as nix/toolchain.sh).
SHIMD=$(mktemp -d "${TMPDIR:-/tmp}/harvey-nm-shim.XXXXXX")
trap '/bin/rm -rf "$SHIMD"' EXIT
_HOSTNM=$(PATH="$(echo "$PATH" | sed 's/^[^:]*\/\.build\/hostbin-[^:]*//; s/:[^:]*\/\.build\/hostbin-[^:]*//g; s/^::*//; s/::*$//')" command -v nm 2>/dev/null || true)
if [ -n "$_HOSTNM" ]; then
	ln -sf "$_HOSTNM" "$SHIMD/nm"
	PATH="$SHIMD:$PATH"
	export PATH
fi
sh mkcname

9c -O0 -Wno-char-subscripts -g -I . \
	asm.c \
	asmout.c \
	bits.c \
	cnam.c \
	dynstub.c \
	list.c \
	mod.c \
	noop.c \
	obj.c \
	optab.c \
	pass.c \
	span.c \
	unixcompat.c \
	../7c/enam.c

9l -o 7l \
asm.o \
asmout.o \
bits.o \
cnam.o \
dynstub.o \
enam.o \
list.o \
mod.o \
noop.o \
obj.o \
optab.o \
pass.o \
span.o \
unixcompat.o

cp 7l $HARVEY_LINUX_BIN
