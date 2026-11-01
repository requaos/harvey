#!/bin/sh
# build/aarch64/subset-exec.sh — the D-08 execution gate (plan 02-07
# Task 2; TC-05's acceptance evidence): the sixteen Harvey aarch64
# subset binaries (rc, grep, ip/ipconfig, auth/factotum, and the core
# single-file commands cat cp date echo ls mkdir mv ps rm sed test wc —
# all compiled by Harvey's vendored 7c and linked by 7l, plan 02-07
# Task 1) EXECUTE on the 9front donor kernel under qemu -M virt TCG.
#
# Generalizes run-gate.sh (plan 02-05): stage the subset into the
# guest's disposable donor tree at arm64/bin/subset/, extend the
# guest-copy CONF=qemu bootdir (guest-scratch staging — never
# committed), targeted mkrootall rebake embeds the binaries into the
# kernel's devroot as /boot/h* (mkpaqfs is NOT re-run — the bootfs.paq
# is unmounted before the shell; devroot survives), boot the rebaked
# kernel with exactly boot-9qemu.sh's qemu invocation, and exercise
# every binary at the rc prompt with per-command markers.
#
# The srv9 root mount is served with --writable-prefix /tmp
# --writable-prefix /usr/glenda/tmp for this gate (and only this
# gate): lib/namespace binds /usr/glenda/tmp onto /tmp with MCREATE,
# giving the guest a writable hierarchical scratch for the
# mkdir/cp/mv/rm round-trip. The proven read-only harnesses never pass
# the flag.
#
# MARKER TABLE (each asserted against the serial capture; the guest
# rc is the donor's own shell — it EXECUTES our binaries by path):
#
#  #  command (sent paced, echo-verified)              required output
#  -- ----------------------------------------------   ------------------------------
#  1  /boot/hecho __SUBSET_SENTINEL__                   ^__SUBSET_SENTINEL__$
#  2  /boot/hls /                                      ^/boot$ line (root non-empty)
#  3  /boot/hcat /boot/sentinel.txt                    ^alpha bravo charlie$
#  4  hcat sentinel.txt | /boot/hgrep __SUBSET_GREP_LINE__
#                                                      ^__SUBSET_GREP_LINE__$
#  5  hecho sentinel | /boot/hsed s/SENTINEL/VERIFIED/ ^__SUBSET_VERIFIED__$
#  6  hcat sentinel.txt | /boot/hwc -l                 ^ *2$ (wc count)
#  7  /boot/hdate                                      ... UTC|GMT yyyy (parseable)
#  8  /boot/htest -f /boot/hcat && hecho __TEST_F_OK__ __TEST_F_OK__
#  9  X=`{/boot/hecho hello} && hecho __RC_EVAL__$X   __RC_EVAL__hello
#                                                      (rc evaluating — rc itself
#                                                      runs the whole script)
# 10  /boot/hps                                        process list incl. rc
# 11  /boot/hmkdir /tmp/subset && hecho __MKDIR_OK__   __MKDIR_OK__
# 12  /boot/hcp sentinel.txt /tmp/subset/copied && ... __CP_OK__
# 13  /boot/hmv copied moved && hecho __MV_OK__        __MV_OK__
# 14  /boot/hls /tmp/subset                            ^/tmp/subset/moved$
# 15  /boot/hrm /tmp/subset/moved && hecho __RM_OK__   __RM_OK__
# 16  /boot/hls /tmp/subset | /boot/hwc -l             ^ *0$ (round-trip empty)
# 17  /boot/hrm /tmp/subset && hecho __RMDIR_OK__      __RMDIR_OK__
# 18  /boot/hipconfig -Z                               usage: ...ipconfig
#                                                      (usage-level; network-less
#                                                      guest per the plan)
# 19  /boot/hfactotum -n -s subexec & + hecho marker   __FACTOTUM_SPAWNED__
# 20  /boot/hps                                        hfactotum resident
# 21  /boot/hecho SUBSET-OK                            ^SUBSET-OK$ — sent ONLY
#                                                      after every assertion
#                                                      above passed
#
# Invariant: zero panic/trap/sys: note lines in the capture (asserted
# host-side; the plan's fails_when). BOOT_BUDGET discipline per
# boot-9qemu.sh (TCG is slow; raise the budget, never retry silently).
# Bake-vs-ufs per the README: bake for gates. Idempotence: the guest
# CONF patch is marker-guarded, the staging rsync is exact, and the
# /tmp scratch round-trip removes what it creates — consecutive runs
# pass consecutively.
#
# Usage (from the repo root, inside the nix devshell):
#   sh build/aarch64/subset-exec.sh
#
# Env overrides: HARVEY, HARVEY_VM, QEMU_BIN, PYTHON, BOOT_BUDGET,
#   SRV9_PORT, DONOR_DIST_HOST (same meaning as run-gate.sh).
#
# On failure the script halts non-zero and the guest serial log
# (.build/9front-dist/subset-exec.log) is the bisect surface — per the
# toolchain-first diagnostic rule, suspect our 7c/7l/libc/subset
# binaries before the donor kernel.

