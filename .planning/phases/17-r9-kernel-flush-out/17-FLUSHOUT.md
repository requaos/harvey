# 17-FLUSHOUT.md — Phase 17's single closure table (D-16)

One row per finding/window the phase touches: finding ID → action taken (fixed / dispositioned / folded) → pin (host test / boot profile / composed gate) → commit (r9 SHA or Harvey SHA) → ledger refs. VERIFICATION walks this table row by row; the ledgers (07/08 REVIEW-DISPOSITION, WINDOWS.md) stay the per-backlog truth — this table is the phase's index over them.

**Seeded by 17-01 (the CR-01 exemplar row, proving the pipeline shape).** Later rows land with their plans: unfilled action/pin/commit cells carry the literal word `pending` until the owning plan lands. Row IDs are ledger-qualified to keep the two WR families distinct (`08-WR-*` = Phase-8 findings, `07-WR-*` = Phase-7 findings); WINDOWS rows carry the bare `#NN` ids.

| Finding | Action | Pin | Commit | Ledger refs |
|---------|--------|-----|--------|-------------|
| 08-CR-01 | fixed — re-proved on x86_64 (D-01 pin-first; no code change) | `devip_tests::tcp_conv_close_lingers_the_socket_until_closed` (cargo test -p port --lib, 101/101) + composed gate boot-r9-net-smoke-x64 (exit 0, all stages pass) | r9 bd4db36 (fix) + r9 7300113 (pin); x86_64 lineage: Harvey flake.lock r9 208ceba | 08-REVIEW-DISPOSITION.md CR-01 |
