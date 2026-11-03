---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
# Testing Patterns

**Analysis Date:** 2026-11-03

**Bottom line up front:** This Plan 9 codebase has **no unit test framework**. There is no jest/vitest/googletest equivalent, no assertion library, no mocking framework, and no enforced coverage. In-tree testing is ad-hoc shell (rc/sh) scripts and mkfile `test:V` targets that run the built binary and compare outputs with `cmp`. The **primary verification surface is the Nix flake harness** (`flake.nix` apps): a full clean-checkout build pipeline where a failed stage fails the run, now crowned by the **self-asserting aarch64 boot smoke** (`nix run .#boot-r9-smoke` — an expect driver asserting a marker sequence over the qemu serial wire, gated on two consecutive green runs). Match these idioms when adding tests.

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
- `flake.nix` exposes the pipeline as apps (`flake.nix:44-111`): `nix run .#setup` → `nix run .#toolchain` → `nix run .#build` → `nix run .#iso`. Each stage is a `writeShellApplication` with `set -euo pipefail`; **a build failure is the test failure**.
- `nix run .#setup` (`nix/setup.sh`) — populates `$HARVEY/.build/hostbin-<os>-<arch>/bin` with the plan9port bootstrap tools; errors if `$HARVEY` is not a checkout.
- `nix run .#toolchain` (`nix/toolchain.sh`) — builds the Plan 9 cross toolchain (`BUILDTOOLCHAIN`, `cmd/BUILD`, vendored `9cc`); requires setup first and checks for `$HARVEY_LINUX_BIN/pcc` (`nix/toolchain.sh:18-21`).
- `nix run .#build` (`nix/build.sh`) — full kernel+userland build inside a Linux private mount namespace (`sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`); on darwin the same app runs `nix/vm-build.sh`, which rsyncs the checkout to a lima VM (`nix/lima-harvey.yaml`), runs `setup && toolchain && build` in the guest, and rsyncs `amd64/`, `386/`, `aarch64/` artifacts back.
- `nix run .#iso` (`nix/iso.sh`) — boots the 9legacy ISO under qemu + expect and builds Harvey inside the VM (`build/build.bash`); the cross-platform (TCG) path.
- `nix run .#boot-r9` (`nix/boot-r9.sh`, wired at `flake.nix:83-87,109`) — **the aarch64 composition** (INT-01, D-10/D-11): builds the aarch64 userland (`build/aarch64/subset-build.sh`; lima on darwin, native `sudo unshare` on linux), bakes `build/aarch64/bootfs.paq` with Harvey's own mkpaqfs (`build/aarch64/mkimage.sh`), fdtput-patches a throwaway copy of the r9 package's DTB, and launches the flake-input r9 kernel to the interactive `%` prompt on `qemu-system-aarch64 -M virt,gic-version=2` (TCG). Kernel and DTB arrive ONLY as the pinned r9 flake input's store paths via `R9_KERNEL_PKG` (`flake.lock` rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6`) — no sibling-checkout path (INT-04).
- `nix run .#boot-r9-smoke` (`nix/smoke-r9.sh` + `build/aarch64/smoke-r9.expect`, wired at `flake.nix:93-97,110`) — the SAME composed pipeline launched under the expect driver, which drives the full D-09 sweep against the serial wire and exits 0/1 for CI. **Markers are the ONLY proof — the supervisor's exit status is never trusted** (D-16).
- Both `boot-r9` apps exist only on systems where r9 ships `packages.kernel-virt` (aarch64-darwin, aarch64-linux, x86_64-linux) — a `builtins.hasAttr` gate keeps evaluation lazy elsewhere (`flake.nix:104-111`; x86_64-darwin is out of project scope).

**Assertion Library:**
- None. Assertions are `cmp` exit statuses and explicit shell `if` checks. In C, `assert` is the macro from `sys/include/libc.h` (`#define assert(x) if(x){}else _assert("x")`) — used in debug code, not in test suites.
- In the flake harness, assertions are explicit guards with stderr diagnostics: `if [ ! -x "$HARVEY_LINUX_BIN/$t" ]; then echo "error: ..." >&2; exit 1; fi` (`nix/build.sh:54-59`).

**Run Commands:**

