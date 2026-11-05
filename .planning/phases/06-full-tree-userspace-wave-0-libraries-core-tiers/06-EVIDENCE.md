# Phase 6 — Evidence Bundle

**Phase:** 06-full-tree-userspace-wave-0-libraries-core-tiers
**Started:** 2026-11-05

## The gate stack (06-03 proven end-to-end)

Tier data files (`build/aarch64/tiers/tier{0,1}-*.txt`, D-13 append-only
allowlists) drive `subset-build.sh` (tier-0 fresh-archive lib builds with
T0-ART sha256 markers; tier-1 entry-form dispatch with T1-ART sha256
markers) and `subset-exec.sh` (stage h-prefix binaries + `tier1-sweep.rc`
+ `hello.c` into the donor tree → marker-guarded CONF=qemu bootdir patch
→ targeted rebake → qemu TCG boot → the staged termrc override SOURCES
the sweep → per-binary T1-OK/T1-FAIL serial markers + the D-01 float
canary + T1-DONE → host presence assertions, zero T1-FAIL, zero
panic|trap:).  mk exit status is never trusted anywhere in the flow.
Ledgers: `build/aarch64/markers/tier{0,1}.ledger` (D-14 append-only;
8-field fixed-order lines; last line per dir wins).

Venues: darwin (lima guest builds, host-side qemu) and native linux
(nsrun sudo-unshare; `--print-platform` dispatch proof).  Donor pin
350266104f1fed81c78c3d05fa44f523bec0ae4d verified host-side per run.

## 06-03 tracer run record

- **Commit:** 7123bce9f5956dfc5e3c92b81e46001c627f9638 (machinery state
  the gate ran; the 7l LP64 fix is 2bbca81ed, included)
- **Host:** darwin-aarch64 (lima guest builds + host qemu TCG)
- **Runs:** two consecutive green donor gates — the initial gate and the
  tracer-feedback re-verify (same retained log path; the retained log is
  the re-verify run)
- **Markers:** 19 × T1-OK (stacksmoke echo ls cat grep sed wc date test
  rc ps ipconfig factotum awk mkdir cp mv rm float-d01) + T1-DONE; zero
  T1-FAIL; zero panic|trap:; float canary `awk 'BEGIN{printf "%.3f\n",
  1.0/3.0}'` → `0.333` (D-01 execution-asserted)
- **Log:** [evidence/06-03-tracer-donor.log](evidence/06-03-tracer-donor.log)
- **The tracer's catch:** the first run faulted hawk (null read in
  abort()) — root-caused to 7l's LP64 double-constant pool emission
  (struct Ieee is 16 bytes on LP64 hosts; the 8-byte emit wrote l's low
  half + zeroes, never h) → fixed `2bbca81ed`, re-proven.

## Tier-0 carrier mapping (D-06 consumer-carried execution)

Per-lib carrier evidence: a swept tier-1 binary links the lib iff the
lib's header is included by the binary's sources.  Grep evidence
(`grep -lE '<lib\.h>'` over the swept sources, 2026-11-05):

