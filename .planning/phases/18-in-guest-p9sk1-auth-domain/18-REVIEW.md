---
phase: 18-in-guest-p9sk1-auth-domain
reviewed: 2026-11-14T07:26:48Z
depth: standard
files_reviewed: 55
files_reviewed_list:
  - build/x86_64/authdomain.example
  - build/x86_64/authdomain-gen.c
  - build/x86_64/authdomain-selftest.sh
  - build/x86_64/authdom-donors/auth.h
  - build/x86_64/authdom-donors/authsrv.h
  - build/x86_64/authdom-donors/crypt.c
  - build/x86_64/authdom-donors/des.c
  - build/x86_64/authdom-donors/desCBC.c
  - build/x86_64/authdom-donors/desmodes.c
  - build/x86_64/authdom-donors/hmac.c
  - build/x86_64/authdom-donors/libc.h
  - build/x86_64/authdom-donors/libsec.h
  - build/x86_64/authdom-donors/mp.h
  - build/x86_64/authdom-donors/nvcsum.c
  - build/x86_64/authdom-donors/os.h
  - build/x86_64/authdom-donors/passtokey.c
  - build/x86_64/authdom-donors/sha1block.c
  - build/x86_64/authdom-donors/sha1.c
  - build/x86_64/authdom-donors/strecpy.c
  - build/x86_64/authdom-donors/u.h
  - build/x86_64/authprobe.c
  - build/x86_64/auth-sweep.rc
  - build/x86_64/auth-termrc
  - build/x86_64/mkimage.sh
  - build/x86_64/randread.c
  - build/x86_64/README.md
  - build/x86_64/root-tree/lib/ndb/local.template
  - build/x86_64/root-tree/lib/netaddr.rc
  - build/x86_64/secstore-obj.txt
  - build/x86_64/smoke-r9-auth.expect
  - build/x86_64/stage-build.sh
  - build/x86_64/tiers/tier2-services.txt
  - flake.lock
  - flake.nix
  - .github/workflows/r9-shell.yml
  - .gitignore
  - nix/smoke-r9-auth-x64.sh
  - ../r9/Cargo.toml
  - ../r9/flake.nix
  - ../r9/port/src/dat.rs
  - ../r9/port/src/devcap.rs
  - ../r9/port/src/devcap_tests.rs
  - ../r9/port/src/devcons.rs
  - ../r9/port/src/hmacsha1.rs
  - ../r9/port/src/lib.rs
  - ../r9/port/src/namec.rs
  - ../r9/x86_64/Cargo.toml
  - ../r9/x86_64/lib/config_q35auth.toml
  - ../r9/x86_64/src/cpu.rs
  - ../r9/x86_64/src/entropy.rs
  - ../r9/x86_64/src/main.rs
  - ../r9/x86_64/src/proc.rs
  - ../r9/x86_64/src/syscall.rs
  - ../r9/xtask/src/lib.rs
  - ../r9/xtask/src/main.rs
findings:
  critical: 2
  warning: 2
  info: 5
  total: 9
  necessity: 1
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-11-14T07:26:48Z
**Depth:** standard
**Files Reviewed:** 55 (33 Harvey + 18 r9, plus 4 config/meta)
**Status:** issues_found

## Summary

Standard-depth adversarial review of the Phase 18 "In-Guest p9sk1 Auth Domain" file set across both repos. The build machinery (mkimage.sh §14, authdomain-gen.c, the self-test, the expect gate, the nix driver) is unusually rigorous — bake-time pairing asserts, negative controls, redaction, and survivor sweeps all check out against the donor sources (Nvrsafe 109/112 layout, KEYDBLEN 73, writeusers record shape, speaksfor row form, and the randread/devcap HMAC fixture all re-verified independently this review; the fixture HMAC reproduces exactly). The vendored donor set is byte-identical to the in-tree originals (crypt/des*/sha1*/strecpy identical to libsec/libc/libauthsrv; authsrv.h/libsec.h identical to sys/include) — no findings there, per the phase contract.

