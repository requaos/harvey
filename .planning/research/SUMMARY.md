# Project Research Summary

**Project:** Harvey OS — Build Revival + aarch64 Port (r9 kernel adoption)
**Domain:** Plan 9-family OS revival — userspace aarch64 port + Rust kernel (r9, sibling repo `../r9`) platform bring-up
**Researched:** 2026-10-30
**Confidence:** HIGH for Harvey-side and 9front/qemu facts (primary sources, directly verified); MEDIUM for r9-side mapping (PROJECT.md's r9 decision post-dates the research run — `../r9` itself was never inspected by the researchers; see Gaps)

## Executive Summary

This project revives the dormant Harvey OS (Plan 9 4e derivative, MIT since 2021) build, ports its userspace to aarch64, and adopts **r9** — a Rust reimplementation of the Plan 9 kernel in sibling repo `../r9` — as the aarch64 kernel, instead of porting Harvey's 9k C kernel. The ecosystem research landed cleanly: 9front is the only viable donor for the aarch64 toolchain (`7a`/`7c`/`7l`), the only maintained Plan 9 aarch64 libc, and the canonical qemu `-M virt` reference — all MIT-licensed, all verified file-by-file against the upstream git tree. Harvey's own build conventions (BUILD scripts, plan9port host tools, namespace build) already match the shape of the donor sources, making the import mostly mechanical with enumerated drift surfaces.

The recommended approach is a strict dependency chain: fix the broken 9k amd64 build tail first (compile-and-run generators + embedded-root ordering — the current blocker), then import the 9front aarch64 toolchain and libc under the project's `aarch64` naming, then bring up r9 on qemu `-M virt` (r9 already has arm64 VM/console/allocator/traps on raspi3b/4b — virt is a new platform, not a new port), then grow r9's missing userspace-exec path (EL0, `svc` syscall dispatch, first-process loading) to host the Harvey aarch64 userland to an `/bin/rc` shell, and finish with one-command reproducible boot on darwin-aarch64 and linux.

The researchers' kernel-port findings were written against a 9k C-kernel port that is now **Out of Scope** — but their load-bearing content transfers: the stage-gated bring-up ordering (polled UART → MMU → traps → GIC/timer → console → process model → syscalls → exec → shell), the qemu virt constants (PL011 `0x09000000`, GIC `0x08000000`, RAM `0x40000000`, `-cpu cortex-a72`, pin `gic-version`), and the trap-frame/ABI discipline all apply directly to r9's virt platform and userspace-exec work. What drops away: the 9k mk/config machinery (`mk/parse`, `k10cpu` grammar, `PMMU` in `dat.h`, `aout2uimage`/7l kernel links) — r9 kernels are cargo-built ELF, not 7l-linked a.out. The single largest risk is now the **Harvey↔r9 syscall ABI contract**: the user side is fixed by the imported 9front libc stubs (`SVC` + register conventions); the kernel side is greenfield Rust in r9, and nothing has designed it yet.

## Key Findings

### Recommended Stack

Import everything toolchain-side from **9front** (branch `front`, pin a SHA at import). Harvey's `6a/6c` BUILD patterns apply unchanged to `7a/7c`; the namespace build's `build_arm64` already globs `/sys/src/cmd/7?` — the import plugs into existing wiring. All donor code is MIT or MIT-compatible (Harvey itself relicensed to MIT in 2021; retain NOTICE lines crediting Bell Labs/Lucent, Vita Nuova, C H Forsyth, 9front).

**Core technologies (all still valid under r9 — these are userspace-side):**
- 9front `sys/src/cmd/7a`, `7c`, `7l`: ARM64 assembler/compiler/linker — the only maintained Plan 9 arm64 toolchain; Harvey's vendored 9-cc `iar` proves this lineage builds in-tree
- 9front `sys/src/libc/arm64/`: per-arch libc (setjmp, tas, atomics, main9) — the only maintained Plan 9 arm64 libc; Harvey already has the shared `libc/{port,9sys,fmt}`
- 9front `arm64/mkfile` + `arm64/include/{u.h,ureg.h}`: objtype wiring — byte-for-byte the pattern of Harvey's `amd64/mkfile`; **rename to `aarch64` on entry** (project naming decision)
- 9front `sys/src/libmach` `7.c`/`7db.c`/`7obj.c`: arm64 object support for `nm`/`acid` on 7l userland binaries — must resolve the **collision with Harvey's retired-Alpha letter-7 wiring** (`alpha/7.out.h` vs arm64 `7.out.h`) before import
- 9front `libc/9syscall/mkfile` arm64 case: `SVC` syscall stubs — **defines the user side of the Harvey↔r9 ABI**
- qemu `qemu-system-aarch64` ≥ 8.x via the nix flake: target emulator, `-M virt`

**Now unused (9k-port-only findings):** `sys/src/9/arm64/` as kernel import source, `aout2uimage`, 7l kernel link lines, uImage boot — r9 builds its own kernel via cargo; these survive only as *reference reading* for r9's virt platform authors.

### Expected Features

The FEATURES.md minimal shell-boot boundary survives with r9 substituted for 9k: one `qemu-system-aarch64 -M virt -nographic` run where (1) the kernel boots and prints on PL011, (2) GIC + generic timer tick, UART RX is interrupt-driven, (3) a process model services `svc` syscalls from EL0, (4) a root filesystem is mounted and `/bin/rc` execs from it, (5) an interactive prompt runs builtins and external binaries, (6) all reproducible from clean checkout on both host OSes.

**Must have (table stakes):**
- 7a/7c/7l toolchain + libc aarch64 + 9syscall stubs + objtype wiring — blocks everything (Plan 9 C has no gcc/clang path)
- r9 qemu-virt platform: entry, memory map, PL011 console, GICv2, ARM generic timer — r9 has all of this on raspi; virt is a platform variant (DTB/addresses differ)
- r9 userspace-exec maturity: EL0 entry/exit, `svc #0` syscall path matching Harvey's ABI, first-process (`initcode`-equivalent) loading, user page-fault services (text demand-load + stack growth), icache maintenance after text load — **the genuinely new r9 work**
- Harvey aarch64 userland: `rc` + minimal cmds (`ls`, `cat`, `echo`, `ps`) built with 7c/7l, delivered to r9 via some root mechanism (mechanism TBD — mkrr/paq is 9k-specific)
- Flake run target + boot smoke test asserting the rc prompt

**Should have (post-shell, v1.x):**
- virtio-9p host mount — collapses userland iteration time; strongest first post-shell item
- FP/SIMD context switching in r9 — defer until a userland binary needs floats
- PSCI reboot/poweroff — smoke-test ergonomics
- Minimal DTB/bootargs handling beyond r9's existing raspi path

**Defer (v2+):**
- SMP (PSCI cpu-on, IPI, TLB shootdown) — `-smp 1` proves the scheduler
- virtio-net/storage, PCIe ECAM scan, GICv3, ASIDs/LSE/PAN hardening
- Hardware aarch64 (r9 already has raspi3b/4b; out of scope this milestone)
- Go userland on aarch64 — impossible (Go unsupported on plan9/arm64); document as known image gap

### Architecture Approach

ARCHITECTURE.md's three-layer Plan 9 kernel anatomy (port/ ↔ arch/ ↔ mk config compiler) is now **background reference**, not build target — r9 is a Rust cargo workspace (`port/` + per-arch crates) with its own structure. What carries forward: (a) the conceptual port/arch split maps to r9's `port` crate vs `aarch64` crate; (b) the 9front `sys/src/9/arm64/` file set (`l.s`, `mmu.c`, `trap.c`, `gic.c`, `clock.c`, `uartqemu.c`, `cache.v8.s`) is the canonical *sequence reference* for r9's virt platform — port sequences and concepts, never code (Rust vs C, and 9front's `sys/src/9` layout matches neither Harvey 9k nor r9); (c) the qemu-virt memory map constants and register-convention notes (R26=`up`, R27=`m`/TPIDR_EL1, R28=SB) describe the ABI the *Harvey userland* will execute under, so r9's trap frame must be laid out to match Harvey's imported `aarch64/include/ureg.h` exactly; (d) the syscall ABI section — args fetched from user stack at `SP_EL0+0` (no pushed return address on arm64), syscall number in R0, result in `ureg->r0`, errstr swap — is the **design input for r9's syscall layer** and the most important cross-repo contract in the project.

