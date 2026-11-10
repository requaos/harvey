#!/bin/sh
# build-9kdraw.sh — build + bake + boot the draw donor venue (15-05,
# USPACE-08, D-04): the kernel-local devdraw donor kernel.
#
# Three phases, one script (the plan's verify greps THIS script's own
# output for the venue markers):
#   1. BUILD — the k10draw config (k10t1's device set + k10f's draw
#      deltas, DISPI route) through the linux private-namespace path
#      (the build-9k10t1.sh shape: nuke sandwich, CONF= override,
#      embedded-count + git-clean asserts), re-proving k10cpu on the
#      way (the multiboot/devcons deltas of tasks 2-3 are kernel-wide
#      source changes; the sacred kernel relinks against them here).
#      The kernel embeds the minimal draw-venue boot set (12 root
#      files) including the host-built mkdir + drawsmoke.
#   2. BAKE — bootfs-draw.paq via the host mkpaqfs (.build/bin, the
#      mkpaqfs-host.sh fallback): the WHOLE lib/font/bit tree copied
#      at bake time (the adm/timezone rule — never a committed
#      duplicate) + the GUI binaries harvested from /amd64/bin
#      (computed from tiers/tier3-gui.txt — never a second hardcoded
#      list) + mntgen/paqfs/drawsmoke.  The paq size prints (the A3
#      measurement; the venue boots -m 512 minimum).
#   3. BOOT — the draw leg under plain qemu-system-x86_64 -vga std:
#      banner wait, marker wait, classify.  The venue boots text-mode;
#      k10draw.rc drives the mode-set through #v/vgactl and drawsmoke
#      proves /dev/draw end-to-end.  The serial capture (the gate
#      wire) cats to this script's stdout at exit.
#
# Usage (from the repo root, inside the nix devshell):
#   nix develop -c sh build/mm/build-9kdraw.sh
#
# Env overrides:
#   HARVEY            repo root            (default: $PWD)
#   DRAW_KERNEL       kernel ELF           (default: $HARVEY/amd64/9kdraw.elf)
#   DRAW_PAQ          payload paq          (default: $HARVEY/build/x86_64/out/bootfs-draw.paq)
#   DRAW_QEMU         qemu-system-x86_64   (default: PATH lookup)
#   DRAW_MEM          guest memory         (default: 512)
#   DRAW_BOOT_BUDGET  seconds to wait for the banner (default: 60 KVM / 600 TCG)
#   DRAW_SMOKE_BUDGET seconds to wait for DRAW-VENUE-DONE (default: 300 KVM / 900 TCG)
#   DRAW_LOG          serial capture       (default: $HARVEY/.build/draw-serial.log)
#
# Exit: 0 iff the kernel built (embed count asserted, tree git-clean),
# the paq baked (magic checks), the venue booted, and the capture
# carries every venue marker with zero panic/trap lines.

set -eu

HARVEY="${HARVEY:-$PWD}"

err() { echo "error: $*" >&2; exit 1; }

# --- platform gate: the namespace build is linux-only (unshare -m) ----
if [ "$(uname -s)" != "Linux" ]; then
	echo "error: the private-namespace build is linux-only." >&2
	echo "on darwin, run it in the lima guest:" >&2
	echo "  limactl shell harvey -- sh -lc 'cd $HARVEY && nix develop -c sh build/mm/build-9kdraw.sh'" >&2
	exit 2
fi

