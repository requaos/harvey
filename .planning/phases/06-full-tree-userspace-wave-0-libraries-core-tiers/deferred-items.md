# Phase 6 — Deferred Items

Items discovered during execution that are pre-existing and NOT caused by the
current task's changes (executor scope boundary — logged, not fixed).

## Deferred Items

- macexpand expansion path cannot carry a >16KB macro
  status: open
  **Found during:** 06-01 Task 1 (gethunk repro input-shape spike)
  **What:** `cc/macbody`'s `macexpand(s, b)` writes the expansion into
  `Io.b[BUFSIZ=16KB]` (`cc.h:154-161`) with no output bound, and the io
  layer's length field is a `short` — a macro whose expansion exceeds 16KB
  compiles the define fine (post-gethunk-fix) but fails at the use site
  with a misleading "saw $end"-class syntax error (observed: `bigmacro.c:3
  syntax error, last name: 1` on a >600KB macro use with the FIXED 6c/7c).
  Pre-existing upstream limitation, orthogonal to the gethunk hang (which
  fires at define time); no in-tree source defines macros anywhere near
  this size.
  **Status:** open — fix only if a real consumer ever needs >16KB macro
  expansion.

- darwin host sbrk arena is capped at exactly 4096KB per process
  status: open
  **Found during:** 06-01 Task 2 (A4 input-shape spike)
  **What:** measured on macOS 14 SDK (apple-sdk-14.4, darwin-arm64): sbrk
  fails after 4096KB regardless of chunk granularity. Any host-side gate
  needing a process to grow the break past ~4MB (e.g. a fixed gethunk
  linker accumulating past its 2.5MB ceiling, ~5MB total) cannot run
  natively on darwin — route through linux (native or lima guest), as
  `build/aarch64/gethunk-repro-6l.sh` does.
  **Status:** open — platform fact, venue constraint for future
  gethunk-class gates.

- 6l (and likely 8l/5l/9l/ql/vl/4l/kl) share the 7l LP64 double-constant
  emission bug — latent, no current consumer
  status: open
  **Found during:** 06-03 Task 1 (the hawk float-canary fault → 7l fix)
  **What:** 7l's datfill D_FCONST case-8 emitted double constants via a
  cast over `struct Ieee {long l; long h;}` — 16 bytes on LP64 hosts,
  so only l's low half + l's zero high half were written (fixed in 06-03
  for 7l, commit `2bbca81ed`).  6l's asm.c D_FCONST case-8 has the same
  shape (`cast = (uchar*)&p->to.ieee` with Ieee EMBEDDED in the Adr
  union — 16 bytes on LP64, fnuxi8 reads only the first 8 = l's bytes).
  Latent: the amd64 9k build carries no non-trivial double data
  constants, so nothing in the default build consumes the path (v1.0
  never printed a float anywhere).  Fix when an amd64/386 consumer
  appears, using the 06-03 7l fix as the pattern (emit the two 32-bit
  halves via int[2]); the dormant-arch letters (8l/5l/9l/ql/vl/4l/kl)
  should be audited at the same time.
  **Status:** open — latent toolchain class, deliberately not fixed in
  06-03 (amd64 leg kept byte-untouched; scope boundary).
