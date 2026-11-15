---
phase: 19-cpu-service-drawterm-rio-desktop
plan: "08"
subsystem: infra (the -G interop gate)
tags: [drawterm, -G, pty, expect, hostfwd, p9any, p9sk1, devssl, ipconfig, ether, flake-app, devmnt, srv-sessions]

# Dependency graph
requires:
  - phase: 19-cpu-service-drawterm-rio-desktop/19-06
    provides: the drawterm -O/-G surface + the nix package (DRAWTERM_BIN) the gate spawns
  - phase: 19-cpu-service-drawterm-rio-desktop/19-07
    provides: the §15 cpu image (bootfs-cpu.paq) + out/auth-creds.txt (the D-12 parse contract) + the cpu-bringup stage vocabulary
  - phase: 16-host-net-modes-networking-exit-gate
    provides: the committed D-04 hostfwd pair (127.0.0.1:17010/5670) the session dials
provides:
  - build/x86_64/drawterm-gate.expect — the TWO-subtree -G session chassis (qemu + drawterm-on-a-pty), validated live through the fed-command round-trip
  - nix/drawterm-gate-x64.sh + the flake app .#drawterm-gate-x64 — the full pipeline (tier build -> bake -> loud creds read -> ISO-with-append -> gate -> both survivor sweeps)
  - the cpu image's ether reception leg (cpurc + §15 ipconfig staging) — the hostfwd pair reaches the guest
  - the r9 listen-park ingress fix (9704b2e) + the FIVE-defect auth_chuid chain (917685c, both PUSHED, unpinned): #¤ on the composed kernel, srv re-mount session reuse (the pipe-hosted mnt_session), ssl chans as 9P connections, Chan::dup's #D refc rule, the q35cpu profile re-key — the -G session now reaches the remote rc -li prompt and the fed command's round-trip
  - the root-caused record of the REMAINING deadlock (devmnt's single-outstanding busy flag + devssl's Dstate lock across wire reads) with the donor-faithful fix design (the tag-mux + direction-split shapes) — the next r9 pass's first item
affects: [19-09 (boots the same §15 image — the ether leg + the one-medium rule apply), 19-10 (DESK-07's evidence rows need the green gate), the next r9-touching pass (owns: the devmnt tag-mux landing, the devssl lock split, then the pin advance + FOD re-wire for 9704b2e+917685c, the gate's green-twice)]

actuals:
  tokens: 21400    # chars/4 over the realized production diff (r9 8 files ~29.4kc + harvey zero — all harvey-side changes this pass were diagnostic scaffolding, reverted; evidence + the prior session's bytes excluded)
  tasks: 2         # 2 complete (Tasks 1-2); Task 3 still open — advanced from "dies at auth_chuid" to "full session, prompt + fed-echo green, session-exit deadlocked"
  commits: 0       # harvey-side: 0 new (the plan's harvey commits were all prior-session; r9: 917685c pushed, its own repo)
plan_head_before: 49a1fca39
plan_head_after: 49a1fca39

tech-stack:
  added: []          # zero packages — committed surfaces only (T-19-SC honored)
  patterns:
    - "the #c/cons device-direct debug channel for service children: listen dups the connection over fd 0/1/2 AND binds it over /dev/cons, so fd-2 prints pollute the 9P wire and /dev/cons prints vanish — syslog's '#c/cons' fallback (the cons=1 path when /sys/log is absent) is the only observation channel that reaches the serial console from inside a service child"
    - "root-cause chains by layer peeling with one instrument per layer: guest-binary step prints (rebuilt via the userns tier build) -> kernel syscall/walk prints -> device refcount lifecycle prints — each run eliminates exactly one hypothesis class"
    - "the .6 object format stores string literals in 8-byte chunked tables, so byte-grep over archives/objects false-negatives — verify instrumented linkage against the linked BINARY, never the archive"

