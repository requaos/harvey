# Phase 20 evidence: the HVF fork-child defect (WINDOWS #49)

Plan 20-02. Kernel under test: r9 `46364d0` (the 20-01 head, `r9-kernel-virt-46364d0`), passed with `R9_OVERRIDE=git+file:///Users/neilskinner/code/r9`. Host: darwin-arm64, qemu 11.1.2, shape `virt,gic-version=3`. HVF runs use `-cpu host`; TCG runs use `cortex-a72`. This is a measurement series on a kernel known to be defective, not an acceptance series.

Instrument: `build/aarch64/repeat-gate.sh <app> <count>`. Every run leaves `run-<i>.log` (serial capture) and `run-<i>.out` (app stdout and stderr) under `.build/hvf-series/<app>-<accel>-<stamp>/`, plus a `series.tsv`. The harness counts forks as the capture lines matching `process [0-9]+ exited`. The r9 kernel prints one such line per reaped child, and every series reported `METHOD forks counted by: exited-lines`. A failing run stops at the fire, so it adds only the forks before it.

Command (one block, about 12 minutes of wall clock in total; the userland was built once by the verify run just before, so `R9_SKIP_BUILD=1`):

```
export R9_OVERRIDE=git+file:///Users/neilskinner/code/r9 R9_SKIP_BUILD=1
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-tier1 12
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-net-smoke 12
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-smoke 30
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-tier1 3
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-net-smoke 3
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-smoke 3
```

## Pre-fix rate

Series lines as printed:

```
SERIES boot-r9-tier1 accel=hvf runs=12 pass=2 fail=10 pushword=10 forks=798
SERIES boot-r9-net-smoke accel=hvf runs=12 pass=8 fail=4 pushword=4 forks=579
SERIES boot-r9-smoke accel=hvf runs=30 pass=29 fail=1 pushword=1 forks=233
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=378
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24
```

Every failing run was a pushword fire (fail = pushword in every row). The rates below are exact one-sided 95% binomial bounds, solved by bisection (`python3`, the script is `bounds.py` in the session scratchpad; the formulas are in `## N derivation`).

| Gate | Accel | Runs | Fails | Pushword fires | Forks per passing run | Total forks F | Per-fork rate f/F | Lower 95% bound (used) | Upper 95% bound (not used for N) | Mean s/run (passing) |
|------|-------|------|-------|----------------|-----------------------|---------------|-------------------|------------------------|----------------------------------|----------------------|
| boot-r9-smoke | hvf | 30 | 1 | 1 | 8 | 233 | 0.00429 | 0.000220 | 0.0202 | 7.9 |
| boot-r9-net-smoke | hvf | 12 | 4 | 4 | 71 | 579 | 0.00691 | 0.00236 | 0.0157 | 14.9 |
| boot-r9-tier1 | hvf | 12 | 10 | 10 | 126 | 798 | 0.0125 | 0.00681 | 0.0212 | 7.0 |
| **HVF pooled** | hvf | 54 | 15 | 15 | — | 1610 | 0.00932 | **0.00575** | 0.0143 | — |
| boot-r9-smoke | tcg | 3 | 0 | 0 | 8 | 24 | 0 | 0 | 0.117 | 8.0 |
| boot-r9-net-smoke | tcg | 3 | 0 | 0 | 71 | 213 | 0 | 0 | 0.0140 | 17.0 |
| boot-r9-tier1 | tcg | 3 | 0 | 0 | 126 | 378 | 0 | 0 | 0.00789 | 7.7 |
| **TCG pooled** | tcg | 9 | 0 | 0 | — | 615 | 0 | 0 | 0.00487 (2.996/F) | — |

Per-run results (`run:rc/forks`):

- tier-1 HVF: `1:0/126 2:1/41 3:1/29 4:1/29 5:1/85 6:1/100 7:0/126 8:1/103 9:1/94 10:1/1 11:1/35 12:1/29`
- net-smoke HVF: `1:0/71 2:0/71 3:1/2 4:0/71 5:1/3 6:0/71 7:1/3 8:0/71 9:0/71 10:0/71 11:1/3 12:0/71`
- smoke HVF: 29 runs `0/8`, run 4 `1/1`
- TCG: every run `0/<forks per passing run>`. The 2-run TCG smoke verify series before the measurement (`pass=2 fail=0 forks=16`) agrees.

TCG control: 0 fires in 615 forks. If TCG had the same per-fork rate as the HVF lower bound, it would come through 615 forks with no fire with probability (1 - 0.00575)^615 = 0.029. So the defect is HVF-specific at the 95% level, which matches research's 0 of 4.

Mean seconds per run with `R9_SKIP_BUILD=1`. A failing run is shorter because the 20-01 fast-fail aborts at the fire (tier-1 6.9 s mean over all runs, net-smoke 11.9 s).

### Where the fires are

The 15 fires are not spread evenly over forks. They cluster at a few fork sites, and at those sites the capture is identical line for line up to the fire:

| Fire site (capture line) | Forks before | Last reaped pid | Last marker | Fires |
|--------------------------|--------------|-----------------|-------------|-------|
| line 1925, the first termrc child after `init: starting /bin/rc` (the stacksmoke stage every gate shares) | 1 | 2 | `init: starting /bin/rc` | 2 (smoke run 4, tier-1 run 10) |
| net-smoke line 2049, a child of the `rc /lib/netip-static.rc` script rc | 3 | 7 | `% rc /lib/netip-static.rc` | 3 (runs 5, 7, 11) |
| net-smoke line 2036, the same script, one fork earlier | 2 | 5 | `% rc /lib/netip-static.rc` | 1 (run 3) |
| tier-1 line 2397 | 29 | 33 | `T1-OK rc` | 3 (runs 3, 4, 12) |
| tier-1, one each at forks 35, 41, 85, 94, 100, 103 | — | 39, 43, 87, 98, 104, 107 | `T1-OK awk`, `T1-OK sort`, `sched: switch 87->88`, `T1-OK xd`, `sched: switch 6->104`, `T1-SKIP cp` | 6 |

What the captures show at the fire:

- In 13 of the 15 fires, the line just before `rc: pushword but no argv!` is `process N exited: ""`. The parent rc has just reaped a child, and the next child it forks aborts on its first action (`pushword("exec")` in `execforkexec`, `sys/src/cmd/rc/havefork.c:229`). The other two (net-smoke run 3, tier-1/smoke line 1925) have no exit line in between, and the abort follows a burst of `fault: bss page-in` lines.
- In the failing child there is **no** `fault:` line between the fork and the abort. The child did not demand-fault the page it read. The pages holding `runq` and `runq->argv` were mapped in the child, but they held wrong contents (`argv == 0`).
- The passing run at the same site (net-smoke run 1, line 2049) prints `process 7 exited: ""` and then the child's text page-ins (`0x10000`, `0x12000`, `0x18000`). So the fork site is the same and only the child's view of its own memory differs.
- `sched: switch` lines (tick preemption between user processes) sit next to 2 of the 15 fires. Most fires have no preemption nearby, so preemption is not needed for a fire.

So the defect is quasi-deterministic per site: given the same boot it tends to strike the same fork. The per-fork Bernoulli model behind the N formula fits these data only roughly. That is one more reason the per-boot form in rule 4 below matters.

## N derivation

Rules as stated in the 20-02 plan (D-02), applied in order.

**1. Pool.** HVF fires f = 10 + 4 + 1 = **15**. HVF forks actually run F = 798 + 579 + 233 = **1610**. A failing run counts only the forks before its fire.

**2. Minimum sample.** f = 15, so f is at least 3. No extension blocks were needed.

**3. Bound.** p_lo is the p at which P(X >= 15 | X ~ Bin(1610, p)) = 0.05. Solved by bisection on the exact binomial tail: **p_lo = 0.00575157**.
Cross-check: the Poisson lower quantile L(15) = 9.2463 (the λ with P(Pois(λ) >= 15) = 0.05), and L(15)/F = 9.2463/1610 = 0.0057431, within 0.2% of the exact value. The same solver reproduces the plan's table: L(1..6) = 0.0513, 0.3554, 0.8177, 1.3663, 1.9701, 2.6130, against 0.0513, 0.355, 0.818, 1.366, 1.970, 2.613.
For the record only, not used: the point estimate is 15/1610 = 0.00932 and the upper bound is 0.0143.

**4. N per gate.** N = max(floor, ceil(ln(0.05) / (forks_per_boot × ln(1 - p_lo)))), with ln(0.05) = -2.99573 and ln(1 - 0.00575157) = -0.00576818. Every gate failed in the measurement, so the per-boot form ceil(ln(0.05) / ln(1 - q_lo)) is also computed, where q_lo is the exact lower 95% bound of that gate's own f_g/K_g. The larger is taken.

