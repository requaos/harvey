---
last_mapped_commit: 8d99c117b284e53cd6b8eb3cc369accd135eedec
last_mapped_at: 2026-11-01
---
# Coding Conventions

**Analysis Date:** 2026-11-01

This is a Plan 9 (4th Edition / Harvey-lineage) C codebase. The authoritative style guide ships with the tree at `sys/man/6/style` ("style - Plan 9 coding conventions for C"). All rules below are derived from that document and confirmed against the actual sources. **Read `sys/man/6/style` before writing C here.**

## Project-Level Rules (AGENTS.md)

These constraints are recorded in `AGENTS.md` (Constraints section) and enforced by the tooling:

- **Architecture naming:** the 64-bit ARM architecture is `aarch64`, **never** `arm64`, in this project's tooling, docs, file names, and `objtype` values. Host scripts normalize `uname -m` output: `[ "$_hb_arch" = "arm64" ] && _hb_arch=aarch64` (`flake.nix:90`, `nix/setup.sh:13`, `nix/toolchain.sh:8`, `nix/build.sh:14`, `nix/vm-build.sh`).
- **plan9port PATH ordering:** `$PLAN9/bin` goes **LAST** in `PATH` per `BUILD_ON_UNIX` — plan9port ships a 9p `mount` (and `sed`, `grep`, `date` dialects) that must not shadow host tools. See `flake.nix:18-21` and the devshell hook (`flake.nix:96-97`).
- **Repo boundary with r9:** the r9 kernel is a **sibling repo** at `../r9`, not a subdirectory. Phases may work across both repos, but each keeps its own conventions: Harvey C follows `sys/man/6/style`; r9 Rust follows its own `rustfmt.toml`. Do not copy files across the boundary without an explicit port decision.
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

**Host-side shell scripts** (`nix/*.sh`, `build/*.bash`):
- Every flake app script runs under `set -euo pipefail` (injected by `mkScriptApp` in `flake.nix:16`); `nix/build.sh` additionally sets `set -e` at line 9 with a comment explaining why silent failure is dangerous
- Fail loudly with a prefixed diagnostic to stderr and nonzero exit: `echo "error: $HARVEY does not look like the harvey checkout (missing sys/src)" >&2; exit 1` (`nix/setup.sh:6-7`, `nix/vm-build.sh:15-16`)
- Capture child-build status explicitly and re-raise it — never let a cleanup/`||` tail mask a failure: `(cd "$HARVEY/sys/src" && bash RUN_BUILD_IN_PRIVATE_NAMESPACE) || { RC=$?; echo "error: namespace build failed (rc=$RC)" >&2; exit $RC; }` (`nix/build.sh:108-112`); same pattern for the guest build in `nix/vm-build.sh:58-62`
- Validate externally-derived values before use: `KERNDATE` is regex-checked (`=~ ^[0-9]+$`) with dialect-aware fallbacks (`date -n` for plan9port, `date +%s` for GNU/BSD) — `nix/build.sh:40-51`, `nix/vm-build.sh:23-32`
- Never `sudo` from the nix store (no setuid bit): use the host's `/usr/bin/sudo` with fallback (`nix/build.sh:93-94`, comment at `flake.nix:58-59`)

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
- Host scripts: progress echoes prefixed with `==` for stages (`echo "== pushing checkout to guest ~/$GUEST_DIR"` in `nix/vm-build.sh:50`); the devshell prints an orientation banner in its `shellHook` (`flake.nix:99-106`)
- Do not add syslog-style severity levels; the codebase has no such concept

## Comments

**When to Comment:**
- One or two lines above a function describing what it does
- Non-obvious invariants, magic numbers, protocol quirks — explain *why*
- File-top comment blocks describe the program's purpose when needed (`sys/src/cmd/tail.c` has a short one)
- Host scripts carry a header comment stating what the script does and what the flake wrapper provides: `# Full kernel build inside a private mount namespace (Linux only). ... Wrapper provides: PLAN9; plan9port+bash+util-linux+sudo+gnused+mount on PATH.` (`nix/build.sh:1-3`)
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
- **Syscall table:** Harvey's `sys/src/libc/9syscall/sys.h` 0–54 verbatim; `NMOUNT`=54 is Harvey-only and may stay unimplemented in r9 until called (D-16). Per-name stub quirks (`seek`→`_seek`, `exits`→`_exits`) match the other arches' generator rules.
- **Output layout:** built artifacts land in `aarch64/bin/`, `aarch64/lib/`, `aarch64/bbin/`, mirroring `amd64/`; on darwin they are rsynced back from the lima build guest by `nix/vm-build.sh:64-67`.

## Host-Side Shell Conventions (nix/ harness)

The flake apps (`flake.nix` + `nix/*.sh`) are the project's host-side harness; their style is distinct from the Plan 9 C tree:

- **Shell dialect:** bash, run via `pkgs.writeShellApplication` (`flake.nix:12-25`) which injects `set -euo pipefail`, `PLAN9`, and PATH. Scripts are shellcheck-clean (commit `df615a33a`).
- **Environment defaults:** `HARVEY="${HARVEY:-$PWD}"` at the top of every script; per-OS/arch host bin dir `HARVEY_LINUX_BIN="$HARVEY/.build/hostbin-$_hb_os-$_hb_arch/bin"` so a checkout shared with the lima guest never clobbers host binaries (`nix/setup.sh:10-14`).
- **PATH hygiene:** host bin FIRST, `$PLAN9/bin` LAST. Where a Plan 9 tool shadows a needed host tool, call the host tool explicitly: `GNU_SED` absolute path (plan9 `sed` has no `-i`, `nix/build.sh:62-68`), `/usr/bin/grep` on darwin (plan9 `grep` has no `-q`/`-x`, `nix/vm-build.sh:34-36`), `/bin/rm` in traps (`nix/toolchain.sh:47`), binutils `nm` shimmed into a temp dir to shadow Harvey's ken-format `nm` during host builds (`nix/toolchain.sh:36-45`, `nix/build.sh:16-32`).
- **Shim pattern:** temporary tool shims go in `mktemp -d` dirs removed via `trap '/bin/rm -rf "$SHIMDIR"' EXIT` — see the `9l` `-static`-dropping shim in `nix/toolchain.sh:26-47`.
- **Sentinel files:** stateful one-time gates use dotfile sentinels in the arch tree, e.g. `amd64/.userland-ok` arms the userland preflight only after a successful build (`nix/build.sh:81-89,114-120`).
- **Reproducibility:** `KERNDATE` pins the kernel build timestamp from the checkout's git commit (`git log -1 --format=%ct`), overridable via env, numerically validated; see `build/REPRODUCIBILITY.md` and `nix/build.sh:37-51`.
- **Idempotent in-tree fixups:** the build edits in-tree mkfiles with `GNU_SED -i` (documented as "from build/BUILD_IN_DOCKER (idempotent)") rather than maintaining patches (`nix/build.sh:61-68`).

---

*Convention analysis: 2026-11-01*
