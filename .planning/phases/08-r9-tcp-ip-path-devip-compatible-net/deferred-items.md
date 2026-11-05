## Deferred Items

- Pre-existing r9 compiler/clippy warnings (observed during 08-01's verify legs; none name smoltcp)
  status: open
  **What:** `cargo xtask check`/`clippy` surface pre-existing warnings untouched by this plan: `port` test files (`devroot_rawimg_test.rs:19` unused `Chan` import; `devenv_test.rs:249` unused `mut`), `port` lib 11 clippy warnings (e.g. `virtio.rs:515` manual_range_contains), `aarch64` bin 32 warnings (unused consts/methods: `AUX_MU_BAUD`, `TrapFrame::sp/psr`, `RootPageTable::empty`), `x86_64` devcons `unnecessary_mut_passed`. Out of 08-01's scope per the deviation scope boundary (not caused by this plan's changes); the 08-01 verify gates pass with exit 0.
