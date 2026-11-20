#include <u.h>
#include <libc.h>

/*
 * churnsem — the arm64 churn gate's in-kernel contention leg (20-09;
 * the build/x86_64/churnsem.c twin, CR-03's D-07 stress half): forks
 * RFMEM children that CONTEND semacquire/semrelease on a word in the
 * shared Data segment while the kernel driver's exec loop keeps
 * spawning — the sem registry exercised under real scheduler timing,
 * real RFMEM-shared physical pages (the word's PA is the registry key,
 * so every contender names the SAME key), and concurrent exec churn.
 * The parent waits for all children, prints the generation marker the
 * gate counts (churngate: semgen), and exits nil; the driver spawns
 * these without waiting so a generation's contenders overlap the execs
 * that follow it.  The acquire retry loop is lock.c's shape: a
 * semacquire interrupted by a note fails -1 and is retried.  r9's
 * `cargo xtask initrd` bakes it as /churnsem beside /init.
 */
enum {
	Nkids = 4,	/* contenders per generation */
	Ncyc = 200,	/* acquire/release cycles per contender */
};

static long word = 1;	/* Data segment: shared under RFMEM */

static void
kid(void)
{
	int i;

	for(i = 0; i < Ncyc; i++){
		while(semacquire(&word, 1) < 0)
			; /* interrupted; retry */
		semrelease(&word, 1);
	}
	exits(nil);
}

void
main(int, char*[])
{
	int i, pid;

	for(i = 0; i < Nkids; i++){
		pid = rfork(RFPROC|RFMEM|RFFDG);
		if(pid < 0){
			print("churngate: FAIL semgen rfork: %r\n");
			exits("rfork");
		}
		if(pid == 0){
			kid();
			exits(nil);	/* not reached */
		}
	}
	for(i = 0; i < Nkids; i++){
		if(wait() == nil){
			print("churngate: FAIL semgen wait: %r\n");
			exits("wait");
		}
	}
	print("churngate: semgen %d contenders done\n", Nkids);
	exits(nil);
}