| Gate | forks/boot | per-fork form | f_g/K_g | q_lo | per-boot form | floor | **N** | wall clock of one N series (N × s/run) |
|------|------------|---------------|---------|------|---------------|-------|-------|----------------------------------------|
| boot-r9-smoke | 8 | ceil(2.99573 / (8 × 0.00576818)) = ceil(64.92) = 65 | 1/30 | 0.00170832 (= 1 - 0.95^(1/30)) | ceil(2.99573 / 0.00170978) = 1753 | 36 | **1753** | 1753 × 7.9 s ≈ 13,850 s ≈ 3.85 h |
| boot-r9-net-smoke | 71 | ceil(2.99573 / (71 × 0.00576818)) = ceil(7.31) = 8 | 4/12 | 0.122851 | ceil(2.99573 / 0.131078) = 23 | 36 | **36** | 36 × 14.9 s ≈ 9 min |
| boot-r9-tier1 | 126 | ceil(2.99573 / (126 × 0.00576818)) = ceil(4.12) = 5 | 10/12 | 0.561895 | ceil(2.99573 / 0.825297) = 4 | 10 | **10** | 10 × 7.0 s ≈ 70 s |

For smoke, the per-boot form decides. The gate's own sample is one fire in 30 boots, and its exact lower bound (0.00171 per boot) is far below what the pooled per-fork bound predicts for an 8-fork boot (1 - (1 - 0.00575)^8 = 0.045). The rule takes the larger N, so smoke's N is set by its own thin per-gate sample. The cost is about 3.85 hours per series, or about 15.4 hours across the four series the phase runs (20-03, 20-06, 20-11, 20-17). This goes to the owner at the Task 3 checkpoint. The executor does not reduce it.

**5. Thin sample / zero fires.** Neither case applies. f = 15 is the main path (3 or more fires). Research's 0.0011 is not used anywhere above. For comparison only: at 0.0011 per fork, the expected number of fires in 1610 forks is 1.8, while this series saw 15.

**6. Machine-read lines.** FORKS-TARGET = ceil(ln(0.05) / ln(1 - p_lo)) = ceil(2.99573 / 0.00576818) = ceil(519.36) = 520. That is the total fork count a zero-fire series must reach.

REPRO: reproduced
N-SOURCE: lower-bound
P-LO = 0.00575157
FORKS-TARGET = 520
N-HVF boot-r9-smoke = 1753
N-HVF boot-r9-net-smoke = 36
N-HVF boot-r9-tier1 = 10

Stressor result (Task 2): `/bin/forkstress -n 450` over 11 HVF boots that reached the prompt made 4950 forks with 0 mismatches. One more boot hit a pushword fire in termrc before the stressor ran. Its own per-fork lower bound is 0, and its upper 95% bound, 2.996/4950 = 0.000605, is below P-LO. So the stressor does not reproduce the defect, and its forks never count toward a gate's forks per boot:

STRESSOR-RATE: not-fired

