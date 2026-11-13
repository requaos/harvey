---
gsd_state_version: "1.0"
milestone: v2.1
milestone_name: x86_64 Pivot + r9 Kernel Flush-Out
current_phase: 17
current_phase_name: r9 Kernel Flush-Out
status: verifying
stopped_at: "Completed 17-08-PLAN.md (phase 17 complete: the CR-07/#66 terminus ratified — FLUSH-01/FLUSH-04 closed)"
last_updated: "2026-11-13T15:05:29.802Z"
last_activity: 2026-11-13
last_activity_desc: Phase 17 execution started
state_head: dbd357e3e5e86f0388e803557b85522e797b6bea
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 40
  completed_plans: 40
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-09)

**Core value:** Harvey userspace + r9 kernel boot to a shell on x86_64 under qemu/KVM — reproducible from clean checkouts on Linux (primary host since 2026-11-06; darwin stays a documented-manual venue).
**Current focus:** Phase 17 — r9 Kernel Flush-Out

## Current Position

Phase: 17 (r9 Kernel Flush-Out) — EXECUTING
Plan: 8 of 8
Status: Phase complete — ready for verification
Last activity: 2026-11-13 — Phase 17 execution started

Progress: [█████░░░░░░░░░░░░░░░] 29% (v2.1: 2/7 phases — 13-14 complete, 15-19 next)

## Performance Metrics

**Velocity:**
- Historical: v1.0 — 38 plans / 5 phases (shipped 2026-11-04); v2.0 — 29 plans across Phases 6-8 (subsumed 2026-11-06)
- v2.1: 0 plans (plan counts set at plan-phase)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 13 | 6 | - | - |
| 14 | 9 | - | - |
| 15 | 9 | - | - |
| 16 | 8 | - | - |

