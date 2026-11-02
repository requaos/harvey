#include <u.h>
#include <libc.h>

/*
 * init — r9's staged first process (phase 04-07, D-04): the minimal
 * 7c-built binary that rides the initrd paqfs, goes through the real
 * a.out load/exec path, prints its alive-ness via write(2), then rforks
 * child A (exec /hello — the committed Phase-2 ABI bisect binary) and
 * child B (exec /smokefork — the rfork/fd-ops smoke) through the real
 * RFORK/EXEC paths, and awaits both exit records via AWAIT.  The early
 * markers stay byte-identical to 04-06 ("init: r9 EL0 alive", the hello
 * print) so the virtexec profile's assertions remain satisfiable as a
 * subset.  The trailing prints/exits keep every failure path loud.
 */
void
main(int, char*[])
{
	char *argv[2];
	char buf[128];
	volatile uvlong spin;
	uvlong v;
	int n;

	print("init: r9 EL0 alive\n");

	switch(rfork(RFPROC|RFMEM)){
	case 0:
		argv[0] = "/hello";
		argv[1] = nil;
		exec("/hello", argv);
		print("init: child A exec returned\n");
		exits("exec-fail");
	case -1:
		print("init: rfork A failed: %r\n");
		exits("rfork-fail");
	}

	switch(rfork(RFPROC|RFMEM)){
	case 0:
		argv[0] = "/smokefork";
		argv[1] = nil;
		exec("/smokefork", argv);
		print("init: child B exec returned\n");
		exits("exec-fail");
	case -1:
		print("init: rfork B failed: %r\n");
		exits("rfork-fail");
	}

	/*
	 * D-13 evidence: preemption needs a CPU-bound EL0 window with live
	 * peers — both children otherwise finish inside one 1 ms tick slice
	 * (and once a parent awaits, its peer set is Blocked, leaving the
	 * scheduler no Ready switch target).  Spin here while hello and
	 * smokefork run concurrently; the tick preempts this spin and the
	 * scheduler round-robins to them (the "sched: switch" markers).
	 * volatile keeps the loop live under 7c.
	 */
	spin = 0;
	for(v = 0; v < 5000000; v++)
		spin += v;

	for(n = 0; n < 2; n++){
		if(await(buf, sizeof buf - 1) < 0){
			print("init: await failed: %r\n");
			exits("await-fail");
		}
		print("init: reaped %s\n", buf);
	}
	print("init: smoke complete\n");
	exits(nil);
}
