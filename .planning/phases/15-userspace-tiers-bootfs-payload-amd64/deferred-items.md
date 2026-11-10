# 15-06 Deferred Items

Out-of-scope discoveries from the trace-rig bring-up (pre-existing
behavior, measured live on the draw donor venue; the rig works around
both — neither is this plan's surface):

- samterm's input machinery is pacing/protocol fragile around file
  exchanges: the menu-New path leaves `which` unset pending the host's
  Hcurrent (a second B3 press re-opens the menu instead of entering the
  sweep — the +1px menuhit warps on the capture pin it), and after a
  `B` command whose reply leaves a non-empty dot on the command window,
  `type()` takes the cut-selection branch and never consumes the pending
  runes (the first typed line after the file command stalls behind the
  kbdblock mask).  The committed replay-sam.rc drives the proven path
  (B on a missing name + a B1 dot-reset click); a real fix owns
  samterm's io.c/main.c state machine.
  status: open
  **What:** sys/src/cmd/samterm/{io,main,menu}.c input-state handling.

- Harvey's amd64 runtime epilogue calls `exits("main")` for programs
  that fall off main (sys/src/libc/amd64/main9.s: `CALL exits` with
  RARG=$_exits<>` — a NON-EMPTY failure status to rc's `&&`), where
  stock Plan 9 exits with a nil/empty status.  arctest.c (no explicit
  exits) is the measured case: its timings print, its exit status is
  "main", so `cmd && echo` never fires.  The rejoin gates on the
  completion output instead (15-06); a runtime-level decision (fix
  main9.s or audit the fall-off-main programs) belongs to a plan that
  owns the libc runtime.
  status: open
  **What:** sys/src/libc/amd64/main9.s epilogue status.
