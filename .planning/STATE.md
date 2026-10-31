---
gsd_state_version: "1.0"
current_phase: 01
current_phase_name: Build-Tail Green (9k amd64)
status: executing
stopped_at: "Completed 01-01-PLAN.md (build tail green: 3 kernels, populated amd64/bin, checkall)"
last_updated: "2026-10-31T01:53:18.167Z"
last_activity: 2026-10-30
last_activity_desc: Phase 01 execution started
state_head: 7d481452bcee590a13fcdf584600c76c26637e7d
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 4
  completed_plans: 1
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-10-30)

**Core value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.
**Current focus:** Phase 01 — Build-Tail Green (9k amd64)

## Current Position

Phase: 01 (Build-Tail Green (9k amd64)) — EXECUTING
Plan: 2 of 4
Status: Ready to execute
Last activity: 2026-10-30 — Phase 01 execution started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 53min | 3 tasks | 12 files |

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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 3: `../r9` never audited (adoption decision post-dates research) — map r9 workspace before planning Phase 3
- Phase 4: Harvey↔r9 syscall ABI undesigned (user side freezes in Phase 2; kernel side greenfield) — highest-risk phase; consider a spike
- Phase 4: root-fs delivery mechanism to r9 undecided (initrd / embedded blob / virtio-9p escape hatch in v1.x)
- KERNDATE bit-reproducibility policy must be decided in Phase 1 (BUILD-04) — Phase 5 reproducibility claims depend on it

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-10-31T01:53:18.154Z
Stopped at: Completed 01-01-PLAN.md (build tail green: 3 kernels, populated amd64/bin, checkall)
Resume file: None
