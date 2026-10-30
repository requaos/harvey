# Architecture Research

**Domain:** Plan 9 kernel architecture port (Harvey 9k → aarch64, qemu `-M virt`)
**Researched:** 2026-10-30
**Confidence:** HIGH for Harvey-side structure (read directly from this repo); MEDIUM-HIGH for 9front-side (primary source — upstream git repo read via gitweb; tagged MEDIUM per source-hierarchy rules)

## Standard Architecture

### System Overview — how a Plan 9 kernel arch port is put together

A Plan 9 kernel is three layers glued by the build system, not one tree:

```
┌────────────────────────────────────────────────────────────────────┐
│  port/   — portable kernel: proc, chan, dev, qio, page, segment,   │
│            sysfile/sysproc, qmalloc, devtab, devroot, portclock,   │
│            devcons, devuart, ip/ stack, error/lock primitives      │
│            (sys/src/9k/port: 61 .c files + portdat.h/portfns.h)    │
├────────────────────────────────────────────────────────────────────┤
│  <arch>/ — machine layer. In Harvey 9k today: k10/ (amd64) with    │
│            drivers in 386/. Contract surface:                      │
│            mem.h dat.h fns.h io.h  (header triad + io)             │
│            l*.s entry/trap/syscall asm, main.c, mmu.c, trap.c,     │
│            syscall.c, fpu.c, clock/timer, interrupt ctlr,          │
│            memory.c (phys mem), arch.c (procsave/restore),         │
│            devarch.c (#P), bootargs/init9, <CONF> config, mkfile   │
├────────────────────────────────────────────────────────────────────┤
│  mk/     — config compiler: parse (awk) reads <CONF> and emits     │
│            $CONF.c (devtab[] + links() + embedded-root table),     │
│            systab.c (from libc/9syscall/sys.h), errstr.h, and the  │
│            object lists MACH/DEVS/PORT/LIB + pattern rules.        │
│            bootmkfile builds boot$CONF.out (pid-1 program) into    │
│            ../boot/libboot.a$O; mkrootall embeds rootdir files.    │
└────────────────────────────────────────────────────────────────────┘
```

**The port/↔arch contract is header-based and circular by design:** arch code includes `u.h` → `../port/lib.h` → `mem.h` → `dat.h` (which ends with `#include "../port/portdat.h"`) → `fns.h` (which ends including `../port/portfns.h`). `dat.h` defines the machine halves of portable structs via macros that portdat.h expands inside `struct Proc`/`struct Mach`: `PMMU`, `PFPU`, `PNOTIFY` (Proc) and `MCPU`, `MFPU`, `MMMU` (Mach). **This is the single most important structural fact for the port: the arch dir owns the definition of these macro-structs.** k10 defines `PMMU = { Page* mmuptp[4]; }`; 9front's arm64 mmu.c instead wants `mmufree/mmuhead[PTLEVELS]/mmutail/asid` per proc — the aarch64 `dat.h` must define PMMU accordingly (fields exist per-arch, so no port/ change is needed).

### Component Responsibilities (arch dir, canonical set)

