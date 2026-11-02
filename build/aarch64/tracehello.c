#include <u.h>
#include <libc.h>

/*
 * tracehello — the D-14 donor-kernel trace target (04-01 Task 3).
 * hello.c's shape with a leading PURE-COMPUTE spin BEFORE the first
 * print(): crt0 (main9.s) makes no syscalls and a volatile counter loop
 * pulls no fmt/pool allocation, so every syscall the binary ever makes
 * happens after the spin.  The harness stops the process mid-spin and
 * arms startsyscall, so the measured set is complete — nothing can fire
 * before the tracer is armed.  No sleep(): alarm would pollute the set.
 */
void
main(int, char*[])
{
	volatile uvlong spin;
	uvlong i;

	spin = 0;
	/* calibrated on the lima guest (TCG ~800MIPS): ~15s wall — the harness
	 * needs ~5s from background-launch to armed tracer (paced serial sends). */
	for(i = 0; i < 2000000000; i++)
		spin += i;
	if(spin == 1)		/* never true; defeat dead-code removal */
		print("tracehello: spin optimized away\n");
	print("hello aarch64 harvey\n");
	print("tracehello second print\n");
	exits(nil);
}
