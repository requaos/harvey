---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
# Technology Stack

**Analysis Date:** 2026-11-03

## Project Identity

This is **Harvey OS** — a community fork / re-release of **Plan 9 from Bell Labs, 4th Edition** (originally Lucent, 2002). It is a complete operating system source tree: kernel, compilers, libraries, userspace commands, file servers, authentication services, and documentation. It is **not** a typical application — there is no `package.json`, no npm/cargo/go modules, and no conventional package manager. The build is driven by Plan 9's own `mk(1)` tool and a small set of bash/rc scripts.

This repo is the **maintained fork** (upstream dormant since 2022-03-30). The active project — described in `AGENTS.md` — is **build revival + aarch64 port**: modernizing the dev environment with Nix, porting userspace to aarch64, and adopting **r9** (a Rust `no_std` reimplementation of the Plan 9 kernel, built with cargo xtask) as Harvey's kernel, including adding/completing aarch64 support in r9 for qemu `-M virt`. r9 arrives as a **pinned Nix flake input** (`inputs.r9 = github:requaos/r9` in `flake.nix`, exact rev + narHash in `flake.lock`); a sibling checkout is used only via the dev override `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` (D-13, never the default). Core target — Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt, reproducible from clean checkouts on macOS or Linux — is met by `nix run .#boot-r9` / `nix run .#boot-r9-smoke` (see "Build System" and `build/REPRODUCIBILITY.md`).

See `README` for the project's own description, `AGENTS.md` for project constraints, and `BUILD_ON_UNIX` + `build/README` for legacy build entry points.

## Languages

**Primary:**
- **C (Plan 9 dialect)** — the overwhelming majority of the tree. Kernel (`sys/src/9/`, `sys/src/9k/`), all libraries (`sys/src/lib*/`), and nearly all userspace commands (`sys/src/cmd/`). Plan 9 C is pre-ANSI/ANSI C with Plan 9 extensions; it does **not** use POSIX headers. Sources include Plan 9 headers such as `<u.h>`, `<libc.h>`, `<9p.h>`, `<bio.h>` from `sys/include/`.
- **Rc shell** — Plan 9's shell. Used for system startup (`cfg/example/cpurc`, `cfg/example/termrc`), build scripts (`sys/src/cmd/go/fetchrepos.rc`, most `BUILD` files), and runtime services. The `rc/` directory at repo root holds rc libraries.

