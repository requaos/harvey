# Harvey amd64 user-side syscall ABI (frozen)

This document is the canonical Harvey↔r9 user-side exec interface for
`objtype=amd64`. It is the whole kernel/user boundary in one document
(phase 14 decision D-02): the wire contract, the user-side stub shape,
the syscall number table, the trap frame (`amd64/include/ureg.h`), the
SYSCALL entry state, the note-delivery convention, and the stack-top
policy. Phase 14 builds r9's x86_64 syscall entry and its build-time
checks against this document and that header — changing either after
Phase 14 means re-freezing both repos.

**D-01 consequence (both kernels):** r9's x86_64 trap frame IS this
`Ureg`, byte-verbatim — no translation anywhere. The same 6.outs run
on Harvey's own 9k kernel (the k10t1 venue) and on r9, which makes
every donor-venue execution a live ABI-conformance witness.

Provenance: every frozen fact below was read verbatim from Harvey's
own 9k k10 tree and toolchain — `sys/src/9k/k10/l64syscall.s` (entry
assembly), `sys/src/9k/k10/vsvm.c` (MSR arming), `sys/src/9k/k10/syscall.c`
(arg copy, return, note delivery), `sys/src/9k/k10/mem.h` (address-space
constants), `sys/src/libc/9syscall/sys.h` (the authoritative number
table — the shared file; there is no `9syscall/amd64/sys.h`) plus the
`case amd64` stub generator in `sys/src/libc/9syscall/mkfile`, the
toolchain register contract (`RARG` = `REGARG` = `D_BP`:
`sys/src/cmd/6a/lex.c:210`, `sys/src/cmd/6c/6.out.h:916`), and
`amd64/include/ureg.h` as the trap-frame half. NOT 9front — the amd64
donor is Harvey's own kernel.

## Wire contract

- **Syscall number:** register `BP` (the 6a/6c `RARG`; the stub loads
  `MOVQ $n, RARG` immediately before the trap instruction).
- **Arguments:** 8-byte slots at user `SP+8` upward. `SP+0` is the
  stub's return-address slot — the kernel NEVER reads an argument
  there. The stub's `MOVQ RARG, a0+0(FP)` spills arg0 (passed in BP by
  the Plan 9 calling convention) into its stack slot, so the first
  kernel-visible argument sits at exactly `SP+8`.
- **Kernel read side:** the 9k kernel validates the stack range then
  copies arguments from `sp+BY2SE` (`BY2SE` = 8) upward
  (`sys/src/9k/k10/syscall.c:248-254`: `memmove(up->arg,
  UINT2PTR(sp+BY2SE), ...)` after `validaddr` of the stack window).
- **Trap instruction:** `SYSCALL` — MSR-routed (STAR/LSTAR/FMASK),
  pushes NO hardware frame; the kernel's entry routine software-builds
  the hardware half of the Ureg (see "Entry state" below).
- **Result:** register `AX` (`ureg->ax = ar0.p`, `syscall.c:280`).
- **Flags mask on entry:** `Sfmask = If` ONLY (`vsvm.c:185`) — the
  SYSCALL instruction clears IF (and the FMASK bits) on entry; TF/DF
  pass through untouched.

## User-side stub shape

Generated per syscall by the `case amd64` block of
`sys/src/libc/9syscall/mkfile` (quoted verbatim):

```
	case amd64
		if(~ $i seek)
			echo TEXT _seek'(SB)', 1, '$0'
		if not
			echo TEXT $i'(SB)', 1, '$0'
		#
		# For architectures which pass the first argument
		# in a register, if the system call takes no arguments
		# there will be no 'a0+0(FP)' reserved on the stack.
		#
		if(! ~ $i nsec)
			echo MOVQ RARG, 'a0+0(FP)'
		echo MOVQ '$'$n, RARG
		echo SYSCALL
		echo RET
```

The generic emitted form is therefore:

```
TEXT name(SB), 1, $0
	MOVQ RARG, a0+0(FP)	// spill arg0 into its stack slot (SP+8)
	MOVQ $NN, RARG		// syscall number into BP
	SYSCALL
	RET
```

Three named ABI rules (quirks frozen as part of the contract, not
generator accidents):

1. **`nsec` emits NO arg0 spill.** `nsec` (53) is zero-arg
   register-return on 64-bit: the generator's `if(! ~ $i nsec)` guard
   skips the `MOVQ RARG, a0+0(FP)` line, so no argument slot is
   reserved on the stack. A generic kernel-side `SP+8` read for nsec
   would consume the stub's return address. The dispatch must handle
   nsec entirely from the frame, with no stack argument read.
