---
phase: 06-full-tree-userspace-wave-0-libraries-core-tiers
reviewed: 2026-11-05T13:12:20Z
depth: standard
files_reviewed: 48
files_reviewed_list:
  - aarch64/include/u.h
  - build/aarch64/coverage-sweep.sh
  - build/aarch64/dir-coverage.txt
  - build/aarch64/donor-vm-build.sh
  - build/aarch64/generator-audit.txt
  - build/aarch64/generator-scan.sh
  - build/aarch64/gethunk-repro-6l.sh
  - build/aarch64/gethunk-repro-cc.sh
  - build/aarch64/ledger-r9-append.sh
  - build/aarch64/markers/tier0.ledger
  - build/aarch64/markers/tier1.ledger
  - build/aarch64/mkimage.sh
  - build/aarch64/nm-input.7
  - build/aarch64/pre-gate-build.sh
  - build/aarch64/run-gate.sh
  - build/aarch64/stage-build.sh
  - build/aarch64/subset-build.sh
  - build/aarch64/subset-exec.sh
  - build/aarch64/tier1-r9.expect
  - build/aarch64/tier1-sweep.rc
  - build/aarch64/tiers/tier0-libs.txt
  - build/aarch64/tiers/tier1-cmds.txt
  - build/aarch64/tiny.l
  - build/aarch64/tiny.mk
  - build/aarch64/tiny.s
  - build/aarch64/tiny.y
  - build/aarch64/tracesup.c
  - build/aarch64/vm-run.sh
  - build/mm/boot-9k10cpu-qemu.sh
  - build/scripts/linux-build
  - flake.lock
  - flake.nix
  - .github/workflows/phase6.yml
  - .gitignore
  - nix/tier1-r9.sh
  - sys/src/cmd/6l/obj.c
  - sys/src/cmd/7l/asm.c
  - sys/src/cmd/auth/factotum/mkfile
  - sys/src/cmd/auth/mkfile
  - sys/src/cmd/cc/macbody
  - sys/src/cmd/ip/mkfile
  - sys/src/cmd/mkfile
  - sys/src/cmd/mkmany
  - sys/src/cmd/rc/havefork.c
  - sys/src/games/mkfile
  - sys/src/libdraw/mkfile
  - sys/src/libdynld/dynld-aarch64.c
  - sys/src/mkfile
findings:
  critical: 1
  warning: 8
  info: 4
  total: 13
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-11-05T13:12:20Z
**Depth:** standard
**Files Reviewed:** 48
**Status:** issues_found

## Summary

Reviewed the phase-06 aarch64 full-tree userspace machinery: the gethunk
accumulate-when-contiguous fixes (cc/macbody, 6l/obj.c), the 7l LP64
ieee-emission fix, the FPdbleword uint fix, the rc Xbackq pushlist fix, the
D-13 tier allowlists + five mk filter sites, the sweep/coverage/generator
harness scripts, the tier-1 execution gates (donor + r9), tracesup.c, the
phase6 CI workflow, and the nix glue.

The core C fixes are correct as far as they go: the gethunk merge condition
(`h == hunk + nhunk`) is sound for the hunk allocator's never-free design,
the 7l `fhw[2]` emission produces byte-identical output to the ILP32 struct
layout on every host, the u.h `uint lo/hi` change matches the amd64
reference exactly, and the havefork.c fix restores the `argv != 0` invariant
before the deref loop. The mk filter keep-rule is applied consistently
across all five sites, and the committed data artifacts (dir-coverage.txt,
both ledgers) are internally consistent with their generators (221 = 206 + 15;
59 r9 lines = 62 tier entries - 3 driver-only).

However, the review surfaced one blocker (the committed tier-donor CI leg
cannot pass on a clean runner — nothing populates the donor tree), and a
cluster of warnings around incomplete fix-class application (6l/9l still
carry the LP64 ieee defect the phase proved in 7l), latent gate holes
(generator-scan single-digit row regex, unguarded $HARVEY in the mk
filters), an unchecked array bound in tracesup.c, and dialect/portability
drift in ledger-r9-append.sh.

## Critical Issues

### CR-01: tier-donor CI leg cannot pass on a clean runner — no step clones or builds the donor

