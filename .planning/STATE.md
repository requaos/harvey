---
gsd_state_version: "1.0"
milestone: v2.1
milestone_name: x86_64 Pivot + r9 Kernel Flush-Out
current_phase: 13
current_phase_name: Harvey amd64 Userspace on r9
status: executing
stopped_at: "14-06 INCOMPLETE after cycle 3 (H1/H3 eliminated; the paqfs torn-tail/dead-server thread is the new primary; dump fixed) — next: pid-keyed pipe probes, then q35shell green twice"
last_updated: "2026-11-09T04:14:02.948Z"
last_activity: 2026-11-09
last_activity_desc: Phase 14 execution started
state_head: a91137fcdfdeb8c603de10a2800438f038b81d13
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 15
  completed_plans: 12
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-07)

**Core value:** Harvey userspace + r9 kernel boot to a shell on x86_64 under qemu/KVM — reproducible from clean checkouts on Linux (primary host since 2026-11-06; darwin stays a documented-manual venue).
**Current focus:** Phase 14 — Harvey amd64 Userspace on r9

## Current Position

Phase: 14 (Harvey amd64 Userspace on r9) — EXECUTING
Plan: 6 of 9
Status: 14-06 INCOMPLETE (blocked on the two-proc scheduler corruption — see Blockers); re-run 14-06 after the fix before 14-07
Last activity: 2026-11-09 — 14-06 executed to the blocker

Progress: [█░░░░░░░░░] 14% (v2.1: 1/7 phases)

## Performance Metrics

**Velocity:**
- Historical: v1.0 — 38 plans / 5 phases (shipped 2026-11-04); v2.0 — 29 plans across Phases 6-8 (subsumed 2026-11-06)
- v2.1: 0 plans (plan counts set at plan-phase)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 13 | 6 | - | - |

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

### Pending Todos

None yet.

### Blockers/Concerns

- aarch64 is FROZEN at the v2.0 pin — all v2.1 work keys to x86_64; do not "fix" aarch64 paths in passing
- raspi3b-on-qemu-11.1.2 boot defect — accepted (pre-existing, A/B-proven not-a-regression); tracked in PROJECT.md Active
- 14-06 STILL INCOMPLETE after the authorized fix cycle: the chain reached init's rc handoff with SIX total kernel/userland fixes landed (conforming-ktext delivery, AX/Tos seed, eager stack+Tos placement, eager brk, embed.c waitpid, preempt-park; + the device-MMIO alias window r9@c166164) — but one deterministic corruption remains: CURRENT_PROC reads as &SCHED_CONTEXT in init's fork window, with hard evidence pointing at a per-proc CR3 mapping divergence (divergent back-to-back loads; no store path, no swtch site, no watchpoint hit) — three ranked hypotheses + working instrumentation recorded in 14-06-SUMMARY Known Issues; full regression battery green at r9@c166164
- 14-06 INCOMPLETE after authorized cycle 3 (stop rule): H1 (PML4 walk/kernel-half copy) ELIMINATED by audit + a never-firing memory-side probe in Deref; H3 (window-VA TLB) ELIMINATED architecturally (no PCID/PTE_G — CR3 write flushes); H2 (trap frame via garbage RSP) UNPROVEN — the panic location/format machinery provably prints stale registers (cold-block merging), blocking per-site confirmation; NEW probe-evidenced primary thread: the userland paqfs 9P server dies mid-chain on a TORN MESSAGE TAIL (read9pmsg short-body; a 3-byte orphan in its stdin queue with no misframed writer — suspect queue-lifetime/qreopen dropping in-flight bytes), rc's exec then parks on the dead mount (idle wedge) and the wedge dump crashed on a garbage parent (FIXED r9@a82d5a0); next probe: pid-keyed memory-side records in devpipe write/drain; regression battery green at r9@a82d5a0

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| CI | harvey.yml nix rewrite — hosted green run pending first push (backlog 999.1) | Open | 2026-11-05 | v2.0 → v2.1 carry |
| aarch64 | Re-activation of the aarch64 target | Frozen at v2.0 pin; re-derivable | 2026-11-06 | v2.1 |

## Session Continuity

Last session: 2026-11-09T04:14:02.874Z
Stopped at: 14-06 INCOMPLETE after cycle 3 (H1/H3 eliminated; the paqfs torn-tail/dead-server thread is the new primary; dump fixed) — next: pid-keyed pipe probes, then q35shell green twice
Resume file: None
