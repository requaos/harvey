# Roadmap: Harvey OS — Build Revival + r9 Adoption

## Overview

v2.1 pivots the Harvey+r9 pair from aarch64 (frozen at its green v2.0 pin) to x86_64 under qemu/KVM on the new linux-x86_64 primary host, and turns Harvey's full amd64 userspace loose on the r9 kernel as the flush-out instrument. The port itself is two phases: the r9 x86_64 platform layer (recorded DTB-free boot protocol, APIC/HPET interrupts, data-driven PCI/ECAM, virtio-net over the arch-neutral `port/` stack — Phase 13) and the userspace re-derivation (amd64 ABI contract, exec, boot→init→rc to `% `, tiers + `/net` gates re-keyed to `objtype=amd64` — Phase 14). From there the inherited v2.0 payoff re-lands on the new arch in dependency order — userspace tiers + bootfs payload (15) in parallel with host net modes + the tap-leg exit gate (16) — feeding both the kernel flush-out phase (17: the open Phase-7/8 review backlog closed under real load, every fix pinned) and the in-guest p9sk1 auth domain (18). Phase 19 is the payoff: cpu service + drawterm + rio desktop on x86_64, with `nix run .#boot-r9` still the ONE command and the full chain proven from clean checkouts.

## Milestones

- ✅ **v1.0 Boot Revival** — Phases 1-5 (shipped 2026-11-04)
- ⏸ **v2.0 Full System & Drawterm** — Phases 6-12 (subsumed into v2.1 on 2026-11-06 at the x86_64 pivot: Phases 6-8 delivered complete; 9-12 inherited, re-keyed to x86_64)
- 🚧 **v2.1 x86_64 Pivot + r9 Kernel Flush-Out** — Phases 13-19 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (13, 14, 15…): Planned milestone work — numbering CONTINUES from v2.0 (Phases 6-8 complete; 9-12 subsumed into v2.1's phases, re-keyed); v2.1's first phase is Phase 13
- Decimal phases (14.1, 14.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>✅ v1.0 Boot Revival (Phases 1-5) — SHIPPED 2026-11-04</summary>

- [x] Phase 1: Build Tail Green (9k amd64) (4/4 plans) — completed 2026-10-31
- [x] Phase 2: aarch64 Toolchain + libc + 9front Donor (7/7 plans) — completed 2026-11-01
- [x] Phase 3: r9 qemu-virt Platform Bring-up (6/6 plans) — completed 2026-11-01
- [x] Phase 4: r9 Userspace Exec + Harvey↔r9 ABI (8/8 plans) — completed 2026-11-02
- [x] Phase 5: Shell Boot + One-Command Integration (13/13 plans) — completed 2026-11-04

Full detail: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>⏸ v2.0 Full System & Drawterm (Phases 6-12) — SUBSUMED into v2.1 2026-11-06</summary>

- [x] Phase 6: Full-Tree Userspace — Wave 0 + Libraries/Core Tiers (10/10 plans) — completed 2026-11-05
- [x] Phase 7: r9 PCI/ECAM + virtio-net + devether (10/10 plans) — completed 2026-11-05
- [x] Phase 8: r9 TCP/IP Path — devip-Compatible /net (9/9 plans) — completed 2026-11-06
- Phases 9-12 were never started; their pending requirements are inherited into v2.1 (Phases 15, 16, 18, 19) re-keyed to x86_64

Full detail: `.planning/milestones/v2.0-ROADMAP.md`

</details>

**v2.1 x86_64 Pivot + r9 Kernel Flush-Out (Phases 13-19):**

- [x] **Phase 13: r9 x86_64 Platform Bring-Up** - *(cross-repo: `../r9`)* q35/pc platform layer — DTB-free boot protocol, APIC/HPET interrupts, PCI/ECAM discovery, virtio-net + devether — KVM-native acceptance gates by default (completed 2026-11-07)
- [x] **Phase 14: Harvey amd64 Userspace on r9** - amd64 Ureg/TrapFrame ABI contract, exec through the real syscall path, boot→init→rc to the `% ` prompt, tier machinery + `/net` gates re-keyed to `objtype=amd64` (completed 2026-11-09)
- [x] **Phase 15: Userspace Tiers + Bootfs Payload (amd64)** - services/GUI/long-tail tiers on the k10t1 venue then r9-x86_64; rio/acme/sam donor syscall traces; desktop payload staged in bootfs (completed 2026-11-10)
- [ ] **Phase 16: Host Net Modes + Networking Exit Gate** - hermetic slirp+hostfwd default, explicit `--net=slirp|tap|vmnet`, linux tap/bridge L2-truth leg + doctor checker; the NETIP-08 tap-leg soak gate
- [ ] **Phase 17: r9 Kernel Flush-Out** - *(cross-repo: `../r9`)* the open Phase-7/8 CR/WR backlog + known kernel windows closed under real userspace load, every fix landing with a pin
- [ ] **Phase 18: In-Guest p9sk1 Auth Domain** - hash-paired bake-time domain generator, `/dev/random` from x86_64 entropy + devcap `#¤`, keyfs/authsrv on tcp/567, loopback probe green before any drawterm
- [ ] **Phase 19: CPU Service + Drawterm + rio Desktop** - `cpu -R` end-to-end, flake drawterm, rio in-session only, full-chain smoke + clean-checkout proof on linux-x86_64

## Phase Details

### Phase 13: r9 x86_64 Platform Bring-Up
**Goal**: r9 boots and speaks Ethernet on x86_64 — a q35/pc platform layer with a recorded DTB-free boot protocol, live APIC/HPET interrupts, data-driven PCI/ECAM discovery, and virtio-net bound through the arch-neutral `port/` stack — with KVM-native acceptance gates as the default. **Kernel work in sibling repo `../r9`.**
**Depends on**: Nothing in v2.1 (v2.0 complete — `port/` is arch-neutral and carries whole; the lean `x86_64/` crate — uart16550/pio/trap/vsvm — is the entry point)
**Requirements**: X64-01, X64-02, X64-03, X64-04, X64-05
**Success Criteria** (what must be TRUE):
  1. r9 boots on qemu x86_64 via a recorded DTB-free boot protocol — the q35-vs-pc machine decision recorded with rationale, the protocol decided against (or explicitly reusing) 9k's existing multiboot path — and a committed boot-test gate asserts banner → timer ticks → serial input echo in order, green on repeated runs (X64-01)
  2. APIC interrupt plumbing (LAPIC + IOAPIC) and HPET/PIT timers are proven under load, and INTx level-triggered virtio ISR read-to-ack is re-proven — a sustained IRQ-load run shows no lost or wedged interrupts (X64-02)
  3. PCI/ECAM discovery works without DTB (ACPI MCFG or the fixed q35 window) with zero hardcoded addresses — the moved-window perturbation boot-test still finds and binds the device (X64-03)
  4. virtio-net binds on x86_64 through the arch-neutral `port/` transport and devether presents `/net/ether0` with live RX/TX counters — the guest's ARP request is observable in a host-side capture (X64-04)
  5. r9's flake ships an x86_64 kernel package and the acceptance gates run KVM-native by default, with the TCG fallback documented (X64-05)
**Plans**: 6/6 plans complete
Plans:
**Wave 1**
- [x] 13-01-PLAN.md — q35 boot channel: config_q35.toml, TOML-driven -cdrom xtask arm, grub-mkrescue ISO, mb2 header in l.S — boot-test x86_64 banner gate green twice (X64-01)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 13-02-PLAN.md — main9-x64 rewrite + platform/q35 tree + mb2 parser + old-gen retirement — memory map on serial, gated (X64-01)

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 13-03-PLAN.md — LAPIC + CPUID-gated TSC-deadline/periodic timer + IDT dispatch + serial echo — the Phase-3-style gate green twice, KVM + TCG (X64-01, X64-02)

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 13-04-PLAN.md — ACPI mini-parser (RSDP→XSDT→MCFG/MADT) + PCIEXBAR-programming ECAM discovery + recursive walk — the moved-window perturbation gate (X64-03)

**Wave 5** *(blocked on Wave 4 completion)*
- [x] 13-05-PLAN.md — MADT-driven IOAPIC + four-seam virtio-net bind + devether /net/ether0 + kernel-side ARP netgate — ping-pong/TX-bulk reconcile + pcap gate (X64-04, X64-02)

**Wave 6** *(blocked on Wave 5 completion)*
- [x] 13-06-PLAN.md — flake kernel-x64 package + reproducible boot-iso + KVM-native gate loop + TCG fallback docs + CI leg + 13-EVIDENCE.md consolidation (X64-05)

### Phase 14: Harvey amd64 Userspace on r9
**Goal**: The core value lands on x86_64 — Harvey amd64 binaries exec on r9 through the re-derived ABI contract, the boot chain reaches the interactive `% ` prompt via one command, and the tier + `/net` gate machinery runs keyed to `objtype=amd64` (no new toolchain work — 6c/6a/6l already green). **Work spans both repos plus the flake glue.**
**Depends on**: Phase 13
**Requirements**: XEXEC-01, XEXEC-02, XEXEC-03, XEXEC-04, XEXEC-05
**Success Criteria** (what must be TRUE):
  1. The amd64 Ureg/TrapFrame ABI contract is published and build-enforced — the `aarch64/ABI.md` equivalent with offsets frozen, const asserts + xtask ureg-check live on every gate, and a negative control firing on drift (XEXEC-01)
  2. Harvey amd64 binaries exec on r9 x86_64 through the real EL/syscall path — the aarch64 measured-set dispatch carries over, proven by staged-init + hello-equivalent execution evidence on serial (XEXEC-02)
  3. The full boot chain boot(8)→init→rc reaches the interactive `% ` prompt on x86_64 — the expect smoke gate (boot-r9-smoke equivalent) is green twice consecutively (XEXEC-03)
  4. The tier machinery runs keyed to `objtype=amd64`: tier-0 libraries + tier-1 core commands prove executing on r9-x86_64 with committed artifact+execution markers, donor venue = Harvey's own 9k kernel (k10t1) (XEXEC-04)
  5. `/net` is re-gated on x86_64: loopback ping/udp/tcp echo, static + DHCP ipconfig, and the composed net smoke are all green as committed gates on the new arch (XEXEC-05)
**Plans**: 9/9 plans complete
Plans:
**Wave 1**
- [x] 14-01-PLAN.md — ABI contract freeze: the 184-byte 9k-verbatim Ureg rework + witness re-derivation, amd64/ABI.md publication, ureg-check amd64 arm + NEGATIVE CONTROL + the x86_64 boot-test gate — every Phase-13 gate re-green (XEXEC-01, D-01/D-02/D-02b)

**Wave 2** *(blocked on Wave 1 — the entry asm implements the frozen frame)*
- [x] 14-02-PLAN.md — SYSCALL/SYSRET entry contract: star/utextsel/fmask revival per the 9k donor, the syscallentry/syscallreturn/touser software-built-frame asm, init-time MSR arming — gates green with arming live (XEXEC-02 entry half, D-02a)

**Wave 3** *(blocked on Wave 2)*
- [x] 14-03-PLAN.md — exec loader + usermem port: validated user access on the CR3/live-memory model, the amd64 a.out loader (S_MAGIC 0x8A97, 2 MiB alignment) with the empty/adjacent edge tests — host-verified (XEXEC-02)

**Wave 4** *(blocked on Wave 3)*
- [x] 14-04-PLAN.md — proc + syscall dispatch port: per-process PML4/TSS-rsp0 Proc machinery, the measured-set dispatch (BP/SP+8/AX, nsec/seek/exits quirks, loud-unimplemented), the tick-print cfg gate (XEXEC-02)

**Wave 5** *(blocked on Wave 4 — the gate consumes the compile-verified substrate)*
- [x] 14-05-PLAN.md — marker exec end-to-end: mb2 TAG_MODULE delivery + templated module2 staging, Harvey's build/x86_64 marker+bake pipeline (paq format verbatim), IRQ-masked exec_bootstrap — the q35exec gate green twice (XEXEC-02 proof, D-03/D-04/D-08/D-09)

**Wave 6** *(blocked on Wave 5)*
- [x] 14-06-PLAN.md — boot chain boot(8)→init→rc to the `% ` prompt: mkfile.amd64 boot(8) build, the chain bake (rcmain/termrc/identity guards), config_q35shell + BOOT_ENTRY — the q35shell gate green twice (XEXEC-03 r9-side leg)

**Wave 7** *(blocked on Wave 6)*
- [x] 14-07-PLAN.md — compose: r9's parameterized ISO builder (kernel-only FOD preserved), Harvey's boot-r9-x64 app chain, the smoke-r9.expect re-key — the composed smoke green twice consecutively + push-before-pin (XEXEC-03, D-05/D-06)

**Wave 8** *(blocked on Wave 7)*
- [x] 14-08-PLAN.md — tiers re-keyed to objtype=amd64: allowlists + mk filter arms, subset-build with artifact markers, the k10t1 donor venue r9 leg — identical 6.outs on BOTH kernels, the r9 tier gate + ledger (XEXEC-04)

**Wave 9** *(blocked on Wave 8)*
- [x] 14-09-PLAN.md — /net re-gates in-guest: netaddr seam + netip fixtures + net-binary bake, the composed net smoke under the NOT-L2-TRUTH slirp label green + re-green, 14-EVIDENCE.md consolidation (XEXEC-05, D-07)

### Phase 15: Userspace Tiers + Bootfs Payload (amd64)
**Goal**: The services/GUI/long-tail tiers ride the re-keyed machinery — session daemons, the IP suite, and the auth suite compile and donor-execute on k10t1 then r9-x86_64; the GUI stack compiles with measure-first donor syscall traces captured; the desktop bootfs payload is staged so Phases 18-19 never block on payload. **Work in the harvey repo.**
**Depends on**: Phase 14 (XEXEC-04's re-keyed tier machinery + the r9-x86_64 venue); runs parallel with Phase 16
**Requirements**: USPACE-07, USPACE-08, USPACE-09, DESK-03 (bootfs payload staged here per the v2.0 precedent — Phase 19 consumes it)
**Success Criteria** (what must be TRUE):
  1. The services tier executes: aux/listen, mntgen, ndb/cs+dns, exportfs, the ip/ suite, and the auth/ suite (~80 files) run on the k10t1 (9k amd64) venue first, then on r9-x86_64, with committed execution markers (USPACE-07)
  2. The GUI stack compiles for amd64 (libdraw family + rio + acme + sam + plumb) and donor-kernel syscall traces for rio/acme/sam are captured and committed — the measure-first input for any r9 kernel growth the desktop needs (USPACE-08)
  3. The long tail compiles for amd64: upas + lp + the remaining cmd dirs; fossil + venti are compile-gated and documented as runtime-unverifiable this milestone (no block device in r9); gs is included (USPACE-09)
  4. The bootfs payload is staged with manifest assertions: `/lib/font/bit/*`, a glenda-style lib/profile, and a `/lib/ndb/local` template are present in the baked image (DESK-03)
**Plans**: 9/9 plans complete
Plans:
**Wave 1**
- [x] 15-01-PLAN.md — tier-2 services data + filters + driver (the anti-staleness decision lands) + aux leaf filter — T2-ART compile green (USPACE-07)

**Wave 2** *(blocked on Wave 1)*
- [x] 15-02-PLAN.md — services functional probes on the k10t1 donor: services-sweep.rc (D-02/D-08), the grown embed, computed SVC expectations (USPACE-07)
- [x] 15-04-PLAN.md — GUI tier compile (tier3 data + libdraw-family tier0 closure) + $T3 filter wiring — T3-ART compile green (USPACE-08)

**Wave 3** *(blocked on Wave 2)*
- [x] 15-03-PLAN.md — the services image (mkimage fifth contract) + the r9-x64 gate green twice + D-01 fix-everything + the SKIP flips + tier2.ledger (USPACE-07)
- [x] 15-05-PLAN.md — the draw donor venue: k10draw config + vgadispi (DISPI) + the -initrd font channel + the eve-gated kbin file (USPACE-08, D-04)
- [x] 15-09-PLAN.md — the libmemdraw LP64 pixel-path audit (carved out of 15-04): drawtest/arctest root-cause class fixes + stale test targets cleaned — BEFORE the trace capture (USPACE-08)

**Wave 4** *(blocked on Wave 3)*
- [x] 15-06-PLAN.md — the trace rig: tracesup + committed replays for rio/acme/sam, raw logs + distilled syscall tables, the drawtest/arctest re-join (USPACE-08, D-05/D-06/D-07)
- [x] 15-07-PLAN.md — long tail: the full DIRS-coverage proof re-keyed + fix classes + fossil/venti compile-gated + gs compile + the render smoke (USPACE-09, D-09/D-10/D-11)

**Wave 5** *(blocked on Wave 4)*
- [x] 15-08-PLAN.md — DESK-03 payload in the root-tree skeleton (manifest asserts, ndb template, D-17 profile, EARLY headroom check) + 15-EVIDENCE.md (DESK-03 + consolidation)

**UI hint**: yes

### Phase 16: Host Net Modes + Networking Exit Gate
**Goal**: Host networking is an explicit, documented choice — a hermetic slirp+hostfwd default that runs unprivileged and in CI, real-L2 tap/bridge on the linux primary host (opt-in socket_vmnet on darwin), a doctor-checker that prints exact remediation — and the milestone's networking exit gate (sustained bidirectional TCP on the tap leg) runs there. **Work spans both repos (r9 platform TOML + Harvey flake/docs).**
**Depends on**: Phases 13, 14 (virtio-net on x86_64; amd64 guest binaries executing — the `/net` payloads); runs parallel with Phase 15
**Requirements**: HNET-01, HNET-02, HNET-03, HNET-04, HNET-05, NETIP-08 (the tap-leg truth gate joins this phase per the v2.0 dependency shape)
**Success Criteria** (what must be TRUE):
  1. The default boot is hermetic and CI-able: slirp with hostfwd bound to 127.0.0.1 for BOTH tcp/17010 and tcp/567, zero privilege required, green in hosted CI (HNET-01)
  2. `--net=slirp|tap|vmnet` selects the mode explicitly with no silent auto-downgrade, and the netdev stanza is single-sourced as data in r9's x86_64 platform TOML, consumed by Harvey's flake (HNET-02)
  3. The linux tap/bridge leg (qemu-bridge-helper + br0) is documented per-distro and tested on the primary host — the guest is reachable at L2 from the host, providing the L2-truth venue (HNET-03); the darwin socket_vmnet leg is documented as opt-in documented-manual (HNET-04)
  4. A doctor-style checker diagnoses privileged host setup and prints the exact sudo/bridge/firewall remediation commands (HNET-05)
  5. The networking exit gate is green on x86_64: sustained bidirectional TCP flow + load soak on the tap leg — slirp evidence explicitly not accepted (it forgives L2 bugs) (NETIP-08)
**Plans**: 5/8 plans executed
Plans:
**Wave 1**
- [x] 16-01-PLAN.md — r9: [qemu.netdev] mode tables (slirp/tap/vmnet + default, D-04 hostfwd data) + the ONE netdev_args builder + the exported r9-netdev-args emitter package
- [x] 16-02-PLAN.md — Harvey: netaddr tap_ seam keys + the netip-tap.rc L2-truth fixture (ARP assert, burst leg) + the bake seam-assert extension, teeth-proven
- [x] 16-03-PLAN.md — Harvey: the net-doctor app (read-only per-mode checks, exact NixOS-first remediation, WARN class for root-gated reads)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 16-04-PLAN.md — Harvey: r9 pin advance (own commit) + the --net/R9_NET surface on boot-r9-x64 + emitter substitution + doctor-inline tap failure + the hermetic slirp boot proof

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 16-05-PLAN.md — NETIP-08 machinery: the tap soak gate app (doctor preflight, slirp refusal, host echo peer, baseline+8-way burst+ARP counting post-passes)

**Wave 4** *(blocked on Wave 3 completion)*
- [ ] 16-06-PLAN.md — HNET-01 CI leg: the net gate rides the emitter argv + hostfwd listener asserts + the r9-shell.yml net-smoke-x64 job
- [ ] 16-08-PLAN.md — NETIP-08 runs: the tap soak green twice + the in-phase kernel-fix loop (push-before-pin, FOD re-wire) + evidence/r9-SHA consolidation

**Wave 5** *(blocked on Wave 4 completion)*
- [ ] 16-07-PLAN.md — per-distro docs (NixOS tested, generic-Linux + darwin manual) + 16-EVIDENCE.md consolidation

### Phase 17: r9 Kernel Flush-Out
**Goal**: The r9 kernel is functionally hardened under real userspace load — the open Phase-7/8 review backlog (the CR classes, the RFMEM OOM leaks, the WR hardening gaps) plus the known kernel windows are closed with tests or explicitly dispositioned with rationale, every fix landing with a pin (host test or boot-test gate) per the established discipline. **Kernel work in sibling repo `../r9`.**
**Depends on**: Phases 14, 16 (real exec load on r9-x86_64 + the tap-soak load venue for the net findings); runs parallel with Phase 18
**Requirements**: FLUSH-01, FLUSH-02, FLUSH-03, FLUSH-04
**Success Criteria** (what must be TRUE):
  1. The Phase-8 review CR classes are closed with tests or explicitly dispositioned with rationale: conv_close FIN-drop, permanent-send-error wedge, semacquire wakeup loss, ipifc multicast panic, unbind stale-handle aliasing, tcp_gc aliasing, multi-waiter RX-wake — each fix pinned by a host test or boot-test gate (FLUSH-01)
  2. The RFMEM OOM-path page leaks (the 6 WR findings) are closed with refcount proofs — leak-repro gates demonstrate bounded memory under fork/exec churn (FLUSH-02)
  3. The Phase-7 WR hardening gaps are closed: cap-walk loud-abort holes, WaitSet-16-vs-MAX_PROCS-64 sizing, used-id slot-liveness (FLUSH-03)
  4. The known kernel windows are closed or gated — fork+exec arena drain (WINDOWS #44), namec union-create miss (WINDOWS #45) — every flush-out fix lands with a pin (FLUSH-04)
**Plans**: TBD

### Phase 18: In-Guest p9sk1 Auth Domain
**Goal**: The x86_64 guest is a self-contained p9sk1 auth domain — one bake-time generator produces the machine key, `/adm/keys`, nvram-substitute, and ndb entries as a hash-paired unit so all four p9sk1 configs agree by construction; keyfs + authsrv serve it over loopback `/net`; the in-guest probe proves the handshake before any drawterm is ever attempted. **Work spans both repos (r9 `/dev/random` + devcap; Harvey bake machinery + image).**
**Depends on**: Phases 14, 15 (loopback `/net` on x86_64; auth suite binaries from the services tier) — the first hard cross-track join; runs parallel with Phase 17; this phase's loopback probe green is Phase 19's entry criterion
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-09
**Success Criteria** (what must be TRUE):
  1. The bake-time domain generator exists and is the only way domains are made: machine key + `/adm/keys` + nvram-substitute + ndb entries produced as ONE hash-paired unit; the demo domain is loudly labeled DEMO and pairing verification fails loud (AUTH-01)
  2. r9's auth substrate is live on x86_64 with boot-test evidence: a `/dev/random` CSPRNG for p9sk1 challenges seeded from an x86_64-appropriate entropy source (no DTB — e.g. RDRAND/jitter mix, re-keyed from v2.0's DTB-seeded design) and devcap `#¤` (caphash/capuse) — the `auth_chuid` path the cpu server depends on (AUTH-02, AUTH-03)
  3. keyfs starts non-interactively over the baked `/adm/keys`, authsrv listens on tcp/567, and the guest domain's ndb content (authdom, hostid, sys, ether) is staged in the image (AUTH-04, AUTH-05)
  4. The in-guest loopback p9sk1 probe is green BEFORE any drawterm attempt: auth/debug completes a full handshake over loopback, the non-hostowner speaksfor gate passes, and serial-visible auth logging has been present since day one (AUTH-06, AUTH-07)
  5. secstore is available for persistent key storage beyond the baked keys, and the writable-`/adm` + nvram-substitute scoping is decided and documented (in-phase decision: baked+paired for CI; host-9P `/adm` mount for real use) (AUTH-08, AUTH-09)
**Plans**: TBD

### Phase 19: CPU Service + Drawterm + rio Desktop
**Goal**: The milestone's payoff — `nix run .#boot-r9` remains the ONE command on x86_64 and now brings up the full system (net + auth + cpu listener); `nix run .#drawterm` connects from the host, authenticates, and lands the user in an interactive rio desktop session — on the flush-out-hardened kernel. **Work spans both repos plus the flake glue.**
**Depends on**: Phases 15, 16, 17, 18 — strictly last (the dependency graph is a chain: desktop consumes cpu, cpu consumes auth, auth consumes net + userspace)
**Requirements**: CPU-01, CPU-02, CPU-03, CPU-04, DESK-01, DESK-02, DESK-04, DESK-05, DESK-06, DESK-07, INT-05, INT-06, INT-07 (DESK-03 staged in Phase 15)
**Success Criteria** (what must be TRUE):
  1. The cpu boot path is real on x86_64: r9 execs `#!` scripts (tcp17010 is literally `#!/bin/cpu -R`, execl'd by listen), `service=cpu` arrives via the x86_64 boot-protocol equivalent of DTB `/chosen/bootargs` (plan9.ini) so cpurc runs instead of termrc, and aux/listen + tcp17010 are live at boot with exportfs served (r9 implements WSTAT/FWSTAT/REMOVE) (CPU-01, CPU-02, CPU-03)
  2. The full `cpu -R` remoteside flow is verified end-to-end with serial evidence: p9any→p9sk1 → auth_chuid → client exportfs mounted at /mnt/term → stdio from /mnt/term/dev/cons → `rc -li` (CPU-04)
  3. The flake drawterm app exists (`nix run .#drawterm`) with its provenance decision recorded; the wrapper pins `-O`, scrubs `$cpu`/`$auth`/`$PASS`, prints the exact connect line — and the `-G` text-mode interop gate is green in CI via hostfwd (scripted login → shell marker) (DESK-01, DESK-06)
  4. rio starts only in-session: profile `case cpu` binds /mnt/term/dev over /dev and execs rio (a serial marker proves rio did NOT start at boot); plumb runs in the drawterm session; and r9 devssl `#D` (rc4_256/sha1) is available for encrypted sessions via pushssl, with `-e clear` as the documented fallback (DESK-02, DESK-04, DESK-05)
  5. The graphical leg is human-accepted on linux AND darwin (drawterm is host-side; the darwin leg connects to the linux-hosted guest); boot-r9-smoke is extended to the full chain; the r9 flake.lock pin advances via push-before-pin as its OWN commit with a fresh hosted CI run (never bundled); and the full v2.1 chain reproduces from clean checkouts on linux-x86_64 (darwin documented-manual) (DESK-07, INT-05, INT-06, INT-07)
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
13 → 14 → {15 ∥ 16} → {17 ∥ 18} → 19. The port is a chain (13 platform → 14 userspace); then tiers (15) and host net (16) run in parallel — both feeding the two hard-join phases (17 flush-out under load ∥ 18 auth domain) — and 19 is strictly last. Decimal insertions slot numerically.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Build-Tail Green (9k amd64) | v1.0 | 4/4 | Complete | 2026-10-31 |
| 2. aarch64 Toolchain + libc | v1.0 | 7/7 | Complete | 2026-11-01 |
| 3. r9 qemu-virt Platform Bring-up | v1.0 | 6/6 | Complete | 2026-11-01 |
| 4. r9 Userspace-Exec + Harvey↔r9 ABI | v1.0 | 8/8 | Complete | 2026-11-02 |
| 5. Shell Boot + One-Command Integration | v1.0 | 13/13 | Complete | 2026-11-04 |
| 6. Full-Tree Userspace — Wave 0 + Libraries/Core | v2.0 | 10/10 | Complete | 2026-11-05 |
| 7. r9 PCI/ECAM + virtio-net + devether | v2.0 | 10/10 | Complete | 2026-11-05 |
| 8. r9 TCP/IP Path — devip-Compatible /net | v2.0 | 9/9 | Complete | 2026-11-06 |
| 9. Host Networking + boot-r9 Net Modes | v2.0 | - | Subsumed → Phase 16 | - |
| 10. Userspace Services + GUI Tiers + Bootfs | v2.0 | - | Subsumed → Phase 15 | - |
| 11. In-Guest p9sk1 Auth Domain | v2.0 | - | Subsumed → Phase 18 | - |
| 12. CPU Service + Drawterm + rio Desktop | v2.0 | - | Subsumed → Phase 19 | - |
| 13. r9 x86_64 Platform Bring-Up | v2.1 | 6/6 | Complete    | 2026-11-07 |
| 14. Harvey amd64 Userspace on r9 | v2.1 | 9/9 | Complete    | 2026-11-09 |
| 15. Userspace Tiers + Bootfs Payload (amd64) | v2.1 | 9/9 | Complete    | 2026-11-10 |
| 16. Host Net Modes + Networking Exit Gate | v2.1 | 5/8 | In Progress | - |
| 17. r9 Kernel Flush-Out | v2.1 | - | Not started | - |
| 18. In-Guest p9sk1 Auth Domain | v2.1 | - | Not started | - |
| 19. CPU Service + Drawterm + rio Desktop | v2.1 | - | Not started | - |

## Backlog

### Phase 999.1: Follow-up — harvey.yml nix rewrite first-push verification (BACKLOG)

**Goal:** Confirm the rewritten harvey.yml workflow (nix pipeline, commit 261105-slx) goes green on the hosted runner after the next push — the red streak on master predates this work (since 2026-11-04T12:01Z)
**Source phase:** 06 (deferred at verification 2026-11-05)
**Follow-ups:**
- [ ] Hosted green run of the nix-based harvey.yml after first push
