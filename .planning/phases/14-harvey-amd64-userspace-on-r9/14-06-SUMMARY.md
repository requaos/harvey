---
phase: 14-harvey-amd64-userspace-on-r9
plan: 06
subsystem: boot-chain-gate
tags: [boot(8), bootfs, chain, mkfile.amd64, q35shell, x86_64, r9, xexec-03]
duration: 146 min
completed: 2026-11-09
requires:
  - "14-05-complete r9 HEAD ae4fb7c (the bake pipeline, the module delivery, exec_bootstrap with BOOT_ENTRY's bootchain arm pre-wired)"
provides:
  - "sys/src/9k/boot/mkfile.amd64 — boot(8) builds under 6c via the aarch64 template (A4 RESOLVED: bootr9.c compiles unchanged; the BOOTFILES closure is identical — embed in, paq out — linker-evidenced by the green 6l link)"
  - "build/x86_64/stage-build.sh's boot-chain section — chain libs (bio auth ip mp sec flate authsrv) + boot(8)/real-init/rc/paqfs harvested to out/ with 00008a97 asserted on each; build/x86_64/mkimage.sh's chain bake — bootfs-chain.paq with /boot/boot + /boot/paqfs + the REAL /amd64/init + /amd64/bin/rc, rcmain verbatim (cmp guard), termrc/namespace/profile, the INVERTED init-identity guard, factotum absence, KERNDATE determinism (two bakes byte-identical 8d2e2d08)"
  - "r9 config_q35shell.toml (exec+bootchain+ether+ip) + the xtask X64Shell gate (bind → module/paqfs → exec entry → boot(8)'s paqfs/version prints → init's rc handoff → the `% ` prompt; the syscall-10 real-chain exemption)"
  - "FOUR latent kernel defects found and fixed by the chain gate, each invisible before the first multi-binary boot: (1) ktext was a CONFORMING code segment (0x9E) — ring-3 interrupt delivery stayed at CPL 3 and fault-looped to triple-fault; (2) the exec seed planted the Tos in bp (a 14-03 mis-reading) instead of AX (the donor's exec-return contract main9.s consumes) — boot(8)'s fused main9 prologue stored a zero _tos and malloc's plock fault-killed at addr 0x40; (3) the stack seed was two pages — boot(8) ran ~8.6 KiB deep (now 32 pages eager + the donor's Tos placement at USTKTOP-88, above the args); (4) brk growth relied on the absent pager (now mapped eagerly)"
  - "Harvey in-tree: embed.c drops the waitpid that deadlocked the paqfs handoff (a sleeping 4e bug — embed was never exercised on 4e/9k); ABI.md records the AX/Tos first-instruction contract"
affects:
  - "../r9/x86_64/src/{seg,dat,exec,syscall,trap,main}.rs, ../r9/xtask/src/main.rs, ../r9/x86_64/lib/config_q35shell.toml"
  - "sys/src/9k/boot/{mkfile.amd64,embed.c}, build/x86_64/{stage-build.sh,mkimage.sh,root-tree/}, amd64/ABI.md"
  - "14-07 (the composed one-command artifact consumes the chain bake + the gate), the follow-up that closes the two-proc scheduler corruption (see Known Issues)"
tech-stack:
  added: []
  patterns:
    - "the chain-gate debugging doctrine: qemu -d int,cpu_reset under TCG names the vector/state class (the ring-3 delivery storm at the IDT stubs with CS=gate-sel|3), the monitor-over-unix-socket dumps live statics, and binary disassembly of the 6.out (a.out parse + objdump) places the faulting instruction — all three were load-bearing this plan"
    - "6l fuses a main9-equivalent prologue (`mov %rax, _tos` + argc/argv reloaded from the stack) into the entry `main` even when _main is absent — kernels seeding a first process must plant the Tos pointer in AX (the exec-return register), never in an argument register"
key-files:
  created:
    - sys/src/9k/boot/mkfile.amd64
    - build/x86_64/root-tree/rc/bin/termrc
    - build/x86_64/root-tree/lib/namespace
    - build/x86_64/root-tree/usr/glenda/lib/profile
    - ../r9/x86_64/lib/config_q35shell.toml
  modified:
    - build/x86_64/stage-build.sh
    - build/x86_64/mkimage.sh
    - sys/src/9k/boot/embed.c
    - amd64/ABI.md
    - ../r9/x86_64/src/seg.rs
    - ../r9/x86_64/src/dat.rs
    - ../r9/x86_64/src/exec.rs
    - ../r9/x86_64/src/syscall.rs
    - ../r9/x86_64/src/trap.rs
    - ../r9/x86_64/src/main.rs
    - ../r9/xtask/src/main.rs
