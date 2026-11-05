---
gsd_state_version: "1.0"
milestone: v2.0
milestone_name: Full System & Drawterm
current_phase: 07
current_phase_name: r9 PCI/ECAM + virtio-net + devether
status: verifying
stopped_at: Completed 07-09-PLAN.md
last_updated: "2026-11-05T14:29:56.076Z"
last_activity: 2026-11-04
last_activity_desc: Phase 07 execution started
state_head: 69c4cf689a54c5371d5a8c903ef5d670c4d520eb
progress:
  total_phases: 7
  completed_phases: 5
  total_plans: 17
  completed_plans: 17
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-04)

**Core value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.
**Current focus:** Phase 07 — r9 PCI/ECAM + virtio-net + devether

## Current Position

Phase: 07 (r9 PCI/ECAM + virtio-net + devether) — EXECUTING
Plan: 8 of 8
Status: Phase complete — ready for verification
Last activity: 2026-11-04 — Phase 07 execution started

Progress: [░░░░░░░░░░] 0% (v2.0)

## Performance Metrics

**Velocity:**
- Total plans completed: 38
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 7 | - | - |
| 03 | 6 | - | - |
| 04 | 8 | - | - |
| 05 | 13 | - | - |

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
| Phase 05 P06 | 110 min | 3 tasks | 19 files |
| Phase 05 P07 | 106 min | 3 tasks | 17 files |
| Phase 05 P08 | 223 min | 3 tasks | 14 files |
| Phase 05 P09 | 54 min | 2 tasks | 14 files |
| Phase 05 P10 | 10 min | 2 tasks | 4 files |
| Phase 05 P11 | 25 min | 3 tasks | 6 files |
| Phase 05 P12 | 6 min | 2 tasks | 5 files |
| Phase 05-shell-boot-one-command-integration P13 | 9 min | 3 tasks | 7 files |
| Phase 06 P01 | 35 min | 3 tasks | 8 files |
| Phase 07 P01 | 10min | 2 tasks | 3 files |
| Phase 07 P03 | 19 min | 2 tasks | 4 files |
| Phase 07 P04 | 19 min | 2 tasks | 5 files |
| Phase 07 P04 | 19 min | 2 tasks | 5 files |
| Phase 06 P02 | 30 min | 3 tasks | 16 files |
| Phase 07 P02 | 12min | 2 tasks | 7 files |
| Phase 07 P05 | 12 min | 2 tasks | 4 files |
| Phase 07 P06 | 25 min | 2 tasks | 18 files |
| Phase 06 P03 | 71 min | 2 tasks | 11 files |
| Phase 06 P04 | 37 min | 2 tasks | 9 files |
| Phase 07 P07 | 63 min | 2 tasks | 20 files |
| Phase 07 P08 | 20 min | 2 tasks | 5 files |
| Phase 06 P05 | 31 min | 2 tasks | 14 files |
| Phase 06 P06 | 65 min | 2 tasks | 14 files |
| Phase 06 P07 | 4h 27m | 2 tasks | 24 files |
| Phase 06 P08 | 4h 8m | 2 tasks | 8 files |
| Phase 07 P09 | 18 min | 4 tasks | 7 files |

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
- [Phase 05]: [Phase 05] 05-06: rfork fd-group semantics follow fork(2)+9k sysproc.c — the plan's bullet inverts RFFDG vs default (NEITHER share / RFFDG copy / RFCFDG empty); the donor governs — the phase's THIRD flag inversion (05-04 RFNAMEG, 05-05 RFENVG precedents). libc fork()=rfork(RFPROC|RFFDG|RFREND)=COPY is exactly what connectembed's child dup/close choreography requires; the staged init's rfork(RFPROC|RFMEM) children now SHARE its fd table (fork(2)) and the fan proves them green
- [Phase 05]: [Phase 05] 05-06: the pipe is TWO cross-connected queues in ONE Arc-shared Pipe (9k devpipe.c — the plan's own semantic reference — governs): paqfs's io(1) reads AND writes fd 1, which a single FIFO cannot serve (a server would consume its own replies); the plan's "single shared queue" prose names the shared pipe STATE both ends reference
- [Phase 05]: [Phase 05] 05-06: FdGroup slots are heap-backed (Vec) — an inline [Option<Chan>; 32] (~5.7 KB) in Proc::new overflowed the 16 KiB kstack into the proc's root-table page (the rfork chain's construction); no giant stack temporaries in proc construction is now a pattern rule
- [Phase 05]: [Phase 05] 05-06: fault::ensure_user_resident closes the cold-syscall-buffer class (phase-04 deferred #3's post-exec half): paqfs's emalloc'd heap buffers are brk_-grown demand pages whose first touch was the kernel's pread write — explicit zero-page-in before deref (04-08's T-04-16 pattern generalized); never a nested fault, so T-05-06 holds. Wired into pread/pwrite/errstr/await/fd2path/pipe's buffer paths
- [Phase 05]: [Phase 05] 05-06: sys_seek (SEEK 39, measured ×72) landed via the gate's iterate-discipline + RFNOTEG accepted as a no-op (per-pid notes have no group to split; paqfs's rfork requires it); devsrv/devdup live boot-chain exercise is 05-07's (boot.c:141 fversion precedes :144 srvcreate — the plan's gate prose inverted that order; semantics host-pinned)
- [Phase 05]: [Phase 05]: 05-07: the 9P session rides the chan (the donor's c->mux) — fversion parks the Arc<Mnt> on the pipe fd's chan and Chan::dup clones it, so devsrv's posted clone carries the session to settime's/newns's second mounts of #s/boot (a fresh Tattach fid per mount; the session is shared)
- [Phase 05]: [Phase 05]: 05-07: one outstanding RPC per devmnt session via an AtomicBool (an MCS lock across the blocking recv would spin-deadlock an IRQ-masked contender; contention errors loudly, never wedges); the pgrp-lock-across-blocking-walk hazard is documented + deferred (the namec chain-snapshot fix lands with the first measured concurrent caller — the staged-init wedge proved the shape)
- [Phase 05]: [Phase 05]: 05-07: per-RPC read counts clamp to 4072 (devpipe's 4096 atomic-write bound minus IOHDRSZ) even at negotiated msize 8192 — the pipe write is whole-message-or-fail; the donor's iounit clamp with the era's transport binding
- [Phase 05]: [Phase 05]: 05-07: exec through the mount stages the WHOLE binary eagerly (proc.rs ByteBacking::Mnt, Arc-shared, 16 MiB loud cap) — the trap-context pager must never RPC; syscall context is where blocking belongs. sys_exec resolves via namec now (the Phase-4 devroot-only prefix scaffold retired — D-03)
- [Phase 05]: [Phase 05]: 05-07: mkimage.sh asserts out/init is the REAL init at bake time (rodata markers) — the 05-02 'last writer wins' out/ ownership means r9's boot-test bake (stage-build.sh) re-pollutes; the bake fails loudly instead of booting the staged chain. The aarch64 seek ABI is the generated _seek stub's FOUR args (rv ptr, fd, offset, base) with the result written through *rv (the donor sysfile.c sysseek comment is the authority; 05-06's slot-0-as-fd reading was wrong)
- [Phase 05]: [Phase 05] 05-08: the console DEL posts "interrupt" to the note GROUPS of the console's readers (blocked waiters ∪ the current reader) — the plan's sanctioned foreground-group scoping for the notepg machinery; r9 grew real note-group ids for it (Proc.noteid: fresh per construction, rfork inherits unless RFNOTEG, non-RFPROC RFNOTEG re-groups the caller — 9k sysproc.c), so init's rfork(RFNOTEG)'d shell children are interrupted without init ever seeing the note.
- [Phase 05]: [Phase 05] 05-08: DEL (0x7f) discards the in-assembly partial line and fails the reading syscall -1/"interrupted" (the donor's qread-under-a-note → rc's Eintr re-prompt); no input ECHO this era (documented devcons delta — typed bytes never re-write to the wire); sleep(0) yields via preempt(); a sleeper wakes only on expiry (the donor's note-interruptible tsleep is a documented era limit — no measured caller interrupts a sleep).
- [Phase 05]: [Phase 05] 05-08: two gate-caught fixes — (1) launchers spawning qemu's stdio serial in the background MUST pass <&0 explicitly: a non-interactive sh redirects a backgrounded command's stdin from /dev/null (POSIX), silently starving console input (run-r9.sh); (2) pick_next no longer skips the current proc — a proc that blocks via sched() stays current while the sched loop runs, so a tick-readied waiter was unpickable (the cons-read deadlock); the scan still starts at cur+1 (the readied current is picked last — fairness kept).
- [Phase 05]: [Phase 05]: 05-09: devproc qid re-encoded pid*8+slot (note 1, status 2, args 3, ctl 4) — transient internals, note path byte-identical (Pitfall 5); Proc.argv recorded at EVERY exec (install_image shared) with ARGV_CAP 256 + documented truncation; rfork inherits pri but NOT argv (truthful-args: pre-exec reads EMPTY)
- [Phase 05]: [Phase 05]: 05-09: #c/pid landed via a devproc-style injected current-pid hook — getpid() resolves so init's pri-10 write names the real pid (the designed warning is gone); devproc ctl accepts+records "pri N" (Proc.pri — the plan's honest degradation, no scheduler priority this era), unknown verbs loud
- [Phase 05]: [Phase 05]: 05-09: mount-table fid aliasing fix — namec's redirects fid-CLONE DEV_MNT heads (devmnt::clone_chan, the zero-name Twalk idiom) instead of bare-dup; a redirect's open+close must never Tclunk the table's server-side fid (the ls /bin → ps exec gate failure)
- [Phase 05]: [Phase 05]: 05-09: stat(5) records carry FOUR strings (muid added) — dirreadall's statcheck walks four and rejects three (convM2D.c); devproc fixed, the same latent shape in devcons/devroot/devenv/devsrv/devdup deferred (no dirreadall consumer this era)
- [Phase 05]: [Phase 05]: 05-09: dispatch table closed against the 05-03 measured set — REMOVE/WSTAT/FWSTAT/OSEEK never measured → loud-None; FAUTH loud-None per D-02; the kernel's syscall attack surface is exactly the measured set (T-05-18)
- [Phase 05]: [Phase 05]: 05-09: the input-wedge flake (2/~7 early sweep runs wedged at a prompt read; 6 consecutive clean passes since; never reproduced under the cons watchdog) documented-not-fixed — this plan's diffs don't touch the cons/wake/note/sched/timer paths; top debug candidate for 05-12/05-13's CI leg
- [Phase 05]: 05-10: r9 packages.kernel-virt builds the virtshell kernel in a sandboxed derivation — toolchain via toolchainFor/fromRustupToolchainFile (D-09), deps vendored from BOTH Cargo.lock and the rust-src library lockfile (the -Z build-std sysroot graph has its own crates.io members); layout: kernel-virt.elf + aarch64/lib/virt-gicv2.dtb (the 05-11 consumption contract); debug profile (the gate default — no release canonical exists) — D-11 pins a kernel-only package; the two-lockfile vendoring is the idiomatic nix-rust shape for -Z build-std in a sandbox (the plan's sanctioned executor latitude)
- [Phase 05]: 05-10: D-10 inversion landed r9-side — uregcheck::harvey_dir returns Result; unset/empty R9_HARVEY_DIR is a named error (names the variable + required checkout contents); initrd/boot-test auto-bake/ureg-check all require it; set-but-headerless keeps the two-tier shape (standalone skip, boot-test fail); r9 CI untouched — 05-CONTEXT D-10's one-way inversion: r9 knows nothing about sibling checkouts by default; the explicit contract keeps the r9-side regression gates (D-12) working against the unchanged staged-init supply chain (RESEARCH OQ-2 lowest-risk answer)
- [Phase 05]: [Phase 05]: 05-11: r9 main pushed to origin BEFORE locking (33a9273..9549cee, 80 commits — 05-01 + 05-04..05-10) so the github:requaos/r9 pin resolves from a clean clone (INT-03's leg); flake.lock then pinned 9549cee with the locked-rev==live-HEAD gate + owner=requaos metadata check
- [Phase 05]: [Phase 05]: 05-11: subset-build.sh owns BOTH transports — additive NATIVE_LINUX leg (nsrun.sh sudo-unshare, artifacts land in place via the binds, no rsync-back, host toolchain auto-bootstrap mirrors vm-run.sh) — the plan's 'linux → the same script natively' was impossible as shipped (hard limactl requirement); darwin leg byte-identical and gate-proven
- [Phase 05]: [Phase 05]: 05-11: compose-app contract — kernel/DTB arrive ONLY via the nix-controlled R9_KERNEL_PKG store path (presence validated before launch, T-05-21); qemu runs as a foreground child (not exec) so the EXIT trap reclaims the mktemp DTB dir; cp-from-store needs chmod u+w before fdtput (store files are r--r--r-- and cp duplicates the mode); pkgs.git rides runtimeInputs so the KERNDATE derivation works inside the app
- [Phase 05]: [Phase 05]: 05-11: boot-r9 app gated by (builtins.hasAttr system r9.packages) — r9 ships no x86_64-darwin package (out of project scope) and an ungated reference broke whole-flake evaluation; x86_64-linux full program eval deferred to 05-13's native CI because r9's kernel-virt embeds genuine IFD (importCargoLock reads a Cargo.lock inside the built toolchain — foreign-system eval builds a foreign-system toolchain)
- [Phase 05]: 05-12: the smoke spawns qemu directly from expect over -nographic stdio (the A6 pick) — the build.bash/drive-r9-proven shape; expect's spawn makes qemu a session/group leader on both hosts so one group-kill teardown works everywhere, the shell-side bracket-fixed pkill a pure fallback
- [Phase 05]: 05-12: the retained smoke evidence is run TWO's capture — the hygiene-proving second pass (run 2 green after run 1's rm -f proves no stale-log/orphan assist); the two gate logs were byte-shaped-identical but genuinely independent (distinct mktemp DTB dirs in the diff)
- [Phase 05-shell-boot-one-command-integration]: 05-13: GH-run leg substituted per the orchestrator's explicit no-push rule: the workflow was authored + locally validated, and the exact pipeline it encodes ran green natively on aarch64-linux from a pristine clone at dc8299575 — 05-EVIDENCE.md records the hosted run as PENDING FIRST PUSH (nothing fabricated)
- [Phase 05-shell-boot-one-command-integration]: 05-13: DeterminateSystems nix-installer-action pinned to commit 3138316df39ed29be04236d7ffc686fa525866aa (v23 resolved via the GitHub API; T-05-24 supply-chain rule)
- [Phase 05-shell-boot-one-command-integration]: 05-13: the flake.lock r9 pin stays at 9549cee (NOT re-pinned to cbbc8e4): the docs commit is docs-only (same kernel image), and re-pinning to an unpushed local commit would break the clean-checkout leg the pin exists to serve
- [Phase 07]: [Phase 07]: 07-01: netdev stanza emission lives in r9 config.rs::apply_virt_netdev (the shared qemu apply-path module), called from both aarch64-virt spawn sites with a per-step pcap path (target/qemu-<config>.pcap / target/boot-test-<config>.pcap); riscv64 MMIO leg + raspi/x86_64 argv byte-untouched, unit-test-pinned
- [Phase 07]: [Phase 07]: 07-01: pcap parser accepts BOTH classic-pcap byte orders — qemu 11.1.2 filter-dump writes the header host-endian (measured: bytes d4c3b2a1 on the LE gate hosts; magic VALUE 0xa1b2c3d4 either way); the plan text's literal a1b2c3d4 od expectation is the big-endian order — corrected substance check run, parser pins both shapes
- [Phase 07]: [Phase 07]: 07-01: plan verify commands ran with --arch aarch64 added (xtask Arch::from defaults to x86_64; every historical boot-test invocation carries the flag)
- [Phase 07]: 07-03: RingMem::fence(order) trait method with a core-fence default (dmb ish/ishld per RESEARCH codegen) — the mock overrides to record op ORDER, so the virtio barrier sandwich is test-proven as a sequence; zero new unsafe/asm in port::virtio (#[forbid(unsafe_code)])
- [Phase 07]: 07-03: avail pre-linking is literal (Ring::new writes each avail entry to its slot's chain head once; post re-writes the fixed value inside the §2.7.13 sequence); a fresh ascending DescPool reproduces ethervirtio.c's 2i chain-head layout organically; MAX_QSIZE=256 loud ceiling implements the accept-256-never-downsize EDGE-PROBE assumption
- [Phase 07]: 07-03: used-ring validation beyond the plan's named checks (Rule 2): odd ids rejected as device faults (chain heads are even — aliasing guard), direction guards on tx_post/rx_replenish — the T-07-05 device-untrusted boundary's completed shape
- [Phase 07]: 07-04: sweep dd syntax is the dash-pair form (dd -if fixture -of datafile) — the baked sys/src/cmd/dd.c parses dash-prefixed key/value pairs (iskey requires the dash), so the classic if=/of= form fails on the guest with dd: bad arg
- [Phase 07]: 07-04: insertion-only edits to the shared build scripts (SUBSET append, separate mk dd.install and manifest assert lines) — the acceptance zero-deletion constraint and Phase-6 collision avoidance govern over the prose alphabetical-in-list placement
- [Phase 07]: 07-04: net-sweep.rc connect step pre-checks test -e on the ctl file — a redirect-open failure is an uncatchable rc Xerror (aborts without the named FAIL line); the || on the echo covers the write-failure (Ebadctl) class
- [Phase 07]: 07-04: mkimage.sh trailer magic re-extracted with od -j — the Harvey host dd shadows POSIX dd on the devshell PATH (D-02 hostbin-shadowing class), leaving the classic-syntax extraction empty and the bake red; od is never shadowed (no Plan 9 od exists)
- [Phase 06]: 06-02: Task-2 checkpoint resolved planned-layout (user 2026-11-04) — tier data files, entry forms, filter hooks, COVERAGE_SWEEP disengagement, and the D-14 ledger grammar committed exactly as presented; ledgers committed header-only to pin the grammar before 06-03's first append
- [Phase 06]: 06-02: uniform keep-rule = first-path-component awk extraction (colon-stripped); dir:target keeps its dir in the mk sweep (mkpaqfs compiles green under 7c) while host-only semantics live at the driver/staging layer; leaf target filtering only where equipped (auth/factotum drops fgui)
- [Phase 06]: 06-02: plan9port mk backquote lexer constraints spiked and encoded (no literal newlines; first unquoted close-brace terminates; $1/$$ are lex errors) — single-line brace-free rc filters with single-quoted awk extractions; mkmany + cmd/mkfile carry empty-TARG phantom guards (Rule-1 deviation, parity re-proven)
- [Phase 06]: 06-02: Task-3 verify gate 2 is defective as written (mk -n never recurses; ip/ipconfig|auth/factotum can never appear in cmd's own output) — intent proven by per-level chain probes; gate-text repair queued for 06-03 planning
- [Phase 07]: 07-06: the device-VA arena now reserves a map's WHOLE span (vm::next_free_device_va_span; deviceutil uses it) — the one-page bump aliased every multi-page map's tail (the 64 KiB GICD map clobbered the ECAM window's dev-1 page; the bind was the first ECAM consumer after gic::init, latent since 07-02)
- [Phase 07]: 07-06: the pci node's ranges 64-bit MMIO window is parsed pci.rs-local (stride from declared cell counts; the 0b11 space-bits tuple) — fdt::property_range_iter caps child addresses at 2 cells and PCI declares 3; the BAR base comes from the DTB either way
- [Phase 07]: 07-06: rx_replenish learns the slot being posted (per-slot buffer-page binding) and returns Replenish { offered, notified } (exact nnote under suppression) — the 07-03 seam's sanctioned evolution; 22 port tests green
- [Phase 07]: 07-06: ring bring-up order = Ring::new chain assembly → queue_enable LAST → DRIVER_OK → rx_replenish pre-posts with ONE notify — the 07-03 boot-order contract (never notify before DRIVER_OK) governs the truth bullet's looser phrasing
- [Phase 06]: 06-03: the staged termrc override swaps the SERVED rootfs's rc/bin/termrc (guest scratch, trap-restored, self-healing) — the donor init's pass structure runs the sweep once at boot and gives drive9 its shell proof on the pass-2 manual rc; no /lib/namespace edit, no typed console interaction during the sweep
- [Phase 06]: 06-03: boot-chain ledger honesty (USPACE-04 transparency outranks plan text): stage/stacksmoke BOOT:donor with the 06-03 gate log; 9k/boot, stage/init, cmd/paqfs:paqfs BOOT:donor with the 05-03 real-chain trace (the subset-exec venue boots the DONOR's own chain); PENDING-CHAIN:06-07 added as the transient Task-1 exec vocabulary
- [Phase 06]: 06-03: the tracer caught 7l's LP64 double-constant pool emission bug (struct Ieee 16 bytes on LP64 hosts; only l's bytes emitted — double constants landed with hi=0; awk float prints aborted). Fixed 2bbca81ed, proven by donor execution (0.333). 6l's embedded-Ieee variant is the same latent class — deferred-items, amd64 untouched
- [Phase 06]: 06-04: the sweep gained a second-chance visitation pass — plan9port mk recipes abort at the first failing command (measured), so container loops stop at the first failing sibling; the plan's adjacency truth (ipconfig + 6 siblings visited) is otherwise unreachable with tier-0 libs outstanding
- [Phase 06]: 06-04: jpg Wave-0 re-verification is forced + state-independent (rm committed headers+generators in the scratch guest, rebuild via the mkfile's own rules, od-assert 7f454c46) — the committed headers satisfy mk without firing the chain; concurrent-session guest churn proved real mid-run-1
- [Phase 06]: 06-04: generator-audit re-confirmation corrected plan cells against live mkfiles (per the plan's mandate): G5 artifact=o.pcode (cpuobjtype=o via /unix/mkfile); G6 genarch=pcc-native-only (build guard gs/mkfile:164, run guard :149)
- [Phase 06]: 06-04: namespace/devshell dialect safety (D-02 shadowing class): Plan 9 sed garbles on pipe-inside-pattern and silently fails capture-group extractions, Plan 9 date prints the epoch for -u +fmt — awk index/substr, plain-caret seds, probe-verified ISO date; ssh probes carry </dev/null under rows-loops (stdin drain measured)
- [Phase 07]: 07-08: push-before-pin executed — r9 e72abfe..2afa3d6 (19 commits) pushed to requaos/r9 BEFORE the flake.lock advance; the pin commit 06380f2bc names flake.lock ALONE; locked rev == live HEAD == origin/main, owner=requaos (the 05-11 gate shape, T-07-17)
- [Phase 07]: 07-08: D-10 end state landed — the identical netdev stanza (-netdev user,id=n0 + -device virtio-net-pci-non-transitional,netdev=n0) on all three compose paths + the smoke's nic-bind whole-capture post-pass; the composed smoke green on the default darwin leg (gicv3+hvf) = the first live NIC-on-GICv3 composed boot; R9_GICV2=1 remains the bisection hatch, never the gate default
- [Phase 07]: 07-08: hosted CI satisfied for real — r9-shell run 41955568449 SUCCESS at headSha 15739d108 (the pushed pin+compose HEAD); the 05-13 PENDING FIRST PUSH substitution NOT needed; legacy harvey.yml's red streak recorded as pre-existing/unrelated (red on every master push since 2026-11-04T12:01Z)
- [Phase 06]: 06-05: libdynld dynld-aarch64 rename KEPT (D-08 rec (i)) — probe-built green before the wave; zero dynld.h consumers → EXCLUDED:no-consumer with the artifact recorded
- [Phase 06]: 06-05: liblex archives as libl.a (historical lex-runtime name) — the tier-0 driver maps per-lib archive names explicitly; the first sweep abort at liblex was machinery, not compilation
- [Phase 06]: 06-05: subset-exec.sh CONF bootdir patch now unconditional drop+insert — the tier1-sweep.rc-keyed skip-guard treated stale blocks as current and silently never landed new members
- [Phase 06]: 06-05: rc ~ dialect measured — quoting DISABLES wildcarding in ~ patterns; multi-star spans over literal text unreliable; sweep assertions use proven edge-glob shapes / split conditions only
- [Phase 06]: 06-05: libmemdraw drawtest/arctest fault on aarch64 (Pitfall-3 class) — filed as Phase-10 per-dir checklist per the plan's no-drive-by prohibition; standing sweep carries green libtest members only (drive9 fast-fail interaction); exec=TEST-FAIL:donor
- [Phase 06]: 06-06: A3 verified on the FULL path — the guest-compiled binary executed from the srv9 writable prefix and printed 'hello aarch64 harvey' (no COMPILE-ONLY fallback needed); A7 settled: this bc prints 0.333 WITH the leading zero (T1-BCOBS)
- [Phase 06]: 06-06: venue findings encoded in the gate — donor devroot Nbootfiles raised 32->128 in the donor-COPY tree (disclosed harness-side accommodation); the served rootfs has no /sys so the gate stages yaccpar/lex ncform/sys-include into it; 9front rc terminates words at bare '=' and plan9port rc rejects separated subshells in backquotes (the sweep is subshell-free, fn producers); bc's hardcoded execl(/bin/dc) gets a union-mount shim over /bin
- [Phase 06]: 06-08: phase6.yml is a NEW sibling workflow (r9-shell.yml + harvey.yml byte-untouched, explicit-range-diff proven) carrying the full phase-6 pipeline on linux legs (D-16) — wave0-host/tier-donor/tier-r9/x86_64-poolpanic; EVERY action 40-char-SHA pinned (checkout 11d5960a… + upload-artifact ea165f8d…, both API-resolved 2026-11-05; nix-installer 3138316d…, the 05-13 pin); concurrency group cancels superseded runs; hosted run PENDING FIRST PUSH per the 05-13 precedent
- [Phase 06]: 06-08: USPACE-10 verdict recorded — PASS no-panic-signature boot-continues (local TCG): the pswt-fixed 6c boots 9k10cpu PAST the 01-04 bad-magic pool-panic point (banner 5s, boot.c's root-is-from prompt reached, zero signature lines) — the Phase-2 pswt hypothesis CONFIRMED; the v1.0 carry-over (deferred 02-8) is closed WITH INFORMATION per D-04's recorded-either-way letter
- [Phase 06]: 06-08: the USPACE-10 verdict harness asserts verdict PRODUCTION (banner + classification file), never the outcome — a FAIL verdict greens the job (information delivered), an empty capture records FAIL no-banner and reds; healthy continuation markers key on the production boot binary's reachable prints ('root is from', boot.c:342) — the plan-named argc=/version... are DEBUG-gated/post-connection (Rule-1 correction)
- [Phase 07]: 07-09: the fix is exactly the diagnosis — `let v = val as u32 as u64;` reproduces the C conversion int→ulong (32-bit truncation, never sign extension; Plan 9 long/ulong is 32-bit even on amd64, vlong/uvlong are the 64-bit types hence VLNUMSIZE=22); NO saturating clamp and NO underflow guard — the u32 ceiling makes the underflow unreachable and a guard would mask a future width regression
- [Phase 07]: 07-09: conv_close's last-close reset (typ=0, owner cleared, queue drain, EOF wake — donor 9k netif.c:446) is pinned as INTENTIONAL by a host test rather than repaired — G-07-1 was a test-PROCEDURE defect (connect before holding the conversation open); the corrected read-first-then-connect protocol lives in 07-UAT.md for the verify-work re-run
- [Phase 07]: 07-09: push-before-pin executed at the fix HEAD — r9 46a2ed2..1c16193 pushed to requaos/r9 BEFORE the flake.lock advance; the pin commit d5df2df38 names flake.lock ALONE; locked rev == live HEAD == origin/main, owner requaos; hosted r9-shell run 42043430592 SUCCESS at headSha eef588612 (and 42043437746 SUCCESS at the subsequent tip carrying these commits)

### Pending Todos

None yet.

### Blockers/Concerns

- ~~Phase 5: note-delivery timing race~~ RESOLVED by 05-01 — trap_return x9 clobber root-caused + buried (20/20 ×2; DEL gate re-exercises every smoke)
- ~~Phase 5: stack-growth never exercised~~ RESOLVED by 05-01/05-04 — stacksmoke forces 3 demand-paged stack page-ins per run through the real EL0 path, in every exec-profile boot
- ~~Phase 5: harness qemu cleanup (phase-04 deferred #2)~~ RESOLVED — D-16 fresh-log + process-group teardown; WR-07 keyed survivor sweeps
- ~~Phase 5: cold-pointer syscall aborts (phase-04 deferred #3)~~ RESOLVED — eager data+bss at exec (05-04) + usermem fused validate+reside + CR-02 stat/fstat
- Phase 5 residue: 13 open Info findings (05-REVIEW-DISPOSITION.md) + the input-wedge note (never reproduced under the cons watchdog; tick-FIFO-drain fix d8496d3 likely closed the class) + hosted CI has exactly one green run — none goal-blocking
- Pin advisory: harvey flake.lock r9 pin (9549cee) is behind r9 main (review fixes + unsafe elimination) — bump at milestone completion with a fresh hosted run (verifier advisory, 2026-11-04)
- 9k-amd64 post-banner `bad magic` pool panic — same signature as the pswt.c LP64 bug fixed in Phase 2; re-test with the fixed 6c (deferred-items.md #8) before relying on the harness for deeper smoke signals
- Hygiene debt: Phase 1 review items (01-REVIEW-DISPOSITION.md) + Phase 2's 13 open Info findings (02-REVIEW-DISPOSITION.md) + Phase 3's 5 open warnings / 10 open Info (03-REVIEW-DISPOSITION.md) + upstream raspi3b-on-qemu-11.1.2 defect (phase-03 deferred-items.md #1, human-accepted A/B evidence); none goal-blocking

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261104-cms | Comment hygiene sweep: planning-artifact citations removed from source comments + narrative headers compressed across r9 (56 files) and harvey (47 files); why preserved sans citations; comment-only proven by diff-invariant + full gates (port 80/80, 5 profiles, toolchain+namespace builds) | 2026-11-04 | ac6f0dbf8 | [261104-cms-comment-hygiene-sweep-across-harvey-r9-r](./quick/261104-cms-comment-hygiene-sweep-across-harvey-r9-r/) |

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| deferred_items | 02-1: bare `sh BUILDTOOLCHAIN` link fails on darwin (9l shim only via nix driver) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-2: 9cc libmach LP64 hswal stride beyond commonllp64 (adotout/crackhdr paths) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-4: guest toolchain ensure re-runs full setup despite sentinels (benign, minutes) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-6: gethunk reset-not-accumulate in 6l/obj.c + cc/macbody (7l fixed; untriggered) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-8: re-test 9k-amd64 bad-magic pool panic with pswt.c-fixed 6c | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-9: libc mkfile `everything` hardcoded object glob lacks `.7` | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-10: ar member staleness — no pruning of removed sources | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-11: ape reduce bind fails in linux namespace (port-cull silently off; harmless today) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 02-12: `nix run .#build` exit status always 0 (break-glass bash tail swallows failures) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 03-1: upstream raspi3b-on-qemu-11.1.2 boot defect (A/B-proven pre-existing; accepted) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 04-4: miniz-inflate heisenbug exposure-eliminated by construction, root cause unisolated | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 05: input-wedge watch item (~1/6 early sweep runs; never reproduced under the cons watchdog; tick-FIFO-drain fix d8496d3 likely closed the class) | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 01-1: dormant-arch toolchain siblings share the LP64 wide-constant bug class | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 05 review Info tier: 13 open Info findings (05-REVIEW-DISPOSITION.md) — doc/comment/hardening nits | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 05: hosted CI has exactly one green run (r9-shell.yml) — history accumulates on master pushes | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 05: flake.lock r9 pin behind r9 main — bump with a fresh hosted run at next milestone open | acknowledged | 2026-11-04 | v1.0 |
| deferred_items | 05: exit-time fd-group sweep landed (261104-b4p) but server-lifecycle consumers remain future work | acknowledged | 2026-11-04 | v1.0 |

## Session Continuity

Last session: 2026-11-05T14:29:55.515Z
Stopped at: Completed 07-09-PLAN.md
Resume file: None

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
