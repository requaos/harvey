---
last_mapped_commit: bf084ee78de58b5f05b98235bb6e6887fde6e8c4
last_mapped_at: 2026-10-30
---
# Technology Stack

**Analysis Date:** 2026-10-30

## Project Identity

This is **Harvey OS** — a community fork / re-release of **Plan 9 from Bell Labs, 4th Edition** (originally Lucent, 2002). It is a complete operating system source tree: kernel, compilers, libraries, userspace commands, file servers, authentication services, and documentation. It is **not** a typical application — there is no `package.json`, no npm/cargo/go modules, and no conventional package manager. The build is driven by Plan 9's own `mk(1)` tool and a small set of bash/rc scripts.

See `README` for the project's own description, and `BUILD_ON_UNIX` + `build/README` for build entry points.

## Languages

**Primary:**
- **C (Plan 9 dialect)** — the overwhelming majority of the tree. Kernel (`sys/src/9/`, `sys/src/9k/`), all libraries (`sys/src/lib*/`), and nearly all userspace commands (`sys/src/cmd/`). Plan 9 C is pre-ANSI/ANSI C with Plan 9 extensions; it does **not** use POSIX headers. Sources include Plan 9 headers such as `<u.h>`, `<libc.h>`, `<9p.h>`, `<bio.h>` from `sys/include/`.
- **Rc shell** — Plan 9's shell. Used for system startup (`cfg/example/cpurc`, `cfg/example/termrc`), build scripts (`sys/src/cmd/go/fetchrepos.rc`, most `BUILD` files), and runtime services. The `rc/` directory at repo root holds rc libraries.

**Secondary:**
- **Assembly** — per-architecture kernel and runtime code (`*.s` files inside `sys/src/9/{pc,port,...}/`, `sys/src/9k/`, `sys/src/libc/{386,amd64,arm,...}/`). Assembled with the matching Plan 9 assembler (e.g. `6a` for amd64).
- **Yacc / Lex** — grammars in `sys/src/cmd/bc.y`, `sys/src/cmd/units.y`, `sys/src/cmd/upas/smtp/smtpd.y`, `sys/src/cmd/upas/smtp/rfc822.y`, `sys/src/cmd/cc/cc.y`. Generated via Plan 9 `yacc(1)` / `lex(1)`.
- **Bash / sh** — host-side build orchestration only: `build/build.bash`, `build/build-usb.bash`, `build/build-go.sh`, `build/BUILD_IN_DOCKER`, `sys/src/BUILD`, `sys/src/BUILDTOOLCHAIN`, `sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`. Not used at runtime on the target.
- **Go** — *not* used to build Harvey itself. The tree pulls Go programs in at image-build time (see `sys/src/cmd/go/`) to ship them inside the Harvey ISO. See "Key Dependencies" below.

## Runtime

**Target environment:** Bare metal or QEMU. Harvey boots on PC hardware (i386 / amd64) and several embedded/legacy architectures. There is no userspace "runtime" in the Java/Python sense — the C library is statically linked into every binary.

**Host build environment (for cross-building from Linux/macOS):**
- **plan9port** (`https://github.com/9fans/plan9port`) — provides `mk`, `rc`, `9c`/`pcc`, `sed`, `yacc`, `lex`, `awk` on the host. Must be installed and on `PATH` (`$PLAN9/bin`). Referenced by `BUILD_ON_UNIX` and `build/Dockerfile`.
- **QEMU** (`qemu-system-i386`, plus `qemu-utils` and `expect` on the host) — used by `build/build.bash` and `.github/workflows/harvey.yml` to boot a 9legacy ISO and run the in-OS build.
- **Go toolchain** (host) — `go get harvey-os.org/cmd/ufs` is run in CI to install the `ufs` 9P file server, which serves the Harvey tree to the build VM.
- **Docker** (optional) — `build/Dockerfile` builds an Ubuntu 21.10 image that pre-installs plan9port + the `9-cc` archiver.

**Package manager:** None. There is no dependency resolution or package manager; the entire system source is vendored in-tree. Third-party tools needed at build time (plan9port, 9-cc, Go repos) are fetched explicitly by scripts.

**Lockfile:** Not applicable.

## Compiler Toolchain (Plan 9 native)

Harvey uses the classic Plan 9 toolchain — one compiler/assembler/linker triple per architecture, all written in C and living in `sys/src/cmd/`:

| Arch | Assembler | Compiler | Linker | Source dir |
|------|-----------|----------|--------|------------|
| x86 (32-bit) | `8a` | `8c` | `8l` | `sys/src/cmd/8a`, `sys/src/cmd/8c`, `sys/src/cmd/8l` |
| amd64 | `6a` | `6c` | `6l` | `sys/src/cmd/6a`, `sys/src/cmd/6c`, `sys/src/cmd/6l` |
| ARM | `5a` | `5c` | `5l` | `sys/src/cmd/5a`, `sys/src/cmd/5c`, `sys/src/cmd/5l` |
| MIPS | `4a`/`va` | `4c`/`vc` | `4l`/`vl` | `sys/src/cmd/4a` … `sys/src/cmd/vl` |
| PowerPC | `9a`/`qa` | `9c`/`qc` | `9l`/`ql` | `sys/src/cmd/9a` … `sys/src/cmd/ql` |

The shared compiler frontend (common code generator) lives in `sys/src/cmd/cc/` (`cc.h`, `cc.y`, `com.c`, `com64.c`, `compat`). `sys/src/cmd/cpp/` is the C preprocessor. The bootstrap script `sys/src/BUILDTOOLCHAIN` builds `6a/6c/6l`, `8a/8c/8l`, `cpp`, and supporting tools.

