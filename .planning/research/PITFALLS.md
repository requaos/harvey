# Pitfalls Research

**Domain:** Dormant Plan 9-family OS revival + aarch64 (ARM64) port to qemu `-M virt`
**Researched:** 2026-10-30
**Confidence:** HIGH for in-tree findings (direct file reads); HIGH for qemu-virt behavior (official QEMU docs); MEDIUM for Plan 9 ecosystem history (web sources, partially cross-checked)

**Scope note:** This file is the risk burn-down input for the roadmap. Pitfalls are ordered so that the ones which can *sink the milestone* are addressed in the earliest phases; chores come last. Every pitfall names the Harvey tree paths where it lives.

## Risk Ranking at a Glance

| # | Pitfall | Blast radius | Sink risk? | Where it lives |
|---|---------|--------------|------------|----------------|
| 1 | Compile-and-run generators assume self-hosting Plan 9 | Whole cmd chain → kernels won't link | **YES — blocks milestone requirement "full 9k amd64 set green"** | `sys/src/cmd/jpg/mkfile`, `sys/src/cmd/awk/mkfile`, `unix/mkfile` |
| 2 | Embedded-root kernels silently depend on userland install order | k10cpuf/k10f fail late, confusingly | **YES — same requirement** | `sys/src/9k/k10/k10cpu` (rootdir), `sys/src/9k/mk/parse`, `sys/src/9k/mk/mkrootall` |
| 3 | riscv64-style scaffolding-first port (headers without toolchain) | aarch64 port dies as vaporware | **YES — the project's own precedent** | `riscv64/`, `sys/src/libc/riscv64/`, `sys/src/mkfile.proto` |
| 4 | arm64↔aarch64 naming collision with vestigial in-tree scaffolding | Half-bound dirs, wrong mkfiles, ecosystem impedance | High (chronic drag, easy to botch) | `arm64/` (empty `bbin/`), `build/scripts/build:76`, `build/scripts/linux-build:63`, `build/mkdirs:264` |
| 5 | Boot-protocol mismatch: multiboot doesn't exist on aarch64 | Kernel never reaches `main()` | **YES — first boot** | `sys/src/9k/k10/main.c:145`, `sys/src/9k/k10/l32p.s`, `sys/src/9k/k10/l64v.s` |
| 6 | qemu `-M virt` defaults (32-bit CPU, drifting GIC/layout) | "Kernel does nothing" with zero diagnostics | Medium (days lost, not weeks) | run scripts / nix qemu invocation |
| 7 | MMU/VA-layout + cache maintenance on arm64 | Hangs before first `print()` | **YES — first boot** | new `sys/src/9k/<aarch64 mach dir>` |
| 8 | No console until PL011+GIC+generic-timer triple works | Debugging blind | Medium | new mach dir, `sys/src/9k/port/devuart.c` |
| 9 | 7c/7a/7l ported from stale 5c lineage instead of 9front's live 7c | Re-imports decade-old fixed bugs | High | `sys/src/cmd/5?`, `sys/src/cmd/cc/` |
| 10 | libc arch-dir minimal contract (tas/setjmp/main9/notejmp) | Everything links, nothing runs | High | `sys/src/libc/riscv64/` (template), `aarch64` equivalent to create |
| 11 | `u.h`/`ureg.h` ABI mismatch between libc and kernel trap frame | Corrupted notes/forkret — worst debug class | High | `riscv64/include/u.h` (pattern), `amd64/include/ureg.h` |
| 12 | 9front bcm64 reference targets `sys/src/9/` layout, not 9k | Copy-paste port doesn't fit mk machinery | Medium | `sys/src/9k/mk/parse` vs 9front `/sys/src/9/bcm64` |
| 13 | TLS 1.2 cap + SSL3 floor + NULL/RC4/DES ciphers | Deferred milestone, but "ported ≠ validated" | Medium (scope creep risk) | `sys/src/libsec/port/tlshand.c:143-267`, `sys/src/9k/port/devtls.c:27-33` |
| 14 | mk quirks: pipe-includes, generated files, `cputype=unix` pseudo-arch | Non-reproducible/stale builds | Medium | `sys/src/9k/k10/mkfile:11`, `sys/src/mkfile.proto`, `nix/build.sh:12-13` |
| 15 | Go unsupported on plan9/arm64 | Image-shipped Go cmds can't exist on aarch64 | Low (scope, not correctness) | `sys/src/cmd/go/commands`, `.github/workflows/harvey.yml` |

---

## Critical Pitfalls

### Pitfall 1: Compile-and-run generators assume a self-hosting Plan 9 host

