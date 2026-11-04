/*
 * bootr9.c — hand-written bootconf for the aarch64/r9 boot(8) build.
 *
 * The amd64 build awk-generates this file from the kernel config's boot
 * section (sys/src/9k/mk/parse, mkbootconf); the r9 boot has no kernel
 * config, so the generated equivalent is written by hand.  It supplies
 * the four extern bootconf symbols boot.h names (method[], cpuflag,
 * rootdir, bootdisk) plus the two further symbols the generated file
 * also emits and the link cannot live without: main() (the generated
 * file's entry — calls boot()) and cfs (nil — the generated default
 * when the config's rootdir section carries no /bin/cfs).
 *
 * The method table names the embed method first, so rootserver()
 * defaults to it (the kernel additionally seeds nobootprompt=embed);
 * embed's arg is the raw-image path /rootfs.img —
 * the cross-repo contract: the devroot raw node serves this exact
 * literal.  cpuflag=0 selects the terminal path (init -t).
 */
#include <u.h>
#include <libc.h>
#include "../boot/boot.h"

Method method[] = {
	{ "embed", configembed, connectembed, "/rootfs.img" },
	{ nil },
};

int cpuflag = 0;		/* terminal → init -t */
char *rootdir = "/root";
char *bootdisk = "";
int (*cfs)(int) = 0;		/* no cache fs — the generated default */

extern void boot(int, char**);

void
main(int argc, char **argv)
{
	boot(argc, argv);
}
