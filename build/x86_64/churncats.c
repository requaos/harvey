#include <u.h>
#include <libc.h>

/*
 * churncats — the 17-02 composed churn leg's driver (D-06 tier (b)):
 * fork+exec /bin/cat — the MOUNTED binary, boot(8)'s paqfs served over
 * 9P, the #44 suspect terrain (ByteBacking::Mnt staging) — N times at
 * the repro shape, waitpid per child, the churn: markers the expect
 * gate stages on.  cat's output goes to /dev/null via the child's own
 * fd-1 redirect (the churn is the exec, not bytes on serial); cat's
 * INPUT is the committed fixture file (a real paqfs read).
 *
 * Why a C driver and not the rc fixture: the first composed leg drove
 * `rc /lib/churn-cats.rc' (a while loop + a dc backquote counter per
 * iteration) and measured RC'S OWN USERLAND POOL corrupting past ~428
 * iterations ("bad arena size ... pool sbrkmem", the poisoned-header
 * signature) — a real Harvey-userland finding recorded with this plan
 * (deferred to the rc rows), but not this gate's subject: the kernel's
 * exec path under sustained real-binary churn.  This driver (the
 * tcpblast lineage — a static 6c binary driving the load itself) puts
 * every iteration on fork+execve+waitpid, no shell pool in the loop.
 */
enum {
	N = 1400,	/* the #44 repro shape */
};

void
main(int, char*[])
{
	int i, pid;

	print("churn: BEFORE\n");
	for(i = 0; i < N; i++){
		pid = fork();
		if(pid < 0){
			print("churn: FAIL fork at %d: %r\n", i);
			exits("fork");
		}
		if(pid == 0){
			close(1);
			if(open("/dev/null", OWRITE) != 1){
				print("churn: FAIL null-open: %r\n");
				exits("null");
			}
			execl("/bin/cat", "cat", "/lib/churn-cats.rc", nil);
			print("churn: FAIL exec at %d: %r\n", i);
			exits("exec");
		}
		if(waitpid() < 0){
			print("churn: FAIL wait at %d: %r\n", i);
			exits("wait");
		}
	}
	print("churn: AFTER\n");
	print("churn: CATS-DONE %d\n", N);
	exits(nil);
}