key-decisions:
  - "TWO IMAGES, not one: the chain bakes to out/bootfs-chain.paq while q35exec keeps out/bootfs.paq — the marker IS the leg-1 image's /amd64/init and the real init IS the chain image's; one image would break q35exec's regression. Chain binaries harvest to out/ (the boot chain's home, the aarch64 separation) — never smoke-out/, where the marker owns the init name"
  - "rcmain ships from rc/lib/rcmain (the aarch64 bake's cmp source — the rc-main that sets the '% ' prompt the gate asserts), NOT sys/src/9k/root/rcmain (the plan's read_first pointer is the kernel-tree reference; the operative source matches the shipped rc)"
  - "the x64 termrc drops stacksmoke (the aarch64 sibling's first line): it is the demand-paged-stack proof and x86_64 has no pager this era — it rejoins when the pager lands"
  - "the AX/Tos seed correction is an ABI fix, not a change: the donor's sysexecregs RETURNS the Tos (syscallreturn lands ar0.p in AX) and main9.s stores AX — 14-03's bp planting mis-read RARG (bp is 6c's FIRST-ARG register); ABI.md now records the contract"
  - "STOPPED at the fix-attempt limit on the remaining two-proc scheduler corruption: CURRENT_PROC receives a wild write of &SCHED_CONTEXT (the static cluster at 0xffffffff806f5000), then any current() deref faults; evidence and the leading theory are recorded under Known Issues for the follow-up"
requirements-completed: []   # XEXEC-03 is NOT complete — the q35shell gate is red at the last stage (see Known Issues)
commits: 3
plan_head_before: 5ba1424c4f0dc3ec10f8c9f9a1a277b7fb995c6a   # harvey repo; r9 ledger ae4fb7c
plan_head_after: 86422fdea   # harvey repo; r9 ac7aa92
actuals:
  tokens: 29700  # chars/4 over the realized diff (harvey 3 commits ~28KB + r9 315+43 lines ~91KB → ~119KB/4)
  tasks: 2       # of 3 (Task 3 partially landed — the profile + gate wired + committed, the gate itself red)
  commits: 3     # harvey (66cd0fc1b, a8cdb4c45, 86422fdea) + r9 ac7aa92 + this docs commit
status: incomplete   # the plan's must-have truth — q35shell green twice — is NOT met; see Known Issues
coverage:
  - deliverable: "Task 1 — mkfile.amd64 + the stage-build chain section (tracer)"
    verification:
      - kind: command
        ref: "direct mk in-namespace: boot 159356 bytes, magic 00008a97 (DIRECT-MK-VERIFY-OK; the plan's host-form re-keyed into the userns chroot — the 14-01..05 environment class); A4: bootr9.c compiled by 6c unchanged (git diff empty), the closure identical to aarch64's (green 6l link)"
        status: pass
      - kind: command
        ref: "sh build/x86_64/stage-build.sh green twice (final file state); /tmp/x64stage2.log magic-count 6 (2 marker + 4 chain binaries); acceptance greps: bootr9×3 (>=2), mkfile.amd64 in driver ×4 (>=1), bootr9.c untouched"
        status: pass
    human_judgment: false
  - deliverable: "Task 2 — the chain bootfs (mkimage chain bake + root-tree)"
    verification:
      - kind: command
        ref: "sh build/x86_64/mkimage.sh — bootfs.paq 37004 bytes + bootfs-chain.paq 238849 bytes, header 529ab12b / trailer 6b46e688; determinism: sha256 8d2e2d08… twice; the manifest log lists /boot/boot and /amd64/init"
        status: pass
      - kind: command
        ref: "acceptance greps: rcmain in mkimage ×9 (>=2), factotum ×7 (>=1), termrc exists; the chain bake's INVERTED identity guard (out/init IS the real init; the marker string ABSENT) green"
        status: pass
    human_judgment: false
  - deliverable: "Task 3 — config_q35shell + BOOT_ENTRY + the chain gate green twice"
    verification:
      - kind: command
        ref: "WIRED AND COMMITTED (r9@ac7aa92): config_q35shell.toml (bootchain dev list), the X64Shell stage chain + Display + finish arm + the syscall-10 exemption, BOOT_ENTRY's bootchain arm verified pre-carried (main.rs /boot/boot grep >=1, comment refreshed). THE GATE ITSELF IS RED: the chain reaches 'init: starting /bin/rc' then dies at a two-proc scheduler corruption (CURRENT_PROC := &SCHED_CONTEXT by a wild .bss write) — four earlier latent defects found+fixed on the way (conforming ktext, AX/Tos seed, eager stack, eager brk), full regression battery green after the fixes (q35exec/q35/q35net/aarch64 virt/ureg-check+negative control/check/clippy/60 host/101 port)"
        status: fail
    human_judgment: false
