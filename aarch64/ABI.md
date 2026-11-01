# Harvey aarch64 user-side syscall ABI (frozen)

This document is the canonical Harvey↔r9 user-side syscall wire
contract for `objtype=aarch64`. It is one half of the ABI freeze
(decisions D-15/D-16/D-17, phase 02): the other half is the trap-frame
layout in `aarch64/include/ureg.h`. Phase 4 builds r9's `svc` dispatch
and its build-time static checks against this document and that header —
changing either after Phase 4 means re-freezing both repos.

Provenance: derived from 9front arm64 at pin
`350266104f1fed81c78c3d05fa44f523bec0ae4d` (branch `front`), wording
research-verified 2026-10-31 against both trees (9front
`sys/src/9/arm64/trap.c:196` and `sys/src/9/arm64/mem.h:92`; Harvey
`sys/src/libc/9syscall/sys.h` and the `case aarch64` stub generator in
`sys/src/libc/9syscall/mkfile`).

## Wire contract

- **Syscall number:** register `R0`.
- **Arguments:** 8-byte slots at user `SP+8` upward. `SP+0` is the
  reserved link-register slot — the kernel never reads an argument
  there. The stub's `MOV R0, 0(FP)` materializes arg0 (passed in R0 by
  the Plan 9 calling convention) into its stack slot, so the first
  kernel-visible argument sits at `SP+8`.
- **Kernel read side:** the 9front arm64 kernel computes
  `(Sargs*)(ureg->sp+BY2WD)` with `BY2WD=8` — i.e. args begin 8 bytes
  above the user stack pointer captured in the trap frame
  (9front `sys/src/9/arm64/trap.c:196`, `sys/src/9/arm64/mem.h:92`).
- **Trap instruction:** `SVC` (supervisor call).
- **Result:** register `R0`.

## User-side stub shape

Generated per syscall by the `case aarch64` block of
`sys/src/libc/9syscall/mkfile` (donor `case arm64` verbatim, case label
renamed):

```
TEXT name(SB), 1, $0
	MOV R0, 0(FP)	// materialize arg0 into its stack slot
	MOV $NN, R0	// syscall number
	SVC
	RETURN
```

Per-name quirks, identical to the other arches' generator rules:
`seek` is emitted as `_seek` (pairs with the C wrapper in
`sys/src/libc/aarch64/_seek.c`), and `exits` is emitted as `_exits`
(Harvey's long-standing line-9 rename). No stub-side buffer store
anywhere — the kernel always writes return buffers.

## Syscall table

The table is Harvey's `sys/src/libc/9syscall/sys.h` 0–54, verbatim:

- 0–52 are wire-identical to 9front arm64 (names and numbers),
  including `SYSR1=0` and the 48–49 gap.
- 53 `NSEC` is zero-arg register-return on 64-bit — Harvey's `nsec`
  name vs 9front's `_NSEC`; same wire, same semantics (D-16).
- 54 `NMOUNT` is **Harvey-only** — the six-argument
  `nmount(fd, afd, old, flag, aname, dev)` whose 6th argument mounts a
  specific device channel. r9 implements the table lazily: `NMOUNT` may
  stay unimplemented until something calls it (D-16). The five-argument
  `mount()` is `MOUNT=46`, wire-identical to 9front.

## Trap frame

The trap frame is `aarch64/include/ureg.h`, field-for-field:
`r0`..`r28` (with `r28` noted as `sb`), `r29`, the
`r30`/`link` union, `sp`, `pc` (interrupted address), `psr`, and
`type` (exception class). Phase 4 enforces the match against r9's Rust
trap frame at build time.

## What does not cross the wire (D-17)

Kernel-side dispatch style is internal and **not** part of this
contract: Harvey 9k's generated `systab[]` handlers are
`void sysxxx(Ar0*, va_list)`; 9front's are `void sysxxx(Ar0)`. r9
mimics neither — it matches this document's wire contract (number in
R0, args at SP+8, `SVC`, result in R0) plus the frozen
`aarch64/include/ureg.h` trap frame, and nothing else.
