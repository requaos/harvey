---
status: testing
phase: 07-r9-pci-ecam-virtio-net-devether
source: [07-VERIFICATION.md]
started: 2026-11-05T03:20:00Z
updated: 2026-11-05T03:20:00Z
---

## Current Test

number: 1
name: Blocking data-file read path (Qmsg block→wake→whole-frame copyout)
expected: |
  Read blocks while the conversation queue is empty, wakes on the first matching
  inbound frame, returns one whole frame per read; the wake rides the same
  EtherHooks the blast gate proved on the TX side. stats in: live-incremented.
awaiting: user response

## Tests

### 1. Blocking data-file read path (Qmsg block→wake)
expected: |
  In a composed boot (`nix run .#boot-r9` or the virtnet harness shape):
  clone a conversation, `echo connect 2054 > /net/ether0/N/ctl`, then
  `cat /net/ether0/N/data` with no traffic — the read must BLOCK (no EOF, no
  error). Then generate ARP traffic to the guest MAC (e.g. from a second
  conversation dd an arp.req so slirp replies) and confirm the blocked read
  wakes and returns exactly one whole 64-byte frame (slirp's padded reply),
  with stats in: incremented per frame.
  Full protocol is in 07-VERIFICATION.md § behavior_unverified_items.
  Why human: the register→block→wake→whole-frame-copyout state transition has
  no test at any level; grep proves presence, not the transition. Phase 8's
  ethermedium is the first real consumer.
result: [pending]

### 2. CR-01 reproduction + triage decision (readnum_content(-1) kernel panic)
expected: |
  In a composed boot: `echo connect -1 > /net/ether0/0/ctl` then
  `cat /net/ether0/0/type`. Donor-faithful expected: reads back `4294967295`.
  Predicted actual (confirmed by code inspection): kernel panic via usize
  underflow in readnum_content — devether.rs:479-494 (`NUMSIZE-1-digits.len()`
  = 11-20, panic="abort" in both kernel profiles).
  Human decides: fix now (recommended — one-line u32 cast per 07-REVIEW.md
  CR-01, plus a host test pinning connect -1 readback) or defer with a
  recorded reason in 07-REVIEW-DISPOSITION.md.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