**Against the point-estimate hypothesis** (36 smoke boots, 5 tier-1 sweeps, from research's 13 boots at about 0.0084 per fork). The pooled point estimate here, 0.0093, is close to that figure. The N above is still larger, for two reasons:

- It uses the lower bound (0.00575), not the point estimate. A still-broken kernel failing at the lowest rate the data allow is the hardest to catch, and a lower rate needs a longer series.
- It takes the per-boot form where it binds. Tier-1 rises from 5 to 10 only because of the floor; the bound alone asks for 5. Smoke rises from 36 to 1753 because the smoke gate itself fired once in 30 boots, and the exact lower bound of that rate is 0.0017 per boot.

Net-smoke stays at its floor of 36.

## Root cause

**Confirmed.** `vm::switch` in `r9/aarch64/src/vm.rs` writes TTBR0_EL1 and then issues `tlbi vmalle1is; dsb ish; isb` with no context synchronization between the `msr` and the `tlbi`. Until an ISB, the TTBR0 write is not guaranteed to be in effect. Table walks in that window, including speculative ones, can still use the previous process's root table, and an entry filled after the TLBI has executed survives the trailing ISB. r9 uses no ASIDs (every user translation lives in one ASID), so the incoming process then runs on the outgoing process's translations for any VA it shares with it.

A fork child and its parent share their entire VA layout. When the parent rc blocks in `Waitfor` and the child is switched in, the child executes on the **parent's physical pages**. By then the parent has already run `poplist()` (`sys/src/cmd/rc/simple.c:69`, before `Waitfor` at :70), so `runq->argv` in the parent's memory is the popped list. The child's first action, `pushword("exec")` (`havefork.c:229`), finds `argv == 0` and aborts with exactly `rc: pushword but no argv!`. That is why every one of the 15 pre-fix fires shows the same message, and why no `fault:` line appears between fork and fire: the child never faults, because it is translating through the parent's valid entries.

Apple-silicon cores walk tables speculatively under HVF. TCG never fills its software TLB speculatively, which explains 0 fires in 615 TCG forks.

**What the wrong bytes are (T-20-04).** These are not zeros and not a stale copy. They are **another live process's memory, mapped read-write**. The probe below shows the child resolving 110 of its 114 pages to physical pages that belong to pid 6, its parent. So the child reads, and can write, the parent's live data, bss and stack, which is a process-isolation fault. The finding is called out for the Task 3 checkpoint. WINDOWS #50 (an intermittent HVF-only EL1 translation fault in `devpipe::read`'s user-buffer copy) fits the same mechanism, a stale or foreign user translation, but that has not been tested here.

Venue for every experiment: an instrumented copy of the r9 tree at `46364d0`, made with `rsync -a --exclude .git --exclude target --exclude result /Users/neilskinner/code/r9/ .build/r9-instr/`. It was passed to the gates with `R9_OVERRIDE=path:<worktree>/.build/r9-instr` and `R9_SKIP_BUILD=1`, on HVF and the same image (forkstress baked in, `46d54b261`). The real r9 checkout was never edited, because the worktree path guard refuses edits to `../r9`. Each experiment's kernel is a distinct store path (`r9-kernel-virt-wip`, hash listed). The copy was deleted after the last run. The probe and fix diffs are kept as `.build/p20-probe-and-fix.diff` and `.build/p20-fix-e-isb.diff`.

### 1. Characterization (from the Task 1 captures)

See "Where the fires are" under `## Pre-fix rate`. In short, the fires cluster at fixed fork sites. In 13 of 15 the parent rc has just reaped a child (`process N exited: ""`) and its next fork's child aborts on its first action. The failing child has no `fault:` lines. Fire sites include the first termrc child (line 1925), the `netip-static.rc` script's children, and the tier-1 sweep's `rc` and `awk`/`sort`/`xd` neighbours. Preemption (`sched: switch`) is next to only 2 of the 15.

### 2. The stressor (rc taken out of the picture)

`build/aarch64/forkstress.c` (commit `46d54b261`) is baked as `/arm64/bin/forkstress`. Before every fork it fills 64 KiB of data, 64 KiB of bss, 64 KiB of heap and 16 KiB of stack with a pattern that depends on the iteration. The child checks all four. Usage: `forkstress [-n forks]`, default 200.

- Command: `R9_KERNEL_PKG=/nix/store/ylf81k8sz1b2bng0jlwsr51pgp2bq8il-r9-kernel-virt-46364d0 R9_ACCEL=hvf R9_FS_N=450 nix develop -c nix shell --inputs-from . nixpkgs#dtc -c bash .build/p20-forkstress.sh 12 base450`. This is the uncommitted launcher: it runs steps 0b, 3 and 4 of `nix/tier1-r9.sh` (shape select, DTB patch, `expect`) over the already-baked `build/aarch64/bootfs.paq`, with `R9_TIER1_LOG` pointed at the per-run capture.
- The driver copy `.build/p20-forkstress.expect` is `build/aarch64/tier1-r9.expect` lines 1-148 verbatim, with two changes. First, line 68's env check drops `R9_EXPECT_OK R9_EXPECT_SKIP`. Second, lines 149-240 (the typed sweep line, the marker waits and the whole-file post-pass) are replaced by:

  ```
  set fsn [expr {[info exists env(R9_FS_N)] ? $env(R9_FS_N) : 200}]
  send "/bin/forkstress -n $fsn\r"
  expect {
      -re {forkstress: ok [0-9]+ forks} { puts stderr "p20-forkstress: OK"; set rc 0 }
      -re {forkstress: FAIL [0-9]+ of [0-9]+ forks} { puts stderr "p20-forkstress: FAIL"; set rc 3 }
      -re {forkstress: fork [0-9]+ failed} { puts stderr "p20-forkstress: FORK-FAILED (proc table)"; set rc 4 }
      timeout { puts stderr "p20-forkstress: TIMEOUT"; cleanup; exit 1 }
      eof { puts stderr "p20-forkstress: EOF"; cleanup; exit 1 }
  }
  expect -timeout 5 -re {% } {}
  log_file
  cleanup
  exit $rc
  ```
- The larger image still boots: after commit `46d54b261`, `R9_ACCEL=tcg nix run .#boot-r9-smoke --no-write-lock-file --override-input r9 git+file:///Users/neilskinner/code/r9` printed `smoke-r9: ALL STAGES PASS`, and the `ls /bin` sweep lists `/bin/forkstress`.
- Limit found: one boot can make at most about 505 forks. At fork 506 the stressor got `proc: table full`, because r9 never frees proc-table slots in this era. So `-n` must stay at or below about 450 per boot.
- Result: 11 boots × 450 = **4950 forks, 0 mismatches**. Run 12 fired in termrc before the prompt. `STRESSOR-RATE: not-fired`.
- Why the stressor cannot see it, now that the cause is known: the stressor's child checks memory that is identical in parent and child at fork time, and the parent does not modify that memory before the child runs (it is blocked in `wait`). A child running on its parent's pages therefore reads correct bytes. rc fails because its parent mutates `runq->argv` (`poplist`) between fork and the child's first instruction. A future stressor would need the parent to write a fresh pattern after `fork()` returns and before `wait()`.

### 3. Mechanisms, one at a time

The reproducer is the tier-1 gate on HVF: `R9_ACCEL=hvf R9_SKIP_BUILD=1 R9_OVERRIDE=<r9 flake ref> sh build/aarch64/repeat-gate.sh boot-r9-tier1 12` (about 90 s). With the switch as shipped it fired in 38 of 48 boots: 10/12 at the 20-01 head, 8/12 in the control, 9/12 and 11/12 in the (d) and (c) runs below. That is 38 fires in 3972 forks, a per-fork rate of 0.0096 with an exact lower bound r_lo = 0.00717. A mechanism counts as the cause only if disabling it gives zero fires over at least ln(0.05)/ln(1 - r_lo) = 418 forks, and FORKS-TARGET (520) is the stricter of the two. Each fix series below ran 1512 tier-1 forks. If a still-broken kernel failed at r_lo per fork, it would come through 1512 forks with no fire with probability (1 - 0.00717)^1512 = 1.9e-5.

| # | Mechanism | Prediction if it is the cause | Instrumentation (temporary, in the copy) | Kernel | Observed (tier-1 HVF ×12) | Verdict |
|---|-----------|------------------------------|------------------------------------------|--------|---------------------------|---------|
| ctl | none (pristine copy) | fires as at the 20-01 head | none | `8w4xif5h…-wip` | 8 fail / 12, 8 pushword, 1086 forks | reproduces |
| (a) | parent page absent from `mapping_log` at copy time | the child demand-faults the missing page: a `fault: … page-in` line between fork and fire, and the page reads zero (bss/stack) or initial (data) | capture evidence only, no kernel change | 20-01 head | 15/15 fires have **no** `fault:` line between fork and abort. The probe shows 110 of 114 child pages resolving to the parent's PAs, so the records exist and map | ruled out |
| (b) | KZERO alias remapped without break-before-make / TLB invalidation | copy reads through a wrong alias, so the child's **own** pages hold wrong bytes; it would fire with the switch fixed | not separately instrumented. `map_kernel_alias` rewrites an identical KZERO+PA entry (same PA and attributes, so no BBM hazard), and every write goes through `write_entry`'s full `tlbi vmalle1is` | — | with only the switch fixed, 0 fires in 2604 forks over 3 gates (below), so the copy path is not needed for a fire | not the cause |
| (c) | stale translation from a PTE store not ordered before the TLBI (missing `dsb ishst`) | adding the barrier stops the fires | `dsb ishst` before `tlbi` in `invalidate_all_tlb_entries` only, switch as shipped | `i2vk4swb…-wip` | **11 fail / 12**, 11 pushword, 801 forks | ruled out (worth adding as hardening, see the fix) |
| (d) | I-cache incoherence for text pages copied through the alias | maintenance on copied text stops the fires | `flush_icache_user_range` (dc cvau + ic ivau) on each copied text page's alias, plus `ic ialluis; dsb ish; isb` after the copy loop | `b417k8yk…-wip` | **9 fail / 12**, 9 pushword, 1287 forks | ruled out |
| (e) | no TLB flush that covers the switch to the child (stale translations across the TTBR0 switch, no ASIDs) | synchronizing the TTBR0 write before the TLBI stops the fires, and the probe shows the incoming proc using another proc's PAs | (e) full: `dsb ishst; msr ttbr0; isb; tlbi; dsb; isb`, kernel `afk34say…-wip`. (e) isb-only: `msr ttbr0; isb; tlbi; dsb; isb`, kernel `5n3xqf7x…-wip`. (c)+(e) together: kernel `9b9lkcka…-wip` | see column | (c)+(e): **0 / 12, 1512 forks**. (e) full: **0 / 12, 1512 forks**. (e) isb-only: **0 / 12, 1512 forks** | **confirmed** |
| (f) | timer preemption inside the copy | fires track `sched: switch` lines, and the fix would have to touch preemption | capture evidence. `rfork_copy` runs IRQ-masked in syscall context | — | `sched: switch` is next to only 2 of 15 fires, and the confirmed fix touches no preemption path | not the cause |

Re-enable check: removing the `isb` brings the fires back. The (c) run, made after the (e) runs with the switch as shipped, gave 11 fires in 12 boots. The probe run below gave 2 of 6.

**Cross-gate check of the isb-only fix** (kernel `j954qrbi…-wip`): `boot-r9-net-smoke` 12/12 pass, 0 pushword, 852 forks. `boot-r9-smoke` 30/30 pass, 0 pushword, 240 forks. Together with the tier-1 series that is 0 fires in 2604 forks over all three gates. At P-LO the probability of that is (1 - 0.00575)^2604 = 3e-7.

**Direct probe** (`p20_probe`, called inside the PROC_TABLE lock right after `vm::switch` in both `pick_next` and `reschedule`). For every record in the incoming proc's `mapping_log` it runs `at s1e0r, va; isb; mrs par_el1` and prints a mismatch when PAR_EL1's PA differs from the recorded PA, naming the live proc whose `mapping_log` owns the PAR's PA.

- Switch as shipped (kernel `8ysm9ix1…-wip`), tier-1 HVF ×6: 2 fails (runs 4 and 6), 725 forks. Probe hits came in 3 boots, each just before the fork child first ran:
  ```
  run-4: p20probe: pid=107 va=0x30000 kind=Data want=0x44dc7000 par=0xff000000428c7b80 owner=6
         ... (va 0x31000..0x35000, Data/Bss, all owner=6)
         p20probe: pid=107 stale=110 of 114
         rc: pushword but no argv
  run-5: p20probe: pid=56 stale=61 of 65   (owner=3; this child happened not to read a mutated word)
  run-6: p20probe: pid=124 stale=110 of 114 (owner=6), then rc: pushword but no argv
  ```
  Both failing boots show a stale switch immediately before the abort, and the stale PAs belong to the parent.
- Same probe with the isb-only fix (kernel `x2kayjx4…-wip`), tier-1 HVF ×12: **0 probe lines**, 12/12 pass, 0 pushword, 1512 forks.

### 4. Widening

Not needed: (e) is confirmed by both criteria (zero fires past the fork target with the fix, fires back without it) and by the direct probe. The rc guards from 17-06 are not involved. The defect is below rc: any process switched in after another one with an overlapping VA layout can run on that process's pages.

### Owner decision (Task 3 checkpoint, 2026-11-17)

Owner's answer, verbatim as relayed: "fix route = aarch64-fix (20-03 applies the vm::switch isb fix as written). N = keep the derived lower-bound values (smoke=1753, net-smoke=36, tier1=10; boot-r9-cpu per the plan's rules)."

DECISION: aarch64-fix

- 20-03 edits `r9/aarch64/src/vm.rs` `switch()` as named below. No `port/src/` edit, no FOD pass.
- N is unchanged: `N-SOURCE: lower-bound` stays in force with the three `N-HVF` lines above. `boot-r9-cpu` gets no line here. Under the plan's rules, the plan that builds that gate (20-16) derives its `N-HVF boot-r9-cpu` from `P-LO` and that gate's measured forks per boot, with a floor of 36.

### Fix location and size