**Major components (r9 reality):**
1. Harvey aarch64 toolchain/libc (9front imports) — produces userland binaries + defines user-side ABI
2. r9 `aarch64` crate + new qemu-virt platform — kernel entry, VM, GIC/timer, PL011 (largely exists on raspi; virt variant needed)
3. r9 userspace-exec layer (greenfield) — EL0 support, syscall dispatch matching Harvey ABI, first-process/root-fs loading
4. Harvey aarch64 userland image (rc + cmds) + delivery mechanism into r9 (TBD)
5. Nix flake integration — qemu run target + smoke test, both host OSes

### Critical Pitfalls

1. **Compile-and-run generators assume self-hosting Plan 9** — `jpg/mkfile` derives a nonexistent `oc` from `cputype=unix`, aborting the cmd chain before `ip/`/`venti/` install, which then detonates embedded-root kernel builds. Current blocker; fix with an explicit host-tool rule (`pcc` into `.build/hostbin-*`) + preflight assertions. *(Phase 1)*
2. **Scaffolding-first port death (the in-tree riscv64 precedent)** — headers/mkfiles referencing a never-committed toolchain. Hard gate: `7a` assembles and `7l` links a hello-world *before* any `aarch64/` arch dir, libc dir, or `CPUS` entry is committed. Quarantine riscv64 debris. *(Phases 1-2)*
3. **arm64↔aarch64 naming collision** — vestigial `arm64/` dir, stale `build_arm64` functions, and 9front's own `arm64` convention vs the project's `aarch64` decision. Rename/quarantine in the toolchain phase's first task; rename every imported 9front path on entry. *(Phase 2)*
4. **Porting 7c from Harvey's stale 5c lineage** — re-imports a decade of bugs 9front already fixed. Vendor 9front 7c/7a/7l as the starting point (proven vendor-and-own strategy); the compiler is the toolchain phase's critical path, not a warm-up. *(Phase 2)*
5. **libc/trap-frame ABI mismatch** — `tas`/`setjmp`/`notejmp`/`main9` and `ureg.h` are the ABI. Under r9 this becomes a **cross-repo** contract: Harvey's imported `ureg.h` must match r9's Rust trap frame field-for-field. Write both sides with a pinned-offset comment + static assertion; smoke-test notes/rfork first after shell. *(Phases 2 and 4)*

