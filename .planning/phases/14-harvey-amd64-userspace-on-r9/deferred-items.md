
## 14-05 (Task 1): boot-iso FOD outputHash stale since 14-01 (pre-existing, out of scope)

`nix build .#boot-iso --rebuild` at r9 fails the wired Phase-13 hash
(dCSPPV…) — proven PRE-EXISTING at the pre-plan commit abee15c (fresh
build yields w6uDAH…, also ≠ specified). Every Phase-14 kernel commit
(14-01 onward) changed the kernel ELF bytes the FOD stages; the hash was
wired in 13-06 against the Phase-13 kernel and never re-wired. 14-05's
grub.cfg component is NOT the cause: the kernel-only emission is
byte-identical to Phase 13's (cmp-proven + pinned by an xtask unit
test); the FOD's sed staging keeps the loader-config component stable so
14-07's re-proof isolates kernel-byte drift. 14-07 owns the re-wire (its
plan: the parameterized builder + a fresh two-derivation byte-identity
proof + the new hash), per OQ-1's resolution.
