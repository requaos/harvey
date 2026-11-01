#!/bin/sh
# build/aarch64/boot-9qemu.sh — boot the D-07 donor kernel (9front
# CONF=qemu arm64, built in-donor-tree by Harvey's vendored 7a/7c/7l)
# to an rc shell under qemu TCG on the host, with captured serial proof.
#
# Usage (from the repo root, inside the nix devshell):
#   sh build/aarch64/boot-9qemu.sh
#
# Env overrides:
#   HARVEY       repo root                (default: $PWD)
#   QEMU_BIN     qemu-system-aarch64      (default: PATH lookup)
#   BOOT_BUDGET  seconds to wait for the shell (default: 600 — TCG on
#                Apple silicon is slow; Phase 1's TCG-degraded serial
#                capture acceptance (2026-10-31) covers this)
#   QEMU_LOG     capture file  (default: .build/9front-dist/boot-9qemu.log)
#   ROOTFS       served root    (default: .build/9front-dist/srvroot)
#   SRV9_PORT    host-side 9P port (default: 1564 — 564 is privileged;
#                qemu guestfwd maps guest 10.0.2.100:564 here)
#   PYTHON       python3        (default: PATH lookup)
#   WAKE_POKE    set to 0 to skip the GICR WAKER wake poke (only for
#                debugging against a hypothetical qemu that wakes the
#                redistributor itself)
#
# Boot proof: the captured serial log must contain the kernel banner
# ("Plan 9", arm64/main.c:181), an rc prompt signature (term% — see
# drive9.py's header for why we set it explicitly), and no panic/trap
# line. The banner/marker greps, not the boot timer, are the source of
# truth — a healthy-but-slow TCG boot just needs a bigger BOOT_BUDGET
# (rerun; do not retry silently on a missed banner).
#
# TCG-only rationale (verified against qemu 11.1.2 on the M5 Max,
# 02-RESEARCH.md Pitfall F): the donor kernel needs GICv3 — its
# trapinit unconditionally syswr's GICv3 ICC registers (gic.c
# intrcpushutdown), which UNDEF under qemu's gic-version=2 (verified:
# "Undefined Instruction" at the mkinstr-built MSR). The research's
# "GICv2-only guest" reading (from gic.c's GICD_TARGETSR0 bank) was
# wrong. qemu rejects HVF for this guest outright — HVF with
# -M virt,gic-version=3 fails with "HVF does not support GICv3
# emulation"... (see below); and HVF with -cpu cortex-a72 fails with
# "Invalid CPU model" (valid HVF CPUs: cortex-a53, cortex-a57, host,
# max). This harness therefore pins `-accel tcg -cpu cortex-a72
# -M virt,gic-version=3,highmem-ecam=off`; no plan may "upgrade" it to
# HVF. highmem-ecam=off restores the legacy PCI ECAM at 0x3f000000 that
# the donor hardcodes (qemu 11.1.2 moved it to 0x40100000). HVF returns
# when the guest is r9 with GICv3 (Phase 3 forward-note, D-02/D-03).
#
# Donor↔qemu drift accommodations (02-04 audit; donor sources stay
# pristine per D-12 — every accommodation is harness-side):
#   1. -device loader: qemu -kernel delivers the DTB via x0 but the
#      donor reads the fixed DTBADDR=0x40000000 — pre-placed there.
#   2. GICR WAKER wake (gdbpoke9.py): qemu 11.1.2's spec-accurate GICv3
#      resets the redistributor ProcessorSleep=1 and the donor's gic.c
#      never clears it (its native platforms' firmware did). Asleep,
#      PPIs (CNTV timer INTID 27) never fire: no ticks → devuart's
#      uartclock() never flushes staged console input → dead console.
#      SPIs (uart RX) are distributor-managed and always fired, which
#      made the failure look like "input vanishes". The poke writes 0 to
#      GICR0 WAKER via the gdbstub through the guest's own VA map.
#   3. console=0 in -append: bootrc runs `aux/kbdfs -q -s cons $console`
#      and with no console key kbdfs gets NO input device (this vintage's
#      kernel /dev/cons read is Egreg by design — kbdfs is the only
#      console-input path); console=0 makes it read /dev/eia0.
#   4. virtio-net-pci-non-transitional: ethervirtio10 only matches the
#      modern device ID 0x1041; qemu's default virtio-net-pci is
#      transitional (0x1000) and never binds → no /net/ether0.
#
# Root-fs delivery (plan deviation, documented in 02-04-SUMMARY): the
# stock donor boot cannot reach a shell from the embedded bootfs.paq
# alone — bootrc needs a /srv/boot connection and the local!paqfs path
# is broken upstream (paqfs has no -f). So srv9.py serves ROOTFS over
# 9P2000/tcp (the donor's own connecttcp path) and the kernel is told
# via -append (DTB /chosen/bootargs → plan9.ini keys):
#   bootargs=tcp fs=10.0.2.100 user=glenda console=0
# user=glenda pre-answers factotum -u's promptforhostowner; the
# bootargs prompt itself is still shown and answered (CR) by drive9.py.
#
# Mechanics: qemu launches PAUSED (-S) with serial on a chardev socket
# (server=on,wait=off); drive9.py attaches the capture BEFORE the guest
# runs, resumes via QMP "cont", then drives the boot with send-on-match;
# a trap kills qemu + the 9P server and removes the tmpdir on every exit.
#
# Boundary: nothing here touches the donor tree; inputs are the
# gitignored .build/9front-dist artifacts from donor-vm-build.sh.