```bash

# Flake pipeline (host-side harness; darwin builds via lima VM):

nix run .#setup && nix run .#toolchain && nix run .#build
nix run .#iso                      # qemu+expect ISO build path
nix run .#boot-r9                  # aarch64: r9 kernel + Harvey userland, interactive % prompt
nix run .#boot-r9-smoke            # aarch64: the same pipeline under the self-asserting expect smoke
R9_SKIP_BUILD=1 nix run .#boot-r9-smoke   # iteration hatch (skip userland build) — NEVER for gates
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

flake.nix             # app definitions: setup/toolchain/build/iso/boot-r9/boot-r9-smoke
nix/
├── setup.sh          # stage 1: host bin population
├── toolchain.sh      # stage 2: cross toolchain build
├── build.sh          # stage 3 (linux): namespace build
├── vm-build.sh       # stage 3 (darwin): lima guest build + artifact rsync
├── iso.sh            # qemu+expect ISO build
├── boot-r9.sh        # aarch64 compose: build → bake → DTB patch → interactive qemu
├── smoke-r9.sh       # the same pipeline under the expect smoke (exit 0/1)
├── lima-harvey.yaml  # darwin build VM definition
└── minimega.nix      # VM orchestration package (linux only)

build/aarch64/        # the aarch64 boot-chain harness + smoke surface
├── subset-build.sh   # the ONE userland-build driver (lima on darwin, nsrun.sh on linux)
├── mkimage.sh        # bakes bootfs.paq from root-tree/ + built binaries (manifest-gated)
├── mkpaqfs-host.sh   # builds Harvey's in-tree mkpaqfs as a host binary (.build/bin/)
├── run-r9.sh         # dev-time qemu launcher (--log FILE = gate mode)
├── drive-r9.expect   # interactive-gate driver (05-08; the smoke's lineage)
├── smoke-r9.expect   # the packaged smoke driver — staged marker assertions, exit 0/1/2
├── root-tree/        # committed image skeleton (lib/namespace, rc/bin/termrc, profile)
├── {init,pidwait,stacksmoke,smokefork,smokenote,tracehello}.c
│                     # harness/smoke binaries, compiled by vendored 7c/7l in the guest
├── trace-syscalls.py # donor-kernel syscall tracer (stdlib-only python3)
├── trace-boot.rc …   # rc trace scripts staged into donor bootdirs as DATA
├── out/              # gitignored: staged/harvested binaries (subset-build/stage-build)
├── bootfs.paq        # gitignored: the baked paqfs root image (mkimage.sh)
└── *.log             # gitignored transient captures (drive-r9/compose-gate/smoke-r9)
```

**Evidence conventions (the boot-chain gates):**
- Transient captures (`build/aarch64/drive-r9.log`, `compose-gate.log`, `smoke-r9.log`) are gitignored (`.gitignore`); **a passing capture is copied into the phase dir as retained evidence** by the plan's gate task. The canonical evidence bundle for the boot composition is `.planning/phases/05-shell-boot-one-command-integration/05-EVIDENCE.md` (referenced from `build/REPRODUCIBILITY.md`).
- Every capture is `rm -f`'d BEFORE qemu launches — a pre-seeded stale log is dead evidence that could satisfy the next run's marker waits (D-16/Pitfall 10; enforced at `nix/smoke-r9.sh:166-169` AND `smoke-r9.expect:68-71`).
- The committed exception to "binaries aren't evidence": `build/aarch64/hello.7.out` (the Phase-2 ABI bisect binary) IS committed as gate evidence; `build/aarch64/gate-evidence.log` accumulates sha256-stamped PASS blocks per gate run.

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

