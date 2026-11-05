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

## Format note for later plans (06-04..06-08 appends)

One section per gated run: commit SHA (the machinery state that ran),
host, marker summary, retained log path under `evidence/`, and the
ledger lines appended by the run.  Append-only; never edit earlier
records (supersede via the ledgers' last-line-wins rule and a new
section here).
