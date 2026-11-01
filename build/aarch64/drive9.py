#!/usr/bin/env python3
# drive9.py — serial-console driver for the 9front donor kernel boot
# (build/aarch64 harness, plan 02-04 Task 2).
#
# Ports the Phase 1 capture-before-start discipline (build/mm/
# boot-9k10cpu.sh) to plain qemu: the caller launches qemu PAUSED (-S)
# with the serial port on a chardev unix socket (server=on,wait=off) and
# a QMP socket; this script attaches the capture FIRST (nothing the guest
# prints is lost), then resumes the guest via QMP "cont", then drives the
# boot to an rc shell with send-on-match over the serial socket
# (expect-style; expect itself would need nc/socat for unix sockets —
# python stdlib sockets are identical on darwin and linux).
#
# Drive table (calibrated against the pinned donor 35026610 boot flow —
# sys/src/9/boot/boot.c, bootrc, net.rc, and factotum's
# promptforhostowner):
#   1. wait for the "bootargs is (tcp, ...)" prompt — bootrc's ask();
#      bootargs=tcp arrives via -append (qemu -append lands in the DTB
#      /chosen/bootargs, read by the kernel's bootargsinit), so the
#      prompt's default is already "tcp" — answer with a bare CR.
#   1b. confignet's `ask auth ' address is? '` (net.rc) still fires —
#      auth is not pre-seeded; answer with a bare CR (the fs default).
#      The auth value is unused on this path: srv's amount() falls back
#      to noauth when srv9 Rerrors Tauth, and the secstore block is
#      guarded by test -x /bin/auth/secstore (absent in the bootfs).
#   2. the user prompt never appears: -append also carries user=glenda,
#      and factotum -u (promptforhostowner, fs.c util.c:699-713) reads
#      getenv("user") first — no readcons prompt when set.
#   3. wait for an interactive rc shell: probe with
#      `echo __GSD_SHELL_^OK__` every few seconds. rc's ^ concatenation
#      means the console-echoed command line never contains the
#      contiguous marker, so a line containing ONLY the marker
#      (^__GSD_SHELL_OK__$) can only be rc's OUTPUT — rc evaluated the
#      concatenation. Echo alone cannot satisfy the proof, even if the
#      console input path drops burst-leading bytes while kbdfs is busy
#      (dropping exactly "echo " used to leave a matching line).
#   4. set prompt='term% ' and emit one more marker: the rc-emitted
#      "term% " prompt line in the log satisfies the plan's
#      (term|cpu)% assertion — the donor's default prompt is bare '% '
#      (rc/lib/rcmain), so we set the documented signature explicitly.
#      The proof is anchored (^term% $ — the echoed assignment line
#      "prompt='term% '" contains the substring but cannot match) and
#      order-dependent (the prompt is accepted only in the buffer
#      region AFTER the probe marker's output line): rc printed the new
#      prompt because it evaluated our assignment interactively, then
#      executed our echo.
#
# Panic/trap fast-fail: any "panic" or "trap:" line aborts immediately.
#
# usage: drive9.py --serial SOCK --qmp SOCK --log FILE [--budget SECS]

import os
import re
import socket
import sys
import threading
import time

SHELL_MARKER = "__GSD_SHELL_OK__"
PANIC_RE = re.compile(rb"panic|trap:", re.I)
BOOTARGS_RE = re.compile(rb"bootargs is \(tcp")
AUTH_RE = re.compile(rb"auth address is\?")
SHELL_RE = re.compile(rb"(?m)^" + SHELL_MARKER.encode() + rb"\r?$")
# The liveness probe splits the marker with rc's ^ concatenation
# operator: the echoed command line ("echo __GSD_SHELL_^OK__") never
# contains the contiguous marker, so SHELL_RE can only match rc's
# output line. (Byte-drop safety: a line matching SHELL_RE now needs
# both the burst-leading "echo " AND the mid-marker caret to vanish.)
SHELL_PROBE = b"echo __GSD_SHELL_^OK__\r"
# Anchored to a bare prompt line: the echoed assignment line
# ("prompt='term% '") contains "term% " as a substring but cannot match.
PROMPT_RE = re.compile(rb"(?m)^term% $")
PROMPT_SET_RE = re.compile(rb"(?m)^__GSD_PROMPT_SET__\r?$")


class Log:
    def __init__(self, path):
        self.fp = open(path, "wb", buffering=0)
        self.buf = b""
        self.lock = threading.Lock()

    def write(self, data):
        with self.lock:
            self.fp.write(data)
            self.buf += data
            if len(self.buf) > 512 * 1024:
                self.buf = self.buf[-256 * 1024:]

    def tail(self, n=4096):
        with self.lock:
            return self.buf[-n:]

    def search(self, rx):
        with self.lock:
            return rx.search(self.buf) is not None

    def search_from(self, rx, base):
        with self.lock:
            return rx.search(self.buf, base) is not None

    def length(self):
        with self.lock:
            return len(self.buf)


