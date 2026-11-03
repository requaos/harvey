---
phase: 05-shell-boot-one-command-integration
verified: 2026-11-03T17:30:00Z
status: human_needed
score: 4/5 must-haves verified
covered_files:
  - .github/workflows/r9-shell.yml
  - .planning/phases/05-shell-boot-one-command-integration/05-01-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-01-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-02-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-02-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-03-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-03-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-04-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-04-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-05-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-05-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-06-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-06-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-07-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-07-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-08-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-08-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-09-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-09-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-10-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-10-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-11-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-11-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-12-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-12-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-13-PLAN.md
  - .planning/phases/05-shell-boot-one-command-integration/05-13-SUMMARY.md
  - .planning/phases/05-shell-boot-one-command-integration/05-EVIDENCE.md
  - .planning/phases/05-shell-boot-one-command-integration/05-REVIEW-DISPOSITION.md
  - .planning/phases/05-shell-boot-one-command-integration/05-REVIEW.md
  - build/REPRODUCIBILITY.md
  - build/aarch64/drive-r9.expect
  - build/aarch64/init.c
  - build/aarch64/mkimage.sh
  - build/aarch64/run-r9.sh
  - build/aarch64/smoke-r9.expect
  - build/aarch64/stacksmoke.c
  - build/aarch64/subset-build.sh
  - flake.lock
  - flake.nix
  - nix/boot-r9.sh
  - nix/smoke-r9.sh
  - sys/src/9k/boot/bootr9.c
  - sys/src/9k/boot/mkfile.aarch64
covered_digest: "v2:sha256:519c97aa0721f38fe21021f7905a4eab05eb2d92469db2c254ddf125d750afb5"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Push harvey master to origin (217 commits pending) and observe the first hosted run of .github/workflows/r9-shell.yml on ubuntu-latest"
    expected: "The workflow's single step `nix run .#boot-r9-smoke` exits 0 — the run log carries 'smoke-r9: ALL STAGES PASS — boot, echo, ls/ps/cat sweep, DEL safety, restart'. Record the run URL in 05-EVIDENCE.md (the PENDING FIRST PUSH slot)."
    why_human: "External-service integration (GH Actions) — pushing to origin was prohibited during phase execution, so no hosted run exists to verify. This is also the FIRST execution of the pipeline on x86_64-linux anywhere (ubuntu-latest's arch): darwin-aarch64 and aarch64-linux are proven by committed clean-clone logs, but the x86_64-linux package set has never been evaluated/run. 05-EVIDENCE.md flags this sub-case honestly ('runs natively for the first time on the GH runner at first push'). Until that run is green, ROADMAP SC#3's CI leg (as amended by 05-CONTEXT D-13: CI = linux) is unmet."
  - test: "Optional live-interactive sanity: `nix run .#boot-r9` on this host, type `echo hi`, `ls /bin`, `ps`, `exit` at the % prompt"
    expected: "Commands answer correctly; `exit` returns to a fresh % prompt via init's restart loop. NOTE: typed input has no console echo this era (documented in deferred-items.md — the donor's cooked-mode echo is deliberately absent; commands execute, input is invisible). Judge whether that is acceptable for the milestone's 'interactive shell' headline."
    why_human: "The expect drivers prove machine interactivity (send/expect round-trips), but no human has watched the live prompt; the no-echo era delta is a UX judgment automation cannot make."
---

# Phase 5: Shell Boot + One-Command Integration — Verification Report

