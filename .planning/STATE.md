---
gsd_state_version: "1.0"
milestone: v2.1
milestone_name: x86_64 Pivot + r9 Kernel Flush-Out
current_phase: 13
current_phase_name: r9 x86_64 Platform Bring-Up
status: executing
stopped_at: Completed 13-04-PLAN.md (ACPI/ECAM discovery + moved-window gate green; X64-03 closed)
last_updated: "2026-11-07T15:21:15.370Z"
last_activity: 2026-11-06
last_activity_desc: Phase 13 execution started
state_head: f1c56cc0bf05fa32e12f24475badd482cb2b6405
progress:
  total_phases: 1
  completed_phases: 0
  total_plans: 6
  completed_plans: 4
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-06)

**Core value:** Harvey userspace + r9 kernel boot to a shell on x86_64 under qemu/KVM — reproducible from clean checkouts on Linux (primary host since 2026-11-06; darwin stays a documented-manual venue).
**Current focus:** Phase 13 — r9 x86_64 Platform Bring-Up

## Current Position

Phase: 13 (r9 x86_64 Platform Bring-Up) — EXECUTING
Plan: 5 of 6
Status: Ready to execute
Last activity: 2026-11-06 — Phase 13 execution started

Progress: [░░░░░░░░░░] 0% (v2.1: 0/7 phases)

## Performance Metrics

**Velocity:**
- Historical: v1.0 — 38 plans / 5 phases (shipped 2026-11-04); v2.0 — 29 plans across Phases 6-8 (subsumed 2026-11-06)
- v2.1: 0 plans (plan counts set at plan-phase)

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:** n/a (milestone start)
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 13 P01 | 27 min | 2 tasks | 8 files |
| Phase 13 P02 | 45 min | 2 tasks | 16 files |
| Phase 13 P03 | 12h 41m | 3 tasks | 11 files |
| Phase 13 P04 | 69 min | 3 tasks | 6 files |

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

### Pending Todos

None yet.

### Blockers/Concerns

- aarch64 is FROZEN at the v2.0 pin — all v2.1 work keys to x86_64; do not "fix" aarch64 paths in passing
- raspi3b-on-qemu-11.1.2 boot defect — accepted (pre-existing, A/B-proven not-a-regression); tracked in PROJECT.md Active

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| CI | harvey.yml nix rewrite — hosted green run pending first push (backlog 999.1) | Open | 2026-11-05 | v2.0 → v2.1 carry |
| aarch64 | Re-activation of the aarch64 target | Frozen at v2.0 pin; re-derivable | 2026-11-06 | v2.1 |

## Session Continuity

Last session: 2026-11-07T15:21:15.343Z
Stopped at: Completed 13-04-PLAN.md (ACPI/ECAM discovery + moved-window gate green; X64-03 closed)
Resume file: None
