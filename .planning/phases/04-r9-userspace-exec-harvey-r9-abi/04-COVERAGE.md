---
phase: 04-r9-userspace-exec-harvey-r9-abi
status: complete
updated: 2026-11-02
---

# Phase 04 — External API Coverage Matrix

**Verdict: NO external-API integration in this phase.** The verify-pre detector's
match is prose — the phase's subject is the Harvey↔r9 syscall ABI ("API surface"
language), not a network/SaaS API integration.

| Capability | Decision | Reason |
|------------|----------|--------|
| External network/SaaS APIs | OPT-OUT | Kernel + userspace ABI work; no network calls, no accounts, no tokens, no external services. |
| crates.io dependencies | INTEGRATE (audited) | `miniz_oxide` + `adler2` added to r9 in 04-02 — both passed the RESEARCH.md Package Legitimacy Audit (OK-seam approved) before use; no other package installs in the phase. |
| 9front donor ISO (pinned `350266104f`) | OPT-OUT (not an integration) | Build/test evidence only — the donor kernel is booted in a VM to *measure* syscall behavior (D-14 trace); nothing from it is linked, loaded, or called at runtime by the shipped system. |
| qemu / plan9port / nix (host tooling) | OPT-OUT (not an integration) | Host-side build and emulation tooling pinned by the nix devshell; no runtime surface. |

Coverage: full (there is no API surface to cover — all capabilities accounted for above).
