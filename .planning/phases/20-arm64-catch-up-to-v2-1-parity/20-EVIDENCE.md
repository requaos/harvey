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

### Fix location and size

- **Where the fix belongs:** `r9/aarch64/src/vm.rs`, `pub unsafe fn switch`. Add `isb` immediately after `msr ttbr0_el1, {pt_phys}` in the User arm. That one instruction is what was confirmed. For consistency, the Kernel arm (`msr ttbr1_el1`) should get the same `isb`, and a `dsb ishst` should go before the `msr` so prior page-table stores are visible to the walker. The `dsb ishst` before the `tlbi` in `invalidate_all_tlb_entries` is architecturally required too, but was shown not to be the cause; it is optional hardening.
- **Classification:** `aarch64/`. No `port/src/` edit, no x86_64 kernel bytes changed, no FOD impact. Not Harvey userspace, and not outside both repos: the qemu/HVF behaviour is architecturally permitted, and the kernel sequence is wrong.
- **Estimated size:** 1 to 3 lines of inline asm in one function, plus a comment. A regression check fits the existing gates; a host test cannot see TLB behaviour. The ASID-free design stays (adding ASIDs would be a separate, larger change and is not needed for this fix).
- **Reproducer (high rate, deterministic enough):** `R9_ACCEL=hvf R9_SKIP_BUILD=1 R9_OVERRIDE=git+file:///Users/neilskinner/code/r9 sh build/aarch64/repeat-gate.sh boot-r9-tier1 12`. Before the fix it fails about 80% of boots (38 of 48, 0.0096 per fork). With the fix it should print `SERIES boot-r9-tier1 accel=hvf runs=12 pass=12 fail=0 pushword=0 forks=1512`. The probe in `.build/p20-probe-and-fix.diff` is the direct signal if a re-check is ever needed. That file is gitignored, so if it is gone, rebuild the probe from the description above.
