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
