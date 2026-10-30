#include <lib9.h>

ulong
getcallerpc(void *arg)
{
	return (ulong)__builtin_return_address(0);
}
