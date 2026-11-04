#!/bin/sh
# bquote-repro.sh — the evidence harness: build a host mk
# from a PRISTINE git-archive copy of sys/src/cmd/mk (pre-fix) or from the
# WORKING tree (post-fix), then run the nested-backquote repro mkfile and
# capture the log.  Never committed artifacts: everything lands under
# .build/bquote-repro/ (gitignored scratch).
#
#   sh build/aarch64/bquote-repro.sh pristine   # pre-fix evidence
#   sh build/aarch64/bquote-repro.sh working    # post-fix evidence
#
# The repro mkfile:
#   X=`{if(true) { echo bquote-ok }}`   — rc-style NESTED braces (the bug:
#   the naive first-`}` scan ends early; the leftover corrupts the parse)
#   Y=`echo sh-ok`                      — sh-style control (unchanged)
#   all:VQ: echo X=$X Y=$Y
# A correct mk prints "X=bquote-ok Y=sh-ok".

set -eu

: "${PLAN9:?run inside the nix devshell — plan9port must be provisioned (PLAN9 unset)}"

HARVEY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$HARVEY_ROOT"
MODE="${1:?usage: bquote-repro.sh pristine|working}"

# $PLAN9/bin LAST (BUILD_ON_UNIX discipline; mkpaqfs-host.sh's shape).
P9LAST=$(echo "$PATH" | sed "s|:$PLAN9/bin||g; s|^$PLAN9/bin:||; s|^$PLAN9/bin$||")
PATH="$P9LAST:$PLAN9/bin"
export PATH

REPRO="$HARVEY_ROOT/.build/bquote-repro"
mkdir -p "$REPRO"
SRC="$REPRO/src-$MODE"
rm -rf "$SRC"
mkdir -p "$SRC"

if [ "$MODE" = pristine ]; then
	# The pre-fix tree, straight from git — the working tree stays
	# untouched while the corruption evidence is captured.
	git archive HEAD sys/src/cmd/mk | tar -x -C "$SRC"
else
	# Post-fix: the working tree's mk sources.
	mkdir -p "$SRC/sys/src/cmd"
	cp -R sys/src/cmd/mk "$SRC/sys/src/cmd/mk"
fi

MKDIR="$SRC/sys/src/cmd/mk"
OUT="$REPRO/mk-$MODE"
rm -f "$OUT"

# Host-compat fixup (scratch copy ONLY — the working tree is never
# touched): plan9port's libc.h '#define waitfor p9waitfor' collides with
# mk's own waitfor(char*) (fns.h/plan9.c/run.c).  Rename it in the scratch
# so 9c can build at all; lex.c (the file under test) stays pristine.
# (No sed -i: the PATH mix may resolve a sed without it.)
for f in "$MKDIR/fns.h" "$MKDIR/plan9.c" "$MKDIR/run.c"; do
	sed 's/waitfor/mkwaitfor/g' "$f" > "$f.bqtmp" && mv "$f.bqtmp" "$f"
done
# plan9port's regexp.h wraps the NEW union-member Resub API (s.sp/e.ep);
# mk's rcopy uses the OLD direct members (sp/ep).  Scratch-only rewrite.
sed 's/match->sp/match->s.sp/g; s/match->ep/match->e.ep/g' "$MKDIR/plan9.c" > "$MKDIR/plan9.c.bqtmp" && mv "$MKDIR/plan9.c.bqtmp" "$MKDIR/plan9.c"
# mk hardcodes shell="/bin/rc" (plan9.c) — absent on a unix host; point
# the scratch build at plan9port's rc so backquote/recipe execs run.
sed "s|\"/bin/rc\"|\"$PLAN9/bin/rc\"|" "$MKDIR/plan9.c" > "$MKDIR/plan9.c.bqtmp" && mv "$MKDIR/plan9.c.bqtmp" "$MKDIR/plan9.c"

echo "== [9c] compile mk ($MODE) — $(ls "$MKDIR"/*.c | wc -l | tr -d ' ') files"
OBJS=""
for f in "$MKDIR"/*.c; do
	b=$(basename "$f" .c)
	# -std=gnu89: mk is Plan 9 C (implicit-int et al.); the host clang
	# behind 9c defaults to C99+ and rejects it.  Scratch-only flag.
	(cd "$REPRO" && "$PLAN9/bin/9c" -O0 -std=gnu89 -I"$MKDIR" -c "$f" -o "$REPRO/mk-$MODE-$b.o")
	OBJS="$OBJS $REPRO/mk-$MODE-$b.o"
done

echo "== [9l] link $OUT (-lbio -lregexp9 -l9)"
# -lregexp9: plan9port maps regcomp/regexec/regsub to the 9-suffixed
# names (libc.h) served by libregexp9.
(cd "$REPRO" && "$PLAN9/bin/9l" -o "$OUT" $OBJS -lbio -lregexp9 -l9)
rm -f $OBJS

# The repro mkfile (rc-style nested braces + the sh-style control).
cat > "$REPRO/repro.mkfile" <<'EOF'
X=`{if(true) { echo bquote-ok }}
Y=`echo sh-ok`

all:VQ:
	echo X=$X Y=$Y
EOF

LOG="$REPRO/$MODE-fix.log"
[ "$MODE" = pristine ] && LOG="$REPRO/prefix.log" || LOG="$REPRO/postfix.log"
echo "== run $OUT -f repro.mkfile (log: $LOG)"
set +e
(cd "$REPRO" && "$OUT" -f repro.mkfile) > "$LOG" 2>&1
RC=$?
set -e
echo "== exit $RC — captured:"
cat "$LOG"
