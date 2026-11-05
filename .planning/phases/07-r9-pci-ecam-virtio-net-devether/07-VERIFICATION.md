---
phase: 07-r9-pci-ecam-virtio-net-devether
verified: 2026-11-05T14:38:07Z
status: human_needed
score: 33/34 must-haves verified
covered_files:
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-01-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-01-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-02-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-02-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-03-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-03-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-04-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-04-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-05-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-05-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-06-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-06-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-07-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-07-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-08-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-08-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-09-PLAN.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-09-SUMMARY.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-CONTEXT.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-EVIDENCE.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-UAT.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-REVIEW.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-REVIEW-DISPOSITION.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/evidence/07-07-virtnet-arp.log
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/evidence/07-07-virtnet-arp.pcap
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/evidence/07-07-virtnet-blast.log
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/evidence/07-07-virtnet-blast.pcap
  - build/aarch64/root-tree/lib/test/arp.req
  - build/aarch64/root-tree/lib/net-sweep.rc
  - build/aarch64/netblast.c
  - build/aarch64/subset-build.sh
  - build/aarch64/mkimage.sh
  - build/aarch64/run-r9.sh
  - build/aarch64/smoke-r9.expect
  - nix/boot-r9.sh
  - flake.lock
covered_digest: "v2:sha256:3630dd15c3cefee75f2238860be841fd150018393eeb25c2d2a534d0cd9d2522"
behavior_unverified: 1
overrides_applied: 0
decision_coverage:
  honored: 10
  total: 10
  not_honored: []
re_verification:
  previous_status: human_needed
  previous_score: 26/27
  gaps_closed:
    - "G-07-2 / CR-01 (readnum_content(-1) kernel panic): FIXED in code — `val as u32 as u64` donor-exact truncation (r9 1c16193), three byte-exact host pins + conv_close pin all green live this session, disposition ledger marked fixed (open 14→13); the live guest re-confirmation (UAT test 2) remains pending with the user"
    - "G-07-1 root cause (blocking read never wakes): diagnosed as a TEST-PROCEDURE defect — kernel donor-faithful; conv_close last-close reset now host-pinned as intentional and 07-UAT.md test 1 carries the corrected read-first-then-connect protocol; the guest re-run (UAT test 1) remains pending with the user"
  gaps_remaining:
    - "Guest re-run of 07-UAT.md tests 1-2 (verify-work owns the reconciliation; both gaps stay open in 07-UAT.md until then)"
  regressions: []
behavior_unverified_items:
  - truth: "The data-file read path blocks per netif's qread semantics (Qmsg — one whole frame per read, virtio header stripped) via the EtherHooks { current, block, wake }"
    test: "Re-run 07-UAT.md test 1 with the CORRECTED protocol: composed boot at the new pin (`nix run .#boot-r9`), `bind -a '#l' /net`, clone, then `cat /net/ether0/$conv/data &` FIRST (holds the conversation open, inuse=1), THEN `echo connect 2054 > /net/ether0/$conv/ctl`. With no traffic the read must BLOCK; then dd /lib/test/arp.req from a second conversation (its own clone+connect 2054) so slirp replies, and confirm the blocked read wakes returning exactly one whole 64-byte frame with stats in: incremented."
    expected: "Block-on-empty, wake-on-first-matching-frame, one whole frame per read, stats in: live-incremented. The prior failure is root-caused to the OLD protocol's ordering (connect's ctl close was a last close → donor-faithful typ=0 reset → demux skip), pinned by the 07-09 host test; the corrected protocol holds the conversation open across the connect."
    why_human: "The RX-side register→block→wake→whole-frame-copyout transition still has no behavioral test at any level: the blast gate proves the TX-side drain, the 07-09 host pin proves close→EOF-wake and the reset semantics, but nothing exercises ingress→wake of a blocked reader. Presence + the pin make a wedge implausible; they do not prove the transition. The guest re-run is the confirmation."