An `iar` (Plan 9 `ar` port for the host) is built from the external `Harvey-OS/9-cc` repo and installed into `$HARVEY/linux_amd64/bin/ar` — see `BUILD_ON_UNIX` lines 7–16 and `build/Dockerfile` lines 49–81.

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
- **`build/`** — host-side orchestration:
  - `build/build.bash` — top-level Linux build (downloads `9legacy.iso`, boots QEMU, runs `rc build && rc repl && rc iso` inside the VM).
  - `build/Dockerfile` — Ubuntu 21.10 + plan9port + 9-cc image for reproducible builds.
  - `build/BUILD_IN_DOCKER` — entrypoint used inside the Docker image.
  - `build/scripts/` — rc scripts run inside the build VM (`build`, `repl`, `iso`, etc.).
  - `build/build-go.sh`, `build/build-usb.bash`, `build/make.bash`, `build/command.bash`, `build/mkdirs`.
  - `build/9-cc.patch` — local patch applied to the external `9-cc` repo when building `iar`.
- **`sys/src/BUILD`** — main in-tree driver: cleans, builds libs, builds everything, then invokes `$HARVEY/build/scripts/linux-build`.
- **`sys/src/BUILDTOOLCHAIN`** — builds the cross-compilers (6a/6c/6l, 8a/8c/8l, cpp, aux tools).
- **`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`** — uses `unshare -m` to run the build in a private mount namespace on Linux.
- **CI:** `.github/workflows/harvey.yml` — Ubuntu-latest, installs `rc qemu go-dep qemu-utils expect qemu-system-x86`, `go get harvey-os.org/cmd/ufs`, builds Go 1.16.6 for `GOOS=plan9 GOARCH=amd64`, then runs `bash command.bash` from `build/`.

## Key Dependencies

**Vendored / in-tree (no external fetch needed to compile):**
- All kernels, libraries, and commands listed above. The repository is self-contained C source.

**Fetched at build/image time:**
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

**Host tools (CI/Docker):** `git`, `curl`, `expect`, `qemu-system-i386`, `qemu-utils`, `tar`, `bzip2`, `bash`, `sudo`, `unshare` (from `util-linux`).

## Configuration

**Build-time environment variables** (set by scripts, not by `.env` files — no `.env` file exists in this repo):
- `HARVEY` — absolute path of the repo root. Used throughout `BUILD_ON_UNIX`, `build/Dockerfile`, `sys/src/BUILD`.
- `HARVEY_LINUX_BIN` — `$HARVEY/linux_amd64/bin` on a Linux host; location for the host-side `ar`, `pcc`, etc. (`build/Dockerfile` line 22).
- `PLAN9` — path to plan9port installation (typically `/usr/local/plan9`). See `BUILD_ON_UNIX` line 2.
- `objtype` — target architecture (`amd64`, `386`, `arm`, …). Drives which `$objtype/mkfile` is included.
- `ARCH`, `OS` — used by CI / build scripts to pick the right toolchain (`harvey.yml` lines 26–27).
- `FORCERCFORMK` — set by `sys/src/BUILD` to force mk to use `rc` for recipe execution.

**System configuration files (target-side, in-tree templates):**
- `cfg/example/termrc` — terminal startup rc script
- `cfg/example/cpurc` — CPU-server startup rc script
- `cfg/example/namespace` — namespace template
- `cfg/example/consoledb` — console configuration
- `cfg/pxe/` — PXE-boot configuration
- `lib/ndb/` — network database content (hosts, DNS, auth domains)
- `lib/namespace`, `lib/namespace.ftp`, `lib/namespace.httpd` — namespace templates for services

**Build configs:**
- `sys/src/mkfile`, `sys/src/mkfile.proto`
- Per-arch mk fragments included as `</$objtype/mkfile`
- `build/scripts/` — rc build stages
- `build/Dockerfile`, `build/BUILD_IN_DOCKER`

## Platform Requirements

**Development (host):**
- Linux (primary; CI uses `ubuntu-latest`, Dockerfile uses `ubuntu:21.10`) or macOS with plan9port
- `qemu-system-i386`, `expect`, `go`, `git`, `curl`, `gcc`/`build-essential`
- plan9port compiled and on `PATH`
- ~4 GB RAM for the build VM (`build/build.bash` passes `-m 4096`)
- KVM recommended on Linux (`build/build.bash` adds `-accel kvm` when `uname -s` is Linux)

**Target (what Harvey runs on):**
- Architectures with in-tree kernel support: `386/`, `amd64/`, `arm/`, `mips/`, `mips64/`, `power/`, `power64/`, `riscv/`, `riscv64/`, `sparc/`, `spim/`, `spim64/` (each contains per-arch `include/` and `mkfile`).
- Kernel ports live in `sys/src/9/` and `sys/src/9k/`:
  - `sys/src/9/pc` — x86 PC (i386/amd64)
  - `sys/src/9k/k10` — newer amd64 kernel
  - `sys/src/9/{bcm,omap,teg2,kw,mtx,rb,vt4,vt5}` — ARM/embedded ports (Raspberry Pi, OMAP, Tegra2, Kirkwood, etc.)
  - `sys/src/9/{loongson,loongson64}` — MIPS
  - `sys/src/9k/386`, `sys/src/9k/boot`, `sys/src/9k/mk` — additional ports
- Boot images: ISO produced by `rc iso` (see `build/build.bash` line 70) and PXE-boot support in `cfg/pxe/` and `sys/src/9/boot/`.

---

*Stack analysis: 2026-10-30*
