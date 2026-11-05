---
status: testing
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
source: [06-VERIFICATION.md]
started: 2026-11-05T14:35:00Z
updated: 2026-11-05T14:35:00Z
---

## Current Test

number: 1
name: First hosted run of .github/workflows/phase6.yml on push
expected: |
  wave0-host / tier-r9 / x86_64-poolpanic green; tier-donor reds at the donor-pin
  precondition (`.build/9front-donor` absent on a clean runner) unless a native-linux
  donor-provisioning step lands first — this is CR-01 from 06-REVIEW.md, confirmed in
  verification by reading the job (phase6.yml:127-152 has no donor clone/build step)
  against subset-exec.sh:174-177 (pin gate errors 'have missing'; requires
  $DIST/9qemu.u + $ROOTFS/arm64/bin).
awaiting: user response

## Tests

### 1. First hosted run of .github/workflows/phase6.yml on push: confirm wave0-host, tier-r9, and x86_64-poolpanic legs green on ubuntu-latest; confirm the tier-donor leg's behavior
expected: wave0-host / tier-r9 / x86_64-poolpanic green; tier-donor reds at the donor-pin precondition (`.build/9front-donor` absent on a clean runner) unless a native-linux donor-provisioning step lands first — CR-01 from 06-REVIEW.md. The fix-vs-accept decision (wire a native donor build into the tier-donor job, or accept the red leg as the first-push tripwire) is a maintainer call.
result: [pending]

### 2. Host-class watch item: the committed dir-coverage.txt's venue line claims host-independence from a linux-aarch64 build host; the hosted wave0-host runner is linux-x86_64
expected: coverage regen + `git diff --exit-code` green on linux-x86_64, or a flipped per-dir build row reds BY DESIGN and the report's re-baseline standing rule applies (disclosed in 06-EVIDENCE.md as an honest watch item).
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
