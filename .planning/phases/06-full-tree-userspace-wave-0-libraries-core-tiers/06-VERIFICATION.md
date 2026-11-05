---
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
verified: 2026-11-05T23:35:00Z
status: passed
score: 12/12 must-haves verified
covered_files:
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-01-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-03-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-04-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-06-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-07-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-08-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-09-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-10-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-01-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-03-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-04-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-06-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-07-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-08-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-09-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-10-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-EVIDENCE.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-UAT.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW-DISPOSITION.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-SECURITY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-09-tier-9k-local.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/poolpanic-verdict.md
  - sys/src/9k/k10/k10t1
  - sys/src/9k/k10/root/k10t1.rc
  - sys/src/9k/port/devroot.c
  - sys/src/9k/k10/l32p.s
  - sys/src/cmd/6l/asm.c
  - sys/src/cmd/cc/macbody
  - sys/src/cmd/6l/obj.c
  - build/mm/build-9k10t1.sh
  - build/mm/boot-9k10t1-sweep.sh
  - build/aarch64/tier1-sweep.rc
  - build/aarch64/tiers/tier0-libs.txt
  - build/aarch64/tiers/tier1-cmds.txt
  - build/aarch64/markers/tier0.ledger
  - build/aarch64/markers/tier1.ledger
  - build/aarch64/dir-coverage.txt
  - build/aarch64/coverage-sweep.sh
  - build/aarch64/generator-audit.txt
  - build/aarch64/subset-exec.sh
  - build/aarch64/gethunk-repro-cc.sh
  - build/aarch64/gethunk-repro-6l.sh
  - .github/workflows/phase6.yml
  - .gitignore
  - aarch64/include/u.h
covered_digest: "v4:sha256:db72faf5f976fb0fdcb4fa7de8042b6c13ba3934f2557769ec9c8d854159792c"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 11/12
  gaps_closed:
    - "Truth 12's residual human item (first hosted run of the rewritten phase6.yml, tier-9k leg on a clean ubuntu-latest runner): PASSED by the maintainer 2026-11-05 — all four legs (wave0-host, tier-9k, tier-r9, x86_64-poolpanic) green on the hosted run (06-UAT.md Test 1, result: pass; G-06-1 reconciled status: resolved)"
  gaps_remaining: []
  regressions: []
---

# Phase 6: Full-Tree Userspace — Wave 0 + Libraries/Core Tiers Verification Report

**Phase Goal:** The mk build factory sweeps the full tree for aarch64 without structural aborts or silent hangs, gated by tiered append-only allowlists whose only truth is artifact+execution markers — tier-0 libraries and the core command/build-chain tier run green on the 9front donor kernel first, then on r9.
**Amended venue note (maintainer direction 2026-11-05, 06-UAT.md):** on amd64/x86_64 CI, donor evidence comes from Harvey's OWN kernel (9k10cpu lineage — the k10t1 venue built by 06-09, wired into phase6.yml by 06-10); 9front remains the aarch64 LOCAL donor only. This verification is against the amended split.
**Verified:** 2026-11-05T23:35:00Z
**Status:** passed
**Re-verification:** Yes — REGENERATION run. The prior re-verification (status human_needed, 11/12 + 1 human item) went stale when covered planning artifacts changed after it was written. This run re-checked the delta, re-ran every cheap behavioral spot-check against the live tree, and upgrades Truth 12 to VERIFIED on the maintainer's recorded UAT PASS.

## Regeneration Delta (what changed since the prior report, and what was re-checked)

| Change | Commit | Material? | Re-check performed |
|--------|--------|-----------|--------------------|
| 06-UAT.md: Test 1 marked PASS (all four hosted legs green); G-06-1 resolved | 8958863b9 | Yes — closes the only human item | UAT record read; consistent with 06-10-SUMMARY's D3 human_judgment item; Truth 12 upgraded to ✓ VERIFIED |
| 06-SECURITY.md created (25/25 register threats closed at L1, threats_open: 0, status verified) | 3fc938d30 | Yes — new phase artifact | Read in full; register internally consistent (25 rows all `closed`, audit trail + sign-off present); added to covered_files |
| ROADMAP.md gained ## Backlog with Phase 999.1 (legacy harvey.yml nix rebuild — deferred, out of phase scope) | d79132ace | No — backlog scheduling | Verified the backlog entry names itself pre-existing/unrelated to Phase 6; phase-6 success criteria untouched |
| 06-REVIEW-DISPOSITION.md rewritten by the gate's ledger reconciliation (14 of 15 open; CR-01 stays resolved-by-retirement) | 61e993039 | No — ledger shape change, same dispositions | Frontmatter re-read: open: 14, total: 15, CR-01 `fixed` with the retirement reason in both the YAML entry and the table row |
| Phase 08-04 concurrent work: build/aarch64/root-tree/lib/netip-loopback.rc + 08-04 planning docs | 391fb79f8, acb3362c1 | No — different phase's scope, not a Phase-6 covered file | `git diff --name-only` over the phase-6 source surface (sys/src, build/mm, build/aarch64 tier machinery, .github, aarch64/include) since the prior verify cycle: only netip-loopback.rc, which no Phase-6 artifact or gate consumes |

