# Phase 19 deferred items

## [19-10 Leg-1 continuation 3, 2026-11-16] the dual-cons-reader defect: ROOT-CAUSED LIVE and FIXED at the kernel layer (r9 56109c3)

Owner report recap: swept window's shell alternating keystrokes with rio's
keyboard reader, prompt/output painted at the drawterm cons layer's left
edge over the desktop.

**Root cause (proven on the owner's LIVE guest, evidence
`19-10-leg1-livecons-probe.log`):** r9's mount-table consults were keyed
by PATH STRING, not by the mount-point CHAN's identity (the donor
findmount/eqchanddq shape). rio's winshell child (wind.c:1341:
`mount /mnt/wsys MREPL` + `bind -b /mnt/wsys /dev`) then opens
`/dev/cons`; the cpu profile REPL-binds the terminal cons AT `/dev/cons`
(`bind /mnt/term/dev/cons /dev/cons`), so namec's final-component
redirect re-consulted "/dev/cons" BY PATH and replaced the correctly
head-resolved wsys cons chan with the SESSION terminal cons — fds 0/1/2
of the window's rc landed on the session cons (two readers on one cons =
the alternation; rc's prompt to fd 1 = the left-edge painting). The live
discriminator on the owner's guest: `bind -b '#e' /dev` +
`cat /dev/consctl` → `devmnt: server error` (the open was hijacked into
the REPL bind's 9P chan; the control `cat /dev/livprobe` proved the union
head itself was consulted and first-accepting).

**Fix (r9 fe67c75, pin advanced to 56109c3 by flake.lock commit ff21c4786):**
identity-keyed mount points — `Chan.devno` (devmnt stamps each 9P session,
the donor's mntalloc.id++), pgrp's MountPoint keyed by the mount-point chan
(Mhead.from), all five namec consult sites match (dev, devno, qid.path).
Also aligned sys_unmount's two arg resolutions to the donor sysunmount
shape (old→Amount, name→Aopen OREAD; the pre-fix code had them swapped).
Choreography executed in full: host battery green (xtask check + clippy +
port 163 lib + 74 integration incl. the new RED→GREEN hijack pin),
two-derivation FOD proof (fe67c75 plain + fcab10c marker clone:
byte-identical ISOs, file sha256 fb11e6b0…, NAR sha256-BfU8eS…, three-way
agreed), FOD re-wired (r9 56109c3, flake.nix only), pushed, hosted CI
observed SUCCESS at the pushed HEAD (run 43887537787), harvey lock-only
advance.

**Live fix verification on a fresh guest at the new pin** (evidence
`19-10-leg1-livecons-verify.log`; verification guest booted with hostfwd
remapped to 17011/5671 — the owner's live guest held the canonical ports;
cpurc ladder ETHER-OK/LISTEN-17010/DONE + authenticated drawterm session):
the SAME discriminator now returns `HEAD-WINS-CTL` — the union head's
resolution survives the final redirect. Windowed-leg proof rides the
owner's reboot + re-presentation (window creation still needs a real
mouse sweep; the synthetic-mouse block stands).

Residual observations recorded below (the /srv item's attribution
CORRECTED by this pass).

### [CORRECTED 2026-11-16] the "r9 /srv open blocks foreign rio driving" finding

The `mount /srv/rio… → mount: namec: does not exist` line was rc's
EXEC-failure print: **`mount`/`unmount` binaries are not in the §15 cpu
image** (zero occurrences in out/bootfs-cpu.paq's name table; verified
2026-11-16). mount(1) never ran; the /srv open was never reached. The
OTHER leg stands unexplained: writing through a posted /srv file →
`devsrv: fd string too long` (a real devsrv parser observation).
Reopener unchanged (first r9 devsrv pass), plus: stage mount/unmount
into a future image tier when a venue needs them.

### the r9 /srv open/write path blocks foreign rio driving (two shapes)

