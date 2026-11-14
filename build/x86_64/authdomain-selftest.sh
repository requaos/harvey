#!/bin/sh
# authdomain-selftest.sh — the standing CI-able proof of the bake-time
# p9sk1 domain generator (18-03, AUTH-01).
#
# Builds authdomain-gen from the vendored Harvey donor algorithm files
# (authdom-donors/) with the host C compiler, then proves:
#   - the ephemeral DEMO path (no local file): one run produces the
#     hash-paired unit — nvram exactly 109 bytes (Nvrsafe), keys
#     exactly 8+3*73 (KEYDBOFF + three 73-byte records), the speaksfor
#     ndb rows, and the manifest with the label row — and -V verifies
#   - the local-file interface path (Task 3): a filled-in copy of the
#     committed authdomain.example drives its own label/authdom/users
#     with distinct passwords; a requested-but-missing -f refuses
#   - verify-mode teeth (Task 2): four doctored-input classes each
#     refuse with a nonzero exit and their own marker
#   - label discipline (Task 2): the DEMO token in the nvram authdom
#     span and in the manifest rows; -i prints the parsed fields
#   - /authdomain.local is gitignored and NOTHING is written inside
#     the repo working tree (all artifacts land in a mktemp dir)
#
# Terminal marker on full green: GEN-SELFTEST-OK (the last line).

set -u

fail()
{
	echo "GEN-SELFTEST-FAIL: $*" >&2
	exit 1
}

# repo root from this script's home (build/x86_64/..)
SELFDIR=$(cd "$(dirname "$0")" && pwd) || fail "can't resolve script dir"
HARVEY=$(cd "$SELFDIR/../.." && pwd) || fail "can't resolve repo root"
[ -f "$HARVEY/build/x86_64/authdomain-gen.c" ] || fail "not run from a checkout?"
DONORS="$HARVEY/build/x86_64/authdom-donors"

# host C compiler (the vendored donors are plain portable C)
CC=${CC:-cc}
command -v "$CC" >/dev/null 2>&1 || CC=gcc
command -v "$CC" >/dev/null 2>&1 || fail "no host C compiler (cc/gcc) on PATH"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/authdom-selftest.XXXXXX") || fail "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || fail "can't cd workdir"	# also ensures the generator's
					# default ./authdomain.local can
					# never pick up repo-root files

# zero repo-working-tree writes: compare porcelain before/after
GITBEFORE=$(cd "$HARVEY" && git status --porcelain | sha1sum | cut -d' ' -f1)

echo "== build: $CC over the vendored donor files"
# shellcheck disable=SC2086
"$CC" -O2 -Wno-unknown-pragmas -I"$DONORS" -o gen \
	"$HARVEY/build/x86_64/authdomain-gen.c" \
	"$DONORS"/passtokey.c "$DONORS"/nvcsum.c "$DONORS"/crypt.c \
	"$DONORS"/des.c "$DONORS"/desCBC.c "$DONORS"/desmodes.c \
	"$DONORS"/sha1.c "$DONORS"/sha1block.c "$DONORS"/hmac.c \
	"$DONORS"/strecpy.c >build.log 2>&1 \
	|| { cat build.log; fail "generator build failed"; }

echo "== DEMO path: generate + verify over a mktemp staging dir"
./gen -o demo >gen.log 2>&1 || { cat gen.log; fail "DEMO generate exited nonzero"; }
./gen -V demo >verify.log 2>&1 \
	|| { cat verify.log; fail "verify refused a fresh DEMO unit"; }
grep -q '^verify: OK dir=demo label=DEMO users=3$' verify.log || fail "verify summary line wrong: $(cat verify.log)"

