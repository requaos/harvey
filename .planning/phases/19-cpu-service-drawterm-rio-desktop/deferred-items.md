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
