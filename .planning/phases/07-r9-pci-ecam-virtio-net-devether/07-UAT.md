---
status: testing
phase: 07-r9-pci-ecam-virtio-net-devether
source: [07-VERIFICATION.md]
started: 2026-11-05T03:20:00Z
updated: 2026-11-05T04:05:00Z
---

## Current Test

number: 2
name: CR-01 reproduction + triage decision (readnum_content(-1) kernel panic)
expected: |
  With #l bound: `echo connect -1 > /net/ether0/0/ctl` then
  `cat /net/ether0/0/type`. Donor-faithful expected: reads back `4294967295`.
  Predicted actual: kernel panic via usize underflow in readnum_content.
awaiting: user response

## Tests

### 1. Blocking data-file read path (Qmsg block→wake)
expected: |
  In a composed boot (`nix run .#boot-r9` or the virtnet harness shape).
  NOTE: the composed boot ships NO network binds by design (lib/namespace:
  "No network binds (#I/#l0)") — bind first, exactly as net-sweep.rc does:
    bind -a '#l' /net
    conv=`{cat /net/ether0/clone}        # prints the fresh conversation id
  Then:
    echo connect 2054 > /net/ether0/$conv/ctl
    cat /net/ether0/$conv/data           # with no traffic — must BLOCK
    (no EOF, no error). Then generate ARP traffic to the guest MAC (from a
  second conversation: `dd < /lib/test/arp.req > /net/ether0/$other/data`
  after its own clone+connect 2054) and confirm the blocked read wakes and
  returns exactly one whole 64-byte frame (slirp's padded reply), with
  stats in: incremented per frame (`cat /net/ether0/stats`).
  Why human: the register→block→wake→whole-frame-copyout state transition has
  no test at any level; grep proves presence, not the transition. Phase 8's
  ethermedium is the first real consumer.
  First attempt failed on protocol, not product: `/net/ether0` did not exist
  (no bind) and the literal placeholder `N` was typed for the conversation id.
  Second attempt (bind + real conv ids, correct protocol): block-on-empty held
  (backgrounded cat = process 9, no output/error/exit), TX/RX at the device
  proved (stats out:1 after dd, in:1 after slirp's reply), BUT the blocked
  read never woke — process 9 never printed the frame and never exited even
  though the reply was already counted at the device.
result: issue
reported: "Console log: bind/clone/connect clean; `cat data &` (pid 9) blocked with no output; dd of arp.req on a second conversation sent (out:1); stats showed in:1 (slirp reply arrived); the blocked cat never woke — no frame printed, no 'process 9 exited' line. stats: in:1 out:1 link:1 mbps:1000 addr:525400123456, all error counters 0."
severity: blocker

### 2. CR-01 reproduction + triage decision (readnum_content(-1) kernel panic)
expected: |
  In a composed boot (bind first — same as test 1: `bind -a '#l' /net`):
  `echo connect -1 > /net/ether0/0/ctl` then `cat /net/ether0/0/type`. Donor-faithful expected: reads back `4294967295`.
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
issues: 1
pending: 1
skipped: 0
blocked: 0

## Gaps

- gap_id: G-07-1
  truth: "A read of /net/ether0/N/data on a connected conversation blocks while the queue is empty, wakes on the first matching inbound frame, and returns one whole frame per read"
  status: failed
  reason: "User reported: block-on-empty held (backgrounded cat pid 9 never errored/exited) and the reply reached the device (stats in:1), but the blocked read never woke — no frame bytes printed, no process-9 exit. The register→block→wake→copyout link in netif/devether (EtherHooks block/wake) is wedged; device-level RX accounting works."
  severity: blocker
  test: 1
  artifacts: []
  missing: []
