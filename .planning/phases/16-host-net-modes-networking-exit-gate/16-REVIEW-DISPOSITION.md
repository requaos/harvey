---
phase: 16
generated: 2026-11-11
review: 16-REVIEW.md
status: open
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
open: 7
fixed: 0
skipped: 0
deferred: 0
---

# Phase 16 Review Disposition

One row per finding from [16-REVIEW.md](16-REVIEW.md). Disposition defaults to
`open`; a row changes only when the finding is actually fixed (via
`/gsd:code-review 16 --fix`, recorded in 16-REVIEW-FIX.md) or explicitly
triaged below by hand (`deferred`/`skipped` **with a reason**).

| ID | Severity | Title | Disposition | Source |
|----|----------|-------|-------------|--------|
| WR-01 | warning | Unpinned `actions/checkout@v4` in the boot-smoke job (supply-chain rule the file itself states) | open | 16-REVIEW.md |
| WR-02 | warning | `r9-netdev-args` does not enforce its own no-spaces token contract for caller-supplied `--pcap`/`--config` values | open | 16-REVIEW.md |
| WR-03 | warning | `boot-r9-net-smoke-x64` app lacks `procps` for its `pkill` survivor sweep — the sweep can silently no-op | open | 16-REVIEW.md |
| IN-01 | info | `host-echo` accepts port arguments above 65535 via strtoul truncation | open | 16-REVIEW.md |
| IN-02 | info | `r9-netdev-args` silently accepts duplicate `--mode`/`--pcap`/`--config` flags (last wins) | open | 16-REVIEW.md |
| IN-03 | info | The five-TOML consistency test checks presence, not value equality — the documented "identical mode tables" invariant is not machine-checked | open | 16-REVIEW.md |
| IN-04 | info | net-doctor's default `--mode all` hard-fails outside the Harvey checkout, contradicting the header's "HARVEY optional" framing | open | 16-REVIEW.md |

**open: 7 of 7** (0 fixed, 0 skipped, 0 deferred)
