/*
 * authdomain-gen — the bake-time p9sk1 domain generator (18-03, AUTH-01).
 *
 * One run turns the committed interface (a local file, or the
 * ephemeral DEMO path when it is absent) into the hash-paired unit
 * every later bake and boot check agrees with by construction:
 *
 *	nvram		exactly 112 bytes: the 109-byte Nvrsafe layout
 *			(sys/include/authsrv.h:140-157 — machkey/authkey/
 *			config/authid/authdom + five nvcsum (seed 9) sums,
 *			all five valid; readnvram checks three, we emit and
 *			verify all five) plus 3 zero tail bytes — the amd64
 *			guest compiler (6c) end-pads the all-char struct to
 *			112 and its readnvram reads sizeof bytes (a 109-byte
 *			file failed its length check SILENTLY — measured
 *			live at 18-04's first boot).  The machkey IS the
 *			/adm/keys master key — getauthkey.c:14 memmoves it
 *			straight out of this file.
 *	keys		KEYDBOFF(8) random bytes + one 73-byte record per
 *			user in keyfs writeusers' layout (keyfs.c:740-795):
 *			Namelen(28) name | DESKEYLEN(7) key | status(1)=Sok
 *			| warnings(1)=0 | expire(4 LE)=0 (never — zero-clock
 *			safe, Pitfall 4) | SECRETLEN(32) zeros.  The whole
 *			buffer is oldCBCencrypt'ed under the nvram machkey
 *			(zero ivec, des56to64, libsec's lacy partial-tail
 *			rule) — that encryption-key identity IS the pairing
 *			invariant.
 *	ndb-auth	the /lib/ndb/auth speaksfor rows authsrv.c:791-821
 *			consumes: `hostid=<authid> uid=!sys uid=!adm uid=*'
 *			(row format is assumption A2; 18-05's negative
 *			control validates it).  Missing file = speaksfor
 *			fails closed, so it is always generated.
 *	manifest	`label <label>' + `users <nu>' + one `<sha1>
 *			<name>' row per artifact (donor libsec sha1) — the
 *			internal-consistency proof.  The auth image is NOT
 *			byte-reproducible across bakes (D-01); no gate may
 *			ever assert cross-bake byte identity.
 *	feed		the LAST user's password (D-12's plain probe user —
 *			DEMO's norbert), a single newline-terminated line:
 *			the bake's /boot/authfeed.txt sentinel source, the
 *			18-05 prompt feeds' substrate.  NOT a manifest
 *			member (the manifest is the crypto pairing; this is
 *			the same run's convenience copy).
 *
 * D-04 label venues: the label lands in the nvram authdom (as part of
 * the authdom token), the ndb header comment, and every manifest row
 * set.  The keys file itself carries NO label bytes — the keyfs byte
 * contract admits none without breaking 18-04's non-interactive keyfs
 * start — so the keys file's label pairing rides the manifest row that
 * hashes it (owner-ratified 2026-11-13).
 *
 * All crypto is the donor's own code, compiled not rewritten: the
 * vendored, byte-verbatim Harvey sources under authdom-donors/
 * (passtokey, nvcsum, crypt's encrypt, the libsec DES set with the
 * lacy tail rule, sha1) plus this tree's authsrv.h/libsec.h headers,
 * built against the host cc through the thin shim headers there.  A
 * generate-time decrypt round-trip re-proves the derivation and CBC
 * pairing on every single run.  Wave-0 A1 probe verdict: plan9port
 * 9c/9l linking -lauthsrv -lsec also works in the nix devshell (cross-
 * validated byte-identical passtokey/desCBC output on a fixed vector);
 * the vendored venue was chosen because the must-have pins the
 * algorithm bytes to THIS tree's donor files and the committed
 * self-test must run under the bare host shell.
 *
 * usage: authdomain-gen -o dir [-f file]	generate (absent -f and
 *			absent ./authdomain.local => ephemeral DEMO)
 *	   authdomain-gen -V dir		verify the pairing, refuse loud
 *	   authdomain-gen -i dir		print the parsed fields
 *
 * NEVER run with -o inside the repo working tree — generation targets
 * an explicit staging dir (mkimage passes one; the self-test passes a
 * mktemp dir).  Real key material never lands in git: the local file
 * is gitignored and the committed example carries placeholders only.
 */