# --- preconditions (named remediation, never assumed) ------------------
[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
_missing=""
for b in rc echo cat test sleep read bind paqfs; do
	[ -f "$HARVEY/amd64/bin/$b" ] || _missing="$_missing amd64/bin/$b"
done
for l in libc.a libdraw.a libmemdraw.a libmemlayer.a; do
	[ -f "$HARVEY/amd64/lib/$l" ] || _missing="$_missing amd64/lib/$l"
done
[ -z "$_missing" ] || err "the venue set is incomplete:$_missing — run the tier drivers first (subset-build.sh; the libdraw family is 15-04's tier-0 closure)"
_ha=$(uname -m); [ "$_ha" = "arm64" ] && _ha=aarch64
NS_HBIN="$HARVEY/.build/hostbin-linux-$_ha/bin"
for t in 6c 6l 6a; do
	[ -x "$NS_HBIN/$t" ] || err "$NS_HBIN/$t missing — run 'nix run .#setup && nix run .#toolchain' first"
done
# the devshell exports HARVEY_LINUX_BIN (the same hostbin) — the userns
# scaffold below passes it through for the chroot's PATH head, whose
# first entry must carry the Plan 9 sed/awk dialects the kernel recipes
# use (the t1 venue's measured lesson: a GNU-sed resolution reds the
# $CONF.c generation rule with 'invalid reference \1').  Defensive
# fallback if the env is absent; NS_HBIN above stays the computed
# authority for the toolchain preconditions.
HARVEY_LINUX_BIN="${HARVEY_LINUX_BIN:-$NS_HBIN}"
[ -n "${PLAN9:-}" ] && [ -x "$PLAN9/bin/rc" ] || err "\$PLAN9/bin/rc missing — run inside the nix devshell (nix develop)"

# 15-01/15-02: the phase build-tree lock — the kernel build embeds from
# the untracked /amd64 tree, the paq harvests it, and the same-wave tier
# drivers (15-03/15-09 subset-build runs) hold this SAME lock; held from
# here (before the staging reads /amd64) to exit.
command -v flock >/dev/null 2>&1 || err "flock not found — the amd64 build-tree lock needs util-linux flock"
exec 9>"$HARVEY/.build/amd64-tree.lock"
flock 9 || err "cannot acquire the amd64 build-tree lock"
echo "== amd64 build-tree lock held: $HARVEY/.build/amd64-tree.lock"

# the 06-02 idiom (D-02): host grep for -q/-E (plan9 grep lacks them)
GREP=$(command -v /usr/bin/grep || command -v grep) || err "no host grep found"
export GREP

# --- staging (idempotent): the venue's host-built embed member --------
# .draw-stage is gitignored (the .tier1-stage rule); never committed.
STAGE="$HARVEY/sys/src/9k/k10/.draw-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
# drawsmoke: the /dev/draw exerciser (plain libc + draw.h constants);
# 6c with repo-root relative -I paths, 6l with -L to the checkout's
# amd64/lib (the OBJECT and the BINARY get distinct paths — 6l must not
# overwrite its own input)
(	cd "$HARVEY" && \
	"$NS_HBIN/6c" -FTVw -o "$STAGE/drawsmoke.6" -Isys/include -Iamd64/include build/x86_64/drawsmoke.c && \
	"$NS_HBIN/6l" -o "$STAGE/drawsmoke" -L "$HARVEY/amd64/lib" "$STAGE/drawsmoke.6" && \
	rm -f "$STAGE/drawsmoke.6"
) || err "drawsmoke host-side build failed"
magic=$(od -An -tx1 -N4 "$STAGE/drawsmoke" | tr -d ' \n')
[ "$magic" = "00008a97" ] || err "drawsmoke: bad magic $magic (want 00008a97 — amd64 S_MAGIC)"
echo "== staged: drawsmoke (magic-checked)"

# --- the namespace build (nuke sandwich) --------------------------------
export NS_HBIN
LOG="$HARVEY/.build/build-9kdraw.log"
mkdir -p "$HARVEY/.build"
CORE="$(mktemp "${TMPDIR:-/tmp}/ns-9kdraw-core.XXXXXX.sh")"
cat > "$CORE" <<'EOF'
cd /sys/src/9k/k10 || exit 1
fails=0
# leading nuke: clean slate
mk nuke || fails=1
# the sacred kernel's re-proof: tasks 2-3 change multiboot.c/devcons.c
# kernel-wide; k10cpu relinks against them (the frozen-CONFIG rule
# covers the config files; this covers the shared sources)
if [ "$fails" -eq 0 ]; then mk CONF=k10cpu 9k10cpu || fails=1; fi
# the venue kernel — the mkfile's target is $p$CONF with p=9, so the
# in-tree product is 9k10draw (the 9k10cpu/9k10t1 family naming); the
# venue artifact lands at /amd64/9kdraw.elf (the plan's venue name)
if [ "$fails" -eq 0 ]; then mk CONF=k10draw 9k10draw || fails=1; fi
if [ "$fails" -eq 0 ]; then
	[ -s 9k10draw ] || { echo "error: 9k10draw missing/empty" >&2; fails=1; }
	[ -s 9k10draw.elf ] || { echo "error: 9k10draw.elf missing/empty" >&2; fails=1; }
fi
# the embedded-count assert: one addbootfile line per rootdir entry in
# the generated k10draw.c (MUST run here — the trailing nuke removes it)
if [ "$fails" -eq 0 ]; then
	N=$("$GREP" -c 'addbootfile("' k10draw.c)
	echo "embedded root files: $N"
	[ "$N" = 11 ] || { echo "error: embedded root file count $N != 11 (devroot.c's panic ceiling is 64)" >&2; fails=1; }
fi
# land the venue kernel in /amd64 (the nuke never touches /amd64)
if [ "$fails" -eq 0 ]; then
	cp 9k10draw.elf /amd64/9kdraw.elf || fails=1
	ls -l 9k10cpu.elf 9k10draw.elf /amd64/9kdraw.elf
fi
# trailing nuke REGARDLESS of assert outcome
mk nuke || fails=1
exit "$fails"
EOF

set +e
if sudo -n true 2>/dev/null; then
	[ -x /bin/rc ] || sudo cp "$PLAN9/bin/rc" /bin/rc
	NSK="$(mktemp "${TMPDIR:-/tmp}/ns-9kdraw.XXXXXX.sh")"
	cat > "$NSK" <<EOF
cd /sys/src || exit 1
. buildnamespace
PATH="$NS_HBIN:\$PATH:/rc/bin:."
export PATH
export FORCERCFORMK=1
bash $CORE
EOF
	echo "== namespace build (sudo unshare): mk nuke && mk CONF=k10cpu 9k10cpu && mk CONF=k10draw 9k10draw && mk nuke"
	echo "== build log: $LOG (tail -f to follow)"
	(cd "$HARVEY/sys/src" && NS_TARGET="bash $NSK" bash RUN_BUILD_IN_PRIVATE_NAMESPACE) > "$LOG" 2>&1
	NSRC=$?
	rm -f "$NSK"
else
	# the passwordless venue: unprivileged user+mount namespace, the
	# tmpfs chroot scaffold (build-9k10t1.sh's proven shape)
	TMPD="$(mktemp -d "${TMPDIR:-/tmp}/ns-9kdraw-scaffold.XXXXXX")"
	cat > "$TMPD/ns-9kdraw-userns.sh" <<'USERNS_EOF'
#!/usr/bin/env bash
set -e
NSX=$(mktemp -d "${TMPDIR:-/tmp}/ns-9kdraw-root.XXXXXX")
mount -t tmpfs tmpfs "$NSX"

mkdir -p "$NSX"/{sys,amd64,rc,lib,etc,tmp,harvey,unix,nix/store,run,dev,usr,bin}
mount --bind "$HARVEY_SYS" "$NSX/sys"
mount --bind "$HARVEY_AMD64" "$NSX/amd64"
mount --bind "$HARVEY_RC" "$NSX/rc"
mount --bind "$HARVEY_LIB" "$NSX/lib"
mount --bind "$HARVEY_UNIX" "$NSX/unix"
for a in 386 aarch64 arm mips mips64 power power64 riscv riscv64 sparc acme; do
	mkdir -p "$NSX/$a"
	mount --bind "$HARVEY_REAL/$a" "$NSX/$a"
done
mount --bind /etc "$NSX/etc"
mount --bind /tmp "$NSX/tmp"
mount --bind "$HARVEY_REAL" "$NSX/harvey"
mount --bind /nix/store "$NSX/nix/store"
ln -sfn "$(readlink /run/current-system)" "$NSX/run/current-system"
ln -sfn ../run/current-system/sw/bin "$NSX/usr/bin"
for b in sh bash env cp mv rm ls cat mkdir touch sed grep find od tr; do
	ln -sfn "../run/current-system/sw/bin/$b" "$NSX/bin/$b"
done
for d in null zero urandom random; do
	touch "$NSX/dev/$d"
	mount --bind "/dev/$d" "$NSX/dev/$d"
done
touch "$NSX/bin/rc"
mount --bind "$PLAN9/bin/rc" "$NSX/bin/rc"

export HARVEY=/harvey
INNER_BIN="/harvey${HARVEY_LINUX_BIN#"$HARVEY_REAL"}"
exec chroot "$NSX" /usr/bin/env \
	HARVEY=/harvey \
	HARVEY_LINUX_BIN="$INNER_BIN" \
	PLAN9="$PLAN9" \
	GREP="$GREP" \
	PATH="$INNER_BIN:/rc/bin:$PATH:." \
	HOME="$HOME" \
	FORCERCFORMK=1 CGO_ENABLED=0 objtype=amd64 cputype=unix \
	bash "$1"
USERNS_EOF
	echo "== no passwordless sudo — namespace build in an unprivileged user namespace (unshare -Ur -m chroot scaffold)"
	echo "== build log: $LOG (tail -f to follow)"
	HARVEY_SYS="$HARVEY/sys" HARVEY_AMD64="$HARVEY/amd64" HARVEY_RC="$HARVEY/rc" HARVEY_LIB="$HARVEY/lib" \
	HARVEY_UNIX="$HARVEY/unix" HARVEY_REAL="$HARVEY" HARVEY_LINUX_BIN="$HARVEY_LINUX_BIN" \
	PATH="$HARVEY_LINUX_BIN:$PATH" \
	unshare -Ur -m bash "$TMPD/ns-9kdraw-userns.sh" "$CORE" > "$LOG" 2>&1
	NSRC=$?
	rm -rf "$TMPD"
fi
set -e
rm -f "$CORE"
[ "$NSRC" -eq 0 ] || {
	echo "error: the namespace build failed (rc=$NSRC) — last 40 lines of $LOG:" >&2
	tail -40 "$LOG" >&2
	exit 1
}

# --- host-side product asserts ------------------------------------------
[ -s "$HARVEY/amd64/9kdraw.elf" ] || err "amd64/9kdraw.elf missing/empty after the namespace build"
"$GREP" -q '^embedded root files: 11' "$LOG" || err "the build log lacks 'embedded root files: 11'"
# the nuke's proof: no untracked BUILD INTERMEDIATE survives (the
# parse-generated k10draw.c rides the .gitignore k10*.c rule,
# .draw-stage its own — anything untracked-and-unignored under sys/src/9k
# after the trailing nuke is a stray) and no tracked file is DELETED.
# MODIFIED tracked sources are legitimate mid-task state (the script
# runs during bring-up iteration, before the task commit) — the commit
# is their authority.
_dirty=$(git -C "$HARVEY" status --porcelain -- sys/src/9k | "$GREP" -v '^ M ' || true)
if [ -n "$_dirty" ]; then
	echo "error: sys/src/9k is not git-clean after the nuke sandwich:" >&2
	echo "$_dirty" >&2
	exit 1
fi
"$GREP" -E '^embedded root files: |9k(10cpu|draw)\.elf' "$LOG" | tail -5 || true
echo "== build OK: amd64/9kdraw.elf ($(wc -c < "$HARVEY/amd64/9kdraw.elf" | tr -d ' ') bytes), k10cpu re-proved, k10 tree git-clean"

# --- the bootfs-draw.paq bake -------------------------------------------
MKPAQFS="$HARVEY/.build/bin/mkpaqfs"
if [ ! -x "$MKPAQFS" ]; then
	echo "== mkpaqfs host binary missing — building via build/x86_64/mkpaqfs-host.sh"
	sh "$HARVEY/build/x86_64/mkpaqfs-host.sh" || err "mkpaqfs host build failed"
fi
[ -x "$MKPAQFS" ] || err "$MKPAQFS missing after mkpaqfs-host.sh"

OUT="$HARVEY/build/x86_64/out"
PSTAGE="$OUT/drawpaq-stage"
IMAGE="$OUT/bootfs-draw.paq"
rm -rf "$PSTAGE"
mkdir -p "$PSTAGE/lib/font" "$PSTAGE/amd64/bin"

# the WHOLE lib/font/bit tree, bake-time-copied (D-14: no exclusions;
# the adm/timezone rule — repo data copied at bake, never a committed
# duplicate)
cp -R "$HARVEY/lib/font/bit" "$PSTAGE/lib/font/bit"

# the GUI binary set — COMPUTED from the tier-3 data (the single-source
# rule; never a second hardcoded list), with the install-path mappings
# the tier driver itself uses (samterm -> bin/aux, the ip container ->
# bin/ip) plus the two named expansions: cmd/plumb is a mkmany dir
# yielding plumber AND plumb; mntgen/paqfs are the payload-channel
# servers (tier-2 / tier-1 built); drawsmoke rides the paq too (the
# plan's letter — the kernel embed also carries it as the boot probe)
DRAW_RELS=$(
	awk 'NF && $1 !~ /^#/ { print $1 }' "$HARVEY/build/x86_64/tiers/tier3-gui.txt" |
	while read -r e; do
		case "$e" in *:*) e="${e%%:*}" ;; esac
		case "$e" in
		cmd/ip/gping) echo amd64/bin/ip/gping ;;
		cmd/samterm) echo amd64/bin/aux/samterm ;;
		*) echo "amd64/bin/${e#cmd/}" ;;
		esac
	done
)
DRAW_RELS="$DRAW_RELS amd64/bin/plumber"
DRAW_RELS="$DRAW_RELS amd64/bin/mntgen amd64/bin/paqfs"
[ -n "$DRAW_RELS" ] || err "the paq member list is empty — the tier-3 data parse failed"
_miss=""
for rel in $DRAW_RELS; do
	[ -f "$HARVEY/$rel" ] || _miss="$_miss $rel"
