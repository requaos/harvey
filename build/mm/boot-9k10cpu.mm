# boot-9k10cpu.mm — minimega script: boot the Phase 1 amd64 9k10cpu kernel.
#
# BUILD-05 boundary: minimega manages amd64/KVM VMs ONLY. aarch64/r9 boots
# stay on plain qemu in later phases — do not extend this script to them.
#
# KERNEL_ELF is a placeholder: build/mm/boot-9k10cpu.sh substitutes the
# absolute path to $HARVEY/amd64/9k10cpu.elf at runtime. The .elf variant is
# mandatory — qemu -kernel multiboot-loads the ELF (multiboot header at
# sys/src/9k/k10/l32p.s:25-28; ELF link via 6l -H5); never use the a.out.
#
# Comment/blank lines are for humans: the wrapper strips them before feeding
# fragments to `minimega -e read`. Boot proof: k10 enables COM1
# unconditionally (i8250console("0"), sys/src/9k/k10/main.c:182) and prints
# "\nPlan 9" (main.c:191); the wrapper captures serial0 and greps the banner.
#
# Ordering (Pitfall 6): qemu always launches PAUSED (-S), so `vm start` is
# mandatory, and the serial capture must attach between launch and start or
# the early COM1 banner is missed. The wrapper splits this file at the
# `vm start` line into launch/start fragments for exactly that ordering.
#
# No `vm config initrd`: the root fs is embedded in the kernel (rootdir
# section of sys/src/9k/k10/k10cpu via 9k/mk/parse + mkrootall).

vm config memory 512
vm config kernel KERNEL_ELF
vm config serial-ports 1
vm config backchannel false

# TCG fallback — enable on hosts without /dev/kvm (e.g. linux-aarch64 dev
# VMs): minimega never emits -enable-kvm, so pointing qemu at a plain
# qemu-system-x86_64 gives TCG emulation (10-50x slower — minutes, not
# seconds). The wrapper injects BOTH lines below when MM_TCG=1; the cpu line
# is required because minimega's default CPU is "host", which qemu rejects
# without KVM.
# vm config qemu /nix/store/.../bin/qemu-system-x86_64
# vm config cpu qemu64

vm launch kvm k10cpu
vm start k10cpu
