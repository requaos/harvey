---
last_mapped_commit: bf084ee78de58b5f05b98235bb6e6887fde6e8c4
last_mapped_at: 2026-10-30
---
# Testing Patterns

**Analysis Date:** 2026-10-30

**Bottom line up front:** This Plan 9 codebase has **no unit test framework**. There is no jest/vitest/googletest equivalent, no assertion library, no mocking framework, and no enforced coverage. Testing is done with ad-hoc shell (rc/sh) scripts and mkfile `test:V` targets that run the built binary and compare outputs with `cmp`. Match that idiom when adding tests.

## Test Framework

**Runner:**
- None. Tests are plain shell scripts or `test:V` targets inside per-directory `mkfile`s, executed by Plan 9 `mk` (build via plan9port's `mk` or the in-tree toolchain on Unix — see `BUILD_ON_UNIX` and `.github/workflows/` which builds on `ubuntu-latest` with qemu + ufs).
- Test targets found via `grep "test:V" sys/src/**/mkfile`:
  - `sys/src/cmd/fossil/mkfile` — full integration test (formats a scratch fossil, mounts it, drives the console)
  - `sys/src/cmd/bzip2/mkfile` — golden-file round-trip comparison
  - `sys/src/cmd/spell/mkfile` — `cmp y z` output comparison
  - `sys/src/cmd/cifs/mkfile` — smoke run against a live server (host-specific, not hermetic)
  - `sys/src/games/mp3enc/mkfile` — byte-compare encoded output (`cmp -l ... | wc -l`)
  - `sys/src/cmd/4l/mkfile`, `vl/mkfile`, `il/mkfile` — linker/assembler tests
  - `sys/src/libstdio/mkfile` — `test:V` just archives objects (effectively a build check)

**Assertion Library:**
- None. Assertions are `cmp` exit statuses and explicit shell `if` checks. In C, `assert` is the macro from `sys/include/libc.h` (`#define assert(x) if(x){}else _assert("x")`) — used in debug code, not in test suites.

**Run Commands:**

```bash

# Native Plan 9 (or plan9port mk):

cd sys/src/cmd/bzip2 && mk test
cd sys/src/cmd/fossil && mk test        # destructive-ish: writes /tmp/fossil, mounts /n/fossil

# Upstream-style suites (POSIX sh):

cd sys/src/cmd/lzip/testsuite && sh check.sh . .   # clzip round-trip tests
sys/src/cmd/postscript/tests/runtests              # drives translator binaries over post* inputs
```

## Test File Organization

**Location:**
- No fixed convention. Patterns present in tree:
  - Co-located `testsuite/` subdirectory: `sys/src/cmd/lzip/testsuite/` (contains `check.sh`, `test.txt`)
  - Co-located `tests/` subdirectory: `sys/src/cmd/postscript/tests/` (input corpus `postbgi1`, `postdaisy1`, … plus `runtests` script)
  - Co-located ad-hoc C test programs in libraries: `sys/src/libbio/btestprint.c` (a standalone `main` that exercises `Bprint` with a large string)
  - Golden data files beside the command: `sys/src/cmd/bzip2/sample1.ref`, `sample1.bz2` referenced from its mkfile
  - Compiler QA suite: `sys/src/cmd/qa/` (yacc-generated random-instruction tester for assemblers: `a.y`, `lex.c`)

**Naming:**
- Scripts: `check.sh`, `runtests`
- Test programs: suffixed `test` or `*test*.c` (`btestprint.c`)
- Golden files: `*.ref`, `*.bz2`, numbered corpora (`postdmd1`)

**Structure:**

```
sys/src/cmd/<cmd>/
├── mkfile            # may contain a test:V target
├── sample*.ref       # golden inputs/outputs
└── testsuite/        # or tests/ — shell script + fixtures
```

## Test Structure

**Suite Organization (mkfile target pattern — the dominant idiom):**
From `sys/src/cmd/bzip2/mkfile:21-29`:

```mk
test:V: $O.bzip2 $O.bunzip2
	./$O.bzip2 -1  < sample1.ref > sample1.rb2
	./$O.bunzip2  < sample1.bz2 > sample1.tst
	cmp sample1.bz2 sample1.rb2
	cmp sample1.ref sample1.tst
```

Build the binary, run it on fixture input, `cmp` against golden output. A nonzero `cmp` exit fails the mk run — that is the entire assertion mechanism.

**Full integration pattern (services):**
From `sys/src/cmd/fossil/mkfile:59-80`:

```mk
test:V: all
	rm -f /srv/test.fossil /srv/test.fscons
	slay 8.flfmt | rc
	{syscall seek 1 6400000000 0; echo} >>/tmp/fossil
	8.flfmt -y /tmp/fossil
	8.fossil -f /tmp/fossil
	cat /srv/test.fscons &
	echo fsys main >>/srv/test.fscons
	mount /srv/test.fossil /n/fossil
	...
	echo sync >>/srv/test.fscons
```

Spin up the real server on a scratch file, drive it through its `/srv` console interface, exercise the mounted namespace. This is the model for testing file servers and daemons here.

**Shell script pattern:**
From `sys/src/cmd/lzip/testsuite/check.sh`: POSIX sh, accumulates failures in a `fail` variable (`test_failed() { fail=1; ... }`), checks exit codes explicitly (`[ $? = 1 ]`), prints one line per failure with `$LINENO`, exits nonzero at the end. Not native Plan 9 style (it's an imported upstream suite) but functional.

**Patterns:**
- Setup: build target as a prerequisite of `test:V`
- Teardown: `rm -f` of scratch files at the start of the next run; some targets end with `rm testcase.new.mp3`
- Assertion: `cmp`, exit-status checks, `wc -l` on `cmp -l` output

## Mocking

**Framework:** None.

**Patterns:**
- Mocking does not exist in this codebase. Dependencies are replaced with real stand-ins:
  - File servers are tested against a scratch disk file (`/tmp/fossil`) instead of real hardware
  - The kernel's test seam is the device/namespace interface: tests mount, bind, and read/write synthetic files rather than stubbing functions
- To isolate new code, follow the fossil pattern: run the real implementation against temporary state in `/tmp` and a private namespace

**What to Mock:**
- Hardware dependencies → point the program at a regular file (`/tmp/fossil` pattern)
- Network dependencies → prefer loopback/`/net` on a private namespace, or skip (existing `cifs` test depends on a live host and is not hermetic — do not copy this)

**What NOT to Mock:**
- Function-level stubbing has no precedent; don't introduce a C mocking library

## Fixtures and Factories

**Test Data:**
- Golden files committed next to the code: `sys/src/cmd/bzip2/sample1.ref`, `sample1.bz2`; `sys/src/cmd/lzip/testsuite/test.txt`
- Input corpora for output-producing tools: `sys/src/cmd/postscript/tests/post*1` files
- Generated fixtures: fossil test synthesizes an empty filesystem image via `syscall seek 1 6400000000 0` (sparse file) instead of committing a 6.4 GB fixture

**Location:**
- Adjacent to the command under test, or in a `testsuite/`/`tests/` subdirectory of the command directory

## Coverage

**Requirements:** None enforced. No coverage tooling exists anywhere in the tree (no gcov/lcov configs, no CI coverage step).

**View Coverage:**

```bash

# Not available. Closest proxies:

# - kernel profiling: kprof(1) via /sys/src/cmd/kprof.c

# - acid debugger: /sys/src/cmd/acid

```

## Test Types

**Unit Tests:**
- Not present as a category. The closest analog is co-located test programs like `sys/src/libbio/btestprint.c` — a standalone `main` exercising one library call, run manually.

**Integration Tests:**
- The dominant real test type: mkfile `test:V` targets that build and run actual binaries against fixtures (bzip2, spell, mp3enc) or live subsystems (fossil).
- Assembler/compiler QA: `sys/src/cmd/qa/` generates random instruction streams and verifies assembler output — a property-based/fuzz-style approach unique in the tree.

**E2E Tests:**
- CI smoke level only: `.github/workflows/` builds the whole system, boots it under `qemu-system-x86` with `ufs` file serving, and runs `build/command.bash`. No assertion of boot success beyond script completion.

## Common Patterns

**Adding a test to an existing command:**
1. Add golden fixture files to the command's directory
2. Add a `test:V` target to its `mkfile` depending on the built binary:
   ```mk
   test:V: $O.myprog
   	./$O.myprog < input.ref > output.tst
   	cmp output.ref output.tst
   ```
3. Ensure scratch files are removed (start of target or `rm` at end)

**Testing a library:**
- Write a `*test*.c` program in the library directory with its own `main` (see `sys/src/libbio/btestprint.c`), built manually or via an extra mkfile target; keep it out of `OFILES` so it is not archived into the `.a`

**Async/Concurrent Testing:**
- No framework support. Threaded code (libthread) is tested by running the threaded program itself (e.g., rio is exercised interactively). Timeouts are handled by shell `sleep`/`await` (`rc/bin/await` exists in `rc/bin`).

**Error Testing:**
- Verify failure modes through exit status: Plan 9 convention is `exits("message")` on failure, so a test asserts `$status` is non-empty (rc) or `$? != 0` (sh). Example from lzip `check.sh`: `[ $? = 2 ] || test_failed $LINENO`.

**Caveats when extending tests:**
- `sys/src/cmd/test.c` is the `test(1)` *command* (the `[` builtin), not a test suite — do not be misled by the name
- Many `test:V` targets are bit-rotted or host-specific (`cifs` needs a server named `se-00`); verify before relying on them as examples
- There is no CI job that runs `mk test` anywhere — tests are opt-in, run manually

---

*Testing analysis: 2026-10-30*