#include <u.h>
#include <libc.h>
#include <authsrv.h>
#include <libsec.h>

enum
{
	Maxusers=	64,
	Maxpw=		32,	/* generated passwords; passtokey reads <=27 */
	Demopwlen=	12,	/* >=7 (secuser), <=13 (nvram config), alnum */
	Filecap=	65536,	/* artifact read cap; real artifacts are tiny */
	Namelen=	ANAMELEN,	/* keyfs.c:35 — the keys record name width */
	/* the nvram FILE is 112 bytes: the 109-byte Nvrsafe layout plus 3
	 * zero tail bytes, because the GUEST compiler (Harvey's amd64 6c,
	 * the tier build's) end-pads the all-char struct to 112 — its
	 * readnvram reads sizeof(Nvrsafe)==112 and a 109-byte file
	 * returned 109 != 112: the SILENT readnvram failure class (no
	 * diagnostic under flag 0, getauthkey escalates straight to the
	 * interactive getpass — measured live at 18-04's first boot:
	 * "read 109 want 112", all five sums verified green over the 109
	 * donor-layout bytes, i.e. the member offsets are IDENTICAL and
	 * only the tail pad differs).  Host compilers see sizeof(Nvrsafe)
	 * == 109 (no padding — all-char members); every field access here
	 * casts the same first 109 bytes either way. */
	Nvramfile=	112,
};

/* keyfs.c:39 — status byte values; Sok is the only one we write */
enum
{
	Sok=		0,
};

typedef struct User User;
struct User
{
	char	name[ANAMELEN];		/* NUL-filled */
	char	pw[Maxpw];
	uchar	key[DESKEYLEN];		/* passtokey(pw), generate-time derived */
};

typedef struct Domain Domain;
struct Domain
{
	char	label[32];
	char	authdom[DOMLEN];
	char	machpw[Maxpw];
	char	secpw[CONFIGLEN];	/* secstore password; <=13 chars */
	char	authid[ANAMELEN];
	User	users[Maxusers];
	int	nu;
};

char *argv0;

void
usage(void)
{
	fprint(2, "usage: %s -o dir [-f file]\n"
		"       %s -V dir   (verify pairing)\n"
		"       %s -i dir   (info: parsed fields)\n", argv0, argv0, argv0);
	exits("usage");
}

/*
 * oldCBCencrypt/oldCBCdecrypt — the keyfs.c:714-738 shape verbatim:
 * zero ivec, des56to64 the 7-byte key, donor desCBC with the lacy
 * partial-tail rule.  This is driver glue over donor calls, not a
 * reimplementation.
 */
void
oldCBCencrypt(char *key7, uchar *p, int len)
{
	uchar ivec[8];
	uchar key[8];
	DESstate s;

	memset(ivec, 0, 8);
	des56to64((uchar*)key7, key);
	setupDESstate(&s, key, ivec);
	desCBCencrypt(p, len, &s);
}

void
oldCBCdecrypt(char *key7, uchar *p, int len)
{
	uchar ivec[8];
	uchar key[8];
	DESstate s;

	memset(ivec, 0, 8);
	des56to64((uchar*)key7, key);
	setupDESstate(&s, key, ivec);
	desCBCdecrypt(p, len, &s);
}

/*
 * host randomness — real /dev/urandom bytes, never a fixed constant.
 * Any failure is loud: DEMO material is throwaway, but it is still
 * generated fresh per run from the host (D-01).
 */
void
randbytes(uchar *p, int n)
{
	static int fd = -1;
	int got;

	if(fd < 0){
		fd = open("/dev/urandom", OREAD);
		if(fd < 0)
			sysfatal("can't open /dev/urandom: %s", strerror(errno));
	}
	got = 0;
	while(got < n){
		int k;

		k = read(fd, p + got, n - got);
		if(k <= 0)
			sysfatal("short read from /dev/urandom");
		got += k;
	}
}

/*
 * a random [0-9a-zA-Z] password — printable, rc-safe (no spaces,
 * quotes, or '#'; sentinel-feed friendly), >=7 for the secuser path,
 * <=13 so it fits the Nvrsafe config field if reused there.
 */
void
genpassword(char *out, int n)
{
	static char alph[] = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
	uchar r[Maxpw];
	int i;

	if(n > Maxpw)
		n = Maxpw;
	randbytes(r, n);
	for(i = 0; i < n; i++)
		out[i] = alph[r[i] % (nelem(alph)-1)];
	out[n] = 0;
}

