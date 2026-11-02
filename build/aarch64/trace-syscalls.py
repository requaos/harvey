#!/usr/bin/env python3
# trace-syscalls.py — D-14 (04-01 Task 3): measure the hello-path syscall
# footprint on the 9front donor kernel.  Zero guessed syscalls: the set is
# produced by the donor's own per-syscall tracer (syscallfmt.c, compiled
# into every 9front kernel), driven over devproc's startsyscall ctl +
# /proc/N/syscall per RESEARCH.md "D-14 Deliverable" (primary method).
#
# Pipeline (every Phase-2 harness discipline reused):
#   1. compile build/aarch64/tracehello.c with Harvey's vendored 7c/7l in
#      the lima guest's Harvey namespace (nsrun.sh --wrap), libc.a for
#      aarch64 refreshed incrementally first
#   2. stage tracehello + the rc trace loop into the guest donor tree's
#      CONF=qemu bootdir (guest-scratch, never committed anywhere — the
#      run-gate.sh discipline) and rebake the donor kernel
#      (mkrootall embeds them as /boot/tracehello and /boot/trace.rc;
#      mkrootall strips only `file`-identified executables, so the text
#      rc script rides through data2s unharmed)
#   3. boot 9qemu-trace.u with run-gate.sh's exact qemu invocation (GICv3
#      + highmem-ecam=off drift accommodations, DTB pre-placement at
#      0x40000000, GICR WAKER wake poke, guestfwd root fs, capture-before-
#      start, QMP cont), drive to the rc shell
#   4. trace: launch /boot/tracehello backgrounded, capture $apid, stop it
#      mid-spin (the leading pure-compute loop guarantees no syscall can
#      fire before the tracer is armed), then run /boot/trace.rc — the
#      RESEARCH recipe verbatim:
#          echo stop > /proc/$pid/ctl
#          while () { echo startsyscall > /proc/$pid/ctl || break
#                     cat /proc/$pid/syscall }
#      The startsyscall write blocks until the target's next stop; each
#      stop leaves exactly one fragment in /proc/N/syscall (entry and
#      return alternate); the loop ends with Eprocdied when the target's
#      EXITS lands — clean termination.
#   5. parse the ENTRY fragments host-side (`<pid> <text> <name> <pc> …`
#      from syscallfmt; return fragments begin " = " and carry no name),
#      resolve each name against sys/src/libc/9syscall/sys.h (donor
#      sysctab lowercases and strips the trailing underscore, so "brk"
#      resolves to BRK_=24 via the name+"_" probe), and write the
#      artifact: .planning/phases/04-…/04-01-d14-trace.txt
#
# Fallback (NOT implemented unless needed, per plan): if /proc/N/syscall
# surprises (empty fragments), patch donor dosyscall with an unconditional
# print("%ld %s\n", scallnr, sysctab[scallnr]), rebuild via
# donor-ns-build.sh, boot, harvest the console log (RESEARCH D-14).
#
# usage (from the repo root, inside the nix devshell):
#   python3 build/aarch64/trace-syscalls.py
#
# Env overrides: HARVEY, HARVEY_VM, BOOT_BUDGET, SRV9_PORT.

import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

HARVEY = os.environ.get("HARVEY", os.getcwd())
VM = os.environ.get("HARVEY_VM", "harvey")
GUEST = "lima-%s" % VM
GUEST_DIR = "harvey-build"          # Harvey checkout in the guest (compile side)
GUEST_DONOR = "9front-donor"        # donor tree in the guest (staging side)
GUEST_DIST = "9front-dist"
DONOR = os.path.join(HARVEY, ".build", "9front-donor")
DONOR_SHA = "350266104f1fed81c78c3d05fa44f523bec0ae4d"
DIST = os.environ.get("DONOR_DIST_HOST", os.path.join(HARVEY, ".build", "9front-dist"))
ROOTFS = os.path.join(DIST, "srvroot")
SYSH = os.path.join(HARVEY, "sys", "src", "libc", "9syscall", "sys.h")
ARTIFACT = os.path.join(
    HARVEY, ".planning", "phases", "04-r9-userspace-exec-harvey-r9-abi", "04-01-d14-trace.txt")
