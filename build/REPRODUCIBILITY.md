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