key-files:
  created:
    - build/x86_64/drawterm-gate.expect          # (prior session) the two-subtree -G session gate
    - nix/drawterm-gate-x64.sh                    # (prior session) the pipeline driver
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-gate-run-a-pinned.console
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-gate-run-fixr9.console
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-gate-run-fixr9.log
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-repro-boot-fixr9-serial.log
    - .planning/phases/19-cpu-service-drawterm-rio-desktop/evidence/19-08-repro-dt-session-fixr9.log
  modified:
    - flake.nix                                     # (prior session) drawtermGateX64Pkg + .#drawterm-gate-x64
    - build/x86_64/root-tree/rc/bin/cpurc          # (prior session) the ether reception seam (ETHER-OK)
    - build/x86_64/mkimage.sh                       # (prior session) §15 ipconfig staging + asserts
    - ../r9/x86_64/lib/config_q35churnshell.toml    # +cap (THIS pass, commit 917685c)
    - ../r9/x86_64/lib/config_q35cpu.toml           # ether+ip + the re-key (THIS pass)
    - ../r9/xtask/src/main.rs                       # the q35cpu gate expectations re-key (THIS pass)
    - ../r9/port/src/{devpipe,devmnt,devssl,dat}.rs # the session fixes (THIS pass)
    - ../r9/x86_64/src/syscall.rs                   # sys_mount's ssl widening (THIS pass)

key-decisions:
  - "Root cause C was a FIVE-defect chain, not one bug — each layer's fix exposed the next (the discipline's measure-first loops paid for themselves): (1) kernel-x64 (q35churnshell) lacked cfg(dev_cap) — factotum's mkcap returned nil since the first boot, invisible until the first capability consumer; (2) every /srv re-mount negotiated a fresh 9P session over the shared wire — the server's per-connection fid space collided ('duplicate fid'); (3) fversion/mount only accepted PIPE chans — the ssl fd that remoteside must mount over was rejected; (4) Chan::dup did not hold #D conversations alive — remoteside's close of the ssl fd killed the mounted session's wire; (5) the q35cpu profile predated the real §15 cpurc"
  - "The diagnostic channel for service children is #c/cons device-direct: the listen child's fd 0/1/2 ARE the connection (step prints pollute the 9P stream — run 1's fprint(2) bytes were consumed by drawterm's readn as key material!) and /dev/cons is bound over by listen — only the syslog-fallback open of #c/cons reaches the serial console"
  - "The five-fix state is the commit line: the session reaches password feedstage -> tr-ok -> byte-aligned key exchange (both sides' 4 bytes verified equal on the wire) -> devssl both ends -> FS/OK handshake -> fversion+mount of the client exportfs at /mnt/term -> the /mnt/term/dev/cons stdio rebind -> rc -li -> THE REMOTE PROMPT ON THE DRAWMTERM PTY -> the fed command's full round-trip (the gate's session-prompt and fed-echo stages GREEN). The remaining deadlock (below) is root-caused with the donor-faithful design in hand — landing it is the next pass's first item, not a re-diagnosis"
  - "The devmnt tag-mux rework + devssl lock split were BUILT this pass (port battery 160/160 at the rework tree, the full session reached) and then REVERTED: the rework introduced a boot-time race whose failure mode varied run-to-run (paqfs 'mount write' / factotum leg fails / full green) and could not be isolated within the session's budget. The revert keeps the deterministic five-fix tree; the design and the partial-implementation notes live in the Deviations section"

patterns-established:
  - "Root-cause by discriminators on the live venue, one instrument per layer: the guest binary's step prints (a temporary #c/cons dbgprint helper, rebuilt via the unprivileged userns tier build), then kernel prints (sys_mount/sys_exec/devmnt walk/devssl refcount), then device lifecycle traces (devpipe qref) — six fix cycles, each eliminating one layer"

requirements-completed: []   # DESK-06/CPU-04/DESK-04 stay OPEN — the gate cannot go green until the devmnt/devssl deadlock closes (see Issues)

