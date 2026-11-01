# Roadmap: Harvey OS — Build Revival + aarch64 Port

## Overview

Revive Harvey's dormant build factory first (9k amd64 green from a clean checkout), then import the 9front aarch64 toolchain and libc under the project's `aarch64` naming — gated by a 7l-linked hello-world before any arch scaffolding lands (the riscv64 vaporware rule). With userspace binaries buildable, bring up r9 (sibling repo `../r9`, Rust Plan 9 kernel) on qemu `-M virt` aarch64, grow its missing userspace-exec path behind a statically-verified Harvey↔r9 syscall ABI, and finish with one command that boots r9 plus the Harvey aarch64 userland to an interactive `/bin/rc` shell — reproducible on darwin-aarch64 and linux.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Build-Tail Green (9k amd64)** - Fix cmd-chain aborts so `nix run .#build` produces k10cpu + k10cpuf + k10f from a clean checkout; quarantine `arm64` vestiges; pin reproducibility policy (completed 2026-10-31)
- [ ] **Phase 2: aarch64 Toolchain + libc (9front donor)** - Vendor 7a/7c/7l + libmach arm64 + libc/aarch64; 7l-linked hello-world gate before any arch scaffolding; shell-subset userland builds for aarch64
- [ ] **Phase 3: r9 qemu-virt Platform Bring-up** - *(cross-repo: `../r9`)* r9 aarch64 boots on qemu `-M virt`: kernel entry, memory map, GICv2, PL011 console, generic timer
- [ ] **Phase 4: r9 Userspace-Exec + Harvey↔r9 ABI** - *(cross-repo: `../r9`)* EL0 entry/exit, `svc` syscall dispatch matching Harvey's frozen user-side ABI, first-process loading, trap-frame static checks
- [ ] **Phase 5: Shell Boot + One-Command Integration** - One command boots r9 + Harvey aarch64 userland to `/bin/rc`; expect smoke test green on darwin-aarch64 and linux; clean-checkout reproducibility verified

## Phase Details

### Phase 1: Build-Tail Green (9k amd64)

**Goal**: The Harvey namespace build is a trustworthy factory — a clean checkout produces the full 9k amd64 kernel set with zero manual intervention, and the tree speaks `aarch64` only.
**Depends on**: Nothing (first phase)
**Requirements**: BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-05
**Success Criteria** (what must be TRUE):
  1. `nix run .#build` from a clean checkout completes the full namespace build and produces `amd64/9k10cpu`, `amd64/9k10cpuf`, and `amd64/9k10f` (plus `.elf` variants) in one run — the `jpg/mkfile` `oc` derivation and `4a` `rfork bind lex.c` failures are gone
  2. The userland install leaves `/amd64/bin` carrying `ip/ipconfig`, `auth/factotum`, and `venti/venti`, so embedded-root kernels link with no "don't know how to make" errors
  3. No live `arm64`-named vestiges remain in build scripts or tree layout (`build_arm64` functions, empty `arm64/` dir, `build/mkdirs` entry renamed or quarantined) — grep finds only documented/quarantined references
  4. A KERNDATE/reproducibility policy is decided and documented in-repo, and the build demonstrably honors it (two clean builds identical, or the timestamp exception written down)
  5. `nix build .#minimega` produces the VM orchestration binary on linux, and a committed `.mm` script boots the Phase 1 `9k10cpu` kernel on a Linux KVM host (kernel boot log captured) — the smoke harness for everything after

**Plans**: 4/4 plans complete
**Wave 1**
- [x] 01-01-PLAN.md — Build-green spine: fix jpg/jtagfs generator idioms, userland preflight, D-04 whack-a-mole to all three kernels + clean-checkout verify + checkall target
- [x] 01-02-PLAN.md — Legacy arm64 quarantine (six-site atomic commit, D-05) + linux-build scope gates (amd64-only, WITH_DIST)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-03-PLAN.md — KERNDATE pinning at both mkfile sites, host-side derivation plumbing, REPRODUCIBILITY.md + bit-identical rebuild demo
- [x] 01-04-PLAN.md — minimega smoke harness: boot-9k10cpu.mm + capture/assert wrapper + KVM/TCG boot demonstration checkpoint

### Phase 2: aarch64 Toolchain + libc (9front donor)

