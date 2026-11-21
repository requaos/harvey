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

The hold was written here as `HARVEY-PUSH: pending-fod` (Harvey `645963ed8`). It was lifted by the owner's boot-iso re-wire (r9 `ff2b632`, below), and the final Harvey state is recorded under `### Final pin and pushes`.

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

### Series at the 2226cc4 pin

The block ran from 2026-11-18T18:47:51Z to 23:06:45Z (Harvey `51d0502a4`, the same driver block, `R9_OVERRIDE` unset, `R9_STOP_ON_FAIL=1`, run 1 rebuilt the userland). Every `run-*.out` names `/nix/store/9hm0inncpdr3yxjxwcd4gp8l2zq78sw9-r9-kernel-virt-2226cc4`, the store path recorded above. The orchestrator ruled that the 5f3ddb0 series cannot stand in for this kernel, so these lines are the at-pin record:

SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3280
SERIES boot-r9-net-smoke accel=hvf runs=21 pass=20 fail=1 pushword=0 forks=1464
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=984
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024

| Series | Directory (`.build/hvf-series/`) | Result | `pushword` captures | `user fault: unresolvable` captures | `not registered` lines |
|--------|----------------------------------|--------|---------------------|-------------------------------------|------------------------|
| tier-1 HVF ×10 | `boot-r9-tier1-hvf-20261118T134751` | green | 0 | 0 | 0 |
| net-smoke HVF ×36 | `boot-r9-net-smoke-hvf-20261118T134933` | **RED at run 21**; `R9_STOP_ON_FAIL` stopped the series, runs 22-36 not made | 0 | 1 (run 21) | 0 |
| tier-1 TCG ×3 | `boot-r9-tier1-tcg-20261118T135450` | green | 0 | 0 | 0 |
| net-smoke TCG ×3 | `boot-r9-net-smoke-tcg-20261118T135520` | green | 0 | 0 | 0 |
| smoke TCG ×3 | `boot-r9-smoke-tcg-20261118T135610` | green | 0 | 0 | 0 |
| smoke HVF ×1753 | `boot-r9-smoke-hvf-20261118T135637` | green | 0 | 0 | 0 |

**The failing run (net-smoke HVF run 21, `run-21.log`, 44 forks, 12 s).** The fixture `rc /lib/netip-loopback.rc` (pid 36) printed `netip: random ok`, reaped pid 47 and then pid 48, and its next fork child faulted:

```
netip: random ok
process 47 exited: ""
fault: text page-in va=0x10000
fault: text page-in va=0x12000
fault: text page-in va=0x18000
process 48 exited: ""
user fault: unresolvable class=7 addr=0x1 pc=0x20a24 read pid=49 name=rc
TrapFrame { x0: 0x1, ... x30: 0x186cc, sp: 0x7ffffffffda0, pc: 0x20a24, ... }
wedgedbg: ... pid=36 ... name=rc parent=4 argv=rc /lib/netip-loopback.rc
wedgedbg: pid=49 state=Running ... name=rc parent=36 argv=
process 49 exited: "fault"
...
netip: FAIL
```

