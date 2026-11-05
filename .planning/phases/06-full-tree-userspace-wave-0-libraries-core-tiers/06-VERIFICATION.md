---
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
verified: 2026-11-05T23:50:08Z
status: passed
score: 12/12 must-haves verified
covered_files:
  - .github/workflows/phase6.yml
  - .gitignore
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-01-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-01-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-03-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-03-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-04-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-04-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-06-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-06-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-07-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-07-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-08-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-08-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-09-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-09-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-10-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-10-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-EVIDENCE.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW-DISPOSITION.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW-FIX.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-SECURITY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-UAT.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-UI-REVIEW.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-09-tier-9k-local.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/poolpanic-verdict.md
  - aarch64/include/u.h
  - build/aarch64/coverage-sweep.sh
  - build/aarch64/dir-coverage.txt
  - build/aarch64/generator-audit.txt
  - build/aarch64/gethunk-repro-6l.sh
  - build/aarch64/gethunk-repro-cc.sh
  - build/aarch64/markers/tier0.ledger
  - build/aarch64/markers/tier1.ledger
  - build/aarch64/nsrun.sh
  - build/aarch64/subset-exec.sh
  - build/aarch64/tier1-sweep.rc
  - build/aarch64/tiers/tier0-libs.txt
  - build/aarch64/tiers/tier1-cmds.txt
  - build/mm/boot-9k10t1-sweep.sh
  - build/mm/build-9k10t1.sh
  - sys/src/9k/k10/k10t1
  - sys/src/9k/k10/l32p.s
  - sys/src/9k/k10/root/k10t1.rc
  - sys/src/9k/port/devroot.c
  - sys/src/cmd/6l/asm.c
  - sys/src/cmd/6l/obj.c
  - sys/src/cmd/cc/macbody

covered_digest: "v2:sha256:95142e716557413c4d51c1f87be90e745a15971c1e37c86aa2a2816444b6d70c"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 12/12
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 6: Full-Tree Userspace — Wave 0 + Libraries/Core Tiers Verification Report

**Phase Goal:** The mk build factory sweeps the full tree for aarch64 without structural aborts or silent hangs, gated by tiered append-only allowlists whose only truth is artifact+execution markers — tier-0 libraries and the core command/build-chain tier run green on the 9front donor kernel first, then on r9.
**Amended venue note (maintainer direction 2026-11-05, 06-UAT.md):** on amd64/x86_64 CI, donor evidence comes from Harvey's OWN kernel (9k10cpu lineage — the k10t1 venue built by 06-09, wired into phase6.yml by 06-10); 9front remains the aarch64 LOCAL donor only. This verification is against the amended split.
**Verified:** 2026-11-05T23:50:08Z
**Status:** passed
**Re-verification:** Yes — REGENERATION run (third). The prior report (status passed, 12/12) went stale when three covered files changed under its digest: the code-review `--fix` run landed `fix(06-review)` commits 984e62eb3 (WR-01: gethunk-repro-6l.sh reachable error handling under `set -e`) and 76ab66aa7 (WR-02: coverage-sweep.sh host `/bin/cpp` overwrite removed + nsrun.sh in-namespace cpp bind), and 3b8a37760 recorded both as `fixed` in the covered 06-REVIEW-DISPOSITION.md ledger. This run verified the fixes are harness-side robustness changes that disturb no verified truth, re-ran every cheap behavioral spot-check against the live tree, and recomputed the fingerprint via the gsd-tools verb.

## Regeneration Delta (what changed since the prior report, and what was re-checked)

