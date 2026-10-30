<!-- GSD:project-start source:PROJECT.md -->

## Project

**Harvey OS — Build Revival + aarch64 Port**

Harvey OS is a Plan 9 4th Edition derivative operating system (C, mk-based build, dual kernel trees: legacy `sys/src/9/` and active amd64 `sys/src/9k/`). This project revives the dormant upstream build (last upstream commit 2022-03-30), modernizes the dev environment with Nix, ports the userspace to aarch64 — and ultimately adopts **r9** (sibling repo `../r9`, a Rust reimplementation of the Plan 9 kernel) as Harvey's kernel, including adding/completing aarch64 support in r9 (qemu `-M virt`, beyond its current raspi3b/4b focus).

**Core Value:** Harvey userspace + r9 kernel boot to a shell on aarch64 under qemu virt — reproducible from clean checkouts on macOS or Linux.

### Constraints

- **Tech stack**: Plan 9 C dialect + mk (Harvey userspace); Rust no_std + cargo xtask (r9 kernel, sibling repo `../r9` — phases will work across both repos); host tools must build with plan9port (`$PLAN9/bin` LAST in PATH per BUILD_ON_UNIX)
- **Host platforms**: darwin-aarch64 (primary dev machine) and linux aarch64/x86_64; Harvey namespace build requires Linux mount namespaces (lima VM on macOS); r9 builds anywhere cargo+qemu run
- **Compatibility**: keep upstream Harvey/Plan 9 conventions (`sys/man/6/style`: tabs, lowercase, `nil`, `exits`/`sysfatal`); r9 follows its own rustfmt.toml
- **Naming**: the 64-bit ARM architecture is `aarch64` (not `arm64`) in this project's tooling and docs
- **Upstream**: dormant; this repo is now the maintained fork — in-tree fixes are preferred over external patch stacks
- **Licenses**: Harvey is MIT since 2021 (GPL only via ghostscript fonts); 9front imports are MIT — compatible

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Project Identity

## Languages

- **C (Plan 9 dialect)** — the overwhelming majority of the tree. Kernel (`sys/src/9/`, `sys/src/9k/`), all libraries (`sys/src/lib*/`), and nearly all userspace commands (`sys/src/cmd/`). Plan 9 C is pre-ANSI/ANSI C with Plan 9 extensions; it does **not** use POSIX headers. Sources include Plan 9 headers such as `<u.h>`, `<libc.h>`, `<9p.h>`, `<bio.h>` from `sys/include/`.
- **Rc shell** — Plan 9's shell. Used for system startup (`cfg/example/cpurc`, `cfg/example/termrc`), build scripts (`sys/src/cmd/go/fetchrepos.rc`, most `BUILD` files), and runtime services. The `rc/` directory at repo root holds rc libraries.
- **Assembly** — per-architecture kernel and runtime code (`*.s` files inside `sys/src/9/{pc,port,...}/`, `sys/src/9k/`, `sys/src/libc/{386,amd64,arm,...}/`). Assembled with the matching Plan 9 assembler (e.g. `6a` for amd64).
- **Yacc / Lex** — grammars in `sys/src/cmd/bc.y`, `sys/src/cmd/units.y`, `sys/src/cmd/upas/smtp/smtpd.y`, `sys/src/cmd/upas/smtp/rfc822.y`, `sys/src/cmd/cc/cc.y`. Generated via Plan 9 `yacc(1)` / `lex(1)`.
- **Bash / sh** — host-side build orchestration only: `build/build.bash`, `build/build-usb.bash`, `build/build-go.sh`, `build/BUILD_IN_DOCKER`, `sys/src/BUILD`, `sys/src/BUILDTOOLCHAIN`, `sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`. Not used at runtime on the target.
- **Go** — *not* used to build Harvey itself. The tree pulls Go programs in at image-build time (see `sys/src/cmd/go/`) to ship them inside the Harvey ISO. See "Key Dependencies" below.

## Runtime

- **plan9port** (`https://github.com/9fans/plan9port`) — provides `mk`, `rc`, `9c`/`pcc`, `sed`, `yacc`, `lex`, `awk` on the host. Must be installed and on `PATH` (`$PLAN9/bin`). Referenced by `BUILD_ON_UNIX` and `build/Dockerfile`.
- **QEMU** (`qemu-system-i386`, plus `qemu-utils` and `expect` on the host) — used by `build/build.bash` and `.github/workflows/harvey.yml` to boot a 9legacy ISO and run the in-OS build.
- **Go toolchain** (host) — `go get harvey-os.org/cmd/ufs` is run in CI to install the `ufs` 9P file server, which serves the Harvey tree to the build VM.
- **Docker** (optional) — `build/Dockerfile` builds an Ubuntu 21.10 image that pre-installs plan9port + the `9-cc` archiver.

