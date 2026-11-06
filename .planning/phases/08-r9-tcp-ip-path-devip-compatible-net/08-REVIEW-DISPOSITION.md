---
phase: 08-r9-tcp-ip-path-devip-compatible-net
review: 08-REVIEW.md
findings:
  total: 20
  critical: 7
  warning: 6
  info: 7
open: 20
generated: 2026-11-06T06:40:00Z
---

# 08-REVIEW-DISPOSITION.md — per-finding disposition ledger

One row per finding in `08-REVIEW.md`. Disposition vocabulary: `open` (untriaged), `fixed`, `skipped`, `deferred`. Hand-edit the Disposition cell to triage; put the reason in Source. This ledger survives re-reviews (REVIEW.md is rewritten by `--auto`; this file is not).

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | open | conv_close drops the FIN — `close()` then `remove()` before any poll |
| CR-02 | critical | open | Permanent smoltcp send errors wedge the writing proc forever (icmp/udp/icmpv6 data writes) |
| CR-03 | critical | open | semacquire loses wakeups — a woken waiter that loses the unit race re-blocks unregistered |
| CR-04 | critical | open | `ipifc add` of a v4-multicast or limited-broadcast address panics the kernel (P-F violation) |
| CR-05 | critical | open | unbind drops a live seam core — re-bind turns stale conv socket handles into panics/aliasing |
| CR-06 | critical | open | tcp_gc steals an in-use conv — cross-conversation aliasing + refcount corruption |
| CR-07 | critical | open | [tracked — phase-deferred] Multi-waiter RX-IRQ wake wedges the guest |
| WR-01 | warning | open | udp listen/accept spawned convs silently discard writes with Ok(n) |
| WR-02 | warning | open | udp spawned convs' `dataq` is unbounded |
| WR-03 | warning | open | RFMEM failure paths leak physical pages (brk family arm unwind; rfork bss-sweep mid-failure) |
| WR-04 | warning | open | ipifc `bind` doesn't reject a conv already bound to another medium (comment claims it does) |
| WR-05 | warning | open | self-table broadcast/network entries aren't refcounted — removing one address strips shared entries |
| WR-06 | warning | open | default-route mirror does not "land at bind" (comment/code mismatch; functional gap) |
| IN-01 | info | open | dead statement in parse_v6 |
| IN-02 | info | open | duplicated section header |
| IN-03 | info | open | add6's `plen < 0` check is unreachable |
| IN-04 | info | open | netlog `only` with a malformed address silently clears the restriction |
| IN-05 | info | open | sys_semrelease `value + delta` can overflow i32 |
| IN-06 | info | open | listen-open's returned chan keeps the listen file's path |
| IN-07 | info | open | WaitPids/WaitSet full-case silently drops a registration |
