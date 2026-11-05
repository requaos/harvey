---
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
verified: 2026-11-05T14:30:00Z
status: human_needed
score: 11/12 must-haves verified
covered_files:
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-01-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-03-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-04-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-06-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-07-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-08-PLAN.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-01-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-03-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-04-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-06-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-07-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-08-SUMMARY.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-EVIDENCE.md
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-03-tracer-donor.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-04-coverage-log.txt
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-04-generator-scan.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-04-generator-scan-teeth.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-05-tier0-wave-build.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-05-libtest-donor.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-05-tier1-gate-donor.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-06-tier1-build.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-06-tier1-donor.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-06-selfhost.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-07-trace.txt
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-07-tier1-r9.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-07-tier1-donor-reverify.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-08-gethunk-verify.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-08-generator-scan.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-08-coverage-log.txt
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/06-08-poolpanic-serial.log
  - .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/evidence/poolpanic-verdict.md
  - sys/src/cmd/cc/macbody
  - sys/src/cmd/6l/obj.c
  - sys/src/cmd/7l/asm.c
  - sys/src/cmd/rc/havefork.c
  - aarch64/include/u.h
  - sys/src/libdynld/dynld-aarch64.c
  - sys/src/libdraw/mkfile
  - sys/src/mkfile
  - sys/src/cmd/mkfile
  - sys/src/cmd/mkmany
  - sys/src/games/mkfile
  - sys/src/cmd/ip/mkfile
  - sys/src/cmd/auth/mkfile
  - sys/src/cmd/auth/factotum/mkfile
  - build/scripts/linux-build
  - build/aarch64/tiers/tier0-libs.txt
  - build/aarch64/tiers/tier1-cmds.txt
  - build/aarch64/markers/tier0.ledger
  - build/aarch64/markers/tier1.ledger
  - build/aarch64/subset-build.sh
  - build/aarch64/subset-exec.sh
  - build/aarch64/tier1-sweep.rc
  - build/aarch64/coverage-sweep.sh
  - build/aarch64/dir-coverage.txt
  - build/aarch64/generator-audit.txt
  - build/aarch64/generator-scan.sh
  - build/aarch64/gethunk-repro-cc.sh
  - build/aarch64/gethunk-repro-6l.sh
  - build/aarch64/tracesup.c
  - build/aarch64/tier1-r9.expect
  - nix/tier1-r9.sh
  - build/aarch64/ledger-r9-append.sh
  - build/aarch64/mkimage.sh
  - build/mm/boot-9k10cpu-qemu.sh
  - build/aarch64/tiny.y
  - build/aarch64/tiny.l
  - build/aarch64/tiny.mk
  - build/aarch64/tiny.s
  - build/aarch64/nm-input.7
  - build/aarch64/hello.c
  - flake.nix
  - flake.lock
  - .github/workflows/phase6.yml
  - build/harness/src/trace.rs
covered_digest: "v4:sha256:7d078d553e0d7cec38cfa17677127fe74ea2033520c1a8a0e9ad94cf08d84f96"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "First hosted run of .github/workflows/phase6.yml on push: confirm wave0-host, tier-r9, and x86_64-poolpanic legs green on ubuntu-latest; confirm the tier-donor leg's behavior"
    expected: "wave0-host / tier-r9 / x86_64-poolpanic green; tier-donor reds at the donor-pin precondition (`.build/9front-donor` absent on a clean runner) unless a native-linux donor-provisioning step lands first — this is CR-01 from 06-REVIEW.md, confirmed in this verification by reading the job (phase6.yml:127-152 has no donor clone/build step) against subset-exec.sh:174-177 (pin gate errors 'have missing'; requires $DIST/9qemu.u + $ROOTFS/arm64/bin)"
    why_human: "Hosted CI behavior cannot be verified without a push (the phase honestly records PENDING FIRST PUSH per the 05-13 precedent); the fix-vs-accept decision on CR-01 (wire a native donor build into the tier-donor job, or accept the red leg as the first-push tripwire) is a maintainer call"
  - test: "Host-class watch item: the committed dir-coverage.txt's venue line claims host-independence from a linux-aarch64 build host; the hosted wave0-host runner is linux-x86_64"
    expected: "coverage regen + `git diff --exit-code` green on linux-x86_64, or a flipped per-dir build row reds BY DESIGN and the report's re-baseline standing rule applies"
    why_human: "Requires the hosted linux-x86_64 runner to observe; disclosed in 06-EVIDENCE.md as an honest watch item"
