# Harvey OS — Build Revival + aarch64 Port

## What This Is

Harvey OS is a Plan 9 4th Edition derivative operating system (C, mk-based build, dual kernel trees: legacy `sys/src/9/` and active amd64 `sys/src/9k/`). This project revives the dormant upstream build (last upstream commit 2022-03-30), modernizes the dev environment with Nix, ports the userspace to aarch64 — and ultimately adopts **r9** (sibling repo `../r9`, a Rust reimplementation of the Plan 9 kernel) as Harvey's kernel, including adding/completing aarch64 support in r9 (qemu `-M virt`, beyond its current raspi3b/4b focus).

## Core Value

Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.

## Requirements

### Validated

- ✓ Nix devshell + flake apps (`setup`/`toolchain`/`build`/`iso`) implement the BUILD_ON_UNIX flow — committed `a1735e67f`
- ✓ Native aarch64 host toolchain (Plan 9 compilers 6a/6c/6l, 8a/8c/8l, cpp, pcc, vendored `iar`) builds on darwin-aarch64 and linux-aarch64 — committed `a1735e67f`
- ✓ 9k amd64 kernel (`k10cpu`) builds via the lima-VM namespace build on macOS hosts — validated this session (`amd64/9k10cpu`, `.elf`)
- ✓ Codebase map + knowledge graph for navigation — `.planning/codebase/`, `.planning/graphs/`
- ✓ amd64 libc + core userspace libraries build green in the namespace build — this session
- ✓ Full 9k amd64 kernel set green from clean checkout: k10cpu + k10cpuf + k10f (all + `.elf`), two fresh-clone proofs — Phase 1
- ✓ Same-path bit-reproducible kernels: KERNDATE pinned from git commit (env-overridable), bit-identical demo + negative control — Phase 1 (`build/REPRODUCIBILITY.md`; conffile absolute-path exception documented)
- ✓ 9k10cpu boots under minimega/qemu with `Plan 9` banner captured over serial (TCG mode, human-accepted) — Phase 1 (`build/mm/`)
- ✓ aarch64 userspace toolchain in-repo: vendored 9front 7a/7c/7l (pinned `350266104f`, Harvey shims), libmach arm64 (Alpha excised from letter 7), libc/aarch64 + frozen syscall ABI (`aarch64/ABI.md`), `objtype=aarch64` wiring — Phase 2 (TC-01…TC-05; proven by execution: hello.7.out + 16-binary shell subset run on the 9front donor kernel under qemu TCG)
- ✓ r9 aarch64 boots on qemu `-M virt,gic-version=2`: platform tree (`platform/{raspi3b,raspi4b,virt}`), ELF `-kernel` + committed DTB at `0x40000000`, GICv2 + generic timer ticks, PL011 IRQ echo, `cargo xtask boot-test` harness, `virtpanic` debug gate — Phase 3 (SC#1–5; evidence bundle byte-identically reproducible, `03-VERIFICATION.md` 22/22)
- ✓ r9 carries its own `flake.nix` (rust-overlay honoring `rust-toolchain.toml`, qemu + dtc, `apps.build`) — Phase 3 (R9-05; darwin + linux legs both passed)
- ✓ r9 loads and runs Harvey aarch64 userland binaries: paqfs initrd delivery (loader + patched DTB), devroot, demand-paged exec, EL0 entry, SVC dispatch (measured set), preemptive round-robin, RFORK/AWAIT/EXITS, notes via devproc-lite — Phase 4 (R9-02/R9-03; SC#2 hello.7.out prints, SC#4 smoke suite green; `04-EVIDENCE.md`, r9 pinned `54e8c10`)
- ✓ Harvey↔r9 syscall ABI published + build-enforced: TrapFrame ≡ `aarch64/include/ureg.h` field-for-field (35×u64, stride 288), two-layer static checks (const asserts + xtask `ureg-check` with negative control) — Phase 4 (R9-04/SC#1; `aarch64/ABI.md` kernel-side appendix)

### Active

- [ ] Harvey aarch64 userland boots to `/bin/rc` shell on r9 kernel under qemu virt — Phase 5
- [ ] Note-delivery timing race (smokenote `note-timeout` flake, ~1/3 virtmulti runs; reproduces on pre-fix base b4f858a — pre-existing, not from the review fixes) — debug candidate before Phase 5 hardening; 04-REVIEW-FIX.md
- [ ] Re-test the Phase 1 9k-amd64 embedded-root `bad magic` pool panic against the LP64-fixed 6c (same signature as the pswt.c bug fixed in Phase 2) — deferred-items.md #8
- [ ] Upstream raspi3b-on-qemu-11.1.2 boot defect (FAR 0xfe215004 — rpi4 MMIO base on the raspi3b machine) — pre-existing, A/B-proven not-a-regression, accepted 2026-11-01; phase-03 deferred-items.md #1

### Out of Scope

- 386 legacy kernel (`sys/src/9/pc`) and the ISO/dist stage — deferred; focus is 9k amd64 health first
- Hardware aarch64 targets — r9 already has raspi3b/4b; this project targets qemu virt
- Harvey 9k (C kernel) aarch64 port — superseded by the r9 adoption decision; 9k stays amd64 reference
- TLS/security modernization (TLS 1.2 cap, RC4/DES/NULL ciphers) — separate hardening milestone
- Dual `9` vs `9k` kernel-tree deduplication — rendered moot by r9 adoption
- Go-based userland on aarch64 — Go is unsupported on plan9/arm64
- x86_64-darwin host support — repo targets aarch64 hosts first

## Context

- **Kernel future is r9**: sibling repo `../r9` (Rust reimplementation of the Plan 9 kernel; cargo workspace: `port/` portable code + per-arch crates `x86_64/`, `riscv64/`, `aarch64/`; xtask build/qemu/boot-test runners). r9's aarch64 now targets raspi3b/raspi4b AND qemu `-M virt` (Phase 3: cfg-gated platform tree, committed virt-gicv2 DTB, GICv2 + generic timer + PL011 IRQ echo, `cargo xtask boot-test` acceptance harness, `virtpanic` debug config); still no userspace exec path — that is Phase 4. Harvey supplies the userspace, libc, toolchain, and dist machinery; r9 supplies the kernel. r9 has its own flake (R9-05) — commits land on `main` of the `requaos/r9` fork.
- **Upstream dormant**: Harvey-OS/harvey last commit 2022-03-30; CI was a fragile expect+qemu bootstrap on EOL Ubuntu 21.10 (`.planning/codebase/CONCERNS.md`)
- **Build system**: mk + mkfiles; host tools built by `sys/src/cmd/*/BUILD` scripts; kernel build runs in a Linux mount namespace emulating Plan 9's root layout (`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE` → `BUILD_SETUP_NAMESPACE` → `BUILD` → `build/scripts/linux-build`)
- **Nix scaffolding**: `flake.nix` + `nix/*.sh`; on darwin the namespace build runs in a lima VM (virtiofs subdir binds yield empty trees, so the VM build rsyncs to guest-local disk and pulls `amd64/`+`386/` back)
- **Vendored 9-cc**: `sys/src/cmd/unix/9cc/` carries the `iar` subset of 0intro/9-cc with aarch64 host support (see its README)
- **aarch64 toolchain donors**: 9front (MIT) vendored at pin `350266104f` in Phase 2 — `sys/src/cmd/{7a,7c,7l}`, `sys/src/libc/aarch64/`, libmach `{7.c,7db.c,7obj.c}` (retired-Alpha letter-7 collision resolved by excision, D-04/D-05). The pinned donor tree doubles as the execution reference: it builds its own CONF=qemu kernel with Harvey's tools and boots it for the TC-03/TC-05 gates (`build/aarch64/`).
- **Naming tension**: in-tree vestiges (`build_arm64`, empty `arm64/` dir, mkdirs) use `arm64`; 9front convention is also `arm64`; project decision is `aarch64` — the toolchain phase starts by renaming/quarantining the vestiges.
- **Known upstream breakage**: `sys/src/cmd/jpg/mkfile:56-68` derives a nonexistent `oc` compiler from `cputype=unix`, aborting the cmd DIRS loop before `ip/`+`venti/` → root-embedding kernels (k10cpuf/k10f) can't find `/amd64/bin/ip/ipconfig`; `4a` `rfork bind lex.c` failure; `mahjonng` cpp breakage noted in Dockerfile TODO
- **VM orchestration**: minimega (`../minimega` read-only clone for reference; the flake fetches+builds it via `nix/minimega.nix`, pinned tag 3.3.0) manages amd64 test VMs on Linux/KVM hosts with `.mm` scripts. It is x86/KVM-centric upstream — aarch64/r9 test boots use plain qemu instead. On darwin, KVM is unavailable; minimega runs on linux hosts (or the lima guest, TCG-slow).
- **riscv64 cautionary tale**: `riscv64/mkfile` references a `jc/jl/ja` toolchain never committed — vaporware scaffolding. Hard rule: toolchain (7l-linked hello-world) lands before any arch dir/mkfile.

## Constraints

- **Tech stack**: Plan 9 C dialect + mk (Harvey userspace); Rust no_std + cargo xtask (r9 kernel, sibling repo `../r9` — phases will work across both repos); host tools must build with plan9port (`$PLAN9/bin` LAST in PATH per BUILD_ON_UNIX)
- **Host platforms**: darwin-aarch64 (primary dev machine) and linux aarch64/x86_64; Harvey namespace build requires Linux mount namespaces (lima VM on macOS); r9 builds anywhere cargo+qemu run
- **Compatibility**: keep upstream Harvey/Plan 9 conventions (`sys/man/6/style`: tabs, lowercase, `nil`, `exits`/`sysfatal`); r9 follows its own rustfmt.toml
- **Naming**: the 64-bit ARM architecture is `aarch64` (not `arm64`) in this project's tooling and docs
- **Upstream**: dormant; this repo is now the maintained fork — in-tree fixes are preferred over external patch stacks
- **Licenses**: Harvey is MIT since 2021 (GPL only via ghostscript fonts); 9front imports are MIT — compatible

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nix flake for devshell + build apps | Reproducible toolchain across darwin/linux without Docker-on-EOL-Ubuntu | ✓ Good |
| Vendor 9-cc `iar` subset in-repo (`sys/src/cmd/unix/9cc/`) | External dep kept failing on aarch64 hosts (C23/glibc collisions); in-repo code we control | ✓ Good |
| VM build rsyncs to guest-local disk | virtiofs subdirectory bind-mounts silently return empty trees — namespace build cannot run on the shared mount | ✓ Good |
| Per-OS/arch host bin dirs (`.build/hostbin-<os>-aarch64`) | Host and guest builds share the checkout; binaries must not clobber each other | ✓ Good |
| plan9port `$PLAN9/bin` LAST in PATH | plan9port ships a 9p `mount` that shadows util-linux mount; BUILD_ON_UNIX mandates last | ✓ Good |
| aarch64 (not arm64) naming | User decision 2026-10-30 | ✓ Good |
| Adopt r9 (Rust Plan 9 kernel) as kernel future instead of porting 9k/C to aarch64 | User decision 2026-10-30 — r9 exists (../r9), is the modern path; avoids investing in a C kernel port that would be discarded | ✓ Good |
| r9 gets its own flake; Harvey consumes r9 via flake input | User decision 2026-10-30 — flakes compose via git URLs; relative paths/submodules are fragile glue | ✓ Good (Phase 3: r9 flake.nix landed, R9-05; Harvey-side consumption lands in Phase 5) |
| minimega for VM orchestration, fetched+built by nix (`nix/minimega.nix`, no submodule) | User decision 2026-10-30 — single-binary KVM VM manager with scriptable `.mm` files; upstream is x86/KVM-centric so it covers amd64 test VMs only; aarch64/r9 boots stay on plain qemu | ✓ Good |
| Host-built generators normalize on the awk idiom (`objtype=$cputype mk <tool>.$cputype`) | Phase 1 — deriving tool names from `$cputype`/`$c^c` produced nonexistent `oc`/`ol`; awk's recursion is the proven in-tree pattern | ✓ Good |
| KERNDATE pinned from git commit timestamp, derived host-side, env-overridable | Phase 1 (BUILD-04) — guest rsync excludes `.git`; same-path bit-reproducibility + documented conffile exception | ✓ Good |
| TCG boot capture accepted for BUILD-05 demonstration | Checkpoint 2026-10-31 — dev fleet has no `/dev/kvm`; KVM path documented for any linux x86_64 host | ✓ Good (scoped) |
| Boot-test the toolchain, not just build-test it | Phase 1 — build-green masked LP64 wide-constant truncation in 6c/6l (zaddr/oclass/immconst, NVAR); only a boot attempt exposed the silent corruption | ✓ Good |
| 9k amd64 green before 386/ISO | 9k is the active kernel; limit blast radius of the build-tail milestone | ✓ Good (Phase 1 enforced via `arch=(amd64)` + `WITH_DIST` gate) |
| Vendor-and-own 9front toolchain at a pinned donor SHA, per-dir provenance READMEs (D-10) | Phase 2 — supply-chain discipline is the phase's real security content; one fetch, hard rev-parse gate | ✓ Good |
| Execution-gated ordering: a 7l-linked binary RUNS on the donor kernel before any `aarch64/` scaffolding/CPUS lands | Phase 2 — riscv64 vaporware rule enforced structurally; the gate caught two real bugs (pswt.c LP64 switch sign-extension; memset/memmove n-width) | ✓ Good |
| User-side syscall ABI freeze: `9syscall case aarch64` donor-verbatim + canonical `aarch64/ABI.md` (R0/SP+8/SVC, NMOUNT=54) | Phase 2 (D-15) — r9 Phase 4 consumes this contract; execution-validated before publication | ✓ Good |
| Host nm built against the 9cc-tree libmach, not Harvey's in-tree libmach | Phase 2 — in-tree executable.c hits an LP64-host embedded-typedef dialect wall; 9cc route is the plan's fallback with arm64 support vendored there | ✓ Good (recorded) |
| qemu-11.1.2 donor drift accommodated harness-side only (GIC wake poke, console=0, virtio-non-transitional, ECAM/DTB loader) | Phase 2 (D-12) — donor tree stays pristine; vendor fidelity outranks convenience | ✓ Good |
| libmp `mpvecdigmulsub` split (retire the 2021 PORT rename); member/symbol 1:1 | Phase 2 (02-07) — archive member lookup needs name equality on aarch64 | ✓ Good |
| Default build is dual-arch: `arch=(amd64 aarch64)` with subset-scoped `build_aarch64` | Phase 2 (02-07) — TC-05 acceptance + regression coverage in one `nix run .#build` | ✓ Good |
| Kernel bring-up on qemu `-M virt` shell | Smallest provable target; r9's raspi focus needs a virt platform anyway | ✓ Good (Phase 3: banner + ticks + IRQ echo + panic gate all proven; shell itself is Phase 5) |
| r9 platform tree (riscv64-style `platform/{raspi3b,raspi4b,virt}`, raspi3b default) + trap init/unmask split | Phase 3 (D-01/P5) — virt lands alongside raspi without if/else rot; no IRQ can arrive before a platform arms its handlers | ✓ Good |
| Virt platform as TOML data (xtask `[qemu]` cpu/smp/memory/accel + `[dist]` format; ELF dist skips objcopy/gzip; accel override chain ends at tcg — never hvf default, HVF rejects GICv2 on qemu 11.1.2) | Phase 3 (D-05/D-06/D-07, research P2/P7) — new platforms become data, not Rust edits | ✓ Good |
| Committed DTB artifact (virt-gicv2.dts/.dtb) + ELF-x0=0 → fixed-PA 0x40000000 fallback at both DTB consumers | Phase 3 (P1/P11) — qemu 11.1.2 loads no DTB for ELF kernels without `-dtb`; regeneration procedure documented in the .dts header | ✓ Good |
| Acceptance harness in r9 (`cargo xtask boot-test`, zero-dep unix-socket, marker-only assertions); canonical evidence consolidated in Harvey phase dir | Phase 3 (D-11/D-13) — converts SCs from hand-run observations into a repeatable gate; verifier reproduced both logs byte-for-byte | ✓ Good |
| Accept A/B no-regression evidence for the pre-existing raspi3b/qemu-11.1.2 defect instead of fixing it in 03-03 | User decision 2026-11-01 (decision A) — defect predates the phase; virt never exercises raspi's early-uart path | ✓ Good (scoped; defect tracked as Active follow-up) |
| initrd delivery = qemu generic `-device loader` + host fdtput-patched DTB (D-01 amended) | Phase 4, user decision A 2026-11-02 — Wave-0 spike falsified A3: qemu 11.1.2 never delivers `-initrd` for ELF kernels (hw/arm/boot.c is_linux=0); loader+patched-DTB preserves DTB-mediated delivery with the ELF boot (D-05) intact | ✓ Good (proven end-to-end; kernel /chosen discovery unchanged) |
| Publish TrapFrame≡Ureg as a cross-repo one-way contract (D-05/D-07 confirmed at the publication gate) | Phase 4 — offsets frozen in `aarch64/ABI.md` + pinned by const asserts and xtask ureg-check; an ABI mismatch is a build failure, never a runtime mystery (SC#1) | ✓ Good (negative control fires; live on every boot-test) |
| Tracer-first falsification spikes before machinery (04-01) | Phase 4 — the spike caught the A3 delivery falsification before any kernel capability depended on it; gate splitting (compile-verified machinery 04-04 vs runtime gate 04-05) caught the trap-entry x0 clobber | ✓ Good |
| Implement only the measured syscall set (D-14 trace: pwrite/open/pread/close/exits + named core; loud-unimplemented default) | Phase 4 — no handler without a traced or SC#4-named caller; the first real SVC was pwrite(51), exactly as measured | ✓ Good |
| Exercise IRQ-from-EL0 + return-to-different-process this phase (D-13); invariant `PSTATE.I=0 ⟺ EL0 or stateless sched wfi` | Phase 4 — preemption proven via `sched: switch` markers; exec_bootstrap IRQ-masked after the miniz-inflate heisenbug (contained, root cause deferred #4) | ✓ Good (containment; race follow-up tracked Active) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-02 after Phase 4*
