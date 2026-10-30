---
last_mapped_commit: bf084ee78de58b5f05b98235bb6e6887fde6e8c4
last_mapped_at: 2026-10-30
---
# Codebase Concerns

**Analysis Date:** 2026-10-30

## Project Vitality

**Upstream dormant/archived:**
- Issue: Last commit is 2022-03-30 (`git log` — "Updating commands doc to use https instead of git"). The upstream Harvey-OS organization archived its repositories; this fork (`requaos/harvey`) has had no activity in ~4.5 years. No security patches, no CI verification on modern toolchains, no community review.
- Files: entire tree; `build/build.bash`, `build/Dockerfile`
- Impact: Any build/toolchain drift (gcc/clang versions, qemu, expect, Ubuntu base image) is unlikely to be fixed upstream. Security issues in TLS/IP stack (below) have no upstream remediation path.
- Fix approach: Treat repo as a self-maintained fork. Budget for local toolchain pinning (Docker) and own any security work.

## Tech Debt

**Two parallel kernel trees (9 vs 9k):**
- Issue: The tree carries both the legacy Plan 9 kernel ports (`sys/src/9/`: bcm, kw, loongson, loongson64, mtx, omap, pc, pcboot, ppc, rb, teg2, vt4, vt5) and the Harvey 64-bit kernel (`sys/src/9k/`: port, k10, 386, ip, boot). Fixes landed in one tree are not propagated to the other (e.g. `sys/src/9/ip/tcp.c` and `sys/src/9k/ip/tcp.c` both contain the same unfixed "sloppy treatment of overflow cases" TODO at line 2049).
- Files: `sys/src/9/`, `sys/src/9k/`
- Impact: Double maintenance surface; bugs fixed in `9k` remain in `9` and vice versa; contributors can't tell which tree is canonical.
- Fix approach: Declare `sys/src/9k/` canonical for amd64 work; either delete or clearly quarantine `sys/src/9/` legacy ports.

**Half-finished architecture ports:**
- Issue: Several arch directories are skeletal. `riscv64/` contains only `include/` and an `mkfile` (no kernel at all). `amd64/` is only `include/` + `mkfile`. `arm/`, `mips/`, `power/`, `sparc/`, `spim/` are header-and-fragments only. Kernel ports like `sys/src/9/kw/cga.c` have stubbed-out hardware access (`#define inb(x) 0 /* TODO */`, `#define outb(x, y) /* TODO */` at lines 36–37).
- Files: `riscv64/`, `amd64/`, `arm/`, `mips/`, `mips64/`, `power/`, `power64/`, `sparc/`, `spim/`, `spim64/`, `sys/src/9/kw/cga.c`
- Impact: Dead code that still gets grep'd, tarred into build archives (`build/build.bash` tars the whole repo into `harvey.tgz`), and confuses navigation.
- Fix approach: Prune abandoned ports to a `attic/` directory or drop them; keep only amd64 (9k/k10) and any port with an active maintainer.

**Kernel memory allocator FIXME:**
- Issue: `sys/src/9k/port/qmalloc.c:249` carries a commented-out `/* FIXME: (ignore for now)` guard — the `nbytes == 0` check is inside a comment block that's partially disabled, so zero-size allocation behavior depends on the exact comment state. This is the core kernel allocator.
- Files: `sys/src/9k/port/qmalloc.c`
- Impact: Ambiguous semantics of `malloc(0)` in the kernel; risk of nil-pointer derefs in callers assuming non-nil.
- Fix approach: Decide the contract (return nil vs. unique pointer), uncomment/fix the guard, and audit callers.

**`crap.c` in the amd64 kernel:**
- Issue: `sys/src/9k/k10/crap.c` is a real, compiled kernel source file (boot-parameter parsing) whose name openly flags it as tech debt. It contains a large commented-out `Conf conf` block and hand-rolled parsing of the boot line at `CONFADDR`.
- Files: `sys/src/9k/k10/crap.c`
- Impact: Boot configuration parsing lives in a file everyone is afraid to touch.
- Fix approach: Rename to `bootconf.c`, remove dead blocks, document the CONFADDR ABI.