---

# Phase 6: Full-Tree Userspace — Wave 0 + Libraries/Core Tiers Verification Report

**Phase Goal:** The mk build factory sweeps the full tree for aarch64 without structural aborts or silent hangs, gated by tiered append-only allowlists whose only truth is artifact+execution markers — tier-0 libraries and the core command/build-chain tier run green on the 9front donor kernel first, then on r9.
**Verified:** 2026-11-05T14:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | SC#1a — cc/macbody + 6l/obj.c gethunk accumulate-when-contiguous fixes in-tree with teeth-proven timeout-gated repro scripts (USPACE-01) | ✓ VERIFIED | `sys/src/cmd/cc/macbody:877` + `sys/src/cmd/6l/obj.c:1321` carry `if(h == hunk + nhunk)`; fix diffs tail-only additive (18+/2−, 20+/2−); repro scripts 259/361 lines with snapshot/archive/verify; committed `evidence/06-08-gethunk-verify.log` shows TEETH-OK 6c/7c/6l (ENOMEM terminus from archived PREREFs) + GREEN ×3 |
| 2 | SC#1b — v1.0-carryover 9k-amd64 "bad magic" pool panic re-tested against the pswt-fixed 6c with a recorded verdict (USPACE-10) | ✓ VERIFIED | `evidence/poolpanic-verdict.md` records `VERDICT=PASS no-panic-signature boot-continues`; committed `06-08-poolpanic-serial.log` shows the boot sailing past the 01-04 death point ("508M memory…" → `root is from (tcp)[tcp]:`) with zero `bad magic`/`panic`/`suicide` lines; harness teeth-proven (5 recorded classification-path runs incl. wrong-image real-qemu); exit-0-on-production contract in `build/mm/boot-9k10cpu-qemu.sh` (280 lines) |
| 3 | SC#1c — aarch64/include/u.h FPdbleword uint lo/hi + libc/fmt rebuilt (D-01) | ✓ VERIFIED | Spot-check ran the CI gate command: FPDBL-OK (exactly 2 uint members, zero ulong); libc rebuild recorded via SUBSET-BUILD-OK; float canary execution-asserted on BOTH kernels (`T1-OK float-d01` in the committed 06-06 donor log AND the 06-07 r9 log) |
| 4 | SC#2 — mk DIRS recursion demonstrably reaches every cmd dir; jpg/mahjongg/4a blockers fixed; committed dir-coverage report proves complete reach (USPACE-02) | ✓ VERIFIED | `build/aarch64/dir-coverage.txt` committed: universe 221 = 206 visited ∪ 15 named exclusions, reconciliation CLOSED; committed reach log 212 VISIT / 212 EXIT / 0 watchdog / 35 SECOND-CHANCE; `sys/src/games/mkfile:67` checkall:V: + `sys/src/cmd/mkfile:66,68` checkall over `$ALLDIRS` unfiltered; coverage-sweep.sh:379-429 gates jpg's host-ELF regeneration hard (errs non-zero otherwise); mahjongg/4a recorded build=ok with citations; 06-08 regen byte-identical (COVERAGE-DIFF-CLEAN) |
| 5 | SC#3 — cross-compiled-generator audit lists every build-then-run generator with host-toolchain proof; CI reds on any `.7`-magic generator artifact (USPACE-03) | ✓ VERIFIED | `generator-audit.txt`: exactly 9 `G<n> site=` rows + 16 `not-swept:` rows; `generator-scan.sh` carries the R_MAGIC (00008c47) RED + ELF/`#!` pass + 7.genarch whitelist; teeth-proven by synthetic plant (`evidence/06-04-generator-scan-teeth.log`: planted 7.rgbycc → RED + exit 1 → removed → re-green); wired into the wave0-host CI job |
| 6 | SC#4a — tiered append-only allowlist machinery live: per-dir append-only growth, never a flag-flip (USPACE-04) | ✓ VERIFIED | `tier0-libs.txt` (35 entries) + `tier1-cmds.txt` (62 entries); git numstat history: every commit +N/0 except one disclosed 2-line COMMENT edit in 5edf99e83 (stale "awaiting 06-06" note; zero entry removals ever); 5 objtype-gated mk filter sites (sys/src/mkfile:73-75, cmd/mkfile:32-33, ip, auth, auth/factotum) all with COVERAGE_SWEEP=1 disengagement branches; build_aarch64 grown to the filtered sweep (linux-build:79-81) |
| 7 | SC#4b — artifact+execution markers committed as the only gates (mk exit status never trusted) | ✓ VERIFIED | subset-build.sh emits T0-ART/T1-ART sha256 markers with artifact-presence asserts; subset-exec.sh asserts per-binary T1-OK presence + T1-DONE + zero T1-FAIL + zero panic\|trap: on the captured serial log (never mk exit codes); ledgers lint clean (LEDGER-FORMAT-OK, spot-check run); no PENDING line survives as any dir's latest (file-order last-line-wins audit) |
| 8 | SC#4c — per-tier execution gates on the 9front donor FIRST, then r9 via measure-first traces | ✓ VERIFIED | Donor-first ordering in committed logs: 06-03 (19 T1-OK) → 06-05 (21) → 06-06 (58 + canary 61) → r9 in 06-07 (37 T1-OK + 23 T1-SKIP + T1-DONE, zero FAIL/panic); measure-first: `evidence/06-07-trace.txt` (201 pids, 8581 entry fragments, 0 malformed) names the r9 dispatch delta as exactly {NSEC(53), RENDEZVOUS(34)}; r9 commits pushed to requaos/r9 main BEFORE pins; **flake.lock r9 rev `46a2ed2…` == r9 live HEAD == origin/main (verified against ../r9 directly)** |
| 9 | SC#5a — all 22 outstanding libraries compile fresh for aarch64 via mksyslib portable-C fallback; no cargo-culted stale .6/.8 (USPACE-05) | ✓ VERIFIED | `evidence/06-05-tier0-wave-build.log`: 35 × T0-ART + TIER-BUILD-OK; `.7`-only member listings in the log (e.g. libc.a `ar vu` line); D-07 fresh-archive `rm -f` rule + `$O`-suffixed OFILES make stale members structurally unreachable; libdynld `dynld-aarch64.c` rename present (2d2fa5725), dynld-arm64.c gone |
| 10 | SC#5b — every lib execution-classified honestly (D-06/D-08) | ✓ VERIFIED | tier0.ledger latest-per-dir (file-order): 13 CARRIED:tier1-consumer + libmach CARRIED:nm + 2 TEST:donor (libdraw, libdisk) + 1 TEST-FAIL:donor (libmemdraw, filed Phase-10 with fault evidence) + 2 EXCLUDED:no-consumer (libaml, libdynld) + 16 EXCLUDED:no-tier1-consumer = 35/35; no silent drops |
| 11 | SC#5c — shell/coreutils + guest build chain (7a/7c/7l/cc/cpp/mk/yacc/lex as aarch64 binaries) execute on the donor (USPACE-06) | ✓ VERIFIED | All 8 chain members in tier1-cmds.txt with per-tool fixed-input evidence (tiny.s/tiny.y/tiny.l/tiny.mk committed); `06-06-tier1-donor.log`: 58 × T1-OK + T1-DONE, zero FAIL/panic; `06-06-selfhost.log`: T1-OK 7a + T1-OK selfhost-compile + `T1-SELFHOST-OBS hello aarch64 harvey` + T1-OK selfhost (full-path D-11, no fallback); aarch64 binaries on disk carry R_MAGIC (478c0000 little-endian) |
| 12 | 06-08 plan truth — D-16: the full phase pipeline runs in CI on linux legs (wave0-host, tier-donor, tier-r9, x86_64-poolpanic) | ? UNCERTAIN | `.github/workflows/phase6.yml` (209 lines) encodes all four jobs; every action 40-char-SHA pinned (8/8 uses: lines); r9-shell.yml + harvey.yml untouched by any 06-scoped commit; wave0-host/tier-r9/poolpanic legs self-contained + locally validated (06-EVIDENCE.md matrix). **But CR-01 confirmed:** the tier-donor job (phase6.yml:127-152) has NO step that clones/builds the donor, while subset-exec.sh:174-177 hard-requires `.build/9front-donor` at pin 350266104f + `$DIST/9qemu.u` + `$ROOTFS/arm64/bin` — on a clean ubuntu-latest runner the leg reds in seconds at the pin gate. Hosted run is honestly PENDING FIRST PUSH. Artifact exists; provisioning wiring incomplete → WARNING, human decision |