int
readfile(char *dir, char *name, uchar *buf, int cap)
{
	char path[512];
	int fd, n, got;

	if(snprint(path, sizeof path, "%s/%s", dir, name) >= sizeof path)
		sysfatal("path too long: %s/%s", dir, name);
	fd = open(path, OREAD);
	if(fd < 0)
		sysfatal("can't open %s: %s", path, strerror(errno));
	got = 0;
	for(;;){
		uchar extra;

		n = read(fd, buf + got, cap - got);
		if(n < 0)
			sysfatal("read %s: %s", path, strerror(errno));
		if(n == 0)
			break;
		got += n;
		if(got == cap){
			/* exactly filled: EOF, or one more byte hiding? */
			n = read(fd, &extra, 1);
			if(n < 0)
				sysfatal("read %s: %s", path, strerror(errno));
			if(n > 0)
				sysfatal("%s bigger than %d bytes (not an authdomain artifact?)", path, cap);
			break;
		}
	}
	close(fd);
	return got;
}

void
writefile(char *dir, char *name, void *buf, int n, uint perm)
{
	char path[512];
	int fd, w;

	if(snprint(path, sizeof path, "%s/%s", dir, name) >= sizeof path)
		sysfatal("path too long: %s/%s", dir, name);
	fd = create(path, OWRITE, perm);
	if(fd < 0)
		sysfatal("can't create %s: %s", path, strerror(errno));
	w = write(fd, buf, n);
	if(w != n)
		sysfatal("short write on %s", path);
	close(fd);
}

void
sha1hex(uchar *p, int n, char *out)
{
	uchar digest[SHA1dlen];
	int i;

	sha1(p, n, digest, nil);
	for(i = 0; i < SHA1dlen; i++)
		snprint(out + 2*i, 3, "%02x", digest[i]);
}

/*
 * DEMO defaults (D-12): glenda the hostowner, bootes the admin, norbert
 * the plain third user so probe traffic is never admin traffic — all
 * sharing one demo password (the sentinel-feed requirement).
 */
void
democonfig(Domain *d)
{
	memset(d, 0, sizeof *d);
	strcpy(d->label, "DEMO");
	strcpy(d->authdom, "DEMO-harvey");
	strcpy(d->authid, "bootes");
	genpassword(d->machpw, Demopwlen);
	genpassword(d->secpw, Demopwlen);
	genpassword(d->users[0].pw, Demopwlen);
	strcpy(d->users[0].name, "glenda");
	strcpy(d->users[1].name, "bootes");
	strcpy(d->users[2].name, "norbert");
	strcpy(d->users[1].pw, d->users[0].pw);
	strcpy(d->users[2].pw, d->users[0].pw);
	d->nu = 3;
}

/*
 * field validation — mirrors keyfs userok's reject classes (keyfs.c:
 * 822-855): no control chars, spaces, or '/' in names; NUL-terminated
 * within the field.  Label/authdom must be single printable tokens
 * (they land in grep-asserted manifest rows).
 */
void
checktoken(char *s, int max, char *what)
{
	int i;

	if(s[0] == 0)
		sysfatal("empty %s", what);
	for(i = 0; s[i]; i++){
		uchar c;

		c = (uchar)s[i];
		if(c < 0x21 || c > 0x7e)
			sysfatal("%s contains non-printable byte %02x", what, c);
	}
	if(i >= max)
		sysfatal("%s longer than %d chars", what, max-1);
}

void
adduser(Domain *d, char *name, char *pw)
{
	User *u;
	int i;

	if(d->nu >= Maxusers)
		sysfatal("more than %d users", Maxusers);
	checktoken(name, ANAMELEN, "user name");
	for(i = 0; i < d->nu; i++)
		if(strcmp(d->users[i].name, name) == 0)
			sysfatal("duplicate user %s", name);
	if(pw[0] == 0)
		sysfatal("user %s: empty password", name);
	if(strlen(pw) >= Maxpw)
		sysfatal("user %s: password longer than %d chars", name, Maxpw-1);
	u = &d->users[d->nu++];
	memset(u->name, 0, sizeof u->name);
	strcpy(u->name, name);
	strcpy(u->pw, pw);
}

/*
 * set a KEY=VALUE field with overflow refused loud — strecpy alone
 * would silently truncate (exactly the class that turns a real
 * secstore password into a different one).
 */