**Third-party code frozen in tree:**
- Issue: Ghostscript (AFPL-licensed, pre-GPL-era, `sys/src/cmd/gs/`), libpng with MMX assembler paths (`pnggccrd.c`, `pngvcrd.c`), antiword, apeg (`sys/src/ape/`) are vendored snapshots from ~2002 with dozens of upstream `HACK`/`FIXME` markers (85 FIXME hits, most HACK hits live under `sys/src/cmd/gs/`). The largest C files in the repo are all vendored code (`sys/src/cmd/gs/icclib/icc.c` at 12,776 lines, `gdevupd.c` at 7,642 lines).
- Files: `sys/src/cmd/gs/`, `sys/src/cmd/aux/antiword/`, `sys/src/ape/`
- Impact: Known CVE-era code with no update path; the gs jpeg/pdf drivers have documented temporary hacks (`gxclrect.c:540`, `gdevpdfi.c:407`).
- Fix approach: Quarantine as "contrib, unmaintained"; don't ship in default builds; document that security bugs here are WONTFIX.

**Fragile bootstrap build:**
- Issue: `build/build.bash` and `build/build-usb.bash` build Harvey by downloading a `9legacy.iso` from a GitHub release URL, booting it in `qemu-system-i386` under an `expect` script that pattern-matches boot prompts (`expect -exact "Selection:"`, sleeps, hard-coded vga answers like `1280x1024x32`). `build/BUILDTOOLCHAIN` and `BUILD_ON_UNIX` describe a manual plan9port + custom `9-cc` toolchain assembled by hand with `ln -s` tricks.
- Files: `build/build.bash`, `build/build-usb.bash`, `build/BUILD_IN_DOCKER`, `BUILD_ON_UNIX`, `sys/src/BUILDTOOLCHAIN`, `sys/src/RUN_BUILD_IN_PRIVATE_NAMESPACE`
- Impact: Build breaks if the ISO URL moves, qemu prompt text changes, or `expect` timing shifts (explicit `expect -timeout 600`). Host-build instructions reference paths that don't exist in this repo layout (`harvey/harvey/linux_amd64/bin`).
- Fix approach: Prefer the Docker path (`build/Dockerfile`, `build/BUILD_IN_DOCKER`) as the only supported build; pin toolchain versions; replace the expect script with a serial-console automated install.

**Deprecated license/notice files kept at root:**
- Issue: `LICENSE.old` (Lucent Public License 1.02) and `NOTICE.old` (© 2002 Lucent Technologies) remain at repo root alongside `LICENSE`/`NOTICE`. The README explains rights transferred to the Plan 9 Foundation, but three additional license files (`LICENSE.afpl`, `LICENSE.gpl`, `LICENSE.lucida`) carve out exceptions for ghostscript and fonts.
- Files: `LICENSE.old`, `NOTICE.old`, `LICENSE.afpl`, `LICENSE.gpl`, `LICENSE.lucida`
- Impact: License audit ambiguity — distributors must read 6 license files to determine what's redistributable (Lucida fonts are NOT redistributable outside Plan 9 per `LICENSE.old`).
- Fix approach: Move historical licenses to `adm/legal/` and add a single `LEGAL.md` summarizing current status.

## Known Bugs

**ether2114x mode-block handling unimplemented:**
- Symptoms: Driver prints `FIXME: handle type 4 mode blocks where cmd.active_invalid != 0` at runtime instead of handling the condition.
- Files: `sys/src/9/pc/ether2114x.c:1038`, `sys/src/9/mtx/ether2114x.c:1011`
- Trigger: Tulip-style NICs emitting type-4 mode blocks with active_invalid set.
- Workaround: None — packet descriptor handling is skipped.