- **Where the fix belongs:** `r9/aarch64/src/vm.rs`, `pub unsafe fn switch`. Add `isb` immediately after `msr ttbr0_el1, {pt_phys}` in the User arm. That one instruction is what was confirmed. For consistency, the Kernel arm (`msr ttbr1_el1`) should get the same `isb`, and a `dsb ishst` should go before the `msr` so prior page-table stores are visible to the walker. The `dsb ishst` before the `tlbi` in `invalidate_all_tlb_entries` is architecturally required too, but was shown not to be the cause; it is optional hardening.
- **Classification:** `aarch64/`. No `port/src/` edit, no x86_64 kernel bytes changed, no FOD impact. Not Harvey userspace, and not outside both repos: the qemu/HVF behaviour is architecturally permitted, and the kernel sequence is wrong.
- **Estimated size:** 1 to 3 lines of inline asm in one function, plus a comment. A regression check fits the existing gates; a host test cannot see TLB behaviour. The ASID-free design stays (adding ASIDs would be a separate, larger change and is not needed for this fix).
- **Reproducer (high rate, deterministic enough):** `R9_ACCEL=hvf R9_SKIP_BUILD=1 R9_OVERRIDE=git+file:///Users/neilskinner/code/r9 sh build/aarch64/repeat-gate.sh boot-r9-tier1 12`. Before the fix it fails about 80% of boots (38 of 48, 0.0096 per fork). With the fix it should print `SERIES boot-r9-tier1 accel=hvf runs=12 pass=12 fail=0 pushword=0 forks=1512`. The probe in `.build/p20-probe-and-fix.diff` is the direct signal if a re-check is ever needed. That file is gitignored, so if it is gone, rebuild the probe from the description above.

## Fix

Plan 20-03 Task 1. The owner chose `aarch64-fix` at the 20-02 checkpoint, so the fix is at the site `## Root cause` names. The plan text expected `aarch64/src/proc.rs`, but the approved site is `vm.rs`.

FIX-SITE: aarch64 r9/aarch64/src/vm.rs

- **r9 commit:** `cb9cde3` `fix(20-03): isb after the TTBR write in vm::switch — the HVF fork-child defect (WINDOWS #49)`. Parent `46364d0`. One file, `aarch64/src/vm.rs`, with 15 lines added and none removed.
- **Change:** in `pub unsafe fn switch`, `isb` goes right after `msr ttbr0_el1, {pt_phys}` in the User arm, before the `tlbi vmalle1is; dsb ish; isb`. This is the confirmed (e) isb-only variant. The Kernel arm (`msr ttbr1_el1`) gets the same `isb` so both arms follow one ordering. A comment at the site states the invariant (the TTBR write is context-synchronized before the TLBI), why it matters with no ASIDs, and why HVF exposed it while TCG did not. The existing `// SAFETY:` comment on the `unsafe` block still describes the block (a TTBR write plus the barrier and TLB sequence), so it was left as it is.
- **Not done:** the `dsb ishst` before the `msr`, and the one before the `tlbi` in `invalidate_all_tlb_entries`. `## Root cause` lists both as hardening. Experiment (c) showed they are not the cause, and the owner's instruction limited 20-03 to the two `isb`s. They stay open as optional hardening.
- **Scope checks:** there is no `port/src/` edit and no x86_64 byte change, so the fix has no FOD impact. `grep -c 'pushword but no argv' sys/src/cmd/rc/exec.c` printed 2 both before and after the change, so rc's guards are untouched. `rustfmt --check` on `vm.rs` is clean. The pre-existing `cargo fmt` drift in `aarch64/src/exec.rs` is not from this change and was left alone.
- **Build:** `cargo xtask build --arch aarch64 --config virtshell` under `nix develop .#kernel-virt` printed `VIRTSHELL-BUILD-OK`.

Reproducer: `R9_ACCEL=hvf R9_OVERRIDE=git+file:///Users/neilskinner/code/r9 sh build/aarch64/repeat-gate.sh boot-r9-tier1 12`. The `run-1.out` store-path name confirms which kernel each series used.

```
before (r9 46364d0, kernel r9-kernel-virt-46364d0, .build/hvf-series/boot-r9-tier1-hvf-20261117T182036):
SERIES boot-r9-tier1 accel=hvf runs=12 pass=1 fail=11 pushword=11 forks=995
after  (r9 cb9cde3, kernel r9-kernel-virt-cb9cde3, .build/hvf-series/boot-r9-tier1-hvf-20261117T182647):
SERIES boot-r9-tier1 accel=hvf runs=12 pass=12 fail=0 pushword=0 forks=1512
```

- **Before:** 11 fires in 995 forks, every one a pushword fire. That is still red, at about the rate in `## Root cause` (38 of 48 boots there, 11 of 12 here).
- **Length the after-run needs:** take r_lo, the reproducer's own exact lower 95% bound. From this re-run alone (11/995), r_lo = 0.006212, and ln(0.05)/ln(1 - 0.006212) = 2.99573/0.006231 = 480.8, so 481 forks. From the 20-02 pool (38/3972), r_lo = 0.007173, which gives 418 forks. Because the reproducer is a gate, the length is `FORKS-TARGET` = 520, the strictest of the three.
- **After:** 0 fires in 1512 forks, which is at least 520. A kernel still failing at r_lo = 0.006212 per fork would get through 1512 forks with no fire with probability (1 - 0.006212)^1512 = 8.1e-5.

## Second defect (found by the forkstress pin, 20-03 Task 2)

**Status: blocked on the owner.** The fix site is `port/src/`, which the 20-03 prohibitions forbid.

The Task 2 work is uncommitted at the time of writing. It is saved as `20-03-task2-wip.patch` in this directory, and the three files were reverted to HEAD. The work has three parts:

- forkstress encodes the 20-02 trigger: the parent rewrites all four arrays after `fork` and before `wait`.
- A `T1-OK forkstress` / `T1-FAIL forkstress` entry is added inside `if(~ $venue r9){…}`, just before `T1-DONE`.
- `forkstress` is added to the fixed names on the `R9_EXPECT_OK=` line in `nix/tier1-r9.sh`.

With that work in place, the first tier-1 HVF gate against r9 `cb9cde3` (kernel `r9-kernel-virt-cb9cde3`) wedged after the stressor finished. The capture is kept as `.build/p20-03-tier1-cb9cde3-forkstress-wedge.log`.

```
forkstress: start 200 forks data=209b0 bss=313e0 heap=41b38 stack=7fffffffbf28
...
process 255 exited: ""
proc: deallocate root table 0x48000000: NotAllocated
proc: deallocate kstack page 0x48001000: NotAllocated      (x4, 0x48001000..0x48004000)
process 256 exited: ""
...
forkstress: ok 200 forks
process 131 exited: ""
rc: can't create /env/status: namec: does not exist
echo: namec: does not exist
process 332 exited: "can't exec: namec: does not exist"
...
% wedgedbg: ~100s fully idle — dumping (pipe-RPC wedge shape)
```

The stressor itself passed with 0 mismatches. Then the shell's namespace stopped resolving anything (`/env`, `/bin/echo`), so `T1-OK forkstress` and `T1-DONE` never printed. The driver would have waited for the 600 s stage timeout, so the qemu process was killed by hand.

**Cause: `BitmapPageAlloc::deallocate` clears the wrong bit** (`r9/port/src/bitmapalloc.rs:164`). It checks `bitmap.is_set(8 * byte_idx + bit_idx)` but clears `bitmap.set(bit_idx, false)`, which is bit `bit_idx` of the bitmap's byte 0. Two things follow:

- **No freed page is ever freed.** Every page a proc frees at exec or exit stays marked as allocated, so allocation only ever grows within a boot.
- **The first 8 pages of each 128 MiB bitmap get marked free by mistake.** Each `Bitmap<4096>` covers 32768 pages, or 128 MiB. Once the leak exhausts PA 0x40000000..0x47ffffff, the allocator moves into the bitmap that starts at PA 0x48000000. On qemu virt that is where the initrd is loaded (`initrd: start=0x48000000 end=0x48409bef`), and `main.rs` reserves it. The first free inside that bitmap clears bits for 0x48000000..0x48007000. Those initrd pages are then handed out as pid 256's root table and kstack, and paqfs's image gets overwritten. That is the `namec: does not exist` that follows. Freeing the same PAs later prints `NotAllocated`.

The existing unit test (`bitmapalloc.rs` around line 399) frees only a page in byte 0, where `8 * 0 + bit == bit`, so it cannot see the bug. The x86_64 kernel uses the same `BitmapPageAlloc<32, PAGE_SIZE_4K>`, so the bug is cross-arch. There, the first 8 pages of PA 0 are the ones wrongly freed.

Why nothing saw it before: one boot of the existing gates leaks less than the roughly 128 MiB minus the kernel that lies below the initrd. The 20-02 run of `forkstress -n 450` right after boot (about 60 pages per child) also stayed under that, and its driver never ran another command after the stressor. The tier-1 sweep's 126 forks plus 200 forkstress children cross it.

