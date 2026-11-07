# build/x86_64 — the r9 x86_64 companion

The x86_64 analog of `build/aarch64/README.md`: the per-topic contract
sections for the r9-on-q35 platform (Phase 13), the accel contract with
its no-silent-downgrade rule, the timer calibration chain, and the
qemu-11.1.2 drift notes. Everything here is consumed by `cargo xtask`
in the sibling repo `../r9` (config data under
`r9/x86_64/lib/config_q35*.toml`); this file is the Harvey-side record
of what those contracts mean and why they are what they are.

## Pins

| Tool | Version | Source |
|------|---------|--------|
| qemu-system-x86_64 | 11.1.2 | host pin (the project pin; NixOS host) |
| grub-mkrescue (GRUB 2.14) | 2.14 | `nixpkgs#grub2` (r9 devshell / flake derivation) |
| xorriso | 1.5.8.pl02 | `nixpkgs#xorriso` (r9 devshell / flake derivation) |
| SeaBIOS | qemu 11.1.2's bundled build | via `-M q35` |

## The boot chain contract (X64-01)

SeaBIOS → GRUB2 → mb2 → r9 kernel, from a `grub-mkrescue` ISO, driven
by `-cdrom`:

- **qemu's `-kernel` loader speaks multiboot 1 ONLY** (qemu issue #389,
  re-confirmed against 11.1.2). The DTB-free protocol therefore rides
  the ISO chain: SeaBIOS loads GRUB's El Torito image, GRUB parses the
  mb2 tagged header in `l.S` (`0xE85250D6`, inside `.text.boot`, first
  in `kernel.ld`), boots the higher-half ELF64 by honoring the AT()
  `p_paddr` bias (entry `0xffffffff80200000` loads at physical
  `0x200000` — no low-entry trampoline), and hands the mb2 info
  pointer via the l.S `.bss` stash (GRUB 2.14 lands the structure
  inside the Mach-zeroing mebibyte; the stash copy runs BEFORE the
  zeroing).
- **The `-cdrom`/`-kernel` distinction** is thus protocol-defining, not
  a convenience: `-kernel` would force mb1 (and ELF32 conversion),
  `-cdrom` carries the whole D-02 chain. The xtask `QemuStep`/`BootTestStep`
  x86_64 arms emit `-cdrom target/boot-<config>.iso` only.

### Recorded decision: q35, not pc (X64-01)

q35 was chosen for its PCIe root-complex topology — the D-08 recursive
bridge walk (read secondary/subordinate buses at config `0x19/0x1A`,
swizzle INTx per bridge crossing, fold to the root-bus slot) is
load-bearing on q35's root ports, where the legacy `pc` machine's
opaque south-bridge PCI would let the walk rot untested. It is also the
modern-only theme of the whole phase (LAPIC/IOAPIC-only, no 8259;
TSC-deadline timer; virtio modern-only): q35 is the machine a modern
kernel actually boots on; `pc` was rejected as legacy. The cost of q35
— SeaBIOS's PCIEXBAR hardcode, the MCFG-driven ECAM window — is
handled kernel-side (see the drift notes).

### Recorded decision: multiboot2, against 9k's multiboot(1) (X64-01)

