/*
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <stdint.h>
#include <inttypes.h>
#include <ppsi/ppsi.h>
// #include "wrs-constants.h"
#include "../proto-standard/common-fun.h"
#include "wrh-servo_state_name.h"

#if CONFIG_ARCH_IS_WRS
#include <libwr/shmem.h>
#else
/* No shmem */
#define wrs_shm_write(ppi, FLAG) do {} while (0)
#endif

/* Define threshold values for SNMP */
#define SNMP_MAX_OFFSET_PS 500
#define SNMP_MAX_DELTA_RTT_PS 1000

/* Enable tracking by default. Disabling the tracking is used for demos. */
static int wrh_tracking_enabled = 1;

/* prototypes */
static int __wrh_servo_update(struct pp_instance *ppi);
static void  setState(struct pp_instance *ppi, int newState);

/* External data */
extern struct wrs_shm_head *ppsi_head;

void wrh_servo_enable_tracking(int enable)
{
	wrh_tracking_enabled = enable;
}

int wrh_servo_init(struct pp_instance *ppi)
{
	wrh_servo_t *s=WRH_SRV(ppi);
	struct pp_servo *gs=SRV(ppi);
	int ret=0;

	pp_servo_init(ppi); // Initialize the standard servo data

	/* shmem lock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	WRH_SERVO_RESET_DATA(s);

	/* Re-read clock period.
	   FIXME: isn't it fixed ?  */
	s->clock_period_ps = WRH_OPER()->get_clock_period();

	/*
	 * Do not reset cur_setpoint, but trim it to be less than one tick.
	 * The softpll code uses the module anyways, but if we unplug-replug
	 * the fiber it will always increase, so don't scare the user
	 */
	if (s->cur_setpoint_ps > s->clock_period_ps)
		s->cur_setpoint_ps %= s->clock_period_ps;

	pp_diag(ppi, servo, 3, "%s.%d: Adjust_phase: %d\n",__func__,__LINE__,s->cur_setpoint_ps);

	WRH_OPER()->adjust_phase(s->cur_setpoint_ps);

	gs->flags |= PP_SERVO_FLAG_VALID;
	TOPS(ppi)->get(ppi, &gs->update_time);
	s->tracking_enabled = wrh_tracking_enabled;
	setState(ppi,WRH_SYNC_TAI);

	/* shmem unlock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
	return ret;
}


void wrh_servo_reset(struct pp_instance *ppi)
{
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		/* shmem lock */
		wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);
		ppi->flags = 0;

		WRH_SERVO_RESET_DATA(WRH_SRV(ppi));

		setState(ppi,WRH_UNINITIALIZED);

		/* shmem unlock */
		wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
	}
}

/**
 *  SYNC/FOLLOW_UP messages have been received: t1/t2 are available
 */
int wrh_servo_got_sync(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);

	/* shmem lock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	gs->t1=ppi->t1;apply_faulty_stamp(ppi,1);
	gs->t2=ppi->t2;apply_faulty_stamp(ppi,2);

	if ( is_delayMechanismP2P(ppi) && gs->got_sync) {
		gs->got_sync=0;
		__wrh_servo_update(ppi);
	} else {
		gs->got_sync=1;
	}

	/* shmem unlock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);

	return 0;
}

/**
 *  DELAY_RESPONSE message has been received: t3/t4 are available
 */

int wrh_servo_got_resp(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);
	int ret;
	static int errcount=0;

	if (!gs->got_sync)
		return 0; /* t1 & t2 not available yet */
	gs->got_sync=0;

	if (is_timestamp_incorrect_thres(ppi,&errcount,0xC /* mask=t3&t4 */))
		return 0;

	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	gs->t3 = ppi->t3; apply_faulty_stamp(ppi,3);
	gs->t4 = ppi->t4; apply_faulty_stamp(ppi,4);

	ret=__wrh_servo_update(ppi);
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
	return ret;
}

#if CONFIG_HAS_P2P
/**
 *  PDELAY_RESPONSE_FUP message has been received: t3/t4/t5/t6 are available
 */
