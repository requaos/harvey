---
last_mapped_commit: 8d99c117b284e53cd6b8eb3cc369accd135eedec
last_mapped_at: 2026-11-01
---
# Testing Patterns

**Analysis Date:** 2026-11-01

**Bottom line up front:** This Plan 9 codebase has **no unit test framework**. There is no jest/vitest/googletest equivalent, no assertion library, no mocking framework, and no enforced coverage. In-tree testing is ad-hoc shell (rc/sh) scripts and mkfile `test:V` targets that run the built binary and compare outputs with `cmp`. The **primary verification surface is the Nix flake harness** (`flake.nix` apps): a full clean-checkout build pipeline where a failed stage fails the run. Match these idioms when adding tests.

## Test Framework

**Runner:**
- None for unit tests. Tests are plain shell scripts or `test:V` targets inside per-directory `mkfile`s, executed by Plan 9 `mk` (build via plan9port's `mk` or the in-tree toolchain on Unix — see `BUILD_ON_UNIX`).
- Test targets found via `grep "test:V" sys/src/**/mkfile`:
  - `sys/src/cmd/fossil/mkfile` — full integration test (formats a scratch fossil, mounts it, drives the console)
  - `sys/src/cmd/bzip2/mkfile` — golden-file round-trip comparison
  - `sys/src/cmd/spell/mkfile` — `cmp y z` output comparison
  - `sys/src/cmd/cifs/mkfile` — smoke run against a live server (host-specific, not hermetic)
  - `sys/src/games/mp3enc/mkfile` — byte-compare encoded output (`cmp -l ... | wc -l`)
  - `sys/src/cmd/4l/mkfile`, `vl/mkfile`, `il/mkfile` — linker/assembler tests
  - `sys/src/libstdio/mkfile` — `test:V` just archives objects (effectively a build check)

**Build harness as test surface (flake apps — the project's primary gate):**
- `flake.nix` exposes the pipeline as apps (`flake.nix:37-72`): `nix run .#setup` → `nix run .#toolchain` → `nix run .#build` → `nix run .#iso`. Each stage is a `writeShellApplication` with `set -euo pipefail`; **a build failure is the test failure**.
- `nix run .#setup` (`nix/setup.sh`) — populates `$HARVEY/.build/hostbin-<os>-<arch>/bin` with the plan9port bootstrap tools; errors if `$HARVEY` is not a checkout.
- `nix run .#toolchain` (`nix/toolchain.sh`) — builds the Plan 9 cross toolchain (`BUILDTOOLCHAIN`, `cmd/BUILD`, vendored `9cc`); requires setup first and checks for `$HARVEY_LINUX_BIN/pcc` (`nix/toolchain.sh:18-21`).
- `nix run .#build` (`nix/build.sh`) — full kernel+userland build inside a Linux private mount namespace (`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`); on darwin the same app runs `nix/vm-build.sh`, which rsyncs the checkout to a lima VM (`nix/lima-harvey.yaml`), runs `setup && toolchain && build` in the guest, and rsyncs `amd64/`, `386/`, `aarch64/` artifacts back.
- `nix run .#iso` (`nix/iso.sh`) — boots the 9legacy ISO under qemu + expect and builds Harvey inside the VM (`build/build.bash`); the cross-platform (TCG) path.

**Assertion Library:**
- None. Assertions are `cmp` exit statuses and explicit shell `if` checks. In C, `assert` is the macro from `sys/include/libc.h` (`#define assert(x) if(x){}else _assert("x")`) — used in debug code, not in test suites.
- In the flake harness, assertions are explicit guards with stderr diagnostics: `if [ ! -x "$HARVEY_LINUX_BIN/$t" ]; then echo "error: ..." >&2; exit 1; fi` (`nix/build.sh:54-59`).

**Run Commands:**

```bash

# Flake pipeline (host-side harness; darwin builds via lima VM):

nix run .#setup && nix run .#toolchain && nix run .#build
nix run .#iso                      # qemu+expect ISO build path
nix develop                        # devshell with plan9port, qemu, expect, etc.

# Native Plan 9 (or plan9port mk) in-tree tests:

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
  - Host harness scripts: `nix/*.sh` (referenced from `flake.nix` via `builtins.readFile`)

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

flake.nix             # app definitions: setup/toolchain/build/iso
nix/
├── setup.sh          # stage 1: host bin population
├── toolchain.sh      # stage 2: cross toolchain build
├── build.sh          # stage 3 (linux): namespace build
├── vm-build.sh       # stage 3 (darwin): lima guest build + artifact rsync
├── iso.sh            # qemu+expect ISO build
├── lima-harvey.yaml  # darwin build VM definition
└── minimega.nix      # VM orchestration package (linux only)
```

## Test Structure

**Suite Organization (mkfile target pattern — the dominant in-tree idiom):**
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

**Flake harness stage pattern (host-side):**
From `nix/vm-build.sh:56-62` — each stage's status is captured explicitly and a failed guest build **refuses to sync artifacts back**:

```bash
ssh -F "$SSH_CFG" "$GUEST" "KERNDATE=$KERNDATE bash -lc 'set -e; cd \"$GUEST_DIR\" && nix run .#setup && nix run .#toolchain && nix run .#build'" || {
	RC=$?
	echo "error: guest build failed (rc=$RC) — refusing to rsync artifacts back" >&2
	exit $RC
}
```

Preflight gates use sentinel files so a clean checkout is never blocked by state the build itself is about to produce: `amd64/.userland-ok` arms the four-binary userland check only after a successful build (`nix/build.sh:73-89,114-120`).

**Shell script pattern:**
From `sys/src/cmd/lzip/testsuite/check.sh`: POSIX sh, accumulates failures in a `fail` variable (`test_failed() { fail=1; ... }`), checks exit codes explicitly (`[ $? = 1 ]`), prints one line per failure with `$LINENO`, exits nonzero at the end. Not native Plan 9 style (it's an imported upstream suite) but functional.

**Patterns:**
- Setup: build target as a prerequisite of `test:V`
- Teardown: `rm -f` of scratch files at the start of the next run; some targets end with `rm testcase.new.mp3`; flake scripts remove shim dirs via `trap '/bin/rm -rf "$SHIMDIR"' EXIT`
- Assertion: `cmp`, exit-status checks, `wc -l` on `cmp -l` output; in the harness, explicit `[ ! -x ... ]` guards with `exit 1`

## Mocking

**Framework:** None.

**Patterns:**
- Mocking does not exist in this codebase. Dependencies are replaced with real stand-ins:
  - File servers are tested against a scratch disk file (`/tmp/fossil`) instead of real hardware
  - The kernel's test seam is the device/namespace interface: tests mount, bind, and read/write synthetic files rather than stubbing functions
  - Host-tool collisions are handled with **shim binaries** in a `mktemp` dir rather than mocks: the `9l` `-static`-dropping shim and the binutils `nm` shadow in `nix/toolchain.sh:26-47`, `nix/build.sh:16-32`
  - The darwin build replaces the environment, not the code: the whole checkout is rsynced into a real Linux VM (`nix/vm-build.sh`) because the kernel build needs Linux mount namespaces — no simulation
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
- **The flake build pipeline is the de-facto integration suite for the port:** `nix run .#build` compiles the full userland + kernel for `objtype=amd64` (with `aarch64/` artifacts synced back from the guest on darwin, `nix/vm-build.sh:64-67`); green build = port progressing.

**E2E Tests:**
- `nix run .#iso` / `build/build.bash`: boots the 9legacy ISO under `qemu-system-i386` with an `expect` harness and builds Harvey inside the VM — the full end-to-end path, cross-platform via TCG.
- CI smoke level: `.github/workflows/` builds the whole system on `ubuntu-latest` with qemu + `ufs` file serving and runs `build/command.bash`. No assertion of boot success beyond script completion.
- VM orchestration for multi-VM testing: `minimega` is packaged via `nix/minimega.nix` (Linux-only, KVM; manages Harvey/r9 **amd64** test VMs — aarch64 guests are **not** supported upstream, noted at `flake.nix:30-33`).

**Frozen-ABI verification (aarch64 port):**
- The Harvey↔r9 syscall wire contract is `aarch64/ABI.md` + `aarch64/include/ureg.h`. Phase 4 (planned) adds **build-time static checks in r9** against that header's trap-frame layout — cross-repo verification by construction, not a runtime test suite (`aarch64/ABI.md:5-8,66-72`).

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

**Verifying a host-harness change (nix/ scripts, flake.nix):**
1. `nix flake check` / `nix develop` to load the devshell
2. Run the affected app end to end: `nix run .#setup` → `nix run .#toolchain` → `nix run .#build` (on darwin this exercises the lima path; on Linux the native namespace path)
3. Keep scripts shellcheck-clean (project history includes a shellcheck-cleanup pass, commit `df615a33a`)
4. Preserve failure propagation: never let a cleanup or `||` tail mask a nonzero status (regression fixed in `566677c94`, `d663bab7b`)

**Async/Concurrent Testing:**
- No framework support. Threaded code (libthread) is tested by running the threaded program itself (e.g., rio is exercised interactively). Timeouts are handled by shell `sleep`/`await` (`rc/bin/await` exists in `rc/bin`).

**Error Testing:**
- Verify failure modes through exit status: Plan 9 convention is `exits("message")` on failure, so a test asserts `$status` is non-empty (rc) or `$? != 0` (sh). Example from lzip `check.sh`: `[ $? = 2 ] || test_failed $LINENO`.

**Reproducibility checks:**
- Kernel builds pin `KERNDATE` from the checkout's git commit (`git log -1 --format=%ct`) with numeric validation and dialect-aware `date` fallbacks (`nix/build.sh:37-51`, `nix/vm-build.sh:19-32`); override with `KERNDATE=<epoch>`. See `build/REPRODUCIBILITY.md`. The lima guest receives `KERNDATE` from the host because the rsync excludes `.git`.

**Caveats when extending tests:**
- `sys/src/cmd/test.c` is the `test(1)` *command* (the `[` builtin), not a test suite — do not be misled by the name
- Many `test:V` targets are bit-rotted or host-specific (`cifs` needs a server named `se-00`); verify before relying on them as examples
- There is no CI job that runs `mk test` anywhere — in-tree tests are opt-in, run manually; the CI/flake gate is "does the full build complete"
- `aarch64/bbin/` is currently empty and `aarch64/bin/` holds **build artifacts** of the port (including a binary named `test` — the `test(1)` command), not test suites
- On darwin, `nix run .#build` mutates nothing in the host checkout until the guest build succeeds — artifacts are only rsynced back on success (`nix/vm-build.sh:58-67`)

---

*Testing analysis: 2026-11-01*
