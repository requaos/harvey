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

### Active

- [ ] Full 9k amd64 kernel set green: k10cpu + k10cpuf + k10f (embedded-root variants) — currently blocked by cmd-chain failures (`jpg/mkfile` derives bogus `oc` from `cputype=unix`, `4a` `rfork bind lex.c`, venti/ipconfig never installed)
- [ ] aarch64 userspace toolchain in-repo: 7a/7c/7l (assembler/compiler/linker) + libc aarch64 + `objtype=aarch64` build wiring
- [ ] r9 aarch64 bring-up on qemu `-M virt` (r9's aarch64 is currently raspi3b/4b-only, DTB-driven) — kernel entry, memory map, GIC, PL011 console
- [ ] r9 maturity work needed to host Harvey userland: process model / syscalls / first-process (`initcode`) boot path (r9 has VM/console/allocator/traps; no userspace exec yet)
- [ ] Harvey aarch64 userland boots to `/bin/rc` shell on r9 kernel under qemu virt
- [ ] Build artifacts reproducible from clean checkout on darwin-aarch64 and linux

### Out of Scope

- 386 legacy kernel (`sys/src/9/pc`) and the ISO/dist stage — deferred; focus is 9k amd64 health first
- Hardware aarch64 targets — r9 already has raspi3b/4b; this project targets qemu virt
- Harvey 9k (C kernel) aarch64 port — superseded by the r9 adoption decision; 9k stays amd64 reference
- TLS/security modernization (TLS 1.2 cap, RC4/DES/NULL ciphers) — separate hardening milestone
- Dual `9` vs `9k` kernel-tree deduplication — rendered moot by r9 adoption
- Go-based userland on aarch64 — Go is unsupported on plan9/arm64
- x86_64-darwin host support — repo targets aarch64 hosts first

## Context

- **Kernel future is r9**: sibling repo `../r9` (Rust reimplementation of the Plan 9 kernel; cargo workspace: `port/` portable code + per-arch crates `x86_64/`, `riscv64/`, `aarch64/`; xtask build/qemu runners). r9's aarch64 currently targets raspi3b/raspi4b (DTB-driven, PL011, pre-MMU page tables); has VM/console/allocator/traps but no userspace exec path yet. Harvey supplies the userspace, libc, toolchain, and dist machinery; r9 supplies the kernel.
- **Upstream dormant**: Harvey-OS/harvey last commit 2022-03-30; CI was a fragile expect+qemu bootstrap on EOL Ubuntu 21.10 (`.planning/codebase/CONCERNS.md`)
- **Build system**: mk + mkfiles; host tools built by `sys/src/cmd/*/BUILD` scripts; kernel build runs in a Linux mount namespace emulating Plan 9's root layout (`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE` → `BUILD_SETUP_NAMESPACE` → `BUILD` → `build/scripts/linux-build`)
- **Nix scaffolding**: `flake.nix` + `nix/*.sh`; on darwin the namespace build runs in a lima VM (virtiofs subdir binds yield empty trees, so the VM build rsyncs to guest-local disk and pulls `amd64/`+`386/` back)
- **Vendored 9-cc**: `sys/src/cmd/unix/9cc/` carries the `iar` subset of 0intro/9-cc with aarch64 host support (see its README)
- **aarch64 toolchain donors**: 9front (MIT) has `sys/src/cmd/{7a,7c,7l}`, `sys/src/libc/arm64/`, `arm64/mkfile`, libmach `{7.c,7db.c,7obj.c}`, `aout2uimage` — see `.planning/research/STACK.md`. Harvey's libmach wires retired **Alpha** under letter 7 — collides with arm64 7-imports, must be resolved first.
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
| r9 gets its own flake; Harvey consumes r9 via flake input | User decision 2026-10-30 — flakes compose via git URLs; relative paths/submodules are fragile glue | — Pending |
| minimega for VM orchestration, fetched+built by nix (`nix/minimega.nix`, no submodule) | User decision 2026-10-30 — single-binary KVM VM manager with scriptable `.mm` files; upstream is x86/KVM-centric so it covers amd64 test VMs only; aarch64/r9 boots stay on plain qemu | ✓ Good |
| 9k amd64 green before 386/ISO | 9k is the active kernel; limit blast radius of the build-tail milestone | — Pending |
| Kernel bring-up on qemu `-M virt` shell | Smallest provable target; r9's raspi focus needs a virt platform anyway | — Pending |

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
*Last updated: 2026-10-30 after initialization*
