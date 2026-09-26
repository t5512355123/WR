#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <stdio.h>
#include <float.h>
#include <math.h>
#include <unistd.h>

static unsigned long unix_calc_timeout(void)
{
	struct timespec now;
	uint64_t now_ms;

	clock_gettime(CLOCK_MONOTONIC, &now);
	now_ms = 1000LL * now.tv_sec + now.tv_nsec / 1000 / 1000;

	return now_ms;
}


int main(int argc, char **argv) {
	static long lastMs=0;
	char text[128]={0};
	while (1) {
		long ms;
		long diff;
		ms=unix_calc_timeout();
		if ( lastMs==0)
				lastMs=ms;
		else
			lastMs+=1000;
		diff=lastMs-ms;
		if (abs(diff) > 100  ) {
			printf("%s",text);
			printf("%ld.%ld %ld\n",ms/1000, ms%1000, lastMs-ms);
		}
		sprintf(text,"%ld.%ld %ld\n",ms/1000, ms%1000, lastMs-ms);
		lastMs=ms;
		sleep(1);
	}
}