done
[ -z "$_miss" ] || err "the GUI harvest is incomplete:$_miss — run sh build/x86_64/subset-build.sh first (the tier builds)"
for rel in $DRAW_RELS; do
	mkdir -p "$(dirname "$PSTAGE/$rel")"
	cp "$HARVEY/$rel" "$PSTAGE/$rel"
done
cp "$STAGE/drawsmoke" "$PSTAGE/amd64/bin/drawsmoke"

# the bake manifest: every mandated path exists — PRINTED (the bake log
# is the evidence; D-15's shape)
for p in lib/font/bit/lucm/unicode.9.font lib/font/bit/lucidasans/euro.8.font \
	lib/font/bit/pelm/latin1.8.font lib/font/bit/pelm/euro.9.font; do
	[ -s "$PSTAGE/$p" ] || err "paq manifest: $p missing/empty from staged tree"
	echo "paq manifest: /$p staged"
done
for rel in $DRAW_RELS amd64/bin/drawsmoke; do
	[ -s "$PSTAGE/$rel" ] || err "paq manifest: $rel missing/empty"
done
FONTN=$(find "$PSTAGE/lib/font/bit" -type f | wc -l | tr -d ' ')
[ "$FONTN" -ge 4000 ] || err "font tree suspiciously small: $FONTN files (expect >= 4000; D-14 ships the whole tree)"
echo "paq manifest: /lib/font/bit staged ($FONTN files)"