**What goes wrong:**
Several mkfiles compile a C generator with the *target* toolchain and then **execute the freshly linked binary** to emit a generated header. The canonical failure observed this milestone: `sys/src/cmd/jpg/mkfile:56-68` derives a tool prefix from the host pseudo-arch — `c=`{sed -n 's/^O=//p' /$cputype/mkfile}` — then runs `$c^c rgbycc.c; $c^l -o $c.rgbycc rgbycc.$c; $c.rgbycc > ycbcr.h`. The namespace build exports `cputype=unix` (`nix/build.sh:13`), and `unix/mkfile` sets `O=o`, so the recipe literally invokes **`oc`** — a compiler that does not exist. The cmd build chain aborts there (`sys/src/cmd/mkfile:34-38` iterates `cc $DIRS` in `ls` order; `jpg` precedes `ip/`, `venti/`, …), so `ipconfig` and `venti` never reach `/amd64/bin`, which then detonates Pitfall 2. Same shape in `sys/src/cmd/awk/mkfile:42-50` (`maketab` builds with the *cputype* compiler then runs `./$cputype.maketab > proctab.c`), and fossil's own build script admits the coupling: `sys/src/cmd/fossil/build:9` — "so awk can be cross-compiled (needs to run pcc for maketab)". `sys/src/cmd/cc/mkfile` additionally depends on yacc output (`y.tab.$O`, `YFILES=cc.y`) and cross-dir sources (`sys/src/cmd/4a/mkfile:19`: `lex.$O: ../cc/macbody ../cc/lexbody ../cc/compat`), the `4a lex.c bind` half of the observed failure.

**Why it happens:**
These mkfiles were written for native Plan 9 builds where host == target == `$cputype`, so "compile a tool and run it" is free. Under the Unix-hosted namespace build (`nix/build.sh` → `RUN_BUILD_IN_PRIVATE_NAMESPACE`), target binaries are Plan 9 a.out — unrunnable on Linux — and `$cputype=unix` is a pseudo-arch whose `O=o` produces nonsense tool names. The build's error surfaces as a missing command (`oc`), not as "you are cross-compiling a generator," so the root cause is disguised.

**How to avoid:**
Introduce an explicit host-tool rule: generators (`rgbycc`, `rgbrgbv`, `maketab`, anything matching `grep -rn '\$c\^c' sys/src/cmd/*/mkfile`) build with the host compiler (`pcc`, already in `HARVEY_LINUX_BIN`) into `.build/hostbin-<os>-<arch>` and run natively. Never derive tool names from `$cputype` in generator recipes. Add a preflight in `nix/build.sh`: after the cmd phase, assert `/amd64/bin/ip/ipconfig`, `/amd64/bin/auth/factotum`, and venti binaries exist before any kernel `mk` runs.

**Warning signs:**
`o^c`-style concatenated command names in build logs; "not found" errors for tool names that aren't real (`oc`, `ol`); generated headers (`ycbcr.h`, `proctab.c`, `y.tab.h`) stale or zero-length after a "successful" build.

**Phase to address:**
The build-revival phase (9k amd64 green). This is the current blocker — burn down first.

---

### Pitfall 2: Embedded-root kernels silently depend on userland install order

**What goes wrong:**
`sys/src/9k/k10/k10cpu` (and k10cpuf/k10f) declare a `rootdir` section embedding `/amd64/bin/auth/factotum`, `/amd64/bin/ip/ipconfig`, `bootk10cpu.out`, and `../root/nvram` *into the kernel binary*. The awk generator `sys/src/9k/mk/parse` (`mkrootrules`, lines 466-478; rule emission lines 97-108) turns each entry into a dependency of `$CONF.root.s`, produced by `sys/src/9k/mk/mkrootall`. If the cmd chain (Pitfall 1) aborted before installing ipconfig/factotum, the kernel build fails at the *root-embedding* step — a different directory, a different tool, minutes later. `k10cpu` (non-embedded) already builds green (validated), which makes the k10cpuf/k10f failures look like a kernel problem when they are a userland-ordering problem.

**Why it happens:**
The config-file → awk → mk-rule pipeline hides a cross-tree dependency (`sys/src/9k/k10` ← `/amd64/bin/*`) that no mkfile declares explicitly. mk's error names the missing file but not *why* it was never installed.

**How to avoid:**
Treat "embedded-root kernels build" as a *postcondition* of the cmd-chain fix, not a separate bug. Verify in order: (1) cmd chain completes with zero aborts, (2) `/amd64/bin/ip/ipconfig` + `/amd64/bin/auth/factotum` exist, (3) `mk CONF=k10cpuf install`. Add the preflight assertion from Pitfall 1 to make the ordering explicit in CI.

**Warning signs:**
Kernel build fails inside `mkrootall`/`$CONF.root.s` rules; `ls /amd64/bin/ip/` empty after a "green" userland build.

**Phase to address:**
Build-revival phase, immediately after Pitfall 1. Same phase, same verification run.

---

### Pitfall 3: Scaffolding-first port death (the riscv64 precedent)

**What goes wrong:**
Harvey's own `riscv64/` is the cautionary tale, in-tree and undeniable: the arch dir contains only `include/` (`u.h`, `ureg.h`, `ape/`) and a 5-line `mkfile` naming **`jc`/`jl`/`ja`** — a toolchain that *was never committed* (`sys/src/cmd/` has `4a 4c 4l 5a 5c 5i 5l 6a 6c 6l 8a 8c 8l 9a 9c 9l`, no `j*`). `sys/src/libc/riscv64/` carries the minimal ~10-file libc set with all `mem*.s` commented out. `sys/src/mkfile.proto:6` nonetheless lists `riscv riscv64` in `CPUS`, so `installall` targets reference a port that cannot compile a single file. Result: dead scaffolding that greps, tars into `harvey.tgz`, and teaches contributors that "ports here are aspirational."

**Why it happens:**
Committing headers/mkfiles first *feels* like progress and is easy to review, but without the toolchain there is no feedback loop, so the scaffolding rots in place. The dependency order for a real port is strict: **assembler+compiler+linker → libc arch dir → arch mkfile+include → kernel mach dir**. Harvey's riscv64 did it backwards.

**How to avoid:**
For aarch64, enforce the gate: `7a` assembles and `7l` links a hello-world (run under qemu user-mode or on the 9k kernel test harness) *before* `aarch64/mkfile`, `aarch64/include/`, or `sys/src/libc/aarch64/` are committed. Add aarch64 to `CPUS` in `sys/src/mkfile.proto` **last**, only when `installall` can survive it. The riscv64 dirs should be quarantined or deleted in the same phase to stop them setting the pattern.

**Warning signs:**
An arch dir whose mkfile names tools absent from `sys/src/cmd/`; `CPUS` entries without a matching `sys/src/libc/<arch>/` that builds.

**Phase to address:**
Toolchain phase (7a/7c/7l + libc). Flag the riscv64 quarantine as a build-revival-phase chore.

---

### Pitfall 4: arm64↔aarch64 naming collision with vestigial scaffolding

**What goes wrong:**
The tree already contains `arm64` debris: an `arm64/` root dir holding only an empty `bbin/`, `build_arm64` functions in both `build/scripts/build:76-80` and `build/scripts/linux-build:63-67` (`for(i in /sys/src/cmd/7?)` — directories that don't exist — and `objtype=arm64`), and `build/mkdirs:264` (`./arm64/bbin`). The project decision (2026-10-30, PROJECT.md) is **`aarch64`** naming. Meanwhile the entire upstream ecosystem (9front `arm64/mkfile`: `CC=7c LD=7l AS=7a O=7`) calls it `arm64`. Three collision risks: (a) a namespace bind or `mkdirs` run resurrects `/arm64` and mkfiles include the wrong arch mkfile; (b) porters import 9front patches and forget the rename, producing mixed `arm64`/`aarch64` paths; (c) `build_arm64` looks runnable but is a no-op-at-best (glob `cmd/7?` matches nothing, `mk` against a nonexistent `/arm64/mkfile` fails).

**Why it happens:**
Two conventions collided in one tree and the rename decision post-dates the scaffolding.

**How to avoid:**
In the first phase that touches arch wiring: rename/remove `arm64/` and `build_arm64` (or rewrite them to `aarch64` + real 7-series dirs), update `build/mkdirs`, and write the mapping "7c/7a/7l, objtype=aarch64" into the phase plan so every imported 9front reference is renamed on entry. Keep tool *letters* (7a/7c/7l) identical to 9front — only the objtype string differs.

**Warning signs:**
`/arm64` appearing in namespace listings; mk errors including `</arm64/mkfile`; any new file with `arm64` in its path.

**Phase to address:**
Toolchain phase, first task (before any 7c import). Cheap now, expensive after references accumulate.

---

### Pitfall 5: Boot-protocol mismatch — multiboot does not exist on aarch64

**What goes wrong:**
The k10 kernel's entry contract is x86 multiboot: `main(u32int ax, u32int bx)` at `sys/src/9k/k10/main.c:145`, reached via `l32p.s` (protected mode) → `l64v.s` (long mode), normally chain-loaded by the EFI loader (`sys/src/boot/efi/`) or a multiboot loader. On qemu aarch64 there is no multiboot. `-kernel` offers exactly two contracts (QEMU virt doc): an **ELF file** loads as "bare-metal" — jumped to at its ELF entry with the DTB placed at the start of RAM (`0x40000000`); a **raw non-ELF image** must carry the arm64 Linux boot protocol header (`ARM\x64` magic at offset 0x38, `text_offset`, entered with MMU off, DTB pointer in `x0`). A Harvey aarch64 kernel built as a flat Plan 9 a.out will be treated as a raw Image and fail the magic check (or worse, jump into header bytes).

**Why it happens:**
"Boot the kernel" means something different per architecture; the k10 flow's assumptions (multiboot params, `plan9.ini` via CONFADDR — the `sys/src/9k/k10/crap.c` parser) have no aarch64 analog until one is designed.

**How to avoid:**
Decide the contract *in the plan*: simplest is ELF via `-kernel` (7l already emits ELF with `-H5` on amd64 — verify 7l supports the same on aarch64), DTB read from `0x40000000`, entry at EL1/EL2 with MMU off per QEMU's ELF boot. Defer `plan9.ini` parsing; pass a fixed boot line initially. Write the entry asm (`l64`-equivalent) to: mask interrupts, read `CurrentEL`, drop EL2→EL1 if needed, set up a stack, clear BSS, then call C `main()`.

**Warning signs:**
qemu exits instantly or spins with `-d int` showing no guest instruction progress; "magic" check failures for raw images.

**Phase to address:**
Kernel bring-up phase — this is its first design decision, not an implementation detail.

---

### Pitfall 6: qemu `-M virt` defaults actively mislead

**What goes wrong:**
Two defaults burn newcomers (QEMU virt doc, confirmed): (1) **default CPU is `cortex-a15`, a 32-bit CPU** — an aarch64 kernel simply won't run and the symptom is "nothing happens"; you must pass e.g. `-cpu cortex-a72`. (2) `virt` is a *versioned* board: device addresses other than RAM (`0x40000000`) and flash (`0x0`) may move between QEMU releases, and GIC version defaults shift (`gic-version` 2 vs 3; v2 caps at 8 CPUs). Hardcoding UART/GIC/virtio-mmio addresses from one qemu's `dumpdtb` produces a kernel that breaks on the next nix bump.

**Why it happens:**
`virt` is designed for Linux guests that read the DTB; bare-metal porters tend to hardcode addresses from a tutorial written against one qemu version.

**How to avoid:**
Pin qemu via the nix flake (already the project's mechanism) and pin `-cpu` and `-machine virt,gic-version=2` (GICv2 matches both the bcm64 reference code and the simplest programming model). Parse the DTB for PL011/GIC/virtio-mmio addresses — DTB parsing is a small, well-understood amount of code and pays for itself the first time qemu moves a window. Keep `dumpdtb` output in-tree as a test fixture for the exact pinned qemu version.

**Warning signs:**
"Works on my qemu" divergence between darwin-aarch64 (HVF) and linux (KVM/TCG) hosts; boot breaks after nix flake bump.

**Phase to address:**
Kernel bring-up phase (run-script design) — but the `-cpu` gotcha should land in the *earliest* qemu smoke test, even before the kernel exists (boot a known-good ELF like a 9front arm64 kernel to validate the harness).

---

### Pitfall 7: MMU/VA layout and cache maintenance — hang before the first print

**What goes wrong:**
k10 links at `-T0xfffffffff0110000` (`sys/src/9k/k10/mkfile:21`) and its mmu.c builds x86 page tables. aarch64 needs the whole model redesigned: TTBR0/TTBR1 split (kernel high half), TCR/MAIR attribute setup, granule choice (4K), and — the classic silent killer — **cache maintenance**: writes to page tables and freshly-written instructions need `DC CVAC` / `IC IVAU` + barriers (`DSB`/`ISB`) or the MMU/CPU sees stale data. Early boot code that "should work" produces a hung core with zero output. Plan 9's allocator and driver code also assume a simple cached/uncached split that on arm64 is expressed via MAIR attributes, not address windows.

**Why it happens:**
x86 is cache-coherent and forgiving; arm64 is not. Porters bring x86 assumptions to TLB/page-table code.

**How to avoid:**
Steal the sequence, not the instructions: follow 9front bcm64's `mmu.c`/`l.s` boot order (they solved MAIR/TCR/TTBR for a GIC-400/PL011 machine — the closest analog to `virt,gic-version=2`). Bring up **UART before MMU** (PL011 is 4 registers, polling mode), get `print()` working physical-only, then enable MMU. Instrument with qemu `-d int,guest_errors` and an early `wfi`-less spin loop marker.

**Warning signs:**
Boot proceeds until MMU-enable (`SCTLR_EL1.M=1`) then instant halt; or works under TCG but not HVF/KVM (cache/CoI differences expose missing barriers).

**Phase to address:**
Kernel bring-up phase — the core of it. Needs deeper phase-specific research (bcm64 mmu.c walkthrough).

---

### Pitfall 8: The console/interrupt/timer triple (PL011 + GIC + ARM generic timer)

**What goes wrong:**
Until three machine services work, the kernel is undebuggable and dead: PL011 UART (console out), GIC distributor+CPU interface (any interrupt), and the ARM generic timer (`CNTPCT_EL0`/`CNTP_EL0` + per-CPU timer PPI) replacing k10's i8254/APIC clock (`sys/src/9k/k10/i8254.c`, `apic.c`). x86 brings these up in a different order with different probing; arm64 has no BIOS/ACPI tables on the default virt boot unless you add EDK2 — device discovery is DTB or nothing. A partial bring-up (UART yes, timer no) looks like a scheduler bug in `sys/src/9k/port/proc.c` and sends debugging in the wrong direction.

**Why it happens:**
The three are separable but their *absence* has identical symptoms (hang after banner).

**How to avoid:**
Stage-gate explicitly: (1) polled UART print, (2) timer interrupt firing at known Hz (print a counter), (3) GIC passing a virtio-mmio or UART IRQ, (4) only then `procinit0`/scheduling. Keep k10's defensive pattern (`2022-01-26 rdmsr: Don't panic on user GPF`) — log-and-continue over panic during bring-up.

**Warning signs:**
Banner prints then silence; `sched()` never reached; interrupts arrive at wrong EL.

**Phase to address:**
Kernel bring-up phase, ordered before any driver/port work.

---

### Pitfall 9: Porting 7c from Harvey's stale 5c lineage

**What goes wrong:**
The obvious move — copy `sys/src/cmd/5c` (32-bit ARM) into `7c` and widen it — re-imports every bug 9front fixed while *writing and then maintaining* their arm64 7c (2016-present): 64-bit constant folding, register allocation around call clobbers, floating-point ABI, linker relocations for ADRP/ADD+ldr pairs. Harvey's `5c` diverged from Bell's in 2015-era and shares the common frontend `sys/src/cmd/cc/` (whose `everything:V` target lists `CURCC=5c 6c 8c qc vc` — note **no 7c**, line 26). The shared `cc` frontend itself has the yacc-generation fragility of Pitfall 1.

**Why it happens:**
In-tree code feels safer than an import ("we control it"), but here the in-tree version is the *older, buggier* one for this architecture.

**How to avoid:**
Vendor 9front's `7c/7a/7l` (and their `cc/` frontend diffs if any) as the starting point — the same vendor-and-own strategy already proven with `sys/src/cmd/unix/9cc/` (9-cc `iar` subset, logged decision). Check license headers on import (9front is Lucent/MIT-lineage like Harvey, but verify file-by-file). Add `7c` to `cc/mkfile`'s CURCC only after it builds. Budget: the compiler is the *largest single chunk* of the toolchain phase — treat as the phase's critical path, not a warm-up.

**Warning signs:**
Miscompiled `setjmp`/`notejmp` or varargs code at `-O`-equivalent levels; hello-world works but `libthread` corrupts stacks (classic code-generator edge).

**Phase to address:**
Toolchain phase — critical path. Needs deeper phase-specific research (diff 9front 7c vs Harvey 5c; import plan).

---

### Pitfall 10: libc arch-dir minimal contract — "links but doesn't run"

**What goes wrong:**
`sys/src/libc/mkfile:8-12` builds `$PORTDIRS $objtype` — so `sys/src/libc/aarch64/` must exist and be *correct* before any userland links. The minimal set (per the riscv64 skeleton, which at least shows the shape): `argv0.s`, `atom.s`, `getcallerpc.s`, `getfcr.s`, `main9.s`, `main9p.s`, `setjmp.s`, `tas.s`, `_seek.c`, `notejmp.c`. The dangerous two: **`tas.s`** (test-and-set underpins every `qlock`/refcount — on arm64 must use `LDAXR`/`STLXR` with correct acquire/release semantics; weak-memory-order bugs here are intermittent corruption under SMP, not clean failures) and **`notejmp.c`/`setjmp.s`** (must match the kernel's `Ureg` layout exactly — see Pitfall 11). `main9.s` sets up the argc/argv ABI and ` Tos`/profiling hand-off; a wrong register convention makes `main(argc, argv)` see garbage *sometimes*.

**Why it happens:**
These files are small (10–40 lines of asm), so they're treated as trivial; they are actually the ABI.

**How to avoid:**
Port `tas`/`setjmp`/`notejmp`/`main9` from 9front's `libc/arm64` (verified-working ABI) rather than writing from ARM docs. Test `tas` under qemu with `-smp 4` hammering a lock before trusting it. Keep mem*/str* in portable C initially (riscv64 pattern) — hand asm memcpy is a later optimization.

