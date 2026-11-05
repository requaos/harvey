---
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
fixed_at: 2026-11-05T23:46:29Z
review_path: .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-11-05T23:46:29Z
**Source review:** .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 2 (fix_scope=critical_warning; review carried 0 critical, 2 warning, 6 info — Info items out of scope)
- Fixed: 2
- Skipped: 0

**Verification venue:** main checkout (`/Users/neilskinner/code/harvey`, branch master), darwin-aarch64. `workflow.use_worktrees=false`, so no isolated worktree was created — edits and commits landed directly on master per project instruction (normal commits, hooks ran). Both edited scripts are linux-venue harnesses whose full execution requires the lima guest or native linux; verification here is static (parse checks + diff-scope proof), with CI/lima as the exercising gate. Numbers below are reproducible from the main checkout.

## Fixed Issues

### WR-01: gethunk libc-provisioning block's error handling is dead under `set -e`

**Files modified:** `build/aarch64/gethunk-repro-6l.sh`
**Commit:** 984e62eb3
**Applied fix:** Wrapped the `RUN_BUILD_IN_PRIVATE_NAMESPACE` invocation in the `set +e … RC=$? … set -e` idiom, mirroring the script's own sibling harness captures verbatim (the two `verify` legs at former lines 289-292 and 310-313), so a namespace-build failure now reaches the named error (`error: libc namespace provisioning failed (rc=$RC)`, exit 2) and the `rm -f "$NSLIBC"` temp-file cleanup instead of aborting silently under `set -e`. Added a 3-line comment citing the idiom. Fix text matches the reviewer's suggestion exactly, tab-indented to the block's 3-tab depth.
**Verification:** Tier 1 re-read (wrapper in place, surrounding block intact). Tier 2: `sh -n` and `bash -n` both pass. Smoke: no-arg invocation still prints usage and exits 2. Behavior change is control-flow reachability only — the success path is byte-identical.

### WR-02: coverage-sweep.sh unconditionally overwrites the host's /bin/cpp outside the namespace

**Files modified:** `build/aarch64/coverage-sweep.sh`, `build/aarch64/nsrun.sh`
**Commit:** 76ab66aa7
**Applied fix:** Full fix via the reviewer's preferred route — the in-namespace bind-mount pattern, not a gated host cp.

- `nsrun.sh` (the shared namespace entry for **both** venue legs — native-linux `nsrun.sh --wrap` at coverage-sweep.sh:406 and darwin→lima via vm-run.sh:83, plus subset-build/subset-exec/pre-gate/stage-build): added a cpp bind immediately after the established `/bin/rc` bind, mirroring it exactly (`[ -e /bin/cpp ] || touch /bin/cpp; mount --bind "$HARVEY_LINUX_BIN/cpp" /bin/cpp`). The bind is conditional on `$HARVEY_LINUX_BIN/cpp` being executable (`set -u`-safe `${HARVEY_LINUX_BIN:-}` guard) so pre-toolchain namespace uses are unaffected. `HARVEY_LINUX_BIN` is available in nsrun.sh's root phase on every path: exported by the devshell shellHook (flake.nix:170), explicitly exported by coverage-sweep.sh:94-95 / subset-build.sh:64-65 / subset-exec.sh:230-231 on native legs, and captured+re-sourced via nsrun.sh's `$ENVFILE` mechanism. `BUILDTOOLCHAIN` builds cpp (sys/src/cmd/cpp/BUILD installs to `$HARVEY_LINUX_BIN`), so every consumer's toolchain-ensure populates it.
- `coverage-sweep.sh`: deleted the unconditional `sudo cp "$HARVEY_LINUX_BIN/cpp" /bin/cpp`; kept the hard early error when hostbin cpp is missing (native leg bootstraps the toolchain when 7c/ar are absent, and BUILDTOOLCHAIN now covers cpp). Updated the comment block to document the bind-mount provisioning.

**Behavior parity on both venue paths:**
- *Native-linux leg:* previously the host's `/bin/cpp` was overwritten so the namespace (sharing distro `/bin`) saw Harvey's cpp; now the bind makes the in-namespace `/bin/cpp` Harvey's cpp. Identical effective in-namespace state, zero host mutation.
- *Darwin/lima leg:* coverage-sweep.sh provisioned nothing host-side before (the guest's persistent `/bin/cpp` was Harvey's cpp from prior `nix/build.sh` full-build runs on the authoring VM — 02-06-SUMMARY.md). The bind makes that deterministic: any guest whose toolchain ensure has run gets Harvey's cpp in-namespace, matching the authoring venue's actual state. On the authoring VM itself the in-namespace cpp is unchanged (already Harvey's).

**Report byte-stability (CI drift gate):** `git diff` on coverage-sweep.sh is a single hunk (`@@ -396,9 +396,8 @@`) confined to the host-side provisioning block before nsrun entry; report generation (the COVERAGE-LOG extraction, row parsing, and the entire output heredoc, lines 404+) is untouched, so emitted `dir-coverage.txt` bytes are identical given identical sweep data. nsrun.sh's diff is a pure 16-line addition after the rc bind. The sweep itself must be re-run on linux/CI to regenerate evidence, but no committed bytes change.

**Verification:** Tier 1 re-read of both modified sections. Tier 2: `bash -n` on nsrun.sh, `sh -n` + `bash -n` on coverage-sweep.sh — all pass. Smoke: nsrun.sh argument-validation paths unchanged (bare invocation and `--wrap` without command both print usage, rc=1). Diff-scope checks as above. Not run: the full sweep/gethunk gates (linux-only venues; CI exercises them).

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-11-05T23:46:29Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
