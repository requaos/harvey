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
  artifacts: [.github/workflows/phase6.yml, sys/src/cmd/cpp/BUILD, sys/src/cmd/go/mkfile, build/aarch64/gethunk-repro-6l.sh, sys/src/BUILD_SETUP_NAMESPACE, build/aarch64/coverage-sweep.sh]
  missing: []
  diagnosis: |
    RESOLVED on the runner (run 42089373924: wave0-host / tier-r9 / x86_64-poolpanic all green) — five root causes, each evidence-driven:
    1. wave0-host/poolpanic lacked 'nix run .#setup' (+.#toolchain) provisioning on clean runners (hostbin absent; dev hosts blind — pre-populated dirs).
    2. cpp/BUILD's -Wno-format collides with the nix cc wrapper's injected -Werror=format-security (cc1 hard error; objects never built). Fixed per the unix/9cc/BUILD precedent (-Wno-error=format-security). Reproduced on lima.
    3. gethunk 6l verify needed amd64/lib/libc.a on a clean checkout — self-provisions via the namespace now (NS_TARGET hook in BUILD_SETUP_NAMESPACE; NS_HBIN recomputed from HARVEY_ROOT because the repro overrides HARVEY_LINUX_BIN with its scratch dir; amd64/lib mkdir'd first).
    4. cmd/go's mkfile aborted the whole amd64 cmd stage on go-present hosts whose fetched repos are absent ('ls edwood' failure; runner images ship /bin/go) — plan9port mk abort-on-first-failure → ipconfig never built → kernel link failed. Both loops now test -d and skip. Verified with a /bin/go stub.
    5. coverage drift gate flipped on per-dir visit-count jitter (watchdog/second-chance timing — jitter reproduced run-to-run on ONE lima host) + pcc's absolute /bin/cpp exec hitting the distro's gcc cpp inside the namespace ('cannot execute cc1'). Gate now diffs count-normalized copies; NATIVE_LINUX sweep provisions /bin/cpp with Harvey's.
    REMAINING: tier-donor leg reds at the donor-pin precondition (CR-01 — no step provisions .build/9front-donor on a clean runner). Maintainer decision: wire native donor provisioning, or accept the red leg as the first-push tripwire.
    maintainer_direction: |
      2026-11-05, user: 9front is the donor ONLY because Harvey lacked local arm64/aarch64 support; on amd64/x86_64 CI the donor evidence should come from HARVEY's OWN kernel (9k10cpu — proven booting on the runner by the poolpanic leg), not 9front. Deliberate direction: focus on harvey + r9, avoid borrowing 9front-specific design decisions that deviate from Harvey's faithful Plan 9 4e implementation. Gap-closure reading: replace/augment the 9front tier-donor CI leg with a Harvey-kernel tier venue on x86_64 (amd64 tier payload swept on 9k10cpu); the aarch64 venues stay 9front-donor locally + r9 in CI (tier-r9 green).
