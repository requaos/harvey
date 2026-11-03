# Kernel build reproducibility (BUILD-04)

Policy: the 9k kernel build pins its embedded build timestamp (`kerndate`)
instead of sampling the wall clock. The pin is SOURCE_DATE_EPOCH-style:
derived from the checkout's git commit timestamp, overridable by environment.

## Scope

This policy covers the three 9k amd64 kernels and their ELF variants:
`9k10cpu`, `9k10cpuf`, `9k10f` (and `*.elf`). Given the same checkout at the
same filesystem path and the same KERNDATE, two rebuilds produce
bit-identical kernel binaries.

Bit-reproducibility of the userland (commands, libraries, man indices) is
NOT claimed. Nothing outside the kernel link is covered by this document.

## Derivation

KERNDATE is an epoch (seconds since 1970-01-01 00:00:00 UTC). Default
derivation, host-side, before any build step runs:

    git log -1 --format=%ct

i.e. the committer timestamp of the checkout's HEAD commit. It is computed
on the host because the lima guest checkout has no git metadata
(`nix/vm-build.sh` rsyncs with `--exclude .git`).

Plumbing:

- `nix/build.sh` exports `KERNDATE` (derived as above) before entering the
  mount namespace.
- `nix/vm-build.sh` derives it on the darwin host and passes it through the
  ssh command line to the guest's `nix run .#build`.
- Both kernel compile sites honor the environment variable and fall back to
  the build clock only when it is unset:

      -DKERNDATE='`{if(~ $#KERNDATE 0) KERNDATE=`{date -n}; echo $KERNDATE}

  at `sys/src/9k/k10/mkfile` (`$p$CONF` rule) and `sys/src/9k/mk/portmkfile`
  (`$CONF.$O` rule). `sys/src/9k/mk/parse` emits `ulong kerndate = KERNDATE;`
  into every generated `$CONF.c`.

## Override

Set the environment variable to any epoch to pin the timestamp explicitly:

    KERNDATE=1700000000 nix run .#build        # darwin (via lima guest)
    KERNDATE=1700000000 nix run .#build        # linux (namespace build)

The variable crosses host -> guest -> namespace -> mk recipe unchanged; the
mkfiles never overwrite a set value.

## Exceptions

1. **Same-path reproducibility only.** `sys/src/9k/mk/parse` embeds the
   absolute build path into every kernel as `char* conffile =
   "<build pwd>/$CONF"`. Two checkouts at *different* paths produce
   different binaries even with identical KERNDATE. Compare only builds made
   at the same checkout path.
2. **No-git fallback is non-reproducible by design.** With KERNDATE unset
   and no git metadata available, the derivation falls back to the wall
   clock (`date +%s` host-side, `date -n` at the mkfile sites). Builds made
   this way embed their own build time and will differ.
3. Any further variance found by the verification procedure below is to be
   recorded here honestly rather than silently chased.

## Verification

From a built checkout (inside the namespace-capable build environment —
native linux, or the lima guest on darwin), relink one kernel twice with a
pinned timestamp and compare:

    cd /sys/src/9k/k10
    rm -f k10cpu.6 9k10cpu 9k10cpu.elf
    KERNDATE=1700000000 mk CONF=k10cpu 9k10cpu
    sha256sum 9k10cpu 9k10cpu.elf > /tmp/kerndate-run1
    rm -f k10cpu.6 9k10cpu 9k10cpu.elf
    KERNDATE=1700000000 mk CONF=k10cpu 9k10cpu
    sha256sum 9k10cpu 9k10cpu.elf > /tmp/kerndate-run2
    diff /tmp/kerndate-run1 /tmp/kerndate-run2   # must be empty

Equivalently, two full `nix run .#build` runs of the same checkout (same
path, KERNDATE unset or equally pinned) must yield identical
`sha256sum amd64/9k10cpu*` output.

# Clean-checkout boot reproduction (INT-03)

