#include	"u.h"
#include	"../port/lib.h"
#include	"mem.h"
#include	"dat.h"
#include	"fns.h"
#include	"../port/error.h"

enum
{
	Qdir = 0,
	Qboot = 0x1000,

	Nrootfiles = 32,
	Nbootfiles = 64,	/* 06-09: the k10t1 tier venue embeds 43 boot files */
};

typedef struct Dirlist Dirlist;
struct Dirlist
{
	uint base;
	Dirtab *dir;
	uchar **data;
	int ndir;
	int mdir;
};

static Dirtab rootdir[Nrootfiles] = {
	"#/",	{Qdir, 0, QTDIR},	0,		DMDIR|0555,
	"boot",	{Qboot, 0, QTDIR},	0,		DMDIR|0555,
};
static uchar *rootdata[Nrootfiles];
static Dirlist rootlist =
{
	0,
	rootdir,
	rootdata,
	2,
	Nrootfiles
};

static Dirtab bootdir[Nbootfiles] = {
	"boot",	{Qboot, 0, QTDIR},	0,		DMDIR|0555,
};
static uchar *bootdata[Nbootfiles];
static Dirlist bootlist =
{
	Qboot,
	bootdir,
	bootdata,
	1,
	Nbootfiles
};

/*
 *  add a file to the list
 */
static void
addlist(Dirlist *l, char *name, uchar *contents, ulong len, int perm)
{
	Dirtab *d;

	if(l->ndir >= l->mdir)
		panic("too many root files");
	l->data[l->ndir] = contents;
	d = &l->dir[l->ndir];
	strcpy(d->name, name);
	d->length = len;
	d->perm = perm;
	d->qid.type = 0;
	d->qid.vers = 0;
	d->qid.path = ++l->ndir + l->base;
	if(perm & DMDIR)
		d->qid.type |= QTDIR;
}

/*
 *  add a root file
 */
void
addbootfile(char *name, uchar *contents, ulong len)
{
	addlist(&bootlist, name, contents, len, 0555);
}

/*
 *  add a root directory
 */
static void
addrootdir(char *name)
{
	addlist(&rootlist, name, nil, 0, DMDIR|0555);
}

static void
rootreset(void)
{
	addrootdir("bin");
	addrootdir("dev");
	addrootdir("env");
	addrootdir("fd");
	addrootdir("mnt");
	addrootdir("net");
	addrootdir("net.alt");
	addrootdir("proc");
	addrootdir("root");
	addrootdir("srv");
	/* 15-02: the standard /rc mount point (rc sources /rc/lib/rcmain on
	 * every invocation — srv(1) -e's exec helper hardcodes rc -c, so a
	 * venue without /rc cannot run any srv -e service; measured on
	 * the k10t1 donor: "can't open: '/rc'").  The services sweep binds
	 * the embedded rcmain in through this dir (mntgen /rc + bind -b
	 * /boot /rc/lib).
	 */
	addrootdir("rc");
	/* 15-05: /lib and /tmp mount points for the draw venue — the
	 * embedded root is read-only (mkdir is denied), and the -initrd
	 * payload channel binds the paqfs font tree at /lib while mntgen
	 * serves the writable /tmp scratch (the same named-mount-point
	 * pattern as /rc above).
	 */
	addrootdir("lib");
	addrootdir("tmp");
}

static Chan*
rootattach(char *spec)
{
	return devattach('/', spec);
}

static int
rootgen(Chan *c, char *name, Dirtab*, int, int s, Dir *dp)
{
	int t;
	Dirtab *d;
	Dirlist *l;

	switch((int)c->qid.path){
	case Qdir:
		if(s == DEVDOTDOT){
			devdir(c, (Qid){Qdir, 0, QTDIR}, "#/", 0, eve, 0555, dp);
			return 1;
		}
		return devgen(c, name, rootlist.dir, rootlist.ndir, s, dp);
	case Qboot:
		if(s == DEVDOTDOT){
			devdir(c, (Qid){Qdir, 0, QTDIR}, "#/", 0, eve, 0555, dp);
			return 1;
		}
		return devgen(c, name, bootlist.dir, bootlist.ndir, s, dp);
	default:
		if(s == DEVDOTDOT){
			if((int)c->qid.path < Qboot)
				devdir(c, (Qid){Qdir, 0, QTDIR}, "#/", 0, eve, 0555, dp);
			else
				devdir(c, (Qid){Qboot, 0, QTDIR}, "#/", 0, eve, 0555, dp);
			return 1;
		}
		if(s != 0)
			return -1;
		if((int)c->qid.path < Qboot){
			t = c->qid.path-1;
			l = &rootlist;
		}else{
			t = c->qid.path - Qboot - 1;
			l = &bootlist;
		}
		if(t >= l->ndir)
			return -1;
		if(t < 0)
			panic("rootgen: negative index %d (qid %#llux)", t, c->qid.path);
		d = &l->dir[t];
		devdir(c, d->qid, d->name, d->length, eve, d->perm, dp);
		return 1;
	}
}

static Walkqid*
rootwalk(Chan *c, Chan *nc, char **name, int nname)
{
	return devwalk(c,  nc, name, nname, nil, 0, rootgen);
}

static long
rootstat(Chan *c, uchar *dp, long n)
{
	return devstat(c, dp, n, nil, 0, rootgen);
}

static Chan*
rootopen(Chan *c, int omode)
{
	return devopen(c, omode, nil, 0, devgen);
}

/*
 * sysremove() knows this is a nop
 */
static void
rootclose(Chan*)
{
}

static long
rootread(Chan *c, void *buf, long n, vlong off)
{
	ulong t;
	Dirtab *d;
	Dirlist *l;
	uchar *data;
	ulong offset = off;

	t = c->qid.path;
	switch(t){
	case Qdir:
	case Qboot:
		return devdirread(c, buf, n, nil, 0, rootgen);
	}

	if(t<Qboot)
		l = &rootlist;
	else{
		t -= Qboot;
		l = &bootlist;
	}

	t--;
	if(t >= l->ndir)
		error(Egreg);

	d = &l->dir[t];
	data = l->data[t];
	if(offset >= d->length)
		return 0;
	if(offset+n > d->length)
		n = d->length - offset;
	memmove(buf, data+offset, n);
	return n;
}

static long
rootwrite(Chan*, void*, long, vlong)
{
	error(Egreg);
	return 0;
}

Dev rootdevtab = {
	'/',
	"root",

	rootreset,
	devinit,
	devshutdown,
	rootattach,
	rootwalk,
	rootstat,
	rootopen,
	devcreate,
	rootclose,
	rootread,
	devbread,
	rootwrite,
	devbwrite,
	devremove,
	devwstat,
};