set -eu

HARVEY="${HARVEY:-$PWD}"
DIST="${DONOR_DIST_HOST:-$HARVEY/.build/9front-dist}"
KERNEL="$DIST/9qemu.u"
ROOTFS="${ROOTFS:-$DIST/srvroot}"
QEMU_LOG="${QEMU_LOG:-$DIST/boot-9qemu.log}"
BOOT_BUDGET="${BOOT_BUDGET:-600}"
SRV9_PORT="${SRV9_PORT:-1564}"
SRV9_GUEST_IP="${SRV9_GUEST_IP:-10.0.2.100}"

err() { echo "error: $*" >&2; exit 1; }

[ -s "$KERNEL" ] || err "$KERNEL missing/empty — run sh build/aarch64/donor-vm-build.sh first"
[ -d "$ROOTFS/arm64/bin" ] || err "$ROOTFS incomplete — run sh build/aarch64/donor-vm-build.sh first"
[ -f "$ROOTFS/arm64/init" ] || err "$ROOTFS/arm64/init missing — donor-vm-build.sh assembles it"

QEMU_BIN="${QEMU_BIN:-}"
if [ -z "$QEMU_BIN" ]; then
	QEMU_BIN=$(command -v qemu-system-aarch64 || true)
fi
[ -n "$QEMU_BIN" ] && [ -x "$QEMU_BIN" ] || err "qemu-system-aarch64 not found — run inside the nix devshell or set QEMU_BIN"
"$QEMU_BIN" --version >/dev/null 2>&1 || err "$QEMU_BIN not runnable"

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
	PYTHON=$(command -v python3 || true)
fi
[ -n "$PYTHON" ] || err "python3 not found — needed for srv9.py/drive9.py (set PYTHON)"

SRV9="$HARVEY/build/aarch64/srv9.py"
DRIVE9="$HARVEY/build/aarch64/drive9.py"
[ -f "$SRV9" ] || err "$SRV9 missing"
[ -f "$DRIVE9" ] || err "$DRIVE9 missing"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/boot-9qemu.XXXXXX")
SOCK="$TMPD/serial.sock"
QMPS="$TMPD/qmp.sock"
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

# 1. serve the root fs (9P2000, read-only) on the host
echo "== serving $ROOTFS on 127.0.0.1:$SRV9_PORT (9P2000)"
"$PYTHON" "$SRV9" serve --root "$ROOTFS" --host 127.0.0.1 --port "$SRV9_PORT" \
	> "$TMPD/srv9.log" 2>&1 &
SRV9_PID=$!
i=0
while ! "$PYTHON" -c "import socket,sys; sys.exit(socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect_ex(('127.0.0.1', $SRV9_PORT)))" >/dev/null 2>&1; do
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

# 2. dump the DTB with the -append baked in, then launch qemu PAUSED
#    with it pre-placed at 0x40000000 (the donor reads the DTB from the
#    fixed DTBADDR=0x40000000, but qemu's -kernel Linux-protocol boot
#    delivers the DTB via x0 — the donor never sees it otherwise, and
#    falls back to a wrong default memory size). Serial + qmp on unix
#    sockets; user-net with a guestfwd mapping the guest's
#    10.0.2.100:564 to the host srv9 port.
APPEND="bootargs=tcp fs=$SRV9_GUEST_IP user=glenda console=0"
DTB="$TMPD/virt.dtb"
"$QEMU_BIN" \
	-M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72 -m 1G \
	-kernel "$KERNEL" \
	-append "$APPEND" \
	-machine "dumpdtb=$DTB" -display none -S &