void
setfield(char *dst, int dstlen, char *v, char *what)
{
	if(strlen(v) >= dstlen)
		sysfatal("%s longer than %d chars", what, dstlen-1);
	strecpy(dst, dst + dstlen, v);
}

/*
 * parse the committed interface (authdomain.example is the shape
 * proof): flat KEY=VALUE lines — label, authdom, machine_password,
 * secstore_password — plus one `user <name> <password>' line per
 * user; '#' comment lines and blanks skipped.  Omitted fields keep
 * their DEMO defaults except the passwords, which are freshly
 * generated (never a placeholder silently becoming key material).
 */
void
parsefile(char *file, Domain *d)
{
	FILE *f;
	char line[256];

	democonfig(d);
	/* file-owned values start from a clean slate */
	d->label[0] = 0;
	d->authdom[0] = 0;
	d->machpw[0] = 0;
	d->secpw[0] = 0;
	d->nu = 0;

	f = fopen(file, "r");
	if(f == nil)
		sysfatal("can't open %s: %s", file, strerror(errno));
	while(fgets(line, sizeof line, f) != nil){
		char *s, *k, *v, *name, *pw;

		s = line;
		while(*s == ' ' || *s == '\t')
			s++;
		if(s[0] == 0 || s[0] == '#' || s[0] == '\n')
			continue;
		s[strcspn(s, "\n")] = 0;
		if(strncmp(s, "user ", 5) == 0){
			name = s + 5;
			while(*name == ' ' || *name == '\t')
				name++;
			pw = name;
			while(*pw && *pw != ' ' && *pw != '\t')
				pw++;
			if(*pw == 0)
				sysfatal("bad user line (want: user <name> <password>): %s", s);
			*pw++ = 0;
			while(*pw == ' ' || *pw == '\t')
				pw++;
			adduser(d, name, pw);
			continue;
		}
		k = s;
		v = strchr(s, '=');
		if(v == nil)
			sysfatal("unrecognized line (want KEY=VALUE or user <name> <password>): %s", s);
		*v++ = 0;
		if(strcmp(k, "label") == 0)
			setfield(d->label, sizeof d->label, v, "label");
		else if(strcmp(k, "authdom") == 0)
			setfield(d->authdom, sizeof d->authdom, v, "authdom");
		else if(strcmp(k, "machine_password") == 0)
			setfield(d->machpw, sizeof d->machpw, v, "machine_password");
		else if(strcmp(k, "secstore_password") == 0)
			setfield(d->secpw, sizeof d->secpw, v, "secstore_password");
		else
			sysfatal("unknown key %s", k);
	}
	fclose(f);

	if(d->label[0] == 0)
		strcpy(d->label, "DEMO");
	checktoken(d->label, sizeof d->label, "label");
	if(d->authdom[0] == 0)
		strcpy(d->authdom, "DEMO-harvey");
	checktoken(d->authdom, DOMLEN, "authdom");
	checktoken(d->authid, ANAMELEN, "authid");
	if(d->nu == 0){
		/* no user lines: the three-user DEMO membership */
		char shared[Maxpw];

		genpassword(shared, Demopwlen);
		adduser(d, "glenda", shared);
		adduser(d, "bootes", shared);
		adduser(d, "norbert", shared);
	}
	if(d->machpw[0] == 0)
		genpassword(d->machpw, Demopwlen);
	if(d->secpw[0] == 0)
		genpassword(d->secpw, Demopwlen);
}

/*
 * generate the paired unit into dir (which must be outside the repo
 * working tree — the caller's burden, asserted by the self-test).
 */