coverage:
  - id: D1
    description: "The pty-driven session chassis (Task 1): two subtrees, feedstage password discipline, presence asserts, fast-fail, post-passes, last-step redaction shape"
    requirement: DESK-06
    verification:
      - kind: other
        ref: "GATE-FILE-SHAPE-OK (the plan's verify) + validated LIVE at the pushed-fix r9: 14 stages green through the dt-password feedstage"
        status: pass
    human_judgment: false
  - id: D2
    description: "The driver + flake app (Task 2): the full pipeline with the loud creds read, the append-bearing ISO compose, both survivor sweeps"
    requirement: DESK-06
    verification:
      - kind: other
        ref: "GATE-APP-EVAL-OK + DRIVER-SHAPE-OK (the plan's verifies) + the full app driven end-to-end twice (pinned + override runs, prior session)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The ether reception seam: the cpu image can receive the committed hostfwd pair (cpurc leg + §15 ipconfig staging)"
    verification:
      - kind: e2e
      ref: "cpurc: ETHER-OK in every boot capture + the accept firing (serial: 'tcp call for tcp17010') + the q35cpu boot profile PASS at the re-keyed expectations (r9 917685c)"
      status: pass
    human_judgment: false
  - id: D4
    description: "Green twice on local KVM + the redacted retained capture (Task 3's DONE, DESK-06's bar, CPU-04's consolidated evidence, DESK-04's live encrypted proof)"
    requirement: DESK-06
    verification:
      - kind: e2e
      ref: "ADVANCED BUT BLOCKED: at the five-fix r9 (917685c) the session reaches the remote rc -li prompt on the drawterm pty and the fed command's round-trip (the gate's session-prompt + fed-echo stages green, the key exchange byte-verified aligned) — but session-exit hangs: an indefinite 9P read parks devmnt's single-outstanding busy flag AND devssl's Dstate lock, deadlocking every later rpc of the mounted session (rc never reaches its next prompt). GATE-A-GREEN / GATE-GREEN-TWICE / REDACTION-OK still cannot run"
    human_judgment: true
    rationale: "The remaining blocker is a two-part kernel concurrency defect (root-caused, donor-faithful fix designs recorded in Deviations); no harvey-side assertion can prove the gate until the next r9 pass lands them"
  - id: D5
    description: "The q35cpu boot-profile re-key (19-07's carried item): the profile's dev set and the xtask gate expectations moved to the real §15 cpurc"
    verification:
      - kind: other
        ref: "boot-test PASS at 917685c: the six-rung ladder green to cpurc: DONE with the pairing rung, then init's post-cpustart terminal handoff — the retired fixture legs and loop-prohibition documented in the profile comments"
        status: pass
    human_judgment: false

duration: 280 min
completed: 2026-11-15
status: halted
---

# Phase 19 Plan 08: The -G interop gate Summary

**The -G session is ALIVE end-to-end at the five-fix r9 (917685c, PUSHED): password feedstage, tr-ok, a byte-verified key exchange, the encrypted devssl session, the FS/OK handshake, fversion+mount of the client exportfs at /mnt/term, the cons stdio rebind, and the remote rc -li prompt ON THE DRAWMTERM PTY with the fed command's round-trip — one root-caused kernel concurrency defect (devmnt's single-outstanding busy flag + devssl's lock-across-read) still deadlocks the session's teardown and with it the gate's green**

## Performance

