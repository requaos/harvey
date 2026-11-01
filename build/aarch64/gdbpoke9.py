#!/usr/bin/env python3
# gdbpoke9.py — poke guest memory through qemu's gdbstub with a raw
# RSP (gdb remote serial protocol) client: no external debugger needed.
#
# Written for plan 02-04's boot harness: qemu 11.1.2's GICv3 model
# resets GICR_WAKER.ProcessorSleep=1 (spec-accurate; older qemu was
# lenient) and the pinned 9front donor's gic.c defines GICR_WAKER but
# never clears it (on its native targets the firmware did). With the
# redistributor asleep, PPI interrupts — notably the CNTV timer
# (INTID 27) — never fire: no clock ticks, so devuart's uartclock()
# never flushes staged console input and every alarm/timeout never
# expires (observed: boot parked forever at the bootargs prompt with
# input dead; GICR0_WAKER physically read as 0x6 via QMP xp; a debugger
# poke to 0 made ticks run — localclockintr breakpoint hits — and the
# boot completed to an rc shell). SPIs are distributor-managed, which is
# why UART RX interrupts fired and silently drained the FIFO all along.
#
# The poke writes 0 to the redistributor-0 WAKER through the guest's own
# kernel VA mapping (VIRTIO=0xFFFFFFFFB0000000 + 0xA0000 GICR + 0x14).
# Timing: the harness boots with an unawakened redistributor quite fine
# up to the bootargs prompt (console output is polled); we watch the
# captured serial log for the prompt string — by then the MMU map is
# long up — then halt once (\x03), write, resume (c), detach. Any
# bootargs answer the driver already sent sits staged in the UART and is
# flushed by uartclock() on the first tick after the wake.
#
# Donor sources stay pristine (D-12): same harness-accommodation
# category as highmem-ecam=off and the DTB loader pre-placement.
#
# usage: gdbpoke9.py --sock PATH --watch-file LOG [--watch-str STR]
#        [--addr HEX] [--value HEX] [--bytes N] [--deadline SECS]
# exits 0 once the write lands, 1 on timeout/error.

import socket
import sys
import time


def pkt(data):
    return b"$" + data + b"#" + ("%02x" % (sum(data) & 0xFF)).encode()


def recv_pkt(s, deadline):
    s.settimeout(max(1, int(deadline - time.time())))
    while True:
        ch = s.recv(1)
        if not ch:
            raise OSError("gdbstub closed")
        if ch == b"+":
            continue
        if ch == b"$":
            payload = b""
            while True:
                c = s.recv(1)
                if not c:
                    raise OSError("gdbstub closed mid-packet")
                if c == b"#":
                    s.recv(2)
                    s.sendall(b"+")
                    return payload
                payload += c


def main(argv):
    sock = addr = value = None
    watch_file = None
    watch_str = "bootargs is"
    nbytes = 4
    deadline = time.time() + 120
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--sock":
            sock = argv[i + 1]; i += 2
        elif a == "--addr":
            addr = int(argv[i + 1], 16); i += 2
        elif a == "--value":
            value = int(argv[i + 1], 16); i += 2
        elif a == "--bytes":
            nbytes = int(argv[i + 1]); i += 2
        elif a == "--watch-file":
            watch_file = argv[i + 1]; i += 2
        elif a == "--watch-str":
            watch_str = argv[i + 1]; i += 2
        elif a == "--deadline":
            deadline = time.time() + int(argv[i + 1]); i += 2
        else:
            sys.stderr.write("gdbpoke9: unknown arg %s\n" % a)
            return 2
    if not sock or not watch_file:
        sys.stderr.write("gdbpoke9: --sock and --watch-file are required\n")
        return 2
    if addr is None:
        addr = 0xFFFFFFFFB00A0014  # VIRTIO + 0xA0000 (GICR0) + 0x14 (WAKER)
    if value is None:
        value = 0

    # 1. wait for the watch string in the captured serial log (the boot
    #    reached the bootargs prompt; MMU/kernel maps are live)
    seen = 0
    while time.time() < deadline:
        try:
            with open(watch_file, "rb") as f:
                if watch_str.encode() in f.read():
                    seen = 1
                    break
        except OSError:
            pass
        time.sleep(0.5)
    if not seen:
        sys.stderr.write("gdbpoke9: watch string %r never appeared\n" % watch_str)
        return 1

    # 2. connect the stub, query state (?) — the guest parked at the
    #    prompt reports stopped (T05) and memory writes are processed —
    #    then write. Retry the whole connect+write on failure: early in
    #    the window the vCPU may still be mid-boot (M answered only when
    #    the stub can service it). NOTE: do NOT send \x03/vCtrlC — qemu
    #    11.1.2's gdbstub never answers a halt for a vCPU parked in WFI
    #    with its timer interrupt dead (the very state we are fixing).
    data = value.to_bytes(nbytes, "little").hex().encode()
    tries = 0
    while time.time() < deadline:
        tries += 1
        s = None
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock)
            s.sendall(pkt(b"?"))
            r = recv_pkt(s, deadline)
            if not r.startswith((b"T", b"S")):
                raise OSError("state query got %r" % r)
            s.sendall(pkt(b"M%x,%x:%s" % (addr, nbytes, data)))
            r = recv_pkt(s, deadline)
            if r != b"OK":
                raise OSError("memory write: %r" % r)
            sys.stderr.write("gdbpoke9: poked %#x=%#x after %d attempt(s) (watch %r seen)\n"
                             % (addr, value, tries, watch_str))
            try:
                s.sendall(pkt(b"D"))  # detach; guest keeps running
            except OSError:
                pass
            return 0
        except OSError as e:
            sys.stderr.write("gdbpoke9: attempt %d: %s\n" % (tries, e))
        finally:
            if s:
                try:
                    s.close()
                except OSError:
                    pass
        time.sleep(1)
    sys.stderr.write("gdbpoke9: poke never landed within deadline\n")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv) or 0)