2. **`seek` is emitted `TEXT _seek`** (the amd64 block's rename;
   pairs with the C wrapper). Number unchanged: SEEK = 39.
3. **`exits` is emitted `TEXT _exits`** (the list-level rename in the
   mkfile's install rule, `if(~ $i exits) i=_exits`). Number
   unchanged: EXITS = 8.

All three are renames/spill decisions only — the wire numbers are the
table below in every case.

## Syscall table

The table is Harvey's `sys/src/libc/9syscall/sys.h` (the shared,
authoritative file), numbers 0–54, verbatim:

| # | Name | # | Name | # | Name |
|---|------|---|------|---|------|
| 0 | SYSR1 | 19 | RFORK | 38 | SEMRELEASE |
| 1 | _ERRSTR | 20 | _WRITE | 39 | SEEK |
| 2 | BIND | 21 | PIPE | 40 | FVERSION |
| 3 | CHDIR | 22 | CREATE | 41 | ERRSTR |
| 4 | CLOSE | 23 | FD2PATH | 42 | STAT |
| 5 | DUP | 24 | BRK_ | 43 | FSTAT |
| 6 | ALARM | 25 | REMOVE | 44 | WSTAT |
| 7 | EXEC | 26 | _WSTAT | 45 | FWSTAT |
| 8 | EXITS | 27 | _FWSTAT | 46 | MOUNT |
| 9 | _FSESSION | 28 | NOTIFY | 47 | AWAIT |
| 10 | FAUTH | 29 | NOTED | 48 | — (gap) |
| 11 | _FSTAT | 30 | SEGATTACH | 49 | — (gap) |
| 12 | SEGBRK | 31 | SEGDETACH | 50 | PREAD |
| 13 | _MOUNT | 32 | SEGFREE | 51 | PWRITE |
| 14 | OPEN | 33 | SEGFLUSH | 52 | TSEMACQUIRE |
| 15 | _READ | 34 | RENDEZVOUS | 53 | NSEC |
| 16 | OSEEK | 35 | UNMOUNT | 54 | NMOUNT |
| 17 | SLEEP | 36 | _WAIT | | |
| 18 | _STAT | 37 | SEMACQUIRE | | |

- 54 `NMOUNT` is **Harvey-only** — the six-argument
  `nmount(fd, afd, old, flag, aname, dev)`. The five-argument
  `mount()` is `MOUNT = 46`.
- **r9 dispatch contract (the loud-unimplemented rule):** r9
  implements exactly the measured boot-chain subset of this table.
  Every other number — implemented-or-not, inside 0–54 or outside it —
  is loud-unimplemented: a named failure (a printed diagnostic plus an
  error-string result), NEVER a silent no-op and never a wedge. A
  syscall number outside the frozen 0–54 table is the same class of
  loud failure.

## Trap frame

The trap frame is `amd64/include/ureg.h`, quoted verbatim (the whole
file — the D-01 source of truth):

```c
struct Ureg {
	u64int	ax;
	u64int	bx;
	u64int	cx;
	u64int	dx;
	u64int	si;
	u64int	di;
	u64int	bp;
	u64int	r8;
	u64int	r9;
	u64int	r10;
	u64int	r11;
	u64int	r12;
	u64int	r13;
	u64int	r14;
	u64int	r15;

	u16int	ds;
	u16int	es;
	u16int	fs;
	u16int	gs;

	u64int	type;
	u64int	error;				/* error code (or zero) */
	u64int	ip;				/* pc */
	u64int	cs;				/* old context */
	u64int	flags;				/* old flags */
	u64int	sp;				/* sp */
	u64int	ss;				/* old stack segment */
};
```

Pinned byte offsets (C layout rules: 8-byte alignment; the four u16
segment fields pack into ONE qword at 120..126 with no padding before
`type`, since 120+8 == 128):

