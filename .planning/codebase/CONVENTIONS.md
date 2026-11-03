---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
# Coding Conventions

**Analysis Date:** 2026-11-03

This is a Plan 9 (4th Edition / Harvey-lineage) C codebase. The authoritative style guide ships with the tree at `sys/man/6/style` ("style - Plan 9 coding conventions for C"). All rules below are derived from that document and confirmed against the actual sources. **Read `sys/man/6/style` before writing C here.**

## Project-Level Rules (AGENTS.md)

These constraints are recorded in `AGENTS.md` (Constraints section) and enforced by the tooling:

- **Architecture naming:** the 64-bit ARM architecture is `aarch64`, **never** `arm64`, in this project's tooling, docs, file names, and `objtype` values. Host scripts normalize `uname -m` output: `[ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64` (`flake.nix:129`, `nix/setup.sh:13`, `nix/toolchain.sh:8`, `nix/build.sh:14`, `nix/vm-build.sh`, `build/aarch64/subset-build.sh:96`).
- **plan9port PATH ordering:** `$PLAN9/bin` goes **LAST** in `PATH` per `BUILD_ON_UNIX` — plan9port ships a 9p `mount` (and `sed`, `grep`, `date` dialects) that must not shadow host tools. See `flake.nix:25-28` and the devshell hook (`flake.nix:135-136`). Scripts that must guarantee it re-strip and re-append explicitly: `build/aarch64/mkimage.sh:48-55`, `build/aarch64/mkpaqfs-host.sh:26-30`.
- **Repo boundary with r9:** the r9 kernel is a **separate repo consumed as a pinned flake input** — `inputs.r9.url = "github:requaos/r9"` (`flake.nix:11`), exact rev + narHash locked in `flake.lock` (rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`, narHash `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`). Shipped tooling consumes ONLY `r9.packages.<system>.kernel-virt` **store paths** exported as `R9_KERNEL_PKG` (`flake.nix:83-87,93-97`); no sibling-checkout path appears in any shipped script (INT-04/T-05-21 — `nix/boot-r9.sh:33-44`, `build/aarch64/run-r9.sh:8-20` — kernel/DTB env vars are REQUIRED, no defaults by design). A local sibling checkout at `../r9` is a **dev-only** flow: `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` (D-13, `flake.nix:9-10`); r9's own tooling locates this repo via `R9_HARVEY_DIR` (default `../harvey`, `aarch64/ABI.md:130-135`). Each repo keeps its own conventions: Harvey C follows `sys/man/6/style`; r9 Rust follows its own `rustfmt.toml`. Do not copy files across the boundary without an explicit port decision.
- **Upstream is dormant:** this repo is the maintained fork — prefer in-tree fixes over external patch stacks.
- **Style compatibility:** keep upstream Harvey/Plan 9 conventions — tabs, lowercase, `nil`, `exits`/`sysfatal` (`AGENTS.md` Constraints).

## Naming Patterns

**Files:**
- All lowercase, no underscores: `bread.c`, `bgetrune.c`, `devcons.c`
- One function (or a small tightly-related group) per file in libraries: `sys/src/libbio/` has `binit.c`, `bflush.c`, `brdline.c`, etc., each containing the function it is named after
- Commands are single files named after the command: `sys/src/cmd/cat.c`, `cp.c`, `tail.c`; multi-file commands get a directory: `sys/src/cmd/rio/`, `sys/src/cmd/fossil/`
- Headers named after their library: `sys/include/bio.h`, `sys/include/thread.h`
- Object/build naming is toolchain-suffixed, never `.o`: `$O` expands to the architecture character (`6` = amd64, `8` = 386, `5` = arm, `7` = aarch64), so `bread.$O` → `bread.6`
- Per-architecture directories are named by the `objtype` string at repo root: `amd64/`, `386/`, `aarch64/` — each with `include/`, `bin/`, `lib/`, `mkfile` (see `aarch64/`)

**Functions:**
- All lowercase, no underscores, often concatenated words: `copy1`, `dirstat`, `sysfatal`, `waserror`, `poperror`, `threadmain`
- Library functions carry a library prefix: `libbio` → `Bread`, `Binit`, `Bprint`, `Bflush`; `libdraw` → `drawsetdebug`... (prefix letters are uppercased in the libbio/libdraw family per `sys/include/bio.h`)
- Static helpers follow the same lowercase rule: `samefile` in `sys/src/cmd/cp.c`

**Variables:**
- All lowercase, short: `dirb`, `todir`, `bout`, `icount`
- Flag variables suffixed with `flag`: `gflag`, `uflag`, `xflag` (see `sys/src/cmd/cp.c`)
- Global state named plainly: `failed`, `count`, `anycount` (see `sys/src/cmd/tail.c`)

**Types:**
- `struct` tags and their matching `typedef`s are Uppercase/Capitalized: `typedef struct Biobuf Biobuf;` (`sys/include/bio.h`), `QLock`, `Ref`, `Queue`, `Dir`, `Rune`, `Ureg` (`aarch64/include/ureg.h:1`)
- `enum` and `#define` constants are Uppercase or UPPERCASE: `Binactive`, `Bractive`, `Bsize`, `UTFmax`, `DMDIR`, `OREAD`, `FPINEX`, `FPRMASK` (`aarch64/include/u.h:30-41`)
- Fixed-width integer typedefs carry their width: `u8int`, `u16int`, `u32int`, `u64int`, `s8int`…`s64int`, `vlong`/`uvlong` (`aarch64/include/u.h:20-27`)

## Code Style

**Formatting:**
- Tool: none enforced (no clang-format/indent config in tree). Style is by convention only; `sys/src/cmd/cb/` is the in-tree C beautifier but is not run automatically.
- **Tabs only** — never expand tabs to spaces (`sys/man/6/style` is explicit). Display width is a reader setting. This applies to C, headers (`aarch64/include/u.h` aligns typedefs with tabs), and mkfiles (`aarch64/mkfile`).
- No whitespace before opening braces; no whitespace after `if`, `for`, `while` keywords: `if(n < 0){`, `for(i=0; i<argc; i++){`
- Function definition return type on its own line, name at column 0:
  ```c
  void
  main(int argc, char *argv[])
  {
  ```
- No braces around single-line blocks:
  ```c
  if(dirb!=nil && (dirb->mode&DMDIR))
      todir=1;
  ```
- Brace placement: opening `{` on the same line as `if`/`for`/function-body start; `} else {` as separate `}else{` or split lines varies by file — match the file you are editing.

**Expressions:**
- Surround binary operators (especially low-precedence) with spaces; favor readability over compactness. Historical code is tighter (`if(n<0)`); match the surrounding file.
- Parenthesize expressions mixing arithmetic and bit-wise operators; otherwise parenthesize lightly.
- Standard idioms: write `x < 0`, not `0 > x`.
- Never write `!strcmp(...)` or `if(memcmp(...))` — always compare explicitly with a relational operator: `if(strcmp(a,b) == 0)`.
- Automatic variables are **never initialized at declaration** (per style(6)); assign on a separate line. (Some older files violate this — follow the file.)

**Comments:**
- Block comments only: `/* ... */`. Do not introduce `//` comments (style(6): existing `//` usage is being converted away; `//` is acceptable only to comment out a few lines of code).
- A one- or two-line comment above a function explaining what it does is welcome; no Javadoc/Doxygen machinery anywhere in the tree.
- Comment anything that takes >2 seconds to understand — explain *why*, not what. In headers, trailing comments annotate fields: `u64int r28; /* sb */`, `u64int pc; /* interrupted addr */` (`aarch64/include/ureg.h:30,37`).

**Pragmas (Plan 9 C compiler extensions — do not remove):**
- `#pragma lib "libbio.a"` / `#pragma src "/sys/src/libbio"` at top of public headers (`sys/include/bio.h`, `sys/include/libc.h`)
- `#pragma varargck argpos fprint 2` — registers printf-like functions for format checking (`sys/include/libc.h:171-180`)
- There are **no `#ifndef` header guards** in Plan 9 headers; the compilers tolerate multiple inclusion of identical declarations. Do not add guards. (`aarch64/include/u.h`, `ureg.h` have none.)

## Import Organization

**Order (user code):**
1. `#include <u.h>` — always first (architecture types: `uchar`, `vlong`, `Rune`, `nil`; lives at `amd64/include/u.h`, `386/include/u.h`, `aarch64/include/u.h`, etc.)
2. `#include <libc.h>` — the core user library (`sys/include/libc.h`)
3. Other library headers as needed: `<bio.h>`, `<draw.h>`, `<thread.h>`

Canonical prologue of every command (`sys/src/cmd/cat.c`):

```c
#include <u.h>
#include <libc.h>
```

**Kernel code** (`sys/src/9/`) uses quoted includes in a fixed order (see `sys/src/9/port/devcons.c`):

```c
#include	"u.h"
#include	"../port/lib.h"
#include	"mem.h"
#include	"dat.h"
#include	"fns.h"
#include	"../port/error.h"
#include	"pool.h"
```

**Path Aliases:**
- None. Includes resolve via the compiler's `-I` search into `/sys/include` and `/$objtype/include`; source-relative paths like `../port/lib.h` are used directly.

## Error Handling

**User space conventions:**
- Integer-valued functions return `-1` on error, 0 or positive on success (style(6))
- Functions that fail must set the error string via `errstr(2)` mechanisms (`werrstr`, `%r` format verb) — callers print the cause with the `%r` verb
- Fatal errors: `sysfatal("can't open %s: %r", argv[i]);` — prints and exits (implementation `sys/src/libc/9sys/sysfatal.c`); see `sys/src/cmd/cat.c`, `aan.c`
- Non-fatal diagnostics go to stderr via `fprint(2, "cp: can't stat %s: %r\n", from);` and a flag variable (`failed`) is set; at end, `exits("errors")` — see `sys/src/cmd/cp.c`
- Exit via `exits(0)` / `exits("message")`, **never** `exit()`; a nil/zero arg means success, a string means failure (the string becomes the process's exit status)
- Bad invocation: print `usage: ...` to stderr and `exits("usage")` — conventionally via a `goto usage;` block at the bottom of `main` (see `sys/src/cmd/cp.c:50-54`)

**Kernel conventions** (`sys/src/9/`):
- Error propagation via longjmp-style exception blocks:
  ```c
  if(waserror()){
      /* cleanup */
      nexterror();
  }
  ...
  poperror();
  ```
  See `sys/src/9/port/devcons.c:340-343`
- Raise errors with `error(Esomething)`; error strings centralized in `sys/src/9/port/error.h`

**Host-side shell scripts** (`nix/*.sh`, `build/*.bash`, `build/aarch64/*.sh`):
- Every flake app script runs under `set -euo pipefail` (injected by `mkScriptApp` in `flake.nix:23`); standalone `build/aarch64/*.sh` scripts set their own `set -eu`/`set -e` at the top (`subset-build.sh:68`, `mkimage.sh:34`, `run-r9.sh:43`, `stage-build.sh:20`); `nix/build.sh` additionally sets `set -e` at line 9 with a comment explaining why silent failure is dangerous
- The standard loud-failure idiom is an `err()` helper — `err() { echo "error: $*" >&2; exit 1; }` — defined right after the sanity checks (`nix/boot-r9.sh:61`, `nix/smoke-r9.sh:65`, `build/aarch64/subset-build.sh:75`, `build/aarch64/mkimage.sh:43`, `build/aarch64/run-r9.sh:47`, `build/aarch64/stage-build.sh:31`)
- Fail loudly with a prefixed diagnostic to stderr and nonzero exit: `echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2; exit 1` (`nix/setup.sh:6-7`, `nix/vm-build.sh:15-16`); the repo-root sanity check `[ -d "$HARVEY/sys/src" ]` is the first guard in every harness script
- Env contracts are validated BEFORE any side effect: required vars with `[ -n "${VAR:-}" ] || err "…"` (`nix/boot-r9.sh:67`, `build/aarch64/run-r9.sh:52-55`); nix-store package contents are located with a `find`-by-name fallback rather than failing blind on layout drift (`nix/boot-r9.sh:70-82`)
- Nix store inputs are **read-only** (r--r--r--): `cp` the store file to a scratch dir, then `chmod u+w` the copy before patching it (`nix/boot-r9.sh:133-137`, `nix/smoke-r9.sh:144-148` — the `nix/setup.sh` `install_tool` chmod precedent for store-derived files)
- Capture child-build status explicitly and re-raise it — never let a cleanup/`||` tail mask a failure: `(cd "$HARVEY/sys/src" && bash RUN_BUILD_IN_PRIVATE_NAMESPACE) || { RC=$?; echo "error: namespace build failed (rc=$RC)" >&2; exit $RC; }` (`nix/build.sh:108-112`); same pattern for the guest build in `nix/vm-build.sh:58-62`
- Validate externally-derived values before use: `KERNDATE` is regex-checked (`=~ ^[0-9]+$`) with dialect-aware fallbacks (`date -n` for plan9port, `date +%s` for GNU/BSD) — `nix/build.sh:40-51`, `nix/vm-build.sh:23-32`
- Never `sudo` from the nix store (no setuid bit): use the host's `/usr/bin/sudo` with fallback (`nix/build.sh:93-94`, comment at `flake.nix:64-66`)

**Patterns to follow:**
- Check every system call that can fail
- On resource-acquisition failure, report `%r` (the errstr) so the real cause is shown
- Do not invent return-code enums; use `-1`/non-negative plus errstr

## Logging

**Framework:** none (no logging library).

**Patterns:**
- Diagnostics: `fprint(2, ...)` to stderr, prefixed with program name: `"cp: ..."`
- `%r` verb to append the current error string
- Kernel: `print`/`iprint` to the console; conditional debug output guarded by static flag variables (e.g., `consdebug`, `iprintscreenputs` in `sys/src/9/port/devcons.c`)
- Host scripts: progress echoes prefixed with `==` for stages (`echo "== pushing checkout to guest ~/$GUEST_DIR"` in `nix/vm-build.sh:50`); numbered step banners for multi-step pipelines (`echo "== step 2/3: bake bootfs.paq …"` in `nix/boot-r9.sh:116`, `nix/smoke-r9.sh:120`); the devshell prints an orientation banner in its `shellHook` (`flake.nix:138-145`)
- Boot-chain launchers always print the assembled qemu argv before launch so captured gate logs are self-describing: `echo "== qemu argv: $*"` (`build/aarch64/run-r9.sh:122-124`, `nix/boot-r9.sh:159-160`)
- Do not add syslog-style severity levels; the codebase has no such concept

## Comments

**When to Comment:**
- One or two lines above a function describing what it does
- Non-obvious invariants, magic numbers, protocol quirks — explain *why*
- File-top comment blocks describe the program's purpose when needed (`sys/src/cmd/tail.c` has a short one)
- Host scripts carry a header comment stating what the script does and what the flake wrapper provides: `# Full kernel build inside a private mount namespace (Linux only). ... Wrapper provides: PLAN9; plan9port+bash+util-linux+sudo+gnused+mount on PATH.` (`nix/build.sh:1-3`)
- The `build/aarch64` harness scripts carry an extended header: purpose + plan/decision provenance, the pipeline's numbered steps, the env contract (`R9_KERNEL`, `R9_DTB`, `R9_SKIP_BUILD`, `R9_SMOKE_LOG`…), hygiene rules, and usage — see `nix/boot-r9.sh:1-55`, `nix/smoke-r9.sh:1-59`, `build/aarch64/run-r9.sh:1-41`, `build/aarch64/smoke-r9.expect:1-50`
- Harness C files open with a block comment naming the phase/plan, the decision IDs implemented, and *why* the code is shaped as it is — including load-bearing compiler behaviors (`build/aarch64/stacksmoke.c:4-13`, `build/aarch64/init.c:4-18`, `build/aarch64/smokenote.c:20-27`, `build/aarch64/pidwait.c:1-28`)
- Workarounds reference their origin: plan/decision IDs (`BUILD-04`, `D-07`, `D-09`, `WR-08`, `WR-09`, `Pitfall 2`, `nm.BUILD, plan 02-03`) appear in comments throughout `nix/*.sh` and `flake.nix` — keep these references when editing; they trace to `.planning/` artifacts

**JSDoc/TSDoc:**
- Not applicable — no structured doc comments exist anywhere. Documentation lives in man pages under `sys/man/` (troff format, e.g. `sys/man/6/style`), not in source. Frozen contracts get their own markdown documents at the arch root (`aarch64/ABI.md`).

## Function Design

**Size:** Keep functions small and single-purpose; library code follows one-function-per-file (`sys/src/libbio/`).

**Parameters:**
- Few parameters; pass pointers to structs (`Dir *`, `Biobufhdr *bp`) rather than long scalar lists
- Output via caller-allocated buffers with explicit sizes: `char *strecpy(char*, char*, char*)` (dst, dst-end, src) — note the end-pointer idiom, safer than `strncpy`
- Variadic printf-style functions must be registered with `#pragma varargck`

**Return Values:**
- `-1` + errstr for failure; `nil` for pointer-returning functions on failure
- Success: 0, positive count, or valid pointer
- `nil` is defined per-arch in `<objtype>/include/u.h` as `((void*)0)` (`amd64/include/u.h`, `aarch64/include/u.h:1`) — always use `nil`, never `NULL`

**Concurrency:**
- User-space concurrency uses libthread (`sys/include/thread.h`): entry point is `threadmain(int argc, char *argv[])` instead of `main` when linking `-lthread` (see `sys/src/cmd/rio/rio.c:119`)
- Channels (`Channel*`, `chansend`/`chanrecv`) preferred over shared memory in threaded programs

## Module Design

**Exports:**
- Public API declared in a single header per library under `sys/include/<name>.h`
- Declarations use explicit `extern` and tabbed alignment:
  ```c
  extern	char*	strecpy(char*, char*, char*);
  extern	int	tokenize(char*, char**, int);
  ```
- Header begins with `#pragma src "/sys/src/lib<name>"` and `#pragma lib "lib<name>.a"`

**Build wiring (mkfiles — the "module manifest"):**
- Every directory has a `mkfile`; first line is `</$objtype/mkfile` which pulls in `sys/src/mkfile.proto` (sets `CFLAGS=-FTVw`, `CPUS`, `OS`) and the arch toolchain file (`amd64/mkfile` sets `CC=6c LD=6l O=6 AS=6a`; `aarch64/mkfile` sets `CC=7c LD=7l AS=7a O=7`)
- Libraries: list `OFILES` with `$O` suffix and `LIB=/$objtype/lib/libX.a`, then include `</sys/src/cmd/mksyslib` — see `sys/src/libbio/mkfile`
- Single-program commands: include `</sys/src/cmd/mkone`; multi-program directories: list `TARG` and include `</sys/src/cmd/mkmany` (see `sys/src/cmd/mkone`, `mkmany`)
- Standard targets everywhere: `all`, `install`, `clean`, `nuke`, `update`, `installall`; some add `safeinstall`
- Recursion pattern from `sys/src/mkfile`: `for(i in $LIBS $SUBSYS $CMDS)@{ cd $i; mk $target }` — note rc-shell `@{...}` blocks inside mkfiles

**Barrel Files:**
- Not used. Header-per-library is the aggregation mechanism.

**Language/toolchain notes:**
- Compilers are the Plan 9 toolchain (`6c`, `8c`, `7c`, etc.) — dialect is ANSI C with Plan 9 extensions (struct embedding like `QLock;` as an anonymous member in `sys/src/9/port/devcons.c`, designated initializers, `USED`/`SET` macros for silencing unused warnings)
- `ARGBEGIN { ... } ARGEND` macros from `sys/include/libc.h:741-756` are the standard flag-parsing idiom; use `EARGF(usage())` for flags with arguments (see `sys/src/cmd/cp.c`, `sys/src/cmd/grep/main.c`)
- `goto` is avoided per style(6), but `goto usage;` for usage errors is an accepted idiom in existing commands

## aarch64 Port Conventions

Rules specific to the `aarch64/` arch tree and the Harvey↔r9 port (from `aarch64/ABI.md`, `aarch64/mkfile`, `AGENTS.md`):

- **Toolchain letters:** aarch64 uses the `7` family — `7a` (assembler), `7c` (compiler), `7l` (linker), `O=7` (object suffix). Wired in `aarch64/mkfile` (5 lines: `</sys/src/mkfile.proto` plus `CC=7c LD=7l AS=7a O=7`), following the same shape as `amd64/mkfile`.
- **Per-arch headers:** `aarch64/include/u.h` (nil, integer typedefs, `FPdbleword`, FPCR/FPSR bits, `va_list` machinery) and `aarch64/include/ureg.h` (trap frame: `r0`..`r28` with `r28`=`sb`, `r29`, `r30`/`link` union, `sp`, `pc`, `psr`, `type`) play the same role as `amd64/include/u.h`/`ureg.h`. No header guards; tab-aligned.
- **Donor-verbatim porting rule:** aarch64 sources are derived **verbatim** from 9front arm64 at pin `350266104f1fed81c78c3d05fa44f523bec0ae4d` (branch `front`), renaming only what must change. Example: the `case aarch64` stub generator in `sys/src/libc/9syscall/mkfile` is the donor `case arm64` block verbatim with the case label renamed (`aarch64/ABI.md:34-44`). Record provenance (donor, pin, verification date) in the port document when adding ported files.
- **Frozen ABI — do not edit casually:** `aarch64/ABI.md` + `aarch64/include/ureg.h` together are the frozen Harvey↔r9 user-side syscall wire contract (decisions D-15/D-16/D-17, phase 02): syscall number in `R0`, args in 8-byte slots at `SP+8`, `SVC` trap, result in `R0`. Phase 4 builds r9's `svc` dispatch and build-time static checks against these two files — **changing either after Phase 4 means re-freezing both repos** (`aarch64/ABI.md:4-8`).
- **ABI kernel-side enforcement (Phase 4 appendix):** `aarch64/ABI.md:83-143` pins r9-side trap-frame byte offsets (r0@0 … r28@224, r29@232, r30/link@240, sp@248, pc@256, psr@264, type@272; `sizeof(Ureg)`=280) and a two-layer drift check — in-crate `core::mem::offset_of!` const asserts in r9's `aarch64/src/trap.rs` (fail `cargo build`, no Harvey checkout needed) plus `cargo xtask ureg-check` (r9 repo) parsing this repo's `aarch64/include/ureg.h` via `R9_HARVEY_DIR` (default `../harvey`), run standalone and as a boot-test precondition. The `type` **slot** is pinned but its value encoding is kernel-internal.
- **Syscall table:** Harvey's `sys/src/libc/9syscall/sys.h` 0–54 verbatim; `NMOUNT`=54 is Harvey-only and may stay unimplemented in r9 until called (D-16). Per-name stub quirks (`seek`→`_seek`, `exits`→`_exits`) match the other arches' generator rules.
- **Output layout:** built artifacts land in `aarch64/bin/`, `aarch64/lib/`, `aarch64/bbin/`, mirroring `amd64/`; on darwin they are rsynced back from the lima build guest by `nix/vm-build.sh:64-67`.

## Host-Side Shell Conventions (nix/ harness)

The flake apps (`flake.nix` + `nix/*.sh`) are the project's host-side harness; their style is distinct from the Plan 9 C tree:

- **Shell dialect:** bash, run via `pkgs.writeShellApplication` (`flake.nix:19-32`) which injects `set -euo pipefail`, `PLAN9`, and PATH. Scripts are shellcheck-clean (commit `df615a33a`; smoke EXIT-trap quoting fixed in `163682f60`). The `build/aarch64/*.sh` supply-chain scripts are POSIX `sh` (`#!/bin/sh`, `set -eu`) invoked via `sh script` from the flake apps — they do not assume bash.
- **Environment defaults:** `HARVEY="${HARVEY:-$PWD}"` at the top of every script; per-OS/arch host bin dir `HARVEY_LINUX_BIN="$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin"` so a checkout shared with the lima guest never clobbers host binaries (`nix/setup.sh:10-14`).
- **PATH hygiene:** host bin FIRST, `$PLAN9/bin` LAST. Where a Plan 9 tool shadows a needed host tool, call the host tool explicitly: `GNU_SED` absolute path (plan9 `sed` has no `-i`, `nix/build.sh:62-68`), `/usr/bin/grep` on darwin (plan9 `grep` has no `-q`/`-x`, `nix/vm-build.sh:34-36`), `/bin/rm` in traps (`nix/toolchain.sh:47`), binutils `nm` shimmed into a temp dir to shadow Harvey's ken-format `nm` during host builds (`nix/toolchain.sh:36-45`, `nix/build.sh:16-32`).
- **Shim pattern:** temporary tool shims go in `mktemp -d` dirs removed via `trap '/bin/rm -rf "$SHIMDIR"' EXIT` — see the `9l` `-static`-dropping shim in `nix/toolchain.sh:26-47`.
- **Sentinel files:** stateful one-time gates use dotfile sentinels in the arch tree, e.g. `amd64/.userland-ok` arms the userland preflight only after a successful build (`nix/build.sh:81-89,114-120`).
- **Reproducibility:** `KERNDATE` pins the kernel build timestamp from the checkout's git commit (`git log -1 --format=%ct`), overridable via env, numerically validated; see `build/REPRODUCIBILITY.md` and `nix/build.sh:37-51`. The compose/smoke apps repeat the same derivation chain (git → `date -n` → `date +%s`, digits-only regex gates) in `nix/boot-r9.sh:94-103` and `nix/smoke-r9.sh:98-107`.
- **Idempotent in-tree fixups:** the build edits in-tree mkfiles with `GNU_SED -i` (documented as "from build/BUILD_IN_DOCKER (idempotent)") rather than maintaining patches (`nix/build.sh:61-68`).

## Boot-Chain Harness Conventions (build/aarch64 supply chain + boot-r9 apps)

The r9 boot supply chain — `build/aarch64/{subset-build,mkimage,stage-build,run-r9}.sh`, `nix/boot-r9.sh`, `nix/smoke-r9.sh`, and the expect drivers — extends the host-shell rules above with its own idioms:

- **One driver per step, both platforms:** `build/aarch64/subset-build.sh` is the single userland-build driver — darwin runs the generated guest script in the lima VM via `build/aarch64/vm-run.sh`; linux runs the SAME generated script natively under `build/aarch64/nsrun.sh` (`sudo unshare -m`), skipping rsync because the namespace bind-mounts the real checkout (`subset-build.sh:82-115,229-277`). The platform split lives in this one script, not in the flake apps.
- **Guest-side scripts are generated, never committed:** the host driver heredocs the guest script into `mktemp -d`, rsyncs it to the guest's `/tmp`, and runs it through the namespace wrap (`subset-build.sh:121-225`, `stage-build.sh:52-100`). Guest scripts end with a sentinel line (`SUBSET-BUILD-OK`, `STAGE-BUILD-OK`) that the host asserts with `/usr/bin/grep -q` — a green exit status alone is never trusted (`subset-build.sh:250`, `stage-build.sh:117`). Guest failures carry a namespaced prefix naming the step — `SUBSET-BUILD-FAIL: <dir>` / `STAGE-BUILD-FAIL: <name>` — and the host error points at the log plus that hint (`subset-build.sh:139,246-248`).
- **Artifact verification is by content, not presence:** every aarch64 binary harvested to `build/aarch64/out/` must carry the arm64 a.out magic — `od -An -tx1 -N4` must equal `00008c47` (R_MAGIC, BE) — checked host-side after rsync-back (`subset-build.sh:286-292`, `stage-build.sh:127-132`). The baked paqfs image proves header magic `529ab12b` + trailer magic `6b46e688` (`mkimage.sh:152-159`).
- **Identity-by-content asserts:** `build/aarch64/out/` is shared between two supply chains ("last writer wins"), so `mkimage.sh:120-132` proves the REAL init at bake time by grepping the binary's rodata (`"init: starting /bin/rc"` present, `"init: r9 EL0 alive"` absent) — with `/usr/bin/grep`, never plan9 grep (no `-q`).
- **Bake-time verbatim copies:** `rc/lib/rcmain` and `adm/timezone/local` are copied into the image from the repo at bake time (single source of truth) and rcmain is `cmp -s`-verified against the source (`mkimage.sh:107-110,143-145`). Never edit a staged copy.
- **Image manifest gates:** the staged tree must satisfy the full manifest before mkpaqfs runs — every mandated path present, `/boot/factotum` ABSENT (D-02 auth-stub-by-absence), mount-point dirs `/root /env /proc /dev /srv /fd /bin /tmp /mnt` pre-created because the image is read-only (Pitfall 8) — `mkimage.sh:112-141`. The committed skeleton lives in `build/aarch64/root-tree/` (`lib/namespace`, `rc/bin/termrc`, `usr/glenda/lib/profile`).
- **qemu launch discipline:** the assembled argv is always echoed before launch; interactive runs use `-nographic` with qemu as a foreground child (NOT `exec`) so the EXIT trap reclaims the mktemp DTB dir (`nix/boot-r9.sh:150-166`); gate runs use `--log FILE` with `-display none -serial file:…` (`run-r9.sh:111-120`). An explicit `<&0` redirect on the backgrounded qemu is LOAD-BEARING — POSIX substitutes `/dev/null` for a backgrounded command's stdin in a non-interactive shell, silently starving the serial console (`run-r9.sh:126-136`).
- **Fresh-capture rule (D-16/Pitfall 10):** gate logs are `rm -f`'d BEFORE qemu launches — a pre-seeded stale log is dead evidence that could satisfy the next run's marker waits. Enforced at both layers: `nix/smoke-r9.sh:166-169` and again inside `smoke-r9.expect:68-71`; `run-r9.sh:73-75`.
- **Process-group teardown:** spawned qemu is killed as a process GROUP (`kill -KILL -- -$pid`) with a lone-pid fallback; pkill fallbacks use a bracket-fixed pattern (`'[q]emu-system-aarch64.*…'`) that cannot self-match the harness's or pkill's own argv (`run-r9.sh:83-95`, `nix/smoke-r9.sh:127-141`, `smoke-r9.expect:86-93`, `drive-r9.expect:64-72`).
- **Regenerable artifacts are gitignored:** `build/aarch64/out/`, `build/aarch64/bootfs.paq`, and the transient captures `drive-r9.log` / `compose-gate.log` / `smoke-r9.log` are in `.gitignore` — passing captures are copied into the phase dir as retained evidence; `build/aarch64/hello.7.out` IS committed (gate evidence).

**Expect/Tcl drivers** (`build/aarch64/drive-r9.expect`, `build/aarch64/smoke-r9.expect`) — a new language in the tree; follow the established shape:

- `#!/usr/bin/expect -f` shebang; `set timeout 600` (TCG-sized, PER STAGE — Pitfall 11); `match_max 65536`. `log_user` stays ON — expect 5.45 writes NOTHING to `log_file` when `log_user` is 0 (measured; `smoke-r9.expect:54-57`).
- Required env validated loudly BEFORE any spawn; `exit 2` on contract violation, `exit 1` naming the failed stage on stderr, `exit 0` only on all-pass (`smoke-r9.expect:49-50,60-65`).
- Assertions go through a named-stage proc `proc stage {name re}` with `expect_out` declared `global` (expect sets it in the CURRENT scope — `smoke-r9.expect:96-106`); `expect_before` fast-fails on kernel panic markers anywhere in the boot (`-re {panic|Unhandled interrupt}`, `smoke-r9.expect:110-116`).
- Patterns are **presence-only, CRLF-tolerant substrings, never end-of-line anchored** (D-13: TCG preemption makes interleaving order meaningless; the kernel console cooks `\n` → `\r\n`). Command-output sweeps capture up to the next `% ` prompt, then word-anchored presence checks (`\mname\M`, `smoke-r9.expect:139-149`).
- Marker strings are chosen unforgeable: r9's devcons does not echo typed input, so `r9shell7` on the wire can only be the echo binary's output (`smoke-r9.expect:29-33`).
- Teardown: a `cleanup` proc kills the spawn's process group on every exit path — expect's pty makes the child a session/group leader on both hosts (`smoke-r9.expect:86-93`).

**Python harness** (`build/aarch64/trace-syscalls.py` alongside the pre-existing `drive9.py`/`srv9.py`/`gdbpoke9.py`/`mkfs9.py`): stdlib-only python3 (`os/re/socket/subprocess/threading/tempfile` — no third-party deps), env-overridable module constants at top (`HARVEY`, `HARVEY_VM`, `BOOT_BUDGET`, `SRV9_PORT`), header comment documenting the full pipeline + plan/decision provenance. `__pycache__/` is gitignored.

**rc trace scripts** (`build/aarch64/trace-boot.rc`, `trace-sweep.rc`, `trace-namespace`, `trace-termrc`): Plan 9 rc — `fn name { … }`, backquote captures (`` `{pidwait …}``), `>[2]/dev/null` stderr redirects, `~` pattern/list-membership tests. They are staged into donor bootdirs as DATA (mkrootall strips only file-identified executables; text rides through). Never use `@{…}` (rc's subshell fork) inside a traced process — fork children are born traced and self-stop (`trace-boot.rc:20-32`).

**Harness C files** (`build/aarch64/{init,pidwait,stacksmoke,smokefork,smokenote,tracehello}.c`): Plan 9 style per `sys/man/6/style` (tabs, `<u.h>`/`<libc.h>` prologue, `exits(nil)`/`exits("msg")`, `%r` diagnostics, `ARGBEGIN` in `pidwait.c:99-108`), compiled by the vendored 7c/7l in the guest namespace. Port-specific idioms:

- Ordering without rendezvous primitives: a bounded **volatile** pure-compute spin is the ordering/wait primitive (no `sleep` — alarm unimplemented on r9); `volatile` keeps the loop live under 7c (`init.c:24,99-112`, `tracehello.c`).
- 7c caches plain static loads in registers across loops — read handler-set flags through a real function call (`smokenote.c:20-27`'s `seen()`); Plan 9 compilers never inline C functions.
- Do not pass values out via `exits(pid)` — the kernel decorates a non-empty exit string into `"name pid: status"`; print to stdout and capture with an rc backquote instead (`pidwait.c:1-8`).

---

*Convention analysis: 2026-11-03*
