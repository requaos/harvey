#!/bin/sh
# build/aarch64/run-gate.sh — the TC-03 execution gate (plan 02-05):
# the committed hello.7.out (plan 02-03, built by Harvey's vendored
# 7c/7l with the frozen-ABI SVC stubs) EXECUTES on the 9front donor
# kernel (plan 02-04, built in-donor-tree by the same tools) under
# qemu -M virt TCG, printing its marker line over the serial console.
#
# This is the phase's load-bearing proof (the riscv64 vaporware gate,
# ROADMAP SC#3): compiler → assembler → linker → libc asm → generated
# SVC stubs → syscall wire contract → reference-kernel execution, in
# one executed slice, BEFORE any aarch64/ scaffolding lands (02-06).
# Phase 4 inherits hello.7.out as the known-good ABI bisect point: if
# it later fails on r9, the bug is in r9 (D-06 rationale).
#
# Usage (from the repo root, inside the nix devshell):
#   sh build/aarch64/run-gate.sh
#
# Env overrides: HARVEY, HARVEY_VM, QEMU_BIN, HARNESS_BIN, BOOT_BUDGET,
#   SRV9_PORT, DONOR_DIST_HOST (same meaning as boot-9qemu.sh).
#
# Steps:
#   1. record sha256 of the committed build/aarch64/hello.7.out
#   2. rsync it to the lima guest's disposable donor tree at
#      ~/9front-donor/arm64/bin/hello and add one bootdir line to the
#      guest copy's CONF=qemu (guest-scratch staging — never committed
#      anywhere, never pushed back into the host's pristine checkout)
#   3. targeted guest namespace rebuild: cd /sys/src/9/arm64 && mk
#      CONF=qemu — mkrootall embeds /arm64/bin/hello into the kernel's
#      root filesystem as /boot/hello; relink + aout2uimage produces
#      9qemu-gate{,.u} (the proven 9qemu.u is left untouched)
#   4. boot 9qemu-gate.u with exactly boot-9qemu.sh's qemu invocation
#      and capture-before-start discipline (TCG pin, DTB pre-placement,
#      GICR WAKER poke, guestfwd root, cleanup trap — duplicated, per
#      the plan's "duplicate the discipline" allowance)
#   5. at the rc prompt: send `/boot/hello`, then `echo __GSD_EXIT__$status`
#   6. assert on the serial log: 9front banner, term% prompt, the
#      marker line "hello aarch64 harvey" AFTER the prompt, an empty
#      $status marker line, zero fault lines
#   7. append the evidence block to build/aarch64/gate-evidence.log
#
# Flagged-assumption resolution (plan 02-05, "spec-less probe
# fallback"): the plan's step (2) says to stage hello where the
# CONF=qemu bootdir/mkpaqfs wiring picks it up — "add hello there,
# e.g. as /hello". The donor's boot flow decides WHICH wiring works:
# boot.c paqfs-mounts bootfs.paq at /root and bootrc later does
# `unmount /` + `unmount /mnt/broot` before exec'ing init — a
# paq-baked binary is GONE at the rc prompt. The CONF bootdir embeds
# via mkrootall into the kernel's embedded root (devroot), which
# survives as the base of the / union (bootrc: bind -a /root / after
# unmount /). devroot's root directory exposes only boot/ (devroot.c
# rootlist), so bootdir entries land UNDER /boot with mode 0555
# (addbootfile) — the same place the kernel's own /boot/boot lives.
# The runnable path at the rc prompt is therefore /boot/hello.
# mkpaqfs is not re-run — the paq is untouched.
#
# On failure the script halts non-zero and the guest serial log
# (.build/9front-dist/run-gate.log) is the bisect surface — per the
# toolchain-first diagnostic rule, suspect our 7c/7l/libc/stubs before
# the donor kernel.

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build-donor}"
GUEST_DONOR="${DONOR_GUEST_DIR:-9front-donor}"
GUEST_DIST=9front-dist
DONOR="$HARVEY/.build/9front-donor"
DONOR_SHA=350266104f1fed81c78c3d05fa44f523bec0ae4d
DIST="${DONOR_DIST_HOST:-$HARVEY/.build/9front-dist}"
HELLO="$HARVEY/build/aarch64/hello.7.out"
EVIDENCE="$HARVEY/build/aarch64/gate-evidence.log"
BUILDLOG="$DIST/gate-rebuild.log"
RUNLOG="${QEMU_LOG:-$DIST/run-gate.log}"
GATE_U="$DIST/9qemu-gate.u"
GATE_K="$DIST/9qemu-gate"
ROOTFS="${ROOTFS:-$DIST/srvroot}"
BOOT_BUDGET="${BOOT_BUDGET:-600}"
SRV9_PORT="${SRV9_PORT:-1564}"
SRV9_GUEST_IP="${SRV9_GUEST_IP:-10.0.2.100}"