**Goal**: Harvey can compile and link its own aarch64 Plan 9 binaries on darwin-aarch64 and linux-aarch64 hosts — the toolchain, libc, and objtype wiring exist and are proven by real binaries, not scaffolding.
**Depends on**: Phase 1 (green namespace build is the harness; BUILD-03's naming quarantine is this phase's entry point)
**Requirements**: TC-01, TC-02, TC-03, TC-04, TC-05
**Success Criteria** (what must be TRUE):
  1. `7a`, `7c`, and `7l` are vendored from 9front into `sys/src/cmd/` with BUILD scripts and build natively via the existing toolchain app on darwin-aarch64 and linux-aarch64 (`compat.h` frontend drift reconciled)
  2. `nm`/`acid` operate on 7l aarch64 objects — libmach arm64 support (`7.c`/`7db.c`/`7obj.c`/setmach) landed with the retired-Alpha letter-7 collision resolved
  3. A 7c-compiled, 7l-linked hello-world aarch64 binary is produced and runs (e.g. qemu user-mode), committed **before** any `aarch64/` arch dir, libc dir, or `CPUS` entry lands (riscv64 `jc/jl/ja` vaporware rule)
  4. `objtype=aarch64` build wiring works end-to-end: `aarch64/mkfile` (CC=7c O=7), `pcc.c` objtype entry, `mkfile.proto` CPUS, config section literally named `aarch64`
  5. The shell-boot userland subset (`rc`, `ipconfig`, `factotum`, core cmds) builds for aarch64 with `sys/src/libc/aarch64/` + generated `9syscall` SVC stubs — these stubs freeze the user side of the Harvey↔r9 ABI

**Plans**: 4/7 plans executed (5 waves)
**Wave 1**
- [x] 02-01-PLAN.md — Vendor 7a/7c/7l from pinned 9front + nine-shim set (+ planner-found thestring shim) + host builds + BUILDTOOLCHAIN wiring + native-compile sweep check (TC-02)
- [x] 02-02-PLAN.md — Alpha excision (D-04/D-05) + libmach arm64: vendored 7.c/7db.c/7obj.c + setmach/exectab/objtable wiring (TC-01)

**Wave 2** *(blocked on Wave 1)*
- [x] 02-03-PLAN.md — case aarch64 ABI-freeze generator + callmain.c + libc/aarch64 verbatim import + pre-gate namespace build → committed hello.7.out + host nm (TC-03 build half, TC-01 functional)
- [x] 02-04-PLAN.md — Donor-kernel harness: in-donor-tree CONF=qemu build with our 7a/7c/7l in lima (D-07) + TCG boot-to-shell with serial proof (TC-03 harness)

