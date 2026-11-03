---
last_mapped_commit: fa0ed761b9667411e8d93797bdbb79ba0598fa2f
last_mapped_at: 2026-11-03
---
# Codebase Concerns

**Analysis Date:** 2026-11-03

## Project Vitality

**Upstream dormant/archived; this fork is now the maintained line:**
- Issue: Upstream Harvey-OS ended 2022-03-30 (`git log` — "Updating commands doc to use https instead of git"); the Harvey-OS organization archived its repositories. This checkout is no longer dormant: Phase 1 (Nix dev environment), Phase 2 (aarch64 userspace port), and Phase 5 (one-command r9-kernel boot: `flake.nix` `inputs.r9`, `nix/boot-r9.sh`, `nix/smoke-r9.sh`, the `build/aarch64/` supply chain, and the `.github/workflows/r9-shell.yml` CI leg) landed Oct–Nov 2026. AGENTS.md declares this repo the maintained fork.
- Files: entire tree; `flake.nix`, `aarch64/`, `build/aarch64/`, `build/build.bash`, `build/Dockerfile`
- Impact: No upstream remediation path for anything — security issues in the TLS/IP stack (below), toolchain drift, and the vendored 9front compiler (`sys/src/cmd/7a|7c|7l`) are all owned locally. The vendored 7a/7c/7l pin (`350266104f1fed81c78c3d05fa44f523bec0ae4d`) has no update watch.
- Fix approach: Continue treating the repo as self-maintained; budget for owning security work and vendored-pin refreshes.

## Tech Debt

**`aarch64/include/u.h` FPdbleword uses 64-bit halves — breaks all float math introspection on aarch64:** *(HIGH)*
- Issue: `aarch64/include/u.h:54-61` defines `union FPdbleword { double x; struct { ulong lo; ulong hi; }; }` where `ulong` is 64-bit on aarch64 (`unsigned long`, line 5). The union is 16 bytes; `hi` sits at byte offset 8 — outside the 8-byte `double`. Harvey's portable libc expects 32-bit halves: `sys/src/libc/port/frexp.c` (`e = (x.hi >> SHIFT) & MASK`, `SHIFT=20`), `sys/src/libc/port/nan.c` (`isNaN`/`isInf`/`Inf`/`NaN` read and write `a.hi`/`a.lo`), and `sys/src/libc/fmt/fltfmt.c:94` (`frexp(f, &e)` — the `%e`/`%f`/`%g` path). The working 64-bit reference, `amd64/include/u.h:49-56`, uses `uint lo; uint hi;`. On aarch64: `frexp` reads the exponent from out-of-union stack bytes, `Inf()`/`NaN()` write bytes that don't overlap `x` and return an uninitialized double, and all float formatting is garbage. Every other arch header (386, arm) pairs `ulong lo/hi` with a 32-bit `ulong`, so the pattern is correct only on 32-bit arches; `riscv64/include/u.h` carries the same latent bug but that port is skeletal.
- Files: `aarch64/include/u.h:54-61`, `amd64/include/u.h:49-56` (correct reference), `sys/src/libc/port/frexp.c`, `sys/src/libc/port/nan.c`, `sys/src/libc/fmt/fltfmt.c`, `riscv64/include/u.h`
- Impact: Silent miscompilation of all FP introspection in every aarch64 binary linked against `aarch64/lib/libc.a`; float printf output and NaN/Inf checks are wrong. Every binary `build/aarch64/subset-build.sh` produces is built with this header (`aarch64/bin` and `aarch64/lib` are now gitignored build outputs — `.gitignore:19-22` — so the defect is regenerated fresh on every build, not just frozen in committed artifacts). The 05-12 smoke (`build/aarch64/smoke-r9.expect`) never prints a float, so the shipped gate does not see it.
- Fix approach: Change `aarch64/include/u.h` FPdbleword to `uint lo; uint hi;` (match amd64), rebuild libc + fmt, add a smoke test printing a float on aarch64. Apply the same fix to `riscv64/include/u.h` when that port revives.

**Build script mutates tracked source files at build time:**
- Issue: `nix/build.sh:64-68` runs `$GNU_SED -i` on tracked files (`sys/src/9/port/portmkfile`, `sys/src/9k/mk/portmkfile`, `sys/src/9/port/mkroot`, `sys/src/9/port/mkrootall`, `sys/src/9k/mk/mkroot`, `sys/src/9k/mk/mkrootall`) to rewrite `aux/mklatinkbd`→`mklatinkbd` and `aux/data2s`→`data2s` on every build. The edits are idempotent but leave the tree dirty and contradict AGENTS.md's "in-tree fixes are preferred over external patch stacks" — these are in-tree fixes applied at build time instead of being committed.
- Files: `nix/build.sh:61-68`, the six mkfiles above
- Impact: `git status` noise after every build; interrupted/racing builds edit sources under the reader; the fixup rationale lives only in a script comment.
- Fix approach: Commit the six one-line edits and delete the sed block from `nix/build.sh`.