**Warning signs:**
Intermittent hangs only under `-smp`; `libthread` channels losing messages; faults in `noted`.

**Phase to address:**
Toolchain phase (second half, after 7c can compile them).

---

### Pitfall 11: `u.h`/`ureg.h` — the kernel↔libc ABI contract

**What goes wrong:**
Each arch root dir carries `include/u.h` (types, `jmp_buf` layout, FP control bits — see `riscv64/include/u.h` for the pattern) and `include/ureg.h` (trap frame). The kernel's `trap.c`/`l*.s` build a `Ureg` on trap/syscall; libc's `notejmp.c` and `libmach` decode it; `sys/src/9k/k10/mkfile:46-51` shows the amd64 kernel compiles against `/$objtype/include/ureg.h`. If the assembler stub's stack layout and the struct disagree by even one field, notes corrupt state and `rfork` children return with wrong registers — the hardest class of bug in the tree to diagnose.

**Why it happens:**
Two files, written at different times, both "obviously" matching a mental model.

**How to avoid:**
Write `ureg.h` and the trap-entry asm *in the same commit*, with a static assertion (`typedef char uregcheck[(sizeof(Ureg)==EXPECTED)?1:-1]`) and a comment pinning field offsets; boot-test `rfork`+notes as the first userland milestone after shell. 9front `arm64/include/ureg.h` + `bcm64/trap.c` are the reference pair — port them together.

