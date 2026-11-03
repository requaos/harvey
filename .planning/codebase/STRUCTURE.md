---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
# Codebase Structure

**Analysis Date:** 2026-11-03

## Directory Layout

The repository root doubles as the Plan 9 root filesystem image layout: top-level directories (`lib`, `usr`, `adm`, `rc`, `386`, `amd64`…) are exactly what appears at `/` on a running Harvey system. Source code lives under `sys/src/`.

```
harvey/
├── sys/                    # The system proper: source, headers, libs, docs, logs
│   ├── src/                # ALL source code (kernel, libs, commands, toolchains)
│   │   ├── 9/              # Legacy Plan 9 kernel tree (multi-arch reference)
│   │   ├── 9k/             # Harvey kernel: port/ + k10/ (amd64) + 386/ + ip/ + mk/
│   │   ├── libc/           # C library: port/ 9sys/ 9syscall/ fmt/ + per-arch asm dirs
│   │   ├── lib9p/ ... libventi/   # ~40 user-space libraries (lib<name>/ pattern)
│   │   ├── cmd/            # ~266 user commands, daemons, file servers, compilers
│   │   ├── ape/            # ANSI/POSIX Environment (lib/, cmd/, 9src/, config/)
│   │   ├── boot/           # Bootloaders: efi/, pc/, vt4/, vt5/
│   │   ├── nboot/          # Newer boot tree (efi/, pc/)
│   │   ├── games/          # Game sources
│   │   ├── mkfile          # Top-level mk entry
│   │   └── mkfile.proto    # Shared mk parameters (CPUS, CFLAGS, LEX/YACC)
│   ├── include/            # Public headers (libc.h, draw.h, fcall.h, 9p.h, …)
│   ├── man/                # Manual pages, sections 1–9 + 9k
│   ├── lib/                # System data installed at /sys/lib (acid, dict helpers…)
│   ├── doc/                # System documentation
│   ├── log/                # Log dirs per service (dns, httpd, auth, fossil…)
│   └── games/              # Installed game data (lib/)
├── 386/  amd64/  aarch64/  arm/  mips/  mips64/  power/  power64/  riscv/
│   │   riscv64/  sparc/  spim/  spim64/   # Per-architecture install roots
│   │                           #   <arch>/include/{u.h,ureg.h,ape/}, <arch>/mkfile,
│   │                           #   <arch>/bin (installed binaries; only some populated)
│   │                           #   aarch64/ also carries ABI.md (frozen syscall contract)
├── acme/                   # Acme user data: bin/, mail/, news/, wiki/, acid/
├── adm/                    # Admin data: users, timezone, keys.who, netkeys.who, cache
├── cfg/                    # Host configs: example/, pxe/
├── cron/                   # Cron spool: sys/, upas/
├── dist/                   # Distribution: replica/
├── lib/                    # Root /lib data: fonts, dict, ndb, namespace, vgadb, rfc…
├── mail/                   # Mail spool dirs: box/, lib/, grey/, faxqueue/
├── rc/                     # rc shell resources: bin/ (scripts incl. termrc/cpurc), lib/rcmain
├── usr/                    # User home dirs (glenda — the Plan 9 mascot default user)
├── unix/                   # Unix-compat headers/mkfile (u.h)
├── build/                  # Harvey host-build harness (bash+QEMU): build.bash, scripts/,
│                           #   Dockerfile, BUILD_IN_DOCKER, RUNCOREBOOT, mkdirs, bind,
│                           #   REPRODUCIBILITY.md (KERNDATE + clean-checkout boot policy),
│                           #   aarch64/ (the r9-boot supply chain — see Directory Purposes)
├── flake.nix               # Nix dev environment: devshell + setup/toolchain/build/iso/
│                           #   boot-r9/boot-r9-smoke apps; inputs: nixpkgs + r9
├── flake.lock              # Pins nixpkgs (nixos-unstable) and r9 (github:requaos/r9,
│                           #   rev 9549cee6… + r9's transitive nixpkgs/rust-overlay nodes)
├── nix/                    # Scripts backing the flake apps: setup.sh, toolchain.sh,
│                           #   build.sh, vm-build.sh, iso.sh, boot-r9.sh, smoke-r9.sh,
│                           #   lima-harvey.yaml, minimega.nix
└── AGENTS.md               # Agent-facing project contract (GSD-managed sections)
```

