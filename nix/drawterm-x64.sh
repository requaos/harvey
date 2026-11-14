# nix/drawterm-x64.sh — the drawterm session wrapper (DESK-01, 19-06).
#
# One command, hermetic build, pinned connection: the vendored in-tree
# drawterm (sys/src/cmd/unix/drawterm — D-01's source of record, built
# by the flake's drawterm package with NO fetch and NO patchPhase,
# D-02) is exec'd with the connection pinned on argv via -O (the OQ-2
# settlement): argv is the single source of connection parameters, so
# this wrapper SCRUBS the credential-bearing environment first — the
# $cpu/$auth defaults are a connection-hijack surface (research
# Pitfall 3 / T-19-12), never a fallback.
#
# The pinned values are the committed hostfwd pair's loopback side
# (the Phase-16 D-04 data the qemu emitter serves): host 17010 ->
# guest 17010 (cpu), host 5670 -> guest 567 (auth) — loopback-literal
# form per the 18-05 idiom ($attr cs translation reds on r9; name the
# 3-part tcp!host!port auth address and the bare cpu host verbatim).
# The auth address carries its service, so netmkaddr passes it through
# as-is.  user=glenda is the Phase-18 baked demo user (18-D-12).
#
# Encryption: the DEFAULT is encrypted (devssl #D rc4_256 sha1 via
# pushssl — D-15).  No -e flag appears in any line this wrapper
# prints; `-e clear` is the documented DEBUG fallback only (see
# build/x86_64/README.md's drawterm section).
#
# The wrapper takes NO arguments (its whole surface is the pin; a
# future flag class is a new decision, not a quiet passthrough).
#
# Env contract:
#   DRAWTERM_BIN  REQUIRED — the flake package's drawterm binary; the
#                 app exports it.  Standalone use: set it to the
#                 package's $out/bin/drawterm yourself.
#
# usage: nix run .#drawterm        (windowed when a display exists;
#                                   headless falls back LOUDLY to -G)

set -eu

err() { echo "error: $*" >&2; exit 1; }

[ -n "${DRAWTERM_BIN:-}" ] || err "DRAWTERM_BIN unset — run via the flake app (nix run .#drawterm), which exports the package binary path"
[ -f "$DRAWTERM_BIN" ] && [ -x "$DRAWTERM_BIN" ] \
	|| err "DRAWTERM_BIN $DRAWTERM_BIN: not an executable file"

[ $# -eq 0 ] || err "unknown argument(s): $* — this wrapper takes no arguments; the connection is pinned (usage: nix run .#drawterm)"

# --- the scrub (Pitfall 3): before anything else ----------------------
# drawterm's no-O path reads $cpu/$auth/$USER as connection defaults;
# unset them here AND pin -O below — belt and suspenders, but the pin
# is what actually carries the session (with -O the env reads never
# execute).
unset cpu auth PASS USER

# --- the pin (seam-derived loopback literals) -------------------------
DT_CPU=127.0.0.1
DT_AUTH='tcp!127.0.0.1!5670'
DT_USER=glenda
SPEC="cpu=$DT_CPU,auth=$DT_AUTH,user=$DT_USER"

# --- the printed connect lines ----------------------------------------
# The human default is WINDOWED (no -G in the primary line); the -G
# text form is printed alongside (it is the CI-able/stdio path).  The
# spec rides unquoted (a pasteable line; in an INTERACTIVE bash shell
# the ! in the auth address wants single quotes around the spec — the
# README recipes show that form).
echo "== drawterm: connect line (windowed default, encrypted rc4_256 sha1):"
echo "   $DRAWTERM_BIN -O $SPEC"
echo "== text form (-G: no window, stdio session):"
echo "   $DRAWTERM_BIN -G -O $SPEC"

# --- exec --------------------------------------------------------------
if [ -z "${DISPLAY:-}" ]; then
	echo "== DISPLAY unset — headless venue: running the -G stdio session (the windowed line needs a display; this is the loud fallback, never a silent downgrade)"
	exec "$DRAWTERM_BIN" -G -O "$SPEC"
fi
exec "$DRAWTERM_BIN" -O "$SPEC"