**Warning signs:**
`sys: trap:` notes with nonsense PC; `await`/`wait` returning corrupted status; acid stack traces that don't terminate.

**Phase to address:**
Kernel bring-up phase (trap path) — but the *headers* land in the toolchain phase with libc. Sequence them as one logical unit.

---

### Pitfall 12: The reference port (9front bcm64) doesn't match Harvey's kernel tree layout

**What goes wrong:**
9front's arm64 kernel is `sys/src/9/bcm64` — the **legacy-tree** layout. Harvey's canonical kernel is `sys/src/9k/` with its own config→codegen machinery (`sys/src/9k/mk/parse` awk emitting `devtab`, `systab` from `/sys/src/libc/9syscall/sys.h`, `rootdir` embedding, `+dev` section tags, `dbgflg` tables — see `k10cpu` and `parse:284-463`). A bcm64 file dropped into a 9k mach dir does not compile: header triad differs (`dat.h`/`fns.h`/`mem.h` split), `Ar0` syscall ABI differs (9k's `syscall.c` uses `Ar0`/va_list per `parse:199-271`), error handling uses 9k's `error.h` strings.

**Why it happens:**
"It's all Plan 9" — but 9front's port layer and Harvey's 9k port layer diverged in 2015-2016.

**How to avoid:**
Port *concepts and sequences* from bcm64 (boot order, GIC programming, mmu setup), but write 9k-native files: new mach dir (e.g. `sys/src/9k/virt/` or `sys/src/9k/aarch64/`), its own config file following `k10cpu`'s grammar, `port/` reused unchanged. Expect the `port/` layer to need a small number of arch hooks (it already assumes some x86-isms — audit `port/` for `amd64` conditionals early).

**Warning signs:**
Import attempt dies on missing `ureg` fields or `Ar0` mismatch; `#ifdef` arch tangles appearing in `port/` files.

**Phase to address:**
Kernel bring-up phase — plan the mach-dir skeleton explicitly; don't "import bcm64."

---

### Pitfall 13: TLS/security debt (out of scope but booby-trapped)

**What goes wrong:**
Not this milestone's deliverable — but the port will touch `libsec` (assembly accel?), and there's a documented trap: TLS ceiling is 1.2 (`sys/src/libsec/port/tlshand.c:143-147`), kernel TLS device accepts **SSL 3.0** (`sys/src/9k/port/devtls.c:27-33`), and NULL/RC4/DES/3DES suites are live (`tlshand.c:200-267`, NULL-MD5 enabled at line 1522). The risk *this milestone* is inadvertent: presenting the aarch64 userland as "working" while `webfs`/`hget` silently negotiate garbage, or wiring chacha (present but unhooked) wrongly.

**Why it happens:**
Deferred concerns leak back in through "just make it connect" debugging.

**How to avoid:**
Milestone rule: no security claims, no cipher changes, no "fixes" to libsec in the port phases; log any TLS oddity to the backlog for the hardening milestone. If aarch64 needs libsec asm primitives, port C-only.

**Warning signs:**
A "quick" commit bumping a cipher list riding along with port work.

**Phase to address:**
None this milestone — explicitly. Document the boundary in the roadmap so phase planners don't absorb it.

---

### Pitfall 14: mk quirks and generated-file hygiene

**What goes wrong:**
The 9k build uses mk's pipe-include: `<| awk -f ../mk/parse $CONF` (`sys/src/9k/k10/mkfile:11`) — the *wrong awk* (host gawk vs Plan 9 awk semantics in rc scripts like `../mk/mkenum`) silently misgenerates `${objtype}l.h`. Generated files with inconsistent nuke coverage: `amd64l.h`/`sipi.h` (nuked via `k10.nuke`, mkfile:93-94), `$CONF.c`, `y.tab.h`, `ycbcr.h`, `$CONF.root.s`. `sipi.h` is built by *linking then hexdumping* (`mkfile:76-83`) — a pattern that breaks under parallel mk. `-DKERNDATE=`{date -n}` (mkfile:20) embeds a timestamp → kernels are never bit-reproducible by default, which will trip the milestone's "reproducible from clean checkout" requirement if that means bit-identical artifacts. `cputype=unix` + `unix/mkfile` (`CC=9c`, `O=o`) is a loaded footgun for any `$cputype`-derived logic (Pitfall 1 shows it firing).

**Why it happens:**
mkfiles grew organically on self-hosting Plan 9; the Unix-hosted flow re-executes them in an environment they weren't written for.

**How to avoid:**
Inventory generated files per phase (`git status --ignored` after build = the list); make `nuke` delete exactly that set; guard `sipi.h`-style recipes against parallelism; decide the KERNDATE policy for reproducibility (pin via env or accept timestamp variance in the requirement's wording); keep `$cputype` usages on a grep-watchlist.

**Warning signs:**
Second build differs from first; `mk nuke && mk` fixes a weird error; parallel build flakes.

**Phase to address:**
Build-revival phase (hygiene) + a later reproducibility phase (KERNDATE policy).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Commit arch headers/mkfile before toolchain (riscv64 pattern) | Feels like progress, easy PR | Dead scaffolding, false signal, broken `installall` | **Never** — this is the project's own cautionary tale |
| Hardcode qemu virt device addresses from dumpdtb | Skip DTB parser (~200 lines) | Breaks on qemu version bump; darwin/linux divergence | Early bring-up only, with a TODO gate before phase exit |
| Portable-C `mem*`/`str*` in libc/aarch64 (skip asm) | Port unblocked sooner | Slower libc; fine | Acceptable — riscv64 precedent; optimization later |
| C-only libsec for aarch64 (skip asm accel) | No per-arch crypto asm audit | Slow RSA/AES | Acceptable this milestone |
| Keep dual `9`/`9k` trees untouched | Zero-risk this milestone | Fixes continue diverging (`tcp.c:2049` duplicated TODO) | Acceptable now (logged Out of Scope); schedule dedup milestone |
| Skip Go programs on aarch64 image | No Go port needed | Image lacks edwood/gopls/acme-lsp/muscle on aarch64 | Forced — Go has no plan9/arm64; document as known gap |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| qemu `-kernel` (aarch64) | Assuming multiboot/`plan9.ini` flow from k10 | ELF bare-metal: entry at ELF entry, DTB at 0x40000000; design new boot-line mechanism |
| qemu `-M virt` | Accepting default `-cpu` (32-bit cortex-a15) | Always `-cpu cortex-a72` (or a53); pin `gic-version=2` |
| 9front bcm64 reference | File-copying into `sys/src/9k/` | Port sequences/concepts; write 9k-native mach dir |
| plan9port host tools | `$PLAN9/bin` early in PATH (shadows util-linux `mount`) | Keep `$PLAN9/bin` LAST (per BUILD_ON_UNIX; logged decision) |
| lima VM (darwin hosts) | virtiofs subdirectory binds (silently empty) | rsync to guest-local disk (logged decision — don't regress) |
| Go toolchain in image | Expecting GOARCH=arm64 to work | Go unsupported on plan9/arm64 — exclude Go cmds from aarch64 image |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `qmalloc` single-lock allocator (`sys/src/9k/port/qmalloc.c`) | SMP scaling cliff | Defer; note per-CPU magazine backlog item | Many CPUs — irrelevant on 1-4 vCPU qemu |
| TCG (no HVF/KVM) bring-up on x86_64-linux hosts | Boot tests 10-50× slower; timeouts misread as hangs | Require aarch64 host (HVF/KVM) for bring-up CI; TCG only for smoke | Immediately on non-ARM CI runners |
| 32-bit-DMA driver assumptions (`ethervgbe.c:875` style) | Bounce-buffer hacks creep into new virtio code | Write virtio-mmio drivers 64-bit-clean from day 1 | When RAM >4GB configured |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| "Port makes TLS work" claims | Silently shipping SSL3/NULL ciphers on a new arch | Milestone rule: zero libsec/devtls changes; backlog for hardening milestone |
| Kernel `strcpy`/`sprintf` (76 hits in 9k) | New aarch64 code copies the idiom (`devsrv.c:170`, `chan.c:892`) | New code uses `kstrcpy`/`snprint`; don't propagate idiom |
| Bootstrap ISO without checksum (`build/build.bash:6-10`) | Supply-chain trust in revival path | Already bypassed by Nix flow; keep it dead — don't resurrect |

## "Looks Done But Isn't" Checklist

- [ ] **9k amd64 "green":** k10cpu building ≠ done — verify `k10cpuf` **and** `k10f` (embedded-root variants) link; they fail at `mkrootall` if `/amd64/bin/ip/ipconfig` or `/amd64/bin/auth/factotum` missing (Pitfalls 1-2).
- [ ] **cmd chain "completed":** mk returning 0 ≠ everything installed — DIRS iteration can skip aborts; verify `venti`, `ip/ipconfig`, `auth/factotum` binaries exist, not just "no error."
- [ ] **7c compiles hello.c:** ≠ toolchain done — verify `7l` links against a `libc.a` archive built by `iar` (archive format compat is separate from codegen correctness).
- [ ] **libc/aarch64 exists:** ≠ userland builds — `main9.s` ABI, `notejmp`/`Ureg` match, and `tas` correctness under `-smp 4` each need a dedicated smoke test (Pitfalls 10-11).
- [ ] **Kernel prints banner:** ≠ kernel works — stage-gate: UART poll → timer IRQ → GIC-passed device IRQ → scheduler → rfork → exec of `boot` from embedded root (Pitfall 8).
- [ ] **Boots once:** ≠ reproducible — `-DKERNDATE=date -n` embeds time; decide the policy before claiming "reproducible from clean checkout" (Pitfall 14).
- [ ] **aarch64 userland "builds":** ghostscript's x86 MMX asm (`pnggccrd.c`/`pngvcrd.c`) and APE dirs will break a full `mk install` — prune/exclude before claiming green (CONCERNS.md).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Generator cross-compile mess (1) | LOW | Switch generator to host `pcc`, `mk nuke` the dir, rebuild |
| Embedded-root ordering (2) | LOW | Install missing cmds, re-run kernel `mk` — no code change |
| Scaffolding-first port (3) | MEDIUM | Quarantine dirs, rebuild toolchain-first; the riscv64 cleanup is itself a task |
| Naming collision (4) | LOW (now) | Rename before references accumulate; cost grows with every import |
| Boot protocol wrong (5) | MEDIUM | Rebuild entry asm + link flags; no portable-code impact |
| qemu defaults (6) | LOW | Fix run script; pin in flake |
| MMU/cache bugs (7) | HIGH | Bisect boot sequence with qemu `-d int,guest_errors`, single-step bring-up; this is the schedule risk |
| Stale compiler lineage (9) | HIGH | Re-vendor from 9front 7c — costs the port work twice; avoid by choosing 9front-first |
| tas/Ureg ABI bugs (10/11) | HIGH | Rewrite ABI files as a set, re-run SMP/note smoke tests |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Compile-and-run generators | Build revival (9k amd64 green) | Clean checkout → full cmd install; `ycbcr.h`/`proctab.c` regenerated by host tools; preflight asserts ipconfig/factotum present |
| 2. Embedded-root ordering | Build revival | `mk CONF=k10cpuf install` and `k10f` link green in same run |
| 3. Scaffolding-first (riscv64) | Build revival (quarantine) + Toolchain (gate) | riscv64 quarantined; aarch64 dirs committed only after 7a/7l hello-world |
| 4. arm64/aarch64 naming | Toolchain, first task | No `arm64` paths remain; `objtype=aarch64` build wiring works |
| 9. 7c from stale 5c | Toolchain | 9front 7c vendored; hello-world + libthread smoke under qemu user/system |
| 10/11. libc ABI contract | Toolchain (headers/libc) + Bring-up (trap path) | `tas` SMP stress; note/rfork smoke; static assert on Ureg size |
| 14. mk hygiene | Build revival | `mk nuke` removes all generated files; two consecutive builds identical modulo KERNDATE |
| 5/6/7/8. Boot/qemu/MMU/console | Kernel bring-up | Stage-gated: ELF entry → UART print → timer IRQ → GIC IRQ → sched → shell on `-M virt` |
| 12. bcm64≠9k layout | Kernel bring-up | New mach dir follows `k10cpu` config grammar; `port/` unmodified or minimally hooked |
| 13. TLS boundary | (Deferred milestone) | Zero libsec/devtls diffs this milestone (audit at ship) |
| 15. Go/arm64 gap | Toolchain/image | aarch64 image build excludes `cmd/go` commands; documented |

**Research flags for phase planners:**
- Toolchain phase needs a **RESEARCH.md** deep-dive: diff 9front `7c/7a/7l` + `cc/` vs Harvey's `5?` + `cc/`; license check; iar archive-format compat with 7l objects.
- Kernel bring-up phase needs a **RESEARCH.md** deep-dive: bcm64 boot/mmu/trap walkthrough mapped onto 9k's parse/portmkfile machinery; qemu virt DTB fixture for the pinned qemu version.
- Build-revival phase: standard patterns (fix generators, ordering, hygiene) — unlikely to need research, but see Pitfall 1 grep list.

## Cautionary Tales (failed/abandoned attempts)

1. **Harvey's own riscv64 port (in-tree):** headers + mkfile referencing a never-committed `jc/jl/ja` toolchain; no kernel, no compiler; libc skeleton with mem*.s commented out. The milestone's explicit cautionary precedent — the ordering failure (scaffolding before toolchain), not a technical dead-end.
2. **Harvey upstream itself (2022-03 dormancy):** the project's existence proof that host-environment assumptions kill dormant Plan 9 trees first — EOL Ubuntu 21.10 Dockerfile (apt mirrors gone), expect+qemu prompt-matching bootstrap against an archived org's release artifact, CI that pattern-matched boot prompts. The Nix flow exists precisely because this path rotted.
3. **9legacy's survival model:** 9legacy persists as a *curated patch queue* on the frozen 4e release — evidence that the sustainable posture for a small team is minimal diffs + active host-tool maintenance (they also run Go's plan9 builders), not heroic rewrites.
4. **Go on plan9/arm64:** doesn't exist upstream; Harvey's image ships Go programs (edwood, gopls, acme-lsp, muscle) for amd64 only. Any aarch64 image plan that assumes feature parity with amd64 userland will over-promise.
5. **Plan 9 arm ports that died at "headers + partial kernel":** Harvey's tree contains the fossils — `arm/`, `mips64/`, `power64/`, `sparc*/`, `spim64/` dirs are header-and-fragment ports; `sys/src/9/kw/cga.c` has `#define inb(x) 0 /* TODO */` stubs compiled into a "working" kernel port. Partial ports don't degrade gracefully; they just lie there.

## Sources

- **In-tree (HIGH confidence, direct reads):** `sys/src/cmd/jpg/mkfile:56-68`, `sys/src/cmd/awk/mkfile:42-50`, `sys/src/cmd/cc/mkfile:26`, `sys/src/cmd/4a/mkfile`, `sys/src/cmd/mkfile:34-38`, `sys/src/mkfile.proto:6`, `unix/mkfile`, `nix/build.sh:12-13`, `build/scripts/build:76-80`, `build/scripts/linux-build:63-67`, `build/mkdirs:264`, `riscv64/` + `riscv64/include/u.h` + `sys/src/libc/riscv64/`, `sys/src/9k/k10/mkfile` (incl. sipi.h recipe, KERNDATE), `sys/src/9k/k10/k10cpu` (rootdir), `sys/src/9k/mk/parse` (mkrootrules/mksystab/mkdevc), `arm64/` (empty bbin), `.planning/codebase/CONCERNS.md` (TLS, dual-tree, TCP TODOs)
- **QEMU official documentation (HIGH):** "'virt' generic virtual platform" — default cortex-a15 (32-bit), DTB at RAM start (0x40000000) for bare-metal/ELF boots, x0=DTB for Linux protocol, versioned machine types, gic-version option, PL011/virtio-mmio inventory (qemu-project.gitlab.io/qemu/system/arm/virt.html, fetched 2026-10-30)
- **9front (MEDIUM-HIGH):** `arm64/mkfile` (`CC=7c LD=7l AS=7a O=7`) via git.9front.org; bcm64 port location/lineage (Richard Miller RPi port) via 9fans topicbox + multiple setup guides; arm64 QCOW2 image boots under QEMU on ARM hosts
- **Ecosystem (MEDIUM):** 9legacy patch-queue model (9legacy.org, github.com/0intro/9legacy); Go plan9 maintenance/bus-factor (golang/go#58011); plan9port issue tracker activity
- **Compiler suite background (MEDIUM):** Thompson, "Plan 9 C Compilers" (9p.io/sys/doc/compiler.html); RV64GC compiler talk (YouTube) confirming the add-an-arch pattern for the ken suite
- Seam confidence note: the research-store seam rated all cached digests LOW (unverified-web provenance); the in-tree and QEMU-doc claims above are nonetheless primary-source and are treated as HIGH in this document.

---
*Pitfalls research for: Harvey OS build revival + aarch64 port*
*Researched: 2026-10-30*
