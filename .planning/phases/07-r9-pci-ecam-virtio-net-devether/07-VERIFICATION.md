---
phase: 07-r9-pci-ecam-virtio-net-devether
verified: 2026-11-05T03:05:39Z
status: human_needed
score: 26/27 must-haves verified
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
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-CONTEXT.md
  - .planning/phases/07-r9-pci-ecam-virtio-net-devether/07-EVIDENCE.md
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
covered_digest: "v2:sha256:a615c876116cb6460e380d2c3a0a145eb3ef0f54e464e81b42665c194127ac4d"
behavior_unverified: 1
overrides_applied: 0
decision_coverage:
  honored: 10
  total: 10
  not_honored: []
behavior_unverified_items:
  - truth: "The data-file read path blocks per netif's qread semantics (Qmsg — one whole frame per read, virtio header stripped) via the EtherHooks { current, block, wake }"
    test: "In a composed boot (nix run .#boot-r9 or the virtnet harness shape), clone a conversation, `echo connect 2054 > /net/ether0/N/ctl`, then `cat /net/ether0/N/data` with no traffic — the read must BLOCK (no EOF, no error). Then generate ARP traffic to the guest MAC (e.g. from a second conversation dd an arp.req so slirp replies) and confirm the blocked read wakes and returns exactly one whole 64-byte frame (slirp's padded reply), with stats in: incremented per frame."
    expected: "Read blocks while the conversation queue is empty, wakes on the first matching inbound frame, returns one whole frame per read; the wake rides the same EtherHooks the blast gate proved on the TX side."
    why_human: "Presence checks confirm the code and hook registration (main.rs:496-501), but the register→block→wake→whole-frame-copyout state transition has no test anywhere: the net-sweep reads only clone/stats/ifstats, the composed smoke never reads a data file, and there are no host tests of read_data. The plan truth itself anticipated 'a smoke-level check' that does not in fact exist. The 07-07 SUMMARY (criterion D5) already flags this truth human_judgment: true."
deferred:
  - truth: "TX loopback/broadcast feedback into the input path (etheroq → etheriq)"
    addressed_in: "Phase 8"
    evidence: "07-CONTEXT phase boundary excludes arp/ethermedium/ipifc binding from Phase 7; ROADMAP Phase 8 SC4: 'arp + ethermedium bound to devether' (NETIP-04). The omission is documented loudly in devether.rs's header per the 07-07 must-have that locks it."
human_verification:
  - test: "Exercise the blocking data-file read path in a live composed boot: clone a conversation, connect 2054, `cat /net/ether0/N/data` with no traffic (must block), then trigger an ARP reply and confirm the read wakes with one whole frame (see behavior_unverified_items for the full protocol)"
    expected: "Block-on-empty, wake-on-frame, one whole frame per read, stats in: live-incremented"
    why_human: "State-transition invariant (register→block→wake) with zero test coverage at any level; grep proves presence, not the transition. Phase 8's ethermedium is the first real consumer — catching a wedge here is cheaper before Phase 8 builds on it."
  - test: "Reproduce and triage CR-01 (07-REVIEW.md): in a composed boot, `echo connect -1 > /net/ether0/0/ctl` then `cat /net/ether0/0/type`. Donor-faithful expected: reads back `4294967295`. Predicted actual (confirmed by code inspection): kernel panic via usize underflow in readnum_content — devether.rs:479-494 (`NUMSIZE-1-digits.len()` = 11-20 with panic=\"abort\" in both kernel profiles)."
    expected: "Human decides: fix now (recommended — one-line u32 cast per the review, plus a host test pinning connect -1 readback) or defer with a recorded reason in 07-REVIEW-DISPOSITION.md."
    why_human: "The defect is confirmed by inspection but unreachable from any automated gate (the sweep only ever connects 2054), and the fix-vs-defer disposition is a project decision — the disposition ledger exists for exactly this and is currently untriaged (all 14 findings open)."
---

# Phase 07: r9 PCI/ECAM + virtio-net + devether — Verification Report

**Phase Goal:** r9 speaks Ethernet on qemu virt — PCI/ECAM discovery driven entirely by the committed DTB, a virtio-net driver with Day-1 zero-offload discipline over barrier-first virtqueues, and devether presenting `/net/ether0`, proven by a guest ARP request captured on the host. Kernel work in sibling repo `../r9`.
**Verified:** 2026-11-05T03:05:39Z
**Status:** human_needed
**Re-verification:** No — initial verification

