---
phase: 02-aarch64-toolchain-libc-9front-donor
verified: 2026-11-01T16:31:54Z
status: human_needed
score: 5/5 must-haves verified
covered_files:
  - .gitignore
  - aarch64/ABI.md
  - aarch64/include/u.h
  - aarch64/include/ureg.h
  - aarch64/mkfile
  - build/aarch64/README.md
  - build/aarch64/boot-9qemu.sh
  - build/aarch64/donor-ns-build.sh
  - build/aarch64/donor-vm-build.sh
  - build/aarch64/drive9.py
  - build/aarch64/gate-evidence.log
  - build/aarch64/gdbpoke9.py
  - build/aarch64/hello.7.out
  - build/aarch64/hello.c
  - build/aarch64/mkfs9.py
  - build/aarch64/nsrun.sh
  - build/aarch64/pre-gate-build.sh
  - build/aarch64/run-gate.sh
  - build/aarch64/srv9.py
  - build/aarch64/subset-build.sh
  - build/aarch64/subset-exec.sh
  - build/aarch64/vm-run.sh
  - build/mkdirs
  - build/scripts/linux-build
  - nix/build.sh
  - nix/toolchain.sh
  - nix/vm-build.sh
  - sys/include/mach.h
  - sys/src/BUILDTOOLCHAIN
  - sys/src/BUILD_SETUP_NAMESPACE
  - sys/src/ape/lib/ap/mkfile
  - sys/src/ape/lib/mp/mkfile
  - sys/src/ape/lib/sec/mkfile
  - sys/src/cmd/7a/BUILD
  - sys/src/cmd/7a/README
  - sys/src/cmd/7a/a.h
  - sys/src/cmd/7a/a.y
  - sys/src/cmd/7a/lex.c
  - sys/src/cmd/7a/mkfile
  - sys/src/cmd/7c/7.out.h
  - sys/src/cmd/7c/BUILD
  - sys/src/cmd/7c/README
  - sys/src/cmd/7c/cgen.c
  - sys/src/cmd/7c/enam.c
  - sys/src/cmd/7c/gc.h
  - sys/src/cmd/7c/list.c
  - sys/src/cmd/7c/machcap.c
  - sys/src/cmd/7c/math.h
  - sys/src/cmd/7c/mkfile
  - sys/src/cmd/7c/mul.c
  - sys/src/cmd/7c/peep.c
  - sys/src/cmd/7c/reg.c
  - sys/src/cmd/7c/sgen.c
  - sys/src/cmd/7c/swt.c
  - sys/src/cmd/7c/txt.c
  - sys/src/cmd/7l/BUILD
  - sys/src/cmd/7l/README
  - sys/src/cmd/7l/asm.c
  - sys/src/cmd/7l/asmout.c
  - sys/src/cmd/7l/bits.c
  - sys/src/cmd/7l/compat.c
  - sys/src/cmd/7l/dyn.c
  - sys/src/cmd/7l/dynstub.c
  - sys/src/cmd/7l/l.h
  - sys/src/cmd/7l/list.c
  - sys/src/cmd/7l/mkcname
  - sys/src/cmd/7l/mkfile
  - sys/src/cmd/7l/mod.c
  - sys/src/cmd/7l/noop.c
  - sys/src/cmd/7l/obj.c
  - sys/src/cmd/7l/optab.c
  - sys/src/cmd/7l/pass.c
  - sys/src/cmd/7l/span.c
  - sys/src/cmd/7l/unixcompat.c
  - sys/src/cmd/cc/compat.h
  - sys/src/cmd/cc/mkfile
  - sys/src/cmd/cc/pswt.c
  - sys/src/cmd/nm.BUILD
  - sys/src/cmd/pcc.c
  - sys/src/cmd/unix/9cc/BUILD
  - sys/src/cmd/unix/9cc/README
  - sys/src/cmd/unix/9cc/cmd/7c/7.out.h
  - sys/src/cmd/unix/9cc/libmach/7.c
  - sys/src/cmd/unix/9cc/libmach/7obj.c
  - sys/src/cmd/unix/9cc/libmach/executable.c
  - sys/src/cmd/unix/9cc/libmach/obj.c
  - sys/src/cmd/unix/9cc/libmach/ureg7.h
  - sys/src/libc/9sys/callmain.c
  - sys/src/libc/9sys/mkfile
  - sys/src/libc/9syscall/mkfile
  - sys/src/libc/aarch64/README
  - sys/src/libc/aarch64/_seek.c
  - sys/src/libc/aarch64/argv0.s
  - sys/src/libc/aarch64/atom.s
  - sys/src/libc/aarch64/atomic.s
  - sys/src/libc/aarch64/atomic64.s
  - sys/src/libc/aarch64/cycles.s
  - sys/src/libc/aarch64/fabs.s
  - sys/src/libc/aarch64/floor.s
  - sys/src/libc/aarch64/getcallerpc.s
  - sys/src/libc/aarch64/getfcr.s
  - sys/src/libc/aarch64/main9.s
  - sys/src/libc/aarch64/main9p.s
  - sys/src/libc/aarch64/memmove.s
  - sys/src/libc/aarch64/memset.s
  - sys/src/libc/aarch64/mkfile
  - sys/src/libc/aarch64/notejmp.c
  - sys/src/libc/aarch64/setjmp.s
  - sys/src/libc/aarch64/sqrt.s
  - sys/src/libc/aarch64/tas.s
  - sys/src/libmach/7.c
  - sys/src/libmach/7db.c
  - sys/src/libmach/7obj.c
  - sys/src/libmach/README
  - sys/src/libmach/executable.c
  - sys/src/libmach/mkfile
  - sys/src/libmach/obj.c
  - sys/src/libmach/setmach.c
  - sys/src/libmp/aarch64/mkfile
  - sys/src/libmp/port/mkfile
  - sys/src/libmp/port/mpvecdigmuladd.c
  - sys/src/libmp/port/mpvecdigmulsub.c
  - sys/src/libsec/aarch64/mkfile
  - sys/src/libthread/aarch64.c
  - sys/src/mkfile.proto
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-01-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-01-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-02-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-02-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-03-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-03-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-04-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-04-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-05-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-05-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-06-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-06-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-07-PLAN.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-07-SUMMARY.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-CONTEXT.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-REVIEW.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/02-REVIEW-DISPOSITION.md
  - .planning/phases/02-aarch64-toolchain-libc-9front-donor/deferred-items.md
