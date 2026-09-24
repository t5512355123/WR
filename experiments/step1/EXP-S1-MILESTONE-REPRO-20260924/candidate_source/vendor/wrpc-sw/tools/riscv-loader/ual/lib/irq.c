/**
 * @copyright Copyright (c) 2016 CERN
 * @author Federico Vaga <federico.vaga@cern.ch>
 * @license LGPLv3
 */

#include <string.h>
#include <inttypes.h>
#include <errno.h>
#include <time.h>

#include "ual-int.h"

/* Subtract the ‘struct timeval’ values X and Y,
   storing the result in RESULT.
   Return 1 if the difference is negative, otherwise 0. */

static int timespec_subtract(struct timespec *result,
			     struct timespec *x, struct timespec *y)
{
	/* Perform the carry for the later subtraction by updating y. */
	if (x->tv_nsec < y->tv_nsec) {
		int nsec = (y->tv_nsec - x->tv_nsec) / 1000000000 + 1;
		y->tv_nsec -= 1000000000 * nsec;
		y->tv_sec += nsec;
	}
	if (x->tv_nsec - y->tv_nsec > 1000000000) {
		int nsec = (x->tv_nsec - y->tv_nsec) / 1000000000;
		y->tv_nsec += 1000000000 * nsec;
		y->tv_sec -= nsec;
	}

	/* Compute the time remaining to wait.
	   tv_nsec is certainly positive. */
	result->tv_sec = x->tv_sec - y->tv_sec;
	result->tv_nsec = x->tv_nsec - y->tv_nsec;

	/* Return 1 if result is negative. */
	return x->tv_sec < y->tv_sec;
}


/**
 * It waits for an event to happen in at a given memory offset.
 * An event is a bit changing within a bitmask.
 *
 * @param[in] tkn UAL BAR token
 * @param[in] addr offset within the selected BAR
 * @param[in] mask bitmask to apply on the read value
 * @param[in] period polling period
 * @param[in|out] timeout timeout for the event to occur. It will updated
 *                with the time left
 * @return the value that triggered the event (already masked).
 *         0 on error and errno is appropriately set.
 */
uint64_t ual_event_wait(struct ual_bar_tkn *tkn, uint64_t addr, uint64_t mask,
			struct timespec *period, struct timespec *timeout)
{
	struct timespec start, curr, diff, left;
	uint64_t ret;
	int err;

	if (!tkn) {
		errno = UAL_ERR_INVALID_TKN;
		return 0;
	}

	if (!mask) {
		errno = UAL_ERR_INVALID_EVENT_MASK;
		return 0;
	}

	if (!period || (period->tv_sec == 0 && period->tv_nsec == 0)) {
		errno = UAL_ERR_INVALID_EVENT_PERIOD;
		return 0;
	}

	err = clock_gettime(CLOCK_REALTIME, &start);
	if (err)
		return 0;
	memcpy(&left, timeout, sizeof(struct timespec));
	while (1) {
		ret = ual_readl(tkn, addr) & mask;
		if (ret) {
			memcpy(timeout, &left, sizeof(struct timespec));
			return ret;
		}

		err = clock_gettime(CLOCK_REALTIME, &curr);
		if (err)
		        break;
		timespec_subtract(&diff, &curr, &start);
		ret = timespec_subtract(&left, timeout, &diff);
		if (ret)
			break;

		ret = nanosleep(period, NULL);
	}

	memset(timeout, 0, sizeof(struct timespec));
	errno = ETIME;
	return 0;
}
