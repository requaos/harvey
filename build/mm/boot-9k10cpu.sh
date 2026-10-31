# boot-9k10cpu.sh — BUILD-05 smoke harness: boot amd64/9k10cpu.elf under
# minimega and prove the boot by capturing the COM1 serial banner.
#
# Usage (from the repo root):
#   sudo build/mm/boot-9k10cpu.sh        # KVM host (daemon + /dev/kvm want root)
#   MM_TCG=1 MM_BOOT_BUDGET=600 bash build/mm/boot-9k10cpu.sh   # KVM-less host:
#                                        # TCG emulation (minutes, not seconds)
#
# Env overrides:
#   HARVEY          repo root               (default: $PWD)
#   MM_MINIMEGA     minimega binary         (default: PATH, then $HARVEY/result/bin/minimega)
#   MM_SOCAT        socat binary            (default: PATH)
#   MM_TCG          1 = allow TCG mode when /dev/kvm is absent
#   MM_QEMU         qemu-system-x86_64 path (TCG mode; default: PATH lookup)
#   MM_BOOT_BUDGET  seconds to wait for the banner (default: 60 KVM / 600 TCG)
#   MM_LOG          capture file            (default: $PWD/boot-9k10cpu.log)
#   MM_BASE         minimega runtime dir    (default: /tmp/minimega)
#
# Boot proof: k10 enables COM1 unconditionally (i8250console("0"),
# sys/src/9k/k10/main.c:182) and prints "\nPlan 9" (main.c:191). Success =
# the string "Plan 9" appears in the captured serial log. The banner grep,
# not the timer, is the source of truth — a healthy-but-slow boot just needs
# a bigger MM_BOOT_BUDGET (rerun; do not retry silently on a missed banner —
# see 01-04-PLAN.md Flagged Assumptions).
#
# Mechanics (verified against minimega 3.3.0 cmd/minimega/kvm.go + main.go):
#  - qemu is always launched PAUSED (-S); `vm start` resumes via QMP. The
#    serial socket ($MM_BASE/<vm_id>/serial0) exists only after launch, and
#    the banner prints within the first milliseconds of start — so the .mm is
#    split at its `vm start` line into launch/start fragments and the socat
#    capture attaches BETWEEN them.
#  - minimega never emits -enable-kvm. Acceleration is probed here via
#    /dev/kvm; TCG mode injects `vm config qemu <path>` AND
#    `vm config cpu qemu64` (minimega's default CPU is "host", which qemu
#    rejects without KVM).
#  - `minimega -e` exits 0 even when the command fails, so launch success is
#    gated on the serial socket appearing, not on exit status.
#
# Boundary (BUILD-05): minimega manages amd64/KVM VMs only; aarch64/r9 boots
# stay on plain qemu in later phases. No in-guest agent (miniccc), no qemu
# stdio scraping — serial socket capture + banner grep only.
#
# NOTE: standalone script (not flake-wrapped this phase), so it sets its own
# shell options instead of relying on writeShellApplication's.

set -euo pipefail

HARVEY="${HARVEY:-$PWD}"
VM_NAME=k10cpu
MM_BASE="${MM_BASE:-/tmp/minimega}"
MM_LOG="${MM_LOG:-$PWD/boot-9k10cpu.log}"
KERNEL_ELF="$HARVEY/amd64/9k10cpu.elf"
MM_TEMPLATE="$HARVEY/build/mm/boot-9k10cpu.mm"

err() { echo "error: $*" >&2; exit 1; }

[ -f "$KERNEL_ELF" ] || err "$KERNEL_ELF missing — run 'nix run .#build' first (plan 01-01 artifact)"
[ -f "$MM_TEMPLATE" ] || err "$MM_TEMPLATE missing — run from the harvey checkout"

MINIMEGA="${MM_MINIMEGA:-}"
if [ -z "$MINIMEGA" ]; then
	MINIMEGA=$(command -v minimega || true)