- **Duration:** 280 min this continuation pass (root-cause heavy: 6 kernel fix cycles, ~20 gate/boot runs, 3 live serial-probe sessions); 120 min the prior pass
- **Started:** 2026-11-15T05:04:08Z (continuation; the prior pass 02:58:44Z)
- **Completed:** 2026-11-15T09:4xZ (halted again — the advanced boundary)
- **Tasks:** 2/3 complete (Task 3 advanced from "dies at auth_chuid" to "full session, session-exit deadlocked")
- **Files modified:** harvey 0 (all this pass's harvey-side edits were diagnostic scaffolding, reverted; the image re-baked stock); r9 8 (commit 917685c)

## The continuation pass's root-cause chain (Task 3, the D-11 umbrella)

Each defect was root-caused with a live discriminator instrument before fixing; each fix exposed the next layer:

1. **The cap was empty** (`ai->cap == ""` — measured by a rebuilt instrumented auth_chuid printing to #c/cons): factotum's `mkcap` returned nil because `initcap`'s `open("#¤/caphash")` failed at factotum start — `namec: unknown # device`, measured live from a cpurc probe. **Kernel-x64 builds `--config q35churnshell` whose dev list never carried `cap`** (the 18-02 port is cfg(dev_cap)-gated; the q35auth/q35cpu substrate profiles have it, the composed venue never did — no composed gate consumed a capability before this session). FIX: q35churnshell +cap.
2. **`duplicate fid` from factotum** (auth_chuid's re-mount of /srv/factotum): every fresh `open("/srv/X")` yields a session-less dup, so every mount negotiated a NEW 9P session (fid 1) over the SAME wire while the server's per-connection fid space still held the first session's fids. The donor's srvopen returns the registry chan OBJECT (the session survives on it); r9's value-dup loses it. FIX: `Pipe::mnt_session` (per-end) — the session lives on the shared connection; fversion consults and stores it.
3. **`fversion: fd is not a 9P-capable connection`**: remoteside fversions/mounts the client's exportfs over the DEVSSL data fd; fversion/sys_mount/ChanIo only accepted PIPE chans. FIX: DEVSSL joins all three (ChanIo dispatches devssl read/write).
4. **The post-mount session died with the ssl fd's close** (`inappropriate use of fd` on every /mnt/term walk): `Chan::dup` bumped pipe/ether/ip open-counts but not #D conversations — the 9P session's io dup did not hold the conv. FIX: the DEVSSL exception in Chan::dup (`devssl::ref_open`).
5. **The fed command's exec failures were benign** (measured: `./echo` — rc's default $path tries "." first; `/bin/echo` succeeds silently; `/bin/test` is deliberately absent) — no fix needed, recorded so the next pass does not re-chase it.

At this point the session's stages went green through **fed-echo** — the fed line returns through the exportfs (`Rread ... 'echo DTGATE-...'` observed from drawterm's debug build).

## THE REMAINING BLOCKER (root-caused, design in hand)

`session-exit` hangs: rc never reaches its next prompt after the fed command. Two compounding concurrency defects, both root-caused:

- **devmnt allows ONE outstanding rpc, with the busy flag held across the blocking reply read.** The first indefinite 9P read on a mounted session — cpu -R's noteproc reading `/mnt/term/dev/cpunote`, or rc's console stdin — parks holding the session; every later rpc (rc's next prompt Twrite, the children's Tclunks) blocks forever.
- **devssl::read holds the Dstate lock across the blocking wire read** (the donor splits by direction: `s->in.q` for reads, `s->out.q` for writes). A parked ssl read blocks all ssl writes on the conversation.

**The donor-faithful fix design (built this pass, reverted for a boot race — see Deviations):** devmnt multiplexes by TAG with a transferable single-wire-reader token (every blocked reader is a potential demux reader for others' replies — the donor's model; the routed-reply queue + the outstanding-tag registry with the loud tag-mismatch check), and devssl's data read takes the Dstate lock only around state transitions, parking with the io chan taken out of the shared state. The implementation reached the full session but introduced a boot-time race (varying failure modes: paqfs `mount write`, the factotum leg, or green) that this pass could not isolate; it was reverted in favor of the deterministic five-fix tree.

## Task Commits

1. **Task 1: drawterm-gate.expect — the pty-driven session chassis** - `8b1b0ecd5` (feat, prior pass)
2. **Task 2: the -G gate driver + flake app registration** - `6defbd9eb` (feat, prior pass)
3. **[Rule 3] the cpu image's hostfwd reception seam** - `66f3e9a13` (fix, prior pass)
4. **Task 3 evidence: the pinned + override gate runs + the repro pair** - `03a11d673` (test, prior pass)
5. **Task 3 (continuation): the five-defect kernel chain + the q35cpu re-key** — **r9 `917685c`** (fix, PUSHED = origin/main; harvey-side: zero — the diagnostic scaffolding was fully reverted)

**Plan metadata:** (this SUMMARY + STATE/ROADMAP — the docs commit follows)

## Files Created/Modified

- (prior session, unchanged this pass): `build/x86_64/drawterm-gate.expect`, `nix/drawterm-gate-x64.sh`, `flake.nix`, `cpurc`, `mkimage.sh`, the five evidence files
- (this pass, r9 917685c): `config_q35churnshell.toml` (+cap), `config_q35cpu.toml` (+ether+ip), `xtask/src/main.rs` (the gate expectations), `port/src/devpipe.rs` (mnt_session), `port/src/devmnt.rs` (fversion pipe-probe + ssl chans), `port/src/devssl.rs` (ref_open), `port/src/dat.rs` (dup's #D rule), `x86_64/src/syscall.rs` (sys_mount's ssl arm)

## Decisions Made

See key-decisions. Additionally: the pin advance is deliberately NOT executed this pass — kernel bytes (9704b2e + 917685c) stay pushed-but-unpinned exactly as the prior pass left 9704b2e, because the plan's own boundary ties the choreography to the gate's green ("a fix here re-opens 19-05's choreography as its own pass"); advancing now would pin bytes whose session evidence is still red.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Kernel bug, D-11 umbrella] The composed kernel lacked #¤ (root cause C, layer 1)**
- **Found during:** Task 3 continuation (instrumented auth_chuid: `cap=0` at the cap check)
- **Issue:** kernel-x64 = q35churnshell, dev list without `cap` — factotum's caps were silently nil since the first composed boot
- **Fix:** q35churnshell dev += "cap" (r9 917685c)
- **Verification:** the capuse write succeeds; auth_chuid proceeds past the cap check (live trace)
- **Commit:** r9 917685c