TRACE_U = os.path.join(DIST, "9qemu-trace.u")
TRACE_K = os.path.join(DIST, "9qemu-trace")
RUNLOG = os.path.join(DIST, "trace-run.log")
BOOT_BUDGET = int(os.environ.get("BOOT_BUDGET", "600"))
SRV9_PORT = int(os.environ.get("SRV9_PORT", "1564"))
SRV9_GUEST_IP = "10.0.2.100"
SSH_CFG = os.path.expanduser("~/.lima/%s/ssh.config" % VM)

SHELL_MARKER = b"__GSD_SHELL_OK__"
SHELL_PROBE = b"echo __GSD_SHELL_^OK__\r"
PANIC_RE = re.compile(rb"panic|trap:", re.I)
BOOTARGS_RE = re.compile(rb"bootargs is \(tcp")
AUTH_RE = re.compile(rb"auth address is\?")
SHELL_RE = re.compile(rb"(?m)^__GSD_SHELL_OK__\r?$")
PROMPT_RE = re.compile(rb"(?m)^term% $")
PID_RE = re.compile(rb"__GSD_PID__(\d+)")
DONE_RE = re.compile(rb"(?m)^__GSD_TRACE_LOOP_DONE__\r?$")

# syscallfmt entry fragment: "<pid> <text> <name> <pc> <args…>" where the
# donor's %p prints the pc as BARE hex ("14918", no 0x prefix); return
# fragments begin " = " and never match this.
ENTRY_RE = re.compile(r"^(\d+) (\S+) (\S+) [0-9a-f]+\s")


def die(msg):
    sys.stderr.write("trace-syscalls: error: %s\n" % msg)
    sys.exit(1)


def sh(argv, **kw):
    sys.stderr.write("+ %s\n" % " ".join(str(a) for a in argv))
    return subprocess.run(argv, **kw)


def ssh_cmd(remote):
    return ["ssh", "-F", SSH_CFG, GUEST, remote]


def rsync(src, dst, *extra):
    return ["rsync", "-a", "-e", "ssh -F %s" % SSH_CFG, *extra, src, dst]


# ---- phase 0: preconditions (read-only) -------------------------------
def preconditions():
    if not os.path.isdir(os.path.join(HARVEY, "sys", "src")):
        die("%s does not look like the harvey checkout" % HARVEY)
    actual = subprocess.run(
        ["git", "-C", DONOR, "rev-parse", "HEAD"], capture_output=True, text=True
    ).stdout.strip()
    if actual != DONOR_SHA:
        die("donor pin mismatch: want %s, have %s" % (DONOR_SHA, actual))
    if not os.path.isdir(os.path.join(ROOTFS, "arm64", "bin")):
        die("%s incomplete — run sh build/aarch64/donor-vm-build.sh first" % ROOTFS)
    if shutil.which("limactl") is None:
        die("limactl not found — run inside the nix devshell")
    out = subprocess.run(["limactl", "list", "-q"], capture_output=True, text=True).stdout
    if VM not in out.split():
        die("lima VM '%s' does not exist" % VM)
    status = subprocess.run(
        ["limactl", "list", "--format", "{{.Status}}", VM], capture_output=True, text=True
    ).stdout.strip()
    if status != "Running":
        sh(["limactl", "start", VM], check=True)
    if shutil.which("qemu-system-aarch64") is None:
        die("qemu-system-aarch64 not found — run inside the nix devshell")
    for helper in ("srv9.py", "gdbpoke9.py", "nsrun.sh"):
        if not os.path.isfile(os.path.join(HARVEY, "build", "aarch64", helper)):
            die("%s missing (plan 02-04)" % helper)
    sys.stderr.write("== preconditions ok (donor pin, lima guest, qemu, helpers)\n")