**No Phase-6 source drift.** Every committed change since the prior verification is either a .planning/ doc or Phase 8's own concurrent work. The working-tree tracked modifications (regenerated generator outputs — enam.c, eqn.c, ycbcr.h, devpost.add C1-3, troff fonts, rc/bin bits) are the pre-existing local-namespace-build dirt class already recorded as ℹ️ Info in the anti-patterns table; nothing in the phase's committed artifact set is dirty.

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | SC#1a — cc/macbody + 6l/obj.c gethunk accumulate fixes in-tree with regression repros (USPACE-01) | ✓ VERIFIED | Regression re-checked THIS RUN: `sys/src/cmd/cc/macbody:877` + `sys/src/cmd/6l/obj.c:1321` both carry `if(h == hunk + nhunk)`; repro scripts on disk (259 / 415 lines); committed `evidence/06-08-gethunk-verify.log` TEETH-OK/GREEN (initial verification) |
| 2 | SC#1b — 9k-amd64 pool panic re-tested with recorded verdict (USPACE-10) | ✓ VERIFIED | `evidence/poolpanic-verdict.md` (114 lines, re-confirmed on disk this run): VERDICT contract + teeth matrix (4 classification paths incl. wrong-image real-qemu); `VERDICT=PASS no-panic-signature boot-continues` against the pswt-fixed 6c; k10cpu re-proven at runtime again during 06-09 |
| 3 | SC#1c — aarch64/include/u.h FPdbleword uint lo/hi (D-01) | ✓ VERIFIED | Re-ran this run with a correctly-scoped awk over the `union FPdbleword { ... };` body: exactly 2 uint members (lo, hi), 0 ulong → FPDBL-OK |
| 4 | SC#2 — mk DIRS recursion reaches every cmd dir; committed coverage report (USPACE-02) | ✓ VERIFIED | `dir-coverage.txt` (303 lines): universe 221 = 206 visited ∪ 15 exclusions; venue block byte-identity between generator emission (coverage-sweep.sh:570-579) and committed report (:20-29) re-diffed THIS RUN → VENUE-BLOCK-IDENTICAL |
| 5 | SC#3 — generator audit + CI .7-magic red (USPACE-03) | ✓ VERIFIED | `generator-audit.txt` (52 lines) + `generator-scan.sh` teeth log committed; scan wired into wave0-host (phase6.yml) |
| 6 | SC#4a — tiered append-only allowlists (USPACE-04) | ✓ VERIFIED | Re-run this run: tier0-libs.txt 35 entries / tier1-cmds.txt 62 entries; git numstat over full history — tier0 pure-append (0 deletions ever); tier1's only deletion is the disclosed 2 COMMENT lines in 5edf99e83 — zero entry removals ever |
| 7 | SC#4b — artifact+execution markers as the only gates | ✓ VERIFIED | Ledger lint re-run THIS RUN with the correct grammar (skip `#` comments/blanks, entries = 8 space-separated k=v fields): LEDGER-FORMAT-OK over both ledgers (tier0 72 lines / tier1 154 lines); marker-gated subset-build/subset-exec stack intact |
| 8 | SC#4c — per-tier execution gates, donor FIRST then r9, via measure-first traces (amended: + Harvey-kernel x86_64 venue) | ✓ VERIFIED | Initial-verification donor→r9 ordering intact (06-03→06-07 committed logs). AMENDED VENUE: census re-run THIS RUN over `evidence/06-09-tier-9k-local.log`: 36 × T1-OK + 24 × T1-SKIP + 1 × T1-DONE, ZERO T1-FAIL and ZERO panic/trap/bad-magic lines; r9 parity proven (06-07: rc=0 + rc -x trace byte-parity) |
| 9 | SC#5a — 22 outstanding libs compile fresh via mksyslib fallback (USPACE-05) | ✓ VERIFIED | Initial verification (35 × T0-ART + TIER-BUILD-OK, .7-only members); tier0-libs.txt regression-checked intact (35 entries) |
| 10 | SC#5b — every lib execution-classified honestly | ✓ VERIFIED | tier0.ledger intact (72 lines, lint-clean this run); honest classifications incl. libmemdraw TEST-FAIL filed Phase-10 |
| 11 | SC#5c — shell/coreutils + guest build chain execute on the donor (USPACE-06) | ✓ VERIFIED | tier1-cmds.txt intact (62 entries); committed 06-06 donor log (58 × T1-OK + selfhost canary observed output) + 06-07 r9 log + 06-09 Harvey-kernel log (36 × T1-OK) |
| 12 | D-16 amended — the full phase pipeline runs in CI on linux legs, x86_64 tier venue = Harvey's own kernel | ✓ VERIFIED | STRUCTURE (re-run this run): yaml parses; job set exactly {wave0-host, tier-9k, tier-r9, x86_64-poolpanic} JOBS-OK; PINS-OK 11/11 40-char SHAs; venue-pin replays 0/0/1; every tier-9k referenced path exists + executable; the job self-provisions ALL preconditions in-job. HOSTED BEHAVIOR: the prior report's single UNCERTAIN residual is now CLOSED by the maintainer's UAT PASS (06-UAT.md Test 1, 2026-11-05) — all four legs green on ubuntu-latest, tier-9k's first hosted run included |

