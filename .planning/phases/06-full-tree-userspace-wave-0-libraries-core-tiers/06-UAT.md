---
status: complete
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
source: [06-VERIFICATION.md]
started: 2026-11-05T14:35:00Z
updated: 2026-11-05T16:55:00Z
---

## Current Test

[testing complete]

## Tests

### 1. First hosted run of .github/workflows/phase6.yml on push: confirm wave0-host, tier-r9, and x86_64-poolpanic legs green on ubuntu-latest; confirm the tier-donor leg's behavior
expected: wave0-host / tier-r9 / x86_64-poolpanic green; tier-donor reds at the donor-pin precondition (`.build/9front-donor` absent on a clean runner) unless a native-linux donor-provisioning step lands first — CR-01 from 06-REVIEW.md. The fix-vs-accept decision (wire a native donor build into the tier-donor job, or accept the red leg as the first-push tripwire) is a maintainer call.
result: issue
reported: "wave0-host: red (error: .build/hostbin-linux-x86_64/bin not populated — run 'nix run .#setup' first) / tier-r9: green (OK) / x86_64-poolpanic: red (error: .build/hostbin-linux-x86_64/bin/pcc missing — run 'nix run .#setup' then 'nix run .#toolchain' first) / tier-donor: red (toolchain BUILDs run, then cpp fails: cc1: error: '-Wformat-security' ignored without '-Wformat' [-Werror=format-security]; objects never produced; ld.bfd cannot find cpp.o etc.; 'error: host toolchain bootstrap failed') [glibc _FORTIFY_SOURCE warning spam elided]"
severity: blocker

### 2. Host-class watch item: the committed dir-coverage.txt's venue line claims host-independence from a linux-aarch64 build host; the hosted wave0-host runner is linux-x86_64
expected: coverage regen + `git diff --exit-code` green on linux-x86_64, or a flipped per-dir build row reds BY DESIGN and the report's re-baseline standing rule applies (disclosed in 06-EVIDENCE.md as an honest watch item).
result: pass
notes: Observed on the runner (run 42068406653): the drift diff redded BY DESIGN with exactly three flips on linux-x86_64 — cmd/go build=ok→fail (a genuine x86_64-host finding, filed to the G-06-1 gap scope), jpg visited=1→3 (visitation-count machinery noise; verdict build=ok unchanged, and the header note line tracks the count). The by-design arm held: the drift gate is the intended venue-skew tripwire; the re-baseline standing rule applies.

## Summary

total: 2
passed: 1
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-06-1
  truth: "phase6.yml hosted run: wave0-host / tier-r9 / x86_64-poolpanic green on ubuntu-latest; tier-donor leg's behavior explained (CR-01 precondition red accepted, or donor provisioning wired)"
  status: failed
  reason: "User reported hosted run: tier-r9 green; wave0-host red (hostbin not populated — job lacks 'nix run .#setup'); x86_64-poolpanic red (pcc missing — job lacks setup+toolchain provisioning); tier-donor red EARLIER than CR-01's pin gate — host toolchain bootstrap fails at cpp under nixpkgs gcc hardening flags (cc1: -Wformat-security ignored without -Wformat, -Werror=format-security; objects never built; ld cannot find cpp.o; 'host toolchain bootstrap failed')"
  severity: blocker
  test: 1
  artifacts: []  # Filled by diagnosis
  missing: []    # Filled by diagnosis
