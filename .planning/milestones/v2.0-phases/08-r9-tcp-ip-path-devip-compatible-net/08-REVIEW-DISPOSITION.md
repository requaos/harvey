---
phase: 08-r9-tcp-ip-path-devip-compatible-net
review: 08-REVIEW.md
fix_report: 08-REVIEW-FIX.md
findings:
  total: 20
  critical: 7
  warning: 6
  info: 7
open: 7
fixed: 12
skipped: 1
generated: 2026-11-06T06:40:00Z
updated: 2026-11-06T07:20:00Z
---

# 08-REVIEW-DISPOSITION.md — per-finding disposition ledger

One row per finding in `08-REVIEW.md`. Disposition vocabulary: `open` (untriaged), `fixed`, `skipped`, `deferred`. Hand-edit the Disposition cell to triage; put the reason in Source. This ledger survives re-reviews (REVIEW.md is rewritten by `--auto`; this file is not).

Reconciled against `08-REVIEW-FIX.md` (iteration 1, scope critical_warning): 12 fixed, 1 skipped. CR-03 and WR-03 are fixed with a **requires-human-verification** flag (race/leak logic in host-unreachable paths; consumed contracts pinned, paths themselves not host-pinnable) — verify on the Phase 9 tap leg.

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | fixed | 08-REVIEW-FIX.md — socket lingers in the core's linger list until State::Closed (r9 bd4db36 + pin 7300113); x86_64 re-proof (17-01, D-01/D-13): host pin `devip_tests::tcp_conv_close_lingers_the_socket_until_closed` (cargo test -p port --lib, 101/101 this session) + composed gate boot-r9-net-smoke-x64 (exit 0, all stages pass) — the shared port fix proven live on x86_64 |
| CR-02 | critical | fixed | 08-REVIEW-FIX.md — oversize/unaddressable sends error immediately (r9 904af8f + pin b9d3977) |
| CR-03 | critical | fixed | 08-REVIEW-FIX.md — register→check→block per iteration (r9 75970f0 + pin b48e809); requires human verification |
| CR-04 | critical | fixed | 08-REVIEW-FIX.md — v4-mcast/limited-bcast adds absorb record-only (r9 ac6370c + pin 2017360) |
| CR-05 | critical | fixed | 08-REVIEW-FIX.md — unbind orphans convs on the dying core (r9 0f602d8 + pin 42b1745) |
| CR-06 | critical | fixed | 08-REVIEW-FIX.md — tcp_gc force-hangs-up stale convs, never steals in-use (r9 79517b1 + pin 27d8ec1) |
| CR-07 | critical | skipped | tracked blocker-class deferred to Phase 9/12 per the phase's own record (deferred-items.md 2026-11-06 + WINDOWS.md #50); root cause unpinned, no minimal fix apparent |
| WR-01 | warning | fixed | 08-REVIEW-FIX.md — spawned udp conv writes ride the announcer's socket with per-write metadata (r9 3dec2e9 + pin 764d0d1) |
| WR-02 | warning | fixed | 08-REVIEW-FIX.md — dataq bounded 8 datagrams / 64 KiB, drop+count past cap (r9 8cfc44f + pin 106e939) |
| WR-03 | warning | fixed | 08-REVIEW-FIX.md — RFMEM OOM unwind arms honor the free verdict (r9 9035bb2); requires human verification |
| WR-04 | warning | fixed | 08-REVIEW-FIX.md — bind rejects an already-bound conv (r9 c6040b7 + pin 4791dc0) |
| WR-05 | warning | fixed | 08-REVIEW-FIX.md — self-table entries refcounted (r9 4ee61c8 + pin 85adba5) |
| WR-06 | warning | fixed | 08-REVIEW-FIX.md — recorded default routes replay into the fresh core at bind (r9 f70d98b + pin 0a4ea82) |
| IN-01 | info | open | out of fix scope (critical_warning); re-run with --all to include |
| IN-02 | info | open | out of fix scope (critical_warning); re-run with --all to include |
| IN-03 | info | open | out of fix scope (critical_warning); re-run with --all to include |
| IN-04 | info | open | out of fix scope (critical_warning); re-run with --all to include |
| IN-05 | info | open | out of fix scope (critical_warning); re-run with --all to include |
| IN-06 | info | open | out of fix scope (critical_warning); re-run with --all to include |
| IN-07 | info | open | out of fix scope (critical_warning); re-run with --all to include |
