---
phase: 18
review: 18-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: open
    title: "Ungated `/dev/hostowner` write defeats the devcap eve gate (authorization bypass)"
  - id: CR-02
    severity: critical
    disposition: open
    title: "RDRAND CPUID bit read from leaf 7 ECX instead of leaf 1 ECX (entropy source misclassification)"
  - id: WR-01
    severity: warning
    disposition: open
    title: "One-byte stack overflow in `authdomain-gen -V`/`-i` on a manifest of exactly `Filecap` bytes"
  - id: WR-02
    severity: warning
    disposition: open
    title: "Generator accepts passwords the donor `passtokey` silently truncates at 27 chars"
  - id: IN-01
    severity: info
    disposition: open
    title: "Workflow comment overstates the CI contract — the secstore round-trip is NAMED-SKIPPED, not exercised"
  - id: IN-02
    severity: info
    disposition: open
    title: "Sweep's secondary probe address lives outside the netaddr seam"
  - id: IN-03
    severity: info
    disposition: open
    title: "Modulo bias in `genpassword`"
  - id: IN-04
    severity: info
    disposition: open
    title: "Necessity — tick-hook infrastructure feeds a value that provably nothing reads"
  - id: IN-05
    severity: info
    disposition: open
    title: "Whitespace-bearing local-file passwords break the sweep's factotum leg non-obviously"
open: 9
total: 9
recorded: 2026-11-14T07:28:41.771Z
---

# Phase 18: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | open | - |
| CR-02 | critical | open | - |
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