void
generate(Domain *d, char *dir)
{
	Nvrsafe nv;
	uchar nvbuf[Nvramfile];
	uchar *buf, *chk;
	char ndb[512], manifest[8192], hex[SHA1dlen*2+1];
	char feed[Maxpw+2];
	int i, buflen, n, ndblen, manlen;
	User *u;
	struct stat st;

	if(stat(dir, &st) == 0){
		if(!S_ISDIR(st.st_mode))
			sysfatal("%s exists and is not a directory", dir);
	}else if(mkdir(dir, 0755) < 0)
		sysfatal("can't mkdir %s: %s", dir, strerror(errno));

	/* every user's key derives now, donor code, generate-time */
	for(i = 0; i < d->nu; i++){
		u = &d->users[i];
		if(passtokey((char*)u->key, u->pw) != 1)
			sysfatal("passtokey failed for %s", u->name);
	}

	/* nvram: the 109-byte Nvrsafe layout, all five sums valid, padded
	 * to the 112-byte FILE size the guest ABI reads (Nvramfile above) */
	memset(&nv, 0, sizeof nv);
	if(passtokey(nv.machkey, d->machpw) != 1)
		sysfatal("passtokey failed for the machine password");
	/* authkey: no consumer this era (getauthkey.c:14 reads machkey
	 * only; readnvram never checks authsum) — zeros with a valid sum */
	strecpy(nv.config, nv.config + sizeof nv.config, d->secpw);
	strecpy(nv.authid, nv.authid + sizeof nv.authid, d->authid);
	strecpy(nv.authdom, nv.authdom + sizeof nv.authdom, d->authdom);
	nv.machsum = nvcsum(nv.machkey, DESKEYLEN);
	nv.authsum = nvcsum(nv.authkey, DESKEYLEN);
	nv.configsum = nvcsum(nv.config, CONFIGLEN);
	nv.authidsum = nvcsum(nv.authid, sizeof nv.authid);
	nv.authdomsum = nvcsum(nv.authdom, sizeof nv.authdom);

	/* keys: writeusers' byte layout (keyfs.c:740-795) */
	buflen = KEYDBOFF + d->nu*KEYDBLEN;
	buf = malloc(buflen);
	if(buf == nil)
		sysfatal("out of memory");
	randbytes(buf, KEYDBOFF);
	memset(buf + KEYDBOFF, 0, buflen - KEYDBOFF);
	chk = buf + KEYDBOFF;
	for(i = 0; i < d->nu; i++){
		uchar *r;

		r = chk + i*KEYDBLEN;
		strncpy((char*)r, d->users[i].name, Namelen);
		memmove(r + Namelen, d->users[i].key, DESKEYLEN);
		r[Namelen + DESKEYLEN] = Sok;
		r[Namelen + DESKEYLEN + 1] = 0;		/* warnings */
		/* expire 0 == never, little-endian: the zero-clock-safe
		 * value (Pitfall 4 — no expiry math can lock a user out
		 * at time(0)==0) — the four bytes are already zero */
		/* SECRETLEN zeros: NUL-terminated, unused by p9sk1 */
	}

	/* the pairing invariant: the whole buffer under the nvram machkey */
	oldCBCencrypt(nv.machkey, buf, buflen);

	/* generate-time teeth: decrypt a copy with the donor decrypt and
	 * re-derive every user key — any shim/compiler/algorithm drift
	 * aborts HERE, never as an opaque p9sk1 failure weeks later */
	chk = malloc(buflen);
	if(chk == nil)
		sysfatal("out of memory");
	memmove(chk, buf, buflen);
	oldCBCdecrypt(nv.machkey, chk, buflen);
	for(i = 0; i < d->nu; i++){
		uchar *r;
		char name[ANAMELEN+1];

		r = chk + KEYDBOFF + i*KEYDBLEN;
		memset(name, 0, sizeof name);
		memmove(name, r, Namelen);
		if(name[Namelen-1] != 0)
			sysfatal("self-check: user %d name not NUL-terminated", i);
		if(strcmp(name, d->users[i].name) != 0)
			sysfatal("self-check: record %d name mismatch (%s != %s)", i, name, d->users[i].name);
		if(memcmp(r + Namelen, d->users[i].key, DESKEYLEN) != 0)
			sysfatal("self-check: user %s key does not round-trip", name);
		if(r[Namelen + DESKEYLEN] != Sok)
			sysfatal("self-check: user %s status is not Sok", name);
	}
	free(chk);

	memset(nvbuf, 0, sizeof nvbuf);
	memmove(nvbuf, &nv, sizeof nv);	/* + 3 zero tail bytes: Nvramfile */
	writefile(dir, "nvram", nvbuf, Nvramfile, 0600);
	writefile(dir, "keys", buf, buflen, 0600);

	/* ndb-auth: the speaksfor rows + a header comment carrying the
	 * label and authdom tokens (ndb '#' comments; trailing newline —
	 * libndb drops an unterminated final line whole) */
	ndblen = snprint(ndb, sizeof ndb,
		"# authdomain-gen label=%s authdom=%s\n"
		"hostid=%s uid=!sys uid=!adm uid=*\n",
		d->label, d->authdom, d->authid);
	if(ndblen >= sizeof ndb)
		sysfatal("ndb-auth too long");
	writefile(dir, "ndb-auth", ndb, ndblen, 0644);

	/* manifest: label row, users row, one sha1 row per artifact
	 * (hash the just-written files — what verify will re-read) */
	manlen = snprint(manifest, sizeof manifest, "label %s\nusers %d\n", d->label, d->nu);
	sha1hex(nvbuf, Nvramfile, hex);
	manlen += snprint(manifest + manlen, sizeof manifest - manlen, "%s  nvram\n", hex);
	n = readfile(dir, "keys", buf, buflen);
	sha1hex(buf, n, hex);
	manlen += snprint(manifest + manlen, sizeof manifest - manlen, "%s  keys\n", hex);
	sha1hex((uchar*)ndb, ndblen, hex);
	manlen += snprint(manifest + manlen, sizeof manifest - manlen, "%s  ndb-auth\n", hex);
	if(manlen >= sizeof manifest)
		sysfatal("manifest too long");
	writefile(dir, "manifest", manifest, manlen, 0644);

	/* feed: the last user's password + newline — the 18-04 bake's
	 * /boot/authfeed.txt (the 18-05 prompt feeds).  The generator's
	 * manifest deliberately carries no passwords; this convenience
	 * copy rides the same run (the DEMO users share one password, and
	 * D-12's plain probe user is the LAST — norbert on the DEMO path) */
	memset(feed, 0, sizeof feed);
	strcpy(feed, d->users[d->nu-1].pw);
	feed[strlen(feed)] = '\n';
	writefile(dir, "feed", feed, strlen(feed), 0444);
	free(buf);

	print("authdomain-gen: generated %s: label=%s authdom=%s authid=%s users=%d\n",
		dir, d->label, d->authdom, d->authid, d->nu);
	print("authdomain-gen: DEMO material is throwaway — never reuse outside a gate image\n");
}

