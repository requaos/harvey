---
phase: 06
review: 06-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: fixed
    title: "tier-donor CI leg cannot pass on a clean runner — no step clones or builds the donor"
  - id: WR-01
    severity: warning
    disposition: open
    title: "The LP64 Ieee-emission fix was applied to 7l only — 6l and 9l carry the identical proven-faulty pattern"
  - id: WR-02
    severity: warning
    disposition: open
    title: "mk tier filters silently produce an empty aarch64 sweep when $HARVEY is unset"
  - id: WR-03
    severity: warning
    disposition: open
    title: "generator-scan.sh's audit-row selector silently skips G10+ rows"
  - id: WR-04
    severity: warning
    disposition: open
    title: "tracesup.c armed/kids arrays grow without a bounds check"
  - id: WR-05
    severity: warning
    disposition: open
    title: "mkimage.sh line 235 is dead, known-broken code left armed"
  - id: WR-06
    severity: warning
    disposition: open
    title: "subset-exec.sh marker asserts are unanchored substring greps (mk⊂mkdir, cp⊂cpp)"
  - id: WR-07
    severity: warning
    disposition: open
    title: "ledger-r9-append.sh uses bash-only process substitution under #!/bin/sh, plus undisciplined grep/sha256sum"
  - id: WR-08
    severity: warning
    disposition: open
    title: "gethunk-repro-6l.sh's \"built fresh every run\" claim is narrower than the code"
  - id: IN-01
    severity: info
    disposition: open
    title: "run-gate.sh's remediation hint points at a script that refuses to run"
  - id: IN-02
    severity: info
    disposition: open
    title: "mkimage.sh duplicate input asserts"
  - id: IN-03
    severity: info
    disposition: open
    title: "generator-scan verifies only G6's guard mechanically"
  - id: IN-04
    severity: info
    disposition: open
    title: "gethunk reset pattern survives in the out-of-scope linkers"
open: 12
total: 13
recorded: 2026-11-05T13:14:57.959Z
---
# Phase 06: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | fixed | closed by retirement 2026-11-05 — tier-donor CI leg removed per maintainer direction; the x86_64 venue is Harvey's own kernel (06-09/06-10); venue-pin step asserts the retirement |
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| WR-05 | warning | open | - |
| WR-06 | warning | open | - |
| WR-07 | warning | open | - |
| WR-08 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
