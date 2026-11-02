---
gsd_state_version: "1.0"
current_phase: 04
current_phase_name: r9 Userspace-Exec + Harvey↔r9 ABI
status: executing
stopped_at: Completed 04-01-PLAN.md
last_updated: "2026-11-02T12:34:58.872Z"
last_activity: 2026-11-01
last_activity_desc: Phase 04 execution started
state_head: cb1784a7f9e1b0b0b1100fe1d4580fe3d6db54f8
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 25
  completed_plans: 18
  percent: 60
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-02)

**Core value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.
**Current focus:** Phase 04 — r9 Userspace-Exec + Harvey↔r9 ABI

## Current Position

Phase: 04 (r9 Userspace-Exec + Harvey↔r9 ABI) — EXECUTING
Plan: 2 of 8
Status: Ready to execute
Last activity: 2026-11-01 — Phase 04 execution started

Progress: [██████░░░░] 60%

## Performance Metrics

**Velocity:**
- Total plans completed: 17
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 7 | - | - |
| 03 | 6 | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 53min | 3 tasks | 12 files |
| Phase 01 P02 | 6min | 2 tasks | 5 files |
| Phase 01 P03 | 8min | 2 tasks | 5 files |
| Phase 01 P04 | 60min | 2 tasks | 9 files |
| Phase 02 P01 | 13 min | 3 tasks | 46 files |
| Phase 02 P02 | 5 min | 2 tasks | 13 files |
| Phase 02 P03 | 19 min | 3 tasks | 28 files |
| Phase 02 P04 | 4h 41m | 2 tasks | 19 files |
| Phase 02 P05 | 11h 18m (incl. human-verify wait) | 2 tasks | 7 files |
| Phase 02 P06 | 6 min | 2 tasks | 9 files |
| Phase 02 P07 | 47 min | 3 tasks | 16 files |
| Phase 03 P01 | 13 min | 1 tasks | 2 files |
| Phase 03 P02 | 5 min | 2 tasks | 12 files |
| Phase 03 P03 | 30 min (incl. human-decision checkpoint) | 2 tasks | 2 files |
| Phase 03 P04 | 26 min | 2 tasks | 12 files |
| Phase 03 P05 | 10 min | 3 tasks | 8 files |
| Phase 03 P06 | 18 min | 2 tasks | 9 files |
| Phase 04 P01 | 33min (continuation; prior segment reached the A3 decision checkpoint) | 3 tasks | 14 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- 2026-10-30: Adopt r9 (sibling `../r9`, Rust) as kernel future — Harvey 9k C aarch64 port is Out of Scope
- 2026-10-30: `aarch64` (not `arm64`) is the project's architecture name — vestiges quarantined in Phase 1
- Roadmap: Phases 3–4 execute in sibling repo `../r9`; Phase 5 spans both repos
- [Phase 01]: 01-01: userland preflight in nix/build.sh is sentinel-armed (amd64/.userland-ok) — inert until a build first produces all four kernel-critical binaries, so clean/repairing runs never deadlock (plan Task 1 NOTE)
- [Phase 01]: 01-01: efiboot.fat is explicit-only (needs a live Plan 9 system: dossrv+/srv+mount); .efi binaries still build+install — unmasked games tree (D-01)
- [Phase 01]: 01-01: NVAR=BITS*32 in cc.h restores exact Plan 9 256-var-cap semantics on LP64 hosts — fixes 6c stack smash (ql SIGBUS); one shared definition fixes all compiler dirs
- [Phase 01]: 01-01: git.allow_default_branch_commits=true — sequential-mode execution commits on master (fork workflow); clean-checkout verification clones the default branch
- [Phase 01]: 01-02: six-site arm64 quarantine in ONE atomic commit 5af5e89bf (D-05 + Pitfall 3 bind-mount coupling); keepers documented (nix host-mapping, lima yaml, a.out.h/mach.h, unix/9cc, dynld-arm64.c)
- [Phase 01]: 01-02: Phase 1 green gate = amd64 kernel loop — linux-build arch=(amd64), dist/man stages behind WITH_DIST=1 (RESEARCH OQ-2/OQ-3); revert comments in place
- [Phase 01]: 01-03: KERNDATE derivation anchored to $HARVEY checkout (cd "$HARVEY" && git log -1 --format=%ct) in both nix entry points — HARVEY!=PWD invocations must not pin the caller's repo
- [Phase 01]: 01-03: reproducibility evidence standard = pinned pair identical + KERNDATE+1 negative control differs + restore matches — falsifies 'deterministic anyway'
- [Phase 01]: 01-03: guest namespace harnesses need su-proof env: re-source captured exports (BUILD's . buildnamespace) + /rc/bin:. PATH tail (repo rc/bin/membername feeds bootmkfile's archive rule)
- [Phase 01]: 01-04: TCG-degraded serial capture ACCEPTED by human (2026-10-31, blocking checkpoint) as BUILD-05's phase demonstration — dev fleet has no KVM host; KVM path documented (nix build .#minimega && sudo build/mm/boot-9k10cpu.sh) for any Linux x86_64 host
- [Phase 01]: 01-04: LP64 wide-constant truncation fixed in amd64 toolchain (6c/swt.c zaddr, 6l/span.c oclass, 6c/cgen.c immconst) — harness surfaced a silently miscompiled kernel; dormant-arch siblings (4c/9c/9a/4l/9l) inventoried + deferred
- [Phase 01]: 01-04: serial capture attaches BEFORE vm start via launch/start .mm split; banner grep (not the boot timer) is the boot-proof source of truth; minimega -e exit status never trusted (socket-appearance gating)
- [Phase 02]: audit-7c7l vindicated: cc/pswt.c LP64 switch-sort miscompile (doswit (long)c->val no-op on LP64 → swcmp signed sort disagrees with swit2's signed target compare tree) was the donor kernel's deterministic "bad magic" pool panic; fixed host-independently as (vlong)(int); Phase-1 9k-amd64 pool panic is the same signature (deferred item 8: re-test with fixed 6c)
- [Phase 02]: donor↔qemu-11.1.2 drift accommodated harness-side only (D-12): gic-version=3, highmem-ecam=off, DTB pre-placement, GICR0 WAKER wake poke via raw-RSP gdbpoke9.py (qemu resets redistributor asleep; donor gic.c never wakes it; no ticks → dead console input), console=0 (kbdfs input device), virtio-net-pci-non-transitional (ethervirtio10 matches only modern 0x1041)
- [Phase 02]: 02-05: TC-03 gate SATISFIED and human-approved — committed hello.7.out executes on the 9front donor kernel (marker after term% prompt, clean exit, sha256 1c89e099 both sides, three consecutive PASS blocks); scaffolding 02-06 unblocked; hello.7.out is Phase 4's ABI bisect point
- [Phase 02]: 02-05: guest path resolution — CONF=qemu bootdir embed lands at /boot/hello (devroot exposes only boot/); bootfs.paq is unmounted before the shell so paq-baked binaries are unrunnable at the rc prompt; mkpaqfs not re-run
- [Phase 02]: 02-05: bake-vs-ufs resolved in build/aarch64/README.md (research OQ-2) — bake-into-bootfs for gates (deterministic), ufs-over-tcp for iteration (ethervirtio10 + ip stack; srv9.py proves host 9P2000/tcp to this guest)
- [Phase 02]: 02-07: subset lib set = the #pragma-lib closure discovered at link time (libbio libregexp libndb libString libthread lib9p beyond the named libip/libmp/libsec/libauth/libauthsrv); libbio precedes the 7? loop (7a/a.h includes bio.h); factotum ships via per-target install (fgui's graphics stack is out of scope)
- [Phase 02]: 02-07: mpvecdigmulsub split into its own libmp port file retires the 2021 PORT rename — archive member names now align 1:1 with text symbols (empty-arch dirs get portable C, asm arches cull via reduce, ape's broken-bind reduce can never duplicate-symbol)
- [Phase 02]: 02-07: srv9.py --writable-prefix (opt-in, scoped) is the guest's writable-scratch mechanism (kernel MCREATE bind already permits /tmp); nix run .#build rc is never trusted — artifact checks + zero-failure-marker log scan are the gate (BUILD's break-glass bash tail swallows statuses, deferred item 12)
- [Phase 03]: 03-03: tcg/cortex-a72 built-in defaults fire only on the virt arm — existing raspi TOMLs sprout no new argv (backward-compat holds end-to-end, verbose-probe verified); darwin runs TCG this phase (HVF rejects GICv2 on qemu 11.1.2, research P2), hvf remains selectable for a future GICv3 driver
- [Phase 03]: 03-03: superseded apply_to_qemu_step free function removed outright instead of kept as a delegating shim — xtask-internal API with a single call site; a compat wrapper would be dead code
- [Phase 03]: 03-03: written raspi3b boot-smoke gate satisfied by substituted A/B evidence (human decision A, 2026-11-01) — identical pre-existing raspi3b-on-qemu-11.1.2 guest abort at FAR 0xfe215004 pre-plan (6a309ae/ae4cd08) and post-plan with byte-identical raspi argv proves NO REGRESSION; upstream defect (rpi4 AUX_ENABLES MMIO on raspi3b machine; suspect init_early_uart_rpi4) deferred
- [Phase 03]: 03-03: darwin qemu smoke isolation — setsid absent on macOS; backgrounded subshell + pkill -f with bracket-fixed pattern ([q]emu-system-aarch64.*raspi3b) so pkill cannot self-match the harness shell argv
- [Phase 03]: 03-06: D-12 delivered as --config virtpanic (virt-specific name; mechanism/trigger/dump as decided) — brk #0 hook before trap::unmask_irq() runs the real sync trap path; TrapFrame Debug uses bare x29/x30 names so dump rows are machine-countable (the plan's >=30-row gate was unsatisfiable with annotated names)
- [Phase 03]: 03-06: RustupState tolerates rustup-absent hosts (nix devshell) — cargo xtask check/test degrade to bins/lib legs via existing Option handling instead of panicking; pre-existing panic proven on the clean tree
- [Phase 03]: 03-06: evidence commit ordering (D-13/T-03-09) — r9 commits land first, EVIDENCE.md records that exact HEAD SHA (55ca7c4), harvey evidence commit second; the verify gate requires the recorded SHA to match the live checkout
- [Phase 04]: D-01 AMENDED (04-01, user decision A): qemu 11.1.2 never delivers -initrd for ELF kernels (hw/arm/boot.c: ELF => not-linux), falsifying assumption A3. Root-fs/initrd delivery is now qemu generic loader at a TOML-data PA + xtask-produced fdtput-patched DTB copy carrying /chosen linux,initrd-start/end (two 32-bit BE cells, hi first — dtc has no 8-byte type). Kernel /chosen discovery/validation/reservation unchanged; ELF boot preserved per D-05. — D-01's locked mechanism (qemu -initrd + DTB /chosen) was written against the assumption that qemu loads -initrd for ELF kernels; source inspection + serial evidence falsified it. The loader+patched-DTB replacement keeps every downstream consumer (kernel /chosen parse, validation, pagealloc reservation) identical — only the host-side delivery and DTB handoff change.
- [Phase 04]: D-14 measured hello-path syscall set (04-01, donor pin 350266104f, primary startsyscall+/proc/N/syscall method): 51 pwrite, 14 open (#c/pid), 50 pread, 4 close, 8 exits — fmt/pool pulls no brk_/segbrk on this path. 04-06/07/08 implement exactly this set plus D-14's named core. — Measured, not guessed (D-14). The open/pread/close triplet is the exits path resolving its own pid via #c/pid; the absence of brk_/segbrk settles the fmt/pool watch item by evidence.

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4: Harvey↔r9 syscall ABI kernel side greenfield (user side frozen in Phase 2: `aarch64/ABI.md`, execution-validated) — highest-risk phase; consider a spike
- Phase 4: root-fs delivery mechanism to r9 undecided (initrd / embedded blob / virtio-9p escape hatch in v1.x)
- Phase 4: WR-01 — the virt TTBR0 identity map (0–1 GiB Normal/RW/executable, covering GIC+PL011 MMIO) is never torn down post-boot; raspi's user-table switch is cfg'd out on virt — consider explicitly in Phase 4 planning (03-REVIEW-DISPOSITION.md)
- ~~KERNDATE bit-reproducibility policy must be decided in Phase 1 (BUILD-04)~~ RESOLVED by 01-03: pinned git-derived policy documented at build/REPRODUCIBILITY.md and demonstrated bit-identical — Phase 5 reproducibility claims unblocked
- 9k-amd64 post-banner `bad magic` pool panic — same signature as the pswt.c LP64 bug fixed in Phase 2; re-test with the fixed 6c (deferred-items.md #8) before relying on the harness for deeper smoke signals
- Hygiene debt: Phase 1 review items (01-REVIEW-DISPOSITION.md) + Phase 2's 13 open Info findings (02-REVIEW-DISPOSITION.md) + Phase 3's 5 open warnings / 10 open Info (03-REVIEW-DISPOSITION.md; WR-02 boot-test platform guard, WR-03 raspi uartpl011 gpiosetpull MMIO window, WR-04 map_phys_range swallowed mid-range failure, WR-05 timer INTID DTB-mismatch warn-only) + upstream raspi3b-on-qemu-11.1.2 defect (phase-03 deferred-items.md #1, human-accepted A/B evidence); none goal-blocking

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-11-02T12:34:53.637Z
Stopped at: Completed 04-01-PLAN.md
Resume file: None
