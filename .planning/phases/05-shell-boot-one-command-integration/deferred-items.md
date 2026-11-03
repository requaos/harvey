# Deferred Items — Phase 05

## Deferred Items

- 05-04's namespace core (namec + pgrp + registry) never got its HowItWorks.md section — the r9 doc's header mandates an update with any material change, and 05-04's key-files omit it. 05-05's section (r9 commit 628d612) references 05-04's namec but does not backfill its documentation.
  status: open
  **What:** add a HowItWorks.md section covering the 05-04 namespace core (namec/pgrp/registry, sys_open prefix-routing retirement, eager data+bss at exec, brk_).  Not goal-blocking; the code carries exhaustive module headers.

- getenv's seek-to-end sizing needs SEEK(39) (observed 05-05): the gate log shows two `syscall 39 unimplemented` walls from partinit's getenv("readparts") — open succeeded through the union-mounted /env (the seeded key resolved), then seek failed soft.  Behavior unchanged vs 05-04 (readparts runs vacuously); the seeded readparts=0 short-circuit only takes effect once SEEK lands.
  status: resolved
  **What:** SEEK(39) is in the 05-03 measured trace and belongs to a later plan (05-06/07/08 territory).  When it lands, the seeded readparts=0 starts skipping the vacuous /dev scan.
  **Resolved 05-06:** sys_seek landed (the 05-06 gate's trace-settled gap — paqfs's libbio Bseek; measured ×72).  The 05-06 gate log has ZERO `syscall 39` walls (getenv's seeks now resolve); the only unimplemented number is FVERSION(40) — the wall by design.

- Exit-time fd-group sweep is deliberately absent (05-06): EXITS marks Moribund and frees the address space, but a proc's fd group is never close-dispatched at exit (the donor's pexit closefgrp).  Nothing this phase's gate needs it — connectembed's closes are all explicit, and devsrv's registered clone pins the pipe by design (the server outlives boot so 05-07's settime can mount via #s/boot; the gate's end state is the paqfs io child parked on its read, exactly like a real Plan 9 boot).
  status: open
  **What:** when a later plan needs exit-time close semantics (e.g. a server whose lifecycle tracks a transient client, or fd leaks mattering across a long-lived init), add the donor's decref-and-last-close sweep to exit_tail: detach the proc's fd_group; if the Arc count hits one, close-dispatch every occupied slot (namec::close_chan).  The close dispatch (05-06) is already the whole device half.