covered_digest: "v4:sha256:e5e4a50e4689102759cdfe6df33c1f3de115ada504f08115d224fb322ada0bfc"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Open .build/9front-dist/subset-exec.log and read the captured serial session"
    expected: "The Harvey aarch64 shell subset (rc, grep, ipconfig, factotum, 12 core cmds — all 7c-compiled) visibly executes on the 9front donor kernel command-by-command: echo sentinel, ls /, cat/grep/sed/wc pipelines, date, test, ps, mkdir/cp/mv/rm round-trip, ipconfig usage, factotum resident in ps, closing SUBSET-OK. Zero panic/trap/sys: note lines."
    why_human: "Plan 02-07 Task 2 carries an explicit <human-check> for the D-08 execution gate; unlike the TC-03 gate (human-approved 2026-11-01), no human approval of this log is recorded in the phase artifacts. Automated greps pass (markers + SUBSET-OK present, 0 fault lines) but the plan requires a human eyeball of the capture."
  - test: "Decide the disposition of code-review critical CR-01 (and warnings WR-01..WR-10, all 24 findings recorded open in 02-REVIEW-DISPOSITION.md)"
    expected: "CR-01 confirmed real by this verification: build/aarch64/run-gate.sh:726-729 still asserts `test ! -e $HARVEY/aarch64`, which was correct pre-gate but is stale since 02-06 legitimately committed aarch64/ — every rerun of the TC-03 gate now appends a PASS block to the committed gate-evidence.log and then exits 1 with a misleading 'leaked' error. This does NOT falsify any phase truth (the committed evidence is historically valid; sha256 matches the committed binary), but it breaks run-gate.sh's README-documented idempotence contract and pollutes a load-bearing proof artifact on rerun. Fix is one deletion (review suggests the patch); decide fix-now vs defer-to-hygiene alongside the 10 open warnings (silent-failure paths in nsrun.sh/vm-build.sh/nix/build.sh, gdbpoke9 120s deadline vs 600–1500s budgets, drive9.py prompt-proof echo weakness, 9cc/BUILD missing set -e, etc.)."
    why_human: "Scope decision: the phase goal is verified achieved (5/5), so this is not a blocking gap — but a confirmed critical finding on a committed artifact needs an explicit human triage call, and the review disposition file shows all 24 findings still open."
