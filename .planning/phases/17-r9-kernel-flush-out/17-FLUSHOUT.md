# 17-FLUSHOUT.md — Phase 17's single closure table (D-16)

One row per finding/window the phase touches: finding ID → action taken (fixed / dispositioned / folded) → pin (host test / boot profile / composed gate) → commit (r9 SHA or Harvey SHA) → ledger refs. VERIFICATION walks this table row by row; the ledgers (07/08 REVIEW-DISPOSITION, WINDOWS.md) stay the per-backlog truth — this table is the phase's index over them.

**Seeded by 17-01** (the CR-01 exemplar row proved the pipeline shape end-to-end; Tasks 2-3 filled the x86_64-re-proved rows). Rows whose plan has not landed carry the literal word `pending` in their action/pin/commit cells until the owning plan lands. Row IDs are ledger-qualified to keep the two WR families distinct (`08-WR-*` = Phase-8 findings, `07-WR-*` = Phase-7 findings); WINDOWS rows carry the bare `#NN` ids.

Row notes (where the later plans land):

- **08-CR-07** → 17-07's root-cause + fix + stress-pin work item; folds WINDOWS **#47/#50/#66** into it per D-09 (one root-cause pass; the fold verdict is execution output).
- **08-WR-03** → its x86_64 audit + OOM-release ports landed with 17-01 (r9 3e8bcec); the row's gates (pin cells) stay pending until **17-02's** tiered leak gates green.
- **08-CR-03's** in-kernel contention leg also rides 17-02's churn profile (the D-07 stress half).
- **07-WR-01..06** → 17-04's Phase-7 hardening class-sweep (cap-walk loud aborts, WaitSet sizing, used-id liveness).
- **07-WR-07/07-WR-08** → dispositioned-in-17-04 (frozen/superseded, the 3-part D-15 rationale).
- **#18/#45** → 17's namec work (D-10: #18 fixed in-phase; #45 union-create). **#44** → 17-02's leak gates (the arena-drain row). **#46/#49/#65** → the D-11 rc fix-class commit. **#47/#50/#66** → the CR-07 fold (17-07).

