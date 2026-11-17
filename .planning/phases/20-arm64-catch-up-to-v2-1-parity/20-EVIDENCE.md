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

**Against the point-estimate hypothesis** (36 smoke boots, 5 tier-1 sweeps, from research's 13 boots at about 0.0084 per fork). The pooled point estimate here, 0.0093, is close to that figure. The N above is still larger, for two reasons:

- It uses the lower bound (0.00575), not the point estimate. A still-broken kernel failing at the lowest rate the data allow is the hardest to catch, and a lower rate needs a longer series.
- It takes the per-boot form where it binds. Tier-1 rises from 5 to 10 only because of the floor; the bound alone asks for 5. Smoke rises from 36 to 1753 because the smoke gate itself fired once in 30 boots, and the exact lower bound of that rate is 0.0017 per boot.

Net-smoke stays at its floor of 36.