**Confirmation (instrumented copy, not the r9 checkout):** I rsynced r9 at `cb9cde3` into `.build/r9-instr` (gitignored) and changed one line to `bitmap.set(8 * byte_idx + bit_idx, false);`. The diff is `.build/p20-03-bitmapalloc-fix.diff`. I passed the copy as `--override-input r9 path:…/.build/r9-instr`, which built kernel `r9-kernel-virt-wip`, and ran the same image with the Task 2 work applied. The tier-1 HVF gate printed `tier1-r9: ALL STAGES PASS` and `T1-OK forkstress`, with 0 `NotAllocated` lines and 328 reaped procs. The capture is `.build/p20-03-tier1-instr-dealloc-fix.log`. `/Users/neilskinner/code/r9` was not edited, and its tracked tree is clean.

**What this blocks:** 20-03 Task 2, the pin. Its acceptance needs `T1-OK forkstress` on the wire. It also blocks Task 3's tier-1 series, which runs with the pin in place. The smoke and net-smoke gates fork too little per boot to reach the threshold.

### Owner decision (20-03 Task 2 checkpoint, 2026-11-17)

Owner's answer, as relayed: "Option A. You are approved to edit r9 port/src/bitmapalloc.rs:164 (bitmap.set(8 * byte_idx + bit_idx, false)) and add a unit test freeing a page outside byte 0. Run the port suite and `cargo xtask check`, commit in r9, and record `PORT-SRC-EDIT: YES` plus the owner approval in 20-EVIDENCE.md so 20-06 redoes the x86_64 boot-iso build."

PORT-SRC-EDIT: YES

- **r9 commit:** `8958c9e` `fix(20-03): bitmapalloc deallocate clears the bit it checked`. Parent `cb9cde3`. One file, `port/src/bitmapalloc.rs`, +35 / -1.
- **Change:** `deallocate` now clears `8 * byte_idx + bit_idx`, the bit `is_set` checked, with a comment at the site. It also adds the test `bitmappagealloc_deallocate_outside_byte_0`, which frees PA 36 (bitmap 0, byte 1) and PA 100 (bitmap 1, byte 1) and checks the bytes, the double free, the reuse and the usage figure.
- **Red/green:** with the old line restored for the check, the new test FAILED at its first byte assertion. With the fix it passes.
- **Suite:** `cargo test -p port --no-fail-fast` passed 232 with 0 failed. One earlier full run showed the new test failing because it used a stale test binary, left over from the red check: the file was restored within the same mtime tick. After `touch` it passed, and the full suite was re-run green. `cargo xtask check` exited 0. `rustfmt --check` on the file is clean. The virtshell kernel built (`VIRTSHELL-BUILD-OK`).
- **Cross-arch:** x86_64 uses the same allocator, so the x86_64 kernel bytes change. **20-06 must redo the stale x86_64 boot-iso FOD**, and the Harvey push stays held for the owner's linux-host pass.
- The Task 2 work was reapplied from `20-03-task2-wip.patch`, and the patch file was deleted.

### The pin, after the fix

The Harvey commit is `905c2ef9d`. With r9 `8958c9e`, the tier-1 HVF gate printed `tier1-r9: ALL STAGES PASS`, and the capture holds `T1-OK forkstress` once, with no `T1-FAIL forkstress` and no `NotAllocated`. The gate's computed set is now `38 T1-OK markers + 23 T1-SKIP markers`. That is the 20-01 computed set plus the one fixed name `forkstress`.

To check that the pin bites, I changed the sweep entry (uncommitted) to `/bin/forkstress >/dev/null`, which prints no marker. The gate then failed:

```
tier1-r9: post-pass FAILED — missing T1-OK forkstress
error: tier-1 r9 gate FAILED (the driver named the stage on stderr; ...)
```

The change was then reverted with `git checkout -- build/aarch64/tier1-sweep.rc`.

## Post-fix series (local override)

Plan 20-03 Task 3. r9 HEAD is `8958c9e` (the vm::switch isb `cb9cde3` plus the bitmapalloc fix `8958c9e`). Every series' `run-1.out` names kernel `r9-kernel-virt-8958c9e`. Harvey HEAD at the start was `fce2d744f`.

The series ran from 2026-11-17T23:56:00Z to 2026-11-18T04:10:07Z, about 4 h 14 min, as one sequential block:

```
export R9_OVERRIDE=git+file:///Users/neilskinner/code/r9 R9_STOP_ON_FAIL=1
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-tier1 10        # run 1 rebuilt the userland
export R9_SKIP_BUILD=1
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-net-smoke 36
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-tier1 3
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-net-smoke 3
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-smoke 3
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-smoke 1753
```

**N.** `N-SOURCE: lower-bound`. The N values are those on the `N-HVF` lines in `## N derivation`: smoke 1753, net-smoke 36 and tier-1 10. Each is at or above its floor (36, 36, 10). On the tier-1 restatement: 20-02 recorded `STRESSOR-RATE: not-fired`, so forkstress's forks do not count toward tier-1's forks per boot, and the `N-HVF boot-r9-tier1` line is unchanged. In this capture tier-1 makes 328 forks per boot, so the ordinary gate makes 328 - 200 = 128, against the recorded 126. 20-03 gave forkstress the 20-02 trigger, but its rate has not been re-measured, so the plan's rule keeps it at `not-fired`.

`R9_STOP_ON_FAIL=1` was set, and no series stopped. No run failed, so none was restarted and no failure is left out.

SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3280
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2556
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=984
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24

| Series | Directory (`.build/hvf-series/`) | Forks per run |
|--------|----------------------------------|---------------|
| tier-1 HVF ×10 | `boot-r9-tier1-hvf-20261117T185600` | 328, every run |
| net-smoke HVF ×36 | `boot-r9-net-smoke-hvf-20261117T185733` | 71, every run |
| smoke HVF ×1753 | `boot-r9-smoke-hvf-20261117T190805` | 8, every run (8.2 s mean; 1753 captures, 0 contain `pushword but no argv`) |
| tier-1 TCG ×3 | `boot-r9-tier1-tcg-20261117T190622` | 328 |
| net-smoke TCG ×3 | `boot-r9-net-smoke-tcg-20261117T190651` | 71 |
| smoke TCG ×3 | `boot-r9-smoke-tcg-20261117T190739` | 8 |

**HVF forks against FORKS-TARGET (520).** With forkstress excluded (`STRESSOR-RATE: not-fired`), tier-1 contributes 3280 - 10 × 200 = 1280, net-smoke 2556, and smoke 14024. The total is 1280 + 2556 + 14024 = **17860 forks with 0 fires**, which is at least 520. Counting the stressor's 2000 forks too gives 19860, but that figure is not used.

A kernel still failing at P-LO = 0.00575157 per fork would get through 17860 forks clean with probability (1 - 0.00575157)^17860 = e^(-103.0), about 1e-45. The per-boot form for smoke, the one that set N = 1753, is passed by construction: 1753 clean boots at q_lo = 0.00170832 has probability 0.95^(1753/30) ≈ 0.05.

D-01 and D-02 are met at the local r9 HEAD. The pinned re-run belongs to 20-06.

## Donor venue

Plan 20-05 Task 1. Harvey HEAD `9aae831a1`. The donor venue does not use r9. The run started at 2026-11-18T12:01:44Z.

```
nix develop -c sh -c 'sh build/aarch64/donor-vm-build.sh >.build/p20-05-donor.out 2>&1; echo "provision exit=$?"; sh build/aarch64/subset-exec.sh >.build/p20-05-subset.out 2>&1; echo "subset-exec exit=$?"; grep -c "T1-DONE" .build/p20-05-subset.out'
provision exit=0
subset-exec exit=0
1
```

- **Donor pin:** `== donor pin verified (350266104f1fed81c78c3d05fa44f523bec0ae4d)`. `git -C .build/9front-donor rev-parse HEAD` printed the same SHA.
- **Provision** (about 32 s, ending 12:02:16Z): the script ran its guest-toolchain check in `~/harvey-build-donor`, rebuilt the guest `7a/7c/7l` and `iar` from the vendored sources, swept the stale donor compiler outputs, and built `9qemu`/`9qemu.u`. It ended with `== donor build OK`.
- **Donor tier-1 gate** (about 43 s, ending 12:02:59Z): `== expected T1-OK marker set (computed from tier1-cmds.txt): 56 members + float-d01 + libtest ×2 + selfhost ×2`, then `== PASS: the tier-1 set executed on the 9front donor kernel (T1-DONE; float canary 0.333 green)`. The capture `.build/9front-dist/subset-exec.log` has 61 distinct `T1-OK` names, 0 `T1-SKIP`, 0 `T1-FAIL` and one `T1-DONE`. This also covers the merged `/arm64` staging: Harvey's `arm64/include` and `arm64/lib/libc.a` sit beside the donor's `arm64/bin` and `arm64/init`, and the in-guest `7c`/`7l` canary (selfhost ×2) compiled and linked against them.
- **The 20-03 sweep edit has no effect on the donor:** `grep -cE 'T1-(OK|FAIL|SKIP) forkstress'` printed **0**, both on `.build/p20-05-subset.out` and on the capture. Any mention of `forkstress` at all also counts 0 in both. The expected set, 56 members + float-d01 + libtest ×2 + selfhost ×2, matches what research recorded before 20-03 (Pitfall 5). The entry sits inside `if(~ $venue r9){…}` (`build/aarch64/tier1-sweep.rc`), and the donor sweep runs as `. /boot/tier1-sweep.rc donor`.
- **Prerequisite documented:** the `donor-vm-build.sh` header and a new `### Re-provision before the donor gates` subsection of `build/aarch64/README.md` both say that `subset-exec.sh` and `harness trace-syscalls` do not refresh the guest `~/harvey-build-donor` checkout or its hostbin `7a/7c/7l`. They say to re-run the script after any change to the objtype, to `arm64/include` or to the compilers, and they name the symptom `7c: No such file or directory: u.h`. The script change is comments only: none of the 12 added lines is code.

