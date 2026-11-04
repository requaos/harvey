---
status: testing
phase: 05-shell-boot-one-command-integration
source: [05-VERIFICATION.md]
started: 2026-11-03T17:35:00Z
updated: 2026-11-03T18:40:00Z
---

## Current Test

number: 1
name: Push harvey master to origin and observe the first hosted run of .github/workflows/r9-shell.yml on ubuntu-latest
expected: |
  The workflow's single step `nix run .#boot-r9-smoke` exits 0 — the run log carries
  'smoke-r9: ALL STAGES PASS — boot, echo, ls/ps/cat sweep, DEL safety, restart'.
  Record the run URL in 05-EVIDENCE.md (the PENDING FIRST PUSH slot).
  NOTE: this is also the FIRST execution of the pipeline on x86_64-linux anywhere
  (darwin-aarch64 and aarch64-linux are proven by committed clean-clone logs; the
  x86_64-linux package set has never been evaluated/run).
awaiting: user response

## Tests

### 1. Push harvey master to origin and observe the first hosted GH Actions run
expected: |
  `nix run .#boot-r9-smoke` exits 0 on ubuntu-latest; run log carries
  'smoke-r9: ALL STAGES PASS — boot, echo, ls/ps/cat sweep, DEL safety, restart'.
  Record the run URL in 05-EVIDENCE.md (the PENDING FIRST PUSH slot).
  Harvey is 217 commits ahead of origin — the hosted run exists only after a push.
  If the project accepts the native aarch64-linux pristine-clone substitute
  (05-13-linux-clean-clone.log, ALL STAGES PASS at dc8299575) in lieu of the hosted
  run, mark this test passed with that rationale — 05-VERIFICATION.md includes the
  override suggestion.
result: issue
reported: "Hosted run FAILED on ubuntu-latest (x86_64-linux — the never-before-executed arch leg): guest subset build died entering libString. Log tail: '== subset lib: libString' with zero mk output after it; driver reports 'error: guest subset build failed (rc=1)'; NO 'SUBSET-BUILD-FAIL: <dir>' line present in the log, so the guest script died without reaching its own fail() — suspicious of set -e kill or mk instant failure. Host toolchain bootstrap (6a/6c/.../7l via host gcc into hostbin-linux-x86_64) succeeded; libc/libbio/libregexp/libip/libndb/libmp/libsec all built green in the sudo-unshare namespace; failure is exactly at libString's mk invocation. darwin-aarch64 + aarch64-linux legs pass identically."
severity: blocker

### 2. Optional live-interactive sanity: run `nix run .#boot-r9` on this host and type at the % prompt
expected: |
  At the live `% ` prompt: type `echo hi`, `ls /bin`, `ps`, `exit`.
  Commands answer correctly; `exit` returns to a fresh % prompt via init's restart loop.
  NOTE: typed input has no console echo this era (documented in deferred-items.md —
  the donor's cooked-mode echo is deliberately absent; commands execute, input is
  invisible). Judge whether that is acceptable for the milestone's 'interactive
  shell' headline.
result: [pending]

## Summary

total: 2
passed: 0
issues: 1
pending: 1
skipped: 0
blocked: 0

## Gaps

- gap_id: G-05-1
  truth: "`nix run .#boot-r9-smoke` exits 0 on ubuntu-latest (x86_64-linux) with the ALL STAGES PASS marker in the run log"
  status: failed
  reason: "User reported: hosted run failed — guest subset build died entering libString with zero mk output; no SUBSET-BUILD-FAIL line emitted; rc=1. x86_64-linux-specific (darwin-aarch64 and aarch64-linux pass)."
  severity: blocker
  test: 1
  artifacts: []
  missing: []
