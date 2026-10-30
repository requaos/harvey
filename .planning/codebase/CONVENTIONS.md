---
last_mapped_commit: bf084ee78de58b5f05b98235bb6e6887fde6e8c4
last_mapped_at: 2026-10-30
---
# Coding Conventions

**Analysis Date:** 2026-10-30

This is a Plan 9 (4th Edition / Harvey-lineage) C codebase. The authoritative style guide ships with the tree at `sys/man/6/style` ("style - Plan 9 coding conventions for C"). All rules below are derived from that document and confirmed against the actual sources. **Read `sys/man/6/style` before writing C here.**

## Naming Patterns

**Files:**
- All lowercase, no underscores: `bread.c`, `bgetrune.c`, `devcons.c`
- One function (or a small tightly-related group) per file in libraries: `sys/src/libbio/` has `binit.c`, `bflush.c`, `brdline.c`, etc., each containing the function it is named after
- Commands are single files named after the command: `sys/src/cmd/cat.c`, `cp.c`, `tail.c`; multi-file commands get a directory: `sys/src/cmd/rio/`, `sys/src/cmd/fossil/`
- Headers named after their library: `sys/include/bio.h`, `sys/include/thread.h`
- Object/build naming is toolchain-suffixed, never `.o`: `$O` expands to the architecture character (`6` = amd64, `8` = 386, `5` = arm, etc.), so `bread.$O` → `bread.6`

**Functions:**
- All lowercase, no underscores, often concatenated words: `copy1`, `dirstat`, `sysfatal`, `waserror`, `poperror`, `threadmain`
- Library functions carry a library prefix: `libbio` → `Bread`, `Binit`, `Bprint`, `Bflush`; `libdraw` → `drawsetdebug`... (prefix letters are uppercased in the libbio/libdraw family per `sys/include/bio.h`)
- Static helpers follow the same lowercase rule: `samefile` in `sys/src/cmd/cp.c`

**Variables:**
- All lowercase, short: `dirb`, `todir`, `bout`, `icount`
- Flag variables suffixed with `flag`: `gflag`, `uflag`, `xflag` (see `sys/src/cmd/cp.c`)
- Global state named plainly: `failed`, `count`, `anycount` (see `sys/src/cmd/tail.c`)

**Types:**
- `struct` tags and their matching `typedef`s are Uppercase/Capitalized: `typedef struct Biobuf Biobuf;` (`sys/include/bio.h`), `QLock`, `Ref`, `Queue`, `Dir`, `Rune`
- `enum` and `#define` constants are Uppercase or UPPERCASE: `Binactive`, `Bractive`, `Bsize`, `UTFmax`, `DMDIR`, `OREAD`

## Code Style

**Formatting:**
- Tool: none enforced (no clang-format/indent config in tree). Style is by convention only; `sys/src/cmd/cb/` is the in-tree C beautifier but is not run automatically.
- **Tabs only** — never expand tabs to spaces (`sys/man/6/style` is explicit). Display width is a reader setting.
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
- Comment anything that takes >2 seconds to understand — explain *why*, not what.

**Pragmas (Plan 9 C compiler extensions — do not remove):**
- `#pragma lib "libbio.a"` / `#pragma src "/sys/src/libbio"` at top of public headers (`sys/include/bio.h`, `sys/include/libc.h`)
- `#pragma varargck argpos fprint 2` — registers printf-like functions for format checking (`sys/include/libc.h:171-180`)
- There are **no `#ifndef` header guards** in Plan 9 headers; the compilers tolerate multiple inclusion of identical declarations. Do not add guards.

## Import Organization

**Order (user code):**
1. `#include <u.h>` — always first (architecture types: `uchar`, `vlong`, `Rune`, `nil`; lives at `amd64/include/u.h`, `386/include/u.h`, etc.)
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
- Do not add syslog-style severity levels; the codebase has no such concept

## Comments

**When to Comment:**
- One or two lines above a function describing what it does
- Non-obvious invariants, magic numbers, protocol quirks — explain *why*
- File-top comment blocks describe the program's purpose when needed (`sys/src/cmd/tail.c` has a short one)

**JSDoc/TSDoc:**
- Not applicable — no structured doc comments exist anywhere. Documentation lives in man pages under `sys/man/` (troff format, e.g. `sys/man/6/style`), not in source.

## Function Design

**Size:** Keep functions small and single-purpose; library code follows one-function-per-file (`sys/src/libbio/`).

**Parameters:**
- Few parameters; pass pointers to structs (`Dir *`, `Biobufhdr *bp`) rather than long scalar lists
- Output via caller-allocated buffers with explicit sizes: `char *strecpy(char*, char*, char*)` (dst, dst-end, src) — note the end-pointer idiom, safer than `strncpy`
- Variadic printf-style functions must be registered with `#pragma varargck`

**Return Values:**
- `-1` + errstr for failure; `nil` for pointer-returning functions on failure
- Success: 0, positive count, or valid pointer
- `nil` is defined in `amd64/include/u.h` as `((void*)0)` — always use `nil`, never `NULL`

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
- Every directory has a `mkfile`; first line is `</$objtype/mkfile` which pulls in `sys/src/mkfile.proto` (sets `CFLAGS=-FTVw`, `CPUS`, `OS`) and the arch toolchain file (`amd64/mkfile` sets `CC=6c LD=6l O=6 AS=6a`)
- Libraries: list `OFILES` with `$O` suffix and `LIB=/$objtype/lib/libX.a`, then include `</sys/src/cmd/mksyslib` — see `sys/src/libbio/mkfile`
- Single-program commands: include `</sys/src/cmd/mkone`; multi-program directories: list `TARG` and include `</sys/src/cmd/mkmany` (see `sys/src/cmd/mkone`, `mkmany`)
- Standard targets everywhere: `all`, `install`, `clean`, `nuke`, `update`, `installall`; some add `safeinstall`
- Recursion pattern from `sys/src/mkfile`: `for(i in $LIBS $SUBSYS $CMDS)@{ cd $i; mk $target }` — note rc-shell `@{...}` blocks inside mkfiles

**Barrel Files:**
- Not used. Header-per-library is the aggregation mechanism.

**Language/toolchain notes:**
- Compilers are the Plan 9 toolchain (`6c`, `8c`, etc.) — dialect is ANSI C with Plan 9 extensions (struct embedding like `QLock;` as an anonymous member in `sys/src/9/port/devcons.c`, designated initializers, `USED`/`SET` macros for silencing unused warnings)
- `ARGBEGIN { ... } ARGEND` macros from `sys/include/libc.h:741-756` are the standard flag-parsing idiom; use `EARGF(usage())` for flags with arguments (see `sys/src/cmd/cp.c`, `sys/src/cmd/grep/main.c`)
- `goto` is avoided per style(6), but `goto usage;` for usage errors is an accepted idiom in existing commands

---

*Convention analysis: 2026-10-30*
