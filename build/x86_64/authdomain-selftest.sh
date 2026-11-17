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
#   - the authid-creds artifact (19-10): the AUTHID's own name+password
#     in the creds line shape — pinned BY VALUE on the local-file leg
#     (the authid's password, never another user's) — and the authid
#     membership rule: a user list without bootes refuses loud
#   - verify-mode teeth (Task 2): four doctored-input classes each
#     refuse with a nonzero exit and their own marker
#   - the CR-01 boundary: a staged manifest of EXACTLY Filecap bytes
#     (readfile accepts exactly-cap files by design) walks verify and
#     info with room for the terminating NUL — -V refuses the padded
#     shape loud, -i completes clean, and an AddressSanitizer build
#     (when the host cc has one) re-runs both — the only venue that
#     can actually SEE a one-byte out-of-bounds stack write
#   - generated passwords (WR-01): the charset is exactly
#     [0-9a-zA-Z] and every one of the 62 alphabet symbols is
#     reachable across a 960-char sample — the sanity floor under the
#     rejection-sampling fix (the distribution itself is not pinnable
#     with a cheap leg)
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

# the authid-creds artifact (19-10): the AUTHID's own name+password in
# the creds line shape — the §15 cpu bake's /boot/authid-creds.txt
# source (cpurc's factotum leg, the p9sk1 SERVER key).  The user= line
# is assertable exactly (bootes, public); the password= line is random
# on the DEMO path — assert its shape + non-emptiness (the local-file
# leg below pins the VALUE with the known test material)
AL=$(wc -l < demo/authid-creds | tr -d ' ')
[ "$AL" = "2" ] || fail "authid-creds is $AL lines, want exactly 2"
grep -q '^user=bootes$' demo/authid-creds \
	|| fail "authid-creds user= line is not the fixed authid bootes"
grep -q '^password=..*$' demo/authid-creds \
	|| fail "authid-creds password= line is empty/malformed"
[ "$(tail -c 1 demo/authid-creds | od -An -tx1 | tr -d ' \n')" = "0a" ] \
	|| fail "authid-creds is not newline-terminated"

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

# (5) the CR-01 boundary: a manifest of EXACTLY Filecap bytes.
# readfile accepts exactly-cap files by design (it only refuses a
# cap+1'th byte), so n == Filecap is reachable and the terminating
# NUL write used to land one byte past the 64 KiB stack buffer in
# verify/info.  Post-fix semantics: read WITH room for the NUL, never
# silently truncated — -V still refuses this doctored shape LOUD (the
# trailing padding rows), -i (which parses only label/users)
# completes clean
cp -r demo n5
ML=$(wc -c < demo/manifest | tr -d ' ')
yes xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
	| head -c $((65536 - ML)) >> n5/manifest
[ "$(wc -c < n5/manifest | tr -d ' ')" = "65536" ] \
	|| fail "CR-01 leg: staged manifest is not exactly Filecap bytes"
if ./gen -V n5 >v5.log 2>&1; then
	fail "verify ACCEPTED an exactly-Filecap manifest padded past the artifact rows"
else
	grep -q 'trailing rows after the three artifacts' v5.log \
		|| fail "CR-01 leg: -V refusal is not the loud trailing-rows marker: $(tail -1 v5.log)"
	echo "FILECAP-BOUNDARY-REFUSED: $(tail -1 v5.log)"
fi
./gen -i n5 >i5.log 2>&1 \
	|| { cat i5.log; fail "CR-01 leg: -i choked on the exactly-Filecap manifest"; }
grep -q '^names: glenda bootes norbert$' i5.log \
	|| fail "CR-01 leg: -i did not parse the exactly-Filecap manifest"