fi
if [ -z "$MINIMEGA" ] && [ -x "$HARVEY/result/bin/minimega" ]; then
	MINIMEGA="$HARVEY/result/bin/minimega"
fi
if [ -z "$MINIMEGA" ] || [ ! -x "$MINIMEGA" ]; then
	err "minimega not found — 'nix build .#minimega' (linux) or set MM_MINIMEGA"
fi

SOCAT="${MM_SOCAT:-}"
if [ -z "$SOCAT" ]; then
	SOCAT=$(command -v socat || true)
fi
[ -n "$SOCAT" ] || err "socat not found — needed for serial capture (nix shell nixpkgs#socat, or set MM_SOCAT)"

# Acceleration probe: KVM when /dev/kvm is writable (default); TCG only when
# explicitly allowed via MM_TCG=1.
TCG=0
QEMU=""
if [ -w /dev/kvm ]; then
	:
elif [ "${MM_TCG:-0}" = "1" ]; then
	TCG=1
	QEMU="${MM_QEMU:-}"
	if [ -z "$QEMU" ]; then
		QEMU=$(command -v qemu-system-x86_64 || true)
	fi
	[ -n "$QEMU" ] || err "TCG mode: qemu-system-x86_64 not on PATH — set MM_QEMU"
else
	err "/dev/kvm not writable and MM_TCG unset — on a KVM-less host rerun with MM_TCG=1 (TCG: minutes, not seconds)"
fi

BUDGET="${MM_BOOT_BUDGET:-}"
if [ -z "$BUDGET" ]; then
	if [ "$TCG" = 1 ]; then BUDGET=600; else BUDGET=60; fi
fi

# minimega CLI: -e joins all positional args into one command string against
# the daemon at -base. NOTE: exit status is 0 even when the command errors —
# never trust it, probe state instead.
mm() { "$MINIMEGA" -base "$MM_BASE" -e "$@"; }

TMPD=$(mktemp -d)
SOCAT_PID=""
STARTED_DAEMON=0

cleanup() {
	status=$?
	[ -n "$SOCAT_PID" ] && kill "$SOCAT_PID" 2>/dev/null || true
	mm vm kill "$VM_NAME" >/dev/null 2>&1 || true
	mm vm flush >/dev/null 2>&1 || true
	if [ "$STARTED_DAEMON" = 1 ]; then
		mm quit >/dev/null 2>&1 || true
	fi
	rm -rf "$TMPD"
	exit $status
}
trap cleanup EXIT

# Daemon: connect to a running one if it answers; otherwise start it.
# KVM mode usually needs root (daemon + /dev/kvm + runtime dir) — run the
# whole wrapper under sudo there.
if ! mm vm info >/dev/null 2>&1; then
	echo "== starting minimega daemon (base $MM_BASE)"
	"$MINIMEGA" -base "$MM_BASE" -nostdin >"$TMPD/daemon.log" 2>&1 &
	STARTED_DAEMON=1
	i=0
	while ! mm vm info >/dev/null 2>&1; do
		i=$((i + 1))
		if [ $i -gt 30 ]; then
			tail -n 20 "$TMPD/daemon.log" >&2 || true
			err "minimega daemon did not come up (base $MM_BASE) — stale $MM_BASE/minimega socket? remove it or set MM_BASE"
		fi
		sleep 1
	done
fi

# Render the .mm: substitute the kernel path, strip comments/blank lines.
# Then split at the `vm start` line: launch.mm carries config + launch,
# start.mm carries the start — the serial capture attaches between them.
sed -e "s|^vm config kernel KERNEL_ELF\$|vm config kernel $KERNEL_ELF|" \
	-e 's/#.*//' -e '/^[[:space:]]*$/d' \
	"$MM_TEMPLATE" >"$TMPD/full.mm"

awk -v launch="$TMPD/launch.mm" -v start="$TMPD/start.mm" '
	/^vm start / { started = 1 }
	started { print >> start; next }
	{ print >> launch }
' "$TMPD/full.mm"