set -eu

HARVEY="${HARVEY:-$PWD}"
VM="${HARVEY_VM:-harvey}"
GUEST_DIR="${HARVEY_GUEST_DIR:-harvey-build-donor}"
GUEST_DONOR="${DONOR_GUEST_DIR:-9front-donor}"
GUEST_DIST=9front-dist
DONOR="$HARVEY/.build/9front-donor"
DONOR_SHA=350266104f1fed81c78c3d05fa44f523bec0ae4d
DIST="${DONOR_DIST_HOST:-$HARVEY/.build/9front-dist}"
ROOTFS="${ROOTFS:-$DIST/srvroot}"
RUNLOG="${QEMU_LOG:-$DIST/subset-exec.log}"
BUILDLOG="$DIST/subset-rebake.log"
GATE_U="$DIST/9qemu-subset.u"
GATE_K="$DIST/9qemu-subset"
BOOT_BUDGET="${BOOT_BUDGET:-1500}"
SRV9_PORT="${SRV9_PORT:-1564}"
SRV9_GUEST_IP="${SRV9_GUEST_IP:-10.0.2.100}"

# the sixteen subset binaries: guest-staging name → /boot name
SUBSET_FLAT="cat cp date echo ls mkdir mv ps rm sed test wc rc grep"
SUBSET_NAMED="ip/ipconfig auth/factotum"

err() { echo "error: $*" >&2; exit 1; }

# ---- preconditions (read-only) ------------------------------------
[ -d "$HARVEY/sys/src" ] || err "$HARVEY does not look like the harvey checkout (missing sys/src)"
actual=$(git -C "$DONOR" rev-parse HEAD 2>/dev/null || echo missing)
[ "$actual" = "$DONOR_SHA" ] || err "donor pin mismatch: want $DONOR_SHA, have $actual"
[ -s "$DIST/9qemu.u" ] || err "$DIST/9qemu.u missing — run sh build/aarch64/donor-vm-build.sh first"
[ -d "$ROOTFS/arm64/bin" ] || err "$ROOTFS incomplete — run sh build/aarch64/donor-vm-build.sh first"
for f in $SUBSET_FLAT; do
	[ -x "$HARVEY/aarch64/bin/$f" ] || err "aarch64/bin/$f missing — run sh build/aarch64/subset-build.sh first"
done
for f in $SUBSET_NAMED; do
	[ -x "$HARVEY/aarch64/bin/$f" ] || err "aarch64/bin/$f missing — run sh build/aarch64/subset-build.sh first"
done
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

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
	PYTHON=$(command -v python3 || true)
fi
[ -n "$PYTHON" ] || err "python3 not found — needed for srv9.py/subsetdrive9.py (set PYTHON)"

[ -f "$HARVEY/build/aarch64/srv9.py" ] || err "srv9.py missing (plan 02-04)"
[ -f "$HARVEY/build/aarch64/gdbpoke9.py" ] || err "gdbpoke9.py missing (plan 02-04)"

SSH_CFG="$HOME/.lima/$VM/ssh.config"
GUEST="lima-$VM"
RSYNC_RSH="ssh -F $SSH_CFG"

# ensure the writable scratch targets exist in the served root (the
# /tmp bind target must exist for lib/namespace's bind -c to succeed)
mkdir -p "$ROOTFS/tmp" "$ROOTFS/usr/glenda/tmp"
# start each run from a clean scratch (idempotence evidence)
rm -rf "$ROOTFS/tmp/subset" "$ROOTFS/usr/glenda/tmp/subset"

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/subset-exec.XXXXXX")
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