err() { echo "error: $*" >&2; exit 1; }

sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

# ---- preconditions (read-only) ------------------------------------
[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
[ -s "$HELLO" ] || err "$HELLO missing/empty — run sh build/aarch64/pre-gate-build.sh (plan 02-03) first"
actual=$(git -C "$DONOR" rev-parse HEAD 2>/dev/null || echo missing)
[ "$actual" = "$DONOR_SHA" ] || err "donor pin mismatch: want $DONOR_SHA, have $actual"
[ -d "$ROOTFS/arm64/bin" ] || err "$ROOTFS incomplete — run sh build/aarch64/donor-vm-build.sh first"
command -v limactl >/dev/null 2>&1 || err "limactl not found — run inside the nix devshell"
if ! limactl list -q 2>/dev/null | /usr/bin/grep -qx "$VM"; then
	err "lima VM '$VM' does not exist"
fi
status=$(limactl list --format '{{.Status}}' "$VM" 2>/dev/null || echo unknown)
if [ "$status" != "Running" ]; then
	limactl start "$VM"
fi

QEMU_BIN="${QEMU_BIN:-}"
if [ -z "$QEMU_BIN" ]; then
	QEMU_BIN=$(command -v qemu-system-aarch64 || true)
fi
[ -n "$QEMU_BIN" ] && [ -x "$QEMU_BIN" ] || err "qemu-system-aarch64 not found — run inside the nix devshell or set QEMU_BIN"
"$QEMU_BIN" --version >/dev/null 2>&1 || err "$QEMU_BIN not runnable"

HARNESS_BIN="${HARNESS_BIN:-}"
if [ -z "$HARNESS_BIN" ]; then
	HARNESS_BIN=$(command -v harness || true)
fi
[ -n "$HARNESS_BIN" ] && [ -x "$HARNESS_BIN" ] || \
	err "harness binary not found — set HARNESS_BIN or run inside the nix devshell (which exports it)"

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

# ---- 1. sha256 of the committed binary (the evidence anchor) ------
HOST_SHA=$(sha256 "$HELLO")
echo "== committed hello.7.out sha256: $HOST_SHA"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/run-gate.XXXXXX")
SRV9_PID=""
QEMU_PID=""
POKE_PID=""
cleanup() {
	status=$?
	[ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
	[ -n "$SRV9_PID" ] && kill "$SRV9_PID" 2>/dev/null || true
	[ -n "$POKE_PID" ] && kill "$POKE_PID" 2>/dev/null || true
	rm -rf "$TMPD"
	exit $status
}
trap cleanup EXIT

# ---- 2/3. guest staging + targeted rebake --------------------------
# The guest-side script is written from here-documents so run-gate.sh
# stays the single committed harness file. It mirrors donor-ns-build.sh's
# namespace discipline (same binds, same PATH order, same su-proof env)
# but runs only the kernel relink: the guest donor tree keeps its 02-04
# build outputs (donor-vm-build.sh rsyncs the donor WITHOUT --delete),
# so this is incremental — root.s/rootc.c regeneration + 7c/7a/7l +
# aout2uimage, seconds-to-minutes, not a full rebuild.
cat > "$TMPD/gate-ns-rebuild.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# gate-ns-rebuild.sh — guest side of run-gate.sh (self-re-entrant:
# wrap -> --ns -> --build, the donor-ns-build.sh shape). Lives in the
# guest's /tmp; never committed.
set -eu

# DONOR/SCRATCH/DIST resolve against the USER's home in the wrap phase
# and are exported BEFORE capture (the --ns phase runs as root with
# $HOME=/root — it must inherit the user's paths through the exports
# file; the :- form keeps the exported value in every phase).
DONOR="${DONOR:-$HOME/9front-donor}"
SCRATCH="${DONOR_HOSTBIN:-$HOME/9front-hostbin}"
DIST="${DONOR_DIST:-$HOME/9front-dist}"

if [ "${1:-}" = "--build" ]; then
	# repo user, inside the namespace
	set -eu
	PATH="$SCRATCH:$HARVEY_LINUX_BIN:$PLAN9/bin:$PATH"
	export PATH
	objtype=arm64
	export objtype
	FORCERCFORMK=1
	export FORCERCFORMK

	echo "== gate rebake provenance (donor kernel relinked by Harvey's tools):"
	echo "   7c: $(command -v 7c)"
	echo "   7a: $(command -v 7a)"
	echo "   7l: $(command -v 7l)"
	echo "   ar: $(command -v ar)"
	echo "   mk: $(command -v mk)"

	cd /sys/src/9/arm64
	# force regeneration of everything derived from the CONF/bootdir:
	# mkdevc (qemu.c), mkrootall/mkrootc (root.s/rootc.c — the hello
	# embed), the link, and the uImage wrap. All other objects are
	# cached from the 02-04 build.
	rm -f qemu.c qemu.7 qemu.root.s qemu.root.7 qemu.rootc.c qemu.rootc.7 9qemu 9qemu.u
	mk 'CONF=qemu'

	[ -s 9qemu ] && [ -s 9qemu.u ] || { echo "error: relink produced no kernel" >&2; exit 1; }
	mkdir -p "$DIST"
	cp 9qemu "$DIST/9qemu-gate"
	cp 9qemu.u "$DIST/9qemu-gate.u"
	echo "== gate kernel assembled: $DIST/9qemu-gate{,.u}"
	exit 0
fi

if [ "${1:-}" = "--ns" ]; then
	# root, inside the private mount namespace (donor-ns-build.sh binds)
	set -u
	BUILD_USER="${2:?internal}"
	ENVFILE="${3:?internal}"
	. "$ENVFILE"

	[ -d "$DONOR/sys/src/9/arm64" ] || {
		echo "error: $DONOR does not look like the 9front donor checkout" >&2
		exit 1
	}

	mount --bind "$DONOR/sys" /sys
	mkdir -p /arm64
	mount --bind "$DONOR/arm64" /arm64
	mkdir -p /aarch64
	mount --bind "$DONOR/arm64" /aarch64
	mkdir -p /rc
	mount --bind "$DONOR/rc" /rc

	# merged /lib (donor-ns-build.sh discipline; distro runtime + donor lib)
	if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
	NSLIB=/tmp/gatelib.$$
	mkdir -p "$NSLIB"
	cp -a "$LIBREAL"/. "$NSLIB/"
	cp -a "$DONOR/lib"/. "$NSLIB/" 2>/dev/null || true
	chown 0:0 "$NSLIB"
	chmod 1777 "$NSLIB"
	mount --bind "$NSLIB" "$LIBREAL"

	unwind() {
		umount "$LIBREAL" 2>/dev/null || true
		rm -rf "$NSLIB"
	}
	trap unwind EXIT

	set +e
	su -c ". '$ENVFILE'; bash '$0' --build" "$BUILD_USER"
	RC=$?
	exit $RC
fi

# wrap phase: repo user, devshell env (nix develop -c)
set -eu

# CONF patch (idempotent): add hello to the guest copy's bootdir.
# mkrootall strips executables before embedding (symbol table only —
# the executed code is byte-identical); the evidence hash is therefore
# taken from the staged pre-strip binary below.
CONF="$DONOR/sys/src/9/arm64/qemu"
if grep -qF '/$objtype/bin/hello' "$CONF"; then
	echo "== CONF already carries the hello bootdir line (idempotent rerun)"
else
	echo "== adding hello to the guest-copy CONF=qemu bootdir"
	awk '
		/^bootdir$/ { inbd=1; print; next }
		inbd && /^[^ \t]/ { print "\t/$objtype/bin/hello\thello"; inbd=0; print; next }
		{ print }
		END { if (inbd) print "\t/$objtype/bin/hello\thello" }
	' "$CONF" > "$CONF.gate"
	mv "$CONF.gate" "$CONF"
fi
echo "== guest CONF bootdir now:"
sed -n '/^bootdir/,$p' "$CONF"

# the binary itself is rsynced into place by the host driver before
# this script runs; assert and hash it here (the guest-side "after" sha)
[ -s "$DONOR/arm64/bin/hello" ] || {
	echo "error: staged hello missing at $DONOR/arm64/bin/hello" >&2
	exit 1
}
chmod 755 "$DONOR/arm64/bin/hello"
echo "GUEST_SHA256=$(sha256sum "$DONOR/arm64/bin/hello" | awk '{print $1}')"

mkdir -p "$DIST"
export DONOR SCRATCH DIST
EXPORTS=/tmp/gate-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m bash "$0" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
GUEST_EOF

echo "== staging hello.7.out into the guest donor tree ($GUEST_DONOR/arm64/bin/hello)"
rsync -a -e "$RSYNC_RSH" "$HELLO" "$GUEST:$GUEST_DONOR/arm64/bin/hello"

echo "== pushing the guest rebake script"
rsync -a -e "$RSYNC_RSH" "$TMPD/gate-ns-rebuild.sh" "$GUEST:/tmp/gsd-gate-ns-rebuild.sh"

echo "== targeted donor kernel rebake in the guest namespace (log: $BUILDLOG)"
mkdir -p "$DIST"
set +e
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c bash /tmp/gsd-gate-ns-rebuild.sh" > "$BUILDLOG" 2>&1
RC=$?
set -e
cat "$BUILDLOG"
if [ $RC -ne 0 ]; then
	echo "error: guest rebake failed (rc=$RC); log: $BUILDLOG" >&2
	exit $RC
fi

GUEST_SHA=$(grep -m1 'GUEST_SHA256=' "$BUILDLOG" | sed 's/.*GUEST_SHA256=//' | tr -d '\r' | tr -d '[:space:]')
[ -n "$GUEST_SHA" ] || err "guest did not report a staged sha256"
if [ "$GUEST_SHA" != "$HOST_SHA" ]; then
	err "staged binary hash mismatch: host $HOST_SHA vs guest $GUEST_SHA — what would run is not what is committed"
fi
echo "== staged guest binary is sha256-identical to the committed one"

echo "== pulling the gate kernel back to $DIST"
rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIST/9qemu-gate" "$GATE_K"
rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIST/9qemu-gate.u" "$GATE_U"
[ -s "$GATE_U" ] || err "$GATE_U missing/empty after rsync"
GATE_KERNEL_SHA=$(sha256 "$GATE_U")
echo "== gate kernel: $GATE_U (sha256 $GATE_KERNEL_SHA)"

# ---- 4/5. boot + execute (boot-9qemu.sh discipline, duplicated) ----
# The post-shell step table (replacing the gatedrive9.py heredoc — D-04):
# drive9 --steps drives the proven boot (capture-before-start, QMP cont,
# bootargs/auth answers, anchored prompt proof), then runs these rows with
# paced echo-verified sends. Tab-separated: cmd, echo-pattern (literal \r
# escape in cmd), out-pattern, timeout-secs, label. Row 1's echo pattern is
# explicit ([\r\n] covers kbdfs's cooked echo ending); row 2's echo check
# anchors on the command's stable prefix.
cat > "$TMPD/steps.tsv" <<'STEPS_EOF'
/boot/hello\r	/boot/hello[\r\n]	hello aarch64 harvey	120	/boot/hello
echo __GSD_EXIT__$status\r	echo __GSD_EXIT__	^__GSD_EXIT__\r?$	60	exit-status probe
STEPS_EOF

# serve the root fs (9P2000, read-only) on the host — same srvroot the
# proven boot used; hello does NOT come from here (it is in devroot)
echo "== serving $ROOTFS on 127.0.0.1:$SRV9_PORT (9P2000)"
"$HARNESS_BIN" srv9 serve --root "$ROOTFS" --host 127.0.0.1 --port "$SRV9_PORT" \
	> "$TMPD/srv9.log" 2>&1 &
SRV9_PID=$!
# poll for the 'srv9: serving' line the Rust server prints after listen()
i=0
while ! grep -q 'srv9: serving' "$TMPD/srv9.log" 2>/dev/null; do
	i=$((i + 1))
	if [ $i -gt 60 ]; then
		cat "$TMPD/srv9.log" >&2 || true
		err "srv9 did not start listening on 127.0.0.1:$SRV9_PORT"
	fi
	if ! kill -0 "$SRV9_PID" 2>/dev/null; then
		cat "$TMPD/srv9.log" >&2 || true
		err "srv9 exited during startup"
	fi
	sleep 1
done

# dump the DTB with the -append baked in, then launch qemu PAUSED with
# it pre-placed at 0x40000000 (boot-9qemu.sh drift accommodation 1)
APPEND="bootargs=tcp fs=$SRV9_GUEST_IP user=glenda console=0"
DTB="$TMPD/virt.dtb"
"$QEMU_BIN" \
	-M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72 -m 1G \
	-kernel "$GATE_U" \
	-append "$APPEND" \
	-machine "dumpdtb=$DTB" -display none -S &
DUMPPID=$!
sleep 2
kill $DUMPPID 2>/dev/null || true
wait $DUMPPID 2>/dev/null || true
[ -s "$DTB" ] || err "qemu dumpdtb produced no DTB"

echo "== launching qemu (TCG; -M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72; kernel $GATE_U)"
"$QEMU_BIN" \
	-M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72 -accel tcg -smp 1 -m 1G \
	-kernel "$GATE_U" \
	-append "$APPEND" \
	-device "loader,file=$DTB,addr=0x40000000" \
	-netdev "user,id=n0,guestfwd=tcp:$SRV9_GUEST_IP:564-tcp:127.0.0.1:$SRV9_PORT" \
	-device virtio-net-pci-non-transitional,netdev=n0 \
	-chardev "socket,id=ser0,path=$TMPD/serial.sock,server=on,wait=off" \
	-serial chardev:ser0 \
	-qmp "unix:$TMPD/qmp.sock,server=on,wait=off" \
	-gdb "unix:$TMPD/gdb.sock,server=on,wait=off" \
	-S -display none \
	> "$TMPD/qemu.err" 2>&1 &
QEMU_PID=$!

sleep 2
if ! kill -0 "$QEMU_PID" 2>/dev/null; then
	cat "$TMPD/qemu.err" >&2 || true
	err "qemu exited during launch (see above)"
fi

# wake the GIC redistributor (boot-9qemu.sh drift accommodation 2) —
# without ticks, console input never flushes and the boot parks at the
# bootargs prompt forever
if [ "${WAKE_POKE:-1}" != "0" ]; then
	"$HARNESS_BIN" gdbpoke9 --sock "$TMPD/gdb.sock" \
		--watch-file "$RUNLOG" --watch-str "bootargs is" \
		--deadline "$BOOT_BUDGET" \
		> "$TMPD/gdbpoke.log" 2>&1 &
	POKE_PID=$!
else
	POKE_PID=""
fi

# attach the capture BEFORE the guest runs, resume via QMP, drive the
# boot to the shell, then execute /boot/hello and check $status
echo "== driving boot to rc shell + executing /boot/hello (budget ${BOOT_BUDGET}s; log: $RUNLOG)"
set +e
"$HARNESS_BIN" drive9 --steps "$TMPD/steps.tsv" --serial "$TMPD/serial.sock" --qmp "$TMPD/qmp.sock" \
	--log "$RUNLOG" --budget "$BOOT_BUDGET"
RC=$?
set -e
if [ -n "$POKE_PID" ]; then
	wait "$POKE_PID" 2>/dev/null || true
	if [ -s "$TMPD/gdbpoke.log" ]; then
		grep -q 'poked' "$TMPD/gdbpoke.log" || {
			cat "$TMPD/gdbpoke.log" >&2
			err "GICR WAKER wake poke failed — redistributor asleep; see boot-9qemu.sh header drift note 2"
		}
	fi
fi
if [ $RC -ne 0 ]; then
	echo "error: gate run failed within ${BOOT_BUDGET}s — last log lines:" >&2
	tail -n 40 "$RUNLOG" >&2 || true
	echo "hint: the guest log is the bisect surface (toolchain-first diagnostic rule):" >&2
	echo "      suspect our 7c/7l/libc/SVC stubs before the donor kernel" >&2
	exit 1
fi

# ---- 6. assertions (defense in depth; the driver already proved it)
grep -qiE '9front|Plan 9' "$RUNLOG" || err "captured log lacks the 9front/Plan 9 banner"
grep -q 'term% ' "$RUNLOG" || err "captured log lacks the rc prompt signature"
grep -q 'hello aarch64 harvey' "$RUNLOG" || err "captured log lacks the hello marker line"
grep -q '^__GSD_EXIT__' "$RUNLOG" || err "captured log lacks the empty-exit-status marker"
if grep -qiE 'panic|trap:' "$RUNLOG"; then
	err "captured log contains a kernel fault line"
fi

# ---- 7. evidence ----------------------------------------------------
# NB: $HARVEY_LINUX_BIN is FIRST on PATH inside the devshell and its
# Plan 9 host-built date(1) returns epoch 0 on darwin — pin /bin/date.
NOW=$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
BANNER_LINE=$(grep -m1 'Plan 9' "$RUNLOG" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
BOOTFS_LINE=$(grep -m1 'qemu.bootfs:' "$RUNLOG" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
FINGERPRINT_LINE=$(grep -m1 'fingerprint:' "$RUNLOG" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
PROMPT_LINE=$(grep 'term% ' "$RUNLOG" | tail -1 | tr -d '\r' | sed 's/[[:space:]]*$//' || true)
MARKER_LINE=$(grep -m1 'hello aarch64 harvey' "$RUNLOG" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
STATUS_LINE=$(grep -m1 '^__GSD_EXIT__' "$RUNLOG" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

{
	echo "=== 02-05 TC-03 execution gate — $NOW ==="
	echo "donor: 9front branch front @ $DONOR_SHA (D-10 pin; kernel built in-donor-tree by Harvey's vendored 7a/7c/7l, plan 02-04)"
	echo "gate kernel: .build/9front-dist/9qemu-gate.u sha256 $GATE_KERNEL_SHA (guest donor rebake; hello embedded via CONF=qemu bootdir as /boot/hello)"
	echo "host sha256 (committed build/aarch64/hello.7.out): $HOST_SHA"
	echo "guest sha256 (staged 9front-donor/arm64/bin/hello): $GUEST_SHA"
	echo "hashes match: yes — the binary that ran in the guest is the committed binary"
	echo "serial banner:       $BANNER_LINE"
	echo "serial bootfs stamp: $BOOTFS_LINE"
	echo "serial fingerprint:  $FINGERPRINT_LINE"
	echo "serial rc prompt:    $PROMPT_LINE"
	echo "serial command:      /boot/hello"
	echo "serial marker:       $MARKER_LINE"
	echo "serial exit status:  $STATUS_LINE (rc \$status empty — exits(nil) success)"
	echo "serial-log fault scan: clean (0 matching lines)"
	echo "gate: PASS"
	echo "=== end ==="
	echo ""
} >> "$EVIDENCE"

# NOTE: the pre-gate "committed tree must stay scaffolding-free"
# assertion was removed when plan 02-06 committed the arch dir
# (aarch64/mkfile, include/{u.h,ureg.h}, ABI.md — commit a7945d8b5).
# aarch64/ is now legitimate committed wiring, so the gate is idempotent
# again (README: consecutive runs append consecutive PASS blocks).

echo "== PASS: hello.7.out executed on the 9front donor kernel; evidence appended to $EVIDENCE"