**CIFS/SMB servers with acknowledged-broken paths:**
- Symptoms: `sys/src/cmd/cifs/trans2.c:361` — `T2setfilelength` marked `/* FIXME: maybe broken, needs testing */`; DFS share flags commented out with `// FIXME!` at `sys/src/cmd/cifs/cifs.c:70-71`; padding/resume-key order uncertain at `sys/src/cmd/cifs/trans.c:736`; `sys/src/cmd/aquarela/smbcomopen.c:413` guesses open mode and header wordcount ("unsure of this constant, maybe should be 3").
- Files: `sys/src/cmd/cifs/`, `sys/src/cmd/aquarela/`
- Trigger: Set-EOF operations over CIFS; DFS referrals; some SMB open modes.
- Workaround: Avoid write/truncate via these servers.

**TCP overflow handling sloppy:**
- Symptoms: `sys/src/9/ip/tcp.c:2049` and identical copy `sys/src/9k/ip/tcp.c:2049`: `/* TODO: fix sloppy treatment of overflow cases here.` Sequence-number wrap arithmetic is acknowledged-incorrect.
- Files: `sys/src/9/ip/tcp.c`, `sys/src/9k/ip/tcp.c`
- Trigger: Long-lived connections crossing 2^32 sequence space.
- Workaround: None in-tree.

**ICMPv6 unknown-type handling is guesswork:**
- Symptoms: `sys/src/9k/ip/icmp6.c:596` — `return 1; /* TODO: unknown, presumed valid; why? */`; line 661 has `/* TODO: fill in */` for unimplemented ICMPv6 cases.
- Files: `sys/src/9k/ip/icmp6.c`, `sys/src/9/ip/icmp6.c`
- Trigger: Receipt of unknown/unexpected ICMPv6 types.
- Workaround: None.

## Security Considerations

**TLS stack caps at TLS 1.2 and still accepts SSL 3.0:**
- Risk: `sys/src/libsec/port/tlshand.c:143-147` defines `ProtocolVersion = TLS12Version` as "maximum version we speak" — no TLS 1.3. Worse, `sys/src/9k/port/devtls.c:27-33` sets `MinProtoVersion = 0x0300` (SSL 3.0), meaning the kernel TLS device will accept SSL3 handshakes (POODLE-class downgrade exposure), and `tlshand.c` retains explicit SSL3 handling at lines 953, 1269, 1481, 2019.
- Files: `sys/src/libsec/port/tlshand.c`, `sys/src/9k/port/devtls.c`, `sys/src/9/port/devtls.c`
- Current mitigation: None; SSL3 code paths are live.
- Recommendations: Raise `MinProtoVersion` to TLS10Version minimum (ideally TLS12), delete SSL3 branches, plan TLS 1.3 support or document "no modern TLS".