| Lib | Carrier (swept tier-1 binary ← including sources) | Ledger exec |
|-----|---------------------------------------------------|-------------|
| libc | every swept binary (u.h/libc.h universal) | CARRIED:tier1-consumer |
| libbio | awk (awk/*.c), grep (grep/grep.h), ipconfig (ip/ipconfig/*), ls.c, ps.c, sed.c, wc.c | CARRIED:tier1-consumer |
| libregexp | sed.c, awk/re.c | CARRIED:tier1-consumer |
| libip | ipconfig (ipv6.c, main.c, ppp.c); also factotum/secstore.c | CARRIED:tier1-consumer |
| libndb | ipconfig (main.c, ppp.c) | CARRIED:tier1-consumer |
| libmp | factotum (dat.h); also paqfs | CARRIED:tier1-consumer |
| libsec | factotum (dat.h); also paqfs | CARRIED:tier1-consumer |
| libString | factotum (dat.h) | CARRIED:tier1-consumer |
| libthread | factotum (dat.h) | CARRIED:tier1-consumer |
| lib9p | factotum (dat.h) | CARRIED:tier1-consumer |
| libauth | factotum (dat.h); also paqfs/paqfs.c | CARRIED:tier1-consumer |
| libauthsrv | factotum (dat.h) | CARRIED:tier1-consumer |
| libflate | paqfs (mkpaqfs.c, paqfs.c) — paqfs's donor-kernel execution evidence is the 05-03 real-chain trace (BOOT:donor) | CARRIED:tier1-consumer |
| libavl | **none** — tree-wide, avl.h's only consumer is venti/copy.c (Phase 10) | EXCLUDED:no-tier1-consumer |

The swept binaries' donor execution evidence is the 06-03 gate log;
factotum's dat.h carries the libsec/libmp/libString/libthread/lib9p/
libauth/libauthsrv/libip includes (the whole factotum closure).

## Boot-chain classification (06-03 Task 2)

| Entry | exec | Evidence |
|-------|------|----------|
| stage/stacksmoke | BOOT:donor | 06-03 gate log — the staged termrc runs /boot/hstacksmoke (`T1-OK stacksmoke` + `stacksmoke: depth 64 ok`) |
| 9k/boot | BOOT:donor | 05-03 real-chain trace (`05-03-trace.txt`): our boot(8) ran its real flow on the donor kernel (opencons → connectembed → fversion → mount → execinit) |
| stage/init | BOOT:donor | 05-03 real-chain trace: our init ran `init -t → newns → termrc` on the donor kernel |
| cmd/paqfs:paqfs | BOOT:donor | 05-03 real-chain trace: our paqfs served the root over the 9P pipe on the donor kernel |

The 06-03 subset-exec venue boots the donor's OWN boot chain (the guest
is the donor kernel + donor init + served rootfs), so the 06-03 gate log
cannot evidence our boot(8)/init/paqfs — the 05-03 trace is their honest
donor-kernel execution evidence.  (USPACE-04 transparency: no execution
claim without serial-marker evidence.)

## 06-04 coverage sweep run record (USPACE-02, D-15)

- **Commit:** the run executed against base `f4ce2326872414a464ac9fffd22fc4dd5ed2e2c0`
  plus the 06-04 machinery working-tree edits (games checkall,
  coverage-sweep.sh); the machinery lands in the 06-04 Task-1 commit on
  top, and the committed report's authoring-run line names that base.
- **Host:** darwin-aarch64; build in the lima guest's linux-aarch64
  namespace (the report's venue line — the build host class is always
  linux-aarch64).
- **Sweep:** 212 visits / 212 exits / 0 watchdog fires; universe 221,
  visited 206, excluded 15 — reconciliation CLOSED, phantom-free, no
  stale exclusions.  58 per-dir `build=fail` rows recorded as Phase-10
  backlog data (almost all missing tier-0 libraries: libmemdraw,
  libhttpd, libplumb, libventi, … — 06-05's wave).
- **Second-chance pass (35 dirs):** plan9port mk recipes abort at the
  first failing command (measured 2026-11-05 with a toy mkfile: a
  container's `for(i in $DIRS) @{ cd $i; mk all }` stops at the first
  failing sibling — the strict abort-on-first-failure semantics 06-02
  documented).  With tier-0 libs outstanding, ip's loop stopped at httpd
  (libhttpd), upas's at fs (libplumb), postscript's at common, aux's
  inside its DIRS — 35 dirs were never reached.  The sweep's pass 2
  visits each remaining dir with its own guarded `mk all` (the log's
  SECOND-CHANCE lines), so reach is TOTAL and the adjacency truth holds:
  ipconfig + all 6 ip siblings are visited and recorded.
- **Wave-0 blocker re-verification:** jpg's committed ycbcr.h/rgbv.h can
  satisfy mk without the generator chain firing, so the run FORCES it in
  the scratch guest tree (rm headers + unix.* generators, `mk ycbcr.h
  rgbv.h`): unix.rgbycc and unix.rgbrgbv rebuilt via 9c/9l and asserted
  host-ELF (`BLOCKER-CHECK … magic=7f454c46` ×2) — the Phase-1 fix
  (7be7e98c8) holds for the aarch64 sweep.  mahjongg `visited=1
  build=ok` (fresh; citation 01-01-SUMMARY.md:156).  4a `visited=1
  build=ok` as an aarch64-target build here; target-sweep-excluded by
  decision (01-01-SUMMARY.md:150 + PITFALLS notorious-dirs).
- **Logs:** driver log `.build/coverage-sweep.log` (gitignored, full
  compile output); reach evidence
  [evidence/06-04-coverage-log.txt](evidence/06-04-coverage-log.txt)
  (committed: the VISIT/EXIT/SECOND-CHANCE log the report was parsed
  from).
- **Toolchain dialect findings (recorded for every later namespace
  script):** inside the namespace (and on the devshell host PATH) the
  Harvey hostbin shadows core tools — Plan 9 sed garbles on `|` inside a
  /-delimited pattern and silently fails `\(\)`/`\1` extractions; Plan 9
  date prints the epoch for `-u +%Y-%m-%d`.  coverage-sweep.sh uses awk
  index/substr or plain-`^` seds and a probe-verified ISO date
  (D-02-shadowing class; 07-04's dd incident was the same class).
- **Observed anomaly (run 1):** jpg's generator chain did not fire
  during that run's checkall (headers committed + fresh; mk's missing-
  prereq chase is proven to fire in three controlled reproductions) —
  the guest's `.build` was concurrently wiped/rebuilt by the Phase-07
  session mid-run, the probable state-churn cause; per the
  concurrent-session rule the probes were made state-independent (the
  forced blocker re-verification) and the run repeated.
- **Ledger lines appended:** none (06-04 owns committed reports, not
  tier markers).

## 06-04 generator audit + .7-magic scan run record (USPACE-03)

- **Commit:** the run executed against base `f4ce2326872414a464ac9fffd22fc4dd5ed2e2c0`
  plus the 06-04 machinery (the Task-1 + Task-2 commits land it).
- **Audit:** `build/aarch64/generator-audit.txt` — exactly 9 `G<n>
  site=` rows (G1-G9, re-confirmed against the live mkfiles at
  authoring) + the `not-swept:` section (linker self-checks, compiler
  t:/x: manual targets, test targets, ip/httpd trial, jtagfs rtest,
  cmd/mkfile compilers:V, 9k/mk/parse).  Two plan-text corrections from
  live-mkfile re-confirmation: G5's artifact is `o.pcode`
  (cpuobjtype=`o` via /unix/mkfile's O=o), and G6's genarch is
  **pcc-built native-only** (gs/mkfile:163-164's build guard) — the
  plan's "$CC-built BUT guarded" described the older shape; the guard
  proof stands (run guard :149, build guard :164).
- **Scan:** `sh build/aarch64/generator-scan.sh` — GREEN on the swept
  tree: G1-G5 host ELF (7f454c46), G7 `#!/b…` (23212f), G9 ed-script
  text (6564202d, NOTE), G6/G8 skipped (guarded), whitelist armed on
  exactly 7.genarch (not present — expected under the current gs
  guard), zero exec-format lines in the sweep log.
  [evidence/06-04-generator-scan.log](evidence/06-04-generator-scan.log)
- **Teeth proof:** planted the sweep-built `sys/src/cmd/va/7.out`
  (R_MAGIC 00008c47, od-verified) as `sys/src/cmd/jpg/7.rgbycc` in the
  guest tree → scan exit 1 with
  `RED: target-built generator in the tree: sys/src/cmd/jpg/7.rgbycc`
  + `GENERATOR-SCAN-FAIL`; plant removed; re-run green.
  [evidence/06-04-generator-scan-teeth.log](evidence/06-04-generator-scan-teeth.log)
- **darwin probing:** on darwin the scan checks the tree the sweep
  built (the lima guest's rsync copy) over ssh with `</dev/null` on
  every probe — ssh consumes the caller's stdin otherwise (measured:
  the rows loop processed only G1 before the fix); on linux the local
  tree is the build tree (namespace binds it).

## Format note for later plans (06-04..06-08 appends)

One section per gated run: commit SHA (the machinery state that ran),
host, marker summary, retained log path under `evidence/`, and the
ledger lines appended by the run.  Append-only; never edit earlier
records (supersede via the ledgers' last-line-wins rule and a new
section here).

## 06-05 tier-0 library wave record (USPACE-05, D-05..D-08)

- **Commits:** verdict `2d2fa5725` (libdynld rename kept — probe-built
  green in the namespace venue BEFORE the wave); wave machinery
  `fa19c15f7` (21 appends in the research dependency sort + the liblex
  archive-name mapping + the darwin lib rsync-back); ledger seed
  `90224e2e8` (22 × PENDING-CLASSIFY in exact tier-file order); libtest
  machinery + donor gate `9397b6823` (the commit the classification
  lines name).
- **Host:** darwin-aarch64 (lima guest linux-aarch64 namespace builds;
  host qemu TCG donor boots).
- **Sweep:** 35/35 `T0-ART` lines, `TIER-BUILD-OK`, zero per-lib compile
  fixes needed.  Member sanity: every object member across all 35 fresh
  archives is `.7` — zero committed `.6`/`.8` cargo-culted (D-07;
  `__.SYMDEF` symtabs aside); host archives byte-matched the guest
  gate-time sha256s at rsync-back.
  Log: [evidence/06-05-tier0-wave-build.log](evidence/06-05-tier0-wave-build.log)
- **libdynld verdict (D-08 recommendation (i)):** `dynld-arm64.c →
  dynld-aarch64.c` rename KEPT — probe-built before the wave
  (`rm -f /aarch64/lib/libdynld.a`, `objtype=aarch64 mk install` →
  fresh 3-member `.7`-only archive, `DYNLD-PROBE-OK`).  Compile note
  filed below (not a failure).
- **liblex machinery fix (not a compile failure):** liblex's mkfile
  builds `libl.a` (the lex runtime's historical name — consumers link it
  by that name), not `liblex.a`; the driver's lib<dir-minus-lib> name
  map aborted the first sweep run at liblex (`no artifact
  /aarch64/lib/liblex.a` after a green compile).  Fixed with an explicit
  per-lib archive-name case in subset-build.sh.
- **Execution classification (D-06/D-08) — all 22 final:**
  - `TEST:donor` (in-tree test ran green on the donor): **libdraw**
    (`T1-OK libtest-tdraw` — the additive `$O.test` rule this wave adds;
    test.c had no rule), **libdisk** (`T1-OK libtest-disktest` —
    opendisk's plain-file fallback on a /tmp fixture).
  - `TEST-FAIL:donor` (in-tree tests ran and FAULTED — filed Phase-10
    checklist below): **libmemdraw** (drawtest + arctest).
  - `PENDING:nm-tier1`: **libmach** — `nm.c:8` `#include <mach.h>`; nm
    joins tier-1 in 06-06 and supersedes this line to CARRIED:nm.
  - `EXCLUDED:no-consumer`: **libaml** (only self-consumers tree-wide;
    the 9k kernel never includes aml.h), **libdynld** (zero dynld.h
    includers outside libdynld — rename verdict recorded, artifact
    green).
  - `EXCLUDED:no-tier1-consumer` (16): libavl (avl.h's only tree-wide
    consumer is venti/copy.c), libbin (upas/bayes/dfa.c, venti/copy.c),
    libcomplete (acme/text.c; gs excluded), libgeometry, liblex (libl.a
    is the runtime for lex-GENERATED scanners; the lex binary itself
    self-contains — sub1.c defines allprint), libstdio (153 cmd
    includers, ape-flavored, Phase-10), libplumb (tier-3 plumber),
    libscribble (sole consumer libcontrol/scribble.c — a tier-3 lib
    chain, no tier-1 binary), libmemlayer (tier-3 GUI; arctest
    references no memlayer symbol), libframe (acme/sam), libcontrol
    (tier-3 GUI), libhtml (webfs/links), libhttpd (ip/httpd),
    libsunrpc (9nfs/nfs), libventi + liboventi (venti suite).
    Grep evidence: no swept or 06-06-planned tier-1 source includes any
    of these libs' headers, and no `#pragma lib "<archive>"` references
    them (swept-set + tree-wide greps, 2026-11-05).
- **Ledger lines appended:** 22 PENDING-CLASSIFY seeds (`90224e2e8`),
  superseded by the 22 final classification lines (the classification
  commit; last-line-per-dir-wins).

### Phase-10 per-dir checklist (the plan's no-drive-by rule — filed, not fixed)

- **libmemdraw (drawtest):** donor run faults — `suicide: sys: trap:
  fault read addr=0x0 pc=0x1ab50`; the pc symbolizes INSIDE `abort()`
  (0x1ab4c..0x1ab5b), i.e. the stochastic memimagedraw pixel
  verification detected a mismatch on aarch64 (the null read is abort's
  own mechanism).  Pixel-path LP64/struct-punning audit needed
  (Pitfall-3 class).
- **libmemdraw (arctest):** `fault write addr=0x1c001374bc
  pc=0x155bc`; the pc sits inside `memsetl` — the caller's destination
  pointer is garbage (LP64-fossil signature).  memarc → fill-path audit.
- **libdynld:** `dynld.c:128` — 7c: "useless or misleading comparison:
  ULONG < 0" (compile note; the lib archived green).
- **liboventi:** the `$O.vttest` + `test:` mkfile targets reference a
  `vttest.c` that does not exist — stale target; Phase 10 decides
  (remove the target or restore the source).
- **libmemdraw mkfile:** the `$O.test` target references a `test.c`
  that does not exist (same stale-target class; only drawtest/arctest
  are real).

### rc `~` dialect discovery (sweep-author trap, measured host-side 2026-11-05)

Quoting DISABLES wildcarding in `~` patterns: a quoted `*` is a literal
star (`~ foo 'f*'` never matches; wildcards must be bare — the sweep's
existing `*20[0-9][0-9]*` idiom).  Multi-star spans over literal text
are unreliable even bare (the three-group `* [0-9]* [0-9]* [0-9]* from *
shape never matched a valid '2048 64 32 from guess').  Assert multi-part
output in separate proven-shape conditions (disktest: `*' from '*` AND
`[0-9]*`).  Same D-02-shadowing-class family as 06-04's sed/date
findings.

### drive9 fast-fail interaction (standing-gate shape note)

A faulting binary's per-proc `suicide: sys: trap:` note trips drive9's
deliberate shared panic fast-fail (`panic|trap:` hardcoded) — observed
twice this plan (06-03's hawk fault was the first).  The standing sweep
therefore carries only green libtest members (tdraw, disktest); the two
faulting libmemdraw tests are evidence-captured
([evidence/06-05-libtest-donor.log](evidence/06-05-libtest-donor.log) —
all four markers + both fault lines + T1-DONE) and rejoin the sweep when
Phase 10 fixes the lib.  The guest completes the sweep regardless of the
host drive's fate (USPACE-04's never-wedge edge held: T1-DONE in the
fault run's log).  Green standing gate:
[evidence/06-05-tier1-gate-donor.log](evidence/06-05-tier1-gate-donor.log)
(21 × T1-OK, zero T1-FAIL, zero panic|trap:, T1-DONE, float 0.333).

## 06-06 tier-1 completion + self-host canary run record (USPACE-06, D-09/D-11)

- **Commits:** machinery `5edf99e83` (membership + sweep + fixed inputs)
  → gate fixes `30914b2b0`, `4e16a8055`, `4ceb04875`, `ce779749f`,
  `a9c8ff7c3`, `0ef2825d0`, `bbe2c4e82` → Task-1 ledger `f8b0b790e` →
  canary machinery `17370bba1` → canary fixes `cd96f5ac7`, `fab7377c4`
  (the gate-ran commit for the Task-2 ledger lines).
- **Host:** darwin-aarch64 (lima guest linux-aarch64 namespace builds;
  host qemu TCG donor boots).
- **Build:** [evidence/06-06-tier1-build.log](evidence/06-06-tier1-build.log)
  — 62 T1-ART + 35 T0-ART markers, `TIER-BUILD-OK`; **zero per-cmd
  compile fixes needed** across the 37 new entries (the Pitfall-3 classes
  again live at runtime, not compile time — and the donor gate measured
  none either).
- **Task-1 donor gate (full ~58-entry scale):**
  [evidence/06-06-tier1-donor.log](evidence/06-06-tier1-donor.log) —
  58 × T1-OK (55 computed members + float-d01 + libtest-tdraw +
  libtest-disktest), zero T1-FAIL, zero panic|trap:, T1-DONE.  The
  expected marker set is now COMPUTED from tier1-cmds.txt (never a second
  hardcoded list to rot).
- **A7 settled by observation:** `T1-BCOBS 0.333` — this bc prints the
  fraction WITH the leading zero (RESEARCH's "may print .333" resolved:
  it prints `0.333`).
- **D-11 canary (full path — A3 verified, NO fallback):**
  [evidence/06-06-selfhost.log](evidence/06-06-selfhost.log) — 61 ×
  T1-OK including `T1-OK 7a` (the committed tiny.s assembled in-guest;
  the canary's `7c -FTVw` emits .7 directly so 7a carries its own
  marker), `T1-OK selfhost-compile` (the guest's OWN h7c+h7l compiled
  and linked the committed hello.c in the writable /tmp scratch,
  resolving headers + autolib libc.a from the srv9-served root's staged
  /aarch64 tree), and `T1-OK selfhost` with
  `T1-SELFHOST-OBS hello aarch64 harvey` — the guest-compiled binary
  EXECUTED from the srv9 writable prefix and printed the known string
  (T-06-12's separate compile/run markers; the known-output string is in
  the retained serial log).  The A3 writable-prefix-exec mechanic works —
  the fallback (COMPILE-ONLY + host-side R_MAGIC assert) was NOT needed.
- **Venue findings filed for later plans (the gate's iterations caught
  them):** the donor kernel's devroot caps /boot at Nbootfiles=32 —
  subset-exec.sh now raises it to 128 in the donor-COPY tree (guest
  scratch, scripted, idempotent, disclosed harness-side accommodation);
  the served rootfs has NO /sys tree — the gate stages Harvey's
  sys/lib/yaccpar + sys/lib/lex/ncform + sys/include into it (yacc/lex
  open their skeletons by compiled-in absolute paths; 7c's include
  search covers /sys/include for libc.h); 9front guest-rc lexes a bare
  `=` as a word terminator (flag=value arguments must be quoted) and
  plan9port rc rejects separated subshells inside backquotes (the sweep
  is subshell-free; fn producers carry multi-command input streams);
  rc redirect-open failure is an uncatchable Xerror (07-04's lesson —
  look's db redirect is dir-probe-guarded); bc.y's execl("/bin/dc") is
  hardcoded and the donor's served /bin is minimal — the sweep
  union-mounts a shim (/tmp/bc-bin/dc ← our hdc) over /bin with the
  donor's own /bin/bind; the guest's /tmp is the MCREATE bind of
  /usr/glenda/tmp, so scratch cleanup mirrors BOTH branches.
- **Ledger lines appended:** 37 × `exec=T1-OK:donor` tier-1 lines
  (build chain + coreutils, evidence = 06-06-tier1-donor.log), the
  tier-0 libmach supersede to `exec=CARRIED:nm` (nm.c:8 <mach.h>; D-06),
  and the 4 × `exec=T1-OK:donor` supersede lines for 7a/7c/7l/cc
  (evidence = 06-06-selfhost.log).  No PENDING-CANARY survives as any
  dir's latest line.
- **dir-coverage (D-15 standing rule):** regenerated after the plan's
  commits — **unchanged** (the plan's members are single-file targets or
  already-ok dirs; no dir-level build rows flipped), `git diff
  --exit-code` green; no re-baseline commit needed.

## 06-07 measure-first tier-1 trace + r9 dispatch delta record (USPACE-04)

- **Commits:** trace rig `d542d727b` (tracesup.c + harness
  `--tier1`); the parser/venue fixes land beside this record; r9 delta
  `2a1f29b9355527aa07b72740fe51e619b9e76f77` (requaos/r9 main, PUSHED
  before the pin); pin bump `f8723ec51` (flake.lock ALONE;
  locked-rev == live-HEAD == origin/main verified at commit time).
- **Host:** darwin-aarch64 (lima guest for the in-guest 7c/7l compile +
  donor rebake; host qemu TCG for the traced boot).
- **The rig (the 05-03 rig with the tier-1 sweep as the traced
  payload):** the staged termrc override runs the sweep SOURCED
  (`venue=donor`) inside a spin-windowed, stop-armed subshell, and the
  NEW in-guest supervisor `build/aarch64/tracesup.c` step-traces it AND
  every born-traced descendant (donor sysproc.c:155 procctl
  inheritance).  The 05-03 rc traceloop/fragprint shape moved into one C
  program: no per-fragment forks (the rc cat|sed pair per fragment would
  dominate at tier scale), one newline-framed fragment file per pid on
  the srv9 writable prefix (`/tmp/t1trace`, read host-side off the served
  root — no serial flood, no mid-line gluing, so no __GSD_FRAG_ tags).
  Root armed write-first (the Proc_stopme stop has no pending fragment);
  born-traced children armed read-first (pidwait.c's traceloop1 rule).
  Venue = subset-exec.sh's 06-06 donor gate exactly (the donor's own
  chain, writable prefixes, srvroot /sys+aarch64 staging, devroot
  Nbootfiles=128, self-healing CONF block) with the trace added.
- **The run:** boot → traced sweep → `T1-DONE` + `__T1_TRACE_DONE__` →
  init's restart → shell proof.  Zero T1-FAIL, zero panic|trap:.  201
  traced pids; **8581 entry fragments; 0 malformed**.  Artifact:
  [evidence/06-07-trace.txt](evidence/06-07-trace.txt) (per-binary
  multisets + classification + the delta section).  Serial log:
  `.build/9front-dist/tier1-trace-run.log` (gitignored transient).
- **The measured set (r9-runnable union, 19 names):** chdir, close,
  dup, exec, exits, open, rfork, pipe, create, fd2path, brk_, notify,
  rendezvous, seek, stat, await, pread, pwrite, nsec.  **The delta vs
  r9's dispatch = exactly {RENDEZVOUS(34) ×1 (hfactotum's libthread
  start), NSEC(53) ×2 (hdate, hipconfig — libc time() = nsec()/1e9)}** —
  expected-small confirmed by measurement, never assumed.  The
  write-flow union (donor-only; r9 T1-SKIPs it) is the artifact's second
  table: remove ×8, wstat ×3, fwstat ×1 fired there — **the measured
  evidence RATIFIES r9's loud-None for REMOVE/WSTAT/FWSTAT this era**
  (their only callers are write-flow binaries r9 cannot serve), and
  OSEEK never fired anywhere.
- **The ed finding (measured, reclassified):** the trace caught hed's
  unconditional `create("/tmp/eXXXXX")` + exit-time `remove`
  (ed.c:159/1092/930) — a /tmp-writable dependency the read-only block
  hid.  ed MOVED into the sweep's donor-venue guard with a named
  `T1-SKIP ed` on r9 (USPACE-04 transparency: never an unearned T1-OK);
  the SKIP set's "known list" gains ed by measured evidence.
- **r9-side implementation (exactly the delta):** NSEC(53) — the
  epoch-ns clock composed from qemu virt's PL031 RTC (DTB
  pl031@9010000, RTCDR epoch seconds) anchored once against the generic
  timer's monotonic CNTPCT count (runtime CNTFRQ; u128 scaling; raspi
  gets no fake clock — compile-time absence); RENDEZVOUS(34) — 9k
  sysrendezvous semantics over a new `port::rendez` group (Arc-shared
  per rfork's RFREND arm, now real; first-sleeps/peer-wakes symmetric
  exchange; exit sweeps the sleeper table per 9k pexit).  Both handlers
  follow the Phase-4/5 discipline (sargs validation, width rules,
  loud errors); the loud-unimplemented default stays for everything
  else.
- **r9 gates (all green with R9_HARVEY_DIR set):** `cargo xtask
  ureg-check` (35 fields ≡ aarch64/include/ureg.h); all five boot-test
  profiles — virt (banner/ticks/echo), virtexec (SC#2 + stacksmoke),
  virtmulti (SC#4 rfork/fd + preemption), virtnotes (notes), virtpanic
  (dump) — and `cargo test -p port` (83 green incl. the 2 new rendez
  table tests).
- **Push-before-pin (T-06-13):** r9 `2afa3d6..2a1f29b` pushed to
  requaos/r9 main BEFORE the Harvey flake.lock advance; the pin bump
  (`f8723ec51`) touches ONLY flake.lock and names both SHAs.
- **NMOUNT-ledger note (step 6):** no NMOUNT-class (number/semantics)
  divergence surfaced.  The trace's two name-level mappings are
  print-name only, same wire: `_nsec` ↔ NSEC(53) (already documented —
  aarch64/ABI.md:59) and the donor mksystab's printed `Rendez` ↔
  RENDEZVOUS(34) (mksystab's baked `Rendezvous→Rendez` rename; the
  parser's `resolve()` maps both).  Nothing to grow.
- **Venue notes for later plans:** the traced sweep's DRIVER shell was
  the donor's own rc (the venue boots the donor's chain; `exec rc`
  resolves the donor's /bin/rc) — the "rc" bucket in the artifact
  aggregates the driver + its pre-exec fork/backquote shims, and bare
  `echo` in sweep pipelines resolves to the donor's /bin/echo (measured:
  `echo` ×69).  Footprint classes are identical to the Harvey binaries'
  (open/pread/close/pwrite/brk_/exits); on r9 the driver is the image's
  /bin/rc (Harvey's).  The trace ran the pre-prefix sweep; the
  venue-prefix edit (B=/boot→/bin, D=/boot→/lib/tier1 on r9) and the ed
  move are venue-mapping only — no measured behavior changed.
- **Ledger lines appended:** none by this record (the r9-venue ledger
  lines — `exec=T1-OK:r9` / `exec=SKIP:r9-no-writable-fs` — land with
  the 06-07 Task-2 gate evidence; PENDING-CHAIN:06-07 resolves there).
