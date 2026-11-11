# Phase 16 Deferred Items

Out-of-scope discoveries logged during plan execution (the scope-boundary
rule: pre-existing issues unrelated to the current task are recorded,
not fixed).

- r9 xtask pcap.rs dead-code warnings (4): `frame_len` on Icmpv4Frame/BootpFrame, `dst_mac`/`frame_len` on Icmpv6Frame, `src_mac`/`dst_mac`/`frame_len` on Tcpv4Frame are constructed by the live parsers but never read by any live gate assert.
  status: open
  **Found during:** 16-01 Task 1 (the lib split's warning sweep)
  **Proof pre-existing:** built pristine base 5f856c9 in a throwaway worktree — identical warnings; the 16-01 diff did not touch any reader or writer of these fields.
  **Why not fixed:** unrelated to netdev; silencing them means either reading the fields in new asserts or deleting them — a gate-evidence decision for a kernel-flush-out plan, not this one.