Two Critical findings land in the r9 kernel half. First, the phase wired `iseve()` (the base of devcap's `#¤/caphash` hostowner gate) to the `#c/hostowner` static while leaving the `/dev/hostowner` write completely ungated — the donor's `hostownerwrite` (sys/src/9k/port/sysauth.c:152-153) is iseve-gated, so any process can rewrite the eve base and mint capability hashes, defeating the exact trust boundary the phase's own HOSTOWNER-GATE marker claims to prove. Second, the new x86_64 entropy classifier reads the RDRAND CPUID bit from leaf 7's ECX instead of leaf 1's ECX — objectively wrong wiring that both current venues (TCG qemu64, KVM -cpu host with RDSEED) mask by accident.

The known recorded items (r9 devip two-write TCP defect / AUTH-08 partial, #68 services dns-stage trap, eqn.c regeneration noise, WINDOWS ledger drift) were not re-reported.

## Critical Issues

### CR-01: Ungated `/dev/hostowner` write defeats the devcap eve gate (authorization bypass)

**File:** `../r9/port/src/devcons.rs:579-585` (write arm), `../r9/port/src/devcons.rs:288-295` (`iseve`), consumer `../r9/port/src/devcap.rs:199,247-248`
**Issue:** Phase 18-02 (commit 0358cbe) made `HOSTOWNER` the comparison base of `iseve()` — and therefore the trust boundary of `#¤/caphash` (devcap's hostowner gate) — but the `QID_HOSTOWNER` write arm stores any bytes from any process with no `iseve()` check, no length bound, and no validation (`open()` at devcons.rs:348-363 does not gate it either; `sys_pwrite` dispatches straight to `devcons::write`). The module comment at devcons.rs:178 even says "the glenda no-op's **guarded** `#c/hostowner` write stores here" — no guard exists. Exploit chain inside this phase's own guest: a process mutated to a non-eve user by capuse writes its own name to `/dev/hostowner` (now `current_user() == base` → `iseve()` true), opens `#¤/caphash` (the Eperm gate passes), posts an arbitrary HMAC hash, presents the matching `from@to@key` string, and becomes any user. This directly falsifies the substrate gate's own asserted contract — randread's `cap: HOSTOWNER-GATE` marker ("the mutated user is no longer eve") is bypassable by one write to a file the same kernel serves. The donor is explicit: `hostownerwrite` (sys/src/9k/port/sysauth.c:148-165) errors `Eperm` for non-eve writers and `Ebadarg` for n <= 0 or n >= 128, then renames the user and re-seeds both eve and up->user. The write pre-dates this phase (present at 8f753ca), but only this phase made it security-load-bearing.
**Fix:** In `devcons.rs`, gate the write on the same base it feeds:

```rust
QID_HOSTOWNER => {
    if !iseve()? {
        return Err("devcons: hostowner requires the hostowner");
    }
    if buf.is_empty() || buf.len() >= 128 {
        return Err("devcons: bad hostowner write");
    }
    let node = LockNode::new();
    let mut stored = HOSTOWNER.lock(&node);
    stored.clear();
    stored.extend_from_slice(buf);
    Ok(buf.len() as u64)
}
```

(Decide deliberately whether the donor's rename-user side effects belong in this era; the gate itself is the must-fix. Add a devcons host pin for the non-eve refusal, and consider having randread's HOSTOWNER-GATE leg attempt the `/dev/hostowner` write and assert its refusal — that would give the bypass its own marker.)

### CR-02: RDRAND CPUID bit read from leaf 7 ECX instead of leaf 1 ECX (entropy source misclassification)

**File:** `../r9/x86_64/src/entropy.rs:108-111`
**Issue:** `armed_source()` does:

```rust
let (max_leaf, _, _, _) = cpu::cpuid(0, 0);
let (_, ebx7, ecx1, _) = cpu::cpuid(7, 0);
classify(max_leaf, ecx1, ebx7)
```

`cpu::cpuid` returns `(eax, ebx, ecx, edx)` (cpu.rs:164-185), so `ecx1` is bound to **leaf 7's ECX**, while `has_rdrand` tests leaf-**1** ECX bit 30 (`cpu::has_rdrand`, cpu.rs:224-226, whose doc and the entropy.rs module header both state "RDRAND when only leaf-1 ECX bit 30 is present"). Leaf 7 subleaf 0 ECX bit 30 is not the RDRAND feature bit. Consequences: on RDRAND-without-RDSEED hardware (Ivy Bridge/Hasberg class — RDRAND shipped two generations before RDSEED) the classifier falls through to the jitter fold, silently downgrading the entropy source and printing the wrong `random: source=` label (the q35auth venue assert would then red the KVM leg as a "venue mismatch"); in the inverse direction, a CPU/hypervisor that sets leaf-7 ECX bit 30 without leaf-1 RDRAND arms the RDRAND instruction path on a CPU that would #UD on it (kernel fault at first seed). Both current venues classify correctly only by accident: TCG qemu64 exposes neither feature bit, and the dev KVM host has RDSEED, which wins via the correctly-sourced leaf-7 EBX. The host pins exercise `classify()` with synthetic values (`entropy_classify_orders_rdseed_rdrand_jitter`), so no test executes the mis-wired probe.
**Fix:**

```rust
let (max_leaf, _, _, _) = cpu::cpuid(0, 0);
let (_, _, cpuid1_ecx, _) = cpu::cpuid(1, 0);
let (_, cpuid7_ebx, _, _) = cpu::cpuid(7, 0);
classify(max_leaf, cpuid1_ecx, cpuid7_ebx)
```

(Note the second call's leaf must remain 7 for EBX; the bug is only the ECX binding — one fresh `cpuid(1, 0)` call supplies the correct ECX.)

## Warnings

### WR-01: One-byte stack overflow in `authdomain-gen -V`/`-i` on a manifest of exactly `Filecap` bytes

**File:** `build/x86_64/authdomain-gen.c:615-616` (verify), `build/x86_64/authdomain-gen.c:775-776` (info)
**Issue:** `readfile(dir, "manifest", (uchar*)manifest, Filecap)` can legitimately return `Filecap` (65536) — the exactly-full case is only distinguished from "one more byte hiding" when a further read succeeds; a file of exactly `Filecap` bytes returns `cap` with no error. Both callers then execute `manifest[n] = 0` with `n == Filecap`, writing one NUL past the end of `char manifest[Filecap]`. `-V` is explicitly the doctored-input-facing arm of the pairing contract (the self-test's negative-control class and `AUTHBAKE_DOCTOR` exist to prove its teeth), so a hostile/corrupted staging dir reaching exactly 64 KiB turns the refusal tool into a stack OOB write (crash under a stack protector; memory corruption otherwise). Same shape in `info()`.
**Fix:** Size the read one byte short so the terminator always fits, and treat the extra byte as an error:

```c
char manifest[Filecap];
int n = readfile(dir, "manifest", (uchar*)manifest, Filecap-1);
manifest[n] = 0;
```

(a file of `Filecap` or more bytes then fails loudly inside `readfile`'s "bigger than %d bytes" check, which is the correct verdict for a non-artifact).

### WR-02: Generator accepts passwords the donor `passtokey` silently truncates at 27 chars

**File:** `build/x86_64/authdomain-gen.c:84,343-344,357-362` vs `build/x86_64/authdom-donors/passtokey.c:11-13`
**Issue:** `adduser` rejects passwords only at `strlen(pw) >= Maxpw` (32) and `setfield` allows `machine_password` up to 31 chars, but the donor `passtokey` caps input at `ANAMELEN-1` = 27 (`n = strlen(p); if(n >= ANAMELEN) n = ANAMELEN-1;`) with no diagnostic. A real-domain `authdomain.local` with two user lines (or a machine password) whose first 27 characters are shared silently derives identical DES keys — the keys file pairs "correctly" (the manifest verifies, keyfs loads) while the domain does not mean what the operator wrote. The committed `authdomain.example` documents no length limit at all. The `Maxpw=32` comment ("passtokey reads <=27") shows the constraint was known but never enforced where the bytes enter.
**Fix:** Enforce the donor envelope at the interface boundary — in `adduser` and in the `machine_password`/`secstore_password` handling (or at least `machine_password`, which derives the master key):

```c
if(strlen(pw) >= 28)
	sysfatal("user %s: password longer than 27 chars (passtokey's limit)", name);
```

and document the 27-char limit in `authdomain.example` (the secstore field is already correctly bounded at 13 by CONFIGLEN).

## Info

### IN-01: Workflow comment overstates the CI contract — the secstore round-trip is NAMED-SKIPPED, not exercised

**File:** `.github/workflows/r9-shell.yml:96`
**Issue:** The `auth-smoke-x64` job comment says the gate runs "the speaksfor C probe with its fail-closed deny control) and the secstore PUT/GET round-trip." The gate does the opposite on the round-trip: `smoke-r9-auth.expect:442-447` asserts `AUTH-OK secstore-roundtrip` is **PROVABLY absent** (the named SKIP for the recorded r9 devip two-write defect). Gates are measurement instruments whose comments describe the contract; this one misdescribes what green means to any reader auditing CI's proof coverage.
**Fix:** Reword to "...and the secstore substrate with the PUT/GET round-trip NAMED-SKIPPED (r9-devip-two-write-tcp; the gate asserts the round-trip verdict stays absent)."

### IN-02: Sweep's secondary probe address lives outside the netaddr seam

**File:** `build/x86_64/auth-sweep.rc:220`
**Issue:** Leg 3 adds a raw `192.168.237.1 255.255.255.255` probe address inline. The D-11 single-seam doctrine (netaddr.rc: "NO gate or fixture hardcodes a ... per-leg address anywhere else") mechanically covers only `root-tree/lib` (mkimage §10b greps), so this is not a bake-red violation, but it is the same class of literal the seam exists to prevent — a future venue colliding with 192.168.237.0/24 would have to be found by eye, exactly what D-11's "never the eye later" rationale rejects.
**Fix:** Add a `probe2_guestv4=192.168.237.1` key to `root-tree/lib/netaddr.rc` and substitute at bake time (or extend the seam grep scope to the committed sweeps if in-guest fixtures are deliberately out of seam scope — then record that verdict in netaddr.rc like the v6 deferral note).

### IN-03: Modulo bias in `genpassword`

**File:** `build/x86_64/authdomain-gen.c:215`
**Issue:** `alph[r[i] % (nelem(alph)-1)]` folds 256 byte values onto 62 symbols; 256 % 62 = 8, so the first 8 alphabet characters are ~1.6% more likely than the rest. Immaterial for the throwaway DEMO material (D-01) and real key material comes from `authdomain.local`, so this is recorded, not demanded.
**Fix:** Rejection-sample (`if(r[i] < 248) use it; else redraw`) or note the bias as accepted for DEMO-only use.

### IN-04: Necessity — tick-hook infrastructure feeds a value that provably nothing reads

**File:** `../r9/port/src/devcap.rs:84-90,109-123,216`; registration `../r9/x86_64/src/main.rs:461-465`
**Category:** necessity
**Issue:** The donor's `Caphash.ticks` is written by `addcap` and consulted by nothing upstream (verified: the only other reference in donor devcap.c is the assignment), and the port carries that dead field deliberately (documented, `#[allow(dead_code)]`). But the port goes beyond donor parity: it builds a live `TICK_HOOK` registry with assert-once registration, a `set_tick_hook`/`ticks_now` seam, and a `main.rs` registration under `cfg(dev_cap)` — ~30 lines of live machinery whose only product is a value that cannot be read by anything in either tree. The guarded state ("no tick source") is not a state that matters; the field it feeds is provably inert (devcap.rs's own doc comment is the proof). Judgment-level, not repo-provable-harmful, hence Info: removal is a scope decision against the documented donor-honesty rationale.
**Fix:** Either seed `ticks: 0` with a comment citing donor parity (dropping the hook machinery and the main.rs registration), or keep the field but document the hook as a deliberate test/audit seam in devcap.rs so a later necessity pass does not re-litigate it.

### IN-05: Whitespace-bearing local-file passwords break the sweep's factotum leg non-obviously

**File:** `build/x86_64/authdomain-gen.c:402-410` (password = rest of line) vs `build/x86_64/auth-sweep.rc:324-325` (`if(~ $#authpw 1)`)
**Issue:** `parsefile`'s `user <name> <password>` form accepts any bytes after the second field, including spaces; `authdomain.example` documents no restriction. The sweep captures the feed with rc's default `ifs`, so a password containing whitespace splits into multiple words, `$#authpw` != 1, and the factotum leg is skipped with `AUTH-FAIL factotum` — loud, but the operator's path from that marker back to "my password has a space" is long. `genpassword` never generates such passwords (alnum only), so the DEMO path is unaffected.
**Fix:** Cheapest is at the generator: reject passwords containing IFS-class bytes (`' '`, `\t`) in `adduser` with a named error, since the committed interface cannot express them to the sweep anyway.

---

_Reviewed: 2026-11-14T07:26:48Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
