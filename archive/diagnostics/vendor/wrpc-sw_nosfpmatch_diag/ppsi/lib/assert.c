#include <stdarg.h>
#include <ppsi/ppsi.h>
#include <ppsi/assert.h>
#if __STDC_HOSTED__
#include <unistd.h> /* bare archs have no sleep, but a sw loop */
#endif


void panic(const char *fmt, ...)
{
	va_list args;

	while (1) {
		pp_printf("Panic: ");
		va_start(args, fmt);
		pp_vprintf(fmt, args);
		va_end(args);
		sleep(1);
	}
}

void __assert(const char *func, int line, int forever,
		     const char *fmt, ...)
{
	va_list args;

	while (1) {
		pp_printf("Assertion failed (%s:%i)", func, line);
		if (fmt && fmt[0]) {
			pp_printf(": ");
			va_start(args, fmt);
			pp_vprintf(fmt, args);
			va_end(args);
		} else {
			pp_printf(".\n");
		}
		if (!forever)
			break;
		sleep(1);
	}
}