Deprioritized by the r9 decision (still documented in PITFALLS.md): multiboot-absence boot-protocol mismatch (r9 owns its own boot), from-scratch MMU/cache bring-up (r9's raspi arm64 VM already works — residual risk is virt addressing only), bcm64≠9k layout mismatch (moot — but the analog holds: port *concepts* from 9front C into r9 Rust, never files). Unchanged and binding: qemu `-M virt` default-CPU trap (`-cpu cortex-a72`, pin `gic-version=2`, parse DTB), TLS boundary (zero libsec/devtls changes this milestone), mk hygiene/KERNDATE reproducibility, Go-on-arm64 gap.

## Implications for Roadmap

Based on combined research, suggested phase structure (5 phases):

### Phase 1: Build-tail green (9k amd64)
**Rationale:** The cmd-chain generator breakage is the *current* blocker and PoC for the namespace build the aarch64 userland will also use; embedded-root kernel failures are a userland-ordering symptom, so fix root causes first. Everything downstream compiles through this harness.
**Delivers:** Full 9k amd64 set green — k10cpu + k10cpuf + k10f link in one clean-checkout run; host-tool rule for generators; preflight assertions (ipconfig/factotum present); mk nuke hygiene; riscv64 scaffolding quarantined.
**Avoids:** Pitfalls 1 (generators), 2 (embedded-root ordering), 14 (mk hygiene), half of 3 (quarantine).

### Phase 2: aarch64 toolchain + libc (9front donor)
**Rationale:** Plan 9 C has no alternate compiler path — the toolchain is the critical-path item #1 even though no kernel or r9 code runs. Strict gate (Pitfall 3): hello-world assembles+links+runs (qemu user-mode) before any arch scaffolding lands.
**Delivers:** `sys/src/cmd/{7a,7c,7l}` imported and host-built; alpha/libmach letter-7 collision resolved; `sys/src/libc/aarch64/` + `aarch64/include/{u.h,ureg.h}`; 9syscall SVC stubs (user-side ABI frozen here); `objtype=aarch64` wiring (`pcc` entry, `mkfile.proto CPUS`, `build_aarch64` replacing stale `build_arm64`); 7l-linked hello-world smoke test.
**Uses:** All 9front STACK.md imports; plan9port host tools unchanged.
**Avoids:** Pitfalls 3 (gate), 4 (naming — first task), 9 (9front-first 7c), 10/11 (libc half of the ABI).

### Phase 3: r9 qemu-virt platform bring-up
**Rationale:** r9's aarch64 support is raspi3b/4b-only and DTB-driven; qemu virt is a new *platform* (different memory map, GIC/UART addresses, no Pi firmware/mailbox), not a new port. Do this before userspace-exec so the kernel console, timer, and interrupt path are proven on the milestone's actual target machine.
**Delivers (in `../r9`):** qemu-virt platform for the aarch64 crate — entry under qemu's ELF/DTB boot (DTB at `0x40000000`, RAM `0x40000000`), PL011 console at `0x09000000` (polled then IRQ), GICv2 at `0x08000000`, ARM generic timer tick, kernel boot banner + clean panic path on `-M virt -cpu cortex-a72 -smp 1`.
**Translates (from researchers' 9k findings):** FEATURES.md capabilities 5–11 and ARCHITECTURE.md's boot-sequence/memory-map sections become r9 platform work; 9front `9/arm64/` files are sequence references only.
**Avoids:** Pitfall 6 (qemu defaults — pin `-cpu`/`gic-version`, parse DTB, keep `dumpdtb` fixture), residual 7/8 (virt-specific addressing).

### Phase 4: Harvey aarch64 userland to shell on r9
**Rationale:** The cross-repo heart of the milestone and the least-charted territory — no donor exists for r9's side. Everything prior exists only to make this phase debuggable in isolation.
**Delivers:** Harvey↔r9 **syscall ABI contract** (user side = Phase 2's SVC stubs + `ureg.h`; kernel side = new Rust `svc` dispatch in r9: args from user stack at `SP_EL0+0`, number in R0, result in R0, errstr semantics); r9 EL0 entry/exit + trap frame matching Harvey's `ureg.h` (static-asserted); first-process loading (`initcode`/`startboot` analog); root-fs delivery mechanism for aarch64 `rc` + minimal cmds (r9-side initrd/embedded image — TBD design); user page-fault services (text demand-load, stack growth) + icache invalidation; **`/bin/rc` interactive prompt on the UART**.
**Implements:** Architecture component 3 (userspace-exec layer) + component 4 (userland image).
**Avoids:** Pitfalls 10/11 (kernel half of the ABI — same-commit trap frame + ureg discipline), 8 (stage-gated: syscall smoke before exec before shell).

### Phase 5: Integration & reproducibility
**Rationale:** Core Value is "one command, any host" — the milestone isn't done until a clean checkout boots to the shell on both darwin-aarch64 (lima for Harvey namespace build; qemu runs natively) and linux.
**Delivers:** Flake app wrapping `qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -nographic`; expect-style boot smoke test asserting the rc prompt (upstream CI precedent); KERNDATE/reproducibility policy decided and enforced; documented Go-on-aarch64 image exclusion; CI on both host OSes.
**Avoids:** Pitfall 14 residual (bit-reproducibility), "Looks Done But Isn't" checklist items.

### Phase Ordering Rationale

- **Build-green first:** the namespace build is the factory for every later artifact; its current breakage also masks the embedded-root dependency chain that Phase 4's userland image will re-encounter.
- **Toolchain before r9 work:** Plan 9 userspace can only be built by the Plan 9 compilers — no kernel-side progress can be *validated* with real Harvey binaries until 7c/7l exist. Toolchain/libc (Phase 2) and r9 virt bring-up (Phase 3) are technically parallelizable, but serial is safer given shared qemu harness work and the naming cleanup touching build scripts both phases use.
- **r9 platform before r9 userspace-exec:** debug surface minimization — console/timer/IRQ proven on the target machine before EL0/syscall/fault paths add the hardest bug class (ABI mismatches).
- **Shell before polish:** virtio-9p, FP switching, SMP, net/storage are all strictly additive after the prompt appears.

### Research Flags

Phases likely needing deeper research during planning (`/gsd-plan-phase --research-phase <N>`):
- **Phase 2:** 9front `7c/7l` vs Harvey `cc/` frontend reconciliation (drift surfaces #1/#2: `compat.h` vs `compat.c`/`compat/` dir, `dyn.c`, file-list diffs); `iar` archive-format compat with 7l objects; per-file license header audit on import.
- **Phase 3:** **`../r9` current-state audit** — the researchers never inspected it (r9 decision post-dates the research run). Before planning Phase 3, map r9's workspace: existing aarch64 platform abstraction, DTB handling, trap/frame layout, xtask qemu wiring, what "no userspace exec yet" concretely means (missing EL0? missing syscall table? missing loader?). A `/gsd-map-codebase` pass on `../r9` is the cheapest way.
- **Phase 4:** Greenfield design — Harvey↔r9 syscall ABI spec, r9 first-process mechanism, root-fs delivery to r9 (no 9front/9k donor transfers directly; mkrr/paq embeds into a 9k kernel binary). Highest-risk phase; consider a spike before full planning.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Well-understood mk fixes with in-tree evidence and grep lists already enumerated in PITFALLS.md.
- **Phase 5:** Existing flake/expect precedent (upstream CI was exactly this on amd64); KERNDATE policy is a decision, not research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every load-bearing claim verified against actual 9front/9-cc/plan9port repo contents and Harvey in-tree files; license position confirmed (MIT all the way) |
| Features | HIGH (Harvey/qemu side), MEDIUM (r9 side) | In-repo and qemu-doc facts are primary-source; r9 maturity scope inferred from PROJECT.md, not inspected |
| Architecture | HIGH (Harvey 9k anatomy), MEDIUM (r9 applicability) | 9k port/↔arch contract read directly; r9 mapping is conceptual transfer, unverified against `../r9` source |
| Pitfalls | HIGH (in-tree + qemu docs), MEDIUM (blast-radius under r9) | Pitfalls 1-4, 9-11, 13-14 stand unchanged; 5, 7, 8, 12 re-rated for the r9 kernel (documented above) |

**Overall confidence:** HIGH for the Harvey-side plan (Phases 1-2, 5); MEDIUM for r9-side phases (3-4) pending the `../r9` audit.

### Gaps to Address

- **`../r9` was never researched** (the adoption decision was revised into PROJECT.md after the researchers ran): map r9 before Phase 3 planning — platform abstraction shape, raspi boot structure, trap frames, any syscall stubs, xtask qemu wiring, cargo/xtask release artifact format (what exactly does qemu `-kernel` load?).
- **Harvey↔r9 syscall ABI is undesigned:** user side frozen by Phase 2's 9front libc import (SVC stub shape, arg block at `SP_EL0+0`, R0 result); kernel side is greenfield Rust. Owner: Phase 4 plan (or a pre-Phase-4 spike). This is the project's single most important contract.
- **Root-fs delivery to r9 undefined:** 9k's mkrr/paq/`$CONF.root.s` embeds into a 9k kernel — r9 needs its own initrd/embedded-image mechanism (qemu `-initrd`? cargo-embedded blob? 9p later?). Decide in Phase 4 planning; virtio-9p is the documented escape hatch if embedding stalls.
- **Trap-frame cross-repo match:** Harvey's imported `aarch64/include/ureg.h` (9front) vs r9's Rust trap frame — needs a pinned-offset comment + static assert with a home in one repo (recommend r9-side assert generated against the Harvey header).
- **9front `arm64` → `aarch64` rename on import:** mechanical but pervasive (mkfile includes, `ureg.h` absolute include path `/arm64/include/ureg.h` referenced by libmach `7.c` — must become `/aarch64/include/ureg.h`).
- **KERNDATE bit-reproducibility policy undecided:** pin via env or relax the requirement wording — decide in Phase 5 (or earlier to avoid CI churn).
- **libmach scope under r9:** MARM64 object support is still needed for tooling on 7l *userland* binaries (nm/acid); the kernel-side uses (aout2uimage, 7l kernel links) are dead with the 9k port. Keep the libmach import minimal but don't skip it — the alpha letter-7 collision must still be resolved.

## Sources

### Primary (HIGH confidence)
- `github.com/9front/9front` (branch `front`, mirror of git.9front.org) — direct file fetches: `sys/src/cmd/{7a,7c,7l}` + mkfiles, `sys/src/libc/arm64/`, `sys/src/libmach/{7.c,7db.c,7obj.c,setmach.c}`, `sys/src/9/arm64/` (reference sequences for r9 virt work), `arm64/include/`, `sys/src/cmd/aux/aout2uimage.c`
- Harvey tree (local, direct reads): `LICENSE` (MIT 2021), `sys/src/cmd/{6c,6a}/BUILD`, `sys/src/libmach` alpha wiring, `sys/include/mach.h` (`MARM64`), empty `arm64/` dir, `build/scripts/{build,linux-build}` (`build_arm64`), `sys/src/9k/{k10,mk,port}`, `sys/src/cmd/jpg/mkfile:56-68`, `sys/src/cmd/awk/mkfile:42-50`, `riscv64/` vaporware scaffolding, `nix/build.sh:12-13`
- QEMU official docs ("virt" platform): default 32-bit cortex-a15 trap, DTB at `0x40000000`, PL011 `0x09000000` INTID 33, GIC `0x08000000`, versioned machine types, `gic-version` option
- `0intro/9-cc` — host-ported 7-suite (fallback donor), `NOTICE` (MIT text), libmach lacks 7-object support
- `9fans/plan9port` — ships zero target compilers; stays host-tool provider only

### Secondary (MEDIUM confidence)
- 9front HUMANBIOLOGICS release notes (2023-11) + commit dd798542 — generic `9/arm64/` layer, qemu kernel recipe
- wiki.9front.org QEMU arm64 page — `virt-2.12` ECAM caveat, GICv2 default note, `-device loader` recipe
- rcarmo 9front A733 bring-up notes — corroborates serial-first bring-up ordering
- Wikipedia/9fans Topicbox — 2021 MIT relicense timeline, 9front MIT statement

### Tertiary (LOW confidence — flagged, none load-bearing)
- 9legacy/Jehanne negative findings (absence-of-evidence; neither is a donor)
- Provider-seam web digests rated LOW; all load-bearing claims re-verified against primary sources above

---
*Research completed: 2026-10-30*
*Synthesis note: researchers ran against a 9k-C-kernel aarch64 port target; PROJECT.md was subsequently revised to adopt r9 (../r9, Rust) as the kernel. Toolchain/libc/build-wiring findings stand unchanged; kernel-port findings are remapped herein onto r9 qemu-virt platform + userspace-exec work. `../r9` audit is the top pre-planning action.*
*Ready for roadmap: yes*