# the known-content file baked into the guest as /boot/sentinel.txt
# (deterministic wc counts: 2 lines, 4 words, 40 bytes)
printf 'alpha bravo charlie\n__SUBSET_GREP_LINE__\n' > "$TMPD/sentinel.txt"

# ---- 1. stage the subset into the guest donor tree -----------------
echo "== staging the 16 subset binaries + sentinel.txt into the guest donor tree ($GUEST_DONOR/arm64/bin/subset/)"
ssh -F "$SSH_CFG" "$GUEST" "mkdir -p $GUEST_DONOR/arm64/bin/subset"
for f in $SUBSET_FLAT; do
	rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/$f" "$GUEST:$GUEST_DONOR/arm64/bin/subset/h$f"
done
rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/ip/ipconfig" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hipconfig"
rsync -a -e "$RSYNC_RSH" "$HARVEY/aarch64/bin/auth/factotum" "$GUEST:$GUEST_DONOR/arm64/bin/subset/hfactotum"
rsync -a -e "$RSYNC_RSH" "$TMPD/sentinel.txt" "$GUEST:$GUEST_DONOR/arm64/bin/subset/sentinel.txt"

# ---- 2. guest CONF bootdir patch (idempotent) + rebake -------------
cat > "$TMPD/subset-bootdir.txt" <<'EOF'
	/$objtype/bin/subset/hrc	hrc
	/$objtype/bin/subset/hgrep	hgrep
	/$objtype/bin/subset/hcat	hcat
	/$objtype/bin/subset/hcp	hcp
	/$objtype/bin/subset/hdate	hdate
	/$objtype/bin/subset/hecho	hecho
	/$objtype/bin/subset/hls	hls
	/$objtype/bin/subset/hmkdir	hmkdir
	/$objtype/bin/subset/hmv	hmv
	/$objtype/bin/subset/hps	hps
	/$objtype/bin/subset/hrm	hrm
	/$objtype/bin/subset/hsed	hsed
	/$objtype/bin/subset/htest	htest
	/$objtype/bin/subset/hwc	hwc
	/$objtype/bin/subset/hipconfig	hipconfig
	/$objtype/bin/subset/hfactotum	hfactotum
	/$objtype/bin/subset/sentinel.txt	sentinel.txt
EOF
rsync -a -e "$RSYNC_RSH" "$TMPD/subset-bootdir.txt" "$GUEST:/tmp/gsd-subset-bootdir.txt"

cat > "$TMPD/subset-ns-rebake.sh" <<'GUEST_EOF'
#!/usr/bin/env bash
# subset-ns-rebake.sh — guest side of subset-exec.sh (self-re-entrant:
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

	echo "== subset rebake provenance (donor kernel relinked by Harvey's tools):"
	echo "   7c: $(command -v 7c)"
	echo "   7a: $(command -v 7a)"
	echo "   7l: $(command -v 7l)"
	echo "   ar: $(command -v ar)"
	echo "   mk: $(command -v mk)"

	cd /sys/src/9/arm64
	# force regeneration of everything derived from the CONF/bootdir:
	# mkdevc (qemu.c), mkrootall/mkrootc (root.s/rootc.c — the subset
	# embed), the link, and the uImage wrap. All other objects are
	# cached from the 02-04 build.
	rm -f qemu.c qemu.7 qemu.root.s qemu.root.7 qemu.rootc.c qemu.rootc.7 9qemu 9qemu.u
	mk 'CONF=qemu'

	[ -s 9qemu ] && [ -s 9qemu.u ] || { echo "error: relink produced no kernel" >&2; exit 1; }
	mkdir -p "$DIST"
	cp 9qemu "$DIST/9qemu-subset"
	cp 9qemu.u "$DIST/9qemu-subset.u"
	echo "== subset kernel assembled: $DIST/9qemu-subset{,.u}"
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
	NSLIB=/tmp/subsetlib.$$
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

CONF="$DONOR/sys/src/9/arm64/qemu"
if grep -qF '/$objtype/bin/subset/hrc' "$CONF"; then
	echo "== CONF already carries the subset bootdir block (idempotent rerun)"
