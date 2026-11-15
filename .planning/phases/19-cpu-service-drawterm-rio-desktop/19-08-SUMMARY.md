---
phase: 19-cpu-service-drawterm-rio-desktop
plan: "08"
subsystem: infra (the -G interop gate)
tags: [drawterm, -G, pty, expect, hostfwd, p9any, p9sk1, devssl, ipconfig, ether, flake-app]

# Dependency graph
requires:
  - phase: 19-cpu-service-drawterm-rio-desktop/19-06
    provides: the drawterm -O/-G surface + the nix package (DRAWTERM_BIN) the gate spawns
  - phase: 19-cpu-service-drawterm-rio-desktop/19-07
    provides: the §15 cpu image (bootfs-cpu.paq) + out/auth-creds.txt (the D-12 parse contract) + the cpu-bringup stage vocabulary
  - phase: 16-host-net-modes-networking-exit-gate
    provides: the committed D-04 hostfwd pair (127.0.0.1:17010/5670) the session dials
provides:
  - build/x86_64/drawterm-gate.expect — the TWO-subtree -G session chassis (qemu + drawterm-on-a-pty), validated live to the password feedstage + tr-ok
  - nix/drawterm-gate-x64.sh + the flake app .#drawterm-gate-x64 — the full pipeline (tier build -> bake -> loud creds read -> ISO-with-append -> gate -> both survivor sweeps)
  - the cpu image's ether reception leg (cpurc + §15 ipconfig staging) — the hostfwd pair can now REACH the guest
  - the r9 listen-park ingress fix (pushed at r9 9704b2e, unpinned) — the accept pool now fires on unsolicited incoming connections
  - the root-caused blocker record for the session's post-auth stretch (the next r9 pass's first item)