int wrh_servo_got_presp(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);
	static int errcount=0;

	if (is_timestamp_incorrect_thres(ppi,&errcount,0x3C /* t3,t4,t5,t6 */))
		return 0;

	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	gs->t3 = ppi->t3; apply_faulty_stamp(ppi,3);
	gs->t4 = ppi->t4; apply_faulty_stamp(ppi,4);
	gs->t5 = ppi->t5; apply_faulty_stamp(ppi,5);
	gs->t6 = ppi->t6; apply_faulty_stamp(ppi,6);

	gs->got_sync=1;

	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);

	return 1;
}
#endif

static void setState(struct pp_instance *ppi, int newState)
{
	struct pp_servo *gs=SRV(ppi);
	const char *state_name = wrh_servo_state_name[newState];
	pp_diag(ppi, servo, 1, "new state %s\n", state_name);
	gs->state=newState;
	gs->servo_state_name = state_name;
}

static int __wrh_servo_update(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);
	wrh_servo_t *s=WRH_SRV(ppi);
	int remaining_offset;
	int32_t  offset_ticks;
	int64_t prev_delayMM_ps = 0;
	int locking_poll_ret;

	struct pp_time offsetMS ;
	int32_t  offset_ps;

	if ( gs->state==WRH_UNINITIALIZED ) {
		pp_error("%s : Servo not initialized !!!!\n",__FUNCTION__);
		return 0;
	}

	prev_delayMM_ps = s->delayMM_ps;

	if ( !pp_servo_calculate_delays(ppi) )
		return 0;

	s->delayMM_ps=pp_time_to_picos(&gs->delayMM);
	s->delayMS_ps=pp_time_to_picos(&gs->delayMS);
	offsetMS=gs->offsetFromMaster;
	s->offsetMS_ps=pp_time_to_picos(&offsetMS);
	s->tracking_enabled = wrh_tracking_enabled;

	// Servo updated
	gs->update_count++;
	TOPS(ppi)->get(ppi, &gs->update_time);

	if (!s->readyForSync )
		return 1; /* We have to wait before to start the synchronization */

	locking_poll_ret = WRH_OPER()->locking_poll(ppi);
	if (locking_poll_ret != WRH_SPLL_LOCKED ){
		pp_error("%s: PLL error detected (Err=%d). Force restart.\n",__func__,locking_poll_ret);
		s->doRestart = TRUE;
		return 0;
	}

	/* After each action on the hardware, we must verify if it is over. */
	if (!WRH_OPER()->adjust_in_progress()) {
		gs->flags &= ~PP_SERVO_FLAG_WAIT_HW;
	} else {
		pp_diag(ppi, servo, 1, "servo:busy\n");
		return 1;
	}

	/* So, we didn't return. Choose the right state */
	if (offsetMS.secs) {/* so bad... */
		setState(ppi,WRH_SYNC_TAI);
		pp_diag(ppi, servo, 2, "offsetMS: %li sec ...\n",
				(long)offsetMS.secs);
	} else {
		pp_time_hardwarize(&offsetMS, s->clock_period_ps,
			      &offset_ticks, &offset_ps);
		pp_diag(ppi, servo, 2, "offsetMS: %li sec %09li ticks (%li ps)\n",
			(long)offsetMS.secs, (long)offset_ticks,
			(long)offset_ps);

		if (offset_ticks) /* not that bad */
			setState(ppi,WRH_SYNC_NSEC);
	/* else, let the states below choose the sequence */
	}

	pp_diag(ppi, servo, 3, "wrh_servo state: %s%s\n",
			gs->servo_state_name,
			gs->flags & PP_SERVO_FLAG_WAIT_HW ? " (wait for hw)" : "");

	switch (gs->state) {
	case WRH_SYNC_TAI:
		WRH_OPER()->adjust_counters(offsetMS.secs, 0);
		gs->flags |= PP_SERVO_FLAG_WAIT_HW;
		/*
		 * If nsec wrong, code above forces SYNC_NSEC,
		 * Else, we must ensure we leave this status towards
		 * fine tuning
		 */
		setState(ppi,WRH_SYNC_PHASE);
		break;

	case WRH_SYNC_NSEC:
		WRH_OPER()->adjust_counters(0, offset_ticks);
		gs->flags |= PP_SERVO_FLAG_WAIT_HW;
		setState(ppi,WRH_SYNC_PHASE);
		break;

	case WRH_SYNC_PHASE:
		pp_diag(ppi, servo, 2, "oldsetp %i, offset %i:%04i\n",
			s->cur_setpoint_ps, offset_ticks,
			offset_ps);
		s->cur_setpoint_ps += offset_ps;
		pp_diag(ppi, servo, 3, "%s.%d: Adjust_phase: %d\n",__func__,__LINE__,s->cur_setpoint_ps);
		WRH_OPER()->adjust_phase(s->cur_setpoint_ps);

		gs->flags |= PP_SERVO_FLAG_WAIT_HW;
		setState(ppi,WRH_WAIT_OFFSET_STABLE);

		if (CONFIG_ARCH_IS_WRS) {
			/*
			 * Now, let's fix system time. We pass here
			 * once only, so that's the best place to do
			 * it. We use current WR time.
			 * */
			struct pp_time t;
			TOPS(ppi)->get(ppi,&t);
			unix_time_ops.set(ppi, &t);
			pp_diag(ppi, time, 1, "system time set to %s TAI\n",
				time_to_string(&t));
		}
		break;

	case WRH_WAIT_OFFSET_STABLE:

		/* ts_to_picos() below returns phase alone */
		remaining_offset = abs(pp_time_to_picos(&offsetMS));
		if(remaining_offset < WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {
			TOPS(ppi)->enable_timing_output(GLBS(ppi),1);
			s->prev_delayMS_ps = s->delayMS_ps;
			setState(ppi,WRH_TRACK_PHASE);
		} else {
			s->missed_iters++;
		}
		if (s->missed_iters >= 10) {
			s->missed_iters = 0;
			setState(ppi,WRH_SYNC_PHASE);
		}
		break;

	case WRH_TRACK_PHASE:
		s->skew_ps = s->delayMS_ps - s->prev_delayMS_ps;

		/* Can be disabled for manually tweaking and testing */
		if(wrh_tracking_enabled) {
			if (abs(offset_ps) >
			    2 * WRH_SERVO_OFFSET_STABILITY_THRESHOLD) {
				setState(ppi,WRH_SYNC_PHASE);
				break;
			}

			// adjust phase towards offset = 0 make ck0 0
			s->cur_setpoint_ps += (offset_ps / 4);

			pp_diag(ppi, servo, 3, "%s.%d: Adjust_phase: %d\n",__func__,__LINE__,s->cur_setpoint_ps);
			WRH_OPER()->adjust_phase(s->cur_setpoint_ps);
			pp_diag(ppi, time, 1, "adjust phase %i\n",
				s->cur_setpoint_ps);

			s->prev_delayMS_ps = s->delayMS_ps;
		}
		break;

	}

	gs->servo_locked = (gs->state==WRH_TRACK_PHASE);

	/* Increase number of servo updates with state different than
	 * WRH_TRACK_PHASE. (Used by SNMP) */
	if (gs->state != WRH_TRACK_PHASE)
		s->n_err_state++;

	/* Increase number of servo updates with offset exceeded
	 * SNMP_MAX_OFFSET_PS (Used by SNMP) */
	if (abs(s->offsetMS_ps) > SNMP_MAX_OFFSET_PS)
		s->n_err_offset++;

	/* Increase number of servo updates with delta rtt exceeded
	 * SNMP_MAX_DELTA_RTT_PS (Used by SNMP) */
	if (abs(prev_delayMM_ps - s->delayMM_ps) > SNMP_MAX_DELTA_RTT_PS)
		s->n_err_delta_rtt++;
	return 1;
}
