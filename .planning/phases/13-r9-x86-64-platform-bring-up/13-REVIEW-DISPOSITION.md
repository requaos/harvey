---
phase: 13
review: 13-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: open
    title: "intrspecial marks the SWAPPED witness bit in the saved RIP word, not the saved CS word — wrong slot arithmetic (+16 vs +24)"
  - id: WR-01
    severity: warning
    disposition: open
    title: "q35net discovery-to-bind stage anchor is a satisfaction-time capture.len() — the same-burst hazard the file documents and fixed one stage earlier"
  - id: WR-02
    severity: warning
    disposition: open
    title: "gen_trap_stub!(8) has a dead second arm — double fault routes through intrregular, contradicting the documented special-handling set"
  - id: WR-03
    severity: warning
    disposition: open
    title: "New CI job boot-test-x86-64 has no timeout-minutes"
  - id: WR-04
    severity: warning
    disposition: open
    title: "Dead ISA-override fold chain whose staging justification is contradicted by the landed bind"
  - id: IN-01
    severity: info
    disposition: open
    title: "devcons probe printed-loudly failure path is a silent no-op"
  - id: IN-02
    severity: info
    disposition: open
    title: "Boot-test budget env overrides silently ignore unparseable values"
  - id: IN-03
    severity: info
    disposition: open
    title: "platform/mod.rs cfg arms are token-identical — the attributes cannot change what compiles"
  - id: IN-04
    severity: info
    disposition: open
    title: "New CI job copies actions/checkout@v3 — stale floating major, not hash-pinned"
open: 9
total: 9
recorded: 2026-11-07T17:32:14.462Z
---

# Phase 13: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | open | - |
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.