/*
 * verify: recompute every manifest digest over the staged artifacts,
 * re-read all five Nvrsafe sums, check the keys length against the
 * manifest's user count, and require the label row + the label token
 * inside the nvram authdom.  Any mismatch refuses loud with the
 * artifact named; exit 0 only when everything agrees.
 */
int
verify(char *dir)
{
	static char *names[3] = { "nvram", "keys", "ndb-auth" };
	uchar *art;
	uchar nv[Filecap];
	char manifest[Filecap], label[32], hex[SHA1dlen*2+1];
	char *line, *next;
	int n, nu, i, fail, seen[3];
	Nvrsafe *safe;

	fail = 0;
	memset(seen, 0, sizeof seen);
	n = readfile(dir, "manifest", (uchar*)manifest, Filecap);
	manifest[n] = 0;

	/* strict shape: `label <t>' row, `users <n>' row, then exactly
	 * the three artifact rows, each once, nothing trailing */
	line = manifest;
	next = strchr(line, '\n');
	if(next == nil || strncmp(line, "label ", 6) != 0){
		fprint(2, "verify: manifest: no label row\n");
		return 1;
	}
	*next = 0;
	if(snprint(label, sizeof label, "%s", line + 6) >= sizeof label){
		fprint(2, "verify: manifest: label too long\n");
		return 1;
	}
	checktoken(label, sizeof label, "manifest label");
	line = next + 1;
	next = strchr(line, '\n');
	if(next == nil || strncmp(line, "users ", 6) != 0){
		fprint(2, "verify: manifest: no users row\n");
		return 1;
	}
	*next = 0;
	nu = atoi(line + 6);
	if(nu < 1 || nu > Maxusers){
		fprint(2, "verify: manifest: bad user count %d\n", nu);
		return 1;
	}

	art = malloc(Filecap);
	if(art == nil)
		sysfatal("out of memory");
	line = next + 1;
	for(i = 0; i < 3; i++){
		char *e;
		int which, j;

		e = strchr(line, '\n');
		if(e == nil){
			fprint(2, "verify: manifest: fewer than 3 artifact rows\n");
			free(art);
			return 1;
		}
		*e = 0;
		which = -1;
		if(strlen(line) > 42 && line[40] == ' ' && line[41] == ' ')
			for(j = 0; j < 3; j++)
				if(strcmp(line + 42, names[j]) == 0){
					which = j;
					break;
				}
		if(which < 0){
			fprint(2, "verify: manifest: not a known artifact row: %s\n", line);
			free(art);
			return 1;
		}
		if(seen[which]){
			fprint(2, "verify: manifest: duplicate row for %s\n", names[which]);
			free(art);
			return 1;
		}
		seen[which] = 1;
		n = readfile(dir, names[which], art, Filecap);
		sha1hex(art, n, hex);
		if(strncmp(line, hex, SHA1dlen*2) != 0){
			fprint(2, "verify: %s: sha1 mismatch (manifest %.40s, file hashes %s)\n",
				names[which], line, hex);
			free(art);
			return 1;
		}
		line = e + 1;
	}
	if(line[0] != 0){
		fprint(2, "verify: manifest: trailing rows after the three artifacts\n");
		free(art);
		return 1;
	}
	for(i = 0; i < 3; i++)
		if(!seen[i]){
			fprint(2, "verify: manifest: missing row for %s\n", names[i]);
			free(art);
			return 1;
		}

	/* Nvrsafe re-read: exactly Nvramfile bytes (the 109-byte layout +
	 * the guest-ABI tail pad), all five sums valid — what readnvram
	 * checks AND what it ignores (readnvram.c:299-311 checks three; we
	 * emitted five, so verify five) */
	n = readfile(dir, "nvram", nv, Filecap);
	if(n != Nvramfile){
		fprint(2, "verify: nvram: %d bytes, want %d\n", n, Nvramfile);
		free(art);
		return 1;
	}
	safe = (Nvrsafe*)nv;
	if(safe->machsum != nvcsum(safe->machkey, DESKEYLEN)){
		fprint(2, "verify: nvram: bad machkey sum\n");
		fail = 1;
	}
	if(safe->authsum != nvcsum(safe->authkey, DESKEYLEN)){
		fprint(2, "verify: nvram: bad authkey sum\n");
		fail = 1;
	}
	if(safe->configsum != nvcsum(safe->config, CONFIGLEN)){
		fprint(2, "verify: nvram: bad config sum\n");
		fail = 1;
	}
	if(safe->authidsum != nvcsum(safe->authid, ANAMELEN)){
		fprint(2, "verify: nvram: bad authid sum\n");
		fail = 1;
	}
	if(safe->authdomsum != nvcsum(safe->authdom, DOMLEN)){
		fprint(2, "verify: nvram: bad authdom sum\n");
		fail = 1;
	}
	if(safe->authid[0] == 0 || safe->authdom[0] == 0){
		fprint(2, "verify: nvram: empty authid or authdom\n");
		fail = 1;
	}
	if(strstr(safe->authdom, label) == nil){
		fprint(2, "verify: nvram: authdom \"%s\" does not carry the label token \"%s\"\n",
			safe->authdom, label);
		fail = 1;
	}

	/* keys length against the manifest's user count */
	n = readfile(dir, "keys", art, Filecap);
	if(n != KEYDBOFF + nu*KEYDBLEN){
		fprint(2, "verify: keys: %d bytes, want %d (KEYDBOFF + %d*KEYDBLEN)\n",
			n, KEYDBOFF + nu*KEYDBLEN, nu);
		fail = 1;
	}

	free(art);
	if(fail)
		return 1;
	print("verify: OK dir=%s label=%s users=%d\n", dir, label, nu);
	return 0;
}

