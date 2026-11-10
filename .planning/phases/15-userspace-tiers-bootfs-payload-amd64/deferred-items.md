# 15-07 Deferred Items

Out-of-scope discoveries from the coverage sweep + gs render smoke
(pre-existing behavior, measured live; both worked around in this
plan's own artifacts — neither is this plan's surface to fix):

- mkpaqfs silently DROPS any file larger than blocksize^2/4 bytes:
  paqFile() warns ("file too big for blocksize") and returns nil, the
  file vanishes from the image, and mkpaqfs still exits 0.  At the
  4096 default blocksize the cap is 4 MiB — the 15.5 MB gs binary
  disappeared from bootfs-gs.paq and the guest saw no /bin/gs
  (measured on the gs smoke's third boot).  Every OTHER bake
  (build-9kdraw.sh's bootfs-draw.paq, the trace rig, mkimage's
  payloads) rides the default blocksize with no stderr check: a
  payload member growing past 4 MiB vanishes with only a stderr line.
  15-07's own harness asserts the fit and fails on any mkpaqfs
  diagnostic; the general fix (make the drop fatal in
  sys/src/cmd/paqfs/mkpaqfs.c, or assert sizes in the shared bake
  helpers) owns a plan that touches the payload machinery.
  status: open
  **What:** sys/src/cmd/paqfs/mkpaqfs.c paqFile()/paqDir() warn-and-drop.

- rc's Execute prints only the LAST path candidate's errstr when a
  command is not found (sys/src/cmd/rc/plan9.c Execute: the loop
  overwrites errstr per candidate), so `gs: './gs' file does not
  exist` masked the real /bin/gs failure behind the trailing-dot
  candidate.  Diagnosability wart (the first candidate's or the
  matching candidate's error would say what actually failed); worked
  around in-guest by absolute-path invocations.  A fix owns rc's
  plan9.c.
  status: open
  **What:** sys/src/cmd/rc/plan9.c Execute errstr overwrite.

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
