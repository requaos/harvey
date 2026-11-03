# build/aarch64 — the aarch64 donor-kernel harness

Everything in this directory is the **temporary bridge** harness: the
goal is Harvey userspace on the r9 kernel, so the 9front donor tooling
here exists to prove the vendored aarch64 toolchain (7a/7c/7l), libc
asm, and the frozen syscall ABI against a *reference* kernel before
any arch scaffolding lands in the committed tree. When r9 speaks
enough 9P and SVC, this harness retires.

## The 9front donor pin (D-10)

- Donor: https://github.com/9front/9front, branch `front`
- Pin SHA: `350266104f1fed81c78c3d05fa44f523bec0ae4d` (pinned 2026-10-31)
- Cloned to the gitignored `.build/9front-donor/` (host) and rsync'd to
  the guest's `~/9front-donor` — the donor kernel and tree **never**
  enter Harvey's tracked tree (D-07/D-12); `.build/` is gitignored.
- One-shot import per D-10: there is **no repeatable import script** —
  the bridge does not warrant machinery. The permanent vendored set
  (7a/7c/7l, libmach 7-format, libc/aarch64) lives under `sys/src/`
  with per-dir provenance READMEs; this harness README is the pin
  record for the donor-side scaffolding.

## Scripts and their contracts

All scripts run from the repo root inside the nix devshell (which
provides limactl, openssh, rsync, qemu on PATH, plus cargo/rustc and the
`harness` binary (HARNESS_BIN) — quick task 261103-giq).