**Broken/legacy cipher suites enabled:**
- Risk: `sys/src/libsec/port/tlshand.c:200-267` enumerates `TLS_RSA_WITH_NULL_MD5`, `TLS_RSA_WITH_NULL_SHA`, `TLS_RSA_WITH_RC4_128_MD5`, `TLS_RSA_WITH_RC4_128_SHA`, `TLS_RSA_WITH_DES_CBC_SHA`, `TLS_RSA_WITH_3DES_EDE_CBC_SHA`; the algorithm table at lines 263–267 actively maps `rc4_128` and `3des_ede_cbc`. Line 1522 shows NULL-MD5 enabled (`1,`). No AEAD ciphers (no AES-GCM, though chacha20 exists in `sys/src/libsec/port/chacha.c` but isn't wired into TLS).
- Files: `sys/src/libsec/port/tlshand.c`, `sys/src/libsec/port/rc4.c`, `sys/src/libsec/port/des.c`, `sys/src/libsec/port/md4.c`, `sys/src/libsec/port/md5.c`
- Current mitigation: Cipher negotiation ordering only.
- Recommendations: Remove NULL/RC4/DES/3DES from the offered list; add AES-GCM or ChaCha20-Poly1305 suites.

**IPsec ESP missing/unverified:**
- Risk: ESP exists only in the legacy tree (`sys/src/9/ip/esp.c`) and carries `TODO: verify aes algorithms` at line 6 — AES modes in IPsec are unverified. The Harvey kernel IP stack (`sys/src/9k/ip/`) has no `esp.c` at all — IPsec ESP is effectively unavailable on the primary kernel.
- Files: `sys/src/9/ip/esp.c`, `sys/src/9k/ip/` (absent)
- Current mitigation: None.
- Recommendations: Either port and audit ESP into 9k or document IPsec as unsupported on 9k.

**Unsafe string handling in kernel:**
- Risk: 76 hits for `strcpy`/`sprintf`/`strcat` in `sys/src/9k/` alone. Samples: `sys/src/9k/port/devsrv.c:170` `strcpy(sname, name);` on service names, `sys/src/9k/port/chan.c:892,971` `strcpy(up->errstr, ...)`. A bounded `kstrcpy` exists (`sys/src/9k/port/chan.c:61`) but is used inconsistently (e.g. `sdaoe.c:211` uses it, `devsrv.c` doesn't).
- Files: `sys/src/9k/port/devsrv.c`, `sys/src/9k/port/chan.c`, `sys/src/9k/port/devuart.c`
- Current mitigation: Partial — `kstrcpy` exists but adoption is spotty.
- Recommendations: Audit each unbounded call; standardize on `kstrcpy`/`snprint`; enable compiler warnings for `strcpy`.

**Boot trust & build provenance:**
- Risk: Build downloads `9legacy.iso.bz2` over HTTPS from a GitHub release with no checksum/signature verification (`build/build.bash:6-10`, `build/build-usb.bash`). QEMU is spawned with host networking and KVM where available.
- Files: `build/build.bash`, `build/build-usb.bash`
- Current mitigation: HTTPS transport only.
- Recommendations: Pin and verify a SHA-256 of the ISO; document threat model of the bootstrap environment.

## Performance Bottlenecks

**TCP retransmit/RTO logic dated:**
- Problem: `sys/src/9k/ip/tcp.c:2986` — `TODO: RFC 4138 F-RTO` — no forward RTO recovery; Reno-era congestion handling.
- Files: `sys/src/9k/ip/tcp.c`, `sys/src/9/ip/tcp.c`
- Cause: Stack never modernized past Plan 9 4e.
- Improvement path: Implement F-RTO and SACK; benchmark against loopback and 10G igbe/82598 paths.

**9P marshalling copies:**
- Problem: `sys/src/cmd/fossil/9p.c:427,551` — two `TODO: optimise this copy (in convS2M) away somehow` on the file server's hot path.
- Files: `sys/src/cmd/fossil/9p.c`
- Cause: convS2M copies every message into a staging buffer.
- Improvement path: Zero-copy marshalling or scatter-gather buffers; measure with fossil benchmarks first.

**Hard-coded NIC link speeds / features:**
- Problem: `sys/src/9/bcm/etherusb.c:486` — `edev->mbps = 100; /* TODO: get this from usbether */`; promiscuous/multicast/shutdown unimplemented (line 498); `sys/src/9/pc/ethervgbe.c:875` — 32-bit-only DMA addressing (`TODO: 64 bits ?`), forcing bounce buffering on >4GB systems.
- Files: `sys/src/9/bcm/etherusb.c`, `sys/src/9/pc/ethervgbe.c`, `sys/src/9/pc/ether82598.c`
- Cause: Drivers written for 32-bit/100Mbps era.
- Improvement path: Report real link state; add 64-bit DMA descriptors per-driver.

## Fragile Areas

**k10 low-level asm/entry code:**
- Files: `sys/src/9k/k10/l32p.s`, `sys/src/9k/k10/l64v.s`, `sys/src/9k/k10/l64syscall.s`, `sys/src/9k/k10/l64idt.s`, `sys/src/9k/k10/l64sipi.s`, `sys/src/9k/k10/trap.c`, `sys/src/9k/k10/mmu.c`
- Why fragile: Hand-written Plan 9 assembler (not gas); SYSCALL/SYSRET path and IDT setup have zero test coverage; a 2022 commit ("Fix 9k build problem with gpf vector", `63e031c5d`) shows regressions here were found by accident, not tests. 46 `panic()` calls in k10 with minimal recoverability.
- Safe modification: Change one vector/path at a time; always boot-test under qemu before real hardware; keep `rdmsr`-style defensive fixes (commit `2022-01-26 rdmsr: Don't panic on user GPF`) as the pattern.
- Test coverage: None — no automated boot test in tree.

**ACPI implementation:**
- Files: `sys/src/9k/k10/devacpi.c` (1,788 lines — largest k10 source), `sys/src/9k/k10/mpacpi.c`, `sys/src/libaml/`
- Why fragile: AML interpreter is a Harvey-specific work-in-progress; ACPI table parsing interacts with MP tables (`mp.c`) and IOAPIC setup where a misparse hangs the boot before console output.
- Safe modification: Add `debugacpi` prints gated by boot param; validate against qemu's default tables before touching real BIOS quirks.
- Test coverage: None.

**MP/CPU startup:**
- Files: `sys/src/9k/k10/mp.c` (487 lines), `sys/src/9k/k10/sipi.c`, `sys/src/9/pc/mp.c:698` (`always use cpu 0. (TODO)` — interrupt routing hard-wired to CPU0 in legacy tree)
- Why fragile: SIPI bring-up is timing-sensitive; legacy tree pins interrupts to BSP.
- Safe modification: Log LAPIC IDs at boot; keep `maxcpu` boot param working as a fallback.
- Test coverage: None.

**Fossil file server:**
- Files: `sys/src/cmd/fossil/` (`fs.c:231` "should be rewritten to eliminate most of the duplication", `9fsys.c:1589` "8K is a hack; use the actual block size")
- Why fragile: Archival-storage semantics; a corruption bug is unrecoverable for archives. Duplicated fsys logic invites fix-one-miss-one.
- Safe modification: Always test against a scratch fossil partition (`fossil.tar.gz` test artifact referenced in `sys/src/cmd/fossil/mkfile:126`); never change on-disk format code without a dump/restore round-trip.
- Test coverage: Only ad-hoc tester binaries (`sys/src/cmd/fossil` mkfile targets, `sys/src/cmd/upas/fs/tester.c`-style harnesses elsewhere).

## Scaling Limits

**Network stack:**
- Current capacity: IPv4+IPv6 with medium abstraction; drivers top out at 1 GbE realistically (`etherigbe`, `ether82563`), 10GbE driver exists (`ether82598.c`) but leaks the controller on detach (`freemem(ctlr); // TODO` at `sys/src/9k/386/ether82598.c:810`).
- Limit: No multiqueue, no RSS, no TCP offload; single-flow hashing.
- Scaling path: Multiqueue support in `etherif` + per-queue locks; fix 82598 teardown.

**Memory model:**
- Current capacity: k10 is 64-bit but drivers with 32-bit DMA assumptions (`ethervgbe.c:875`) constrain usable I/O memory.
- Limit: `qmalloc`'s quicklist/rover design (`sys/src/9k/port/qmalloc.c`) scales poorly with many CPUs — single `MLOCK` around the tail allocator.
- Scaling path: Per-CPU magazines or slab for common sizes.

## Dependencies at Risk

**Ubuntu 21.10 Docker base:**
- Risk: `build/Dockerfile:15` — `FROM ubuntu:21.10` (Impish) went EOL July 2022; apt mirrors moved to old-releases, so `apt-get -y update` will fail on fresh builds.
- Impact: The only reproducible build path bit-rots; new contributors can't build the image without editing the Dockerfile.
- Migration plan: Rebase to `ubuntu:22.04`/`24.04` LTS or `debian:stable`; pin apt packages.

**9legacy bootstrap ISO:**
- Risk: `build/build.bash` depends on `https://github.com/Harvey-OS/harvey/releases/download/9legacy/9legacy.iso.bz2` — a release artifact on an archived org; if GitHub releases are pruned or the repo is removed, the build stops.
- Impact: No bootstrap → no build, since the Harvey toolchain (6a/6c/6l) must be built inside a Plan 9 environment.
- Migration plan: Mirror the ISO into this repo's releases or a checksum-pinned artifact store; long-term, finish the Unix-hosted build (`BUILD_ON_UNIX`, `sys/src/BUILDTOOLCHAIN`) so Plan 9 bootstrap isn't needed.

**Vendored Ghostscript/libpng/jpeg:**
- Risk: AFPL-era ghostscript + ancient libpng with x86 MMX asm (`pnggccrd.c`, `pngvcrd.c`) — won't build for non-x86 and carry years of known CVEs.
- Impact: `gs` can't be shipped in security-sensitive contexts; blocks clean riscv/aarch64 userland builds if enabled.
- Migration plan: Remove from default mkfile targets; mark `sys/src/cmd/gs/` unmaintained; consider deletion since rendering is non-core.

## Missing Critical Features

**TLS 1.3:**
- Problem: `ProtocolVersion = TLS12Version` is the ceiling (`sys/src/libsec/port/tlshand.c:147`). Modern hosts increasingly require 1.3.
- Blocks: Interop with current HTTPS endpoints from `webfs`, `hget`, `tlsclient`-style tools.

**SMP network drivers / 10GbE completeness:**
- Problem: See Scaling Limits; `ether82598` teardown leak and no multiqueue.
- Blocks: Using Harvey as a performant network server.

**riscv64 kernel:**
- Problem: `riscv64/` has headers and `mkfile` referencing `jc/jl/ja` compilers but no kernel sources at all; RISC-V support is aspirational.
- Blocks: Any RISC-V bring-up.

**Automated testing:**
- Problem: No test runner, no CI config in tree, no unit-test framework for kernel or libc. Existing "tests" are standalone binaries (`sys/src/cmd/aquarela/test*.c`, `sys/src/cmd/wikifs/testwrite.c`, `sys/src/libsec/port/*test.c`) that must be built and run by hand inside a running Harvey system.
- Blocks: Regression detection for any change; CI.

## Test Coverage Gaps

**Kernel (entire `sys/src/9k/`):**
- What's not tested: Everything — allocators (`qmalloc.c`), channel/refcount logic (`chan.c`), IP stack, TLS device, trap/syscall entry.
- Files: `sys/src/9k/port/`, `sys/src/9k/k10/`, `sys/src/9k/ip/`
- Risk: Regressions (e.g. the 2022 gpf-vector build break) are only caught by manual booting.
- Priority: High

**libsec / devtls:**
- What's not tested: TLS handshake state machine (`tlshand.c` is 2000+ lines with version/cipher branches for SSL3–TLS1.2); only primitive self-tests exist (`md5test.c`, `hmactest.c`, `chachatest.c`, `rsatest.c` in `sys/src/libsec/port/` and duplicated under `sys/src/cmd/unix/drawterm/libsec/`).
- Files: `sys/src/libsec/port/tlshand.c`, `sys/src/9k/port/devtls.c`
- Risk: Silent downgrade/negotiation bugs in the only network security layer.
- Priority: High

**Storage stack (fossil/venti/sd):**
- What's not tested: Fossil fsys duplication noted at `sys/src/cmd/fossil/fs.c:231`; no on-disk format regression suite; venti has scattered test binaries but no runner.
- Files: `sys/src/cmd/fossil/`, `sys/src/cmd/venti/`, `sys/src/9k/port/devsd.c`, `sys/src/9k/port/sd*.c`
- Risk: Data corruption in archival storage discovered only after the fact.
- Priority: High

**Userland commands:**
- What's not tested: Most of `sys/src/cmd/` — test files exist for a handful of tools only (aquarela, wikifs, upas, 9nfs, gs zcid, jtagfs).
- Files: `sys/src/cmd/`
- Risk: Command regressions go unnoticed across builds.
- Priority: Medium

---

*Concerns audit: 2026-10-30*