- **Who faulted:** pid 49 is a fork child of the script rc that has not exec'd yet (`name=rc`, empty `argv`).
- **Where:** symbolized with `.build/hostbin-darwin-aarch64/bin/nm -n arm64/bin/rc` (the image's rc, built by this series' run 1). `pc 0x20a24` is in `strncmp` (`0x20a04`). The link register `0x186cc` is in `searchpath` (`0x18690`), and `x0 = 0x1` is its word argument. `searchpath` begins with `strncmp(w, "/", 1)` (`sys/src/cmd/rc/simple.c:120`). In the fork child, `execforkexec` passes it `runq->argv->words->word`.
- **Classification: WINDOWS #49 class (a fork child sees corrupted rc argv state), not a pushword fire.** It has the same site shape as the pre-fix fires: the parent rc has just reaped a child, and its next fork child fails on its first argv access. Here `argv` is non-null but its word pointer is junk (`0x1`), so the child faults in `strncmp` instead of reaching `pushword`'s `argv == 0` abort. Runs 1-20 passed the same site (run 20 prints `netip: random ok`, `process 47 exited`, `process 48 exited` and continues).
- **Not seen before at the fix.** No capture in the 20-03 series (`r9 8958c9e`), the 5f3ddb0 at-pin series, or the stopped ff2b632 re-run has a `user fault: unresolvable` line. This is the first fire of any kind on a kernel carrying `cb9cde3`. Over this block's HVF gates it is 1 fire in 16768 gate forks (tier-1 1280 excluding forkstress, net-smoke 1464, smoke 14024).
- **What it does not show:** whether the cause is a residual of the same TTBR/TLB ordering (the `dsb ishst` hardening that `## Root cause` lists was never added), a different defect (WINDOWS #50 is the other open HVF-only translation fault), or something the kernel changed between `8958c9e` and `2226cc4`. The kernel code from `8958c9e` to `2226cc4` differs only by `29f0c3d` (CI and xtask test), `5f3ddb0` (devShell), the FOD hash and the path remap, none of which touches kernel logic. No probe was run.

AT-PIN-2226CC4: RED — boot-r9-net-smoke accel=hvf failed run 21 of 36 (user fault addr=0x1 in rc searchpath/strncmp, fork child pid 49; WINDOWS #49 class, not pushword); the other five series green

### Hardening (owner decision A, back to the 20-03 work)

The owner chose option A: reopen WINDOWS #49 (Harvey `a334e1edc`, row and JSON mirror `open`, the `645963ed8` re-close text corrected) and harden r9 `vm::switch`, starting with `dsb ishst`.

- **r9 commit:** `57e295242484237464a93a665577899e3aa4bc50` `fix(20-06): dsb ishst before the TTBR writes and the full tlbi — the residual fork-child fault (WINDOWS #49)`. Its parent is `cec2299`, another session's x86_64 commit, which this plan did not touch. It changes one file, `aarch64/src/vm.rs`, +17 / -3.
- **Change:** `dsb ishst` now goes ahead of `msr ttbr0_el1` (User arm) and `msr ttbr1_el1` (Kernel arm), and ahead of `tlbi vmalle1is` in `invalidate_all_tlb_entries`. The isb after each TTBR write (`cb9cde3`) is kept. A comment at the site gives the reason. The incoming process's tables are built by `rfork_copy` or a fault handler, now possibly in pages another process just freed (a page is really freed since `8958c9e`). Without the barrier, a walk may read a reused table page's stale contents.
- **Binary check:** `llvm-objdump -d` on the built ELF shows `dsb ishst; msr TTBR0_EL1, x0; isb; tlbi vmalle1is; dsb ish; isb`.
- **Battery:** `rustfmt --edition 2024 --check aarch64/src/vm.rs` passed. Inside `nix develop`, `cargo xtask check`, `clippy`, `test`, `build --arch aarch64 --config virtshell` and `build --arch aarch64` all exited 0.
- **Kernel:** `/nix/store/qc1i4nhl0slbgwcv8a9gnm877c3nmm57-r9-kernel-virt-57e2952`, `kernel-virt.elf` sha256 `da4ab2dab941acb498e3aa8dd41cb6db7a9fb807d1ee1dda053984aa235c9b73` (60517848 bytes), no sandbox path.
- **Push:** this plan committed `57e2952` locally only. When the series ended, r9 `origin/main` already pointed at `57e2952`, pushed outside this plan.

KERNEL-VIRT-SHA256 57e2952: da4ab2dab941acb498e3aa8dd41cb6db7a9fb807d1ee1dda053984aa235c9b73

### Series on the hardened kernel (r9 57e2952, rev-pinned override)

`R9_OVERRIDE='git+file:///Users/neilskinner/code/r9?rev=57e295242484237464a93a665577899e3aa4bc50'`. Pinning the rev keeps any uncommitted r9 edits out of the source. `R9_STOP_ON_FAIL=1`. The block ran from 2026-11-19T01:47:12Z to 05:56:59Z with the same driver order. Every `run-*.out` names `qc1i4nhl…-r9-kernel-virt-57e2952`.

- **Tier-1 HVF run 1 did not boot.** Its userland build failed in the lima guest before qemu ran: `error: opening file "/home/neilskinner.guest/harvey-build/sys/lib/postscript/troff/Hx": No such file or directory` while nix fetched `git+file:///home/neilskinner.guest/harvey-build`. `run-1.log` is 0 bytes. Darwin's case-insensitive checkout cannot hold both `HX` and `Hx`, the same collision behind the 11 pre-existing ` M sys/…` font entries. This is a build-venue failure, not a gate result, and no fork ran. It is not caused by this plan and is left for the owner.
- **Same image for every series.** The other five series ran with `R9_SKIP_BUILD=1` on the arm64 userland from the 2226cc4 series' run 1 (`arm64/bin/rc` 2026-11-18T13:48-0500). Between that build and this block, Harvey changed only docs, CI, `flake.lock` (`b0e3cef8f`, made elsewhere, not read under the override) and `nix/build.sh` (`0d01baa43`, made elsewhere). The tier-1 HVF ×10 series was re-run after the block on the same image and override (`R9_SKIP_BUILD=1`).

SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3280
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2560
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=984
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24

The failed build attempt printed `SERIES boot-r9-tier1 accel=hvf runs=1 pass=0 fail=1 pushword=0 forks=0` (directory `boot-r9-tier1-hvf-20261118T204712`, 0 forks). It is recorded here and not counted.

| Series | Directory (`.build/hvf-series/`) | `pushword` | `user fault: unresolvable` | `not registered` | Notes |
|--------|----------------------------------|------------|----------------------------|------------------|-------|
| tier-1 HVF ×10 | `boot-r9-tier1-hvf-20261119T022907` | 0 | 0 | 0 | 328 forks/run, `T1-OK forkstress` in all 10 |
| net-smoke HVF ×36 | `boot-r9-net-smoke-hvf-20261118T204720` | 0 | 0 | 0 | 35 runs 71 forks, 1 run 75 |
| smoke HVF ×1753 | `boot-r9-smoke-hvf-20261118T205744` | 0 | 0 | 0 | 8 forks/run |
| tier-1 / net-smoke / smoke TCG ×3 | `…-tcg-20261118T2056{02,31}`, `…T205718` | 0 | 0 | 0 | — |

**What this series can and cannot show.** HVF gate forks, with forkstress excluded: 1280 + 2560 + 14024 = **17864 with 0 fires**.

- The kernels carrying only the `cb9cde3` isb had 1 fire in about 54,600 HVF gate forks (8958c9e 17860, 5f3ddb0 17860, ff2b632 partial 2132, 2226cc4 16768). That is about 1.8e-5 per fork.
- At that rate, a kernel no better than `2226cc4` would come through 17864 forks clean with probability e^(-0.33), about 0.72. At the 2226cc4 series' own rate (1 in 16768), the probability is about 0.34.
- So this series is green at the plan's N. It does not show that the hardening removed the residual. At 1.8e-5 per fork, showing it at 95% needs about ln(20)/1.8e-5 ≈ 166,000 clean forks. With net-smoke, the gate that fired (71 forks a boot, about 15 s), that is about 2,300 boots or about 9.6 h.

HARDENED-57E2952: series green at the plan's N (17864 HVF gate forks, 0 fires); not yet distinguishable from the isb-only residual rate

### Final pin and pushes

**Owner decision (2026-11-19, relayed by the orchestrator):** option (b). The 57e2952 series is accepted at the plan's N. Harvey's r9 input is pinned to `57e2952`. WINDOWS #49 stays **open** with the residual-rate note and a long-measurement follow-up (about 2,300 net-smoke HVF boots, about 9.6 h, stop-on-fail off, on the pinned kernel). Pushing Harvey was approved.

- **Pin:** Harvey `0dafd07ad` `chore(20-06): advance the r9 pin cec2299 -> 57e2952 lock-only (...)`. `nix flake update r9` landed on `57e295242484237464a93a665577899e3aa4bc50`, which equals r9 `origin/main`. The commit's file list is exactly `flake.lock`. `nix build github:requaos/r9/57e2952…#kernel-virt` gives the same store path (`qc1i4nhl…-r9-kernel-virt-57e2952`) and the same ELF sha256 (`da4ab2da…`) as the series kernel, so the pinned kernel is byte-identical to the kernel the series ran.
- **Harvey push:** `git log origin/master..master` held only `658f7faee` and `0dafd07ad`. `git push origin master` (no force) printed `17df85ebc..0dafd07ad  master -> master`, and `origin/master` now equals `HEAD`.
- **Pushes and commits made outside this plan, recorded as reported by the orchestrator:**
  - r9 up to `cec2299` (`058b848` docs, `cec2299` x86_64 unlink-before-free): pushed by the coordinator on the owner's instructions.
  - r9 `57e2952`: this plan committed it locally. The push was not the coordinator's; it was presumably the owner's.
  - Harvey `b0e3cef8f` (pin r9 → `cec2299`, the x86_64 fix) and `17df85ebc` (the debug doc): made by the coordinator on the owner's instructions.
  - Harvey `0d01baa43` (`nix/build.sh`: stage `/bin` tools via temp+rename, the `/bin/ls` CI fix): made by the coordinator; the owner pushed it.
  - Earlier in the plan: the owner pushed Harvey through `645963ed8`, the orchestrator added `b41e7129a`, and the owner made the r9 `ff2b632` FOD re-wire and the `2226cc4` path remap.

PIN: r9 57e295242484237464a93a665577899e3aa4bc50 (Harvey 0dafd07ad)

HARVEY-PUSH: done

## Group B measurements

Plan 20-07 (D-09). Kernel under test: the pinned r9 `57e2952` (`/nix/store/qc1i4nhl0slbgwcv8a9gnm877c3nmm57-r9-kernel-virt-57e2952`, the `boot-r9-tier1` app's `R9_KERNEL_PKG`; no `--override-input`, no `R9_OVERRIDE`). Host: darwin-arm64, qemu 11.1.2, shape `virt,gic-version=3`; HVF `-cpu host`, TCG `cortex-a72`. Image: `build/aarch64/bootfs.paq` sha256 `6824c143d7f46551e59f595e6717747d281da6750c9c6f541bb286cc27afbd29`, baked by the tier-1 gate run below; every write-flow and diagnostic run in this section booted that same file (the brkprobe runs have their own image, named in their subsection). Driver: an uncommitted copy of `tier1-r9.expect`'s spawn shape (`.build/p20-07-probe.expect` + `.build/p20-07-probe.sh`) that types one line at the `%` prompt and waits for a marker.

### Conclusions (details below)

- **A-venue holds.** ramfs builds for arm64, mounts on `/n/wp` and creates. The write flow is red only at b5 (write), b6 (mkdir), b7 (union create) and b13 (remove).
- **A-rfork holds.** The `fdsplit` step is red with `rfork: bad flags for non-RFPROC` (b4).
- **A-brk holds: the lone-member arm works on aarch64 by demand paging; the x86_64 eager-map change is not ported.** 10/10 runs (5 HVF, 5 TCG) pass, plus the plain and family controls.
- **New finding (unmapped):** a fd table shared through a plain `rfork(RFPROC)` child leaks a pipe writer past the last sharer's exit, so a backquote reader hangs (HVF and TCG). It is outside b4–b7/b13.

### Write-flow transcript (`rc /lib/writeprobe.rc`, HVF and TCG)

The HVF and TCG transcripts are byte-identical (`diff` empty). One run each:

```
WP-FAIL fdsplit rfdprobe: FAIL rffdg rffdg: rfork: bad flags for non-RFPROC
WP-OK mount
WP-OK create
WP-FAIL write echo: write error: devmnt: the mounted tree is read-only this era [status: write error]
WP-FAIL readback got:
WP-FAIL mkdir mkdir: can't create /n/wp/d: create: directories unsupported this era [status: error]
WP-FAIL union-create [status: error]
WP-FAIL remove rm: /n/wp/f: syscall not implemented [status: syscall not implemented]
WP-DONE
```

### Build result (A-venue, part 1)

`ramfs` builds for arm64 by the per-target install rule. From `.build/subset-build.log`:

```
== subset cmd: ramfs (per-target install, 20-07 r9 writable venue)
7^c -FTVw ramfs.c
7^l  -o 7.ramfs ramfs.7
o._cp 7.ramfs /arm64/bin/ramfs
== boot chain: rfdprobe (20-07, b4 non-RFPROC fd split probe)
```

`arm64/bin/ramfs` is 97907 bytes with the arm64 a.out magic `00008c47`; `build/aarch64/out/rfdprobe` passed the magic loop. `mkimage.sh` baked `/arm64/bin/ramfs`, `/arm64/bin/rfdprobe`, `/lib/writeprobe.rc` and the empty mount point `/n/wp`, each with a manifest assert. `tiers/tier1-cmds.txt` is unchanged.

**Build venue (deviation, Rule 3).** The first three `nix run .#boot-r9-tier1` attempts never reached the build. The lima guest's nix fetch of `git+file:///home/neilskinner.guest/harvey-build` failed on `sys/lib/postscript/troff/Hx: No such file or directory`, every time (captures `.build/p20-07-tier1-attempt{1,2,3}-hx.out`). Cause: the guest checkout's `.git` was copied from darwin and carried `core.ignorecase=true`, but the guest disk is case-sensitive. git there matched the missing `Hx` against the `HX` that rsync delivers, so the dirty-tree fetch listed `Hx` as present and then could not open it. Fix: `git config core.ignorecase false` in the guest's `~/harvey-build` only. No repo file changed and the 11 font files were not touched. To revert: `git -C ~/harvey-build config core.ignorecase true` in the guest. The fourth attempt built.

### Tier-1 gate with the probes baked in (TCG, at the pin)

`R9_ACCEL=tcg nix run .#boot-r9-tier1`, run after the final edit to `rfdprobe.c` and `writeprobe.rc`:

```
== expected on r9: 38 T1-OK markers + 23 T1-SKIP markers (computed)
tier1-r9: ALL STAGES PASS — boot, one typed sweep line, float canary on r9, marker parity + exact SKIP set, T1-DONE, user-hooks-registered, no-unknown-device, no-unsupported-era
exit=0 ramfs-in-tier-file=0
```

38 + 23 are the same expected-set sizes the 20-06 series printed (`boot-r9-tier1-tcg-20261118T205602`, `boot-r9-tier1-hvf-20261119T022907`). The capture has 38 `T1-OK` lines (`.build/p20-07-tier1-tcg.log`). So ramfs, `/n/wp`, rfdprobe and `writeprobe.rc` are in the image and no gate calls them. An earlier run of the same gate, before the `fdsplit` rework below, also passed with 38 + 23.

### Write-flow steps mapped to the inventory

What the kernel printed on the console for each failing step (identical on both accelerators):

| Step | Kernel / console text | Inventory item |
|------|-----------------------|----------------|
| fdsplit | `rfdprobe: FAIL rffdg rffdg: rfork: bad flags for non-RFPROC` and `rfdprobe: FAIL rfcfdg rfcfdg: rfork: bad flags for non-RFPROC`; the children exit with `rffdg: rfork: bad flags for non-RFPROC` and `rfcfdg: rfork: bad flags for non-RFPROC` | **b4** (aarch64 `syscall.rs:1628`, both RFFDG and RFCFDG) |
| write | `devmnt: the mounted tree is read-only this era` (echo's write error) | **b5** (`syscall.rs:326`) |
| readback | empty: `/n/wp/f` exists (create passed) but holds no bytes, because the write failed | **b5**, downstream; no message of its own |
| mkdir | `create: directories unsupported this era` | **b6** (`syscall.rs:1416`) |
| union-create | `bind -ac /n/wp /lib/tier1` passed; then the create printed `/lib/tier1/wpu: rc: can't open: namec: device has no create` to the console (rc's redirect error is not routed to the captured fd 2), and `/n/wp/wpu` was not created | **b7**: `sys_create` resolves the parent with a plain open-mode `namec` and creates in the union's first member, the read-only `/lib/tier1`, without consulting the union for the `MCREATE` member `/n/wp`. b7 has no errstr of its own; the text is the first member's device error |
| remove | `syscall 25 unimplemented`, errstr `syscall not implemented` | **b13** (REMOVE is loud-None in the aarch64 DISPATCH table) |

Steps that passed: `mount` (`/bin/ramfs -m /n/wp`; sys/src/cmd/ramfs.c forks with `RFFDG|RFPROC|RFNAMEG|RFNOTEG` and mounts its own pipe) and `create` (a plain-file create through devmnt into ramfs). The two `syscall 10 unimplemented` lines in each capture come from the boot chain's FAUTH before the prompt. They are the designed no-auth fall-through and are not part of the probe.

**A-venue holds.** ramfs builds, mounts and creates on the group-A kernel. The write flow fails only at the inventory arms: b5 (write, and readback after it), b6 (mkdir), b7 (union create) and b13 (remove).

**A-rfork holds.** `fdsplit` is `WP-FAIL` with the kernel's `bad flags for non-RFPROC` errstr, carried in rfdprobe's own `FAIL rffdg` line. `/bin/ramfs` never reaches that path: the `mount` step passed.

### New finding, outside b4–b7/b13 (for the checkpoint)

**An fd table shared by a plain `rfork(RFPROC)` child is not released when its last sharer exits.** A backquote reader of such a process never sees end of file, so rc hangs. The first `writeprobe.rc` captured `fdsplit` with `` `{/bin/rfdprobe ...} ``. That hung on HVF after rfdprobe and both its children had exited (`.build/p20-07-wp-hvf-hang1.log`). Single-line reductions on the same kernel and image:

| Typed line | HVF | TCG |
|------------|-----|-----|
| `` x=`{/bin/rfdprobe}; echo DIAGA $x `` | hangs (no `DIAGA` output; all three procs exited) | hangs |
| `` x=`{/bin/rfdprobe -s}; echo DIAGS $x `` (one shared-table RFPROC child that exits at once; **no** bare rfork) | hangs | hangs |
| `` x=`{/bin/forkstress -n 1}; echo DIAGF $x `` (control: `fork()`, a copied table) | completes: `DIAGF forkstress: start 1 forks … forkstress: ok 1 forks` | — |
| `/bin/rfdprobe -s; echo DIAGT $status` (no pipe) | completes: `rfdprobe: share ok`, `DIAGT` with an empty status | — |
| `` x=`{/bin/echo hi}; echo DIAGB $x `` (control) | completes: `DIAGB hi` | — |

So a pipe write end held in an fd table shared through `rfork(RFPROC)` without `RFFDG`/`RFCFDG` stays open after every process holding that table has exited. Reading the code, `exit_tail` (aarch64 `syscall.rs` ~2093) drains the group only when `Arc::strong_count == 1`, so a reference to the shared group appears to outlive the child. That is a reading, not a measurement. The bare-rfork reject (b4) is not involved: `-s` makes no bare rfork. It is not one of b4–b7/b13. libthread's `proccreate` (RFPROC without RFFDG) and any lib9p server that uses it share tables this way.

Effect on the probe: `fdsplit` now runs rfdprobe without a pipe (`if(/bin/rfdprobe) … $status`). rfdprobe's exit string is its own FAIL line, because this kernel's wait message carries the bare exit string with no `prog pid:` prefix. The `mount` step is also uncaptured, because the ramfs server child keeps its copy of the fd table for its whole life. rfdprobe keeps the `-s` mode as the reproducer.

### Red steps per inventory item

RED-STEP b4: fdsplit
RED-STEP b5: write
RED-STEP b6: mkdir
RED-STEP b7: union-create

Each line names the probe step that is `WP-FAIL` on this kernel because of that item, and it is the same on HVF and TCG. b4: rfdprobe's `FAIL rffdg` with `rfork: bad flags for non-RFPROC`, and also `FAIL rfcfdg`. b5: `devmnt: the mounted tree is read-only this era`; `readback` is red only as a consequence. b6: `create: directories unsupported this era`. b7: the create through the `-ac` union landed on the read-only first member (`namec: device has no create`) and not in `/n/wp`. b7's red is the absence of the union redirect, not a b7-specific errstr, so its green-after is the file appearing in `/n/wp`. No item reads `none`. The remove step is red for b13, which is outside 20-08's b4–b7 pin claim.

### Lone-member RFMEM brk (A-brk)

Probe: `build/aarch64/brkprobe.c`. The image is rebuilt with brkprobe baked in: `bootfs.paq` sha256 `30f61249173fb665f6e6034e76c31496558bc9965b0499d2be901c2d0c5999aa`. Same pinned kernel `qc1i4nhl…-r9-kernel-virt-57e2952`, no override. The tier-1 gate passed on TCG with this image: `38 T1-OK markers + 23 T1-SKIP markers (computed)`, `ALL STAGES PASS`. Typed line: `/bin/brkprobe; echo BRKST $status`. Default mode: phase lone, then phase family.

Ten runs, identical output in every run:

| Run | Accel | Output | Exit status |
|-----|-------|--------|-------------|
| 1–5 | HVF | `brkprobe: start break=0x21bd0` / `brkprobe: phase lone ok 8388608 (break 0x22bf8..0x822bf8)` / `brkprobe: phase family ok 8388608 (break 0x822bf8..0x1022bf8)` / `brkprobe: ok 8388608` | nil (`BRKST` with an empty status; `process 6 exited: ""`) |
| 1–5 | TCG | the same four lines | nil |

Controls, one run each per accelerator with the same output on both: `brkprobe -p` (plain growth, no fork) printed `phase plain ok 8388608 (break 0x21bd0..0x821bd0)`, nil. `brkprobe -f` (the family arm alone) printed `phase family ok 8388608 (break 0x21bd0..0x821bd0)`, nil.

Kernel notes: none. No `user fault`, `unresolvable` or `panic` line appears in any of the 14 captures. Between the RFMEM child's exit (`process 7 exited: ""`) and `phase lone ok`, the HVF run-1 capture has exactly **2048** `fault: bss page-in` lines, one per 4 KiB page of the 8 MiB growth. The lone member's growth is served by the demand pager. The family phase has **0** page-ins in its range, because the family arm maps the growth into every member eagerly, as `rfmem_brk_set` documents.

**Invalid earlier runs (probe defect, not a kernel result).** The first two brkprobe builds reported `MISMATCH` on every run, 10 + 14 runs in `.build/p20-07-brk-v1/` and `.build/p20-07-brk-v2/`. Example: `MISMATCH addr=0x28bf8 phase=lone page=6 want=0x15 got=0x15`. want equalled got, and the first bad page was exactly the first page whose unmasked pattern `(page*31 + who*0x5a + 1)` exceeds 0xff: page 6 for who=1, page 3 for who=2 (the family child, `addr=0x24bd0`), and page 0 for who=4 (plain). So 7c on arm64 does not narrow a `uchar` function result before the caller compares it. The probe now masks with `& 0xff`, with a comment on why, and every run passes. The compiler behavior is recorded in `deferred-items.md`. It is not a kernel defect and not in this plan's scope.

A-brk holds: the lone-member arm works on aarch64 by demand paging; the x86_64 eager-map change is not ported

### Owner decision (D-09 checkpoint)

**Owner decision (2026-11-19, relayed by the coordinator): `ramfs-venue-brk-holds`.** ramfs is the writable venue for the b4–b7 ports. 20-08 pins them through `T1-OK writeprobe` against the four RED-STEP lines above. The lone-member brk arm is not ported. brkprobe stays in the image as a regression check only.

- **Finding 1 (the shared-fd-table pipe leak)** was handed to a separate gsd-debugger investigation. It is not fixed in 20-07.
- **The 7c uchar-narrowing note** is in `deferred-items.md`.
- **The lima guest's `core.ignorecase=false`** was approved by the owner and is kept.

D-09: ramfs-venue-brk-holds

## Group B ports

Plan 20-08. r9 `b82ee9d` (local, not pushed; `aarch64/src/syscall.rs` only, +47/-22) ports the aarch64 halves of b4 (non-RFPROC `rfork(RFFDG)` / `rfork(RFCFDG)`), b5 (devmnt write), b6 (DMDIR create) and b7 (union create: `walk_one_union` / `create_chan_union` with the `nomount` bit). `git diff origin/main..HEAD -- port/src` in r9 is empty. Harvey's pin is unchanged (`57e2952`); every run below takes the kernel through `--override-input` or the driver's kernel path.

- **Kernels:** before = the pin, `/nix/store/qc1i4nhl0slbgwcv8a9gnm877c3nmm57-r9-kernel-virt-57e2952`, ELF sha256 `da4ab2da…9b73`. After = `/nix/store/cqiqfc81zxz5c5v91kb37s9b4adqc7vg-r9-kernel-virt-b82ee9d`, ELF sha256 `e130d40a41fc6484786701b4007cf0516ea05c89e8ff2b1fbfbfffa7dd49ee8c` (60524968 bytes; the pin's is 60517848). The kernel bytes change, as a code change must.
- **Image:** `build/aarch64/bootfs.paq` sha256 `7960d4297ab99b354e83a78cf3b81775c310dada61ed951ff0f5d5636d225de5`, baked by the plan's TCG tier-1 run below (it carries the new sweep entry). Every before and after write-flow run here booted this same file.
- **Driver:** `.build/p20-08-probe.sh`, an uncommitted copy of 20-07's launcher with the kernel package as a parameter, typing `rc /lib/writeprobe.rc` at the `%` prompt and waiting for `WP-DONE`. Host: darwin-arm64, qemu 11.1.2, `virt,gic-version=3`; HVF `-cpu host`, TCG `cortex-a72`.

### Write-flow transcripts, before and after (same image)

Before, kernel `57e2952`. HVF and TCG byte-identical, and identical to 20-07's transcript under `## Group B measurements`:

```
WP-FAIL fdsplit rfdprobe: FAIL rffdg rffdg: rfork: bad flags for non-RFPROC
WP-OK mount
WP-OK create
WP-FAIL write echo: write error: devmnt: the mounted tree is read-only this era [status: write error]
WP-FAIL readback got:
WP-FAIL mkdir mkdir: can't create /n/wp/d: create: directories unsupported this era [status: error]
WP-FAIL union-create [status: error]
WP-FAIL remove rm: /n/wp/f: syscall not implemented [status: syscall not implemented]
WP-DONE
```

After, kernel `b82ee9d`, HVF:

```
WP-OK fdsplit
WP-OK mount
WP-OK create
WP-OK write
WP-OK readback
WP-OK mkdir
WP-OK union-create
WP-FAIL remove rm: /n/wp/f: syscall not implemented [status: syscall not implemented]
WP-DONE
```

After, kernel `b82ee9d`, TCG (`diff` against the HVF transcript is empty):

```
WP-OK fdsplit
WP-OK mount
WP-OK create
WP-OK write
WP-OK readback
WP-OK mkdir
WP-OK union-create
WP-FAIL remove rm: /n/wp/f: syscall not implemented [status: syscall not implemented]
WP-DONE
```

### Red steps, before and after

| 20-07 red step | Step | Before (HVF = TCG) | After (HVF = TCG) |
|----------------|------|--------------------|-------------------|
| RED-STEP b4 | fdsplit | WP-FAIL (`rfork: bad flags for non-RFPROC`) | WP-OK |
| RED-STEP b5 | write | WP-FAIL (`devmnt: the mounted tree is read-only this era`) | WP-OK |
| (b5, downstream) | readback | WP-FAIL (empty file) | WP-OK |
| RED-STEP b6 | mkdir | WP-FAIL (`create: directories unsupported this era`) | WP-OK |
| RED-STEP b7 | union-create | WP-FAIL (the create landed on the read-only first member) | WP-OK |
| (b13) | remove | WP-FAIL (`syscall not implemented`) | WP-FAIL, unchanged: 20-14 owns REMOVE |

`fdsplit` is the rfork port's step: no other step reaches the non-RFPROC branch (ramfs's own rfork carries RFPROC, and `mount` passed before the port too).

### The sweep entry and the gate

`tier1-sweep.rc` gained one r9-venue entry after `forkstress`. It prints `T1-OK writeprobe` only when the seven owned steps (fdsplit, mount, create, write, readback, mkdir, union-create) each printed `WP-OK`, and otherwise `T1-FAIL writeprobe <missing steps>`. `remove` is never required. `nix/tier1-r9.sh` lists `writeprobe` among the fixed expected names, so the expected OK set went from 38 to 39. The SKIP set is unchanged at 23. `tier1-r9.expect` is unchanged: its `no-unsupported-era` absence check already existed (20-01).

Shape, measured while building it:

- **No backquote over the probe.** The ramfs server keeps a copy of the fd table, and so the pipe writer, for its whole life. The probe writes into a pipe to awk, which copies each line to `/dev/cons`, collects the `WP-OK` names and exits at `WP-DONE` without waiting for end of file. Only awk's stdout is backquote-captured. The probe runs in its own namespace (`rfork n`), so `/n/wp` and the union bind on `/lib/tier1` do not leak into the sweep.
- **r9's exec takes at most 128 bytes per argument** (`MAX_EXEC_ARG_LEN`, aarch64 `syscall.rs`). The first version of the entry passed a ~500-byte awk program. It failed on HVF and TCG with `/bin/hawk: string too long` (`process … exited: "can't exec: string too long"`), no WP lines and `post-pass FAILED — missing T1-OK writeprobe` (captures `.build/p20-08-tier1-{hvf,tcg}.out` of the first attempt were overwritten; the iteration rerun is `.build/p20-08-tier1-hvf-iter2.{out,log}`). The shipped program is 67 bytes, and the set check is in rc.

The plan's verify command, against the local kernel (`--override-input r9 git+file:///Users/neilskinner/code/r9`, a full build):

```
hvf exit=0 ok=1 fail=0 okall=39 skip=23
tcg exit=0 ok=1 fail=0 okall=39 skip=23
```

Both runs printed `== expected on r9: 39 T1-OK markers + 23 T1-SKIP markers (computed)` and `tier1-r9: ALL STAGES PASS … no-unsupported-era`. Captures: `.build/p20-08-tier1-{hvf,tcg}.{out,log}`.

**At the current pin (`57e2952`), this sweep entry is `T1-FAIL writeprobe`**: the before transcript has five of the seven owned steps red. So the default `nix run .#boot-r9-tier1` (no override) reds from this commit until the pin advances to an r9 that carries `b82ee9d`. That needs the r9 push, which waits for the owner.

### r9 boot-test profiles at b82ee9d (TCG)

`cargo xtask boot-test --arch aarch64 --config <c>` on the working tree that became `b82ee9d`: virt 0 (14 s), virtlowecam 0 (4 s), virtpanic 0 (8 s), virtexec 0 (10 s), virtexec3 0 (1 s), virtmulti 0 (2 s), virtnotes 0 (2 s), virtnet 0 (9 s), virtip 0 (12 s). virtshell exits 1 with `dev_exec: config carries no initrd image`, as at 20-04: it is not an xtask boot-test profile by design. The virtshell kernel is the one both tier-1 runs above booted green.

### Partial series at r9 b82ee9d only (stopped by the owner)

This is a record for `b82ee9d` alone. It is **not** the at-pin series. The owner stopped it because the debugger's r9 commits (`3a1c9e5`, the aarch64 `exit_tail` fd-group release, and more to come) land on top of `b82ee9d`, and one series is to cover all of them.

It used the 20-06 shape, with `R9_OVERRIDE='git+file:///Users/neilskinner/code/r9?rev=b82ee9d2f82465ec3ba2ba8e4c63bef8db065ea5'` and `R9_STOP_ON_FAIL=1`. Harvey was at `8bad466f1`. It started at 2026-11-19T16:15:01Z and was stopped at about 16:35Z by killing only this plan's series process tree. Every run booted the kernel `/nix/store/cqiqfc81zxz5c5v91kb37s9b4adqc7vg-r9-kernel-virt-b82ee9d`, the same store path as the tested kernel above. `nix build --rebuild` of its derivation (`ghm52l2r…-r9-kernel-virt-b82ee9d.drv`) was clean, so the build is reproducible.

```
SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3650
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2556
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=1095
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24
boot-r9-smoke accel=hvf: STOPPED at 52 of 1753 runs, pass=52 fail=0 pushword=0 forks=416 (no SERIES line; the counts are summed from its RUN lines)
```

The tier-1 runs carry the new `writeprobe` entry. Each prints 365 forks per run where 20-06 printed 328: the probe's forks. The run in flight when the series stopped has no RUN line and is not counted. The series log is copied to `.build/p20-08-series-b82ee9d.log`, and the per-run captures are under `.build/hvf-series/`.

### Series at r9 7b598f2 (the 20-08 ports plus the debugger's fd-group fixes)

r9 `7b598f2` contains `b82ee9d` (this plan) and the debugger's `3a1c9e5` (aarch64 `exit_tail` releases the fd-group reference before it diverges), `f8c2ac9` (a bare `rfork(RFCFDG)` gets a fresh table, and the bare split releases the old one; this edits this plan's `sys_rfork` hunk), `5893ae9` (aarch64 exit-path drains: one-at-a-time fd close and the #44 husk sweep) and `7b598f2` (the `sem_deregister_waiter` FIFO fix). Checks: `git merge-base --is-ancestor b82ee9d 7b598f2` and `git merge-base --is-ancestor 3a1c9e5 7b598f2` both hold. `57e2952..7b598f2` touches only `aarch64/src/{proc,syscall}.rs` and `x86_64/src/{proc,syscall}.rs`, with no `port/src` change.

**Tier-1 gate at 7b598f2** (`--override-input r9 'git+file:///Users/neilskinner/code/r9?rev=7b598f2…'`, full build):

```
hvf exit=0 ok=1 fail=0 okall=39 skip=23
tcg exit=0 ok=1 fail=0 okall=39 skip=23
```

Both runs print `expected on r9: 39 T1-OK markers + 23 T1-SKIP markers` and `ALL STAGES PASS`. With the driver at `7b598f2`, the writeprobe transcripts on HVF and TCG are byte-identical to each other and to the `b82ee9d` after-transcript above: seven `WP-OK` lines, then `WP-FAIL remove … syscall not implemented`. The image baked by these runs is bootfs sha256 `180a3c86d4f39373f3f31442cf062fb45de69ad88f0ea1ee995155ed2b7ac703`. It differs from the `7960d429…` image above, although the sources are the same; the bake is not byte-stable from run to run. Captures: `.build/p20-08-7b5-tier1-{hvf,tcg}.{out,log}`, `.build/p20-08-7b5-wp-{hvf,tcg}.transcript`.

**Series**, in the 20-06 shape, with `R9_OVERRIDE='git+file:///Users/neilskinner/code/r9?rev=7b598f23f03af5aec779a2846801338bd6331f90'` and `R9_STOP_ON_FAIL=1`. Harvey was at `176723fc9`. It ran from 2026-11-19T17:43:45Z to 21:58:34Z:

```
SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3650
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2556
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=1095
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024
```

That is 1808 of 1808 runs green and 21562 forks, with no `pushword` line. Every block booted `/nix/store/2inqg9mw20zfb9c8300zrhiy8x5l0nqv-r9-kernel-virt-7b598f2`. No capture in any block has a `Not registered`, `user fault` or `unresolvable` line. The tier-1 blocks carry the `writeprobe` entry: 365 forks per run. The series log is `.build/p20-08-series-7b598f2.log`, and the per-run captures are under `.build/hvf-series/boot-r9-*-20261119T12[4-5]*`.

### Byte identity (aarch64 kernel-virt)

| Kernel | Store path | ELF sha256 | Bytes |
|--------|------------|------------|-------|
| the pin (57e2952) | `qc1i4nhl…-r9-kernel-virt-57e2952` | `da4ab2dab941acb498e3aa8dd41cb6db7a9fb807d1ee1dda053984aa235c9b73` | 60517848 |
| b82ee9d (Task 1 alone) | `cqiqfc81…-r9-kernel-virt-b82ee9d` | `e130d40a41fc6484786701b4007cf0516ea05c89e8ff2b1fbfbfffa7dd49ee8c` | 60524968 |
| 7b598f2 (series kernel) | `2inqg9mw20zfb9c8300zrhiy8x5l0nqv-r9-kernel-virt-7b598f2` | `92cc905bdd4392b15291849d4fe475f01d4610e0a9f8c971f8d3b557f6f45578` | 60584848 |
| 27f38a3 (r9 origin/main) | `193ys32r0j6m137cljadqy2dxzc2n60a-r9-kernel-virt-27f38a3` | `92cc905bdd4392b15291849d4fe475f01d4610e0a9f8c971f8d3b557f6f45578` | 60584848 |

- **The 7b598f2 kernel is reproducible.** `nix build --rebuild` of `yhf7xknsbzl6b6mdxm0mff54f06vbrgh-r9-kernel-virt-7b598f2.drv` exits 0 with no `may not be deterministic`. It is the same store path the debugger reported (sha256 `92cc905b…`). `b82ee9d`'s `--rebuild` was clean too.
- **27f38a3 equals 7b598f2 plus one `flake.nix` line**, the x86_64 boot-iso `outputHash` (`sha256-rl+HA3pg…` → `sha256-Dk1zd/JQ…`). `git diff --stat 7b598f2 27f38a3` lists only `flake.nix`.
- **27f38a3's aarch64 kernel is byte-identical to the series kernel.** `nix eval` of `github:requaos/r9/27f38a3a916d829307cce60bb09e4ce50f361ced#packages.aarch64-darwin.kernel-virt.outPath` gives `193ys32r…-r9-kernel-virt-27f38a3`, the store path a Harvey pin to `27f38a3` would boot. `diff -r` of that path against `2inqg9mw…-7b598f2` is empty, and the ELF sha256 values are equal. The store path differs only because the source rev is part of the derivation name and inputs.
- **The x86_64 kernel bytes change too** (`57e2952..7b598f2` touches `x86_64/src/{proc,syscall}.rs`). They are not measured here. The pin needs the linux-host `nix build .#boot-iso` against `27f38a3`'s new `outputHash` and the x64 gates, which the debugger is running separately.

## Churn gate (pre-fix)

Plan 20-09 ported the x86_64 churn gate to aarch64 as the r9 boot-test profile `virtchurn`: r9 `ff1b155` (the kernel driver `aarch64/src/platform/virt/churngate.rs`, the `heap_stats`/`heap_census` wrappers, `config_virtchurn.toml`) and `3aa3eeb` (the xtask profile and markers). Harvey `783b13ed6` stages `churnmark` and `churnsem` into `build/aarch64/smoke-out/` for `cargo xtask initrd`.

**Outcome in one line:** A5 holds for the exit path without the drains (about 16.4 KiB per exec, gate red). The exit path as it stands before 20-10 already has the drains, and the gate is green there (136 to 154 bytes per exec). The closing statement is at the end of this section.

**What "pre-fix" means here.** The plan assumed the aarch64 exit tail still had the borrowed fd drain and no husk sweep. That was out of date by the time this plan ran. The debugger's r9 `3a1c9e5` (drop the detached fd-group Arc before `exit_tail` diverges) and `5893ae9` (one-at-a-time fd drain plus the #44 husk sweep, `proc::sweep_husk_payloads`) landed before 20-09 and are in the pin `27f38a3`. Those are the exit-half drains 20-10 Task 1 plans to port. So the gate was run in two places:

- **As planned:** r9 `3aa3eeb`, the exit path as it stands before 20-10 (the pin `27f38a3` plus this plan's two commits). Three runs.
- **Added:** the same two commits cherry-picked onto r9 `b82ee9d`, the 20-08 port commit, which comes just before `3a1c9e5`. This is the exit path without the drains. Three runs, in a scratch worktree that was removed afterwards; nothing was committed.

Venue: `R9_HARVEY_DIR=/Users/neilskinner/code/harvey cargo xtask boot-test --arch aarch64 --config virtchurn`, TCG (`virt,gic-version=2`, cortex-a72, 1024M), darwin-aarch64.

**Threshold:** `CEILING_BYTES_PER_EXEC = 1772` bytes per exec over the steady leg (iterations 41 to 1400). This is the x86_64 driver's constant, `max(3 x 420, 1024) + 512` from x86_64's first measured-green baseline. It is not re-derived from any aarch64 reading. The kernel prints it on the slope line, and the xtask post-pass re-derives `measured` from the raw `heap base`/`heap end` samples and the churn-leg print counts.

### At r9 3aa3eeb (exit path with the debugger's drains)

| Run | Exit | `heap one` (after exec 1) | census `one` | `heap end` (after exec 1400 + drain) | census `end` | steady (2..40) | measured (41..1400) | Verdict |
|-----|------|------|------|------|------|------|------|------|
| 1 | 0 | 81920 | live 0 / pooled 36 blocks 59776 B | 301312 | live 0 / pooled 135 blocks 179200 B | 482 | 147 | PASS |
| 2 | 0 | 81920 | live 0 / pooled 36 blocks 59776 B | 311360 | live 0 / pooled 95 blocks 188992 B | 482 | 154 | PASS |
| 3 | 0 | 81920 | live 0 / pooled 36 blocks 59776 B | 286784 | live 0 / pooled 106 blocks 164672 B | 482 | 136 | PASS |

- Every run prints `churngate: DONE iterations=1400 semgens=39`. The post-pass counted 1361 `churnmark: ready` lines and 39 `churngate: semgen` lines. No capture has a `panic`, `Unhandled`, `user fault`, `unresolvable` or `Not registered` line.
- The arena is 33554432 bytes. `heap start` is 51840 and `heap base` is 100736 in all three runs.
- Each slope line reads `churngate: slope steady=482 measured=<n> ceiling=1772`. `semgens=39` and not 40 because the generation at iteration 35 falls in the baseline leg, which spawns none. x86_64 has the same count.
- The census `live` column reads 0 blocks at every sample on aarch64. The verdict does not use it (the verdict rides the bump cursor), but it means the live/pooled split is not informative on this arch. Recorded in `deferred-items.md`.
- Captures: `.build/p20-09-virtchurn-run{1,2,3}.{log,out}` (sha256 prefixes `36bf56df`, `6a5b3a54`, `b96a82d7`). r9 sha in `.build/p20-09-virtchurn-r9sha.txt`. An earlier trial run at the same kernel (before the Task 2 commit, identical xtask) read `measured=144`, PASS.

### At r9 b82ee9d + the gate (exit path without the drains)

| Run | Exit | `heap one` | census `one` | `heap base` (after exec 40) | steady (2..40) | churn leg until the panic | Verdict |
|-----|------|------|------|------|------|------|------|
| 1 | 1 | 81920 | live 0 / pooled 29 blocks 51264 B | 737344 | 16805 | 1095 marks + 32 gens, cursor 21078144, 18048 B/exec | FAIL |
| 2 | 1 | 81920 | live 0 / pooled 29 blocks 51264 B | 737344 | 16805 | 1103 marks + 31 gens, cursor 21160064, 18009 B/exec | FAIL |
| 3 | 1 | 81920 | live 0 / pooled 29 blocks 51264 B | 737344 | 16805 | 1088 marks + 30 gens, cursor 21012544, 18135 B/exec | FAIL |

- The cursor climbs about 16.4 KiB per exec in the baseline leg, the x86_64 pre-17-02 size (WINDOWS #44: the ~8 KiB fd-group Arc plus the husk's retained group handles).
- None of the three runs reaches the end sample. Each dies at about exec 1170 with `panicked at port/src/allocator.rs:300:9: allocator: header table exhausted`, about 21 MB into the 32 MiB arena. The xtask gate fails on the negative scan (`panic`), with the DONE line never printed.
- The churn-leg column is computed from the per-exit `churngate: heap exit` lines up to the panic: (last cursor - base) / (marks + gens in the leg). It runs higher than the baseline because each churnsem generation's contenders exit too.
- Captures: `.build/p20-09-virtchurn-predrain-run{1,2,3}.{log,out}`.

### Kernel bytes

- **aarch64 kernel-virt changes.** `nix build git+file:///Users/neilskinner/code/r9?rev=3aa3eeb…#kernel-virt` gives `jqv87m36…-r9-kernel-virt-3aa3eeb`, ELF sha256 `028044f52ad7872c8828e1add5cdcdca7eb1bfd4975813849d6c616dc232c247`, 60585720 bytes. The pinned `27f38a3` is `92cc905b…`, 60584848 bytes. The churn code is all under `cfg(dev_churn)`, but `exec_bootstrap`'s head moved into `exec_prologue` and lines shifted in `main.rs`, `proc.rs` and `syscall.rs`, so code layout and panic-location constants differ. The local virtshell debug ELF agrees: its loadable image differs from the `27f38a3` build in 618874 bytes, with section sizes unchanged. The pin did not move in this plan. Any pin move that carries `ff1b155` needs the 20-06-shape HVF series first; it can be batched with 20-10's r9 changes.
- **x86_64 kernel bytes are unchanged.** A local `cargo xtask build --arch x86-64 --config q35churnshell` (the boot-iso kernel's config) gives ELF sha256 `b7a1e00bc371e0925f0c9ce619981ba2ba131ea166b0cbd51e53a5f57ed0d435` both before (r9 `27f38a3`) and after (`3aa3eeb`). The only non-aarch64 changes are the workspace `check-cfg` list and xtask. The boot-iso `outputHash` needs no re-derivation, and no x64 gate run is owed. `kernel-x64` is a linux-only flake package, so the nix-side comparison is left to the linux host.
- The `virtshell` and `virtexec` configs still build. Their warning count (25) is unchanged.

A5 holds: the exit path leaks 16805 bytes per exec on aarch64 when it lacks the debugger's drains (r9 `b82ee9d`), and the gate is red there (the kernel dies of allocator header-table exhaustion at about exec 1170). The exit path as it stands before 20-10 (r9 `3aa3eeb`, the pin `27f38a3` plus the gate) already carries those drains (`3a1c9e5`, `5893ae9`). There the slope is 136 to 154 bytes per exec against the 1772 threshold, so the gate is green before 20-10 and serves 20-10 as a regression pin.

## Churn gate (post-fix)

Plan 20-10 Task 1 planned to port the aarch64 exit-path drains. They were already in r9 before 20-10 started, so Task 1 had no code to write. This section is its measurement.

**What Task 1 asked for, against what r9 already had.** Every item is in the pin `27f38a3`:

| Task 1 item | Where it is in r9 | Commit |
|---|---|---|
| `empty_pgrp`, `empty_env_group`, `empty_rendez_group` (lazy singletons, `empty_fdgroup`'s shape) | `aarch64/src/proc.rs` | `5893ae9` |
| `sweep_husk_payloads`: the last-holder `take_mount_chans` close under a `LockNode`, the three group swaps, `slash`/`dot` dropped | `aarch64/src/proc.rs` (`release_pgrp` + `sweep_husk_payloads`) | `5893ae9` |
| (1) `sys_exits` copies the message into a `[0u8; ERRMAX]` stack buffer and drops the `Vec` before the diverging call | `aarch64/src/syscall.rs` `sys_exits` | `5893ae9` |
| (2) The owning drain: `drain_all()` under the lock, then `close_chan` and drop one chan at a time | `aarch64/src/proc.rs` `release_fd_group` | `5893ae9` (one at a time), `3a1c9e5` (the helper) |
| (3) The detached fd group dropped before the tail | `release_fd_group` is a returning helper, so the detached `Arc` drops at its return | `3a1c9e5` |
| (4) `exit_tail` calls `proc::sweep_husk_payloads(proc)` | `aarch64/src/syscall.rs` `exit_tail` | `5893ae9` |
| The 20-09 `#[cfg(dev_churn)]` heap-exit marker kept | `exit_tail` | `ff1b155` (unchanged) |

One placement differs from the plan's text, on purpose. The plan says to call the sweep "after the three queue resets and before `ProcState::Moribund`", which is where x86_64 has it. On aarch64, `5893ae9` calls it after `rendez_remove` and before `free_user_mappings`. The comment in place gives the reason: a mount chan's Tclunk can RPC-block, and an RPC needs the address space live, the same rule as the fd sweep. That order is at least as safe as x86_64's, so it was left alone. Task 1 therefore made no r9 commit. The debugger's history is in `.planning/debug/resolved/shared-fgrp-pipe-leak.md` and `.planning/debug/r9-fgrp-followups.md`.

**The kernel measured:** r9 `1125a20`. That is `3aa3eeb` (the pin `27f38a3` plus 20-09's gate) plus 20-10 Task 2's close-on-exec sweep, so the reading covers the final r9 rev of this plan.

Venue: the same as the pre-fix section. `R9_HARVEY_DIR=/Users/neilskinner/code/harvey cargo xtask boot-test --arch aarch64 --config virtchurn`, TCG (`virt,gic-version=2`, cortex-a72, 1024M), darwin-aarch64. Threshold: `CEILING_BYTES_PER_EXEC = 1772`, unchanged.

| Run | Exit | `heap one` | census `one` | `heap end` | census `end` | steady (2..40) | measured (41..1400) | Verdict |
|-----|------|------|------|------|------|------|------|------|
| 1 | 0 | 81920 | live 0 / pooled 36 blocks 59776 B | 299520 | live 0 / pooled 122 blocks 177280 B | 482 | 146 | PASS |
| 2 | 0 | 81920 | live 0 / pooled 36 blocks 59776 B | 311232 | live 0 / pooled 138 blocks 188992 B | 482 | 154 | PASS |
| 3 | 0 | 81920 | live 0 / pooled 36 blocks 59776 B | 312704 | live 0 / pooled 151 blocks 190464 B | 482 | 155 | PASS |

- Every run prints `churngate: DONE iterations=1400 semgens=39`. Each log has 1361 `churnmark: ready` lines and 39 `churngate: semgen` lines, and no `panic`, `Unhandled`, `user fault`, `unresolvable` or `Not registered` line. `heap start` is 51840 and `heap base` is 100736 in all three runs, as before.
- Captures: `.build/p20-10-virtchurn-run{1,2,3}.{log,out}` (log sha256 prefixes `801c8905`, `b21b1fb0`, `81a3ca53`). The r9 sha is in `.build/p20-10-virtchurn-r9sha.txt`, and the per-run exits are in `.build/p20-10-virtchurn-runs.txt`.

**Before and after.** Two "before" readings exist, so both are compared.

| Kernel | Exit path | measured, 3 runs (B/exec) | Mean | Verdict |
|---|---|---|---|---|
| r9 `b82ee9d` + gate | no drains | about 16805 steady; dies near exec 1170 | n/a | FAIL 3/3 |
| r9 `3aa3eeb` (20-09) | drains (`3a1c9e5`, `5893ae9`) | 147, 154, 136 | 145.7 | PASS 3/3 |
| r9 `1125a20` (this plan) | drains + close-on-exec sweep | 146, 154, 155 | 151.7 | PASS 3/3 |

The pre-fix gate was already green at `3aa3eeb` (A5 is false for that exit path), so the bar here is "no worse than pre-fix". The post-fix range (146 to 155) sits inside the pre-fix run-to-run spread (136 to 154; that spread is 18 B). The 6 B difference in means is 0.3% of the ceiling. Neither commit was expected to move the churn slope: churnmark opens no OCEXEC fd, so the close-on-exec sweep only walks an fd table with nothing to take. So the post-fix slope is no worse than pre-fix within measurement noise. Strictly, though, the third run (155) is above the best pre-fix run (136), and this section does not claim an improvement.

**The other aarch64 boot-test profiles at `1125a20` (TCG):** virt 0 (13 s), virtlowecam 0 (4 s), virtpanic 0 (9 s), virtexec 0 (9 s), virtexec3 0 (2 s), virtmulti 0 (1 s), virtnotes 0 (2 s), virtnet 0 (9 s), virtip 0 (12 s). `virtshell` exits 1 with `panicked at aarch64/src/main.rs:580:9: dev_exec: config carries no initrd image`, the same as at 20-04 and 20-08. It is not an xtask boot-test profile by design; the tier-1 runs below boot its kernel. Outputs: `.build/p20-10-prof-<config>.out`, with the summary in `.build/p20-10-profiles.txt`.

## Exec and brk pins (20-10)

**The ports.** r9 `1125a20` (20-10 Task 2, on top of `3aa3eeb`) adds `close_on_exec_fds` to `aarch64/src/exec.rs`, x86_64's twin. It takes the OCEXEC-marked chans with `FdGroup::take_cexec` under the group lock and runs `port::namec::close_chan` on each one outside the lock. `exec_replace` calls it exactly once, after `check_seed_fit` and before `free_user_mappings`, so a failed exec closes nothing. brk takes the D-09 `ramfs-venue-brk-holds` branch: the only change is one doc-comment sentence above `rfmem_brk_set`'s one-member arm in `aarch64/src/proc.rs`. It records 20-07's measurement and that x86_64's eager mapping is deliberately not ported. `3aa3eeb..1125a20` touches only `aarch64/src/exec.rs` and `aarch64/src/proc.rs`, with no `port/src` change. Checks at `1125a20`:
- `virtshell` builds, with aarch64 warnings unchanged at 25;
- `cargo xtask test` is green;
- `cargo test -p aarch64 --bins --target aarch64-apple-darwin` passes 29.

**The sweep pin.** Harvey `61ad20f43` adds `build/aarch64/cexecprobe.c`. It opens `/lib/namespace` once `OREAD|OCEXEC` and once `OREAD`, execs `/bin/cexecprobe` with the two fd numbers, and checks that the first is closed and the second still open. subset-build.sh compiles and harvests it, and mkimage.sh bakes it to `/arm64/bin/cexecprobe` with a manifest assert. tier1-sweep.rc runs `/bin/cexecprobe` and `/bin/brkprobe` in a new r9-venue block after `writeprobe`. nix/tier1-r9.sh adds both names to the fixed `R9_EXPECT_OK` names, so the expected OK set grows from 39 to 41, and the 23 SKIPs are unchanged.

**Tier-1 gate at r9 1125a20** (`--override-input r9 git+file:///Users/neilskinner/code/r9`, full build; kernel `/nix/store/j0d1q06rqc36ikf8p312fkqdqdzpyj3b-r9-kernel-virt-1125a20`):

```
hvf exit=0 cexec=1 brk=1 fail=0
tcg exit=0 cexec=1 brk=1 fail=0
```

Both runs count 41 `T1-OK` and 23 `T1-SKIP` lines and print `ALL STAGES PASS`. The probe lines are the same on HVF and TCG:

```
cexecprobe: ok
T1-OK cexecprobe
brkprobe: start break=0x21bd0
brkprobe: phase lone ok 8388608 (break 0x22bf8..0x822bf8)
brkprobe: phase family ok 8388608 (break 0x822bf8..0x1022bf8)
brkprobe: ok 8388608
T1-OK brkprobe
```

Captures: `.build/p20-10-tier1-{hvf,tcg}.{out,log}` (log sha256 prefixes `453944c5`, `60d3a794`), with the summary in `.build/p20-10-tier1-summary.txt`.

**The pin is red without the port.** The default gate at the Harvey pin, r9 `27f38a3` (`R9_SKIP_BUILD=1 R9_ACCEL=hvf nix run .#boot-r9-tier1`, no override, the same freshly built userland; kernel `193ys32r…-r9-kernel-virt-27f38a3`), exits 1:

```
cexecprobe: LEAK fd=3
T1-FAIL cexecprobe
tier1-r9: post-pass FAILED — missing T1-OK cexecprobe
```

`T1-OK brkprobe` is present at the pin as well, as expected: D-09 ported no brk code, so brkprobe is a regression pin, not a red-to-green one. Capture: `.build/p20-10-tier1-pinned-hvf.{out,log}` (log sha256 prefix `b9883799`). This also means the default gate stays red from `61ad20f43` until the pin advances to an r9 that carries `1125a20`, the same situation as 20-08's writeprobe before its pin move.

### Kernel bytes at r9 1125a20

| Kernel | Store path | ELF sha256 | Bytes |
|--------|------------|------------|-------|
| the pin (27f38a3) | `193ys32r0j6m137cljadqy2dxzc2n60a-r9-kernel-virt-27f38a3` | `92cc905bdd4392b15291849d4fe475f01d4610e0a9f8c971f8d3b557f6f45578` | 60584848 |
| 3aa3eeb (20-09) | `jqv87m36…-r9-kernel-virt-3aa3eeb` | `028044f52ad7872c8828e1add5cdcdca7eb1bfd4975813849d6c616dc232c247` | 60585720 |
| 1125a20 (20-10, the series kernel) | `j0d1q06rqc36ikf8p312fkqdqdzpyj3b-r9-kernel-virt-1125a20` | `3e86d2f12a7fe0df6640b75726abd0232fba99576ac3336fcbeea52fc88955c6` | 60598080 |

- **x86_64 kernel bytes do not change.** `27f38a3..1125a20` touches `aarch64/`, `xtask/src/main.rs` and the workspace `Cargo.toml` `check-cfg` list, and nothing under `x86_64/` or `port/src`. 20-09 measured the x86_64 `q35churnshell` ELF as byte-identical across `27f38a3..3aa3eeb` (`b7a1e00b…`), and `3aa3eeb..1125a20` touches only `aarch64/src/{exec,proc}.rs`. So the boot-iso `outputHash` needs no re-derivation, and no x64 TCG gate run is owed.

### Series at r9 1125a20 (20-09 and 20-10 together)

This is one series in the 20-06 shape. It covers both of the r9 changes since the pin: 20-09's `ff1b155` and `3aa3eeb` (the churn gate, the `exec_prologue` split, and the code shifts that moved the aarch64 kernel bytes), and 20-10's `1125a20` (the close-on-exec sweep). It used `R9_OVERRIDE='git+file:///Users/neilskinner/code/r9?rev=1125a205ef6c2f8f8271d47f89d58a4434f2a307'` and `R9_STOP_ON_FAIL=1`. Harvey was at `61ad20f43`, with no Harvey commit until the series ended. It ran from 2026-11-20T01:28:39Z to 05:50:32Z, about 4 h 22 min, as the same block as 20-06 and 20-08. Run 1 rebuilt the userland, and every later block set `R9_SKIP_BUILD=1`.

```
SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3710
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2556
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=1113
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024
```

- **1808 of 1808 runs were green**, with 21640 forks and no `pushword` line. `R9_STOP_ON_FAIL=1` never fired.
- **Every block booted the tested kernel,** `/nix/store/j0d1q06rqc36ikf8p312fkqdqdzpyj3b-r9-kernel-virt-1125a20`, the one the tier-1 runs above booted. No capture in any block has a `Not registered`, `user fault`, `unresolvable` or `pushword but no argv` line.
- **The tier-1 blocks carry the cexecprobe and brkprobe entries:** 371 forks per run, against 365 at 20-08.
- **The kernel is reproducible.** `nix build --rebuild` of `hx6ldfbblyd14dqg552kvvb365naclap-r9-kernel-virt-1125a20.drv` exits 0 with no `may not be deterministic`.
- **Logs:** the series log is `.build/p20-10-series-1125a20.log`, and the per-run captures are under `.build/hvf-series/boot-r9-*-20261119T20[234]*`.

**For the pin.** A pin carrying `1125a20` would boot an aarch64 kernel whose bytes differ from the pin's (`3e86d2f1…` against `92cc905b…`). This series covers those bytes. The x86_64 kernel bytes do not change across `27f38a3..1125a20` (see `### Kernel bytes at r9 1125a20`), so the boot-iso `outputHash` stays and no x64 gate is owed. The steps that remain are the owner's: push r9 (`ff1b155`, `3aa3eeb`, `1125a20`), then a lock-only Harvey pin move, `27f38a3` -> `1125a20` or whatever rev the push produces. The default gate is red until then (`T1-FAIL cexecprobe` at `27f38a3`).

### Pin move to r9 1125a20 (owner: pin-1125a20)

The owner chose `pin-1125a20`, and the coordinator pushed r9, so `origin/main` is now `1125a205ef6c2f8f8271d47f89d58a4434f2a307`. `nix flake update r9` moved `flake.lock` from `github:requaos/r9/27f38a3` to `github:requaos/r9/1125a20`. Only the `r9` node changed, and the locked rev equals r9 `origin/main`.

The default gate at the new pin (`R9_ACCEL=hvf nix run .#boot-r9-tier1`, no override, full build) passes: `exit=0 cexec=1 brk=1 fail=0 okall=41 skip=23`, `ALL STAGES PASS`. It booted `/nix/store/j0d1q06rqc36ikf8p312fkqdqdzpyj3b-r9-kernel-virt-1125a20`, the same store path as the series kernel. So the pinned kernel is byte-identical to the one the 1808-run series tested. Capture: `.build/p20-10-tier1-pin1125-hvf.{out,log}`.

## Group B at the pin

Plan 20-11. It started on 2026-11-20 shortly before 12:51Z with Harvey HEAD at `699f3dcf9` and r9 `origin/main` at `1125a20`, the current pin. A separate debugger session is working on the r9 `create(..., OCEXEC)` defect (`.planning/debug/create-ocexec-not-marked.md`) at the same time. At this point it has made no r9 commit.

### CI lane (Task 1)

r9 `7d464ad` `ci(20-11): build aarch64 virtchurn in CI` adds the job `build-aarch64-virtchurn` to `.github/workflows/xtask.yml`, in the shape of `build-aarch64-virtshell`, running `cargo xtask build --arch aarch64 --config virtchurn --verbose`. Of the aarch64 configs, only `config_virtchurn.toml` carries `dev_churn`. Without this lane, no CI job compiles the 20-09 churn driver. The commit touches only that file (12 insertions).

### r9 local battery (Task 1)

r9 `main` is at `7d464ad`, and the tracked tree is clean. After `git fetch origin`, `git log --oneline origin/main..HEAD` lists one commit, this plan's own:

```
7d464ad ci(20-11): build aarch64 virtchurn in CI
```

Group B's r9 kernel work (20-08 `27f38a3` and before, 20-09 `ff1b155` and `3aa3eeb`, 20-10 `1125a20`) is already on `origin/main`, pushed by the coordinator at the 20-10 pin move.

The battery ran in a clean clone of `7d464ad`, so it could not pick up uncommitted debugger work in `/Users/neilskinner/code/r9`. It ran inside `nix develop` (rustc 1.95.0-nightly 842bd5be2, QEMU 11.1.2). Each step's exit code:

| Step | Exit |
|------|------|
| `cargo xtask check` | 0 |
| `cargo xtask clippy` | 0 |
| `cargo xtask test` | 0 (12 `test result: ok.` lines, no `FAILED`) |
| `cargo xtask build --arch aarch64 --config virtshell` | 0 |
| `cargo xtask build --arch aarch64 --config virtchurn` | 0 |
| `cargo xtask build --arch aarch64` (raspi3b default) | 0 |
| `cargo xtask build --arch x86-64` | 0 |
| `cargo xtask build --arch riscv64` | 0 |
| `R9_HARVEY_DIR=/Users/neilskinner/code/harvey cargo xtask ureg-check` | 0 (35 fields match `arm64/include/ureg.h`, 26 match `amd64/include/ureg.h`, negative control fired) |
| `R9_HARVEY_DIR=… cargo xtask boot-test --arch aarch64 --config virtchurn` (TCG) | 0: `steady=482 measured=168 <= ceiling=1772 bytes/exec`, 1400 exec iterations, 1361 churnmark prints, 39 RFMEM generations |

The first virtchurn attempt hung, and the hang came from the venue, not the kernel. The clone sat at a 145-byte path, and the console socket path (`<clone>/target/boot-test-virtchurn.sock`) was over the 104-byte macOS `sun_path` limit. qemu, holding the socket with `wait=on`, never got a client: it and xtask sat at 0% CPU for about 59 minutes. I killed them and re-ran from a short-path clone (`.build/r9-battery`, since removed), which passed in 31 s. The 168 B/exec reading is 13 B above 20-10's post-fix maximum (146, 154, 155), inside the 18 B pre-fix spread, and at 9% of the ceiling. Logs: `.build/p20-11-battery/` and `.build/p20-11-virtchurn.out`.

`git diff --stat origin/main..HEAD -- port/src` is **empty**. Across all of group B, `git diff --stat 57e2952..7d464ad -- port/src` is also empty. Group B's x86_64 changes are `f8c2ac9` (bare `rfork(RFCFDG)`) and `7b598f2` (`sem_deregister_waiter`). The boot-iso hash bump in `27f38a3` (`3a1c9e5..7b598f2`) covers both. Nothing under `x86_64/` changes in `27f38a3..7d464ad`. `7d464ad` changes no kernel byte on any arch.

PORT-SRC-EDIT: no

### r9 push (owner: option 3)

At the Task 1 checkpoint the owner chose option 3: push r9 now, and do not move the pin until the debugger's OCEXEC fix lands. Then one battery, one lock-only pin move and one combined series cover both. The coordinator pushed `7d464ad`. After `git fetch origin`, `origin/main` equals local `main`, and the plan's verify printed `PUSHED-CLEAN`.

R9-PUSHED: 7d464ad0824c8e5fb92566a8b210862e9aabc9fe

The pin stays at `1125a20` for now. `7d464ad` is CI-only, so the pinned kernel is byte-identical to the r9 `origin/main` kernel on every arch. Harvey `a71a45b8c` stays local.

### r9 42203d8: the create(OCEXEC) fix (battery and the cexeccreate pin)

The debugger session (`.planning/debug/create-ocexec-not-marked.md`) landed two commits on r9 `origin/main`, which the coordinator reported as `42203d8`:

```
42203d8 bump boot-iso hash for the create(OCEXEC) kernel change
437b752 fix: create(OCEXEC) marks the new chan close-on-exec on both arches
```

`git diff --stat 7d464ad..42203d8` touches `aarch64/src/syscall.rs`, `x86_64/src/syscall.rs`, `x86_64/src/exec.rs` and `flake.nix`. The only `flake.nix` change is the boot-iso `outputHash`, from `sha256-Dk1zd/JQVH7PtNXrwUD+Yi3To3h1dZWIprofEutR6Yk=` to `sha256-L8Sm1tGU6KOyb3+XkzddGeqKe993L/akNm5xaqLjmV8=`. `port/src` is **empty** again (`PORT-SRC-EDIT: no` stands). The x86_64 diff is exactly `437b752`'s. The debugger ran the x64 TCG gates green in an amd64 container, so no x64 gate is owed here.

**Battery at `42203d8`** (a clean short-path clone, `.build/r9-b42`, since removed; the same steps and toolchain as the `7d464ad` battery):

- check, clippy, test, and the virtshell, virtchurn, aarch64-default, x86-64 and riscv64 builds all exit 0. `test` has 12 `ok.` results and no `FAILED`.
- ureg-check exits 0 (35 and 26 fields match, negative control fired).
- The virtchurn boot-test exits 0 with `steady=482 measured=143 <= ceiling=1772` bytes/exec.
- Logs: `.build/p20-11-battery-42203d8/`.

**aarch64 kernel at `42203d8`:** `/nix/store/sw5pfm8m3i83dqw4kxcp80452z39h1ii-r9-kernel-virt-42203d8`, `kernel-virt.elf` sha256 `d8be7228d31cc5d398d530a09196662402170bcec8dc12aa80bbbbec4bd57cb4`. This matches the coordinator's report.

**The new gate entry (owner decision).** Harvey `68119abf8` adds `T1-OK cexeccreate` to the r9-venue block of `build/aarch64/tier1-sweep.rc`. It runs `/bin/cexecprobe -c`, the create leg from `3592699f0`. That leg self-execs as `/bin/cexecprobe -C <fd> <fd> <fd>`, with every argument far under exec's 128-byte cap. `nix/tier1-r9.sh` adds `cexeccreate` to the fixed expected names, so the computed expected OK set goes from 41 to 42. Like the other probes, the entry sits inside `if(~ $venue r9){…}`, so the donor and 9k venues do not run it.

**TCG, red at the pin and green at the fix.** Harvey was at `68119abf8` for both runs, and both used the same freshly built userland:

| Kernel | Invocation | Exit | Result |
|---|---|---|---|
| r9 `42203d8` (`sw5pfm8m…`) | `R9_ACCEL=tcg nix run .#boot-r9-tier1 --no-write-lock-file --override-input r9 'git+file:///Users/neilskinner/code/r9?rev=42203d8…'` (full build) | 0 | `expected on r9: 42 T1-OK markers + 23 T1-SKIP markers`; 42 distinct OK, 23 SKIP, 0 FAIL; `cexecprobe: ok`, `cexecprobe: create ok`; `ALL STAGES PASS` |
| the pin r9 `1125a20` (`j0d1q06r…`) | `R9_SKIP_BUILD=1 R9_ACCEL=tcg nix run .#boot-r9-tier1 --no-write-lock-file` (no override) | 1 | `cexecprobe: ok`, then `cexecprobe: LEAK create fd=3`, `T1-FAIL cexeccreate`, `post-pass FAILED — missing T1-OK cexeccreate`; 41 distinct OK |

- The pin bites. `1125a20` leaks the fd made by the new-file create arm, and `42203d8` closes it. The open leg (`T1-OK cexecprobe`) stays green on both.
- Captures: `.build/p20-11-cc-{42203d8,1125a20}-tcg.{out,log}`.
- From `68119abf8` until the pin moves past `437b752`, the default `nix run .#boot-r9-tier1` at the pin is red on `cexeccreate`. This is the same situation as cexecprobe at 20-10.

**Forks per tier-1 boot.** Both captures count 373 `process N exited` lines, 2 more than 371 at `1125a20` without the entry. Excluding forkstress's 200 (`STRESSOR-RATE: not-fired`) leaves 173 ordinary forks. That gives ceil(2.99573 / (173 × 0.00576818)) = ceil(3.002) = 4, so the floor of 10 holds, as a preview. The formal `N-HVF boot-r9-tier1` restatement comes from the series' first capture at the pin.

The combined HVF series is held. The owner also ordered an ORCLOSE fix, which changes kernel bytes on both arches. The final r9 rev, the lock-only pin move and the one combined series follow it.

### ORCLOSE fix: port/src edit pre-approved (owner, relayed by the coordinator)

The owner approved the ORCLOSE fix as a `port/src` change: ORCLOSE plus shared device-remove routing in port. It is in progress in a debugger session. It may add an `rcloseprobe` tier-1 marker. So the final rev's `git diff --stat 7d464ad..<final> -- port/src` will not be empty. Being owner-approved, that is not a stop for the battery.

**THIS CHANGES THE PUSH RULE FOR GROUP B.** Once the final rev carries a `port/src` edit, `PORT-SRC-EDIT: no` above no longer holds for the pin. Under the 20-06 hold, Harvey `master` is not pushed after the series (`HARVEY-PUSH: pending-fod`). Nothing further builds on the pin until the owner's linux-host `nix build .#boot-iso` pass in Task 3.

### Linux boot-iso check at r9 42203d8 (owner, relayed by the coordinator)

On the linux host, the owner ran `nix build .#boot-iso` at r9 `42203d8`, the OCEXEC fix with `outputHash = "sha256-L8Sm1tGU6KOyb3+XkzddGeqKe993L/akNm5xaqLjmV8="`. It completed with no hash mismatch.

BOOT-ISO-LINUX 42203d8: pass (no mismatch)

This covers `42203d8` only. The ORCLOSE fix changes the x86_64 kernel bytes again, so a fresh linux-host boot-iso check is owed at the final rev before the Harvey push (Task 3 item 3).

### Donor gate (Task 2 step 3)

`nix develop -c sh -c 'sh build/aarch64/subset-exec.sh >.build/p20-11-subset.out 2>&1; …'` ran at Harvey `699f3dcf9` from 2026-11-20T12:51:50Z to 12:52:36Z. No re-provision was needed:

```
subset-exec exit=0 done=1 r9only=0
```

- The script reported `== expected T1-OK marker set (computed from tier1-cmds.txt): 56 members + float-d01 + libtest ×2 + selfhost ×2`, then `== PASS: the tier-1 set executed on the 9front donor kernel (T1-DONE; float canary 0.333 green)`.
- The capture `.build/9front-dist/subset-exec.log` has 61 distinct `T1-OK` names, 0 `T1-SKIP`, 0 `T1-FAIL`, one `T1-DONE` and no `panic`/`trap:` line.
- No line in either the capture or `.build/p20-11-subset.out` mentions `forkstress`, `writeprobe`, `cexecprobe` or `brkprobe`. Group B's entries in the shared `tier1-sweep.rc` stay inside the r9-venue guard.
- The expected set is the same as at 20-05.

DONOR-GATE: pass 61 members

(This first donor run predates the `cexeccreate` and `rcloseprobe` sweep entries. It was re-run at the final Harvey HEAD; see `### Donor gate at the final sweep` below.)

### r9 fa38402: the ORCLOSE fix (battery and the rcloseprobe pin)

The coordinator reported the final rev as r9 `fa38402`, on `origin/main`. It sits two commits above `42203d8`:

```
fa38402 bump boot-iso hash for the ORCLOSE kernel change
5629cf0 fix: ORCLOSE removes local files at the last close, through one shared remove dispatch
```

`fa38402` changes only `flake.nix`: the boot-iso `outputHash` goes from `sha256-L8Sm1tGU…` to `sha256-4vLm2Qsoq87i1cWN9Ief/9LCT2WlKibHnqlZzTKhjGk=`. `5629cf0` touches `aarch64/src/syscall.rs`, `x86_64/src/syscall.rs` and five `port/src` files. In `7d464ad..fa38402`, the x86_64 changes are exactly the debugger's `437b752` and `5629cf0`. The debugger ran the x64 TCG gates and the x86_64 host tests green in a container, so no x64 re-run is owed here.

**PORT/SRC IS NOT EMPTY AT THE PIN (OWNER-APPROVED: ORCLOSE PLUS THE SHARED REMOVE DISPATCH).** `git diff --stat 7d464ad..fa38402 -- port/src`:

```
 port/src/dat.rs         | 20 ++++++++++++++-
 port/src/devenv.rs      | 27 ++++++++++++++++++++
 port/src/devsrv.rs      | 28 +++++++++++++++++++++
 port/src/namec.rs       | 66 ++++++++++++++++++++++++++++++++++++++++++++-----
 port/src/namec_tests.rs | 66 +++++++++++++++++++++++++++++++++++++++++++++++++
 5 files changed, 200 insertions(+), 7 deletions(-)
```

PORT-SRC-EDIT: YES (r9 5629cf0, owner-approved)

**Battery at `fa38402`** (a clean short-path clone, `.build/r9-bfa`, since removed; the same steps and toolchain as before):

- check, clippy, test, and the virtshell, virtchurn, aarch64-default, x86-64 and riscv64 builds all exit 0. `test` has 12 `ok.` results and no `FAILED`. The port lib tests go from 165 to 168 passed, the new `namec_tests`.
- ureg-check exits 0.
- The virtchurn boot-test exits 0 with `steady=482 measured=158 <= ceiling=1772` bytes/exec.
- Logs: `.build/p20-11-battery-fa38402/`.

**aarch64 kernel at `fa38402`:** `/nix/store/y1gq491ka27sslgzgkhl8rs9s6v32s5m-r9-kernel-virt-fa38402`, `kernel-virt.elf` sha256 `bd0d969651a6c7287940087d5e12fb5be88c8284704455f9010d85b583b18f81`. This matches the coordinator's report. `nix build --rebuild` of `1z4xf234…-r9-kernel-virt-fa38402.drv` exits 0 with no `may not be deterministic` line.

**The gate entry.** The debugger's Harvey `1e6d8e79f` builds `build/aarch64/rcloseprobe.c` (subset-build.sh) and bakes it as `/arm64/bin/rcloseprobe` (mkimage.sh), but did not wire it into the sweep. Harvey `6fa102769` adds `T1-OK rcloseprobe` to the r9-venue block of `tier1-sweep.rc`, beside cexecprobe and cexeccreate, and adds `rcloseprobe` to the fixed expected names in `nix/tier1-r9.sh`. The computed expected OK set goes from 42 to 43.

**TCG, red at the pin and green at the fix.** Harvey was at `6fa102769`. The green run did a full userland build, which rebuilt `rcloseprobe`. The red run reused that userland.

| Kernel | Invocation | Exit | Result |
|---|---|---|---|
| r9 `fa38402` (`y1gq491k…`) | `R9_ACCEL=tcg nix run .#boot-r9-tier1 --no-write-lock-file --override-input r9 'git+file:///Users/neilskinner/code/r9?rev=fa38402…'` | 0 | `expected on r9: 43 T1-OK markers + 23 T1-SKIP markers`; 43 distinct OK, 23 SKIP, 0 FAIL, 376 forks; `cexecprobe: ok`, `cexecprobe: create ok`, `rcloseprobe: ok`; `ALL STAGES PASS` |
| the pin r9 `1125a20` (`j0d1q06r…`) | `R9_SKIP_BUILD=1 R9_ACCEL=tcg nix run .#boot-r9-tier1 --no-write-lock-file` (no override) | 1 | `cexecprobe: LEAK create fd=3`, and `rcloseprobe: LEAK` on every leg (`srv`, `dup`, `exit`, `env`, `env-open`); `T1-FAIL cexeccreate`, `T1-FAIL rcloseprobe`; `post-pass FAILED — missing T1-OK cexeccreate`; 41 distinct OK |

Captures: `.build/p20-11-rc-{fa38402,1125a20}-tcg.{out,log}`.

### The pin

Harvey `c7cd176d2` `chore(20-11): advance the r9 pin 1125a20 -> fa38402 lock-only (arm64 syscall-path parity + churn gate)`. Running `nix flake update r9` changed only the `r9` node's `lastModified`, `narHash` and `rev` (6 changed lines). The locked rev `fa38402ec3c9e18817b4d5c9c8b9052794dc2bab` equals r9 `origin/main`. `git show --name-only` on the pin commit prints exactly `flake.lock`.

The pin move covers `7d464ad` (CI), `437b752` with `42203d8` (create(OCEXEC)), and `5629cf0` with `fa38402` (ORCLOSE).

PIN: r9 fa38402ec3c9e18817b4d5c9c8b9052794dc2bab (Harvey c7cd176d2)

### N for this series

`N-SOURCE: lower-bound` (the `## N derivation` lines) and `STRESSOR-RATE: not-fired` are in force, so forkstress's 200 forks do not count. Run 1 of the tier-1 HVF block at the pin made 376 forks: 371 at 20-10, plus 2 for `cexecprobe -c`, plus 3 for `rcloseprobe`. The ordinary gate therefore makes 376 - 200 = **176** forks per boot. N = max(10, ceil(ln(0.05) / (176 × ln(1 - 0.00575157)))) = max(10, ceil(2.99573 / (176 × 0.00576818))) = max(10, ceil(2.99573 / 1.01520)) = max(10, ceil(2.951)) = max(10, 3) = **10**. The floor decides, as at 20-06. Smoke (8 forks per boot) and net-smoke (71) are unchanged, so their N lines stand at 1753 and 36.

N-HVF boot-r9-tier1 = 10

### Series at the pin (no override)

The block ran from 2026-11-20T18:39:32Z to 23:16:58Z (about 4 h 37 min), with `R9_OVERRIDE` unset and `R9_STOP_ON_FAIL=1`. Run 1 of tier-1 HVF rebuilt the userland at the pin, and every later block set `R9_SKIP_BUILD=1`. The order was the 20-10 block's. `KERNDATE` was exported as the pin commit's time (`1795199925`), so a commit by a concurrent session could not move it. Harvey HEAD was `c7cd176d2` at both `SERIES-START` and `SERIES-END`.

```
SERIES boot-r9-tier1 accel=hvf runs=10 pass=10 fail=0 pushword=0 forks=3760
SERIES boot-r9-net-smoke accel=hvf runs=36 pass=36 fail=0 pushword=0 forks=2556
SERIES boot-r9-tier1 accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=1128
SERIES boot-r9-net-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=213
SERIES boot-r9-smoke accel=tcg runs=3 pass=3 fail=0 pushword=0 forks=24
SERIES boot-r9-smoke accel=hvf runs=1753 pass=1753 fail=0 pushword=0 forks=14024
```

- **1808 of 1808 runs were green.** No `pushword` line appeared, and `R9_STOP_ON_FAIL=1` never fired.
- **Every block booted the pinned kernel,** `/nix/store/y1gq491ka27sslgzgkhl8rs9s6v32s5m-r9-kernel-virt-fa38402`, in every `run-*.out`. No `run-*.out` mentions `override`. No capture in any block has a `pushword but no argv`, `Not registered`, `user fault`, `unresolvable` or `panic` line.
- **Every tier-1 run had 376 forks; every net-smoke HVF run had 71.**
- **HVF gate forks, forkstress excluded:** 10 × 176 + 2556 + 14024 = 18340, with 0 fires. That is at least `FORKS-TARGET = 520`. The WINDOWS #49 residual note from 20-06 still applies: this series is green at the plan's N and does not separate the isb-only residual rate.
- **The last tier-1 capture** (TCG run 3, `boot-r9-tier1-tcg-20261120T135024/run-3.log`) has `T1-OK forkstress` 1, `T1-OK writeprobe` 1, `T1-OK cexecprobe` 1, `T1-OK cexeccreate` 1, `T1-OK rcloseprobe` 1, `T1-OK brkprobe` 1, `T1-FAIL` 0, 43 distinct OK and 23 SKIP. The last HVF tier-1 capture (`boot-r9-tier1-hvf-20261120T133932/run-10.log`) has the same counts.
- **Logs:** the series log is `.build/p20-11-series-fa38402.log`, and the per-run captures are under `.build/hvf-series/boot-r9-*-20261120T13{3,4,5}*`.

### Donor gate at the final sweep

The first donor run (above) was at `699f3dcf9`, before `68119abf8` and `6fa102769` edited the shared sweep. It was re-run at the pin commit `c7cd176d2` from 2026-11-20T23:21:26Z to 23:22:12Z: `nix develop -c sh -c 'sh build/aarch64/subset-exec.sh >.build/p20-11-subset-final.out 2>&1; …'`.

```
subset-exec exit=0 done=1 r9only=0
```

- The result is again `56 members + float-d01 + libtest ×2 + selfhost ×2` and `== PASS`.
- The capture has 61 distinct `T1-OK`, 0 `T1-SKIP`, 0 `T1-FAIL`, one `T1-DONE`, and no `panic`/`trap:` line.
- No line mentions `forkstress`, `writeprobe`, `cexecprobe`, `cexeccreate`, `rcloseprobe` or `brkprobe`, in either the capture or the `.out`.

DONOR-GATE: pass 61 members

### Linux boot-iso check at r9 fa38402 (owner, relayed by the coordinator)

On the linux host, the owner ran `nix build .#boot-iso --rebuild` at r9 `fa38402` (`outputHash = "sha256-4vLm2Qsoq87i1cWN9Ief/9LCT2WlKibHnqlZzTKhjGk="`). It passed with no mismatch. This is the FOD pass the `port/src` hold waits for, so the `pending-fod` hold on the Harvey push is cleared. The push itself still waits for the owner's approval at the Task 3 checkpoint.

BOOT-ISO-LINUX fa38402: pass

### Harvey push (owner: approve push)

The owner approved the push at the Task 3 checkpoint. Before it, `git log origin/master..master` held exactly the 16 commits the checkpoint listed, `699f3dcf9..34941cc0a`: 9 from this plan and 7 from the debugger sessions (`3592699f0`, `dd7a2069f`, `aa9517288`, `291849414`, `1e6d8e79f`, `19c8ab8ac`, `4528f2d6a`). The checkpoint's "11 and 5" split was a miscount; the commit list itself was right. `git push origin master` (no force) printed `699f3dcf9..34941cc0a  master -> master`. After `git fetch origin`, `origin/master` equals `HEAD` (`34941cc0ace0a6e0c378d49ae006856627ee38a4`), and the plan's check printed `HARVEY-PUSHED`. The 11 pre-existing font/postscript modifications stayed unstaged.

HARVEY-PUSH: done

### Owner checks (Task 3)

The coordinator verified these through `gh` and relayed them as the owner's "approved".

- **r9 xtask at `fa38402`:** all 8 jobs pass: `lint`, `tests`, `build-aarch64`, `build-aarch64-virtshell`, `build-aarch64-virtchurn` (the new lane), `build-x86_64`, `build-riscv64`, `boot-test-x86-64`.
- **Harvey at `34941cc0a`:**
  - r9-shell (run 44846197796): `boot-smoke`, `net-smoke`, `auth-smoke-x64`, `net-smoke-x64` pass.
  - phase6-userspace (run 44846197787): `tier-2`, `x86_64-poolpanic`, `tier-r9`, `tier-9k`, `wave0-host` pass.
  - harvey (run 44846197768): passes.
- **The tier-9k capture** (the CI-only Harvey-kernel venue that copies the shared `tier1-sweep.rc`): `T1-VENUE-PASS ok=36 skip=22+2libtest fail=0 done=yes svc=9/0 … verdict=PASS`. It has 0 lines matching any of the six r9-only markers (forkstress, writeprobe, cexecprobe, cexeccreate, rcloseprobe, brkprobe), and 0 parse or syntax errors.
- **Linux boot-iso at `fa38402`:** pass (above).
- **Churn:** 20-09 found the leak present on aarch64 (A5 holds: 16805 B/exec on the drain-free exit path at `b82ee9d`). So the gate catches a real defect, and no regression-pin-only acceptance was needed.

OWNER-CHECKS: approved

## Group C measurements

Plan 20-12 (D-09). r9 at `fa38402` (= the Harvey pin = r9 `origin/main`); pre-phase base `8e4e730`. Host darwin-arm64. Toolchain: r9's default devShell (`nix develop` in `/Users/neilskinner/code/r9`), `rustc 1.95.0-nightly (842bd5be2 2026-01-29)`, host triple `aarch64-apple-darwin`, std present for that triple in the sysroot, no `rustup` on PATH. The base worktree's own devShell does not evaluate on darwin (`grub-2.14 ... not available on the requested hostPlatform`, the research Pitfall 4 failure, fixed after `8e4e730`), so the base runs used the HEAD devShell with `cd` into the worktree. `rust-toolchain.toml` is identical at both revs, so the compiler is the same.

### Host-test compilability (Task 1)

**Step 1: `cfg(test)` sites under `aarch64/src` at `fa38402`** (`grep -rc 'cfg(test)' aarch64/src`): vm.rs 4, proc.rs 4, vmdebug.rs 3, registers.rs 2, syscall.rs 1, allocator.rs 1 (a comment), platform/virt/churngate.rs 1. Test modules: `vm::tests`, `registers::tests`, `proc::{rfmem_tests, sem_tests, fdgrp_release_tests, husk_sweep_tests}`, `vmdebug::tests`, `syscall::create_cexec_tests` (the 20-11 debugger's create(OCEXEC)/ORCLOSE pins; the planner's "syscall.rs 0" predates it), `platform::virt::churngate::tests`. The research record "aarch64 has none" was already wrong at `8e4e730` (18 host tests there).

**Step 2: `cargo xtask test --verbose`** exit 0. It executes exactly one command, `cargo test --package port --lib --tests` (port lib 168 passed, then the port integration files). No `--package aarch64 --bins` leg is executed. Why: `RustupState::new()` shells out to `rustup target list --installed`, which fails (no rustup in the nix devShell), so `installed_targets` is empty and `std_supported_target("aarch64")` returns `None`. Under rustup it would also need the current toolchain name to end in `aarch64-apple-darwin` (or an `aarch64-unknown-linux-gnu` target installed); the aarch64 leg is skipped on this host as the code stands.

**Step 3 and 4: the leg run directly.**

| Rev | Command | Compile | Tests | Pass |
|---|---|---|---|---|
| `fa38402` | `cargo test --package aarch64 --bins --target aarch64-apple-darwin` (default cfg) | ok (4 unused-import warnings) | 32 | 32 |
| `fa38402` | same with `RUSTFLAGS='--cfg platform="virt" --cfg dev_exec --cfg dev_bootchain --cfg dev_ether --cfg dev_ip'` (virtshell cfg, the set `apply_platform_config` derives from `config_virtshell.toml`) | **fails**, 4 errors | — | — |
| `8e4e730` | default cfg | ok | 18 | 18 |
| `8e4e730` | virtshell cfg | **fails**, 6 errors | — | — |

The HEAD virtshell failure, first lines (all four errors are the same shape, at main.rs:153, 238, 697, 698):

```
error[E0659]: `devcons` is ambiguous
   --> aarch64/src/main.rs:153:15
    |
153 |     platform::devcons::set_dtb_va(dtb_va);
    |               ^^^^^^^ ambiguous name
    |
    = note: ambiguous because of multiple glob imports of a name in the same module
note: `devcons` could refer to the module imported here
   --> aarch64/src/platform/mod.rs:12:9
    |
 12 | pub use crate::platform::virt::*;
note: `devcons` could also refer to the module imported here
   --> aarch64/src/platform/mod.rs:22:9
    |
 22 | pub use crate::platform::raspi3b::*;
error: could not compile `aarch64` (bin "aarch64" test) due to 4 previous errors; 4 warnings emitted
```

Classification: **other** (not asm/target-feature, not linker, not `no_main`, not a missing std item). It is a glob-import collision in `aarch64/src/platform/mod.rs`: the `pub use crate::platform::raspi3b::*` line is gated `any(test, platform = "raspi3b", not(any(platform = "virt", platform = "raspi4b")))`, so under `cfg(test)` it is glob-imported beside `virt::*` even when `platform = "virt"`, and `devcons` exists in both. The base has the same four E0659 errors plus the two research compile-drift errors (`missing field note_pending in initializer of PipeHooks` / `DevipHooks`) that group A fixed.

**Step 4a: base control.** Default cfg compiles and passes at both revs; virtshell cfg fails to compile at both revs, with the same E0659 collision. Plans 01-11 introduced no host-test break (they removed two compile errors and added 14 host tests).

HOST-TEST-BASE: same

**Step 5: scratch probes (reverted).** A `#[cfg(test)]` module was appended to `aarch64/src/exec.rs` (`assert!(super::parse_aout(&[0u8; 4]).is_err())`) and one to `aarch64/src/syscall.rs` (`crate::proc::new_user_proc("t1").expect(..)`, the x86_64 `MockStack::new` first line).

| Cfg | exec.rs scratch test | syscall.rs scratch test |
|---|---|---|
| default | compiled, discovered (`--list`: 34 tests), **passes** | compiled, discovered, **fails at run time**: `error:pagealloc:allocate_physpage:failed to allocate: OutOfSpace`, then the panic `construction succeeds: "proc: root table page alloc failed"` |
| virtshell (unmodified tree) | not compiled (the E0659 collision) | not compiled |
| virtshell + a one-line scratch edit to `platform/mod.rs` (the raspi3b glob gated `all(test, not(platform = "virt"))` instead of `test`) | compiled, **passes**; the run is 38 passed / 0 failed (the default 32, the exec scratch test, and the 5 `platform::virt::churngate::tests`) | compiled, **fails** with the same `OutOfSpace` |

Then `git checkout -- aarch64/src`; `git status --porcelain` printed nothing. `git worktree remove --force "$TMPDIR/r9-p20-12-base"`; `git worktree list` shows one worktree.

**`new_user_proc` is not host-runnable on aarch64.** It allocates the root page table from `pagealloc` and maps it in the kernel page table; on the host `pagealloc` has no memory (`OutOfSpace`). The x86_64 one is host-runnable (its `MockStack` tests build on it). So the syscall-level `MockStack` pins do not port as-is in any route: they need either a host seam in `new_user_proc` or a test-only `Proc` constructor.

HOST-TEST-ROUTE: B

Decided by steps 3, 4 and 5 on the tree as it stands: crate tests run on the host at the default cfg (32/32), and with the virtshell cfg the crate does not compile (step 4), so `dev_exec`-gated code cannot be tested on the host today. Consequence as planned for B: the pure functions are gated `#[cfg(any(test, dev_exec))]` in modules that build at the default cfg and are pinned there; the `MockStack`-dependent pins are not ported (and step 5 shows they would not run anyway: `new_user_proc` is not host-runnable).

Finding for Task 3 (not a route input on its own): route A is one aarch64-only line away. The only obstacle to the virtshell cfg is the `platform/mod.rs` glob gate; with it narrowed (scratch, reverted) the crate compiled and ran 38/38 with `dev_exec` set, and a test inside `exec.rs` passed. Adopting A would mean 20-17 makes that one-line fix, passes the cfg from `cargo xtask test`, and still drops or re-seams the `MockStack` pins. Either way no `port/src/` edit is needed for the host-test battery.

PROFILE-FACT: kernel-virt builds --config virtshell

From r9 `flake.nix` line 437 (`kernel-virt` derivation, buildPhase: `cargo xtask build --arch aarch64 --config virtshell`; installs `kernel-virt.elf`). Other users of the config name: r9 CI job `build-aarch64-virtshell` (`.github/workflows/xtask.yml:50-56`) and a comment at `flake.nix:327`. No other r9 derivation builds it. Harvey never names the config: its four arm64 apps `boot-r9`, `boot-r9-smoke`, `boot-r9-net-smoke` and `boot-r9-tier1` (`flake.nix:473-476`) all export `R9_KERNEL_PKG=${r9.packages.${system}.kernel-virt}`, so a change to `config_virtshell.toml` changes the kernel under all four.