---

# Phase 14 Plan 6: The Boot Chain — boot(8)→init→rc to the Interactive Prompt Summary

Built the whole chain leg and drove it through the gate: boot(8) now compiles for amd64 (A4 resolved — arch-neutral, unchanged), the chain bake carries /boot/boot + paqfs + the real init + rc + rcmain verbatim with every guard green and byte-deterministic, and the q35shell profile + gate are wired. The gate did exactly its job on the kernel: it surfaced FOUR latent x86_64 defects no prior gate could see (a conforming ktext segment that broke ring-3 interrupt delivery, the Tos seeded in the wrong register, a two-page stack seed, lazy brk with no pager) — all fixed with the full Phase-13/14 regression battery green — plus one sleeping 4e bug in Harvey's embed.c (a waitpid that deadlocks the paqfs handoff). The chain now runs to init's rc handoff; the remaining blocker is a two-proc scheduler corruption (a wild write of &SCHED_CONTEXT into CURRENT_PROC), characterized with live-monitor evidence and left for the follow-up at the fix-attempt limit.

**Duration:** 146 min (2026-11-08T22:59:30Z → 2026-11-09T01:25:18Z)
**Tasks:** 2/3 complete (Task 3 wired+committed, the gate itself red — see Known Issues)
**Files:** 8 harvey-side (4 created, 4 modified) + 8 r9-side (1 created, 7 modified)

## Commits

| Repo | Hash | Message |
|------|------|---------|
| harvey | 66cd0fc1b | feat(14-06): boot(8) builds for amd64 — mkfile.amd64 + the stage-build chain section |
| harvey | a8cdb4c45 | feat(14-06): the chain bootfs — bootfs-chain.paq baked with rcmain/termrc/namespace staged |
| r9 | ac7aa92 | feat(14-06): the q35shell chain profile + four chain-gate kernel fixes |
| harvey | 86422fdea | fix(14-06): embed.c drops the waitpid that deadlocks the paqfs handoff + ABI.md records the AX/Tos exec-return |
| harvey | (docs) | docs(14-06): this file + state |

## Accomplishments

### Task 1: mkfile.amd64 — boot(8) under 6c (tracer)

- **mkfile.amd64** from the aarch64 template, comments re-keyed (the r9 boot has no kernel config here either — hand-written bootr9 bootconf; harvested to out/; printstub named on the link line; the autolib closure — libc/bio/auth/ip — documented for the stage driver). One real delta from the template text: my first draft carried a trailing `>` on the `</$objtype/mkfile` include (a display artifact of the read); the tree's mkfiles have none and plan9port mk treats the bracketed form as a missing file — caught on the first run, fixed, and re-verified.
- **A4 RESOLVED**: bootr9.c compiles under 6c byte-unchanged (git diff empty); the BOOTFILES closure is identical to aarch64's (embed in, paq out — the plan's "paq.$O stays" parenthetical was a misnomer for the embed member; linker evidence: the green 6l link with no missing externs and no needed additions). The plan's direct-mk verify leg re-keyed into the namespace (this host has no /amd64 at the root — the documented 14-01..05 class): DIRECT-MK-VERIFY-OK, boot 159356 bytes, magic 00008a97.
- **stage-build.sh's boot-chain section**: the chain libs first (bio, auth, ip, mp, sec, flate, authsrv — the autolib sets of boot/init/paqfs), then boot(8) via mk -f mkfile.amd64 (build → harvest → clean), the real init via cmd's per-target init.install (harvested from /amd64/init), rc, and paqfs per-target — all to out/ with the 00008a97 magic asserted and printed per binary. Chroot-venue fixes: /rc/bin on PATH (membername is an rc script) and tr in the /bin farm; explicit cleans for the cmd-tree droppings (the checkout IS the build tree here).

