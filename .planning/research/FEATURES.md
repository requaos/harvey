# Feature Research

**Domain:** OS kernel port bring-up — Harvey 9k kernel to aarch64 (qemu `-M virt`)
**Researched:** 2026-10-30
**Confidence:** HIGH for in-repo facts (directly inspected) and 9front/qemu reference facts (official sources, cross-checked); MEDIUM for recipe-level details

## Minimal Shell-Boot Boundary

The milestone succeeds when **all** of these hold, in one `qemu-system-aarch64 -M virt -nographic` run:

1. Kernel image loads and executes from reset entry (EL2→EL1 drop, MMU bring-up) — boot banner printed on PL011 UART.
2. Interrupts work: GIC + ARM generic timer tick at HZ; UART RX is interrupt-driven (typing works, not just output).
3. Process model works: kernel creates proc0/init, context-switches, services `svc #0` syscalls from EL0.
4. An **embedded root filesystem** (Harvey's existing `mkrr`/paq mechanism, per `sys/src/9k/k10/mkfile` `$CONF.root.$O`) is mounted and the kernel execs `/bin/rc` from it.
5. An interactive `rc` prompt accepts commands on the UART and can run at least one builtin (`echo`) and one external binary (e.g. `ls`/`cat` — proving exec + text fault-in + syscall return path).
6. Reproducible from clean checkout via the flake/namespace build on darwin-aarch64 (lima VM) and linux — Core Value: "one command, any host."

Everything else — networking, storage, USB, SMP, FP context switching, PCIe, RTC, reboot — is outside this boundary.

## Ordered Capability List (what must land before what)

Ordering is dependency-driven; each step is verifiable in isolation before proceeding.

| # | Capability | Depends on | Verifiable milestone |
|---|-----------|------------|----------------------|
| 1 | **7a/7c/7l toolchain** in `sys/src/cmd/7?`, built as host tools (port from 9front; suites 4/5/6/8/9 already in-tree) | nothing | compile+link "hello" arm64 a.out on host |
| 2 | **arm64 libc arch dir** (`sys/src/libc/arm64`): `main9.s`/`main9p.s` startup, `setjmp.s`, `atom.s` (tas via ldxr/stxr), `getcallerpc.s`, `notejmp.c`; C fallbacks from `libc/port` cover mem* (riscv64 dir proves minimal set is ~9 files) | 1 | libc.a builds for arm64 |
| 3 | **9syscall stubs for arm64**: new case in `sys/src/libc/9syscall/mkfile` emitting `SVC` stubs with arm64 register conventions | 1, 2 | syscall stubs assemble |
| 4 | **Build wiring**: objtype root dir + mkfile (`CC=7c LD=7l O=7 AS=7a`, pattern in `arm/mkfile`), `build_arm64` func fixed (currently references nonexistent `sys/src/cmd/7?` and says `objtype=arm64` — project naming decision is `aarch64`, in-tree artifacts say `arm64`; **resolve before wiring**), namespace-build + flake app | 1 | `mk install` for libc runs in namespace build |
| 5 | **Kernel arch dir skeleton** `sys/src/9k/<aarch64-arch>/`: `mem.h`, `dat.h`, `fns.h`, `io.h`, `l.s` entry, `main.c`, `mkfile` with `CONF=virt` (k10 dir is the template; drop x86-only files: acpi/vga/apic/multiboot/realmode) | 1 | kernel links (ELF via 7l) |
| 6 | **Boot/load protocol**: qemu `-kernel` ELF load **or** raw binary at fixed address via `-device loader` (9front's `9qemu` approach: `addr=0x40200000,force-raw=on`); EL2→EL1 drop; BSS clear; stack. No bootloader, no multiboot — direct load | 5 | first instruction executes; visible via early print |
| 7 | **Early UART output**: PL011 at `0x09000000`, polled `putc` before MMU/IRQ | 6 | boot banner on serial |
| 8 | **MMU bring-up**: 4-level tables, 4K granule, 48-bit VA, TTBR0/TTBR1 split, kernel high map (k10 links at `-T0xfffffffff0110000`; 9front bcm64 uses `0xffffffffc0080000`), device-memory attrs for MMIO windows, RAM at `0x40000000` (size hardcoded per CONF — DTB/plan9.ini parsing deferred) | 7 | kernel runs at high VAs, RAM mapped |
| 9 | **Exception vectors + trap skeleton**: VBAR_EL1 table (4 EL levels × sync/irq/fiq/serror), sync handler dumps ESR/FAR/regs → panic | 8 | deliberate trap produces clean register dump |
| 10 | **GICv2 + timer**: GIC dist `0x08000000`/CPU `0x08010000` (qemu virt default is GICv2 — 9front notes `gic-version=3` must be *requested*), ARM generic timer (CNTPCT fastticks, CNTP PPI for HZ tick), `delay()` | 9 | HZ clock interrupt fires |
| 11 | **Console device**: PL011 interrupt-driven UART (RX IRQ = INTID 33), wired to portable `devcons.c`/`devuart.c` → `/dev/cons` | 10 | interactive echo path |
| 12 | **Process model arch half**: Mach/Proc setup, context switch (`forkret`/switcher in `l.s`), ureg layout, `splhi/spllo` (DAIF), tas lock, `wfi` idle; portable `proc.c`/`qlock.c`/`taslock.c` reused | 9 | kernel kprocs schedule |
| 13 | **Syscall path**: `svc #0` entry from EL0, systab dispatch (portable `sys.h`), `retregs`, errstr, notes/notify | 12 | first user syscall returns |
| 14 | **User page-fault services**: data/instruction abort from EL0 → portable `fault.c`: text demand-load from executable + stack growth (both required to exec anything); kernel fault → panic dump; icache invalidation after text load (arm64 needs explicit `ic iallu` — silent stale-icache crashes otherwise) | 13 | exec of a static binary completes |
| 15 | **User init chain**: portable `initcode.c` (`startboot`) + arm64 `init9.s` user bootstrap; exec `/boot/boot` | 14 | boot program runs |
| 16 | **Embedded root + minimal userland**: reuse `sys/src/9k/root` + `mkrr`/`$CONF.proto`; arm64 builds of `rc` + a handful of cmds (`ls`, `cat`, `echo`, `ps`) | 3, 15 | `/bin/rc` prompt on UART — **SHELL BOOT** |
| 17 | **Reproducible run target**: flake app wrapping `qemu-system-aarch64 -M virt -cpu cortex-a72 -m 512M -smp 1 -nographic -kernel …` + expect-style smoke test asserting the rc prompt (upstream CI was exactly this, on amd64) | 16 | one-command boot on macOS + linux |

**Ordering rationale:** 1–4 are pure host-side (no kernel runs) and unblock everything; 6→7→8 is the classic "print before MMU, MMU before CComfort zone" sequence — polled UART at #7 exists precisely because it is the only debug channel for #8–#10; interrupts (#10) precede console RX (#11) because devcons is IRQ-driven; user faults (#14) are separate from syscall dispatch (#13) because exec exercises both and conflating them doubles debug surface; userland (#16) is last because it needs the entire syscall/FS path.

## Feature Landscape

### Table Stakes (boot blockers — missing any = no shell)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| 7a/7c/7l Plan 9 toolchain | zero arm64 codegen exists in-tree (`sys/src/cmd` has 4/5/6/8/9 suites only) | MEDIUM | port from 9front 7* suite; vendored 9-cc `iar`/libmach headers already know arm64 (`R_MAGIC` in `a.out.h`) |
| libc arm64 primitives | every user binary links libc; startup/setjmp/tas/syscall stubs are mandatory asm | LOW | riscv64 dir shows the minimal viable file set; C fallbacks cover mem* |
| qemu virt boot protocol | kernel must be entered (EL2→EL1, MMU off, x0=DTB) | LOW | direct `-kernel`/raw load; **no bootloader** |
| PL011 polled early print | only debug channel before console driver | LOW | UART @ `0x09000000`, qemu `-serial stdio` |
| MMU 4-level tables + high kernel map | 9k is a high-half kernel; everything post-boot assumes VAs | HIGH | the port's center of gravity; 9front `sys/src/9/arm64/mmu.c` is the reference |
| Exception vector + sync trap decode | arm64 faults are useless without ESR/FAR decode | MEDIUM | panic-with-registers is sufficient at first |
| GICv2 + generic timer | no timer = no scheduler preemption; no GIC = no device IRQs | MEDIUM | qemu virt defaults to GICv2; timer is architected (PPI 30 phys / 27 virt) |
| PL011 IRQ console + devcons | interactive shell requires interrupt-driven RX | LOW | INTID 33; devcons/devuart are portable |
| Context switch + Mach/Proc arch | rfork/exec/scheduler core | HIGH | second center of gravity (with MMU switch per proc) |
| `svc` syscall path + systab | Plan 9 userspace is 100% syscalls | MEDIUM | syscallfmt/systab mostly portable |
| User fault-in (text demand-load + stack growth) | exec and rc both fault; without it nothing runs | MEDIUM | portable `fault.c`; arch half = ureg + ESR decode + icache flush |
| icache/dcache maintenance ops | arm64 has non-coherent icache; exec'd text must be invalidated | LOW | small asm, but catastrophic if forgotten |
| Embedded root fs (mkrr/paq) | no block device in v1 — root must be in-kernel | LOW | mechanism exists (`k10root`, `sys/src/9k/root`, `mkrr`); needs arm64 proto |
| arm64 `rc` + minimal cmds | the "shell" itself | LOW | rc is portable C; risk is upstream cmd-chain breakage (see Anti-Features note) |
| objtype/build wiring + flake run target | Core Value is reproducible one-command boot | LOW | `build_arm64` exists but is stale (`7?` dirs missing, `arm64` vs `aarch64` naming) |

### Differentiators (deferrable polish — valuable, not boot blockers)

| Feature | Value Proposition | Complexity | Deferral rationale |
|---------|-------------------|------------|--------------------|
| virtio-9p host mount | fast dev loop: edit userland on host, no kernel/root rebuild | MEDIUM | strongest candidate to pull *into* v1.x early; not needed to prove shell boot |
| FP/SIMD context switching | user binaries using floats work correctly under preemption | MEDIUM | rc + integer cmds never touch FP; leave CPACR enabled, no save/restore; document "FP binaries unsupported in v1" |
| SMP (PSCI cpu-on, IPI, TLB shootdown) | multi-core | HIGH | `-smp 1` proves the scheduler; SMP adds Heisenbugs while basics are still being debugged |
| virtio-net + IP stack | networking (devip is portable C) | HIGH | needs virtio-mmio (`0x0a000000`, 32 slots) or PCI transport + driver; shell doesn't need net; amd64 `ethervirtio.c` exists as later reference |
| virtio-blk / devsd storage | persistent filesystem, fossil/venti | HIGH | embedded root removes the need; storage is its own milestone |
| PCIe ECAM scan + MSI/ITS | real device topology | HIGH | no PCI device is needed on virt for a shell; note newer virt puts ECAM high (`0x40_1000_0000`) — 9front pins `virt-2.12` partly for this |
| GICv3 | more CPUs, MSIs later | LOW | qemu virt defaults to GICv2; v2 driver is smaller; v3 needed only with ITS/MSI |
| PSCI reboot/poweroff | `reboot` command works | LOW | ~20 lines of HVC; stretch goal for v1, else halt in `wfi` loop and kill qemu from host |
| PL031 RTC / wall-clock time | correct `date` | LOW | kernel timebase works from generic timer; epoch can be wrong in v1 |
| ASID-tagged TLB | performance | LOW | full flush on mmuswitch is correct, just slower — irrelevant at this scale |
| plan9.ini / bootargs / DTB parsing | runtime config instead of compile-time CONF | MEDIUM | hardcode `ncpu=1`, maxmem in CONF for v1 |
| libmach/acid arm64 debugging | symbolic kernel debugging | MEDIUM | nm/size for 7l objects are near-free (headers already in vendored libmach); full acid deferrable |
| 64K granule, 52-bit VA, LSE atomics, PAN | perf/security hardening | MEDIUM | target ARMv8.0 baseline (`-cpu cortex-a72`); ldxr/stxr atomics suffice |

### Anti-Features (explicitly out for the first port milestone)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Hardware targets (RPi4 etc.) | "real" port proof | different firmware/boot/irq/timer matrix (mailbox, GIC-400 vs bcm2835, mini-UART) doubles the surface; PROJECT.md already excludes | qemu virt only; hardware is a follow-on milestone reusing this port's arch dir |
| Bootloader chain (9boot/U-Boot/multiboot) | matches amd64 flow; needed for hardware | pure overhead under qemu direct kernel load; k10's multiboot.c is x86-only anyway | `-kernel` ELF or `-device loader` raw (9front 9qemu pattern) |
| Full cmd/ userland parity | "real system" feel | upstream amd64 cmd chain is already broken (`cc` rgbycc, `4a` lex.c, ipconfig/venti never install — PROJECT.md); importing that breakage into the port milestone conflates two efforts | minimal embedded root (rc + ~5 cmds); full-cmd green is the separate build-tail effort |
| Porting/merging legacy `sys/src/9` tree | one kernel tree | dedup is a tracked non-goal (PROJECT.md); 9k port files are portable enough | port 9k only; reuse 9front's *generic* `sys/src/9/arm64/` as reference, not its kernel layout |
| AArch32 (32-bit EL0) compat | run existing arm binaries | second ureg/syscall/exec path; zero Harvey arm32 userland exists for 9k | 64-bit EL0 only |
| Framebuffer/graphics console (devdraw, virtio-gpu) | rio/acme demos | -nographic UART milestone; drawterm exists for later GUI access | serial console only |
| TLS/security modernization | needed eventually | orthogonal hardening milestone (PROJECT.md) | defer wholesale |
| Swap/paging beyond Plan 9 norms | "real VM" | Plan 9 never swaps; text fault-in + stack growth suffice and are already table stakes | none needed |

## Feature Dependencies

```
7a/7c/7l toolchain
    ├──requires nothing (host tools, first phase)
    ├──> libc arm64 ──> 9syscall arm64 stubs ──> userland (rc, cmds)
    └──> kernel arch dir skeleton
            └──> boot protocol (entry, EL2→EL1)
                    └──> polled PL011 print
                            └──> MMU bring-up
                                    └──> exception vectors/trap decode
                                            ├──> GICv2 + generic timer
                                            │       └──> IRQ console (devcons)
                                            └──> process model (switch/Mach)
                                                    └──> syscall path (svc)
                                                            └──> user faults (exec/stack)
                                                                    └──> init chain ──> embedded root ──> /bin/rc  == SHELL

virtio-9p ──enhances──> dev loop (post-shell)
SMP ──requires──> PSCI + GIC (v2 fine) ──conflicts-with──> early debugging simplicity
FP save/restore ──requires──> trap decode + context switch (defer past both)
```

### Dependency Notes

- **Toolchain before everything:** Plan 9 kernels build with their own compiler suite; there is no gcc/clang path for 9k (Plan 9 C dialect, a.out format). This makes 7a/7c/7l the critical-path item #1 even though no kernel code runs.
- **libc before userland, not before kernel:** the kernel is freestanding (own mem.c, print.c); libc is only needed for initcode and commands. Kernel bring-up (#5–#14) can proceed in parallel with libc/userland work once the toolchain exists.
- **Polled UART before MMU:** every successful arm64 bring-up (9front imx8/bcm64/qemu, rcarmo's A733 port notes) establishes serial output first; it is the debug channel for all later steps.
- **MMU before trap/console/scheduler:** high-half jump must happen before portable C subsystems come up.
- **GIC+timer before devcons:** devcons input is interrupt-driven; a polling console hack is possible but the IRQ path is required anyway — do it once.
- **Text fault-in + stack growth before any exec:** portable `fault.c` does the work, but the arch half (ureg, ESR decode, icache flush) must exist; rc cannot start without it.
- **Embedded root independent of block devices:** removing storage from the critical path is the single biggest scope reduction available; k10f/k10cpuf already prove the pattern on amd64.

## MVP Definition

### Launch With (v1 = "boots to shell on qemu virt")

- [ ] 7a/7c/7l + libc arm64 + 9syscall stubs + objtype wiring — toolchain/libc prerequisites
- [ ] Kernel: entry/EL drop, polled PL011, MMU high-half, vectors/trap decode, GICv2, generic timer
- [ ] devcons + IRQ UART console
- [ ] Process model + `svc` syscalls + user fault-in (text/stack) + icache maintenance
- [ ] Embedded root with rc + minimal cmds; boot to interactive prompt
- [ ] One-command flake run + boot smoke test

### Add After Validation (v1.x)

- [ ] virtio-9p host mount — first post-shell item; collapses userland iteration time
- [ ] FP/SIMD context switching — trigger: first userland binary needing floats (bc, awk float paths)
- [ ] PSCI reboot/poweroff — trigger: smoke-test ergonomics
- [ ] plan9.ini/bootargs or minimal DTB parse — trigger: >1 CONF or memory-size experiments
- [ ] GICv3 support — trigger: `-cpu host`/hvf on macOS (hvf exposes GICv3)

### Future Consideration (v2+)

- [ ] SMP — needs its own milestone (PSCI, IPI, TLB shootdown)
- [ ] virtio-net + IP — networking milestone (drawterm/rcpu access)
- [ ] virtio-blk + fossil/venti — storage milestone
- [ ] Hardware aarch64 (RPi4) — new arch-* dir reusing this port
- [ ] 9boot/EFI boot path for hardware
- [ ] ASIDs, LSE, PAN — perf/hardening pass

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| 7a/7c/7l toolchain | HIGH (blocks all) | MEDIUM | P1 |
| libc arm64 + syscall stubs | HIGH | LOW | P1 |
| Boot entry + polled UART | HIGH | LOW | P1 |
| MMU high-half | HIGH | HIGH | P1 |
| Trap/GIC/timer | HIGH | MEDIUM | P1 |
| Console (devcons+UART IRQ) | HIGH | LOW | P1 |
| Process model + syscall path | HIGH | HIGH | P1 |
| User fault-in + icache | HIGH | MEDIUM | P1 |
| Embedded root + rc userland | HIGH | LOW | P1 |
| Flake run + smoke test | HIGH | LOW | P1 |
| virtio-9p mount | MEDIUM | MEDIUM | P2 |
| FP context switching | MEDIUM | MEDIUM | P2 |
| PSCI reboot | LOW | LOW | P2 |
| DTB/plan9.ini parsing | LOW | MEDIUM | P2 |
| SMP | MEDIUM | HIGH | P3 |
| virtio-net/storage, PCIe | MEDIUM | HIGH | P3 |
| GICv3, ASID, LSE, PAN | LOW | MEDIUM | P3 |

## Reference Port Analysis

| Capability | 9front arm64 (bcm64/imx8/qemu) | Harvey k10 amd64 (in-tree) | Our Approach |
|------------|-------------------------------|----------------------------|--------------|
| Toolchain | mature 7a/7c/7l in `sys/src/cmd/7*` | 6a/6c/6l in-tree; no 7* | port 9front 7* suite into `sys/src/cmd/7?` |
| Generic arch code | shared `sys/src/9/arm64/` (mmu.c, trap.c, fpu.c, cache.v8.s, sysreg, init9.s) since 2023 | n/a (x86 only) | primary reference for arm64 kernel code; adapt into new 9k arch dir |
| qemu virt kernel | `9qemu`: raw binary, `-bios u-boot.bin` or `-device loader,addr=0x40200000`; GICv3 assumed; virtio PCI drivers | n/a | same direct-load idea, but GICv2 (qemu default), no virtio, no U-Boot |
| Embedded root | `$CONF.root` via mkdevlist/bootmkfile | `mkrr` + `root/$CONF.proto` + paq — proven by k10f/k10cpuf | reuse Harvey's existing mkrr/paq path unchanged |
| Console | UART drivers per-SoC (pl011 on pi4, miniuart on pi3, aw on A733) | uarti8250 (386 dir) | new PL011 driver (~200 lines) + portable devcons |
| Boot config | plan9.ini passed via loader addr (no DTB parsing) | multiboot command line | compile-time CONF first; parsing deferred |

## Sources

- In-repo (HIGH, directly inspected): `sys/src/cmd` (suites 4/5/6/8/9, no 7*), `sys/src/libc/arm` + `libc/riscv64` (minimal arch-dir file set), `sys/src/libc/9syscall/mkfile` (per-arch stub generation), `sys/src/9k/k10/mkfile` (mkrr embedded root, high-half link), `sys/src/9k/boot` (paq/embed boot chain), `sys/src/9k/port/initcode.c` (`startboot`), `build/scripts/linux-build` (`build_arm64` referencing missing `cmd/7?`, `objtype=arm64`), root `arm64/` (empty `bbin` only — upstream started wiring, never finished), `arm/mkfile` (`CC=5c` pattern), vendored `sys/src/cmd/unix/9cc` (iar + libmach headers incl. arm64 `R_MAGIC`)
- 9front (HIGH, official git + release notes): "HUMANBIOLOGICS" release (2023-11) — generic `sys/src/9/arm64/`, arm64 qemu kernel, arm64 EFI loader; bcm64 mkfile (`loadaddr=0xffffffffc0080000`, `objtype=arm64`, `-H6` raw link); qemu kernel commit (U-Boot / `-device loader`, `gic-version=3`, virtio)
- qemu virt platform (HIGH, qemu docs / coreboot addressmap / zephyr dts, cross-checked): PL011 @ `0x09000000` INTID 33, GIC dist `0x08000000` / CPU `0x08010000`, RAM `0x40000000`, virtio-mmio `0x0a000000` (32×0x200, INTID 48+n), PCIe ECAM low `0x3f000000` (old) / high `0x40_1000_0000` (new virt), PL031 RTC `0x09010000`
- wiki.9front.org QEMU arm64 page (MEDIUM): `virt-2.12` ECAM caveat, "QEMU defaults to GICv2" note, `-device loader` recipe, plan9.ini-instead-of-DTB approach
- rcarmo 9front A733 bring-up notes (MEDIUM): corroborates serial-first ordering and MMU/IRQ setup-order pain points

---
*Feature research for: Harvey 9k aarch64 kernel port bring-up*
*Researched: 2026-10-30*
