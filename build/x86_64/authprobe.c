#include <u.h>
#include <libc.h>
#include <authsrv.h>

/*
 * authprobe — the 18-05 speaksfor leg-2 client (AUTH-06/D-13): the
 * p9sk1 ticket request in the SPEAKS-FOR wire form.  Ticketreq
 * hostid=<speaker> DIFFERS from uid=<user> — the form stock auth/debug
 * cannot send (debug.c:233-234 always sets tr.hostid=tr.uid=user;
 * factotum's client is the in-tree precedent, p9sk1.c:260-264) —
 * which is why this client exists.  The exchange is debug.c's
 * authfutz with the speaksfor delta; the reply is decrypted with the
 * SPEAKER's key and the verdict asserted against the requested arm:
 *
 *	pass arm (default):	t.num==AuthTc && t.cuid==user &&
 *				t.suid==user
 *				-> `authprobe: SPEAKSFOR-OK <speaker> for <user>'
 *	deny arm (-d):	authsrv scrambles BOTH keys on a speaksfor
 *			denial (the mkkey anti-enumeration,
 *			authsrv.c:130-138), so the reply FAILS to
 *			decrypt: t.num != AuthTc
 *				-> `authprobe: SPEAKSFOR-DENIED <user>'
 *
 * The password comes from /dev/cons (debug.c's readcons shape, raw
 * mode dropped — the sentinel feed is a plain file): the same baked
 * read-only sentinel that drives auth/debug drives this client (one
 * shared DEMO password, D-12; never an argv word).  Markers carry
 * user/domain names only, never password material (T-18-13).
 *
 * Built host-side by mkimage.sh's auth contract (the svctcpecho 6c/6l
 * block shape; libauthsrv rides the #pragma-lib autolib record),
 * staged as /amd64/bin/hauthprobe.
 *
 * usage: authprobe [-d] addr dom speaker user
 *	addr:	the auth server address for netmkaddr(addr, nil,
 *		"ticket") — cs translates the ticket service name from
 *		the baked ndb row (tcp=ticket port=567)
 *	dom:	the authentication domain (DEMO-harvey on the DEMO path)
 *	speaker: the key user whose key decrypts the reply (bootes)
 *	user:	the spoken-for uid (norbert; sys on the deny arm)
 *
 * exits(0) ONLY when the requested arm's verdict held.
 */

int denyarm;

void
usage(void)
{
	fprint(2, "usage: %s [-d] addr dom speaker user\n", argv0);
	exits("usage");
}

/* debug.c's readcons with the raw-mode machinery dropped: the sentinel
 * feed is a plain file, so consctl rawon buys nothing; each fresh
 * OREAD of the bound file starts at offset 0 and returns the same
 * first line (the 15-02 sentinel discipline).  Prompts go to fd 2 —
 * the inherited serial fd, never /dev/cons by path (under the
 * sentinel bind the OWRITE open fails; fd 2 is always live). */
static char*
readcons(char *prompt, char *buf, int nbuf)
{
	int fd, n, m;
	char line[1];

	fd = open("/dev/cons", OREAD);
	if(fd < 0)
		fd = 0;
	fprint(2, "authprobe: %s: ", prompt);
	m = 0;
	for(;;){
		n = read(fd, line, 1);
		if(n <= 0){
			close(fd);
			werrstr("readcons: EOF");
			return nil;
		}
		if(line[0] == '\n' || line[0] == '\r'){
			buf[m] = '\0';
			close(fd);
			return buf;
		}
		if(m >= nbuf-1){
			fprint(2, "authprobe: line too long\n");
			m = 0;
		}else
			buf[m++] = line[0];
	}
}

void
main(int argc, char **argv)
{
	char pw[128], key[DESKEYLEN], tbuf[2*TICKETLEN], trbuf[TICKREQLEN];
	char *addr, *dom, *speaker, *user;
	int fd;
	Ticket t;
	Ticketreq tr;

	ARGBEGIN{
	case 'd':
		denyarm = 1;
		break;
	default:
		usage();
	}ARGEND

	if(argc != 4)
		usage();
	addr = argv[0];
	dom = argv[1];
	speaker = argv[2];
	user = argv[3];

	/* the speaks-for wire form REQUIRES hostid != uid.  hostid is set
	 * from the speaker argv below and this check keeps the
	 * SPEAKSFOR-OK marker UNREACHABLE from a self-speaks request
	 * (hostid==uid is what stock auth/debug sends — that probe owns
	 * the self-speaks leg). */
	if(strcmp(speaker, user) == 0)
		sysfatal("%s: speaker == user (%s): the speaksfor form needs hostid != uid (auth/debug owns the self-speaks probe)", argv0, speaker);

	if(readcons("password", pw, sizeof pw) == nil)
		sysfatal("password read failed: %r");
	passtokey(key, pw);

	/* the speaks-for request: authid=hostid=speaker, uid=the spoken-for
	 * user — authsrv's speaksfor() consults /lib/ndb/auth's hostid=
	 * rows (uid=!x denies and WINS, * or the exact name allows) */
	memset(&tr, 0, sizeof tr);
	tr.type = AuthTreq;
	strecpy(tr.authid, tr.authid+sizeof tr.authid, speaker);
	strecpy(tr.authdom, tr.authdom+sizeof tr.authdom, dom);
	strecpy(tr.hostid, tr.hostid+sizeof tr.hostid, speaker);
	strecpy(tr.uid, tr.uid+sizeof tr.uid, user);
	memset(tr.chal, 0xAA, sizeof tr.chal);
	convTR2M(&tr, trbuf);

	alarm(30000);
	fd = dial(netmkaddr(addr, nil, "ticket"), 0, 0, 0);
	if(fd < 0)
		sysfatal("dial %s: %r", netmkaddr(addr, nil, "ticket"));
	if(_asgetticket(fd, trbuf, tbuf) < 0){
		close(fd);
		sysfatal("_asgetticket: %r");
	}
	close(fd);

	/* decrypt with the SPEAKER's key: a granted speaksfor ticket is
	 * encrypted under hostid's key and carries cuid==suid==the
	 * spoken-for user; a denied one is encrypted under a random mkkey
	 * and cannot decrypt here (the anti-enumeration scrambling IS the
	 * observable — authsrv logs `tr-fail ... no speaks for' for the
	 * same exchange through its -d syslog line) */
	convM2T(tbuf, &t, key);
	if(denyarm){
		if(t.num == AuthTc)
			sysfatal("deny arm: the ticket DECRYPTED (t.num==AuthTc) for uid=%s — the uid=! row did not bite (the gate has no teeth)", user);
		print("authprobe: SPEAKSFOR-DENIED %s\n", user);
		exits(nil);
	}
	if(t.num != AuthTc)
		sysfatal("ticket does not decrypt with the speaker's key (t.num=0x%.2ux) — auth server and you do not agree on key for %s@%s", t.num&0xff, speaker, dom);
	if(strcmp(t.cuid, user) != 0)
		sysfatal("ticket cuid=%s, want %s", t.cuid, user);
	if(strcmp(t.suid, user) != 0)
		sysfatal("ticket suid=%s, want %s — the speaksfor grant did not name the spoken-for user", t.suid, user);
	if(memcmp(t.chal, tr.chal, sizeof tr.chal) != 0)
		sysfatal("bad challenge from auth server — rogue");
	print("authprobe: SPEAKSFOR-OK %s for %s\n", speaker, user);
	exits(nil);
}