# ---- phase 1: compile tracehello in the guest Harvey namespace --------
def compile_tracehello(tmpd):
    src = os.path.join(HARVEY, "build", "aarch64", "tracehello.c")
    sys.stderr.write("== pushing tracehello.c to the guest checkout\n")
    sh(rsync(src, "%s:%s/build/aarch64/tracehello.c" % (GUEST, GUEST_DIR)), check=True)
    # libc.a for aarch64 is a Phase-2 guest artifact; mk install is
    # incremental, so this is seconds when fresh and self-heals when stale.
    cmd = (
        'cd /sys/src/libc && objtype=aarch64 mk install && '
        'cd "$HARVEY/build/aarch64" && '
        '7c -FVw tracehello.c && 7l -o /aarch64/tracehello.7.out tracehello.7'
    )
    log = os.path.join(tmpd, "compile.log")
    with open(log, "wb") as fp:
        rc = subprocess.run(
            ssh_cmd(
                'cd "%s" && nix develop -c bash build/aarch64/nsrun.sh --wrap %s'
                % (GUEST_DIR, shq(cmd))
            ),
            stdout=fp,
            stderr=subprocess.STDOUT,
        ).returncode
    if rc != 0:
        die("guest compile failed (rc=%d); log: %s" % (rc, log))
    out_bin = os.path.join(tmpd, "tracehello.7.out")
    sh(rsync("%s:%s/aarch64/tracehello.7.out" % (GUEST, GUEST_DIR), out_bin), check=True)
    if not os.path.getsize(out_bin):
        die("tracehello.7.out missing/empty after compile")
    sys.stderr.write("== tracehello.7.out compiled by vendored 7c/7l\n")
    return out_bin


def shq(s):
    return "'" + s.replace("'", "'\\''") + "'"


# ---- phase 2: stage into the donor guest tree + rebake ----------------
GUEST_REBUILD = r"""#!/usr/bin/env bash
# trace-ns-rebuild.sh — guest side of trace-syscalls.py (self-re-entrant:
# wrap -> --ns -> --build, the run-gate.sh gate-ns-rebuild.sh shape).
# Lives in the guest's /tmp; never committed.
set -eu

DONOR="${DONOR:-$HOME/9front-donor}"
SCRATCH="${DONOR_HOSTBIN:-$HOME/9front-hostbin}"
DIST="${DONOR_DIST:-$HOME/9front-dist}"

if [ "${1:-}" = "--build" ]; then
	set -eu
	PATH="$SCRATCH:$HARVEY_LINUX_BIN:$PLAN9/bin:$PATH"
	export PATH
	objtype=arm64
	export objtype
	FORCERCFORMK=1
	export FORCERCFORMK

	cd /sys/src/9/arm64
	# force regeneration of everything derived from the CONF/bootdir:
	# mkdevc (qemu.c), mkrootall/mkrootc (the tracehello+trace.rc embed),
	# the link, and the uImage wrap.  All other objects are cached.
	rm -f qemu.c qemu.7 qemu.root.s qemu.root.7 qemu.rootc.c qemu.rootc.7 9qemu 9qemu.u
	mk 'CONF=qemu'

	[ -s 9qemu ] && [ -s 9qemu.u ] || { echo "error: relink produced no kernel" >&2; exit 1; }
	mkdir -p "$DIST"
	cp 9qemu "$DIST/9qemu-trace"
	cp 9qemu.u "$DIST/9qemu-trace.u"
	echo "== trace kernel assembled: $DIST/9qemu-trace{,.u}"
	exit 0
fi

if [ "${1:-}" = "--ns" ]; then
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

	if [ -L /lib ]; then LIBREAL=$(readlink -f /lib); else LIBREAL=/lib; fi
	NSLIB=/tmp/tracelib.$$
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

# wrap phase: repo user, devshell env
set -eu

# CONF patch (idempotent): add tracehello + trace.rc to the guest copy's
# CONF=qemu bootdir.  mkrootall strips only `file`-identified executables,
# so the text rc script is embedded byte-identical.  Bootdir rows are
# TAB-indented (an unindented line terminates the section — a bare append
# silently drops the entry from mkrootall's list).
CONF="$DONOR/sys/src/9/arm64/qemu"
add_line() {
	# $1 = source path, $2 = boot name
	if grep -qF "	$1	$2" "$CONF"; then
		echo "== CONF already carries $2 (idempotent rerun)"
	else
		echo "== adding $2 to the guest-copy CONF=qemu bootdir"
		awk -v path="$1" -v name="$2" '
			/^bootdir$/ { inbd=1; print; next }
			inbd && /^[^ \t]/ { print "\t" path "\t" name; inbd=0; print; next }
			{ print }
			END { if (inbd) print "\t" path "\t" name }
		' "$CONF" > "$CONF.trace"
		mv "$CONF.trace" "$CONF"
	fi
}
add_line '/$objtype/bin/tracehello' 'tracehello'
add_line '/arm64/bin/trace.rc' 'trace.rc'

[ -s "$DONOR/arm64/bin/tracehello" ] || {
	echo "error: staged tracehello missing at $DONOR/arm64/bin/tracehello" >&2
	exit 1
}
[ -s "$DONOR/arm64/bin/trace.rc" ] || {
	echo "error: staged trace.rc missing at $DONOR/arm64/bin/trace.rc" >&2
	exit 1
}
chmod 755 "$DONOR/arm64/bin/tracehello"

mkdir -p "$DIST"
export DONOR SCRATCH DIST
EXPORTS=/tmp/trace-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m bash "$0" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
"""

