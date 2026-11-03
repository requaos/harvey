---
schema_version: 1
open_count: 13
waived_count: 1
fixed_count: 1
total_count: 15
last_updated: 2026-11-03T06:32:58.375Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 02 | deviation | sys/src/libmach/executable.c |  | 02-02: 9c host probe substituted with direct host-clang (plan9port header shadowing, A3 fallback); 7.c/7obj.c compile proofs deferred to 02-06/02-03 by plan design | open |  | 2026-10-31T17:02:41.072Z |  |
| 2 | 02 | deviation | sys/src/libmach/executable.c |  | 02-02: 9c host probe substituted with direct host-clang (plan9port header shadowing, A3 fallback); 7.c/7obj.c compile proofs deferred to 02-06/02-03 by plan design | open |  | 2026-10-31T17:02:46.189Z |  |
| 3 | 02 | deviation | sys/src/cmd/pcc.c |  | 02-06 verify(a): pcc functional proof relocated to lima guest — pcc.c execs /bin/cpp + /bin/7c absolute; darwin /bin SIP-sealed (pre-existing); proof passed in guest (PCC-PROOF-PASS) | open |  | 2026-11-01T15:15:57.249Z |  |
| 4 | 03 | deviation | .planning/phases/03-r9-qemu-virt-platform-bring-up/03-01-PLAN.md | 101 | 03-01 gate-2 toolchain probe (rustc --version \| grep nightly-2026-01-30) unsatisfiable — rustc prints source-commit date; corrected to store-path identity proof (rust-default-1.95.0-nightly-2026-01-30). See 03-01-SUMMARY deviation 4. | open |  | 2026-11-01T22:33:17.552Z |  |
| 5 | 03 | deviation | xtask/src/main.rs |  | 03-03 raspi3b boot-smoke gate satisfied by substituted A/B evidence (human-approved); upstream raspi3b/qemu-11.1.2 defect deferred | open |  | 2026-11-01T23:15:26.857Z |  |
| 6 | 03 | deviation | r9/aarch64/src/main.rs |  | 03-04: verify block-2's 'mkdir -p ... && qemu ... &' binds & to the whole list, so $QP names a subshell, not qemu; with a stale log the first poll (i=1) reads pre-boot content and the kill orphans qemu mid-boot. Gate passes deterministically from a fresh log (rm first). 03-05's D-11 boot-test socket chardev avoids this pattern. (File ref is r9-repo-relative: ../r9) | open |  | 2026-11-01T23:44:10.289Z |  |
| 7 | 03 | unrun-verify | r9/aarch64/src/trap.rs |  | 03-06: trap.rs sync dump path gained 'kernel halted' + wfi park on ALL platforms; verified live on virt (virtpanic evidence) but compile-only on raspi — raspi boot verification is blocked by the known upstream raspi-on-qemu-11.1.2 defect (03-03/03-04 deferred, WINDOWS #5). Behavior change is dump-path-only. (File ref is r9-repo-relative: ../r9) | open |  | 2026-11-02T00:33:39.701Z |  |
| 8 | 04 | deviation | .planning/phases/04-r9-userspace-exec-harvey-r9-abi/04-05-PLAN.md |  | 04-05: plan's Task-2 raw-qemu verify leg written against the pre-amendment -initrd mechanism (falsified 04-01, D-01 AMENDED); executed with the amended loader+patched-DTB delivery, grep chain unchanged | fixed |  | 2026-11-02T13:58:26.801Z | 2026-11-02T13:58:40.779Z |
| 9 | 04 | deviation | .planning/phases/04-r9-userspace-exec-harvey-r9-abi/04-05-PLAN.md |  | test-shape-probe | waived | Accidental probe entry appended while checking the windows CLI output shape (executor error, no content); the real entry is #8. | 2026-11-02T13:58:30.416Z | 2026-11-02T13:58:40.990Z |
| 10 | 04 | deviation | .planning/phases/04-r9-userspace-exec-harvey-r9-abi/deferred-items.md |  | 04-07: exec_bootstrap IRQ-masked until first EL0 entry (heisenbug exposure closed by construction; root cause = deferred-items #4) | open |  | 2026-11-02T18:41:05.291Z |  |
| 11 | 05 | stub | r9:port/src/devcons.rs |  | cons reads return loud -1 until 05-08 wires the PL011 RX ring through the device (plan-mandated; open succeeds) | open |  | 2026-11-03T05:59:51.093Z |  |
| 12 | 05 | stub | r9:port/src/devproc.rs |  | devproc directory reads + status/args absent this plan; 05-08/05-09 grow them (ps needs /proc/*/status) | open |  | 2026-11-03T05:59:51.314Z |  |
| 13 | 05 | deviation | r9:aarch64/src/exec.rs |  | exec maps data+bss eagerly (cold syscall-arg residency) — D-09-letter adjustment, T-05-06 honored; phase-04 deferred #3 closed for the argument class | open |  | 2026-11-03T05:59:51.532Z |  |
| 14 | 05 | stub | r9:aarch64/src/syscall.rs |  | CREATE(22) stays loud-unimplemented until 05-06 wires sys_create; devenv's create op is host-tested and slots in unchanged (init's setenv/cpenv path); plan-mandated ordering (05-05 Task 1 action step 1) | open |  | 2026-11-03T06:32:58.158Z |  |
| 15 | 05 | deviation | r9:aarch64/src/proc.rs |  | 05-05: plan's RFENVG/RFCENVG bullet inverted vs fork(2)+9k sysproc.c — donor governs (neither=share, RFENVG=copy, RFCENVG=empty); the 05-04 RFNAMEG/RFCNAMEG precedent; pinned by devenv_test.rs + the env-driven boot gate | open |  | 2026-11-03T06:32:58.375Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "02",
    "file": "sys/src/libmach/executable.c",
    "line": null,
    "description": "02-02: 9c host probe substituted with direct host-clang (plan9port header shadowing, A3 fallback); 7.c/7obj.c compile proofs deferred to 02-06/02-03 by plan design",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-31T17:02:41.072Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "02",
    "file": "sys/src/libmach/executable.c",
    "line": null,
    "description": "02-02: 9c host probe substituted with direct host-clang (plan9port header shadowing, A3 fallback); 7.c/7obj.c compile proofs deferred to 02-06/02-03 by plan design",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-31T17:02:46.189Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "02",
    "file": "sys/src/cmd/pcc.c",
    "line": null,
    "description": "02-06 verify(a): pcc functional proof relocated to lima guest — pcc.c execs /bin/cpp + /bin/7c absolute; darwin /bin SIP-sealed (pre-existing); proof passed in guest (PCC-PROOF-PASS)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-01T15:15:57.249Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 4,
    "kind": "deviation",
    "phase": "03",
    "file": ".planning/phases/03-r9-qemu-virt-platform-bring-up/03-01-PLAN.md",
    "line": 101,
    "description": "03-01 gate-2 toolchain probe (rustc --version | grep nightly-2026-01-30) unsatisfiable — rustc prints source-commit date; corrected to store-path identity proof (rust-default-1.95.0-nightly-2026-01-30). See 03-01-SUMMARY deviation 4.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-01T22:33:17.552Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 5,
    "kind": "deviation",
    "phase": "03",
    "file": "xtask/src/main.rs",
    "line": null,
    "description": "03-03 raspi3b boot-smoke gate satisfied by substituted A/B evidence (human-approved); upstream raspi3b/qemu-11.1.2 defect deferred",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-01T23:15:26.857Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "03",
    "file": "r9/aarch64/src/main.rs",
    "line": null,
    "description": "03-04: verify block-2's 'mkdir -p ... && qemu ... &' binds & to the whole list, so $QP names a subshell, not qemu; with a stale log the first poll (i=1) reads pre-boot content and the kill orphans qemu mid-boot. Gate passes deterministically from a fresh log (rm first). 03-05's D-11 boot-test socket chardev avoids this pattern. (File ref is r9-repo-relative: ../r9)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-01T23:44:10.289Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 7,
    "kind": "unrun-verify",
    "phase": "03",
    "file": "r9/aarch64/src/trap.rs",
    "line": null,
    "description": "03-06: trap.rs sync dump path gained 'kernel halted' + wfi park on ALL platforms; verified live on virt (virtpanic evidence) but compile-only on raspi — raspi boot verification is blocked by the known upstream raspi-on-qemu-11.1.2 defect (03-03/03-04 deferred, WINDOWS #5). Behavior change is dump-path-only. (File ref is r9-repo-relative: ../r9)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-02T00:33:39.701Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 8,
    "kind": "deviation",
    "phase": "04",
    "file": ".planning/phases/04-r9-userspace-exec-harvey-r9-abi/04-05-PLAN.md",
    "line": null,
    "description": "04-05: plan's Task-2 raw-qemu verify leg written against the pre-amendment -initrd mechanism (falsified 04-01, D-01 AMENDED); executed with the amended loader+patched-DTB delivery, grep chain unchanged",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-11-02T13:58:26.801Z",
    "resolved_at": "2026-11-02T13:58:40.779Z",
    "milestone": null
  },
  {
    "id": 9,
    "kind": "deviation",
    "phase": "04",
    "file": ".planning/phases/04-r9-userspace-exec-harvey-r9-abi/04-05-PLAN.md",
    "line": null,
    "description": "test-shape-probe",
    "status": "waived",
    "reason": "Accidental probe entry appended while checking the windows CLI output shape (executor error, no content); the real entry is #8.",
    "recorded_at": "2026-11-02T13:58:30.416Z",
    "resolved_at": "2026-11-02T13:58:40.990Z",
    "milestone": null
  },
  {
    "id": 10,
    "kind": "deviation",
    "phase": "04",
    "file": ".planning/phases/04-r9-userspace-exec-harvey-r9-abi/deferred-items.md",
    "line": null,
    "description": "04-07: exec_bootstrap IRQ-masked until first EL0 entry (heisenbug exposure closed by construction; root cause = deferred-items #4)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-02T18:41:05.291Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 11,
    "kind": "stub",
    "phase": "05",
    "file": "r9:port/src/devcons.rs",
    "line": null,
    "description": "cons reads return loud -1 until 05-08 wires the PL011 RX ring through the device (plan-mandated; open succeeds)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T05:59:51.093Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 12,
    "kind": "stub",
    "phase": "05",
    "file": "r9:port/src/devproc.rs",
    "line": null,
    "description": "devproc directory reads + status/args absent this plan; 05-08/05-09 grow them (ps needs /proc/*/status)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T05:59:51.314Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 13,
    "kind": "deviation",
    "phase": "05",
    "file": "r9:aarch64/src/exec.rs",
    "line": null,
    "description": "exec maps data+bss eagerly (cold syscall-arg residency) — D-09-letter adjustment, T-05-06 honored; phase-04 deferred #3 closed for the argument class",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T05:59:51.532Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 14,
    "kind": "stub",
    "phase": "05",
    "file": "r9:aarch64/src/syscall.rs",
    "line": null,
    "description": "CREATE(22) stays loud-unimplemented until 05-06 wires sys_create; devenv's create op is host-tested and slots in unchanged (init's setenv/cpenv path); plan-mandated ordering (05-05 Task 1 action step 1)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T06:32:58.158Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 15,
    "kind": "deviation",
    "phase": "05",
    "file": "r9:aarch64/src/proc.rs",
    "line": null,
    "description": "05-05: plan's RFENVG/RFCENVG bullet inverted vs fork(2)+9k sysproc.c — donor governs (neither=share, RFENVG=copy, RFCENVG=empty); the 05-04 RFNAMEG/RFCNAMEG precedent; pinned by devenv_test.rs + the env-driven boot gate",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T06:32:58.375Z",
    "resolved_at": null,
    "milestone": null
  }
]
````