### Task 2: the chain bootfs

- **Two images by design**: mkimage.sh keeps the leg-1 marker bake (bootfs.paq for q35exec) and adds the chain bake (bootfs-chain.paq for q35shell) — one image would have broken q35exec's regression (the marker IS the leg-1 image's /amd64/init). The marker tree strips the new /rc+/usr skeleton subtrees so the 14-05 contract keeps its letter.
- **The chain manifest** (aarch64 re-keyed to /amd64): /boot/boot + /boot/paqfs, the REAL /amd64/init, /amd64/bin/rc, rcmain verbatim from rc/lib/rcmain (the cmp guard; the '% '-prompt rc-main matching the shipped rc), termrc/namespace/profile from the extended root-tree, /adm/timezone/local, the mount-point dirs; the INVERTED init-identity guard (real-init string PRESENT, smokesleep string ABSENT — the marker guard's mirror), factotum absence, KERNDATE determinism (two bakes byte-identical, sha256 8d2e2d08…), the od -j header/trailer checks. The x64 termrc drops stacksmoke (no pager this era — documented in the file).
- The bake log prints the staging manifest (the plan's log-grep verify: /boot/boot and rcmain both non-zero).

### Task 3: the q35shell profile + gate (wired; the gate red at the last stage)

- **config_q35shell.toml**: q35exec's shape with dev = ["exec", "bootchain", "ether", "ip"] (virtshell's membership; ether/ip per the Phase-13 placement — the gate asserts the bind half), module = the CHAIN bake (harvey:build/x86_64/out/bootfs-chain.paq).
- **xtask**: the X64Shell profile — Q35PciDiscovery → X64Bind (ether is on) → Q35ModulePaqfs → Q35ExecEntry → Q35ChainBoot (boot(8)'s own "paqfs..." + "version..." prints) → Q35ChainInit ("init: starting /bin/rc") → Q35ChainPrompt ("% "); order-anchored stages, the real-chain syscall-10 exemption (the Net-gate precedent), the finish-time whole-capture scan. main.rs's BOOT_ENTRY bootchain arm was already pre-wired by 14-05 (verified; comment refreshed to present tense).
- **The gate ran and did its job** — the chain's progress across the fix iterations: first ring-3 instruction (fault storm at the IDT stubs) → after the ktext fix: real user code, a fault at _tos → after the AX seed: paqfs.../version... → after embed.c: time... + **init: starting /bin/rc** → the current blocker (below).

## The four kernel fixes (each gate-surfaced, each invisible before multi-binary boots)

1. **ktext was CONFORMING (seg.rs)**: `Descr::ktext64()` set `.with_conforming(true)` (access 0x9E). For a conforming gate target the interrupt delivery sets dpl:=cpl — the first RING-3-origin interrupt in r9 x86_64's history delivered its stub AT CPL 3 (no stack switch: the hardware frame pushed on the user stack, CS = ktext|3 = 0x0B) and fault-looped to triple-fault. Diagnosed from qemu TCG's -d int trace (the stub-fetch faults with CS=gate-sel|3, SP=user-0x30 = the exact 5-push frame) and confirmed against TCG's delivery logic. At CPL 0 (every prior gate) the bit is unobservable. Fixed to 0x9A (non-conforming, every real kernel's shape).
2. **The exec seed planted the Tos in bp, not ax (dat.rs)**: 14-03 read "bp=Tos via RARG" — but bp is 6c's FIRST-ARG register and the donor's contract is the exec RETURN: sysexecregs returns the Tos pointer, syscallreturn lands ar0.p in AX, and main9.s opens with `MOVQ AX, _tos(SB)`. 6l fuses that same prologue into `main` even when _main is absent (observed in boot's disassembly: `mov %rax, 0x400088` as the entry's second instruction) — so boot(8) stored AX=0 into _tos and malloc's `plock` (`pv->pid = _tos->pid`) fault-killed at addr 0x40 (the CR2 print added to trap.rs named it in one run). The exec syscall path was already correct (sys_exec returns exec_replace's tos_va through the AX writeback); only the first-process seed was wrong. Test expectations updated; ABI.md now records the contract.
3. **The stack seed was two pages (exec.rs)**: boot(8) faulted its stack at USTKTOP-0x21b8 (~8.6 KiB deep). Now 32 pages (128 KiB) map eagerly, and the Tos struct moved to the donor's placement — the very top of the seed page (USTKTOP-88, above the arg block) — so a downward-growing stack can never overwrite it (the old below-the-seed placement sat in the growth path).
4. **brk growth relied on the pager (syscall.rs)**: malloc's first sbrk faulted on the untouched growth page (the 14-04 no-pager era-limit, now hit by real binaries). sys_brk_'s private arm maps the grown range eagerly (same policy as map_text_eager; the pager remains the follow-up).

