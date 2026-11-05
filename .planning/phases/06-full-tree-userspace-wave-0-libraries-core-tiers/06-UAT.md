---
status: testing
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
source: [06-VERIFICATION.md]
started: 2026-11-05T17:30:00Z
updated: 2026-11-05T17:30:00Z
---

## Current Test

number: 1
name: First hosted run of the rewritten phase6.yml (tier-9k leg)
expected: |
  All four legs green on ubuntu-latest: wave0-host, tier-9k, tier-r9,
  x86_64-poolpanic. Three legs already hosted-green at run 42089373924;
  the tier-9k venue is locally green (06-09, retained log
  evidence/06-09-tier-9k-local.log); the job self-prints failure digests
  to the step summary on red.
awaiting: user response

## Tests

### 1. First hosted run of the rewritten phase6.yml on push: confirm wave0-host, tier-9k, tier-r9, and x86_64-poolpanic legs green on ubuntu-latest
expected: all four legs green; the tier-9k leg's first hosted observation is honestly PENDING FIRST PUSH (05-13/06-08 precedent — recorded in 06-EVIDENCE.md). Push and watch `gh run list --workflow phase6-userspace`. On red, the tier-9k job's step summary carries the failure digest.
result: [pending]

## Prior Cycle (2026-11-05, pre-gap-closure — kept for history)

### A. First hosted run of the original phase6.yml (with the 9front tier-donor leg)
result: issue — wave0-host red (hostbin not populated; 'nix run .#setup' precondition), x86_64-poolpanic red (pcc missing), tier-r9 green, tier-donor red at donor provisioning. Resolution: G-06-1 gap closure (06-09/06-10) — the tier-donor leg was RETIRED per maintainer direction 2026-11-05 and replaced by the self-provisioned tier-9k job; wave0-host/poolpanic legs self-provision setup+toolchain. This is exactly what Test 1 re-observes.
severity: blocker (closed)

### B. Host-class watch item: dir-coverage.txt venue line on linux-x86_64 hosted runner
result: pass — drift diff redded BY DESIGN with exactly three flips (cmd/go build row, jpg visitation count); re-baseline standing rule applied; venue line now discloses host-class visit-count jitter (06-10).

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