# The RESEARCH.md D-14 recipe verbatim, staged as /boot/trace.rc so the
# console only ever carries short single-line commands.
TRACE_RC = """# trace.rc — D-14 startsyscall loop over /proc/$1 (RESEARCH.md recipe).
# Plan 9 rc has no break builtin: the while CONDITION is the startsyscall
# write itself — when the target's EXITS lands, the write fails
# (process exited) and the loop ends.
pid = $1
echo stop > /proc/$pid/ctl || echo __GSD_TRACE_STOP_FAILED__
while (echo startsyscall > /proc/$pid/ctl)
	cat /proc/$pid/syscall
echo __GSD_TRACE_LOOP_DONE__
"""


def stage_and_rebake(tmpd, trace_bin):
    rc_path = os.path.join(tmpd, "trace.rc")
    with open(rc_path, "w") as fp:
        fp.write(TRACE_RC)
    guest_script = os.path.join(tmpd, "trace-ns-rebuild.sh")
    with open(guest_script, "w") as fp:
        fp.write(GUEST_REBUILD)

    sys.stderr.write("== staging tracehello + trace.rc into the guest donor tree\n")
    sh(rsync(trace_bin, "%s:%s/arm64/bin/tracehello" % (GUEST, GUEST_DONOR)), check=True)
    sh(rsync(rc_path, "%s:%s/arm64/bin/trace.rc" % (GUEST, GUEST_DONOR)), check=True)
    sh(rsync(guest_script, "%s:/tmp/gsd-trace-ns-rebuild.sh" % GUEST), check=True)

    log = os.path.join(DIST, "trace-rebuild.log")
    os.makedirs(DIST, exist_ok=True)
    sys.stderr.write("== targeted donor kernel rebake (log: %s)\n" % log)
    with open(log, "wb") as fp:
        rc = subprocess.run(
            ssh_cmd('cd "%s" && nix develop -c bash /tmp/gsd-trace-ns-rebuild.sh' % "harvey-build-donor"),
            stdout=fp,
            stderr=subprocess.STDOUT,
        ).returncode
    if rc != 0:
        die("guest rebake failed (rc=%d); log: %s" % (rc, log))
    sh(rsync("%s:%s/9qemu-trace" % (GUEST, GUEST_DIST), TRACE_K), check=True)
    sh(rsync("%s:%s/9qemu-trace.u" % (GUEST, GUEST_DIST), TRACE_U), check=True)
    if not os.path.getsize(TRACE_U):
        die("9qemu-trace.u missing/empty after pull")
    sys.stderr.write("== trace kernel: %s\n" % TRACE_U)