**Verification posture note:** this verifier did not stop at the committed evidence. Both payoff gates AND the moved-window perturbation gate were **re-run live during this verification** at r9 HEAD `2afa3d6` (== origin/main == the flake.lock locked rev), and all three passed. The fresh pcaps' frame payloads are byte-identical to the committed evidence.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | r9 finds the NIC from data, not constants: ECAM window from the DTB pci node's translated `reg`, device found by bus walk (1af4:1041 rev≥1), route decoded from `interrupt-map` — zero hardcoded IRQs/addresses (NETDRV-01) | ✓ VERIFIED | `pci.rs:77-177` reads `property_translated_reg_iter` + `dt.interrupt_map_lookup`; `VIRTIO_NET_INTID` publish-once cell keys trap.rs:393-394 (no hardcoded 36). Repo-wide grep: `0x4010…`/`0x3f00…` appear only in a mem.rs unit-test fixture and xtask expectation strings (`PCI_ECAM_BASE_STANDARD/LOWECAM`) — the plan's locked allowance. Live log: `pci: ecam base 0x4010000000`, `pci: virtio-net 1af4:1041 at 00:01.0 rev 01`, `pci: inta -> spi 4 intid 36 flags 0x4 level-high` |
| 2 | Moved-window DTB perturbation still binds the device (NETDRV-01's proof) | ✓ VERIFIED | Committed `virt-gicv2-lowecam.{dts,dtb}` + `config_virtlowecam.toml` (`highmem-ecam=off`). **Re-run live this session: PASS** — fresh log shows `pci: ecam base 0x3f000000 size 0x1000000`, identical route (spi 4/intid 36), and the bind line `#l0: virtio: 1000Mbps: 52:54:00:12:34:56` at line 703. A hardcoded-window driver would fail this boot loudly |
| 3 | DTB discovery failure is loud, never a fallback (NETDRV-01 prohibition, judgment-tier — non-authoritative verdict) | ✓ VERIFIED (code evidence) | pci.rs header: "deliberately NO hardcoded-window fallback"; every absence branch prints a named line and returns None (`pci: no pci node in dtb`, `no ecam window`, `no virtio-net device found`, `no interrupt route`). Host test `fdt::tests::loud_absence_returns_none_never_a_default` passes |
| 4 | The virtio transport is from-scratch in `port/src/virtio.rs` (D-01), generic (D-02), `#![forbid(unsafe_code)]` | ✓ VERIFIED | virtio.rs:54, netif.rs:71, devether.rs:79 all carry the forbid attribute; zero `unsafe` tokens in any of them; module is PCI-capability/negotiation/ring machinery with nothing net-specific beyond the 12-byte header model |
| 5 | Negotiation accepts exactly MAC(5)\|STATUS(16)\|VERSION_1(32) — zero-offload from Day 1 (D-03; NETDRV-02 prohibition, judgment-tier — non-authoritative verdict, test-backed) | ✓ VERIFIED | `ACCEPT_LO=(1<<5)\|(1<<16)`, `ACCEPT_HI=1<<0` (virtio.rs:219-222); `negotiate()` follows §3.1.1 (reset read-back-0 wait → ACK→DRIVER→two-window read→accepted-subset write→FEATURES_OK re-read). Host test `negotiate_accepts_exactly_mac_status_and_version1` passes; **live gate log: `features offered 0x10130bf8024 negotiated 0x100010020`** — the audit line shows every offload bit refused |
| 6 | Barrier-first ring code, order proven by test (D-04 first half) | ✓ VERIFIED | `tx_post_barrier_sandwich_is_the_2_7_13_order` + `used_drain_is_acquire_ordered_and_recovers_the_slot` + `queue_setup_writes_addresses_then_enable_last_and_driver_ok` pass — operation ORDER asserted via Vec-backed mocks recording the volatile-op sequence. `fence(Release)`/`fence(Acquire)` lower to `dmb ish`/`dmb ishld` (review independently confirmed adequacy against the DTB's dma-coherent pci node) |
| 7 | D-01 provenance decision recorded in-repo (NETDRV-02's record requirement) | ✓ VERIFIED | `HowItWorks.md:242-248` — from-scratch choice, control/audit rationale, the stale-caveat note (crate's VERSION_1 concern resolved upstream 2025-09; override stands on control grounds), reversibility rated "costly" |
| 8 | virtio_net_hdr is 12 bytes under VERSION_1 with a const size assertion (CONTEXT errata) | ✓ VERIFIED | virtio.rs:764 comment + `:782` `const _: () = assert!(size_of::<VirtioNetHdr>() == VIRTIO_NET_HDR_LEN)`; TX posts prepend it with num_buffers=0; RX frame length = used len − 12 |
| 9 | devether `#l` presents the netif.h file tree: clone/addr/stats/ifstats + per-conversation N/{data,ctl,stats,type,ifstats}, NETQID(i,t)=(i<<5)\|t, four-string stat records | ✓ VERIFIED | devether.rs:185-196 static metadata table (clone 0666, addr 0666, stats 0444, ifstats 0444; conversation files at owner perms 0666→0660 collapse); netif.rs:96 NETQID; namec.rs:75 `'l' => devether::attach(spec)`; dat.rs:38 DEV_ETHER; syscall.rs pread/pwrite arms (07-07 Deviation 1's real dispatch site). The live sweep walks the tree: clone → ctl write → data writes → stats/ifstats reads |
| 10 | Clone/open semantics per netif.c:158-197 | ✓ VERIFIED | The gate exercises it: `cat /net/ether0/clone` returns the id, `echo connect 2054 > /net/ether0/$conv/ctl` writes the conversation's ctl (arp log lines 1363-1480) |
| 11 | Write path netif-faithful: 60..=1514 bounds, src-MAC overwrite, block-on-full with wake (D-08 wedge-hunt) | ✓ VERIFIED | devether.rs:28-31 documents Etoobig/Etoosmall; the fixture's 60 bytes is exactly ETHERMINTU. Blast gate behaviorally exercises the drain machinery: 256 frames through 128 TX chains reconcile exactly with zero drops — a stalled retire would wedge the writer into the gate timeout |
| 12 | Data-file read path blocks per Qmsg semantics via EtherHooks | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Code complete and hooks registered (main.rs:496-501), omission documented loudly in the module header per the plan's rule — but **no test at any level exercises the block→wake read transition** (nothing reads /net/ether0/N/data: not the sweep, not the smoke, not host tests). The truth's own text anticipated "a smoke-level check" that does not exist. See Human Verification #1 |
| 13 | RX retire → demux per etheriq: inpackets++ every frame, type-match delivery, live counters in the stats file | ✓ VERIFIED | netif.rs:750-753 stats format matches netif.c:221-238 (`in: `, `link: `, `out: `…); arp gate log: `in: 4` / `out: 4` reconciling exactly with the 8-frame pcap; blast: `in: 0` / `out: 256` |
| 14 | ctl depth per discretion: connect N functional, promiscuous no-op, others loud-unimplemented, unknown verbs error loudly | ✓ VERIFIED | Gate: `echo connect 2054` works (arp sent ×4). Code: `nonblocking`/`addmulti`/`remmulti` return loud errors (devether.rs:684-689). **Caveat — see CR-01 below:** `connect -1` is admitted (range check :678 passes -1) and the type-file readback of that legal state panics the kernel; the truth as written verifies on its exercised surface, the defect routes per the review-findings section |
| 15 | ifstats routes to the driver hook with the `vq<q>: avail= used= lastused= nintr= nnote=` line (NETDRV-04 reconciliation surface) | ✓ VERIFIED | arp log: `vq0: avail=132 used=4 lastused=4 nintr=4 nnote=0`, `vq1: avail=4 used=4 lastused=4 nintr=4 nnote=4` — used==lastused (drained), nintr ∈ [1,4] per queue; blast log: `vq1: … used=256 lastused=256 nintr=85` |
| 16 | The guest's ARP request is observable in a host-side capture (NETDRV-03, D-06) | ✓ VERIFIED | Committed `evidence/07-07-virtnet-arp.pcap` independently parsed by this verifier: exactly 8 frames = 4 requests (len 60, sha 52:54:00:12:34:56, spa 10.0.2.15, tpa 10.0.2.2, tha zeroed) + 4 slirp replies (oper=2, spa 10.0.2.2→tpa 10.0.2.15, tha=guest MAC, len 64). **Gate re-run live this session: PASS**; fresh pcap payloads byte-identical to the committed evidence |
| 17 | INTx level-trigger plumbing in BOTH GIC generations, ICFGR before ISENABLER (Pitfall N4) | ✓ VERIFIED | gicv2.rs:95-108 and gicv3.rs:226-239 both program ICFGR level BEFORE ISENABLER with the IMPLEMENTATION-DEFINED-reset rationale; the NIC binds on both generations (virtexec3 = GICv3; the darwin smoke leg is gicv3+hvf) |
| 18 | ISR read-to-ack: handler's first device touch is the ISR byte | ✓ VERIFIED | pci.rs:846-847: `let isr = io::read_reg8(&state.isr, 0);` precedes all queue work; bounded drain (DRAIN_CAP), faults counted loudly |
| 19 | Interrupt accounting reconciles under sustained load — no silent virtqueue wedge (NETDRV-04) | ✓ VERIFIED | **Blast gate re-run live this session: PASS.** 256 pure-TX frames: pcap == sent == stats out == 256, stats in == 0, nintr_tx=86 ∈ [1,256], used==lastused, zero soverflows, NET-DONE in budget, negative scan clean. Fresh pcap payloads byte-identical to committed evidence (256 frames, all oper=1) |
| 20 | xtask netdev stanza is aarch64-virt-only; riscv64/x86_64/raspi argv untouched (D-09/D-10 staging) | ✓ VERIFIED | config.rs:576-584 `apply_virt_netdev` gated on `platform == "virt"`; unit tests pin the emitted argv (`boot-test-virt.pcap` per-config path); riscv64's MMIO leg is a separate emission site |
| 21 | xtask pcap parser is std-only and unit-proven before the live gate (D-06 machinery) | ✓ VERIFIED | xtask/src/pcap.rs (44 KB, bounds-checked per the review); 12 assertion tests RED-path-proven in 07-05-RED-task2.json (exit 101, golden + 11 negative fixtures fail pre-implementation); xtask suite 47/47 green this session |
| 22 | Bootfs payload: 60-byte ARP fixture, two-mode sweep, netblast, dd — manifest-asserted at bake | ✓ VERIFIED | `arp.req` hexdump is byte-exact to D-07+errata (dst bcast, src 52:54:00:12:34:56, ethertype 0x0806, spa 10.0.2.15, tpa 10.0.2.2, 18-byte zero pad — 60 bytes total); net-sweep.rc has both modes with named FAIL lines; mkimage.sh:117,135-138 manifest asserts; subset-build.sh stages dd + netblast; netblast.c conforms to style(6) |
| 23 | virtnet Net profile: real Harvey boot chain under xtask, typed sweep, fast-fail, pcap assertions in finish() after sweep markers, guest MAC parsed from the bind line | ✓ VERIFIED | config_virtnet.toml (dev exec+bootchain+ether, gicv2, committed DTB, `harvey:` initrd); main.rs:1472 types `rc /lib/net-sweep.rc {mode}\r`; finish() calls `pcap::assert_arp_pingpong`/`assert_blast`; negative scan exempts exactly the D-02 fauth line. Both modes re-run green this session |
| 24 | Driver bind per spec order: BAR4 sized/assigned from the DTB `ranges` window, PCI_COMMAND Memory+Master explicit, capability walk bounds-checked, queue_enable LAST, DRIVER_OK before any notify, RX pre-post | ✓ VERIFIED | Live log: `pci: bar4 pa 0x8000000000 size 0x4000 readback 0x8000000000`, `pci: caps common@0x0+0x1000 notify@0x3000 isr@0x1000 device@0x2000 mult 4`, `rx pre-posted 128 buffers qsize 256`; pci.rs:209-216 PCI_COMMAND bits; host test `queue_setup_writes_addresses_then_enable_last_and_driver_ok` pins the order |
| 25 | `dev = ["ether"]` across every aarch64 virt config (D-10 end state) + cfg(dev_ether) declared | ✓ VERIFIED | All nine config_*.toml carry it (review files_reviewed_list spans them; virtnet/virtshell/lowecam read directly); Cargo.toml:34 declares `cfg(dev_ether)` in check-cfg |
| 26 | Push-before-pin: r9 pushed to requaos/r9 BEFORE the Harvey flake.lock advanced; pin commit names flake.lock alone; locked rev == live HEAD, owner requaos | ✓ VERIFIED | r9 HEAD == origin/main == `2afa3d6` (git ls-remote); harvey commit `06380f2b` touches flake.lock ALONE (`git show --stat`: 1 file, 3+/3-) and lands before compose commit `15739d10` in origin/master history; flake.lock json-parsed: rev `2afa3d6ebfde…`, owner `requaos`, repo `r9` |
| 27 | Composed boot speaks Ethernet: identical stanza on all three compose paths, smoke nic-bind post-pass, fresh hosted CI green | ✓ VERIFIED | Byte-identical `-netdev user,id=n0` + `-device virtio-net-pci-non-transitional,netdev=n0` in nix/boot-r9.sh:197-198, run-r9.sh:125-126, smoke-r9.expect:98-99; no filter-dump on compose paths. smoke-r9.expect:264-269 whole-capture nic-bind post-pass. Local smoke-r9.log (gitignored transient, still on disk) matches EVIDENCE.md exactly: 1442 lines, bind line at :990. **Hosted CI API-verified: run 41955568449 r9-shell conclusion=success headSha=15739d10** |

**Score:** 26/27 truths verified (1 present, behavior-unverified)

### Decision Coverage

All trackable CONTEXT.md decisions are honored by shipped artifacts. (10/10 — D-01..D-10; non-blocking gate, `check.decision-coverage-verify` handler result.)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | TX loopback/broadcast feedback into the input path (etheroq → etheriq) — deliberately not implemented this phase | Phase 8 | 07-CONTEXT phase boundary excludes the arp/ethermedium/ipifc binding; ROADMAP Phase 8 SC4 ("arp + ethermedium bound to devether", NETIP-04); omission documented loudly in devether.rs header per the 07-07 must-have that locks it |

### Required Artifacts

r9-side artifacts are outside this repo's fingerprint surface (the phase pins the exact rev — r9 `2afa3d6ebfde3a6a5fcc123d2cfaf89fd6dc0466` == origin/main — as the evidence anchor; per-phase SHAs in 07-EVIDENCE.md).

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `../r9/aarch64/src/platform/virt/pci.rs` | DTB-driven ECAM discovery + driver bring-up + IRQ handler | ✓ VERIFIED | 39.9 KB; discovery, BAR/caps, negotiation drive, ISR read-to-ack handler all present and wired |
| `../r9/port/src/virtio.rs` | from-scratch unsafe-free transport | ✓ VERIFIED | 36.5 KB; `#![forbid(unsafe_code)]`; ACCEPT mask; §3.1.1 machine; ring model |
| `../r9/port/src/netif.rs` | Netif/Netfile model, counters, EtherHooks | ✓ VERIFIED | 32.8 KB; forbid(unsafe); qid scheme; WaitSet (see WR-05) |
| `../r9/port/src/devether.rs` | the `#l` device surface | ✓ VERIFIED | 29 KB; forbid(unsafe); full file tree; ctl verbs (see CR-01) |
| `../r9/port/src/fdt.rs` | interrupt-map helpers + decode tests | ✓ VERIFIED | find_phandle/#interrupt-cells/interrupt_map_iter/masked lookup; 6 fdt tests green incl. `interrupt_map_decodes_all_16_entries` and `masked_lookup_routes_the_virtio_nic_inta_to_spi4` on the committed DTB bytes |
| `../r9/port/src/virtio_tests.rs` | host ring/negotiation suite (D-04) | ✓ VERIFIED | 22 tests, all green this session (`cargo test -p port`: 108 total across port binaries, 0 failed) |
| `../r9/xtask/src/pcap.rs` + `config.rs` + `main.rs` | netdev emission, harvey: channel, Net profile, assertions | ✓ VERIFIED | xtask suite 47/47 green this session; live gates PASS ×3 |
| `../r9/HowItWorks.md` | D-01 provenance record | ✓ VERIFIED | §virtio lines 242-248 (note: IN-03 doc drift elsewhere in this file — proc/fd table sizes stale) |
| `../r9/aarch64/lib/virt-gicv2-lowecam.{dts,dtb}` + `config_virtlowecam.toml` | the perturbation fixture | ✓ VERIFIED | committed; live gate PASS on the moved window |
| `build/aarch64/root-tree/lib/test/arp.req` | 60-byte ARP fixture | ✓ VERIFIED | byte-exact vs D-07 + ETHERMINTU errata (hexdumped) |
| `build/aarch64/root-tree/lib/net-sweep.rc` | two-mode sweep | ✓ VERIFIED | arp + blast modes, named FAIL lines, NET-DONE (see WR-07 for a hand-typed-arg hang) |
| `build/aarch64/netblast.c` | TX-bulk generator | ✓ VERIFIED | style(6)-conformant; `netblast: sent <n>` marker; tpa 10.0.2.99 pure-TX design |
| `evidence/07-07-virtnet-{arp,blast}.{log,pcap}` | committed gate evidence | ✓ VERIFIED | pcaps independently parsed — frame counts/fields exactly as claimed; payloads byte-identical to this session's fresh re-runs |
| `flake.lock` | r9 pin at the gated HEAD | ✓ VERIFIED | rev 2afa3d6…, owner requaos — resolves from clean clone |
| `nix/boot-r9.sh`, `build/aarch64/run-r9.sh`, `build/aarch64/smoke-r9.expect` | D-10 compose stanza + nic-bind post-pass | ✓ VERIFIED | byte-identical stanza tokens; post-pass at smoke-r9.expect:264 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `pci.rs` discovery | `fdt.rs` | `interrupt_map_lookup` / `property_translated_reg_iter` | ✓ WIRED | pci.rs:88,145 |
| `virt/mod.rs` | `pci.rs` | `pci::discover_and_print(dt)` on every virt boot | ✓ WIRED | mod.rs:40; prints observed in every live log |
| `trap.rs` | `pci.rs` handler | match-guard on `virtio_irq_intid()` (published, not hardcoded) | ✓ WIRED | trap.rs:393-394 |
| `main.rs` | bind chain | `#[cfg(dev_ether)] platform::pci::bind_virtio_net(&dt)` in the IRQ-arming window | ✓ WIRED | main.rs:377-378 |
| `main.rs` | `devether` hooks | `set_hooks(EtherHooks{current,block,wake})` before first exec | ✓ WIRED | main.rs:496-501 |
| `namec.rs` | `devether.rs` | `'l'` attach arm + DEV_ETHER walk/open/stat/read dispatch | ✓ WIRED | namec.rs:75,115,336,361,405; syscall.rs pread/pwrite arms (Deviation 1's real site) |
| `xtask main.rs` | `pcap.rs` | `mod pcap` + finish() assertions | ✓ WIRED | main.rs:20,1589-1591 |
| `xtask config.rs` | `uregcheck.rs` | `harvey:` prefix → `harvey_dir()` | ✓ WIRED | config.rs:131-137 |
| `net-sweep.rc` | `arp.req` + `netblast` | dd to data file / exec blaster | ✓ WIRED | exercised live in both gate re-runs |
| `smoke-r9.expect` | composed boot | spawn argv stanza + whole-capture nic-bind post-pass | ✓ WIRED | log line 990 + hosted CI success |
| `flake.lock` | compose paths | pin delivers the dev-ether virtshell kernel | ✓ WIRED | smoke's store path names the 2afa3d6 kernel (EVIDENCE.md) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------| ------ |
| pci discovery prints | ecam base/size, route | DTB parse (live hardware description) | Yes — changes with the DTB (0x4010000000 vs 0x3f000000 across the two profiles) | ✓ FLOWING |
| negotiated-mask print | features | device config registers over mapped BAR4 | Yes — offered mask is qemu's real offer set | ✓ FLOWING |
| stats file | in/out counters | IRQ-driven RX retire + syscall TX post | Yes — reconcile with the pcap exactly | ✓ FLOWING |
| ifstats file | avail/used/lastused/nintr/nnote | live ring indices + IRQ counters | Yes — nintr varies run-to-run (85 vs 86 across two green blast runs) | ✓ FLOWING |
| host pcap | frames | qemu filter-dump on the netdev | Yes — per-invocation fresh (pre-spawn removal, main.rs:1189-1191) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Host port suite (ring/negotiation/fdt/paqfs) | `nix develop --command cargo test -p port` | 108 passed, 0 failed (incl. 22 virtio_tests, 6 fdt interrupt-map tests) | ✓ PASS |
| Host xtask suite (pcap assertions, argv pinning) | `nix develop --command cargo test -p xtask` | 47 passed, 0 failed | ✓ PASS |
| **arp-mode payoff gate (NETDRV-03)** | `R9_HARVEY_DIR=… cargo xtask boot-test --arch aarch64 --config virtnet` | `boot-test: PASS — …typed sweep (arp mode, N=4), netsweep markers and the pcap assertion observed` | ✓ PASS (live re-run) |
| **blast-mode load gate (NETDRV-04)** | `R9_NET_SWEEP_MODE=blast … --config virtnet` | `boot-test: PASS — …(blast mode, N=256)…`; fresh log `out: 256`, `vq1: used=256 lastused=256 nintr=86` | ✓ PASS (live re-run) |
| **moved-window perturbation (NETDRV-01)** | `cargo xtask boot-test --arch aarch64 --config virtlowecam` | PASS; fresh log shows `ecam base 0x3f000000`, same route, NIC binds | ✓ PASS (live re-run) |
| Fresh pcap vs committed evidence | python pcap parse + payload compare | arp: 8==8 frames, payloads byte-identical; blast: 256==256, byte-identical | ✓ PASS |
| Hosted CI at the pushed pin | `curl api.github.com/…/runs/41955568449` | `r9-shell | success | 15739d108595…` | ✓ PASS |

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|-----------|-----------|--------|---------|----------|-----------------|---------|
| `port/src/virtio_tests.rs` | NETDRV-02 | 22 | 0 | No — mocks record op order; oracle is the virtio spec's §2.7.13/§3.1.1 sequences | Behavioral (sequence assertions) | ✓ SUFFICIENT |
| `port/src/fdt.rs` (in-file tests) | NETDRV-01 | 6 | 0 | No — fixture is the committed qemu-generated DTB (external-system output) | Value-level (exact SPI/flags decode) | ✓ SUFFICIENT |
| `xtask/src/pcap.rs` tests | NETDRV-03/04 | 12 | 0 | No — synthetic fixtures hand-built before the live gate existed; RED-path-proven (07-05-RED-task2.json: exit 101, golden + negatives all fail pre-implementation) | Value + negative (field-exact + mismatch rejection) | ✓ SUFFICIENT |
| `xtask/src/config.rs` tests | NETDRV-03 | 5+ | 0 | No | Value (argv token equality) | ✓ SUFFICIENT |

**Disabled tests on requirements:** 0. **Circular patterns:** 0. **Insufficient assertions:** 0.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers in any phase-modified file (r9 or harvey side); no empty-implementation or console-only patterns observed during full-file reads of the core modules | — | — |

### Review Findings Routing (07-REVIEW.md — 14 open/untriaged in 07-REVIEW-DISPOSITION.md)

The code review's central finding holds up under this verifier's re-inspection: the phase's core engineering is sound (the review itself says so, and three live gate re-runs this session agree). The defects cluster on **gate-unexercised edges** — none falsifies a must-have truth as written, so none blocks goal verification. But "open/untriaged" is not a terminal state for a critical panic; the routing below is this verification's recommendation to the disposition ledger:

| Finding | Verified this session? | Routing recommendation |
|---------|------------------------|------------------------|
| **CR-01** `readnum_content(-1)` kernel panic | **Confirmed by inspection at every link**: `connect -1` admitted (devether.rs:678 `typ < -1` passes -1) → parse_i32 handles the minus (:701) → conv_connect stores i32 → type_of returns it → `(-1) as u64` = 20 digits → `NUMSIZE(12) − 1 − 20` underflows usize → slice panic → `panic = "abort"` in both kernel profiles | **Gap closure (fix before Phase 8).** A two-command userspace sequence panics the kernel on the phase's headline deliverable; the donor-faithful fix is the review's one-line u32 cast + a host test. Phase 8's ethermedium/arp will exercise ctl/type heavily — fix before that lands. Escalated as Human Verification #2 |
| **WR-05** WaitSet 16 vs MAX_PROCS 64 silent drop | Confirmed: netif.rs:315-335 `[u64; 16]` + stale "≤ 16 procs" comment vs proc.rs MAX_PROCS=64; full arm silently no-ops | **Gap closure** (same module area as CR-01; silent-wake-loss is the wedge class this phase forbids; cheap: size to the proc table + loud drop counter) |
| **WR-06** RX retire slot-liveness | Confirmed plausible: handler's retire path clears `posted[slot]` unconditionally (pci.rs:876-902 + virtio.rs:753-756); a duplicated used id aliases one page into two chains | **Gap closure** (one-line check + host negative test; untrusted-device posture the module itself documents) |
| **WR-01..WR-04, WR-08** malformed-device validation gaps | Spot-confirmed WR-02 (bind accepts devcfg length ≥ 6, link-status read needs 8 — off-by-two from the driver's own usage) | **Bundle into the same closure** — all are cheap integer checks completing the module's own "loud bind failure" contract; latent on qemu's well-formed device, so defer-with-reason is also defensible for WR-03/WR-08 |
| **WR-07** rc leading-zero hang | Confirmed by reading net-sweep.rc:35-42 + :74-81 (`04` accepted, `$#i` never string-matches `04`) | **Closure** (one-line validation reject); gate-irrelevant (gates pass no count) but the script's own header forbids silent hangs |
| **IN-01..IN-05** hygiene (dead dd line, offset_addr width, doc drift, DescPool guards, atoi) | IN-03 spot-confirmed: config_virtnet.toml's header comment is indeed stale post-07-06, and HowItWorks.md:64's proc/fd numbers predate the 05-06/07-07 bumps | **Bundle as hygiene** in the closure pass |

### Human Verification Required

**1. Blocking data-file read path (Qmsg block→wake transition)**

**Test:** In a composed boot (`nix run .#boot-r9`), `bind -a '#l' /net`, `conv=`{cat /net/ether0/clone}`, `echo connect 2054 > /net/ether0/$conv/ctl`, then `cat /net/ether0/$conv/data` with no traffic — the read must block (no EOF, no error). Then from a second conversation dd `/lib/test/arp.req` to its data file so slirp's reply arrives, and confirm the blocked read wakes returning exactly one whole frame (64 bytes — slirp pads). Check `cat /net/ether0/stats` shows `in:` incremented per frame.
**Expected:** block-on-empty → wake-on-matching-frame → one whole frame per read; no wedge, no panic.
**Why human:** The register→block→wake→copyout state transition has zero test coverage at any level (gate, smoke, host). Presence checks prove the code and hook registration exist; they cannot prove the transition. The 07-07 SUMMARY (criterion D5) already flags this truth `human_judgment: true`; the plan's truth text anticipated "a smoke-level check" that was never in fact added. Phase 8's ethermedium is the first real consumer — verify before Phase 8 builds on it.

**2. CR-01 reproduction + triage decision**

**Test:** In the same composed boot: `echo connect -1 > /net/ether0/0/ctl` then `cat /net/ether0/0/type`.
**Expected (donor-faithful):** reads back `4294967295`. **Predicted actual (confirmed by code inspection):** kernel panic — devether.rs:479-494 usize underflow, `panic = "abort"`.
**Why human:** The defect is unreachable from every automated gate (the sweep only connects 2054), and fix-now vs defer-with-reason is a project decision — the disposition ledger (all 14 findings currently `open`) is the venue. This verifier's recommendation: fix now; it's one line plus a host test, and Phase 8 will hammer this surface.

### Gaps Summary

No verification gaps: every must-have truth is VERIFIED except one ⚠️ PRESENT_BEHAVIOR_UNVERIFIED truth (the blocking read path), which routes to human verification above. The phase goal — r9 speaks Ethernet on qemu virt with DTB-driven discovery, Day-1 zero-offload discipline, `/net/ether0` per netif.h, and the guest ARP captured host-side — is **observably achieved**, re-proven live at the pinned HEAD during this verification (arp gate PASS, blast gate PASS, moved-window perturbation PASS, hosted CI success API-confirmed).

The status is `human_needed` (not `passed`) solely because of the two human items above: one behavior-unverified state transition, and one confirmed critical review finding whose triage belongs to the developer. Neither contradicts the goal's achievement; both should be resolved before Phase 8 builds the TCP/IP path on this surface.

**One immaterial accuracy nit:** 07-EVIDENCE.md quotes `nintr_tx=86` for the blast gate while the committed blast log shows `nintr=85`. Both values satisfy the asserted invariant (nintr ∈ [1,256] with drained rings) — coalescing varies run to run (this session's re-run also produced 86). The index's quote came from a different green run than the committed log; worth a one-word fix when the review dispositions land, not a gap.

---

_Verified: 2026-11-05T03:05:39Z_
_Verifier: the agent (gsd-verifier)_
