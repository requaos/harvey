# Deferred Items — Phase 05

## Deferred Items

- 05-04's namespace core (namec + pgrp + registry) never got its HowItWorks.md section — the r9 doc's header mandates an update with any material change, and 05-04's key-files omit it. 05-05's section (r9 commit 628d612) references 05-04's namec but does not backfill its documentation.
  status: open
  **What:** add a HowItWorks.md section covering the 05-04 namespace core (namec/pgrp/registry, sys_open prefix-routing retirement, eager data+bss at exec, brk_).  Not goal-blocking; the code carries exhaustive module headers.

- getenv's seek-to-end sizing needs SEEK(39) (observed 05-05): the gate log shows two `syscall 39 unimplemented` walls from partinit's getenv("readparts") — open succeeded through the union-mounted /env (the seeded key resolved), then seek failed soft.  Behavior unchanged vs 05-04 (readparts runs vacuously); the seeded readparts=0 short-circuit only takes effect once SEEK lands.
  status: open
  **What:** SEEK(39) is in the 05-03 measured trace and belongs to a later plan (05-06/07/08 territory).  When it lands, the seeded readparts=0 starts skipping the vacuous /dev scan.