## Directory Purposes

**`sys/src/9k/` — Harvey kernel:**
- Purpose: The actively-developed kernel, amd64-first with 386 support.
- Contains: `port/` (62 portable `.c` + `portdat.h`, `portfns.h`, `error.h`, `sd.h`, `netif.h`), `k10/` (amd64 machine layer + kernel configs `k10cpu`, `k10cpuf`, `k10aoe`, `k10root`), `386/` (i386 drivers: ether*, sdata/sdiahci, uarti8250, vgavesa, pci), `ip/` (TCP/IP stack), `boot/` (user bootstrap program), `root/` (embedded boot root: `rcmain`, `cpu.c`), `mk/` (config compiler: `parse`, `bootmkfile`, `portmkfile`, `mkroot*`).
- Key files: `sys/src/9k/k10/main.c` (entry `main()` line 145), `sys/src/9k/k10/mkfile`, `sys/src/9k/port/portdat.h` (struct Dev line 198), `sys/src/9k/port/sysfile.c`, `sys/src/9k/port/proc.c`.

**`sys/src/9/` — legacy Plan 9 kernel:**
- Purpose: Original Bell Labs kernel retained for reference/other architectures.
- Contains: `port/` + machine dirs `pc/`, `bcm/` (Raspberry Pi), `kw/` (Kirkwood), `omap/`, `teg2/` (Tegra), `loongson*/`, `mtx/`, `ppc/`, `rb/`, `vt4/`, `vt5/`, plus `ip/`, `boot/`.
- Note: New work goes in `9k/`; consult `9/` for drivers not yet ported.

**`sys/src/libc/` — the C library:**
- Purpose: Single libc for all native code, all architectures.
- Contains: `port/` (112 portable .c: fmt, math, strings, pools), `9sys/` (~70 syscall wrappers + 9P codec: `convM2S.c`, `dial.c`, `bind.c`), `9syscall/sys.h` (syscall numbers), `fmt/` (printf), per-arch asm dirs (`amd64/`, `386/`, `arm/`, `riscv/`, `riscv64/`, `mips*/`, `power*/`, `sparc/`, `spim*/`) holding `memcpy.s`, `setjmp.s`, `tas.s`, `main9.s`…
- Key files: `sys/include/libc.h` (API), `amd64/include/u.h` (arch types), `sys/src/libc/9syscall/sys.h` (kernel-shared syscall table).

**`sys/src/cmd/` — userland commands:**
- Purpose: Every executable on the system: file utilities, shells, compilers, network daemons, file servers, window system, editors, compilers.
- Contains: Mix of single-file programs (`cat.c`, `cp.c`, `bind.c`, `srv.c`, `walk.c`) and directories for multi-file programs (`acme/`, `auth/`, `ip/`, `upas/`, `venti/`, `webfs/`, `ndb/`, `mk/`, `rc/`…). Toolchains: `8c/8a/8l` (amd64), `6c/6a/6l` (386), `5c/5a/5l` (arm), plus `cc`, `cpp`, `yacc.c`, `lex/`.
- Key files: `sys/src/cmd/mk/` (build tool), `sys/src/cmd/rc/` (shell), `sys/src/cmd/acme/acme.c`, `sys/src/cmd/go/fetchrepos.sh` (vendored Go toolchain for build-time tools).