human_verification:
  - test: "Re-run 07-UAT.md test 1 with the corrected read-first-then-connect protocol (see behavior_unverified_items for the full protocol) against the composed boot at the new flake.lock pin"
    expected: "Block-on-empty → wake-on-matching-frame → one whole 64-byte frame per read; stats in: incremented per frame; no wedge, no panic"
    why_human: "RX-side block→wake state transition with zero automated coverage at any level; diagnosis + host pins closed the root cause (test procedure) and locked the semantics, but the live transition confirmation is the remaining step. G-07-1 stays open in 07-UAT.md until this re-run lands (verify-work owns the reconciliation)."
  - test: "Re-run 07-UAT.md test 2 against the composed boot at the new pin: `bind -a '#l' /net`, `echo connect -1 > /net/ether0/0/ctl`, then `cat /net/ether0/0/type`"
    expected: "Prints 4294967295 (the donor's byte-exact ` 4294967295 ` 12-byte field) — never the prior kernel panic. Fix verified in code this session: readnum_content truncates through u32 (devether.rs:496) exactly per the donor's int→ulong conversion, host-pinned byte-exact by devether_tests (green live)"
    why_human: "The fix is host-test-proven and the full NTYPEQID path is wired (type_of → i64::from → readnum_content), but the guest-visible end-to-end readback at the pinned kernel is unexercised — the sweeps never connect -1. G-07-2 stays open in 07-UAT.md until this re-run lands."
deferred:
  - truth: "TX loopback/broadcast feedback into the input path (etheroq → etheriq)"
    addressed_in: "Phase 8"
    evidence: "07-CONTEXT phase boundary excludes arp/ethermedium/ipifc binding from Phase 7; ROADMAP Phase 8 SC4: 'arp + ethermedium bound to devether' (NETIP-04). The omission is documented loudly in devether.rs's header per the 07-07 must-have that locks it."
---

# Phase 07: r9 PCI/ECAM + virtio-net + devether — Verification Report

**Phase Goal:** r9 speaks Ethernet on qemu virt — PCI/ECAM discovery driven entirely by the committed DTB, a virtio-net driver with Day-1 zero-offload discipline over barrier-first virtqueues, and devether presenting `/net/ether0`, proven by a guest ARP request captured on the host. Kernel work in sibling repo `../r9`.
**Verified:** 2026-11-05T14:38:07Z
**Status:** human_needed
**Re-verification:** Yes — after gap-closure plan 07-09 (G-07-1, G-07-2)

**Verification posture note:** this re-verification re-proved the 07-09 delta live at r9 HEAD `1c161931000e77edb546a972f33b1adfa89b0b30` (== origin/main == the flake.lock locked rev): the full port host suite ran green this session including all four new devether pins; the push/pin/CI chain was re-asserted against live git state and the GitHub API. The standing phase evidence (truths 1–11, 13–27) was regression-checked against the 07-09 diff scope (`46a2ed2..1c16193`: devether.rs +25/-5, devether_tests.rs +150, lib.rs +5 — nothing else), which cannot touch the discovery/negotiation/ring/gate surfaces those truths stand on; the virtnet gates themselves were re-proven by 07-09 at this exact HEAD (07-EVIDENCE.md re-proof section) and were not re-run here per the dispatch.

## Goal Achievement

