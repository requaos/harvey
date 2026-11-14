#!/bin/sh
# flagtest.sh — TAP harness for the drawterm flag surface (-O/-G).
#
# Exercises the 19-06 vendor additions from the OUTSIDE: each test runs
# the built binary with a fixed argv and asserts on its output/exit,
# so the harness is usable both before the flags exist (RED) and after
# (GREEN).  Emits TAP 13 on stdout; diagnostics ride #-comment lines
# (kept OFF the ok/not-ok lines so the test names stay stable).
#
# usage: flagtest.sh [drawterm-binary] [cpu.c-source]
#
# The runs are headless by design (DISPLAY unset): a -G session must
# never touch X, and a usage error must be visible without a display
# (the pre-scan fires before any gui init).
#
# Every drawterm invocation is timeout-guarded: the vendor's exits()
# parks forever (windowed behavior), so a regression would otherwise
# wedge the harness instead of failing a test.

BIN=${1:-./drawterm}
SRC=${2:-./cpu.c}
T=10	# per-run timeout seconds

if [ ! -x "$BIN" ]; then
	echo "1..0 # SKIP no binary at $BIN" >&2
	exit 1
fi

diag() { echo "# $*"; }
FAILS=0
ok() { echo "ok $1 - $2"; }
no() { echo "not ok $1 - $2"; FAILS=$((FAILS+1)); }

echo "1..6"

# 1-2: a malformed -O spec is a usage error naming the accepted keys.
#      Validated before any gui init, so the message is reachable on a
#      headless run (the vendor's post-screeninit usage path exits at
#      XOpenDisplay instead).
N=0
for SPEC in 'bogus=1' 'cpu=x,auth=y'; do
	N=$((N+1))
	OUT=$(env -u DISPLAY timeout "$T" "$BIN" -O "$SPEC" 2>&1)
	if echo "$OUT" | grep -q 'usage'; then
		ok $N "-O $SPEC rejected with usage"
	else
		no $N "-O $SPEC rejected with usage"
		diag "got: $(echo "$OUT" | head -1)"
	fi
done

# 3-4: a valid -O spec plus -G reaches the dial with no window: hostile
#      env (cpu/auth/USER set) is not consulted (-O is the single
#      source), no X error fires, the dial failure is loud, and the
#      process terminates instead of parking.
SPEC='cpu=127.0.0.1,auth=tcp!127.0.0.1!5670,user=glenda'
OUT=$(env -u DISPLAY cpu=evil auth=evil USER=evil timeout "$T" "$BIN" -G -O "$SPEC" 2>&1)
RC=$?
N=$((N+1))
if ! echo "$OUT" | grep -q 'usage' \
	&& ! echo "$OUT" | grep -qi 'XOpenDisplay\|open display' \
	&& ! echo "$OUT" | grep -q 'evil' \
	&& echo "$OUT" | grep -qi 'dial\|refused\|connection'; then
	ok $N "-G with a valid -O spec dials with no window and no env reads"
else
	no $N "-G with a valid -O spec dials with no window and no env reads"
	diag "rc=$RC first-lines: $(echo "$OUT" | head -2 | tr '\n' '|')"
fi
N=$((N+1))
if [ "$RC" -ne 124 ] && [ "$RC" -ne 0 ]; then
	ok $N "-G session terminates on dial failure"
else
	no $N "-G session terminates on dial failure"
	diag "rc=$RC (124=timed out, 0=zero)"
fi

# 5: structural — the $cpu/$auth/$USER env reads sit behind the no-O
#    path (lexically after ARGEND, so a -O run never executes them).
ARGEND_LINE=$(grep -n 'ARGEND' "$SRC" | head -1 | cut -d: -f1)
ENV_LINE=$(grep -n 'getenv("cpu")' "$SRC" | head -1 | cut -d: -f1)
N=$((N+1))
if [ -n "$ARGEND_LINE" ] && [ -n "$ENV_LINE" ] && [ "$ENV_LINE" -gt "$ARGEND_LINE" ]; then
	ok $N "env reads are behind the no-O path"
	diag "getenv(cpu) at cpu.c:$ENV_LINE > ARGEND at cpu.c:$ARGEND_LINE"
else
	no $N "env reads are behind the no-O path"
	diag "getenv(cpu) at ${ENV_LINE:-none}, ARGEND at ${ARGEND_LINE:-none}"
fi

# 6: guard — the encrypted default ealgs is untouched (rc4_256 sha1).
N=$((N+1))
if grep -q 'ealgs = "rc4_256 sha1"' "$SRC"; then
	ok $N "default ealgs stays rc4_256 sha1"
else
	no $N "default ealgs was changed"
fi

# TAP producers exit nonzero when any test failed
[ "$FAILS" -eq 0 ] || exit 1
exit 0