## Compiler Toolchain (Plan 9 native)

| Arch | Assembler | Compiler | Linker | Source dir |
|------|-----------|----------|--------|------------|
| x86 (32-bit) | `8a` | `8c` | `8l` | `sys/src/cmd/8a`, `sys/src/cmd/8c`, `sys/src/cmd/8l` |
| amd64 | `6a` | `6c` | `6l` | `sys/src/cmd/6a`, `sys/src/cmd/6c`, `sys/src/cmd/6l` |
| ARM | `5a` | `5c` | `5l` | `sys/src/cmd/5a`, `sys/src/cmd/5c`, `sys/src/cmd/5l` |
| MIPS | `4a`/`va` | `4c`/`vc` | `4l`/`vl` | `sys/src/cmd/4a` … `sys/src/cmd/vl` |
| PowerPC | `9a`/`qa` | `9c`/`qc` | `9l`/`ql` | `sys/src/cmd/9a` … `sys/src/cmd/ql` |

## Frameworks

- `sys/src/libc/` — Plan 9 C library (per-arch under `libc/{386,amd64,arm,mips,mips64,power,power64,riscv,riscv64,sparc,spim,spim64}/`, portable code in `libc/9sys/`, `libc/port/`, `libc/fmt/`).
- `sys/src/lib9p/` — 9P file-protocol server framework. Header `sys/include/9p.h`.
- `sys/src/libbio/` — buffered I/O (`sys/include/bio.h`).
- `sys/src/libthread/` — cooperative threading.
- `sys/src/libmach/` — architecture abstraction, symbol tables, debug info (used by `acid` debugger).
- `sys/src/libndb/` — network database (`/lib/ndb`) parser.
- `sys/src/libdraw/`, `sys/src/libmemdraw/`, `sys/src/libmemlayer/` — drawing primitives, in-memory images, layered windows.
- `sys/src/libframe/` — text-frame widget used by `acme`, `sam`, `rio`.
- `sys/src/libcontrol/` — full widget toolkit (buttons, menus, text entries) used by GUI apps.
- `sys/src/libplumb/` — plumber client library (inter-app message bus).
- `sys/src/libip/` — IP helpers, dial/parse, protocol implementations.
- `sys/src/libhttpd/` — HTTP server framework (used by `sys/src/cmd/ip/httpd/`).
- `sys/src/libhtml/` — HTML parser.
- `sys/src/libsunrpc/` — Sun RPC (basis for NFS in `sys/src/cmd/9nfs/`, `sys/src/cmd/nfs.c`).
- `sys/src/liboventi/`, `sys/src/libventi/` — Venti archival-storage client (`sys/include/venti.h`, `oventi.h`).
- `sys/src/libsec/` — symmetric ciphers and PK crypto: AES, DES, 3DES, Blowfish, RC4, ChaCha, RSA, DSA, ElGamal, ECC, X.509/ASN.1, PEM. See `sys/src/libsec/port/` (e.g. `aes.c`, `chacha.c`, `dsagen.c`, `genprime.c`).
- `sys/src/libmp/` — multi-precision integer arithmetic backing libsec.
- `sys/src/libauth/`, `sys/src/libauthsrv/` — authentication protocols (p9sk1, p9cr, apop, chap, httpdigest, wep, wpapsk).
- `sys/src/libString/`, `sys/src/libavl/`, `sys/src/libbin/`, `sys/src/libcomplete/`, `sys/src/libdisk/`, `sys/src/libdynld/`, `sys/src/libflate/` (deflate/gzip), `sys/src/libframe/`, `sys/src/libgeometry/`, `sys/src/liblex/`, `sys/src/libregexp/`, `sys/src/libscribble/`, `sys/src/libstdio/` (ANSI-compat), `sys/src/libaml/` (ACPI machine language parser).

## Build System

- **`mk(1)`** — Plan 9's make. Every directory of interest has a `mkfile`. Top-level templates live in `sys/src/cmd/`:
- **`build/`** — host-side orchestration:
- **`sys/src/BUILD`** — main in-tree driver: cleans, builds libs, builds everything, then invokes `$HARVEY/build/scripts/linux-build`.
- **`sys/src/BUILDTOOLCHAIN`** — builds the cross-compilers (6a/6c/6l, 8a/8c/8l, cpp, aux tools).
- **`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`** — uses `unshare -m` to run the build in a private mount namespace on Linux.
- **CI:** `.github/workflows/harvey.yml` — Ubuntu-latest, installs `rc qemu go-dep qemu-utils expect qemu-system-x86`, `go get harvey-os.org/cmd/ufs`, builds Go 1.16.6 for `GOOS=plan9 GOARCH=amd64`, then runs `bash command.bash` from `build/`.

## Key Dependencies

