---
phase: 17-r9-kernel-flush-out
verified: 2026-11-13T07:11:20Z
status: gaps_found
score: 5/6 must-haves verified
covered_files: [".planning/WINDOWS.md", ".planning/milestones/v2.0-phases/07-r9-pci-ecam-virtio-net-devether/07-REVIEW-DISPOSITION.md", ".planning/milestones/v2.0-phases/08-r9-tcp-ip-path-devip-compatible-net/08-REVIEW-DISPOSITION.md", ".planning/phases/17-r9-kernel-flush-out/17-01-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-01-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-02-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-02-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-03-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-03-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-04-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-04-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-05-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-05-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-06-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-06-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-07-PLAN.md", ".planning/phases/17-r9-kernel-flush-out/17-07-SUMMARY.md", ".planning/phases/17-r9-kernel-flush-out/17-CR07-ROOTCAUSE.md", ".planning/phases/17-r9-kernel-flush-out/17-FLUSHOUT.md", ".planning/phases/17-r9-kernel-flush-out/17-REVIEW-DISPOSITION.md", ".planning/phases/17-r9-kernel-flush-out/17-REVIEW.md", "build/x86_64/churn-r9.expect", "build/x86_64/churncats.c", "build/x86_64/churnmark.c", "build/x86_64/churnsem.c", "build/x86_64/root-tree/lib/churn-cats.rc", "build/x86_64/root-tree/lib/netstress.rc", "build/x86_64/stress-r9.expect", "flake.lock", "flake.nix", "nix/churn-r9-x64.sh", "nix/stress-r9-net-x64.sh", "sys/src/cmd/rc/exec.c", "sys/src/cmd/rc/plan9.c", "sys/src/cmd/rc/simple.c"]
covered_digest: "v4:sha256:dee16d1d31549eb2dd3265877d93691f614d11f27049c90c292051b1b5fd14b0"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "SC1/FLUSH-01 — the Phase-8 CR class 'multi-waiter RX-wake' (CR-07 / WINDOWS #66) is closed with tests or explicitly dispositioned with rationale"
    status: failed
    reason: >-
      The class is NOT closed and NOT explicitly dispositioned: WINDOWS #66 status=open (reason empty) and the 08-ledger CR-07 row stays skipped. The N=25 stress series at the fix pin FAILED AT RUN 3 (evidence/17-07-cr07-n25-series-at-fix-pin.log: greens=2; fix-pin fire serial retained) — the deregister fix (r9 d4a5d38) is real hardening but was refuted as the CURE by the plan's own D-03 evidence bar. The executor honestly recorded this (17-07-SUMMARY status: halted; FLUSH-01 and FLUSH-04 left unchecked in REQUIREMENTS.md). The goal's 'closed with tests or explicitly dispositioned' bar is therefore not met for this one class — a live ~8%/run triple-fault class under the full 8-way concurrent bulk transfer, with a committed reproduction instrument (boot-r9-stress-x64) and venue-conditional reopener, but no cure and no accepted disposition.
    artifacts:
      - path: ".planning/WINDOWS.md"
        issue: "row #66 status=open (enriched description; resolved_at null) — neither fixed nor waived/deferred"
      - path: ".planning/milestones/v2.0-phases/08-r9-tcp-ip-path-devip-compatible-net/08-REVIEW-DISPOSITION.md"
        issue: "CR-07 row disposition=skipped (enriched backbone; the accidental 'fixed' prose match deliberately removed so the gate fails honestly)"
      - path: ".planning/phases/17-r9-kernel-flush-out/17-CR07-ROOTCAUSE.md"
        issue: "section 7 records the refutation; the cure is assigned to a future venue-conditional reopener with NO owning phase in the roadmap"
    missing:
      - "A cure for the #66 triple-fault class (the hunt resumes from 17-CR07-ROOTCAUSE.md when a host-side venue can reach the faulting context or non-healing instrumentation exists), OR an explicit maintainer disposition (waiver/defer with the 3-part D-15 rationale) accepted via a VERIFICATION override — see the override suggestion in this report"
      - "If accepted as-is: re-check FLUSH-01 (and decide FLUSH-04) in REQUIREMENTS.md to reflect the ratified outcome; today both honestly read Pending"
