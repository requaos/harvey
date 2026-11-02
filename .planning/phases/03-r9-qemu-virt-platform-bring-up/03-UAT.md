---
status: testing
phase: 03-r9-qemu-virt-platform-bring-up
source: [03-VERIFICATION.md]
started: 2026-11-01T23:59:00Z
updated: 2026-11-01T23:59:00Z
---

## Current Test

number: 1
name: D-10 linux leg of SC#1 — r9 flake devshell reproduces the kernel build on a linux host
expected: |
  On a linux host (aarch64 or x86_64) from a clean checkout of r9 at commit 55ca7c4 (main):
  - `nix develop` yields the pinned nightly-2026-01-30 toolchain (rustc 1.95.0-nightly), qemu-system-aarch64 11.1.2, and dtc — zero host setup beyond nix itself
  - `nix develop -c cargo xtask build --arch aarch64` completes and produces target/aarch64-unknown-none-elf/debug/aarch64 (ELF)
  - `nix run .#build` from the r9 root builds the kernel without entering the devshell (apps.build embeds its runtime inputs)
  Reference (darwin leg, already machine-proven): r9 commit ae4cd08, rustc 1.95.0-nightly (842bd5be2 2026-01-29), QEMU 11.1.2, DTC 1.8.1; lock pins nixpkgs 1c89083 / rust-overlay c85ccd3.
awaiting: user response

## Tests

### 1. D-10 linux leg of SC#1 — r9 flake devshell reproduces the kernel build on a linux host
expected: |
  On a linux host from r9 55ca7c4: `nix develop` yields pinned nightly-2026-01-30 + qemu 11.1.2 + dtc; `nix develop -c cargo xtask build --arch aarch64` produces the kernel ELF; `nix run .#build` works bare (no devshell). Accel/KVM variance is out of scope for this leg — building only, no boot required.
result: [pending]

### 2. D-11/D-13 evidence-bundle phase-gate approval
expected: |
  Human reviews and approves the canonical evidence bundle in this phase dir:
  - evidence/virt-boot.log — banner ("r9 from the Internet"), DTB line at 0xffff800040000000, ≥3 periodic ticks, typed probe string echoed via the IRQ path
  - evidence/virtpanic-boot.log — full TrapFrame register dump (31 rows, ec: Ok(Brk)) + "kernel halted" clean-halt marker, zero IRQ interleaving
  - evidence/EVIDENCE.md — integrity record: r9 commit SHA (55ca7c4), qemu 11.1.2, host darwin-aarch64, exact commands, per-assertion results
  Mechanical integrity is already machine-proven: the verifier reproduced both logs byte-for-byte from r9 HEAD via `cargo xtask boot-test --config virt` / `--config virtpanic`. This test is the approval act itself (D-11/D-13 phase gate, same shape as the 02-05 gate).
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
