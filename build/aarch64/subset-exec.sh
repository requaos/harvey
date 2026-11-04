#!/bin/sh
# build/aarch64/subset-exec.sh — the execution gate: the sixteen Harvey
# aarch64
# subset binaries (rc, grep, ip/ipconfig, auth/factotum, and the core
# single-file commands cat cp date echo ls mkdir mv ps rm sed test wc —
# all compiled by Harvey's vendored 7c and linked by 7l)
# EXECUTE on the 9front donor kernel under qemu -M virt TCG.
#
# Generalizes run-gate.sh: stage the subset into the
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
# Env overrides: HARVEY, HARVEY_VM, QEMU_BIN, HARNESS_BIN, BOOT_BUDGET,
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

HARNESS_BIN="${HARNESS_BIN:-}"
if [ -z "$HARNESS_BIN" ]; then
	HARNESS_BIN=$(command -v harness || true)
fi
[ -n "$HARNESS_BIN" ] && [ -x "$HARNESS_BIN" ] || \
	err "harness binary not found — set HARNESS_BIN or run inside the nix devshell (which exports it)"

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
	# cached from the prior build.
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
# The post-shell step table (replacing the subsetdrive9.py heredoc):
# drive9 --steps drives the proven boot, then runs these rows
# with paced echo-verified sends ('drive9: step i/n OK (label)').
# Tab-separated: cmd (literal \r escape), echo-pattern ('-' = the
# escaped first-16-bytes default), out-pattern, timeout-secs, label.
# Patterns are the subsetdrive9.py STEPS + FINAL rows verbatim (the
# engine is multiline-always, so the (?m) prefixes are simply dropped).
cat > "$TMPD/steps.tsv" <<'STEPS_EOF'
/boot/hecho __SUBSET_SENTINEL__\r	-	^__SUBSET_SENTINEL__\r?$	60	echo sentinel
/boot/hls /\r	-	^/boot\r?$	60	ls / non-empty
/boot/hcat /boot/sentinel.txt\r	-	^alpha bravo charlie\r?$	60	cat known file
/boot/hcat /boot/sentinel.txt | /boot/hgrep __SUBSET_GREP_LINE__\r	-	^__SUBSET_GREP_LINE__\r?$	60	grep pipeline
/boot/hecho __SUBSET_SENTINEL__ | /boot/hsed s/SENTINEL/VERIFIED/\r	-	^__SUBSET_VERIFIED__\r?$	60	sed pipeline
/boot/hcat /boot/sentinel.txt | /boot/hwc -l\r	-	^ *2\r?$	60	wc -l expected count
/boot/hdate\r	-	(UTC|GMT) 20[0-9][0-9]\r?$	60	date parseable line
/boot/htest -f /boot/hcat && /boot/hecho __TEST_F_OK__\r	-	^__TEST_F_OK__\r?$	60	test -f true-branch
X=`{/boot/hecho hello} && /boot/hecho __RC_EVAL__$X\r	-	^__RC_EVAL__hello\r?$	60	rc evaluates (command substitution)
/boot/hps\r	-	\src\r?$	60	ps process list (shell resident)
/boot/hmkdir /tmp/subset && /boot/hecho __MKDIR_OK__\r	-	^__MKDIR_OK__\r?$	60	mkdir in /tmp
/boot/hcp /boot/sentinel.txt /tmp/subset/copied && /boot/hecho __CP_OK__\r	-	^__CP_OK__\r?$	60	cp into /tmp/subset
/boot/hmv /tmp/subset/copied /tmp/subset/moved && /boot/hecho __MV_OK__\r	-	^__MV_OK__\r?$	60	mv rename
/boot/hls /tmp/subset\r	-	^/tmp/subset/moved\r?$	60	ls verifies mv
/boot/hrm /tmp/subset/moved && /boot/hecho __RM_OK__\r	-	^__RM_OK__\r?$	60	rm file
/boot/hls /tmp/subset | /boot/hwc -l\r	-	^ *0\r?$	60	ls|wc round-trip empty
/boot/hrm /tmp/subset && /boot/hecho __RMDIR_OK__\r	-	^__RMDIR_OK__\r?$	60	rm empty dir
/boot/hipconfig -Z\r	-	usage: .*hipconfig	60	ipconfig usage-level (network-less guest)
/boot/hfactotum -n -s subexec &\r	-	^term% 	60	factotum backgrounded start
/boot/hecho __FACTOTUM_SPAWNED__\r	-	^__FACTOTUM_SPAWNED__\r?$	60	shell survived factotum start
/boot/hps\r	-	\bhfactotum\b	60	factotum resident in ps
/boot/hecho SUBSET-OK\r	-	^SUBSET-OK\r?$	60	SUBSET-OK sentinel
STEPS_EOF
[ "$(grep -c . "$TMPD/steps.tsv")" = "22" ] || err "steps.tsv row count drifted (want 22)"

# serve the root fs (9P2000) with the writable /tmp scratch unlocked
# for THIS gate only (see header)
echo "== serving $ROOTFS on 127.0.0.1:$SRV9_PORT (9P2000; writable prefixes /tmp, /usr/glenda/tmp)"
"$HARNESS_BIN" srv9 serve --root "$ROOTFS" --host 127.0.0.1 --port "$SRV9_PORT" \
	--writable-prefix /tmp --writable-prefix /usr/glenda/tmp \
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

# wake the GIC redistributor (boot-9qemu.sh drift accommodation 2)
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
# boot to the shell, then run the exercise table and assert every marker
echo "== driving boot to rc shell + exercising the subset (budget ${BOOT_BUDGET}s; log: $RUNLOG)"
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
