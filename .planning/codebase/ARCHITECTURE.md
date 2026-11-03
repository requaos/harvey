---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
<!-- refreshed: 2026-11-03 -->

# Architecture

**Analysis Date:** 2026-11-03

## System Overview

Harvey OS is a distributed operating system forked from Plan 9 4th Edition (Bell Labs). It implements the Plan 9 architectural model: **everything is a file**, per-process namespaces, and the 9P (9P2000) file protocol as the universal interface between components. The codebase contains two parallel kernel trees (legacy `9/` and Harvey's `9k/`), a full userland (~266 commands), ~40 libraries, and per-architecture ports.

```text
┌─────────────────────────────────────────────────────────────────────┐
│                        Userland (Commands & Apps)                   │
├──────────────┬──────────────┬──────────────┬────────────────────────┤
│  Core cmds   │  File servers│  GUI/apps    │  rc shell scripts      │
│ `sys/src/cmd`│ `sys/src/cmd`│ `sys/src/cmd`│  `rc/bin`              │
│  (srv, auth, │  (fossil,    │  (acme, rio, │  `usr/glenda/bin/rc`   │
│   ip, ndb…)  │   venti,     │   sam, mothra│                        │
│              │   webfs…)    │   via draw)  │                        │
└──────┬───────┴──────┬───────┴──────┬───────┴──────────┬─────────────┘
       │              │              │                  │
       ▼              ▼              ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        User-space Libraries                          │
│  `libc` (port+arch asm) `lib9p` `libthread` `libdraw`/`libmemdraw`   │
│  `libbio` `libsec` `libauth` `libmp` `libventi` `libndb` … (~40)     │
│  `sys/src/lib*/`         headers: `sys/include/*.h`                  │
│  POSIX compat layer (APE): `sys/src/ape/`                            │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │ system calls (sys.h vectors,
                                  │ amd64: `l64syscall.s`)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            Kernel (`sys/src/9k`)                     │
├──────────────────────────────┬──────────────────────────────────────┤
│  Portable kernel (`port/`)   │  Machine-specific (`k10/`, `386/`)   │
│  proc, chan, dev, qio, page, │  mmu, trap, fpu, apic, asm entry,    │
│  segment, sysfile, sysproc,  │  vga/ether/uart drivers, `main.c`    │
│  devmnt (9P client), dev*.c  │                                      │
└──────────────────────────────┴──────────────────┬───────────────────┘
                                                  │
                                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Boot chain & hardware                            │
│  EFI/PXE bootloaders: `sys/src/boot/efi`, `sys/src/nboot`,           │
│  `sys/src/9k/boot` (user-mode bootstrap: root fs, auth, bootip)      │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  External 9P services (network): cpu servers, auth servers,          │
│  file servers (fossil/venti), all reached over 9P2000                │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Portable kernel | Processes, channels, devices, memory, syscall dispatch | `sys/src/9k/port/` |
| k10 (amd64) machine layer | MMU, traps, FPU, APIC/IOAPIC, SMP boot, asm entry | `sys/src/9k/k10/` |
| 386 machine layer | 32-bit x86 drivers (ether, uart, sdata/AHCI, pci, vesa) | `sys/src/9k/386/` |
| Device drivers (kernel) | Each `devX.c` implements the `Dev` vtable, appears as `/dev` subtree | `sys/src/9k/port/dev*.c` |
| Kernel build config | Declarative kernel configs → generated `devtab` + embedded root | `sys/src/9k/k10/k10cpu`, `sys/src/9k/mk/parse` |
| Syscall interface | Syscall numbers/stubs shared kernel↔libc | `sys/src/libc/9syscall/sys.h` |
| libc | C library: portable (`port/`), syscalls (`9sys/`), per-arch asm (`amd64/`, `386/`, …) | `sys/src/libc/` |
| lib9p | User-space 9P file server framework (Srv, File, Req, Fid) | `sys/src/lib9p/` |
| libthread | Cooperative threads + channels (Plan 9 thread model) | `sys/src/libthread/` |
| Bootloaders | EFI loader, ISO walker, PXE | `sys/src/boot/efi/`, `sys/src/nboot/` |
| boot (user bootstrap) | First user program: authenticates, mounts root, starts init | `sys/src/9k/boot/boot.c` |
| Commands | ~266 user commands/daemons/file servers | `sys/src/cmd/` |
| APE | ANSI/POSIX Environment (ports of Unix software) | `sys/src/ape/` |
| Legacy kernel | Original Plan 9 kernel tree (multi-arch: pc, bcm, omap, teg2…) | `sys/src/9/` |
| Host build harness | Builds Harvey ISO by booting Plan 9 under QEMU; also hosts the aarch64 r9-boot supply chain (userland build → paqfs bake → DTB patch → qemu/expect) | `build/` (`build/aarch64/`) |
| aarch64 port tree | Per-arch install root + frozen user-side syscall ABI contract for the Harvey↔r9 kernel pairing | `aarch64/` (`ABI.md`, `include/u.h`, `include/ureg.h`, `mkfile`) |
| Nix dev environment | Reproducible host toolchain: devshell + `setup`/`toolchain`/`build`/`iso`/`boot-r9`/`boot-r9-smoke` apps; owns the Harvey↔r9 composition via the pinned `inputs.r9` flake input; lima VM path on darwin | `flake.nix`, `flake.lock`, `nix/` |
| Agent instructions | Repo-facing agent/project contract (project, stack, conventions, GSD workflow) | `AGENTS.md` |

## Pattern Overview

**Overall:** Microkernel-flavored monolithic kernel + user-space file servers, unified by the 9P protocol ("everything is a file"), with per-process namespaces.

**Key Characteristics:**
- **File-oriented IPC:** All resources (network, windows, processes, auth, graphics) are presented as files served over 9P2000 (`sys/include/fcall.h`, `sys/include/9p.h`). User programs `bind`/`mount` these into their private namespace.
- **Per-process namespaces:** Each process group has its own mount table (`sys/src/9k/port/pgrp.c`, `sys/src/9k/port/chan.c`). There is no single global file tree — the view of the system is constructed per-process via `bind(2)`/`mount(2)`.
- **Device = vtable:** Kernel devices implement the `Dev` struct interface (reset/init/attach/walk/stat/open/read/write/close…) declared in `sys/src/9k/port/portdat.h` (~line 198). The `devtab[]` array is *generated* from declarative kernel config files.
- **Kernel split:** portable vs. machine-dependent. All portable logic lives in `port/`; arch code lives in a sibling dir (`k10/`, `386/`). The mk build merges them via `../mk/portmkfile` + `../mk/bootmkfile` + an awk `parse` of the config file.
- **User-space file servers:** Services that would be kernel subsystems elsewhere (DNS, auth, ftp, http, web, wiki) run as user processes using `lib9p` and are mounted over 9P. The kernel's `devmnt.c` is the 9P *client* that glues mounts into the namespace.
- **rfork process model:** Process creation is `rfork(flags)` with fine-grained sharing flags (RFPROC, RFNAMEG, RFENVG, RFNOTEG…), not fork/exec. Threads via `libthread` build on this.
- **Note-based async:** Instead of Unix signals, Plan 9 uses textual "notes" posted to a process (`atnotify`, `noted` in libc; `sys/src/9k/port/proc.c`).

## Layers

**Kernel portable layer (`sys/src/9k/port/`):**
- Purpose: Architecture-independent OS services — processes, channels (name resolution), device dispatch, queues, paging/segments, syscall handlers, portable device drivers (console, env, pipe, proc, mnt, srv, ssl/tls, root fs, sd storage, uart core, draw/mouse).
- Location: `sys/src/9k/port/` (62 `.c` files)
- Contains: `proc.c` (scheduler), `chan.c` (name channeling / namespace resolution), `dev.c` (dev dispatch), `qio.c` (queued I/O), `page.c`/`segment.c` (VM), `sysfile.c` (file syscalls: sysopen, sysbind, sysmount, sysnmount…), `sysproc.c` (process syscalls), `qlock.c`/`taslock.c` (locking), `qmalloc.c` (kernel alloc), `devmnt.c` (9P mount client), `devroot.c` (embedded boot root fs), `edf.c` (earliest-deadline-first scheduler), `portdat.h`/`portfns.h` (portable kernel data/prototypes).
- Depends on: machine layer (`k10/`) for MMU, traps, clock, FPU.
- Used by: linked into every kernel config (see `OBJ=$MACH $CONF.root.$O $DEVS $PORT` in `sys/src/9k/k10/mkfile:15`).

**Machine layer (`sys/src/9k/k10/`, `sys/src/9k/386/`):**
- Purpose: Everything hardware-specific for a CPU family/board.
- Location: `sys/src/9k/k10/` (amd64; 55 files), `sys/src/9k/386/` (i386 drivers)
- Contains: `main.c` (kernel entry `main(u32int ax, u32int bx)` at line 145 — multiboot), `mmu.c`, `trap.c`, `fpu.c`, `apic.c`/`ioapic.c`, `mp.c`/`sipi.c` (SMP startup), `memory.c`, assembly entry/interrupt/syscall stubs (`l64v.s`, `l64idt.s`, `l64syscall.s`, `l64sipi.s`, `l32p.s`), `arch.c`, drivers (`devvga.c`, `devacpi.c`, `i8254.c`, `i8259.c`, `hpet.c`), and kernel config files (`k10cpu`, `k10cpuf`, `k10aoe`, `k10root`).
- Depends on: `port/` APIs; libc subset in kernel (`port/lib.h`).
- Used by: linked with `port/` objects per config.

**Kernel build machinery (`sys/src/9k/mk/`):**
- Purpose: Generates per-config kernel sources: `parse` (awk) reads a config file (`k10cpu`) and emits `$CONF.c` (devtab + linktab + root fs table), `bootmkfile`/`portmkfile` supply mk rules, `mkroot`/`mkrootall` build the embedded boot root image.
- Location: `sys/src/9k/mk/`
- Consumed by: `sys/src/9k/k10/mkfile` (`<| awk -f ../mk/parse $CONF` at line 11).

**User C library (`sys/src/libc/`):**
- Purpose: The single C library for all native programs.
- Structure: `port/` (112 portable `.c` files: string, fmt/printf, math, dir ops, regexp glue, pool allocators), `9sys/` (syscall wrappers: `open.c`, `mount.c`, `bind.c`, `dial.c`, `convM2S.c`/`convS2M.c` for 9P messages), `9syscall/sys.h` (syscall number table — BIND=2, MOUNT=46, NMOUNT added by Harvey), `fmt/` (printf family), per-arch dirs (`amd64/`, `386/`, `arm/`, `riscv/`, …) with assembly implementations (`memcpy.s`, `setjmp.s`, `tas.s`, `main9.s` startup).
- Headers: `sys/include/libc.h` plus per-arch `u.h` (`amd64/include/u.h`, `386/include/u.h`) and `ureg.h`.

**User-space services & commands (`sys/src/cmd/`):**
- Purpose: All userland — from `cat.c`/`cp.c` to subsystems: `ip/` (TCP/IP stack daemons), `auth/` (authentication server + factotum), `ndb/` (network database), `fossil`/`venti` (archival file servers), `acme/` (editor/window system), `rio` (window manager), `sam`, `webfs`, `wikifs`, `upas/` (mail), `aux/`, compilers/assemblers/linkers per arch (`8c/8a/8l` = amd64 compiler/asm/linker, `5c` = arm, `6c` family…), `go/` (Go toolchain fetch scripts), `mk` (build tool), `rc` (shell).
- Depends on: libc + specialized libs (`lib9p`, `libthread`, `libdraw`, `libmemdraw`, `libbio`, `libsec`, `libmp`, `libauth`, `libndb`…).

**APE — ANSI/POSIX Environment (`sys/src/ape/`):**
- Purpose: POSIX compatibility layer for ported Unix software (its own libc, headers, and commands like diff/patch/sh).
- Contains: `lib/` (ape libc), `cmd/` (ported GNU/BSD tools), `9src/` (X11R5 etc.), `config/`.
- Note: APE programs are second-class citizens; native code uses Plan 9 APIs directly.

**Boot chain:**
- `sys/src/boot/efi/` — EFI application: walks ISO/FAT filesystems, loads kernel + `plan9.ini` from ESP, sets up framebuffer, jumps to kernel entry. `iso.c` contains the ISO9660 walker (`isowalk`).
- `sys/src/nboot/` — newer boot loader tree (efi, pc).
- `sys/src/9k/boot/` — the `boot` user program embedded in/loaded with the kernel: performs authentication (`bootauth.c`, `doauthenticate.c`), finds the root (`local.c`, `bootip.c`), then execs init.

**Host tooling layer (Nix):**
- Purpose: Reproducible host environment on darwin-aarch64, linux-aarch64, linux/x86_64 — replaces manual plan9port/qemu/expect installation; also owns the Harvey↔r9 composition.
- Location: `flake.nix` (two inputs: `nixpkgs/nixos-unstable` and `r9 = github:requaos/r9`, both pinned in `flake.lock` — r9 at rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`, narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`; the lock also captures r9's transitive nixpkgs/rust-overlay nodes), scripts in `nix/`.
- Structure: `flake.nix` exposes six `apps` built with `writeShellApplication` (`mkScriptApp`), each wrapping a `nix/*.sh` script with a controlled `PATH` and `PLAN9` export: `setup` (`nix/setup.sh` — populates per-host `$HARVEY/.build/hostbin-<os>-<arch>/bin` with bootstrap `pcc`/host tools), `toolchain` (`nix/toolchain.sh` — builds the Plan 9 cross compilers 6a/6c/6l, 8a/8c/8l + vendored 9cc), `build` (`nix/build.sh` on Linux — full kernel build in a private mount namespace via `unshare`; `nix/vm-build.sh` on darwin — rsyncs the checkout into a lima VM (`nix/lima-harvey.yaml`, Ubuntu 24.04) because the namespace build needs Linux bind mounts and virtiofs subdir mounts silently yield empty trees), `iso` (`nix/iso.sh` — the legacy qemu+expect `build/build.bash` path), and the r9 composition pair `boot-r9` (`nix/boot-r9.sh` — build the aarch64 userland → bake `bootfs.paq` → fdtput-patch the r9 DTB → qemu to the interactive `%` prompt) and `boot-r9-smoke` (`nix/smoke-r9.sh` — the same pipeline launched under `build/aarch64/smoke-r9.expect`, exiting 0/1 for CI). Both r9 apps export `R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"` and are gated by `optionalAttrs (builtins.hasAttr system r9.packages)` so evaluation stays lazy where r9 ships no `kernel-virt` (x86_64-darwin).
- Key invariants enforced by the wrappers: `$PLAN9/bin` is appended LAST on `PATH` (per `BUILD_ON_UNIX` — plan9port ships a 9p `mount` that must not shadow util-linux `mount`); `HARVEY_LINUX_BIN` is per-OS/arch so a checkout shared with the lima guest never clobbers host binaries; shims strip `-static` from `9l` (modern Apple ld and nix glibc can't link static) and shadow Harvey's ken-format `nm` during host-ELF autolib; the r9 kernel/DTB arrive ONLY as nix store paths from the flake input (T-05-21 — never a sibling-checkout path, INT-04).
- Also provides: `devShells.default` (plan9port, qemu, expect, gnused…; exports `HARVEY`, `PLAN9`, `HARVEY_LINUX_BIN`, `objtype=amd64`, `FORCERCFORMK=1`) and, Linux-only, a `minimega` package (`nix/minimega.nix`, v3.3.0 via `buildGoModule`) for KVM test-VM orchestration — amd64 guests only, no upstream aarch64 guest support.

**aarch64 r9-boot supply chain (`build/aarch64/`):**
- Purpose: Host-side harness that produces, launches, and asserts the Harvey-aarch64-userland-on-r9-kernel boot: builds the userland subset in a Plan 9 mount namespace, bakes the paqfs root image with Harvey's own mkpaqfs, fdtput-patches the r9 DTB, and drives qemu (interactive or expect-asserted). Also retains the 9front donor-kernel bridge harness (proving the vendored 7a/7c/7l toolchain + frozen ABI against a reference kernel) and the 05-03 syscall trace rig.
- Location: `build/aarch64/` (full file inventory in STRUCTURE.md → Directory Purposes).
- Producers: `subset-build.sh` (the ONE userland build driver on both hosts — darwin: lima guest namespace via `vm-run.sh`/`nsrun.sh`; linux: the same generated guest script natively under `sudo unshare -m`; builds 13 libs + 16 commands + the boot chain `boot`/`init`/`paqfs`/`stacksmoke`, harvests to gitignored `aarch64/bin/` + `build/aarch64/out/`, R_MAGIC `0x8C47`-verified), `stage-build.sh` (the phase-04 staged-init supply chain — compiles `init.c`/`smokefork.c`/`smokenote.c`/`stacksmoke.c` for r9's own `cargo xtask initrd` bake; owns `out/` wholesale, "last writer wins"), `mkimage.sh` (stages the committed `root-tree/` skeleton + binaries + verbatim `rc/lib/rcmain`/`adm/timezone/local`, asserts the manifest including the D-02 `/boot/factotum` absence, bakes `bootfs.paq` via the host mkpaqfs from `mkpaqfs-host.sh`, verifies paqfs magics `529ab12b`/`6b46e688`).
- Launchers: `run-r9.sh` (unpackaged dev launcher; `R9_KERNEL`/`R9_DTB` required env — no implicit sibling-checkout defaults; locked qemu argv `-M virt,gic-version=2 -cpu cortex-a72 -smp 1 -m 1024M -accel tcg`, initrd via `-device loader,addr=0x48000000`) and the flake apps `nix/boot-r9.sh`/`nix/smoke-r9.sh` (the packaged compose/smoke; kernel+DTB arrive only as the r9 flake input's store paths).
- Drivers: `drive-r9.expect` (05-08 interactive gate — spawns `run-r9.sh`), `smoke-r9.expect` (05-12 packaged smoke — spawns qemu directly): staged presence-only marker assertions (banner → `paqfs...` → `stacksmoke: depth 64 ok` → `% ` prompt → echo round-trip → `ls`/`ps`/`cat` sweep → DEL safety → init restart), CRLF-tolerant, 600s TCG-sized per stage, qemu process-group kill on every exit path.

## Data Flow

### Primary Request Path (file open → device)

1. User calls `open("/net/tcp/clone", ORDWR)` — libc wrapper `sys/src/libc/9sys/open.c`, issuing syscall vector `OPEN` (14) via amd64 `syscall` instruction (`sys/src/9k/k10/l64syscall.s`).
2. Kernel trap/syscall entry → `sys/src/9k/k10/syscall.c` → dispatch table (from `sys/src/libc/9syscall/sys.h`) → `sysopen()` in `sys/src/9k/port/sysfile.c:286`.
3. Name resolution: `namec()` in `sys/src/9k/port/chan.c` walks the per-process namespace (union/mount table in `pgrp.c`), crossing mount points into `devmnt` for 9P-mounted services or into a kernel device via `devtab[]`.
4. Device dispatch: `dev.c` looks up the device by rune (e.g., `'|'` pipe, `'d'` cons, `'I'` ip) in `devtab[]` (generated into `$CONF.c`), calls the `Dev` vtable's `open/read/write` (`portdat.h:198`).
5. For networked file servers: `devmnt.c` formats 9P `Topen`/`Tread` messages (`sys/include/fcall.h`), sends them over the mounted channel to the user-space server process (e.g., `webfs`, `fossil`), which replies via `lib9p`'s request loop (`sys/src/lib9p/srv.c`, `req.c`).

### Boot Flow (amd64)

1. Firmware → EFI loader `sys/src/boot/efi/efi.c` → reads `plan9.ini`, loads kernel image `9k10cpu` at physical 0x110000 (link address `-T0xfffffffff0110000`, see `k10/mkfile:21-22`).
2. Assembly entry (`l32p.s` → protected mode → `l64v.s` long mode) → C entry `main(u32int ax, u32int bx)` in `sys/src/9k/k10/main.c:145`.
3. `main()` initializes: console, memory map (`memory.c`), MMU (`mmu.c`), traps (`trap.c`, `l64idt.s`), APIC/IOAPIC, SMP application processors (`sipi.c`), then calls portable init: `procinit0`, `devtabreset`/`devtabinit` (`port/devtab.c`), timers, and finally `init0` which starts the first user process.
4. First user process runs `boot` (`sys/src/9k/boot/boot.c`) from the embedded root (`devroot.c`, built by `sys/src/9k/mk/mkrootall`), which authenticates to the network, mounts the real root file system, and execs the init script (`/rc/bin/rc` with `rcmain` — see `sys/src/9k/root/rcmain`).
5. `rcmain` → `cpurc`/`termrc` (`rc/bin/`) → starts namespace, `factotum`, network services, and on terminals: `rio` + `acme` (`usr/glenda/bin/rc/riostart`).

### Network Path (TCP/IP)

1. `sys/src/9k/port/netif.c` + machine ethernet drivers (`k10/ether*.c` in `386/` dir, e.g., `ether82563.c`) implement the medium; `devether.c` binds NICs.
2. IP stack lives in kernel `sys/src/9k/ip/` (tcp.c, udp.c, ipifc.c, iproute.c, arp.c, icmp.c, ipv6.c…) exposed as `/net` files.
3. User-space daemons in `sys/src/cmd/ip/` (dhcpd, tftpd, snoopy, 6in4, ppp…) manipulate `/net`; `libip` provides shared helpers.
4. DNS/connection services run as user file servers: `sys/src/cmd/ndb/dns.c`, `cs.c` mounted at `/net`.

### r9 Boot Pipeline (aarch64 compose — `nix run .#boot-r9[-smoke]`)

1. **Kernel/DTB arrive as store paths:** `flake.nix` exports `R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"` into `nix/boot-r9.sh` / `nix/smoke-r9.sh`; the scripts resolve `kernel-virt.elf` + `aarch64/lib/virt-gicv2.dtb` under that read-only store path (with a `find` fallback for layout drift). No sibling-checkout path exists anywhere in the composition (INT-04).
2. **KERNDATE derivation:** host-side `git log -1 --format=%ct` (override `KERNDATE=<epoch>`), exported into the build — the BUILD-04 pin; see `build/REPRODUCIBILITY.md`.
3. **Userland build:** `build/aarch64/subset-build.sh` — the one driver on both hosts: darwin rsyncs the checkout into the lima guest and runs the generated guest script under `nsrun.sh --wrap` (Plan 9 mount namespace via `sudo unshare -m`: `/sys`←checkout sys, `/aarch64`←checkout aarch64); linux runs the same guest script natively under `sudo unshare`. Builds libc + 12 libs (`libbio libregexp libip libndb libmp libsec libString libthread lib9p libauth libauthsrv libflate`) + 16 commands + the boot chain (`boot(8)` via `sys/src/9k/boot/mkfile.aarch64`, `init` via cmd's per-target install, `paqfs`, `stacksmoke`) with `objtype=aarch64`; harvests to `aarch64/bin/` and `build/aarch64/out/`, every boot-chain binary R_MAGIC-verified (`00 00 8c 47` BE). Skip hatch: `R9_SKIP_BUILD=1` (dev iteration only, never the gate).
4. **Image bake:** `build/aarch64/mkimage.sh` stages the committed `build/aarch64/root-tree/` skeleton (`lib/namespace`, `rc/bin/termrc`, `usr/glenda/lib/profile`) + empty mount-point dirs (`/root /env /proc /dev /srv /fd /bin /tmp /mnt`) + the built binaries + verbatim `rc/lib/rcmain` and `adm/timezone/local`; asserts the manifest (including `/boot/factotum` ABSENT — D-02 auth-stub-by-absence — and the real-init identity via rodata grep `"init: starting /bin/rc"`, guarding against `stage-build.sh`'s `out/` pollution), then bakes `build/aarch64/bootfs.paq` with the host mkpaqfs (`.build/bin/mkpaqfs`, built by `mkpaqfs-host.sh`) and verifies the paqfs header/trailer magics (`529ab12b` / `6b46e688`).
5. **DTB patch:** a writable throwaway copy of the package's `virt-gicv2.dtb` gets `/chosen linux,initrd-start`/`linux,initrd-end` written by `fdtput` as two 32-bit BE cells each, high word first (r9's `property_value_as_u64` reads one 8-byte BE cell; dtc has no 8-byte property type) — mirrors r9's `xtask/src/config.rs` `prepare_initrd_dtb` (lines 385-434).
6. **Launch:** locked qemu argv (values from r9's `aarch64/lib/config_virtexec.toml` `[qemu]`): `qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -smp 1 -m 1024M -accel tcg -kernel <r9 ELF> -dtb <patched copy> -device loader,file=<bootfs.paq>,addr=0x48000000 -nographic`. `boot-r9` runs qemu foreground on stdio (the terminal is the console; ctrl-a x quits); `build/aarch64/run-r9.sh` is the unpackaged equivalent (env contract: `R9_KERNEL`/`R9_DTB` required, no defaults; `--log FILE` gate mode).
7. **Smoke (boot-r9-smoke only):** `build/aarch64/smoke-r9.expect` spawns qemu itself, captures serial to a fresh-per-run log (`R9_SMOKE_LOG`, rm'd before launch — a stale capture is dead evidence), and drives the staged assertion sweep: banner `r9 from the Internet` → `paqfs...` → `stacksmoke: depth 64 ok` → `% ` prompt → `echo r9shell7` round-trip → `ls /bin` subset presence (`rc ls cat echo ps`) → `ps` live-process lines incl rc → `cat /lib/namespace` known line (`bind -c #e /env`) → DEL (0x7f) interrupt safety + `r9delok` re-prompt → `exit` → init's `for(;;)` restart to a fresh prompt. Exit 0 only when every stage passed; each stage names its failure on stderr; markers are PRESENCE assertions only, never interleaving order; qemu's process group is killed on every exit path. `build/aarch64/drive-r9.expect` is the interactive-gate predecessor (spawns `run-r9.sh` instead of qemu directly). CI: `.github/workflows/r9-shell.yml` runs the clean-checkout smoke on `ubuntu-latest`.

### Guest-side boot flow inside the image (what the smoke asserts)

1. r9 kernel starts → banner, mounts the paqfs initrd, execs `/boot/boot` (the aarch64 boot(8) from `sys/src/9k/boot/mkfile.aarch64` + hand-written `bootr9.c` bootconf).
2. `boot` runs the real chain: opencons → bindenvsrv → doauth (glenda path — `/boot/factotum` absent, D-02) → rfork(RFNAMEG) → connectembed (pipe + fork + exec `/boot/paqfs` — the `paqfs...` print) → fversion → mount `/root` → nsinit binds → execinit → `/aarch64/init`.
3. `init` (the real one, from cmd's `init.install`) runs `newns` against the image's scoped `/lib/namespace` — the re-mount pair `mount -a #s/boot /root` + `bind -a /root /` comes FIRST (newns's RFCNAMEG wipe clears boot's mount table) — then `rc/lib/rcmain` → `/rc/bin/termrc` (runs `stacksmoke` first, D-15, then `exec rc -i`) → the interactive `% ` prompt as user glenda.

**State Management:**
- Kernel global singletons exist and are deliberate: `Sys* sys` (system structure, `k10/main.c:17`), `conf` (config), per-CPU `Mach*` (`m` macro), device state in each `dev*.c`. `extern Mach *m;` per-CPU pointer is the threading model.
- User state: environment variables are files in `/env` (`devenv.c`); process control via `/proc` (`devproc.c`).

## Key Abstractions

**Chan (channel):**
- Purpose: The kernel's open-file handle — the result of name resolution; every operation on a file goes through a `Chan`.
- Examples: `sys/src/9k/port/chan.c` (`cclose` line 378, `addelem` line 287 — union directory resolution)
- Pattern: Ref-counted, linked to a `Dev` + qid path; mount points stitch Chan trees together (`Mount` struct in `pgrp.c`).

**Dev (device vtable):**
- Purpose: Uniform interface for kernel devices — the table-driven polymorphism at the heart of "everything is a file".
- Examples: `sys/src/9k/port/portdat.h:198` (struct Dev), drivers `devcons.c`, `devpipe.c`, `devmnt.c`, `devproc.c`, `devdraw.c`, `devtls.c`; registration list generated from kernel config (`sys/src/9k/k10/k10cpu` `dev` section) by `sys/src/9k/mk/parse`.
- Pattern: One C file per device named `dev<name>.c`; init order follows `devtab[]` (`port/devtab.c`).

**9P message codec (fcall):**
- Purpose: Wire format of 9P2000 — every file operation becomes T/R message pairs (Tversion, Tattach, Twalk, Topen, Tread…).
- Examples: `sys/include/fcall.h`, codec in `sys/src/libc/9sys/convM2S.c` + `convS2M.c`, server-side helpers in `sys/src/lib9p/`.

**Srv/File (lib9p):**
- Purpose: Framework for writing user-space file servers: define a `Srv` struct with attach/walk/read/write hooks and a `FileTree`, then `postmountsrv()` mounts it into the namespace.
- Examples: `sys/src/lib9p/srv.c`, `file.c`, `listen.c`, `post.c`; canonical trivial server `sys/src/lib9p/ramfs.c`; real servers: `sys/src/cmd/webfs/`, `sys/src/cmd/wikifs/`.

**Proc + rfork:**
- Purpose: Process abstraction with composable sharing.
- Examples: `sys/src/9k/port/proc.c`, `sysproc.c` (`sysrfork`), user wrappers `sys/src/libc/9sys/rfork.c` / `fork.c`.
- Pattern: `rfork(RFPROC|RFMEM|RFNAMEG|…)` selects what child shares; `libthread` layers coroutines + channels (`sys/src/libthread/channel.c`) on top.

**Segment/Page:**
- Purpose: Virtual memory — address spaces are lists of `Segment`s (text, data, bss, stack, mapped files) backed by `Image`s (demand-paged from files).
- Examples: `sys/src/9k/port/segment.c`, `page.c`, `image.c`, machine MMU in `k10/mmu.c`.

**Qid/Dir:**
- Purpose: Unique file identity (`Qid`: path+vers+type) and portable directory entry `Dir` — the 9P metadata currency.
- Examples: `sys/include/libc.h`, `sys/src/libc/9sys/convM2D.c`, `dirstat.c`.

## Entry Points

**Kernel (amd64/k10):**
- Location: `sys/src/9k/k10/main.c` — `main(u32int ax, u32int bx)` at line 145 (multiboot magic + params)
- Triggers: EFI loader (`sys/src/boot/efi/efi.c`) or multiboot/nboot chain; asm entry `l64v.s`/`l32p.s` sets up stack/long mode first.
- Responsibilities: Machine init → portable kernel init (`port/`) → spawn first user process (`boot`).

**User bootstrap (boot):**
- Location: `sys/src/9k/boot/boot.c` (`main`), helpers `bootauth.c`, `bootip.c`, `local.c`
- Triggers: Exec'd by kernel `init0` as pid 1 from embedded root.
- Responsibilities: Root filesystem selection (local/tcp), authentication handshake, then exec of system init.

**System init (rc):**
- Location: `sys/src/9k/root/rcmain` (embedded), `rc/bin/termrc`, `rc/bin/cpurc`
- Triggers: Exec'd by `boot`.
- Responsibilities: Build the default namespace (`/lib/namespace`), start services (`factotum`, network, `rio`/`acme` on terminals).

**Command programs:**
- Location: `sys/src/cmd/<name>.c` (single-file) or `sys/src/cmd/<name>/` (multi-file with mkfile).
- Convention: `void main(int argc, char *argv[])`, use `ARGBEGIN{...}ARGEND` macro for flags (Plan 9 style), exit via `exits("msg")`.

**Host build (from Linux/macOS):**
- Location: `build/build.bash` (QEMU + expect harness), `build/scripts/` (`build`, `repl`, `iso`, `main`, `funcs`), Docker path: `build/Dockerfile`, `build/BUILD_IN_DOCKER`.
- Triggers: `bash build.bash` from `build/`. Requires a host 9P server (`ufs`/`centre`) on port 5640 to receive the ISO (`build/README`).
- Native (on Plan 9/Harvey): `sys/src/BUILD` runs `mk libs && mk all`, then `build/scripts/linux-build`.

**Kernel build (per config):**
- Location: `sys/src/9k/k10/mkfile` — targets like `9k` build `9k10cpu` (mk var `p=9`, `CONF=k10cpu`).
- Triggers: `mk 9k` in `sys/src/9k/k10/`. Uses Plan 9 toolchain `8c/8a/8l` (`objtype=amd64`, line 5).

**Host build (Nix — current path):**
- Location: `flake.nix` apps → `nix/setup.sh`, `nix/toolchain.sh`, `nix/build.sh` (Linux), `nix/vm-build.sh` (darwin→lima), `nix/iso.sh`.
- Triggers: `nix run .#setup` → `nix run .#toolchain` → `nix run .#build` (or `.#iso` for the legacy qemu path); `nix develop` drops into the devshell.
- Responsibilities: Replaces manual plan9port/Docker setup; darwin builds rsync the checkout to a lima guest (guest-local disk — virtiofs bind-mount subtrees don't work) and rsync artifacts (`amd64/`, `386/`, `aarch64/`) back.

**r9 compose/smoke (aarch64 shell boot):**
- Location: `flake.nix` apps → `nix/boot-r9.sh` (interactive), `nix/smoke-r9.sh` (CI smoke → `build/aarch64/smoke-r9.expect`); unpackaged dev launcher `build/aarch64/run-r9.sh` (+ `drive-r9.expect` interactive gate).
- Triggers: `nix run .#boot-r9` (to the interactive `%` prompt), `nix run .#boot-r9-smoke` (self-asserting, exit 0/1 — the CI/clean-checkout proof); `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` for a local r9 checkout (D-13 dev flow, never the default).
- Responsibilities: Compose the pinned r9 flake-input kernel (`r9.packages.<system>.kernel-virt` store paths) with the Harvey aarch64 userland — build (`build/aarch64/subset-build.sh`) → bake (`mkimage.sh` → `bootfs.paq`) → fdtput DTB patch → qemu `virt,gic-version=2` TCG launch; the smoke variant drives the D-09 assertion sweep over the serial wire.

## Architectural Constraints

- **Threading:** Kernel is a single-stack-per-CPU cooperative/preemptive hybrid: processes are kernel coroutines scheduled by `proc.c`; per-CPU `Mach` state, `taslock.c` test-and-set spinlocks + `qlock.c` queueing locks; `Rendez` sleep/wakeup (`sleep`/`wakeup`). User space: `libthread` coroutines + channels, or raw `rfork(RFPROC)` procs. No pthreads in native code (APE has its own).
- **Global state:** Kernel singletons are idiomatic: `Sys *sys` (`k10/main.c:17`), `conf`, `devtab[]` (generated), per-device state structs at file scope in each `dev*.c`, `Mach *m` per-CPU. Do not add process-specific data to device globals — use `Chan`/`qid` private fields.
- **Toolchain:** Plan 9's own C compiler suite (`8c` amd64, `6c` 386…), NOT gcc/clang for native code. Dialect: Plan 9 C (no prototypes needed across files — `fns.h`/`portfns.h` collect them; `#pragma` variants; `void` returns default). Headers included as `u.h` → `libc.h` → `../port/lib.h` in kernel.
- **Build tool:** `mk` (not make). All builds via `mkfile` + includes (`</$objtype/mkfile`, `mkfile.proto`).
- **Cross-arch includes:** per-arch headers resolved via `/$objtype/include` (e.g., `amd64/include/u.h`, `ureg.h`) — code references them as absolute `/amd64/include/...` paths inside the Plan 9 namespace.
- **Circular imports:** Kernel `port/` ↔ machine dirs interdepend by design (`port/lib.h` included from machine code; machine provides `fns.h`/`dat.h`/`mem.h` consumed by port). The mk layer resolves ordering; do not add new reverse deps beyond the established header triad (`dat.h`/`fns.h`/`mem.h` per arch).
- **Two kernels coexist:** `sys/src/9/` (legacy, full multi-arch) vs `sys/src/9k/` (Harvey, amd64/386 focus). New work targets `9k`. Shared libs (libc etc.) serve both.
- **Two repos, one ABI:** the aarch64 user side runs on the **r9** Rust kernel, consumed as a pinned flake input (`inputs.r9 = github:requaos/r9`, rev+narHash in `flake.lock`; the compose apps see only `r9.packages.<system>.kernel-virt` store paths — never a sibling-checkout path, INT-04). The user↔kernel wire contract is frozen in-repo (`aarch64/ABI.md` + `aarch64/include/ureg.h`); see Cross-Cutting Concerns → Syscall ABI. Do not edit either file without re-freezing both repos. Dev flow against a local r9 checkout (D-13): `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` — dev-only, never the default, never what CI uses.
- **aarch64 toolchain letter is 7:** `aarch64/mkfile` sets `CC=7c LD=7l AS=7a O=7` (the 9front arm64 toolchain letters, adopted verbatim). Object files for aarch64 are `*.7`.
- **Host builds are Nix-mediated:** the supported host entry points are the `flake.nix` apps (`setup`→`toolchain`→`build`/`iso`), not raw `build/build.bash` or Docker. PATH ordering is contractual: `$HARVEY_LINUX_BIN` FIRST, `$PLAN9/bin` LAST. The kernel build requires Linux mount namespaces — on darwin it runs inside the lima VM defined by `nix/lima-harvey.yaml`.

## Anti-Patterns

### Mixing portable and machine code

**What happens:** A few machine-dependent hacks leak into portable files or vice versa (e.g., `main.c` still carries `extern void crapoptions(void); /* XXX - must go */` at `k10/main.c:11-12`).
**Why it's wrong:** Breaks the `port/` ↔ `k10/` split that makes the kernel portable; the mk `parse` machinery assumes clean layering.
**Do this instead:** Put new hardware logic in the machine dir (`k10/` or `386/`), expose it via `fns.h`, and call it from `port/` through that header. 19 `XXX`/`TODO` markers in `sys/src/9k/` flag known violations — check them before adding nearby code.

### Bypassing the namespace with hardcoded paths in C

**What happens:** C code opening absolute Unix-style paths assuming a global root.
**Why it's wrong:** Plan 9 has per-process namespaces; the "real" root depends on how the process's namespace was assembled (`bind`/`mount` order, `/lib/namespace`). Hardcoded assumptions break under `cpu`, `auth`, or chroot-like namespace games.
**Do this instead:** Open the conventional Plan 9 locations (`/net`, `/dev`, `/env`, `#c` device roots like `#|/data` for pipe) and let the user's namespace resolve them; use `bind`/`mount` (or `sysbind`/`sysmount` in kernel, `sys/src/9k/port/sysfile.c:1174/1192`) rather than renaming files.

### Using APE/POSIX APIs in native code

**What happens:** Including `ape` headers (`sys/include/ape/`, `amd64/include/ape/`) or linking the ape libc in a native program.
**Why it's wrong:** APE shadows Plan 9 semantics (fork vs rfork, signals vs notes, blocking I/O) and produces subtly broken native binaries.
**Do this instead:** Native code uses `libc.h` + Plan 9 idioms (`rfork`, `atnotify`, `thread` library, `dial()`/`announce()` for networking in `sys/src/libc/9sys/dial.c`/`announce.c`). APE is only for ported Unix programs under `sys/src/ape/cmd/`.

## Error Handling

**Strategy:** String-based errors via the errstr mechanism + longjmp-style `error()` unwinding in the kernel; `nil`-return or `-1` + errstr in user space.

**Patterns:**
- Kernel: `error("message")` raises (`port/error.h`, `sys/src/9k/port/proc.c` unwinds via `nexterror()`/`poperror()`); `waserror()` guards resource cleanup. `kerror` for kernel-originated failures.
- User: functions return -1/nil and set thread-local errstr; caller checks with `errstr(buf, n)` (`sys/src/libc/9sys/errstr.c`); `exits("diagnostic")` terminates with a status string consumed by `wait`/`await`.
- Notes: async conditions arrive as textual notes ("hangup", "alarm", "sys: trap: …"); programs install `atnotify()` handlers (`sys/src/libc/port/atnotify.c`).
- No errno. No exceptions. Assertions via `assert()` (`_assert.c`) or `panic()` in kernel for unrecoverable state.

## Cross-Cutting Concerns

**Logging:** No syslog daemon in the modern sense — services write to their console or to files under `sys/log/<service>/` (e.g., `sys/log/dns`, `sys/log/httpd`). Kernel: `print()`/`iprint()` to console + `devkprof`/trace facilities (`devtrace.c`). Command-line tools print diagnostics to stderr (fd 2) with program name prefix by convention.

**Validation:** Argument parsing via `ARGBEGIN`/`ARGEND` macros (`sys/include/libc.h`); path canonicalization via `cleanname()` (`sys/src/libc/port/cleanname.c`); user/kernel pointer checks via `validaddr`/`validname` family in the kernel syscall layer.

**Authentication:** Centralized in `factotum` (user-space key agent, `sys/src/cmd/auth/factotum/`) speaking 9P; kernel support via `devcap.c` (capability device) and `sysauth.c`; wire crypto in `libsec` (TLS in kernel `devtls.c` + user `libsec`), auth server code in `sys/src/cmd/auth/` + `libauthsrv`/`libauth`. Network identity via `ndb` (`sys/src/ndb`, `libndb`).

**Syscall ABI (aarch64 — FROZEN):** The Harvey↔r9 user-side syscall wire contract for `objtype=aarch64` is frozen (decisions D-15/D-16/D-17) and lives in two in-repo files that must change together — changing either after Phase 4 means re-freezing both this repo and `../r9`:
- `aarch64/ABI.md` — the canonical prose contract. Wire format: syscall number in register `R0`; arguments in 8-byte slots at user `SP+8` upward (`SP+0` is the reserved link-register slot; the stub's `MOV R0, 0(FP)` materializes arg0 into its stack slot, so the first kernel-visible argument is at `SP+8`); trap via `SVC`; result returned in `R0`. Kernel read side computes `(Sargs*)(ureg->sp+BY2WD)` with `BY2WD=8` (per 9front arm64 `trap.c:196`/`mem.h:92` at pin `350266104f1fed81c78c3d05fa44f523bec0ae4d`). Syscall table is Harvey's `sys/src/libc/9syscall/sys.h` 0–54 verbatim: 0–52 wire-identical to 9front arm64 (including `SYSR1=0` and the 48–49 gap), 53 `NSEC` is zero-arg register-return, 54 `NMOUNT` is Harvey-only (six-arg; r9 may leave it unimplemented until called). A Phase-4 appendix (kernel-side enforcement) pins r9's `TrapFrame` byte offsets against `ureg.h` (r0@0 … r28@224, r29@232, r30/link@240, sp@248, pc@256, psr@264, type@272; `sizeof(Ureg)`=280, r9 frame stride 288) and specifies the two-layer drift check: in-crate `core::mem::offset_of!` const asserts in r9's `aarch64/src/trap.rs` plus `cargo xtask ureg-check` (r9 repo) parsing this repo's `aarch64/include/ureg.h` — located via `R9_HARVEY_DIR`, default `../harvey` — failing every boot-test profile on drift.
- `aarch64/include/ureg.h` — the frozen trap frame, field-for-field: `r0`..`r28` (`r28` = `sb`), `r29`, `r30`/`link` union, `sp`, `pc` (interrupted address), `psr`, `type` (exception class). r9's Rust trap frame is checked against this at build time.
- User-side stubs are generated per syscall by the `case aarch64` block of `sys/src/libc/9syscall/mkfile` (`TEXT name(SB), 1, $0` / `MOV R0, 0(FP)` / `MOV $NN, R0` / `SVC` / `RETURN`; `seek`→`_seek` and `exits`→`_exits` quirks preserved).
- Explicitly **not** part of the contract (D-17): kernel-side dispatch style. Harvey 9k's `void sysxxx(Ar0*, va_list)` and 9front's `void sysxxx(Ar0)` are both internal; r9 matches only the wire contract above.
- Base types for the port are in `aarch64/include/u.h` (LP64: `long`=64-bit assumption avoided — `vlong`/`uvlong`, `uintptr`, `usize`, `jmp_buf[2]` with `JMPBUFSP`/`JMPBUFPC`, 8-byte-slot `va_list`).

---

*Architecture analysis: 2026-11-03*