# KERNDATE determinism (the mkimage rule: staged mtimes pinned, the
# header time rides the same env)
KERNDATE=$(git -C "$HARVEY" log -1 --format=%ct 2>/dev/null || date +%s)
find "$PSTAGE" -exec touch -h -d "@$KERNDATE" {} +
mkdir -p "$OUT"
rm -f "$IMAGE"
KERNDATE="$KERNDATE" "$MKPAQFS" -o "$IMAGE" "$PSTAGE" || err "mkpaqfs failed"
[ -s "$IMAGE" ] || err "$IMAGE missing/empty after mkpaqfs"
magic=$(od -An -tx1 -N4 "$IMAGE" | tr -d ' \n')
[ "$magic" = "529ab12b" ] || err "$IMAGE: bad header magic $magic (want 529ab12b)"
sz=$(wc -c < "$IMAGE" | tr -d ' ')
trailer=$(od -An -tx1 -j $((sz - 28)) -N 4 "$IMAGE" | tr -d ' \n')
[ "$trailer" = "6b46e688" ] || err "$IMAGE: bad trailer magic $trailer (want 6b46e688)"
rm -rf "$PSTAGE"
echo "== bake OK: $IMAGE ($sz bytes; header $magic trailer $trailer) — the A3 measurement"

# --- the draw boot leg ----------------------------------------------------
KERNEL="${DRAW_KERNEL:-$HARVEY/amd64/9kdraw.elf}"
PAQ="${DRAW_PAQ:-$OUT/bootfs-draw.paq}"
BOOTLOG="${DRAW_LOG:-$HARVEY/.build/draw-serial.log}"
QEMU="${DRAW_QEMU:-}"
if [ -z "$QEMU" ]; then
	QEMU=$(command -v qemu-system-x86_64 || true)
