# Phase 02 — Deferred Items

| # | Item | Found during | Status |
|---|------|--------------|--------|
| 1 | Bare `sh sys/src/BUILDTOOLCHAIN` in a plain devshell fails at 6c's link: 6c/BUILD passes `-static`, which Apple ld rejects (`library not found for -lcrt0.o`). The 9l shim that drops `-static` is installed only by `nix/toolchain.sh` — the supported driver is `nix run .#toolchain`. Pre-existing Phase 1 design (not a 02-01 regression); consider either documenting on BUILDTOOLCHAIN's header or moving the shim into the devshell hook. | 02-01 Task 3 (plan-level verification) | open |
