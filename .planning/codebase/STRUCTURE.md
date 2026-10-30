---
last_mapped_commit: bf084ee78de58b5f05b98235bb6e6887fde6e8c4
last_mapped_at: 2026-10-30
---
# Codebase Structure

**Analysis Date:** 2026-10-30

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
├── 386/  amd64/  arm/  mips/  mips64/  power/  power64/  riscv/  riscv64/
│   │   sparc/  spim/  spim64/   # Per-architecture install roots
│   │                           #   <arch>/include/{u.h,ureg.h,ape/}, <arch>/mkfile,
│   │                           #   <arch>/bin (installed binaries; only some populated)
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
└── build/                  # Harvey host-build harness (bash+QEMU): build.bash, scripts/,
                            #   Dockerfile, BUILD_IN_DOCKER, RUNCOREBOOT, mkdirs, bind
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

**Architecture install roots (`386/`, `amd64/`, `arm/`, …):**
- Purpose: Per-`$objtype` install targets: headers and (after build) binaries.
- Contains: `<arch>/include/u.h`, `<arch>/include/ureg.h`, `<arch>/include/ape/`, `<arch>/mkfile` (arch mk parameters: CC/AS/LD, `O` suffix), `<arch>/bin/` (populated by `mk install`; e.g. `386/bin`, `386/bbin`).
- Only `386/` and `arm/` ship populated `bin/` in-tree; `amd64/` currently ships headers+mkfile only.

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
- `build/build.bash`: Host-side build entry.

**Configuration:**
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
- Arch dirs are short cpu names: `386`, `amd64`, `arm`, `riscv64`, `power64`, `mips64`, `spim` (big-endian MIPS for simulator).
- Library dirs all carry the `lib` prefix; everything else in `sys/src/` is a subsystem (`cmd`, `boot`, `9k`, `ape`, `nboot`).
- Plan 9 toolchain naming: `<n>c`/`<n>a`/`<n>l` = compiler/assembler/linker for arch n (8=amd64, 6=386, 5=arm, 9=power64, 4/0 variants…) — sources in `sys/src/cmd/{4,5,6,8,9}{a,c,l}/`.

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

**`build/` outputs:**
- `harvey.tgz`, `9legacy.iso*`, final `plan9-new.iso.bz2` — build artifacts at repo root / build dir.
- Generated: Yes. Committed: No (`.gitignore` covers them).

**`sys/src/cmd/go/`:**
- Purpose: Fetches (not vendors) the Go toolchain repos needed at build time (`fetchrepos.sh`/`fetchrepos.rc`); Go binaries under `sys/go/bin/plan9_386` are used by `build.bash` inside the VM.
- Generated content: fetched repos. Committed: only the fetch scripts + mkfile.

**`sys/log/`:**
- Purpose: Per-service log directories (`auth`, `dns`, `httpd`, `fossil`, `ipboot`…) — empty scaffolding in repo, filled at runtime.
- Generated: partially (runtime). Committed: structure only.

**Per-arch `bin/` (`386/bin`, `arm/bin`, `386/bbin`):**
- Purpose: Install targets for `mk install` — binaries land here, named without extension.
- Generated: Yes (build output). Committed: some legacy binaries are in-tree.

---

*Structure analysis: 2026-10-30*