**`sys/src/lib*/` — user-space libraries (~40):**
- Purpose: Shared code beyond libc, one dir per library named `lib<name>`.
- Notable: `lib9p` (9P server framework), `libthread` (threads/channels), `libdraw`+`libmemdraw`+`libmemlayer` (graphics), `libframe`+`libcontrol` (GUI widgets), `libbio` (buffered I/O), `libsec` (crypto/TLS), `libmp` (bignum), `libauth`+`libauthsrv` (auth protocols), `libndb` (network db), `libip` (IP helpers), `libventi`/`liboventi` (Venti archival store client), `libmach` (debugger/disasm), `libregexp`, `libplumb` (plumber), `libhtml`, `libhttpd`, `libflate`, `libavl`, `libgeometry`, `liblex`, `libdisk`, `libcomplete`, `libscribble`, `libsunrpc`, `libstdio`, `libString`, `libaml`, `libbin`, `libdynld`.
- Layout per lib: sources + `mkfile` at `sys/src/lib<name>/`; public header at `sys/include/<name>.h` (e.g., `sys/include/draw.h`, `sys/include/thread.h`, `sys/include/9p.h`).

**`sys/src/ape/` — POSIX environment:**
- Purpose: ANSI/POSIX libc + ported Unix programs; isolated so native code never sees POSIX semantics.
- Contains: `lib/` (ape libc impl), `cmd/` (diff, patch, sh, make, awk…), `9src/`, `config/`.
- Headers: `sys/include/ape/`, per-arch `amd64/include/ape/`.

**`build/` — host build harness:**
- Purpose: Build the Harvey ISO from Linux/macOS by booting a Plan 9 VM (9legacy.iso) under QEMU with the source as a tarball disk; scripts inside the VM run the native mk build.
- Key files: `build/build.bash` (main driver, downloads 9legacy.iso, QEMU+expect automation), `build/scripts/` (`build`, `repl`, `iso`, `main`, `funcs`, `linux-build`, `usb`), `build/mkdirs`, `build/bind`, `build/Dockerfile` + `BUILD_IN_DOCKER`, `build/RUNCOREBOOT`, `build/README` (requires host 9P server on port 5640).
- `build/REPRODUCIBILITY.md`: the two reproduction policies — BUILD-04 KERNDATE pinned-timestamp (9k amd64 kernels bit-reproducible at same checkout path + KERNDATE, derived from `git log -1 --format=%ct`) and INT-03 clean-checkout r9-boot reproduction (documented-commands level: `git clone … && nix run .#boot-r9-smoke` reproduces the green boot smoke on darwin-aarch64 and linux; image bytes are NOT claimed bit-identical across checkouts).
- `build/aarch64/`: the r9-boot supply chain + donor harness (next entry).