### Observable Truths (phase contract — regression-checked)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | r9 finds the NIC from data, not constants: ECAM window from the DTB pci node's translated `reg`, device found by bus walk (1af4:1041 rev≥1), route decoded from `interrupt-map` — zero hardcoded IRQs/addresses (NETDRV-01) | ✓ VERIFIED | Unchanged by 07-09 (diff is port/devether-only). Prior live evidence stands: pci.rs:77-177 DTB parse; live log `pci: ecam base 0x4010000000`, `pci: virtio-net 1af4:1041 at 00:01.0 rev 01`, `pci: inta -> spi 4 intid 36` |
| 2 | Moved-window DTB perturbation still binds the device (NETDRV-01's proof) | ✓ VERIFIED | Committed `virt-gicv2-lowecam.{dts,dtb}` + `config_virtlowecam.toml`; prior live re-run PASS (`ecam base 0x3f000000`, same route, bind line present). 07-09 diff does not touch discovery |
| 3 | DTB discovery failure is loud, never a fallback (NETDRV-01 prohibition, judgment-tier — non-authoritative verdict) | ✓ VERIFIED (code evidence) | pci.rs header "deliberately NO hardcoded-window fallback"; named absence lines; host test `loud_absence_returns_none_never_a_default` in the port suite — green this session |
| 4 | The virtio transport is from-scratch in `port/src/virtio.rs` (D-01), generic (D-02), `#![forbid(unsafe_code)]` | ✓ VERIFIED | virtio.rs untouched by 07-09; forbid attributes stand (virtio.rs:54, netif.rs:71, devether.rs:79) |
| 5 | Negotiation accepts exactly MAC(5)\|STATUS(16)\|VERSION_1(32) — zero-offload from Day 1 (D-03; NETDRV-02 prohibition, judgment-tier — non-authoritative verdict, test-backed) | ✓ VERIFIED | ACCEPT_LO/HI masks unchanged; `negotiate_accepts_exactly_mac_status_and_version1` green this session; gate log shows `negotiated 0x100010020` |
| 6 | Barrier-first ring code, order proven by test (D-04 first half) | ✓ VERIFIED | The three order-pinning virtio_tests green this session within the 51/51 port lib suite |
| 7 | D-01 provenance decision recorded in-repo (NETDRV-02's record requirement) | ✓ VERIFIED | HowItWorks.md:242-248 unchanged |
| 8 | virtio_net_hdr is 12 bytes under VERSION_1 with a const size assertion | ✓ VERIFIED | virtio.rs:782 const assert unchanged |
| 9 | devether `#l` presents the netif.h file tree per NETQID(i,t)=(i<<5)\|t | ✓ VERIFIED | devether.rs metadata table/namec arm unchanged by 07-09 (the diff touched readnum_content + its doc comment only, plus pub(crate) visibility) |
| 10 | Clone/open semantics per netif.c:158-197 | ✓ VERIFIED | Exercised by the gates; unchanged |
| 11 | Write path netif-faithful: 60..=1514 bounds, src-MAC overwrite, block-on-full with wake (D-08) | ✓ VERIFIED | Blast gate re-proven at 1c16193 by 07-09 (EVIDENCE re-proof: N=256 PASS, same HEAD, no intermediate commits) |
| 12 | Data-file read path blocks per Qmsg semantics via EtherHooks | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | **Updated:** the G-07-1 debug session root-caused the UAT failure to the TEST PROCEDURE (connect's ctl close was a last close → donor-faithful typ=0 reset → demux skip; .planning/debug/data-read-never-wakes.md). The kernel is donor-faithful; conv_close's last-close reset is now host-pinned as INTENTIONAL (`conv_close_last_close_reset_is_donor_intentional` green this session); 07-UAT.md test 1 carries the corrected read-first-then-connect protocol. The RX-side block→wake transition itself remains unexercised by any automated test — the guest re-run is pending. See Human Verification #1 |
| 13 | RX retire → demux per etheriq: inpackets++ every frame, type-match delivery, live counters | ✓ VERIFIED | arp/blast gate evidence stands; counters reconcile with the pcaps exactly; rx_ingress path unchanged by 07-09 |
| 14 | ctl depth per discretion: connect N functional, promiscuous no-op, others loud-unimplemented, unknown verbs error loudly | ✓ VERIFIED | **Caveat resolved:** the CR-01 edge (`connect -1` admitted, type readback panicked) is FIXED — readnum_content now truncates through u32 (devether.rs:496), the NTYPEQID path (type_of → i64::from → readnum_content) produces the donor's byte-exact ` 4294967295 ` field, host-pinned (green this session). Full connect surface verified; live guest re-confirmation routes via Human Verification #2 |
| 15 | ifstats routes to the driver hook with the `vq<q>: avail= used= lastused= nintr= nnote=` line (NETDRV-04) | ✓ VERIFIED | Gate logs stand; re-proven at 1c16193 by 07-09's blast re-run |
| 16 | The guest's ARP request is observable in a host-side capture (NETDRV-03, D-06) | ✓ VERIFIED | Committed pcaps independently parsed (8 frames = 4 requests + 4 slirp replies, field-exact); arp gate re-proven PASS at 1c16193 by 07-09 |
| 17 | INTx level-trigger plumbing in BOTH GIC generations, ICFGR before ISENABLER | ✓ VERIFIED | gicv2.rs:95-108 / gicv3.rs:226-239 unchanged |
| 18 | ISR read-to-ack: handler's first device touch is the ISR byte | ✓ VERIFIED | pci.rs:846-847 unchanged |
| 19 | Interrupt accounting reconciles under sustained load — no silent virtqueue wedge (NETDRV-04) | ✓ VERIFIED | Blast gate re-proven at 1c16193 by 07-09 (N=256, NET-DONE, pcap assertion) |
| 20 | xtask netdev stanza is aarch64-virt-only; other-arch argv untouched (D-09/D-10) | ✓ VERIFIED | config.rs:576-584 unchanged |
| 21 | xtask pcap parser is std-only and unit-proven (D-06 machinery) | ✓ VERIFIED | pcap.rs tests unchanged; xtask suite green at 07-09's gate runs |
| 22 | Bootfs payload: 60-byte ARP fixture, two-mode sweep, netblast, dd — manifest-asserted | ✓ VERIFIED | Harvey-side files unchanged since the initial verification (fingerprint-covered) |
| 23 | virtnet Net profile: real Harvey boot chain, typed sweep, fast-fail, pcap assertions in finish() | ✓ VERIFIED | Both modes re-proven green at 1c16193 by 07-09 (EVIDENCE re-proof section) |
| 24 | Driver bind per spec order: BAR4 from the DTB `ranges` window, PCI_COMMAND explicit, caps bounds-checked, queue_enable LAST, DRIVER_OK before notify, RX pre-post | ✓ VERIFIED | Order pinned by host test (green this session); live bind lines stand |
| 25 | `dev = ["ether"]` across every aarch64 virt config + cfg(dev_ether) declared | ✓ VERIFIED | Unchanged |
| 26 | Push-before-pin: r9 pushed BEFORE the flake.lock advance; pin commit names flake.lock alone; locked rev == live HEAD, owner requaos | ✓ VERIFIED | **Re-verified live at the new pin:** r9 HEAD == origin/main == `1c161931000e77edb546a972f33b1adfa89b0b30` (git ls-remote this session); harvey commit `d5df2df38` touches flake.lock ALONE (diff-tree verified this session) and precedes the evidence commit `eef588612` in pushed history; flake.lock r9 block: rev `1c16193…`, owner `requaos` |
| 27 | Composed boot speaks Ethernet: identical stanza on all three compose paths, smoke nic-bind post-pass, fresh hosted CI green | ✓ VERIFIED | Stanza/post-pass unchanged. **Hosted CI API-verified this session: run 42043430592 completed/success, headSha `eef588612c26…` (the pushed evidence commit carrying the pin); tip run 42043437746 also success** |

### Gap-Closure Plan 07-09 Must-Haves (the delta — full verification)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 28 | readnum_content reproduces the donor's 32-bit truncation exactly: `connect -1` reads back as the 12-byte field ` 4294967295 ` — never a usize underflow, never sign extension, never a clamp | ✓ VERIFIED | devether.rs:496 `let v = val as u32 as u64;`; `readnum_content_neg1_matches_donor_truncation` asserts byte-exact `b" 4294967295 "` — **green live this session**; no saturating_sub/clamp in the body (grep over non-comment lines: 0); the underflow is unreachable by construction (u32 ≤ 10 digits < NUMSIZE-1=11) |
| 29 | The doc comment states the true donor shape: truncation through 32-bit ulong, no sign extension (Plan 9 long/ulong 32-bit even on amd64; vlong/uvlong are the 64-bit types, hence VLNUMSIZE=22) | ✓ VERIFIED | devether.rs:475-491 rewritten: netif.h:40 `int` × devcons.c:712 `ulong`, amd64/include/u.h rationale, the no-clamp warning, and the class-sweep conclusion (only NUMSIZE-digits site; NCTLQID ids 0..7; netif.rs zero NUMSIZE arithmetic) |
| 30 | conv_close's last-close reset (typ=0, queue drain, EOF wake — donor 9k netif.c:446) pinned by a crate-root host test as INTENTIONAL donor behavior | ✓ VERIFIED | `conv_close_last_close_reset_is_donor_intentional` (devether_tests.rs:69-150) — green live this session. Alloc-first drive per netif's visibility surface: ConvBook fields via the NETIF pub(crate) chain (typ==0, owner_set==false, inuse==0), EOF wake via stub EtherHooks log, drain+close observed behaviorally via pop_frame == Pop::Closed |
| 31 | 07-UAT.md test 1 carries the corrected protocol: blocked read FIRST (`cat /net/ether0/$conv/data &`), THEN connect — the re-run itself is verify-work's, not this plan's | ✓ VERIFIED | 07-UAT.md:28-29 — the literal `cat /net/ether0/$conv/data &` line precedes `echo connect 2054 > /net/ether0/$conv/ctl`, with the open-lifetime rationale (inuse=1 across the connect; last-close reset per netif.c:446, pinned intentional by the 07-09 host test). Result/reported/severity fields and test 2's text untouched |
| 32 | 07-REVIEW-DISPOSITION.md CR-01 marked fixed; WR-05 and WR-06 remain open and untouched | ✓ VERIFIED | YAML block: CR-01 `disposition: fixed`; summary table row `| CR-01 | critical | fixed | 07-09 (u32 truncation + host pins) |`; frontmatter `open: 13` / `total: 14`; WR-01..WR-06 all `open` |
| 33 | Full port host suite green, xtask regression green, both virtnet gates green on the fixed HEAD | ✓ VERIFIED | **Port suite re-run live this session: 114 passed / 0 failed across all port binaries (lib suite 51/51 = +4 vs the 47 pre-plan baseline), incl. all four devether pins.** xtask regression + both virtnet gates (arp N=4, blast N=256) green at 1c16193 per 07-09's gate runs (07-EVIDENCE.md re-proof section; not re-run here per dispatch) |
| 34 | Push-before-pin carries the fix to the composed-boot venue: r9 RED+GREEN on requaos/r9 main, flake.lock advanced as its own commit, fresh hosted CI green at the pushed HEAD | ✓ VERIFIED | r9 log: `1e77266` (RED, test) → `1c16193` (GREEN, feat); ls-remote origin main == `1c16193…` this session; `d5df2df38` diff-tree names flake.lock ALONE; locked rev == pushed HEAD, owner requaos; **CI run 42043430592 completed/success at headSha `eef588612c26…` (GitHub API this session)**; tip run 42043437746 success at 69c4cf689 (carries these commits) |

**Score:** 33/34 truths verified (1 present, behavior-unverified)

### Decision Coverage

All trackable CONTEXT.md decisions honored (10/10 — D-01..D-10; non-blocking gate). 07-09 re-applied the carried-forward push-before-pin decision at the fix HEAD.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | TX loopback/broadcast feedback into the input path (etheroq → etheriq) — deliberately not implemented this phase | Phase 8 | 07-CONTEXT phase boundary excludes the arp/ethermedium/ipifc binding; ROADMAP Phase 8 SC4 ("arp + ethermedium bound to devether", NETIP-04); omission documented loudly in devether.rs header per the 07-07 must-have that locks it |

### Required Artifacts

r9-side artifacts are outside this repo's fingerprint surface (the phase pins the exact rev — r9 `1c161931000e77edb546a972f33b1adfa89b0b30` == origin/main == flake.lock locked rev — as the evidence anchor; per-phase SHAs in 07-EVIDENCE.md).

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `../r9/aarch64/src/platform/virt/pci.rs` | DTB-driven ECAM discovery + driver bring-up + IRQ handler | ✓ VERIFIED | Unchanged by 07-09; prior verification stands |
| `../r9/port/src/virtio.rs` | from-scratch unsafe-free transport | ✓ VERIFIED | Unchanged; suite green this session |
| `../r9/port/src/netif.rs` | Netif/Netfile model, counters, EtherHooks | ✓ VERIFIED | Unchanged by 07-09 (diff stat confirms); conv_close semantics now host-pinned |
| `../r9/port/src/devether.rs` | the `#l` device surface | ✓ VERIFIED | **07-09 delta verified:** readnum_content pub(crate) + `val as u32 as u64` (:496) + corrected donor-shape doc comment (:475-491); no clamp/guard; rest of the surface byte-untouched (25-line diff) |
| `../r9/port/src/devether_tests.rs` | **NEW (07-09):** crate-root pins | ✓ VERIFIED | 150 lines; four tests exactly as planned; all green live this session; header records the G-07-1/G-07-2 oracles |
| `../r9/port/src/lib.rs` | `#[cfg(test)] mod devether_tests;` registration | ✓ VERIFIED | Present (grep count 1), crate-root rationale comment per the allocator_tests/virtio_tests precedent; cfg(test)-gated — the module vanishes from kernel builds (lib.rs:3 cfg_attr no_std) |
| `../r9/port/src/fdt.rs` | interrupt-map helpers + decode tests | ✓ VERIFIED | Unchanged; fdt tests green this session |
| `../r9/port/src/virtio_tests.rs` | host ring/negotiation suite (D-04) | ✓ VERIFIED | 22 tests green this session |
| `../r9/xtask/src/pcap.rs` + `config.rs` + `main.rs` | netdev emission, Net profile, assertions | ✓ VERIFIED | Unchanged; gates re-proven by 07-09 |
| `../r9/HowItWorks.md` | D-01 provenance record | ✓ VERIFIED | §virtio lines 242-248 |
| `../r9/aarch64/lib/virt-gicv2-lowecam.{dts,dtb}` + `config_virtlowecam.toml` | the perturbation fixture | ✓ VERIFIED | Committed; unchanged |
| `build/aarch64/root-tree/lib/test/arp.req` | 60-byte ARP fixture | ✓ VERIFIED | Byte-exact vs D-07+errata (prior; file unchanged) |
| `build/aarch64/root-tree/lib/net-sweep.rc` | two-mode sweep | ✓ VERIFIED | Unchanged |
| `build/aarch64/netblast.c` | TX-bulk generator | ✓ VERIFIED | Unchanged |
| `evidence/07-07-virtnet-{arp,blast}.{log,pcap}` | committed gate evidence | ✓ VERIFIED | Unchanged (07-09 deliberately committed no capture refresh — re-proof rows only) |
| `flake.lock` | r9 pin at the fixed HEAD | ✓ VERIFIED | rev `1c16193…`, owner requaos — resolves the fixed kernel from a clean clone |
| `07-UAT.md` | corrected test-1 protocol | ✓ VERIFIED | Read-first-then-connect + rationale; gaps remain open pending the guest re-run (verify-work owns reconciliation) |
| `07-REVIEW-DISPOSITION.md` | CR-01 fixed, open 14→13 | ✓ VERIFIED | Both the YAML block and the table row; counters hand-updated; WR-05/06 untouched |
| `07-EVIDENCE.md` | 07-09 re-proof section + new pin rows | ✓ VERIFIED | `### 07-09 — … re-proof at r9 1c161931…` with both gate verdicts + the no-new-captures note; Pinned-commits rows added |
| `nix/boot-r9.sh`, `build/aarch64/run-r9.sh`, `build/aarch64/smoke-r9.expect` | D-10 compose stanza + nic-bind post-pass | ✓ VERIFIED | Unchanged |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `devether_tests.rs` | `devether.rs` | crate-root module calls pub(crate) `readnum_content` directly | ✓ WIRED | devether_tests.rs:23 import; devether.rs:493 visibility; pins green live |
| `devether_tests.rs` | `netif.rs` | conv_close pin drives publish → conv_alloc → conv_connect → rx_ingress → pop_frame probe → rx_ingress → register_rx_waiter → conv_close; state read via the NETIF pub(crate) chain + behavioral pop_frame/stub-hook surfaces | ✓ WIRED | Pin green live this session — all four assertion groups fire (ConvBook reset, EOF wake log, Pop::Closed) |
| NTYPEQID read arm | `readnum_content` | `type_of(netid)` → `i64::from(t)` → readnum_content → read_str | ✓ WIRED | devether.rs:536-540 — the guest-visible type-file path now terminates in the donor-exact truncation |
| `flake.lock` | `../r9` (requaos/r9 origin main) | push-before-pin: locked rev == live HEAD == origin/main, owner requaos | ✓ WIRED | Asserted live this session (ls-remote + flake.lock grep + diff-tree isolation) |
| All prior links (pci↔fdt, trap↔pci, main↔bind/hooks, namec↔devether, xtask↔pcap/config, sweep↔fixtures, smoke↔compose) | — | — | ✓ WIRED | Regression-checked: the 07-09 diff (3 r9 files, port-only) cannot touch these surfaces |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| type file readback | stored conversation typ | ctl `connect` write → ConvBook → readnum_content | Yes — and now donor-exact over the full admitted domain [-1, 0xffff], host-pinned at the boundaries (-1, 0, 65535) | ✓ FLOWING |
| pci discovery prints | ecam base/size, route | DTB parse | Yes (unchanged) | ✓ FLOWING |
| negotiated-mask print | features | device config registers | Yes (unchanged) | ✓ FLOWING |
| stats file | in/out counters | IRQ-driven RX retire + TX post | Yes (re-proven at 1c16193 by 07-09's gates) | ✓ FLOWING |
| ifstats file | avail/used/lastused/nintr/nnote | live ring indices + IRQ counters | Yes (unchanged) | ✓ FLOWING |
| host pcap | frames | qemu filter-dump | Yes (unchanged) | ✓ FLOWING |

### Behavioral Spot-Checks (this session)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| **The four 07-09 pins** | `nix develop --command cargo test -p port` (r9 @ 1c16193) | `devether_tests::readnum_content_neg1_matches_donor_truncation … ok`, `…_zero_pads_numsize … ok`, `…_max_ethertype_65535 … ok`, `conv_close_last_close_reset_is_donor_intentional … ok` | ✓ PASS (live) |
| Full port host suite, zero regressions | same run | 114 passed / 0 failed across all port binaries (lib 51/51, +4 vs the pre-07-09 baseline of 47) | ✓ PASS (live) |
| r9 push state | `git ls-remote origin main` + `git rev-parse HEAD` | both `1c161931000e77edb546a972f33b1adfa89b0b30`; plan-scope files clean | ✓ PASS (live) |
| Pin isolation + lock accuracy | `git diff-tree --name-only -r d5df2df38`; grep flake.lock r9 block | `flake.lock` alone; rev == HEAD, owner requaos | ✓ PASS (live) |
| Hosted CI at the pushed HEAD | GitHub API `/actions/runs/42043430592` | `completed success eef588612c26… r9-shell` (+ tip run 42043437746 success) | ✓ PASS (live) |
| virtnet arp + blast gates at 1c16193 | `cargo xtask boot-test --arch aarch64 --config virtnet` (± blast) | PASS ×2 at 1c16193 — re-proven by 07-09, recorded in 07-EVIDENCE.md; not re-run this session per dispatch (07-09 diff cannot touch the gate surface) | ✓ PASS (committed re-proof) |

### Test Quality Audit (07-09 additions)

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|-----------|-----------|--------|---------|----------|-----------------|---------|
| `port/src/devether_tests.rs` (readnum ×3) | NETDRV-03 | 3 | 0 | No — oracle is the in-tree donor (devcons.c:712 × netif.h:40 × NUMSIZE=12), byte-exact expected values; RED-proven (the -1 pin panicked pre-fix with subtract-with-overflow, RED_EVIDENCE_OK) | Value-level (byte-exact 12-byte fields) | ✓ SUFFICIENT |
| `port/src/devether_tests.rs` (conv_close pin) | NETDRV-03 | 1 | 0 | No — drives the real pub/pub(crate) netif surface; drain asserted non-vacuously (delivery proven by a Pop::Frame probe BEFORE the close); module-private state observed behaviorally, never field-read | Behavioral (state-transition + wake-log assertions) | ✓ SUFFICIENT |

**Disabled tests on requirements:** 0. **Circular patterns:** 0. **Insufficient assertions:** 0.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers in any 07-09-modified file; no clamp/guard snuck into the readnum_content body (grep over non-comment lines: 0 — the prohibition honored); the test module is cfg(test)-gated and cannot reach kernel builds | — | — |

### Review Findings Routing (07-REVIEW.md — 13 open/14 total in 07-REVIEW-DISPOSITION.md)

**CR-01 is FIXED** (07-09; host-pinned byte-exact; the incremental review pass on the 07-09 diff found **0 new findings** and independently verified donor-exactness over the full admitted domain, including that no assertion was weakened and no panic-introducing construct reaches the kernel). The prior verification's recommendation — fix before Phase 8 — was followed.

The remaining 13 open findings (WR-01..WR-08, IN-01..IN-05) stand as previously routed: WR-05 (WaitSet 16 vs MAX_PROCS 64) and WR-06 (RX retire slot-liveness) recommended for gap closure before Phase 8's ethermedium lands; WR-01..04/WR-08 cheap validation hardening; IN-01..05 hygiene. None falsifies a must-have truth; none was in 07-09's scope (WR-05/WR-06 explicitly untouched per plan). They remain tracked in the disposition ledger — not verification gaps.

### Human Verification Required

**1. UAT test 1 re-run — blocking read path, corrected protocol (G-07-1)**

**Test:** Composed boot at the new pin (`nix run .#boot-r9`): `bind -a '#l' /net`, `conv=`{cat /net/ether0/clone}`, then **read first**: `cat /net/ether0/$conv/data &`, **then** `echo connect 2054 > /net/ether0/$conv/ctl`. With no traffic the read must block. From a second conversation (clone + connect 2054) `dd < /lib/test/arp.req > /net/ether0/$other/data` so slirp replies; confirm the blocked read wakes returning exactly one whole 64-byte frame and `cat /net/ether0/stats` shows in: incremented.
**Expected:** block-on-empty → wake-on-matching-frame → one whole frame per read; no wedge, no panic.
**Why human:** the RX-side register→block→wake transition has no automated test at any level. The prior failure is root-caused to the OLD protocol (connect's ctl close was a last close → donor-faithful typ=0 reset → demux skip — .planning/debug/data-read-never-wakes.md); the kernel is donor-faithful, the reset semantics are now host-pinned as intentional, and the corrected protocol holds the conversation open across the connect. The guest re-run is the remaining confirmation; G-07-1 stays open in 07-UAT.md until it lands (verify-work owns the reconciliation).

**2. UAT test 2 re-run — CR-01 fix live confirmation (G-07-2)**

**Test:** Same composed boot: `echo connect -1 > /net/ether0/0/ctl` then `cat /net/ether0/0/type`.
**Expected:** prints `4294967295` (the donor's byte-exact field) — never the prior `panicked at port/src/devether.rs:492:15` subtract-with-overflow.
**Why human:** the fix is verified in code and host-pinned byte-exact (green live this session), and the full NTYPEQID path is wired; but the guest-visible end-to-end readback at the pinned kernel is unexercised — no gate ever connects -1. G-07-2 stays open in 07-UAT.md until this re-run lands.

### Gaps Summary

**No verification gaps.** All automated evidence is green and the 07-09 fix is verified in code: CR-01 is fixed donor-exactly (`val as u32 as u64`, no clamp, doc comment corrected) with byte-exact host pins plus the conv_close donor-intentional pin — all four green live this session inside a fully green port suite (114/114). The composed-boot venue carries the fix (r9 `1c16193` == origin/main; flake.lock pinned as its own isolated commit; hosted CI success API-verified at the pushed HEAD). Both virtnet gates were re-proven at the fixed HEAD by 07-09.

The status is `human_needed` (not `passed`) solely because the two UAT gaps remain open pending the guest re-run of 07-UAT.md tests 1–2 with the user — test 1 now with the corrected read-first-then-connect protocol, test 2 expecting `4294967295` instead of the panic. Neither item contradicts the goal's achievement; they are live confirmations of a diagnosed procedure defect and a code-verified fix, and verify-work owns the reconciliation.

**Info (not a gap):** two harvey planning-docs commits (`77c610e7b` gap-closure completion, `253b232df` review incremental) are unpushed local master — docs-only; the pin, evidence, and all substantive commits are pushed and CI-covered. The pre-existing `cargo test --workspace` arch-crate host-link failure is untouched and structural; the sanctioned lanes (`-p port`, `-p xtask`) are green.

---

_Verified: 2026-11-05T14:38:07Z_
_Verifier: the agent (gsd-verifier)_