**Expect-driven boot smoke pattern (the aarch64 gate — the project's strongest test idiom):**
`build/aarch64/smoke-r9.expect` (grown from the interactive-gate driver `build/aarch64/drive-r9.expect`) spawns qemu directly with serial on stdio and walks **staged, ordered marker assertions**, each naming its failure on stderr:

```
banner ("r9 from the Internet") → paqfs… → stacksmoke ("depth 64 ok") → % prompt
→ echo round-trip ("r9shell7") → ls /bin subset (rc ls cat echo ps present)
→ ps (≥3 live-process lines, one rc) → cat /lib/namespace (known line)
→ DEL safety (partial line + 0x7f → re-prompt, rc alive, "r9delok" clean)
→ exit → init's for(;;) restart ("init: starting /bin/rc" → fresh prompt)
```

The discipline that makes the markers trustworthy:

- **Presence, never interleaving order** (D-13): TCG preemption makes arrival order meaningless; each command's output is captured up to the next `% ` prompt, then presence-asserted with word-anchored regexps (`\mname\M`).
- **Unforgeable markers:** r9's devcons does not echo typed input this era, so `r9shell7` on the wire can only be the echo binary's OUTPUT; DEL-safety uses a typed `fnord` non-command partial so a flush failure can never echo the marker through it.
- **Fast-fail on panic:** `expect_before { -re {panic|Unhandled interrupt} … }` aborts the run anywhere in the boot.
- **TCG-sized timeouts:** 600s PER STAGE (Pitfall 11); never shorten to "speed up" a gate.
- **Exit contract:** `exit 0` only when every stage passed; `exit 1` names the failed stage (banner/paqfs/stacksmoke/prompt/echo/ls/ps/cat/DEL/restart); `exit 2` on a missing-env contract violation.
- **Teardown:** every exit path kills qemu's process group; the supervising shell's EXIT trap sweeps survivors with a bracket-fixed `pkill -f '[q]emu-system-aarch64.*kernel-virt\.elf'` that cannot self-match (`nix/smoke-r9.sh:127-141`).
- **Acceptance gate = TWO CONSECUTIVE green runs**, not one (INT-02: `e97bc2245` — "two consecutive green `nix run .#boot-r9-smoke` runs on darwin + retained evidence"). A single pass is flake-suspect under TCG.

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
  - The r9 boot chain substitutes **pinned, read-only real artifacts** for the kernel: `kernel-virt.elf` + `virt-gicv2.dtb` arrive as nix store paths (`R9_KERNEL_PKG`), never as caller-supplied paths (T-05-21); the DTB is `cp`'d to a throwaway `mktemp` copy, `chmod u+w`'d, and fdtput-patched there — the store object is never mutated (`nix/boot-r9.sh:125-148`)
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
- `nix run .#boot-r9-smoke` — the aarch64 E2E (INT-02, D-12): clean-checkout → userland build → image bake → DTB patch → qemu under `build/aarch64/smoke-r9.expect` asserting the full marker sweep (boot → echo → ls/ps/cat → DEL safety → init restart). Acceptance requires **two consecutive green runs**; the darwin leg's evidence lives in the phase dir, and the **linux leg is CI**: `.github/workflows/r9-shell.yml` runs exactly `git clone → nix install (SHA-pinned) → nix run .#boot-r9-smoke` on `ubuntu-latest` with a 90-minute budget, on every push (`build/REPRODUCIBILITY.md:86-156`).
- `nix run .#boot-r9` is the interactive counterpart (terminal as console, ctrl-a x to quit) — it is NOT a self-asserting test; use it for dev, the smoke for gates.
- CI smoke level: `.github/workflows/` builds the whole system on `ubuntu-latest` with qemu + `ufs` file serving and runs `build/command.bash`. No assertion of boot success beyond script completion.
- VM orchestration for multi-VM testing: `minimega` is packaged via `nix/minimega.nix` (Linux-only, KVM; manages Harvey/r9 **amd64** test VMs — aarch64 guests are **not** supported upstream, noted at `flake.nix:37-42`).

**Frozen-ABI verification (aarch64 port):**
- The Harvey↔r9 syscall wire contract is `aarch64/ABI.md` + `aarch64/include/ureg.h`. The enforcement is **build-time static checks in r9**, not a runtime suite (`aarch64/ABI.md:83-143`): in-crate `core::mem::offset_of!` const asserts in r9's `aarch64/src/trap.rs` (fail `cargo build` on layout drift, no Harvey checkout needed) plus the cross-repo `cargo xtask ureg-check` (r9 repo) parsing this repo's `aarch64/include/ureg.h` via `R9_HARVEY_DIR` (default `../harvey`), which runs standalone and as a boot-test precondition — drift fails every r9 boot-test profile.

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
2. Run the affected app end to end: `nix run .#setup` → `nix run .#toolchain` → `nix run .#build` (on darwin this exercises the lima path; on Linux the native namespace path). For boot-chain changes: `nix run .#boot-r9-smoke` — the full composition is the test.
3. Keep scripts shellcheck-clean (project history includes a shellcheck-cleanup pass, commit `df615a33a`; a smoke EXIT-trap quoting fix landed in `163682f60`)
4. Preserve failure propagation: never let a cleanup or `||` tail mask a nonzero status (regression fixed in `566677c94`, `d663bab7b`)

**Adding a stage to the boot smoke (`build/aarch64/smoke-r9.expect`):**
1. Append a `stage <name> {<regex>}` assertion (or a `send` + capture + presence-check block) BEFORE the DEL/exit stages — the state-resetting stages stay LAST so the sweep rides the first rc generation.
2. Patterns are presence-only CRLF-tolerant substrings, never end-of-line anchored (D-13); choose markers that cannot be produced by typed-input echo (r9's devcons does not echo).
3. Name the stage — the failure line `smoke-r9: TIMEOUT at stage: <name>` is the only localization a CI log gets.
4. Re-run the gate TWICE (`nix run .#boot-r9-smoke` × 2 consecutive green) and retain both captures as phase evidence.

**Evidence-log conventions (boot-chain gates):**
- Capture path is env-overridable (`R9_SMOKE_LOG`, default `build/aarch64/smoke-r9.log` — gitignored); the caller `rm -f`s it before launch and the driver does so again belt-and-braces.
- A PASSING capture is copied into the phase dir (e.g. the 05-12 gate's evidence); the gitignored working copy is transient.
- Keep `log_user` ON in expect drivers — expect 5.45 writes nothing to `log_file` with `log_user 0` (measured; the capture file is created empty).

**Async/Concurrent Testing:**
- No framework support. Threaded code (libthread) is tested by running the threaded program itself (e.g., rio is exercised interactively). Timeouts are handled by shell `sleep`/`await` (`rc/bin/await` exists in `rc/bin`).

**Error Testing:**
- Verify failure modes through exit status: Plan 9 convention is `exits("message")` on failure, so a test asserts `$status` is non-empty (rc) or `$? != 0` (sh). Example from lzip `check.sh`: `[ $? = 2 ] || test_failed $LINENO`.

**Reproducibility checks:**
- Kernel builds pin `KERNDATE` from the checkout's git commit (`git log -1 --format=%ct`) with numeric validation and dialect-aware `date` fallbacks (`nix/build.sh:37-51`, `nix/vm-build.sh:19-32`); override with `KERNDATE=<epoch>`. See `build/REPRODUCIBILITY.md`. The lima guest receives `KERNDATE` from the host because the rsync excludes `.git`.
- The r9 boot reproduction (INT-03, `build/REPRODUCIBILITY.md:86-170`) is **process-level**, not bit-level: the documented command sequence (`git clone … && nix run .#boot-r9-smoke`) reproduces the green smoke on darwin-aarch64 and linux from clean checkouts, resting on the pins: r9 at rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` + narHash in `flake.lock`, nixpkgs at `31ecbaca1bdefa45dffc409f0250bd8039ea0010`, r9's rust toolchain (`nightly-2026-01-30` via rust-overlay, captured transitively), qemu 11.1.2-era from the nixpkgs pin. `bootfs.paq` bytes differ across checkouts (mkpaqfs embeds KERNDATE-derived time) — the smoke asserts boot BEHAVIOR (marker sequence, D-09 sweep, DEL safety, init restart), never image bytes.
- Dev-only overrides (never the default, never CI): `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` (local r9 checkout, D-13); `R9_SKIP_BUILD=1` (skip the userland build leg).

**Caveats when extending tests:**
- `sys/src/cmd/test.c` is the `test(1)` *command* (the `[` builtin), not a test suite — do not be misled by the name
- Many `test:V` targets are bit-rotted or host-specific (`cifs` needs a server named `se-00`); verify before relying on them as examples
- There is no CI job that runs `mk test` anywhere — in-tree tests are opt-in, run manually; the CI/flake gate is "does the full build complete" plus (for aarch64) "does the boot smoke pass" via `.github/workflows/r9-shell.yml`
- `aarch64/bbin/` is currently empty and `aarch64/bin/` holds **build artifacts** of the port (including a binary named `test` — the `test(1)` command), not test suites
- `build/aarch64/out/`, `build/aarch64/bootfs.paq`, and the `*.log` captures are gitignored REGENERABLE artifacts — never commit them as evidence; copy passing captures into the phase dir instead. The exception is `build/aarch64/hello.7.out` (committed ABI-bisect gate binary).
- On darwin, `nix run .#build` mutates nothing in the host checkout until the guest build succeeds — artifacts are only rsynced back on success (`nix/vm-build.sh:58-67`)
- `nix run .#boot-r9` / `.#boot-r9-smoke` do not exist on x86_64-darwin (the `builtins.hasAttr system r9.packages` gate at `flake.nix:104-111` — r9 ships no kernel-virt there)
- The smoke's qemu argv values (GICv2, cortex-a72, 1024M, TCG, initrd at `0x48000000`) are the carried-forward LOCKED shape from r9's `aarch64/lib/config_virtexec.toml` — do not "upgrade" to HVF or GICv3 here; the TCG constraint rationale is documented in `build/aarch64/README.md`

---

*Testing analysis: 2026-11-03*
