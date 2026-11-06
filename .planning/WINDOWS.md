---
schema_version: 1
open_count: 40
waived_count: 3
fixed_count: 3
total_count: 46
last_updated: 2026-11-06T03:05:00.000Z
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
| 14 | 05 | stub | r9:aarch64/src/syscall.rs |  | CREATE(22) stays loud-unimplemented until 05-06 wires sys_create; devenv's create op is host-tested and slots in unchanged (init's setenv/cpenv path); plan-mandated ordering (05-05 Task 1 action step 1) | fixed |  | 2026-11-03T06:32:58.158Z | 2026-11-03T08:27:38.113Z |
| 15 | 05 | deviation | r9:aarch64/src/proc.rs |  | 05-05: plan's RFENVG/RFCENVG bullet inverted vs fork(2)+9k sysproc.c — donor governs (neither=share, RFENVG=copy, RFCENVG=empty); the 05-04 RFNAMEG/RFCNAMEG precedent; pinned by devenv_test.rs + the env-driven boot gate | open |  | 2026-11-03T06:32:58.375Z |  |
| 16 | 05 | deviation | r9:aarch64/src/proc.rs |  | 05-06: plan's fd-group bullet inverts RFFDG vs default vs fork(2)+9k sysproc.c (neither=SHARE, RFFDG=COPY, RFCFDG=empty) — the phase's third flag inversion; donor governs (libc fork()=RFFDG=COPY is what connectembed's dup/close needs); pinned by fdgroup_test.rs | open |  | 2026-11-03T08:27:38.289Z |  |
| 17 | 05 | deviation | r9:aarch64/src/fault.rs |  | 05-06: cold-syscall-buffer class fixed at the gate (EL1h DataAbort on paqfs's emalloc'd brk_-grown buffer — the kernel's pread made the first touch) — fault::ensure_user_resident generalizes 04-08's explicit page-in to any writable user buffer before deref; T-05-06 holds (never a nested fault); phase-04 deferred #3 closed for the growth class | open |  | 2026-11-03T08:27:38.460Z |  |
| 18 | 05 | todo | r9:port/src/namec.rs |  | 05-07: pgrp lock held across namec walks incl. devmnt's blocking Twalk RPCs — a pgrp-SHARING contender (fork shares the pgrp) spins IRQ-masked = wedge once the first concurrent namespace caller exists (rc pipelines/backgrounded cmds); the gate never contends (strictly sequential chain). Fix: snapshot the union chain under a brief lock, walk unlocked (phase deferred-items.md) | open |  | 2026-11-03T10:19:28.856Z |  |
| 19 | 05 | todo | r9:port/src/devcons.rs |  | 05-07: #c/pid absent — getpid() fails, init's pri-10 write names #p/0/ctl (the designed warning fires either way; the gate is unaffected). 05-09's devproc ctl is the first real consumer — add devcons's Qpid file (donor devcons.c) via a current-pid hook before it lands | open |  | 2026-11-03T10:19:29.077Z |  |
| 20 | 05 | deviation | build/aarch64/drive-r9.expect |  | interactive-driver input wedge flake: 2 of ~7 early sweep runs wedged at a prompt read (line never completes); 6 consecutive clean passes since; not reproducing under the cons watchdog; deferred as the top debug candidate for 05-12/05-13's CI leg | open |  | 2026-11-03T15:09:13.138Z |  |
| 21 | 05 | stub | .planning/phases/05-shell-boot-one-command-integration/deferred-items.md |  | r9-side: stat(5) records carry 3 strings (no muid) in devcons/devroot/devenv/devsrv/devdup listings — dirreadall's statcheck walks FOUR and rejects them (devproc fixed 05-09; the rest latent, no dirreadall consumer this era) | open |  | 2026-11-03T15:09:20.285Z |  |
| 22 | 05 | deviation | build/aarch64/drive-r9.expect |  | interactive-driver input wedge flake: 2 of ~7 early sweep runs wedged at a prompt read (line never completes); 6 consecutive clean passes since; not reproducing under the cons watchdog; deferred as the top debug candidate for 05-12/05-13's CI leg | open |  | 2026-11-03T15:09:20.518Z |  |
| 23 | 05 | stub | .planning/phases/05-shell-boot-one-command-integration/deferred-items.md |  | r9-side: stat records carry 3 strings no muid in devcons/devroot/devenv/devsrv/devdup listings - dirreadall statcheck walks FOUR and rejects them (devproc fixed 05-09) | waived | accidental duplicate of #21 (executor re-ran the append after a misleading tail display) | 2026-11-03T15:09:25.686Z | 2026-11-03T15:09:56.078Z |
| 24 | 05 | deviation | build/aarch64/drive-r9.expect |  | interactive-driver input wedge flake: 2 of ~7 early sweep runs wedged at a prompt read; 6 consecutive clean passes since; top debug candidate for 05-12/05-13 CI | waived | accidental duplicate of #20 (executor re-ran the append after a misleading tail display) | 2026-11-03T15:09:25.913Z | 2026-11-03T15:09:56.309Z |
| 25 | 261103-giq | deviation | build/harness/src/srv9.rs |  | Twstat name offset corrected to 47 (Dir wire shape is doubly size-prefixed); the .py's offset-45 rename was dead code — mv fell back to copy+delete | open |  | 2026-11-03T18:24:06.467Z |  |
| 26 | 261103-giq | deviation | build/harness/src/trace.rs |  | trace-syscalls: prompt-substring wait after pid probe closes the .py's latent echo/prompt race | open |  | 2026-11-03T18:24:06.688Z |  |
| 27 | 261103-giq | deviation | build/aarch64/vm-run.sh |  | rsync exclusion for build/harness/target added to the four vm-sync scripts | open |  | 2026-11-03T18:24:06.904Z |  |
| 28 | 261103-giq | deviation | build/aarch64/subset-exec.sh |  | guest-scratch CONF=qemu bootdir reset to pristine (39 accumulated rows exceeded Nbootfiles=32; pre-existing guest state) | open |  | 2026-11-03T18:24:07.120Z |  |
| 29 | 06 | deviation | build/aarch64/gethunk-repro-cc.sh |  | cc repro input shape changed from plan's >600KB string literal to digit/comma macro define (NSYMB/STRINGSZ caps reject the sketched shape before gethunk); use line dropped (macexpand Io.b 16KB cap) | open |  | 2026-11-04T23:18:26.722Z |  |
| 30 | 06 | deviation | build/aarch64/gethunk-repro-6l.sh |  | 6l repro input shape settled by A4 spike to >2.5MB archive __.SYMDEF bang-malloc (array toothless, string-literal impossible); venue linux-only (darwin sbrk 4096KB arena); fixed pair built from working tree not hostbin | open |  | 2026-11-04T23:18:26.940Z |  |
| 31 | 07 | deviation | build/aarch64/root-tree/lib/net-sweep.rc | 77 | dd syntax corrected to dash-pair form (-if/-of); the baked dd.c rejects classic if=/of= (plan prose corrected, gate-blocking) | open |  | 2026-11-05T00:04:57.930Z |  |
| 32 | 07 | deviation | build/aarch64/mkimage.sh | 165 | trailer magic re-extracted via od -j (Harvey host dd shadows POSIX dd on the devshell PATH — D-02 class) | open |  | 2026-11-05T00:04:58.144Z |  |
| 33 | 07 | deviation | build/aarch64/root-tree/lib/net-sweep.rc | 77 | dd syntax corrected to dash-pair form (-if/-of); the baked dd.c rejects classic if=/of= (plan prose corrected, gate-blocking) | open |  | 2026-11-05T00:05:04.202Z |  |
| 34 | 07 | deviation | build/aarch64/mkimage.sh | 165 | trailer magic re-extracted via od -j (Harvey host dd shadows POSIX dd on the devshell PATH — D-02 class) | open |  | 2026-11-05T00:05:08.206Z |  |
| 35 | 06 | deviation | .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-PLAN.md | 216 | 06-02 Task-3 verify gate 2 text defective: mk -n never recurses, so the nested-path grep on cmd's own output always counts 0; intent proven by chain probes in 06-02-SUMMARY; repair gate text at 06-03 planning | open |  | 2026-11-05T00:10:54.539Z |  |
| 36 | 07 | unrun-verify | r9:aarch64/src/platform/virt/pci.rs |  | 07-06 D6: virtio IRQ handler armed-and-inert-proven only; traffic-level proof lands with 07-08's NETDRV-04 gates (no traffic source until 07-07) | open |  | 2026-11-05T01:09:17.807Z |  |
| 37 | 06 | deviation | build/aarch64/coverage-sweep.sh |  | 06-04: second-chance visitation pass added — plan9port mk recipes abort at the first failing command (measured), so container recursion stops at the first failing sibling; the plan's adjacency truth (ipconfig+6 siblings visited) is otherwise unreachable with tier-0 libs outstanding; pass 2 gives each unvisited in-universe dir its own shimmed guarded mk all | open |  | 2026-11-05T02:10:46.163Z |  |
| 38 | 06 | deviation | build/aarch64/coverage-sweep.sh |  | 06-04: pass-2 initially invoked $REAL_MK directly — a leaf dir runs no nested mk so no VISIT line was logged (run-3 reconciliation failure); pass-2 visits now invoke bare mk through the shim | open |  | 2026-11-05T02:10:46.381Z |  |
| 39 | 06 | deviation | build/aarch64/coverage-sweep.sh |  | 06-04: namespace/devshell Plan 9-tool dialect fixes — sed {/pat/!p} group garbled (host), sed s/\|.*$// garbled by hostbin Plan 9 sed (namespace; silently emptied the exclusions in run 2), date -u +fmt prints the epoch under Plan 9 date — awk index/substr + host-precomputed plain-path exclusions + probe-verified ISO date | open |  | 2026-11-05T02:10:46.602Z |  |
| 40 | 06 | deviation | build/aarch64/generator-scan.sh |  | 06-04: ssh tree probes drained the audit-rows while-loop's stdin (only G1 checked on the first run) — all ssh probe sites carry </dev/null now | open |  | 2026-11-05T02:10:46.815Z |  |
| 41 | 06 | deviation | build/aarch64/generator-audit.txt |  | 06-04: plan/RESEARCH cells corrected against live mkfiles (plan-mandated re-confirmation): G5 artifact is o.pcode (cpuobjtype=o via /unix/mkfile O=o); G6 genarch is pcc-built native-only (build guard gs/mkfile:164), never built nor run in the aarch64 sweep | open |  | 2026-11-05T02:10:47.035Z |  |
| 42 | 06 | deviation | .planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-PLAN.md |  | 06-05 Task-2's literal no-PENDING-CLASSIFY grep contradicts Task-1's mandated append-only seed lines; ran the intent gate (latest-line-per-dir clean) — gate-text repair filed for the next planning pass | open |  | 2026-11-05T02:51:20.644Z |  |
| 43 | 08 | unmet-truth | r9:aarch64/src/proc.rs |  | 08-04: the NETIP-03 ping-127.0.0.1 truth is MET — RFMEM landed per the blocking-human decision (option A, donor dupseg semantics): Data/Bss pages share under RFMEM with PA-keyed refcount-gated frees, RFMEM families carry the shared break (sys_brk_ family arm births grown pages shared — the checkpoint's 'ping does not brk_-grow post-fork' premise was falsified at the gate and the donor's shared-segment growth is the implemented semantics), the rfork bss sweep closes the untouched-page hole, and SEMACQUIRE(37)/SEMRELEASE(38) implemented for the contended libc lock() path; virtip gate green (netip: ping ok + NETIP-DONE), 8/8 regression profiles green, r9 4298fc0 | fixed |  | 2026-11-05T19:54:26.000Z | 2026-11-05T22:30:00.000Z |
| 46 | 08 | deviation | .planning/phases/08-r9-tcp-ip-path-devip-compatible-net/deferred-items.md |  | 08-08: rc redirect-stack/fd-reuse corner — a file-open redirect (`> file`) or an in-block `>[2]/dev/null` on a backquote dd INSIDE a subshell block carrying a held-open fd redirect (`} >[6]/mnt/data`) leaks the payload into the held fd's pipe (measured twice in-guest; root cause unpinned — suspect class: doredir re-applies a stale ROPEN record whose from-fd was closed/reused, Dup() return unchecked at rc plan9.c:583); 08-08's aan fixture sidesteps by construction (the drop moved in-band via baked /lib/netip-aan-drop.rc; dd summary rides the console); recorded in the phase's deferred-items.md | open |  | 2026-11-06T03:05:00.000Z |  |
| 44 | 08 | deviation | r9:aarch64/src/proc.rs |  | 08-05: kernel arena (4 MiB QuickFit) drains under a spin loop of short-lived fork+exec — ~1400 iterations of /bin/cat from a fixture's port-discovery spin exhausted it (oom size=4160 panic); exec staging teardown (ByteBacking::Mnt) is the suspect; fixture-side workaround applied (invoke the baked name so the spin terminates) | open |  | 2026-11-05T23:35:00.000Z |  |
| 45 | 08 | deviation | r9:port/src/namec.rs |  | 08-05: Creat on a top-level file of a union-mounted dir misses non-head members — walk_one never consults the union chain (documented shape); rc's `>` is Creat-first so `> /net/log` failed with 'namec: device has no create'; fixture uses `>>` (open-first); the two-level-deep ctl writes unaffected | open |  | 2026-11-05T23:55:00.000Z |  |

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
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-11-03T06:32:58.158Z",
    "resolved_at": "2026-11-03T08:27:38.113Z",
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
  },
  {
    "id": 16,
    "kind": "deviation",
    "phase": "05",
    "file": "r9:aarch64/src/proc.rs",
    "line": null,
    "description": "05-06: plan's fd-group bullet inverts RFFDG vs default vs fork(2)+9k sysproc.c (neither=SHARE, RFFDG=COPY, RFCFDG=empty) — the phase's third flag inversion; donor governs (libc fork()=RFFDG=COPY is what connectembed's dup/close needs); pinned by fdgroup_test.rs",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T08:27:38.289Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 17,
    "kind": "deviation",
    "phase": "05",
    "file": "r9:aarch64/src/fault.rs",
    "line": null,
    "description": "05-06: cold-syscall-buffer class fixed at the gate (EL1h DataAbort on paqfs's emalloc'd brk_-grown buffer — the kernel's pread made the first touch) — fault::ensure_user_resident generalizes 04-08's explicit page-in to any writable user buffer before deref; T-05-06 holds (never a nested fault); phase-04 deferred #3 closed for the growth class",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T08:27:38.460Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 18,
    "kind": "todo",
    "phase": "05",
    "file": "r9:port/src/namec.rs",
    "line": null,
    "description": "05-07: pgrp lock held across namec walks incl. devmnt's blocking Twalk RPCs — a pgrp-SHARING contender (fork shares the pgrp) spins IRQ-masked = wedge once the first concurrent namespace caller exists (rc pipelines/backgrounded cmds); the gate never contends (strictly sequential chain). Fix: snapshot the union chain under a brief lock, walk unlocked (phase deferred-items.md)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T10:19:28.856Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 19,
    "kind": "todo",
    "phase": "05",
    "file": "r9:port/src/devcons.rs",
    "line": null,
    "description": "05-07: #c/pid absent — getpid() fails, init's pri-10 write names #p/0/ctl (the designed warning fires either way; the gate is unaffected). 05-09's devproc ctl is the first real consumer — add devcons's Qpid file (donor devcons.c) via a current-pid hook before it lands",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T10:19:29.077Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 20,
    "kind": "deviation",
    "phase": "05",
    "file": "build/aarch64/drive-r9.expect",
    "line": null,
    "description": "interactive-driver input wedge flake: 2 of ~7 early sweep runs wedged at a prompt read (line never completes); 6 consecutive clean passes since; not reproducing under the cons watchdog; deferred as the top debug candidate for 05-12/05-13's CI leg",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T15:09:13.138Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 21,
    "kind": "stub",
    "phase": "05",
    "file": ".planning/phases/05-shell-boot-one-command-integration/deferred-items.md",
    "line": null,
    "description": "r9-side: stat(5) records carry 3 strings (no muid) in devcons/devroot/devenv/devsrv/devdup listings — dirreadall's statcheck walks FOUR and rejects them (devproc fixed 05-09; the rest latent, no dirreadall consumer this era)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T15:09:20.285Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 22,
    "kind": "deviation",
    "phase": "05",
    "file": "build/aarch64/drive-r9.expect",
    "line": null,
    "description": "interactive-driver input wedge flake: 2 of ~7 early sweep runs wedged at a prompt read (line never completes); 6 consecutive clean passes since; not reproducing under the cons watchdog; deferred as the top debug candidate for 05-12/05-13's CI leg",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T15:09:20.518Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 23,
    "kind": "stub",
    "phase": "05",
    "file": ".planning/phases/05-shell-boot-one-command-integration/deferred-items.md",
    "line": null,
    "description": "r9-side: stat records carry 3 strings no muid in devcons/devroot/devenv/devsrv/devdup listings - dirreadall statcheck walks FOUR and rejects them (devproc fixed 05-09)",
    "status": "waived",
    "reason": "accidental duplicate of #21 (executor re-ran the append after a misleading tail display)",
    "recorded_at": "2026-11-03T15:09:25.686Z",
    "resolved_at": "2026-11-03T15:09:56.078Z",
    "milestone": null
  },
  {
    "id": 24,
    "kind": "deviation",
    "phase": "05",
    "file": "build/aarch64/drive-r9.expect",
    "line": null,
    "description": "interactive-driver input wedge flake: 2 of ~7 early sweep runs wedged at a prompt read; 6 consecutive clean passes since; top debug candidate for 05-12/05-13 CI",
    "status": "waived",
    "reason": "accidental duplicate of #20 (executor re-ran the append after a misleading tail display)",
    "recorded_at": "2026-11-03T15:09:25.913Z",
    "resolved_at": "2026-11-03T15:09:56.309Z",
    "milestone": null
  },
  {
    "id": 25,
    "kind": "deviation",
    "phase": "261103-giq",
    "file": "build/harness/src/srv9.rs",
    "line": null,
    "description": "Twstat name offset corrected to 47 (Dir wire shape is doubly size-prefixed); the .py's offset-45 rename was dead code — mv fell back to copy+delete",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T18:24:06.467Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 26,
    "kind": "deviation",
    "phase": "261103-giq",
    "file": "build/harness/src/trace.rs",
    "line": null,
    "description": "trace-syscalls: prompt-substring wait after pid probe closes the .py's latent echo/prompt race",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T18:24:06.688Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 27,
    "kind": "deviation",
    "phase": "261103-giq",
    "file": "build/aarch64/vm-run.sh",
    "line": null,
    "description": "rsync exclusion for build/harness/target added to the four vm-sync scripts",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T18:24:06.904Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 28,
    "kind": "deviation",
    "phase": "261103-giq",
    "file": "build/aarch64/subset-exec.sh",
    "line": null,
    "description": "guest-scratch CONF=qemu bootdir reset to pristine (39 accumulated rows exceeded Nbootfiles=32; pre-existing guest state)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-03T18:24:07.120Z",
    "resolved_at": null,
    "milestone": null
  },
  {
    "id": 29,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/gethunk-repro-cc.sh",
    "line": null,
    "description": "cc repro input shape changed from plan's >600KB string literal to digit/comma macro define (NSYMB/STRINGSZ caps reject the sketched shape before gethunk); use line dropped (macexpand Io.b 16KB cap)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-04T23:18:26.722Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 30,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/gethunk-repro-6l.sh",
    "line": null,
    "description": "6l repro input shape settled by A4 spike to >2.5MB archive __.SYMDEF bang-malloc (array toothless, string-literal impossible); venue linux-only (darwin sbrk 4096KB arena); fixed pair built from working tree not hostbin",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-04T23:18:26.940Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 31,
    "kind": "deviation",
    "phase": "07",
    "file": "build/aarch64/root-tree/lib/net-sweep.rc",
    "line": 77,
    "description": "dd syntax corrected to dash-pair form (-if/-of); the baked dd.c rejects classic if=/of= (plan prose corrected, gate-blocking)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T00:04:57.930Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 32,
    "kind": "deviation",
    "phase": "07",
    "file": "build/aarch64/mkimage.sh",
    "line": 165,
    "description": "trailer magic re-extracted via od -j (Harvey host dd shadows POSIX dd on the devshell PATH — D-02 class)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T00:04:58.144Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 33,
    "kind": "deviation",
    "phase": "07",
    "file": "build/aarch64/root-tree/lib/net-sweep.rc",
    "line": 77,
    "description": "dd syntax corrected to dash-pair form (-if/-of); the baked dd.c rejects classic if=/of= (plan prose corrected, gate-blocking)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T00:05:04.202Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 34,
    "kind": "deviation",
    "phase": "07",
    "file": "build/aarch64/mkimage.sh",
    "line": 165,
    "description": "trailer magic re-extracted via od -j (Harvey host dd shadows POSIX dd on the devshell PATH — D-02 class)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T00:05:08.206Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 35,
    "kind": "deviation",
    "phase": "06",
    "file": ".planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-02-PLAN.md",
    "line": 216,
    "description": "06-02 Task-3 verify gate 2 text defective: mk -n never recurses, so the nested-path grep on cmd's own output always counts 0; intent proven by chain probes in 06-02-SUMMARY; repair gate text at 06-03 planning",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T00:10:54.539Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 36,
    "kind": "unrun-verify",
    "phase": "07",
    "file": "r9:aarch64/src/platform/virt/pci.rs",
    "line": null,
    "description": "07-06 D6: virtio IRQ handler armed-and-inert-proven only; traffic-level proof lands with 07-08's NETDRV-04 gates (no traffic source until 07-07)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T01:09:17.807Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 37,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/coverage-sweep.sh",
    "line": null,
    "description": "06-04: second-chance visitation pass added — plan9port mk recipes abort at the first failing command (measured), so container recursion stops at the first failing sibling; the plan's adjacency truth (ipconfig+6 siblings visited) is otherwise unreachable with tier-0 libs outstanding; pass 2 gives each unvisited in-universe dir its own shimmed guarded mk all",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T02:10:46.163Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 38,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/coverage-sweep.sh",
    "line": null,
    "description": "06-04: pass-2 initially invoked $REAL_MK directly — a leaf dir runs no nested mk so no VISIT line was logged (run-3 reconciliation failure); pass-2 visits now invoke bare mk through the shim",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T02:10:46.381Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 39,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/coverage-sweep.sh",
    "line": null,
    "description": "06-04: namespace/devshell Plan 9-tool dialect fixes — sed {/pat/!p} group garbled (host), sed s/|.*$// garbled by hostbin Plan 9 sed (namespace; silently emptied the exclusions in run 2), date -u +fmt prints the epoch under Plan 9 date — awk index/substr + host-precomputed plain-path exclusions + probe-verified ISO date",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T02:10:46.602Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 40,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/generator-scan.sh",
    "line": null,
    "description": "06-04: ssh tree probes drained the audit-rows while-loop's stdin (only G1 checked on the first run) — all ssh probe sites carry </dev/null now",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T02:10:46.815Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 41,
    "kind": "deviation",
    "phase": "06",
    "file": "build/aarch64/generator-audit.txt",
    "line": null,
    "description": "06-04: plan/RESEARCH cells corrected against live mkfiles (plan-mandated re-confirmation): G5 artifact is o.pcode (cpuobjtype=o via /unix/mkfile O=o); G6 genarch is pcc-built native-only (build guard gs/mkfile:164), never built nor run in the aarch64 sweep",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T02:10:47.035Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 42,
    "kind": "deviation",
    "phase": "06",
    "file": ".planning/phases/06-full-tree-userspace-wave-0-libraries-core-tiers/06-05-PLAN.md",
    "line": null,
    "description": "06-05 Task-2's literal no-PENDING-CLASSIFY grep contradicts Task-1's mandated append-only seed lines; ran the intent gate (latest-line-per-dir clean) — gate-text repair filed for the next planning pass",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-05T02:51:20.644Z",
    "resolved_at": null,
    "milestone": "v2.0"
  },
  {
    "id": 43,
    "kind": "unmet-truth",
    "phase": "08",
    "file": "r9:aarch64/src/proc.rs",
    "line": null,
    "description": "08-04: the NETIP-03 ping-127.0.0.1 truth is MET — RFMEM landed per the blocking-human decision (option A, donor dupseg semantics): Data/Bss pages share under RFMEM with PA-keyed refcount-gated frees, RFMEM families carry the shared break (sys_brk_ family arm births grown pages shared — the checkpoint's 'ping does not brk_-grow post-fork' premise was falsified at the gate and the donor's shared-segment growth is the implemented semantics), the rfork bss sweep closes the untouched-page hole, and SEMACQUIRE(37)/SEMRELEASE(38) implemented for the contended libc lock() path; virtip gate green (netip: ping ok + NETIP-DONE), 8/8 regression profiles green, r9 4298fc0",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-11-05T19:54:26.000Z",
    "resolved_at": "2026-11-05T22:30:00.000Z",
    "milestone": "v2.0"
  },
  {
    "id": 46,
    "kind": "deviation",
    "phase": "08",
    "file": ".planning/phases/08-r9-tcp-ip-path-devip-compatible-net/deferred-items.md",
    "line": null,
    "description": "08-08: rc redirect-stack/fd-reuse corner — a file-open redirect (`> file`) or an in-block `>[2]/dev/null` on a backquote dd INSIDE a subshell block carrying a held-open fd redirect (`} >[6]/mnt/data`) leaks the payload into the held fd's pipe (measured twice in-guest; root cause unpinned — suspect class: doredir re-applies a stale ROPEN record whose from-fd was closed/reused, Dup() return unchecked at rc plan9.c:583); 08-08's aan fixture sidesteps by construction (the drop moved in-band via baked /lib/netip-aan-drop.rc; dd summary rides the console); recorded in the phase's deferred-items.md",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-11-06T03:05:00.000Z",
    "resolved_at": null,
    "milestone": "v2.0"
  }
]
````