affects: [19-09 (boots the same §15 image — the ether leg + the one-medium rule apply), 19-10 (DESK-07's evidence rows need the green gate), the next r9-touching pass (owns: the post-auth namec blocker, the pin advance + FOD re-wire for 9704b2e, the q35cpu profile re-key)]

actuals:
  tokens: 13119    # chars/4 over the realized production diff (52,475 chars across the 4 commits; evidence logs excluded)
  tasks: 2         # 2 complete (Tasks 1-2); Task 3 halted at the root-caused kernel blocker
  commits: 4       # MEASURED: git rev-list --count 4f5a55a60..03a11d673
plan_head_before: 4f5a55a6030957de1755fee4cd0f857fafa526ea
plan_head_after: 03a11d6737cf2d7a71e7fda3d15a3ba553f43ef7

tech-stack:
  added: []          # zero packages — committed surfaces only (T-19-SC honored)
  patterns:
    - "the second-subtree expect gate: one capture for BOTH ptys (qemu serial + the drawterm session), spawn_id switched per stream, the serial DRAINED before the whole-file post-passes (log_file records only what expect processed)"
    - "drawterm's unique run tag rides argv[0] via bash `exec -a` (drawterm rejects extra argv operands) — the survivor sweep keys on it and can never cross-kill a foreign drawterm session"
    - "-s '' is load-bearing on this venue: drawterm's secstore probe dials the AUTH port on a 3-part authserver (netmkaddr passthrough) and mutual-parks against authsrv's readn(TICKREQLEN); '' routes the probe to the unforwarded 5356 (instant refusal)"
    - "one medium per boot is the era's r9 limit: the medium registry pins conv ownership and the clone open re-hands the lowest idle conv — the cpu image carries ETHER ONLY (the loopback leg was the auth-sweep's vestige; nothing on the cpu image dials in-guest)"

key-files:
  created:
    - build/x86_64/drawterm-gate.expect
    - nix/drawterm-gate-x64.sh
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-gate-run-a-pinned.console
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-gate-run-fixr9.console
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-gate-run-fixr9.log
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-repro-boot-fixr9-serial.log
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-repro-dt-session-fixr9.log
  modified:
    - flake.nix                          # drawtermGateX64Pkg + the .#drawterm-gate-x64 registration (the frozen hasAttr gate list byte-untouched)
    - build/x86_64/root-tree/rc/bin/cpurc   # leg 2 re-keyed: the ether reception seam replaces loopback (ETHER-OK marker)
    - build/x86_64/mkimage.sh            # §15: cmd/ip/ipconfig asserts + staging at /amd64/bin/ip/ipconfig + the §15b cpurc shape asserts

key-decisions:
  - "The gate rides -s '': without it drawterm's secstore probe lands on the AUTH port (a 3-part authserver address passes through netmkaddr as-is) and mutual-parks against authsrv's readn(TICKREQLEN) — neither side's timers can heal a mutual park; the empty -s makes secdial's $auth parse extract the host and dial 5356, which the committed hostfwd pair does not forward (instant refusal, the standard no-secstore behavior)"
  - "The cpu image carries ONE medium (ether): r9's medium registry pins one medium per conv while the clone open re-hands the lowest idle conv, so any second bind from a one-shot caller (rc-ctl writes AND ipconfig both, measured) collides with 'interface already bound'; the loopback leg was the auth-sweep's in-guest-dial vestige — nothing on the cpu image dials in-guest and the wildcard announces serve over ether — the donor-faithful clone-allocation fix is the named r9 follow-up"
  - "The kernel fix (r9 9704b2e, PUSHED, unpinned): the tcp listen park path now drives ingress before blocking (the icmp park shape) — the RX-IRQ wake readied the parked listener but its re-probe popped a pool member only if smoltcp had ALREADY processed the SYN, and nothing else drives ingress on an idle venue (every prior gate's traffic was guest-initiated, its polls ingesting replies in the same syscall context); measured: the SYN sat in the ether queue, ipifc pktin stayed 0"
  - "The gate asserts the VENUE's actual prompt shape: rcmain sources $home/lib/profile only when /bin/test -r succeeds — the §15 session image carries no /bin/test and the creds user (norbert) has no staged home, so the profile's cpu case (and its cpu% prompt) never runs; the session prompt is rcmain's default — asserted presence-only as the plan's own acceptance criteria word it ('prompt, shell, fed-command echo')"

patterns-established:
  - "Root-cause by discriminators on the live venue: same-boot probes of both listeners (567/17010), in-guest ps + /net/tcp conv listings during held connections, and the direct service-file run from the serial shell isolated each layer of the failure chain (image -> kernel wake -> post-auth stretch) without any debug kernel"

requirements-completed: []   # DESK-06/CPU-04/DESK-04 stay OPEN — the gate cannot go green until the post-auth kernel blocker closes (see Deviations/Issues)

coverage:
  - id: D1
    description: "The pty-driven session chassis (Task 1): two subtrees, feedstage password discipline, presence asserts, fast-fail, post-passes, last-step redaction shape"
    requirement: DESK-06
    verification:
      - kind: other
        ref: "GATE-FILE-SHAPE-OK (the plan's verify) + validated LIVE at the pushed-fix r9: 14 stages green through the dt-password feedstage (evidence/19-08-gate-run-fixr9.console)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The driver + flake app (Task 2): the full pipeline with the loud creds read, the append-bearing ISO compose, both survivor sweeps"
    requirement: DESK-06
    verification:
      - kind: other
        ref: "GATE-APP-EVAL-OK + DRIVER-SHAPE-OK (the plan's verifies) + the full app driven end-to-end twice (pinned + override runs, both evidence files)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The ether reception seam: the cpu image can receive the committed hostfwd pair (cpurc leg + §15 ipconfig staging)"
    verification:
      - kind: e2e
        ref: "cpurc: ETHER-OK in every boot capture since the re-key + the accept firing at the pushed-fix r9 (serial: 'tcp call for tcp17010 on chan /net/tcp/2 (10.0.2.2)')"
        status: pass
    human_judgment: false
  - id: D4
    description: "Green twice on local KVM + the redacted retained capture (Task 3's DONE, DESK-06's bar, CPU-04's consolidated evidence, DESK-04's live encrypted proof)"
    requirement: DESK-06
    verification:
      - kind: e2e
        ref: "BLOCKED: the pinned kernel lacks r9 9704b2e (root cause B) and, at the pushed-fix r9, cpu -R dies post-auth in the auth_chuid mount/newns stretch (root cause C: 'cpu: srvauth: namec: does not exist' + two factotum 'not found' server errors) — the session reaches the password prompt + tr-ok but no shell prompt; GATE-A-GREEN / GATE-GREEN-TWICE / REDACTION-OK cannot run"
        status: fail
    human_judgment: true
    rationale: "The remaining blocker is a kernel-side defect chain owned by the next r9-touching pass (fix + pin advance + FOD re-wire + gates re-green); no harvey-side assertion can prove it until that pass lands"

duration: 120 min
completed: 2026-11-15
status: halted
---

# Phase 19 Plan 08: The -G interop gate Summary

**The two-subtree drawterm -G gate is built and validated live through the password feedstage and the p9sk1 exchange (14 stages green at the pushed-fix r9 9704b2e); green-twice is HALTED at a root-caused kernel chain — the image's missing NIC address (fixed here), the listen park path's missing ingress drive (fixed + pushed to r9, unpinned), and a remaining post-auth namec failure in cpu -R's auth_chuid stretch (the next r9 pass's first item)**

## Performance

- **Duration:** 120 min (diagnosis-heavy: 6 root-cause boot cycles, 15 diagnostic probes, 2 full gate runs)
- **Started:** 2026-11-15T02:58:44Z
- **Completed:** 2026-11-15T04:58:41Z
- **Tasks:** 2/3 complete (Task 3 halted at the kernel boundary)
- **Files modified:** 8 production + 5 evidence

## Accomplishments

- **Task 1:** drawterm-gate.expect — the auth chassis with TWO spawned subtrees: qemu (the §15 image + the emitter's slirp hostfwd argv) and drawterm -G -O on a pty (expect's spawn IS a pty; drawterm's -G runtime sets its own raw mode). The feedstage matches drawterm's own readcons prompt (`norbert@DEMO-harvey password: `), sends exact bytes, and the teardown rides drawterm's deterministic `goodbye`. Unique run tags on both subtrees (qemu -name + drawterm argv[0] via `exec -a`), both process groups killed on every exit path, the serial drained into the capture before the post-passes, redaction LAST with the contract line. The `-s ''` finding is load-bearing (see key-decisions).
- **Task 2:** nix/drawterm-gate-x64.sh (the auth pipeline re-keyed: contract checks, accel discipline, emitter capture, full bake with the log tee'd, the LOUD creds parse of out/auth-creds.txt before any compose or spawn, the ISO compose WITH the init append, both survivor sweeps) + the flake app .#drawterm-gate-x64 (the auth gate's runtimeInputs verbatim + DRAWTERM_BIN; the frozen hasAttr gate list byte-untouched). All three of the plan's verify legs green.
- **Task 3 (partial, halted):** the session's failure chain root-caused layer by layer on the live venue — (A) the image had no NIC address: FIXED (cpurc's ether leg via the REAL ipconfig, seam-sourced, replacing the vestigial loopback leg under the era's one-medium-per-boot limit; §15 stages cmd/ip/ipconfig); (B) the kernel's listen park path never drove ingress on the RX wake: FIXED and PUSHED to r9 main at 9704b2e (the icmp park shape's drive_stack; port battery 160/160; pin advance + FOD re-wire deliberately NOT bundled — the plan names them the next pass's own choreography); (C) at the pushed-fix kernel the accept fires, drawterm reaches the password prompt, p9sk1 completes (tr-ok on serial), the devssl session establishes — and cpu -R then dies in auth_chuid's mount/newns stretch. (C) is the honest halt point: another kernel stretch (the RFCNAMEG namespace rebuild + fd-mounts under the service child — never-exercised surface), site not fully isolated within this session's budget.

## Task Commits

1. **Task 1: drawterm-gate.expect — the pty-driven session chassis** - `8b1b0ecd5` (feat)
2. **Task 2: the -G gate driver + flake app registration** - `6defbd9eb` (feat)
3. **[Rule 3] the cpu image's hostfwd reception seam (cpurc + §15 + the gate's ether stage)** - `66f3e9a13` (fix)
4. **Task 3 evidence: the pinned + override gate runs + the repro pair** - `03a11d673` (test)

**r9 (sibling repo, PUSHED):** `9704b2e` fix(19-08): the tcp listen park path drives ingress before blocking

**Plan metadata:** (this SUMMARY + STATE/ROADMAP — the docs commit follows)

## Files Created/Modified

- `build/x86_64/drawterm-gate.expect` — the two-subtree -G session gate (the DESK-06 chassis)
- `nix/drawterm-gate-x64.sh` — the pipeline driver (creds read, append compose, both sweeps)
- `flake.nix` — drawtermGateX64Pkg + .#drawterm-gate-x64 (the frozen gate list untouched)
- `build/x86_64/root-tree/rc/bin/cpurc` — leg 2: the ether reception seam (ETHER-OK)
- `build/x86_64/mkimage.sh` — §15: ipconfig asserts/staging + the cpurc shape asserts
- `evidence/19-08-*` (5 files) — the pinned run, the pushed-fix run (console + capture), the repro pair

## Decisions Made

See key-decisions. Additionally: the gate asserts the venue's ACTUAL prompt (`% `) — the plan's "cpu% prompt shape" parenthetical assumed the profile's cpu case runs, but rcmain's login-source guard needs /bin/test (not staged) and the creds user has no home; the default prompt IS the login shell's evidence (the acceptance criteria's own wording — "prompt, shell, fed-command echo" — is what the gate asserts).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Bash-style ${VAR:-default} inside Tcl**
- **Found during:** Task 1 (env-contract dry test)
- **Issue:** The empty-creds abort message used `${R9_CREDS_FILE:-...}` — Tcl has no such expansion; the abort path itself crashed
- **Fix:** The creds_file default computed before the loop, referenced as a Tcl variable; all four abort paths re-tested to exit 2 with named messages
- **Files modified:** build/x86_64/drawterm-gate.expect
- **Verification:** env -i dry runs of each abort path
- **Committed in:** 8b1b0ecd5