# ---- phase 3/4: boot + drive + trace ----------------------------------
class Log:
    def __init__(self, path):
        self.fp = open(path, "wb", buffering=0)
        self.buf = b""
        self.lock = threading.Lock()

    def write(self, data):
        with self.lock:
            self.fp.write(data)
            self.buf += data
            if len(self.buf) > 1024 * 1024:
                self.buf = self.buf[-512 * 1024:]

    def tail(self, n=4096):
        with self.lock:
            return self.buf[-n:]

    def search(self, rx):
        with self.lock:
            return rx.search(self.buf) is not None

    def search_from(self, rx, base):
        with self.lock:
            return rx.search(self.buf, base) is not None

    def match_from(self, rx, base):
        with self.lock:
            return rx.search(self.buf, base)

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
    f.readline()
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
    sys.stderr.write("trace-syscalls: %s\n" % msg)
    sys.stderr.write("trace-syscalls: last log lines:\n")
    sys.stderr.write(log.tail(2048).decode("utf-8", "replace") + "\n")
    return 1


def paced_send(s, cmd):
    for i in range(len(cmd)):
        s.sendall(cmd[i:i + 1])
        time.sleep(0.05)


def boot_and_trace(tmpd):
    qemu = shutil.which("qemu-system-aarch64")
    serial = os.path.join(tmpd, "serial.sock")
    qmp = os.path.join(tmpd, "qmp.sock")
    gdb = os.path.join(tmpd, "gdb.sock")

    # serve the root fs (9P2000, read-only) — same srvroot the proven
    # run-gate boot used; tracehello comes from devroot, not from here.
    srv9_log = open(os.path.join(tmpd, "srv9.log"), "wb")
    srv9 = subprocess.Popen(
        [sys.executable, os.path.join(HARVEY, "build", "aarch64", "srv9.py"),
         "serve", "--root", ROOTFS, "--host", "127.0.0.1", "--port", str(SRV9_PORT)],
        stdout=srv9_log, stderr=subprocess.STDOUT)
    for _ in range(60):
        if socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect_ex(
                ("127.0.0.1", SRV9_PORT)) == 0:
            break
        if srv9.poll() is not None:
            die("srv9 exited during startup")
        time.sleep(1)
    else:
        die("srv9 did not start listening on 127.0.0.1:%d" % SRV9_PORT)

    procs = []
    try:
        # dump the DTB with -append baked in, then pre-place it at
        # 0x40000000 via the generic loader (run-gate drift accommodation 1)
        append = "bootargs=tcp fs=%s user=glenda console=0" % SRV9_GUEST_IP
        dtb = os.path.join(tmpd, "virt.dtb")
        dumper = subprocess.Popen([qemu, "-M", "virt,gic-version=3,highmem-ecam=off",
                                   "-cpu", "cortex-a72", "-m", "1G", "-kernel", TRACE_U,
                                   "-append", append, "-machine", "dumpdtb=%s" % dtb,
                                   "-display", "none", "-S"],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2)
        dumper.kill()
        dumper.wait()
        if not os.path.isfile(dtb) or not os.path.getsize(dtb):
            die("qemu dumpdtb produced no DTB")

        qerr = open(os.path.join(tmpd, "qemu.err"), "wb")
        qp = subprocess.Popen(
            [qemu, "-M", "virt,gic-version=3,highmem-ecam=off", "-cpu", "cortex-a72",
             "-accel", "tcg", "-smp", "1", "-m", "1G", "-kernel", TRACE_U,
             "-append", append, "-device", "loader,file=%s,addr=0x40000000" % dtb,
             "-netdev", "user,id=n0,guestfwd=tcp:%s:564-tcp:127.0.0.1:%d"
             % (SRV9_GUEST_IP, SRV9_PORT),
             "-device", "virtio-net-pci-non-transitional,netdev=n0",
             "-chardev", "socket,id=ser0,path=%s,server=on,wait=off" % serial,
             "-serial", "chardev:ser0",
             "-qmp", "unix:%s,server=on,wait=off" % qmp,
             "-gdb", "unix:%s,server=on,wait=off" % gdb,
             "-S", "-display", "none"],
            stdout=qerr, stderr=subprocess.STDOUT)
        procs.append(qp)
        time.sleep(2)
        if qp.poll() is not None:
            die("qemu exited during launch (see %s)" % os.path.join(tmpd, "qemu.err"))

        # wake the GIC redistributor (run-gate drift accommodation 2)
        poke = subprocess.Popen(
            [sys.executable, os.path.join(HARVEY, "build", "aarch64", "gdbpoke9.py"),
             "--sock", gdb, "--watch-file", RUNLOG, "--watch-str", "bootargs is",
             "--deadline", str(BOOT_BUDGET)],
            stdout=open(os.path.join(tmpd, "gdbpoke.log"), "wb"),
            stderr=subprocess.STDOUT)
        procs.append(poke)

        # capture BEFORE the guest runs, then resume
        log = Log(RUNLOG)
        deadline = time.time() + BOOT_BUDGET
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
            fail(log, "serial socket never appeared")
            return 1
        threading.Thread(target=reader, args=(s, log), daemon=True).start()
        qmp_cont(qmp)
        sys.stderr.write("== capture attached, guest resumed (budget %ds)\n" % BOOT_BUDGET)

        # answer the bootargs prompt
        while time.time() < deadline:
            if PANIC_RE.search(log.tail(8192)):
                return fail(log, "kernel panic/trap during early boot")
            if log.search(BOOTARGS_RE):
                break
            time.sleep(1)
        else:
            return fail(log, "no bootargs prompt within budget")
        s.sendall(b"\r")

        # wait for the interactive shell (drive9.py probe discipline)
        answered_auth = False
        nextprobe = time.time() + 10
        while time.time() < deadline:
            if PANIC_RE.search(log.tail(8192)):
                return fail(log, "kernel panic/trap during boot")
            if not answered_auth and log.search(AUTH_RE):
                s.sendall(b"\r")
                answered_auth = True
                continue
            if log.search(SHELL_RE):
                break
            if time.time() >= nextprobe:
                s.sendall(SHELL_PROBE)
                nextprobe = time.time() + 5
            time.sleep(1)
        else:
            return fail(log, "no interactive rc shell within budget")
        sys.stderr.write("== rc shell reached\n")

        # prompt signature + idle proof (same ordering discipline as
        # gatedrive9.py: the shell must provably evaluate before the
        # trace commands go out, paced at human-typing speed)
        base = log.length()
        s.sendall(b"prompt='term% '\r")
        time.sleep(1)
        paced_send(s, b"echo __GSD_SHELL_^OK__\r")
        pdeadline = time.time() + 60
        while time.time() < pdeadline:
            if PANIC_RE.search(log.tail(8192)):
                return fail(log, "kernel fault at the shell")
            if log.search_from(PROMPT_RE, base):
                break
            time.sleep(0.5)
        else:
            return fail(log, "shell did not emit the term% prompt")
        sys.stderr.write("== shell live and idle; starting the trace\n")

        # launch the trace target backgrounded and capture its pid.
        # The target's leading pure-compute spin makes no syscalls, so
        # nothing can fire before the tracer arms.
        base = log.length()
        paced_send(s, b"/boot/tracehello &; echo __GSD_PID__$apid\r")
        m = None
        pdeadline = time.time() + 60
        while time.time() < pdeadline:
            if PANIC_RE.search(log.tail(8192)):
                return fail(log, "kernel fault at trace launch")
            m = log.match_from(PID_RE, base)
            if m:
                break
            time.sleep(0.5)
        if not m:
            return fail(log, "no pid probe output")
        pid = int(m.group(1))
        sys.stderr.write("== tracehello launched: pid %d\n" % pid)

        # run the trace loop (RESEARCH recipe, staged as /boot/trace.rc)
        base = log.length()
        paced_send(s, b"rc /boot/trace.rc %d\r" % pid)
        tdeadline = time.time() + 360
        while time.time() < tdeadline:
            if PANIC_RE.search(log.tail(8192)):
                return fail(log, "kernel fault during trace")
            if log.search_from(DONE_RE, base):
                break
            time.sleep(1)
        else:
            return fail(log, "trace loop never completed (Eprocdied break not seen)")
        sys.stderr.write("== trace loop complete\n")

        with open(RUNLOG, "rb") as fp:
            return fp.read()
    finally:
        for p in procs:
            try:
                p.kill()
            except OSError:
                pass
        srv9.kill()