This is a recorded divergence from Harvey's own 9k kernel: **9k stays
mb1** (`sys/src/9k/k10/main.c`'s `main(u32int ax, u32int bx)`), while
r9 x86_64 takes mb2 via the GRUB2 chain. Rationale (D-02, deliberate
user override of the mb1 recommendation): mb2's tagged protocol
(bounds-checkable tag walk, the fdt.rs parser discipline), the
loader-mediated entry matching Harvey's EFI/ISO boot lineage, and
qemu-independence — real hardware and other loaders speak mb2; qemu's
`-kernel` mb1 path ties the gate to one loader implementation. mb1
remains available as 9k's recorded path; the two kernels' boot
protocols are now deliberately distinct contracts.

## The accel contract (X64-05)

- **KVM-native is the default**, from data: `x86_64/lib/config_q35*.toml`
  carry `accel = "kvm"`, `cpu = "host"`, `smp = 1`, `memory = "1024M"`
  (D-01). The gate loop runs the TOML default with no overrides —
  `cargo xtask boot-test --arch x86-64 --config q35` (and
  `q35lowmcfg`, `q35net`) IS the KVM-native proof.
- **The TCG fallback is explicit and runnable**: 
  `cargo xtask boot-test --arch x86-64 --config <c> --accel tcg --cpu qemu64`.
  Under TCG the timer falls back to LAPIC periodic (see below) and the
  LAPIC to xAPIC MMIO — the CPUID gates key both ways, and the q35 +
  q35net TCG legs are green alongside the KVM legs.
- **NO silent auto-downgrade.** Acceleration comes only from the
  explicit chain `--accel/--cpu` flag > `R9_ACCEL`/`R9_CPU` env > TOML
  (`kvm`) > built-in default. A KVM-less environment fails loudly
  ("Could not access KVM kernel module" from qemu) unless the TCG leg
  was explicitly selected — the gates never quietly fall back to TCG
  because `/dev/kvm` happened to be absent (the same doctrine Phase
  16's HNET-02 net-mode chain carries).
- **The CI leg runs TCG by environment, not by downgrade**: hosted
  runners lack `/dev/kvm` (RESEARCH A7), so the r9 workflow's
  `boot-test-x86-64` job passes the explicit `--accel tcg --cpu
  qemu64` overrides — the same explicit selection, made for a
  KVM-less venue. KVM in hosted CI is out of scope this milestone.

## The timer chain

Mode selection is CPUID-gated at boot and printed with provenance
(`lapic: cpuid leaf-1 ecx: ...`, `timer: <Hz> (<source>), <mode>,
armed`):

- **KVM-native (`-cpu host`)**: CPUID.1 ECX bit 24 set → **TSC-deadline
  LAPIC timer**, armed by writing the true `IA32_TSC_DEADLINE` MSR
  **0x6E0** (one-shot, re-armed inside `tick()` — the
  NET_DEADLINE/poll_at one-shot idiom). NB: 0x832 is NOT the deadline
  MSR — it is the x2APIC-mode address of the LVT-timer register
  itself, and KVM gates the entire MSR range 0x800-0xBFF on the guest
  actually being in x2APIC mode; a 0x832 write from xAPIC mode is an
  architectural #GP on any host (found live in 13-03; 0x6E0 is valid in
  either APIC mode). The LAPIC itself runs CPUID.01H:ECX[21]-gated
  x2APIC (MSR map) when the CPU advertises it, classic xAPIC MMIO
  otherwise — the same publish-once registry either way.
- **TCG (`-cpu qemu64`)**: bit 24 clear (TCG's feature whitelist
  omits TSC-deadline entirely) → **LAPIC periodic** (DCR divide +
  ICR initial count, re-armed in the handler), LAPIC rate calibrated
  against the resolved TSC.
- **Frequency resolution order**: CPUID 0x15 (crystal ratio) → CPUID
  0x16 (nominal) → **PIT channel-2 one-shot calibration**, with sanity
  bands — synthetic qemu CPU models report nonsense leaf values
  (a Skylake-Client under TCG claimed a ~68 kHz crystal; measured),
  and out-of-band values fall through to the next source. Live values
  on the gate host: 2496 MHz via the PIT reference.

## qemu 11.1.2 drift notes

Each entry: the drift, the accommodation (always harness- or
data-side, never in vendored/pinned trees), and the re-test condition.

| Drift | Accommodation | Re-test |
|-------|---------------|---------|
| `-global q35-pcihost.MCFG=<any value>` **crashes qemu 11.1.2 at machine init** — the MCFG property stores into `PCIExpressHost.base_addr`, the same field `pcie_host_mmcfg_unmap()` uses as its is-mapped state, so ANY pre-realize set (including the default 0xb0000000) trips the `memory_region_del_subregion: Assertion 'subregion->container == mr'` failure on the first mch reset. Verified against the v11.1.2 source. | The X64-03 moved-window perturbation rides `-acpitable file=x86_64/lib/q35-mcfg-moved.bin` (a committed 60-byte artifact: qemu's own guest MCFG with base → 0xe0000000, checksum recomputed). qemu/SeaBIOS ADD the user table after the built-ins (two MCFGs in the RSDT, moved one last) and r9's ACPI walk takes the last MCFG — the ACPI override idiom — with the gate asserting exact bases so ordering drift reds loudly. | If the qemu pin ever advances past 11.1.2, re-test `-global q35-pcihost.MCFG=0xe0000000` (the upstream property-vs-unmap interaction may be fixed); if it works, the config can return to the plain `-global` form and the committed artifact can retire. |
| SeaBIOS hardcodes `Q35_HOST_BRIDGE_PCIEXBAR_ADDR 0xb0000000` and writes it on every boot — a kernel that only trusts the ACPI MCFG table breaks under any moved window. | Not a qemu bug to accommodate but a firmware fact to follow: r9 PROGRAMS the MCH PCIEXBAR register (config 0x60) from the parsed MCFG base before the first ECAM access, printing the `pciexbar: <old> -> <new>` audit line. The one CF8/CFC port access for that single write is the recorded D-07 carve-out; all other config access is ECAM. | Re-verify the audit line's old→new pair whenever the SeaBIOS bundle in the qemu pin changes. |
| TCG's CPU feature whitelist omits `CPUID_EXT_TSC_DEADLINE_TIMER` (and qemu64 carries only SSE3+CX16); the TCG APIC model implements only periodic/one-shot timer modes. | Kernel-side CPUID gating (the timer chain above) — the documented TCG fallback leg, not a harness workaround. | None (architectural emulator behavior). |
| TCG's `qemu64` has no FSGSBASE (CR4 pinning wedges early boot; found live in 13-03 by EIP sampling). | r9 never enables CR4.FSGSBASE; warp64 sets the kernel GS base via the `IA32_KERNEL_GS_BASE` MSR — valid everywhere. | None needed for the pinned pair; if a future CPU model gains FSGSBASE under TCG the MSR path remains correct. |

## Where the gates live

`cargo xtask boot-test --arch x86-64 --config {q35,q35lowmcfg,q35net}`
in `../r9` (under `nix develop`): ordered serial markers, never
timings; accel-aware wall-clock budgets (TCG multiplies the
first-marker and overall allowances — SeaBIOS+GRUB+BIOS-disk load
dominates under emulation); negative panic scan; per-run serial logs +
pcap under `r9/target/`. The KVM-native loop is the default proof; the
TCG legs are the documented fallback; r9's `boot-test-x86-64` CI job
runs the three profiles TCG on hosted runners (see
`.planning/phases/13-r9-x86-64-platform-bring-up/13-EVIDENCE.md` for
the local-validation matrix and the hosted-leg status).
