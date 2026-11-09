#include <u.h>
#include <libc.h>
#include <../boot/boot.h>

static char *paqfile;

void
configembed(Method *m)
{
	if(*sys == '/' || *sys == '#'){
		/*
		 *  if the user specifies the disk in the boot cmd or
		 * 'root is from' prompt, use it
		 */
		paqfile = sys;
	} else if(m->arg){
		/*
		 *  a default is supplied when the kernel is made
		 */
		paqfile = m->arg;
	}
}

int
connectembed(void)
{
	int i, p[2];
	Dir *dir;
	char **arg, **argp;

	dir = dirstat("/boot/paqfs");
	if(dir == nil)
		return -1;
	free(dir);

	dir = dirstat(paqfile);
	if(dir == nil || dir->mode & DMDIR)
		return -1;
	free(dir);

	print("paqfs...");
	if(bind("#c", "/dev", MREPL) < 0)
		fatal("bind #c");
	if(bind("#p", "/proc", MREPL) < 0)
		fatal("bind #p");
	if(pipe(p)<0)
		fatal("pipe");
	switch(fork()){
	case -1:
		fatal("fork");
	case 0:
		arg = malloc((bargc+5)*sizeof(char*));
		argp = arg;
		*argp++ = "/boot/paqfs";
		*argp++ = "-iv";
		*argp++ = paqfile;
		for(i=1; i<bargc; i++)
			*argp++ = bargv[i];
		*argp = 0;

		dup(p[0], 0);
		dup(p[1], 1);
		close(p[0]);
		close(p[1]);
		exec("/boot/paqfs", arg);
		fatal("can't exec paqfs");
	default:
		break;
	}
	/* NOTE (14-06, the r9 boot-chain bring-up): no waitpid() here.
	 * The 4e original waited for the child before using the pipe —
	 * but paqfs -i is a PERSISTENT server on fds 0/1 and never exits,
	 * so the wait deadlocks the chain at the first fversion (the
	 * embed method was never exercised on 4e/9k: their boots used
	 * tcp/local, so the bug slept until the r9 chain's gate).  The
	 * 9front sibling's embedpaq.c has no wait — drop it (the in-tree
	 * fix; Harvey is the maintained fork). */
	close(p[1]);
	return p[0];
}
