---
status: testing
phase: 16-host-net-modes-networking-exit-gate
source: [16-VERIFICATION.md]
started: 2026-11-11T15:30:00Z
updated: 2026-11-11T15:30:00Z
---

## Current Test

number: 1
name: Hosted-CI observation of the pushed phase (net-smoke-x64 green on ubuntu-latest/TCG + pin-advance observation at 208ceba)
expected: |
  Push the 16 local commits on harvey master, then watch the GitHub Actions run:
  - the `net-smoke-x64` job (r9-shell.yml) runs green on ubuntu-latest at TCG
    (R9_ACCEL=tcg per OQ-2) — HNET-01's "green in hosted CI" leg;
  - the pin-advance CI observation at r9 208ceba (the WR-02 fix pin) completes
    the PENDING FIRST PUSH item carried from 16-04/16-06.
  No checkout-local command can execute a hosted-runner leg; the local halves
  are fully proven (job authored, actionlint-clean, SHA-pinned, app green twice
  with retained captures at evidence/16-06-netsmoke-a/b.log).
awaiting: user response

## Tests

### 1. Hosted-CI observation of the pushed phase
expected: Push harvey master (16 commits ahead) and observe the `net-smoke-x64` CI job green on hosted TCG, plus the pin-advance observation at r9 208ceba.
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
