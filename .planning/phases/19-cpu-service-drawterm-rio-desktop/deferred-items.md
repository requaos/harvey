# Phase 19 deferred items

## [19-10 Leg-1 continuation] the §14 auth image's sweep hardcodes dom=DEMO-harvey (user-domain breakage)

Found during the 19-10 Leg-1 authid root-cause (2026-11-15): `build/x86_64/auth-sweep.rc:331`
loads factotum's client key as `key proto=p9sk1 user=norbert dom=DEMO-harvey ...` — a
hardcoded DEMO domain token in the §14 AUTH image's bring-up sweep. With a repo-root
`authdomain.local` present (any user-supplied domain), the §14 bake stages that domain's
paired material, the local authsrv advertises the user authdom, and the sweep's
client-side p9sk1 probes fail their key lookup on the dom mismatch — `nix run
.#smoke-r9-auth-x64` would red on such a checkout (it was green when the gate last ran
with no authdomain.local present; the owner's file landed after).

- Same family as the Leg-1 defect (the p9sk1 key/dom pairing assumed the DEMO domain),
  but a DIFFERENT image (§14 auth, not §15 cpu) and a DIFFERENT consumer (the gate
  sweep's client probes, not the cpu server's listener key).
- Out of the Leg-1 fix's scope: Leg-1's path (boot --system=cpu + drawterm) never
  touches the §14 image; fixing the sweep's literal means re-keying the auth gate's
  expectations (the sweep's marker vocabulary) against a per-bake authdom.
- Reopener/owner: the next plan that runs `.#smoke-r9-auth-x64` on a checkout carrying
  an `authdomain.local`, or the next §14-touching plan. Fix shape: parse the authdom
  from the baked /lib/ndb/local (the cpurc leg-5 idiom, group-free sed) instead of the
  literal.

## 19-10 Leg-1 substrate (D-11 continuation, 2026-11-15): two open findings

### 1. drawterm cpu-session mouse delivery — rio runs but synthetic X mouse events drive nothing

- Observed: the windowed session's desktop is UP (rio's 0x777777 grey, deterministic
  across runs; evidence/19-10-leg1-desktop-grey*.png) and rio's fsys serves
  (label/winname probes on the serial), but XTEST mouse moves/clicks (xdotool) never
  open the B3 menu or sweep a window; the whole window stays uniform grey. The X
  keyboard path WORKS (the password feed; the pre-fix sessions' rio error lines
  printed to the window), and the 9P cons path works both ways over /mnt/term.
- Suspect: the drawterm-side /dev/mouse read path under the exportfs (a parked
  mouseread + the xmouse wakeup) — a path NO prior gate exercises (the -G gate has
  no mouse; the 15-06 rio traces rode the KERNEL-side devdraw + mousein replays).
  Not root-caused: host ptrace is yama-restricted in this venue (strace could not
  follow drawterm's threads), and the 2-attempt fix budget was spent on the
  root-caused iounit defect instead.
- Impact on Leg 1: the OWNER with a real mouse may well be unaffected (real X events
  vs XTEST synthetics were not distinguished before the venue ran out of probing
  tools); the automated Xvfb leg could not open a window, so no window screenshot.
- Reopener: the first drawterm-side plan; drive drawterm's exportfs against its own
  devmouse on the host (no guest needed) and pin the parked-read wakeup.

### 2. aborted wrong-password connections poison the guest's auth service

- Observed: three windowed connections fed the wrong password (norbert's, on the
  owner's distinct-password domain) and were abandoned mid-negotiation; after the
  first abort, every later connection died at `cpu: srvauth: namec: does not exist`
  (the server-side p9any proxy missing a file — consistent with the per-connection
  proxy's factotum/rpc state dying on the aborted connection and the /mnt/factotum
  mount going stale for later listeners' children). A fresh boot restored the
  service; the single-connection wrong-password RETRY loop (drawterm's re-prompt)
  is fine — only the connection-abort class poisoned it.
- Not root-caused (the harness artifact forced the fresh-boot route); recorded so
  the robustness defect has a home. Reopener: the next r9 kernel pass (factotum's
  hangup handling under aux/listen's per-connection forks).
