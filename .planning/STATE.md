---
gsd_state_version: "1.0"
current_phase: 02
current_phase_name: aarch64 Toolchain + libc (9front donor)
status: executing
stopped_at: Completed 02-01-PLAN.md
last_updated: "2026-10-31T16:53:56.322Z"
last_activity: 2026-10-31
last_activity_desc: Phase 02 execution started
state_head: 9e6d92c66c2fdaf1f7f0ee96af1a7dcbcfdc0ac4
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 11
  completed_plans: 5
  percent: 20
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-10-31)

**Core value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.
**Current focus:** Phase 02 — aarch64 Toolchain + libc (9front donor)

## Current Position

Phase: 02 (aarch64 Toolchain + libc (9front donor)) — EXECUTING
Plan: 2 of 7
Status: Ready to execute
Last activity: 2026-10-31 — Phase 02 execution started

Progress: [██░░░░░░░░] 20%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |

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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 3: `../r9` never audited (adoption decision post-dates research) — map r9 workspace before planning Phase 3
- Phase 4: Harvey↔r9 syscall ABI undesigned (user side freezes in Phase 2; kernel side greenfield) — highest-risk phase; consider a spike
- Phase 4: root-fs delivery mechanism to r9 undecided (initrd / embedded blob / virtio-9p escape hatch in v1.x)
- ~~KERNDATE bit-reproducibility policy must be decided in Phase 1 (BUILD-04)~~ RESOLVED by 01-03: pinned git-derived policy documented at build/REPRODUCIBILITY.md and demonstrated bit-identical — Phase 5 reproducibility claims unblocked
- Phase 2: post-banner `bad magic` pool panic in 9k embedded-root `boot` (deferred-items #2) — 9k amd64 boots to banner only; fix before relying on the harness for deeper smoke signals
- Phase 2: open code-review debt carried in 01-REVIEW-DISPOSITION.md — CR-01 (boot-9k10cpu.sh has no shebang; `sudo` direct invocation fails on dash hosts) + WR-01..04 (KERNDATE silent fallback, preflight deadlock hatch, socat attach race, checkall cd cascade); none goal-blocking, fix early in Phase 2

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-31T16:53:56.298Z
Stopped at: Completed 02-01-PLAN.md
Resume file: None