| Component | Responsibility | k10 (amd64) file | 9front arm64 file |
|-----------|----------------|------------------|-------------------|
| Entry asm | Reset entry, MMU enable, jump to high VA, per-CPU Mach/SP setup | `l32p.s`+`l64v.s` | `l.s` |
| Exception vectors | VBAR table, trap/syscall/irq entry stubs, `touser`, `forkret` | `l64idt.s`, `l64syscall.s` | `l.s` + `cache.v8.s` helpers |
| `main.c` | C entry, init ordering, `init0`/`userinit`/`bootargs`, shutdown/reboot/exit hooks | `main.c` (465 ln) | `main.c` (~410 ln) |
| `mmu.c` | Page tables, `mmuswitch`, `putmmu`, `mmukmap`, `kmap`/`vmap`, ASID | `mmu.c` (628 ln) | `mmu.c` (~550 ln) |
| `trap.c` | `trapinit`, `trap(Ureg*)`, fault dispatch, `intrenable`/`intrdisable`, Vctl | `trap.c` (668 ln) | `trap.c` (~600 ln) |
| `syscall.c` | Harvey-specific: build `Ar0`, call generated `systab[]`, notes/`noted` | `syscall.c` (375 ln) | *absent — 9front folds syscall into trap.c with different ABI* |
| Timer/clock | `fastticks(uvlong*)` (contract fn), `kproftimer` hook, `timerset`, HZ tick via irq | `i8254.c`, `hpet.c`, `apic.c` timers | `clock.c` (ARM generic timer CNTPCT/CNTP) |
| Interrupt ctlr | `intrenable(int, void(*)(Ureg*,void*), void*, int, char*)`, Vctl alloc, IRQ dispatch | `apic.c`+`ioapic.c`+`i8259.c` | `gic.c` (GICv2/v3) |
| FPU | `fpuinit`, `fpuprocsave/restore`, `fpunoted`, FPU-in-irq policy | `fpu.c`, `l64fpu.s` | `fpu.c` |
| Phys memory | `meminit`/memory map discovery, `conf.mem[]` fill, `kmapram` | `memory.c`, `map.c`, `multiboot.c` | `mem.c` (dtb/`*maxmem`) |
| Arch device | `#P` devarch (ioalloc, irq stats) — *optional*, 9front arm64 omits it | `devarch.c` | — |
| Proc machine glue | `procsave`/`procrestore`, `machinit`, `mpinit`/SMP bring-up | `arch.c`, `archk10.c`, `sipi.c`, `mp.c` | `main.c` (mpinit), `bootargs.c` |
| Console uart | `PhysUart` registration for `devuart`, early printk | `uarti8250.c` (in 386/) | `uartqemu.c` (PL011 @ 0x09000000) |
| PCI | config-space access for virtio etc. | `pci.c` (in 386/) | `pciqemu.c` (ECAM) |
| RTC | `devrtc` (#rTC) via tod hooks | `devrtc.c` (in 386/, CMOS) | `devrtc.c` (generic) |
| Config | device list, links, boot method, rootdir, per-objtype MACH list | `k10cpu`, `k10cpuf`, … | `qemu`, `pi3`, `pi4` |
| mkfile | `ARCH=`, `objtype=`, link addr, `$LD` header flags, special rules | `k10/mkfile` | `arm64/mkfile` |
| Boot args | parse firmware handoff (multiboot vs DTB/plan9.ini) | `multiboot.c` | `bootargs.c` |
| First user trampoline | `init9` → `startboot` (port/initcode.c) embedded via `init.h` | `init9.c` | `init9.s` |

## The conf/mk machinery — how a new arch gets wired in

Concrete wiring checklist (each item verified in-repo):

1. **`sys/src/9k/<arch>/mkfile`** sets `ARCH=<dirname>`, `CONF=<arch>cpu`, `objtype=aarch64`, then `</$objtype/mkfile` (pulls CC/AS/LD/O from the arch root), includes `<../mk/bootmkfile` + `<../mk/portmkfile`, and runs `<| awk -f ../mk/parse $CONF` which emits `DEVS=… MACH=… LIB=… PORT=…` plus all pattern rules. Final link: `$LD -o $target -T<loadaddr> -l $OBJ $CONF.$O $LIB`. k10 additionally emits an ELF via a second `$LD -H5`; bcm-style raw uses `-H6 -R4096`; 9front qemu kernel uses neither (Plan 9 boot image) + `aux/aout2uimage`.
2. **The config file** (`<arch>cpu`) is sectioned text. Sections: `dev` (kernel devices; entries may take driver names on the right), `uart`/`ip`/`link`/`misc` (+dev variants get compiled in), `boot` (method table → `boot$CONF.c`), `rootdir` (files embedded into devroot: `boot<conf>.out boot`, factotum, ipconfig…), `conf` (raw C appended to `$CONF.c`, e.g. `int cpuserver=0;`), `dbgflg`, **`<objtype>`** (the machine object list — `parse` reads section named by `$objtype` env into `MACH=`), `port` (portable objects), `dir` (extra source dirs to auto-compile from: k10cpu uses `386 ip port`), `lib` (libraries to link: libip libsec libmp libc).
3. **Generated sources:** `$CONF.c` (devtab[], links(), addbootfile() root table, physseg[], dbgflg[], conffile), `../port/systab.c` (from `sys/src/libc/9syscall/sys.h` — Harvey's Ar0-typed syscall table), `errstr.h` (from port/error.h), `init.h` (embedded init.out bytecode), `$CONF.root.s` (mkrootall — embedded root image).
4. **Arch root dir** `/$objtype/` (`aarch64/`): `mkfile` (`CC=7c LD=7l O=7 AS=7a`), `include/u.h`, `include/ureg.h` (+`ape/` later). Repo currently has an **empty `arm64/`** root and `build_arm64` functions in `build/scripts/{build,linux-build}` referencing `objtype=arm64` — PROJECT.md mandates `aarch64`, so: create `aarch64/`, update the two build functions, remove/ignore the empty `arm64/`.
5. **libc**: `sys/src/libc/aarch64/` (asm files below) + **`sys/src/libc/9syscall/mkfile` needs a `case aarch64`** emitting SVC stubs (9front's arm64 case: `MOV R0,'0(FP)'; MOV $n,R0; SVC; RETURN`). `sys/src/libc/mkfile` iterates `$objtype` automatically; `sys/src/mkfile.proto` `CPUS` += aarch64 for installall.
6. **Toolchain**: `sys/src/cmd/7a`, `7c`, `7l` (import from 9front; 7c links shared `../cc/cc.a` which Harvey already has) + **`sys/src/cmd/pcc.c` objtype entry** `{"aarch64", "7c", "7l", "7", "7.out"}`.
7. **libmach** (debugger/disasm): 9front `libmach/7.c` + `MARM64` — defer to a debug-support phase; not needed to boot.

## Mapping table: 9front arm64 → Harvey 9k

9front restructured arm64 support (Nov 2023 "HUMANBIOLOGICS") into a **generic `sys/src/9/arm64/` layer** shared by all arm64 kernels (bcm64, imx8, qemu) — this generic layer, not bcm64, is the right import source. The `qemu` kernel config there targets exactly our milestone machine (`-M virt`, GIC, PL011, ECAM PCIe, virtio).

| 9front source | Action for Harvey | Harvey destination | Adaptation needed |
|---------------|-------------------|--------------------|-------------------|
| `9/arm64/l.s` | **Adapt** | `9k/aarch64/l.s` | Entry asm is directly reusable (MMU-off entry, EL2→EL1 drop, cache invalidate, Mach/SP from MPIDR, mmuidmap/mmu0init calls, TPIDR_EL1=m, SEVL secondary release). Edit: symbols must match Harvey `mem.h`; integrate Harvey `init.h` path later. |
| `9/arm64/cache.v8.s` | **Import** | `9k/aarch64/cache.v8.s` | Verbatim ARMv8 cache/TLB ops (`cachedwbinv`, `cacheiinv`, `flushtlb`, `flushasid*`, `coherence`). |
| `9/arm64/sysreg.h` (+`sysreg.c`) | **Import** | `9k/aarch64/sysreg.h` | SYSREG encoding macros + accessors. bcm64 later dropped sysreg.c (macros only) — prefer header-only. |
| `9/arm64/mmu.c` | **Adapt (medium)** | `9k/aarch64/mmu.c` | Core logic portable (block-map kernel, per-proc TTBR0, ASID alloc, `mmuswitch`/`putmmu`/`mmukmap`/`kmap`/`vmap`). Must match Harvey port contract: `PMMU` fields in Proc (define 9front-style `mmufree/mmuhead/mmutail/asid` in our `dat.h`), Harvey `putmmu(va,pa,Page*)` signature (matches), `flushmmu`, `kmapinval` macro, Harvey `PTE*` names in `mem.h`. |
| `9/arm64/mem.c` | **Adapt (small)** | `9k/aarch64/memory.c` (Harvey naming) | `mmuidmap`/`mmu0init`/`meminit`. 9front uses DTB + `*maxmem`; keep DTB parse minimal, honor `conf.mem[0]`. Rename to match k10 (`memory.c`). |
| `9/arm64/main.c` | **Adapt (medium)** | `9k/aarch64/main.c` | Init call sequence differs: Harvey k10 order is console→memory→mmu→trap→devtab→`procinit0`→`init0`; Harvey has `Sys *sys` singleton + `sizeofSys`, `confsetenv`, Harvey `init0` (namec `#/`, devtabinit, ksetenv `cputype=aarch64`), Harvey `bootargs` stack build, `userinit` using Harvey Segment/KMap API. Keep 9front's `machinit`/`mpinit` (SPINTABLE/SEV SMP start) — can defer SMP to later phase. |
| `9/arm64/trap.c` | **Adapt (medium)** | `9k/aarch64/trap.c` | Keep vector install (`VBAR_EL1`), ESR decode, irq dispatch via `Vctl`. Adapt to Harvey: `intrenable` signature (k10 fns.h:57), Harvey note delivery (`postnote`, "sys: trap: …" strings), `fault()` interaction in port/fault.c, `userureg()` check. |
| — (9front folds into trap.c) | **Write new** | `9k/aarch64/syscall.c` | Harvey-specific: `syscall(int scallnr, Ureg*)` modeled on `k10/syscall.c` — `userureg` check, `up->insyscall`, proctrace hooks, `memmove(up->arg, sp+…, sizeof(up->arg))` (**offset 0 from SP_EL0, not BY2SE**: arm64 BL doesn't push a return address), `systab[scallnr].f(&ar0, (va_list)up->arg)`, return via `ureg->r0 = ar0.p`, errstr swap dance. |
| `9/arm64/clock.c` | **Adapt (small)** | `9k/aarch64/clock.c` | ARM generic timer: read CNTFRQ_EL0, `fastticks(uvlong*)` = CNTVCT/CNTPCT, `kproftimer` wiring (Harvey portclock.c:172 calls it if non-nil), `timerset` via CNTP_TVAL/CVAL, timer PPI irq (27/30) through gic. |
| `9/arm64/gic.c` | **Adapt (small)** | `9k/aarch64/gic.c` | GICv2/v3 dist/redist/cpuif init (virt: GIC400 @0x08000000 or GICv3 @0x08000000/0x0A000000), `intrenable`→enable SGI/PPI/SPI, EOI. Match Harvey Vctl. |
| `9/arm64/fpu.c` | **Import (small edits)** | `9k/aarch64/fpu.c` | FP/SIMD save-restore (32×128-bit regs + FPCR/FPSR), `fpuprocsave/restore`, CPACR_EL1 enable. Harvey names via fns.h. |
| `9/arm64/uartqemu.c` | **Adapt (small)** | `9k/aarch64/uartpl011.c` | PL011 @0x09000000, irq 33. Register as `PhysUart pl011physuart` — Harvey's `parse` generates `physuart[]` from config `uart` section by stripping the `uart` prefix (`uartpl011` → `pl011physuart`). Rename file to say what it is. |
| `9/arm64/pciqemu.c` | **Import/adapt** | `9k/aarch64/pciqemu.c` | ECAM PCIe for qemu virt. Only needed when virtio drivers enter the config (phase 2); deferrable for first boot. |
| `9/arm64/devrtc.c` | **Import** | `9k/aarch64/devrtc.c` | Generic tod-based rtc device; only if `rtc` stays in config (can drop initially). |
| `9/arm64/bootargs.c` | **Adapt (small)** | fold into `main.c` or keep | Parses x0 (DTB pa) + plan9.ini at CONFADDR. For direct `-kernel` boot with embedded root and no plan9.ini, reduce to DTB scan for memory size (or fixed `*maxmem` default). |
| `9/arm64/init9.s` | **Import (trivial)** | `9k/aarch64/init9.s` | 4 instructions: set SB, load `/boot`, `B startboot`. Harvey port/initcode.c provides `startboot`. |
| `9/arm64/rebootcode.s` | **Skip for now** | — | Reboot support; add in a later phase. |
| `9/arm64/qemu` (config) | **Rewrite in Harvey format** | `9k/aarch64/aarch64cpu` | Harvey config grammar (see below). |
| `9/arm64/mkfile` | **Rewrite** | `9k/aarch64/mkfile` | Harvey style: `ARCH=aarch64`, `parse`+`bootmkfile`+`portmkfile`, Harvey link line. |
| `9/bcm64/*` (archbcm3/4, ethergenet, sdhc, pcibcm, gisb, vcore…) | **Do not import** | — | RPi board support; out of scope (qemu virt only). |
| 9front `port/ethervirtio10.c`, `sdvirtio10.c` | **Phase 2, optional** | `9k/port/` | Harvey already has `386/ethervirtio.c` (PCI virtio-net) and `386/sdvirtio.c` — audit for x86 port-I/O assumptions before reuse; alternatively import 9front's newer virtio10 drivers into port/. **Not needed for first shell.** |

## Recommended port dir: `sys/src/9k/aarch64/` file inventory

Minimal set to boot qemu virt to a shell (~4,500 lines, most imported/adapted):

```
sys/src/9k/aarch64/
├── mkfile            # ARCH=aarch64 objtype=aarch64 CONF=aarch64cpu; parse+bootmkfile+portmkfile (~60 ln)
├── aarch64cpu        # kernel config in Harvey grammar (~90 ln, below)
├── mem.h             # address map + PTE bits + register conventions (~200 ln, from 9front arm64)
├── dat.h             # Lock/Label/Mach/Sys-adapted, PMMU/PFPU/PNOTIFY, Vctl, Confmem (~250 ln)
├── fns.h             # machine fn prototypes consumed by port/ (~200 ln)
├── io.h              # PHYSIO/VIRTIO windows, GIC/UART base addrs, Vctl irq glue (~80 ln)
├── sysreg.h          # SYSREG macros, DAIF/SCTLR/TCR/MAIR constants (~250 ln, import)
├── l.s               # _start, vectors (vsys0/vtrap0 + EL1 variants), touser, forkret,
│                     #   mmuenable/mmudisable, setttbr, splhi/splx, tas/locks asm (~450 ln)
├── cache.v8.s        # ARMv8 cache/TLB maintenance (~350 ln, import verbatim)
├── syscallentry.s    # (optional split of l.s; k10 splits l64syscall.s — our call)
├── main.c            # main(arg0=dtb), machinit, confinit, init0, userinit, bootargs,
│                     #   mpinit(deferrable), shutdown/exit/reboot stubs (~450 ln)
├── memory.c          # mmuidmap, mmu0init, meminit, kmapram (~150 ln, = 9front mem.c)
├── mmu.c             # mmuswitch, putmmu, mmuwalk, mmukmap, kmap/vmap, ASIDs (~550 ln)
├── trap.c            # trapinit, trap(), fault glue, intrenable/intrdisable (~400 ln)
├── syscall.c         # Harvey Ar0 ABI, systab dispatch, notify/noted (~300 ln, from k10)
├── clock.c           # generic timer: fastticks, kproftimer, HZ irq, timersinit (~200 ln)
├── fpu.c             # fpuprocsave/restore, fpuinit, fpunoted (~250 ln)
├── gic.c             # GICv2/v3 init + irq enable/disable/eoi (~250 ln)
├── uartpl011.c       # PhysUart pl011physuart + consuart early print (~180 ln)
├── devrtc.c          # optional; generic rtc via tod (~120 ln)
├── pciqemu.c         # optional phase-2; ECAM pci (~600 ln)
├── bootargs.c        # optional; dtb/plan9.ini scan (~150 ln, can fold into main.c)
└── init9.s           # 4-line first-user trampoline (import)
```

Config sketch (`aarch64cpu`, Harvey grammar — note `<objtype>` section must be named `aarch64` since `parse` keys MACH off `$objtype`):

```
dev +dev
	root cons env pipe proc mnt srv dup ssl tls cap kprof
	ether	netif
	ip	arp chandial ip ipv6 ipaux iproute netlog nullmedium pktmedium ptclbsum
	uart
uart +dev
	uartpl011
ip +dev
	tcp udp ipifc icmp icmp6
link +dev
	loopbackmedium ethermedium netdevmedium
misc +dev
	cache
boot cpu
	tcp
rootdir
	bootaarch64cpu.out boot
	/aarch64/bin/auth/factotum factotum
	/aarch64/bin/ip/ipconfig ipconfig
conf
	int cpuserver = 0;
aarch64 +dev
	l cache.v8 clock fpu gic main mmu memory syscall trap uartpl011 sysreg(?) …
port
	alarm allocb chan dev devtab edf fault image latin1 page parse pgrp
	portclock print proc ps qio qlock qmalloc random rebootcmd segment
	sysauth sysfile sysproc sysseg systab taslock tod watermarks
dir
	ip port
lib
	libip libsec libmp libc
```

Deliberately **excluded** vs k10cpu: `acpi`, `rtc` (until devrtc imported), `devarch` (`arch` — x86 ioalloc semantics; 9front arm64 omits #P entirely), vga/draw/mouse (headless), `swap` (9k port has no devswap), `ether`+`link` virtio NICs (phase 2), `sd` storage (boot from embedded devroot).

**Critical compile-time trap:** Harvey `port/` files assume arch defines from `mem.h`: `BY2PG/PGSZ`, `PTEMAPMEM/PTEPERTAB/SEGMAXSIZE` (portdat.h:351,373 size the Segment page-map arrays!), `MACHMAX`, `MACHSZ`, `KZERO`, `UTZERO/USTKTOP/USTKSIZE`, `KTZERO`, `STACKALIGN`. SEGMAXSIZE is derived from PTEPERTAB×PTEMAPMEM — pick mem.h values first, then verify portdat.h arrays stay sane (9front arm64: 4K pages, EVASHIFT=36, PTLEVELS=3 → PGLSZ(1)=2MiB blocks; their kernel later had to fix SEGMAXSIZE for 64-bit — see 9front commit "kernel: fix SEGMAXSIZE macro, force 64-bit result"; apply that fix proactively).

## Memory map (recommended: adopt 9front arm64 qemu layout verbatim)

```
0xFFFFFFFF80000000  KZERO    kernel VA base
0xFFFFFFFFB0000000  VIRTIO   device window VA (phys 0x08000000–0x10000000: GIC, PL011)
0xFFFFFFFFC0000000  VDRAM    DRAM VA base (phys 0x40000000 = qemu virt DRAM start)
0xFFFFFFFFC0100000  KTZERO   kernel text VA (phys 0x40100000; first 1M: DTB@0x40000000,
│                              plan9.ini/CONFADDR@0x40010000, rebootcode@0x40020000)
↓ below KTZERO:      MACHADDR(n) = KTZERO-(n+1)*8KiB   per-CPU Mach+stack arrays
↓                    L1TOP/L1 boot page tables
0xFFFFFFFE00000000  KMAP/KSEG0  kmap window (phys 0x40000000…, to 0x140000000 = 5GB max RAM)
0xFFFFFFFF00000000  VMAP     vmap() arena
user: UZERO=0, UTZERO=+0x10000, USTKTOP=0x00007FFFFFFF0000, USTKSIZE=16MiB
```

Rationale: identical constants to 9front's qemu kernel means `l.s`/`mmu.c`/`mem.c` import with near-zero constant bugs. `va−KZERO = pa` for DRAM (paddr/kaddr are ±KZERO).

**Register conventions (7c ABI + kernel):** R0 = first arg / return value / syscall number carrier; R26 = `up` (USER); R27 = `m` (MACH), mirrored in `TPIDR_EL1` (trap entry does `MRS TPIDR_EL1,R27; MOV 16(R27),R26` — **Mach.proc must stay at offset 16**, asm-known offsets documented in k10 dat.h comments — replicate); R28 = SB (`setSB`); R30 = LR. Trap frame: Ureg = r0..r30, sp, pc, psr, type (38×8 frame).

**Syscall ABI (matches Harvey amd64 shape):** user stub `MOV R0,'0(FP)'; MOV $n,R0; SVC`; kernel `vsys0` saves regs, `syscall(ureg->r0, ureg)`; args fetched from user stack at `SP_EL0+0` (no pushed return addr on arm64 — differs from k10's `sp+BY2SE`); handlers `sysX(Ar0*, va_list)` read from `up->arg` via the arm64 `va_arg` (8-byte slots, from `aarch64/include/u.h`); result → `ureg->r0 = ar0.p`.

## Boot sequence: qemu `-M virt` → shell

**Recommended path for the milestone: direct `qemu -kernel` raw binary.** Alternatives documented after.

```
qemu-system-aarch64 -M virt,gic-version=2(or 3) -cpu cortex-a72 -m 1G \
    -nographic -serial mon:stdio -kernel 9aarch64cpu
```

1. **Firmware/loader:** qemu loads the raw kernel image at physical `DRAM+0x80000` (0x40080000) for `-kernel` on virt, sets **x0 = phys addr of DTB** (qemu places DTB at 0x40000000), starts all primaries' CPU0 at the load address in **EL1 (or EL2 with virtualization=on), MMU off, caches off**.
   - *Constant check:* 9front's layout assumes phys load at 0x40100000 (u-boot loads there). For `-kernel` either (a) set `KTZERO=VDRAM+0x80000` in mem.h and link `-T` accordingly, or (b) keep 0x40100000 and emit ELF (`7l` ELF header flag — verify `-H` support during toolchain phase; k10 uses `6l -H5`) and let qemu honor ELF phdrs. Pick (a) if 7l lacks ELF output.
2. **`l.s _start`:** save x0(DTB)→R26; physical SB (`$setSB-KZERO`); `svcmode` (drop EL2→EL1 if needed, `SPSel=1`); `mmudisable`; invalidate caches; compute this CPU's Mach phys base from `MPIDR_EL1&(MAXMACH-1)`, set SP to Mach top; CPU0 only: zero L1+Mach region, clear BSS, `mmuidmap(L1BOT)` (TTBR0 identity map of DRAM), `mmu0init(L1)` (TTBR1 kernel high map: INITMAP + VIRTIO device window), `SEVL` releases secondaries (they WFE-wait then re-enter at `_startup` — SMP deferrable: conf.nmach=1).
3. **`mmuenable`:** program MAIR/TCR/TTBR0/TTBR1, `SCTLR_EL1.M=1`, ISB, return into the high alias; restore R0=DTB; `TPIDR_EL1 = m|KZERO`; SB virtual; `BL main`.
4. **`main(arg0)` (CPU0):** `machinit` → `bootargsinit(arg0)` (DTB mem size / plan9.ini) → `meminit` (conf.mem, `kmapram`) → `confinit` (npage/nproc/nswap…) → `xinit` (Harvey qmalloc arenas) → `printinit` → **uartconsinit (PL011)** → `print("Harvey\n")` → `trapinit` (VBAR_EL1) → `fpuinit` → `clockinit`/`timersinit` (generic timer, fastticks live) → `pageinit` → `procinit0` → `initseg` → `links()` → `devtabreset`/`chandevreset` → `userinit` (first proc + embedded initcode page) → `mmu1init` → `schedinit` → first `sched()` enters `init0` kproc.
5. **`init0` (Harvey):** `up->slash = namec("#/",…)` (devroot = embedded root from `mkrootall`), `devtabinit`, `ksetenv("cputype","aarch64")`, service env, `kproc("alarm",…)`, `touser(sp)`.
6. **First user process:** embedded `initcode` (port/initcode.c `startboot`) execs `/boot` (= `bootaarch64cpu.out`, embedded per config `rootdir`).
7. **`boot` (9k/boot/boot.c):** with embedded root + `local`/no-auth path, mounts `#/`, execs rc with `rcmain` → **shell on the UART console**. (Network/auth methods come alive once virtio-net lands; the milestone can ship `boot` with a rootdir-only path — follow `k10root`-style embedding precedent.)

**Alternative boot paths (document, don't build yet):** (b) u-boot: 9front's flow — `7l` image → `aux/aout2uimage -Z$kzero` → FAT with `boot.scr`+`plan9.ini`, qemu `-bios u-boot.bin` (adds a firmware dep but matches 9front qcow2 installs); (c) EDK2 + Harvey EFI loader — 9front ported boot/efi to arm64; that's the long-term hardware path, out of milestone scope.

## Architectural Patterns

### Pattern 1: Import board-neutral layer, rewrite the seams
**What:** Take 9front `9/arm64/*` (not bcm64) as the base; rewrite only `dat.h`/`fns.h`/`main.c`/`syscall.c`/`trap.c` seams where Harvey's port contract differs (Ar0 ABI, Sys singleton, PMMU shape, devtab init order).
**When:** This whole port.
**Trade-offs:** fastest path to a proven booting arm64 kernel; cost is keeping a mental diff vs upstream 9front for future merges. Acceptable — upstream Harvey is dormant and this repo is the maintained fork.

### Pattern 2: Config-driven composition (devtab/systab/rootdir generated)
**What:** Never hand-edit `$CONF.c`, `systab.c`, `errstr.h`, `init.h`, `*.root.s` — all generated by `mk/parse` from the config + `sys.h` + `error.h`.
**Trade-offs:** adding a device = edit config + drop `devX.c`; but the awk generator is fragile about section names (`<objtype>` section must literally be `aarch64`) and the `+dev` suffix controls compilation inclusion.

### Pattern 3: Headless-first kernel config
**What:** First config has no draw/mouse/vga/sd/ether-pci — console purely on PL011 UART, root purely from devroot. Mirrors k10cpu (which is also headless: no draw in its dev list).
**Trade-offs:** shell over serial proves proc/VM/syscall/9p-root stack end-to-end; graphics/storage/network are strictly additive config lines later.

## Anti-Patterns

### Anti-Pattern 1: Porting bcm64 (board) files instead of the generic arm64 layer
**Why wrong:** bcm64 carries RPi mailbox/vcore/genet/sdhc baggage and *itself* now reuses `../arm64` via mkfilelist rules; copying it imports board deps and 9front's old-style mk helpers (`mkdevlist`, `mkbootrules`) that don't exist in 9k.
**Instead:** import `9/arm64/*` only; write Harvey-native mkfile/config.

### Anti-Pattern 2: Letting 386/ x86 drivers leak into the aarch64 build
**What:** k10cpu's `dir` section pulls `386/` (pci.c, uarti8250.c, devrtc.c are x86-shaped: inb/outb, iomap, ISA IRQs).
**Instead:** aarch64 config's `dir` = `ip port` only; arch-local gic/pl011/pciqemu. Audit any 386 file before reuse (ethervirtio.c/sdvirtio.c are the only plausible reuse candidates — check for x86 port I/O first).

### Anti-Pattern 3: Hand-rolling the arm64 MMU from ARM ARM instead of importing mmu.c
**Why wrong:** TLB/ASID/break-before-make and cache-coherence details (the `putasid` race comment in 9front mmu.c — freed page tables vs in-flight interrupts across CPUs) are hard-won; SEGMAXSIZE had a real 64-bit overflow bug upstream.
**Instead:** import and adapt; re-derive only where Harvey's PMMU/Proc shape forces it.

### Anti-Pattern 4: Assuming `arm64` naming anywhere in-tree
**Instead:** `aarch64` everywhere (PROJECT.md decision): dir `9k/aarch64`, root `aarch64/`, `objtype=aarch64`, pcc entry key, libc dir. Toolchain program names stay `7a/7c/7l` (digit = arch family, invariant). Fix stale `build_arm64`/`objtype=arm64` references in `build/scripts/{build,linux-build}`; empty `arm64/` root dir should be removed when `aarch64/` lands.

## Integration Points

| Boundary | Communication | Notes |
|----------|---------------|-------|
| port/ ↔ aarch64/ | header triad `dat.h`/`fns.h`/`mem.h` + `io.h`; port calls fns.h exports (`touser`, `mmuswitch`, `putmmu`, `fastticks`, `intrenable`, `procsave/restore`, `coherence`…) | k10/fns.h (232 ln) is the definitive contract list — diff against it at bring-up |
| kernel ↔ libc | `9syscall/sys.h` numbers + generated SVC stubs + `ureg.h` frame | arg block from user stack; Ar0/va_list per arm64 u.h |
| kernel ↔ qemu | DTB (x0), memory map, GIC/PL011 bases | hardcode virt addresses in io.h initially (0x09000000 uart, 0x08000000 gic), DTB parse is the polish |
| kernel ↔ boot userland | embedded devroot (`mkrootall`, `addbootfile`) | boot aarch64 binaries must exist → depends on toolchain+libc phases first |
| build harness ↔ port | `build_arm64`→`build_aarch64` in build/scripts; lima-VM namespace build path unchanged | kernel build must run under the Linux namespace (lima on macOS) like k10 |

## Phase-shape implications (for the roadmap)

1. **Toolchain phase** (7a/7c/7l + pcc + arch root + libmach-later): everything else compiles through this. Import from 9front; Harvey `cc/cc.a` shared core already exists.
2. **libc aarch64 phase** (11 .s + 3 .c + u.h/ureg.h + 9syscall case): unblocks all userspace; independent of kernel phase once toolchain lands.
3. **Kernel skeleton phase**: mem.h/dat.h/fns.h/io.h + l.s + cache.v8.s + sysreg.h + minimal main (print to PL011, die cleanly) — proves entry/MMU/UART before touching port/.
4. **Kernel port phase**: mmu/trap/syscall/clock/fpu/gic/memory + config/mkfile + rootdir embedding → schedinit → shell.
5. **Stretch:** virtio (pciqemu + ethervirtio audit), SMP (mpinit/spin-table), devrtc, EFI/u-boot boot paths.

## Sources

- 9front git (primary, read via gitweb): `sys/src/9/arm64/` dir listing, `l.s`, `mmu.c`, `mem.h`, `mem.c`, `mkfile`, `qemu` config, `bcm64/mkfile`, `main.c` (bcm64) — commits 68512a3f, 12ad6dff, 404c901f, 9be64bcb [MEDIUM per seam; primary-source content]
- 9front commit dd798542 (2023-10-28, Keegan Saunders): "add arm64 qemu kernel" — qemu run line, u-boot flow [MEDIUM]
- 9front HUMANBIOLOGICS release notes (2023-11-22): generic 9/arm64 layer, qemu kernel, efi-on-arm64 [MEDIUM]
- 9front `sys/src/libc/arm64/mkfile`, `libc/9syscall/mkfile` (arm64 stub case), `arm64/include/u.h`+`ureg.h` (cinap patch 9920ecc0), `cmd/7c/mkfile`, `pcc.c` objtype table, `libmach/7.c` [MEDIUM]
- Harvey repo (read directly): `sys/src/9k/{k10,mk,port}`, `sys/src/9/bcm`, `sys/src/libc`, `build/scripts` [HIGH]
- Plan 9 compiler paper (9p.io/sys/doc/compiler.html): shared cc/ + per-arch split [MEDIUM]

---
*Architecture research for: Harvey 9k aarch64 port (qemu virt)*
*Researched: 2026-10-30*