/*
 * info: the parsed Nvrsafe fields (authid, authdom), the manifest
 * label, the user count, and — because the machkey sits right there
 * in the nvram artifact — the decrypted user names, proving the
 * pairing identity live (keys decrypt under the nvram machkey).
 */
int
info(char *dir)
{
	uchar nv[Nvramfile];
	uchar keys[Filecap];
	Nvrsafe *safe;
	char manifest[Filecap], label[32], *line, *next;
	int n, nu, i;

	n = readfile(dir, "nvram", nv, Nvramfile);
	if(n != Nvramfile)
		sysfatal("nvram: %d bytes, want %d", n, Nvramfile);
	safe = (Nvrsafe*)nv;
	n = readfile(dir, "manifest", (uchar*)manifest, Filecap);
	manifest[n] = 0;
	line = manifest;
	next = strchr(line, '\n');
	if(next == nil || strncmp(line, "label ", 6) != 0)
		sysfatal("manifest: no label row");
	*next = 0;
	if(snprint(label, sizeof label, "%s", line + 6) >= sizeof label)
		sysfatal("manifest: label too long");
	line = next + 1;
	next = strchr(line, '\n');
	if(next == nil || strncmp(line, "users ", 6) != 0)
		sysfatal("manifest: no users row");
	*next = 0;
	nu = atoi(line + 6);

	print("label: %s\n", label);
	print("authid: %s\n", safe->authid);
	print("authdom: %s\n", safe->authdom);
	print("machsum: %s\n", safe->machsum == nvcsum(safe->machkey, DESKEYLEN) ? "ok" : "BAD");
	print("authsum: %s\n", safe->authsum == nvcsum(safe->authkey, DESKEYLEN) ? "ok" : "BAD");
	print("configsum: %s\n", safe->configsum == nvcsum(safe->config, CONFIGLEN) ? "ok" : "BAD");
	print("authidsum: %s\n", safe->authidsum == nvcsum(safe->authid, ANAMELEN) ? "ok" : "BAD");
	print("authdomsum: %s\n", safe->authdomsum == nvcsum(safe->authdom, DOMLEN) ? "ok" : "BAD");

	n = readfile(dir, "keys", keys, Filecap);
	if(n != KEYDBOFF + nu*KEYDBLEN)
		sysfatal("keys: %d bytes, want %d", n, KEYDBOFF + nu*KEYDBLEN);
	oldCBCdecrypt(safe->machkey, keys, n);
	print("users: %d\n", nu);
	print("names:");
	for(i = 0; i < nu; i++){
		uchar *r;
		char name[ANAMELEN+1];

		r = keys + KEYDBOFF + i*KEYDBLEN;
		memset(name, 0, sizeof name);
		memmove(name, r, Namelen);
		if(name[Namelen-1] != 0)
			sysfatal("keys: user %d name not NUL-terminated", i);
		print(" %s", name);
	}
	print("\nkeys: decrypt-ok under nvram machkey\n");
	return 0;
}

