# build/x86_64 — the r9 x86_64 companion

The x86_64 analog of `build/aarch64/README.md`: the per-topic contract
sections for the r9-on-q35 platform (Phase 13), the accel contract with
its no-silent-downgrade rule, the timer calibration chain, the
qemu-11.1.2 drift notes, and — since Phase 16 — the **host net modes**
(`--net=slirp|tap|vmnet`) with their per-distro host-setup pages
(NixOS tested on the primary host; generic Linux and darwin
documented-not-tested, each labeled as such below). Everything here is
consumed by `cargo xtask` in the sibling repo `../r9` (config data
under `r9/x86_64/lib/config_q35*.toml`); this file is the Harvey-side
record of what those contracts mean and why they are what they are.

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

## The net modes (Phase 16: HNET-01..HNET-05, NETIP-08)

Three explicit modes, one data source, zero silent downgrades. The
netdev stanza qemu sees is **pinned TOML data in the r9 repo** —
`[qemu.netdev]` with `default = "slirp"` plus `slirp`/`tap`/`vmnet`
sub-tables in all five `config_q35*.toml` — emitted by ONE builder
(`xtask`'s `netdev_args`) consumed by both front-ends: the in-process
r9 gates and the exported `r9-netdev-args` bin (D-05). No Harvey
script assembles a netdev token.

### The one-command surface

```
nix run .#boot-r9-x64                      # the hermetic slirp default
nix run .#boot-r9-x64 -- --net=slirp|tap|vmnet
R9_NET=tap nix run .#boot-r9-x64           # env sets the default
nix run .#boot-r9-x64 -- --system=cpu      # the FULL system (see the Phase-19 section below)
```

- **Selection chain (D-01, the R9_ACCEL precedent):** `--net=<mode>`
  flag over `R9_NET` env over the `slirp` default. The `=` form ONLY —
  `--net tap` is a usage error, one accepted form, no ambiguity.
- **Fail-loud rules:** an unknown mode is a usage error listing
  `slirp|tap|vmnet`; a cross-venue request (`--net=vmnet` on linux,
  `--net=tap` on darwin) is rejected at parse naming the venue's valid
  modes — never an obscure failure inside qemu, never a silent
  downgrade.
- **The tap leg doctor-gates FIRST (D-03):** `--net=tap` runs the
  net-doctor before any bake/boot and aborts on any FAIL with the
  per-issue remediation blocks inline; `--net=vmnet`/`--net=tap` off
  their venues never reach that far (parse rejects them).
- **Parallel-boot constraint:** both slirp hostfwd listeners bind
  eagerly at netdev init — two simultaneous slirp-venue boots on one
  host collide on `127.0.0.1:17010`/`127.0.0.1:5670`; two simultaneous
  tap soaks collide on the peer's blastport bind and the one br0 leg.
  Run the x86_64 gates sequentially.

### The slirp default (hermetic, zero-privilege, CI-able — HNET-01)

The emitted argv (verbatim from the pinned emitter; the D-04 hostfwd
pair is TOML data):

```
-netdev user,id=n0,hostfwd=tcp:127.0.0.1:17010-:17010,hostfwd=tcp:127.0.0.1:5670-:567
-device virtio-net-pci-non-transitional,netdev=n0
```

| Host entry point | Forwards to guest | Service era |
|------------------|-------------------|-------------|
| `127.0.0.1:17010` | guest `17010` | the cpu-listener drawterm target (Phases 18/19) |
| `127.0.0.1:5670`  | guest `567`      | the auth listener (Phase 18 owns the listener itself) |

Both hostfwd rules bind **loopback only** — never `0.0.0.0` (HNET-01's
wording; the default must not expose future guest services to the LAN).

**The D-04 remap rationale.** Linux refuses unprivileged binds below
1024: `net.ipv4.ip_unprivileged_port_start = 1024` on the primary host
(the stock default; live sysctl), and a bind attempt on 567 as an
unprivileged user fails EPERM (live probe, errno 13) while
17010/5670/7777 bind clean. A literal `hostfwd=tcp:127.0.0.1:567-:567`
would make the hermetic default require privilege or a sysctl — so the
HOST entry point for auth is 5670 while the guest port stays 567 (the
in-guest service contracts Phases 18/19 own are untouched).

**The 1:1 host-567 variant (documented opt-in, NOT the gates' shape).**
A venue that wants `127.0.0.1:567-:567` verbatim sets
`net.ipv4.ip_unprivileged_port_start` to 0 (or a start ≤ 567) and
re-keys the slirp TOML stanza's hostfwd line; no committed gate runs
that shape (the deferred-ideas list names it opt-in only).

### The tap topology (D-08 — the L2-truth leg, linux only)

| Element | Value | Source |
|---------|-------|--------|
| bridge | `br0` (empty member list — a pure NAT bridge) | the r9 TOML `br=` + host config |
| subnet | `192.168.122.0/24` (libvirt-conventional; collision-free with slirp's 10.0.2.0/24 and the host LAN) | OQ-1 adopted the host's existing bridge |
| host | `192.168.122.1` (`tap_gwv4` — the echo peer binds here) | the netaddr seam |
| guest | `192.168.122.15` (`tap_guestv4`, static — DHCP-on-tap is a documented non-goal, D-09) | the netaddr seam |
| egress | masquerade out the default route | host config (the doctor WARNs until verified) |
| inbound | **NO LAN→br0** — the bridge is not exposed to external networks | D-08's rule |

Guest-side addressing lives ONLY in the seam
(`build/x86_64/root-tree/lib/netaddr.rc`'s `tap_` keys), consumed by
`/lib/netip-tap.rc` (static ipconfig → gateway ping → ARP L2-truth
assert → the tiered soak); the bake-time literal-grep assert enforces
the single seam for both venue prefixes. The emitted tap argv carries
the NixOS helper path verbatim:

```
-netdev tap,id=n0,br=br0,helper=/run/wrappers/bin/qemu-bridge-helper
-device virtio-net-pci-non-transitional,netdev=n0
```

**The real-LAN variant — NOT TESTED.** Giving `br0` a physical member
(`networking.bridges.br0.interfaces = [ "wlan0" ]`-class) would place
the guest on the LAN at L2. That variant is explicitly **not tested**
this phase and carries no gate: nobody has run it, the security
posture above (NAT, no inbound) does not describe it, and anyone
adopting it re-derives the firewall and masquerade story for their own
venue. It is documented here only so the question has a named answer.

### The NixOS page — TESTED on the primary host (D-10)

This is the tested-and-proven page: the primary host's actual
remediation (the `allow br0` bridge.conf line + the
`trustedInterfaces` firewall opening) was applied for the 16-05/16-08
soak, which ran green twice through this exact br0 setup. The same
content prints live from `nix run .#net-doctor` — the README is the
canonical home, the doctor the live one.

**Two measured divergences lead — every NixOS tap setup hits both:**

1. **The nosuid store helper (helper= MUST be explicit).** Both qemu
   11.1.2 builds on the host (the system `qemu-host-cpu-only` and the
   flake's nixpkgs qemu) compile the bridge helper's DEFAULT path into
   their own read-only `/nix/store/.../libexec` — mounted nosuid, so
   the setuid bit is dead and unprivileged tap creation fails obscurely
   inside qemu. Neither binary carries a `QEMU_BRIDGE_HELPER` env
   override (0 strings in the binaries — live-extracted). The tap
   netdev therefore names the wrapper explicitly:
   `helper=/run/wrappers/bin/qemu-bridge-helper` (the committed TOML
   carries it verbatim; without it qemu prints "bridge helper failed"
   with br0 and bridge.conf both correct).
2. **The bridge.conf allow virbr0-vs-br0 trap.** The host's
   `/etc/qemu/bridge.conf` (libvirt-era) contained `allow virbr0` only
   while the bridge that exists is `br0` — the helper denied with
   `access denied by acl file` (live-probed: running the wrapper
   against a non-allowed bridge prints exactly that). The ACL is
   exact per-bridge lines; `allow all` is forbidden (the ACL is the
   unprivileged-tap control point).

The declarative remediation (add to the host config, rebuild; the
bridge, ip_forward, and the setuid wrapper already existed on the
primary host via its libvirt-era setup — the delta was the allow line
and the firewall opening):

```nix
networking.bridges.br0.interfaces = [ ];  # empty member list: the pure NAT bridge (D-08)
networking.interfaces.br0.ipv4.addresses = [
  { address = "192.168.122.1"; prefixLength = 24; }
];
networking.nat.enable = true;
networking.nat.externalInterface = "<default-route iface>";  # ip route show default names it
networking.nat.internalInterfaces = [ "br0" ];
boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
# br0<->host forwarding ONLY — NO LAN-to-br0 inbound stays the rule (D-08).
# MEASURED on the primary host: without this line, inbound NEW TCP from
# br0 is default-DROPped (NixOS firewall) and the soak peer is
# unreachable from the guest — 4x SYN on the wire, zero SYN-ACK
# (the 16-08 wedge root-cause; see the doctor-gap note below):
networking.firewall.trustedInterfaces = [ "br0" ];
environment.etc."qemu/bridge.conf".text = ''
  allow br0
  allow virbr0  # keep ONLY while libvirt's virbr0 must stay allowed (append semantics)
'';
# the EXACT per-bridge line only — "allow all" is forbidden
security.wrappers.qemu-bridge-helper = {
  source = "${lib.getBin pkgs.qemu}/libexec/qemu-bridge-helper";
  owner = "root";
  setuid = true;
};
```

**Colmena note:** the primary host's `/etc/nixos/configuration.nix`
literally `throw`s "managed by colmena" — the snippet lands in the
colmena config, never in /etc/nixos.

**Doctor-gap warning (measured, 16-08):** the `trustedInterfaces` line
above is part of the tap remediation even where the doctor does NOT
print it — on a host whose netfilter read is privileged-only, the
masquerade check degrades to WARN (by design, never gates) and the
WARN text carries only the sudo verify commands, so the firewall
opening was never surfaced by the tool; the human had to find it
through the soak's wedge diagnosis. Treat the checklist above — not
the doctor's FAIL list alone — as the complete tap remediation.

**The honest boundary of "TESTED":** the soak's traffic terminates at
the host peer on the bridge IP (guest `.15` → host `.1`), so the
bridge/addr/sysctl/ACL/firewall lines above are proven live by the
green-twice runs; the `networking.nat` masquerade rendering is NOT
exercised by any committed gate (nothing dials past the default route)
and stays WARN-class in the doctor — unproven on this host.

### The generic-Linux page — DOCUMENTED, NOT TESTED

Nobody has executed this page in anger; it is the imperative
equivalent of the NixOS snippet above (the doctor prints it
automatically on non-NixOS hosts). The NixOS page is the tested one.

```sh
ip link add br0 type bridge && ip link set br0 up
ip addr add 192.168.122.1/24 dev br0
sysctl -w net.ipv4.ip_forward=1          # persist via the distro's /etc/sysctl.d/
nft add table nat
nft add chain nat postrouting '{ type nat hook postrouting priority 100 ; }'
nft add rule nat postrouting oifname "<default-iface>" ip saddr 192.168.122.0/24 masquerade
# the host-bound firewall opening (the 16-08 lesson above applies to every
# default-enabled firewall — the NixOS-measured DROP is the example, not the only case)
chmod u+s /usr/libexec/qemu-bridge-helper # distro path varies: find /usr -name qemu-bridge-helper
echo "allow br0" >> /etc/qemu/bridge.conf # the EXACT per-bridge line — never "allow all"
```

### The darwin page — DOCUMENTED-MANUAL (HNET-04)

This leg is unexecuted by construction: this milestone has no darwin
runner. `--net=vmnet` is accepted on darwin only (linux rejects it at
parse as cross-venue), and the doctor prints an INFO n/a line on linux
pointing here.

- **The daemon model:** socket_vmnet runs as root (launchd or sudo) and
  exposes vmnet over a UNIX socket — default `/var/run/socket_vmnet`;
  Homebrew `${HOMEBREW_PREFIX}/var/run/socket_vmnet`; MacPorts
  `/var/run/socket_vmnet`. Install routes: `brew install socket_vmnet`
  + `sudo brew services start socket_vmnet`, or `sudo make
  install.launchd`, or nix (`socket-vmnet` 1.2.2 in nixpkgs,
  aarch64-darwin). Shared/NAT is the default mode; bridged-en0 is a
  separate daemon/socket.
- **The vmnet-socket argv the r9 emitter prints** (from the committed
  vmnet TOML table):

  ```
  -netdev vmnet-socket,id=n0,path=/var/run/socket_vmnet
  -device virtio-net-pci-non-transitional,netdev=n0
  ```

  **A4 flag:** this `path=` spelling is the corroborated-not-probed
  form — qemu ≥ 9.0 official docs are sparse, two secondary sources
  corroborate, and it cannot be probed on linux. The verified
  alternative from the socket_vmnet README is fd-passing:
  `socket_vmnet_client` + `-netdev socket,id=net0,fd=3`.
- **The entitlement wall on builtin vmnet:** the builtin
  `vmnet-host`/`vmnet-shared`/`vmnet-bridged` backends require the
  Apple-contract-restricted entitlement `com.apple.vm.networking` —
  the nixpkgs darwin qemu is unsigned, so builtin vmnet would mean
  running qemu itself as root. socket_vmnet is the rootless route;
  that is why it is this project's darwin leg.

### The scripts and their contracts

| Surface | Contract |
|---------|----------|
| `nix run .#boot-r9-x64` (`nix/boot-r9-x64.sh`) | the one-command interactive boot. Argv: `--net=slirp\|tap\|vmnet` (the `=` form only) — flag over `R9_NET` over the slirp default, venue-validated at parse; and `--system=terminal\|cpu` (19-09) — flag over `R9_SYSTEM` over the terminal default; cpu boots the full system off §15's image with the bootconf append (see the Phase-19 section). Env: `R9_KERNEL_X64_PKG` + `R9_ISO_BUILDER` + `R9_NETDEV_EMITTER` (required), `R9_NET_DOCTOR` (required for `--net=tap` only — the D-03 gate), `R9_SYSTEM` (default system mode), `R9_ACCEL`/`R9_CPU`, `R9_SKIP_BUILD`, `KERNDATE`. The qemu netdev+device argv is the emitter's output for the selected mode — no netdev literal in the script. |
| `nix run .#net-doctor` (`nix/net-doctor.sh`) | the read-only host-state doctor. `--mode slirp\|tap\|vmnet\|all` (default `all`). 12 checks (slirp 3, tap 8, vmnet 1 — the committed list; extending it is a new decision, not a silent patch). Every FAIL prints the exact remediation (NixOS-declarative first when `/run/current-system` exists, generic imperatives otherwise). **Exit semantics:** exit 0 iff zero FAILs (final line `DOCTOR-OK`); WARN-class findings NEVER gate the exit — the root-gated masquerade read degrades to a loud WARN carrying the exact sudo commands. Never fixes anything (D-14). |
| `R9_NET=tap nix run .#boot-r9-net-soak-x64` (`nix/soak-r9-net-x64.sh`) | the NETIP-08 soak gate. **Refuses slirp outright** — `slirp evidence not accepted … refusing before any bake or boot` at parse time, the hermetic default included, BEFORE the doctor preflight (a doctor-first order would make the refusal unreachable on wrong-allow hosts). Gate data (committed in the expect driver): baseline 2048 rounds + burst 8×512 (`rc /lib/netip-tap.rc 2048 8` — one typed line, the fixture owns the legs). One soak at a time (the peer's blastport bind + one br0 leg). |
| `host-echo` (`nix/host-echo.c` → flake `hostEchoX64Pkg`) | the soak's host-side echo peer (D-12): argv `host-echo <bindaddr> <port>` (the gate passes the seam's `tap_gwv4` + `blastport` — binds the literal bridge address, NEVER the wildcard). poll()-concurrent (the listener and every accepted fd in one loop — the anti-serialization shape; 8 simultaneously-open tcpblast connections are the burst). Markers: `hostecho: listening <addr>:<port>`, `hostecho: conn <n>`, `hostecho: closed <n> <bytes-in> <bytes-out>`. Runs as the gate's own child, SIGTERM teardown — no daemon, no systemd, dies with the gate. |
| `r9-netdev-args` (r9 `packages.netdev-args`, pinned) | the ONE netdev emitter (D-05): `--mode slirp\|tap\|vmnet [--pcap <path>] [--config <path>]`; default config = the committed `config_q35shell.toml` embedded at build time. Prints the netdev+device(+filter-dump) argv tokens for the mode — every Harvey front-end (boot script, net gate, soak) consumes this output; nothing re-assembles netdev text. |

### Probe-evidence notes (the measured facts behind the above)

All probed live on the primary NixOS host (2026-11-10/11, read-only
probes; qemu 11.1.2 both builds unless noted):

- **Ports bind matrix:** 17010, 5670, and 7777 (blastport) bind
  unprivileged; 567 fails EPERM (errno 13).
  `net.ipv4.ip_unprivileged_port_start = 1024`.
- **Devices:** `/dev/kvm` `crw-rw-rw-` (world rw — KVM venues need no
  group); `/dev/net/tun` `crw-rw-rw-`.
- **The helper default:** both qemu builds compile
  `CONFIG_QEMU_HELPERDIR` to their own store libexec (nosuid); 0
  `QEMU_BRIDGE_HELPER` env-override strings in either binary; the
  working wrapper at `/run/wrappers/bin/qemu-bridge-helper`, mode
  4511 (`-r-s--x--x`).
- **The bridge (pre-remediation):** br0 192.168.122.1/24, UP, no
  members, stp off; `ip_forward=1` already set;
  `/etc/qemu/bridge.conf` = `allow virbr0` only — the wrapper denied
  br0 with `access denied by acl file`.
- **The r9 pin relationship:** every emitted netdev argv this era
  comes from Harvey's `flake.lock` pin
  `d1c4849dfa1d769240630c29b9b03b88d5819558` (the 16-01 pushed SHA,
  advanced from `af52fee` as its own lock-only commit) — the 16-04
  boot capture's echoed argv carries `r9-netdev-args-d1c4849` in the
  emitter path. A pin predating the 16-04 advance lacks the export
  (the boot script's contract check names that case).
- **Cross-reference:** `nix run .#net-doctor` is the LIVE remediation
  source — its printed remediation blocks are the same content as the
  pages above (the doctor's tap address values interpolate the seam at
  runtime; this README spells the committed seam values out).


## Auth domain (Phase 18: AUTH-01..AUTH-09)

One command boots the whole p9sk1 domain and gates it:

```
nix run .#boot-r9-auth-x64            # KVM default; R9_ACCEL=tcg for the hosted leg
```

The bake (mkimage §14, the sixth contract) invokes the domain
generator AT BAKE: `authdomain-gen` (18-03, host cc over the vendored
Harvey donor algorithm files — passtokey/DES-CBC/nvcsum are the
donor's own code, compiled not reimplemented) produces the
hash-paired unit — `/adm/nvram` (the 112-byte Nvrsafe the guest's
readnvram expects — the amd64 6c end-pads the 109-byte struct; the
generator emits layout+tail), `/adm/keys` (DES-CBC under the nvram
machkey — the pairing invariant), `/lib/ndb/auth` (the speaksfor
rows), and the sha1 manifest.  The bake asserts the pairing over the
STAGED COPIES (`AUTHBAKE_DOCTOR=nvram|keys|ndb-auth` flips a byte in
the scratch twin and the bake must refuse — the runnable teeth seam)
and the guest re-verifies all three digests before keyfs starts.

### The domain interface (D-01)

- **A developer's real domain:** a gitignored `/authdomain.local` at
  the repo root satisfying the committed interface
  `build/x86_64/authdomain.example` (label/authdom/
  machine_password/secstore_password + user lines).  Actual key
  material never lands in git history.
- **Absent file (CI / clean checkout):** the generator produces
  ephemeral **DEMO** material at bake time — real randomness, the
  loud DEMO label in every artifact (`DEMO-harvey`, three users
  glenda/bootes/norbert sharing one 12-char per-bake password), so
  every presence-based gate stays green on a clean checkout and the
  image is legitimately NOT byte-reproducible across bakes (the
  manifest is an internal-consistency proof, never a cross-build
  identity claim; the auth image is never FOD-bound).
- **A local-file bake re-keys the domain** — the gate asserts the
  PAIRED banner carries the DEMO label and reds loudly if it doesn't.

### The scoping verdict (AUTH-09/D-15)

**Baked+paired per-bake domains are the CI/gate venue.**  For REAL
use, the writable-`/adm` + nvram-substitute answer is a **host-9P
`/adm` mount — documented, not wired** (never implemented in this
phase): the wiring belongs to the
phase that first needs a real (non-CI) domain (post-v2.1 or a
demand-named follow-up).  No such mount exists anywhere in this tree;
nothing here promises one.  Consequence: the secstore venue is
per-boot scratch (ramfs) — persistence ACROSS boots is not claimed
and is part of the same deferred wiring.

### The venue facts (measured)

- **The writable `/adm/secstore` is ramfs** — mntgen's FILE writes
  are read-only on this tree (15-06), re-confirmed live in 18-05: an
  rc `>` create under a mntgen-served `/adm/secstore` is refused
  (`devmnt: directory opens OREAD only`) and rc's redirect-open
  failures are FATAL to a sourced sweep — the gate's leg probes the
  ramfs venue (MREPL|MCREATE) live instead.  The `cmd/ramfs` tier
  leaf carries it.
- **`listen1 -t` is the trusted arm** for `authsrv -d` on
  `tcp!*!567` (its `-t` skips `becomenone()`, whose namespace strip
  would starve authsrv; the staged-copy listener cannot pass `-d`).
  `secstored -v` announces `tcp!*!5356` self-contained.
- **AUTH-07's serial visibility is syslog's `#c/cons` fallback** —
  authsrv -d's `tr-ok`/`tr-fail` and secstored's
  `ANNOUNCE`/`AUTH`/`[id] PUT/GET` lines reach the console because
  read-only paqfs makes `/sys/log/*` unopenable.  NEVER stage a
  writable `/sys/log` (a writable log file silently kills the
  fallback — Pitfall 6).
- **The service-name row:** the composed `/lib/ndb/local` carries
  `tcp=ticket port=567` — cs's `ipserv` translates alpha service
  names through the ndb (`cs.c`), so every `dial(netmkaddr(a, nil,
  "ticket"))` (auth/debug's own form and authprobe's) resolves.
- **The 112-byte Nvrsafe guest ABI:** any future bake-side emitter of
  nvram-substitutes must emit 109-layout + 3 tail bytes (the amd64
  guest compiler end-pads the struct; readnvram reads sizeof bytes
  and rejects other lengths silently).
- **The secstore client pins its listener (18-08, measured):** the
  client's default serve `$auth` rides cs's `$attr` translation,
  whose system-identity substrate ENOETs on r9 (the kernel's
  `namec: does not exist` relayed verbatim as the cs error —
  `secstore: can't dial tcp!$auth!5356`).  The sweep's 9d legs pass
  `-s 127.0.0.1` (secstore's own flag) — the same literal-loopback
  dial class the hauthprobe legs prove every run.

### The marker vocabulary

| Marker | Producer | Meaning |
|--------|----------|---------|
| `authdom: PAIRED <label>` | the sweep's leg 1 | the D-02 boot pairing check passed (label from the manifest — DEMO on the gate path) |
| `AUTH-OK keyfs` | leg 2 | keyfs mounted `/mnt/keys` non-interactively over `nvram=` |
| `AUTH-LOOPBACK-UP` | leg 3 | the loopback /net bring-up |
| `AUTH-OK authsrv-listen` / `AUTH-OK secstored` | leg 4 | the listener topology (567 connect-accept proven; 5356 announced) |
| `AUTH-OK cs` | leg 5 | cs answered `authdom=DEMO-harvey` → `auth=127.0.0.1` from the baked local |
| `AUTH-OK factotum` | leg 6 | factotum carries norbert's p9sk1 key (written from the baked feed) |
| `AUTH-DEBUGOBS ticket request using norbert@…` | leg 7 | auth/debug's OWN p9sk1 success line as norbert (the filtered echo — only the matching line reaches serial, T-18-13) |
| `authprobe: SPEAKSFOR-OK bootes for norbert` | leg 8 | the speaks-for wire form (hostid≠uid) proven: the reply decrypts with the SPEAKER's key and carries `suid=norbert` |
| `authprobe: SPEAKSFOR-DENIED sys` | leg 8 | the negative control's EXPECTED output (exactly once; the `uid=!sys` row bit and the scrambled reply failed to decrypt) |
| `AUTH-CONSOLEOBS restored` | leg 8 | the sentinel window's cleanup (`'#c/cons'` re-bind — getpassm needs the live console) |
| `AUTH-VENUEOBS ramfs-file-write-ok` | leg 3b/9 | the writable venue probed live (create/write/read through the ramfs mount) |
| `AUTH-OK secuser` | leg 9 | the account created through the venue (console-fed passwords; who/ + store/ + who/norbert standing) |
| `secstore: saved N bytes` | leg 9d (client, fd 2) | the client PUT's own success line — unconditional on a completed PUT |
| `AUTH norbert` / `[norbert] PUT` / `[norbert] GET` (syslog) | secstored -v | the round-trip's server-side tokens through the `#c/cons` fallback (one AUTH line per connection) |
| `AUTH-SECOBS AUTH-ROUNDTRIP-PAYLOAD-18-05` | leg 9d | the bytes-back observation — the unique payload line grepped out of the `-G` GET's DELIVERED bytes (D-14: test-delivery-not-counters) |
| `AUTH-OK secstore-roundtrip` | leg 9d | the verdict, printed ONLY on that bytes-back match; presence-demanded by the gate (18-08's flip — the 18-05 named-SKIP arm is retired) |
| `AUTH-DONE` | the sweep | every leg green |
| `tr-ok` / `tr-fail` (syslog) | authsrv -d | the per-exchange AUTH-07 evidence (the deny exchange's `tr-fail … no speaks for` is the fail-closed proof) |

The gate redacts the per-bake DEMO password from the retained capture
(auth/debug's noise leg echoes the sentinel line into one syslog
authid field); the asserts run over the true capture first.

### The closed blocker: the secstore client round-trip (AUTH-08/D-14) — DELIVERED

The 18-05 blocker is CLOSED (18-07 + 18-08).  The defect — r9's
devip loopback TCP never delivering SConn's donor two-write pattern
(a 2-byte count write then the payload write, `secstore/SConn.c`
SC_write; both procs parked forever) — was root-caused at
`tcp_socket`'s stock smoltcp defaults: **Nagle ON + a 10 ms delayed
ACK** held every sub-MSS follow-up write for a post-deadline drive a
fully-parked venue can never run.  The fix (r9 `ab4cb66`, the 18-07
plan) restores the donor's TCP shape — Nagle off, ACK immediate —
pinned RED->GREEN host-side (`tcp_two_write_client_pattern_round_trips`)
and proven live (the mode-2 stall became the mode-2 round-trip;
`evidence/18-07-devip-twowrite-{repro,fix}.console.log`; the 18-05
isolation matrix stays at
`evidence/18-05-secstore-stall-modes.console.log`).

18-08 closed the Harvey half: the FOD pass pinned the kernel bytes
(r9 `9103522`, Harvey `flake.lock` advanced lock-only), the sweep's
9d legs are restored per their committed shape (venue copy, PUT with
CWD there, `-G` GET, the bytes-back grep), and the gate FLIPPED from
the retired named-SKIP arm to presence demands (`secstore: saved`,
`AUTH norbert`, `[norbert] PUT`/`[norbert] GET`, `AUTH-SECOBS`, and
the verdict are all staged and post-pass demanded; every pre-existing
tooth — nvram-prompt-absent, zero-AUTH-FAIL, the DEMO label,
ANNOUNCE, DENIED-exactly-once, tr-ok, no-speaks-for — stayed armed).
The full gate is green twice consecutively at the advanced pin with
both captures retained: `evidence/18-08-auth-a.log`,
`evidence/18-08-auth-b.log` (redacted; the verdict appears only
where the payload line came back in the delivered bytes).  The
client dials `-s 127.0.0.1` — see the venue fact above.

## Drawterm (Phase 19: DESK-01, DESK-06, DESK-07)

The client surface is the **vendored in-tree drawterm**
(`sys/src/cmd/unix/drawterm`) — D-01's source of record: the Plan 9 4e
lineage carrying the Harvey-era fixes, built as a normal part of this
tree.  Upstream (0intro/9front) maintenance is deliberately NOT
re-vendored; every phase-19 addition (`-O`, `-G`, the `gui-none`
backend) lands as ordinary Harvey commits on the vendor.  The flake's
`packages.drawterm` compiles that committed source hermetically (D-02:
`src` is the repo directory itself — no `fetchurl`, no `fetchgit`, no
`patchPhase`), and the `nix run .#drawterm` app wraps it (linux-only;
darwin is the documented-manual venue below).

### The flag table

| Flag | Meaning |
|------|---------|
| `-O cpu=<host>,auth=<addr>,user=<name>` | **The pinned-connection form** (the OQ-2 settlement): comma-separated `key=value` with exactly the three keys `cpu`, `auth`, `user`, all required, none empty. `auth` may carry its service — the 3-part `tcp!host!port` form passes through `netmkaddr` verbatim. **With `-O`, argv is the single source of connection parameters: the `$cpu`/`$auth`/`$USER` environment reads never execute** (T-19-12). A spec with an unknown key, an empty value, or a missing key is a usage error naming the accepted keys — validated before any gui init, so the message is reachable headless. |
| `-G` | **No-window stdio session** (D-04): connect, authenticate, mount — and the session's stdio rides the invoking terminal. No window, no X display (works with `DISPLAY` unset; `#m`/`#i` are never bound). drawterm puts its own tty into raw mode (output post-processing kept, `ISIG` off so `^C` is a byte for the remote side) and restores it on every exit path; the remote's exit ends the local process with the status propagated. The windowed path is untouched. |
| `-e` | Encryption/hash algorithms. **The default is `rc4_256 sha1` (encrypted)** — devssl `#D` via `pushssl`, D-15: ordinary sessions are encrypted by construction. `-e clear` clears encryption and is the **DEBUG fallback only** — it never appears in any wrapper-printed line or committed recipe. |
| `-a <authserver>` / `-c <cpusererver>` | The legacy per-argument connection flags (no-`-O` path only — with `-O` the env reads AND these lose to the spec). |
| `-u <user>` | Username (no-`-O` path; `-O user=` otherwise). |
| `-s <secstore>` | Secstore server (default: the auth server). |
| `-k <keyspec>`, `-r <root>`, `-C <cmd…>`, `-d` | Existing vendor flags: factotum keyspec, devroot base, remote command form, debug. |

The `-O`/`-G` surface is pinned by `sys/src/cmd/unix/drawterm/flagtest.sh`
(TAP; green on both the gui-x11 and gui-none builds).

### The wrapper (`nix run .#drawterm`) — TESTED on the primary host (headless leg)

`nix/drawterm-x64.sh` scrubs `$cpu`/`$auth`/`$PASS`/`$USER` before
anything (the connection-hijack surface, Pitfall 3), accepts **no
arguments**, pins the seam-derived spec
(`cpu=127.0.0.1,auth=tcp!127.0.0.1!5670,user=glenda` — the Phase-16
D-04 hostfwd pair's loopback side, host 17010→guest 17010 and host
5670→guest 567; the 18-05 literal-idiom form), prints the exact
connect lines (windowed primary + the `-G` text form; **no `-e` flag
anywhere**), and execs the package binary. With `DISPLAY` set it runs
the windowed line; headless it runs the `-G` stdio line **loudly**
(`DISPLAY unset — headless venue: …`, never a silent downgrade).
Observed live: the no-guest dial refusal (`cpu: can't dial:
127.0.0.1: Connection refused`, exit 1) and the hostile-env scrub
(`cpu=evil auth=evil USER=evil` never reach the dial).

### The linux session recipe (D-07)

Two terminals, zero extra machinery:

1. **Boot the guest** — `nix run .#boot-r9-x64` (default slirp) in
   one terminal; leave it running. The hostfwd pair is listening on
   `127.0.0.1:17010` (cpu) and `127.0.0.1:5670` (auth) once the guest
   brings the listeners up.
2. **Connect** — `nix run .#drawterm` in the other terminal. With a
   display you get the rio-capable windowed session; headless you get
   the `-G` stdio session. In an interactive bash shell, quote the
   spec when typing it by hand (the `!` in the auth address is a
   history-expansion character): `drawterm -G -O 'cpu=127.0.0.1,auth=tcp!127.0.0.1!5670,user=glenda'`.
3. **Log in** — the password prompt is drawterm's own console
   (`readcons`; no echo). Phase 18's baked users apply (18-D-12).
4. **Teardown** — exit the remote shell: the session ends and
   drawterm exits (`goodbye`, status propagated). Then `ctrl-a x` the
   qemu terminal.

Venue honesty: the pieces proven on the primary host are the builds,
the wrapper's scrub/pin/print/dial, and the flag surface; the full
interactive login→shell-marker loop over hostfwd is 19-08's `-G`
interop gate (green-twice on local KVM per D-14).

### The darwin page — DOCUMENTED-MANUAL, `-G` only (amended D-03, D-05/D-06)

The darwin graphical leg is **deferred** by owner decision
2026-11-14: this phase ships no darwin window backend, and XQuartz
was considered and **rejected** (an X11-on-mac dependency for a
Plan 9 client is a compatibility layer too far; the native window
path belongs to a future milestone porting a 64-bit Cocoa/AppKit
backend of the 9front `gui-cocoa` class into the vendor — that is
the recorded reopener). Until then darwin's drawterm is the same
vendored source built with the **gui-none backend** (`-G` only —
no Carbon, no XQuartz, nothing graphical):

```
git clone <harvey> && cd harvey/sys/src/cmd/unix/drawterm
make CONF=osx GUI=none
```

The connection rides an SSH tunnel to the linux-hosted guest over
the existing loopback-bound hostfwd pair — zero new network surface
(D-05):

```
ssh -L 17010:127.0.0.1:17010 -L 5670:127.0.0.1:5670 user@linuxhost
```

then, on the mac against its own forwarded loopback:

```
./drawterm -G -O 'cpu=127.0.0.1,auth=tcp!127.0.0.1!5670,user=glenda'
```

Not executed by construction this phase (no darwin runner — the same
venue label as the net-modes darwin page). A recipe that was never
run is not evidence; the DESK-07 darwin acceptance row requires a
real run on the machine.

### The `-G` gate note

`-G` is deliberately the CI-able shape: scripted login → shell marker
over the hostfwd pair on a pty, green-twice on local KVM — that gate
is **19-08's** (`boot-r9` interop compose; D-12's credentials file,
D-14's venue verdict). This page's `-G` material is the client-side
surface that gate drives.

## The full-system boot (Phase 19: INT-05, the OQ-4 settlement)

The ONE command now means the whole system. `--system` selects what
`nix run .#boot-r9-x64` boots:

```
nix run .#boot-r9-x64 -- --system=cpu     # the FULL system: net + auth + cpu listener
nix run .#boot-r9-x64                     # --system=terminal, the default (the chain shell)
R9_SYSTEM=cpu nix run .#boot-r9-x64       # env sets the default (the R9_NET precedent)
```

| Mode | Image | ISO compose | What comes up |
|------|-------|-------------|---------------|
| `--system=cpu` | §15's `bootfs-cpu.paq` (the seventh contract: chain tree + the 18 auth suite + `cmd/cpu` + `aux/listen` + the real `#!` cpurc + the tcp17010 service file + the font payload + §15's own bake-time p9sk1 domain) | WITH the bootconf append `init=/amd64/init -c` (the 19-01 iso-builder seam — the `service=cpu` identity arrives through the boot protocol, never file content) | cpurc's fail-loud ladder in order: the pairing check, the ether leg (`cpurc: ETHER-OK` — the hostfwd reception seam), keyfs, the authsrv listener (guest tcp/567, host-side `127.0.0.1:5670`), factotum, and the cpu listener (`cpurc: LISTEN-17010` — host-side `127.0.0.1:17010`) |
| `--system=terminal` (default; also the no-flag behavior) | the chain paq | no append — byte-identical to the pre-19-09 compose | the interactive rc shell (every existing gate rides this path untouched) |

- **The cpu mode also runs the tier build** (`subset-build.sh`) before
  the bake — §15's named input producer — so the full system is
  genuinely one command off a clean checkout, not one command plus a
  prerequisite.
- **D-07's session recipe starts here:** once `cpurc: LISTEN-17010`
  prints, `nix run .#drawterm` (or its `-G` line) connects through the
  committed hostfwd pair; the boot banner names the venue
  (`system: cpu` + the full-system line) so a human terminal always
  shows which system is up.
- **Fail-loud rules (the `--net` discipline verbatim):** the `=` form
  only (`--system cpu` is a usage error); a duplicate `--system` is an
  error; an unknown mode is a usage error naming exactly
  `terminal|cpu` — no silent downgrade, no fall-through to a default
  venue.
- **The frozen aarch64 app is untouched:** the full-system mode lives
  on `boot-r9-x64` only; `nix/boot-r9.sh` (aarch64, frozen at the
  v2.0 pin) has no `--system` surface and gains none.

### The full-chain smoke leg (the standing gate)

`nix run .#boot-r9-smoke-x64` now asserts the whole bring-up in ONE
composed gate — green twice consecutively, per the standing
discipline. The existing chain leg (boot → echo round-trip → the
ls/ps/cat sweep → DEL safety → init restart → the post-passes) is
untouched; the gate ADDS a second boot in the same run: the §15 image
under the emitter's slirp argv (the D-04 hostfwd pair as pinned TOML
data), asserting the bootconf seed line
(`devenv: bootconf init=/amd64/init -c`), the host-side loopback
hostfwd observation (`127.0.0.1:17010` + `127.0.0.1:5670` in the host
listening table), the cpurc ladder in emission order through
`cpurc: LISTEN-17010` and `cpurc: DONE`, zero `cpurc: FAIL`, and the
desktop-absent-at-boot proof (zero `latin1.8.font` markers — DESK-02's
backstop living in the standing gate). Presence-only, timing-tolerant,
expect_before fast-fail on the panic + FAIL vocabularies.

**Scope boundary (one gate, one concern):** the smoke leg proves
BRING-UP — the listeners standing — not an interactive session. The
scripted login → shell-marker round-trip is 19-08's `-G` interop gate
(`nix run .#drawterm-gate-x64`); the two gates compose, neither
subsumes the other. The desktop itself is proven only in-session (the
draw-guarded profile; the font-line marker count proves the NEGATIVE
at boot).

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

The composed-system net gates live Harvey-side (the 14-D-06 split):
`nix run .#boot-r9-net-smoke-x64` (slirp venue, fixed — the hosted-CI
net leg) and `R9_NET=tap nix run .#boot-r9-net-soak-x64` (the
NETIP-08 verdict gate, primary host only). Their contracts are in the
scripts table above; the phase's evidence index is
`.planning/phases/16-host-net-modes-networking-exit-gate/16-EVIDENCE.md`.
