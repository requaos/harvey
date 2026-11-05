# API Coverage — Phase 06 (Full-Tree Userspace — Wave 0 + Libraries/Core Tiers)

No external API integration: this phase ports the Harvey/Plan 9 userspace to aarch64 and gates it on the 9front donor kernel and the r9 kernel — all work is OS/toolchain/build-harness engineering. There is no third-party service, SDK, REST/GraphQL surface, or vendor API anywhere in scope. The detector's signal was the bare token `api` in phase prose (e.g. "syscall ABI/dispatch" discussion); qemu (machine emulator), 9P2000 (the OS's own file protocol, kernel-implemented), and GitHub Actions YAML (CI configuration, not an integrated service API) are named here explicitly as the nearest surfaces and are none of them external-API integrations.

| capability | decision | reason |
|---|---|---|
| external service APIs | OPT-OUT | none exist in this phase's scope — OS userspace port |
| third-party SDKs | OPT-OUT | no dependencies of that class introduced (Plan 9 C + shell + nix + GitHub Actions only) |