**File:** `.github/workflows/phase6.yml:127-152` (interacting with `build/aarch64/subset-exec.sh:173-177`)
**Issue:** The `tier-donor` job runs `subset-build.sh` then `subset-exec.sh`
on a clean `ubuntu-latest` checkout. subset-exec.sh's preconditions
hard-require `.build/9front-donor` pinned at
`350266104f1fed81c78c3d05fa44f523bec0ae4d` (`git -C "$DONOR" rev-parse HEAD`,
errors with "donor pin mismatch: want ..., have missing" when absent) plus
`$DIST/9qemu.u` and `$ROOTFS/arm64/bin` — but no step in the job produces
any of these. The only donor-populating driver, `donor-vm-build.sh`, is
lima-mediated end to end (unconditional `limactl` use; the linux devshell
ships no lima per flake.nix's `pkgs.lib.optionals (!isLinux) [ lima ]`),
and is not invoked by any CI step. subset-exec.sh:618's own hint says
"06-08's CI job owns the native donor build" — that step never landed in
the committed workflow, whose header (lines 16-20) claims "the donor clone
pin-verified to 350266104f host-side"; only the verify runs, never the
clone. Verified by grep: no workflow step and no native-linux script
references a donor clone/fetch/build; `nix develop`'s shellHook only echoes
and exports. On a clean runner the leg reds in seconds at the pin gate —
the committed D-16 full-pipeline CI is structurally incapable of green on
this leg.
**Fix:** Add a native-linux donor stage to the `tier-donor` job before
subset-exec.sh — clone the pin into `.build/9front-donor`, build host
helpers, and run the `donor-ns-build.sh` shape natively (sudo unshare) to
produce `.build/9front-dist/9qemu.u` + `srvroot/` — or mark the leg
explicitly manual until that driver exists. Alternatively, teach
subset-exec.sh's native leg the clone-if-missing logic donor-vm-build.sh
already has (its lines 73-80), so the gate is self-contained on both
venues.

## Warnings

### WR-01: The LP64 Ieee-emission fix was applied to 7l only — 6l and 9l carry the identical proven-faulty pattern

**File:** `sys/src/cmd/6l/asm.c:297` (also `sys/src/cmd/9l/asm.c:556`), measured against this phase's `sys/src/cmd/7l/asm.c:506-531`
**Issue:** The phase fixed 7l's `case 8` D_FCONST emission because casting
`struct Ieee {long l; long h;}` (16 bytes on LP64 hosts) emits `l`'s low
half then its zero high half — `h` never reaches the literal pool, proven by
the 06-03 awk `%.3f` float-canary fault on the donor. 6l/asm.c:297 still
does `cast = (uchar*)&p->to.ieee;` over `fnuxi8` against the identical
struct (`sys/src/cmd/6c/6.out.h:934-941`), and 6l is the host-built linker
for every amd64 build on the LP64 hosts this project uses. Any amd64 binary
embedding an 8-byte double constant gets its high 32 bits zeroed at link
time — silent data corruption of the exact class this phase fixed. (9l is
the same shape but power64 is not exercised.) The amd64 legs have no
float-canary gate, so nothing would have caught it.
**Fix:** Mirror the 7l repair in 6l (and 9l for completeness):
```c
case 8:
	fhw[0] = p->to.ieee.l;	/* 6l embeds Ieee by value */
	fhw[1] = p->to.ieee.h;
	cast = (uchar*)fhw;
	nuxi = fnuxi8;
	break;
```
(with `int fhw[2];` in datfill's declarations), or record a deliberate
deferral with evidence that no swept amd64 binary carries a double
constant.

### WR-02: mk tier filters silently produce an empty aarch64 sweep when $HARVEY is unset

**File:** `sys/src/mkfile:68-75` (same shape in `sys/src/cmd/mkfile:29-33`, `sys/src/cmd/auth/mkfile:48-52`, `sys/src/cmd/ip/mkfile:36`, `sys/src/cmd/auth/factotum/mkfile:11-14`)
**Issue:** The keep-list extractions read `$HARVEY/build/aarch64/tiers/…`.
With `objtype=aarch64` and `HARVEY` unset, those become
`/build/aarch64/tiers/…` — a path the namespace never binds (the comment
itself cites Pitfall P6-2) — awk errors, `T0KEEP`/`T1KEEP` come back empty,
and `LIBS`/`CMDS`/`SUBSYS` (and downstream `TARG`/`DIRS`) filter to
nothing. mk does not abort on a failed backquote assignment, so
`objtype=aarch64 mk libs` / `mk install` becomes a green no-op sweep — the
worst failure shape for a coverage gate (silence, not red).
**Fix:** Guard the filter sites, e.g. prepend to each filter line's rc:
`if(~ $HARVEY ''){ echo 'mk: HARVEY unset (tier filter needs it)' >[1=2]; exit 1 }`
or have the extraction pipe awk's failure into a non-empty sentinel that
fails the `~` match loudly.

### WR-03: generator-scan.sh's audit-row selector silently skips G10+ rows

**File:** `build/aarch64/generator-scan.sh:109`
**Issue:** `"$GREP" '^G[0-9] site=' "$AUDIT"` matches only single-digit row
numbers. The audit file's own maintenance instruction is "add the next G
number in the same commit as its host-toolchain proof" — the next number is
G10, which this regex will not select. A G10 row would be silently skipped
by the runs=always artifact asserts (no missing-artifact RED, no magic
check), so the drift tripwire fails exactly when it is next exercised. The
negative sweep (section 2) covers only the five named shapes, so a new
generator name would escape entirely.
**Fix:** Change the selector to `'^G[0-9]+ site='`.

### WR-04: tracesup.c armed/kids arrays grow without a bounds check

**File:** `build/aarch64/tracesup.c:226-230, 261-262`
**Issue:** `armed` and `kids` are allocated at fixed capacity
`(npre + 4096) * sizeof(int)` and grown with `armed[narmed++] = pid;` /
`kids[nkids++] = kid;` inside the poll loop with no capacity check. A run
that arms more than `npre + 4096` distinct pids (armed pids are never
removed, so pid reuse does not help) writes past both heap allocations —
silent corruption in the guest supervisor that produces the run's trace
evidence.
**Fix:** Add a capacity guard before each insert:
```c
if(narmed >= npre + 4096)
	sysfatal("tracesup: armed table full");
```
(or realloc to double). Same for `kids`.

### WR-05: mkimage.sh line 235 is dead, known-broken code left armed

**File:** `build/aarch64/mkimage.sh:235`
**Issue:** `trailer=$(dd if="$IMAGE" bs=1 skip=$((sz - 28)) count=4 2>/dev/null | od …)`
is computed and then unconditionally overwritten by the od-based line 240.
Worse, the dd invocation is the measured-broken path the comment at 236-239
describes: Harvey's dash-pair host dd shadows POSIX dd on the devshell PATH,
so this line silently yields an empty `trailer` (the pipeline's exit status
is od's, so `set -e` never fires). If the od line is ever deleted or
reordered, the bake fails red with an empty trailer and no diagnostic.
**Fix:** Delete line 235 outright.

### WR-06: subset-exec.sh marker asserts are unanchored substring greps (mk⊂mkdir, cp⊂cpp)

**File:** `build/aarch64/subset-exec.sh:816-818`
**Issue:** `grep -q "T1-OK $m" "$RUNLOG"` matches substrings: the `T1-OK mk`
pattern is satisfied by a `T1-OK mkdir` line, and `T1-OK cp` by a
`T1-OK cpp` line. If a marker were absent (sweep truncation) while its
superset sibling passed, the gate would false-green. Bounded today by the
zero-`T1-FAIL` and `T1-DONE` asserts, so this is assertion precision rather
than a live soundness hole — but the r9-side driver
(`build/aarch64/tier1-r9.expect:166-172`) does the same check correctly with
`\n`-anchored matches, so the two venues enforce different rigor for the
same marker vocabulary.
**Fix:** Anchor the donor-side asserts, e.g. on a CR-normalized log:
`grep -qE "T1-OK $m([^A-Za-z0-9.-]|\$)" "$RUNLOG"`.

### WR-07: ledger-r9-append.sh uses bash-only process substitution under #!/bin/sh, plus undisciplined grep/sha256sum

**File:** `build/aarch64/ledger-r9-append.sh:76` (also lines 22, 36)
**Issue:** `done < <(awk …)` is a bashism; under dash (ubuntu's /bin/sh —
the CI host class this phase targets) the script dies with
`Syntax error: "<" unexpected`. It survives on darwin only because macOS
`/bin/sh` is bash in POSIX mode, which still permits `< <()`. Separately,
line 22 uses bare `grep -oE` — every sibling script in this phase resolves
a host grep via the D-02 `GREP=$(command -v /usr/bin/grep || command -v grep)`
idiom because plan9port grep lacks `-o`/`-E` — and line 36 uses bare
`sha256sum` with no `shasum -a 256` fallback (run-gate.sh:89-95 carries that
fallback; this script doesn't). The committed ledger proves it ran once
(darwin), but as committed it cannot re-run on the CI host's /bin/sh.
**Fix:** Replace the process substitution with a plain pipe
(`awk … | while IFS= read -r line; do … done` — the loop needs no state
afterward), adopt the GREP resolution idiom, and add the shasum fallback.

### WR-08: gethunk-repro-6l.sh's "built fresh every run" claim is narrower than the code

**File:** `build/aarch64/gethunk-repro-6l.sh:229-231` (header claim at lines 45-48)
**Issue:** The header says the fixed pair is "built fresh from the working
tree every run — the gate never trusts hostbin staleness", but the rebuild
condition only compares `sys/src/cmd/6l/obj.c`'s mtime against
`fixed-bin/6l`. A change to any other 6l source (l.h, unixcompat.c,
span.c, pass.c, …) leaves the "fixed" 6l stale, and the GREEN/RED verdict
then measures an old binary while claiming otherwise.
**Fix:** Rebuild unconditionally (the pair builds in seconds), or extend
the `-nt` probe to the full 6l + shared-cc source set.

## Info

### IN-01: run-gate.sh's remediation hint points at a script that refuses to run

**File:** `build/aarch64/run-gate.sh:99`
**Issue:** The precondition error says "run sh
build/aarch64/pre-gate-build.sh (plan 02-03) first", but
pre-gate-build.sh's obsolescence guard (lines 72-75) exits 2 on any tree
where `aarch64/mkfile` is committed — i.e. every current checkout.
hello.7.out is committed gate evidence; the hint should say to restore it
from git, not to run a script that can never run again.
**Fix:** Update the hint text.

### IN-02: mkimage.sh duplicate input asserts

**File:** `build/aarch64/mkimage.sh:99-100`
**Issue:** The `$BIN/ip/ipconfig` and `$BIN/auth/factotum` existence checks
are byte-identical duplicates of lines 79-80 (the 06-07 block re-asserts
what the subset block already asserted). Harmless, but reads like a merge
artifact.
**Fix:** Drop lines 99-100.

### IN-03: generator-scan verifies only G6's guard mechanically

**File:** `build/aarch64/generator-scan.sh:103-104, 151-174`
**Issue:** The audit self-consistency check covers only G6 (`7.genarch`).
G8's guard (`runs=never-cross`, artifact `7.regen`, guard at
upas/bayes/mkfile:16) is neither in the negative-sweep name set nor
drift-checked — a removed guard would not red the scan. The audit header
presents the scan as the mechanical red for the whole invariant; the G8
class currently rests on prose only.
**Fix:** Either extend the negative-sweep name set/whitelist-derivation to
G8, or note the asymmetry in the audit header.

### IN-04: gethunk reset pattern survives in the out-of-scope linkers

**File:** `sys/src/cmd/8l/obj.c:1250`, `sys/src/cmd/4l/obj.c:1222`, `sys/src/cmd/5l/obj.c:1233`, `sys/src/cmd/9l/obj.c:1248`, `sys/src/cmd/kl/obj.c:1067`, `sys/src/cmd/ql/obj.c:1217`, `sys/src/cmd/vl/obj.c:1165`, `sys/src/cmd/il/obj.c:1202`, `sys/src/cmd/ld/sub.c:222`
**Issue:** Nine other-arch linker gethunk copies still do the unconditional
`hunk = h; nhunk = nh;` reset this phase proved is a silent hang-class land
mine. None are exercised by the amd64/aarch64 sweep (386 is deferred scope;
the rest are other-arch), so there is no current exposure — but the class is
now documented and the next port will trip it.
**Fix:** A Phase-10 tracking note; when any of these letters becomes a host
tool, apply the accumulate-when-contiguous merge from 6l/obj.c:1307-1326.

---

_Reviewed: 2026-11-05T13:12:20Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
