#!/bin/sh
# cnam.c is generated per-build from l.h's C_* enum (host ed; proven on
# BSD ed). enam.c is committed in ../7c (6c precedent).
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