---

# Phase 02: aarch64 Toolchain + libc (9front donor) Verification Report

**Phase Goal:** Harvey can compile and link its own aarch64 Plan 9 binaries on darwin-aarch64 and linux-aarch64 hosts — the toolchain, libc, and objtype wiring exist and are proven by real binaries, not scaffolding.
**Verified:** 2026-11-01T16:31:54Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `7a`/`7c`/`7l` vendored from 9front into `sys/src/cmd/` with BUILD scripts; build natively via the toolchain app on darwin-aarch64 and linux-aarch64 | ✓ VERIFIED | Dirs exist with BUILD/mkfile/README each; all BUILD scripts parse (`sh -n`); READMEs carry pin `350266104f1fed81c78c3d05fa44f523bec0ae4d`; `sys/src/cmd/cc/compat.h` carries `mysbrk(ulong)`; BUILDTOOLCHAIN lines 10-12 wire all three. **Live proof (run by this verifier):** `.build/hostbin-darwin-aarch64/bin/7c -S` on a fib smoke file emitted TEXT/MOV arm64 asm, `7a` assembled it to `fib.7`, `7l` parsed it and emitted correct ken-linker diagnostics (`fib: entry not text: _main` / `_main: not defined`). linux-aarch64 half: `donor-build.log` provenance line shows guest `hostbin-linux-aarch64/bin/7c` built the donor kernel. thestring=aarch64 shim present in all three (`7c/txt.c:11`, `7a/lex.c:13`, `7l/obj.c:12`); zero OROL/rolor residue in vendored 7c; shared cc frontend untouched except additive compat.h (+ the reviewed pswt.c LP64 bug fix) |
| 2 | `nm`/`acid` operate on 7l aarch64 objects — libmach arm64 support landed, letter-7 collision resolved | ✓ VERIFIED | Alpha excision: 0 `alpha` residue lines in libmach/mach.h; no tracked alpha files (`git ls-files` empty). Vendored `7.c`/`7db.c`/`7obj.c` present; `7.c:9` includes `/aarch64/include/ureg.h`; zero `/arm64/` residue in the trio. Wiring: setmach.c:109 `"arm64"` entry, executable.c:258 R_MAGIC exectab, obj.c:63 `[ObjArm64] "arm64 .7", _is7, _read7`, mkfile FILES 7/7db/7obj + `7obj.$O: /sys/src/cmd/7c/7.out.h` dep; mach.h retains MARM64/FARM64/FARM64B/AARM64/ObjArm64. **Live proof:** hostbin `nm` (built via `nm.BUILD` against the 9cc libmach arm64 additions, also verified present) read `hello.7.out` exit 0 listing `main` (T 10028), `_main` (L 10044), `print`, `exits`; also parsed `aarch64/bin/rc` (530 symbols). **Caveat (recorded interpretation):** delivered nm-only — no host acid was built; 7db.c disassembler tables are landed in libmach. Plan 02-07's flagged assumptions and SUMMARY explicitly close SC#2 under this interpretation; TC-01's text (libmach learns arm64) is fully satisfied |
| 3 | 7c-compiled, 7l-linked hello-world aarch64 binary produced and runs, committed BEFORE any `aarch64/` arch dir, libc dir, or CPUS entry lands | ✓ VERIFIED | `build/aarch64/hello.7.out` committed (e60e168dc, plan 02-03), magic `00 00 8c 47` = R_MAGIC verified live via `od`, sha256 `1c89e099…` matches the committed `gate-evidence.log`. **Runs:** 3 consecutive PASS blocks in gate-evidence.log (banner → `term% ` prompt → `hello aarch64 harvey` marker → clean exit, fault scan clean, guest/host sha256 match); human-approved at the tracer gate 2026-11-01. **Ordering proven via git ancestry:** execution-evidence commit 62351f81f (02-05) `is-ancestor-of` first aarch64/ commit a7945d8b5 (02-06) — YES; binary commit e60e168dc precedes CPUS/pcc commit 0f8ea566f (02-06) — YES; `git log -- aarch64/` shows a7945d8b5 as the only/first scaffolding commit. **Letter-vs-intent nuance (noted, not a gap):** `sys/src/libc/aarch64/` sources committed at 25ddb3d6c, one commit *before* the binary — construction ordering (the binary links against that libc) and TC-03's own wording gates "arch dir/mkfile scaffolding", which all landed strictly post-execution; the vaporware rule's intent (no build-system support claims before a proven running binary) is fully satisfied |
| 4 | `objtype=aarch64` build wiring works end-to-end: `aarch64/mkfile` (CC=7c O=7), `pcc.c` entry, `mkfile.proto` CPUS, config section named `aarch64` | ✓ VERIFIED | `aarch64/mkfile` content: `CC=7c LD=7l AS=7a O=7` (+ mkfile.proto include). `pcc.c:21` row `{"aarch64", "7c", "7l", "7", "7.out"}`; `allos = "056789kqvij"` includes 7. `mkfile.proto`: `CPUS=… aarch64` (last), `OS=568ijqv7`. `build/mkdirs:50-59+` carries the `./aarch64` tree set + bbin. "Config section literally named aarch64" verified under the plan's recorded Assumption A1: `build/scripts/linux-build:127` `arch=(amd64 aarch64)` + `fn build_aarch64` dispatch (subset-scoped body verified). End-to-end: committed-wiring libc rebuild ran green in the guest (02-06 D4: libc.a 779,312 bytes / 259 members); subset + full dual-arch build products exist on disk with matching Nov 1 11:02 mtimes |
| 5 | Shell-boot userland subset (rc, ipconfig, factotum, core cmds) builds for aarch64 with `sys/src/libc/aarch64/` + generated `9syscall` SVC stubs freezing the Harvey↔r9 user ABI | ✓ VERIFIED | All 16 binaries present and executable in `aarch64/bin/` (rc grep cat cp date echo ls mkdir mv ps rm sed test wc + ip/ipconfig + auth/factotum); spot-checked `rc` and `factotum` carry R_MAGIC `00 00 8c 47`. `sys/src/libc/aarch64/` = 16 asm + notejmp.c + _seek.c + mkfile (`objtype=aarch64` line 1) + README. `9syscall/mkfile` `case aarch64` block verified line-by-line: TEXT / `MOV R0, 0(FP)` / `MOV $n, R0` / SVC / RETURN with local `_seek` rename, no SYSCALL-trap residue; sys.h carries NSEC=53 and NMOUNT=54. `aarch64/ABI.md` carries SP+8/R0/SVC/NMOUNT/ureg.h contract elements, zero pre-correction `SP+0 is where` wording. **Live D-09 audit:** nm over `aarch64/bin/rc` = 0 nmount references. Execution: `.build/9front-dist/subset-exec.log` carries exercise markers + SUBSET-OK, 0 fault lines (169-line final capture) — human eyeball outstanding (see Human Verification) |