**Score:** 11/12 truths verified (0 present-but-behavior-unverified; 1 UNCERTAIN → human)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `sys/src/cmd/cc/macbody` | gethunk accumulate fix | ✓ VERIFIED | `h == hunk + nhunk` at :877; 10L*NHUNK ladder + yyerror retained |
| `sys/src/cmd/6l/obj.c` | gethunk accumulate fix | ✓ VERIFIED | `h == hunk + nhunk` at :1321; 25L ladder + diag retained |
| `aarch64/include/u.h` | FPdbleword uint lo/hi | ✓ VERIFIED | region assert FPDBL-OK (spot-check run) |
| `build/aarch64/gethunk-repro-{cc,6l}.sh` | teeth-proven repro gates | ✓ VERIFIED | 259/361 lines; committed verify log TEETH-OK+GREEN |
| `build/aarch64/tiers/tier{0,1}-*.txt` | append-only allowlists | ✓ VERIFIED | 35 + 62 entries; pure-append git history |
| `build/aarch64/markers/tier{0,1}.ledger` | D-14 ledgers | ✓ VERIFIED | 72 + 154 lines; 8-field lint green; honest classifications |
| `build/aarch64/subset-{build,exec}.sh` + `tier1-sweep.rc` | tier gate stack | ✓ VERIFIED | marker-gated; 665-line sweep with venue parameter |
| `build/aarch64/dir-coverage.txt` + `coverage-sweep.sh` | reach proof (D-15) | ✓ VERIFIED | 221=206+15 CLOSED; CI regen+diff wired |
| `build/aarch64/generator-{audit.txt,scan.sh}` | USPACE-03 audit+red | ✓ VERIFIED | 9 G rows; teeth-proven scan |
| `build/aarch64/tracesup.c`, `tier1-r9.expect`, `nix/tier1-r9.sh`, `flake.nix` | r9 venue | ✓ VERIFIED | all present; boot-r9-tier1 app at flake.nix:146; R9_KERNEL_PKG contract wired |
| `build/mm/boot-9k10cpu-qemu.sh` + `evidence/poolpanic-verdict.md` | USPACE-10 verdict | ✓ VERIFIED | PASS recorded; teeth-proven classifier |
| `.github/workflows/phase6.yml` | 4-job phase CI | ⚠️ ORPHANED-LEG | 4 jobs, SHA-pinned, but tier-donor leg's donor provisioning absent (CR-01) — see Truth 12 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| sys/src/mkfile + cmd/mkfile | tiers/*.txt | `$HARVEY/build/aarch64/tiers` backquote keep-extraction | ✓ WIRED | filter lines present at 5 sites (WR-02: unguarded if HARVEY unset — latent, all drivers set it) |
| subset-build.sh | tier0-libs.txt | tier-0 fresh-archive loop + T0-ART | ✓ WIRED | :146-163; log shows 35/35 markers |
| subset-exec.sh | tier1-sweep.rc | staged termrc sources the sweep; host marker asserts | ✓ WIRED | :816-818 asserts T1-OK set computed from tier1-cmds.txt (WR-06: unanchored substring greps — bounded by zero-FAIL + T1-DONE asserts) |
| tier1.ledger | gate logs | evidence paths per line | ✓ WIRED | evidence files exist, committed, marker-consistent |
| phase6.yml | coverage-sweep.sh / generator-scan.sh / boot-9k10cpu-qemu.sh / flake.nix | wave0-host regen+diff, scan, poolpanic leg, boot-r9-tier1 | ✓ WIRED | 3 of 4 legs self-contained |
| phase6.yml tier-donor | donor provisioning | (missing) | ⚠️ PARTIAL | job invokes subset-exec.sh but nothing populates `.build/9front-donor`/`$DIST` on a clean runner (CR-01) |
| flake.lock | ../r9 | r9 pin | ✓ WIRED | locked rev 46a2ed2 == r9 live HEAD == origin/main (push-before-pin held) |