- All kernels, libraries, and commands listed above. The repository is self-contained C source.
- **plan9port** (`9fans/plan9port`) — required on the host to provide `mk`, `rc`, host-side `9c/pcc`, `sed`, `yacc`, `lex`, `awk`, `date`. See `BUILD_ON_UNIX` and `build/Dockerfile` lines 29–42.
- **Harvey-OS/9-cc** (`0intro/9-cc`, patched by `build/9-cc.patch`) — provides `iar` used as the host `ar` for Plan 9-format archives. Cloned by `build/Dockerfile` (lines 49–54) and referenced in `BUILD_ON_UNIX`.
- **9legacy ISO** — `https://github.com/Harvey-OS/harvey/releases/download/9legacy/9legacy.iso.bz2`, downloaded by `build/build.bash` line 6 to bootstrap the build VM.
- **Go 1.16.6 source** (`golang/go`, branch `go1.16.6`) — cloned in CI (`.github/workflows/harvey.yml` line 21) and built for `GOOS=plan9 GOARCH=amd64`. Used to compile the Go programs shipped in the image.
- **Go programs shipped inside the image** (listed in `sys/src/cmd/go/commands`, fetched by `sys/src/cmd/go/fetchrepos.sh` / `fetchrepos.rc`):
- **`harvey-os.org/cmd/ufs`** — Go-based 9P file server, fetched by CI (`go get harvey-os.org/cmd/ufs` in `harvey.yml`) to serve the Harvey tree to the build VM.

## Configuration

- `HARVEY` — absolute path of the repo root. Used throughout `BUILD_ON_UNIX`, `build/Dockerfile`, `sys/src/BUILD`.
- `HARVEY_LINUX_BIN` — `$HARVEY/linux_amd64/bin` on a Linux host; location for the host-side `ar`, `pcc`, etc. (`build/Dockerfile` line 22).
- `PLAN9` — path to plan9port installation (typically `/usr/local/plan9`). See `BUILD_ON_UNIX` line 2.
- `objtype` — target architecture (`amd64`, `386`, `arm`, …). Drives which `$objtype/mkfile` is included.
- `ARCH`, `OS` — used by CI / build scripts to pick the right toolchain (`harvey.yml` lines 26–27).
- `FORCERCFORMK` — set by `sys/src/BUILD` to force mk to use `rc` for recipe execution.
- `cfg/example/termrc` — terminal startup rc script
- `cfg/example/cpurc` — CPU-server startup rc script
- `cfg/example/namespace` — namespace template
- `cfg/example/consoledb` — console configuration
- `cfg/pxe/` — PXE-boot configuration
- `lib/ndb/` — network database content (hosts, DNS, auth domains)
- `lib/namespace`, `lib/namespace.ftp`, `lib/namespace.httpd` — namespace templates for services
- `sys/src/mkfile`, `sys/src/mkfile.proto`
- Per-arch mk fragments included as `</$objtype/mkfile`
- `build/scripts/` — rc build stages
- `build/Dockerfile`, `build/BUILD_IN_DOCKER`

## Platform Requirements

- Linux (primary; CI uses `ubuntu-latest`, Dockerfile uses `ubuntu:21.10`) or macOS with plan9port
- `qemu-system-i386`, `expect`, `go`, `git`, `curl`, `gcc`/`build-essential`
- plan9port compiled and on `PATH`
- ~4 GB RAM for the build VM (`build/build.bash` passes `-m 4096`)
- KVM recommended on Linux (`build/build.bash` adds `-accel kvm` when `uname -s` is Linux)
- Architectures with in-tree kernel support: `386/`, `amd64/`, `arm/`, `mips/`, `mips64/`, `power/`, `power64/`, `riscv/`, `riscv64/`, `sparc/`, `spim/`, `spim64/` (each contains per-arch `include/` and `mkfile`).
- Kernel ports live in `sys/src/9/` and `sys/src/9k/`:
- Boot images: ISO produced by `rc iso` (see `build/build.bash` line 70) and PXE-boot support in `cfg/pxe/` and `sys/src/9/boot/`.

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- All lowercase, no underscores: `bread.c`, `bgetrune.c`, `devcons.c`
- One function (or a small tightly-related group) per file in libraries: `sys/src/libbio/` has `binit.c`, `bflush.c`, `brdline.c`, etc., each containing the function it is named after
- Commands are single files named after the command: `sys/src/cmd/cat.c`, `cp.c`, `tail.c`; multi-file commands get a directory: `sys/src/cmd/rio/`, `sys/src/cmd/fossil/`
- Headers named after their library: `sys/include/bio.h`, `sys/include/thread.h`
- Object/build naming is toolchain-suffixed, never `.o`: `$O` expands to the architecture character (`6` = amd64, `8` = 386, `5` = arm, etc.), so `bread.$O` → `bread.6`
- All lowercase, no underscores, often concatenated words: `copy1`, `dirstat`, `sysfatal`, `waserror`, `poperror`, `threadmain`
- Library functions carry a library prefix: `libbio` → `Bread`, `Binit`, `Bprint`, `Bflush`; `libdraw` → `drawsetdebug`... (prefix letters are uppercased in the libbio/libdraw family per `sys/include/bio.h`)
- Static helpers follow the same lowercase rule: `samefile` in `sys/src/cmd/cp.c`
- All lowercase, short: `dirb`, `todir`, `bout`, `icount`
- Flag variables suffixed with `flag`: `gflag`, `uflag`, `xflag` (see `sys/src/cmd/cp.c`)
- Global state named plainly: `failed`, `count`, `anycount` (see `sys/src/cmd/tail.c`)
- `struct` tags and their matching `typedef`s are Uppercase/Capitalized: `typedef struct Biobuf Biobuf;` (`sys/include/bio.h`), `QLock`, `Ref`, `Queue`, `Dir`, `Rune`
- `enum` and `#define` constants are Uppercase or UPPERCASE: `Binactive`, `Bractive`, `Bsize`, `UTFmax`, `DMDIR`, `OREAD`

