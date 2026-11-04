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