**`/usr/bin/grep` hardcoded across the aarch64 build scripts:** *(new, from 05-REVIEW IN-03)*
- Issue: Six scripts invoke `/usr/bin/grep` by absolute path: `build/aarch64/subset-build.sh:108,250`, `build/aarch64/stage-build.sh:40,117`, `build/aarch64/mkimage.sh:129,131`, plus the same pattern in `build/aarch64/vm-run.sh:45`, `run-gate.sh:99`, `pre-gate-build.sh:83`, `donor-vm-build.sh:85`, `subset-exec.sh:116`. The rationale (mkimage.sh:128) is that plan9 grep lacks `-q` — true — but `/usr/bin/grep` does not exist on NixOS-style Linux hosts, and the native-linux leg is a supported platform (`subset-build.sh:229-235` runs natively under `sudo unshare`; `subset-build.sh:250`'s `/usr/bin/grep -q 'SUBSET-BUILD-OK'` runs on BOTH legs). The devshell already provides GNU grep on PATH.
- Files: `build/aarch64/subset-build.sh`, `build/aarch64/stage-build.sh`, `build/aarch64/mkimage.sh`, `build/aarch64/vm-run.sh`, `build/aarch64/run-gate.sh`, `build/aarch64/pre-gate-build.sh`, `build/aarch64/donor-vm-build.sh`, `build/aarch64/subset-exec.sh`
- Impact: The composed boot (`nix run .#boot-r9` / `.#boot-r9-smoke`) fails on NixOS hosts at the first `/usr/bin/grep` call; on other Linux distros it silently picks up whatever grep the distro put there (busybox grep lacks `-q` on some builds).
- Fix approach: Resolve a host grep once at the top of each script (`GREP=$(command -v /usr/bin/grep || command -v grep)`) or drop the absolute path and rely on the devshell's PATH with `$PLAN9/bin` LAST.

**Two parallel kernel trees (9 vs 9k):**
- Issue: The tree carries both the legacy Plan 9 kernel ports (`sys/src/9/`: bcm, kw, loongson, loongson64, mtx, omap, pc, pcboot, ppc, rb, teg2, vt4, vt5) and the Harvey 64-bit kernel (`sys/src/9k/`: port, k10, 386, ip, boot). Fixes landed in one tree are not propagated to the other (e.g. `sys/src/9/ip/tcp.c` and `sys/src/9k/ip/tcp.c` both contain the same unfixed "sloppy treatment of overflow cases" TODO at line 2049). The nix build still patches both trees' mkfiles (`nix/build.sh:64-68`).
- Files: `sys/src/9/`, `sys/src/9k/`
- Impact: Double maintenance surface; bugs fixed in `9k` remain in `9` and vice versa; contributors can't tell which tree is canonical.
- Fix approach: Declare `sys/src/9k/` canonical for amd64 work; either delete or clearly quarantine `sys/src/9/` legacy ports.

**Half-finished architecture ports:**
- Issue: Several arch directories are skeletal. `riscv64/` contains only `include/` and an `mkfile` (no kernel at all). `amd64/` ships headers + `mkfile` only in git (its `bin/`/`lib/` are build outputs). `arm/`, `mips/`, `power/`, `sparc/`, `spim/` are header-and-fragments only. Kernel ports like `sys/src/9/kw/cga.c` have stubbed-out hardware access (`#define inb(x) 0 /* TODO */`, `#define outb(x, y) /* TODO */` at lines 36–37). Note: `aarch64/` is NOT in this category anymore — it has real headers, mkfile, a building userland subset (Phase 2), and a booted shell on r9 (Phase 5); see its own entries below.
- Files: `riscv64/`, `amd64/`, `arm/`, `mips/`, `mips64/`, `power/`, `power64/`, `sparc/`, `spim/`, `spim64/`, `sys/src/9/kw/cga.c`
- Impact: Dead code that still gets grep'd, tarred into build archives (`build/build.bash` tars the whole repo into `harvey.tgz`), and confuses navigation.
- Fix approach: Prune abandoned ports to a `attic/` directory or drop them; keep amd64 (9k/k10), aarch64 (active), and any port with an active maintainer.

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
- Impact: Known CVE-era code with no update path; the gs jpeg/pdf drivers have documented temporary hacks (`gxclrect.c:540`, `gdevpdfi.c:407`). libpng's x86 MMX asm also blocks clean aarch64 userland builds if `gs` is ever enabled for `objtype=aarch64`.
- Fix approach: Quarantine as "contrib, unmaintained"; don't ship in default builds; document that security bugs here are WONTFIX.

**Legacy qemu+expect bootstrap build retained for ISO production:**
- Issue: `build/build.bash` and `build/build-usb.bash` build Harvey by downloading a `9legacy.iso` from a GitHub release URL, booting it in `qemu-system-i386` under an `expect` script that pattern-matches boot prompts (`expect -exact "Selection:"`, sleeps, hard-coded vga answers like `1280x1024x32`). This path is now wrapped as `nix run .#iso` (`nix/iso.sh` execs `build/build.bash`) — it is no longer the dev build path (that is `.#setup` → `.#toolchain` → `.#build`, a native namespace build needing no qemu bootstrap), but it remains the only ISO producer.
- Files: `build/build.bash`, `build/build-usb.bash`, `nix/iso.sh`, `build/BUILD_IN_DOCKER`, `BUILD_ON_UNIX`
- Impact: ISO generation breaks if the ISO URL moves, qemu prompt text changes, or `expect` timing shifts (explicit `expect -timeout 600`).
- Fix approach: Replace the expect script with a serial-console automated install; long-term, produce the ISO from the namespace build artifacts directly.

**Deprecated license/notice files kept at root:**
- Issue: `LICENSE.old` (Lucent Public License 1.02) and `NOTICE.old` (© 2002 Lucent Technologies) remain at repo root alongside `LICENSE`/`NOTICE`. The README explains rights transferred to the Plan 9 Foundation, but three additional license files (`LICENSE.afpl`, `LICENSE.gpl`, `LICENSE.lucida`) carve out exceptions for ghostscript and fonts.
- Files: `LICENSE.old`, `NOTICE.old`, `LICENSE.afpl`, `LICENSE.gpl`, `LICENSE.lucida`
- Impact: License audit ambiguity — distributors must read 6 license files to determine what's redistributable (Lucida fonts are NOT redistributable outside Plan 9 per `LICENSE.old`).
- Fix approach: Move historical licenses to `adm/legal/` and add a single `LEGAL.md` summarizing current status.

**Stale comment/header drift in the nix layer:** *(minor)*
- Issue: `nix/toolchain.sh:1` header says "Build the Plan 9 cross toolchain (6a/6c/6l, 8a/8c/8l, cpp, aux) and pcc" but `sys/src/BUILDTOOLCHAIN:10-12` now also builds `7a`/`7c`/`7l` (the vendored aarch64 toolchain) — the comment predates Phase 2. `nix/lima-harvey.yaml` header references artifact dir `linux_amd64/bin`, superseded by `.build/hostbin-<os>-<arch>/bin` (`nix/setup.sh:14`).
- Files: `nix/toolchain.sh:1`, `nix/lima-harvey.yaml`
- Impact: Cosmetic; misleads readers about what the toolchain app produces.
- Fix approach: Update both comments.

**Documentation drift: AGENTS.md's embedded stack snapshot predates the Nix/aarch64 era:**
- Issue: AGENTS.md embeds `.planning/codebase/STACK.md`, which has no mention of `flake.nix`, the `nix/` app layer (`setup`/`toolchain`/`build`/`iso` — the primary dev path since Phase 1), the `aarch64/` port tree and vendored 7a/7c/7l (Phase 2), or the Phase-5 `boot-r9`/`boot-r9-smoke` apps and `build/aarch64/` supply chain. STRUCTURE.md is current, but STRUCTURE.md is not embedded in AGENTS.md — agents reading only AGENTS.md get a stack picture describing the legacy bash/Docker build as the only path.
- Files: `AGENTS.md` (GSD:stack section), `.planning/codebase/STACK.md`
- Impact: Planning/execution agents guided by AGENTS.md may drive the deprecated Docker/qemu build instead of the flake apps.
- Fix approach: Refresh STACK.md from the tree (nix layer, vendored 9front toolchain, aarch64 arch dir, r9 composition); regenerate AGENTS.md.

**Expect drivers open the capture after spawn:** *(new, from 05-REVIEW IN-11; minor)*
- Issue: `build/aarch64/smoke-r9.expect:76-83` and `build/aarch64/drive-r9.expect:59-61` call `spawn` before `log_file` — output emitted in the spawn→log_file window is matched by expect but never written to the capture file.
- Files: `build/aarch64/smoke-r9.expect`, `build/aarch64/drive-r9.expect`
- Impact: In practice qemu boot output is slow enough that nothing is lost; the retained evidence log can theoretically be missing the first bytes of a run.
- Fix approach: Move `log_file` ahead of `spawn` (expect supports this).

**trace-syscalls.py leaks a socket per poll iteration:** *(new, from 05-REVIEW IN-05; minor)*
- Issue: `build/aarch64/trace-syscalls.py` (~:461-463 and ~:1002-1004) constructs a fresh `socket.socket(...).connect_ex(...)` per pass of the srv9 readiness loop and never closes it (up to 60 per run).
- Files: `build/aarch64/trace-syscalls.py`
- Impact: Harmless at this scale — fd pressure only.
- Fix approach: `with socket.socket(...) as s: s.connect_ex(...)`.

**Kernel/image reproducibility is same-path-only and git-dependent:** *(new, documented limitation)*
- Issue: `build/REPRODUCIBILITY.md` states the 9k kernel bit-reproducibility claim holds only for builds at the same checkout path (`sys/src/9k/mk/parse` embeds the absolute build path as `conffile`), and the KERNDATE derivation falls back to the wall clock when git metadata is absent (non-reproducible by design). The Phase-5 INT-03 claim is explicitly *process-level* — `bootfs.paq` bytes differ between checkouts at different HEAD commits (mkpaqfs embeds a time field); only behavior (marker sequence) is asserted, never image bytes.
- Files: `build/REPRODUCIBILITY.md`, `sys/src/9k/mk/parse`, `nix/boot-r9.sh:94-103`, `nix/smoke-r9.sh:98-107`
- Impact: Cross-host binary comparison is impossible; "reproducible from clean checkouts" means "the documented commands reproduce the green outcome," not bit-identity.
- Fix approach: None required short-term (documented honestly); long-term, strip/normalize embedded paths and mkpaqfs time fields if bit-identity becomes a goal.

## Known Bugs

**drive-r9.expect interactive sweep known-flake (unresolved):** *(new, from phase-05 deferred items)*
- Symptoms: The extended interactive driver wedged twice in early runs (2 of ~7): mid-sweep, at a prompt read, the typed line never completes — rc stays blocked in the cons read and no fork/exec follows (run A: `ls /bin` never started after the echo stage; run B: `echo r9delok` never answered after the DEL re-prompt). Six consecutive clean passes followed (four with a tick-side cons watchdog in place — never fired), so it does NOT reproduce under instrumentation. Phase-05 diffs do not touch the cons read/wake, note, scheduler, or timer paths; the shape sits in 05-08's cons-input wake machinery or below (qemu stdio/pty delivery, PL011 RX IRQ, the tick wake).
- Files: `build/aarch64/drive-r9.expect`, `build/aarch64/smoke-r9.expect` (shares the sweep shape), r9-side cons input path (out of this repo)
- Trigger: Not reproducible on demand; seen at prompt reads mid-sweep under qemu TCG.
- Workaround: Re-run. The D-14 known-flake policy class applies — a flaky sweep would erode the `.github/workflows/r9-shell.yml` CI claim, so debug-first when it recurs: reproduce with the tick-side watchdog (fire when `cons_rx_pending()` persists >2000 ticks), then the 05-08 register-dump recipe (PL011 FR/IMSC/CR + chardev logfile + `-trace pl011_*`).

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

**Build provenance: unverified downloads across both build paths:**
- Risk: The legacy ISO path downloads `9legacy.iso.bz2` over HTTPS from a GitHub release with no checksum/signature verification (`build/build.bash:6-10`). The nix/lima path provisions the guest VM by piping an unpinned installer (`curl ... https://install.determinate.systems/nix | sh`) and pulls an Ubuntu 24.04 cloud image whose `digest:` field is empty (`nix/lima-harvey.yaml` — comment says "fill after first run if desired; cloud images roll"). QEMU is spawned with host networking and KVM where available. The Phase-5 composition itself is better: the r9 kernel and nixpkgs arrive only as `flake.lock`-pinned store paths (rev + narHash), and CI pins the nix installer by 40-char SHA.
- Files: `build/build.bash`, `build/build-usb.bash`, `nix/lima-harvey.yaml`
- Current mitigation: HTTPS transport only; nixpkgs itself is properly pinned (`flake.lock` rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010` + narHash); r9 pinned at rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` + narHash.
- Recommendations: Pin and verify a SHA-256 of the 9legacy ISO; pin the lima image digest after first run; pin the Determinate installer version or install nix via the distribution.

**pkill teardown patterns kill foreign qemu processes:** *(new, from 05-REVIEW WR-07)*
- Risk: `nix/smoke-r9.sh:137` (EXIT trap) and `build/aarch64/drive-r9.expect:71` sweep survivors with `pkill -f '[q]emu-system-aarch64.*kernel-virt\.elf'` / `[q]emu-system-aarch64.*aarch64-unknown-none-elf` — matched by kernel-name CLASS, not by this run's identity. A developer's concurrent interactive `nix run .#boot-r9` (same `kernel-virt.elf`), or a parallel CI job on a shared runner, is killed by the gate's cleanup. `nix/smoke-r9.sh:134-136`'s own comment acknowledges the class ("a dev's interactive boot-r9 uses the same kernel, but never concurrently with the gate") — an assumption, not a guard. The `[q]` bracket correctly prevents pkill self-matching; the exposure is cross-process, not self-match.
- Files: `nix/smoke-r9.sh:129-141`, `build/aarch64/drive-r9.expect:63-72`, `build/aarch64/run-r9.sh:83-95` (the setsid/pgroup teardown that covers the common case correctly)
- Current mitigation: Process-group kill is primary on both drivers (`kill -KILL -- -$spawn_pid`); the broad pkill is only the fallback sweep. run-r9.sh already tracks `QEMU_PID`.
- Recommendations: Key the sweep on a per-run unique value — record the spawned qemu pid/pgid at launch and pkill on the run's unique capture-path/pidfile, or pass `-name "r9smoke-$$"` into qemu's argv and match on that.

**CI supply-chain rule applied inconsistently:** *(new, from 05-REVIEW IN-06)*
- Risk: `.github/workflows/r9-shell.yml` pins `DeterminateSystems/nix-installer-action` to a full 40-char SHA (`3138316df39ed29be04236d7ffc686fa525866aa`, per the T-05-24 rule documented in the header at lines 17-21) but leaves `actions/checkout@v4` tag-pinned at line 35 — the rule is applied narrowly. The job also has no `concurrency` group and no nix store cache, so every push/PR runs a full TCG rebuild + smoke serially (90-minute budget each).
- Files: `.github/workflows/r9-shell.yml:30-40`
- Current mitigation: `permissions: contents: read` (line 27-28); no secrets in scope.
- Recommendations: Pin checkout by SHA too (or document the scoped exception); add `concurrency: { group: r9-shell-${{ github.ref }}, cancel-in-progress: true`; consider a nix cache if runtime becomes a problem.

**Host-system mutation by the kernel build (Linux):**
- Risk: `nix/build.sh:95-102` sudo-copies build tools into the host's `/bin` (`cpp`, `bind`, `rc`, `6a`/`6c`/`6l`/`8a`/`8c`/`8l`) because pcc/rc hardcode `/bin` paths. There is no cleanup/uninstall, and `/bin/cpp` on distributions that ship one (Ubuntu: symlink into gcc) gets overwritten with Harvey's cpp.
- Files: `nix/build.sh:91-102`
- Current mitigation: Uses the setuid system sudo deliberately (comment at line 92); copies only when present.
- Recommendations: Track installed files and offer an uninstall; prefer bind-mounts inside the private namespace over persistent `/bin` writes; at minimum refuse to overwrite a pre-existing `/bin/cpp`.

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

**Frozen aarch64 ABI — enforcement exists but lives entirely in the r9 repo:** *(updated 2026-11-03)*
- Files: `aarch64/ABI.md`, `aarch64/include/ureg.h`, `aarch64/include/u.h`, `sys/src/libc/9syscall/sys.h`, `sys/src/libc/9syscall/mkfile` (`case aarch64`, lines 96–103; the `exits`→`_exits` rename at line 9 and `seek`→`_seek` at line 98 are ABI-referenced)
- Why fragile: ABI.md declares the syscall wire contract (number in R0, args at SP+8, `SVC`, result in R0) and the `ureg.h` trap frame frozen (D-15/D-16/D-17). Since the last mapping, ABI.md gained the "Kernel-side enforcement (Phase 4 appendix)" (lines 83–143): r9 now carries in-crate `core::mem::offset_of!` const asserts plus `cargo xtask ureg-check`, which parses THIS repo's `aarch64/include/ureg.h` and fails on field drift, and runs as a boot-test precondition. That closes the loop only when the r9 side runs it — and ureg-check locates this repo via the `R9_HARVEY_DIR` env var with default `../harvey`, i.e. a sibling-checkout assumption on the r9 side (the inverse of Harvey's INT-04 "no sibling paths" rule; the flake-input composition cannot run the cross-repo check because the Harvey checkout is not in the r9 build's closure). Nothing in THIS repo compiles against, diffs, or greps the frozen artifacts; an innocent edit to `ureg.h` field order, the stub generator, or sys.h numbering would be caught only at the next r9-side boot test. Verified consistent as of this audit (sys.h 0–54 with the 48–49 gap, SYSR1=0, MOUNT=46, NSEC=53, NMOUNT=54; stub shape matches ABI.md verbatim; ureg.h field-for-field; vendored 7a/7c/7l and libc/aarch64 all cite the same 9front pin `350266104f1fed81c78c3d05fa44f523bec0ae4d`).
- Safe modification: Treat all five files as LOCKED; any change requires re-freezing both repos per ABI.md. Do not touch the `case aarch64` block when editing neighboring arch cases. When running r9's boot tests locally, set `R9_HARVEY_DIR` explicitly rather than relying on the `../harvey` default.
- Test coverage: None on the Harvey side by design — the r9-side checks (const asserts + ureg-check) are the whole enforcement story, and they run only where an r9 checkout exists.

**`build/aarch64/out/` shared staging with "last writer wins" ownership:** *(new)*
- Files: `build/aarch64/stage-build.sh` (owns `out/` wholesale — rsyncs back with `--delete`, line 122), `build/aarch64/subset-build.sh` (writes `out/{boot,init,paqfs,stacksmoke}` individually, no `--delete`, lines 265-272), `build/aarch64/mkimage.sh:120-132` (bake-time guard)
- Why fragile: Two supply chains write the same gitignored directory with different ownership models; stage-build.sh's `--delete` can reap subset-build.sh's binaries, and r9's boot-test bake re-running stage-build.sh can land the WRONG init (`init.c` — the staged "r9 EL0 alive" init whose concurrent exec children never reach rc) between a subset-build and a bake. The mitigation is a heuristic: mkimage.sh greps the init BINARY's rodata for "init: starting /bin/rc" (real) vs "init: r9 EL0 alive" (staged) before baking — string-identity on an a.out, which silently rots if either init's banner text changes.
- Safe modification: Never run stage-build.sh between `subset-build.sh` and `mkimage.sh` in the same tree; if the guard trips, re-run `subset-build.sh`. If init banners change, update the two grep patterns in the same commit.
- Test coverage: The guard itself is the only coverage; exercised by the 05-07 gate-wedge incident it was born from.

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

**darwin build path depends on rsync/lima choreography:** *(low)*
- Files: `nix/vm-build.sh`, `nix/lima-harvey.yaml`
- Why fragile: The macOS build rsyncs the checkout to a lima guest (excluding `.git`, `.build`, `.planning`), builds there, then pulls `amd64/`, `386/`, `aarch64/` back *without* `--delete` (`nix/vm-build.sh:64-67`) — artifacts deleted guest-side persist on the host. Guest build failure propagation was fixed in `d663bab7b`/`566677c94`; KERNDATE is correctly computed host-side (guest has no `.git`). The virtiofs bind-mount caveat (empty tree) that forced the rsync design is documented in the script header. The Phase-5 compose apps inherit this choreography on darwin (`nix/boot-r9.sh` → `build/aarch64/subset-build.sh` → lima leg).
- Safe modification: Keep the push/pull asymmetry in mind; add `--delete` to pull-back only after confirming no host-side build outputs would be reaped.
- Test coverage: The linux leg is CI-covered (`r9-shell.yml`); the darwin leg is exercised manually on darwin-aarch64 only (documented-manual per `build/REPRODUCIBILITY.md` INT-03).

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

**r9 kernel consumed as a flake input from a personal GitHub repo:** *(new)*
- Risk: `flake.nix:11` inputs `github:requaos/r9` (no `ref` — follows the default branch), pinned in `flake.lock` at rev `9549cee63d86a0c6d9b4d04ed8860b2efabcd3e6` + narHash. The composed boot (`nix run .#boot-r9`, `.#boot-r9-smoke`, and the `r9-shell.yml` CI leg) depends on this repo's continued availability and on the pin being refreshed deliberately: any `nix flake update` jumps r9 to arbitrary new default-branch HEAD with no documented review gate, and the `boot-r9`/`boot-r9-smoke` apps consume `r9.packages.<system>.kernel-virt` by contract (kernel-virt.elf + `aarch64/lib/virt-gicv2.dtb` layout) — an r9-side package-layout change breaks the compose apps, softened only by `find`-by-name fallbacks (`nix/boot-r9.sh:71-82`). The dev escape hatch `--override-input r9 git+file:///path/to/r9` (D-13) bypasses the pin entirely by design. Closure bloat: `flake.lock` carries TWO nixpkgs pins — root `31ecbaca…` and r9's transitive `1c89083e…` (plus rust-overlay `c85ccd34…`) — so two nixpkgs checkouts are fetched/evaluated per clean run (05-REVIEW IN-13; intended transitive capture per `build/REPRODUCIBILITY.md`).
- Impact: The project's core-value demo (Harvey userspace + r9 kernel booting to a shell) is unavailable if the r9 repo vanishes or its package contract drifts; lock bumps can silently swap the kernel under the smoke.
- Migration plan: Mirror/transfer r9 to an org the project controls; document an r9-pin update cadence with smoke evidence required per bump; long-term, absorb r9 into this repo or a monorepo once the kernel adoption completes.

**nixpkgs tracks `nixos-unstable` (rolling):** *(updated 2026-11-03)*
- Risk: `flake.nix:4` inputs `github:NixOS/nixpkgs/nixos-unstable`. The lock (`flake.lock`) is pinned and hashed (rev `31ecbaca1bdefa45dffc409f0250bd8039ea0010`), so builds are reproducible today; but any `nix flake update` jumps to arbitrary new unstable, and plan9port/qemu/expect/dtc bumps there can break the namespace build, the expect-driven ISO path, or the TCG boot smoke. No update cadence or rollback policy is documented. CI coverage improved: `.github/workflows/r9-shell.yml` now evaluates the flake and runs the full pipeline (`nix run .#boot-r9-smoke`) on every push/PR — but only the linux leg (darwin is documented-manual), only the smoke app (not `nix flake check` or the `.#iso`/`.#build` apps), and a known pre-existing eval break on x86_64-darwin (nixpkgs's "x86_64-darwin-26.11" release-notes throw; proven pre-existing by evaluating the pre-05-11 flake `49145f3a0`) breaks any `--all-systems` full-matrix eval — the `systems` list entry at `flake.nix:15` is out of PROJECT.md scope but still evaluated.
- Impact: Dev-environment breakage on lock bumps surfaces on the next push (linux) or on a developer's darwin machine (manual); the project's "reproducible from clean checkouts" core value depends on this lock plus the r9 pin.
- Migration plan: Pin `nixos-25.11`-style stable branches with scheduled bumps; add a CI job running `nix flake check` (blocked for full-matrix until the x86_64-darwin systems-list entry is dropped or the nixpkgs throw is worked around); require r9-shell green on lock-change PRs.

**Ubuntu 21.10 Docker base (superseded but still present):**
- Risk: `build/Dockerfile:15` — `FROM ubuntu:21.10` (Impish) went EOL July 2022; apt mirrors moved to old-releases, so `apt-get -y update` will fail on fresh builds. The flake devshell/apps are now the supported path, making the Dockerfile legacy.
- Impact: Anyone following `build/BUILD_IN_DOCKER` hits a wall; the lima guest uses Ubuntu 24.04 (`nix/lima-harvey.yaml`), so the two container-ish paths disagree by three LTS cycles.
- Migration plan: Rebase to `ubuntu:24.04` (matching the lima guest) or delete the Docker path in favor of the flake.

**9legacy bootstrap ISO (ISO path only):**
- Risk: `build/build.bash` depends on `https://github.com/Harvey-OS/harvey/releases/download/9legacy/9legacy.iso.bz2` — a release artifact on an archived org; if GitHub releases are pruned or the repo is removed, `nix run .#iso` stops working. The kernel/userland dev build no longer needs it (namespace build via `nix/build.sh`).
- Impact: No 9legacy → no ISO production, since the Harvey toolchain (6a/6c/6l) must be built inside a Plan 9 environment on that path.
- Migration plan: Mirror the ISO into this repo's releases or a checksum-pinned artifact store; long-term, emit the ISO from namespace-build artifacts.

**Vendored 9front toolchain pin (7a/7c/7l, libc/aarch64):**
- Risk: `sys/src/cmd/7a/`, `sys/src/cmd/7c/`, `sys/src/cmd/7l/`, and `sys/src/libc/aarch64/` are vendored wholesale from 9front at pin `350266104f1fed81c78c3d05fa44f523bec0ae4d` (branch `front`, pinned 2026-10-31 — see each dir's README). Compiler bugs fixed upstream after the pin won't flow in; local shims (D-13: e.g. `7c/math.h`, `7a/a.h` BUFSIZ) must be reapplied on any re-vendor.
- Impact: aarch64 compiler correctness is frozen at the pin; re-vendoring is a manual, shim-reapplying exercise.
- Migration plan: Documented as a temporary bridge to the r9 kernel (Phase 2 READMEs); revisit after r9 adoption.

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

**Full aarch64 userland (subset only today):** *(updated 2026-11-03)*
- Problem: The aarch64 userland is a shell-boot subset: 16 commands (`rc grep cat cp date echo ls mkdir mv ps rm sed test wc` plus `ip/ipconfig` and `auth/factotum`) plus the boot chain (`boot`, `init`, `paqfs`, `stacksmoke`), built by `build/aarch64/subset-build.sh`. `aarch64/bin`/`aarch64/lib` are gitignored build outputs since Phase 5 (`.gitignore:19-22`) — previously committed binaries were dropped from tracking. Most of `sys/src/cmd/` (~266 commands) is not built for `objtype=aarch64`; there is no aarch64 storage/network tooling beyond ipconfig, no APE, no draw/rio stack.
- Blocks: Booting a *useful* Harvey userland on aarch64 with r9 beyond the smoke's shell; any aarch64 storage/network tooling.

**Automated testing:**
- Problem: No test runner, no unit-test framework for kernel or libc. Existing "tests" are standalone binaries (`sys/src/cmd/aquarela/test*.c`, `sys/src/cmd/wikifs/testwrite.c`, `sys/src/libsec/port/*test.c`) that must be built and run by hand inside a running Harvey system. Phase 5 added the first automated end-to-end gate (`build/aarch64/smoke-r9.expect` via `nix run .#boot-r9-smoke`, CI'd on linux by `.github/workflows/r9-shell.yml`) — but it is a boot/shell behavior smoke, not a test framework, and its assertions are presence-markers on a serial wire, not unit coverage.
- Blocks: Regression detection for any change outside the smoke's narrow sweep; per-component CI.

## Test Coverage Gaps

**aarch64 port tree (boot-gated end-to-end, unit-gaps remain):** *(updated 2026-11-03, HIGH)*
- What's not tested: The FP bug above (`aarch64/include/u.h`) — the Phase-5 smoke never prints a float, so it ships unguarded. The vendored 7a/7c/7l compile chain is exercised end-to-end by every `subset-build.sh` run but has no codegen test suite. What IS now covered: the frozen ABI's wire behavior is gated end-to-end by `build/aarch64/smoke-r9.expect` (banner → paqfs → stacksmoke → `% ` prompt → echo/ls/ps/cat sweep → DEL safety → init restart), run on linux CI every push via `r9-shell.yml`; and the `ureg.h` trap-frame layout is enforced r9-side (`cargo xtask ureg-check` parses `aarch64/include/ureg.h`, runs as a boot-test precondition) — though only when an r9 checkout runs it (see Fragile Areas).
- Files: `aarch64/`, `sys/src/cmd/7a/`, `sys/src/cmd/7c/`, `sys/src/cmd/7l/`, `sys/src/libc/aarch64/`, `sys/src/libc/9syscall/mkfile`, `build/aarch64/smoke-r9.expect`
- Risk: Broken float math shipping in every freshly built `aarch64/lib/libc.a`; ABI drift caught only cross-repo.
- Priority: High

**Nix build/dev layer:**
- What's not tested: `flake.nix` apps and `nix/*.sh` — the r9 composition (`boot-r9`, `boot-r9-smoke`) is CI-covered on linux (`r9-shell.yml` runs the full build → bake → DTB-patch → qemu smoke per push); the darwin leg of the same pipeline is documented-manual only (`build/REPRODUCIBILITY.md` INT-03); the older apps (`setup`, `toolchain`, `build`, `iso`, `vm-build`) and the legacy `.github/workflows/harvey.yml` qemu path remain hand-exercised, and no CI runs `nix flake check` (the x86_64-darwin eval break blocks full-matrix evals).
- Files: `flake.nix`, `flake.lock`, `nix/`, `.github/workflows/r9-shell.yml`, `.github/workflows/harvey.yml`
- Risk: Darwin-leg regressions (lima/rsync choreography) and non-smoke app rot found only when a developer's build breaks; no cache/concurrency controls mean 90-minute serial CI runs amplify the cost of finding out.
- Priority: High

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
- What's not tested: Most of `sys/src/cmd/` — test files exist for a handful of tools only (aquarela, wikifs, upas, 9nfs, gs zcid, jtagfs). The aarch64 subset's 16 commands get behavior-level presence assertions from the smoke (ls/ps/cat/echo in the D-09 sweep) but no argument/edge-case coverage.
- Files: `sys/src/cmd/`
- Risk: Command regressions go unnoticed across builds.
- Priority: Medium

---

*Concerns audit: 2026-11-03*