else
	echo "== adding the subset bootdir block to the guest-copy CONF=qemu"
	awk '
		/^bootdir$/ { inbd=1; print; next }
		inbd && /^[^ \t]/ {
			while ((getline l < "/tmp/gsd-subset-bootdir.txt") > 0) print l
			inbd=0; print; next
		}
		{ print }
		END {
			if (inbd)
				while ((getline l < "/tmp/gsd-subset-bootdir.txt") > 0) print l
		}
	' "$CONF" > "$CONF.subset"
	mv "$CONF.subset" "$CONF"
fi
echo "== guest CONF bootdir now:"
sed -n '/^bootdir/,$p' "$CONF"

# assert the staged binaries (17 files: 16 h* + sentinel.txt)
for f in hrc hgrep hcat hcp hdate hecho hls hmkdir hmv hps hrm hsed htest hwc hipconfig hfactotum sentinel.txt; do
	[ -s "$DONOR/arm64/bin/subset/$f" ] || {
		echo "error: staged subset file missing: $DONOR/arm64/bin/subset/$f" >&2
		exit 1
	}
done

mkdir -p "$DIST"
export DONOR SCRATCH DIST
EXPORTS=/tmp/subset-exports.$$
export > "$EXPORTS"
set +e
sudo unshare -m bash "$0" --ns "$USER" "$EXPORTS"
RC=$?
rm -f "$EXPORTS"
exit $RC
GUEST_EOF

rsync -a -e "$RSYNC_RSH" "$TMPD/subset-ns-rebake.sh" "$GUEST:/tmp/gsd-subset-ns-rebake.sh"

echo "== targeted donor kernel rebake in the guest namespace (log: $BUILDLOG)"
mkdir -p "$DIST"
set +e
ssh -F "$SSH_CFG" "$GUEST" "cd \"$GUEST_DIR\" && nix develop -c bash /tmp/gsd-subset-ns-rebake.sh" > "$BUILDLOG" 2>&1
RC=$?
set -e
cat "$BUILDLOG"
if [ $RC -ne 0 ]; then
	echo "error: guest rebake failed (rc=$RC); log: $BUILDLOG" >&2
	exit $RC
fi

echo "== pulling the subset gate kernel back to $DIST"
rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIST/9qemu-subset" "$GATE_K"
rsync -a -e "$RSYNC_RSH" "$GUEST:$GUEST_DIST/9qemu-subset.u" "$GATE_U"
[ -s "$GATE_U" ] || err "$GATE_U missing/empty after rsync"

# ---- 3. boot + exercise (boot-9qemu.sh discipline, duplicated) -----
cat > "$TMPD/subsetdrive9.py" <<'PY_EOF'
#!/usr/bin/env python3
# subsetdrive9.py — generated by subset-exec.sh (never committed).
# Fork of run-gate.sh's gatedrive9.py (itself a fork of drive9.py,
# plan 02-04): same capture-before-start, QMP resume, prompt discipline,
# paced echo-verified sends — then a per-command exercise table over
# the /boot/h* subset, ending with SUBSET-OK sent only after every
# assertion passed. Panic/trap fast-fail is active throughout.
import re
import socket
import sys
import threading
import time

SHELL_MARKER = "__GSD_SHELL_OK__"
PANIC_RE = re.compile(rb"panic|trap:", re.I)
BOOTARGS_RE = re.compile(rb"bootargs is \(tcp")
AUTH_RE = re.compile(rb"auth address is\?")
SHELL_RE = re.compile(rb"(?m)^__GSD_SHELL_OK__\r?$")
PROMPT_RE = re.compile(rb"term% ")

