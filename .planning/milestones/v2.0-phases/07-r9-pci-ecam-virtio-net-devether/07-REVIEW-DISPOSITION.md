---
phase: 07
review: 07-REVIEW.md
titles: json
findings:
  - id: CR-01
    severity: critical
    disposition: fixed
    title: "`readnum_content(-1)` panics the kernel — `connect -1` is an admitted ctl verb"
  - id: WR-01
    severity: warning
    disposition: open
    title: "Capability extent validation admits zero-length/undersized regions — first register touch panics instead of a loud bind-fail"
  - id: WR-02
    severity: warning
    disposition: open
    title: "device-config cap admits `length >= 6`; the link-status read at offset 6 needs 8"
  - id: WR-03
    severity: warning
    disposition: open
    title: "BAR4 type never validated; window size ignored at assignment"
  - id: WR-04
    severity: warning
    disposition: open
    title: "Capability-walk pointers never alignment-checked — a misaligned cap pointer is an unaligned volatile u32 read"
  - id: WR-05
    severity: warning
    disposition: fixed
    title: "`WaitSet` capacity is 16 on a stale \"MAX_PROCS=16\" invariant — the table is now 64, and the full case silently drops a waiter"
  - id: WR-06
    severity: warning
    disposition: fixed
    title: "RX retire never checks the slot was actually posted — a duplicated used-ring id aliases one buffer page into two chains"
  - id: WR-07
    severity: warning
    disposition: open
    title: "net-sweep.rc's count validation admits leading zeros that the arp loop can never match — infinite loop"
  - id: WR-08
    severity: warning
    disposition: open
    title: "Decoded DTB interrupt trigger flags are printed but never honored — ICFGR is always programmed level"
  - id: IN-01
    severity: info
    disposition: open
    title: "Dead `dd` trailer extraction in mkimage.sh"
  - id: IN-02
    severity: info
    disposition: open
    title: "`VirtRange::offset_addr` bounds-checks only the access start, not start+width"
  - id: IN-03
    severity: info
    disposition: open
    title: "Documentation drift — proc-table/fd-table sizes and a stale virtnet header comment"
  - id: IN-04
    severity: info
    disposition: open
    title: "`DescPool::free` has no bounds or duplicate-free checks"
  - id: IN-05
    severity: info
    disposition: open
    title: "netblast's `atoi` silently accepts trailing garbage"
open: 11
total: 14
recorded: 2026-11-05T02:57:20.913Z
---

# Phase 07: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| CR-01 | critical | fixed | 07-09 (u32 truncation + host pins) |
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| WR-03 | warning | open | - |
| WR-04 | warning | open | - |
| WR-05 | warning | fixed | 17-03 — one port-level MAX_WAITERS=512 const (the live table on both arches) resized the three WaitSet copies + twelve take buffers; the full arm counts + reports (r9 2bc52a7, RED pins aea604c; the nine waitset capacity pins, 9/9, battery 112/112; gates re-green at Harvey pin b02408cad) |
| WR-06 | warning | fixed | 17-03 — next_used rejects a used-ring id for an unposted slot before the clear, the '(device fault)' family (r9 abe72e7, RED pin 3bd8625; used_drain_rejects_unposted_slot_ids + the existing negatives 4/4; net gate re-green at Harvey pin b02408cad) |
| WR-07 | warning | open | - |
| WR-08 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |
| IN-04 | info | open | - |
| IN-05 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
