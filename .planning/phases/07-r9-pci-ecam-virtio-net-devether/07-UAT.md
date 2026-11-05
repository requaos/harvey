---
status: diagnosed
phase: 07-r9-pci-ecam-virtio-net-devether
source: [07-VERIFICATION.md]
started: 2026-11-05T03:20:00Z
updated: 2026-11-05T05:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Blocking data-file read path (Qmsg block→wake)
expected: |
  In a composed boot (`nix run .#boot-r9` or the virtnet harness shape).
  NOTE: the composed boot ships NO network binds by design (lib/namespace:
  "No network binds (#I/#l0)") — bind first, exactly as net-sweep.rc does:
    bind -a '#l' /net
    conv=`{cat /net/ether0/clone}        # prints the fresh conversation id
  Then (the ORDER is load-bearing — netif scopes connect by the
  conversation's open lifetime: the ctl redirection's close is a LAST
  close unless the data chan is already held open, and conv_close's
  last-close reset clears typ=0 per donor netif.c:446 — pinned as
  intentional donor behavior by the 07-09 host test; with typ reset the
  demux skips the reply and the blocked read never wakes):
    cat /net/ether0/$conv/data &
    echo connect 2054 > /net/ether0/$conv/ctl
  The backgrounded cat holds the conversation's data chan open (inuse=1
  across the connect), so the redirection's ctl close is NOT a last
  close and typ=2054 sticks. With no traffic the read must BLOCK
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
  CONFIRMED LIVE: `connect -1` admitted (clean exit), `cat type` panicked the
  kernel — "panicked at port/src/devether.rs:492:15: attempt to subtract with
  overflow" — exactly the reviewed readnum_content underflow.
result: issue
reported: "Console log: `echo connect -1 > /net/ether0/0/ctl` exited clean; `cat /net/ether0/0/type` panicked at port/src/devether.rs:492:15 'attempt to subtract with overflow' — CR-01 reproduced verbatim (kernel panic, panic=abort)."
severity: blocker

## Summary

total: 2
passed: 0
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-07-1
  truth: "A read of /net/ether0/N/data on a connected conversation blocks while the queue is empty, wakes on the first matching inbound frame, and returns one whole frame per read"
  status: failed
  reason: "User reported: block-on-empty held (backgrounded cat pid 9 never errored/exited) and the reply reached the device (stats in:1), but the blocked read never woke — no frame bytes printed, no process-9 exit. The register→block→wake→copyout link in netif/devether (EtherHooks block/wake) is wedged; device-level RX accounting works."
  severity: blocker
  test: 1
  root_cause: "TEST-PROCEDURE defect, not a kernel defect: the protocol's `echo connect 2054 > ctl` opens ctl, sets typ=2054, then the redirection close drops inuse to 0, triggering conv_close's last-close reset (typ=0, netif.rs:497/499 — donor-faithful: 9k netif.c:446). The blocked read then sits on a typ=0 conversation; the demux (netif.rs:603) skips the reply and rx_ingress returns before the wake drain (netif.rs:621-623). Frame counted (in:1, netif.rs:584 — proves ISR→ingress ran) but never enqueued. Wake machinery statically sound and TX-side live-proven by the blast gate."
  artifacts:
    - path: "../r9/port/src/netif.rs"
      issue: "497/499 last-close typ reset (causal origin, donor-faithful), 603 demux skip, 621-623 early return before wake — all correct donor semantics; no code change indicated"
    - path: ".planning/phases/07-r9-pci-ecam-virtio-net-devether/07-UAT.md"
      issue: "test 1 procedure drops the last conversation reference between connect and the blocked read — violates netif's open-lifetime scoping of connect"
  missing:
    - "Corrected test-1 protocol: start the blocked read FIRST (cat data & holds the conversation open), THEN echo connect 2054 > ctl (ctl close leaves inuse=1, typ sticks)"
    - "Optional host test pinning conv_close last-close reset semantics (typ=0, queue drain, EOF wake) as documented donor behavior"
    - "Re-run UAT test 1 with the corrected protocol"
  debug_session: .planning/debug/data-read-never-wakes.md
- gap_id: G-07-2
  truth: "A conversation whose ctl accepted `connect -1` reports its type file per donor semantics — reading /net/ether0/0/type reads back 4294967295 (u32 wrap of -1), never a kernel panic"
  status: failed
  reason: "User reported: connect -1 admitted cleanly; reading the type file panicked the kernel at port/src/devether.rs:492:15 'attempt to subtract with overflow' — the reviewed CR-01 readnum_content usize underflow (NUMSIZE-1-20), reproduced live under panic=abort."
  severity: blocker
  test: 2
  root_cause: "readnum_content (devether.rs:479) formats through a 64-bit reinterpretation: read path sign-extends stored i32 -1 to i64 (:523 i64::from), then `val as u64` (:481) = 18446744073709551615 (20 digits); NUMSIZE-1-20 = 11-20 underflows usize at :492 → panic. Donor never sign-extends: Netfile.type is 32-bit int (9k netif.h:40) through readnum's 32-bit ulong param (devcons.c:712) → 4294967295 (10 digits, fits). Donor oracle byte-exact: netif.c:251 produces \" 4294967295 \" (12 bytes). The port's doc comment (:475-478) asserts the wrong donor shape — Plan 9 long/ulong is 32-bit even on amd64 (amd64/include/u.h); vlong/uvlong are the 64-bit types (hence VLNUMSIZE=22)."
  artifacts:
    - path: "../r9/port/src/devether.rs"
      issue: "479-494 the defect (val as u64 + usize underflow) + wrong donor-shape doc comment 475-478; 521-525 NTYPEQID read path sign-extends i32→i64"
  missing:
    - "Fix (donor-faithful): `let v = val as u32 as u64;` in readnum_content — reproduces C int→ulong 32-bit truncation exactly; NOT a clamp (dead code masking width regressions)"
    - "Rewrite the 475-478 doc comment: donor truncates through 32-bit ulong, does not sign-extend"
    - "New crate-root port/src/devether_tests.rs host tests (lib.rs:72-78 precedent): readnum_content(-1)==b\" 4294967295 \" (12 bytes); neighbors readnum_content(0) and readnum_content(65535); ctl-level connect -1 readback pin if reachable"
    - "Class sweep already done by diagnosis: readnum_content is the ONLY NUMSIZE-digits site; NCTLQID caller can't underflow (ids 0..7); netif.rs has zero NUMSIZE arithmetic"
  debug_session: .planning/debug/connect-neg1-type-panics.md