NB=$(wc -c < demo/nvram | tr -d ' ')
KB=$(wc -c < demo/keys | tr -d ' ')
# 112 = the 109-byte Nvrsafe layout + 3 zero tail bytes (the amd64
# guest compiler 6c end-pads the all-char struct to 112 and its
# readnvram reads sizeof bytes — measured live at 18-04's first boot;
# 18-04's Rule-1 fix, carried here so the committed self-test pins the
# GUEST-consuming size)
[ "$NB" = "112" ] || fail "nvram is $NB bytes, want 112 (Nvrsafe 109 + the 6c guest-ABI tail pad)"
[ "$KB" = "227" ] || fail "keys is $KB bytes, want 227 (KEYDBOFF + 3*KEYDBLEN)"
# the feed artifact (18-04): the LAST user's password, one
# newline-terminated line — the /boot/authfeed.txt source
FL=$(wc -l < demo/feed | tr -d ' ')
[ "$FL" = "1" ] || fail "feed is $FL lines, want exactly 1"
[ -s demo/feed ] || fail "feed is empty"
[ "$(tail -c 1 demo/feed | od -An -tx1 | tr -d ' \n')" = "0a" ] \
	|| fail "feed is not newline-terminated"

grep -q '^label DEMO$' demo/manifest || fail "manifest lacks the 'label DEMO' row"
grep -q '^users 3$' demo/manifest || fail "manifest lacks the 'users 3' row"

echo "== label discipline (D-04): the DEMO token in the artifacts"
# nvram: the authdom span inside the 109 bytes carries the token
if grep -a -q 'DEMO-harvey' demo/nvram; then
	echo "LABEL-IN-NVRAM-OK"
else
	fail "nvram authdom span does not carry the DEMO token"
fi
if grep -a -q 'DEMO' demo/manifest && grep -q '^label DEMO$' demo/manifest; then
	echo "LABEL-IN-MANIFEST-OK"
else
	fail "manifest does not carry the DEMO label"
fi
# the keys file carries no label bytes by design (the keyfs byte
# contract; owner-ratified manifest-row substitution) — nothing to
# assert there beyond its hash row above

echo "== info mode: the parsed fields without binary tools"
./gen -i demo >info.log 2>&1 || { cat info.log; fail "-i exited nonzero"; }
grep -q '^authid: bootes$' info.log || fail "-i lacks authid"
grep -q '^authdom: DEMO-harvey$' info.log || fail "-i lacks authdom"
grep -q '^label: DEMO$' info.log || fail "-i lacks label"
grep -q '^users: 3$' info.log || fail "-i lacks the user count"
grep -q '^names: glenda bootes norbert$' info.log || fail "-i lacks the decrypted names"
grep -q '^keys: decrypt-ok under nvram machkey$' info.log \
	|| fail "-i lacks the pairing identity line"

echo "== verify-mode teeth: doctored-input negative controls"
# each class must refuse with a nonzero exit; the marker below is the
# self-test's own class receipt, the refusal line is quoted for triage

# (1) nvram: flip authdom[0] ('D' at offset 60) to NUL — always a real
# mutation on the DEMO path, and it breaks the sum, the sha1, and the
# label token at once
cp -r demo n1
head -c 60 demo/nvram > n1/nvram
printf '\000' >> n1/nvram
tail -c +62 demo/nvram >> n1/nvram
if ./gen -V n1 >v1.log 2>&1; then
	fail "verify ACCEPTED a doctored nvram"
else
	echo "NEG-CONTROL-REFUSED-nvram: $(tail -1 v1.log)"
fi

# (2) keys: flip the first record byte ('g' of glenda at KEYDBOFF=8)
# to NUL — always a real mutation on the DEMO path
cp -r demo n2
head -c 8 demo/keys > n2/keys
printf '\000' >> n2/keys
tail -c +10 demo/keys >> n2/keys
if ./gen -V n2 >v2.log 2>&1; then
	fail "verify ACCEPTED a doctored keys file"
else
	echo "NEG-CONTROL-REFUSED-keys: $(tail -1 v2.log)"
fi

# (3) manifest: replace the nvram row's first hex digit with 'g' —
# never a sha1 character, so the recomputation can never agree
cp -r demo n3
sed '3s/^[0-9a-f]/g/' demo/manifest > n3/manifest
if ./gen -V n3 >v3.log 2>&1; then
	fail "verify ACCEPTED a doctored manifest row"