## Boot-chain trace (D-06)

Plan 20-05 Task 2. These runs came right after the `## Donor venue` provision, on the same donor dist, under TCG. The invocation is the one research used (README has none): `nix develop -c sh .build/trace/run3.sh <tag>`. For i = 1..3 that script runs `TRACE_OUT=$PWD/.build/trace/<tag>-run$i-trace.txt harness trace-syscalls --boot-chain` and copies `.build/9front-dist/bootchain-trace-run.log` to `.build/trace/<tag>-run$i-raw.log`. Everything stays under the gitignored `.build/trace/`. Research's failing raw log was still on disk, and I copied it to `.build/trace/research-bootchain-trace-run.log` before the first rerun overwrote it.

"Glued" means the `Fversion` record does not start its line: another pid's fragment comes before it on the same line. "Glued lines" counts every line in the raw log that has two or more `__GSD_FRAG_<pid>__` tags.

| Run | Harness | Result | Failing assert | Raw `Fversion` records | Each one | Glued lines in the log | `/arm64/init` exec (the `bind /boot/ourinit` path) |
|-----|---------|--------|----------------|------------------------|----------|------------------------|----------------------------------------------------|
| research (2026-11-17) | pre-fix | FAIL | `measured set lacks fversion — the connectembed/nsinit flow was not measured` | 1 | **glued**, line 406: `__GSD_FRAG_1259__ = 0 "" 33801607008 33801611008__GSD_FRAG_234__234 ourboot Fversion 203b4 3 0 0x7fffefe38/"" 32` | 6 | yes, chain ran to `__GSD_ALL_DONE__` |
| base 1 | pre-fix (`8qkk0vdl…-harness`) | PASS | — | 1 | line start (407) | 3 | yes |
| base 2 | pre-fix | FAIL, different stage | none from the distiller; the sweep stage aborted (see below) | 1 | line start (405) | 3 | yes; `__GSD_CHAIN_DONE__` printed, `__GSD_ALL_DONE__` did not |
| base 3 | pre-fix | PASS | — | 1 | line start (409) | 2 | yes |
| fix 1 | fixed (`v1anrpzg…-harness`) | PASS | — | 1 | line start (407) | 5 | yes |
| fix 2 | fixed | PASS | — | 1 | line start (404) | 3 | yes |
| fix 3 | fixed | PASS | — | 1 | line start (406) | 8 | yes |

Every passing run printed `== PASS: real-chain trace complete` and `40 fversion (×1)`. Each wrote its artifact to `.build/trace/<tag>-run<i>-trace.txt`, and every artifact lists 26 syscalls, 16 of them new against Phase 4.

**Branch A.** A failing run has a raw `Fversion` record that the distilled set lacks. The fault is in the distiller's record splitting, not in the traced flow and not in the rename.

