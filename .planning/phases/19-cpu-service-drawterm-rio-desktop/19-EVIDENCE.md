# Phase 19 Evidence — DESK-07 human acceptance + the INT-07 clean-checkout proof

**Phase:** 19-cpu-service-drawterm-rio-desktop
**Consolidated:** 2026-11-15 (plan 19-10)
**Status:** checkpoint-pending — the two human-acceptance rows below are UNSIGNED scaffolds awaiting the owner's own sessions (blocking-human gates, D-13); the darwin graphical deferral is recorded (owner decision 2026-11-14); the INT-07 clean-checkout record is automated and real. Nothing below is claimed human-accepted that a human did not accept: **an unsigned row is not evidence** (the plan's own prohibition), and a recipe that was never run is not evidence either (venue honesty).

## The pinned substrate

| Repo | SHA | Role |
|------|-----|------|
| r9 (`requaos/r9`, flake input `r9`, type github) | `df4ad78d0177b60b48603e00fd9ba786e2d3c69f` | the flake.lock pin every session and gate below rides; `== origin/main` (pushed, verified 2026-11-15). The clean-checkout proof consumes r9 through this pin only — nix fetches the locked commit itself; no sibling clone participates. |
| harvey | `e39585500392c203237e3b9fcf56feefab0800c7` | the tree at scaffold time (19-09's docs head); the clean-checkout runs record their own clone SHAs below |

## DESK-07 human-acceptance rows (D-13 — one signed row + one screenshot per leg)

Each row becomes evidence ONLY when signed (date, venue, r9 SHA, accepter) with a
screenshot that resolves at its named path. Until then the row is a scaffold and
says so on its face.

### Row 1 — the linux graphical leg (the rio desktop in a drawterm window)

| Field | Value |
|-------|-------|
| Status | **PENDING — awaiting the owner's session** (blocking-human; no executor accepts a desktop on the owner's behalf) |
| Venue | linux-x86_64, KVM (qemu q35; slirp + the committed D-04 hostfwd pair `127.0.0.1:17010`/`127.0.0.1:5670`) |
| r9 SHA | `df4ad78d0177b60b48603e00fd9ba786e2d3c69f` (pre-filled from the flake.lock pin) |
| Date | *(to be signed)* |
| Accepter | *(to be signed)* |
| Screenshot | `evidence/19-10-linux-rio.png` *(to be captured — the interactive rio desktop visible in the drawterm window)* |
| Session notes | *(to be signed — MUST record: the desktop started IN-SESSION (the profile's `case cpu` exec, not at boot; the boot-side absence proof lives in the 19-07/19-08/19-09 gates) and ONE in-session plumbing observation — a plumber-fed action or the plumber's presence, DESK-05's in-session evidence)* |

The recipe (README §"The linux session recipe" + §"The full-system boot", executed
verbatim): boot `nix run .#boot-r9-x64 -- --system=cpu` in one terminal and leave
it running (wait for `cpurc: LISTEN-17010`); then `nix run .#drawterm` in another
terminal with a display — authenticate with the developer's local-file domain
credentials (the 18-D-01 shape, NOT the DEMO material) — accept the rio desktop
when it starts in the drawterm window; exercise it minimally (open a window, run
a command, one plumbing observation); take ONE screenshot; sign this row.

### Row 2 — the darwin -G text leg (the interactive cpu shell over the SSH tunnel)

| Field | Value |
|-------|-------|
| Status | **PENDING — awaiting the owner's session** (blocking-human; the recipe must be exercised FOR REAL before the row is signed) |
| Venue | darwin-aarch64, reaching the linux-hosted guest over the SSH tunnel (D-05) — `ssh -L 17010:127.0.0.1:17010 -L 5670:127.0.0.1:5670 user@linuxhost` with the linux guest left running per D-07 |
| r9 SHA | `df4ad78d0177b60b48603e00fd9ba786e2d3c69f` (pre-filled from the flake.lock pin — the same commit the darwin build clones) |
| Date | *(to be signed)* |
| Accepter | *(to be signed)* |
| Screenshot | `evidence/19-10-darwin-g.png` *(to be captured — Terminal.app showing the interactive cpu shell session over the tunnel)* |
| Session notes | *(to be signed — the exact commands run on the mac and any recipe delta found; any delta is fixed in the README/vendor BEFORE the row is signed so the exercised recipe and the committed recipe match)* |

The recipe (README §"The darwin page — DOCUMENTED-MANUAL, `-G` only", the
amended-D-03 gui-none build — no Carbon, no XQuartz):

```
git clone <harvey> && cd harvey/sys/src/cmd/unix/drawterm
make CONF=osx GUI=none
ssh -L 17010:127.0.0.1:17010 -L 5670:127.0.0.1:5670 user@linuxhost
./drawterm -G -O 'cpu=127.0.0.1,auth=tcp!127.0.0.1!5670,user=glenda'
```

## The darwin graphical deferral (owner decision — recorded, not a this-phase leg)

**Deferred 2026-11-14 by owner decision** (the amended D-03 / the OQ-1
settlement): this milestone ships no darwin window backend. The darwin `-G` text
leg above IS this phase's darwin row (Row 2). **Reopener:** a future milestone
phase porting a 64-bit Cocoa/AppKit backend (the 9front `gui-cocoa` class) into
`sys/src/cmd/unix/drawterm`. **XQuartz was considered and rejected** (an
X11-on-mac dependency for a Plan 9 client is a compatibility layer too far; the
native window path belongs to the reopener). The deferral is recorded in
REQUIREMENTS.md (the DESK-07 annotation) and STATE.md (the Deferred Items row);
DESK-07 is NOT silently marked fully complete — the two rows above must be
signed first.

## INT-07 — the clean-checkout proof of the v2.1 chain (linux-x86_64)

*(To be recorded by the automated run: the fresh-clone SHA, the r9 locked rev,
the commands, the verdicts. If the clean checkout misses anything, that is a
real defect: fix the packaging/composition, never note-around it.)*

---
*Phase: 19-cpu-service-drawterm-rio-desktop*
*Scaffold: 2026-11-15 (plan 19-10; the human rows await the owner's sessions)*