# ---- phase 5: parse + artifact ----------------------------------------
def load_sysh():
    defines = {}
    with open(SYSH) as fp:
        for line in fp.readlines():
            m = re.match(r"^#define\s+([A-Z0-9_]+)\s+(\d+)\s*$", line)
            if m:
                defines[m.group(1).lower()] = int(m.group(2))
    return defines


def resolve(defines, name):
    # donor sysctab lowercases the sys.h names and strips the trailing
    # underscore (mksystab's `x/_"/c/"`), so "brk" here is Harvey's BRK_.
    for cand in (name, name + "_", "_" + name):
        if cand in defines:
            return defines[cand], cand
    return None, None


def parse_and_write(capture):
    # fragments live between the trace.rc command echo and the done marker
    start = capture.find(b"rc /boot/trace.rc")
    end = capture.rfind(b"__GSD_TRACE_LOOP_DONE__")
    if start < 0 or end < 0 or end <= start:
        die("trace region not bracketed in the serial log (see %s)" % RUNLOG)
    region = capture[start:end].decode("utf-8", "replace")

    defines = load_sysh()
    ordered = []  # (number, sys.h name) in first-use order
    seen = set()
    for line in region.splitlines():
        line = line.strip()
        m = ENTRY_RE.match(line)
        if not m:
            continue
        name = m.group(3)
        if name == "huh?":
            die("donor emitted 'huh?' — an unknown syscall number was traced")
        number, sysh_name = resolve(defines, name.lower())
        if number is None:
            die("unknown syscall name: %s (no matching #define in %s)" % (name, SYSH))
        if sysh_name not in seen:
            seen.add(sysh_name)
            ordered.append((number, sysh_name))

    if not ordered:
        die("no entry fragments parsed — /proc/N/syscall surprised; "
            "the D-14 fallback (dosyscall print patch) is required")
    names = {n for _, n in ordered}
    for required in ("pwrite", "exits"):
        if required not in names:
            die("measured set lacks %s — the trace did not cover the hello path" % required)

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(ARTIFACT, "w") as fp:
        fp.write("# date: %s\n" % now)
        fp.write("# donor pin: %s (9front branch front)\n" % DONOR_SHA)
        fp.write("# target: /boot/tracehello (build/aarch64/tracehello.c, vendored 7c/7l in the lima guest namespace)\n")
        fp.write("# method: startsyscall+/proc/N/syscall (primary; RESEARCH.md D-14)\n")
        fp.write("# serial log: %s (gitignored .build evidence)\n" % RUNLOG)
        for number, name in ordered:
            fp.write("%d %s\n" % (number, name))
    sys.stderr.write("== artifact written: %s (%d syscalls)\n" % (ARTIFACT, len(ordered)))
    for number, name in ordered:
        sys.stderr.write("   %d %s\n" % (number, name))


def main():
    preconditions()
    tmpd = tempfile.mkdtemp(prefix="trace-syscalls.")
    try:
        trace_bin = compile_tracehello(tmpd)
        stage_and_rebake(tmpd, trace_bin)
        capture = boot_and_trace(tmpd)
        if isinstance(capture, int):
            return capture
        parse_and_write(capture)
    finally:
        shutil.rmtree(tmpd, ignore_errors=True)
    sys.stderr.write("== PASS: D-14 trace complete\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