/*
 * the local-file default: ./authdomain.local — the developer's real
 * material lives at the repo root (gitignored).  Absent (ENOENT)
 * falls back to ephemeral DEMO; any other open error refuses (never
 * silently DEMO over a permission problem).
 */
int
loaddefault(Domain *d)
{
	int fd;

	fd = open("authdomain.local", OREAD);
	if(fd >= 0){
		close(fd);
		parsefile("authdomain.local", d);
		return 0;
	}
	if(errno != ENOENT)
		sysfatal("authdomain.local: %s", strerror(errno));
	return -1;
}

void
main(int argc, char *argv[])
{
	Domain d;
	char *odir, *vdir, *idir, *file;

	if(sizeof(Nvrsafe) != 109 || KEYDBOFF != 8 || KEYDBLEN != 73
	|| ANAMELEN != 28 || DESKEYLEN != 7 || CONFIGLEN != 14 || SECRETLEN != 32)
		sysfatal("authsrv.h constants drifted (Nvrsafe %d, KEYDBOFF %d, KEYDBLEN %d)",
			(int)sizeof(Nvrsafe), KEYDBOFF, KEYDBLEN);

	odir = vdir = idir = file = nil;
	ARGBEGIN{
	case 'o':
		odir = EARGF(usage());
		break;
	case 'V':
		vdir = EARGF(usage());
		break;
	case 'i':
		idir = EARGF(usage());
		break;
	case 'f':
		file = EARGF(usage());
		break;
	default:
		usage();
	}ARGEND
	if(argc != 0)
		usage();

	if(odir != nil){
		if(vdir != nil || idir != nil)
			usage();
		if(file != nil)
			parsefile(file, &d);
		else if(loaddefault(&d) < 0){
			fprint(2, "authdomain-gen: no authdomain.local — generating ephemeral DEMO material\n");
			democonfig(&d);
		}
		generate(&d, odir);
		exits(0);
	}
	if(vdir != nil){
		if(idir != nil || file != nil)
			usage();
		if(verify(vdir) != 0)
			exits("verify failed");
		exits(0);
	}
	if(idir != nil){
		if(file != nil)
			usage();
		if(info(idir) != 0)
			exits("info failed");
		exits(0);
	}
	usage();
}