DUMPPID=$!
sleep 2
kill $DUMPPID 2>/dev/null || true
wait $DUMPPID 2>/dev/null || true
[ -s "$DTB" ] || err "qemu dumpdtb produced no DTB"

echo "== launching qemu (TCG; -M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72; kernel $KERNEL)"
"$QEMU_BIN" \
	-M virt,gic-version=3,highmem-ecam=off -cpu cortex-a72 -accel tcg -smp 1 -m 1G \
	-kernel "$KERNEL" \
	-append "$APPEND" \
	-device "loader,file=$DTB,addr=0x40000000" \
	-netdev "user,id=n0,guestfwd=tcp:$SRV9_GUEST_IP:564-tcp:127.0.0.1:$SRV9_PORT" \
	-device virtio-net-pci-non-transitional,netdev=n0 \
	-chardev "socket,id=ser0,path=$SOCK,server=on,wait=off" \
	-serial chardev:ser0 \
	-qmp "unix:$QMPS,server=on,wait=off" \
	-gdb "unix:$TMPD/gdb.sock,server=on,wait=off" \
	-S -display none \
	> "$TMPD/qemu.err" 2>&1 &
QEMU_PID=$!

# qemu exits immediately on bad args — catch that early
sleep 2
if ! kill -0 "$QEMU_PID" 2>/dev/null; then
	cat "$TMPD/qemu.err" >&2 || true
	err "qemu exited during launch (see above)"
fi

# 2b. wake the GIC redistributor (donor↔qemu drift — see header, drift
#     accommodation 2): without ticks, console input never flushes and
#     the boot parks at the bootargs prompt forever. The poker watches
#     the captured log for the prompt (MMU long-up by then), then halts
#     the guest once, pokes GICR0 WAKER=0 through the gdbstub, resumes.
#     A CR the driver sent meanwhile sits staged in the UART and is
#     flushed by uartclock() on the first tick after the wake.
if [ "${WAKE_POKE:-1}" != "0" ]; then
	"$PYTHON" "$HARVEY/build/aarch64/gdbpoke9.py" --sock "$TMPD/gdb.sock" \
		--watch-file "$QEMU_LOG" --watch-str "bootargs is" \
		--deadline "$BOOT_BUDGET" \
		> "$TMPD/gdbpoke.log" 2>&1 &
	POKE_PID=$!
else
	POKE_PID=""
fi

# 3. attach the capture BEFORE the guest runs, resume via QMP, drive
#    the boot to the shell (banner → bootargs answered → rc prompt)
echo "== driving boot to rc shell (budget ${BOOT_BUDGET}s; log: $QEMU_LOG)"
set +e
"$PYTHON" "$DRIVE9" --serial "$SOCK" --qmp "$QMPS" --log "$QEMU_LOG" \
	--budget "$BOOT_BUDGET"
RC=$?
set -e
if [ -n "$POKE_PID" ]; then
	wait "$POKE_PID" 2>/dev/null || true
	# the wake poke is mandatory: if it never landed, the hang below is
	# explained by the poke log, not by the boot itself
	if [ -s "$TMPD/gdbpoke.log" ]; then
		grep -q 'poked' "$TMPD/gdbpoke.log" || {
			cat "$TMPD/gdbpoke.log" >&2
			err "GICR WAKER wake poke failed — redistributor asleep; see header drift note 2"
		}
	fi
fi
if [ $RC -ne 0 ]; then
	echo "error: boot did not reach an rc shell within ${BOOT_BUDGET}s — last log lines:" >&2
	tail -n 40 "$QEMU_LOG" >&2 || true
	echo "hint: a healthy-but-slow TCG boot just needs a bigger BOOT_BUDGET; a missed" >&2
	echo "      early banner means the capture attached late — triage manually, do not" >&2
	echo "      retry silently" >&2
	exit 1
fi

# 4. assertions (defense in depth; drive9.py already proved the shell)
grep -qiE '9front|Plan 9' "$QEMU_LOG" || err "captured log lacks the 9front/Plan 9 banner"
grep -qE '(term|cpu)%' "$QEMU_LOG" || err "captured log lacks the rc prompt signature"
if grep -qiE 'panic|trap:' "$QEMU_LOG"; then
	err "captured log contains a panic/trap line"
fi

echo "== PASS: donor kernel booted to an rc shell under TCG; log: $QEMU_LOG"