fi
[ -n "$QEMU" ] && [ -x "$QEMU" ] || err "qemu-system-x86_64 not found — run inside the nix devshell or set DRAW_QEMU"
DRAW_MEM="${DRAW_MEM:-512}"

# accel probe (once): KVM iff /dev/kvm writable, else TCG
ACCEL=kvm
ACCEL_ARGS="-accel kvm -cpu host"
if [ -w /dev/kvm ]; then
	:
else
	ACCEL=tcg
	ACCEL_ARGS="-accel tcg -cpu qemu64"
fi
BUDGET="${DRAW_BOOT_BUDGET:-}"
if [ -z "$BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then BUDGET=600; else BUDGET=60; fi
fi
SMOKE_BUDGET="${DRAW_SMOKE_BUDGET:-}"
if [ -z "$SMOKE_BUDGET" ]; then
	if [ "$ACCEL" = tcg ]; then SMOKE_BUDGET=900; else SMOKE_BUDGET=300; fi
fi

# the venue marker contract — every marker below must land on the
# capture (presence-only, never interleaving order), with zero
# panic/trap lines.  Task 1: DRAW-SMOKE-OK (the draw device end-to-end).
# Task 2: FONT-CHANNEL-OK (the -initrd -> addbootfile -> paqfs channel
# delivers the fonts; the `mod` boot print is the A2 evidence, asserted
# separately below).  Task 3: KBIN-OK + MOUSEIN-OK (the eve-gated
# synthetic-input surface — the complete four-marker bring-up gate).
MARKERS="DRAW-SMOKE-OK FONT-CHANNEL-OK KBIN-OK MOUSEIN-OK"

: > "$BOOTLOG"
echo "== draw leg: mode $ACCEL (banner budget ${BUDGET}s, marker budget ${SMOKE_BUDGET}s)"
echo "== launching: $QEMU -kernel $KERNEL -initrd $PAQ -append -v -vga std -m $DRAW_MEM $ACCEL_ARGS -display none -no-reboot -serial file:$BOOTLOG"
QEMU_PID=""
cleanup() {
	status=$?
	[ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
	exit $status
}
trap cleanup EXIT
# -initrd registers the paq as an mb1 module (multiboot.c's Fmods loop
# exposes it through addbootfile; the in-guest paqfs mounts it — the A2
# evidence is the boot print's `mod ...` line).  -append -v arms the
# kernel's verbose multiboot pass (main.c's vflag re-walk AFTER fmtinit),
# which prints the mod lines and the memory map on the capture.
# SC2086: ACCEL_ARGS is intentionally word-split (two fixed args).
# shellcheck disable=SC2086
"$QEMU" -kernel "$KERNEL" -initrd "$PAQ" -append -v -vga std -m "$DRAW_MEM" $ACCEL_ARGS -display none -no-reboot -serial "file:$BOOTLOG" &
QEMU_PID=$!

# Phase A: deadline-wait for the banner
elapsed=0
found=1
while [ "$elapsed" -lt "$BUDGET" ]; do
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		echo "== qemu exited before the banner (${elapsed}s) — classifying what was captured"
		break
	fi
	if "$GREP" -q 'Plan 9' "$BOOTLOG" 2>/dev/null; then
		found=0
		break
	fi
	sleep 5
	elapsed=$((elapsed + 5))
done

# Phase B: poll for the completion marker within the budget; early-break
# on the panic signature or qemu death
if [ "$found" -eq 0 ]; then
	echo "== banner captured at ${elapsed}s — waiting for DRAW-VENUE-DONE (budget ${SMOKE_BUDGET}s)"
	celapsed=0
	while [ "$celapsed" -lt "$SMOKE_BUDGET" ]; do
		if "$GREP" -q 'DRAW-VENUE-DONE' "$BOOTLOG" 2>/dev/null; then
			echo "== DRAW-VENUE-DONE observed at +${celapsed}s"
			break
		fi
		if "$GREP" -qF 'panic' "$BOOTLOG" 2>/dev/null || \
		   "$GREP" -qF 'sys: trap' "$BOOTLOG" 2>/dev/null; then
			echo "== signature line observed at +${celapsed}s"
			break
		fi
		if ! kill -0 "$QEMU_PID" 2>/dev/null; then
			echo "== qemu exited at +${celapsed}s — classifying the final log"
			break
		fi
		sleep 5
		celapsed=$((celapsed + 5))
	done
fi

# stop qemu and reap it so the chardev's buffered writes flush
if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
	kill "$QEMU_PID" 2>/dev/null || true
fi
wait "$QEMU_PID" 2>/dev/null || true
QEMU_PID=""
sleep 2

# classify: banner + every marker + the mod boot print (A2) + zero panic/trap
RC=0
"$GREP" -q 'Plan 9' "$BOOTLOG" || { echo "DRAW-GATE-FAIL: no banner"; RC=1; }
for m in $MARKERS; do
	"$GREP" -q "$m" "$BOOTLOG" || { echo "DRAW-GATE-FAIL: missing $m"; RC=1; }
done
NMODS=$("$GREP" -ci 'mod ' "$BOOTLOG" || true)
[ "$NMODS" -gt 0 ] || { echo "DRAW-GATE-FAIL: no 'mod' boot print (A2: the -initrd did not register as an mb1 module)"; RC=1; }
if "$GREP" -qiE 'panic|sys: trap' "$BOOTLOG"; then
	echo "DRAW-GATE-FAIL: panic/trap lines in the capture"
	RC=1
fi
if [ "$RC" -eq 0 ]; then
	echo "DRAW-GATE-PASS: markers present ($MARKERS), zero panic/trap, accel=$ACCEL"
fi

# the capture is the gate's evidence — cat it to THIS script's stdout
echo "== serial capture ($BOOTLOG):"
cat "$BOOTLOG"
exit "$RC"