## Code Style

- Tool: none enforced (no clang-format/indent config in tree). Style is by convention only; `sys/src/cmd/cb/` is the in-tree C beautifier but is not run automatically.
- **Tabs only** — never expand tabs to spaces (`sys/man/6/style` is explicit). Display width is a reader setting.
- No whitespace before opening braces; no whitespace after `if`, `for`, `while` keywords: `if(n < 0){`, `for(i=0; i<argc; i++){`
- Function definition return type on its own line, name at column 0:
- No braces around single-line blocks:
- Brace placement: opening `{` on the same line as `if`/`for`/function-body start; `} else {` as separate `}else{` or split lines varies by file — match the file you are editing.
- Surround binary operators (especially low-precedence) with spaces; favor readability over compactness. Historical code is tighter (`if(n<0)`); match the surrounding file.
- Parenthesize expressions mixing arithmetic and bit-wise operators; otherwise parenthesize lightly.
- Standard idioms: write `x < 0`, not `0 > x`.
- Never write `!strcmp(...)` or `if(memcmp(...))` — always compare explicitly with a relational operator: `if(strcmp(a,b) == 0)`.
- Automatic variables are **never initialized at declaration** (per style(6)); assign on a separate line. (Some older files violate this — follow the file.)
- Block comments only: `/* ... */`. Do not introduce `//` comments (style(6): existing `//` usage is being converted away; `//` is acceptable only to comment out a few lines of code).
- A one- or two-line comment above a function explaining what it does is welcome; no Javadoc/Doxygen machinery anywhere in the tree.
- Comment anything that takes >2 seconds to understand — explain *why*, not what.
- `#pragma lib "libbio.a"` / `#pragma src "/sys/src/libbio"` at top of public headers (`sys/include/bio.h`, `sys/include/libc.h`)
- `#pragma varargck argpos fprint 2` — registers printf-like functions for format checking (`sys/include/libc.h:171-180`)
- There are **no `#ifndef` header guards** in Plan 9 headers; the compilers tolerate multiple inclusion of identical declarations. Do not add guards.

## Import Organization

#include <u.h>
#include <libc.h>
#include	"u.h"
#include	"../port/lib.h"
#include	"mem.h"
#include	"dat.h"
#include	"fns.h"
#include	"../port/error.h"
#include	"pool.h"
- None. Includes resolve via the compiler's `-I` search into `/sys/include` and `/$objtype/include`; source-relative paths like `../port/lib.h` are used directly.

## Error Handling

