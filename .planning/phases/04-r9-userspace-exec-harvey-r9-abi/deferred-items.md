# Phase 04 — Deferred Items

| # | Item | Found during | Status |
|---|------|--------------|--------|
| 1 | `port/src/dat.rs`'s `Mode` bitflags carry wrong values vs Plan 9's frozen open-mode encoding (sys/include/libc.h: OREAD=0 OWRITE=1 ORDWR=2 OEXEC=3, then OTRUNC=16 OCEXEC=32 ORCLOSE=64 OEXCL=4096; the low two bits are an access-mode field, not a bit set). The skeleton predates Phase 4 and nothing consumes it — 04-05's devroot carries local OREAD/OEXEC constants with the frozen values instead. 04-06's syscall OPEN path (real userspace mode values on the wire) should fix or replace the skeleton. | 04-05 Task 2 (devroot open) | open |
| 2 | Orphaned qemu processes from earlier phase-verification runs (mon:stdio smoke boots) were observed still running days later; their stale serial log then short-circuited a rerun's marker-wait loop (the loop matched the old log and killed the fresh qemu before it opened the log file). Evidence scripts should `rm -f` the log before launch (04-05's does); consider a cleanup step in the boot-test/smoke harnesses. | 04-05 Task 2 (verify reruns) | open |