Plus the Harvey in-tree fix: **embed.c's `waitpid()`** — paqfs -i is a persistent server that never exits, so the 4e-original wait deadlocked boot(8) at the first fversion. The embed method was never exercised on 4e/9k (their boots use tcp/local) and k10t1's /boot/boot was an rc script (initcode's shell-script contract) — the bug slept until this chain. 9front's embedpaq.c has no wait; dropped with the provenance comment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] mkfile.amd64's include line carried a trailing `>`**
- **Found during:** Task 1's first build
- **Issue:** plan9port mk parsed `</$objtype/mkfile>` as a missing include file named `/amd64/mkfile>` — the build compiled bootr9.c with empty CC/CFLAGS. The tree's mkfiles use the bracket-less form.
- **Fix:** line 1 corrected to `</$objtype/mkfile`; re-run green end-to-end.
- **Files modified:** sys/src/9k/boot/mkfile.amd64
- **Commit:** harvey@66cd0fc1b

**2. [Rule 1 - Latent kernel defect] Conforming ktext broke ring-3 interrupt delivery (Task 3)**
- **Found during:** the first q35shell run (fault storm at the tick stub; qemu reset)
- **Issue/Fix/Evidence:** see "The four kernel fixes" #1. TCG's -d int trace + the delivery-source read pinned it; the fault arithmetic (CS=0x0B, SP=user-0x30, IPs at the stubs) matched the no-privilege-switch path exactly.
- **Files modified:** ../r9/x86_64/src/seg.rs
- **Commit:** r9@ac7aa92

**3. [Rule 1 - ABI bug] The exec seed's Tos rode bp instead of ax (Task 3)**
- **Found during:** the chain's fault at addr=0x40 (boot(8)'s _tos deref in malloc's plock)
- **Issue/Fix/Evidence:** see "The four kernel fixes" #2. The 6.out disassembly (the fused main9 prologue storing AX) was the decisive evidence; ABI.md corrected/extended.
- **Files modified:** ../r9/x86_64/src/{dat.rs,exec.rs,syscall.rs}, amd64/ABI.md
- **Commit:** r9@ac7aa92, harvey@86422fdea

**4. [Rule 2 - Missing-critical for the era] Two-page stack seed + lazy brk vs the no-pager reality (Task 3)**
- **Found during:** the chain's stack fault at USTKTOP-0x21b8, then the first malloc
- **Issue/Fix:** 32-page eager stack + the donor's Tos placement at USTKTOP-88; sys_brk_ maps growth eagerly. The 14-04 module docs record the pager as the follow-up.
- **Files modified:** ../r9/x86_64/src/{exec.rs,syscall.rs}
- **Commit:** r9@ac7aa92

**5. [Rule 1 - Sleeping upstream bug] embed.c's waitpid deadlock (Task 3)**
- **Found during:** the chain stalled between "paqfs..." and "version..."
- **Issue/Fix:** the 4e embed method waited for the never-exiting paqfs server. Dropped (the 9front shape), provenance commented in-tree.
- **Files modified:** sys/src/9k/boot/embed.c
- **Commit:** harvey@86422fdea

**6. [Rule 3 - Diagnostics] The user-trap print lacked the faulting address (Task 3)**
- **Found during:** the _tos hunt (pc alone could not distinguish NULL from a wild pointer)
- **Fix:** trap.rs's ring-3-origin exception print names CR2 (the donor faultnote's addr field).
- **Files modified:** ../r9/x86_64/src/trap.rs
- **Commit:** r9@ac7aa92

**7. [Rule 3 - Venue] The chroot scaffold lacked membername's PATH/tools (Task 1)**
- **Fix:** /rc/bin on the chroot PATH + tr in the /bin symlink farm (membername is an rc script using tr+sed); cmd-tree droppings explicitly cleaned after harvest.
- **Files modified:** build/x86_64/stage-build.sh
- **Commit:** harvey@66cd0fc1b

