---
phase: 14-harvey-amd64-userspace-on-r9
fixed_at: 2026-11-09T17:09:52Z
review_path: .planning/phases/14-harvey-amd64-userspace-on-r9/14-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-11-09T17:09:52Z
**Source review:** .planning/phases/14-harvey-amd64-userspace-on-r9/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (fix_scope `critical_warning`: CR-01, WR-01, WR-02, WR-03)
- Fixed: 4
- Skipped: 0
- Out of scope, not attempted: IN-01, IN-02 (Info) and IN-03 (Info, **Category:** necessity) — they remain in REVIEW.md for the human

Dual-repo dispositions, each commit atomic in the repo that owns the file
(`workflow.use_worktrees=false` — all edits and commits landed directly in the
main checkouts; no worktree was created):

| Finding | File | Repo | Commit |
|---------|------|------|--------|
| CR-01 | `../r9/x86_64/src/exec.rs` | r9 | `f13ffda` |
| WR-01 | `../r9/x86_64/src/dat.rs` | r9 | `aa72df2` |
| WR-02 | `../r9/x86_64/src/l.S` | r9 | `86a8677` |
| WR-03 | `amd64/ABI.md` | harvey | `ea0604aeb` |

Close discipline (the r9 fixes are kernel-byte commits, so the standing
drift-class rule applied — re-wire-then-pin, all of it executed):

- FOD re-wire: r9 `5a563dd` (two-derivation proof, below)
- r9 pushed push-before-pin: `4132e25..5a563dd main -> main`, 0 unpushed after
- Harvey pin advance: `f6783ec89` — lock-only (flake.lock 3+/3-), pins
  `github:requaos/r9` at `5a563dd27e966169f76311a608200cc9c030d930`;
  sanity `nix eval .#apps.x86_64-linux.boot-r9-x64.type` = `"app"`

## Fixed Issues

### CR-01: check_seed_fit does not mirror seed_user_pages — exec with argv in the gap kills the process post-free instead of returning -1

**Status:** fixed: requires human verification (arithmetic/logic fix — though both boot gates exercised the exec seed path green, see Verification)
**File:** `../r9/x86_64/src/exec.rs:225-235`
**Files modified:** `../r9/x86_64/src/exec.rs`
**Commit:** r9 `f13ffda`
**Applied fix:** Introduced `const fn seed_tos_va()` — the single definition of
`(USTACKTOP - TOS_SIZE) & !0xf` — and made both functions consume it
(`seed_user_pages` now calls it instead of recomputing inline).
`check_seed_fit` recomputes the seed's exact arithmetic instead of the old
`strings + 8*(n+2) + 16 <= 4096` approximation: usable bytes below the Tos
block (`seed_tos_va() - (USTACKTOP - PAGE_SIZE_4K)` = 4000), minus the string
bytes, then `& !0xf` for the pointer array's alignment loss, then
`8*(argc+2)` must fit — `checked_sub` so an over-long string total is an
error rather than an underflow. The acceptance window (~80-95 bytes for
n=32) where the pre-free check passed and the post-free seed failed is
closed; arg-shape failures now return -1/errstr before `free_user_mappings`.

### WR-01: The ax@0 frozen-ABI const assert is swallowed by a line comment — the witness does not compile, and ABI.md's enforcement claim is false for ax

**Status:** fixed
**File:** `../r9/x86_64/src/dat.rs:98`
**Files modified:** `../r9/x86_64/src/dat.rs`
**Commit:** r9 `aa72df2`
**Applied fix:** Put the assert on its own line (the comment now ends after
"(the xtask ureg-check covers the header itself)." and
`const _: () = assert!(core::mem::offset_of!(Ureg, ax) == 0);` compiles like
its 13 siblings). Verified live: `cargo check`/`cargo build` of the x86_64
crate succeed with the assert compiling — the witness is real (it would fail
the build on any ax drift), and the full `ureg-check` (both arches Match,
negative control fired) ran green afterwards.

### WR-02: l.S module-tag walk performs no minimum tag-size validation — a corrupt size-0 tag loops forever at 32-bit boot, and module-header reads can run 4 bytes past the stash

**Status:** fixed: requires human verification (asm control-flow hardening — though the walk executed on every boot of both green gates, see Verification)
**File:** `../r9/x86_64/src/l.S:170-198`
**Files modified:** `../r9/x86_64/src/l.S`
**Commit:** r9 `86a8677`
**Applied fix:** The walk now (1) bounds the loop at `MB2INFOMAX - 16` so the
8-byte tag header plus the fixed module body (mod_start/mod_end at offsets
8/12) always fit the 4096-byte stash — max byte read is 4079+15 = 4094 < 4096;
(2) rejects any tag size under 8 (`cmpl $8, %ecx; jb 4f` — a tag is at least
its header; corrupt data bails to no-module and mb2.rs reports loudly);
(3) catches the wrap class the min-size check alone misses — after
`andl $-8, %ecx` (which sets ZF), `jz 4f` bails on any size whose +7 rounds
the advance to 0 (sizes 0xFFFFFFF9..0xFFFFFFFF), the exact infinite-loop
case. The block comment above the walk documents the corrupt-size bail.

