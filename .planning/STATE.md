---
gsd_state_version: "1.0"
current_phase: 05
current_phase_name: Shell Boot + One-Command Integration
status: executing
stopped_at: Completed 05-05-PLAN.md
last_updated: "2026-11-03T06:35:12.536Z"
last_activity: 2026-11-02
last_activity_desc: Phase 05 execution started
state_head: 8743f2328f14a93055cd44d89a61c72d8ee9c25f
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 38
  completed_plans: 30
  percent: 79
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-02)

**Core value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.
**Current focus:** Phase 05 — Shell Boot + One-Command Integration

## Current Position

Phase: 05 (Shell Boot + One-Command Integration) — EXECUTING
Plan: 6 of 13
Status: Ready to execute
Last activity: 2026-11-02 — Phase 05 execution started

Progress: [████████░░] 79%

## Performance Metrics

**Velocity:**
- Total plans completed: 25
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 7 | - | - |
| 03 | 6 | - | - |
| 04 | 8 | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 53min | 3 tasks | 12 files |
| Phase 01 P02 | 6min | 2 tasks | 5 files |
| Phase 01 P03 | 8min | 2 tasks | 5 files |
| Phase 01 P04 | 60min | 2 tasks | 9 files |
| Phase 02 P01 | 13 min | 3 tasks | 46 files |
| Phase 02 P02 | 5 min | 2 tasks | 13 files |
| Phase 02 P03 | 19 min | 3 tasks | 28 files |
| Phase 02 P04 | 4h 41m | 2 tasks | 19 files |
| Phase 02 P05 | 11h 18m (incl. human-verify wait) | 2 tasks | 7 files |
| Phase 02 P06 | 6 min | 2 tasks | 9 files |
| Phase 02 P07 | 47 min | 3 tasks | 16 files |
| Phase 03 P01 | 13 min | 1 tasks | 2 files |
| Phase 03 P02 | 5 min | 2 tasks | 12 files |
| Phase 03 P03 | 30 min (incl. human-decision checkpoint) | 2 tasks | 2 files |
| Phase 03 P04 | 26 min | 2 tasks | 12 files |
| Phase 03 P05 | 10 min | 3 tasks | 8 files |
| Phase 03 P06 | 18 min | 2 tasks | 9 files |
| Phase 04 P01 | 33min (continuation; prior segment reached the A3 decision checkpoint) | 3 tasks | 14 files |
| Phase 04 P02 | 15min | 2 tasks | 9 files |
| Phase 04 P03 | 8m | 3 tasks | 7 files |
| Phase 04 P04 | 17min | 2 tasks | 10 files |
| Phase 04 P05 | 31min | 2 tasks | 16 files |
| Phase 04 P06 | 27min | 2 tasks | 18 files |
| Phase 04 P07 | 240min | 2 tasks | 12 files |
| Phase 04 P08 | 40min | 3 tasks | 18 files |
| Phase 05 P01 | 64 min | 3 tasks | 11 files |
| Phase 05 P02 | 15 min | 3 tasks | 9 files |
| Phase 05 P03 | 225 min | 2 tasks | 7 files |
| Phase 05 P04 | 55 min | 3 tasks | 18 files |
| Phase 05 P05 | 26 min | 2 tasks | 14 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- 2026-10-30: Adopt r9 (sibling `../r9`, Rust) as kernel future — Harvey 9k C aarch64 port is Out of Scope
- 2026-10-30: `aarch64` (not `arm64`) is the project's architecture name — vestiges quarantined in Phase 1
- Roadmap: Phases 3–4 execute in sibling repo `../r9`; Phase 5 spans both repos
- [Phase 01]: 01-01: userland preflight in nix/build.sh is sentinel-armed (amd64/.userland-ok) — inert until a build first produces all four kernel-critical binaries, so clean/repairing runs never deadlock (plan Task 1 NOTE)
- [Phase 01]: 01-01: efiboot.fat is explicit-only (needs a live Plan 9 system: dossrv+/srv+mount); .efi binaries still build+install — unmasked games tree (D-01)
- [Phase 01]: 01-01: NVAR=BITS*32 in cc.h restores exact Plan 9 256-var-cap semantics on LP64 hosts — fixes 6c stack smash (ql SIGBUS); one shared definition fixes all compiler dirs
- [Phase 01]: 01-01: git.allow_default_branch_commits=true — sequential-mode execution commits on master (fork workflow); clean-checkout verification clones the default branch
- [Phase 01]: 01-02: six-site arm64 quarantine in ONE atomic commit 5af5e89bf (D-05 + Pitfall 3 bind-mount coupling); keepers documented (nix host-mapping, lima yaml, a.out.h/mach.h, unix/9cc, dynld-arm64.c)
- [Phase 01]: 01-02: Phase 1 green gate = amd64 kernel loop — linux-build arch=(amd64), dist/man stages behind WITH_DIST=1 (RESEARCH OQ-2/OQ-3); revert comments in place
- [Phase 01]: 01-03: KERNDATE derivation anchored to $HARVEY checkout (cd "$HARVEY" && git log -1 --format=%ct) in both nix entry points — HARVEY!=PWD invocations must not pin the caller's repo
- [Phase 01]: 01-03: reproducibility evidence standard = pinned pair identical + KERNDATE+1 negative control differs + restore matches — falsifies 'deterministic anyway'
- [Phase 01]: 01-03: guest namespace harnesses need su-proof env: re-source captured exports (BUILD's . buildnamespace) + /rc/bin:. PATH tail (repo rc/bin/membername feeds bootmkfile's archive rule)
- [Phase 01]: 01-04: TCG-degraded serial capture ACCEPTED by human (2026-10-31, blocking checkpoint) as BUILD-05's phase demonstration — dev fleet has no KVM host; KVM path documented (nix build .#minimega && sudo build/mm/boot-9k10cpu.sh) for any Linux x86_64 host
- [Phase 01]: 01-04: LP64 wide-constant truncation fixed in amd64 toolchain (6c/swt.c zaddr, 6l/span.c oclass, 6c/cgen.c immconst) — harness surfaced a silently miscompiled kernel; dormant-arch siblings (4c/9c/9a/4l/9l) inventoried + deferred
- [Phase 01]: 01-04: serial capture attaches BEFORE vm start via launch/start .mm split; banner grep (not the boot timer) is the boot-proof source of truth; minimega -e exit status never trusted (socket-appearance gating)
- [Phase 02]: audit-7c7l vindicated: cc/pswt.c LP64 switch-sort miscompile (doswit (long)c->val no-op on LP64 → swcmp signed sort disagrees with swit2's signed target compare tree) was the donor kernel's deterministic "bad magic" pool panic; fixed host-independently as (vlong)(int); Phase-1 9k-amd64 pool panic is the same signature (deferred item 8: re-test with fixed 6c)
- [Phase 02]: donor↔qemu-11.1.2 drift accommodated harness-side only (D-12): gic-version=3, highmem-ecam=off, DTB pre-placement, GICR0 WAKER wake poke via raw-RSP gdbpoke9.py (qemu resets redistributor asleep; donor gic.c never wakes it; no ticks → dead console input), console=0 (kbdfs input device), virtio-net-pci-non-transitional (ethervirtio10 matches only modern 0x1041)
- [Phase 02]: 02-05: TC-03 gate SATISFIED and human-approved — committed hello.7.out executes on the 9front donor kernel (marker after term% prompt, clean exit, sha256 1c89e099 both sides, three consecutive PASS blocks); scaffolding 02-06 unblocked; hello.7.out is Phase 4's ABI bisect point
- [Phase 02]: 02-05: guest path resolution — CONF=qemu bootdir embed lands at /boot/hello (devroot exposes only boot/); bootfs.paq is unmounted before the shell so paq-baked binaries are unrunnable at the rc prompt; mkpaqfs not re-run
- [Phase 02]: 02-05: bake-vs-ufs resolved in build/aarch64/README.md (research OQ-2) — bake-into-bootfs for gates (deterministic), ufs-over-tcp for iteration (ethervirtio10 + ip stack; srv9.py proves host 9P2000/tcp to this guest)
- [Phase 02]: 02-07: subset lib set = the #pragma-lib closure discovered at link time (libbio libregexp libndb libString libthread lib9p beyond the named libip/libmp/libsec/libauth/libauthsrv); libbio precedes the 7? loop (7a/a.h includes bio.h); factotum ships via per-target install (fgui's graphics stack is out of scope)
- [Phase 02]: 02-07: mpvecdigmulsub split into its own libmp port file retires the 2021 PORT rename — archive member names now align 1:1 with text symbols (empty-arch dirs get portable C, asm arches cull via reduce, ape's broken-bind reduce can never duplicate-symbol)
- [Phase 02]: 02-07: srv9.py --writable-prefix (opt-in, scoped) is the guest's writable-scratch mechanism (kernel MCREATE bind already permits /tmp); nix run .#build rc is never trusted — artifact checks + zero-failure-marker log scan are the gate (BUILD's break-glass bash tail swallows statuses, deferred item 12)
- [Phase 03]: 03-03: tcg/cortex-a72 built-in defaults fire only on the virt arm — existing raspi TOMLs sprout no new argv (backward-compat holds end-to-end, verbose-probe verified); darwin runs TCG this phase (HVF rejects GICv2 on qemu 11.1.2, research P2), hvf remains selectable for a future GICv3 driver
- [Phase 03]: 03-03: superseded apply_to_qemu_step free function removed outright instead of kept as a delegating shim — xtask-internal API with a single call site; a compat wrapper would be dead code
- [Phase 03]: 03-03: written raspi3b boot-smoke gate satisfied by substituted A/B evidence (human decision A, 2026-11-01) — identical pre-existing raspi3b-on-qemu-11.1.2 guest abort at FAR 0xfe215004 pre-plan (6a309ae/ae4cd08) and post-plan with byte-identical raspi argv proves NO REGRESSION; upstream defect (rpi4 AUX_ENABLES MMIO on raspi3b machine; suspect init_early_uart_rpi4) deferred
- [Phase 03]: 03-03: darwin qemu smoke isolation — setsid absent on macOS; backgrounded subshell + pkill -f with bracket-fixed pattern ([q]emu-system-aarch64.*raspi3b) so pkill cannot self-match the harness shell argv
- [Phase 03]: 03-06: D-12 delivered as --config virtpanic (virt-specific name; mechanism/trigger/dump as decided) — brk #0 hook before trap::unmask_irq() runs the real sync trap path; TrapFrame Debug uses bare x29/x30 names so dump rows are machine-countable (the plan's >=30-row gate was unsatisfiable with annotated names)
- [Phase 03]: 03-06: RustupState tolerates rustup-absent hosts (nix devshell) — cargo xtask check/test degrade to bins/lib legs via existing Option handling instead of panicking; pre-existing panic proven on the clean tree
- [Phase 03]: 03-06: evidence commit ordering (D-13/T-03-09) — r9 commits land first, EVIDENCE.md records that exact HEAD SHA (55ca7c4), harvey evidence commit second; the verify gate requires the recorded SHA to match the live checkout
- [Phase 04]: D-01 AMENDED (04-01, user decision A): qemu 11.1.2 never delivers -initrd for ELF kernels (hw/arm/boot.c: ELF => not-linux), falsifying assumption A3. Root-fs/initrd delivery is now qemu generic loader at a TOML-data PA + xtask-produced fdtput-patched DTB copy carrying /chosen linux,initrd-start/end (two 32-bit BE cells, hi first — dtc has no 8-byte type). Kernel /chosen discovery/validation/reservation unchanged; ELF boot preserved per D-05. — D-01's locked mechanism (qemu -initrd + DTB /chosen) was written against the assumption that qemu loads -initrd for ELF kernels; source inspection + serial evidence falsified it. The loader+patched-DTB replacement keeps every downstream consumer (kernel /chosen parse, validation, pagealloc reservation) identical — only the host-side delivery and DTB handoff change.
- [Phase 04]: D-14 measured hello-path syscall set (04-01, donor pin 350266104f, primary startsyscall+/proc/N/syscall method): 51 pwrite, 14 open (#c/pid), 50 pread, 4 close, 8 exits — fmt/pool pulls no brk_/segbrk on this path. 04-06/07/08 implement exactly this set plus D-14's named core. — Measured, not guessed (D-14). The open/pread/close triplet is the exits path resolving its own pid via #c/pid; the absence of brk_/segbrk settles the fmt/pool watch item by evidence.
- [Phase 04]: Harvey libflate adler32 is the seed-0 variant (mkpaqfs writes adler32(0,...)); r9's paqfs reader reproduces it via adler2::Adler32::from_checksum(0) — proven against fixture block headers (root block 0x479d0ee0) — RFC 1950 seeds s1=1; Harvey seeds s1=0. Fixture bytes proved the mismatch (seed-1 yields 0x579d0ee1). from_checksum(0) keeps the plan-mandated adler2 crate instead of a hand-rolled checksum.
- [Phase 04]: r9 has no full-RAM kernel map: runtime access to a physical range (initrd) maps it explicitly via kernel_pagetable().map_phys_range with VaMapping::Offset(KZERO) — vminit's DTB convention, reused post-boot — 04-02 plan assumed an existing KZERO+PA physical-map convention that does not exist (vminit maps only DTB+kernel sections). 04-04's fault handler reads the initrd through the same mapping.
- [Phase 04]: paqfs reader API grew root_dir()/read_dir() beyond the plan sketch — directory listing is required by the boot root-walk and 04-05 devroot; stateless-per-call invariant preserved — The 4-method sketch (open_image/read_block/walk/read_at) cannot express listing a directory's entries.
- [Phase 04]: Boot serial evidence emits banner FIRST, then initrd marker, then paqfs root-entry lines — the 04-01 marker block moved below the banner print — 04-02 acceptance pins emission order (banner first); 04-01's greps were order-insensitive and remain satisfied.
- [Phase 04]: 04-03 publication gate resolved: user selected 'publish' — D-05/D-07 kernel-side ABI contract published as locked (35-field frame, sp@248/pc@256/psr@264/type@272, size 280 stride 288; OQ-3 type-field = kernel-side informational)
- [Phase 04]: 04-03: ESR_EL1/FAR_EL1 are never frame fields — read live at trap() entry, passed as dispatcher args (04-04 fault handler signature fault::user_fault(frame, esr, far))
- [Phase 04]: 04-03: ureg-check missing-Harvey policy — skip+continue for bare builds (layer-1 const asserts guard), FAIL boot-test runs; R9_HARVEY_DIR env override, default ../harvey
- [Phase 04]: 04-04: kernel-stack VA allocation rides vm::next_free_device_page4k (the kernel-VA bump allocator) — 4 contiguous VA pages per proc, each a fresh pagealloc page, contiguity asserted loudly
- [Phase 04]: 04-04: exec maps the two seed pages into the proc's INACTIVE root table via map_to's temp-recursive dance and writes contents via KZERO+PA aliases; the fault handler maps demand pages into the ACTIVE user table and writes through the user VA — two edit paths, split by table liveness
- [Phase 04]: 04-04: fault handler kills on already-mapped-page faults (mapping_log lookup, the donor fault() existence check) — remapping a live page would silently zero its contents
- [Phase 04]: 04-04: r9 user address-space policy constants landed (D-11): USTACKTOP=0x0000_8000_0000_0000, USTKSIZE=16 MiB, USTOP=USTACKTOP-16MiB in exec.rs
- [Phase 04]: 04-05: trap-entry stack switch removed (9front no-switch shape) — the old entry poisoned every frame's x0 with the interrupt-stack address; EL0 entry only via trap_return
- [Phase 04]: 04-05: staged-init supply chain landed — stage-build.sh (lima 7c/7l) → build/aarch64/out/ → cargo xtask initrd (mkpaqfs) → target/bootfs.paq; initrd path in config is workspace-relative (dtb emission base)
- [Phase 04]: 04-05: WR-01 closed — TTBR0 identity map torn down at first exec with the console-liveness proof print; D-12 experiments deleted; tick print cfg(not(dev_exec))-gated (Pitfall 3)
- [Phase 04]: 04-06: syscall dispatch landed — implemented set is exactly the 04-01 trace {pwrite(51), open(14), pread(50), close(4), exits(8)} ∪ {exec(7)}; no brk_/segbrk (trace-settled); loud-unimplemented + -1 for everything else; per-access user-VA validation (T-04-11)
- [Phase 04]: 04-06: SC#2 SATISFIED — committed hello.7.out (sha256 1c89e099…) exec'd by staged init on r9/qemu-virt prints via the real EL0 svc path; evidence 04-06-sc2-boot.log at r9 HEAD 230fc74 (D-13 ordering)
- [Phase 04]: 04-06: Rule-1 fix — demand-pager file reads clamped to the exact segment content end (unclamped reads bled paqfs syms bytes into bss tails; poisoned exits()'s onex[i].f into an indirect call to 'tas.s')
- [Phase 04]: 04-06: dat.rs Mode bitflags replaced with frozen Plan 9 open-mode constants (deferred #1 resolved); DEV_ROOT/DEV_CONS chan.dev routing until the devtab era; pagealloc gains deallocate_physpage; proc records kstack PAs for the EXITS free
- [Phase 04]: 04-07: return-side CURKSTACK load enforces the per-process entry-stack invariant (an entry-side switch is impossible on aarch64 without the 04-05 x0-clobber)
- [Phase 04]: 04-07: swtch.S rewritten symmetric — the imported sequence could never round-trip (latent, never called on aarch64)
- [Phase 04]: 04-07: 1 ms tick slice + init's calibrated spin (preemption evidence needs a CPU-bound EL0 window with live peers); syscall int-width args masked to 32 bits (donor va_arg semantics)
- [Phase 04]: 04-07: exec_bootstrap IRQ-masked until first EL0 entry — boot orchestration is a non-preemptible critical section; invariant: PSTATE.I=0 only at EL0 or the stateless sched wfi (heisenbug exposure closed by construction, root cause = deferred-items #4)
- [Phase 04]: 04-08: note delivery resolves CURFRAME on the IRQ boundary (preemption-safe — deliver to the proc actually returning to EL0); delivery write window validated user-writable THEN forced resident (never a kernel write to a bad/unmapped user VA)
- [Phase 04]: 04-08: NOTED takes dispatch's no-writeback special return on success (donor dosyscall case); sys_noted validates resume pc/sp BEFORE the 280-byte restore; exec clears note machinery, rfork inherits the handler (donor semantics)
- [Phase 04]: 04-08: 7c caches a plain static load in a register across a spin loop (volatile included) — a note-handler-set flag must be read through a real C call or the store is never observed (caught by the SC#4 gate)
- [Phase 05]: 05-01: note-timeout race root-caused to the trap_return tail's post-restore x9 clobber (psr re-read + CURKSTACK load); fixed by the uniform frame+288 final-sp step — every restored frame sits at entry-stack-top-288 by construction, so no post-pops scratch is needed. 20/20 virtnotes + 20/20 virtmulti clean, twice. r9 83cbbbe.
- [Phase 05]: 05-01: long is 32-bit in Plan 9 C on every arch (7c SZ_LONG=4; only vlong is 64-bit); the donor kernel's va_arg(list,long) reads the slot's low half — pread/pwrite's n is now masked to 32 bits in r9 (61e6a70). stacksmoke's deep recursion exposed the deviation; Harvey libc stays donor-pristine.
- [Phase 05]: 05-01: D-16 harness hygiene landed r9-side (c2f141e): fresh serial log per run + qemu spawned as process-group leader + group kill at teardown — phase-04 deferred #2 closed.
- [Phase 05]: [Phase 05]: 05-02: bootr9.c hand-written bootconf supplies SIX symbols, not four — method[]/cpuflag/rootdir/bootdisk plus main()→boot() and cfs=0 — because the awk mkbootconf generator emits all six and the 7l link cannot resolve without them (boot.h's extern cfs; libc startup needs main)
- [Phase 05]: [Phase 05]: 05-02: BOOTFILES trimmed to the real 7l closure by reference analysis — paq.7 is the lone trim (embed-only table never names it); bootcache.7 stays for statbuf (settime/local extern it), bootip.7 via local.c's configip, printstub.7 linked explicitly so its fmt stubs beat libc's fmtlock members
- [Phase 05]: [Phase 05]: 05-02: build/aarch64/out/ ownership — subset-build.sh syncs its four boot-chain binaries per-file (no --delete); stage-build.sh keeps wholesale --delete for the staged-init supply chain (05-10's "unchanged" constraint); last writer wins, and mkimage.sh's manifest assert names the fix
- [Phase 05]: [Phase 05]: 05-02: adm/timezone/local is copied into the staged tree at bake time from the repo's adm/timezone/local (not committed to root-tree/) — the action text's "copy at bake time" governs over the files_modified listing
- [Phase 05]: 05-03: the real-chain donor trace is the measure-first gate for the kernel stream — 26 syscalls measured (16 NEW vs Phase 4: bind, chdir, dup, alarm, fauth, sleep, pipe, create, fd2path, brk_, unmount, seek, fversion, stat, fstat, mount); 05-04..05-09 implement exactly this set — Measured on the 9front donor with the 05-03 rig (born-traced arming + tagged fragments); opencons provably captured; REMOVE/WSTAT never fired (loud-unimplemented stays)
- [Phase 05]: 05-03: donor trace accommodations that do NOT carry to r9: devcons /dev/cons reads Egreg by design on the donor (kbdfs-served consoles) so the sweep was sourced not typed; r9's devcons serves reads (D-06) and 05-09 drives the console for real — opencons's bind #c MBEFORE pins the kernel cons into the chain's fd 0 on the donor; the donor's devcons refuses Qcons reads (Egreg) — the trace termrc sources the sweep instead
- [Phase 05]: 05-03 finding for 05-08: the image's scoped /lib/namespace needs the k10root-style re-mount (mount -a #s/boot /root; bind -a /root /) BEFORE its /root-prefixed bin binds — newns's RFCNAMEG wipe discards boot's mount table — proven empirically on the donor: the trace namespace file with exactly that shape let init's newns resolve /bin/rc; without it the replay fails soft and init's exec stalls
- [Phase 05]: exec maps data+bss eagerly (05-04): phase-04 deferred #3 lands — real binaries pass cold syscall-arg pages; T-05-06 no-nested-paging holds; D-09 pinned wording (text fault-in + stack growth) untouched
- [Phase 05]: rfork namespace semantics follow fork(2)/9k sysrfork (05-04 plan-text inversion corrected): RFPROC+neither shares Arc<Lock<Pgrp>>, RFNAMEG deep-copies, RFCNAMEG wipes; non-RFPROC split re-groups the caller
- [Phase 05]: staged init binds #p at /proc itself (donor shape) — the namespace era retired the routing scaffold; xtask initrd tree ships empty proc/ (Pitfall-8)
- [Phase 05]: /rootfs.img synthesized by devroot pulled forward from 05-05 Task 2 (the 05-04 gate needs dirstat(paqfile)); real image entry always wins; 05-05 hardens
- [Phase 05]: sys_brk_ landed in 05-04 per the dispatch-note mandate (brk_ ×28); boot dirstat mallocs are gate-load-bearing; brk_ = bss-break set with USTOP cap
- [Phase 05]: multi-config verify ordering: all aarch64 configs share target/.../debug/aarch64 — the config under gate must build LAST (the raspi4b leg otherwise overwrites the virtshell ELF)

### Pending Todos

None yet.

### Blockers/Concerns

- ~~Phase 4: Harvey↔r9 syscall ABI kernel side greenfield~~ RESOLVED — Phase 4 complete: ABI published + build-pinned (R9-04), measured-set dispatch (R9-02), first-process demand-paged path (R9-03); the Wave-0 spike pattern caught the A3 delivery falsification early
- ~~Phase 4: root-fs delivery mechanism to r9 undecided~~ RESOLVED — D-01 amended (04-01): qemu generic loader + fdtput-patched DTB (qemu never delivers -initrd for ELF kernels)
- ~~Phase 4: WR-01 — virt TTBR0 identity map never torn down~~ RESOLVED by 04-05 (D-10 teardown + console-liveness proof at every exec-profile boot)
- ~~KERNDATE bit-reproducibility policy must be decided in Phase 1 (BUILD-04)~~ RESOLVED by 01-03: pinned git-derived policy documented at build/REPRODUCIBILITY.md and demonstrated bit-identical — Phase 5 reproducibility claims unblocked
- Phase 5: note-delivery timing race (smokenote `note-timeout` flake, ~1/3 virtmulti runs, reproduces on pre-fix base) — debug candidate; 04-REVIEW-FIX.md
- Phase 5: stack-growth machinery proven-by-shared-path but never exercised (no evidence run grew the stack; UAT-accepted) — first deep-stack binary is the real test
- Phase 5: 8 open Info findings (04-REVIEW-DISPOSITION.md) + phase-04 deferred #2/#3/#4 (harness qemu cleanup, cold-pointer syscall aborts, contained heisenbug) — none goal-blocking
- 9k-amd64 post-banner `bad magic` pool panic — same signature as the pswt.c LP64 bug fixed in Phase 2; re-test with the fixed 6c (deferred-items.md #8) before relying on the harness for deeper smoke signals
- Hygiene debt: Phase 1 review items (01-REVIEW-DISPOSITION.md) + Phase 2's 13 open Info findings (02-REVIEW-DISPOSITION.md) + Phase 3's 5 open warnings / 10 open Info (03-REVIEW-DISPOSITION.md; WR-02 boot-test platform guard, WR-03 raspi uartpl011 gpiosetpull MMIO window, WR-04 map_phys_range swallowed mid-range failure, WR-05 timer INTID DTB-mismatch warn-only) + upstream raspi3b-on-qemu-11.1.2 defect (phase-03 deferred-items.md #1, human-accepted A/B evidence); none goal-blocking

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-11-03T06:35:12.467Z
Stopped at: Completed 05-05-PLAN.md
Resume file: None
