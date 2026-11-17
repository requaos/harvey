# Phase 20: arm64 catch-up to v2.1 parity — Context

**Gathered:** 2026-11-17
**Source:** owner answers during /gsd-plan-phase 20 (no discuss-phase was run; these two decisions were put to the owner after research and are locked)

<domain>
Bring the r9 aarch64 kernel (sibling repo `../r9`, crate dir `aarch64/`, Rust name stays aarch64) and Harvey arm64 userspace (objtype `arm64`) to parity with the v2.1 x86_64 work. See 20-RESEARCH.md for the measured start state and drift inventory.
</domain>

<decisions>

### Pass bar

- **D-01: The phase gates on HVF, not TCG.** The arm64 gates (boot-r9-smoke, boot-r9-net-smoke, boot-r9-tier1) must be reliably green under HVF on the darwin-arm64 host. The intermittent `rc: pushword but no argv!` failure measured in research (4 of 13 HVF boots, 0 of 4 TCG boots; fires in a freshly forked child) must be root-caused and fixed in this phase — it is not deferrable and not time-boxed. TCG results are still recorded as a control leg.
- **D-02: "Reliably green" needs a stated repeat count.** Because the defect fired in roughly 30% of HVF boots, a single green run proves nothing. Each HVF gate's acceptance must name an N of consecutive green runs large enough to distinguish a fix from luck, and the plan must justify the N it picks.

### Scope

- **D-03: Full kernel parity now.** In addition to the must tier (the complete note fix including the `push_note` ready-a-Blocked-target half, the per-proc user hook registration, the rename test fix in `port/tests/devenv_test.rs`, donor-venue re-provision, CI coverage that compiles the aarch64 `dev_exec` code), this phase includes the aarch64 halves of rfork, mount-write, exit and exec, AND the cpu-port items research recommended deferring: the `#!` exec pre-pass, WSTAT/FWSTAT/REMOVE dispatch arms, devcap, devssl, and DTB bootconf.
- **D-04: Research rated the cpu-port items as phase-sized.** The owner chose to include them anyway. If the planner finds the phase exceeds the budget for full-fidelity plans, it must return a phase-split recommendation rather than thin the plans or silently drop items.

### Carried in

- **D-05: The objtype is `arm64`** (quick 261117-bz5). The harness dir keeps the name `build/aarch64/`; r9's crate keeps `aarch64/`. Do not rename either.
- **D-06: The boot-chain trace gate's `measured set lacks fversion` failure** (one run, cause unconfirmed) must be diagnosed in this phase, since the `bind /boot/ourinit /arm64/init` deviation it exercises was introduced by the rename and has no green run yet.

### Claude's Discretion

- Plan count, wave structure and ordering, provided the HVF fork-child defect is investigated early enough that its size is known before the parity work is declared done.
- Requirement IDs: research proposes ARM-01..06; extend as needed for the D-03 scope.
- Whether r9 edits touch `port/src/` (which re-stales the x86_64 boot-iso FOD that cannot be checked on this host) — avoid where an aarch64-side change suffices, and flag every case where it cannot be avoided.

</decisions>

<deferred>
None recorded.
</deferred>