### Data-Flow Trace (Level 4)

The phase's dynamic-data surfaces are the committed marker artifacts. Traced: ledger sha256/commit fields reference real commits (spot-checked 7123bce9f, 9397b6823 — on master); evidence paths in ledger lines resolve to committed logs; the logs contain substantive kernel-boot + marker content (r9 log: 303KB with page-table dumps, per-pid page-in faults, 37 distinct T1-OK names); dir-coverage.txt's own regeneration was run in 06-08 and diffed clean against the committed copy. No static-fallback or disconnected chains found.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| FPdbleword uint lo/hi (CI gate command) | `sed -n '/^union FPdbleword/,/^};/p' aarch64/include/u.h` + uint/ulong count | FPDBL-OK (n=2, no ulong) | ✓ PASS |
| Grep-hygiene gate (CI command) | `grep -nE '/usr/bin/grep[[:space:]]+-' build/aarch64/*.sh` | GREP-HYGIENE-OK | ✓ PASS |
| Ledger 8-field grammar lint | awk NF!=8 over both ledgers | LEDGER-FORMAT-OK | ✓ PASS |
| Donor/r9 qemu gates, coverage sweep, gethunk repros | — | require lima VM / multi-minute runs; committed evidence logs verified instead (the phase's marker-as-truth evidence standard) | ? SKIP |
| mk -n amd64 parity probe | `objtype=amd64 mk -n libs` | mk not on host PATH (nix-develop-provided); structural passthrough verified by reading the filter code (`if not echo $ALLLIBS` at every site) | ? SKIP |

### Probe Execution

No `scripts/**/tests/probe-*.sh` exist and no plan declares probes — N/A.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| USPACE-01 | 06-01 | gethunk ×2 fixes with regression proof | ✓ SATISFIED | fixes in-tree; repro scripts + committed TEETH-OK/GREEN verify log |
| USPACE-02 | 06-04 | full-tree sweep reaches every cmd dir | ✓ SATISFIED | dir-coverage.txt 221=206+15 CLOSED; blockers gated in coverage-sweep.sh |
| USPACE-03 | 06-04 | generator audit + CI .7-magic red | ✓ SATISFIED | generator-audit.txt (9 G rows); scan teeth log; wave0-host wiring |
| USPACE-04 | 06-02/03/07 | tiered append-only allowlists + donor-first-then-r9 gates + marker truth | ✓ SATISFIED | tier files/ledgers append-only; donor logs then r9 log; trace-measured delta; pin==HEAD |
| USPACE-05 | 06-05 | 22 libs compile fresh via mksyslib fallback | ✓ SATISFIED | 35/35 T0-ART + TIER-BUILD-OK; .7-only members; honest ledger classes |
| USPACE-06 | 06-06/07 | core cmds + build chain compile + donor-execute | ✓ SATISFIED | 58 × T1-OK donor; selfhost canary observed output; 37 × T1-OK on r9 |
| USPACE-10 | 06-08 | 9k-amd64 pool-panic re-test with recorded verdict | ✓ SATISFIED | VERDICT=PASS no-panic-signature boot-continues; serial log committed; CI leg asserts production |

All 7 phase requirement IDs accounted for in REQUIREMENTS.md (mapped Phase 6, marked Complete). No orphaned requirements (no other IDs map to Phase 6).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (28 phase-modified files scanned) | — | TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER | — | zero hits — debt-marker gate clean |
| .github/workflows/phase6.yml | 127-152 | tier-donor leg lacks donor provisioning (CR-01, review-confirmed, re-confirmed here) | ⚠️ Warning | leg reds at pin gate on clean runner; goal-level gates unaffected (ran green locally with committed markers); human decision queued |
| sys/src/mkfile + 4 siblings | 68-75 et al. | unguarded $HARVEY in mk tier filters (WR-02, confirmed) | ⚠️ Warning | silent green no-op sweep if HARVEY unset; all in-tree drivers export it |
| build/aarch64/generator-scan.sh | 109 | `^G[0-9] site=` skips G10+ rows (WR-03, confirmed) | ⚠️ Warning | latent drift-tripwire hole; only G1-G9 exist today |
| build/aarch64/subset-exec.sh | 816-818 | unanchored `T1-OK $m` substring greps (WR-06, confirmed) | ⚠️ Warning | mk⊂mkdir / cp⊂cpp false-green class; bounded by zero-T1-FAIL + T1-DONE asserts |
| build/aarch64/ledger-r9-append.sh | 76 | bashism `< <()` under `#!/bin/sh` (WR-07, confirmed) | ⚠️ Warning | cannot re-run on CI's dash; the committed ledger proves its one needed run |
| 06-05-SUMMARY.md | prose | "62 → 22 remaining: rio, sam, acme, …" mismatches the committed artifact | ℹ️ Info | committed dir-coverage.txt is authoritative and internally consistent (58 → 19 build=fail dir rows; the named dirs all flipped build=ok at b7344296d); summary prose describes a stale intermediate state — favorable-miscount, nothing hidden |
| 06-EVIDENCE.md | 06-04 record | BLOCKER-CHECK lines live only in the gitignored driver log | ℹ️ Info | the committed reach logs carry VISIT/EXIT/SECOND-CHANCE; coverage-sweep.sh:429 hard-gates on the jpg host-ELF check, so the green exit implies the check passed; retention nit only |

### Human Verification Required

#### 1. First hosted run of phase6.yml (CR-01 disposition)

**Test:** Push master; watch `gh run list --workflow phase6.yml`. Confirm wave0-host, tier-r9, and x86_64-poolpanic legs green on ubuntu-latest; observe the tier-donor leg.
**Expected:** three legs green; tier-donor reds at the donor-pin precondition (`.build/9front-donor` absent) unless a native-linux donor-provisioning step lands first. CR-01 (confirmed here against phase6.yml:127-152 + subset-exec.sh:174-177) needs a maintainer decision: wire a native donor build/clone step into the tier-donor job, or accept the first-push red as the provisioning tripwire.
**Why human:** hosted CI behavior is unverifiable without a push (the phase honestly records PENDING FIRST PUSH per the 05-13 precedent); the fix-vs-accept call is a maintainer decision.

#### 2. Coverage report host-class watch item

**Test:** on the hosted linux-x86_64 wave0-host runner, the coverage regen + `git diff --exit-code` step.
**Expected:** green, or a flipped per-dir build row reds BY DESIGN (the committed report's venue is linux-aarch64); the report header's re-baseline standing rule then applies.
**Why human:** requires the hosted runner class to observe; disclosed in 06-EVIDENCE.md as an honest watch item.

### Gaps Summary

No goal-blocking gaps. All five ROADMAP success criteria are verified against committed code, data files, and marker evidence. The one CRITICAL code-review finding (CR-01) was re-confirmed against the committed workflow and judged **not goal-blocking**: the phase criteria govern the gates running green on the donor then r9 — proven by committed marker logs (58/61 T1-OK donor, 37+23 r9, float canary on both kernels, selfhost canary with observed output) — not hosted-CI greenness, which the phase honestly records as PENDING FIRST PUSH. CR-01 is carried as a WARNING with a human decision queued above. Eight open review warnings are latent-hygiene items confirmed real but non-blocking (WR-01's 6l/9l LP64 ieee class deserves the noted follow-up; it affects the amd64 host toolchain leg, outside this phase's aarch64 sweep truth).

---

_Verified: 2026-11-05T14:30:00Z_
_Verifier: the agent (gsd-verifier)_