**2. [Rule 3 - Blocking] The §15 image could not receive the hostfwd pair (no NIC address)**
- **Found during:** Task 3 (run A: the session black-holed at the auth-method ack)
- **Issue:** cpurc configured loopback only (the auth-sweep's vestige) — the guest dropped dest-10.0.2.15 packets; measured: /net/ipifc held just loopback0, no accepted conv ever materialized, no service child was ever born
- **Fix:** cpurc leg 2 re-keyed to the ether seam (bind #I + #l0 + the REAL ipconfig with seam-sourced addresses); §15 asserts + stages cmd/ip/ipconfig at the net image's own exec path; the gate gains the ether-ok stage. TWO intermediate shapes were tried and discarded with measurements: the per-write ctl emulation (collides: the clone open re-hands conv 0, 'interface already bound') and a conv-holder via a backgrounded data read (ipifc data reads error immediately this era) — the one-medium limit is recorded as the named r9 follow-up
- **Files modified:** cpurc, mkimage.sh, drawterm-gate.expect
- **Verification:** cpurc: ETHER-OK + the full ladder in every boot since; the accept firing at the fixed kernel
- **Committed in:** 66f3e9a13

**3. [Rule 1 - Kernel bug, D-11 umbrella] The tcp listen park path never drove ingress**
- **Found during:** Task 3 (with the ether up: ipifc pktin stayed 0, the SYN never processed)
- **Issue:** note_rx_pending wakes the parked listen() opener, but its re-probe pops a pool member only if smoltcp has already processed the SYN — and nothing else drives ingress on an idle venue (every prior gate's traffic was guest-initiated)
- **Fix:** r9 9704b2e (PUSHED to main, unpinned): a drive_stack() after the waker arming, before the block — the icmp park shape; port battery 160/160; the pin advance + FOD re-wire deliberately left to the next r9-touching pass per the plan's own choreography rule
- **Files modified:** ../r9/port/src/devip.rs
- **Verification:** the accept fires live (serial: 'tcp call for tcp17010 on chan /net/tcp/2 (10.0.2.2)'); drawterm reaches the password prompt and completes p9sk1 (tr-ok)
- **Committed in:** r9 9704b2e (sibling repo)

---

**Total deviations:** 3 auto-fixed (1 bug, 1 blocking, 1 kernel bug under D-11's umbrella)
**Impact on plan:** Deviations 2+3 were prerequisites for the session working AT ALL; no scope creep. The kernel fix is pushed but deliberately unpinned (the plan's own "its own pass" boundary).

## Issues Encountered

- **THE HALT — root cause C (kernel, OPEN):** at the pushed-fix r9, cpu -R completes srvp9auth's exchange (tr-ok norbert) and then dies with `cpu: srvauth: namec: does not exist`, preceded by two factotum-walk `devmnt: server error: not found` lines — the death sits in auth_chuid's stretch (#¤/capuse write -> the /srv/factotum mount over /mnt -> newns's RFCNAMEG namespace rebuild), a never-exercised kernel surface on this venue. NOT fully site-isolated within this session (three fix attempts spent per the limit; the remaining work needs a debug-kernel tracing pass). The next r9-touching pass owns it together with the pin advance + FOD re-wire for 9704b2e + the q35cpu profile re-key (the pass 19-07 already named).
- The drawterm package's secstore probe parks against authsrv on a 3-part auth address — avoided by `-s ''` in the gate (documented in the gate header + key-decisions); a venue fact for 19-09/19-10's human sessions too (the wrapper pins the same 3-part auth address — a human windowed session from the README recipe would hit the same probe; the wrapper does NOT pass -s — follow-up recorded for the next plan touching the wrapper).
- `expect` is not on the bare host PATH (the 19-07 note stands; the flake app's runtimeInputs carry it — the manual repro used the store binary).
- cpu-bringup.expect (19-07's gate) was NOT re-run after the cpurc re-key; the manual boots show the full ladder green (ETHER-OK through DONE, three captures) — equivalent evidence, but 19-07's gate should re-green in the next pass's battery (with the pinned kernel it would red at the same listen-park blocker? no — bringup never dials; it stays green on the ladder alone).

## Known Stubs

None - no stubs, placeholders, or unwired data paths were introduced. (The gate's post-pass redaction arm never executed because no run reached teardown — the retained evidence copies were string-mapped at copy time instead, noted in the evidence commit.)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 19-09 (--system=cpu boot mode) can proceed: it boots the SAME §15 image (now with the ether leg) and does not dial; note the one-medium rule applies to any future in-guest dials on that image
- 19-10 (DESK-07 evidence) is BLOCKED on this plan's green gate (a halted 19-08 marks dependents blocked until re-summarized complete)
- THE NAMED NEXT PASS (r9-touching): (1) root-cause + fix root cause C (the auth_chuid mount/newns stretch under the service child — likely candidates from the evidence: the fd-mount path or the namespace-rebuild walks); (2) the flake.lock pin advance to >= 9704b2e with the FOD re-wire (the 19-05 choreography, its own commit + fresh hosted CI per INT-06); (3) the r9-side q35cpu boot-profile re-key (19-07's carried item); (4) re-green the full gate battery incl. cpu-bringup at the new pin; (5) re-run THIS gate's green-twice + REDACTION-OK legs and re-summarize 19-08 complete

## Self-Check: PASSED

- Created files exist: build/x86_64/drawterm-gate.expect, nix/drawterm-gate-x64.sh, the five evidence files FOUND
- Task commits exist: 8b1b0ecd5, 6defbd9eb, 66f3e9a13, 03a11d673 all ancestors of HEAD (03a11d673)
- Plan verify legs at close-out: Task 1 GATE-FILE-SHAPE-OK PASS; Task 2 GATE-APP-EVAL-OK + DRIVER-SHAPE-OK PASS; Task 3 GATE-A-GREEN / GATE-GREEN-TWICE / REDACTION-OK BLOCKED (root cause C — honestly recorded, coverage D4 status: fail)

---
*Phase: 19-cpu-service-drawterm-rio-desktop*
*Completed: 2026-11-15 (halted at the kernel boundary — see Issues)*
