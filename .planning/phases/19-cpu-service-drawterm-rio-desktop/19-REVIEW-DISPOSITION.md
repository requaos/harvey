---
phase: 19-cpu-service-drawterm-rio-desktop
padded: "19"
source: [19-REVIEW.md]
recorded: 2026-11-17
open: 5
fixed: 0
skipped: 0
deferred: 0
---

# Phase 19 Code Review Disposition

One row per finding in [19-REVIEW.md](19-REVIEW.md). Dispositions: `open` (untouched),
`fixed` (a fix landed), `skipped` (won't fix, reason in Source), `deferred` (reopener
recorded, reason in Source). Hand-edit the Disposition and Source cells to triage; keep
the enum vocabulary exact.

| ID | Title | Severity | Disposition | Source |
|----|-------|----------|-------------|--------|
| CR-01 | One-byte stack out-of-bounds write in `verify()`/`info()` when a staged file is exactly Filecap bytes | critical | open | awaiting triage |
| WR-01 | Modulo bias in generated passwords (`alph[r[i] % 62]`) | warning | open | awaiting triage |
| WR-02 | `FdGroup::op_done` merges the streaming offset into a possibly REFILLED slot — the comments' premise contradicts the op_ref design | warning | open | awaiting triage |
| IN-01 | devssl secrets and RC4 state are freed without zeroization — key material persists in kernel heap | info | open | awaiting triage |
| IN-02 | Impossible-state guard — `check_data_bss_below_ustop` cannot fire for any parseable header | info | open | awaiting triage |

## Legend

- Rows default to `open`; a row records what happened to a finding, never whether it mattered.
- `deferred` rows carry their reopener in the Source cell.