| Change | Commit | Material? | Re-check performed |
|--------|--------|-----------|--------------------|
| WR-01 fix: `set +e … RC=$? … set -e` wrapper around the libc-provisioning `RUN_BUILD_IN_PRIVATE_NAMESPACE` call; named error (`error: libc namespace provisioning failed (rc=$RC)`, exit 2) + `rm -f "$NSLIBC"` cleanup now reachable | 984e62eb3 | Yes — error-path reachability in a covered gate script | Re-read THIS RUN: wrapper at gethunk-repro-6l.sh:280-285 mirrors the script's own verify-leg idiom (:295-298, :316-319) verbatim with the 3-line citing comment; `sh -n` + `bash -n` pass; script grew 415→421 lines (+6, matches the commit's 6 insertions); success path byte-identical (control-flow reachability only) |
| WR-02 fix: unconditional `sudo cp "$HARVEY_LINUX_BIN/cpp" /bin/cpp` DELETED from coverage-sweep.sh (hard early error on missing hostbin cpp kept); nsrun.sh gained a conditional in-namespace cpp bind | 76ab66aa7 | Yes — host-mutation discipline restored in two covered/now-covered harness scripts | Re-read THIS RUN: coverage-sweep.sh diff vs pre-fix is exactly ONE hunk (`@@ -394,13 +394,12 @@`) confined to the host-side provisioning block; nsrun.sh:107-121 adds the cpp bind immediately after the established `/bin/rc` bind (:103-105), mirroring it exactly, gated on `[ -n "${HARVEY_LINUX_BIN:-}" ] && [ -x "$HARVEY_LINUX_BIN/cpp" ]`; `sh -n`/`bash -n` pass on all three scripts; grep confirms ZERO residual host `cp … /bin/cpp` in either script |
| 06-REVIEW-DISPOSITION.md rewritten: WR-01/WR-02 → `fixed` (Source: 06-REVIEW-FIX.md); open: 14 → 12, total: 15 | 3b8a37760 | Yes — covered ledger changed | Frontmatter + table re-read THIS RUN: both rows `fixed`; CR-01 stays `fixed` with the retirement reason intact; open 12 = 6 info + 6 warning (WR-03..WR-08), internally consistent |
| 06-REVIEW-FIX.md created (fix record: 2 in scope / 2 fixed / 0 skipped, status all_fixed) | 522c99454 | Yes — new phase artifact | Read in full; fix descriptions match the committed diffs line-for-line (verified above); added to covered_files |
| 06-UI-REVIEW.md created (verdict: NO UI SURFACE IN THIS PHASE, with file-census evidence) | bcbe0bbdb | No — null-verdict gate doc | Read; census consistent with the phase's actual file mix (C/sh/rc/ledger/yml, zero web surface); added to covered_files |
| Planning-root bookkeeping (ROADMAP complete-phase edits, STATE, PROJECT evolution) | 0acb41079, 0b01eb25e | No — planning-root docs, inert to the digest | Confirmed via `git show --stat`: neither commit touches any covered path |
| Prior VERIFICATION.md digest repair (the report's own covered_digest line) | f9d0b4f33 | No — self-referential metadata | N/A — this report replaces that file wholesale |

**Definitive staleness enumeration:** `git log --oneline f9d0b4f33..HEAD` over all 49 prior covered paths returns exactly three commits — 3b8a37760, 76ab66aa7, 984e62eb3. No other covered file moved. `build/aarch64/nsrun.sh` changed under 76ab66aa7 but was not previously covered; it is now added to covered_files as a phase-changed impl file (52 paths total).

**Coverage-report byte-stability claim — VERIFIED.** `git diff 9795e2d1c..HEAD -- build/aarch64/dir-coverage.txt` is non-empty but is ENTIRELY commit 0d7c1f537 (`fix(06-10): dir-coverage venue line discloses host-class count jitter`) — the 06-10 venue-wording + count-jitter disclosure the prior report already verified (VENUE-BLOCK-IDENTICAL at that time). Neither fix commit touches dir-coverage.txt, and the coverage-sweep.sh fix hunk stops 9 lines before the report-generation section (heredoc at :404+ untouched; venue-block emission shifted :570-579 → :569-578 by the net -1 line, content unchanged). Byte-identity between the generator emission (coverage-sweep.sh:569-578) and the committed report (:20-29) was RE-DIFFED THIS RUN → VENUE-BLOCK-IDENTICAL.

**No Phase-6 source drift.** Working-tree status over the phase source surface shows only untracked local-build products (6.out/7.out/cc.a6/cc.a7 — the pre-existing ℹ️ Info local-namespace-build dirt class) and untracked 06-PATTERNS.md (not a covered file). Every tracked covered file is clean.

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | SC#1a — cc/macbody + 6l/obj.c gethunk accumulate fixes in-tree with regression repros (USPACE-01) | ✓ VERIFIED | Regression re-checked THIS RUN: `sys/src/cmd/cc/macbody:877` + `sys/src/cmd/6l/obj.c:1321` both carry `if(h == hunk + nhunk)`; repro scripts on disk (259 / 421 lines — the 6l script +6 from the WR-01 fix, parse-clean); committed `evidence/06-08-gethunk-verify.log` TEETH-OK/GREEN (initial verification) |
| 2 | SC#1b — 9k-amd64 pool panic re-tested with recorded verdict (USPACE-10) | ✓ VERIFIED | `evidence/poolpanic-verdict.md` (114 lines, re-confirmed on disk this run): VERDICT contract + teeth matrix (4 classification paths incl. wrong-image real-qemu); `VERDICT=PASS no-panic-signature boot-continues` against the pswt-fixed 6c; k10cpu re-proven at runtime again during 06-09 |
| 3 | SC#1c — aarch64/include/u.h FPdbleword uint lo/hi (D-01) | ✓ VERIFIED | Re-ran this run with a correctly-scoped awk over the `union FPdbleword { ... };` body: exactly 2 uint members (lo, hi), 0 ulong → FPDBL-OK |
| 4 | SC#2 — mk DIRS recursion reaches every cmd dir; committed coverage report (USPACE-02) | ✓ VERIFIED | `dir-coverage.txt` (unchanged since the prior verification — 0d7c1f537 predates it): universe 221 = 206 visited ∪ 15 exclusions; venue block byte-identity between generator emission (coverage-sweep.sh:569-578 post-fix) and committed report (:20-29) re-diffed THIS RUN → VENUE-BLOCK-IDENTICAL |
| 5 | SC#3 — generator audit + CI .7-magic red (USPACE-03) | ✓ VERIFIED | `generator-audit.txt` (52 lines) + `generator-scan.sh` teeth log committed; scan wired into wave0-host (phase6.yml) |
| 6 | SC#4a — tiered append-only allowlists (USPACE-04) | ✓ VERIFIED | Re-run this run: tier0-libs.txt 35 entries / tier1-cmds.txt 62 entries; git numstat over full history — tier0 pure-append (0 deletions ever); tier1's only deletion-commit is the disclosed 2 COMMENT lines in 5edf99e83 (52+/2- numstat row) — zero entry removals ever |
| 7 | SC#4b — artifact+execution markers as the only gates | ✓ VERIFIED | Ledger lint re-run THIS RUN with the correct grammar (skip `#` comments/blanks, entries = 8 space-separated k=v fields): LEDGER-FORMAT-OK over both ledgers (tier0 72 lines / tier1 154 lines); marker-gated subset-build/subset-exec stack intact |
| 8 | SC#4c — per-tier execution gates, donor FIRST then r9, via measure-first traces (amended: + Harvey-kernel x86_64 venue) | ✓ VERIFIED | Initial-verification donor→r9 ordering intact (06-03→06-07 committed logs). AMENDED VENUE: census re-run THIS RUN over `evidence/06-09-tier-9k-local.log`: 36 × T1-OK + 24 × T1-SKIP + 1 × T1-DONE, ZERO T1-FAIL and ZERO panic/trap/bad-magic lines; r9 parity proven (06-07: rc=0 + rc -x trace byte-parity) |
| 9 | SC#5a — 22 outstanding libs compile fresh via mksyslib fallback (USPACE-05) | ✓ VERIFIED | Initial verification (35 × T0-ART + TIER-BUILD-OK, .7-only members); tier0-libs.txt regression-checked intact (35 entries) |
| 10 | SC#5b — every lib execution-classified honestly | ✓ VERIFIED | tier0.ledger intact (72 lines, lint-clean this run); honest classifications incl. libmemdraw TEST-FAIL filed Phase-10 |
| 11 | SC#5c — shell/coreutils + guest build chain execute on the donor (USPACE-06) | ✓ VERIFIED | tier1-cmds.txt intact (62 entries); committed 06-06 donor log (58 × T1-OK + selfhost canary observed output) + 06-07 r9 log + 06-09 Harvey-kernel log (36 × T1-OK) |
| 12 | D-16 amended — the full phase pipeline runs in CI on linux legs, x86_64 tier venue = Harvey's own kernel | ✓ VERIFIED | STRUCTURE (re-run this run): yaml parses; job set exactly {wave0-host, tier-9k, tier-r9, x86_64-poolpanic} JOBS-OK; PINS-OK 11/11 40-char SHAs; venue-pin replays 0/0/1; every tier-9k referenced path exists + executable; the job self-provisions ALL preconditions in-job. HOSTED BEHAVIOR: CLOSED by the maintainer's UAT PASS (06-UAT.md Test 1, 2026-11-05) — all four legs green on ubuntu-latest, tier-9k's first hosted run included |

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

### Required Artifacts (06-09/06-10 gap-closure layer + the review-fix layer; earlier-layer artifacts re-verified in the initial pass and regression-checked above)

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `sys/src/9k/k10/k10t1` | venue kernel config | ✓ VERIFIED | 246 lines; dev/uart/ip/link/misc/dbgflg/amd64/port/dir/lib sections byte-IDENTICAL to k10cpu (10/10 section diff, prior run; file untouched since — staleness enumeration this run); rootdir carries exactly 43 embed entries |
| `sys/src/9k/k10/root/k10t1.rc` | embedded /boot/boot rc script | ✓ VERIFIED | 52 lines; first line exactly `#!/boot/rc -m /boot/rcmain`; path-first + binds + RTC clock + hostowner + child-rc sweep + infinite console block (untouched since prior verify) |
| `sys/src/9k/port/devroot.c` | Nbootfiles 32→64 | ✓ VERIFIED | `Nbootfiles = 64` at :14 with the 06-09 comment; additive-only (untouched since prior verify) |
| `build/mm/build-9k10t1.sh` | namespace build driver | ✓ VERIFIED | 203 lines, executable; nuke sandwich + `embedded root files: 43` assert + git-clean gate; darwin→lima dispatch (untouched since prior verify) |
| `build/mm/boot-9k10t1-sweep.sh` | boot + marker harness with teeth | ✓ VERIFIED | 375 lines, executable; T1_CLASSIFY_ONLY hook; expected set computed from tier1-cmds.txt; 24-name SKIP whitelist with converse assert; boundary-anchored T1-OK regex; T1-VENUE-PASS print; teeth recorded (untouched since prior verify) |
| `build/aarch64/tier1-sweep.rc` | 9k venue arm | ✓ VERIFIED | venue-9k blocks; $rcm rcmain override; libtest SKIP pair via block-local fn keeping r9's literal-SKIP extraction at 23 (untouched since prior verify) |
| `sys/src/cmd/6l/asm.c` | LP64 double-constant fix | ✓ VERIFIED | `fhw[0]=p->to.ieee.l; fhw[1]=p->to.ieee.h` two-int emit at :315-317 (re-checked this run); commit 778d4616b |
| `sys/src/9k/k10/l32p.s` | early KZERO map 0–8MiB | ✓ VERIFIED | header comment + 06-09 note; the +[6,8)MiB PDE (untouched since prior verify) |
| `.gitignore` | k10t1.c / systab.c / .tier1-stage | ✓ VERIFIED | entries at :78/:82/:84 (untouched since prior verify) |
| `evidence/06-09-tier-9k-local.log` | retained local serial log | ✓ VERIFIED | census re-run this run: 36 OK / 24 SKIP / 1 DONE / 0 FAIL / 0 panic-class lines |
| `.github/workflows/phase6.yml` | 4-job CI, tier-donor retired + pinned | ✓ VERIFIED | JOBS-OK exact set (re-run); PINS-OK 11/11 (re-run); venue-pin replays 0/0/1 (re-run); tier-9k job fully self-provisioned with step-summary digests + `if: always()` log upload; hosted run green (UAT Test 1) |
| `build/aarch64/coverage-sweep.sh` | host-jitter venue wording + WR-02 fix | ✓ VERIFIED | venue block byte-identical to committed report (diff re-run this run → VENUE-BLOCK-IDENTICAL); WR-02 fix re-read this run: single hunk at :394, `sudo cp` gone, hard error kept, nsrun bind documented in the comment block |
| `build/aarch64/nsrun.sh` | shared namespace entry + WR-02 cpp bind | ✓ VERIFIED | NEWLY COVERED this run (changed by 76ab66aa7): cpp bind at :107-121 mirrors the /bin/rc bind exactly, conditional on executable `$HARVEY_LINUX_BIN/cpp` with a `set -u`-safe `${HARVEY_LINUX_BIN:-}` guard; `bash -n` clean; zero residual host cpp mutation |
| `build/aarch64/gethunk-repro-6l.sh` | 6l regression repro + WR-01 fix | ✓ VERIFIED | 421 lines (+6 from the fix); set+e/RC/set-e wrapper at :280-285 makes the named error + NSLIBC cleanup reachable; mirrors the script's own verify-leg idiom; `sh -n`/`bash -n` clean; success path byte-identical |
| `build/aarch64/subset-exec.sh` | venue-split header | ✓ VERIFIED | VENUE SPLIT note at :11-17; stale "06-08's CI job owns the native donor build" hint ABSENT (untouched since prior verify) |
| `06-REVIEW-DISPOSITION.md` | CR-01 fixed; WR-01/WR-02 fixed | ✓ VERIFIED | Re-written by 3b8a37760 after the fix run; re-read this run: WR-01 + WR-02 `fixed` (Source: 06-REVIEW-FIX.md), CR-01 `fixed` with the retirement reason; open: 12 / total: 15 (6 info + WR-03..WR-08) |
| `06-REVIEW-FIX.md` | fix record, status all_fixed | ✓ VERIFIED | NEW since the prior report; read in full this run: 2 in scope / 2 fixed / 0 skipped; both fix descriptions match the committed diffs line-for-line; added to covered_files |
| `06-SECURITY.md` | threat register closed | ✓ VERIFIED | 25/25 register rows `closed` at L1, threats_open: 0, status verified, audit trail + sign-off present; no accepted risks (untouched since prior verify) |
| `06-UI-REVIEW.md` | UI gate verdict | ✓ VERIFIED | NEW since the prior report (bcbe0bbdb): verdict NO UI SURFACE IN THIS PHASE with a file-census evidence table consistent with the phase's realized diff; honest null verdict, no fabricated pillar scores; added to covered_files |
| `06-UAT.md` | human items resolved | ✓ VERIFIED | Test 1 result: pass (maintainer-confirmed 2026-11-05, all four hosted legs green); summary 1 passed / 0 issues; G-06-1 status resolved (untouched since prior verify) |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| phase6.yml tier-9k job | build/mm/build-9k10t1.sh + boot-9k10t1-sweep.sh | `nix develop -c sh` run lines | ✓ WIRED | both scripts exist, executable, substantive (203/375 lines); phase6.yml untouched since prior verify |
| tier-9k job preconditions | nix setup/toolchain/build | in-job provisioning + artifact asserts | ✓ WIRED | TOOLCHAIN-PRODUCTS-OK assert loop + amd64/9k10cpu.elf+bin/rc+bin/awk assert with BUILD-SWALLOWED-FAIL digest |
| venue-pin step ↔ workflow content | anchored job-key greps + donor-script ERE | ✓ WIRED | re-run this run: `^  tier-donor:` = 0, `subset-(build\|exec)\.sh` = 0, `^  tier-9k:` = 1 |
| k10t1 rootdir (43 entries) | build-9k10t1.sh staging → devroot.c Nbootfiles=64 | `.tier1-stage` dual-name copies + embed-count assert | ✓ WIRED | 43 ≤ 64; count asserted from generated k10t1.c inside the namespace |
| boot harness expected set | tiers/tier1-cmds.txt | subset-exec.sh awk mapping, MINUS stacksmoke PLUS float-d01 | ✓ WIRED | D-13 data is the single source; no second hardcoded list |
| tier1-sweep.rc 9k arm | $rcm / libtest SKIP helper | venue token `9k` | ✓ WIRED | r9 extraction venue-correctness proven (literal SKIP lines back to exactly r9's 23) |
| UAT pass record → Truth 12 | 06-UAT.md Test 1 ↔ phase6.yml four legs | maintainer-confirmed hosted green 2026-11-05 | ✓ WIRED | the human item's evidence chain is recorded in the phase dir; G-06-1 reconciled status resolved |
| coverage-sweep.sh native leg → nsrun.sh cpp provisioning (WR-02) | coverage-sweep.sh:405 `--wrap` invocation → nsrun.sh:118-121 conditional bind | ✓ WIRED | NEW LINK this run: the deleted host `sudo cp` is replaced by the in-namespace bind on the shared entry point BOTH venue legs use (native `--wrap` at :405; darwin→lima via vm-run.sh); hard early error at :402 keeps the missing-cpp case a loud failure |

### Data-Flow Trace (Level 4)

The phase's dynamic-data surfaces are committed marker artifacts + the retained venue log + the CI run record. Traced: the 06-09 log's commit field resolves in git log; the harness's result/print vocabulary matches the log's census (36/24/1, re-counted this run); dir-coverage.txt's venue block is byte-identical to the generator's emission post-fix (re-diffed this run, :569-578 ↔ :20-29); ledger sha256/commit fields spot-checked on master in the initial pass; the hosted-green claim traces to the maintainer's UAT record (06-UAT.md), not to a SUMMARY assertion. The WR-02 fix changes WHERE cpp comes from (host cp → in-namespace bind) but not any emitted byte — the report-generation path (:404+) is untouched by the single fix hunk. No static-fallback or disconnected chains found.

### Behavioral Spot-Checks (all re-run THIS verification)

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| phase6.yml parses; exact 4-job set | python3 yaml.safe_load + set assert | jobs = {tier-9k, tier-r9, wave0-host, x86_64-poolpanic} → JOBS-OK | ✓ PASS |
| Venue-pin replays | `grep -cE '^  tier-donor:'` / `subset-(build\|exec)\.sh` / `^  tier-9k:'` phase6.yml | 0 / 0 / 1 | ✓ PASS |
| Action pins | `uses:` 40-char-SHA regex over all 11 | PINS-OK 11/11 | ✓ PASS |
| Ledger grammar lint | awk 8-field k=v grammar (comments/blanks skipped) over both ledgers | LEDGER-FORMAT-OK (72 / 154 lines) | ✓ PASS |
| FPdbleword region assert | awk-scoped union body uint/ulong count | 2 uint / 0 ulong → FPDBL-OK | ✓ PASS |
| Venue log census | grep -c over 06-09-tier-9k-local.log | 36 OK / 24 SKIP / 1 DONE / 0 FAIL / 0 panic-class | ✓ PASS |
| Venue blocks byte-identical (post-fix) | diff coverage-sweep.sh:569-578 vs dir-coverage.txt:20-29 | empty diff → VENUE-BLOCK-IDENTICAL | ✓ PASS |
| Tier append-only history | git numstat over both tier files | tier0 pure-append (0 deletion-commits); tier1 exactly 1 deletion-commit = the disclosed 2 comment lines (52+/2-, 5edf99e83); entry counts 35/62 | ✓ PASS |
| gethunk fixes + 6l LP64 fix presence | sed line checks | macbody:877 + obj.c:1321 `if(h == hunk + nhunk)`; asm.c:315-317 two-int emit | ✓ PASS |
| WR-01 fix shape | re-read gethunk-repro-6l.sh:276-298 | set+e/RC/set-e wrapper mirrors the verify-leg idiom; named error + cleanup reachable; sh -n + bash -n clean | ✓ PASS |
| WR-02 fix shape + no residual host mutation | diff hunk count; grep `sudo cp`/`cp … /bin/cpp` over both scripts | exactly 1 hunk (`@@ -394,13 +394,12 @@`); zero residual host cpp overwrite; nsrun.sh bind conditional + guarded; all parse checks clean | ✓ PASS |
| dir-coverage.txt byte-stability claim | `git diff 9795e2d1c..HEAD -- build/aarch64/dir-coverage.txt` | entirely 0d7c1f537 (06-10's disclosed venue-jitter wording + 5 count rows); neither fix commit touches the report | ✓ PASS |
| Debt-marker gate | TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER scan over the three fixed scripts | zero real hits (the 3 XXX hits are mktemp `XXXXXX` templates — the same false-positive class as ed's `eXXXXX`, not markers) | ✓ PASS |
| Staleness enumeration over the covered set | `git log f9d0b4f33..HEAD -- <49 prior covered paths>` | exactly 3 commits: 984e62eb3, 76ab66aa7, 3b8a37760 — no other covered file moved | ✓ PASS |
| Venue boot / sweep execution | — | requires lima VM multi-minute qemu run; committed retained log + recorded local green + hosted green UAT stand as the marker-as-truth evidence; the WR-01/WR-02 fixes are linux-venue harness changes whose exercising gate is CI/lima (REVIEW-FIX.md verification venue note) | ? SKIP |
| tier-9k hosted run | — | DONE by the maintainer — UAT Test 1 PASS (all four legs green) | ✓ PASS (human) |

### Probe Execution

No `scripts/**/tests/probe-*.sh` exist and no plan declares probes — N/A.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| USPACE-01 | 06-01 | gethunk ×2 fixes with regression proof | ✓ SATISFIED | fixes in-tree (re-checked this run); repro scripts + committed TEETH-OK/GREEN log; WR-01 fix improves the 6l repro's error path without touching its teeth or success path |
| USPACE-02 | 06-04, 06-10 | full-tree sweep reaches every cmd dir; coverage report | ✓ SATISFIED | dir-coverage.txt 221=206+15; venue wording truthful under both linux host classes (byte-identical generator/report re-diffed POST-FIX); WR-02 fix provably does not alter emitted report bytes (single hunk ends before :404) |
| USPACE-03 | 06-04 | generator audit + CI .7-magic red | ✓ SATISFIED | generator-audit.txt; teeth log; wave0-host wiring |
| USPACE-04 | 06-02/03/07/09/10 | tiered append-only allowlists + donor-first-then-r9 gates + marker truth + amended venue split | ✓ SATISFIED | tier files pure-append (numstat re-run); ledgers lint-clean (re-run); donor→r9 committed logs; Harvey-kernel x86_64 venue locally green with teeth AND hosted green (UAT); retirement CI-asserted (venue-pin 0/0/1 re-run) |
| USPACE-05 | 06-05 | 22 libs compile fresh via mksyslib fallback | ✓ SATISFIED | 35/35 T0-ART; .7-only members; honest ledger classes |
| USPACE-06 | 06-06/07/09 | core cmds + build chain compile + donor-execute | ✓ SATISFIED | 58 × T1-OK donor; selfhost canary observed output; 37 × T1-OK r9; 36 × T1-OK on Harvey's own kernel |
| USPACE-10 | 06-08 | 9k-amd64 pool-panic re-test with recorded verdict | ✓ SATISFIED | VERDICT=PASS recorded; teeth-proven classifier; CI leg asserts production and is hosted-green (UAT) |

All 7 phase requirement IDs accounted for in REQUIREMENTS.md (each mapped Phase 6, marked Complete). No orphaned requirements (no other IDs map to Phase 6; USPACE-07/08/09 map to Phase 10 as expected).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (three fixed scripts re-scanned THIS RUN) | — | TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER | — | zero real hits — debt-marker gate clean (the 3 `XXX` hits are mktemp `XXXXXX` random-suffix templates, not markers) |
| sys/src/9k/port/devroot.c | 154-157 | pre-existing debug `panic("whoops")` remnant (IN-06) | ℹ️ Info | unreachable for well-formed qids; pre-existing upstream leftover in a file this phase touched; disposition-recorded open (12-of-15 ledger confirmed this run) |
| ~~build/aarch64/gethunk-repro-6l.sh~~ | ~~276-279~~ | ~~libc-provisioning error handling dead under `set -e` (WR-01)~~ | ✅ FIXED | 984e62eb3: set+e/RC/set-e wrapper at :280-285; named error + cleanup now reachable; disposition `fixed` in the reconciled ledger |
| ~~build/aarch64/coverage-sweep.sh~~ | ~~399-403~~ | ~~unconditional host /bin/cpp overwrite outside the namespace (WR-02)~~ | ✅ FIXED | 76ab66aa7: host `sudo cp` deleted (hard early error kept); nsrun.sh:118-121 provisions cpp via in-namespace bind on the shared entry both venue legs use; zero host mutation; disposition `fixed` in the reconciled ledger |
| working tree | sys/src/cmd/** | local full-tree build dirt: untracked 6.out/7.out/cc.a6/cc.a7 products | ℹ️ Info | produced by local namespace builds (they bind-mount the host tree); CI gates run from clean checkouts and are hosted-green (UAT Test 1); nothing in the phase's committed artifact set is dirty (staleness enumeration this run) |
| (open warnings WR-03..WR-08) | — | latent hygiene (G10+ audit-row selector, tracesup bounds, dead mkimage line, unanchored greps on the DONOR gate, sh/bashism in ledger-r9-append, gethunk staleness key) | ⚠️ Warning | all disposition-recorded open in the reconciled ledger (open: 12 / total: 15, re-read this run); the 9k venue harness already implements WR-06's boundary-anchored shape; non-blocking |

### Human Verification Required

**None.** The single historical human item — the first hosted run of the rewritten phase6.yml — was PASSED by the maintainer on 2026-11-05 (06-UAT.md Test 1, result: pass; G-06-1 resolved) and remains closed. The WR-01/WR-02 fixes are harness-side robustness changes to linux-venue scripts whose exercising gate is CI/lima (per REVIEW-FIX.md's verification-venue note); they alter no marker semantics, no report bytes, and no truth's evidence chain — static + diff-scope verification here is sufficient. The human verification section is empty, so `passed` is the correct status per the decision tree.

### Gaps Summary

**No gaps.** All five ROADMAP success criteria and all 7 requirement IDs remain verified after the review-fix delta. The delta since the prior (stale) report is exactly three commits touching the covered set — the two `fix(06-review)` commits and the disposition-ledger reconciliation — plus two new phase gate docs (REVIEW-FIX, UI-REVIEW) and inert planning-root bookkeeping. Both fixes were re-read line-by-line and diff-scoped: WR-01 is control-flow reachability only (success path byte-identical); WR-02 is a single hunk that provably cannot alter emitted report bytes, with the cpp bind provisioned on nsrun.sh's shared namespace entry. The coverage report itself is unchanged since 06-10's disclosed venue-jitter wording (0d7c1f537, pre-dating the prior verification). Open review warnings (12 of 15: 6 info + WR-03..WR-08) are latent-hygiene items, disposition-recorded, non-blocking; the deferred-items register is filed to Phase 10 and the ROADMAP backlog (Phase 999.1).

---

_Verified: 2026-11-05T23:50:08Z_
_Verifier: the agent (gsd-verifier)_