**8. [Rule 3 - Verify re-key] The plan's host-form direct-mk cannot run on this host (the 14-01..05 class)**
- **Fix:** the verify leg ran inside the same userns chroot scaffold via a one-off harness (never committed): `mk -f mkfile.amd64` + `test -s boot` + the od magic — DIRECT-MK-VERIFY-OK.
- **Files modified:** none (execution-only)

**Total deviations:** 8 auto-fixed (4 latent-defect/bug class, 1 missing-critical, 3 blocking/venue/diagnostic). **Impact:** the four kernel fixes are permanent improvements proven by the full regression battery; the remaining scheduler bug is documented below, not silently absorbed.

## Authentication Gates

None.

## Known Issues

**OPEN — the two-proc scheduler corruption (the q35shell gate's remaining red).** After "init: starting /bin/rc" (init's fexec fork of rc), the kernel panics with `misaligned pointer dereference ... 0xffffffff806f5010` attributed to the ProcGuard Deref (proc.rs:1514) — 0xffffffff806f5010 IS `&SCHED_CONTEXT`. Live qemu-monitor dumps (unix-socket monitor; the panic parks the kernel) established:

- CURRENT_PROC ends up holding `&SCHED_CONTEXT` (the run with a temporary set_current_proc bounds-assert never fired — the bad value arrives by a DIRECT wild write into the .bss static cluster at 0xffffffff806f5000 (CURRENT_PROC/SCHED_SEEDED/SCHED_CONTEXT/CURFRAME), not through any store path; that instrumented build instead showed `sched: switch 0->0` — pid read as 0 off &SCHED_CONTEXT — then `trap PF pc=0`).
- The failure is on the scheduler/Mach stack (two-proc context), AFTER the first fork+await-block of the chain — i.e., the first time a tick preempt must switch between two live procs. q35exec never exercises this (single proc — reschedule finds no other Ready and never switches).
- The instrumented build shifting the failure point earlier (layout sensitivity) is consistent with a wild write, not a logic-only bug.
- Leading theory (unproven, recorded for the follow-up): `reschedule` performs the locked switch — including `switch_cr3` — while executing on the CURRENT proc's kstack at the FIXED window VA (PML4[400], each proc's own four pages); after the CR3 switch the same VA maps the NEXT proc's kstack, so the code continuing on the old stack now reads/writes the wrong pages, and the eventual return through intrcommon's restore reads a clobbered frame. The park-and-switch-through-sched-context shape (like sched()) is the likely fix direction; a hardware watchpoint on CURRENT_PROC (KVM lacks -d int; TCG reproduces) or a scheduler-stack crawl via the parked monitor will pin the writer.

Recorded in .planning/WINDOWS.md as an open unmet-truth; the q35exec/q35/q35net/aarch64/ureg-check/check/clippy/host-test regression battery is GREEN at the final commit (the fixes carry; only the NEW two-proc path is broken).

## Issues Encountered

The Known Issue above — the plan's terminal truth (q35shell green twice) is not met; everything below it on the chain (14-07's composed artifact and the Harvey-side smoke) depends on its closure.

## TDD Gate Compliance

N/A — no task carries tdd="true".

## Next Plan Readiness

NOT ready for 14-07's composed gate: the chain bake and profile exist, but the r9-side chain gate must first go green twice (the scheduler-corruption fix is the one open item — it is a well-characterized kernel bug, not a chain-artifacts gap). 14-07's ISO-builder work is otherwise unblocked (it consumes the bake + template conventions that this plan landed).

## Self-Check: PASSED

- harvey files exist: mkfile.amd64, root-tree/{rc/bin/termrc,lib/namespace,usr/glenda/lib/profile} created; {stage-build.sh,mkimage.sh,embed.c,ABI.md} modified in harvey@{66cd0fc1b,a8cdb4c45,86422fdea}
- r9 files exist: config_q35shell.toml created; {seg,dat,exec,syscall,trap,main}.rs + xtask/main.rs modified in r9@ac7aa92
- commits are ancestors of HEAD: harvey 66cd0fc1b/a8cdb4c45/86422fdea ✓; r9 ac7aa92 ✓
- plan-level verification: Task 1+2 verifies green (logged in coverage); Task 3's verify is the documented OPEN failure (the gate red, regression battery green)
