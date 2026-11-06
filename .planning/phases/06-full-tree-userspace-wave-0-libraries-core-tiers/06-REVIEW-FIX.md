---
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
fixed_at: 2026-11-06T00:17:52Z
review_path: .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-11-06T00:17:52Z
**Source review:** .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (fix_scope=all; review carried 0 critical, 2 warning, 6 info)
- Fixed: 8
- Skipped: 0

**Verification venue:** main checkout (`/Users/neilskinner/code/harvey`, branch master), darwin-aarch64. `workflow.use_worktrees=false`, so no isolated worktree was created — edits and commits landed directly on master per project instruction (normal commits, hooks ran). The edited scripts are linux-venue harnesses whose full execution requires the lima guest or native linux; verification here is static (parse checks + targeted functional probes of the changed expressions), with CI/lima as the exercising gate. IN-06 touches 9k kernel source, which cannot compile on this host (Plan 9 toolchain) — Tier 1 re-read only there; the kernel build is the CI/linux-venue gate. Numbers below are reproducible from the main checkout.

## Fixed Issues

### WR-01: gethunk libc-provisioning block's error handling is dead under `set -e` (previously fixed)

**Files modified:** `build/aarch64/gethunk-repro-6l.sh`
**Commit:** 984e62eb3
**Applied fix:** Wrapped the `RUN_BUILD_IN_PRIVATE_NAMESPACE` invocation in the `set +e … RC=$? … set -e` idiom, mirroring the script's own sibling harness captures verbatim (the two `verify` legs at former lines 289-292 and 310-313), so a namespace-build failure now reaches the named error (`error: libc namespace provisioning failed (rc=$RC)`, exit 2) and the `rm -f "$NSLIBC"` temp-file cleanup instead of aborting silently under `set -e`. Added a 3-line comment citing the idiom. Fix text matches the reviewer's suggestion exactly, tab-indented to the block's 3-tab depth.
**Re-verification (this run):** the wrapper is still in place at lines 280-285 (`set +e` / subshell / `RC=$?` / `set -e` / `rm -f "$NSLIBC"` / named error), intact and unregressed.

### WR-02: coverage-sweep.sh unconditionally overwrites the host's /bin/cpp outside the namespace (previously fixed)

**Files modified:** `build/aarch64/coverage-sweep.sh`, `build/aarch64/nsrun.sh`
**Commit:** 76ab66aa7
**Applied fix:** Full fix via the reviewer's preferred route — the in-namespace bind-mount pattern, not a gated host cp. `nsrun.sh` gained a cpp bind immediately after the established `/bin/rc` bind (`[ -e /bin/cpp ] || touch /bin/cpp; mount --bind "$HARVEY_LINUX_BIN/cpp" /bin/cpp`), conditional on `$HARVEY_LINUX_BIN/cpp` being executable; `coverage-sweep.sh` deleted the unconditional `sudo cp` and kept the hard early error when hostbin cpp is missing. Behavior parity on both venue paths; zero host mutation.
**Re-verification (this run):** the nsrun.sh bind is intact at lines 107-121 (comment block + conditional bind); coverage-sweep.sh lines 393-402 carry the updated comment and the `[ -x "$HARVEY_LINUX_BIN/cpp" ] || err …` hard check with no host-side cp. Unregressed.

### IN-01: mkimage.sh keeps a dead dd trailer extraction

