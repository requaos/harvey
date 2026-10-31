# Deferred Items — Phase 01, Plan 01

Out-of-scope discoveries logged during execution (not fixed, per deviation scope rules).

| # | Discovered during | Item | Disposition |
|---|-------------------|------|-------------|
| 1 | Task 3 clean-checkout (both runs) | **Case-colliding committed paths**: repo contains both case variants (`rc/bin/Kill`+`kill`, `sys/lib/postscript/troff/HX`+`Hx`, `sys/lib/troff/font/devutf/HB`+`Hb`, `HI`+`Hi`, `HX`+`Hx`, `charlib/LH`+`lH`+`lh`, `RC`+`rc`+`rH`+`rh`, `devpost.add/C1`+`c1`, `C2`+`c2`, `C3`+`c3`). On case-insensitive APFS every checkout shows phantom "modified" files (the working file holds the sibling variant's content). Pre-existing upstream condition; the plan explicitly forbids destroying these local working-tree states. Needs a repo policy decision (rename one of each pair) in a hygiene phase. | Deferred — repo-wide policy decision, not this plan |
| 2 | Task 1 verify | **vm-build.sh syncs back only `amd64/`+`386/`** — in-tree generated files (e.g. `jtagfs/rtab.c`) never return to the host, so host-side `test -s` on generated sources cannot pass on darwin. Verified guest-side instead (`~/harvey-build/.../rtab.c` = 1701 B). If host-side visibility is ever wanted, add a targeted rsync of generated sources. | Deferred — cosmetic; guest-side verification is sufficient |
| 3 | Post-completion state audit | **STATE.md Velocity prose block stale** (`Total plans completed: 0` while frontmatter `completed_plans: 1` and the Per-Plan Metrics row are correct). `state.update-progress` re-run returned the tool's phase-level 0% (0/5 phases) — tool-owned display data, not hand-edited to avoid fighting the tooling's accounting. | Deferred — cosmetic; authoritative frontmatter/metric rows are correct |
