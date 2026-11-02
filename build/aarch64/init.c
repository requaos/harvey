#include <u.h>
#include <libc.h>

/*
 * init — r9's staged first process (phase 04-06, D-04): the minimal
 * 7c-built binary that rides the initrd paqfs, goes through the real
 * a.out load/exec path, prints its alive-ness via write(2), then execs
 * /hello (the committed Phase-2 ABI bisect binary) through the real EXEC
 * syscall path.  The trailing print/exits prove the failure path is loud
 * if EXEC breaks — on success they are never reached (exec returns only
 * on failure).
 */
void
main(int, char*[])
{
	char *argv[2];

	print("init: r9 EL0 alive\n");
	argv[0] = "/hello";
	argv[1] = nil;
	exec("/hello", argv);
	print("init: exec returned\n");
	exits("exec-fail");
}