**Files modified:** `build/aarch64/mkimage.sh`
**Commit:** aed40c38d
**Applied fix:** Deleted the dead line `trailer=$(dd if="$IMAGE" bs=1 skip=$((sz - 28)) count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')` — the live extraction is the `od -j` form on the next line, whose value overwrote the dd result unread. The 07-04 comment explaining why dd was abandoned (Harvey's dash-pair dd shadows POSIX dd on the devshell PATH) is kept verbatim; it remains the accurate rationale for the od path.
**Verification:** Tier 1 re-read (single-line deletion, surrounding block intact, od extraction untouched). Tier 2: `sh -n` and `bash -n` both pass. Byte-stability: the emitted image and the header/trailer assert path are unchanged — only dead code was removed.

### IN-02: subset-exec.sh defines the D-02 GREP idiom but barely uses it

**Files modified:** `build/aarch64/subset-exec.sh`
**Commit:** 8b22723c4
**Applied fix:** Mechanical substitution — all eleven bare host-side `grep` invocations in subset-exec.sh's own body now go through `"$GREP"` (resolved once at startup, line 177): the termrc self-heal probe (`-qF`), the srv9 startup poll, the gdbpoke log check, the failure-path marker extraction (`-oE`), and the seven final gate assertions (`-qiE` banner, `-q` prompt/stacksmoke/T1-OK-loop/T1-DONE/T1-FAIL, `-qiE` panic|trap). Diff is exactly 11 insertions / 11 deletions — invocation shape and arguments unchanged at every site.
**Documented exception:** one bare `grep -q 'Nbootfiles = 128' "$DEVROOT"` remains inside the quoted `GUEST_EOF` heredoc (line 595) — that text is the *generated* `subset-ns-rebake.sh`, a separate runtime script (run on the host on the native leg, rsync'd to the guest on darwin) where `$GREP` is neither exported nor expanded through the quoted heredoc. The reviewer excluded it from the finding's line list for this reason; fixing it would require the generated script to self-resolve GREP, which is beyond this finding's mechanical scope. Also untouched by design: guest-side rc sweep text (out of scope per the finding), the `SUBSET_FLAT` command-name data string, and prose comments mentioning grep.
**Verification:** Tier 1 re-read (all eleven sites converted; only the documented exception remains bare). Tier 2: `sh -n` and `bash -n` both pass. Functional probes (macOS host grep): the resolution line yields `/usr/bin/grep`, and each changed invocation shape (`-q`, `-qF`, `-oE`, `-qiE`) exercised against fixture input returns/matches as expected, including the miss case (rc=1). Smoke: `--print-platform` dry dispatch proof still passes (rc=0).

### IN-03: subset-exec.sh sentinel comment says "40 bytes"; the fixture is 41

**Files modified:** `build/aarch64/subset-exec.sh`
**Commit:** 6df5295e3
**Applied fix:** Measured the actual fixture first: `printf 'alpha bravo charlie\n__SUBSET_GREP_LINE__\n'` = 20 + 21 = 41 bytes (2 lines, 4 words), matching tier1-sweep.rc:241-243's own comment. Corrected the comment: `s/40 bytes/41 bytes/`.
**Verification:** Tier 1 re-read. Tier 2: `sh -n` + `bash -n` pass. Comment-only change — no emitted artifact bytes affected (the wc assert keys on `-l` = 2 only).

### IN-04: subset-exec.sh rebake comment undercounts the tier-1 bootdir (66 vs 70)

**Files modified:** `build/aarch64/subset-exec.sh`
**Commit:** 0b6be9e78
**Applied fix:** Counted the actual bootdir block: the `subset-bootdir.txt` heredoc carries exactly 70 `subset/` entries (25 + 37 h* + 4 fixed inputs + 3 canary h7* + tiny.s), matching the literal assert list at line 575. Took the reviewer's preferred option — the comment now states 70 and cites the assert list as the source of truth instead of counting in prose: "(25 + 37 h* + 4 fixed inputs + 3 canary h7* + tiny.s — the literal assert list above is the source of truth)".
**Verification:** Tier 1 re-read. Tier 2: `sh -n` + `bash -n` pass; `--print-platform` smoke passes. Comment-only change inside the generated rebake script's heredoc — the generated script is ephemeral (`$TMPD`, never committed, never byte-asserted), and its behavior is unchanged (comments only); the assert list itself is untouched. dir-coverage.txt and tier ledgers unaffected.

### IN-05: gethunk fixed-bin staleness key watches only obj.c

**Files modified:** `build/aarch64/gethunk-repro-6l.sh`
**Commit:** d0d186ccd
**Applied fix:** Extended the staleness key per the reviewer's first suggestion — the rebuild test now keys on the newest source in the whole 6l tree: `[ ! -x "$SCRATCH/fixed-bin/6l" ] || [ -n "$(find "$HARVEY_ROOT/sys/src/cmd/6l" -name '*.[ch]' -newer "$SCRATCH/fixed-bin/6l" 2>/dev/null)" ]`. This covers `asm.c` (the other half of the 06-09 LP64 fix, commit 778d4616b) and any future 6l source edit. The `[ ! -x … ]` short-circuit preserves the missing-binary path (find never runs without a valid `-newer` reference); `2>/dev/null` keeps find errors from false-triggering. Added a one-line comment noting why the key watches more than obj.c.
**Verification:** Tier 1 re-read. Tier 2: `sh -n` + `bash -n` pass. Functional probe of the exact test expression against a temp SCRATCH: absent binary → rebuild; binary newer than all sources → keep; binary older than asm.c (the IN-05 scenario) → rebuild. All three correct.

### IN-06: devroot.c carries a pre-existing debug `panic("whoops")` remnant

**Files modified:** `sys/src/9k/port/devroot.c`
**Commit:** d7e8f316e
**Applied fix:** Read the call site first. The `t < 0` guard in `rootgen` is unreachable by construction — `case Qdir` and `case Qboot` return early via devgen, so in `default:` the rootlist branch has path ≥ 1 (t ≥ 0) and the bootlist branch has path ≥ Qboot+1 (t ≥ 0). It is dead defensive code, not a load-bearing assertion on any reachable path — but it is also the only thing standing between a corrupt qid and a negative `Dirtab` index (`d = &l->dir[t]`), so deletion would trade a safe panic for kernel memory corruption in the impossible case. Chose the reviewer's "promote to a real guard" option over deletion (strictly safer for shared 9k kernel code, zero reachable-behavior change): dropped the debug `print`, tab-indented to the block's depth (was flush-left, space-formatted), brace-free single statement per the file's style, and gave the panic a diagnosable message matching surrounding conventions — `panic("rootgen: negative index %d (qid %#llux)", t, c->qid.path);` (`%#llux` for the vlong qid path is established 9k port usage: dev.c:215, devcons.c:1038, devproc.c:449/1191).
**Verification:** Tier 1 re-read of the full `rootgen` function (structure intact, indentation consistent with the adjacent `if(t >= l->ndir)` guard). Tier 2 unavailable — no host syntax checker handles Plan 9 C on macOS (needs the 6c toolchain and Plan 9 headers); per the 3-tier strategy Tier 1 is accepted, and the kernel build is the CI/linux-venue gate. No reachable path changes: the branch fires only on a condition that was already unreachable, and only its message changed.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-11-06T00:17:52Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