**2. [Rule 1 - Kernel bug] `duplicate fid` at every /srv re-mount**
- **Found during:** Task 3 continuation (kernel devmnt walk prints + the lib9p error string)
- **Fix:** Pipe::mnt_session — the donor's session-survives-the-registry-chan semantics, hosted on the shared connection (r9 917685c)
- **Verification:** the factotum re-mount's Tattach succeeds; the error line disappears from the capture
- **Commit:** r9 917685c

**3. [Rule 1 - Kernel bug] fversion/mount rejected the ssl fd**
- **Fix:** DEVSSL accepted as a 9P connection in fversion, sys_mount, and ChanIo (r9 917685c)
- **Verification:** remoteside's fversion completes ("fversion done" live trace); the /mnt/term mount's Tattach observed at drawterm's exportfs
- **Commit:** r9 917685c

**4. [Rule 1 - Kernel bug] Chan::dup did not hold #D conversations**
- **Fix:** the DEVSSL exception in Chan::dup (devssl::ref_open) — the devpipe/devip rule extended (r9 917685c)
- **Verification:** the post-mount walks (dev, cons, cpunote) reach the exportfs after remoteside's close of the ssl fd
- **Commit:** r9 917685c

**5. [Rule 3 - Blocking] The q35cpu profile predated the real §15 cpurc (19-07's carried item)**
- **Fix:** ether+ip in the dev set; the xtask expectations re-keyed to the ladder markers (cpurc: PAIR-OK/DONE); the 19-03 fixture legs and the 19-01 terminal-loop prohibition retired with the reasoning recorded at each site (r9 917685c)
- **Verification:** boot-test PASS (twice) at 917685c
- **Commit:** r9 917685c

**6. [Rule 1 - Kernel bug, BUILT AND REVERTED] The devmnt tag-mux + the devssl lock split**
- **Found during:** Task 3 continuation (the session-exit hang localized by exportfs debug traces: the prompt Twrite's reply never returns while the cpunote read parks)
- **Issue:** the two compounding lock-scope defects described above
- **Fix:** the full donor-faithful rework was implemented (port battery 160/160 green at the rework tree, devmnt host tests re-keyed to the mux, the session reached prompt + fed-echo deterministically at first) — but a boot-time race appeared (paqfs `mount write` / the factotum leg / green, varying per run; NOT the waived triple-fault class — clean process-level failures) and could not be isolated within the fix-attempt budget. REVERTED to the deterministic five-fix tree; the design + the partial implementation's shape are recorded here and in the commit message
- **Verification:** the revert tree: battery 160/160 + q35cpu boot PASS + the gate's prior behavior restored (session-prompt + fed-echo green, session-exit timeout)
- **Commit:** (none — reverted; the design rides this record)

---

**Total deviations:** 6 auto-fixed (5 kernel bugs under D-11's umbrella, 1 blocking re-key; one additional fix built and deliberately reverted)
**Impact on plan:** all six were prerequisites for the session working AT ALL; no scope creep. The revert keeps the tree at the highest DETERMINISTICALLY-VERIFIED state.

## Issues Encountered

- **THE REMAINING HALT — the session-exit deadlock (kernel, OPEN):** the two root-caused lock-scope defects (devmnt's busy-flag-across-parked-read; devssl's Dstate-lock-across-wire-read). The next r9-touching pass owns: land the tag-mux + the devssl direction split (the designs above; the partial implementation reached the full session once), THEN the pin advance + FOD re-wire for 9704b2e+917685c together (the 19-05 choreography verbatim), the battery re-green at the pin, and THIS gate's green-twice + REDACTION-OK + the honest TCG leg.
- **The boot-flake discriminator confusion:** two boot failures during the rework bisect initially looked like the rework's regression; one was a genuine rework bug (an MCS LockNode reused across nested acquisitions — corrupting both lock queues), one was a run-to-run race that ALSO fires on the five-fix tree rarely. Both recorded; the MCS fix's lesson (one node per acquisition, always) is noted in the r9 commit.
- **D-09 record (the waived #66/CR-07 class):** no triple-fault/capture-context firing occurred this pass; the varying boot failures above are a DIFFERENT class (clean process exits with named errstrs) and were treated as ordinary bugs, not the waiver.
- The drawterm wrapper's `-s ''` gap (the prior pass's note) stands for 19-09/19-10's human sessions.
- `expect` is not on the bare host PATH (the flake app's runtimeInputs carry it — unchanged).
- cpu-bringup.expect re-greens as part of the next pass's battery (the ladder is green in every capture this pass: ETHER-OK through DONE, including the q35cpu boot-test PASS which asserts the same vocabulary).

## Known Stubs

None - no stubs, placeholders, or unwired data paths were introduced. (All diagnostic instrumentation — the #c/cons dbgprint helper in cpu.c, the drawterm/exportfs debug builds, the kernel DBG prints, the cpurc probe block — was fully reverted; the harvey tree is byte-clean and the image re-baked stock.)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 19-09 (--system=cpu boot mode) can proceed: it boots the SAME §15 image (the ether leg, the one-medium rule)
- 19-10 (DESK-07 evidence) remains BLOCKED on this plan's green gate
- THE NAMED NEXT PASS (r9-touching): (1) land the devmnt tag-mux + devssl lock split (designs in Deviations; the boot race in the partial implementation needs isolation — the varying failure modes suggest a lost-wakeup or a lock-queue hazard in the reader-token protocol, prime suspects: the reader-flag release/re-take window in the framing loop and the tick-retry's interaction with the parked io_r read); (2) the pin advance + FOD re-wire for 9704b2e+917685c; (3) the battery + composed gates re-green at the pin (incl. cpu-bringup); (4) this gate's green-twice + REDACTION-OK + the TCG leg; (5) re-summarize 19-08 complete

## Self-Check: PENDING (appended below after verification)

---
*Phase: 19-cpu-service-drawterm-rio-desktop*
*Completed: 2026-11-15 (halted at the session-exit deadlock — see Issues; the prior halt's record is preserved above in the root-cause chain)*

## Self-Check: PASSED

- Created/modified files exist: build/x86_64/drawterm-gate.expect, nix/drawterm-gate-x64.sh, the five evidence files, the SUMMARY FOUND; the harvey working tree is CLEAN apart from this SUMMARY (all diagnostic scaffolding reverted; the image re-baked stock)
- Task commits exist: 8b1b0ecd5, 6defbd9eb, 66f3e9a13, 03a11d673 all ancestors of HEAD (49a1fca39); r9 917685c == origin/main (PUSHED, verified post-push)
- Plan verify legs at close-out: Task 1 GATE-FILE-SHAPE-OK PASS; Task 2 GATE-APP-EVAL-OK + DRIVER-SHAPE-OK PASS (prior session); Task 3 session-prompt + fed-echo STAGES GREEN at r9 917685c (the final verification run), GATE-A-GREEN / GATE-GREEN-TWICE / REDACTION-OK BLOCKED (the session-exit deadlock — honestly recorded, coverage D4 status: fail/advanced)
- r9 battery at the final tree: cargo xtask check + test green (port 160/160), q35cpu boot-test PASS