**`build/aarch64/` — aarch64 r9-boot supply chain + donor harness:**
- Purpose: Everything host-side for the Harvey-userland-on-r9-kernel boot: build the aarch64 userland subset, bake the paqfs root image, patch the r9 DTB, launch and assert qemu. Also retains the phase-02 9front donor-kernel bridge harness and the 05-03 syscall trace rig.
- Supply chain (the compose pipeline's stages): `subset-build.sh` (the ONE userland build driver, both hosts — lima namespace on darwin, native `sudo unshare` on linux; 13 libs + 16 commands + boot chain `boot`/`init`/`paqfs`/`stacksmoke`; harvests to gitignored `aarch64/bin/` + `build/aarch64/out/` with R_MAGIC asserts), `mkimage.sh` (bakes `bootfs.paq` from `root-tree/` + binaries via host mkpaqfs; manifest asserts incl. D-02 `/boot/factotum` absence and real-init identity), `mkpaqfs-host.sh` (builds Harvey's in-tree `sys/src/cmd/paqfs/mkpaqfs.c` as `.build/bin/mkpaqfs` — the paqfs byte-format owner), `run-r9.sh` (dev qemu launcher; `R9_KERNEL`/`R9_DTB` required env, no sibling-checkout defaults; fdtput DTB patch + locked `-M virt,gic-version=2` TCG argv).
- Drivers: `drive-r9.expect` (05-08 interactive gate — spawns `run-r9.sh`), `smoke-r9.expect` (05-12 packaged smoke — spawns qemu directly; the D-09 sweep: banner→paqfs→stacksmoke→prompt→echo→ls/ps/cat→DEL safety→init restart; invoked by `nix run .#boot-r9-smoke`).
- Staged-init chain (phase 04, feeds r9's own `cargo xtask initrd` bake): `stage-build.sh` + staged sources `init.c` (minimal first process: rforks/exec children, postnote, await), `smokefork.c`, `smokenote.c`, `stacksmoke.c` (depth-64 recursion stack-growth smoke, D-15); the committed ABI bisect binary `hello.7.out` (+ `hello.c`) rides along verbatim.
- Trace rig (05-03, donor-kernel era): `trace-syscalls.py` (host driver + parser — devproc `startsyscall` measurement of the real boot chain), guest-side `trace-boot.rc`, `trace-namespace`, `trace-termrc`, `trace-sweep.rc`, helper `pidwait.c` (watch /proc for a named process), probe `tracehello.c`.
- Donor harness (phase 02): `vm-run.sh`, `nsrun.sh`, `donor-vm-build.sh`, `donor-ns-build.sh`, `boot-9qemu.sh` (+ `drive9.py`, `srv9.py`, `gdbpoke9.py`, `mkfs9.py`), `run-gate.sh`, `pre-gate-build.sh` (obsolete post-02-06 — refuses to run), `subset-exec.sh`; `README.md` is the pin record (9front `front` @ `350266104f1fed81c78c3d05fa44f523bec0ae4d`, TCG-only constraint, bake-vs-ufs delivery); committed gate evidence `gate-evidence.log` + `hello.7.out`.
- Committed image skeleton: `root-tree/lib/namespace` (scoped: no network binds, no factotum; the re-mount pair `mount -a #s/boot /root` + `bind -a /root /` comes FIRST because newns's RFCNAMEG wipe clears boot's mount table), `root-tree/rc/bin/termrc` (`stacksmoke` then `exec rc -i`), `root-tree/usr/glenda/lib/profile` (near-empty). `rc/lib/rcmain` and `adm/timezone/local` ship verbatim from the repo root at bake time (never duplicated into the skeleton).
- Generated (gitignored): `out/` (staged binaries), `bootfs.paq`, `drive-r9.log`, `compose-gate.log`, `smoke-r9.log`, `pre-gate-build.log`, `__pycache__/`.

**Architecture install roots (`386/`, `amd64/`, `aarch64/`, `arm/`, …):**
- Purpose: Per-`$objtype` install targets: headers and (after build) binaries.
- Contains: `<arch>/include/u.h`, `<arch>/include/ureg.h`, `<arch>/include/ape/`, `<arch>/mkfile` (arch mk parameters: CC/AS/LD, `O` suffix), `<arch>/bin/` (populated by `mk install`; e.g. `386/bin`, `386/bbin`).
- Only `386/`, `arm/`, and `aarch64/` ship populated `bin/` in-tree; `amd64/` currently ships headers+mkfile only.
- **`aarch64/` specifics (Phase 2 port tree):** `aarch64/ABI.md` — the frozen Harvey↔r9 user-side syscall wire contract (number in R0, args at SP+8, `SVC`, result in R0); `aarch64/include/u.h` — LP64 base types, 8-byte-slot `va_list`, `jmp_buf[2]`; `aarch64/include/ureg.h` — frozen trap frame (`r0`..`r28`/`sb`, `r29`, `r30`/`link`, `sp`, `pc`, `psr`, `type`); `aarch64/mkfile` — toolchain selection `CC=7c LD=7l AS=7a O=7`; `aarch64/bin/` — populated with the `7a`/`7c`/`7l` toolchain plus core commands (`cat`, `cp`, `date`, `echo`, `grep`, `ls`, `mkdir`, `mv`, `ps`, `rc`, `rm`, `sed`, `test`, `wc`); `aarch64/lib/` — built archives (`libc.a`, `lib9p.a`, `libbio.a`, `libsec.a`, `libmp.a`, `libthread.a`, `libauth*.a`, `libip.a`, `libndb.a`, `libregexp.a`, `libString.a`); `aarch64/bbin/` — boot binaries dir (currently empty).

**Nix layer (`flake.nix`, `flake.lock`, `nix/`):**
- Purpose: Reproducible host dev environment and build entry points (supersedes manual plan9port install and the Docker path for day-to-day work); owns the Harvey↔r9 composition (D-10/INT-04 — r9 arrives as a flake input, never a submodule or sibling path).
- Contains: `flake.nix` — apps `setup`/`toolchain`/`build`/`iso` plus the r9 pair `boot-r9`/`boot-r9-smoke` (wrappers around `nix/*.sh` via `writeShellApplication`; the r9 apps exist only where `r9.packages` ships `kernel-virt`, gated by `builtins.hasAttr`), `devShells.default`, Linux-only `minimega` package; `flake.lock` — pins `nixpkgs` (`nixos-unstable`, rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010`) and `inputs.r9` (`github:requaos/r9`, rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`, narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`) plus r9's transitive `nixpkgs`/`rust-overlay` nodes; `nix/setup.sh` (populate `.build/hostbin-<os>-<arch>/bin`), `nix/toolchain.sh` (cross-compiler build with `-static`-stripping `9l` shim), `nix/build.sh` (Linux namespace build, host-`nm` shim), `nix/vm-build.sh` (darwin: rsync→lima VM→rsync-back), `nix/iso.sh` (qemu+expect ISO path), `nix/boot-r9.sh` (compose app: subset-build → mkimage bake → fdtput DTB patch → interactive qemu; consumes `R9_KERNEL_PKG` exported by the flake from the r9 input's `kernel-virt` package), `nix/smoke-r9.sh` (same pipeline under `build/aarch64/smoke-r9.expect`, exit 0/1 for CI), `nix/lima-harvey.yaml` (Ubuntu 24.04 VM, 4 CPU/8 GiB), `nix/minimega.nix` (v3.3.0 KVM VM orchestrator, Linux only).

**Root data directories (installed at `/`):**
- `lib/` — system databases: `ndb/` (network database), `namespace` + variants (default namespace templates), `font/`, `dict/`, `vgadb`, `pci`, `rfc/`, `unicode`, `keyboard`, `units`, `sky/`, `map/`…
- `rc/` — `rc/bin/` holds shell scripts that ARE system commands (`termrc`, `cpurc`, `9fs`, `B`, `await`, `addaoe`…); `rc/lib/rcmain` init.
- `usr/glenda/` — default user home: `bin/rc/` personal scripts (`riostart`, `pull`), `lib/`.
- `adm/`, `cfg/`, `cron/`, `mail/`, `dist/`, `acme/`, `sys/log/` — runtime state/spools/config for auth, timezones, cron, mail (upas), replica distribution, acme scratch, per-service logs.

## Key File Locations

**Entry Points:**
- `sys/src/9k/k10/main.c`: Kernel C entry — `main(u32int ax, u32int bx)` at line 145 (multiboot); asm entry `sys/src/9k/k10/l32p.s`/`l64v.s`.
- `sys/src/boot/efi/efi.c`: EFI bootloader main; ISO9660 walker in `sys/src/boot/efi/iso.c`.
- `sys/src/9k/boot/boot.c`: First user process (pid 1 bootstrap).
- `sys/src/9k/root/rcmain`, `rc/bin/termrc`, `rc/bin/cpurc`: System/session init scripts.
- `build/build.bash`: Legacy host-side build entry (still used by `nix/iso.sh`).
- `flake.nix` apps (`nix run .#setup` → `.#toolchain` → `.#build` / `.#iso`): Current host build entry; `nix develop` for the devshell.
- `nix run .#boot-r9` / `nix run .#boot-r9-smoke` (`nix/boot-r9.sh`, `nix/smoke-r9.sh`): The aarch64 r9-boot entries — interactive `%` prompt / self-asserting CI smoke over the composed pipeline (build → bake → DTB patch → qemu). CI leg: `.github/workflows/r9-shell.yml` (clean checkout on `ubuntu-latest`).

**Configuration:**
- `flake.nix`, `flake.lock`: Host dev environment; pins nixpkgs + the r9 kernel input (`inputs.r9`, rev+narHash); apps are the supported host entry points.
- `build/REPRODUCIBILITY.md`: The KERNDATE pinned-timestamp policy (9k kernels) + the INT-03 clean-checkout r9-boot reproduction policy.
- `nix/lima-harvey.yaml`: lima VM definition for darwin kernel builds (Linux mount namespaces required).
- `AGENTS.md`: Agent-facing project contract; GSD-managed `<!-- GSD:* -->` sections are regenerated, not hand-edited.
- `aarch64/ABI.md`: **Frozen** aarch64 user-side syscall ABI (Harvey↔r9) — do not edit without re-freezing both repos.
- `aarch64/mkfile`: aarch64 toolchain selection (`CC=7c LD=7l AS=7a O=7`).
- `sys/src/9k/k10/k10cpu` (+`k10cpuf`, `k10aoe`, `k10root`): Kernel configuration — device list, drivers, links, boot program, root contents. Compiled by `sys/src/9k/mk/parse`.
- `sys/src/mkfile.proto`: Global mk parameters (`CPUS=amd64 arm 386 riscv riscv64 power mips`, `CFLAGS=-FTVw`).
- `<arch>/mkfile` (e.g., `amd64/mkfile`): Per-arch toolchain selection (CC=8c, AS=8a, LD=8l, O=8).
- `sys/src/9k/k10/mkfile`: Kernel link rules (link addr `0xfffffffff0110000`, see line 21).
- `cfg/example/`, `cfg/pxe/`: Sample host/PXE configs; `plan9.ini` consumed by EFI loader.
- `lib/namespace`, `lib/namespace.httpd`, `lib/namespace.ftp`: Namespace assembly templates.

**Core Logic:**
- `sys/src/9k/port/proc.c`: Scheduler/processes.
- `sys/src/9k/port/chan.c`: Name resolution (namespaces, unions).
- `sys/src/9k/port/dev.c` + `devtab.c` + generated `$CONF.c`: Device dispatch.
- `sys/src/9k/port/sysfile.c`: File syscalls (sysopen:286, sysbind:1174, sysmount:1192, sysnmount:1212 — nmount is a Harvey addition).
- `sys/src/9k/port/sysproc.c`: Process syscalls (rfork, exec, exits).
- `sys/src/9k/port/devmnt.c`: 9P mount client (kernel side of user file servers).
- `sys/src/9k/ip/`: In-kernel TCP/IP.
- `sys/src/lib9p/srv.c`: 9P server framework (user side).
- `sys/src/libc/9sys/convS2M.c`/`convM2S.c`: 9P2000 wire codec.

**Testing:**
- No unit-test framework in the tree (upstream Plan 9 culture: testing via usage).
- Test-adjacent files exist per-library: `sys/src/lib9p/ftest.c`, `sys/src/libthread/example.c`, command `test.c` (shell builtin), `sys/src/cmd/*/test*` sporadically.
- Validation happens via running the system: `build/scripts/` boots QEMU; `sys/src/cmd/syscall/` exercises syscall surface.

## Naming Conventions

**Files:**
- Kernel devices: `dev<name>.c` — `devcons.c`, `devmnt.c`, `devproc.c`, `devtls.c` (`sys/src/9k/port/`).
- Machine asm: `l64*.s`/`l32*.s` in `k10/`, `<routine>.s` per-function asm in libc arch dirs.
- Commands: `<verb>.c` lowercase single word — `cat.c`, `bind.c`, `walk.c`; multi-file in `cmd/<name>/`.
- Libraries: `lib<name>/` dir + `sys/include/<name>.h` header (`libdraw/` ↔ `draw.h`).
- Kernel configs: `<arch><flavor>` — `k10cpu`, `k10cpuf` (f=full/framebuffer), `k10aoe`, `k10root`.
- Headers per layer: `dat.h`/`fns.h`/`mem.h`/`io.h` (machine decls), `portdat.h`/`portfns.h`/`error.h` (portable decls), `u.h` (per-arch base types), `lib.h` (kernel libc subset).
- Manual pages: `sys/man/<section>/<name>`.

**Directories:**
- Arch dirs are short cpu names: `386`, `amd64`, `aarch64`, `arm`, `riscv64`, `power64`, `mips64`, `spim` (big-endian MIPS for simulator). This project spells the 64-bit ARM architecture `aarch64` (never `arm64`) in tooling and docs.
- Library dirs all carry the `lib` prefix; everything else in `sys/src/` is a subsystem (`cmd`, `boot`, `9k`, `ape`, `nboot`).
- Plan 9 toolchain naming: `<n>c`/`<n>a`/`<n>l` = compiler/assembler/linker for arch n (8=amd64, 6=386, 5=arm, 7=aarch64, 9=power64, 4/0 variants…) — sources in `sys/src/cmd/{4,5,6,7,8,9}{a,c,l}/`.

**Code identifiers (for reference when editing):**
- Kernel C: short lowercase functions (`namec`, `cclose`, `sysopen`, `waserror`), structs `CamelCase` typedef'd (`Chan`, `Dev`, `Proc`, `Segment`, `Qid`).
- Syscall numbers: UPPERCASE in `sys/src/libc/9syscall/sys.h` (`BIND 2`, `MOUNT 46`, `NMOUNT` Harvey-added).
- Plan 9 types: `u32int`, `uintptr`, `usize`, `uvlong` (from `u.h`); `nil` instead of NULL; `Ar0` syscall-arg struct in Harvey kernel handlers.

## Where to Add New Code

**New kernel device (portable):**
- Primary code: `sys/src/9k/port/dev<name>.c` implementing `struct Dev` (`portdat.h:198`).
- Register: add `<name>` to the `dev` section of the kernel config, e.g. `sys/src/9k/k10/k10cpu`.
- Build: `cd sys/src/9k/k10 && mk 9k` (mkfile runs `../mk/parse` to regenerate devtab).

**New hardware driver (x86):**
- Implementation: `sys/src/9k/386/<driver>.c` (32-bit-safe) or `sys/src/9k/k10/<driver>.c` if amd64-only; ethernet drivers follow `ether<chipset>.c` and use `etherif.h`/`ethermii.h`.
- Declare prototypes in the machine `fns.h`; wire into config `link`/`misc` section of `k10cpu`.

**New system call:**
- Number: append to `sys/src/libc/9syscall/sys.h`.
- Kernel handler: `sys<name>()` in `sys/src/9k/port/sysfile.c` or `sysproc.c` (Harvey signature `sysname(Ar0* ar0, va_list list)`), registered in the syscall table via the config/mk pipeline.
- User wrapper: `sys/src/libc/9sys/<name>.c`.
- Precedent: Harvey's `nmount` — commit `80deb8e34`, handler `sysnmount` at `sysfile.c:1212`.

**New architecture port (precedent: `aarch64/`):**
- Install root: top-level `<arch>/` dir with `include/u.h` (base types, `va_list`, `jmp_buf`), `include/ureg.h` (trap frame), `mkfile` (`</sys/src/mkfile.proto` include + `CC/LD/AS/O` letters), `bin/`, `bbin/`, `lib/`.
- libc arch dir: `sys/src/libc/<arch>/` (asm primitives: `memcpy.s`, `setjmp.s`, `tas.s`, `main9.s`, `_seek.c` wrapper as needed).
- Syscall stubs: add a `case <arch>` block to `sys/src/libc/9syscall/mkfile`'s stub generator (aarch64's is the `arm64` donor verbatim with the label renamed).
- Toolchain: Plan 9 compiler suite sources under `sys/src/cmd/<n>{a,c,l}/` (aarch64 reuses the 9front-derived `7a`/`7c`/`7l`).
- ABI: if the port targets a non-9k kernel (e.g. r9), write and freeze the wire contract first — see `aarch64/ABI.md` (D-15/D-16/D-17). The `ureg.h` trap frame is part of the freeze.

**New user command:**
- Single file: `sys/src/cmd/<name>.c` — but prefer a directory `sys/src/cmd/<name>/` with its own `mkfile` if more than one file; include `</$objtype/mkfile>` pattern like neighbors.
- Install target: `mk install` → `/$objtype/bin/<name>` (e.g., `386/bin/`).
- Script commands: drop in `rc/bin/<name>` (no build needed).

**New library:**
- Implementation: `sys/src/lib<name>/*.c` + `mkfile`.
- Public header: `sys/include/<name>.h`.
- Consumers link via `$objtype` library path rules already in mk includes.

**New file server (user space):**
- Use `lib9p`: model on `sys/src/lib9p/ramfs.c` (minimal) or `sys/src/cmd/webfs/` (real).
- Mount via `srv`/`mount` in namespace or `postmountsrv()` to `/srv`.

**Utilities/shared helpers:**
- Kernel helpers: `sys/src/9k/port/` (portable) or machine `fns.h`-declared.
- User helpers: extend libc only if universally needed (`sys/src/libc/port/`); otherwise create/extend the appropriate `lib<name>`.

## Special Directories

**`.planning/`:**
- Purpose: GSD planning artifacts (this analysis, phase plans).
- Generated: Yes (tooling). Committed: Yes (per project convention).

**`.build/hostbin-<os>-<arch>/`:**
- Purpose: Per-host bootstrap toolchain bin dir populated by `nix run .#setup` (`pcc`, host tools); referenced as `$HARVEY_LINUX_BIN`. Per-OS/arch so a checkout shared with the lima build VM never clobbers host binaries.
- Generated: Yes. Committed: No.

**`.build/` (other contents):**
- Purpose: Host artifacts — `.build/bin/mkpaqfs` (Harvey's in-tree mkpaqfs built as a host binary by `build/aarch64/mkpaqfs-host.sh`; the paqfs byte-format owner for `mkimage.sh` bakes), `.build/9front-donor/` + `.build/9front-dist/` (the pinned 9front donor checkout and its build outputs, host side), harness logs (`stage-build.log`, `subset-build.log`).
- Generated: Yes. Committed: No (whole `/.build/` gitignored).

**`build/` outputs:**
- `harvey.tgz`, `9legacy.iso*`, final `plan9-new.iso.bz2` — build artifacts at repo root / build dir.
- `build/aarch64/out/` (staged aarch64 binaries — regenerated by `stage-build.sh`/`subset-build.sh`), `build/aarch64/bootfs.paq` (the baked paqfs root image — regenerated by `mkimage.sh`), transient captures `build/aarch64/drive-r9.log`, `compose-gate.log`, `smoke-r9.log`, `pre-gate-build.log`, and `__pycache__/` from the harness's python scripts.
- Generated: Yes. Committed: No (`.gitignore` covers them; passing smoke/gate captures are copied into phase dirs as retained evidence instead).

**`sys/src/cmd/go/`:**
- Purpose: Fetches (not vendors) the Go toolchain repos needed at build time (`fetchrepos.sh`/`fetchrepos.rc`); Go binaries under `sys/go/bin/plan9_386` are used by `build.bash` inside the VM.
- Generated content: fetched repos. Committed: only the fetch scripts + mkfile.

**`sys/log/`:**
- Purpose: Per-service log directories (`auth`, `dns`, `httpd`, `fossil`, `ipboot`…) — empty scaffolding in repo, filled at runtime.
- Generated: partially (runtime). Committed: structure only.

**Per-arch `bin/` (`386/bin`, `arm/bin`, `aarch64/bin`, `386/bbin`):**
- Purpose: Install targets for `mk install` — binaries land here, named without extension.
- Generated: Yes (build output). Committed: some legacy binaries are in-tree; `aarch64/bin` holds the Phase 2 aarch64 toolchain (`7a`/`7c`/`7l`) and core command builds, `aarch64/lib` the built archives.

---

*Structure analysis: 2026-11-03*
