---
schema_version: 1
open_count: 7
waived_count: 1
fixed_count: 1
total_count: 9
last_updated: 2026-11-02T13:58:40.990Z
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
  }
]
````