grep -q '^vm launch kvm ' "$TMPD/launch.mm" || err "rendered $TMPD/launch.mm lost the vm launch line — template corrupt?"
grep -q '^vm start ' "$TMPD/start.mm" || err "rendered $TMPD/start.mm lost the vm start line — template corrupt?"

# TCG: inject the qemu binary + a TCG-valid CPU model ahead of the launch.
if [ "$TCG" = 1 ]; then
	awk -v q="vm config qemu $QEMU" '
		/^vm launch / && !done { print q; print "vm config cpu qemu64"; done = 1 }
		{ print }
	' "$TMPD/launch.mm" >"$TMPD/launch.mm.tcg"
	mv "$TMPD/launch.mm.tcg" "$TMPD/launch.mm"
fi

# Clear any stale instance of this VM name (crashed prior run); flush only
# removes VMs already in quit/error state.
mm vm kill "$VM_NAME" >/dev/null 2>&1 || true
mm vm flush >/dev/null 2>&1 || true

if [ "$TCG" = 1 ]; then
	echo "== mode: TCG (no /dev/kvm; qemu=$QEMU; cpu=qemu64; budget ${BUDGET}s)"
else
	echo "== mode: KVM (budget ${BUDGET}s)"
fi
echo "== launching $VM_NAME (kernel $KERNEL_ELF)"
mm read "$TMPD/launch.mm"

# Resolve the VM id from `vm info` (parse by header name; column order is not
# assumed) and wait for the serial socket — its appearance, not minimega's
# exit status, proves qemu actually started.
VM_ID=$(mm vm info | awk -F'|' -v name="$VM_NAME" '
	NR == 1 {
		for (i = 1; i <= NF; i++) {
			gsub(/^[ \t]+|[ \t]+$/, "", $i)
			if ($i == "id") idc = i
			if ($i == "name") namec = i
		}
		next
	}
	namec {
		val = $namec
		gsub(/^[ \t]+|[ \t]+$/, "", val)
		if (val == name) {
			id = $idc
			gsub(/^[ \t]+|[ \t]+$/, "", id)
			print id
			exit
		}
	}
')
case "$VM_ID" in
	'' | *[!0-9]*)
		mm vm info >&2 || true
		err "could not resolve minimega VM id for $VM_NAME — launch failed?"
		;;
esac
SERIAL_SOCK="$MM_BASE/$VM_ID/serial0"

i=0
while [ ! -S "$SERIAL_SOCK" ]; do
	i=$((i + 1))
	if [ $i -gt 60 ]; then
		mm vm info >&2 || true
		err "serial socket $SERIAL_SOCK never appeared — qemu failed to start (TCG qemu on PATH? see above)"
	fi
	sleep 1
done

# Attach the capture BEFORE starting the VM: the COM1 banner prints within
# the first milliseconds of `vm start`, and chardev output with no client
# connected is lost.
: >"$MM_LOG"
"$SOCAT" -u "UNIX-CONNECT:$SERIAL_SOCK" "CREATE:$MM_LOG" &
SOCAT_PID=$!

echo "== capture attached: $SERIAL_SOCK -> $MM_LOG"
echo "== starting $VM_NAME"
mm read "$TMPD/start.mm"

echo "== waiting for 'Plan 9' banner (budget ${BUDGET}s)"
deadline=$((SECONDS + BUDGET))
found=1
while [ $SECONDS -lt $deadline ]; do
	if grep -q 'Plan 9' "$MM_LOG" 2>/dev/null; then
		found=0
		break
	fi
	sleep 5
done

if [ "$found" -ne 0 ]; then
	echo "error: no 'Plan 9' banner within ${BUDGET}s — last log lines:" >&2
	tail -n 40 "$MM_LOG" >&2 || true
	echo "hint: a healthy-but-slow boot just needs a bigger MM_BOOT_BUDGET; a missed early banner means the capture attached late — triage manually, do not retry silently" >&2
	exit 1
fi

echo "== PASS: 'Plan 9' banner captured in $MM_LOG"