### WR-03: ABI.md's enforcement appendix contradicts the checker it freezes — stale `../harvey` default, wrong pinned-table size, wrong mutation medium

**Status:** fixed
**File:** `amd64/ABI.md:320-342`
**Files modified:** `amd64/ABI.md`
**Commit:** harvey `ea0604aeb`
**Applied fix:** All three drifts amended to match the implementation
(facts verified against `xtask/src/uregcheck.rs` before editing): the header
is located via `R9_HARVEY_DIR`, REQUIRED (no default — an unset variable is a
named error, uregcheck.rs:70-84); the pinned table is 26 entries (22 u64int
fields plus the four u16int segment fields, `PINNED_FIELDS_AMD64:
[&str; 26]`); the negative control mutates an in-memory copy of the header
text (`replacen`, uregcheck.rs:184 — the committed header is never touched).

## Verification

All gates ran in the MAIN r9 checkout (/home/req/code/r9) at the fixed tree —
reproducible from /home/req/code/r9@5a563dd (= the Harvey-pinned rev) and
/home/req/code/harvey@f6783ec89. No worktree was created
(workflow.use_worktrees=false), so nothing here depends on a torn-down tree.

Regression battery (all green, exit 0):

- `nix develop . -c cargo xtask test` — 101 passed; 0 failed
- `R9_HARVEY_DIR=/home/req/code/harvey nix develop . -c cargo xtask ureg-check`
  — 35 fields match aarch64/include/ureg.h; 26 fields match
  amd64/include/ureg.h; negative control fired (cs -> cseg rejected with a
  named-field diff)
- `cargo xtask boot-test --config q35exec` — PASS: banner, memory facts,
  discovery, module-tag/paqfs mount, exec-entry note, and the marker binary's
  OWN ring-3 prints in order (exercises CR-01's exec seed path and WR-02's
  tag walk — every boot runs the l.S walk before any Rust)
- `cargo xtask boot-test --config q35shell` — PASS: the real
  boot(8) -> init -> rc chain through to the interactive `% ` prompt
  (exercises CR-01's `check_seed_fit`/`seed_user_pages` on the chain's execs)

boot-iso FOD re-wire (the drift-class rule; procedure per 14-07-SUMMARY.md
and evidence/14-gap-fod-proof.md):

1. Mismatch captured at the fixed tree (r9@86a8677): specified
   `sha256-lwbDSqYx…` (stale at the e417660 pin), got
   `sha256-PLfyY3v48QruonYK+TJ7J+Ci6oVaCF88wkzhFF2SVzU=`
2. Two independent non-FOD realizations via `f.lib.bootIso`, each forcing a
   FRESH kernel build through never-before-used version overrides
   (`reviewfix-proof-a` / `reviewfix-proof-b`; both logs show
   `building …-r9-kernel-x64-reviewfix-proof-{a,b}.drv` — no cache hits)
3. Byte-identity at both layers: `cmp` clean; file sha256 both
   `2be9a177cea8c6e59b080b6bf45e67bc85dd2506f3d651d16c6c797960889be5`;
   `nix hash path` both outputs =
   `sha256-PLfyY3v48QruonYK+TJ7J+Ci6oVaCF88wkzhFF2SVzU=`
   (base16 `3cb7f2637bf8f10aeea2760af9327b27e0a2ea855a085f3cc24ce1145d925735`)
   — three-way agreement with the FOD's own measured got-value
4. Wired in r9 flake.nix with the full-provenance comment (14-07 style);
   `nix build .#boot-iso` + `--rebuild` green, and green again at the
   committed pinned rev (`r9-boot-iso-5a563dd.drv`, exit 0)

Per-finding verification tiers: Tier 1 (re-read) for every fix; Tier 2
`cargo check -p x86_64` for CR-01/WR-01, `cargo build -p x86_64` for WR-02
(`cargo check` skips `global_asm!` codegen, so the assembler ran); Tier 1
only for WR-03 (markdown). Pre-existing warnings (dead code in trap.rs,
nightly-rustfmt import-order drift in untouched exec.rs regions) were left
alone — the fixes introduced none.

Both repos end clean (tracked); r9 `4132e25..5a563dd` pushed push-before-pin;
Harvey's pin advanced lock-only.

## Skipped Issues

None — all four in-scope findings were fixed. IN-01, IN-02, IN-03 were out
of scope (fix_scope `critical_warning`; IN-03 additionally a necessity
finding) and remain in REVIEW.md for the human.

---

_Fixed: 2026-11-09T17:09:52Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