**Score:** 12/12 truths verified (Truth 12 verified via the recorded human UAT pass; 0 present-behavior-unverified)

### Deferred Items

Items discovered during execution, recorded in `deferred-items.md`, explicitly filed to later milestone phases — not gaps against this phase's goal.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | libmemdraw drawtest/arctest aarch64 faults (Pitfall-3 LP64 class) | Phase 10 | deferred-items.md: "Phase 10's libmemdraw pixel-path LP64/struct-punning audit owns this"; ROADMAP Phase 10 covers the GUI stack tiers |
| 2 | rc argv-stack residual drain sites beyond Xbackq (live under load per the 06-09 sharpening) | Phase 10 | deferred-items.md: "A Phase-10 per-dir audit item: audit rc's pushlist/poplist balance across every op" |
| 3 | Stale mkfile test targets (liboventi vttest.c, libmemdraw test.c) + libdynld unsigned-compare note | Phase 10 | deferred-items.md: "Phase 10 decides: remove the targets or restore the sources" |
| 4 | 6l/8l/5l… LP64 double-constant audit sweep for dormant arch letters (the 6l consumer WAS fixed in 06-09, commit 778d4616b) | Phase 10 / on-consumer-appearance | deferred-items.md: "Fix when an amd64/386 consumer appears… the dormant-arch letters should be audited at the same time" |
| 5 | plan9port mk missing-intermediate tolerance; darwin sbrk 4MB cap; macexpand >16KB | procedural/platform facts | deferred-items.md: documented iteration rules and venue constraints, no tree change |
| 6 | Legacy harvey.yml nix rebuild (red streak pre-dates Phase 6, recorded since 2026-11-04T12:01Z) | ROADMAP Backlog Phase 999.1 | 06-UAT.md Deferred Follow-Ups; ROADMAP.md ## Backlog (d79132ace) — explicitly "pre-existing/unrelated to Phase 6" |