# the memory-safety pin itself: the same boundary input under an
# AddressSanitizer build (the plain -O2 build cannot observe a
# one-byte stack overrun — it corrupts silently).  Leak detection is
# off: this leg pins the CR-01 overwrite, not donor allocation
# hygiene.  Skipped with a note when the host cc lacks ASan
if "$CC" -fsanitize=address -O1 -Wno-unknown-pragmas -I"$DONORS" -o gen-asan \
	"$HARVEY/build/x86_64/authdomain-gen.c" \
	"$DONORS"/passtokey.c "$DONORS"/nvcsum.c "$DONORS"/crypt.c \
	"$DONORS"/des.c "$DONORS"/desCBC.c "$DONORS"/desmodes.c \
	"$DONORS"/sha1.c "$DONORS"/sha1block.c "$DONORS"/hmac.c \
	"$DONORS"/strecpy.c >asanbuild.log 2>&1; then
	if ASAN_OPTIONS=detect_leaks=0 ./gen-asan -V n5 >a5v.log 2>&1; then
		fail "ASan build: -V accepted the padded Filecap manifest"
	else
		grep -q 'trailing rows' a5v.log \
			|| fail "ASan build: wrong -V refusal marker: $(tail -1 a5v.log)"
	fi
	ASAN_OPTIONS=detect_leaks=0 ./gen-asan -i n5 >a5i.log 2>&1 \
		|| { cat a5i.log; fail "ASan build: -i failed on the exactly-Filecap manifest"; }
	if grep -q 'AddressSanitizer' a5v.log a5i.log; then
		fail "AddressSanitizer reported a memory error on the exactly-Filecap boundary — the CR-01 shape is not fixed"
	fi
	echo "FILECAP-BOUNDARY-ASAN-CLEAN"
else
	echo "NOTE: host cc has no AddressSanitizer — CR-01 boundary pinned behaviorally only (loud -V refusal + clean -i)"
fi

echo "== generated-password alphabet (WR-01): charset + reachability"
# genpassword maps /dev/urandom bytes onto [0-9a-zA-Z] by rejection
# sampling; a sanity leg can pin the invariants, not the distribution:
# every generated char is IN the alphabet, and every one of the 62
# symbols is REACHABLE across a 960-char sample (80 DEMO runs x the
# 12-char feed password) — an indexing or rejection bug that strands a
# symbol or emits a foreign byte reds here (a missed symbol over 960
# uniform draws is a <1e-5 flake; termination of the redraw loop is
# exercised by every one of these generate runs)
i=0
while [ "$i" -lt 80 ]; do
	./gen -o "pw$i" >"pw$i.log" 2>&1 || { cat "pw$i.log"; fail "WR-01 leg: DEMO generate $i failed"; }
	i=$((i+1))
done
cat pw*/feed >allpw
PWC=$(tr -d '\n' <allpw)
NW=${#PWC}
[ "$NW" = "960" ] || fail "WR-01 leg: harvested $NW password chars, want 960 (80 x 12)"
if [ -n "$(printf '%s' "$PWC" | tr -d '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')" ]; then
	fail "WR-01 leg: a generated password carries a char outside [0-9a-zA-Z]"
fi
miss=""
for c in 0 1 2 3 4 5 6 7 8 9 \
	a b c d e f g h i j k l m n o p q r s t u v w x y z \
	A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
	case "$PWC" in
	*$c*)	;;
	*)	miss="$miss$c"
	esac
done
[ -z "$miss" ] || fail "WR-01 leg: alphabet symbols never generated: $miss"
echo "GENPASSWORD-ALPHABET-OK"

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
# the authid-creds VALUE pin (19-10): the artifact must carry the
# AUTHID's OWN password — bootes's selftest-pw-two, NOT another user's
# (glenda's -one / norbert's -three).  This is the tooth that would
# have reds'd the 19-10 Leg-1 defect's generator side: any LAST-user
# or hostowner substitution fails here.
grep -q '^user=bootes$' d2/authid-creds \
	|| fail "local-file authid-creds user= line is not bootes"
grep -q '^password=selftest-pw-two$' d2/authid-creds \
	|| fail "local-file authid-creds carries the WRONG password — want the authid's own (selftest-pw-two)"
echo "LOCALFILE-PATH-OK"

echo "== authid membership: a user list without the authid refuses loud"
# (19-10) the cpu server's p9sk1 key derives from the authid's own
# password; a domain whose authid has no user row is unusable for cpu
# sessions by construction — generate must refuse, naming the fix
grep -v '^user bootes ' self.local > nobootes.local
if ./gen -o d5 -f nobootes.local >nb.log 2>&1; then
	fail "generate ACCEPTED a user list without the authid (bootes) — the baked cpu image would carry an unusable server key"
else
	grep -q "authid bootes is not in the user list" nb.log \
		|| fail "the no-bootes refusal is not loud about the authid remediation"
	echo "NO-BOOTES-REFUSED"
fi

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