else
	echo "NEG-CONTROL-REFUSED-manifest: $(tail -1 v3.log)"
fi

# (4) truncated keys: ten bytes short — the length-vs-user-count check
# (and the sha1) must both refuse
cp -r demo n4
head -c 217 demo/keys > n4/keys
if ./gen -V n4 >v4.log 2>&1; then
	fail "verify ACCEPTED a truncated keys file"
else
	echo "NEG-CONTROL-REFUSED-truncated: $(tail -1 v4.log)"
fi

echo "== local-file interface path (the committed example is the shape proof)"
# fill the example's placeholders with test values: a custom label, a
# custom authdom, three users with DISTINCT passwords (the shared
# password is a DEMO-path convenience only).  Distinct passwords
# provably work: generate decrypts the whole keys buffer with the
# donor oldCBCdecrypt and re-derives every user key with donor
# passtokey before writing — any password that did not derive would
# abort generate right here.
sed	-e 's/^label=.*/label=SELFTEST/' \
	-e 's/^authdom=.*/authdom=SELFTEST-domain/' \
	-e 's/^machine_password=.*/machine_password=selftest-machpw/' \
	-e 's/^secstore_password=.*/secstore_password=stsec12/' \
	-e 's/^user glenda .*/user glenda selftest-pw-one/' \
	-e 's/^user bootes .*/user bootes selftest-pw-two/' \
	-e 's/^user norbert .*/user norbert selftest-pw-three/' \
	"$HARVEY/build/x86_64/authdomain.example" > self.local
./gen -o d2 -f self.local >gen2.log 2>&1 \
	|| { cat gen2.log; fail "local-file generate exited nonzero"; }
./gen -V d2 >verify2.log 2>&1 \
	|| { cat verify2.log; fail "verify refused the local-file unit"; }
# the local file WINS over the DEMO defaults: custom label/authdom in,
# DEMO token absent everywhere
grep -q '^label SELFTEST$' d2/manifest || fail "local-file manifest lacks the custom label"
grep -a -q 'SELFTEST-domain' d2/nvram || fail "local-file nvram lacks the custom authdom"
if grep -a -q 'DEMO' d2/nvram; then
	fail "DEMO token leaked into the local-file nvram"
fi
if grep -q '^label DEMO$' d2/manifest; then
	fail "DEMO label leaked into the local-file manifest"
fi
./gen -i d2 >info2.log 2>&1 || { cat info2.log; fail "-i exited nonzero on the local-file unit"; }
grep -q '^users: 3$' info2.log || fail "local-file unit lost the user count"
grep -q '^names: glenda bootes norbert$' info2.log || fail "local-file unit lost the names"
grep -q '^label: SELFTEST$' info2.log || fail "local-file unit lost its label in -i"
echo "LOCALFILE-PATH-OK"

echo "== missing -f: a requested-but-missing file refuses loud"
# silent fallback to DEMO when a file was EXPLICITLY requested is the
# D-01 forbidden failure mode; absence-fallback happens only on the
# implicit default path (proven green in the DEMO leg above)
if ./gen -o d3 -f nosuchfile.local >miss.log 2>&1; then
	fail "missing -f silently generated instead of refusing"
else
	grep -q "can't open nosuchfile.local" miss.log \
		|| fail "missing -f refusal is not loud about the file"
	echo "MISSING-F-REFUSED"
fi

echo "== gitignore: /authdomain.local must stay out of git"
(cd "$HARVEY" && git check-ignore -q authdomain.local) \
	|| fail "authdomain.local is not gitignored (T-18-06)"

echo "== zero repo-tree writes"
GITAFTER=$(cd "$HARVEY" && git status --porcelain | sha1sum | cut -d' ' -f1)
[ "$GITBEFORE" = "$GITAFTER" ] || fail "self-test changed the repo working tree"

echo "GEN-SELFTEST-OK"
