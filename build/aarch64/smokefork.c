#include <u.h>
#include <libc.h>

/*
 * smokefork — the rfork + fd-ops smoke, exec'd by the
 * staged init on r9.  Exercises OPEN/PREAD/CLOSE against devroot from EL0
 * (read /hello's first four bytes, verify the R_MAGIC 0x00008c47 a.out
 * header), then rforks a child and awaits its exit record.  One binary
 * covers both halves of the smoke so a single exec is the whole test.
 */
void
main(int, char*[])
{
	char buf[128];
	uchar magic[4];
	int fd, n;

	fd = open("/hello", OREAD);
	if(fd < 0){
		print("smokefork: open /hello failed: %r\n");
		exits("open-fail");
	}
	n = pread(fd, magic, 4, 0);
	close(fd);
	if(n == 4 && magic[0] == 0x00 && magic[1] == 0x00 && magic[2] == 0x8c && magic[3] == 0x47)
		print("smokefork: fd ok\n");
	else{
		print("smokefork: fd bad (n=%d %02ux %02ux %02ux %02ux)\n",
			n, magic[0], magic[1], magic[2], magic[3]);
		exits("fd-fail");
	}

	switch(rfork(RFPROC|RFMEM)){
	case 0:
		print("smokefork: child running\n");
		exits("kid");
	case -1:
		print("smokefork: rfork failed: %r\n");
		exits("rfork-fail");
	}

	if(await(buf, sizeof buf - 1) < 0){
		print("smokefork: await failed: %r\n");
		exits("await-fail");
	}
	print("smokefork: await: %s\n", buf);
	exits(nil);
}
