---
status: checkpoint_port_src_and_20-14_overlap
trigger: "Fix the ORCLOSE gap now: ORCLOSE must take effect for local devices on both arches, so that /srv files etc. are removed on close. Plan 20-14 owns aarch64 remove (syscall 25 is unimplemented); if ORCLOSE needs that remove path on aarch64, checkpoint the overlap before implementing. Arch-only, otherwise checkpoint with the diff. Plan 20-11 adds `T1-OK cexeccreate` concurrently; don't edit tier1-sweep.rc."
created: 2026-11-20T18:05:00Z
updated: 2026-11-20T18:05:00Z
---

## Current Focus

bug_class: Bohrbug (by reading: no code path records or acts on ORCLOSE for a local device)
hypothesis: H1 (by reading, unambiguous) — r9 never records ORCLOSE on a chan (no CRCLOSE twin on Chan; open_chan and sys_create drop it for local devices) AND devsrv/devenv have no remove op, so a local file opened/created ORCLOSE is never removed at its last close; devmnt is already fine (ORCLOSE rides the Topen/Tcreate wire byte, the server removes at clunk)
test: drafted + host-tested fix in scratch clone scratchpad/r9-rc (base 42203d8 = origin/main); patch scratchpad/rc/orclose-draft.patch (sha256 21dbc853…)
expecting: owner/coordinator decision before implementation (port/src + plan 20-14 overlap)
next_action: CHECKPOINT returned. On approval: boot RED probe (new build/aarch64/rcloseprobe.c, /srv + /env legs) at the 42203d8 kernel, apply the draft on main HEAD, GREEN probe HVF+TCG, aarch64 TCG gates, x64 container gates + boot-iso hash + cleanup, local commits
arch_only_verdict: NOT POSSIBLE — (1) devsrv's registry is a private port static (port/src/devsrv.rs:59 `static SRV`) and EnvGroup's entries are private, so no arch code can remove an entry; (2) last-close detection needs a reference shared by the open's dups (Chan is copied by value per fd; arch code cannot add a Chan field); (3) the close paths that must act (exit drains, exec sweep, dup eviction, op-ref release in port/src/fdgrp.rs op_done) run port's close_chan
overlap_with_20-14: ORCLOSE does NOT need syscall 25 (REMOVE) or an aarch64 sys_remove; it needs the DEVICE remove ops (devsrv::remove, devenv::remove — new in port) that REMOVE("/srv/x"), REMOVE("/env/x") would also dispatch to. x86_64's remove routing is arch-local (x86_64/src/syscall.rs:898 remove_chan, DEV_CAP only); the draft adds a second, port-side routing for the close path (namec::remove_if_last_rclose: DEV_SRV, DEV_ENV). 20-14 must decide whether aarch64's sys_remove (and x86_64's remove_chan) gain DEV_SRV/DEV_ENV arms over these ops, or route through one shared port dispatch
related_session: resolved/create-ocexec-not-marked.md (archived 2026-11-20; MemPalace absent — knowledge-base.md is the only index)

## Symptoms

expected: (donor chan.c:1412/1518 + devsrv.c:287 srvclose + devenv.c:229 envclose) a file opened or created with ORCLOSE is removed when the LAST reference to its chan closes — e.g. lib9p postfd's `/srv/<name>` (OWRITE|ORCLOSE|OCEXEC) disappears when the server exits
actual: (reading) r9 records no remove-on-close for local devices; the /srv post outlives its server
errors: none (stale /srv and /env entries)
reproduction: create /srv/x (or /env/x) ORCLOSE, close the fd (or exit), stat the name — it is still there
started: since devsrv/devenv were ported (no remove arm ever existed)

## Eliminated

## Evidence

- timestamp: 2026-11-20T18:05:00Z
  checked: knowledge-base.md (4 entries incl. create-ocexec-not-marked)
  found: create-ocexec-not-marked's meta-lesson applies directly — "an fd-state bit carried in the mode word (OCEXEC, ORCLOSE) must be recorded on EVERY arm that yields a chan"; method notes for host-compiled probes and the amd64 container reused
  implication: known-pattern candidate (same class as the OCEXEC gap); test it first

- timestamp: 2026-11-20T18:05:00Z
  checked: donor sys/src/9k/port chan.c:1412-1413, 1518-1519; devsrv.c:109, 287-297, 324; devenv.c:229; sysfile.c:164
  found: Aopen and Acreate both set CRCLOSE when omode has ORCLOSE (after the device op); srvclose and envclose call srvremove/envremove when CRCLOSE is set (errors ignored — cclose can't fail); dev->close runs only at the LAST cclose (decref); srvopen refuses ORCLOSE on the #s dir (Eperm); srvwrite refuses to post an fd with CCEXEC|CRCLOSE
  implication: the contract is per-device remove at last close, gated by a chan flag

- timestamp: 2026-11-20T18:05:00Z
  checked: r9 42203d8 grep ORCLOSE/CRCLOSE/rclose (aarch64, x86_64, port) and every `fn remove`
  found: ORCLOSE appears only as the dat.rs constant and in devmnt's wire-byte comments (devmnt.rs:879, 1077); no chan flag; remove ops: only port/src/devcap.rs:359 `remove`, reached from x86_64/src/syscall.rs:898 `remove_chan` (arch-local routing: DEV_CAP only, every other device refuses); aarch64 has no REMOVE at all (plan 20-14)
  implication: devsrv and devenv cannot remove an entry today on either arch — the device half of ORCLOSE is missing in port/src, not just the flag

- timestamp: 2026-11-20T18:20:00Z
  checked: r9 42203d8 port/src/dat.rs Chan (fields, new, dup, op_clone, drop_op_ref), namec.rs open_chan/close_chan, devmnt.rs open/create mode byte + clunk_if_last, devsrv.rs (SRV static, create/open/write), devenv.rs (EnvGroup API), fdgrp.rs op_done, both arches' exit_tail + release_fd_group
  found: Chan has no rclose state; dup/op_clone copy by value (shared state rides Arcs — devmnt's fid Arc + clunk_if_last is the last-close model, incl. the op-ref corner in drop_op_ref); devmnt passes `(mode & 0xff)` on Topen and the low byte on Tcreate, so mounted ORCLOSE already works server-side; devsrv's SRV registry and EnvGroup.entries are private with no remove; both exit tails run release_fd_group (drained.drain(..): one chan consumed per close) BEFORE sweep_husk_payloads swaps the env group; fdgrp op_done calls drop_op_ref UNDER the fd-group lock
  implication: an arch-only fix does not exist; a port fix can follow the devmnt-fid pattern (an Arc token per ORCLOSE open, remove when the closing chan holds the last share)

- timestamp: 2026-11-20T18:40:00Z
  checked: draft fix in scratchpad/r9-rc (on 42203d8), patch scratchpad/rc/orclose-draft.patch — port: Chan.rclose: Option<Arc<()>> (new/dup/op_clone), namec::mark_fd_state (OCEXEC+ORCLOSE; open_chan uses it), namec::remove_if_last_rclose (DEV_SRV → devsrv::remove, DEV_ENV → devenv::remove, errors dropped) called first in close_chan and in drop_op_ref, devsrv::remove (+ the donor's Eperm for ORCLOSE on the #s dir), EnvGroup::remove + devenv::remove; arch: both create_new_chan call port::namec::mark_fd_state; 7 files +220/-25
  found: |
    cargo xtask test (darwin) rc=0, incl. namec_tests::{orclose_srv_entry_goes_at_the_last_close_only, orclose_remove_waits_for_an_in_flight_op_ref, orclose_env_key_goes_at_the_last_close}; cargo test -p aarch64 --bins 32/32 (31 + syscall::create_cexec_tests::created_orclose_srv_post_goes_at_the_last_close); x86_64 twin test added (not yet run — container leg); cargo xtask check rc=0, no new compiler warning (the one extra line is nix's dirty-tree notice)
    mutants (port, `-- orclose`): M0 close arm removed (= today) KILLED 2; M1 last-close guard removed KILLED 2; M2 mark not recorded KILLED 3
  implication: the draft is credible and tested on host; held at the checkpoint (port/src + 20-14 overlap) — no r9 or Harvey source change committed