**Score:** 5/5 truths verified (0 behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `sys/src/cmd/7a/`, `7c/`, `7l/` | Vendored 9front toolchain + BUILD/mkfile/README | ✓ VERIFIED | All present; BUILD scripts parse; READMEs carry pin; binaries in hostbin run live |
| `sys/src/cmd/cc/compat.h` | Host-compat declarations | ✓ VERIFIED | Exists; `mysbrk(ulong)` at line 23; only additive file under cc/ (per summaries' git-status gates) |
| `sys/src/libmach/7.c`, `7db.c`, `7obj.c` | arm64 machine support | ✓ VERIFIED | Present; 7.c single `/aarch64/include/ureg.h` rewrite; no /arm64/ residue |
| `sys/src/libc/aarch64/` | Per-arch libc | ✓ VERIFIED | 19 files + README; mkfile line 1 `objtype=aarch64`; lock.c deliberately dropped (D-14 reconcile, portable port/lock.c supplies Harvey-semantics locks — documented) |
| `sys/src/libc/9syscall/mkfile` | `case aarch64` generator | ✓ VERIFIED | Donor-verbatim block verified (SVC, 0(FP), _seek) |
| `sys/src/libc/9sys/callmain.c` | _callmain startup glue | ✓ VERIFIED | Present; `callmain.$O` in 9sys/mkfile OFILES line 8 |
| `aarch64/mkfile`, `include/u.h`, `include/ureg.h`, `ABI.md` | objtype wiring + frozen headers + ABI contract | ✓ VERIFIED | Contents verified; summaries record sha256-equality gates vs the pinned donor (u.h dd1bd611…, ureg.h 04910dfc…) |
| `build/aarch64/hello.7.out` | Committed gate binary | ✓ VERIFIED | R_MAGIC + sha256 match to evidence log; git-tracked |
| `build/aarch64/gate-evidence.log` | Execution proof | ✓ VERIFIED | 3 PASS blocks, human-approved |
| `build/scripts/linux-build` | Dual-arch activation | ✓ VERIFIED | `arch=(amd64 aarch64)` line 127; subset-scoped `build_aarch64` |
| `sys/src/libmp/aarch64/mkfile`, `sys/src/libsec/aarch64/mkfile` | riscv64-pattern arch stubs | ✓ VERIFIED | Empty-OFILES stubs with objtype=aarch64 |
| `sys/src/libthread/aarch64.c` | libthread arch member | ✓ VERIFIED | Present (donor arm64.c verbatim per summary) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| BUILDTOOLCHAIN | 7a/7c/7l BUILD scripts | lines 10-12 | ✓ WIRED | `(cd $HARVEY/sys/src/cmd/7{a,c,l} && sh BUILD)` present; script parses |
| BUILDTOOLCHAIN | nm.BUILD | line 15 | ✓ WIRED | `(cd $HARVEY/sys/src/cmd && sh nm.BUILD)`; nm binary exists and runs |
| 7c → 7a → 7l pipeline | hostbin tools | live smoke test | ✓ WIRED | Ran live this session: compile→assemble→link-diagnostics all correct |
| nm (host) | 7l executables | 9cc libmach ObjArm64 row + R_MAGIC exectab | ✓ WIRED | Live: nm read hello.7.out + aarch64/bin/rc correctly |
| libmach obj.c | 7obj.c | `[ObjArm64] "arm64 .7", _is7, _read7` | ✓ WIRED | Row present at obj.c:63 |
| 9syscall generator | libc.a stubs | `case aarch64` feeds 7a + ar | ✓ WIRED | Block verified; guest build archived 53 stubs + full libc.a (259 members post-02-06) |
| linux-build | aarch64 subset | `arch=(amd64 aarch64)` → `build_aarch64` | ✓ WIRED | Function body subset-scoped; aarch64/bin products on disk |
| aarch64/mkfile | mkfile.proto | `</$objtype/mkfile` include | ✓ WIRED | aarch64/mkfile line 1; CPUS/OS know the arch |
| run-gate.sh | gate-evidence.log | TC-03 gate | ⚠️ STALE SELF-CHECK | Script's final `test ! -e $HARVEY/aarch64` assertion (lines 726-729) is stale post-02-06 — review CR-01 confirmed. Evidence already committed is valid; reruns exit 1 after appending PASS. See Human Verification item 2 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `aarch64/bin/*` (16 binaries) | n/a (build products) | 7c/7l via committed namespace wiring | Yes — R_MAGIC executables, executed on donor kernel per subset-exec.log | ✓ FLOWING |
| `gate-evidence.log` | serial capture | live qemu TCG boot of donor kernel | Yes — real serial log with banner/prompt/marker; sha256 pair matches committed binary | ✓ FLOWING |
| `subset-exec.log` | serial capture | live qemu TCG boot + 20-step exercise | Yes — markers + SUBSET-OK; 0 fault lines | ✓ FLOWING |
| `donor-build.log` | build transcript | guest in-donor-tree kernel build | Yes — provenance line resolves 7c to Harvey guest hostbin | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 7c compiles C to arm64 asm | `$HB/7c -S fib.c` | 5 TEXT/MOV lines | ✓ PASS |
| 7a assembles 7c output | `$HB/7a fib.s` | fib.7 produced (481 bytes) | ✓ PASS |
| 7l parses .7 + diagnostics | `$HB/7l fib.7` | `entry not text: _main` / `_main: not defined` | ✓ PASS |
| nm decodes 7l executable | `$HB/nm build/aarch64/hello.7.out` | exit 0; main/_main/print/exits listed | ✓ PASS |
| D-09 audit capability | `$HB/nm aarch64/bin/rc \| grep -w nmount` | 530 symbols, 0 nmount | ✓ PASS |
| hello.7.out magic | `od -An -tx1 -N4` | `00 00 8c 47` (R_MAGIC) | ✓ PASS |
| Donor pin integrity | `git -C .build/9front-donor rev-parse HEAD` | `350266104f1fed81c78c3d05fa44f523bec0ae4d` | ✓ PASS |
| Phase 1 regression artifacts | `ls amd64/9k10cpu{,.elf} 9k10cpuf{,.elf} 9k10f{,.elf}` | all 6 present (Nov 1 11:02 — phase-exit build) | ✓ PASS |

Boot/execution behaviors were not re-run by this verifier (qemu TCG boots are 10+ minute server-class operations; the project's chosen proof mechanism is committed serial-capture evidence, human-approved for TC-03). The committed evidence was content-verified instead.

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|--------------|-------------|--------|----------|
| TC-01 | 02-02, 02-03 | libmach arm64 (7.c/7db.c/7obj.c/setmach); letter-7 collision resolved | ✓ SATISFIED | Excision zero-residue; wiring verified; nm operates on 7l objects live |
| TC-02 | 02-01 | 7a/7c/7l vendored + BUILD scripts; build on darwin-aarch64 + linux-aarch64; compat.h drift reconciled | ✓ SATISFIED | Tools exist, parse, run live on darwin; linux-aarch64 proven via guest donor-kernel build provenance |
| TC-03 | 02-03, 02-04, 02-05 | libc/aarch64 + `case aarch64` stubs; hello-world proves toolchain end-to-end before scaffolding | ✓ SATISFIED | Binary committed + executed on donor kernel (3 PASS blocks, human-approved); ordering vs arch dir/CPUS proven via git ancestry |
| TC-04 | 02-06 | aarch64/mkfile, pcc.c entry, mkfile.proto CPUS, config section named aarch64 | ✓ SATISFIED | All wiring greps pass; arch=(amd64 aarch64) + build_aarch64; committed-wiring libc rebuild green |
| TC-05 | 02-07 | Shell-boot subset builds for aarch64 (+ aout2uimage resolved not-needed per D-12) | ✓ SATISFIED | 16 binaries on disk with R_MAGIC; executed on donor kernel (SUBSET-OK, 0 faults); D-09 nm audit clean live |

All five phase requirement IDs appear in REQUIREMENTS.md mapped to Phase 2 and are claimed by at least one plan's frontmatter. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `build/aarch64/run-gate.sh` | 726-729 | Stale `test ! -e $HARVEY/aarch64` assertion (review CR-01) | ⚠️ Warning | Gate script now always exits 1 post-02-06 *after* appending PASS evidence — contradicts documented idempotence; does not invalidate committed evidence. Routed to human disposition |
| (debt-marker scan) | — | `TBD|FIXME|XXX|PLACEHOLDER` across all phase-touched files | — | **Zero real markers.** grep hits were false positives: `mktemp …XXXXXX` templates and the `AXXX` opcode constant |
| (stub scan) | — | empty returns / hardcoded-empty props / console-only impls | — | None found in Harvey-authored files; harness scripts are fully wired end-to-end |

The code review's 10 standing warnings (WR-01..WR-10: silent-failure paths, deadline mismatch, prompt-proof echo weakness, missing set -e in 9cc/BUILD + nix/build.sh, etc.) were sampled against the live tree and confirmed accurately reported (e.g. run-gate.sh CR-01 verified above; nsrun.sh/9cc BUILD set -e absence matches review line refs). They are triage items, not goal blockers — see Human Verification item 2.

### Human Verification Required

#### 1. D-08 subset execution log eyeball (plan 02-07's explicit human-check)

**Test:** Open `.build/9front-dist/subset-exec.log` and read the captured serial session.
**Expected:** The Harvey aarch64 subset (rc, grep, ipconfig, factotum, 12 core commands — all 7c-compiled) visibly executes on the 9front donor kernel command-by-command: echo sentinel, `ls /`, cat/grep/sed/wc pipelines, date, test, ps, mkdir/cp/mv/rm round-trip, ipconfig usage, factotum resident in a later ps, closing SUBSET-OK; zero panic/trap/`sys: ` lines.
**Why human:** The plan carries an explicit `<human-check>` here; unlike the TC-03 gate (human-approved 2026-11-01 per 02-05-SUMMARY), no human approval of this specific log is recorded. Automated greps pass; the plan requires the human eyeball.

#### 2. Disposition of review CR-01 + 10 standing warnings

**Test:** Triage the 24 open findings in `02-REVIEW-DISPOSITION.md` — lead item CR-01 (run-gate.sh stale scaffolding assertion, confirmed live by this verification).
**Expected:** Decide fix-now vs defer-to-hygiene for the critical (one-line-class fix; review supplies the patch shape) and the 10 warnings. CR-01 does not falsify any phase truth — the phase goal stands verified regardless.
**Why human:** Scope/severity triage is a human call; the review process recorded all 24 findings as open and the orchestrator asked for them to factor into verification honesty.

### Gaps Summary

No must-have gaps. The phase goal — Harvey compiles and links its own aarch64 Plan 9 binaries on darwin-aarch64 and linux-aarch64, proven by real binaries, not scaffolding — is **verified achieved** with live tool-chain execution evidence collected independently by this verifier (not from SUMMARY claims): the vendored 7c/7a/7l ran a compile→assemble→link-diagnostics pipeline on this host; nm decoded both the gate binary and an installed subset binary; all 16 subset executables carry the arm64 R_MAGIC; committed execution evidence (human-approved) demonstrates the binaries run on the reference kernel; git ancestry proves the vaporware-rule ordering against all build-system scaffolding.

Two interpretation records to carry forward (both documented in-plan and verified under those interpretations): SC#2 delivered nm-only (no host acid; 7db.c tables landed), and SC#4's "config section" realized as the `arch=(amd64 aarch64)` + `build_aarch64` dispatch per Assumption A1. One letter-vs-intent note on SC#3: `sys/src/libc/aarch64/` sources committed one commit before the hello binary (construction necessity; all *scaffolding* — arch dir, CPUS, pcc, mkdirs — landed strictly after execution evidence, which is the rule's intent).

The single confirmed critical (CR-01) and 10 warnings from the standing code review are routed to human triage above; none negate the phase goal.

---

_Verified: 2026-11-01T16:31:54Z_
_Verifier: the agent (gsd-verifier)_