overrides:
  - must_have: "SC1/FLUSH-01 — the Phase-8 CR class 'multi-waiter RX-wake' (CR-07 / WINDOWS #66) is closed with tests or explicitly dispositioned with rationale"
    reason: "Maintainer-ratified explicit disposition at the 17-08 blocking-human checkpoint (Neil Skinner, 2026-11-13T14:42:08Z): investigated-to-the-capture-ceiling (the KVM ceiling of 17-CR07-ROOTCAUSE section 2, completed by section 8's TCG x slirp avenue — NO-FIRE-IN-SERIES) + hardened (r9 d4a5d38) + reproducible-at-will (boot-r9-stress-x64, ~25s) + the 3-part D-15 rationale with a venue-conditional reopener per section 7 — deferred/waived, NOT cured; FLUSH-04 ratified yes in the same decision (the verifier-confirmed letter: #44/#45 closed, every landed fix pinned)"
    accepted_by: "Neil Skinner"
    accepted_at: "2026-11-13T14:42:08Z"
---

# Phase 17: r9 Kernel Flush-Out Verification Report

**Phase Goal:** The r9 kernel is functionally hardened under real userspace load — the open Phase-7/8 review backlog (the CR classes, the RFMEM OOM leaks, the WR hardening gaps) plus the known kernel windows are closed with tests or explicitly dispositioned with rationale, every fix landing with a pin (host test or boot-test gate) per the established discipline. **Kernel work in sibling repo `../r9`.**
**Verified:** 2026-11-13T07:11:20Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