- Integer-valued functions return `-1` on error, 0 or positive on success (style(6))
- Functions that fail must set the error string via `errstr(2)` mechanisms (`werrstr`, `%r` format verb) — callers print the cause with the `%r` verb
- Fatal errors: `sysfatal("can't open %s: %r", argv[i]);` — prints and exits (implementation `sys/src/libc/9sys/sysfatal.c`); see `sys/src/cmd/cat.c`, `aan.c`
- Non-fatal diagnostics go to stderr via `fprint(2, "cp: can't stat %s: %r\n", from);` and a flag variable (`failed`) is set; at end, `exits("errors")` — see `sys/src/cmd/cp.c`
- Exit via `exits(0)` / `exits("message")`, **never** `exit()`; a nil/zero arg means success, a string means failure (the string becomes the process's exit status)
- Bad invocation: print `usage: ...` to stderr and `exits("usage")` — conventionally via a `goto usage;` block at the bottom of `main` (see `sys/src/cmd/cp.c:50-54`)
- Error propagation via longjmp-style exception blocks:
- Raise errors with `error(Esomething)`; error strings centralized in `sys/src/9/port/error.h`
- Check every system call that can fail
- On resource-acquisition failure, report `%r` (the errstr) so the real cause is shown
- Do not invent return-code enums; use `-1`/non-negative plus errstr

## Logging

- Diagnostics: `fprint(2, ...)` to stderr, prefixed with program name: `"cp: ..."`
- `%r` verb to append the current error string
- Kernel: `print`/`iprint` to the console; conditional debug output guarded by static flag variables (e.g., `consdebug`, `iprintscreenputs` in `sys/src/9/port/devcons.c`)
- Do not add syslog-style severity levels; the codebase has no such concept

## Comments

- One or two lines above a function describing what it does
- Non-obvious invariants, magic numbers, protocol quirks — explain *why*
- File-top comment blocks describe the program's purpose when needed (`sys/src/cmd/tail.c` has a short one)
- Not applicable — no structured doc comments exist anywhere. Documentation lives in man pages under `sys/man/` (troff format, e.g. `sys/man/6/style`), not in source.

## Function Design

- Few parameters; pass pointers to structs (`Dir *`, `Biobufhdr *bp`) rather than long scalar lists
- Output via caller-allocated buffers with explicit sizes: `char *strecpy(char*, char*, char*)` (dst, dst-end, src) — note the end-pointer idiom, safer than `strncpy`
- Variadic printf-style functions must be registered with `#pragma varargck`
- `-1` + errstr for failure; `nil` for pointer-returning functions on failure
- Success: 0, positive count, or valid pointer
- `nil` is defined in `amd64/include/u.h` as `((void*)0)` — always use `nil`, never `NULL`
- User-space concurrency uses libthread (`sys/include/thread.h`): entry point is `threadmain(int argc, char *argv[])` instead of `main` when linking `-lthread` (see `sys/src/cmd/rio/rio.c:119`)
- Channels (`Channel*`, `chansend`/`chanrecv`) preferred over shared memory in threaded programs

## Module Design

- Public API declared in a single header per library under `sys/include/<name>.h`
- Declarations use explicit `extern` and tabbed alignment:
- Header begins with `#pragma src "/sys/src/lib<name>"` and `#pragma lib "lib<name>.a"`
- Every directory has a `mkfile`; first line is `</$objtype/mkfile` which pulls in `sys/src/mkfile.proto` (sets `CFLAGS=-FTVw`, `CPUS`, `OS`) and the arch toolchain file (`amd64/mkfile` sets `CC=6c LD=6l O=6 AS=6a`)
- Libraries: list `OFILES` with `$O` suffix and `LIB=/$objtype/lib/libX.a`, then include `</sys/src/cmd/mksyslib` — see `sys/src/libbio/mkfile`
- Single-program commands: include `</sys/src/cmd/mkone`; multi-program directories: list `TARG` and include `</sys/src/cmd/mkmany` (see `sys/src/cmd/mkone`, `mkmany`)
- Standard targets everywhere: `all`, `install`, `clean`, `nuke`, `update`, `installall`; some add `safeinstall`
- Recursion pattern from `sys/src/mkfile`: `for(i in $LIBS $SUBSYS $CMDS)@{ cd $i; mk $target }` — note rc-shell `@{...}` blocks inside mkfiles
- Not used. Header-per-library is the aggregation mechanism.
- Compilers are the Plan 9 toolchain (`6c`, `8c`, etc.) — dialect is ANSI C with Plan 9 extensions (struct embedding like `QLock;` as an anonymous member in `sys/src/9/port/devcons.c`, designated initializers, `USED`/`SET` macros for silencing unused warnings)
- `ARGBEGIN { ... } ARGEND` macros from `sys/include/libc.h:741-756` are the standard flag-parsing idiom; use `EARGF(usage())` for flags with arguments (see `sys/src/cmd/cp.c`, `sys/src/cmd/grep/main.c`)
- `goto` is avoided per style(6), but `goto usage;` for usage errors is an accepted idiom in existing commands

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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
| Host build harness | Builds Harvey ISO by booting Plan 9 under QEMU | `build/` |

## Pattern Overview

- **File-oriented IPC:** All resources (network, windows, processes, auth, graphics) are presented as files served over 9P2000 (`sys/include/fcall.h`, `sys/include/9p.h`). User programs `bind`/`mount` these into their private namespace.
- **Per-process namespaces:** Each process group has its own mount table (`sys/src/9k/port/pgrp.c`, `sys/src/9k/port/chan.c`). There is no single global file tree — the view of the system is constructed per-process via `bind(2)`/`mount(2)`.
- **Device = vtable:** Kernel devices implement the `Dev` struct interface (reset/init/attach/walk/stat/open/read/write/close…) declared in `sys/src/9k/port/portdat.h` (~line 198). The `devtab[]` array is *generated* from declarative kernel config files.
- **Kernel split:** portable vs. machine-dependent. All portable logic lives in `port/`; arch code lives in a sibling dir (`k10/`, `386/`). The mk build merges them via `../mk/portmkfile` + `../mk/bootmkfile` + an awk `parse` of the config file.
- **User-space file servers:** Services that would be kernel subsystems elsewhere (DNS, auth, ftp, http, web, wiki) run as user processes using `lib9p` and are mounted over 9P. The kernel's `devmnt.c` is the 9P *client* that glues mounts into the namespace.
- **rfork process model:** Process creation is `rfork(flags)` with fine-grained sharing flags (RFPROC, RFNAMEG, RFENVG, RFNOTEG…), not fork/exec. Threads via `libthread` build on this.
- **Note-based async:** Instead of Unix signals, Plan 9 uses textual "notes" posted to a process (`atnotify`, `noted` in libc; `sys/src/9k/port/proc.c`).

## Layers

- Purpose: Architecture-independent OS services — processes, channels (name resolution), device dispatch, queues, paging/segments, syscall handlers, portable device drivers (console, env, pipe, proc, mnt, srv, ssl/tls, root fs, sd storage, uart core, draw/mouse).
- Location: `sys/src/9k/port/` (62 `.c` files)
- Contains: `proc.c` (scheduler), `chan.c` (name channeling / namespace resolution), `dev.c` (dev dispatch), `qio.c` (queued I/O), `page.c`/`segment.c` (VM), `sysfile.c` (file syscalls: sysopen, sysbind, sysmount, sysnmount…), `sysproc.c` (process syscalls), `qlock.c`/`taslock.c` (locking), `qmalloc.c` (kernel alloc), `devmnt.c` (9P mount client), `devroot.c` (embedded boot root fs), `edf.c` (earliest-deadline-first scheduler), `portdat.h`/`portfns.h` (portable kernel data/prototypes).
- Depends on: machine layer (`k10/`) for MMU, traps, clock, FPU.
- Used by: linked into every kernel config (see `OBJ=$MACH $CONF.root.$O $DEVS $PORT` in `sys/src/9k/k10/mkfile:15`).
- Purpose: Everything hardware-specific for a CPU family/board.
- Location: `sys/src/9k/k10/` (amd64; 55 files), `sys/src/9k/386/` (i386 drivers)
- Contains: `main.c` (kernel entry `main(u32int ax, u32int bx)` at line 145 — multiboot), `mmu.c`, `trap.c`, `fpu.c`, `apic.c`/`ioapic.c`, `mp.c`/`sipi.c` (SMP startup), `memory.c`, assembly entry/interrupt/syscall stubs (`l64v.s`, `l64idt.s`, `l64syscall.s`, `l64sipi.s`, `l32p.s`), `arch.c`, drivers (`devvga.c`, `devacpi.c`, `i8254.c`, `i8259.c`, `hpet.c`), and kernel config files (`k10cpu`, `k10cpuf`, `k10aoe`, `k10root`).
- Depends on: `port/` APIs; libc subset in kernel (`port/lib.h`).
- Used by: linked with `port/` objects per config.
- Purpose: Generates per-config kernel sources: `parse` (awk) reads a config file (`k10cpu`) and emits `$CONF.c` (devtab + linktab + root fs table), `bootmkfile`/`portmkfile` supply mk rules, `mkroot`/`mkrootall` build the embedded boot root image.
- Location: `sys/src/9k/mk/`
- Consumed by: `sys/src/9k/k10/mkfile` (`<| awk -f ../mk/parse $CONF` at line 11).
- Purpose: The single C library for all native programs.
- Structure: `port/` (112 portable `.c` files: string, fmt/printf, math, dir ops, regexp glue, pool allocators), `9sys/` (syscall wrappers: `open.c`, `mount.c`, `bind.c`, `dial.c`, `convM2S.c`/`convS2M.c` for 9P messages), `9syscall/sys.h` (syscall number table — BIND=2, MOUNT=46, NMOUNT added by Harvey), `fmt/` (printf family), per-arch dirs (`amd64/`, `386/`, `arm/`, `riscv/`, …) with assembly implementations (`memcpy.s`, `setjmp.s`, `tas.s`, `main9.s` startup).
- Headers: `sys/include/libc.h` plus per-arch `u.h` (`amd64/include/u.h`, `386/include/u.h`) and `ureg.h`.
- Purpose: All userland — from `cat.c`/`cp.c` to subsystems: `ip/` (TCP/IP stack daemons), `auth/` (authentication server + factotum), `ndb/` (network database), `fossil`/`venti` (archival file servers), `acme/` (editor/window system), `rio` (window manager), `sam`, `webfs`, `wikifs`, `upas/` (mail), `aux/`, compilers/assemblers/linkers per arch (`8c/8a/8l` = amd64 compiler/asm/linker, `5c` = arm, `6c` family…), `go/` (Go toolchain fetch scripts), `mk` (build tool), `rc` (shell).
- Depends on: libc + specialized libs (`lib9p`, `libthread`, `libdraw`, `libmemdraw`, `libbio`, `libsec`, `libmp`, `libauth`, `libndb`…).
- Purpose: POSIX compatibility layer for ported Unix software (its own libc, headers, and commands like diff/patch/sh).
- Contains: `lib/` (ape libc), `cmd/` (ported GNU/BSD tools), `9src/` (X11R5 etc.), `config/`.
- Note: APE programs are second-class citizens; native code uses Plan 9 APIs directly.
- `sys/src/boot/efi/` — EFI application: walks ISO/FAT filesystems, loads kernel + `plan9.ini` from ESP, sets up framebuffer, jumps to kernel entry. `iso.c` contains the ISO9660 walker (`isowalk`).
- `sys/src/nboot/` — newer boot loader tree (efi, pc).
- `sys/src/9k/boot/` — the `boot` user program embedded in/loaded with the kernel: performs authentication (`bootauth.c`, `doauthenticate.c`), finds the root (`local.c`, `bootip.c`), then execs init.

## Data Flow

### Primary Request Path (file open → device)

### Boot Flow (amd64)

### Network Path (TCP/IP)

- Kernel global singletons exist and are deliberate: `Sys* sys` (system structure, `k10/main.c:17`), `conf` (config), per-CPU `Mach*` (`m` macro), device state in each `dev*.c`. `extern Mach *m;` per-CPU pointer is the threading model.
- User state: environment variables are files in `/env` (`devenv.c`); process control via `/proc` (`devproc.c`).

## Key Abstractions

- Purpose: The kernel's open-file handle — the result of name resolution; every operation on a file goes through a `Chan`.
- Examples: `sys/src/9k/port/chan.c` (`cclose` line 378, `addelem` line 287 — union directory resolution)
- Pattern: Ref-counted, linked to a `Dev` + qid path; mount points stitch Chan trees together (`Mount` struct in `pgrp.c`).
- Purpose: Uniform interface for kernel devices — the table-driven polymorphism at the heart of "everything is a file".
- Examples: `sys/src/9k/port/portdat.h:198` (struct Dev), drivers `devcons.c`, `devpipe.c`, `devmnt.c`, `devproc.c`, `devdraw.c`, `devtls.c`; registration list generated from kernel config (`sys/src/9k/k10/k10cpu` `dev` section) by `sys/src/9k/mk/parse`.
- Pattern: One C file per device named `dev<name>.c`; init order follows `devtab[]` (`port/devtab.c`).
- Purpose: Wire format of 9P2000 — every file operation becomes T/R message pairs (Tversion, Tattach, Twalk, Topen, Tread…).
- Examples: `sys/include/fcall.h`, codec in `sys/src/libc/9sys/convM2S.c` + `convS2M.c`, server-side helpers in `sys/src/lib9p/`.
- Purpose: Framework for writing user-space file servers: define a `Srv` struct with attach/walk/read/write hooks and a `FileTree`, then `postmountsrv()` mounts it into the namespace.
- Examples: `sys/src/lib9p/srv.c`, `file.c`, `listen.c`, `post.c`; canonical trivial server `sys/src/lib9p/ramfs.c`; real servers: `sys/src/cmd/webfs/`, `sys/src/cmd/wikifs/`.
- Purpose: Process abstraction with composable sharing.
- Examples: `sys/src/9k/port/proc.c`, `sysproc.c` (`sysrfork`), user wrappers `sys/src/libc/9sys/rfork.c` / `fork.c`.
- Pattern: `rfork(RFPROC|RFMEM|RFNAMEG|…)` selects what child shares; `libthread` layers coroutines + channels (`sys/src/libthread/channel.c`) on top.
- Purpose: Virtual memory — address spaces are lists of `Segment`s (text, data, bss, stack, mapped files) backed by `Image`s (demand-paged from files).
- Examples: `sys/src/9k/port/segment.c`, `page.c`, `image.c`, machine MMU in `k10/mmu.c`.
- Purpose: Unique file identity (`Qid`: path+vers+type) and portable directory entry `Dir` — the 9P metadata currency.
- Examples: `sys/include/libc.h`, `sys/src/libc/9sys/convM2D.c`, `dirstat.c`.

## Entry Points

- Location: `sys/src/9k/k10/main.c` — `main(u32int ax, u32int bx)` at line 145 (multiboot magic + params)
- Triggers: EFI loader (`sys/src/boot/efi/efi.c`) or multiboot/nboot chain; asm entry `l64v.s`/`l32p.s` sets up stack/long mode first.
- Responsibilities: Machine init → portable kernel init (`port/`) → spawn first user process (`boot`).
- Location: `sys/src/9k/boot/boot.c` (`main`), helpers `bootauth.c`, `bootip.c`, `local.c`
- Triggers: Exec'd by kernel `init0` as pid 1 from embedded root.
- Responsibilities: Root filesystem selection (local/tcp), authentication handshake, then exec of system init.
- Location: `sys/src/9k/root/rcmain` (embedded), `rc/bin/termrc`, `rc/bin/cpurc`
- Triggers: Exec'd by `boot`.
- Responsibilities: Build the default namespace (`/lib/namespace`), start services (`factotum`, network, `rio`/`acme` on terminals).
- Location: `sys/src/cmd/<name>.c` (single-file) or `sys/src/cmd/<name>/` (multi-file with mkfile).
- Convention: `void main(int argc, char *argv[])`, use `ARGBEGIN{...}ARGEND` macro for flags (Plan 9 style), exit via `exits("msg")`.
- Location: `build/build.bash` (QEMU + expect harness), `build/scripts/` (`build`, `repl`, `iso`, `main`, `funcs`), Docker path: `build/Dockerfile`, `build/BUILD_IN_DOCKER`.
- Triggers: `bash build.bash` from `build/`. Requires a host 9P server (`ufs`/`centre`) on port 5640 to receive the ISO (`build/README`).
- Native (on Plan 9/Harvey): `sys/src/BUILD` runs `mk libs && mk all`, then `build/scripts/linux-build`.
- Location: `sys/src/9k/k10/mkfile` — targets like `9k` build `9k10cpu` (mk var `p=9`, `CONF=k10cpu`).
- Triggers: `mk 9k` in `sys/src/9k/k10/`. Uses Plan 9 toolchain `8c/8a/8l` (`objtype=amd64`, line 5).

## Architectural Constraints

- **Threading:** Kernel is a single-stack-per-CPU cooperative/preemptive hybrid: processes are kernel coroutines scheduled by `proc.c`; per-CPU `Mach` state, `taslock.c` test-and-set spinlocks + `qlock.c` queueing locks; `Rendez` sleep/wakeup (`sleep`/`wakeup`). User space: `libthread` coroutines + channels, or raw `rfork(RFPROC)` procs. No pthreads in native code (APE has its own).
- **Global state:** Kernel singletons are idiomatic: `Sys *sys` (`k10/main.c:17`), `conf`, `devtab[]` (generated), per-device state structs at file scope in each `dev*.c`, `Mach *m` per-CPU. Do not add process-specific data to device globals — use `Chan`/`qid` private fields.
- **Toolchain:** Plan 9's own C compiler suite (`8c` amd64, `6c` 386…), NOT gcc/clang for native code. Dialect: Plan 9 C (no prototypes needed across files — `fns.h`/`portfns.h` collect them; `#pragma` variants; `void` returns default). Headers included as `u.h` → `libc.h` → `../port/lib.h` in kernel.
- **Build tool:** `mk` (not make). All builds via `mkfile` + includes (`</$objtype/mkfile`, `mkfile.proto`).
- **Cross-arch includes:** per-arch headers resolved via `/$objtype/include` (e.g., `amd64/include/u.h`, `ureg.h`) — code references them as absolute `/amd64/include/...` paths inside the Plan 9 namespace.
- **Circular imports:** Kernel `port/` ↔ machine dirs interdepend by design (`port/lib.h` included from machine code; machine provides `fns.h`/`dat.h`/`mem.h` consumed by port). The mk layer resolves ordering; do not add new reverse deps beyond the established header triad (`dat.h`/`fns.h`/`mem.h` per arch).
- **Two kernels coexist:** `sys/src/9/` (legacy, full multi-arch) vs `sys/src/9k/` (Harvey, amd64/386 focus). New work targets `9k`. Shared libs (libc etc.) serve both.

## Anti-Patterns

### Mixing portable and machine code

### Bypassing the namespace with hardcoded paths in C

### Using APE/POSIX APIs in native code

## Error Handling

- Kernel: `error("message")` raises (`port/error.h`, `sys/src/9k/port/proc.c` unwinds via `nexterror()`/`poperror()`); `waserror()` guards resource cleanup. `kerror` for kernel-originated failures.
- User: functions return -1/nil and set thread-local errstr; caller checks with `errstr(buf, n)` (`sys/src/libc/9sys/errstr.c`); `exits("diagnostic")` terminates with a status string consumed by `wait`/`await`.
- Notes: async conditions arrive as textual notes ("hangup", "alarm", "sys: trap: …"); programs install `atnotify()` handlers (`sys/src/libc/port/atnotify.c`).
- No errno. No exceptions. Assertions via `assert()` (`_assert.c`) or `panic()` in kernel for unrecoverable state.

## Cross-Cutting Concerns

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