From `evidence/19-10-leg1-cont-srvctl.log` (live guest, glenda sessions):

- Writing THROUGH a posted `/srv` file (`echo 'new …' >/srv/riowctl…`)
  → `devsrv: fd string too long` — the write reaches the publish-command
  parser, not the posted service's pipe.
- Opening/mounting rio's posted service (`mount /srv/rio.glenda.51 /mnt`)
  → `mount: namec: does not exist` from mount(1) — **[corrected
  2026-11-16: this was rc failing to exec mount(1) — the binary is not in
  the §15 image; see the corrected item above]**

Net effect: no foreign process (a `-G` side session, the serial shell) can
drive a live rio's wctl — window creation without a real mouse is
impossible on this venue. Also candidate material for the /tmp finding
below. Reopener: the first r9 devsrv pass.

### /tmp unwritable in a cpu session despite the ramfs stanza

`mkdir /tmp/u` in a `-G` session → `namec: does not exist`
(`evidence/19-10-leg1-cont-gunion.log`), while the profile's ramfs stanza
runs in every cpu session (ps showed the parallel session's ramfs process
alive). The image stages `/tmp` (§15's STAGE9 mkdir set) and the profile
falls back to ramfs on the create failure, yet the writable mount did not
take effect in the probed session. One observation, not root-caused
(possibly the same posted-/srv mount class as above — ramfs mounts through
its own postmountsrv). Reopener: the next venue needing session `/tmp`.

## [19-10 Leg-1 continuation 2, 2026-11-16] the dual-cons-reader report vs the live tree: profile exonerated, window-child path open

(SUPERSEDED by the root-cause item above — kept for the record.)

Owner report (after the sweep fix worked): a window swept open OK, but a
prompt painted on the cons layer at the left edge OVER the desktop and only
every other keystroke reached the window (typed chars visible in the window;
output at the out-of-window prompt). Orchestrator diagnosis: the session
`rc -li` left alive beside rio; prescribed fix: the windowed profile case
must end `exec rio`.

Live refutation (KVM guest, the current tree's bake, 2026-11-15/16):

- The staged profile's guarded windowed block ALREADY ends `exec rio`
  (`build/x86_64/root-tree/usr/glenda/lib/profile` line 49; §15's P6 bake
  assert pins `exec rio` in the cpu case) — there was nothing profile-side
  to fix, and any image re-bake would be byte-identical.
- A `-G` side session's `ps` against the LIVE windowed session (evidence
  `19-10-leg1-cont-ps.log`) shows the windowed session's chain as
  `tcp17010 → rio` (rio pid 51 + its libthread procs 70-74) with `plumber`
  (68/69) and `ramfs` (59) — **no `rc -li` survives the exec**. The two
  other `rc` entries are init's serial console shell and the probe's own.
- Login is single-reader end to end: an XTEST-typed marker line + Enter at
  the empty grey desktop produced NO painting on the cons layer
  (`19-10-leg1-cont-desktop-keys-2.png`; with no window open, rio swallows
  keys silently).
- r9's MBEFORE union semantics are head-insert/first-accepting by source
  (`port/src/pgrp.rs` bind(), MBEFORE arm) — rio's winshell
  `/dev/cons`-through-the-union shape is kernel-correct on paper.

Open mechanism (hypothesis, NOT root-caused — the fix-everything bar is
unmet without reproduction): the only process a sweep adds is the window's
own `rc -i`, and the symptom's alternation + left-side prompt/output fits
that child reading and writing the SESSION cons instead of its wsys window
cons. Not reproducible on the automated venue: the synthetic XTEST mouse
still drives nothing (the prior recorded finding), and both programmatic
window-creation avenues into a live rio are blocked by r9-side defects
(below). Reopener: the owner's next windowed session with the README's
`ps` discriminator hot (a live one-line capture names the class), or the
first r9 devsrv/srv-mount pass that unblocks automated rio driving.


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