def reader(sock, log):
    while True:
        try:
            data = sock.recv(4096)
        except OSError:
            return
        if not data:
            return
        log.write(data)


def qmp_cont(path):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect(path)
    f = s.makefile("rwb")
    f.readline()  # greeting
    f.write(b'{"execute":"qmp_capabilities"}\r\n')
    f.flush()
    f.readline()
    f.write(b'{"execute":"cont"}\r\n')
    f.flush()
    time.sleep(0.2)
    try:
        f.close()
        s.close()
    except OSError:
        pass


def fail(log, msg):
    sys.stderr.write("drive9: %s\n" % msg)
    sys.stderr.write("drive9: last log lines:\n")
    tail = log.tail(2048).decode("utf-8", "replace")
    sys.stderr.write(tail + "\n")
    return 1


def main(argv):
    serial = qmp = logpath = None
    budget = 600
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--serial":
            serial = argv[i + 1]; i += 2
        elif a == "--qmp":
            qmp = argv[i + 1]; i += 2
        elif a == "--log":
            logpath = argv[i + 1]; i += 2
        elif a == "--budget":
            budget = int(argv[i + 1]); i += 2
        else:
            sys.stderr.write("drive9: unknown arg %s\n" % a)
            return 2
    if not serial or not qmp or not logpath:
        sys.stderr.write("drive9: --serial, --qmp and --log are required\n")
        return 2

    deadline = time.time() + budget
    log = Log(logpath)

    # 1. attach the capture BEFORE the guest runs (qemu is paused with
    #    -S; the chardev socket already exists)
    s = None
    while time.time() < deadline:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(serial)
            break
        except OSError:
            if s:
                s.close()
            s = None
            time.sleep(0.5)
    if s is None:
        return fail(log, "serial socket %s never appeared" % serial)
    threading.Thread(target=reader, args=(s, log), daemon=True).start()

    # 2. resume the guest
    try:
        qmp_cont(qmp)
    except OSError as e:
        return fail(log, "qmp cont failed: %s" % e)
    sys.stderr.write("drive9: capture attached, guest resumed (budget %ds)\n" % budget)

    # 3. answer the bootargs prompt
    while time.time() < deadline:
        if PANIC_RE.search(log.tail(8192)):
            return fail(log, "kernel panic/trap during early boot")
        if log.search(BOOTARGS_RE):
            break
        time.sleep(1)
    else:
        return fail(log, "no bootargs prompt within budget")
    sys.stderr.write("drive9: bootargs prompt seen; answering default (tcp)\n")
    s.sendall(b"\r")

    # 4. wait for the interactive shell via echo probes; answer the
    #    confignet auth prompt if it appears (net.rc `ask auth`)
    answered_auth = False
    nextprobe = time.time() + 10
    while time.time() < deadline:
        if PANIC_RE.search(log.tail(8192)):
            return fail(log, "kernel panic/trap during boot")
        if not answered_auth and log.search(AUTH_RE):
            sys.stderr.write("drive9: auth-address prompt seen; answering default\n")
            s.sendall(b"\r")
            answered_auth = True
            continue
        if log.search(SHELL_RE):
            break
        if time.time() >= nextprobe:
            try:
                s.sendall(SHELL_PROBE)
            except OSError:
                return fail(log, "serial socket closed during boot")
            nextprobe = time.time() + 5
        time.sleep(1)
    else:
        return fail(log, "no interactive rc shell within %ds budget" % budget)
    sys.stderr.write("drive9: rc shell reached (marker executed)\n")

    # 5. set the documented prompt signature and prove it was evaluated.
    #    Order-dependent: wait for the probe's OUTPUT line first (rc
    #    provably executing), then accept the anchored bare prompt only
    #    in the buffer region after the base recorded here — the echoed
    #    assignment line alone can never satisfy either regex.
    base = log.length()
    s.sendall(b"prompt='term% '\r")
    time.sleep(1)
    s.sendall(b"echo __GSD_PROMPT_SET__\r")
    pdeadline = time.time() + 60
    while time.time() < pdeadline:
        if log.search_from(PROMPT_SET_RE, base):
            break
        time.sleep(0.5)
    else:
        return fail(log, "shell did not execute the prompt probe")
    while time.time() < pdeadline:
        if log.search_from(PROMPT_RE, base):
            sys.stderr.write("drive9: rc printed the term%% prompt — shell is live\n")
            return 0
        time.sleep(0.5)
    return fail(log, "shell did not emit the term% prompt after assignment")


if __name__ == "__main__":
    sys.exit(main(sys.argv) or 0)