**Wave 3** *(blocked on Wave 2)*
- [ ] 02-05-PLAN.md — THE GATE (tracer): hello-world executes on the 9front donor kernel, evidence committed before any scaffolding (D-06, SC#3) + harness README (D-10 pin record)

**Wave 4** *(blocked on Wave 3 — vaporware rule)*
- [ ] 02-06-PLAN.md — TC-04 objtype wiring: aarch64/mkfile + verbatim headers + ABI.md freeze doc + pcc.c + CPUS/OS + mkdirs + .gitignore + CURCC

**Wave 5** *(blocked on Wave 4)*
- [ ] 02-07-PLAN.md — TC-05 shell subset (rc, grep, ipconfig, factotum, 12 core cmds) builds + executes on donor kernel (D-08) + D-09 NMOUNT nm audit + build_aarch64 activation + full dual-arch regression

### Phase 3: r9 qemu-virt Platform Bring-up

**Goal**: r9's aarch64 crate boots on qemu `-M virt` — kernel console, interrupts, and timer proven on the milestone's actual target machine before any userspace-exec work begins. **All work in this phase happens in the sibling repo `../r9`.**
**Depends on**: Phase 2 (serial recommended — shared qemu harness and naming cleanup; r9 itself is cargo-built and has no hard Harvey-build dependency)
**Requirements**: R9-01, R9-05
**Success Criteria** (what must be TRUE):
  1. `../r9` carries its own `flake.nix` (R9-05): devshell with the pinned rust toolchain (incl. `llvm-tools`/`llvm-objcopy`), qemu, and `cargo xtask` — `nix develop` + `cargo xtask build --arch aarch64` reproduces the kernel on darwin-aarch64 and linux with zero host setup
  2. The qemu serial log shows the r9 kernel banner on `qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -smp 1 -nographic` — ELF `-kernel` entry with DTB at `0x40000000` works
  3. GICv2 (`0x08000000`) is initialized and the ARM generic timer IRQ fires on schedule — the log shows periodic ticks
  4. PL011 console (`0x09000000`) runs polled-then-IRQ: typed input is received interrupt-driven and visible in the kernel log
  5. A deliberate kernel panic prints registers/stack on the console and halts cleanly (no silent wedge) — the debug path for Phase 4 exists

**Plans**: TBD

**Pre-planning flag**: `/gsd-map-codebase` (or equivalent audit) on `../r9` before planning — the research run never inspected it (r9 adoption post-dates research). Map the platform abstraction, raspi boot structure, trap frames, and xtask qemu wiring first.

### Phase 4: r9 Userspace-Exec + Harvey↔r9 ABI

**Goal**: r9 can load and run Harvey aarch64 userland binaries — the cross-repo syscall ABI is designed, implemented on both sides, and mismatch is a build failure, not a runtime mystery. **Work spans both repos: kernel side in `../r9`, user side anchored to this repo's Phase 2 imports.**
**Depends on**: Phase 2 (Harvey aarch64 binaries + frozen user-side ABI: SVC stubs + `aarch64/include/ureg.h`), Phase 3 (proven console/IRQ/timer on the target machine)
**Requirements**: R9-02, R9-03, R9-04
**Success Criteria** (what must be TRUE):
  1. The Harvey↔r9 syscall ABI contract is written down in one canonical place and enforced by build-time static checks — r9's Rust trap frame matches Harvey's `aarch64/include/ureg.h` field-for-field (pinned offsets; a mismatch fails the build)
  2. A Harvey aarch64 test binary (Phase 2's hello-world) executes on r9 under qemu virt and prints via the real syscall path — EL0 entry/return and `svc` dispatch (args at `SP_EL0+0`, number in R0, result in R0) work
  3. r9's first-process path loads a Harvey aarch64 `init` from an embedded root-fs or equivalent delivery, faulting in user text and growing the user stack (with icache maintenance after text load)
  4. A syscall smoke suite (rfork, notes, basic fd ops) runs from EL0 without kernel panic — exercised before the full shell is attempted

**Plans**: TBD

**Pre-planning flag**: Highest-risk phase (greenfield design — no donor transfers directly). Root-fs delivery mechanism to r9 is undecided (qemu `-initrd`? cargo-embedded blob?); consider a spike before full planning. virtio-9p is the documented v1.x escape hatch.

### Phase 5: Shell Boot + One-Command Integration

**Goal**: The Core Value is delivered — one command, on either host OS, from clean checkouts of both repos, boots r9 plus the Harvey aarch64 userland to an interactive `/bin/rc` shell. **Work spans both repos plus the flake glue.**
**Depends on**: Phase 4
**Requirements**: INT-01, INT-02, INT-03, INT-04
**Success Criteria** (what must be TRUE):
  1. A single command (`nix run` app or `cargo xtask`) boots r9 + Harvey aarch64 userland to an interactive `/bin/rc` prompt over the PL011 console in qemu
  2. At the prompt, rc builtins and external binaries (`ls`, `cat`, `echo`, `ps`) execute correctly
  3. An expect-style smoke test asserting the rc prompt passes on darwin-aarch64 (lima for the Harvey namespace build, native qemu) and linux hosts — CI green on both
  4. From clean checkouts of both repos, the documented commands reproduce the boot with pinned toolchains/qemu — honoring Phase 1's KERNDATE/reproducibility policy
  5. Harvey's `flake.nix` consumes r9 as a flake input (pinned git rev) — the integration glue lives in the flakes, not in `../r9` relative paths or git submodules (INT-04)

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Build-Tail Green (9k amd64) | 4/4 | Complete    | 2026-10-31 |
| 2. aarch64 Toolchain + libc | 4/7 | In Progress|  |
| 3. r9 qemu-virt Platform Bring-up | 0/TBD | Not started | - |
| 4. r9 Userspace-Exec + Harvey↔r9 ABI | 0/TBD | Not started | - |
| 5. Shell Boot + One-Command Integration | 0/TBD | Not started | - |