# the exercise table: (command, output regex, timeout, description)
# Every command runs our Harvey-built binaries from /boot/h*; the shell
# evaluating them is the donor's rc (rc evaluation itself is proven by
# step 9's command substitution).
STEPS = [
    (b"/boot/hecho __SUBSET_SENTINEL__\r",
     rb"(?m)^__SUBSET_SENTINEL__\r?$", 60, "echo sentinel"),
    (b"/boot/hls /\r",
     rb"(?m)^/boot\r?$", 60, "ls / non-empty"),
    (b"/boot/hcat /boot/sentinel.txt\r",
     rb"(?m)^alpha bravo charlie\r?$", 60, "cat known file"),
    (b"/boot/hcat /boot/sentinel.txt | /boot/hgrep __SUBSET_GREP_LINE__\r",
     rb"(?m)^__SUBSET_GREP_LINE__\r?$", 60, "grep pipeline"),
    (b"/boot/hecho __SUBSET_SENTINEL__ | /boot/hsed s/SENTINEL/VERIFIED/\r",
     rb"(?m)^__SUBSET_VERIFIED__\r?$", 60, "sed pipeline"),
    (b"/boot/hcat /boot/sentinel.txt | /boot/hwc -l\r",
     rb"(?m)^ *2\r?$", 60, "wc -l expected count"),
    (b"/boot/hdate\r",
     rb"(?m)(UTC|GMT) 20[0-9][0-9]\r?$", 60, "date parseable line"),
    (b"/boot/htest -f /boot/hcat && /boot/hecho __TEST_F_OK__\r",
     rb"(?m)^__TEST_F_OK__\r?$", 60, "test -f true-branch"),
    (b"X=`{/boot/hecho hello} && /boot/hecho __RC_EVAL__$X\r",
     rb"(?m)^__RC_EVAL__hello\r?$", 60, "rc evaluates (command substitution)"),
    (b"/boot/hps\r",
     rb"(?m)\src\r?$", 60, "ps process list (shell resident)"),
    (b"/boot/hmkdir /tmp/subset && /boot/hecho __MKDIR_OK__\r",
     rb"(?m)^__MKDIR_OK__\r?$", 60, "mkdir in /tmp"),
    (b"/boot/hcp /boot/sentinel.txt /tmp/subset/copied && /boot/hecho __CP_OK__\r",
     rb"(?m)^__CP_OK__\r?$", 60, "cp into /tmp/subset"),
    (b"/boot/hmv /tmp/subset/copied /tmp/subset/moved && /boot/hecho __MV_OK__\r",
     rb"(?m)^__MV_OK__\r?$", 60, "mv rename"),
    (b"/boot/hls /tmp/subset\r",
     rb"(?m)^/tmp/subset/moved\r?$", 60, "ls verifies mv"),
    (b"/boot/hrm /tmp/subset/moved && /boot/hecho __RM_OK__\r",
     rb"(?m)^__RM_OK__\r?$", 60, "rm file"),
    (b"/boot/hls /tmp/subset | /boot/hwc -l\r",
     rb"(?m)^ *0\r?$", 60, "ls|wc round-trip empty"),
    (b"/boot/hrm /tmp/subset && /boot/hecho __RMDIR_OK__\r",
     rb"(?m)^__RMDIR_OK__\r?$", 60, "rm empty dir"),
    (b"/boot/hipconfig -Z\r",
     rb"usage: .*hipconfig", 60, "ipconfig usage-level (network-less guest)"),
    (b"/boot/hfactotum -n -s subexec &\r",
     rb"(?m)^term% ", 60, "factotum backgrounded start"),
    (b"/boot/hecho __FACTOTUM_SPAWNED__\r",
     rb"(?m)^__FACTOTUM_SPAWNED__\r?$", 60, "shell survived factotum start"),
    (b"/boot/hps\r",
     rb"(?m)\bhfactotum\b", 60, "factotum resident in ps"),
]

FINAL = (b"/boot/hecho SUBSET-OK\r",
         rb"(?m)^SUBSET-OK\r?$", 60, "SUBSET-OK sentinel")


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
    sys.stderr.write("subsetdrive9: %s\n" % msg)
    sys.stderr.write("subsetdrive9: last log lines:\n")
    tail = log.tail(2048).decode("utf-8", "replace")
    sys.stderr.write(tail + "\n")
    return 1


