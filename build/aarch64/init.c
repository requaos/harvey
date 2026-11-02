#include <u.h>
#include <libc.h>

/*
 * init — r9's staged first process (phase 04-08, D-04 complete): the
 * minimal 7c-built binary that rides the initrd paqfs, goes through the
 * real a.out load/exec path, prints its alive-ness via write(2), then
 * rforks child A (exec /hello — the committed Phase-2 ABI bisect
 * binary), child B (exec /smokefork — the rfork/fd-ops smoke) and child
 * C (exec /smokenote — the notes smoke) through the real RFORK/EXEC
 * paths, posts the note to C via unmodified libc postnote (a write to
 * /proc/N/note on devproc-lite), and awaits all three exit records via
 * AWAIT.  The early markers stay byte-identical to 04-06 ("init: r9 EL0
 * alive", the hello print) so the virtexec profile's assertions remain
 * satisfiable as a subset; 04-07's smoke markers likewise for virtmulti.
 * The trailing prints/exits keep every failure path loud.
 */
void
main(int, char*[])
{
	char *argv[2];
	char buf[128];
	volatile uvlong spin;
	uvlong v;
	int n, pidc;

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

	switch(pidc = rfork(RFPROC|RFMEM)){
	case 0:
		argv[0] = "/smokenote";
		argv[1] = nil;
		exec("/smokenote", argv);
		print("init: child C exec returned\n");
		exits("exec-fail");
	case -1:
		print("init: rfork C failed: %r\n");
		exits("rfork-fail");
	}

	/*
	 * D-16 ordering: the child must have notify() installed BEFORE the
	 * postnote lands — a note delivered to a handlerless process kills
	 * it (the donor pexit shape), and exec clears the handler.  No
	 * rendezvous primitive exists this era, so a CPU-bound spin is the
	 * ordering primitive; it doubles as the D-13 preemption window
	 * (three children live + this spin → "sched: switch" markers).
	 * smokenote's exec+notify completes within its first few slices;
	 * the spin is orders of magnitude longer.  volatile keeps the loop
	 * live under 7c.
	 */
	spin = 0;
	for(v = 0; v < 50000000; v++)
		spin += v;

	if(postnote(PNPROC, pidc, "smoke") < 0){
		print("init: postnote failed: %r\n");
		exits("postnote-fail");
	}

	for(n = 0; n < 3; n++){
		if(await(buf, sizeof buf - 1) < 0){
			print("init: await failed: %r\n");
			exits("await-fail");
		}
		print("init: reaped %s\n", buf);
	}
	print("init: smoke complete\n");
	exits(nil);
}