- **Cause:** `parse_chain_region` matched each line once with `__GSD_FRAG_(\d+)__(.*)` and took everything after the first tag as one record. The per-pid `fragprint` procs write to the shared console at the same time, so a record that has no newline yet gets the next proc's record appended. Research's line 406 is pid 1259's return fragment (`= 0 …`) followed by pid 234's `Fversion` entry. The distiller saw a record starting with `=` and skipped the whole line as a return fragment. That `Fversion` was the run's only one (boot issues exactly one), so `REQUIRED_BC` failed. Entry-after-entry glue lost records the same way, for example line 1214 `… paqfs Pread … -1__GSD_FRAG_234__234 init Create …`. Those losses never broke the gate only because those names occur many times.
- **The glue happens in every run:** each of my six raw logs has 2 to 8 glued lines. `fversion` landed at a line start in all six, so the miss did not recur live. The cause is shown by replaying the code over the saved raw logs instead (a scratch copy of the crate with one `#[test]` that feeds each log's bracketed region to `parse_chain_region`):

  | Raw log | pre-fix distiller | fixed distiller |
  |---------|-------------------|-----------------|
  | research | ERR `measured set lacks fversion — the connectembed/nsinit flow was not measured` | OK, fversion 1, 1712 entry records |
  | base 1 | OK, 1706 records | OK, 1707 records |
  | base 2 (region cut at `__GSD_CHAIN_DONE__`) | OK, 1486 records | OK, 1488 records |
  | base 3 | OK, 1709 records | OK, 1710 records |

  The pre-fix distiller reproduces the exact gate failure on research's log, and the fixed one measures `fversion` from the same bytes. On every other log the fix recovers the 1 or 2 entry records that the old split dropped.
- **Fix:** `build/harness/src/trace.rs`. A new `pub fn frag_records` splits each line at every `__GSD_FRAG_<pid>__` tag, and each record runs to the next tag or the end of the line. `parse_chain_region` now loops over those records. Records are attributed to their own pid, and sweep brackets use the record's offset rather than its line's. A tag needs pid digits, so rc's `fragprint` definition, which appears as quoted text (`'s/^/__GSD_FRAG_'^$1^'__/'`), does not split a record. `REQUIRED_BC` is unchanged: `["bind", "pipe", "fversion", "mount", "dup"]`.
- **Tests:** `chain_region_glued_fversion_is_measured` feeds research's raw lines 403 to 406 and 1214, byte for byte with their CRs, and expects `fversion` ×1 (number 40) in pid 234's boot stream, plus the `Pread` and `Create` from the entry-entry glue and the `Close` whose tag follows console text. `frag_records_splits_at_every_tag` covers the splitter. Red check: with the splitter forced back to the old rest-of-line record (a scratch copy), both tests FAIL. The glued test fails with `"measured set lacks fversion — the connectembed/nsinit flow was not measured"`, which is the gate's own message. With the fix, `cargo test --manifest-path build/harness/Cargo.toml` printed `test result: ok. 72 passed; 0 failed`.
- **Three consecutive green runs:** fix 1, 2 and 3 all passed with the fixed harness. They are the last three runs.
- **The `bind /boot/ourinit /arm64/init` deviation (D-05, quick 261117-bz5)** now has green runs: base 1, base 3 and fix 1 to 3. In each, `ourboot Exec 203d4 …/"/arm64/init" …/"init" …/"-t"` is traced and the chain runs to `__GSD_ALL_DONE__`.
- **Stale defaults removed:** the three defaults that pointed into the archived `.planning/phases/04-…`, `05-…` and `06-…` directories are now `.build/trace/{hello,bootchain,tier1}-trace.txt`. A new `write_artifact` creates the directory first, and the usage text names the new paths. `grep -c 'planning/phases/0[456]-' build/harness/src/trace.rs` prints 0. No caller relied on the old defaults: every `git grep trace-syscalls` hit outside the crate is a comment. `git status --porcelain .planning/phases` shows only phase-20 files.

**A second, unrelated failure (base 2): the sweep-stage launch race.** The chain stage finished, but `rc /boot/trace-boot.rc sweep` aborted at its fourth entry with `/boot/trace-boot.rc:272: > can't create: /proc/16353/ctl: file does not exist: '/proc/16353'`. The forked `{ spin; exec /boot/ourcat … }` child got through its spin and finished before the parent's `echo stop`, which is a fork and exec of `/bin/echo`. The script then returned to `term%` with no `__GSD_ALL_DONE__`, and the harness would have waited out its 1800 s `sweep traces` timeout. About 6 minutes in, with the outcome already decided, I stopped qemu, the harness and srv9 by hand (`rc=143`). The capture is `.build/trace/base-run2-raw.log`. This is a fixture race in `build/aarch64/trace-boot.rc`, which this plan does not own, and the `fversion` fix neither causes nor touches it. It is logged in `deferred-items.md` with its cause and possible fixes. The owner-visible consequence: about 1 boot-chain trace run in 6 (1 of the 6 here) can fail at the sweep stage and hang for up to 30 minutes, regardless of `fversion`.

## Group A at the pin

Plan 20-06. Started 2026-11-18T12:44:33Z. Harvey HEAD at the start: `5fa4c0f69`.

### r9 local battery (Task 1)

r9 `main` at `5f3ddb0e77176d6f8994c8c69a373d054679496d`. The tracked tree is clean. After `git fetch origin`, `origin/main` is `46364d0` (the 20-01 head, already pushed), and `HEAD..origin/main` is empty, so the push is a fast-forward. `git log --oneline origin/main..HEAD` lists four commits, each named in a phase-20 summary:

```
5f3ddb0 fix(20-04): r9 devShell evaluates on darwin (grub2/xorriso linux-gated)
29f0c3d ci(20-04): build aarch64 virtshell in CI; xtask test runs the port integration tests
8958c9e fix(20-03): bitmapalloc deallocate clears the bit it checked
cb9cde3 fix(20-03): isb after the TTBR write in vm::switch — the HVF fork-child defect (WINDOWS #49)
```

Battery, inside `nix develop` (rustc 1.95.0-nightly 842bd5be2, QEMU 11.1.2), each step's exit code:

| Step | Exit |
|------|------|
| `cargo xtask check` | 0 |
| `cargo xtask clippy` | 0 (warnings only, none new to the four commits' files) |
| `cargo xtask test` | 0 (every `test result:` line `ok`, 165 port lib tests among them, no `FAILED`) |
| `cargo xtask build --arch aarch64 --config virtshell` | 0 |
| `cargo xtask build --arch aarch64` (raspi3b default, the `build-aarch64` CI job) | 0 |
| `cargo xtask build --arch x86-64` (the `build-x86_64` CI job) | 0 |
| `cargo xtask build --arch riscv64` (the `build-riscv64` CI job) | 0 |
| `R9_HARVEY_DIR=/Users/neilskinner/code/harvey cargo xtask ureg-check` | 0 (35 fields match `arm64/include/ureg.h`, 26 match `amd64/include/ureg.h`, negative control fired) |

The plan's verify line printed `R9-BATTERY-GREEN`.

`git diff --stat origin/main..HEAD -- port/src`:

```
 port/src/bitmapalloc.rs | 36 +++++++++++++++++++++++++++++++++++-
 1 file changed, 35 insertions(+), 1 deletion(-)
```

**PORT/SRC IS NOT EMPTY: THE x86_64 KERNEL BYTES CHANGE (r9 `8958c9e`, owner-approved, `PORT-SRC-EDIT: YES` above). THE x86_64 `boot-iso` FOD IS PRESUMED STALE. HARVEY `master` IS NOT PUSHED UNTIL THE OWNER'S LINUX-HOST `nix build .#boot-iso` PASS IN TASK 3.**

### r9 push

The owner approved the push at the 20-06 Task 1 checkpoint ("approve r9 push"), accepting that the `boot-iso` FOD is stale on r9 main until the linux-host re-wire. `git -C /Users/neilskinner/code/r9 push origin main` (no force) printed `46364d0..5f3ddb0  main -> main`. After `git fetch origin`, `origin/main` equals `HEAD`, and the plan's verify printed `PUSHED-CLEAN`.

R9-PUSHED: 5f3ddb0e77176d6f8994c8c69a373d054679496d

### The pin

Harvey `980f09c4e` `chore(20-06): advance the r9 pin 8e4e730 -> 5f3ddb0 lock-only (...)`. Running `nix flake update r9` changed only the r9 node's `lastModified`, `narHash` and `rev` (6 changed lines, the same shape as the `4a4f463e1` precedent). The locked rev `5f3ddb0e77176d6f8994c8c69a373d054679496d` equals r9 `origin/main`. `git show --name-only` on the pin commit prints exactly `flake.lock`.

PIN: r9 5f3ddb0e77176d6f8994c8c69a373d054679496d (Harvey 980f09c4e)

### Series at the pin (no override)

The block ran from 2026-11-18T12:52:28Z to 17:04:31Z (about 4 h 12 min), with `R9_OVERRIDE` unset and `R9_STOP_ON_FAIL=1`. Run 1 of tier-1 HVF rebuilt the userland at the pin, and every later series set `R9_SKIP_BUILD=1`. The driver was the 20-03 block, without the `R9_OVERRIDE` export:

```
unset R9_OVERRIDE; export R9_STOP_ON_FAIL=1
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-tier1 10
export R9_SKIP_BUILD=1
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-net-smoke 36
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-tier1 3
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-net-smoke 3
R9_ACCEL=tcg sh build/aarch64/repeat-gate.sh boot-r9-smoke 3
R9_ACCEL=hvf sh build/aarch64/repeat-gate.sh boot-r9-smoke 1753
```

**N.** The N values come from the `N-HVF` lines in `## N derivation`, unchanged and not recomputed: smoke 1753, net-smoke 36 and tier-1 10. These are the same values 20-03 used, and each is at or above its floor (36, 36, 10). No run failed, so no series was broken and nothing needed classifying.

SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3280
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2556
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=984
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24

| Series | Directory (`.build/hvf-series/`) | Kernel named in every `run-*.out` | `--override-input` in any `run-*.out` | Captures with `pushword but no argv` | `not registered` lines (expected 0) | Forks per run |
|--------|----------------------------------|-----------------------------------|---------------------------------------|--------------------------------------|-------------------------------------|---------------|
| tier-1 HVF ×10 | `boot-r9-tier1-hvf-20261118T075228` | `r9-kernel-virt-5f3ddb0` | 0 | 0 | 0 | 328 (`T1-OK forkstress` once in every capture; 0 `NotAllocated`) |
| net-smoke HVF ×36 | `boot-r9-net-smoke-hvf-20261118T075410` | `r9-kernel-virt-5f3ddb0` | 0 | 0 | 0 | 71 |
| smoke HVF ×1753 | `boot-r9-smoke-hvf-20261118T080440` | `r9-kernel-virt-5f3ddb0` | 0 | 0 | 0 | 8 (8.1 s mean) |
| tier-1 TCG ×3 | `boot-r9-tier1-tcg-20261118T080300` | `r9-kernel-virt-5f3ddb0` | 0 | 0 | 0 | 328 |
| net-smoke TCG ×3 | `boot-r9-net-smoke-tcg-20261118T080328` | `r9-kernel-virt-5f3ddb0` | 0 | 0 | 0 | 71 |
| smoke TCG ×3 | `boot-r9-smoke-tcg-20261118T080416` | `r9-kernel-virt-5f3ddb0` | 0 | 0 | 0 | 8 |

(The directory stamps are local time, -0500.)

**HVF forks against FORKS-TARGET (520).** Forkstress is excluded (`STRESSOR-RATE: not-fired`). Tier-1 contributes 3280 - 10 × 200 = 1280, net-smoke 2556 and smoke 14024, so the total is **17860 forks with 0 fires**, at least 520. That is the same count as the 20-03 local-override series, now made at the pushed pin. A kernel still failing at P-LO per fork would come through that with probability about e^(-103).

D-01 and D-02 are met at the pin.

### Harvey push

20-03's `PORT-SRC-EDIT: YES` and the non-empty `port/src` diff stat above both flag a `port/src/` edit. So Harvey `master` is not pushed here. It waits for the owner's linux-host `nix build .#boot-iso` pass and the FOD re-wire (Task 3). After the owner reports that, the push gets its own checkpoint.

HARVEY-PUSH: pending-fod

### Task 3: the owner's checks

The owner reported both results, relayed by the orchestrator on 2026-11-18:

- **Item 2, boot-iso FOD re-wire: DONE at r9 `ff2b632`.** On the linux x86_64 host, `nix build .#boot-iso` at `5f3ddb0` failed with the hash mismatch the `port/src` flag predicted. The owner set `outputHash` to the reported "got" value, and `nix build .#boot-iso` then succeeded. The owner committed and pushed that change: r9 `origin/main` = `ff2b632f6d89e84e9d690aa3a75a7c31a0cb95cf`, `bump boot-iso hash for allocator fix`. Checked here: `git diff --stat 5f3ddb0 ff2b632` is `flake.nix | 2 +-`, the single `outputHash` line (`sha256-0ahIuT…` → `sha256-rl+HA3pgTy+xfK7ztJ6ArQ4V9geBhXK/vJrBXw20tpQ=`).
- **Item 1, r9 hosted CI: VERIFIED.** The owner reports every job green on `ff2b632`, including `build-aarch64-virtshell`.
- **Harvey `origin/master`:** the owner pushed the 22 commits to `645963ed8`. The orchestrator then added and pushed `b41e7129a` (`sys/src/mkfile`: the amd64 plain build adds `ape/lib/net`, which fixes tier-9k's BUILD-SWALLOWED-FAIL on a missing `amd64/bin/rc`; the orchestrator verified it with a clean-ape `nix run .#build`). This plan leaves it as is.
- **Item 3, Harvey hosted CI:** not yet reported.
- **Item 4:** does not apply (`FIX-SITE: aarch64`, not `userspace`).

R9-FOD-REWIRE: ff2b632f6d89e84e9d690aa3a75a7c31a0cb95cf

### Second pin: 5f3ddb0 -> ff2b632

Harvey `38ec00ad7` `chore(20-06): advance the r9 pin 5f3ddb0 -> ff2b632 lock-only (the boot-iso FOD re-wire for the allocator fix)`. `nix flake update r9` changed only the r9 node's `lastModified`, `narHash` and `rev`. The commit's file list is exactly `flake.lock`, and the locked rev equals r9 `origin/main`.

PIN: r9 ff2b632f6d89e84e9d690aa3a75a7c31a0cb95cf (Harvey 38ec00ad7)

**Is the arm64 kernel the one the series ran?** The orchestrator's rule: if the aarch64 kernel output is byte-identical to `5f3ddb0`'s, record that and skip the re-run; if it differs, re-run the series. The comparison, using `llvm-readelf` and `llvm-objcopy -O binary` from `nixpkgs#llvm`, script `kcmp.sh` in the session scratchpad:

| Build | Store path | `kernel-virt.elf` bytes | sha256 (ELF) | Loaded image sha256 (`objcopy -O binary`, 41029632 bytes) | Sandbox path embedded |
|-------|------------|-------------------------|--------------|------------------------------------------------------------|------------------------|
| `5f3ddb0`, the one the at-pin series ran | `684a280w…-r9-kernel-virt-5f3ddb0` | 60523304 | `2804c886…` | `d89d0b5a…` | `nix-31439-1990151617` (41×) |
| `ff2b632` | `fv5wyb0b…-r9-kernel-virt-ff2b632` | 60523216 | `41e60f76…` | `64109432…` | `nix-1405-2348648680` (41×) |
| `5f3ddb0` again (`nix build --rebuild`, same `.drv` `gds7c7ha…`) | `684a280w…-r9-kernel-virt-5f3ddb0.check` | 60523104 | — | `94919b44…` | `nix-3913-1082037613` (41×) |

- The program headers and section headers 0-10 (every allocated section's address and size) are identical across all three. The two DTBs (`virt-gicv2.dtb`, `virt-gicv3.dtb`) are byte-identical.
- `.text` and `.rodata` differ in content, and so do the debug sections, `.strtab` and the `.llvm.<hash>` suffixes.
- **The kernel-virt build is not deterministic.** `nix build --rebuild` of the same `5f3ddb0` derivation printed `may not be deterministic: output … differs from ….check`. The sandbox build directory, which changes on every build, is embedded in the panic-location strings, and the symbol and module hashes change with it. Substituting the equal-length path in the rebuilt image still leaves 19783 differing bytes against `ff2b632`, so the bytes cannot be normalized to one image.
- **Conclusion: the bytes differ.** The source of the difference is the build, not the r9 diff. The r9 source diff touches only the x86_64 `boot-iso` `outputHash` line, which no aarch64 code reads. Even so, no byte comparison can show that the ff2b632 kernel is the kernel the series ran. Under the orchestrator's rule, the at-pin series is re-run on the `ff2b632` kernel.

KERNEL-BYTES: differ (non-deterministic build; source diff x86_64 FOD hash only) — series re-run at ff2b632

**Re-run stopped by the owner.** The re-run started at 2026-11-18T18:11:05Z (Harvey `5661ee6e3`, the same driver block, `R9_OVERRIDE` unset). The owner then decided to stop it, and the orchestrator killed the series script, `repeat-gate.sh`, expect and qemu. It was not restarted. The block exited 143. Partial results, every capture naming `r9-kernel-virt-ff2b632`:

| Series | Directory (`.build/hvf-series/`) | Completed | Result | `pushword but no argv` captures | `not registered` lines |
|--------|----------------------------------|-----------|--------|---------------------------------|------------------------|
| tier-1 HVF ×10 | `boot-r9-tier1-hvf-20261118T131105` | 10 of 10 | `SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3280` | 0 | 0 |
| net-smoke HVF ×36 | `boot-r9-net-smoke-hvf-20261118T131243` | 12 of 36 (run 13 killed mid-boot, no SERIES line) | runs 1-12 `rc=0 pushword=0 forks=71` | 0 | 0 |
| TCG ×3 each, smoke HVF ×1753 | — | not started | — | — | — |

These partial lines are not acceptance series and are not written as `SERIES` lines at the start of a line, so the 5f3ddb0 lines above remain the ones the plan's verify reads.

SERIES-AT-FF2B632: owner-waived — re-run stopped (partial: tier1 done, net-smoke interrupted); the 5f3ddb0 series stands, since ff2b632's source diff is the x86_64 boot-iso outputHash line only; kernel-virt non-determinism deferred (see deferred-items.md)

### Third pin: ff2b632 -> 2226cc4 (reproducible kernel bytes)

**The non-determinism is resolved.** The owner approved and pushed r9 `2226cc4f316555b13d5a79b57a2e97a51e92557b`, `fix(xtask): remap build paths for reproducible kernel bytes` (`ff2b632..2226cc4`, `xtask/src/config.rs` +20). In `apply_to_build_step` it adds `--remap-path-prefix` (`NIX_BUILD_TOP` → `/build`, the workspace → `/r9`) through `build.rustflags`. The owner reports:

- On darwin: `nix build .#kernel-virt --rebuild` reports no difference, no sandbox path is left in the ELF, `cargo xtask check`/`clippy`/`test` are green, and TCG `boot-r9-smoke` printed ALL STAGES PASS.
- On the linux x86_64 host at `2226cc4`: `nix build .#boot-iso --rebuild` passes with no warning. The existing `outputHash` (`sha256-rl+HA3…`) still holds, so no FOD re-wire commit was needed. `2226cc4` is the final r9 sha for group A.

The `5f3ddb0` series cannot stand in, because the kernel bytes really changed (the remap rewrites the strings in `.rodata`). So the full series runs again on this kernel.

Harvey `adcd47cd3` `chore(20-06): advance the r9 pin ff2b632 -> 2226cc4 lock-only (...)`. `nix flake update r9` changed only the r9 node's `lastModified`, `narHash` and `rev`. The commit's file list is exactly `flake.lock`, and the locked rev equals r9 `origin/main`.

PIN: r9 2226cc4f316555b13d5a79b57a2e97a51e92557b (Harvey adcd47cd3)

**Kernel identity at this pin** (`nix build github:requaos/r9/2226cc4f316555b13d5a79b57a2e97a51e92557b#kernel-virt`, aarch64-darwin). This is the reference for checking later aarch64-neutral pin changes by byte comparison:

| Item | Value |
|------|-------|
| Derivation | `/nix/store/cly25vwyc5x8c5ahfw7s0lg5ddfxwdg3-r9-kernel-virt-2226cc4.drv` |
| Output | `/nix/store/9hm0inncpdr3yxjxwcd4gp8l2zq78sw9-r9-kernel-virt-2226cc4` |
| Output narHash | `sha256-U6FHG2yBot0lacdyjYUf/rDz8Dz/uTe1mmDKxikixys=` (narSize 60534544) |
| `kernel-virt.elf` sha256 | `d35373047a0f47eeb988d0fa1332e321175423df6631a4d18b8fd0b3484b722d` (60517872 bytes) |
| Loaded image sha256 (`llvm-objcopy -O binary`) | `24c8213b1276cf3a8536b6ac4de79c30493c8af400f2d3d6fe7aebbc42298fe2` (41029632 bytes) |
| `aarch64/lib/virt-gicv2.dtb` sha256 | `af2aa3fa0a6abd4d096842792d16562ca2b75baa745774ceb1cc7b687297134f` (unchanged since 5f3ddb0) |
| `aarch64/lib/virt-gicv3.dtb` sha256 | `d96aae6b9bdf420ccff1f7af6e24a95464d1928f1c0a63f8be31dee34b6b47c6` (unchanged since 5f3ddb0) |

- Checked here: two `nix build --rebuild` runs of this derivation exited 0 with no `may not be deterministic` message. `grep -a -c /nix/var/nix/builds` on the ELF prints 0, and the vendored crate paths read `/build/cargo-vendor-dir/…` (204 occurrences).
- How to check a later pin: build `kernel-virt` at the new rev and compare the ELF sha256 above. If the ELF sha256 is equal, the kernel is the one this series ran, and an aarch64 re-run is not needed.

KERNEL-VIRT-SHA256 2226cc4: d35373047a0f47eeb988d0fa1332e321175423df6631a4d18b8fd0b3484b722d
