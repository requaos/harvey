#include <u.h>
#include <libc.h>

/*
 * init — r9's staged first process (phase 04-05, D-04): the minimal
 * 7c-built binary that rides the initrd paqfs, goes through the real
 * a.out load/exec path, prints its alive-ness via write(2), and exits.
 * The exec/fork smoke grows onto it in 04-06/07/08.
 */
void
main(int, char*[])
{
	print("init: r9 EL0 alive\n");
	exits(nil);
}