| Field | Offset | Width | Cross-check site (independent 9k assembly) |
|-------|--------|-------|--------------------------------------------|
| ax | 0 | 8 | `l64syscall.s` syscallreturn `MOVQ 16(SP), AX /* Ureg.ax */` (SP = ureg−16) |
| bx | 8 | 8 | — |
| cx | 16 | 8 | touser `MOVQ $(UTZERO+0x28), CX /* ip */` (CX carries ip at entry) |
| dx | 24 | 8 | — |
| si | 32 | 8 | — |
| di | 40 | 8 | — |
| bp | 48 | 8 | syscallreturn `MOVQ (16+6*8)(SP), BP /* Ureg.bp */` (16+48 = SP+16+48) |
| r8..r15 | 56–112 | 8 ea | intrcommon-style GP push order (15 qwords) |
| ds | 120 | 2 | syscallentry `MOVW $SSEL(...), (15*8+0)(SP)` = 120 |
| es | 122 | 2 | syscallentry `MOVW ES, (15*8+2)(SP)` |
| fs | 124 | 2 | syscallentry `MOVW FS, (15*8+4)(SP)` |
| gs | 126 | 2 | syscallentry `MOVW GS, (15*8+6)(SP)` |
| type | 128 | 8 | IDT path: vector lands here; 9k `l64idt.s` builds the same 23-qword frame |
| error | 136 | 8 | CPU error code (7 classes) or stub placeholder |
| ip | 144 | 8 | syscallreturn post-ADDQ `MOVQ 24(SP), CX /* ip */` (SP′ = ureg+120; +24 = 144) |
| cs | 152 | 8 | `userureg`: `ureg->cs == SSEL(SiUCS, SsRPL3)` (`vsvm.c`) |
| flags | 160 | 8 | post-ADDQ `MOVQ 40(SP), R11 /* flags */` (+40 = 160) |
| sp | 168 | 8 | post-ADDQ `MOVQ 48(SP), SP /* sp */` (+48 = 168) |
| ss | 176 | 8 | highest; constructed on the SYSCALL path, CPU-pushed on the IDT path |
| **sizeof** | **184** | | 23 qwords |

Independent confirmation: three 9k sites agree field-for-field — the
syscall path (`sys/src/9k/k10/l64syscall.s`), the IDT trap path
(`sys/src/9k/k10/l64idt.s`, `SUBQ $24` + 13 pushes + the R14/R15/
segment hole), and `syscallreturn`'s post-ADDQ reads.

## Entry state and note delivery

**SYSCALL entry (the LSTAR target).** The `SYSCALL` instruction
pushes nothing — no SS/RSP/FLAGS/CS/RIP. The kernel's entry routine
software-builds the hardware half of the Ureg from the architectural
registers before carving the rest (9k `syscallentry`,
`l64syscall.s:26-48`): RCX = user rip, R11 = user flags, user SP
saved before the stack switch, SS/CS constructed from the user
selectors, then `SUBQ $(18*8)` and the packed segment stores at
`(15*8+0..6)(SP)`. SWAPGS on this path is unconditional (SYSCALL only
fires from ring 3). The stack switch goes through the per-CPU Mach /
TSS-rsp0 mechanism.

**MSR arming (the entry contract, `vsvm.c:174-185`):**

- `Efer.Sce` set (SYSCALL/SYSRET enabled);
- `Star = SSEL(SiU32CS, SsRPL3)<<48 | SSEL(SiCS, SsRPL0)<<32`
  (SYSRET takes CS from STAR[63:48]+16, SS from STAR[63:48]+8);
- `Lstar = syscallentry`;
- `Sfmask = If` (IF only — see Wire contract);
- kernel `GSbase` = the per-CPU Mach pointer, `KernelGSbase` = 0
  (user GS base is 0; user code does not use GS).

**Return to user / first entry (SYSRETQ, 9k `touser`,
`l64syscall.s:8-22`):** CX = user ip, R11 = user flags, BP (RARG) =
user sp, DS/ES/FS/GS loaded with the flat user data selector
`SSEL(SiUDS, SsRPL3)`, then `SYSRETQ`. For the seeded first process
the entry is `UTZERO+0x28` (past the a.out header — see Stack-top
policy); for exec'd processes it is the a.out header's `entry` field.

**Exec return / `_tos` (the first-instruction AX contract).** The
donor's `sysexecregs` (k10 `syscall.c:328-347`) RETURNS the address of
the kernel-written Tos (`USTKTOP-sizeof(Tos)`); the syscall machinery
lands that return in `AX` (`ureg->ax = ar0.p`). The C startup
consumes it as its first instruction: `main9.s` opens with
`MOVQ AX, _tos(SB)` — and 6l emits the same store at the head of
`main` even when `_main` is absent (the linker-fused prologue; boot(8)
links without main9 and still carries it). Kernels seeding a first
process (no exec syscall happened) must therefore plant the Tos
pointer in `AX`, not in any argument register — argc/argv arrive on
the seeded stack and the prologue reloads them; `BP` (6c's first-arg
register) is left alone. A zero `_tos` is not benign: libc's malloc
`plock` reads `_tos->pid` (offset 0x40) on the first allocation.

**Note delivery (`syscall.c:182-192`).** When a note must reach a
process with a `notify` handler installed, the kernel copies the
whole `Ureg` into a user-allocated `NFrame` placed at
`ureg->sp - sizeof(NFrame)` (address-validated first), then:

- the handler receives its `Ureg*` as arg0 **through `ureg->bp`**
  (`nf->arg0 = &nf->ureg; ureg->bp = PTR2UINT(nf->arg0)`) —
  consistent with the 6c first-argument-in-BP convention;
- `nf->arg1 = nf->msg` (the note string is arg1);
- `ureg->sp` = the NFrame address; `ureg->ip = up->notify` (resume
  at the handler); `nf->ip = 0` (the handler returns to it as 0).

## Stack-top policy

r9's adopted x86_64 user address-space policy mirrors the 9k donor
(`sys/src/9k/k10/mem.h:57-61`) — this is the phase-14 discretion
resolution, recorded here as part of the contract:

- `UTZERO = 2 MiB` — first address of user text;
- `INITTEXT = 0x200000 + HEADR = 0x200028` with `HEADR = 40`
  (`sys/src/cmd/6l/obj.c` HEADTYPE 2: `HEADR = 32+8`,
  `INITTEXT = 0x200000+HEADR`) — the linked entry sits just past the
  a.out header;
- data-segment alignment `INITRND = 0x200000` (2 MiB, `obj.c`) — the
  data segment lands at the next 2 MiB boundary above text;
- `USTKTOP = 0x00007ffffffff000`, `USTKSIZE = 16 MiB` — the user
  stack top and size.

## What does not cross the wire

Kernel-side dispatch style is internal and **not** part of this
contract: 9k's generated `systab[]` handlers are
`void sysxxx(Ar0*, va_list)` with a full table; r9's dispatch is the
measured boot-chain subset with loud-unimplemented defaults (see
Syscall table). Likewise the `type` slot's VALUE is kernel-side
informational (the trap vector on the IDT path; the syscall class on
the SYSCALL path) — only the slot's offset (128) is frozen. r9
matches this document's wire contract (number in BP, args at SP+8,
`SYSCALL`, result in AX) plus the frozen `amd64/include/ureg.h` trap
frame, and nothing else.

## Kernel-side enforcement (appendix)

This appendix is the kernel side of the contract: how r9's x86_64
frame matches the frozen `amd64/include/ureg.h`, and the build-time
checks that make any drift a build failure, not a runtime mystery
(D-02b; the aarch64 Phase-4 two-layer shape, extended with a negative
control). It documents enforcement only — the frozen wire contract
above is unchanged.

### Pinned trap-frame offsets

r9's `Ureg` (`x86_64/src/dat.rs` in the r9 repo) IS the `Ureg` of
`amd64/include/ureg.h`, byte-verbatim: 15 u64 GP fields (ax@0 …
r15@112), the four u16 segment fields packed into one qword
(ds@120, es@122, fs@124, gs@126), then type@128, error@136, ip@144,
cs@152, flags@160, sp@168, ss@176. `sizeof(Ureg)` = 184 — 23 qwords.
There is exactly ONE trap-frame layout and no compat shim alongside
it (D-01).

### The two-layer check

1. **In-crate const asserts** (r9 `x86_64/src/dat.rs`): one
   `core::mem::offset_of!` assertion per pinned offset (ax, bp, r15,
   ds, es, fs, gs, type, error, ip, cs, flags, sp, ss) plus
   `core::mem::size_of::<Ureg>() == 184`. Always on — any layout
   drift fails `cargo build`, with no Harvey checkout needed.
2. **Cross-repo header check**: `cargo xtask ureg-check` (r9 repo)
   parses this repo's `amd64/include/ureg.h` — located via the
   `R9_HARVEY_DIR` environment variable, default `../harvey` —
   against a pinned 22-slot table and fails with a named-field diff
   when the field names, order, or count drift. The amd64 arm of the
   checker handles this header's two parser-relevant shapes: the bare
   `struct Ureg {` form (no typedef wrapper) and the `u16int`
   declarations — with the four-fields-one-qword packing rule pinned
   EXPLICITLY (ds/es/fs/gs land in slots 15–18 of one qword; they
   are never skipped or wildcarded — a relaxed parser would certify
   nothing). It runs standalone and as a boot-test precondition for
   BOTH the aarch64 and x86_64 profiles, so drift fails every
   boot-test gate.

### The negative control (D-02b)

`cargo xtask ureg-check` also runs a negative-control leg: the check
is re-run against a deliberately-mutated temp copy of the amd64
header and MUST fail, with the failure output containing the
named-field diff and a `NEGATIVE CONTROL FAILED` line. If the mutated
copy ever passes the check, that is the loud failure — the gate
proves it can catch drift, not just that it can parse the pristine
header.