def main(argv):
    serial = qmp = logpath = None
    budget = 1500
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
            sys.stderr.write("subsetdrive9: unknown arg %s\n" % a)
            return 2
    if not serial or not qmp or not logpath:
        sys.stderr.write("subsetdrive9: --serial, --qmp and --log are required\n")
        return 2

    deadline = time.time() + budget
    log = Log(logpath)

    # 1. attach the capture BEFORE the guest runs
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
    sys.stderr.write("subsetdrive9: capture attached, guest resumed (budget %ds)\n" % budget)

    # 3. answer the bootargs prompt
    while time.time() < deadline:
        if PANIC_RE.search(log.tail(8192)):
            return fail(log, "kernel fault during early boot")
        if log.search(BOOTARGS_RE):
            break
        time.sleep(1)
    else:
        return fail(log, "no bootargs prompt within budget")
    sys.stderr.write("subsetdrive9: bootargs prompt seen; answering default (tcp)\n")
    s.sendall(b"\r")

    # 4. wait for the interactive shell via echo probes; answer the
    #    confignet auth prompt if it appears
    answered_auth = False
    nextprobe = time.time() + 10
    while time.time() < deadline:
        if PANIC_RE.search(log.tail(8192)):
            return fail(log, "kernel fault during boot")
        if not answered_auth and log.search(AUTH_RE):
            sys.stderr.write("subsetdrive9: auth-address prompt seen; answering default\n")
            s.sendall(b"\r")
            answered_auth = True
            continue
        if log.search(SHELL_RE):
            break
        if time.time() >= nextprobe:
            try:
                s.sendall(b"echo " + SHELL_MARKER.encode() + b"\r")
            except OSError:
                return fail(log, "serial socket closed during boot")
            nextprobe = time.time() + 5
        time.sleep(1)
    else:
        return fail(log, "no interactive rc shell within %ds budget" % budget)
    sys.stderr.write("subsetdrive9: rc shell reached (marker executed)\n")

    # 5. set the documented prompt signature and prove it was evaluated
    #    (gatedrive9.py's race note: wait for the probe's OUTPUT line —
    #    rc provably idle — before sending anything else, then pace
    #    every later send at human-typing speed with echo verification)
    s.sendall(b"prompt='term% '\r")
    time.sleep(1)
    s.sendall(b"echo __GSD_PROMPT_SET__\r")
    pdeadline = time.time() + 60
    while time.time() < pdeadline:
        if PANIC_RE.search(log.tail(8192)):
            return fail(log, "kernel fault at the shell")
        if log.search(PROMPT_RE):
            break
        time.sleep(0.5)
    else:
        return fail(log, "shell did not emit the term% prompt after assignment")
    edeadline = time.time() + 60
    while time.time() < edeadline:
        if PANIC_RE.search(log.tail(8192)):
            return fail(log, "kernel fault at the shell")
        if log.search(re.compile(rb"(?m)^__GSD_PROMPT_SET__\r?$")):
            break
        time.sleep(0.5)
    else:
        return fail(log, "shell did not execute the prompt probe")
    sys.stderr.write("subsetdrive9: rc printed the term%% prompt — shell is live and idle\n")

    def paced_send(cmd):
        for i in range(len(cmd)):
            s.sendall(cmd[i:i + 1])
            time.sleep(0.05)

    def send_verified(cmd, echo_re, out_re, out_timeout, base, what):
        # Delivery is verified against the console ECHO; a clean echo
        # without the expected output is a GENUINE failure -> no retry.
        for _attempt in range(3):
            paced_send(cmd)
            edl = time.time() + 30
            got_echo = False
            while time.time() < edl:
                if PANIC_RE.search(log.tail(8192)):
                    fail(log, "kernel fault while sending %s" % what)
                    return False
                if log.search_from(echo_re, base):
                    got_echo = True
                    break
                time.sleep(0.5)
            if not got_echo:
                continue
            odl = time.time() + out_timeout
            while time.time() < odl:
                if PANIC_RE.search(log.tail(8192)):
                    fail(log, "kernel fault after %s" % what)
                    return False
                if log.search_from(out_re, base):
                    return True
                time.sleep(0.5)
            fail(log, "%s delivered but produced no expected output" % what)
            return False
        fail(log, "%s could not be delivered intact after 3 attempts" % what)
        return False

    # 6. THE GATE: the exercise table over /boot/h*
    for idx, (cmd, out_re, timeout, what) in enumerate(STEPS, 1):
        if time.time() > deadline:
            return fail(log, "budget exhausted mid-exercise (step %d %s)" % (idx, what))
        base = log.length()
        echo_re = re.compile(re.escape(cmd[:16]))
        if not send_verified(cmd, echo_re, re.compile(out_re), timeout, base,
                             "step %d (%s)" % (idx, what)):
            return 1
        sys.stderr.write("subsetdrive9: step %d/%d OK (%s)\n" % (idx, len(STEPS), what))

    # 7. every assertion passed — only now send the closing sentinel
    base = log.length()
    cmd, out_re, timeout, what = FINAL
    echo_re = re.compile(re.escape(cmd[:16]))
    if not send_verified(cmd, echo_re, re.compile(out_re), timeout, base, what):
        return 1
    sys.stderr.write("subsetdrive9: SUBSET-OK — the full subset executed on the donor kernel\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv) or 0)
PY_EOF

# serve the root fs (9P2000) with the writable /tmp scratch unlocked
# for THIS gate only (see header)
echo "== serving $ROOTFS on 127.0.0.1:$SRV9_PORT (9P2000; writable prefixes /tmp, /usr/glenda/tmp)"
"$PYTHON" "$HARVEY/build/aarch64/srv9.py" serve --root "$ROOTFS" --host 127.0.0.1 --port "$SRV9_PORT" \
	--writable-prefix /tmp --writable-prefix /usr/glenda/tmp \
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

# wake the GIC redistributor (boot-9qemu.sh drift accommodation 2)
if [ "${WAKE_POKE:-1}" != "0" ]; then
	"$PYTHON" "$HARVEY/build/aarch64/gdbpoke9.py" --sock "$TMPD/gdb.sock" \
		--watch-file "$RUNLOG" --watch-str "bootargs is" \
		> "$TMPD/gdbpoke.log" 2>&1 &
	POKE_PID=$!
else
	POKE_PID=""
fi

# attach the capture BEFORE the guest runs, resume via QMP, drive the
# boot to the shell, then run the exercise table and assert every marker
echo "== driving boot to rc shell + exercising the subset (budget ${BOOT_BUDGET}s; log: $RUNLOG)"
set +e
"$PYTHON" "$TMPD/subsetdrive9.py" --serial "$TMPD/serial.sock" --qmp "$TMPD/qmp.sock" \
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
	echo "error: subset gate run failed within ${BOOT_BUDGET}s — last log lines:" >&2
	tail -n 40 "$RUNLOG" >&2 || true
	echo "hint: the guest log is the bisect surface (toolchain-first diagnostic rule):" >&2
	echo "      suspect our 7c/7l/libc/subset binaries before the donor kernel" >&2
	exit 1
fi

# ---- 4. assertions (defense in depth; the driver already proved it)
grep -qiE '9front|Plan 9' "$RUNLOG" || err "captured log lacks the 9front/Plan 9 banner"
grep -q 'term% ' "$RUNLOG" || err "captured log lacks the rc prompt signature"
grep -q '__SUBSET_SENTINEL__' "$RUNLOG" || err "captured log lacks the echo sentinel"
grep -q '__SUBSET_GREP_LINE__' "$RUNLOG" || err "captured log lacks the grep marker"
grep -q '__SUBSET_VERIFIED__' "$RUNLOG" || err "captured log lacks the sed marker"
grep -q '__TEST_F_OK__' "$RUNLOG" || err "captured log lacks the test marker"
grep -q '__RC_EVAL__hello' "$RUNLOG" || err "captured log lacks the rc-eval marker"
grep -q '__MKDIR_OK__' "$RUNLOG" || err "captured log lacks the mkdir marker"
grep -q '__CP_OK__' "$RUNLOG" || err "captured log lacks the cp marker"
grep -q '__MV_OK__' "$RUNLOG" || err "captured log lacks the mv marker"
grep -q '__RM_OK__' "$RUNLOG" || err "captured log lacks the rm marker"
grep -q '__RMDIR_OK__' "$RUNLOG" || err "captured log lacks the rmdir marker"
grep -q 'usage: .*hipconfig' "$RUNLOG" || err "captured log lacks the ipconfig usage line"
grep -q '__FACTOTUM_SPAWNED__' "$RUNLOG" || err "captured log lacks the factotum spawn marker"
grep -q 'hfactotum' "$RUNLOG" || err "captured log lacks the factotum-resident ps line"
grep -q 'SUBSET-OK' "$RUNLOG" || err "captured log lacks SUBSET-OK"
if grep -qiE 'panic|trap:' "$RUNLOG"; then
	err "captured log contains a kernel fault line"
fi

echo "== PASS: the aarch64 shell subset executed on the 9front donor kernel (SUBSET-OK); log: $RUNLOG"