| Finding | Action | Pin | Commit | Ledger refs |
|---------|--------|-----|--------|-------------|
| 08-CR-01 | fixed — re-proved on x86_64 (D-01 pin-first; no code change) | `devip_tests::tcp_conv_close_lingers_the_socket_until_closed` (cargo test -p port --lib, 101/101) + composed gate boot-r9-net-smoke-x64 (exit 0, all stages pass) | r9 bd4db36 (fix) + r9 7300113 (pin); x86_64 lineage: Harvey flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md CR-01 |
| 08-CR-02 | fixed — re-proved on x86_64 (D-01) | `udp_write_oversized_or_unaddressable_errors_instead_of_wedging` + `icmp_write_oversized_or_unaddressable_errors_instead_of_wedging` + `icmp6_write_oversized_errors_instead_of_wedging` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0) | r9 904af8f (fix) + r9 b9d3977 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md CR-02 |
| 08-CR-03 | fixed — deterministic verification transferred from Phase 8 and the host half DISCHARGED (D-07) | the four x86_64 sem pins `sem_register_is_idempotent`, `sem_wake_consumes_picked_registrations_in_order`, `sem_reregistered_waiter_is_found_by_the_next_release`, `sem_wake_never_touches_other_words` (cargo test -p x86_64 --bins --target x86_64-unknown-linux-gnu -- sem_ = 5/5; battery 64/64) + boot-r9-net-smoke-x64 (exit 0); the in-kernel contention leg rides 17-02 | r9 75970f0 (fix) + r9 b48e809 (aarch64 pins) + r9 f9088d0 (x86_64 sem pins); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md CR-03 |
| 08-CR-04 | fixed — re-proved on x86_64 (D-01) | `ipifc_add_v4_multicast_and_broadcast_absorb_without_panic` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0) | r9 ac6370c (fix) + r9 2017360 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md CR-04 |
| 08-CR-05 | fixed — re-proved on x86_64 (D-01) | `ipifc_unbind_orphans_convs_on_the_dying_core` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0; the two unbind stages) | r9 0f602d8 (fix) + r9 42b1745 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md CR-05 |
| 08-CR-06 | fixed — re-proved on x86_64 (D-01) | `tcp_gc_hangs_up_stale_convs_but_never_steals_an_in_use_slot` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0; tcp/7 + DUPBIND legs) | r9 79517b1 (fix) + r9 27d8ec1 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md CR-06 |
| 08-CR-07 | pending | pending | pending | 08-REVIEW-DISPOSITION.md CR-07; WINDOWS.md #47/#50/#66 (the D-09 fold) |
| 08-WR-01 | fixed — re-proved on x86_64 (D-01) | `udp_spawned_conv_writes_ride_the_announcers_socket` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0; the udp echo leg) | r9 3dec2e9 (fix) + r9 764d0d1 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md WR-01 |
| 08-WR-02 | fixed — re-proved on x86_64 (D-01) | `udp_spawned_conv_dataq_is_capped` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0) | r9 8cfc44f (fix) + r9 106e939 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md WR-02 |
| 08-WR-03 | fixed (Phase 8) + x86_64 audit COMPLETE with four OOM-release gaps ported (D-02) — NOT closed: gates pending | pending — 17-02's tiered leak gates (r9-side churn profile asserting the heap_stats cursor slope + the Harvey composed /bin/cat churn leg) | r9 9035bb2 (aarch64 fix) + r9 3e8bcec (x86_64 OOM-release ports) + r9 476605d (FOD re-wire); Harvey flake.lock pin 476605d | 08-REVIEW-DISPOSITION.md WR-03 |
| 08-WR-04 | fixed — re-proved on x86_64 (D-01) | `ipifc_bind_rejects_a_conv_already_bound_to_another_medium` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0; the DUPBIND-REJECTED stage) | r9 c6040b7 (fix) + r9 4791dc0 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md WR-04 |
| 08-WR-05 | fixed — re-proved on x86_64 (D-01) | `ipifc_remove_keeps_shared_selftab_entries_for_surviving_lifcs` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0; the ipconfig add/remove legs) | r9 4ee61c8 (fix) + r9 85adba5 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md WR-05 |
| 08-WR-06 | fixed — re-proved on x86_64 (D-01) | `iproute_default_recorded_before_bind_lands_at_bind` (port battery 101/101) + boot-r9-net-smoke-x64 (exit 0; the ipconfig static leg) | r9 f70d98b (fix) + r9 0a4ea82 (pin); lineage flake.lock r9 476605d | 08-REVIEW-DISPOSITION.md WR-06 |
| 07-WR-01 | pending | pending | pending | 07-REVIEW-DISPOSITION.md WR-01 |
| 07-WR-02 | pending | pending | pending | 07-REVIEW-DISPOSITION.md WR-02 |
| 07-WR-03 | pending | pending | pending | 07-REVIEW-DISPOSITION.md WR-03 |
| 07-WR-04 | pending | pending | pending | 07-REVIEW-DISPOSITION.md WR-04 |
| 07-WR-05 | pending | pending | pending | 07-REVIEW-DISPOSITION.md WR-05 |
| 07-WR-06 | pending | pending | pending | 07-REVIEW-DISPOSITION.md WR-06 |
| 07-WR-07 | dispositioned-in-17-04 | pending | pending | 07-REVIEW-DISPOSITION.md WR-07 |
| 07-WR-08 | dispositioned-in-17-04 | pending | pending | 07-REVIEW-DISPOSITION.md WR-08 |
| #18 | pending | pending | pending | WINDOWS.md #18 |
| #44 | pending | pending | pending | WINDOWS.md #44 |
| #45 | pending | pending | pending | WINDOWS.md #45 |
| #46 | pending | pending | pending | WINDOWS.md #46 |
| #47 | pending | pending | pending | WINDOWS.md #47 (folds into 17-07's CR-07 work item, D-09) |
| #49 | pending | pending | pending | WINDOWS.md #49 |
| #50 | pending | pending | pending | WINDOWS.md #50 (folds into 17-07's CR-07 work item, D-09) |
| #65 | pending | pending | pending | WINDOWS.md #65 |
| #66 | pending | pending | pending | WINDOWS.md #66 (folds into 17-07's CR-07 work item, D-09) |
