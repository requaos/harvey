#include <u.h>
#include <libc.h>

/*
 * init — r9's staged first process: the
 * minimal 7c-built binary that rides the initrd paqfs, goes through the
 * real a.out load/exec path, prints its alive-ness via write(2), then
 * rforks child A (exec /hello — the committed ABI-bisect
 * binary), child B (exec /smokefork — the rfork/fd-ops smoke), child
 * C (exec /smokenote — the notes smoke), child D (exec /stacksmoke
 * — the stack-growth smoke) and child E (exec /smokesleep —
 * the interruptible-sleep smoke) through the real
 * RFORK/EXEC paths, posts the note to C via unmodified libc postnote
 * (a write to /proc/N/note on devproc-lite), and awaits all five exit
 * records via AWAIT.  The early markers stay byte-identical
 * ("init: r9 EL0 alive", the hello print) so the exec profile's
 * assertions remain satisfiable as a subset; the smoke markers
 * likewise for the multi profile.  The trailing prints/exits keep every failure
 * path loud.
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

	/*
	 * The namespace era: /proc resolves through the
	 * mount table now (the literal-path routing scaffold is retired),
	 * so bind #p before the postnote, the real chain's connectembed
	 * shape.  The staged initrd ships an empty /proc to bind onto
	 * (bind targets must pre-exist).  Fatal on failure: a gate that
	 * cannot reach
	 * devproc proves nothing.  rfork(RFPROC) children SHARE this
	 * namespace (fork(2): neither RFNAMEG nor RFCNAMEG).
	 */
	if(bind("#p", "/proc", MREPL) < 0){
		print("init: bind #p failed: %r\n");
		exits("bind-fail");
	}

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
	 * Child D: the stack-growth smoke.  Forked before the
	 * ordering spin so it shares the preemption window with its
	 * siblings; its own marker ("stacksmoke: depth 64 ok") is the only
	 * evidence it prints.  Purely additive — the existing children and
	 * their markers are untouched.
	 */
	switch(rfork(RFPROC|RFMEM)){
	case 0:
		argv[0] = "/stacksmoke";
		argv[1] = nil;
		exec("/stacksmoke", argv);
		print("init: child D exec returned\n");
		exits("exec-fail");
	case -1:
		print("init: rfork D failed: %r\n");
		exits("rfork-fail");
	}

	/*
	 * Child E: the interruptible-sleep smoke.
	 * alarm(300) interrupts its sleep(30000) — the note posts, the
	 * sleeper wakes early and fails -1 "interrupted", and the handler
	 * runs at the return boundary (NCONT resumes main).  Its marker is
	 * "smokesleep: interrupted"; any other outcome is a loud
	 * sleep-not-interrupted exit.  Additive like child D.
	 */
	switch(rfork(RFPROC|RFMEM)){
	case 0:
		argv[0] = "/smokesleep";
		argv[1] = nil;
		exec("/smokesleep", argv);
		print("init: child E exec returned\n");
		exits("exec-fail");
	case -1:
		print("init: rfork E failed: %r\n");
		exits("rfork-fail");
	}

	/*
	 * Ordering: the child must have notify() installed BEFORE the
	 * postnote lands — a note delivered to a handlerless process kills
	 * it (the donor pexit shape), and exec clears the handler.  No
	 * rendezvous primitive exists this era, so a CPU-bound spin is the
	 * ordering primitive; it doubles as the preemption window
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

	for(n = 0; n < 5; n++){
		if(await(buf, sizeof buf - 1) < 0){
			print("init: await failed: %r\n");
			exits("await-fail");
		}
		print("init: reaped %s\n", buf);
	}
	print("init: smoke complete\n");
	exits(nil);
}