### Required Artifacts (06-09/06-10 gap-closure layer; earlier-layer artifacts re-verified in the initial pass and regression-checked above)

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `sys/src/9k/k10/k10t1` | venue kernel config | ✓ VERIFIED | 246 lines; dev/uart/ip/link/misc/dbgflg/amd64/port/dir/lib sections byte-IDENTICAL to k10cpu — 10/10 section diff RE-RUN THIS RUN (SECTIONS-IDENTICAL); rootdir carries exactly 43 embed entries |
| `sys/src/9k/k10/root/k10t1.rc` | embedded /boot/boot rc script | ✓ VERIFIED | 52 lines; first line exactly `#!/boot/rc -m /boot/rcmain` (re-checked); path-first + binds + RTC clock + hostowner + child-rc sweep + infinite console block |
| `sys/src/9k/port/devroot.c` | Nbootfiles 32→64 | ✓ VERIFIED | `Nbootfiles = 64` at :14 with the 06-09 comment (re-checked); additive-only |
| `build/mm/build-9k10t1.sh` | namespace build driver | ✓ VERIFIED | 203 lines, executable; nuke sandwich + `embedded root files: 43` assert + git-clean gate; darwin→lima dispatch |
| `build/mm/boot-9k10t1-sweep.sh` | boot + marker harness with teeth | ✓ VERIFIED | 375 lines, executable; T1_CLASSIFY_ONLY hook; expected set computed from tier1-cmds.txt; 24-name SKIP whitelist with converse assert; boundary-anchored T1-OK regex; T1-VENUE-PASS print; teeth recorded |
| `build/aarch64/tier1-sweep.rc` | 9k venue arm | ✓ VERIFIED | venue-9k blocks; $rcm rcmain override; libtest SKIP pair via block-local fn keeping r9's literal-SKIP extraction at 23 |
| `sys/src/cmd/6l/asm.c` | LP64 double-constant fix | ✓ VERIFIED | `fhw[0]=p->to.ieee.l; fhw[1]=p->to.ieee.h` two-int emit at :315-317 (re-checked this run); commit 778d4616b |
| `sys/src/9k/k10/l32p.s` | early KZERO map 0–8MiB | ✓ VERIFIED | header comment + 06-09 note; the +[6,8)MiB PDE |
| `.gitignore` | k10t1.c / systab.c / .tier1-stage | ✓ VERIFIED | entries at :78/:82/:84 (re-checked this run) |
| `evidence/06-09-tier-9k-local.log` | retained local serial log | ✓ VERIFIED | census re-run this run: 36 OK / 24 SKIP / 1 DONE / 0 FAIL / 0 panic-class lines |
| `.github/workflows/phase6.yml` | 4-job CI, tier-donor retired + pinned | ✓ VERIFIED | JOBS-OK exact set (re-run); PINS-OK 11/11 (re-run); venue-pin replays 0/0/1 (re-run); tier-9k job :248-341 fully self-provisioned with step-summary digests + `if: always()` log upload; hosted run green (UAT Test 1) |
| `build/aarch64/{coverage-sweep.sh,dir-coverage.txt}` | host-jitter venue wording | ✓ VERIFIED | venue blocks byte-identical (diff re-run this run → VENUE-BLOCK-IDENTICAL) |
| `build/aarch64/subset-exec.sh` | venue-split header | ✓ VERIFIED | VENUE SPLIT note at :11-17 (re-checked); stale "06-08's CI job owns the native donor build" hint ABSENT (grep = 0, re-run) |
| `06-REVIEW-DISPOSITION.md` | CR-01 fixed | ✓ VERIFIED | Rewritten by the gate's ledger reconciliation after the prior report; re-read this run: CR-01 `fixed` with the retirement reason in both the YAML entry and the table row; open: 14 / total: 15 |
| `06-SECURITY.md` | threat register closed | ✓ VERIFIED | NEW since the prior report; read in full this run: 25/25 register rows `closed` at L1, threats_open: 0, status verified, audit trail + sign-off present; no accepted risks |
| `06-UAT.md` | human items resolved | ✓ VERIFIED | Test 1 result: pass (maintainer-confirmed 2026-11-05, all four hosted legs green); summary 1 passed / 0 issues; G-06-1 status resolved |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| phase6.yml tier-9k job | build/mm/build-9k10t1.sh + boot-9k10t1-sweep.sh | `nix develop -c sh` run lines (:314, :325) | ✓ WIRED | both scripts exist, executable, substantive (203/375 lines) — re-checked this run |
| tier-9k job preconditions | nix setup/toolchain/build | in-job provisioning + artifact asserts | ✓ WIRED | TOOLCHAIN-PRODUCTS-OK assert loop + amd64/9k10cpu.elf+bin/rc+bin/awk assert with BUILD-SWALLOWED-FAIL digest (job body re-read this run) |
| venue-pin step ↔ workflow content | anchored job-key greps + donor-script ERE | ✓ WIRED | re-run this run: `^  tier-donor:` = 0, `subset-(build\|exec)\.sh` = 0, `^  tier-9k:` = 1 |
| k10t1 rootdir (43 entries) | build-9k10t1.sh staging → devroot.c Nbootfiles=64 | `.tier1-stage` dual-name copies + embed-count assert | ✓ WIRED | 43 ≤ 64; count asserted from generated k10t1.c inside the namespace |
| boot harness expected set | tiers/tier1-cmds.txt | subset-exec.sh awk mapping, MINUS stacksmoke PLUS float-d01 | ✓ WIRED | D-13 data is the single source; no second hardcoded list |
| tier1-sweep.rc 9k arm | $rcm / libtest SKIP helper | venue token `9k` | ✓ WIRED | r9 extraction venue-correctness proven (literal SKIP lines back to exactly r9's 23) |
| UAT pass record → Truth 12 | 06-UAT.md Test 1 ↔ phase6.yml four legs | maintainer-confirmed hosted green 2026-11-05 | ✓ WIRED | the human item's evidence chain is recorded in the phase dir; G-06-1 reconciled status resolved |

### Data-Flow Trace (Level 4)

The phase's dynamic-data surfaces are committed marker artifacts + the retained venue log + the CI run record. Traced: the 06-09 log's commit field (f2543ec8e) resolves in git log; the harness's result/print vocabulary matches the log's census (36/24/1, re-counted this run); dir-coverage.txt's venue block is byte-identical to the generator's emission (re-diffed this run); ledger sha256/commit fields spot-checked on master in the initial pass; the hosted-green claim traces to the maintainer's UAT record (06-UAT.md), not to a SUMMARY assertion. No static-fallback or disconnected chains found.

### Behavioral Spot-Checks (all re-run THIS verification)

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| phase6.yml parses; exact 4-job set | python3 yaml.safe_load + set assert | jobs = {tier-9k, tier-r9, wave0-host, x86_64-poolpanic} → JOBS-OK | ✓ PASS |
| Venue-pin replays | `grep -cE '^  tier-donor:'` / `subset-(build\|exec)\.sh` / `^  tier-9k:'` phase6.yml | 0 / 0 / 1 | ✓ PASS |
| Action pins | `uses:` 40-char-SHA regex over all 11 | PINS-OK 11/11 | ✓ PASS |
| Ledger grammar lint | awk 8-field k=v grammar (comments/blanks skipped) over both ledgers | LEDGER-FORMAT-OK | ✓ PASS |
| FPdbleword region assert | awk-scoped union body uint/ulong count | 2 uint / 0 ulong → FPDBL-OK | ✓ PASS |
| k10cpu↔k10t1 shared-section identity | python section extraction + compare, 10 sections | 10/10 IDENTICAL | ✓ PASS |
| Venue log census | grep -c over 06-09-tier-9k-local.log | 36 OK / 24 SKIP / 1 DONE / 0 FAIL / 0 panic-class | ✓ PASS |
| Venue blocks byte-identical | diff generator emission vs committed report | empty diff → VENUE-BLOCK-IDENTICAL | ✓ PASS |
| Tier append-only history | git numstat over both tier files | tier0 pure-append; tier1 only the disclosed 2 comment-line deletion (5edf99e83) | ✓ PASS |
| gethunk fixes + 6l LP64 fix presence | sed line checks | macbody:877 + obj.c:1321 `if(h == hunk + nhunk)`; asm.c:315-317 two-int emit | ✓ PASS |
| Debt-marker gate | TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER scan over 16 phase-touched files | zero real hits (AXXX = 6l opcode; eXXXXX = ed mktemp template) | ✓ PASS |
| No Phase-6 source drift since prior verify | git diff --name-only over the phase source surface | only Phase-8's netip-loopback.rc (out of scope) | ✓ PASS |
| Venue boot / sweep execution | — | requires lima VM multi-minute qemu run; committed retained log + recorded local green at f2543ec8e + hosted green UAT stand as the marker-as-truth evidence | ? SKIP |
| tier-9k hosted run | — | DONE by the maintainer — UAT Test 1 PASS (all four legs green); no longer pending | ✓ PASS (human) |

### Probe Execution

No `scripts/**/tests/probe-*.sh` exist and no plan declares probes — N/A.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| USPACE-01 | 06-01 | gethunk ×2 fixes with regression proof | ✓ SATISFIED | fixes in-tree (re-checked this run); repro scripts + committed TEETH-OK/GREEN log |
| USPACE-02 | 06-04, 06-10 | full-tree sweep reaches every cmd dir; coverage report | ✓ SATISFIED | dir-coverage.txt 221=206+15; venue wording truthful under both linux host classes (byte-identical generator/report, re-diffed) |
| USPACE-03 | 06-04 | generator audit + CI .7-magic red | ✓ SATISFIED | generator-audit.txt; teeth log; wave0-host wiring |
| USPACE-04 | 06-02/03/07/09/10 | tiered append-only allowlists + donor-first-then-r9 gates + marker truth + amended venue split | ✓ SATISFIED | tier files pure-append (numstat re-run); ledgers lint-clean (re-run); donor→r9 committed logs; Harvey-kernel x86_64 venue locally green with teeth AND hosted green (UAT); retirement CI-asserted (venue-pin 0/0/1 re-run) |
| USPACE-05 | 06-05 | 22 libs compile fresh via mksyslib fallback | ✓ SATISFIED | 35/35 T0-ART; .7-only members; honest ledger classes |
| USPACE-06 | 06-06/07/09 | core cmds + build chain compile + donor-execute | ✓ SATISFIED | 58 × T1-OK donor; selfhost canary observed output; 37 × T1-OK r9; 36 × T1-OK on Harvey's own kernel |
| USPACE-10 | 06-08 | 9k-amd64 pool-panic re-test with recorded verdict | ✓ SATISFIED | VERDICT=PASS recorded; teeth-proven classifier; CI leg asserts production and is hosted-green (UAT) |

All 7 phase requirement IDs accounted for in REQUIREMENTS.md (lines 121-127, 179: each mapped Phase 6, marked Complete). No orphaned requirements (no other IDs map to Phase 6; USPACE-07/08/09 map to Phase 10 as expected).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (16 phase-touched files re-scanned THIS RUN) | — | TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER | — | zero real hits — debt-marker gate clean (the `AXXX` hit is a 6l opcode constant; the `eXXXXX` hits are ed's mktemp template named in a comment, not markers) |
| sys/src/9k/port/devroot.c | 154-157 | pre-existing debug `panic("whoops")` remnant (IN-06) | ℹ️ Info | unreachable for well-formed qids; pre-existing upstream leftover in a file this phase touched; disposition-recorded open (14-of-15 ledger confirmed this run) |
| build/aarch64/gethunk-repro-6l.sh | 276-279 | libc-provisioning error handling dead under `set -e` (WR-01) | ⚠️ Warning | gate still reds correctly (set -e propagates); named message/cleanup unreachable; disposition-recorded open |
| build/aarch64/coverage-sweep.sh | 399-403 | unconditional host /bin/cpp overwrite outside the namespace (WR-02) | ⚠️ Warning | host-mutation discipline break vs nsrun.sh's bind-mount pattern; disposition-recorded open |
| working tree | sys/src/cmd/** | local full-tree build dirt: untracked 6.out/7.out products + regenerated committed generator outputs (enam.c, eqn.c, ycbcr.h, devpost.add C1-3, troff fonts, rc/bin) | ℹ️ Info | produced by local namespace builds (they bind-mount the host tree); CI gates run from clean checkouts and are hosted-green (UAT Test 1); the regenerated-generator drift is the pre-existing USPACE-03 documented class, not a phase-6 regression; nothing in the phase's committed artifact set is dirty |
| (prior warnings WR-03..WR-08) | — | latent hygiene (G10+ audit-row selector, tracesup bounds, dead mkimage line, unanchored greps on the DONOR gate, sh/bashism in ledger-r9-append, gethunk staleness key) | ⚠️ Warning | all disposition-recorded open in the reconciled ledger (re-read this run); the 9k venue harness already implements WR-06's boundary-anchored shape; non-blocking |

### Human Verification Required

**None.** The prior report's single human item — the first hosted run of the rewritten phase6.yml (tier-9k leg on a clean ubuntu-latest runner) — was PASSED by the maintainer on 2026-11-05: all four legs (wave0-host, tier-9k, tier-r9, x86_64-poolpanic) green (06-UAT.md Test 1, result: pass; G-06-1 reconciled status: resolved). The human verification section is empty, so `passed` is the correct status per the decision tree.

### Gaps Summary

**No gaps.** All five ROADMAP success criteria and all 7 requirement IDs are verified against committed code, data files, marker evidence, and the maintainer's recorded hosted-run pass. The delta since the prior (stale) report is docs/metadata-only for Phase 6 — UAT completion, the security register, the backlog deferral, and the review-ledger reconciliation — plus one out-of-scope Phase 8 source commit; no Phase-6 source drift exists. Open review warnings (14 of 15 in the reconciled ledger) are latent-hygiene items, disposition-recorded, confirmed real but non-blocking; the deferred-items register is filed to Phase 10 and the ROADMAP backlog (Phase 999.1).

---

_Verified: 2026-11-05T23:35:00Z_
_Verifier: the agent (gsd-verifier)_
