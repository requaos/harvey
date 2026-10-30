# Stack Research

**Domain:** Plan 9-family OS porting — aarch64 (ARM64) toolchain + reference kernel ecosystem for Harvey OS
**Researched:** 2026-10-30
**Confidence:** HIGH for locations/contents (verified by direct fetch of primary source trees: 9front git mirror, 0intro/9-cc, 9fans/plan9port). Provider-seam tier for all web evidence is LOW (no curated docs DB configured for this domain), but every load-bearing claim below was confirmed against actual file contents in the canonical repos, not search-result summaries. Jehanne/9legacy negative findings are absence-of-evidence (MEDIUM).

## Executive Answer

**Import everything from 9front.** It is the only Plan 9-family tree with a maintained, shipping aarch64 toolchain (`7a`/`7c`/`7l`), the only maintained Plan 9 aarch64 libc, a working libmach arm64 backend, *and* an in-tree qemu `-M virt` reference kernel (`CONF=qemu`). Harvey's build conventions (BUILD scripts compiling Plan 9 sources with plan9port `9c`/`9l`) already match the shape of 9front's sources — the import is mostly mechanical, with known drift surfaces enumerated below. All donor code is MIT or MIT-compatible; Harvey itself is MIT (see license section — the milestone brief's "GPL tree" assumption is outdated).

## Recommended Stack

### Core Technologies (import sources)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **9front `sys/src/cmd/7a`** | branch `front` @ HEAD (pin SHA at import; e.g. `9front/9front` mirror commit for a.y `a5b1f96…` blob) | ARM64 assembler (Plan 9 syntax) | Canonical, actively maintained. File layout (`a.h`, `a.y`, `lex.c`, `mkfile`) is identical in shape to Harvey's `6a` — Harvey's `6a/BUILD` pattern (`yacc -D1 -d a.y; 9c *.c; 9l -o 7a`) applies unchanged. |
| **9front `sys/src/cmd/7c`** | branch `front` @ HEAD | ARM64 C compiler (ken-cc lineage) | The only living Plan 9 arm64 compiler. Files: `cgen.c enam.c gc.h list.c machcap.c mul.c peep.c reg.c sgen.c swt.c txt.c 7.out.h`, mkfile with `T=7`, `HFILES=gc.h 7.out.h ../cc/compat.h ../cc/cc.h`, includes `../cc/mkfile.port`. Slots into `sys/src/cmd/7c/` where Harvey's `build_arm64` (`build/scripts/linux-build:63`, `build/scripts/build:76`) already globs `/sys/src/cmd/7?`. |
| **9front `sys/src/cmd/7l`** | branch `front` @ HEAD | ARM64 linker/loader | Companion to 7c; produces Plan 9 a.out (`R_MAGIC`, per 9front `bcm64/dat.h` `AOUT_MAGIC (R_MAGIC)`). Note: `7l` has `dyn.c` (dynamic-linking support) and depends on `../cc/compat` — see Version Compatibility. |
| **9front `sys/src/libc/arm64/`** | branch `front` @ HEAD | Per-arch libc (setjmp, tas, atomics, memmove, main9) | The only maintained Plan 9 arm64 libc. Full file set confirmed: `_seek.c argv0.s atom.s atomic.s atomic64.s cycles.s fabs.s floor.s getcallerpc.s getfcr.s lock.c main9.s main9p.s memmove.s memset.s notejmp.c setjmp.s sqrt.s tas.s mkfile`. Harvey already has `libc/{port,9sys,fmt}` shared code — only this per-arch dir is missing (`sys/src/libc/` has 386/amd64/arm/…/riscv64 but no arm64). |
| **9front `arm64/mkfile` + `arm64/include/`** | branch `front` @ HEAD | objtype wiring | `arm64/mkfile` is `CC=7c LD=7l AS=7a O=7` + `</sys/src/mkfile.proto` — byte-for-byte the pattern of Harvey's `amd64/mkfile` (`CC=6c LD=6l AS=6a O=6`). `arm64/include/` carries `u.h` (per-arch types) and `ureg.h` (trap frame — also included by libmach `7.c` as `/arm64/include/ureg.h`), plus `ape/` (skip unless APE is wanted). Harvey's `arm64/` dir currently contains only an empty `bbin/`. |
| **9front `sys/src/libmach`: `7.c`, `7db.c`, `7obj.c`** | branch `front` @ HEAD | arm64 object/executable/debug support for `nm`, `acid`, `aout2uimage` | Harvey's `sys/include/mach.h` already has the `MARM64` enum (line 40) but **no** `7.c/7obj.c/7db.c` and no `arm64` entry in `setmach.c` — so nothing in Harvey can parse a 7l binary today. 9front's setmach entry is `{ "arm64", FARM64, FARM64B, AARM64, &marm64, &arm64mach }`; `7.c` defines `Mach marm64` (kzero `0xFFFFFFFF80000000`, page size 0x10000, reg list incl. `setSB`); `7db.c` is a complete arm64 disassembler; `7obj.c` parses 7-object streams (`_is7`/`_read7`, includes `7c/7.out.h`). **Collision warning:** Harvey's libmach still wires the *retired Alpha* toolchain under letter 7 (`alpha/7.out.h`, `alphaobj.c`, `alphadb.c`, setmach entry `"alpha"`). 9front deleted Alpha entirely. Decide whether to retire Harvey's alpha libmach entries before importing — both trees call their header `7.out.h`. |
| **9front `sys/src/9/arm64/` (reference kernel)** | branch `front` @ HEAD | Portable arm64 kernel layer **with `CONF=qemu`** | This is the qemu `-M virt` reference kernel: `l.s main.c mem.c mmu.c trap.c fpu.c clock.c sysreg.c/h bootargs.c cache.v8.s init9.s rebootcode.s devrtc.c gic.c uartqemu.c pciqemu.c qemu mkfile dat.h mem.h fns.h io.h`. Produces `9qemu` + `9qemu.u`. Harvey's 9k port should adapt this into 9k conventions (9k has `sys/src/9k/port` + `sys/src/9k/k10`; expect `sys/src/9k/arm64` + a machine dir). |
| **9front `sys/src/cmd/aux/aout2uimage.c`** | branch `front` @ HEAD | Wrap 7l a.out kernel as u-boot uImage for `qemu -kernel` | qemu's arm boot path (`load_uimage`) accepts legacy uImages; 9front's arm64 mkfile does `aux/aout2uimage -Z$kzero 9qemu` → `9qemu.u`. Requires working libmach `crackhdr` for MARM64 (hence the libmach import above). Harvey has `sys/src/cmd/aux/` but no `aout2uimage`. |
| **qemu `qemu-system-aarch64`** | ≥ 8.x host package (nixpkgs `qemu`) | Target emulator, `-M virt` | Matches the 9front `CONF=qemu` reference exactly: RAM at `0x40000000` (DTBADDR), PL011 UART at `0x09000000`, GIC, PCIe ECAM, virtio-1.0. Stable across darwin (hvf) and linux (kvm/tcg); `-M virt` is versioned (`virt-8.x`) for reproducibility. |

### Supporting Libraries (import when the phase needs them)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| 9front `sys/src/9/port/ethervirtio10.c`, `sdvirtio10.c`, virtio-1.0 helpers | branch `front` | virtio-net / virtio-block for qemu | After boot-to-shell: networking/storage on `-M virt`. The qemu CONF already links `ethervirtio10 pci virtio10mem` and `sdvirtio10 pci sdscsi virtio10mem`. |
| 9front `sys/src/9/bcm64/` | branch `front` | RPi3/4 kernel (GIC, mini-UART/pl011, sdhc, genet ether, spin-table SMP) | Only when hardware Pi targets come back in scope (currently Out of Scope). Also a second worked example of the shared-arm64 + machine-dir pattern. |
| 9front `sys/src/9/lx2k/` | branch `front` | LX2160A (Honeycomb) kernel | Best *structural* analog for a from-scratch virt machine layer: GIC + PL011 + PCIe ECAM + generic timers, no Pi-firmware weirdness (no mailbox, no spin tables). |
| **0intro/9-cc** `src/cmd/{7a,7c,7l}` | `main` @ HEAD (Harvey already vendors a subset at `634e7371`, 2022-04-04) | Same toolchain, already host-ported to unix | Fallback/diff reference if 9front sources hit Plan 9-isms that Harvey's `9c`+lib9 host build can't digest. Also the provenance of Harvey's vendored `iar` (`sys/src/cmd/unix/9cc/`), so its conventions are already proven in this tree. Its libmach lacks 7-object support — do **not** take libmach from here. |

### Development Tools (already in Harvey's stack — no change)

| Tool | Purpose | Notes |
|------|---------|-------|
| plan9port (`9fans/plan9port`) | host `mk`, `rc`, `9c`/`9l`, `yacc`, `lex`, lib9 | Confirmed: ships **no** target compilers (src/cmd has zero `?a/?c/?l` dirs) — it cannot be a 7a/7c/7l donor. Keep `$PLAN9/bin` LAST in PATH (existing PROJECT.md decision). |
| Vendored `9-cc` subset (`sys/src/cmd/unix/9cc/`) | host `iar` archiver | If 7-format archives ever need inspection, this vendored libmach also lacks `7obj` — but `ar`/`iar` don't parse objects, so no change needed for the milestone. |
| Nix flake devshell | reproducible host env | Add `qemu` (aarch64 system target) to the flake for the boot phases; lima VM path unchanged for the namespace build. |

## Installation

```bash
# Donor checkout (pin to a SHA at import time; 'front' is 9front's mainline)
git clone https://github.com/9front/9front.git /tmp/9front   # canonical: git.9front.org/plan9front/plan9front
cd /tmp/9front && git rev-parse front > /tmp/9front.PIN

# Import into Harvey (target layout):
#   sys/src/cmd/7a  sys/src/cmd/7c  sys/src/cmd/7l     <- sys/src/cmd/{7a,7c,7l}
#   sys/src/libc/arm64/                               <- sys/src/libc/arm64
#   sys/src/libmach/{7.c,7db.c,7obj.c} + setmach/machdata wiring
#   arm64/mkfile  arm64/include/{u.h,ureg.h}
#   sys/src/cmd/aux/aout2uimage.c                      (add to aux/BUILD)
#   sys/src/9k/arm64/ + sys/src/9k/<virt>/             (adapted from sys/src/9/arm64/, not copied verbatim)

# Host deps (already present via flake): plan9port, qemu (add qemu-system-aarch64)
```

## License Compatibility

| Source | License | Evidence | Compatible with Harvey (MIT)? |
|--------|---------|----------|-------------------------------|
| **Harvey itself** | **MIT** (Plan 9 Foundation, 2021) | Top-level `LICENSE` read directly. `LICENSE.gpl` applies **only** to ghostscript printer fonts (`/sys/lib/ghostscript/font`); `LICENSE.old` is historic LPL 1.02. | — |
| 9front | MIT | Plan 9 relicensed to MIT by Plan 9 Foundation 2021-03-23 (covers all pre-2021 Plan 9 code); 9front project statement on 9fans: "9front kept licensing with MIT". No top-level LICENSE file in the repo (404) — weaker evidence for post-2021 additions; treat as MIT with NOTICE retention. | ✓ |
| 0intro/9-cc | MIT-grant NOTICE (Lucent/Vita Nuova/C H Forsyth copyrights) | `NOTICE` file fetched directly — verbatim MIT permission text. | ✓ |
| 9legacy | MIT (same 2021 relicense basis) | 9legacy.org (absence-of-evidence tier). Irrelevant — not a donor. | ✓ (n/a) |
| plan9port | MIT (post-2021) | 9fans/plan9port. Not a donor for this work. | ✓ (n/a) |

**Action:** retain a `NOTICE`/`COPYRIGHT` line in each imported dir crediting Bell Labs/Lucent, Vita Nuova, C H Forsyth, and 9front. No copyleft conflicts exist; the milestone brief's "Harvey (GPL)" framing is stale — Harvey relicensed to MIT in 2021.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| 9front `sys/src/cmd/{7a,7c,7l}` | 0intro/9-cc `src/cmd/{7a,7c,7l}` | If 9front sources need shims for unix-host building that Harvey's existing `9c`+lib9 pattern doesn't already provide. 9-cc's versions are pre-ported (its repo builds with host cc + mk on Linux/MacOSX). Same code lineage, slightly older; Harvey already vendors 9-cc for `iar`, so bumping that vendor pin and widening the subset is a low-friction Plan B. |
| qemu `-M virt` (CONF=qemu reference) | qemu `-M raspi3b` (bcm64/pi3 reference) | Only if the port were pivoted to Raspberry Pi hardware. raspi3b emulation exists to run bcm64 kernels (BCM2835 peripherals, Pi spin tables, firmware mailbox) — none of that transfers to a clean virt port, and PROJECT.md already targets virt. |
| 9front `sys/src/libc/arm64` | Harvey's `libc/arm` (32-bit) as skeleton + hand-write asm | Never. 32-bit ARM asm (setjmp/tas/memmove) does not translate mechanically to A64 (different register file, calling convention, atomics via LDXR/STXR). Importing 9front's is strictly less work and battle-tested. |
| uImage via `aout2uimage` | Teach 7l to emit ELF, boot ELF directly via `qemu -kernel` | Possible (qemu arm boot accepts ELF; Harvey's amd64 flow already produces `.elf`), but it means patching 7l — a worse trade than importing one 3.6KB aux tool. Revisit only if ELF boot becomes a requirement (e.g., for a future bootloader chain). |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **9legacy** as toolchain donor | No arm64 support at all — 386/amd64 focus, no `7a/7c/7l`, no `libc/arm64` (absence-of-evidence, MEDIUM). | 9front |
| **plan9port** as toolchain donor | Ships zero target compilers (verified: full `src/cmd` listing has no `?a/?c/?l`). It stays in the stack only as the host-tool provider it already is. | 9front |
| **Jehanne** as port reference | Harvey-derived sibling, but no completed aarch64 port surfaced (absence-of-evidence, MEDIUM). | 9front `sys/src/9/arm64` |
| Writing `7c` from scratch / adapting `5c` by hand | 9front's 7c is a decade of maintained, shipped correctness (RPi3/4, i.MX8, LX2K, qemu all build with it). Re-deriving A64 codegen from 5c is a multi-month detour with silent-miscompilation risk. | Import 9front 7c |
| Harvey's retired Alpha "7" files (`sys/src/libmach/alpha/7.out.h`, `alphaobj.c`) coexisting blindly with arm64 7 imports | Both claim letter 7 and the filename `7.out.h`; 9front solved this by deleting Alpha. Harvey must either retire alpha's libmach entries or namespace one of them, or `setmach`/`mkfile` rules will collide. | Decide in the toolchain phase; follow 9front (retire alpha) unless there's a stated reason to keep it |
| qemu `-M raspi4` | Newer and less complete than raspi3b in qemu; only relevant to Pi hardware, which is Out of Scope this milestone. | `-M virt` |

## Stack Patterns by Variant

**If building the toolchain as host tools (the Harvey pattern):**
- Model `sys/src/cmd/7c/BUILD` on `sys/src/cmd/6c/BUILD`: plan9port `yacc` for `cc.y`, `9c -I../cc …` over the shared `../cc/*.c` frontend + 7c's own files, `9l -o 7c`, install to `$HARVEY_LINUX_BIN` (and the per-OS/arch hostbin dirs per the existing `.build/hostbin-<os>-aarch64` convention).
- Because 9front's 7c mkfile lists `../cc/compat.h` and Harvey's `cc` has a `compat` **directory** + `compat.c`, expect a small reconciliation here (see Version Compatibility).
- 7a's BUILD mirrors 6a's trivially (`yacc a.y; 9c *.c; 9l`).

**If the namespace (in-VM) build compiles the arm64 target:**
- `build_arm64` in `build/scripts/linux-build:63` and `build/scripts/build:76` already does `for(i in /sys/src/cmd/7?)` + `objtype=arm64 mk install` — importing into `sys/src/cmd/7{ a,c,l }` + `arm64/mkfile` + `sys/src/libc/arm64` plugs straight into existing wiring. No new build plumbing needed beyond the aux tool and the kernel dir.

**If booting the kernel on qemu:**
- Follow 9front's arm64 mkfile link line: `$LD -o 9qemu -T$loadaddr -l …` with `kzero=0xffffffff80000000`, `loadaddr=0xffffffffc0100000`, then `aux/aout2uimage -Z$kzero 9qemu` → `9qemu.u`; boot `qemu-system-aarch64 -M virt -kernel 9qemu.u -serial stdio`. Single CPU first — 9front's bcm64 SMP uses Pi spin tables (`SPINTABLE` + `sev()`); on virt the clean mechanism is PSCI from the qemu DTB, which is a phase-level research item, not a milestone blocker.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| 9front `cmd/7c` | Harvey `sys/src/cmd/cc` frontend | **Drift surface #1.** 9front 7c's mkfile requires `../cc/compat.h` and `../cc/mkfile.port`; Harvey's cc has `compat.c` + a `compat/` dir and its own `cc.h`. Reconcile before expecting 7c to build — either sync 9front's cc pieces or adapt 7c to Harvey's frontend. Harvey's 6c additionally has `div.c`/`sys.c` that 9front 7c lacks — file-list diffs are expected, not a defect. |
| 9front `cmd/7l` | Harvey `../cc/compat` | **Drift surface #2.** 7l mkfile has `compat.$O: ../cc/compat` and a `dyn.c` (dynamic linking). If Harvey's 6l lacks `dyn.c`, either drop `dyn.$O` from 7l's OFILES (Harvey links statically) or import the cc/compat support it needs. |
| 9front `libmach` 7 files | Harvey libmach alpha "7" | **Collision.** Both use `7.out.h`. 9front deleted Alpha; Harvey still has `alpha/7.out.h`, `alphaobj.c`, `alphadb.c`, and the setmach `"alpha"` entry. Retire or namespace before import. |
| 9front `arm64/include/ureg.h` | 9front libmach `7.c` (`#include "/arm64/include/ureg.h"`) | Absolute include from repo root — works only if the header lands at exactly `arm64/include/ureg.h`. Keep that path. |
| `aout2uimage` | Harvey libmach | Needs `crackhdr` to recognize MARM64 (`archtab[MARM64] = IH_ARCH_ARM64`) — i.e., depends on the libmach import landing first. Sequence phases accordingly. |
| 9front `libc/arm64` asm | Harvey `libc/port` conventions | 9front libc has accumulated 9front-only APIs (e.g., its own `atomic.s` helpers). Expect a handful of symbols with no Harvey counterpart; audit against Harvey's `sys/include/libc.h` during the libc phase. MEDIUM confidence — not diffed file-by-file here. |

## Sources

- `github.com/9front/9front` (branch `front`; mirror of canonical `git.9front.org/plan9front/plan9front`) — direct directory/file fetches: `sys/src/cmd/7a`, `sys/src/cmd/7c/mkfile`, `sys/src/cmd/7l/mkfile`, `sys/src/libc/arm64/`, `sys/src/libmach/{7.c,7db.c,7obj.c,setmach.c}`, `sys/src/9/arm64/{mkfile,qemu,mem.h,uartqemu.c,main.c…}`, `sys/src/9/bcm64/{mkfile,main.c,dat.h}`, `sys/src/9/lx2k/`, `sys/src/cmd/aux/aout2uimage.c`, `arm64/include/` — primary evidence (seam tier: LOW provider, content directly verified).
- `github.com/0intro/9-cc` — `src/cmd/` listing (confirms host-ported 7a/7c/7l), `src/cmd/7c/` listing, `src/libmach/` listing (no 7-object support), `NOTICE` (MIT text) — primary evidence.
- `github.com/9fans/plan9port` — `src/cmd/` listing (no target compilers) — primary evidence.
- Harvey tree (local): `LICENSE`, `LICENSE.gpl`, `LICENSE.old`, `sys/src/cmd/` listing, `sys/src/cmd/6c/BUILD`, `6a/BUILD`, `sys/src/BUILDTOOLCHAIN`, `sys/src/libc/`, `sys/src/libmach/` (+ `alpha/7.out.h`, `setmach.c`), `sys/include/mach.h` (`MARM64`), `arm64/` (empty `bbin/`), `amd64/mkfile`, `build/scripts/linux-build` (`build_arm64`), `build/scripts/build`, `sys/src/cmd/unix/9cc/README` — primary evidence.
- Wikipedia "Plan 9 from Bell Labs" — 2021 MIT relicense timeline (corroborating, MEDIUM).
- 9fans Topicbox "licence question" — 9front MIT statement (corroborating, MEDIUM).
- 9fans Topicbox "RPi in QEMU" — mixed results booting Pi kernels under qemu (corroborating the virt-over-raspi recommendation, LOW).

---
*Stack research for: Plan 9-family aarch64 porting (Harvey OS)*
*Researched: 2026-10-30*
