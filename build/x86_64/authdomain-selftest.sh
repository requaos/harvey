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
[ "$NB" = "109" ] || fail "nvram is $NB bytes, want 109 (Nvrsafe)"
[ "$KB" = "227" ] || fail "keys is $KB bytes, want 227 (KEYDBOFF + 3*KEYDBLEN)"

grep -q '^label DEMO$' demo/manifest || fail "manifest lacks the 'label DEMO' row"
grep -q '^users 3$' demo/manifest || fail "manifest lacks the 'users 3' row"

echo "== gitignore: /authdomain.local must stay out of git"
(cd "$HARVEY" && git check-ignore -q authdomain.local) \
	|| fail "authdomain.local is not gitignored (T-18-06)"

echo "== zero repo-tree writes"
GITAFTER=$(cd "$HARVEY" && git status --porcelain | sha1sum | cut -d' ' -f1)
[ "$GITBEFORE" = "$GITAFTER" ] || fail "self-test changed the repo working tree"

echo "GEN-SELFTEST-OK"
