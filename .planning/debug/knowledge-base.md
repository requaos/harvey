# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## G-05-1 — x86_64 CI failure: missing /bin/rc breaks #!/bin/rc rc-script exec from mk recipes (membername → boot(8) link)
- **Date:** 2026-11-03
- **Error patterns:** `membername: No such file or directory`, `SUBSET-BUILD-FAIL: boot(8) aarch64 build`, `main: undefined: boot`, `semacquire: configembed: not defined`, `cannot execute: required file not found`, "works on the dev VM, fails on fresh CI host", reported-symptom-vs-raw-log mismatch
- **Root cause(s):** `rc/bin/membername` (shebang `#!/bin/rc`, invoked from `sys/src/9k/boot/mkfile.aarch64:50` and both shared bootmkfile templates) needs the kernel to exec `/bin/rc`; the mount namespace (build/aarch64/nsrun.sh) shares the distro `/bin` and never provided `/bin/rc`. Passing legs were masked by an undocumented manually-placed `/bin/rc` in the long-lived lima VM; the legacy docker path codified it (build/Dockerfile:42) but the nix/namespace path never did. The "arch-specific" axis was correlation, not cause.
- **Fix:** nsrun.sh root section binds `$PLAN9/bin/rc` over `/bin/rc` inside the private mount namespace (touch mountpoint if missing; fail-hard if `$PLAN9/bin/rc` absent). Commit d758c2071 `fix(05): G-05-1 ...`.
- **Files changed:** build/aarch64/nsrun.sh
- **Why not caught:** no gate exercised the namespace build on a truly fresh host before the first x86_64 CI run — both proven legs shared one VM image carrying manual state; the env contract ("/bin/rc must exist") was implicit.
- **Recurrence guard:** the nsrun.sh bind itself (fresh hosts now get /bin/rc deterministically); plus the debug-verified repro recipe (emulated x86_64 docker: ubuntu:24.04 + nix `sandbox=false` + `nix run .#boot-r9-smoke`) is recorded in .planning/debug/DEBUG-G-05-1.md for future arch-leg bring-up.
- **Meta-lesson:** when a report says "log ends at X with zero output and no failure marker," fetch the RAW CI log before theorizing — streaming/partial views mislead; here the raw log showed the true failure two stages later with its marker intact.
---

## x64-kzero-panic-after-dealloc-fix — x86_64 r9 exec reuses freed page tables once frees became real (KZERO panic / #UD)
- **Date:** 2026-11-19
- **Error patterns:** `panicked at x86_64/src/proc.rs:361:5`, `PA 0x... outside the KZERO window`, `user trap: unhandled vector 6 pc=0x204ff8`, `process N exited: "sys: trap"`, panic right after `init: starting /bin/rc`, x86_64-only (aarch64 green on the same r9), started at an allocator fix that made frees real (r9 8958c9e), invalid opcode at a 0xff8 page offset, garbage PA whose bytes decode as amd64 code
- **Root cause(s):** r9 `x86_64/src/proc.rs` `Proc::free_user_mappings` freed the user-half intermediate page tables (`mapping_tables`: PDPT/PD/PT) while the proc's PML4 still linked them (PML4[0] text/data, PML4[255] stack); EXEC keeps that PML4 and maps the new image through it, so the walk descended into freed pages that `alloc_phys_page` was handing out again as the new image's leaves — text bytes walked as PTEs (KZERO panic) and stale stack-path walks wrote PTEs into text (slot 511 = offset 0xff8 → #UD); AND r9 8958c9e made `bitmapalloc` deallocate really free (correct), which turned the previously leaked-and-intact tables into reused pages. aarch64 never frees intermediate tables, hence green.
- **Fix:** r9 cec2299 `fix(x86_64): unlink the user-half tables before freeing them` — new `unlink_user_half()` clears PML4[0..256) and reloads CR3 when that root is active, called in `free_user_mappings` BEFORE the table frees; compile-time assert that the kstack slot (400) is outside the cleared range; allocator untouched. Harvey pinned at b0e3cef8f.
- **Files changed:** r9 x86_64/src/proc.rs
- **Why not caught:** no gate existed for this class — every free leaked before 8958c9e, so free-while-linked was invisible; the x86_64 host tests never re-mapped through a root after `free_user_mappings`; the composed x64 gates were the first to run on the fixed allocator (8958c9e's own verification covered the port suite and aarch64, and flagged the x86_64 kernel bytes as changed but did not run the x64 composed gates).
- **Recurrence guard:** regression test `x86_64/src/proc.rs:proc::tests::free_user_mappings_unlinks_the_freed_tables_for_exec_reuse` (PML4 user half empty after free; every reachable table owned after re-map; kills the unlink-removed / 0..255 / 1..256 mutants) + the `KSTACK_PML4_INDEX >= USER_PML4_SLOTS` const assert. Note: run x86_64 host tests explicitly (`cargo test -p x86_64 --bins --target x86_64-unknown-linux-gnu`) — `cargo xtask test` inside `nix develop` skips the arch leg (no rustup).
- **Meta-lesson:** an allocator fix that makes frees real is a cross-arch event — re-run every arch's composed gates, and audit each "free" for the free-while-still-linked shape (unlink → flush → free). Repro recipe for x86_64 CI on an Apple-silicon Mac: Docker Desktop amd64 (Rosetta) ubuntu:24.04 `--privileged`, single-user nix with `sandbox = false` + `filter-syscalls = false`, a non-root builder with passwordless sudo, and **gcc installed** (ubuntu-latest parity — mkimage's authdomain-gen needs a host cc).
---