**Phase Goal:** The Core Value is delivered — one command, on either host OS, from clean checkouts of both repos, boots r9 plus the Harvey aarch64 userland to an interactive `/bin/rc` shell. Work spans both repos plus the flake glue.
**Verified:** 2026-11-03T17:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A single command (`nix run` app or `cargo xtask`) boots r9 + Harvey aarch64 userland to an interactive `/bin/rc` prompt over the PL011 console in qemu | ✓ VERIFIED | `flake.nix:109` declares `boot-r9`; `nix/boot-r9.sh` (166 lines) composes: userland build → mkpaqfs bake → fdtput DTB patch → qemu argv. `05-11-compose-gate.log:1727` shows the actual argv with the kernel ONLY from the flake-input store path (`…-r9-kernel-virt-9549cee/kernel-virt.elf`), `:1738` banner, `:2471` `paqfs...`, `:2543` `init: starting /bin/rc`, `:2609` stacksmoke, then `% `. That store path exists in `/nix/store` and is a real `ELF 64-bit LSB executable, ARM aarch64` (21.9 MB) — verifier-checked. Interactivity proven by `05-08-drive-r9.log`: `r9shell7` echo answer (:938), `r9delok` DEL-safety answer (:952), `init: starting /bin/rc` restart (:957). |
| 2 | At the prompt, rc builtins and external binaries (`ls`, `cat`, `echo`, `ps`) execute correctly | ✓ VERIFIED | `build/aarch64/smoke-r9.expect` asserts each by name (echo exact-string round-trip; `ls /bin` word-anchored presence of rc/ls/cat/echo/ps; `ps` ≥3 `glenda \d+` process lines incl rc; `cat /lib/namespace` containing `bind -c #e /env`). `05-12-smoke.log` byte-verified by grep: `r9shell7` (:936), the 17-entry `/bin/*` listing (:960–1000 incl `/bin/cat /bin/echo /bin/ls /bin/ps /bin/rc`), four ps lines init/paqfs/rc/ps (:1017–1020), `bind -c #e /env` (:1050), `r9delok` (:1070), restart `init: starting /bin/rc` (:1075 — the second occurrence; boot occurrence at :816). rc itself executes as the shell driving all of the above. |
| 3 | Expect-style smoke passes on darwin-aarch64 and linux hosts — CI green on both (amended by 05-CONTEXT D-13: CI = linux-only; darwin documented-manual) | ? UNCERTAIN → human | darwin leg: VERIFIED — two consecutive green `nix run .#boot-r9-smoke` runs (05-12's gate), run 2's capture committed (`05-12-smoke.log`). linux leg: VERIFIED NATIVELY — `05-13-linux-clean-clone.log` byte-verified: `clone HEAD: dc8299575…` (:2), `host: Linux 6.8.0-147-generic aarch64` (:3), `SUBSET-BUILD-OK` (:2076), bake PASS with paqfs magics (:2091), `ALL STAGES PASS` (:3229), `exit: 0` (:3231). **CI leg: NOT RUN** — `.github/workflows/r9-shell.yml` exists, is valid YAML, pins nix-installer-action to a 40-char SHA, leaves harvey.yml untouched (git log empty in window) — but harvey is 217 commits ahead of origin/master (verifier-checked: `git log @{u}..HEAD`), so no hosted run exists. The GH runner arch (x86_64-linux) has never executed the pipeline anywhere. D-13's amendment was user-approved in CONTEXT.md, but even the amended criterion requires the linux CI run, which is pending first push. |
| 4 | From clean checkouts of both repos, the documented commands reproduce the boot with pinned toolchains/qemu — honoring Phase 1's KERNDATE/reproducibility policy | ✓ VERIFIED | `build/REPRODUCIBILITY.md:86–146` INT-03 section: process-level policy, KERNDATE derived from checkout HEAD host-side, named pins (r9 rev+narHash, nixpkgs, rust-toolchain.toml via rust-overlay, qemu via nixpkgs), explicit NOT-claimed (bit-identical images), per-host derivation, non-default overrides. Clean-checkout evidence: darwin pristine clone @ `dc8299575` → green (`05-13-darwin-clean-clone.log`, 1116 lines, full sweep markers); linux pristine clone @ `dc8299575` → green (`05-13-linux-clean-clone.log`, in-log provenance header). Pins resolve from a clean clone: verifier confirmed flake.lock's r9 rev `9549cee…` IS `origin/main` HEAD in the r9 repo (`git merge-base --is-ancestor` → YES) and `nix flake metadata` resolves `r9: github:requaos/r9/9549cee`. Caveat: x86_64-linux clean-checkout leg unexecuted (folded into human item 1). |
| 5 | Harvey's `flake.nix` consumes r9 as a flake input (pinned git rev) — no `../r9` relative-path or submodule glue (INT-04) | ✓ VERIFIED | `flake.nix:11` `inputs.r9.url = "github:requaos/r9"`; `flake.lock` locks rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` + narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=` (matches 05-EVIDENCE.md). No `.gitmodules` exists. `grep -vE '^\s*#' nix/boot-r9.sh \| grep -c '../r9'` → 0; same for `nix/smoke-r9.sh` → 0. Kernel/DTB arrive only via `R9_KERNEL_PKG` store path (`flake.nix:84,94`), presence-validated in boot-r9.sh:67–82. The `9549cee..cbbc8e4` delta is docs-only (HowItWorks.md + README.md, 32 insertions — verifier `git diff --stat`), so the pin's kernel equals the evidence kernel. |

**Score:** 4/5 truths verified (0 present-but-behavior-unverified; SC#3 is UNCERTAIN on the CI component and routes to human verification)

### Plan-Level Must-Have Spot-Checks (13 plans)

Verified beyond the roadmap SCs (the load-bearing plan truths):

- **05-01 (D-14 note-race):** fix commit `83cbbbe` exists on r9 main with the root-cause mechanism in its message ("trap_return tail clobbered restored x9 with the CURKSTACK load"); pre-fix failure captures committed under `05-01-evidence/`; 40/40 burial claim recorded in 05-01-SUMMARY. The smoke's DEL-safety stage re-exercises the fix on every run.
- **05-02 (supply chain):** `sys/src/9k/boot/bootr9.c` + `mkfile.aarch64` exist and are substantive (hand-written bootconf: embed method first, `/rootfs.img` arg, cpuflag=0). `mkimage.sh` enforces the manifest incl. the D-02 prohibition at bake time (`[ ! -e "$STAGE/boot/factotum" ] || err`) and the paqfs magics (529ab12b/6b46e688). `bootfs.paq` gitignored (`.gitignore:97`). amd64 shared boot files untouched in the phase window (git log empty for boot.c/embed.c/init.c/rcmain).
- **05-03 (measured set):** `05-03-trace.txt` substantive — donor pin, rig, honest coverage-boundary header, 26-syscall measured set (verified the header + counts exist; matches 05-EVIDENCE.md's quote).
- **05-04..05-09 (kernel growth):** all port devices exist in `/Users/neilskinner/code/r9/port/src/` (namec, pgrp, devenv, devpipe, devdup, devsrv, devmnt, devproc, devroot, fdgrp — real file sizes 5.5–34 KB); all syscall handlers present in `aarch64/src/syscall.rs` (bind:588, chdir:631, unmount:662, fversion:712, mount:759, stat:844, fstat:879, pipe:1070, dup:1118, create:1155, fd2path:1250, seek:1380, sleep:1471, alarm:1501). Gate logs byte-verified: 05-04 PIPE wall (`syscall 21 unimplemented` at :730 after `exec: entering EL0 … path=/boot/boot`), 05-06 FVERSION wall (`version...syscall 40 unimplemented` :778), 05-07 hinge (`% ` prompts + init restarts), 05-08 interactive gate, 05-09 full sweep.
- **05-10 (D-10 inversion):** `r9/flake.nix:81–103` `packages.kernel-virt` builds via `cargo xtask build --arch aarch64 --config virtshell` and ships `kernel-virt.elf` + `aarch64/lib/virt-gicv2.dtb` (the store-path contract Harvey reads). `xtask/src/uregcheck.rs:52–61`: `R9_HARVEY_DIR` required, loud named error when unset, NO `../harvey` default anywhere in xtask code. `aarch64/lib/config_virtshell.toml` exists with the virt/cortex-a72/gicv2/TCG shape.
- **05-11 (compose):** see SC#1/SC#5.
- **05-12 (packaged smoke):** `boot-r9-smoke` app at `flake.nix:110`; `nix/smoke-r9.sh` (187 lines) fresh-capture hygiene (rm -f before launch), per-stage named timeouts, group-kill teardown; two-consecutive-run gate recorded.
- **05-13 (CI + clean-clone + evidence):** workflow authored/valid/pinned; REPRODUCIBILITY.md INT-03; 05-EVIDENCE.md consolidated with live-gated SHAs; r9 docs tour landed (HowItWorks.md namespace-core + flake-package sections — verified present at lines 112–151; README rows).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `flake.nix` (harvey) | inputs.r9 + boot-r9/boot-r9-smoke apps | ✓ VERIFIED | lines 11, 108–111; hasAttr-gated per-system |
| `flake.lock` (harvey) | r9 rev+narHash pin | ✓ VERIFIED | 9549cee…; == r9 origin/main HEAD |
| `nix/boot-r9.sh` | compose pipeline | ✓ VERIFIED | 166 lines; R9_KERNEL_PKG required; fdtput two-cell patch; qemu argv assembly |
| `nix/smoke-r9.sh` | packaged smoke wrapper | ✓ VERIFIED | 187 lines; fresh capture; EXIT-trap teardown |
| `build/aarch64/smoke-r9.expect` | full D-09 sweep driver | ✓ VERIFIED | 209 lines; stage-named failures; all sweep assertions present |
| `build/aarch64/drive-r9.expect` | dev interactive driver | ✓ VERIFIED | 187 lines |
| `sys/src/9k/boot/bootr9.c` + `mkfile.aarch64` | additive aarch64 boot build | ✓ VERIFIED | hand-written bootconf; embed method; `/rootfs.img` contract |
| `build/aarch64/{subset-build,mkimage,run-r9}.sh`, `stacksmoke.c`, `init.c`, root-tree skeleton | supply chain | ✓ VERIFIED | all present, substantive |
| `build/REPRODUCIBILITY.md` INT-03 section | policy + pins + derivation | ✓ VERIFIED | lines 86–146 |
| `.github/workflows/r9-shell.yml` | linux CI leg | ⚠️ PRESENT, NEVER RUN | valid YAML; SHA-pinned installer; pending first push |
| `../r9/port/src/*.rs` device set | namespace/pipe/9P/env/cons/proc | ✓ VERIFIED | 11 files, substantive sizes |
| `../r9/aarch64/src/syscall.rs` handlers | measured-set dispatch | ✓ VERIFIED | 15 handlers located by grep |
| `../r9/flake.nix` packages.kernel-virt | kernel store-path contract | ✓ VERIFIED | lines 81–103; realized in /nix/store |
| `../r9/aarch64/lib/config_virtshell.toml` | shell-chain profile | ✓ VERIFIED | present with correct qemu shape |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| harvey flake | r9 flake input | `inputs.r9` → `r9.packages.${system}.kernel-virt` → `R9_KERNEL_PKG` env → boot-r9.sh | ✓ WIRED | store path realized on this host; compose log argv proves consumption |
| boot-r9.sh | bake | `mkimage.sh` → host mkpaqfs → bootfs.paq (magics asserted) | ✓ WIRED | bake PASS lines in both clean-clone logs |
| boot-r9.sh | qemu | fdtput `/chosen` initrd cells + `-device loader,@0x48000000` | ✓ WIRED | compose log :143–154 script, :1727 argv |
| smoke-r9.expect | composed pipeline | spawns qemu over -nographic stdio; asserts markers | ✓ WIRED | smoke log contains every asserted marker |
| r9 kernel | Harvey userland | paqfs initrd → devroot/exec → pid 1 /boot/boot | ✓ WIRED | 05-04/05-07 logs: EL0 entry naming /boot/boot, init, rc prompt |
| devmnt | userspace paqfs | connectembed pipe → FVERSION/MOUNT → mounted union | ✓ WIRED | 05-06/05-07 gate logs (fversion wall → mounted boot completion) |
| GH workflow | the pipeline | `nix run .#boot-r9-smoke` on ubuntu-latest | ✗ NOT WIRED (never run) | file correct; hosted execution pending first push |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| boot-r9.sh kernel path | `R9_KERNEL_PKG` | flake-input store path | ✓ real ELF in /nix/store | ✓ FLOWING |
| smoke log markers | expect `expect_out(buffer)` | live qemu serial (pty) | ✓ committed logs byte-verified | ✓ FLOWING |
| ps output | devproc PROC_TABLE | live kernel proc list | ✓ 4 real procs in log | ✓ FLOWING |
| ls /bin | devmnt → paqfs → baked image | Harvey's own mkpaqfs bake | ✓ 17 real entries | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| flake.lock r9 pin == claimed rev | `python3 json load` | 9549cee… + narHash match EVIDENCE | ✓ PASS |
| pinned rev fetchable from clean clone | `git merge-base --is-ancestor 9549cee origin/main` (r9 repo) | ancestor of origin/main (== HEAD) | ✓ PASS |
| pinned kernel realized on this host | `file /nix/store/…-r9-kernel-virt-9549cee/kernel-virt.elf` | ELF 64-bit ARM aarch64, 21.9 MB | ✓ PASS |
| flake resolves with r9 input | `nix flake metadata` | r9: github:requaos/r9/9549cee | ✓ PASS |
| smoke markers in committed log | grep 05-12-smoke.log | all markers at quoted lines | ✓ PASS |
| linux clean-clone PASS in log | grep 05-13-linux-clean-clone.log | ALL STAGES PASS + exit: 0 | ✓ PASS |
| workflow YAML validity | `yaml.safe_load` | valid | ✓ PASS |
| no `../r9` in shipped scripts | grep -c | 0, 0 | ✓ PASS |
| r9 host suites (`cargo test -p port`) | — | cargo not on host PATH (nix devshell only); not re-run — committed EVIDENCE matrix + per-plan summaries attest; test files present (15 files incl. 5 red-evidence JSONs) | ? SKIP |
| qemu boot-test profiles (5) | — | not re-run by verifier (TCG minutes each; committed gate logs 05-04..05-09 byte-verified instead) | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| INT-01 | 05-11 | One command boots to interactive /bin/rc over PL011 | ✓ SATISFIED | SC#1 row |
| INT-02 | 05-12, 05-13 | Expect smoke on darwin + linux | ⚠️ SATISFIED-PENDING-CI | darwin (2× green, committed log) + native aarch64-linux (committed log) proven; the GH-hosted leg pending first push (human item 1) |
| INT-03 | 05-13 | Clean-checkout reproducibility, pinned toolchains | ✓ SATISFIED | SC#4 row; x86_64-linux sub-case folded into human item 1 |
| INT-04 | 05-10, 05-11 | flake input (pinned rev), no relative-path/submodule glue | ✓ SATISFIED | SC#5 row |

No orphaned requirements: REQUIREMENTS.md maps exactly INT-01..04 to Phase 5; plans claim exactly INT-01..04 (grep-verified across all 13 PLAN frontmatters).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `../r9/port/src/devcons.rs` | 41, 61 | `// XXX: Just for testing.` markers on the shipped console print path | ⚠️ Warning | Tracked as IN-10 in 05-REVIEW.md + disposition ledger — auditable follow-up exists; not an untracked debt marker |
| `../r9/HowItWorks.md` | 58 | stale doc: says ureg-check has "default `../harvey`" — the 05-10 inversion removed it | ℹ️ Info | Code is correct (loud error, no default); docs-tour commit missed this Phase-4-era sentence; cosmetic drift |
| `nix/smoke-r9.sh:137`, `drive-r9.expect:71` | — | pkill teardown keyed on kernel-name class, not run identity (WR-07) | ⚠️ Warning | Can kill a developer's concurrent interactive boot-r9; smoke header acknowledges the assumption; CI-single-runner safe today |

### 05-REVIEW.md Findings vs the Phase GOAL

All 23 findings are disposition-open (ledger untouched). I re-verified the two criticals directly against the code:

- **CR-01 (six devices serve 3-string stat records): CONFIRMED REAL** — `devcons.rs:310-329` writes name/uid/gid only (`need = 41 + (2+name) + (2+6) + (2+6)`), same shape in the five siblings; `devproc.rs` is the one correct device. **Goal impact: NONE on the verified criteria.** The gated sweep never dirreadall's those devices: `ls /bin` rides devmnt→paqfs (proper 4-string records), `ps` rides devproc (correct), `cat /lib/namespace` rides the mounted tree. `ls /dev`, `ls /env`, `ls /fd`, `ls /srv` WOULD fail, and `dirstat` on those devices returns uninitialized string pointers. Latent, pre-documented in deferred-items.md before the review found it. **Does not defeat the goal; must be triaged before milestone ship.**
- **CR-02 (sys_stat/sys_fstat skip ensure_user_resident): CONFIRMED REAL** — `syscall.rs:844–897` validate range but omit the `fault::ensure_user_resident` call that 8 sibling buffer-writing handlers carry (verified by grep: lines 300/372/723/1078/1258/1391/1437/1534). A cold brk_-grown heap page under a stat buffer → EL1h abort → kernel halt. Reachable in principle via rc's own dirstat probes; never hit in the gated flows. **Does not defeat the goal as evidenced; a one-line-per-handler fix; must be triaged before milestone ship.**
- WR-01..WR-08: real, era-shaped or latent; none falsify any success criterion. WR-03 (^D EOF never yields) and WR-04 (pgrp lock across blocking RPCs — also deferred-items.md) are the most consequential for the next phase.
- The known 05-09 input-wedge flake: documented-not-fixed, 4/4 clean in 05-12/05-13 runs — consistent with the logs I verified (no wedge markers).

### Human Verification Required

#### 1. First hosted CI run of r9-shell.yml (the amended SC#3's CI leg)

**Test:** Push harvey master to origin (217 commits pending — includes the workflow at `dc8299575` and the evidence commits), then watch the first run: `gh run list --workflow r9-shell.yml`.
**Expected:** Green — the run log carries `smoke-r9: ALL STAGES PASS — boot, echo, ls/ps/cat sweep, DEL safety, restart`; record the run URL in 05-EVIDENCE.md's PENDING FIRST PUSH slot.
**Why human:** External-service integration; pushing was prohibited during execution, and this is additionally the first-ever execution of the pipeline on x86_64-linux (ubuntu-latest's arch — the one linux sub-case no committed log covers; 05-EVIDENCE.md flags it honestly). If the run fails on an x86_64-specific evaluation issue (r9's kernel-virt IFD is the named suspect), that becomes a real gap for a follow-up plan.

**Override path (if the project accepts the native substitute as sufficient):** the deviation is intentional (orchestrator no-push rule) and a same-pipeline native aarch64-linux pristine-clone proof exists. To accept formally, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "An expect-style smoke test asserting the rc prompt passes on darwin-aarch64 and linux hosts — CI green on both (D-13: CI = linux)"
    reason: "The exact pipeline the workflow encodes ran green natively on aarch64-linux from a pristine clone carrying the workflow commit (05-13-linux-clean-clone.log, exit 0); the hosted x86_64-linux run is structurally identical and lands at first push, which was policy-prohibited during execution"
    accepted_by: "<name>"
    accepted_at: "<ISO timestamp>"
```

#### 2. Live interactive sanity (optional but recommended)

**Test:** `nix run .#boot-r9`; type `echo hi`, `ls /bin`, `ps`, `exit` at the `% ` prompt.
**Expected:** Commands answer; exit restarts to a fresh `% `. NOTE: typed input has NO echo this era (documented era delta in deferred-items.md — commands execute, keystrokes are invisible). Judge whether that is acceptable under the milestone's "interactive shell" headline or should be scheduled.
**Why human:** Expect drivers prove machine interactivity; no human has watched the prompt; echo-absence is a UX judgment.

### Gaps Summary

No code gaps. The single unmet criterion component is the **hosted CI run** (SC#3 as amended by user-approved D-13): the workflow exists, is valid and pinned, and the pipeline it encodes is proven green by committed clean-clone logs on darwin-aarch64 and aarch64-linux — but the GH Actions execution itself is pending the first push, which also covers the never-executed x86_64-linux arch. Everything else about the phase goal is delivered and byte-verified against committed evidence: one command (`nix run .#boot-r9`) boots the flake-pinned r9 kernel plus Harvey's own baked aarch64 userland to an interactive `/bin/rc` shell; echo/ls/cat/ps execute correctly at the prompt; DEL is safe; exit restarts the shell; the integration is flake-input-only with zero relative-path or submodule glue.

Two critical kernel defects (CR-01 malformed stat records in six devices; CR-02 missing cold-buffer residency in sys_stat/sys_fstat) are confirmed real, latent in all gated flows, and tracked open in 05-REVIEW-DISPOSITION.md. They do not falsify any success criterion as written, but they are user-reachable and must be triaged (fix or accept) before the milestone ships — recommended as the first item of milestone-completion audit or a small follow-up phase.

---

_Verified: 2026-11-03T17:30:00Z_
_Verifier: the agent (gsd-verifier)_