**Secondary:**
- **Assembly** — per-architecture kernel and runtime code (`*.s` files inside `sys/src/9/{pc,port,...}/`, `sys/src/9k/`, `sys/src/libc/{386,amd64,arm,...}/`). Assembled with the matching Plan 9 assembler (e.g. `6a` for amd64, `7a` for aarch64).
- **Yacc / Lex** — grammars in `sys/src/cmd/bc.y`, `sys/src/cmd/units.y`, `sys/src/cmd/upas/smtp/smtpd.y`, `sys/src/cmd/upas/smtp/rfc822.y`, `sys/src/cmd/cc/cc.y`. Generated via Plan 9 `yacc(1)` / `lex(1)`.
- **Bash / sh** — host-side build orchestration only: `build/build.bash`, `build/build-usb.bash`, `build/build-go.sh`, `build/BUILD_IN_DOCKER`, `sys/src/BUILD`, `sys/src/BUILDTOOLCHAIN`, `sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`, the Nix app scripts referenced by `flake.nix` (`./nix/iso.sh`, `./nix/setup.sh`, `./nix/toolchain.sh`, `./nix/build.sh`, `./nix/vm-build.sh`, `./nix/boot-r9.sh`, `./nix/smoke-r9.sh` — embedded via `builtins.readFile`), and the `build/aarch64/` r9 supply-chain drivers (`subset-build.sh`, `stage-build.sh`, `mkimage.sh`, `mkpaqfs-host.sh`, `run-r9.sh`). Not used at runtime on the target.
- **Expect (Tcl)** — host-side qemu/serial drivers in the `build/aarch64/` harness: `build/aarch64/drive-r9.expect` (interactive gate) and `build/aarch64/smoke-r9.expect` (packaged CI smoke, spawned by `./nix/smoke-r9.sh`). Legacy heredoc-expect precedent: `build/build.bash`.
- **Python 3** — host-side harness helpers only: `build/aarch64/trace-syscalls.py` (donor-kernel syscall tracer), `drive9.py` / `srv9.py` / `mkfs9.py` / `gdbpoke9.py` (9front donor boot/9P-server/proto-image/RSP-poke tooling). Never on the target.
- **Nix expression language** — host-side dev environment: `flake.nix` (devshell, apps, packages) and `./nix/minimega.nix`. Pinned by `flake.lock`.
- **Go** — *not* used to build Harvey itself. The tree pulls Go programs in at image-build time (see `sys/src/cmd/go/`) to ship them inside the Harvey ISO. See "Key Dependencies" below.
- **Rust (out-of-tree)** — the r9 kernel, consumed as the pinned flake input `github:requaos/r9` (`flake.lock` rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`); the apps use only its `packages.<system>.kernel-virt` store paths (`kernel-virt.elf` + `aarch64/lib/virt-gicv2.dtb`). r9's rust toolchain (`rust-toolchain.toml` channel `nightly-2026-01-30`, `rust-src` + `llvm-tools`) is honored via rust-overlay inside r9's own derivation — its `nixpkgs`/`rust-overlay` pins are captured transitively in this repo's `flake.lock` (`nixpkgs_2`, `rust-overlay` nodes). No Rust source lives in this repo.

## Runtime

**Target environment:** Bare metal or QEMU. Harvey boots on PC hardware (i386 / amd64) and several embedded/legacy architectures; the aarch64 port targets qemu `-M virt` under the r9 kernel. There is no userspace "runtime" in the Java/Python sense — the C library is statically linked into every binary.

**Host build environment (Nix — the modern entry point, `flake.nix`):**
- **Nix flake** (`flake.nix`, pinned by `flake.lock` → `github:NixOS/nixpkgs/nixos-unstable` rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010`, plus `github:requaos/r9` rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` and r9's transitive `nixpkgs_2`/`rust-overlay` pins) — supports `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, `x86_64-darwin`.
  - **Devshell** (`nix develop`): provides `plan9port git gnumake bashInteractive coreutils gnused findutils qemu expect curl bzip2 gnutar`; Linux adds `util-linux binutils minimega`; darwin adds `lima`.
  - **Apps** (`nix run .#<app>`): `setup` (`./nix/setup.sh`), `toolchain` (`./nix/toolchain.sh` — builds the vendored 9cc toolchain with host cc), `build` (`./nix/build.sh` on Linux via `sudo unshare`; `./nix/vm-build.sh` on darwin via a **lima** VM `./nix/lima-harvey.yaml`), `iso` (`./nix/iso.sh`), **`boot-r9`** (`./nix/boot-r9.sh` — interactive r9+Harvey aarch64 boot) and **`boot-r9-smoke`** (`./nix/smoke-r9.sh` — the same pipeline under `build/aarch64/smoke-r9.expect`, exits 0/1 for CI). The boot-r9 apps exist only where r9 ships `packages.kernel-virt` (aarch64-darwin, aarch64-linux, x86_64-linux — not x86_64-darwin; gated by `builtins.hasAttr system r9.packages` in `flake.nix`). Default app is `setup`.
  - **Packages**: `minimega` (Linux-only, `./nix/minimega.nix`) — VM orchestration for Harvey/r9 amd64 test VMs on KVM hosts; aarch64 guests not supported upstream.
  - All script apps export `PLAN9=${pkgs.plan9port}/plan9` and append `$PLAN9/bin` **LAST** in `PATH` (per `BUILD_ON_UNIX` — plan9port's 9p `mount` must not shadow util-linux `mount` in the namespace build). The darwin build app exports `LIMA_YAML`; the Linux build app exports `GNU_SED` (absolute path, because `$HARVEY_LINUX_BIN` shadows `sed` with plan9 sed which lacks `-i`).
- **plan9port** (`https://github.com/9fans/plan9port`) — provides `mk`, `rc`, `9c`/`pcc`, `sed`, `yacc`, `lex`, `awk` on the host. In the Nix flow it comes from nixpkgs; outside Nix it must be installed manually on `PATH` (`$PLAN9/bin`, typically `/usr/local/plan9`). Referenced by `BUILD_ON_UNIX` and `build/Dockerfile`.
- **QEMU** (`qemu-system-i386` for the legacy amd64 build harness; `qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -accel tcg` for the r9/aarch64 boot) — used by `build/build.bash`, `.github/workflows/harvey.yml`, `./nix/iso.sh`, `./nix/boot-r9.sh`, `./nix/smoke-r9.sh`, and `build/aarch64/run-r9.sh`. TCG-only on the aarch64 path (HVF rejected by probe evidence — see `build/aarch64/README.md` "TCG-only constraint").
- **dtc** (`fdtput`) — patches a throwaway copy of the r9 DTB with `/chosen linux,initrd-start`/`-end` before launch (`./nix/boot-r9.sh`, `./nix/smoke-r9.sh`, `build/aarch64/run-r9.sh`); supplied by nixpkgs.
- **lima** (darwin only) — runs the Linux mount-namespace build inside a VM on macOS (`./nix/vm-build.sh`, `./nix/lima-harvey.yaml`); the Harvey namespace build requires Linux mount namespaces.
- **Go toolchain** (host) — `go get harvey-os.org/cmd/ufs` is run in CI to install the `ufs` 9P file server, which serves the Harvey tree to the build VM.
- **Docker** (optional, legacy path) — `build/Dockerfile` builds an Ubuntu 21.10 image that pre-installs plan9port + the `9-cc` archiver.

**Package manager:** Nix (host dev environment only, via `flake.nix`). There is no target-side dependency resolution; the entire system source is vendored in-tree. Third-party tools needed at legacy build time (plan9port, 9-cc, Go repos) are fetched explicitly by scripts.

**Lockfile:** `flake.lock` (pins `nixpkgs` `nixos-unstable` rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010` narHash `sha256-dhoW6VgFWlaodSY5jrBn+CF2FLmaUvDVgM7+C7T2+NM=`; pins `r9` `github:requaos/r9` rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`; transitively captures r9's `nixpkgs_2` rev `1c89083e451e891152365b799595cf7790a43325` and `rust-overlay` rev `c85ccd343087c57da6021cafa1647142ad03e32e`).

## Compiler Toolchain (Plan 9 native)

Harvey uses the classic Plan 9 toolchain — one compiler/assembler/linker triple per architecture, all written in C and living in `sys/src/cmd/`:

| Arch | Assembler | Compiler | Linker | Source dir |
|------|-----------|----------|--------|------------|
| x86 (32-bit) | `8a` | `8c` | `8l` | `sys/src/cmd/8a`, `sys/src/cmd/8c`, `sys/src/cmd/8l` |
| amd64 | `6a` | `6c` | `6l` | `sys/src/cmd/6a`, `sys/src/cmd/6c`, `sys/src/cmd/6l` |
| ARM (32-bit) | `5a` | `5c` | `5l` | `sys/src/cmd/5a`, `sys/src/cmd/5c`, `sys/src/cmd/5l` |
| **aarch64** | `7a` | `7c` | `7l` | triple defined by `aarch64/mkfile` (`CC=7c LD=7l AS=7a O=7`); prebuilt binaries in `aarch64/bin/{7a,7c,7l}`; user-side ABI derived from 9front arm64 (see `aarch64/ABI.md`) |
| MIPS | `4a`/`va` | `4c`/`vc` | `4l`/`vl` | `sys/src/cmd/4a` … `sys/src/cmd/vl` |
| PowerPC | `9a`/`qa` | `9c`/`qc` | `9l`/`ql` | `sys/src/cmd/9a` … `sys/src/cmd/ql` |

The shared compiler frontend (common code generator) lives in `sys/src/cmd/cc/` (`cc.h`, `cc.y`, `com.c`, `com64.c`, `compat`). `sys/src/cmd/cpp/` is the C preprocessor. The bootstrap script `sys/src/BUILDTOOLCHAIN` builds `6a/6c/6l`, `8a/8c/8l`, `cpp`, and supporting tools; the Nix `toolchain` app (`./nix/toolchain.sh`) is the modern equivalent entry point.

An `iar` (Plan 9 `ar` port for the host) is built from the external `Harvey-OS/9-cc` repo and installed into `$HARVEY/linux_amd64/bin/ar` (legacy layout) or `$HARVEY/.build/hostbin-$os-$arch/bin/` (Nix devshell layout) — see `BUILD_ON_UNIX` lines 7–16, `build/Dockerfile` lines 49–81, and `flake.nix` shellHook.

## aarch64 Port Artifacts (Phase 2 tree)

The `aarch64/` directory at repo root is the aarch64 port tree:

- `aarch64/mkfile` — arch mk fragment: `CC=7c LD=7l AS=7a O=7`, includes `</sys/src/mkfile.proto`. Selected when `objtype=aarch64`.
- `aarch64/include/u.h` — per-arch LP64 type header: `nil`, `ushort/uchar/ulong/uint/vlong/uvlong`, `intptr`/`uintptr`/`usize` (64-bit), `Rune`, `mpdigit`, fixed-width `u8int`…`u64int`, FPCR/FPSR floating-point bits, `FPdbleword` union (little-endian), and the aarch64 `va_list`/`va_arg` macros (8-byte slot model).
- `aarch64/include/ureg.h` — **frozen** kernel-visible trap frame `Ureg`: `r0`..`r28` (`r28` = `sb`), `r29`, `r30`/`link` union, `sp`, `pc` (interrupted address), `psr`, `type` (exception class). r9's Rust trap frame is build-time-checked against this header (Phase 4).
- `aarch64/ABI.md` — **frozen** Harvey↔r9 user-side syscall wire contract for `objtype=aarch64` (decisions D-15/D-16/D-17): syscall number in `R0`, args in 8-byte slots at user `SP+8` upward, trap via `SVC`, result in `R0`. Syscall table = `sys/src/libc/9syscall/sys.h` 0–54 verbatim (53 `NSEC` zero-arg register-return; 54 `NMOUNT` Harvey-only). Stubs generated by the `case aarch64` block of `sys/src/libc/9syscall/mkfile`. Its **Phase-4 appendix** pins the `Ureg` byte offsets (r0@0 … r28@224, r29@232, r30/link@240, sp@248, pc@256, psr@264, type@272; `sizeof(Ureg)`=280) and defines the two-layer enforcement: r9 in-crate `core::mem::offset_of!` const asserts (frame stride 288) plus `cargo xtask ureg-check` in the r9 repo, which parses this repo's `aarch64/include/ureg.h` (located via `R9_HARVEY_DIR`, default `../harvey`) and fails on field drift. Changing this document or `ureg.h` after Phase 4 means re-freezing both repos.
- `aarch64/bin/` — built aarch64 toolchain (`7a`, `7c`, `7l`) and userspace binaries (`cat`, `cp`, `date`, `echo`, `grep`, `ls`, `mkdir`, `mv`, `ps`, `rc`, `rm`, `sed`, `test`, `wc`, `paqfs`, `dial`) plus per-subsystem dirs (`auth/`, `ip/`, `ndb/`, `upas/`, `aux/`, `disk/`, `fossil/`, `fs/`, `games/`, `bitsy/`, `replica/`, `usb/`, `venti/`, `ape/`).
- `aarch64/lib/` — built aarch64 archives: `libc.a`, `lib9p.a`, `libString.a`, `libauth.a`, `libauthsrv.a`, `libbio.a`, `libip.a`, `libmp.a`, `libndb.a`, `libregexp.a`, `libsec.a`, `libthread.a`, plus `ape/`.
- `aarch64/bbin/` — boot binaries dir (currently empty).

The matching **r9 boot supply chain** lives in `build/aarch64/` (see "Build System" below): `subset-build.sh` produces the `aarch64/bin` + `build/aarch64/out/` binaries, `mkimage.sh` bakes `build/aarch64/bootfs.paq` from those plus the committed `build/aarch64/root-tree/` skeleton (`lib/namespace`, `rc/bin/termrc`, `usr/glenda/lib/profile`), and `run-r9.sh` / `nix/boot-r9.sh` / `nix/smoke-r9.sh` launch it under the flake-pinned r9 kernel. Gitignored transient artifacts (`.gitignore`): `/build/aarch64/{out/,bootfs.paq,pre-gate-build.log,drive-r9.log,compose-gate.log,smoke-r9.log}`.

**Naming constraint (from `AGENTS.md`):** the 64-bit ARM architecture is spelled `aarch64` (not `arm64`) in this project's tooling and docs.

## Frameworks

There are no "frameworks" in the web/app sense. The closest equivalents are the **in-tree Plan 9 libraries** under `sys/src/lib*/` (each with headers in `sys/include/`):

**Core OS:**
- `sys/src/libc/` — Plan 9 C library (per-arch under `libc/{386,amd64,arm,mips,mips64,power,power64,riscv,riscv64,sparc,spim,spim64}/`, portable code in `libc/9sys/`, `libc/port/`, `libc/fmt/`).
- `sys/src/lib9p/` — 9P file-protocol server framework. Header `sys/include/9p.h`.
- `sys/src/libbio/` — buffered I/O (`sys/include/bio.h`).
- `sys/src/libthread/` — cooperative threading.
- `sys/src/libmach/` — architecture abstraction, symbol tables, debug info (used by `acid` debugger).
- `sys/src/libndb/` — network database (`/lib/ndb`) parser.

**Graphics & UI:**
- `sys/src/libdraw/`, `sys/src/libmemdraw/`, `sys/src/libmemlayer/` — drawing primitives, in-memory images, layered windows.
- `sys/src/libframe/` — text-frame widget used by `acme`, `sam`, `rio`.
- `sys/src/libcontrol/` — full widget toolkit (buttons, menus, text entries) used by GUI apps.
- `sys/src/libplumb/` — plumber client library (inter-app message bus).

**Networking / protocols:**
- `sys/src/libip/` — IP helpers, dial/parse, protocol implementations.
- `sys/src/libhttpd/` — HTTP server framework (used by `sys/src/cmd/ip/httpd/`).
- `sys/src/libhtml/` — HTML parser.
- `sys/src/libsunrpc/` — Sun RPC (basis for NFS in `sys/src/cmd/9nfs/`, `sys/src/cmd/nfs.c`).
- `sys/src/liboventi/`, `sys/src/libventi/` — Venti archival-storage client (`sys/include/venti.h`, `oventi.h`).

**Crypto / security:**
- `sys/src/libsec/` — symmetric ciphers and PK crypto: AES, DES, 3DES, Blowfish, RC4, ChaCha, RSA, DSA, ElGamal, ECC, X.509/ASN.1, PEM. See `sys/src/libsec/port/` (e.g. `aes.c`, `chacha.c`, `dsagen.c`, `genprime.c`).
- `sys/src/libmp/` — multi-precision integer arithmetic backing libsec.
- `sys/src/libauth/`, `sys/src/libauthsrv/` — authentication protocols (p9sk1, p9cr, apop, chap, httpdigest, wep, wpapsk).

**Misc:**
- `sys/src/libString/`, `sys/src/libavl/`, `sys/src/libbin/`, `sys/src/libcomplete/`, `sys/src/libdisk/`, `sys/src/libdynld/`, `sys/src/libflate/` (deflate/gzip), `sys/src/libframe/`, `sys/src/libgeometry/`, `sys/src/liblex/`, `sys/src/libregexp/`, `sys/src/libscribble/`, `sys/src/libstdio/` (ANSI-compat), `sys/src/libaml/` (ACPI machine language parser).

## Build System

- **`mk(1)`** — Plan 9's make. Every directory of interest has a `mkfile`. Top-level templates live in `sys/src/cmd/`:
  - `sys/src/cmd/mkone` — build a single binary
  - `sys/src/cmd/mkmany` — build many binaries from one dir
  - `sys/src/cmd/mklib` — build a library archive
  - `sys/src/cmd/mksyslib` — build a system library
  - `sys/src/mkfile.proto`, `sys/src/mkfile` — top-level drivers
- **Nix flake** (`flake.nix`) — the modern host-side entry point:
  - `nix run .#setup` → `./nix/setup.sh` (plan9port + coreutils)
  - `nix run .#toolchain` → `./nix/toolchain.sh` (builds vendored 9cc toolchain with host `stdenv.cc`; Linux adds `binutils` for `nm`/`ar` — plan9port's darwin build ships its own `nm`, and GNU `nm` can't read Mach-O objects)
  - `nix run .#build` → Linux: `./nix/build.sh` via `sudo unshare` (host `/usr/bin/sudo` — a store sudo lacks setuid); darwin: `./nix/vm-build.sh` inside a lima VM (`lima`, `openssh`, `rsync`)
  - `nix run .#iso` → `./nix/iso.sh` (`expect qemu curl bzip2 gnutar git`)
  - `nix run .#boot-r9` → `./nix/boot-r9.sh` (`plan9port bash qemu dtc git`; +`util-linux gnused mount binutils` on Linux, +`lima openssh rsync` on darwin) — **the one command**: builds the aarch64 userland, bakes the initrd, patches the DTB, and launches the flake-pinned r9 kernel to the interactive rc `%` prompt
  - `nix run .#boot-r9-smoke` → `./nix/smoke-r9.sh` (same inputs + `expect`) — the same pipeline driven by `build/aarch64/smoke-r9.expect`; asserts the full D-09 sweep and exits 0/1 for CI
  - both boot-r9 apps export `R9_KERNEL_PKG="${r9.packages.${system}.kernel-virt}"` — the kernel/DTB arrive **only** as r9 flake-input store paths (INT-04: no sibling-checkout path anywhere in the composition); `boot-r9`/`boot-r9-smoke` exist only on systems where r9 ships `packages.kernel-virt`
  - `nix develop` → devshell with all of the above
- **`build/aarch64/` — the r9 compose/smoke supply chain** (Phase 5, INT-01/INT-02; the pipeline both boot-r9 apps run):
  1. **userland build** — `build/aarch64/subset-build.sh` (the ONE host driver on both platforms: darwin drives the lima guest's Plan 9 namespace via `vm-run.sh`/`nsrun.sh`; linux runs the same generated guest script natively under `sudo unshare -m`). Builds the lib closure (`libc libbio libregexp libip libndb libmp libsec libString libthread lib9p libauth libauthsrv libflate`) with `objtype=aarch64`, the 16-command subset (12 single-file + `rc`, `grep`, `ip/ipconfig`, `auth/factotum`), and the boot chain (`boot(8)` via `sys/src/9k/boot/mkfile.aarch64`, `init`, `paqfs`, `stacksmoke`) harvested to gitignored `build/aarch64/out/` with R_MAGIC (`00 00 8c 47`) asserts. Skip hatch: `R9_SKIP_BUILD=1` (dev only, never the default).
  2. **bake** — `build/aarch64/mkimage.sh` stages `build/aarch64/root-tree/` (committed skeleton: `lib/namespace`, `rc/bin/termrc`, `usr/glenda/lib/profile`) + binaries + verbatim `rc/lib/rcmain` and `adm/timezone/local`, then bakes `build/aarch64/bootfs.paq` with Harvey's own host-built `mkpaqfs` (`build/aarch64/mkpaqfs-host.sh` → `.build/bin/mkpaqfs`; r9's xtask is never invoked — D-11). No `/boot/factotum` in the image (D-02 auth-stub-by-absence).
  3. **DTB patch** — `fdtput` writes `/chosen linux,initrd-start`/`-end` (two 32-bit BE cells, high word first) into a writable throwaway copy of the r9 package's `virt-gicv2.dtb`; initrd load address `0x48000000`.
  4. **launch** — `qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a72 -smp 1 -m 1024M -accel tcg -kernel <r9 kernel-virt.elf> -dtb <patched> -device loader,file=<bootfs.paq>,addr=0x48000000 -nographic` (argv shape from r9's `aarch64/lib/config_virtexec.toml` `[qemu]`).
  - Supporting harness: `build/aarch64/run-r9.sh` (dev-time launcher; `R9_KERNEL`/`R9_DTB` required env, `--log FILE` gate mode), `build/aarch64/drive-r9.expect` (interactive gate driver), `build/aarch64/stage-build.sh` (stages `init`/`smokefork`/`smokenote`/`stacksmoke` + committed `hello.7.out` into `out/`), smoke/trace sources (`init.c`, `stacksmoke.c`, `pidwait.c`, `smokefork.c`, `smokenote.c`, `tracehello.c`, `trace-syscalls.py`, `trace-boot.rc`, `trace-sweep.rc`, `trace-namespace`, `trace-termrc`), and the retired-but-present 9front donor harness (`boot-9qemu.sh`, `donor-*-build.sh`, `run-gate.sh`, `drive9.py`, `srv9.py`, `mkfs9.py`, `gdbpoke9.py` — see `build/aarch64/README.md`).
  - **Reproducibility policy**: `build/REPRODUCIBILITY.md` — `KERNDATE` (SOURCE_DATE_EPOCH-style, derived host-side from `git log -1 --format=%ct`) pins kernel/userland build timestamps; INT-03 documents the clean-checkout boot reproduction (`git clone … && nix run .#boot-r9-smoke`, proven on darwin-aarch64 and linux; CI leg `.github/workflows/r9-shell.yml`).
- **`build/`** — legacy host-side orchestration:
  - `build/build.bash` — top-level Linux build (downloads `9legacy.iso`, boots QEMU, runs `rc build && rc repl && rc iso` inside the VM).
  - `build/Dockerfile` — Ubuntu 21.10 + plan9port + 9-cc image for reproducible builds.
  - `build/BUILD_IN_DOCKER` — entrypoint used inside the Docker image.
  - `build/scripts/` — rc scripts run inside the build VM (`build`, `repl`, `iso`, etc.).
  - `build/build-go.sh`, `build/build-usb.bash`, `build/make.bash`, `build/command.bash`, `build/mkdirs`.
  - `build/9-cc.patch` — local patch applied to the external `9-cc` repo when building `iar`.
- **`sys/src/BUILD`** — main in-tree driver: cleans, builds libs, builds everything, then invokes `$HARVEY/build/scripts/linux-build`.
- **`sys/src/BUILDTOOLCHAIN`** — builds the cross-compilers (6a/6c/6l, 8a/8c/8l, cpp, aux tools).
- **`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`** — uses `unshare -m` to run the build in a private mount namespace on Linux.
- **CI:** `.github/workflows/harvey.yml` (legacy amd64) — Ubuntu-latest, installs `rc qemu go-dep qemu-utils expect qemu-system-x86`, `go get harvey-os.org/cmd/ufs`, builds Go 1.16.6 for `GOOS=plan9 GOARCH=amd64`, then runs `bash command.bash` from `build/`. **Plus** `.github/workflows/r9-shell.yml` (Phase 5, D-13) — the linux clean-checkout leg: `actions/checkout@v4` → `DeterminateSystems/nix-installer-action` pinned to full SHA `3138316df39ed29be04236d7ffc686fa525866aa` (T-05-24 supply-chain rule) → `nix run .#boot-r9-smoke` on `ubuntu-latest`, 90-minute budget, `permissions: contents: read`, on `[push, pull_request]`. CI-green means linux only; the darwin leg is documented-manual (`build/REPRODUCIBILITY.md` INT-03).

## Key Dependencies

**Vendored / in-tree (no external fetch needed to compile):**
- All kernels, libraries, and commands listed above. The repository is self-contained C source.

**Pinned by Nix (`flake.lock`):**
- **nixpkgs** (`github:NixOS/nixpkgs/nixos-unstable`, rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010`) — primary flake input; supplies plan9port, qemu, lima, expect, dtc, binutils, util-linux, stdenv.cc, and the `minimega` package build (`./nix/minimega.nix`).
- **r9** (`github:requaos/r9`, rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`, narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`) — the Rust kernel as a proper flake input (D-10/INT-04); consumed only as `r9.packages.<system>.kernel-virt` store paths (`kernel-virt.elf` + `aarch64/lib/virt-gicv2.dtb`). Its own `nixpkgs` (`nixpkgs_2` node) and `rust-overlay` pins are captured transitively in this repo's `flake.lock`; r9's rust toolchain (`nightly-2026-01-30` + `rust-src`/`llvm-tools`) is honored inside the kernel-virt derivation. Dev override (D-13, dev-only): `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9`.

**Fetched at build/image time (legacy path):**
- **plan9port** (`9fans/plan9port`) — required on the host to provide `mk`, `rc`, host-side `9c/pcc`, `sed`, `yacc`, `lex`, `awk`, `date`. See `BUILD_ON_UNIX` and `build/Dockerfile` lines 29–42.
- **Harvey-OS/9-cc** (`0intro/9-cc`, patched by `build/9-cc.patch`) — provides `iar` used as the host `ar` for Plan 9-format archives. Cloned by `build/Dockerfile` (lines 49–54) and referenced in `BUILD_ON_UNIX`.
- **9legacy ISO** — `https://github.com/Harvey-OS/harvey/releases/download/9legacy/9legacy.iso.bz2`, downloaded by `build/build.bash` line 6 to bootstrap the build VM.
- **Go 1.16.6 source** (`golang/go`, branch `go1.16.6`) — cloned in CI (`.github/workflows/harvey.yml` line 21) and built for `GOOS=plan9 GOARCH=amd64`. Used to compile the Go programs shipped in the image.
- **Go programs shipped inside the image** (listed in `sys/src/cmd/go/commands`, fetched by `sys/src/cmd/go/fetchrepos.sh` / `fetchrepos.rc`):
  - `edwood` — `github.com/Harvey-OS/edwood` (Go port of Acme)
  - `tools/gopls`, `tools/cmd/goimports` — `github.com/golang/tools`
  - `acme-lsp` (and `L`, `Lone`) — `github.com/fhs/acme-lsp`
  - `muscle`, `musclefs`, `mus3` — `github.com/nicolagi/muscle`
- **`harvey-os.org/cmd/ufs`** — Go-based 9P file server, fetched by CI (`go get harvey-os.org/cmd/ufs` in `harvey.yml`) to serve the Harvey tree to the build VM.

**Cross-repo:**
- **r9** — Rust `no_std` Plan 9 kernel reimplementation (cargo xtask). Consumed as the pinned flake input `github:requaos/r9` (see above); a sibling checkout `../r9` is used only for development via `--override-input r9 git+file://…` and via r9's `cargo xtask ureg-check`, which parses this repo's `aarch64/include/ureg.h` located through `R9_HARVEY_DIR` (default `../harvey`). Harvey's `aarch64/ABI.md` + `aarch64/include/ureg.h` are the frozen wire/trap-frame contract r9's `svc` dispatch is build-time-checked against.

**Host tools (Nix devshell / CI / Docker):** `git`, `curl`, `expect`, `qemu`, `qemu-utils`, `dtc` (`fdtput` — DTB patch step of the r9 boot), `tar`, `bzip2`, `bash`, `sudo` (host `/usr/bin/sudo` only — needed for `unshare`), `unshare` (from `util-linux`), `gnused`, `binutils` (Linux), `lima` + `openssh` + `rsync` (darwin), `gnumake`, `python3` (build/aarch64 trace/donor harness scripts).

## Configuration

**Build-time environment variables** (set by scripts or the devshell, not by `.env` files — no `.env` file exists in this repo):
- `HARVEY` — absolute path of the repo root. Used throughout `BUILD_ON_UNIX`, `build/Dockerfile`, `sys/src/BUILD`. The devshell derives it from `git rev-parse --show-toplevel` with `$PWD` fallback.
- `HARVEY_LINUX_BIN` — host toolchain bin dir. Legacy default: `$HARVEY/linux_amd64/bin` (`build/Dockerfile` line 22). Nix devshell default: `$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin` where `arm64` is normalized to `aarch64` (`flake.nix` shellHook).
- `PLAN9` — path to plan9port installation. Nix apps/devshell set it to `${pkgs.plan9port}/plan9`; legacy default `/usr/local/plan9` (`BUILD_ON_UNIX` line 2). **`$PLAN9/bin` goes LAST in `PATH`** (plan9port ships a 9p `mount` that must not shadow util-linux `mount`).
- `objtype` — target architecture (`amd64`, `386`, `arm`, `aarch64`, …). Drives which `$objtype/mkfile` is included. Devshell exports `objtype=amd64`.
- `cputype` — devshell exports `cputype=unix`.
- `ARCH`, `OS` — used by CI / build scripts to pick the right toolchain (`harvey.yml` lines 26–27).
- `FORCERCFORMK` — force mk to run recipes via rc (set in `sys/src/BUILD`; devshell exports `FORCERCFORMK=1`).
- `CGO_ENABLED=0` — exported by the devshell (host Go builds must not drag in cgo).
- `GNU_SED` — absolute path to GNU sed, exported by the Linux `harvey-build` app (`$HARVEY_LINUX_BIN` shadows `sed` with plan9 sed, which lacks `-i`).
- `LIMA_YAML` — path to `./nix/lima-harvey.yaml`, exported by the darwin `harvey-build` app.
- `KERNDATE` — pinned build timestamp (epoch), SOURCE_DATE_EPOCH-style; derived host-side from `git log -1 --format=%ct` by `nix/build.sh`, `nix/vm-build.sh`, `nix/boot-r9.sh`, `nix/smoke-r9.sh`; honored by `sys/src/9k/k10/mkfile` and `sys/src/9k/mk/portmkfile` (`-DKERNDATE`). Override to pin explicitly. Policy: `build/REPRODUCIBILITY.md`.
- `R9_KERNEL_PKG` — **required** by `nix/boot-r9.sh` + `nix/smoke-r9.sh`; the r9 `kernel-virt` package's read-only store path, exported by the flake apps (`${r9.packages.${system}.kernel-virt}`). Presence validated before launch; no caller-supplied kernel path is exec'd (T-05-21).
- `R9_SKIP_BUILD` — `=1` skips the userland build leg of the boot-r9 apps (iteration hatch only; acceptance gates run the default full build).
- `R9_KERNEL`, `R9_DTB`, `R9_INITRD`, `QEMU_BIN` — env contract of `build/aarch64/run-r9.sh` (kernel ELF + DTB paths required, no defaults by design D-10/D-11).
- `R9_SMOKE_LOG` (default `build/aarch64/smoke-r9.log`), `R9_QEMU` (default `qemu-system-aarch64`) — `nix/smoke-r9.sh` capture path / qemu binary overrides.
- `R9_HARVEY_DIR` — consumed by r9's `cargo xtask ureg-check` to locate this repo's `aarch64/include/ureg.h` (default `../harvey`).

**System configuration files (target-side, in-tree templates):**
- `cfg/example/termrc` — terminal startup rc script
- `cfg/example/cpurc` — CPU-server startup rc script
- `cfg/example/namespace` — namespace template
- `cfg/example/consoledb` — console configuration
- `cfg/pxe/` — PXE-boot configuration
- `lib/ndb/` — network database content (hosts, DNS, auth domains)
- `lib/namespace`, `lib/namespace.ftp`, `lib/namespace.httpd` — namespace templates for services

**Build configs:**
- `flake.nix`, `flake.lock` — Nix dev environment (devshell, apps incl. `boot-r9`/`boot-r9-smoke`, minimega package; inputs `nixpkgs` + `r9`)
- `nix/` — flake support files referenced by `flake.nix`: `setup.sh`, `toolchain.sh`, `build.sh`, `vm-build.sh`, `iso.sh`, `boot-r9.sh`, `smoke-r9.sh`, `minimega.nix`, `lima-harvey.yaml`
- `build/REPRODUCIBILITY.md` — KERNDATE kernel-build pin policy (BUILD-04) + the INT-03 clean-checkout boot reproduction commands
- `build/aarch64/` — the r9 compose/smoke supply chain (see "Build System") and the retired 9front donor harness (`build/aarch64/README.md`)
- `sys/src/mkfile`, `sys/src/mkfile.proto`
- Per-arch mk fragments included as `</$objtype/mkfile` (e.g. `aarch64/mkfile`)
- `build/scripts/` — rc build stages
- `build/Dockerfile`, `build/BUILD_IN_DOCKER`

## Platform Requirements

**Development (host):**
- Primary dev machine: **darwin-aarch64**; also supported: linux aarch64/x86_64 (`AGENTS.md`). Nix flake systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, `x86_64-darwin`.
- Nix with flakes enabled (modern path) **or** manual plan9port install (legacy path per `BUILD_ON_UNIX`).
- The Harvey namespace build requires **Linux mount namespaces**: native `sudo unshare -m` on Linux; a **lima** VM on macOS (`nix run .#build` handles both).
- `qemu`, `expect`, `go`, `git`, `curl`, `gcc`/`build-essential` (all supplied by the devshell)
- plan9port compiled and on `PATH` (supplied by nixpkgs in the devshell)
- ~4 GB RAM for the legacy build VM (`build/build.bash` passes `-m 4096`)
- KVM recommended on Linux (`build/build.bash` adds `-accel kvm`; `minimega` requires KVM hosts)
- r9 builds anywhere cargo + qemu run (`AGENTS.md`)

**Target (what Harvey runs on):**
- Architectures with in-tree kernel support: `386/`, `amd64/`, `arm/`, `mips/`, `mips64/`, `power/`, `power64/`, `riscv/`, `riscv64/`, `sparc/`, `spim/`, `spim64/` (each contains per-arch `include/` and `mkfile`), plus **`aarch64/`** (Phase 2 userspace port tree: `aarch64/mkfile`, `aarch64/include/`, `aarch64/ABI.md`).
- Kernel ports live in `sys/src/9/` and `sys/src/9k/`:
  - `sys/src/9/pc` — x86 PC (i386/amd64)
  - `sys/src/9k/k10` — newer amd64 kernel
  - `sys/src/9/{bcm,omap,teg2,kw,mtx,rb,vt4,vt5}` — ARM/embedded ports (Raspberry Pi, OMAP, Tegra2, Kirkwood, etc.)
  - `sys/src/9/{loongson,loongson64}` — MIPS
  - `sys/src/9k/386`, `sys/src/9k/boot`, `sys/src/9k/mk` — additional ports
- The aarch64 kernel is **r9** (flake input `github:requaos/r9`, pinned in `flake.lock`), targeted at qemu `-M virt,gic-version=2` (beyond r9's raspi3b/4b focus); Harvey userspace (this repo, `aarch64/` tree + `build/aarch64/bootfs.paq`) runs on it against the frozen ABI in `aarch64/ABI.md`. Boot to the rc `%` prompt is demonstrated end-to-end by `nix run .#boot-r9` (interactive) and `nix run .#boot-r9-smoke` (CI smoke), per `build/REPRODUCIBILITY.md` INT-03.
- Boot images: ISO produced by `rc iso` (see `build/build.bash` line 70), PXE-boot support in `cfg/pxe/` and `sys/src/9/boot/`, and the paqfs initrd `build/aarch64/bootfs.paq` (baked by `build/aarch64/mkimage.sh`, loaded via qemu `-device loader,…,addr=0x48000000`) for the r9 path.

---

*Stack analysis: 2026-11-03*
