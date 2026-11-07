# Deferred Items

- .planning/WINDOWS.md ledger is internally inconsistent: rows 44 and 45 exist in the table but not in the fenced JSON block (frontmatter counts 44/3/3/50 vs entries 42/3/3/48), so `gsd_run windows append` errors out and no new entries can be recorded
  status: open
  **What:** Pre-existing planning-ledger corruption, discovered during 13-01 closeout when appending the Known Stub entry (the parked old-gen x86_64 payload, resolved by 13-02's main9-x64 rewrite). Per the executor scope boundary this was not repaired in-plan. Fix: add the two missing entries to the fenced JSON block (or drop the stray table rows) and re-sync the frontmatter counts; then re-run the 13-01 stub append if 13-02 has not already superseded it.