| Script | Contract |
|--------|----------|
| `vm-run.sh '<cmd>'` | Host-side (darwin) driver: rsync this checkout to the lima guest (`harvey`, dir `harvey-build`), ensure the guest hostbin toolchain, ssh-run `nsrun.sh --wrap '<cmd>'` under the devshell env. Propagates the remote exit status. (Mirror of `nix/vm-build.sh`, command-parameterized.) |
| `nsrun.sh` | Guest-side Plan 9 mount-namespace runner: `--wrap` captures the devshell exports, re-enters as root under `sudo unshare -m`, binds the Harvey tree onto `/sys`, `/amd64`, … (the `sys/src/BUILD_SETUP_NAMESPACE` + `RUN_BUILD_IN_PRIVATE_NAMESPACE` pattern), and runs the caller's command as the repo user. If the guest copy has an `aarch64/` dir it is additionally bound at `/aarch64` — pre-gate that dir exists only in scratch copies; post-gate (plan 02-06) it is committed. Never invoked by hand in its root mode. |
| `pre-gate-build.sh` | The riscv64-vaporware pre-gate (plan 02-03): compiles libc for aarch64 and links `hello.7.out` using the **committed** mkfiles, with the arch scaffolding (`aarch64/mkfile`, `aarch64/include/{u.h,ureg.h}`, `aarch64/lib/`) injected into the **disposable guest copy only**. This is why the committed tree carried no `aarch64/` dir until the execution gate passed — the guest scratch injection is removed by the next rsync `--delete`; the real wiring landed in plan 02-06, which commits the identical files and asserts sha256 equality with the scratch copies. Committed output: `hello.7.out` (the gate binary). **Obsolete post-02-06**: `aarch64/` is now committed, so the script refuses to run (exit 2) — use `objtype=aarch64 mk` in the namespace instead. |
| `donor-vm-build.sh` | Host driver for the D-07 donor kernel build (plan 02-04): pin-verifies `.build/9front-donor`, rsyncs this checkout to guest dir `harvey-build-donor` (**distinct** from vm-run.sh's `harvey-build` — declared guest-state partitioning so same-wave namespace builds race-free), rsyncs the donor checkout separately to guest `~/9front-donor` (plain `-a`, no `--delete`: build outputs live there, keeping reruns incremental), runs `donor-ns-build.sh` in the guest, pulls `.build/9front-dist/` back. Sweeps stale donor objects (`*.7`, `7.*`, `arm64/{lib,bin,init}`) after any toolchain rebuild — mk's freshness graph never names the toolchain binaries. Full transcript: `.build/9front-dist/donor-build.log` (carries the D-07 `command -v 7c` provenance line). |
| `donor-ns-build.sh` | Guest-side in-donor-tree kernel build: self re-entrant (exports capture → `sudo unshare -m` → namespace build). Binds the donor tree into a Plan 9 namespace — `/sys`←donor `sys`, `/arm64`←donor `arm64`, and **`/aarch64`←donor `arm64` as a compatibility alias**: Harvey's vendored 7a/7c/7l carry `thestring=aarch64` (plan 02-01), so their built-in include search `/aarch64/include` and library search `/aarch64/lib` must resolve into the donor's arm64 dirs (the donor keeps its own `arm64` naming internally — the D-11 carve-out). Builds donor host helpers (mkfs, mkpaqfs, data2s, aout2uimage, size, strip) from donor sources, then `mk CONF=qemu` → `9qemu` + `9qemu.u`, then assembles `~/9front-dist`. |
| `boot-9qemu.sh` | Boots the donor kernel to a live rc shell under qemu TCG with captured serial proof (plan 02-04). qemu launches paused (`-S`) with serial on a chardev socket; `harness drive9` attaches the capture **before** the guest runs, resumes via QMP `cont`, answers the bootargs/auth prompts with send-on-match, and proves the `term% ` prompt. Asserts: 9front banner, rc prompt, zero `panic\|trap:` lines. Capture: `.build/9front-dist/boot-9qemu.log`. Idempotent — rerun freely; on a missed banner raise `BOOT_BUDGET` (TCG is slow), never retry silently. Root fs is served over 9P2000/tcp by `harness srv9` via qemu guestfwd (stock `local!paqfs` boot is broken upstream — paqfs has no `-f`). Helpers (subcommands of the std-only Rust `harness` binary, quick task 261103-giq): `harness drive9` (serial driver; `--steps FILE` generalizes the old gatedrive9/subsetdrive9 heredocs), `harness srv9` (read-only 9P server with opt-in `--writable-prefix`), `harness gdbpoke9` (raw-RSP guest-memory poke — wakes GICR0 WAKER), `harness mkfs9` (proto-semantics bootfs builder, host-side substitute for the donor's mkfs, installed as `disk/mkfs` by donor-ns-build.sh). |
| `run-gate.sh` | **The TC-03 execution gate (plan 02-05)**: records sha256 of the committed `hello.7.out`, stages it into the guest's disposable donor tree at `arm64/bin/hello` with one added `CONF=qemu` bootdir line (guest-scratch staging — never committed anywhere), re-runs the guest's `mkrootall`/relink/`aout2uimage` to produce `9qemu-gate.u` with hello embedded in the kernel's embedded root (devroot) as **`/boot/hello`** (devroot's root exposes only `boot/`; the bootfs.paq is unmounted before the shell, so paq-baked binaries are gone at the rc prompt — mkpaqfs is not re-run), boots it with exactly boot-9qemu.sh's qemu invocation and capture discipline, sends `/boot/hello` + `echo __GSD_EXIT__$status` at the rc prompt, asserts banner/prompt/marker-after-prompt/empty-status/zero-faults, and appends the evidence block (both sha256s included) to `gate-evidence.log`. Idempotent: consecutive runs append consecutive PASS blocks. On failure it halts non-zero and `.build/9front-dist/run-gate.log` is the bisect surface (toolchain-first diagnostic rule). |
| `stage-build.sh` | **The r9-userspace staging pipeline (phase 04-05, D-03/D-04)**: compiles the script's C list (`init.c` — the staged minimal first process) in the guest namespace with the committed 7c/7l wiring into the gitignored `build/aarch64/out/`, copies the committed `hello.7.out` in verbatim (the ABI bisect binary rides the initrd), and R_MAGIC-verifies (00 00 8c 47 BE) every staged binary before the rsync-back is trusted. r9's `cargo xtask initrd` then bakes `out/{init,hello}` into `target/bootfs.paq` via the 04-01 mkpaqfs host build. Idempotent — rerun freely. Log: `.build/stage-build.log`. |

Data files: `hello.c` (the marker source — prints `hello aarch64
harvey`), `hello.7.out` (committed gate binary, plan 02-03),
`gate-evidence.log` (committed execution proof — banner, rc prompt,
marker line, exit status, sha256 pair per run).

## TCG-only constraint (probe evidence)

The harness pins `-accel tcg -cpu cortex-a72 -M
virt,gic-version=3,highmem-ecam=off`. **No plan may "upgrade" it to
HVF.** Verified against qemu 11.1.2 on the M5 Max:

- `-accel hvf -M virt,gic-version=2` → `HVF does not support GICv2 emulation`
- `-accel hvf -cpu cortex-a72` → `Invalid CPU model` (valid HVF CPUs: cortex-a53, cortex-a57, host, max)
- and at execution time (02-04 audit): the donor kernel needs GICv3 — its
  `trapinit` unconditionally `syswr`s GICv3 ICC registers
  (`gic.c`), which UNDEF under `gic-version=2` — and qemu rejects
  `-accel hvf -M virt,gic-version=3` as well (`HVF does not support
  GICv3 emulation`). The research's "GICv2-only guest" reading was
  wrong; the donor truth governs.

TCG on Apple silicon is slow: the Phase 1 TCG-degraded acceptance
precedent (human-approved 2026-10-31) covers serial capture under TCG
on this fleet — the banner/marker greps, not the boot timer, are the
source of truth.

**Forward note (Phase 3, D-02/D-03):** HVF returns when the guest is
r9 speaking **GICv3**. Also for Phase 3: Apple hosts use 16K pages,
which constrains HVF guest granule choices (9front arm64's 64K-granule
preference will not transfer), and r9's cache maintenance must use
architectural discovery (`CTR_EL0`), not hardcoded Apple geometry.

## Binary delivery: bake vs ufs (research Open Question 2 — RESOLVED)

- **Bake into the donor bootfs / embedded root is the gate path** —
  deterministic, zero guest config, sha256-verifiable end to end.
  Implemented by `run-gate.sh` (CONF=qemu bootdir → devroot
  `/boot/hello`).
- **ufs-over-tcp is the documented faster iteration path**: the donor
  CONF=qemu carries `ethervirtio10` + the full ip stack, and the
  Phase 1 `ufs` lineage (Go 9P file server serving the tree to a VM)
  applies directly. `harness srv9` already demonstrates a working
  host-side 9P2000/tcp server feeding this guest (it serves the root
  fs every boot) — iterating on binaries over tcp avoids the donor
  rebake cycle. Use bake for gates, ufs for iteration.

## License / provenance credits

The vendored toolchain and donor-derived sources carry the Plan 9 /
9front lineage: Bell Labs / Lucent Technologies, Vita Nuova Holdings,
C H Forsyth (9front's initial diffs), and the 9front contributors.
Harvey is MIT since 2021; the 9front imports are MIT-compatible.
Per-dir provenance READMEs follow the `sys/src/cmd/unix/9cc/README`
shape (pin SHA recorded inline there as well).