**Recent Trend:** n/a (milestone start)
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 13 P01 | 27 min | 2 tasks | 8 files |
| Phase 13 P02 | 45 min | 2 tasks | 16 files |
| Phase 13 P03 | 12h 41m | 3 tasks | 11 files |
| Phase 13 P04 | 69 min | 3 tasks | 6 files |
| Phase 13 P05 | 39 min | 3 tasks | 12 files |
| Phase 13 P06 | 59 min | 3 tasks | 9 files |
| Phase 14 P01 | 21 min | 3 tasks | 5 files |
| Phase 14 P02 | 11 min | 2 tasks | 5 files |
| Phase 14 P03 | 12 min | 2 tasks | 5 files |
| Phase 14 P04 | 48 min | 3 tasks | 12 files |
| Phase 14 P05 | 108 min | 3 tasks | 26 files |
| Phase 14 P06 | 146 min | 2 tasks | 16 files |
| Phase 14 P06 | 146+196 min | 2 tasks | 16 files |
| Phase 14 P06 | 417 min (3 cycles) | 3 tasks | 17 files |
| Phase 14 P07 | 142 min | 3 tasks | 8 files |
| Phase 14 P08 | 70 min active (wall 7h; kill gap) | 3 tasks | 17 files |
| Phase 14 P09 | 14 min | 3 tasks | 17 files |
| Phase 15 P01 | 30 min | 3 tasks | 12 files |
| Phase 15 P02 | 179 min | 3 tasks | 10 files |
| Phase 15 P04 | 26 min | 2 tasks | 9 files |
| Phase 15 P03 | 120 min | 3 tasks | 10 files |
| Phase 15 P05 | 123 min | 3 tasks | 10 files |
| Phase 15 P09 | 11 min | 3 tasks | 5 files |
| Phase 15 P06 | 146 min | 3 tasks | 18 files |
| Phase 15 P07 | ~50 min continuation (wall <=3h44m; interrupted mid-Task-2) | 3 tasks | 17 files |
| Phase 15 P08 | 77 min | 3 tasks | 13 files |
| Phase 16 P01 | 21 min | 3 tasks | 13 files |
| Phase 16 P02 | 8min | 2 tasks | 3 files |
| Phase 16 P03 | 9 min | 2 tasks | 2 files |
| Phase 16 P04 | 14 min | 3 tasks | 4 files |
| Phase 16 P05 | 20 min | 2 tasks | 4 files |
| Phase 16 P06 | 15 min | 2 tasks | 6 files |
| Phase 16 P08 | 274 min (diagnosis-heavy: 3 wedges root-caused, 6 full gate runs) | 2 tasks | 6 files |
| Phase 16 P07 | 19 min | 2 tasks | 2 files |
| Phase 17 P01 | 38 min | 3 tasks | 5 files |
| Phase 17 P02 | 224 min | 3 tasks | 26 files |
| Phase 17 P03 | 18 min | 3 tasks | 15 files |
| Phase 17 P04 | 96 min | 3 tasks | 9 files |
| Phase 17 P05 | 97 min | 3 tasks | 12 files |
| Phase 17 P05 | 97 min | 3 tasks | 12 files |
| Phase 17 P17-06 | 41 min | 3 tasks | 5 files |
| Phase 17 P07 | 3h 44min (halted at the refuted cure; wall ~4h with unattended loops) | 3 tasks | 23 files |
| Phase 17 P08 | 48 min wall across two executor sessions (Task 1 series 14:17-14:35Z; continuation 14:46-15:05Z) | 3 tasks | 19 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v2.1 re-scope 2026-11-06]: Pivot target aarch64 → x86_64; v2.0 subsumed (6-8 delivered, 9-12 inherited re-keyed); aarch64 frozen at the v2.0 pin
- [v2.1 re-scope 2026-11-06]: Three-track end state — Harvey-on-9k standalone ∥ Harvey-on-r9 (v2.1 proving ground) → r9 as complete Rust port of Harvey (future milestone)
- [Phase 13]: GRUB 2.14 mb2 ELF64 loader honors the AT() p_paddr bias for higher-half entries (0xffffffff80200000 boots at phys 0x200000) — no low-entry trampoline needed; kernel.ld unchanged (13-01, RESEARCH A2 confirmed empirically)
- [Phase 13]: grub.cfg puts GRUB console on serial + -no-reboot on the x86_64 boot-test arm: loader errors are visible on the gate wire and a wedged channel exits loudly instead of a SeaBIOS reboot loop (13-01)
- [Phase 13]: [qemu] netdev table (mode/device/pcap) + extra args are xtask config data consumed by the generalized apply_netdev emitter (q35-gated); aarch64 apply_virt_netdev stays frozen-at-pin (13-01, OQ-2 resolved)
- [Phase 13]: GRUB 2.14 lands the mb2 info inside the Mach-zeroing mebibyte (0x16dc08 observed): l.S stashes it to .bss before zeroing and warp64 keeps the boot PML4 — node0s cr3 switch retired with it
- [Phase 13]: mb2 tag sizes are legitimately non-8-multiples (live: 9/18/28) — the parser validates positions/total_size/fixed bodies and walks 8-aligned; strict size%8 would reject GRUBs own output (13-02)
- [Phase 13]: mb2 ACPI tags embed the RSDP structure itself — parser signature-validates and extracts the RSDT/XSDT address (live: rsdt 0x3ffe2345 via tag 14 on BIOS boots); 13-04 consumes it directly
- [Phase 13]: The q35 gate asserts banner then >= 1 q35: memory fact line, order-anchored past the banner byte offset via marker_position (presence, never timings)
- [Phase 13]: 13-03: MSR 0x832 is the x2APIC-mode LVT-timer address (0x800+0x320>>4) and KVM gates MSR range 0x800-0xBFF on x2APIC mode — the KVM #GP was this range gate plus a wrong constant; IA32_TSC_DEADLINE is 0x6E0, valid in either APIC mode (user root cause, dispatch 3)
- [Phase 13]: 13-03: r9 x86_64 LAPIC runs CPUID-gated dual-mode — x2APIC MSR map when leaf-1 ECX bit 21 is present (KVM cpu=host), xAPIC MMIO fallback otherwise (TCG qemu64), same publish-once registry; the platform gate is green twice on KVM (x2apic+TSC-deadline) and once on TCG (xapic+periodic)
- [Phase 13]: 13-04: MADT entries begin at table offset 44 — after lapic_addr (36) comes a flags dword (40) the first synthetic fixtures shared the misreading of; found by dumping SeaBIOS's real MADT through the qemu monitor
- [Phase 13]: 13-04: ECAM is memory-mapped config space — byte-granular, NO 0xFC mask; the CF8 mask cargo-culted into ecam_addr silently redirected every sub-dword read (device ID at 0x02 re-read the vendor) and the NIC was skipped as unidentified
- [Phase 13]: 13-04: -global q35-pcihost.MCFG crashes qemu 11.1.2 at machine init (any value — the property shares PCIExpressHost.base_addr with the mmcfg is-mapped state); the X64-03 perturbation rides -acpitable injection of a committed moved-MCFG binary instead, with the walk taking the last MCFG (override idiom) and the gate asserting exact bases
- [Phase 13]: 13-04: the q35 discovery gate stage anchors POSITIONALLY past the last q35: memory line (last_marker_line_end) — the kernel prints facts+discovery in one serial burst, so a satisfaction-time capture-length anchor deadlocks the stage
- [Phase 13]: 13-04: bridge secondary/subordinate live at config 0x19/0x1A (the plan's 0x18/0x1C named the primary/IO slots); live route: virtio-net 1af4:1041 at 00:02.0 INTA -> GSI 22 (PIRQ G = 16+6), the pciexbar audit line is the window-move evidence
- [Phase 13]: 13-05: The IOAPIC uses the 82093AA/ACPI IOWIN 0x10 layout (verified live: id 0 version 0x11 rtes 23), MADT-driven with the IntSrcOverride fold; BAR assignments are firmware-kept with the [ecam-end, ioapic-base) derived window as fallback
- [Phase 13]: 13-05: Post-sti boot-context code must mask around driver ops AND console prints (the console MCS lock vs the timer tick IRQ print — the wedge found live at the first tx-bulk run); the netgate runs masked posts + enabled waits
- [Phase 13]: 13-05: Pitfall 6 recorded in the metal: 0 mfence across the whole 2M-line kernel disassembly — the trait-default core fences compile away on TSO, correct while EVENT_IDX stays un-negotiated
- [Phase 13]: 13-05: OQ-1 resolved — driver_ops() widened pub(crate)->pub (the one-line port seam) and the kernel-side netgate consumes it after sti; Phase 14 swaps the exec dd path in at the same seam
- [Phase 13]: 13-06: reproducible grub-mkrescue under nix needs a --xorriso wrapper — grub 2.14 has no SOURCE_DATE_EPOCH support and injects a current-time --modification-date into its xorriso argv (xorriso args appended after `--` on the grub-mkrescue line execute after the image write, silently ineffective); the wrapper pins the date and injects --set_all_file_dates + -volid where they actually apply
- [Phase 13]: 13-06: the boot-iso stages a strip-ALL kernel + a length-preserving store-hash zero-zap — rustc emits per-invocation-random .llvm.<u64> anon symbols (symtab identity impossible) and build-std's toolchain panic strings match nix's hash-keyed FOD reference scanner even under a prefix remap; GRUB mb2 loads only PT_LOADs so the symtab is dead weight anyway
- [Phase 13]: 13-06: the flake owns the distributable reproducible boot-iso fixed-output derivation (hash wired only after a two-independent-derivation byte-identity proof — a cache-hit --rebuild proves only the ISO layer); the xtask gate keeps its per-invocation dev copy for evidence freshness (OQ-3)
- [Phase 13]: 13-06: the CI leg selects TCG explicitly (--accel tcg --cpu qemu64 — hosted runners are KVM-less per A7); the no-silent-downgrade rule holds everywhere: accel comes only from the flag > R9_ACCEL/R9_CPU env > TOML kvm default, and a KVM-less venue fails loudly unless TCG was selected
- [Phase 14]: 14-01 D-01 landed: r9 x86_64 Ureg reworked to the 184-byte 9k-verbatim layout — u16 ds/es/fs/gs quartet packed in one qword at 120, type@128, cs@152; UREG_TRAPNO_OFFSET=16*8 / UREG_CS_OFFSET=19*8; always-on const asserts; no compat shim
- [Phase 14]: 14-01 CR-01-class witness re-derivation: intrspecial/intrregular's SWAPPED_CS_OFFSET+24 sites are stub-entry-relative (independent of the carve) and stay correct; intrcommon's btr rides UREG_CS_OFFSET 176->152 (byte 159 = CS qword high byte), re-derivation documented in place
- [Phase 14]: 14-01 D-02 landed: amd64/ABI.md freezes the FULL exec interface — BP number / args at user SP+8 (SP+0 = return-address slot) / SYSCALL / AX result / Sfmask=If; nsec no-spill, _seek, _exits quirks; sys.h 0-54 with the loud-unimplemented rule; USTKTOP 0x00007ffffffff000 + 16 MiB stack policy as the adopted discretion resolution
- [Phase 14]: 14-01 D-02b landed: ureg-check is dual-arch (26-declaration amd64 table, bare-struct + u16int parser, quartet pinned never skipped) with an in-memory negative control mutating the REAL header (cs->cseg; a pass is the loud NEGATIVE CONTROL FAILED), and the x86_64 boot-test precondition is live — Phase-13 deferral retired
- [Phase 14]: 14-02: SYSCALL/SYSRET entry landed donor-verbatim — Star/Lstar/Sfmask armed at init (vsvm.c order, If-only FMASK), syscallentry software-builds the hardware frame on the frozen 184-byte Ureg; the kernel-stack switch is gs-relative TSS rsp0 (one mechanism for both ring-3 entry paths) and the Mach scratch word replaces the donor's RMACH/RUSER register sacrifice, so all 15 GP frame slots hold true user values
- [Phase 14]: 14-02: l.S already set Efer.Sce with Lstar=0 since Phase 13 (SYSCALL enabled-but-unrouted); the arming adds the routing and Lstar now points at the real entry — strictly safer, still unreachable (no ring-3 code exists); Lstar was sequenced never-at-a-hole across the two task commits
- [Phase 14]: 14-03: usermem ported with the UserAddressSpace trait predicate — aarch64's Proc::validate_user_range(va,len,writable) shape compiled ahead of 14-04's proc so the port plugs in with zero interface churn; SAFETY re-keyed to CR3/per-process-PML4-live (the locked no-copy-layer model)
- [Phase 14]: 14-03: the amd64 loader constants are the 6l HEADTYPE-2 set (INITTEXT 0x200028, TEXT_MAP_BASE 0x200000, INITRND 2 MiB data alignment, USTKTOP 0x00007ffffffff000/16 MiB) — synthetic-header host tests pin them; A1's real-binary proof rides 14-05's magic assert
- [Phase 14]: 14-03: USTOP is unreachable by u32 a.out fields on the 128 TiB user map — the donor check carried as factored defense-in-depth (check_data_bss_below_ustop) with its boundary pinned at the function parse_aout calls; Ureg seed = 9k sysexecregs (bp=Tos via RARG, type=64) + touser's If/selector state on dat.rs
- [Phase 14]: 14-04: per-process PML4/CR3 on x86_64 — kernel half shared by copying boot-PML4 entries 510/511 into every proc table; kstacks at a fixed kernel-half window (PML4[400], US-clear) behind TSS rsp0; content writes via the KZERO+PA alias; no dynamic kernel-table aliasing, no PA contiguity
- [Phase 14]: 14-04: exec maps TEXT eagerly on x86_64 (no trap-context pager this era — deeper stack/tos growth and demand text arrive with the pager); NSEC returns the loud no-RTC errstr until an epoch clock exists (the nsec_now seam is ready)
- [Phase 14]: 14-04: usize::next_multiple_of banned in the SSE-free kernel — it lowers to u128/__multi3 soft-float; power-of-two masks everywhere (the link error surfaced the moment the syscall chain made the mapping bodies live)
- [Phase 14]: 14-05 D-03 landed: bootfs rides an mb2 tag-3 module off the same GRUB ISO — the committed grub.cfg is a TEMPLATE SOURCE (@R9-MODULE@ markers; kernel-only emission byte-identical to Phase 13, unit-test-pinned), and the module bytes ride an l.S .bss stash because GRUB placed the first live module INSIDE the Mach mebibyte the early boot zeroes
- [Phase 14]: 14-05: the first ring-3 exec exposed and fixed three latent x86_64 defects — the kernel had been executing in the IDENTITY alias since 13-01 (l.S RIP-relative entry; fatal at the first per-process CR3 load), KSTACK_VA was non-canonical (0xffff_3200... = index 100's offset sign-extended; every window access #GP), and the panic handler was a silent loop (the aarch64 loud shape ported)
- [Phase 14]: 14-06: TWO IMAGES, not one — the chain bakes out/bootfs-chain.paq while q35exec keeps out/bootfs.paq (the marker IS the leg-1 image's /amd64/init); chain binaries harvest to out/ (the boot chain's home), never smoke-out/
- [Phase 14]: 14-06: the amd64 exec-entry contract is AX = Tos (the donor's exec-return: sysexecregs returns the pointer, syscallreturn lands ar0.p in AX, main9.s stores AX into _tos — and 6l fuses that prologue into main9-less mains like boot(8)'s); 14-03's bp planting mis-read RARG; ABI.md corrected
- [Phase 14]: 14-06: ktext must be NON-conforming (0x9A) — a conforming gate target makes ring-3 interrupt delivery stay at CPL 3 (dpl:=cpl), invisible at CPL 0 (every prior gate) and fatal at the first ring-3-origin interrupt
- [Phase 14]: 14-06 cycle 4: the chain panic root-caused and closed (r9@8aa9ba2) — sched_loop's Resume::Return/trap_return arm diverged without re-saving the scheduler context, so the next blocked proc's swtch re-entered a STALE SCHED_CONTEXT save whose stack slot the intervening iterations had reused — wild execution explains the whole 'lying panic' syndrome (merged cold-block entries under garbage registers, truncated prints, the H2-class garbage parent); fix: every resume (fresh forks via a first_entry trampoline, frame ptr in rbx) rides the ONE swtch arm; the devpipe/qreopen suspicion was run live and ELIMINATED (pid-keyed rings: no EOF/err/reopen, paqfs never died — readied and never resumed); q35shell green twice
- [Phase 14-07]: 14-07: OQ-1 resolved both-shapes-from-one-source — r9 exports the argv-driven iso-builder script AND the flake-lib bootIo function, both from one writeShellApplication text (D-05, un-forked); kernel-x64 re-keyed to q35shell (the compose kernel)
- [Phase 14-07]: 14-07: the stale boot-iso FOD hash re-wired per the 13-06 discipline — old body ≡ new builder over four independent kernel builds at both hash layers; FOD mismatch reports name the NAR hash, not the file sha (proofs compare like-for-like)
- [Phase 14-07]: 14-07: two gate-surfaced kernel defects closed — console RX delivery (the 16550 RX ring + ConsHooks, r9@8a338a6) and the SWAPGS witness-bit stale-byte leak (the donor CS-word cmpw on both sides, r9@e5def72; caught by a GS-observation ring — the flip was inside an idle-hlt tick return)
- [Phase 14]: 14-08: the ABI witness is structural — build-9k10t1's r9 leg pins a 38-member sha256 manifest of the exact /amd64/bin set the k10t1 kernel embedded, and mkimage's tier bake digest-verifies it before staging the r9 image; identical 36-marker T1-OK sets proven on both kernels at gate time
- [Phase 14]: 14-08: the tier image runs the sweep from the boot flow (tier-termrc override — the donor's k10t1.rc shape, no typed line); SKIP expectations extracted verbatim from the committed sweep's own lines, OK sets computed from the tier data in all three gate consumers
- [Phase 14]: 14-08: two r9 kernel gaps fixed push-before-pin (r9@e417660, pin 5294f27b8 lock-only) — user SSE armed (CR4.OSFXSR/OSXMMEXCPT + per-exec fninit/ldmxcsr reset; era limit: no per-proc FXSAVE yet) and the eager stack grown 32->64 pages (cmp's 2x64KiB frame); full regression battery green
- [Phase 14]: 14-09: the x64 net gate re-key went GREEN ON THE FIRST BOOT — the port devip stack + virtio-net held under the real userspace drivers; the degenerate-input backstop edges are named stages (netgate: DUPBIND-REJECTED with devip's own 'interface already bound' asserted + netgate: NOADDR-REJECTED), a marker prefix distinct from the fixtures' netip: FAIL fast-fail arm
- [Phase 14]: 14-09: the D-11 single-seam discipline became a BAKE-TIME assert (mkimage's net section greps root-tree/lib for venue literals outside netaddr.rc) — even the fixtures' own comment prose had to be reworded to keep the mechanical check clean; the tier sweep's ipconfig T1-SKIP reason is stale for x64 (the port devcons serves /dev/random there, no-hooks deterministic-seed era) and flips with Phase 15's tier append
- [Phase 15]: The 06-03 anti-staleness decision landed in the tier-2 driver loop: per-entry fresh build (mk <t>.clean / in-tree rm before every build) + run-granularity freshness for shared in-tree archives (auth lib.6.a rm at run end) — stale objects can never earn T2-ART markers
- [Phase 15]: gping re-derived OUT of tier-2 as the GUI class (links libdraw, measured at 6l) — the factotum:fgui precedent; and a filter-emptied $DIRS:V: rule target is a mk parse error (retarget $ALLDIRS) — the aux leaf filter's two new invariants
- [Phase 15]: The in-guest rc dialect is a measurement surface: braced if-not bodies are parse errors that kill a sourced file mid-stream (rc parses blocks whole); bare = in match patterns is a lexer token error; the fd-dup redirect is unreliable in nested sourced blocks — flat status ladders, =-free patterns, the transient 14-09 conv shape and /fd reads are the reliable forms (15-02, measured on the donor across 13 boot cycles)
- [Phase 15]: cs queries ride the !ipinfo route (the dom-attr network translation takes dnsiplookup first whose /srv/dns failure swamps the ndb fallback); libndb drops an unterminated final line whole (generated ndb files carry their newline); myipaddr never falls back to loopback (a loopback-only venue carries a second non-loopback probe address)
- [Phase 15]: The donor venue gained the standard /rc root dir in devroot (srv -e execs rc -c which sources /rc/lib/rcmain unconditionally — no /rc means no srv -e service at all) and the namespace bootstrap for it; keyfs probes isolate getauthkey interactive prompt by binding the read-only sentinel over /dev/cons, and the write-back observable is the through-mount user dir (the server forks RFENVG)
- [Phase 15]: [15-04] The libdraw family landed in tier-0 as DATA closure in k10f's lib order — memlayer/memdraw are the KERNEL-side closure (no userspace GUI source reaches them by autolib, measured), draw/frame/plumb/close are the consumers' link closures; one tier-0 file feeds the LIBS filter and the 15-05 draw-donor kernel
- [Phase 15]: [15-04] gping re-derived IN to tier-3 (15-01's exclusion record named tier 3 as its destination once libdraw closed — the promise kept); fgui stays excluded re-derived (<control.h> -> libcontrol, a closure no plan owns yet — appends when one does, never silently)
- [Phase 15]: [15-04] T3-ART is artifact evidence ONLY (D-07's boundary in the marker vocabulary): compile green is never execution proof for the GUI tier — 15-06's traces are the gate, and 15-09's libmemdraw audit stays sequenced before the trace capture
- [Phase 15]: [15-03] lib9p's postmountsrv needs the kernel's non-RFPROC rfork RFFDG (the in-place fd-group copy, donor sysproc.c:50-57): without it every srv-mounted daemon died mount:bad-fd — fixed at r9 e045dde; devmnt Twrite/Tcreate landed the same plan (the read-only policy is the SERVER's, paqfs still refuses; Tcreate transforms its fid so it rides a clone)
- [Phase 15]: [15-03] The kernel heap is now 32 MiB (measured: the services venue exhausted the 4 MiB arena mid-sweep — exec staging + resident daemons + a ~16 KiB per-exit residue); the residue LEAK audit stays Phase 17's RFMEM-OOM backlog, and the oom handler now prints the failed layout + arena high-water
- [Phase 15]: [15-03] The tier-1 ipconfig/factotum SKIPs are retired (flipped live in one commit with every gate expectation at 7a9ad4b70): the r9 venue now expects ZERO tier-1 skips; the r9 gate's post-pass uses the donor classify semantics for conditional SVC skips (per-subject OK-or-declared + the converse), and expect stage sequences are EMISSION-ordered (expect consumes the buffer to each match — srv-before-exportfs measured)
- [Phase 15]: [15-05] A1+A2 confirmed on the k10draw venue: qemu's VBE DISPI ports (0x1CE/0x1CF) set 1024x768x32 under KVM (route 1 stands, the realmode fallback never needed) and -initrd registers as an mb1 module under -kernel (the -append -v verbose pass prints the mod evidence); A3 measured 20240113 bytes for the 36MB font tree — -m 512 holds
- [Phase 15]: [15-05] k10 meminit fixed for reserved spans above the kernel image: the identity-window extension base is vmunmapped's own KZERO offset (the mmuphysaddr(vmunused) walk lies beyond the early 2MiB pages) and the window maps [vmstart, vmend) whole — load-bearing for every module-bearing k10 boot; the no-initrd path re-proven green
- [Phase 15]: [15-05] This tree's draw wire is LITTLE-endian (draw.h's BG/BP macros flipped vs stock Plan 9) — raw-protocol exercisers use the header macros; the venue's input probes live in the C exerciser (alarm-bounded), never in rc console forms (they wedge the boot); /dev/kbin is eve-gated like mousein and feeds bytes-as-runes through kbdputc
- [Phase 15]: [15-09] drawtest abort = two-sided compositing-arithmetic mismatch: the reference truncated while the byte-path calculators double-rounded (MUL+MUL, ~49% of random pixels off by 1); both sides now round-to-nearest ((s+127)/255 exactly — the MUL2 +128 shape), proven equal on every reachable coefficient pair
- [Phase 15]: probe from the memory side: arctest wild write pinned by the fault address arithmetic (0x1c001374bc = 0x1b001374bc + 4GiB) — an unsigned 32-bit row-offset product zero-extending into 64-bit pointers in byteaddr; row offsets wrap in int now (the plan9port shape); RGB2K /1000 vs >>19 provably identical, untouched
- [Phase 15]: [15-06] mousein writes are RELATIVE (mousetrack deltas, clamped) — replays home-clamp then move known absolute deltas; the trace launch is hang-at-exec (rc sets hang on itself, waitstop blocks until the image stops at its first instruction, nohang clears it for descendants) — the 06-07 spin window lost the race on KVM; and the venue needs /rc/lib/rcmain bound (rc sources one unconditionally — rio/acme/sam command children all died without it)
- [Phase 15]: [15-06] 9k's /proc/N/syscall substrate completed: syscall.c's trace stops now format entry/return fragments (validaddr first, waserror-guarded) and syscallfmt.$O links in every k10 CONF; syscallfmt.c's first 9k compile fixed a one-byte heap overflow (fmtuserstring smalloc(n) then t[n]=0 — the arena-corruption panic) and an unterminated fmtrwdata buffer
- [Phase 15]: [15-06] mntgen measured read-only on this tree (synthetic mount-point generator) — ramfs serves the writable /tmp; sam driven through its command window (the menu-New path and a post-B typed line both measured dead on this venue — samterm which/Hcurrent + the non-empty-dot cut-stall, deferred); arctest falls off main and Harvey's _main epilogue exits("main") so rc conditionals see failure — the rejoin gates on the loop's completion output
- [Phase 15]: [15-07] The amd64 DIRS-coverage proof is green and full-set (702 rows, zero not-ok, 1353 VISIT/EXIT): 7 failures are re-derived upstream-disabled/dead-tool exclusions recorded as named tier4 '# exclude:' comments with measured digests (postscript's '# UNIX remnants' five, tcs/font, games/blabs) — the sweep never visits them and a stale exclusion fails the run; the aarch64 'x86-hardware-only' aux class is re-derived as amd64 MEMBERS; sys/src/cmd/games does not exist in this tree
- [Phase 15]: [15-07] mkpaqfs silently DROPS any file past blocksize^2/4 (4 MiB at the 4096 default — warn, exit 0): the gs bake uses -b 16384 with an arithmetic fit assert and fails on any mkpaqfs diagnostic (every other bake script is unprotected — phase deferred item); Harvey's rc lexer ends a word at every bare '=' (single-quote =-bearing argv in guest scripts — plan9port's rc hides the class); and a second recipe for a target mkone already defines (clean:V:) is mk 'ambiguous recipes' — extend by prerequisite, never by recipe
- [Phase 15]: [15-07] gs renders headless on the donor venue: the FILE device is ppmraw (gdevpbm is in this build's link set, gdevbit is not), its init chain needs the non-.ps config tables xlatmap + FAPIconfig beyond the *.ps library (measured-minimal staging; zero font payloads anywhere), and GS-BITS 43269 is the recorded bitmap size at -m 1024; fossil + venti are compile-gated only — runtime-unverifiable until r9 has a block device (virtio-blk, future milestone)
- [Phase 15]: [15-08] The DESK-03 payload is a DECLARE-by-invocation mkimage section (stage_payload + the committed bootfs-payload.txt manifest: [paths]/[fonts]/[floors] consumed by name) and the SERVICES contract declares it — the whole lib/font/bit tree as a bake-time copy with a staged==source count check, /lib/ndb/local sed-substituted from the token template through the netaddr seam (both-direction asserts), and the D-17 profile shape asserted on the staged file (terminal case rio-free, cpu case intact); every assert class is proven by a doctored-input negative control
- [Phase 15]: [15-08] r9's boot-module stash is now 64 MiB (was 8): the font-carrying services paq is ~26.5MB and the 8 MiB clamp panicked the stash-length reconciliation at the EARLY check's first boot — venue -m was never the limit (a fixed .bss cap); fixed under D-01 at r9 236d5a7 with the FOD re-wired at af52fee (pin eba6b07e2); A3's <=15MB font-deflate guess is falsified (~18.8MB measured); every r9 gate re-greened at the new pin (services/tier-1/net-smoke/smoke)
- [Phase 15]: [15-08] The tier witness is tree-history-sensitive for the yacc-grammar directory entries (rc/grep/awk): this plan's first tier build produced different bytes for exactly those three once (the tree had matched the pinned digests before it), then every later build reproduced the pinned digests byte-for-byte — measured, cause undetermined — re-pin order is tier-driver-THEN-build-9k10t1.sh (root cause open, phase deferred item); and the expect gates' panic fast-fail truncates the kernel's panic text mid-line (deferred item)
- [Phase 16]: 16-01: ONE netdev argv builder (config::netdev_args + testable netdev_args_checked core) in a new xtask lib target serves both front-ends — the in-process apply_netdev and the exported r9-netdev-args bin; the Netdev TOML shape is default=slirp + slirp/tap/vmnet sub-tables with the D-04 hostfwd remap (host 5670 -> guest 567, loopback-bound) and the NixOS tap helper path as data; PUSHED at r9 d1c4849dfa1d769240630c29b9b03b88d5819558 (the 16-04 pin target)
- [Phase 16]: 16-01: xtask needs default-run = xtask once a second bin exists — cargo's xtask custom-subcommand protocol (and kernel-x64's flake buildPhase) breaks on bin ambiguity otherwise; and nix flake builds see only git-TRACKED files, so new sources must be staged before nix build verifies them
- [Phase 16]: 16-01: the five committed q35 TOMLs are machine-checked by a lib test (include_str! parse, default=slirp + all three sub-tables each) — the must-haves truth enforced at test time; the parallel-boot constraint lands with the hostfwd data (two simultaneous q35 boots collide on 127.0.0.1:17010/5670)
- [Phase 16]: 16-02: OQ-1 adopted — the host's existing br0 192.168.122.0/24 is the committed tap seam (host .1, guest .15; collision-free with slirp and the LAN); OQ-4 verdict recorded in the seam: v6 is NOT free to verify and stays deferred (no v6 key this phase)
- [Phase 16]: 16-02: the burst leg's marker-COUNT assert belongs to the host-side expect post-pass — rc cannot collect per-child statuses after a bare wait; the fixture prints netsoak: burst wait returned and 16-05 counts tcpblast: done occurrences
- [Phase 16]: 16-02: dc rides the net image (Rule 3 additive extension) — the mandated dc backquote burst counter needs the tier-1-built binary in the guest; the bake's seam assert now covers BOTH venue prefixes, teeth-proven by a doctored-input negative control
- [Phase 16]: 16-03: OQ-3 landed as committed exit semantics — the doctor exits 0 iff zero FAILs; WARN-class findings never gate the exit, and the root-gated masquerade read degrades to a loud WARN carrying the exact sudo commands (iptables-save/nft) with the seam-derived subnet
- [Phase 16]: 16-03: the doctor carries zero address literals — the tap subnet/ports interpolate seam-derived values into remediations (the seam is the single address source host-side too), probe output prints on detail lines only (T-16-05), and the app gate is its OWN linux optionalAttrs with the frozen kernel-x64/iso-builder list untouched (Pitfall 6, diff-asserted)
- [Phase 16]: 16-04: the boot app's net surface landed — --net=<mode> (the = form only) over R9_NET over the slirp default; unknown-mode and cross-venue requests are parse-time usage errors naming the valid set, and the tap leg doctor-gates FIRST (D-03) with remediation blocks inline — never a silent downgrade, never a fall-through to qemu
- [Phase 16]: 16-04: no netdev literal survives in boot-r9-x64.sh — the qemu netdev+device argv is the pinned r9 emitter's output (D-04 hostfwd pair as TOML data through R9_NETDEV_EMITTER), and the x64 apps hasAttr gate carries netdev-args only from the pin-advance commit set onward (Pitfall 6); pin advanced af52fee -> d1c4849 lock-only, hosted-CI observation PENDING FIRST PUSH
- [Phase 16]: [16-05] The soak app's slirp refusal sits at parse time BEFORE the doctor preflight — the doctor aborts wrong-allow hosts (this one today), so a doctor-first order would make the refusal unreachable exactly where it matters; the doctor still gates before any bake/boot/listener
- [Phase 16]: [16-05] Driver self-test pattern: a fake marker-stream qemu proves an expect driver end-to-end without the venue (argv split, stage order, post-passes) — it caught expect's -timeout-before-braced-block silent no-match (fixed by setting the global timeout var, the sibling gates' mechanism); an 8-count negative control proves the tcpblast: done count has teeth
- [Phase 16]: [16-05] Host-tool findings for 16-08's run loop: this host's coreutils head emits NOTHING when timeout-killed mid-count (client harnesses must read exact byte counts), and spawned ptys stay canonical for children that don't set raw mode themselves (real qemu does)
- [Phase 16]: 16-06: the composed net gate's qemu spawn rides the emitter's slirp argv (R9_NETDEV_ARGV split in the driver — zero netdev literals; venue FIXED slirp per D-02, the D-04 hostfwd pair flows from the pinned TOML, D-05) and observes both loopback hostfwd listeners host-side mid-boot (ss -tln stages); iproute2 joined the app's runtimeInputs for the driver's exec ss; net-smoke-x64 joins r9-shell.yml at R9_ACCEL=tcg with pinned actions — hosted observation PENDING FIRST PUSH
- [Phase 16]: 16-08: the soak first-run failures were the GATE's — the carried 600s per-stage budget cannot span the KVM-paced baseline (~810s at 2.5 rounds/s); the driver's own timeout kill masqueraded as a kernel wedge (torn serial, unacked finals, dead timers); fixed with a burst-wait-only soak_stage_timeout 2700 (stage gained an optional per-call override); r9 exonerated by debugcon instrumented autopsy and left byte-identical at d1c4849 (no pin advance, FOD clauses vacuous)
- [Phase 16]: 16-08: the intermittent burst-leg guest triple fault (1 failure in 5 full runs, observer-healed — both debugcon-instrumented runs green) is recorded OPEN (deferred-items + WINDOWS #66) with the stress-loop recommendation (rounds=1/burstn=8, uninstrumented pinned kernel, -d int exception-cascade capture); no blind fix — the fix-everything doctrine's root-cause bar cannot be met without reproduction
- [Phase 16]: 16-07: build/x86_64/README.md EXTENDS the Phase-13 companion in place (the drift-notes home already existed) with the Phase-16 net-modes sections — NixOS TESTED leading with the two live-probed divergences, generic-Linux/darwin/real-LAN each explicitly not-tested
- [Phase 16]: 16-07: the trustedInterfaces firewall opening is documented as mandatory tap-remediation checklist material with the measured 4x-SYN/zero-SYN-ACK evidence — the 16-08 deferred item's ask (the doctor's WARN-class read cannot surface it)
- [Phase 16]: 16-07: 16-EVIDENCE.md separates retained captures (7 on-disk files, existence-checked) from records living in SUMMARYs; every indexed artifact names its r9 SHA (all rode d1c4849); A3 masquerade + A4 vmnet spelling honestly open
- [Phase 17]: [17-01] D-02 audit verdict: x86_64 carries the aarch64 WR-03 family verbatim at the four anchors, but four x86_64-LOCAL OOM paths leaked (pml4_map_user walk intermediates, map_user_page leaf, rfork copy arm, new_user_proc tuple prefix) — ported as one class commit r9 3e8bcec, FOD re-wired 476605d, pin advanced lock-only
- [Phase 17]: [17-01] CR-03's Phase-8 requires-human-verification host half DISCHARGED: four deterministic x86_64 sem pins (r9 f9088d0, sem_ filter 5/5, battery 64/64); the in-kernel contention leg rides 17-02's churn profile; WR-03's half rides 17-02's tiered leak gates (not closed)
- [Phase 17]: [17-01] The closure pipeline is proven on the CR-01 exemplar: port battery -> composed x64 gate -> 08-ledger Source re-cite -> FLUSHOUT row; 13 x86_64-keyed re-cites landed (baseline 0) and 17-FLUSHOUT.md seeded with all 30 rows — the index VERIFICATION walks
- [Phase 17]: [17-02] WINDOWS #44 closed at a MEASURED root cause, not the plan's suspect: exit_tail's diverging tail never dropped its transients (the ~8 KiB fd-group Arc per exit) + the never-reaped husk's retained group handles — 16 KiB/exec drain fixed at r9 c4f2f2c/72edbba (60 bytes/exec post-fix); ByteBacking::Mnt never implicated
- [Phase 17]: [17-02] The composed venue's bounded-memory mechanism: the PREFERRED arm — kernel-x64 re-pointed at a new q35churnshell config (q35shell verbatim + the churn dev key; q35shell.toml byte-stable) carrying the per-exit heap marker; the composed gate bounds its window from the kernel's own emitted numbers
- [Phase 17]: [17-02] The contention leg found its own bug: rfmem_brk_set's lone-member arm (the post-sibling-exit state) mapped nothing — the survivor's first malloc fault-killed it; fixed r9 72edbba. New deferred finding: rc's userland pool corrupts under ~428+ backquote iterations (17-03's rows)
- [Phase 17]: [17-03] WR-05/WR-06 closed push-before-pin: one port-level MAX_WAITERS=512 const (the live table, both arches) resized all three WaitSet copies + twelve take buffers with a count+report full arm; next_used gained the unposted-slot liveness reject — 9 waitset pins + 1 used-drain negative RED-proven, r9 aea604c..658001b, FOD re-wired (NAR sha256-0KGcgz, three-way agreement), pin b02408cad lock-only, smoke+net gates ALL STAGES PASS, 07 ledger at 11 open
- [Phase 17]: 17-04 end-edge re-derivation: qemu 11.1.2's virtio notify cap (length = notify_off_multiplier x VIRTIO_QUEUE_MAX = 4 x 1024 = 0x1000 at offset 0x3000) ends EXACTLY at the 0x4000 BAR boundary (the BAR is sized pow2ceil(notify.offset + notify.size)) — the plan's flagged >=-style edge would reject the real device and redden every net gate; the closed form keeps the > edge and adds the zero-length reject, which alone closes the named offset==bar_size length==0 hole; pinned by the live-shape admit pin (cap_extents_admit_the_live_q35_shape)
- [Phase 17]: 17-04 TDD shape: RED evidence for both fix tasks was captured and classified BEFORE any implementation (17-04-t1/t2 RED_EVIDENCE_OK, libtest JSON preserved), but the pins rode the ONE class commit per the plan's own Pitfall-5 prohibition — no separate test() commit exists for 17-04; documented in the SUMMARY's TDD Gate Compliance section
- [Phase 17]: 17-04 D-13 token mapping executed: WR-07/WR-08 closed as the 07 ledger's native 'deferred' disposition carrying the full D-15 3-part rationale in Source (WHERE/WHY/Reopener:) — same vocabulary-mapping class as 17-02's WINDOWS resolved-vs-fixed call; the ledger ends with exactly the 5 IN rows open
- [Phase 17]: 17-04 services-x64 dns-stage trap (kernel PF at pc=0x0 after a devmnt cs error): PRE-EXISTING, A/B-proven — the identical trap frame fires at pin b02408cad (r9 658001b, pre-17-04); last green services run was the 15-08 era; deferred (17-04-deferred-items.md + WINDOWS), the root-cause belongs to the next plan touching the services venue
- [Phase 17]: [Phase 17]: 17-05: WINDOWS #18 closed verify+pin — the four-site syscall.rs pgrp-lock audit found every site already snapshot-then-drop (the shared namec chain_snapshot carries the contract; sys_bind/unmount/mount lock only the table mutation; sys_create's :1159 block IS the shape verbatim); the 17-02 churn/composed captures are the under-load pin
- [Phase 17]: [Phase 17]: 17-05: WINDOWS #45 closed fix+pin — sys_create's probe and create consult the union chain (walk_one_union/create_chan_union, first-accepting member; refusals propagate per the 15-03 server-owns-policy stance, a deliberate deviation from donor createdir's MCREATE gate); RED-proven 6 host pins at port/src/namec_tests.rs (venue A)
- [Phase 17]: [Phase 17]: 17-05: the empty mount-table key collision — a registry attach chan's empty path keys to the same normalize('/')=='' the boot's bind -a /root / owns, so every union consult needs namec's #-arm nomount bit at the call site; found live by the tier1 gate (init's setenv('#e/timezone') silently failing -> T1-FAIL date), fixed r9 421d5e1 with a counterfactual pin
- [Phase 17]: [Phase 17]: 17-05: the tier1 date check's green is a pre-existing quirk — hdate -n == 0 every kernel this era (r9 devcons has no /dev/bintime; libc nsec() returns 0) and the 20xx expectation is met by ctime(0)+EST displaying 'Feb 7 2006'; identical pre/post 17-05, recorded open in 17-05-deferred-items.md
- [Phase 17]: [17-06] The three rc corners (#46/#49/#65) landed as ONE Harvey class commit 6779df7d7 (D-11) — checked doredir Dup in both arms, Execute first-failure errstr, Xqdol/Xcount argv-stack guards; proof = smoke-x64/tier1-x64 ALL STAGES PASS at the 17-05 pin, no r9 pin mechanics — D-11 executed as locked: rc is the load driver; one class commit, sweep-proven, panic sites untouched
- [Phase 17]: [17-06] #49's fix sites are Xqdol+Xcount — the invariant audit found exactly two remaining pop-then-pushword ops in exec.c (the class reaching the recorded pushword panic); pop-then-deref ops are a different crash surface and stay unguarded — minimal fix exactly matching the recorded crash class; the 06-07 Xbackq guard completes its class
- [Phase 17]: [17-06] No fixture for any rc corner (D-11 escape clause): no sweep fails a dup; absolute-path invocation never exercises the #65 masking path; the #49 class is HVF-timing-only (A6 — unreproducible on this venue, audit-grounded, live-fire reopener) — fixture routes disproportionate or unmeasured; the re-greened sweeps + invariant shapes are the pin
- [Phase 17]: [17-06] A /amd64/bin byte change (the fixed rc) trips mkimage witness-manifest digest — the standing remedy is build/mm/build-9k10t1.sh re-run (donor rebuild + 38-member manifest re-pin, gitignored, no commit, no pin advance); services-x64 stays blocked by the pre-existing #68 dns-stage kernel trap (A/B-identical at this pin, kernel byte-identical — root cause owned by 17-07) — the 14-08 identical-6.outs discipline executing as designed; the services block is out of this plan's authority (no flake.lock)
- [Phase 17]: 17-07: the D-09 fold verdict is a SPLIT — #66 is the CR-07 class (reproduced live 3x, stays OPEN); #47 the wedge form closed-by-discipline; #50 a different class waived frozen (17-CR07-ROOTCAUSE.md is the record)
- [Phase 17]: 17-07: the cure evidence FAILED — the stress series at the fix pin (r9 8f3ff11) refuted the deregister fix as the cure (fired at run 3, 25s, the byte-consistent signature); the fix stands as hardening (4 pins, gates green) but #66/CR-07 stay open with the enriched record and the committed reproduction instrument (fires the class at will in ~25s)
- [Phase 17]: 17-07: the 30/30 narrowing matrix localizes the class to the FULL 8-way concurrent bulk transfer (launch storm alone and <=4-way full-depth never fire); the KVM capture ceiling is an empirical platform fact (-d int blind at death, cpu_reset post-state, userspace-APIC refused, TCG-tap wedges at ping)
- [Phase 17]: [17-08] The CR-07/#66 terminus RATIFIED: ratify-disposition + FLUSH-04 yes (Neil Skinner, 2026-11-13T14:42:08Z) — WINDOWS #66 waived with the 3-part D-15 rationale + resolved_at, the 08-ledger CR-07 row deferred with the same rationale + the ratification cite, FLUSHOUT's cells/verdict/lineage ratified, the VERIFICATION overrides block recorded with the rest of the file hash-intact, REQUIREMENTS FLUSH-01/FLUSH-04 checked + Complete; the waiver is of the CURE this era (class live ~8%/run, reopener + instrument stand); the TCG x slirp avenue completed NO-FIRE-IN-SERIES (N=10 serialized, weak-negative semantics stated in the record itself) — The verifier's single blocking gap (CR-07/#66 neither closed nor explicitly dispositioned) closes via the goal's own disposition arm: the evidence — live reproduction 3x, the refuted strongest-candidate fix, the 30/30 narrowing matrix, the empirically established KVM capture ceiling completed by section 8's TCG x slirp avenue, and the committed reproduction instrument — supports a waiver only a maintainer could grant, and it was granted with who/when recorded verbatim. The class stays live (~8%/run under the full 8-way concurrent bulk transfer) with the venue-conditional reopener intact; records-only, r9 untouched at 8f3ff11 == origin/main.

### Pending Todos

None yet.

### Blockers/Concerns

- aarch64 is FROZEN at the v2.0 pin — all v2.1 work keys to x86_64; do not "fix" aarch64 paths in passing
- raspi3b-on-qemu-11.1.2 boot defect — accepted (pre-existing, A/B-proven not-a-regression); tracked in PROJECT.md Active
- 14-06 RESOLVED (cycle 4, r9@8aa9ba2): the "scheduler corruption" was sched_loop's diverging trap_return resume arm leaving SCHED_CONTEXT stale against a stack slot the intervening scheduler iterations reused — wild execution explains every prior symptom (the "lying panic" with merged cold-block locations, the H2-class garbage parent, the apparent paqfs death: it never died, it was readied and never resumed); the devpipe/qreopen suspicion was run live and ELIMINATED (pid-keyed rings: no EOF/err/reopen in the whole run); q35shell green twice consecutively, full regression battery green at r9@8aa9ba2
- CR-07/WINDOWS #66 OPEN after 17-07: the 8-way-transfer triple fault — reproducible at will (boot-r9-stress-x64, ~25s, ~8%/run); cure unfound (the deregister fix refuted by the series); reopener conditions in 17-CR07-ROOTCAUSE section 7

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| CI | harvey.yml nix rewrite — hosted green run pending first push (backlog 999.1) | Open | 2026-11-05 | v2.0 → v2.1 carry |
| aarch64 | Re-activation of the aarch64 target | Frozen at v2.0 pin; re-derivable | 2026-11-06 | v2.1 |

## Session Continuity

Last session: 2026-11-13T15:05:29.049Z
Stopped at: Completed 17-08-PLAN.md (phase 17 complete: the CR-07/#66 terminus ratified — FLUSH-01/FLUSH-04 closed)
Resume file: None
