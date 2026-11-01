---
gsd_state_version: "1.0"
current_phase: 3
current_phase_name: r9 qemu-virt Platform Bring-up
status: executing
stopped_at: Phase 3 context gathered
last_updated: "2026-11-01T21:11:50.630Z"
last_activity: 2026-11-01
last_activity_desc: Phase 02 complete, transitioned to Phase 3
state_head: aeee5b0b52298673b5b3c7213ab6d7bb04a2f5ec
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 17
  completed_plans: 11
  percent: 40
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-01)

**Core value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.
**Current focus:** Phase 3 — r9 qemu-virt Platform Bring-up

## Current Position

Phase: 3 (r9 qemu-virt Platform Bring-up) — READY TO EXECUTE
Plan: Not started
Status: Ready to execute
Last activity: 2026-11-01 — Phase 02 complete, transitioned to Phase 3

Progress: [████░░░░░░] 40%

## Performance Metrics

**Velocity:**
- Total plans completed: 11
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 7 | - | - |

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

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 3: `../r9` never audited (adoption decision post-dates research) — map r9 workspace before planning Phase 3
- Phase 4: Harvey↔r9 syscall ABI kernel side greenfield (user side frozen in Phase 2: `aarch64/ABI.md`, execution-validated) — highest-risk phase; consider a spike
- Phase 4: root-fs delivery mechanism to r9 undecided (initrd / embedded blob / virtio-9p escape hatch in v1.x)
- ~~KERNDATE bit-reproducibility policy must be decided in Phase 1 (BUILD-04)~~ RESOLVED by 01-03: pinned git-derived policy documented at build/REPRODUCIBILITY.md and demonstrated bit-identical — Phase 5 reproducibility claims unblocked
- 9k-amd64 post-banner `bad magic` pool panic — same signature as the pswt.c LP64 bug fixed in Phase 2; re-test with the fixed 6c (deferred-items.md #8) before relying on the harness for deeper smoke signals
- Hygiene debt: Phase 1 review items (01-REVIEW-DISPOSITION.md: boot-9k10cpu.sh shebang, KERNDATE fallback, preflight hatch, socat race, checkall cascade) + Phase 2's 13 open Info findings (02-REVIEW-DISPOSITION.md) + WR-04 prompt-proof end-to-end confirmation on the next live TCG gate run; none goal-blocking

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-11-01T20:07:39.498Z
Stopped at: Phase 3 context gathered
Resume file: .planning/phases/03-r9-qemu-virt-platform-bring-up/03-CONTEXT.md
