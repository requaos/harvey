#!/bin/sh
# build/aarch64/stage-build.sh — stage the r9-userspace binaries (phase
# 04-05, D-03/D-04): compile the C list below in the lima guest's Plan 9
# namespace (objtype=aarch64, the committed 02-06 wiring: the vendored
# 7c/7l carry thestring=aarch64, resolving /aarch64/include and
# /aarch64/lib), rsync the results back to the gitignored
# build/aarch64/out/, and copy the committed hello.7.out in verbatim
# (the ABI bisect binary rides the initrd from 04-06 on).  r9's
# `cargo xtask initrd` then bakes out/{init,hello,smokefork,smokenote}
# into target/bootfs.paq via mkpaqfs.  Every staged binary is R_MAGIC
# (0x8C47, BE) verified here before the rsync-back is trusted.
#
# Mirrors subset-build.sh's lima/rsync flow (vm-run.sh exclusion set,
# guest script via /tmp, nsrun.sh namespace wrap).  Idempotent: the
# libc install and every compile are re-run each time.
#
# usage: sh build/aarch64/stage-build.sh   (repo root, inside the nix devshell)

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build}"
LOG="${STAGE_BUILD_LOG:-$HARVEY/.build/stage-build.log}"
OUT="$HARVEY/build/aarch64/out"

# The C sources this script stages: NAME.c -> out/NAME (7c/7l).
STAGE_SRCS="init smokefork smokenote"

err() { echo "error: $*" >&2; exit 1; }

[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
for f in $STAGE_SRCS; do
	[ -f "$HARVEY/build/aarch64/$f.c" ] || err "build/aarch64/$f.c missing"
done
[ -f "$HARVEY/build/aarch64/hello.7.out" ] || err "build/aarch64/hello.7.out missing (the committed ABI bisect binary)"

command -v limactl >/dev/null 2>&1 || err "limactl not found — run inside the nix devshell"
if ! limactl list -q 2>/dev/null | /usr/bin/grep -qx "$VM"; then
	err "lima VM '$VM' does not exist"
fi
status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
if [ "$status" != "Running" ]; then
	limactl start "$VM"
fi

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/stage-build.XXXXXX")
cleanup() {
	rm -rf "$TMPD"
}
trap cleanup EXIT

# guest-side script (the subset-build.sh single-committed-file
# discipline): written to a host tmp file, rsynced to the guest's /tmp,
# executed via vm-run.sh (which rsyncs the checkout, ensures the guest
# toolchain, and wraps the command in nsrun.sh's namespace entry).
cat > "$TMPD/stage-build-guest.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# stage-build-guest.sh — guest side of build/aarch64/stage-build.sh.
# Runs inside the Plan 9 mount namespace (nsrun.sh --wrap): /sys is the
# checkout's sys, /aarch64 the committed arch dir.  Never committed;
# the host driver regenerates it each run.
set -e

fail() { echo "STAGE-BUILD-FAIL: $1" >&2; exit 1; }

STAGE_SRCS="init smokefork smokenote"
STAGE="$HARVEY/build/aarch64/out"

echo "== stage build provenance (Harvey's vendored toolchain):"
echo "   7c: $(command -v 7c)"
echo "   7l: $(command -v 7l)"
echo "   mk: $(command -v mk)"

# the namespace binds $HARVEY/aarch64 at /aarch64; mkdirs lays out the
# bin/lib tree libc's install needs (vm-run.sh, unlike nix/build.sh,
# does not run mkdirs first — subset-build.sh's note)
cd "$HARVEY" && bash build/mkdirs || fail "mkdirs"

# ensure objtype=aarch64 libc — idempotent rerun (02-06 wiring proved
# it green); everything staged here links /aarch64/lib/libc.a
echo "== stage lib: libc (idempotent)"
(cd /sys/src/libc && objtype=aarch64 mk install) || fail "libc"

mkdir -p "$STAGE"
for f in $STAGE_SRCS; do
	echo "== stage compile: build/aarch64/$f.c -> out/$f"
	(cd "$HARVEY/build/aarch64" && objtype=aarch64 7c -FTVw "$f.c" && objtype=aarch64 7l -o "$STAGE/$f" "$f.7" && rm -f "$f.7") || fail "$f"
done

echo "== staged tree ($STAGE):"
ls -l "$STAGE"

echo "STAGE-BUILD-OK"
GUEST_EOF

echo "== pushing the guest stage-build script"
rsync -a -e "$RSYNC_RSH" "$TMPD/stage-build-guest.sh" "$GUEST:/tmp/gsd-stage-build-guest.sh"

mkdir -p "$HARVEY/.build"
echo "== running the stage build in the guest namespace (log: $LOG)"
set +e
sh "$HARVEY/build/aarch64/vm-run.sh" 'bash /tmp/gsd-stage-build-guest.sh' > "$LOG" 2>&1
RC=$?
set -e
cat "$LOG"
if [ $RC -ne 0 ]; then
	echo "error: guest stage build failed (rc=$RC); log: $LOG" >&2
	echo "hint: the log names the first failing step (STAGE-BUILD-FAIL: <name>)" >&2
	exit $RC
fi
/usr/bin/grep -q 'STAGE-BUILD-OK' "$LOG" || err "guest build log lacks STAGE-BUILD-OK"

# rsync the staged binaries back to the host checkout's gitignored out/
echo "== pulling the staged binaries back to host build/aarch64/out"
mkdir -p "$OUT"
rsync -a --delete -e "$RSYNC_RSH" "$GUEST:$GUEST_DIR/build/aarch64/out/" "$OUT/"

# the committed ABI bisect binary rides along verbatim (04-06 consumes it)
cp "$HARVEY/build/aarch64/hello.7.out" "$OUT/hello"

# every staged binary must carry the arm64 a.out magic (R_MAGIC 0x8C47, BE)
for f in $STAGE_SRCS hello; do
	[ -s "$OUT/$f" ] || err "build/aarch64/out/$f missing after stage"
	magic=$(od -An -tx1 -N4 "$OUT/$f" | tr -d ' \n')
	[ "$magic" = "00008c47" ] || err "build/aarch64/out/$f: bad magic $magic (want 00008c47)"
done

echo "== PASS: staged $(ls "$OUT" | tr '\n' ' ')into build/aarch64/out (log: $LOG)"
