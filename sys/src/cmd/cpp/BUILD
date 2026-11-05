#!/bin/sh
# -Wno-error=format-security: nix's cc wrapper injects -Werror=format-security,
# which errors out when the tree's -Wno-format disables -Wformat (same collision
# as sys/src/cmd/unix/9cc/BUILD; decades-old Plan 9 C is warning-dirty by design).
9c -Wno-char-subscripts \
   -Wno-format \
   -Wno-unused-variable \
   -Wno-format-extra-args \
   -Wno-maybe-uninitialized \
   -Wno-int-conversion \
   -Wno-error=format-security \
   -nostdlib \
   -g -I .   \
	cpp.c\
	lex.c\
	nlist.c\
	tokens.c\
	macro.c\
	eval.c\
	include.c\
	hideset.c\

9l -o cpp \
	cpp.o\
	lex.o\
	nlist.o\
	tokens.o\
	macro.o\
	eval.o\
	include.o\
	hideset.o\

cp cpp $HARVEY_LINUX_BIN