Verified against the actual repos: Harvey at HEAD (48bd6c0d4) and the writable sibling r9 repo (clean, 0 unpushed, origin/main = 8f3ff11 — matching Harvey's flake.lock r9 input 8f3ff11 exactly). All 25 r9 commits claimed across the seven plans exist and are pushed. Every host-test pin claimed by the phase was re-run live in its own process this verification (not trusted from SUMMARYs).

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1/FLUSH-01: the Phase-8 CR classes are closed with tests or explicitly dispositioned — conv_close FIN-drop (CR-01), permanent-send-error wedge (CR-02), semacquire wakeup loss (CR-03), ipifc multicast panic (CR-04), unbind stale-handle aliasing (CR-05), tcp_gc aliasing (CR-06), multi-waiter RX-wake (CR-07) | ✗ FAILED | CR-01..06: VERIFIED closed — 08-REVIEW-DISPOSITION.md rows read fixed with x86_64-keyed Source re-cites (14 `x86_64` mentions, baseline 0); named host pins re-run green live (sem_ 5/5 among 124/124 port; 76/76 x86_64 bins). CR-07 (multi-waiter RX-wake / WINDOWS #66): NOT closed, NOT dispositioned — WINDOWS #66 `status: open`, 08-ledger CR-07 `skipped`; the N=25 stress series at the fix pin failed at run 3 (`evidence/17-07-cr07-n25-series-at-fix-pin.log` — greens=2; fix-pin fire serial retained with the SeaBIOS reset chain). The deregister hardening (r9 d4a5d38, wake filter 6/6 green live) is beside the open row, never its closure — the phase's own honest verdict, and the evidence supports it |
| 2 | SC2/FLUSH-02: the RFMEM OOM-path page leaks (the 6 WR findings) are closed with refcount proofs — leak gates demonstrate bounded memory under fork/exec churn | ✓ VERIFIED | The D-02 audit table (17-01-SUMMARY, 24 rows, zero sampled) with 4 x86_64-local gaps ported (r9 3e8bcec exists); the tiered gates exist and ran green twice each (churngate.rs CEILING_BYTES_PER_EXEC=1772 with the derivation comment + negative-control record; composed boot-r9-churn-x64; capture `build/x86_64/churn-r9.log` on disk carries `churn: CATS-DONE 1400`); WINDOWS #44 status=fixed with r9 c4f2f2c+72edbba reason and resolved_at stamped; port battery 124/124 re-run green live |
| 3 | SC3/FLUSH-03: the Phase-7 WR hardening gaps are closed — cap-walk loud-abort holes, WaitSet-16-vs-proc-table sizing, used-id slot-liveness | ✓ VERIFIED | Code re-read live: `MAX_WAITERS: usize = 512` at r9 port/src/lib.rs:130; `grep 'u64; 16]' port/src/` = 0 (baseline 18); the liveness reject `"virtio: used-ring id for an unposted slot (device fault)"` at virtio.rs:780 BEFORE the recovery clear; `p & 3` + `cap_len < CAP_NOTIFY_LEN` rejects in Caps::parse (virtio.rs:140/:170); check_cap_extents / is_64bit_mem_bar_nibble / notify_reachable predicates in pci.rs. Pins re-run green live: waitset 9/9, used_ 4/4, caps 5/5, x86_64 battery 76/76. 07-ledger: WR-01..06 disposition: fixed, WR-07/08 disposition: deferred (3-part WHERE/WHY/Reopener), open count exactly 5 (the IN rows, by policy) |
| 4 | SC4/FLUSH-04 (letter): the known kernel windows are closed or gated — fork+exec arena drain (#44), namec union-create miss (#45) — every flush-out fix lands with a pin | ✓ VERIFIED | #44 fixed (truth 2); #45 fixed: walk_one_union (namec.rs:341) + create_chan_union (namec.rs:460) + sys_create routing + the nomount follow-up (r9 421d5e1); namec pins re-run green live (6/6); WINDOWS #45 status=fixed citing r9 cfe7af0+421d5e1 + the host pins + gates. Every landed fix row in 17-FLUSHOUT.md carries a host-test or boot-gate pin. NOTE: REQUIREMENTS.md leaves FLUSH-04 unchecked — the phase's own stricter bar ties it to the CR-07/#66 open row (see Gaps Summary); the roadmap-SC letter for #44/#45 is met. Ratification of the checkbox is a maintainer call (escalation item 1) |
| 5 | Goal discipline clause: every fix landing with a pin (host test or boot-test gate) | ✓ VERIFIED | Walked all 30 FLUSHOUT rows: every fixed row names its pin(s) + commit SHA(s); all 25 claimed r9 commits exist and are pushed; Harvey pin-advance commit 1c51844f2 is flake.lock-only; the r9 tree is clean with origin/main = 8f3ff11 = Harvey's locked pin |
| 6 | Goal index clause: the closure index (17-FLUSHOUT.md) is complete and VERIFICATION-walkable (D-16) | ✓ VERIFIED | 31 `\| `-leading lines (header + 30 rows), zero `pending` cells; the CR-07/#66 rows carry the honest open state (investigated + hardened + reproducible-instrument, no cure claim) rather than placeholder or false closure; the pin-advance lineage table (208ceba -> every fix SHA -> every own-commit advance) is present and matches the git record |

**Score:** 5/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/phases/17-r9-kernel-flush-out/17-FLUSHOUT.md` | 30-row closure index, zero placeholder cells | ✓ VERIFIED | Header + 30 rows; 0 `pending`; lineage table present |
| `../r9/x86_64/src/proc.rs` | 4 OOM-release ports + 4 sem pins | ✓ VERIFIED | sem pins at :2927/:2941/:2959/:2976; ports in commit 3e8bcec (ancestor of 8f3ff11) |
| `../r9/x86_64/lib/config_q35churn.toml`, `../r9/x86_64/src/platform/q35/churngate.rs` | churn profile + slope driver | ✓ VERIFIED | Exist; CEILING_BYTES_PER_EXEC=1772 documented at the const; cfg-gated |
| `build/x86_64/churn-r9.expect`, `nix/churn-r9-x64.sh`, churncats.c/churnmark.c/churnsem.c, `root-tree/lib/churn-cats.rc` | composed churn leg | ✓ VERIFIED | All exist; flake app boot-r9-churn-x64 wired (flake.nix:336/:406) |
| `build/x86_64/stress-r9.expect`, `nix/stress-r9-net-x64.sh`, `root-tree/lib/netstress.rc` | CR-07 stress instrument | ✓ VERIFIED | All exist; flake app boot-r9-stress-x64 wired (flake.nix:353/:410); `stress-r9.log` on disk carries stress: markers |
| `../r9/port/src/lib.rs` + netif/stack/conv + netlog/proto/ipifc | MAX_WAITERS=512 across 3 WaitSet copies + 12 buffers | ✓ VERIFIED | Single const at lib.rs:130; 0 `u64; 16]` literals remain |
| `../r9/port/src/virtio.rs`, `../r9/port/src/virtio_tests.rs` | parse + used-id + extent/BAR hardening with pins | ✓ VERIFIED | Rejects in place (virtio.rs:140/:170/:780); caps 5/5 + used_ 4/4 green live |
| `../r9/x86_64/src/platform/q35/pci.rs` | q35 bind-time loud aborts | ✓ VERIFIED | check_cap_extents (:955), is_64bit_mem_bar_nibble (:829), notify_reachable (:862); 76/76 battery |
| `../r9/port/src/namec.rs`, `../r9/port/src/namec_tests.rs` | union consult twins + 6 host pins | ✓ VERIFIED | walk_one_union (:341), create_chan_union (:460); namec 6/6 green live |
| `../r9/port/src/devip/stack.rs` (+proto.rs/devip.rs) | NET_WAITERS deregister counterpart + NetWaiterScope | ✓ VERIFIED | deregister_net_waiter (stack.rs:273), NetWaiterScope + Drop (:289-302), scope at blocking fns; wake filter 6/6 green live |
| `sys/src/cmd/rc/{simple,plan9,exec}.c` | the three rc corner fixes | ✓ VERIFIED | dupfailed + checked Dup in both arms (simple.c:85/:100/:106); first-failure cerrstr (plan9.c:361/:390-397); argv-stack guards at Xqdol/Xcount (exec.c:720/:837) with panic sites :45/:54 untouched; commit 6779df7d7 spans exactly the three files |
| `.planning/WINDOWS.md`, 07/08 REVIEW-DISPOSITION ledgers | closure records | ✓ VERIFIED | #18/#44/#45/#46/#47/#49/#65 fixed, #50 waived (3-part), #66 open (the gap); 07 ledger 5 open (IN rows); 08 ledger CR-01..06 fixed, CR-07 skipped, 14 x86_64 re-cites |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| port host battery | composed x64 net gate | 08-ledger Source re-cite -> FLUSHOUT row | ✓ WIRED | 14 x86_64 mentions in the 08 ledger (baseline 0); CR-01 row names the devip_tests pin + the gate; FLUSHOUT rows cite both |
| MAX_WAITERS (port root) | 3 WaitSet copies + 12 take buffers | the single const | ✓ WIRED | 0 surviving `u64; 16]` literals; waitset pins 9/9 at all three homes |
| used-id liveness check | slot-recovery clear | the check precedes the clear in next_used | ✓ WIRED | virtio.rs:780 reject before the posted[slot]=false clear; used_ 4/4 |
| heap_stats() | churn driver samples -> xtask post-pass bound | kernel's own marker, parsed | ✓ WIRED | churngate.rs emits `churngate: heap` markers; xtask re-derives from markers (churn log on disk shows the marker lines) |
| Caps::parse (shared) | q35 bind path -> devcfg+6 IRQ read | one class commit cc22223 | ✓ WIRED | Predicates called at the bind site; battery + live caps print recorded at the pin |
| chain_snapshot contract | walk_one_union/create_chan_union | sys_create routing | ✓ WIRED | Twins + sys_create re-wire (r9 cfe7af0+421d5e1); namec 6/6 |
| the #66 toolkit -> reproduction -> root-cause record -> fix -> pins | the committed instrument + record | stress app + 17-CR07-ROOTCAUSE.md | ✓ WIRED | Instrument committed + proven (3 fires); record carries mechanism, candidate verdicts, fold SPLIT, and the post-fix refutation — the chain is wired to an honest open terminus, not a closure |
| pg.lock sites -> snapshot-then-drop | #18 closure | 4-site audit | ✓ WIRED | Re-verified live: :527/:599/:716 with drop(guard) at :529/:601/:718 before any close/walk; :1170 chain_snapshot block shape |

### Data-Flow Trace (Level 4)

Kernel/infrastructure phase — no rendered-UI data. The gate data flows verified instead: the leak gates bound on numbers parsed from the kernel's own `churngate: heap` markers (present in the retained captures), never a second hardcoded constant; the ceiling const is derived from a measured baseline with a pin asserting `CEILING == derive_ceiling(420)`.

### Behavioral Spot-Checks

All run live this verification in /home/req/code/r9 with the pinned nightly-2026-01-30 toolchain:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full r9 port host battery | `cargo test -p port --lib` | 124 passed / 0 failed | ✓ PASS |
| Full r9 x86_64 bins battery | `cargo test -p x86_64 --bins --target x86_64-unknown-linux-gnu` | 76 passed / 0 failed | ✓ PASS |
| CR-03 sem contract pins | `cargo test -p x86_64 ... -- sem_` | 5 passed / 0 failed | ✓ PASS |
| CR-07 multi-waiter/deregister pins | `cargo test -p port --lib -- wake` | 6 passed / 0 failed | ✓ PASS |
| WR-05 WaitSet capacity boundary | `cargo test -p port --lib -- waitset` | 9 passed / 0 failed | ✓ PASS |
| WR-06 used-id liveness negatives | `cargo test -p port --lib -- used_` | 4 passed / 0 failed | ✓ PASS |
| WR-04 cap-parse rejects | `cargo test -p port --lib -- caps` | 5 passed / 0 failed | ✓ PASS |
| #45 union-consult pins | `cargo test -p port --lib namec` | 6 passed / 0 failed | ✓ PASS |
| Commit/pin integrity | git: r9 origin/main = 8f3ff11; all 25 claimed SHAs exist; Harvey flake.lock r9 = 8f3ff11; pin commit 1c51844f2 = flake.lock-only | all hold | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| r9 host batteries (the phase's pin venue) | the two `cargo test` runs above | 124/124 + 76/76 | PASS |
| Boot gates (smoke/net-smoke/tier1/churn/stress) | qemu-boot composed gates, minutes each | Not re-run by the verifier (runtime cost); corroborated by retained captures on disk (`churn-r9.log` CATS-DONE 1400, `stress-r9.log` markers, smoke/tier1 logs) + committed machinery + the live host pins | ? SKIP (log-corroborated) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| FLUSH-01 | 17-01, 17-07 | Phase-8 CR classes closed with tests or explicitly dispositioned | ✗ PARTIAL → BLOCKED | CR-01..06 closed + pinned (verified live); CR-07/#66 open — the gap below. REQUIREMENTS.md honestly unchecked |
| FLUSH-02 | 17-01, 17-02 | RFMEM OOM leaks closed with refcount proofs (leak gates, bounded churn) | ✓ SATISFIED | Audit + ports + tiered gates green twice + #44 fixed; checked in REQUIREMENTS.md |
| FLUSH-03 | 17-03, 17-04 | Phase-7 WR hardening gaps closed (cap-walk, WaitSet sizing, used-id liveness) | ✓ SATISFIED | Code + live pins + ledger states (WR-01..06 fixed, 07/08 deferred 3-part, 5 IN open); checked |
| FLUSH-04 | 17-02, 17-05, 17-06, 17-07 | Known windows #44/#45 closed or gated; every fix pinned | ? NEEDS HUMAN (letter met) | #44/#45 fixed with pins (verified); every landed fix pinned; the phase's own authority left it unchecked tying completion to the CR-07/#66 open row — maintainer ratification requested |

No orphaned requirements: all four FLUSH IDs appear in plan frontmatter and map to Phase 17 in REQUIREMENTS.md.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| 08-REVIEW-DISPOSITION.md (WR-03 Source cell) | 34 | Stale prose: "the deterministic leak-gate verification has NOT run … do not read this row as closed until those gates green" — the gates greened twice in 17-02 but this ledger cell was never re-cited; the discharge lives only in FLUSHOUT/17-02-SUMMARY | ⚠️ Warning | Ledger-internal inconsistency (disposition=fixed vs stale warning prose); one-line Source update closes it |
| r9 x86_64/src/proc.rs (sys_brk_ regrowth), port/src/devip/conv.rs (conv_close sweep), accept-pool pop | per 17-REVIEW.md | The phase's own fresh code review found 3 warnings on the phase's changes (duplicate mapping_log records + stale semaphore PA key; unconditional pending-incall sweep reset; accept-pool member-socket leak on two error arms) | ⚠️ Warning | All 3 (plus 5 infos) dispositioned open in 17-REVIEW-DISPOSITION.md — new backlog recorded per convention, not phase must-haves; none regress a closed row's pin |
| WINDOWS #67/#68/#69 | ledger | New/persisting open windows recorded during the phase: rc userland malloc pool corruption under backquote churn (~428+ iters, repro committed); services dns-stage kernel trap (pre-existing, A/B-proven, blocks services-x64); tier1 date-check display quirk | ℹ️ Info | Outside the phase's 30-row FLUSHOUT scope; honestly ledgered with owners/reopeners |
| All modified rc/r9 source files | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers; no stub returns in the phase's diffs | — | Clean |

### Human Verification Required

With `gaps_found` as the leading status, these are escalation items for the maintainer, not blocking test requests:

1. **Ratify the CR-07 / WINDOWS #66 honest-open outcome (the central decision).** The phase deliberately refused both a false `fixed` and a `waived` on a live ~8%/run crash class. To accept investigated + hardened + reproducible-instrument as the phase outcome for this row, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "SC1/FLUSH-01 — the Phase-8 CR class 'multi-waiter RX-wake' (CR-07 / WINDOWS #66) is closed with tests or explicitly dispositioned with rationale"
    reason: "Accepted as investigated-to-the-capture-ceiling + hardened (r9 d4a5d38) + reproducible-at-will (boot-r9-stress-x64); the cure is a venue-conditional reopener per 17-CR07-ROOTCAUSE.md §7"
    accepted_by: "{name}"
    accepted_at: "{ISO timestamp}"
```

   Otherwise plan a cure pass (or a 3-part waiver) as gap-closure work — the instrument, the narrowing matrix, and the shape hatches are committed and ready.
2. **Ratify the FLUSH-04 checkbox.** The roadmap-SC letter (#44/#45 closed, all fixes pinned) is verified met; the phase left it unchecked under its stricter whole-ledger reading. Either outcome is defensible; REQUIREMENTS.md should reflect the decision.

### Gaps Summary

One root gap, honestly self-reported by the phase and confirmed by this verification against the code and evidence: **the multi-waiter RX-wake class (CR-07 / WINDOWS #66) is neither closed nor explicitly dispositioned.** The deregister hardening is real and pinned (wake 6/6 live), but the N=25 stress series at the fix pin failed at run 3 with the byte-consistent triple-fault signature — the plan's own D-03 bar correctly refutes the fix as the cure, and the record correctly refuses a waiver of a live crash class. Everything else the phase touched is closed with live-verified pins (CR-01..06, 08-WR-01..06, 07-WR-01..06, #18/#44/#45/#46/#47/#49/#65) or carries a 3-part disposition (07-WR-07/08, #50). The open row's reopener is venue-conditional and unassigned to any later roadmap phase (18 = auth, 19 = cpu/drawterm — neither owns the cure), so it is a real gap, not a deferral. Secondary (non-blocking): the stale WR-03 Source prose in the 08 ledger, and the three open code-review warnings from 17-REVIEW.md.

---

_Verified: 2026-11-13T07:11:20Z_
_Verifier: Claude (gsd-verifier)_
