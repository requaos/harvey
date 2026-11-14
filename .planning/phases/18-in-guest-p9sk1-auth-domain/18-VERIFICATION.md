---
phase: 18-in-guest-p9sk1-auth-domain
verified: 2026-11-14T09:12:00Z
status: gaps_found
score: 8/9 must-haves verified
covered_files: [".github/workflows/r9-shell.yml", ".gitignore", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-01-PLAN.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-01-SUMMARY.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-02-PLAN.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-02-SUMMARY.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-03-PLAN.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-03-SUMMARY.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-04-PLAN.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-04-SUMMARY.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-05-PLAN.md", ".planning/phases/18-in-guest-p9sk1-auth-domain/18-05-SUMMARY.md", "build/x86_64/README.md", "build/x86_64/auth-sweep.rc", "build/x86_64/auth-termrc", "build/x86_64/authdom-donors/auth.h", "build/x86_64/authdom-donors/authsrv.h", "build/x86_64/authdom-donors/crypt.c", "build/x86_64/authdom-donors/des.c", "build/x86_64/authdom-donors/desCBC.c", "build/x86_64/authdom-donors/desmodes.c", "build/x86_64/authdom-donors/hmac.c", "build/x86_64/authdom-donors/libc.h", "build/x86_64/authdom-donors/libsec.h", "build/x86_64/authdom-donors/mp.h", "build/x86_64/authdom-donors/nvcsum.c", "build/x86_64/authdom-donors/os.h", "build/x86_64/authdom-donors/passtokey.c", "build/x86_64/authdom-donors/sha1.c", "build/x86_64/authdom-donors/sha1block.c", "build/x86_64/authdom-donors/strecpy.c", "build/x86_64/authdom-donors/u.h", "build/x86_64/authdomain-gen.c", "build/x86_64/authdomain-selftest.sh", "build/x86_64/authdomain.example", "build/x86_64/authprobe.c", "build/x86_64/mkimage.sh", "build/x86_64/randread.c", "build/x86_64/root-tree/lib/ndb/local.template", "build/x86_64/root-tree/lib/netaddr.rc", "build/x86_64/secstore-obj.txt", "build/x86_64/smoke-r9-auth.expect", "build/x86_64/stage-build.sh", "build/x86_64/tiers/tier2-services.txt", "flake.lock", "flake.nix", "nix/smoke-r9-auth-x64.sh"]
covered_digest: "v4:sha256:5b1f087fb70390c0cd556a7cab7729c94a27f04df2352340c47548d85538c97a"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "AUTH-08 / SC5 first half: secstore is available for persistent key storage beyond the baked keys"
    status: partial
    reason: "The substrate is green (ramfs venue live-probed per gate run, secuser account console-fed, secstored announcing 5356 — all in both 18-05 captures), but the client PUT/GET round-trip cannot complete: r9's devip never delivers SConn's donor two-write TCP pattern (2-byte count + payload), both procs park forever. Kernel bytes pinned at b2a6151; the phase's one FOD pass was consumed by 18-02. ALREADY RECORDED by project governance: REQUIREMENTS.md AUTH-08 unchecked (Pending) with annotation, STATE.md blocker entry, the gate's named-SKIP arm holds the verdict provably absent. Reopener: the next r9 kernel-byte pass (STATE names Phase 19's cpu path, which rides multi-write TCP, as the trigger)."
    artifacts:
      - path: "build/x86_64/auth-sweep.rc"
        issue: "legs 9d (client PUT/GET) disabled behind the AUTH-SKIP arm pending the devip fix (committed restore shape documented in the sweep comments)"
      - path: "../r9 (devip)"
        issue: "kernel-side defect, outside Harvey authority at the pinned b2a6151; isolation-matrix evidence retained at evidence/18-05-secstore-stall-modes.console.log (mode-1 single write round-trips, mode-2 two-write stalls)"
    missing:
      - "r9 devip fix for the two-write TCP client pattern, then restore the sweep's 9d legs and flip the gate's absent-assert to presence demands (the committed shape: fix devip -> restore PUT/GET -> assert 'secstore: saved', 'AUTH norbert', '[norbert] PUT'/'[norbert] GET', 'AUTH-OK secstore-roundtrip')"
  - truth: "AUTH-03 / 18-02 truth: caphash hostowner-only — the eve gate holds as a security boundary"
    status: failed
    reason: "CR-01 (18-REVIEW.md, disposition open), independently CONFIRMED in code by this verification: the #c/hostowner WRITE arm (r9 port/src/devcons.rs, QID_HOSTOWNER in devcons::write) stores any bytes from any process with no iseve() gate, no length bound, while iseve() (devcons.rs:288) compares current_user() against that same HOSTOWNER static — so a process mutated to a non-eve user by capuse re-writes /dev/hostowner to its own name and re-gains eve, reopening #¤/caphash. The donor's hostownerwrite (sys/src/9k/port/sysauth.c:148-165) is eve-gated; the module comment in devcons.rs even claims the write is 'guarded'. The boot-proven HOSTOWNER-GATE marker is therefore observably true but bypassable by one write to a file the same kernel serves."
    artifacts:
      - path: "../r9/port/src/devcons.rs"
        issue: "QID_HOSTOWNER write arm ungated (no iseve check, no Ebadarg length bound); iseve() base is the same static"
    missing:
      - "Gate the #c/hostowner write on iseve() with the donor's n<=0/n>=128 Ebadarg bound (r9-side fix; needs the next r9 kernel-byte pass), add the non-eve refusal host pin, and ideally a randread/gate leg asserting the refusal"
  - truth: "AUTH-02 / 18-01 truth: the entropy source is CPUID-gated (RDRAND detected from leaf-1 ECX bit 30)"
    status: partial
    reason: "CR-02 (18-REVIEW.md, disposition open), independently CONFIRMED in code by this verification: armed_source() (r9 x86_64/src/entropy.rs:108-110) binds cpuid(7,0)'s ECX into the cpuid1_ecx argument of classify(), so has_rdrand() (which correctly tests leaf-1 ECX bit 30) is fed the WRONG register — on RDRAND-without-RDSEED hardware the classifier silently downgrades to the jitter fold and prints the wrong armed label; a leaf-7-ECX-bit-30 CPU would arm an RDRAND path that #UDs. Both evidence venues classify correctly only by accident (KVM host carries RDSEED, which wins via the correctly-bound leaf-7 EBX; TCG qemu64 exposes neither bit). The pure helpers and the 6 host pins are correct and pass — the defect is exclusively the probe wiring in armed_source()."
    artifacts:
      - path: "../r9/x86_64/src/entropy.rs"
        issue: "armed_source(): 'let (_, ebx7, ecx1, _) = cpu::cpuid(7, 0);' — ecx1 is leaf-7 ECX; needs a fresh cpuid(1,0) call for the leaf-1 ECX (r9-side fix)"
    missing:
      - "One-line rebind: derive cpuid1_ecx from cpu::cpuid(1, 0) (keep leaf 7 for EBX); ideally add a pin over the probe wiring seam"
coincidental_reliance_items:
  - truth: "AUTH-02: the KVM evidence leg prints `random: source=rdrand` from real CPUID classification"
    reason: undeclared-precondition
    harden: "The rdrand label on KVM holds because the dev host carries RDSEED, which wins classification via the correctly-bound leaf-7 EBX — the RDRAND detection arm is never exercised on any evidence venue AND is mis-wired (CR-02). Declare the venue precondition (RDSEED-bearing host) or fix CR-02 and pin the leaf-1 probe wiring so the RDRAND arm is not load-bearing-by-luck."
---

# Phase 18: In-Guest p9sk1 Auth Domain Verification Report

**Phase Goal:** The x86_64 guest is a self-contained p9sk1 auth domain — one bake-time generator produces the machine key, `/adm/keys`, nvram-substitute, and ndb entries as a hash-paired unit so all four p9sk1 configs agree by construction; keyfs + authsrv serve it over loopback `/net`; the in-guest probe proves the handshake before any drawterm is ever attempted. Work spans both repos (r9 `/dev/random` + devcap; Harvey bake machinery + image).
**Verified:** 2026-11-14T09:12:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal's core outcome is REAL and evidenced: the generator exists and its committed self-test passed LIVE under this verification (exit 0, all four negative controls firing), keyfs starts non-interactively, authsrv answers tcp!*!567, cs resolves authdom from the baked ndb, the speaksfor hostid!=uid probe is green with its fail-closed deny control, tr-ok lines are on serial, and the gate was green twice at the final code state (evidence captures verified marker-by-marker; only docs commits follow the last code commit). Phase 19's entry criterion (loopback p9sk1 green before any drawterm) is met on AUTH-06/07 substance.

Three gaps remain, ALL r9-kernel-side, ALL sharing one reopener (the next r9 kernel-byte pass, STATE names Phase 19's cpu path): the AUTH-08 secstore round-trip (venue-blocked, honestly named-SKIPPED with structural gate teeth), and the two critical review findings CR-01/CR-02, which this verification independently confirmed in code rather than trusting the review text.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | AUTH-01: bake-time generator is the only way domains are made — machine key + /adm/keys + nvram-substitute + ndb entries as ONE hash-paired unit; DEMO loudly labeled; pairing fails loud | ✓ VERIFIED | `authdomain-gen.c` (901 lines, -o/-f/-V/-i), 17 vendored donor files, `.gitignore:/authdomain.local`; **self-test run live in verification: exit 0, GEN-SELFTEST-OK, LOCALFILE-PATH-OK, MISSING-F-REFUSED, LABEL-IN-NVRAM/MANIFEST-OK, all four NEG-CONTROL-REFUSED-{nvram,keys,manifest,truncated}**; mkimage §14 invokes the generator AT BAKE with the AUTHBAKE_DOCTOR teeth seam; commit interface documented in authdomain.example |
| 2 | AUTH-02: r9 /dev/random CSPRNG seeded from x86_64 entropy (no DTB), re-keyed from the DTB design, live on both accel legs | ✓ VERIFIED | entropy.rs hooks + main.rs registration + armed-source print confirmed in code; **6 entropy host pins passed live** (`cargo test -p x86_64 --bins -- entropy`: 6/6); all 4 substrate logs carry venue-correct labels (kvm-a/b: source=rdrand; tcg-a/b: source=jitter), READS-OK, substrate: DONE, zero FAIL; port/devcons.rs + aarch64/ untouched by 18-01's commits (git-verified). CAVEAT: CR-02 mis-wiring confirmed — see Gaps |
| 3 | AUTH-03: devcap #¤ (caphash/capuse) — the auth_chuid path | ✓ VERIFIED | devcap.rs donor-verbatim (error strings, FIFO-256, caphash LAST, eve remove hide), hmacsha1.rs KATs, namec '¤' arm under cfg(dev_cap), config dev=["exec","cap"]; **devcap+hmac filters passed live (15/15)**; all 4 legs of 18-02 evidence carry POST-OK/USE-OK/ONESHOT-REJECT/HOSTOWNER-GATE. CAVEAT: CR-01 eve-gate bypass confirmed — see Gaps |
| 4 | AUTH-04: keyfs starts non-interactively over baked /adm/keys; authsrv listens on tcp/567 | ✓ VERIFIED | both 18-04/18-05 captures: `authdom: PAIRED DEMO`, `3 keys read`, `AUTH-OK keyfs`, `AUTH-OK authsrv-listen`; zero occurrences of `can't read NVRAM, please enter machine key` (never-appears post-pass in smoke-r9-auth.expect:369); sweep wires nvram= before keyfs, listen1 -t tcp!*!567 authsrv -d, secstored -v |
| 5 | AUTH-05: guest domain ndb content staged in the image | ✓ VERIFIED | local.template authdom=@AUTHDOM@/auth=127.0.0.1/ether=@ETHER@ rows, netaddr.rc ether= single home, tier leaf cmd/aux:listen1; both captures: `AUTH-CSOBS ... authdom=DEMO-harvey auth=127.0.0.1` -> `AUTH-OK cs` — cs ANSWERS from the baked file (a live client interaction, not file presence) |
| 6 | AUTH-06: in-guest loopback p9sk1 probe green before any drawterm; non-hostowner speaksfor gate + fail-closed control | ✓ VERIFIED | both 18-05 captures: `ticket request using norbert@DEMO-harvey key succeeded` -> AUTH-OK p9sk1-norbert; `authprobe: SPEAKSFOR-OK bootes for norbert`; exactly 1 SPEAKSFOR-DENIED (count_occurrences assert); `no speaks for` tr-fail line present; authprobe.c self-speaks guard verified at :120 + t.num/cuid/suid assertions |
| 7 | AUTH-07: serial-visible auth logging from day one | ✓ VERIFIED | both 18-05 captures carry 4 tr-ok syslog tokens, the PAIRED banner, ANNOUNCE /net/tcp!*!5356 — through syslog's #c/cons fallback (no writable /sys/log staged, mkimage 14l refuses) |
| 8 | AUTH-08: secstore available for persistent key storage beyond baked keys | ✗ FAILED (partial) | Substrate green in both captures (AUTH-VENUEOBS ramfs-file-write-ok, `change written`, AUTH-OK secuser, mntgen-refusal evidence retained) but the client PUT/GET round-trip is venue-blocked (r9 devip two-write TCP defect, kernel pinned b2a6151) — AUTH-SKIP secstore-roundtrip in both captures, the gate asserts the OK verdict PROVABLY absent; isolation-matrix evidence: mode-1 single write round-trips, mode-2 two-write stalls. RECORDED: REQUIREMENTS Pending, STATE blocker, reopener = next r9 kernel-byte pass |
| 9 | AUTH-09: writable-/adm + nvram-substitute scoping decided and documented | ✓ VERIFIED | README.md `## Auth domain (Phase 18: AUTH-01..AUTH-09)` section + PROJECT.md Key Decisions row: "host-9P /adm mount for REAL use — DOCUMENTED, NOT WIRED"; docs do not promise wiring that does not exist |

**Score:** 8/9 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `../r9/x86_64/src/entropy.rs` | RandomHooks rng_seed/jitter + pins | ✓ VERIFIED | 334 lines, 6 pins passed live; armed_source probe wiring defect (CR-02) noted as gap |
| `../r9/port/src/devcap.rs` | donor-verbatim cap device | ✓ VERIFIED | verbatim error strings, MAXHASH=256, caphash LAST; 10-class pins passed live |
| `../r9/port/src/hmacsha1.rs` | hand-rolled SHA-1/HMAC + KATs | ✓ VERIFIED | FIPS abc + RFC 2202 vectors pinned; 5 pins passed live |
| `build/x86_64/authdomain-gen.c` | generator -o/-f/-V/-i | ✓ VERIFIED | self-test green live; 112-byte guest-ABI nvram + feed artifact |
| `build/x86_64/authdom-donors/` (17 files) | vendored donor crypto | ✓ VERIFIED | byte-verbatim donors + shims (review cross-checked byte-identity vs in-tree sources) |
| `build/x86_64/auth-termrc`, `auth-sweep.rc`, `smoke-r9-auth.expect`, `nix/smoke-r9-auth-x64.sh` | the gate chain | ✓ VERIFIED | all marker emitters + invocations verified in code; flake app boot-r9-auth-x64 wired (flake.nix:385,443) |
| `build/x86_64/authprobe.c` | speaksfor C client | ✓ VERIFIED | self-speaks guard + cuid/suid assertions verified at source |
| `.github/workflows/r9-shell.yml` | auth CI leg at TCG | ✓ VERIFIED | auth-smoke-x64 job, `env R9_ACCEL=tcg nix run .#boot-r9-auth-x64`, pinned actions (hosted run PENDING FIRST PUSH — recorded convention) |
| `evidence/` (14 files) | green-twice captures + blocker evidence | ✓ VERIFIED | all 8 substrate logs + 4 auth logs marker-verified; 2 blocker logs substantiate the devip defect; 18-05 captures password-redacted (T-18-13) with asserts run over the true capture |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| generator (18-03) | mkimage §14 bake | authdomain-gen invoked at bake + -V over staged copies | ✓ WIRED | mkimage.sh:1387-1453 verified; AUTHBAKE_DOCTOR teeth seam committed |
| bake | boot pairing check | auth-sweep leg 1 sha1 recompute vs manifest | ✓ WIRED | sweep:169-172; PAIRED DEMO in all captures |
| nvram machkey | keyfs | nvram=/adm/nvram plain assignment before keyfs, no -p | ✓ WIRED | sweep:190; `3 keys read` in all captures |
| listen1 | authsrv -d | tcp!*!567 announce, flags ride via exec | ✓ WIRED | sweep:277; connect-accept AUTH-LISTENOBS in captures |
| sentinel feed | auth/debug + factotum | /boot/authfeed.txt + R9_DEMO_PW driver export | ✓ WIRED | driver:204-208; mkimage 14f2b host-side feed copy |
| netaddr seam | baked /lib/ndb/local | @ETHER@/@AUTHDOM@ substitution + venue-literal greps | ✓ WIRED | template:47,50; netaddr.rc:76; cs answers in captures |
| namec '¤' | devcap | registry_attach cfg(dev_cap) arm | ✓ WIRED | namec.rs:88-89; 4 cap markers on all 4 legs |
| x86_64 entropy | devcons DRBG | set_random_hooks in main's boot-facts window | ✓ WIRED | main.rs:209-218; READS-OK from ring 3 in all 4 legs |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| mkimage §14 | /adm/{nvram,keys,domain.manifest}, /lib/ndb/{auth,local} | authdomain-gen run per bake | Yes — pairing verified at bake AND boot | ✓ FLOWING |
| auth-sweep | pairing/keys/listeners/cs/factotum verdicts | live in-guest reads + dials | Yes — markers only on assertion success | ✓ FLOWING |
| entropy.rs | DRBG seed | RDRAND/RDSEED/TSC via CPUID classification | Yes on evidence venues — classification mis-wired for RDRAND-only hardware (CR-02) | ✓ FLOWING (defect noted) |
| devcap capuse | user mutation | HMAC match over posted hash | Yes — #c/user readback `norbert` live | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Generator self-test (AUTH-01) | `sh build/x86_64/authdomain-selftest.sh` | exit 0; GEN-SELFTEST-OK + all 4 negative controls + local-file path | ✓ PASS |
| devcap + hmac pins (AUTH-03) | `nix develop --command sh -c 'cargo test -p port --lib -- devcap hmac'` | 15 passed; 0 failed | ✓ PASS |
| entropy pins (AUTH-02) | `nix develop --command sh -c 'cargo test -p x86_64 --bins --target x86_64-unknown-linux-gnu -- entropy'` | 6 passed; 0 failed | ✓ PASS |
| Boot gates (qemu) | not re-run by verifier (minutes-long VM boots; fast-check constraint) | retained captures at final code state verified marker-by-marker | ✓ PASS (capture-based) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention in this repo; the phase's probe machinery is the xtask boot-test + the committed expect gate, both evidenced above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|---------------------|----------|
| AUTH-01 | 18-03, 18-04 | hash-paired domain generator | ✓ SATISFIED | self-test live green; bake arm wired |
| AUTH-02 | 18-01 | r9 /dev/random from x86_64 entropy | ✓ SATISFIED (with CR-02 defect open) | 4 substrate logs + 6 live pins |
| AUTH-03 | 18-02 | devcap #¤ auth_chuid path | ✓ SATISFIED (with CR-01 defect open) | 10 live pins + 4 boot legs |
| AUTH-04 | 18-04 | keyfs non-interactive; authsrv tcp/567 | ✓ SATISFIED | captures + wiring |
| AUTH-05 | 18-04 | ndb content staged | ✓ SATISFIED | cs answers live |
| AUTH-06 | 18-05 | loopback p9sk1 probe green pre-drawterm; speaksfor | ✓ SATISFIED | both captures; authprobe guard verified |
| AUTH-07 | 18-04, 18-05 | serial-visible auth logging | ✓ SATISFIED | tr-ok x4, banner, ANNOUNCE |
| AUTH-08 | 18-05 | secstore for persistent key storage | ✗ PARTIAL-BLOCKED (matches REQUIREMENTS.md Pending) | substrate green; round-trip venue-blocked (recorded STATE blocker) |
| AUTH-09 | 18-05 | scoping decided + documented | ✓ SATISFIED | README AUTH section + PROJECT.md row |

No orphaned requirements: all nine AUTH IDs appear in plan frontmatter; REQUIREMENTS.md statuses match the evidence (AUTH-08 Pending, others Complete).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none — no unreferenced TBD/FIXME/XXX, no placeholders, no stub returns in phase files) | | | | mktemp `XXXXXX` templates are false positives, not debt markers |
| .planning/.../18-REVIEW.md | | untracked in git (working tree) | ℹ️ Info | the review report itself awaits the orchestrator's docs bundle; the DISPOSITION is committed |

### Prohibition Verdicts (ADR-550, non-authoritative LLM-judge — human review recommended)

All 17 judgment-tier prohibitions across the five plans were judged against the code: **all KEPT** — no new random device/qid (random stays devcons QIDs), no statistical battery (distinctness only), aarch64 untouched (git-verified empty diff across all six r9 phase commits), no time-based cap expiry (ticks recorded, never read), no new crates, donor crypto compiled not rewritten (17 vendored files, cross-validated byte-identical), no real key material in git (gitignore + placeholders + zero repo-tree writes asserted by the self-test), no writable /sys/log (14l refuses), nvram prompt provably absent, no speculative SERVICES (exportfs/srv binaries staged inert per the plan's own staging list — service topology stays 567+5356), SPEAKSFOR-OK unreachable from self-speaks (guard at authprobe.c:120), no secstore green without bytes-back (absent-assert structural), deny control fires exactly once, docs state documented-not-wired. Two soft notes: the venue-literal prohibition has one recorded exception (IN-02: a 192.168.237.1 probe address in auth-sweep.rc, info-level open), and the IN-01 CI comment overstates the round-trip as exercised. Per the autonomous-verify rule these verdicts are NON-AUTHORITATIVE — flagged `unverified-prohibition` for the end-of-phase human checkpoint; none reverses a truth.

### Gaps Summary

All three gaps are r9-kernel-side and share ONE reopener — the next r9 kernel-byte pass (STATE names Phase 19's cpu path, which rides multi-write TCP, as the trigger):

1. **AUTH-08 secstore round-trip (FAILED-partial)** — substrate green, client PUT/GET blocked by the devip two-write defect. Already recorded everywhere (REQUIREMENTS Pending, STATE blocker, gate SKIP arm). Not deferred per Step 9b: Phase 19's roadmap text does not name the secstore round-trip or the devip fix as a success criterion (its cpu criteria imply it at most).
2. **CR-01 eve-gate bypass (FAILED)** — ungated #c/hostowner write defeats the devcap hostowner gate; confirmed in code this verification; disposition open; fix is a small r9 devcons change plus pins.
3. **CR-02 entropy mis-wiring (FAILED-partial)** — armed_source() feeds leaf-7 ECX to the leaf-1 RDRAND test; confirmed in code this verification; evidence venues masked; one-line r9 fix.

**Escalation decision for the developer:** the project's own governance deliberately recorded gap 1 with a reopener and the review left CR-01/CR-02 open. Options: (a) accept all three as tracked open items and let the Phase 19 kernel pass close them (add overrides to this file's frontmatter to accept formally), or (b) run `/gsd:plan-phase --gaps` to plan an interstitial r9 kernel fix round (CR-01/CR-02 are small, well-specified fixes; AUTH-08's devip fix is larger and Phase 19 needs it anyway). Note also: the CI leg auth-smoke-x64 is PENDING FIRST PUSH (recorded convention), and SECURITY.md does not exist (secure-phase warning posture — a project-level note, not a phase gap).

---

_Verified: 2026-11-14T09:12:00Z_
_Verifier: Claude (gsd-verifier)_
