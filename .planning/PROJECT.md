# Harvey OS — Build Revival + aarch64 Port

## What This Is

Harvey OS is a Plan 9 4th Edition derivative operating system (C, mk-based build, dual kernel trees: legacy `sys/src/9/` and active amd64 `sys/src/9k/`). This project revives the dormant upstream build (last upstream commit 2022-03-30), modernizes the dev environment with Nix, and ports Harvey to aarch64 (ARM64).

## Core Value

Harvey builds green from a clean checkout and boots on aarch64 under qemu — one command, any host (macOS or Linux).

## Requirements

### Validated

- ✓ Nix devshell + flake apps (`setup`/`toolchain`/`build`/`iso`) implement the BUILD_ON_UNIX flow — committed `a1735e67f`
- ✓ Native aarch64 host toolchain (Plan 9 compilers 6a/6c/6l, 8a/8c/8l, cpp, pcc, vendored `iar`) builds on darwin-aarch64 and linux-aarch64 — committed `a1735e67f`
- ✓ 9k amd64 kernel (`k10cpu`) builds via the lima-VM namespace build on macOS hosts — validated this session (`amd64/9k10cpu`, `.elf`)
- ✓ Codebase map + knowledge graph for navigation — `.planning/codebase/`, `.planning/graphs/`
- ✓ amd64 libc + core userspace libraries build green in the namespace build — this session

### Active

- [ ] Full 9k amd64 kernel set green: k10cpu + k10cpuf + k10f (embedded-root variants) — currently blocked by cmd-chain failures (`cc` suite `o^c rgbycc.c`, `4a` `rfork bind lex.c`, venti/ipconfig never installed)
- [ ] aarch64 target toolchain in-repo: 7a/7c/7l (assembler/compiler/linker) + libc aarch64 + `objtype=aarch64` build wiring
- [ ] 9k kernel aarch64 port booting to a shell on qemu `-M virt`
- [ ] Build artifacts reproducible from clean checkout on darwin-aarch64 and linux

### Out of Scope

- 386 legacy kernel (`sys/src/9/pc`) and the ISO/dist stage — deferred; focus is 9k amd64 health first
- Hardware aarch64 targets (RPi4 etc.) — qemu virt only this milestone; drivers come later
- TLS/security modernization (TLS 1.2 cap, RC4/DES/NULL ciphers) — separate hardening milestone
- Dual `9` vs `9k` kernel-tree deduplication — tracked concern, not this milestone
- x86_64-darwin host support — repo targets aarch64 hosts first

## Context

- **Upstream dormant**: Harvey-OS/harvey last commit 2022-03-30; CI was a fragile expect+qemu bootstrap on EOL Ubuntu 21.10 (`.planning/codebase/CONCERNS.md`)
- **Build system**: mk + mkfiles; host tools built by `sys/src/cmd/*/BUILD` scripts; kernel build runs in a Linux mount namespace emulating Plan 9's root layout (`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE` → `BUILD_SETUP_NAMESPACE` → `BUILD` → `build/scripts/linux-build`)
- **Nix scaffolding**: `flake.nix` + `nix/*.sh`; on darwin the namespace build runs in a lima VM (virtiofs subdir binds yield empty trees, so the VM build rsyncs to guest-local disk and pulls `amd64/`+`386/` back)
- **Vendored 9-cc**: `sys/src/cmd/unix/9cc/` carries the `iar` subset of 0intro/9-cc with aarch64 host support (see its README)
- **aarch64 scaffolding**: `build_arm64` in `build/scripts/funcs` references `sys/src/cmd/7?` which do not exist — the port starts from zero toolchain; Plan 9 arm64 references exist upstream (9front/9legacy 7c/7a/7l, bcm kernel port)
- **Known upstream breakage**: cmd install chain aborts partway (`cc` maketab/rgbycc, `4a` lex.c bind), so `ipconfig`/`venti` never reach `/amd64/bin` and root-embedding kernels (k10cpuf/k10f) fail; `mahjonng` cpp breakage noted in Dockerfile TODO

## Constraints

- **Tech stack**: Plan 9 C dialect + mk; host tools must build with plan9port (`$PLAN9/bin` LAST in PATH per BUILD_ON_UNIX)
- **Host platforms**: darwin-aarch64 (primary dev machine) and linux aarch64/x86_64; kernel build requires Linux mount namespaces (lima VM on macOS)
- **Compatibility**: keep upstream Harvey/Plan 9 conventions (`sys/man/6/style`: tabs, lowercase, `nil`, `exits`/`sysfatal`)
- **Naming**: the 64-bit ARM architecture is `aarch64` (not `arm64`) in this project's tooling and docs
- **Upstream**: dormant; this repo is now the maintained fork — in-tree fixes are preferred over external patch stacks

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nix flake for devshell + build apps | Reproducible toolchain across darwin/linux without Docker-on-EOL-Ubuntu | ✓ Good |
| Vendor 9-cc `iar` subset in-repo (`sys/src/cmd/unix/9cc/`) | External dep kept failing on aarch64 hosts (C23/glibc collisions); in-repo code we control | ✓ Good |
| VM build rsyncs to guest-local disk | virtiofs subdirectory bind-mounts silently return empty trees — namespace build cannot run on the shared mount | ✓ Good |
| Per-OS/arch host bin dirs (`.build/hostbin-<os>-aarch64`) | Host and guest builds share the checkout; binaries must not clobber each other | ✓ Good |
| plan9port `$PLAN9/bin` LAST in PATH | plan9port ships a 9p `mount` that shadows util-linux mount; BUILD_ON_UNIX mandates last | ✓ Good |
| aarch64 (not arm64) naming | User decision 2026-10-30 | ✓ Good |
| 9k amd64 green before 386/ISO | 9k is the active kernel; limit blast radius of the build-tail milestone | — Pending |
| aarch64 port targets qemu `-M virt` shell | Smallest provable kernel port; hardware later | — Pending |

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
