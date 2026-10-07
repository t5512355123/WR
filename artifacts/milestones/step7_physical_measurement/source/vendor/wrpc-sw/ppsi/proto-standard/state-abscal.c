#include <ppsi/ppsi.h>
#include "common-fun.h"

/*
 * This is similar to master state, but it only sends sync, that
 * is going to be timestampedboth internally and externally (on a scope).
 * We should send it as close as possible to the pps signal.
 */


/* Calculate when is the next pps going to happen */
static int next_pps_ms(struct pp_instance *ppi, struct pp_time *t)
{
	int nsec;

	TOPS(ppi)->get(ppi, t);
	nsec = t->scaled_nsecs >> 16;
	return  1000 - (nsec / 1000 / 1000);
}

/*
 * This is using a software loop during the last 10ms in order to get
 * right after the pps event
 */
int pp_abscal(struct pp_instance *ppi, void *buf, int plen)
{
	struct pp_time t;
	int len;

	if (ppi->is_new_state) {
		/* add 1s to be enough in the future, the first time */
		pp_timeout_set_rename(ppi, PP_TO_SYNC_SEND, 990 + next_pps_ms(ppi, &t));
		ppi->bmca_execute = 0;
		/* print header for the serial port stream of stamps */
		pp_printf("### t4.phase is already corrected for bitslide\n");
		pp_printf("t1:                     t4:                  "
			  "bitslide: %d\n", 0 /* ep_get_bitslide() */);
		pp_printf("      sec.       ns.pha       sec.       ns.pha\n");
	}
	else if (pp_timeout(ppi, PP_TO_SYNC_SEND)) {
		uint64_t secs;

		next_pps_ms(ppi, &t);
		secs = t.secs;

		TOPS(ppi)->enable_timing_output(GLBS(ppi), 1);

		/* Wait for the second to tick */
		while( TOPS(ppi)->get(ppi, &t), t.secs == secs)
			;

		/* Send sync, no f-up -- actually we could send any frame */
		TOPS(ppi)->get(ppi, &t);
		len = msg_pack_sync(ppi, &t);
		__send_and_log(ppi, len, PP_NP_EVT, PPM_SYNC_FMT);

		/* And again next second */
		pp_timeout_set(ppi, PP_TO_SYNC_SEND, next_pps_ms(ppi, &t) - 10);
	}

	ppi->next_delay = pp_next_delay_1(ppi, PP_TO_SYNC_SEND);
	return  0;
}