Policy: the r9-kernel + Harvey-aarch64-userland boot is reproducible at
the *process* level — from a clean checkout of this repo, the documented
command sequence below reproduces the green boot smoke on macOS
(darwin-aarch64) and on Linux, with every toolchain pinned. The Phase-1
KERNDATE policy above applies unchanged to the aarch64 userland build:
the compose/smoke apps derive KERNDATE from the checkout's HEAD commit
host-side (`git log -1 --format=%ct`) and export it into the build,
overridable by environment. Reproducibility claims here rest on the two
clean-checkout runs recorded in
`.planning/phases/05-shell-boot-one-command-integration/05-EVIDENCE.md`
(CI/linux leg + darwin leg) plus the pins named below — never on a
"deterministic anyway" assumption.

## Scope

Pinned (the pins that matter):

- **r9 kernel source** — this repo's `flake.lock` pins
  `inputs.r9 = github:requaos/r9` to rev
  `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` (narHash
  `sha256-g9OBd1Mwll2bx5bNjzxkuREB0X3H7uTPTyQ62PGrzQc=`). The compose
  apps consume only `r9.packages.<system>.kernel-virt` store paths; no
  sibling-checkout path exists anywhere in the composition (INT-04).
- **nixpkgs** — `flake.lock` pins `github:NixOS/nixpkgs/nixos-unstable`
  at rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010`; qemu, plan9port,
  expect, dtc, lima, util-linux and every other host tool resolve from
  this pin.
- **r9's rust toolchain** — r9's `rust-toolchain.toml`
  (`channel = "nightly-2026-01-30"`, components incl. `rust-src` +
  `llvm-tools`) honored via rust-overlay inside the kernel-virt
  derivation; r9's own `flake.lock` pins its nixpkgs/rust-overlay, and
  this repo's lock captures those nodes transitively.
- **qemu** — from the nixpkgs pin above (11.1.2-era; the carried-forward
  qemu virt machine facts apply).

NOT claimed: bit-identical artifacts across hosts or runs. The baked
`bootfs.paq` image carries KERNDATE-derived metadata (mkpaqfs embeds a
time field), so image bytes differ between checkouts at different HEAD
commits. The INT-03 claim is *documented-commands reproducibility*: the
same commands on the same checkout reproduce the same green outcome —
the smoke asserts the boot's behavior (marker sequence to the `% `
prompt, the D-09 command sweep, DEL safety, init restart), not image
bytes.

## Derivation

The documented command sequence, per host — exactly what the evidence
runs executed:

    git clone <this-repo-url-or-path> harvey && cd harvey
    nix run .#boot-r9-smoke

- **darwin-aarch64:** the app builds the aarch64 userland in the lima
  guest's Plan 9 namespace (first run creates/starts the `harvey` VM and
  bootstraps the guest toolchain), bakes `bootfs.paq` with Harvey's own
  mkpaqfs, fdtput-patches a copy of the r9 package's DTB, and drives
  qemu (TCG) under the expect sweep. A fresh nix is the only host
  prerequisite (plan9port/qemu/expect/lima all arrive via the flake).
- **linux (aarch64 or x86_64):** the identical command; the userland
  build runs natively under `sudo unshare -m`
  (`build/aarch64/nsrun.sh`), so passwordless sudo is the one host
  requirement beyond nix. The GH Actions workflow
  `.github/workflows/r9-shell.yml` runs exactly this sequence on
  `ubuntu-latest` (clean checkout → SHA-pinned nix install →
  `nix run .#boot-r9-smoke`, 90-minute budget) — the CI leg is the
  linux clean-checkout proof on every push.
- For the interactive shell instead of the self-asserting smoke:
  `nix run .#boot-r9` (same pipeline; qemu attaches the terminal as the
  console — ctrl-a x to quit).

## Override

Both non-default, documented for the dev loop only:

- `nix run .#boot-r9 --override-input r9 git+file:///path/to/r9` —
  build against a LOCAL r9 checkout instead of the pinned input (D-13
  dev flow; never the default, never what CI or a clean checkout uses).
- `R9_SKIP_BUILD=1 nix run .#boot-r9-smoke` — skip the userland build
  leg (iteration hatch against an already-built tree; the acceptance
  gates always run the default full-pipeline path).

`KERNDATE=<epoch>` pins the userland build timestamp explicitly, exactly
as in the 9k policy above.
