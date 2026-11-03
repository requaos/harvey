/*
 * bootr9.c — hand-written bootconf for the aarch64/r9 boot(8) build
 * (05-02 Task 1; 05-CONTEXT D-01/D-04; 05-RESEARCH Pattern 2 / Pitfall 2).
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
 * defaults to it (the kernel additionally seeds nobootprompt=embed per
 * RESEARCH Pattern 3); embed's arg is the raw-image path /rootfs.img —
 * the cross-plan contract: 05-05's devroot raw node serves this exact
 * literal.  cpuflag=0 selects the terminal path (init -t, D-05).
 */
#include <u.h>
#include <libc.h>
#include "../boot/boot.h"

Method method[] = {
	{ "embed", configembed, connectembed, "/rootfs.img" },
	{ nil },
};

int cpuflag = 0;		/* terminal → init -t (D-05) */
char *rootdir = "/root";
char *bootdisk = "";
int (*cfs)(int) = 0;		/* no cache fs — the generated default */

extern void boot(int, char**);

void
main(int argc, char **argv)
{
	boot(argc, argv);
}
