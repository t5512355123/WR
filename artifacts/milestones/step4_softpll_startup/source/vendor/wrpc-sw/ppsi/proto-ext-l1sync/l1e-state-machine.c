/*
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include <common-fun.h>
#include "l1e-constants.h"
#include <math.h>

typedef int (*l1e_state_action_t)(struct pp_instance *ppi, Boolean newState);

extern const char * const l1e_state_name[];

#define MAX_STATE_ACTIONS ARRAY_SIZE(le1_state_actions)

/* prototypes */
static int l1e_empty_action(struct pp_instance *ppi, Boolean new_state);
static int l1e_handle_state_disabled(struct pp_instance *ppi, Boolean new_state);
static int l1e_handle_state_idle(struct pp_instance *ppi, Boolean new_state);
static int l1e_handle_state_link_alive(struct pp_instance *ppi, Boolean new_state);
static int l1e_handle_state_config_match(struct pp_instance *ppi, Boolean new_state);
static int l1e_handle_state_up(struct pp_instance *ppi, Boolean new_state);

static const l1e_state_action_t le1_state_actions[] =
{
	[0]			= l1e_empty_action,
	[L1SYNC_DISABLED]	= l1e_handle_state_disabled,
	[L1SYNC_IDLE]		= l1e_handle_state_idle,
	[L1SYNC_LINK_ALIVE]	= l1e_handle_state_link_alive,
	[L1SYNC_CONFIG_MATCH]	= l1e_handle_state_config_match,
	[L1SYNC_UP]		= l1e_handle_state_up,
};

/*
 * This hook is called by fsm to run the extension state machine.
 * It is used to send signaling messages.
 * It returns the ext-specific timeout value
 */
int l1e_run_state_machine(struct pp_instance *ppi, void *buf, int len)
{
	L1SyncBasicPortDS_t * basicDS=L1E_DSPOR_BS(ppi);
	Enumeration8 nextState=basicDS->next_state;
	Boolean newState=nextState!=basicDS->L1SyncState;
	int *execute_state_machine=&L1E_DSPOR(ppi)->execute_state_machine;
	int delay;

	if ( basicDS->next_state!=L1SYNC_DISABLED &&
			(ppi->extState!=PP_EXSTATE_ACTIVE || ppi->state==PPS_INITIALIZING))
		return PP_DEFAULT_NEXT_DELAY_MS; /* Return default delay */

	if ( nextState>=MAX_STATE_ACTIONS)
		return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC);

	/*
	 *  Update the L1SYNC dynamic data independent of the state machine
	 */

	/* By design, when link is up, it is always tx coherent and congruent*/
	basicDS->isTxCoherent= ppi->link_up ? 1 : 0;

	/* Check L1SYNC reception Time-out */
	if ( pp_timeout(ppi, PP_TO_L1E_RX_SYNC) ) {
		/* Time-out detected */
		pp_timeout_set(ppi, PP_TO_L1E_RX_SYNC, l1e_get_rx_tmo_ms(basicDS));
		basicDS->L1SyncLinkAlive = FALSE;
		*execute_state_machine=TRUE;
	}

	/* Check L1SYNC transmission Time-out */
	if ( pp_timeout(ppi, PP_TO_L1E_TX_SYNC) ) {
		*execute_state_machine=TRUE;
	}

	/*
	 * Evaluation of events common to all states
	 */
	if ( newState ) {
		basicDS->L1SyncState=nextState;
		pp_diag(ppi, ext, 2, "L1SYNC state: Enter %s\n", l1e_state_name[nextState]);
		*execute_state_machine=TRUE;
	}

	if ( *execute_state_machine ) {
		/* The state machine is executed only when really needed because
		 * fsm can call this function too often.
		 */
		delay=(*le1_state_actions[basicDS->L1SyncState])(ppi,newState);
	} else
		delay=pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */

	/* If return delay is 0, it means that the state machine should be executed at last call */
	*execute_state_machine= (delay==0);

	if ( basicDS->L1SyncState != basicDS->next_state )
		pp_diag(ppi, ext, 2, "L1SYNC state: Exit %s\n", l1e_state_name[basicDS->L1SyncState]);
	return delay;
}

static int l1e_empty_action(struct pp_instance *ppi, Boolean new_state)
{
	return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */
}

/* L1_SYNC_RESET event */
static inline Boolean le1_evt_L1_SYNC_RESET(struct pp_instance *ppi)
{
	return ppi->link_up == 0 || ppi->state==PPS_INITIALIZING;
}

/* L1_SYNC_ENABLED event */
static inline Boolean le1_evt_L1_SYNC_ENABLED(struct pp_instance *ppi)
{
	return L1E_DSPOR_BS(ppi)->L1SyncEnabled == TRUE;
}

/* CONFIG_OK event */
static inline Boolean le1_evt_CONFIG_OK(struct pp_instance *ppi)
{
	L1SyncBasicPortDS_t *basicDS=L1E_DSPOR_BS(ppi);

	return basicDS->txCoherentIsRequired==basicDS->peerTxCoherentIsRequired
		&& basicDS->rxCoherentIsRequired==basicDS->peerRxCoherentIsRequired
		&& basicDS->congruentIsRequired==basicDS->peerCongruentIsRequired;
}


/* STATE_OK event */
static Boolean le1_evt_STATE_OK(struct pp_instance *ppi)
{
	L1SyncBasicPortDS_t *basicDS=L1E_DSPOR_BS(ppi);
	int pll_state;

	/* Update isRxCoherent and isCongruant : it must follow the PTP state machine */
	switch (ppi->state) {
	case PPS_SLAVE :
	case PPS_UNCALIBRATED :
		pll_state= WRH_OPER()->locking_poll(ppi); /* Get the PPL state */
		basicDS->isCongruent =
			basicDS->isRxCoherent = pll_state == WRH_SPLL_LOCKED;
		break;
	case PPS_MASTER :
		basicDS->isRxCoherent=  basicDS->peerIsTxCoherent  &&
					basicDS->peerIsRxCoherent  &&
					basicDS->isTxCoherent;
		/** TODO: in principle, the PLL should report unlocked when it is not locked,
		 * regardless of the state. Thus, when we check in MASTER state, it should report
		 * unlocked - this is not the case for some reasons
		 * Ideally, we want to check whether PLL is locked at any time. This is to cover
		 * the case of network re-arrangement. In such case, a port in SLAVE state can
		 * transition to MASTER state and after such transition the port in MASTER state
		 * might remain locked. We want to detect this case.
		 *
		 * Thus, the condition should be:
		 * basicDS->isCongruent= pll_state == !WRH_SPLL_LOCKED ? 1 : 0;
		 */
		basicDS->isCongruent = 1;
		break;
	default :
		basicDS->isCongruent = 0;
	}

	return ( !basicDS->txCoherentIsRequired  || (basicDS->isTxCoherent && basicDS->peerIsTxCoherent ))
		&& ( !basicDS->rxCoherentIsRequired  || (basicDS->isRxCoherent && basicDS->peerIsRxCoherent ))
		&& ( !basicDS->congruentIsRequired   || (basicDS->isCongruent && basicDS->peerIsCongruent));
}

/* LINK_OK event */
static inline Boolean le1_evt_LINK_OK(struct pp_instance *ppi)
{
	return L1E_DSPOR(ppi)->basic.L1SyncLinkAlive == TRUE;
}

static __inline__ int measure_first_time(struct pp_instance *ppi)
{
	struct pp_time current_time;
	int ms;
	uint64_t ns;

	/* FIXME: use calc_timeout ? */

	TOPS(ppi)->get(ppi, &current_time);
	ms=(current_time.secs&0xFFFF)*1000; /* do not take all second - Not necessary to calculate a difference*/
	ns = (current_time.scaled_nsecs + 0x8000) >> TIME_INTERVAL_FRACBITS;
	__div64_32(&ns, 1000000);
	ms += ns;

	return ms;
}

static __inline__ int measure_last_time(struct pp_instance *ppi, int fmeas)
{
	int ms=measure_first_time(ppi);
	if ( ms<fmeas ) {
		/* Readjust the time */
		ms+=0xFFFF*1000;
	}
	return ms;
}

static void l1e_send_sync_msg(struct pp_instance *ppi, Boolean immediatSend)
{
	int len;
	int fmeas, lmeas;
	int diff;
	int tmo_ms;

	if (!immediatSend && !pp_timeout(ppi, PP_TO_L1E_TX_SYNC))
		return;

	fmeas=measure_first_time(ppi);
	pp_diag(ppi, ext, 1, "Sending L1SYNC_TLV signaling msg\n");
	len = l1e_pack_signal(ppi);
	__send_and_log(ppi, len, PP_NP_GEN,PPM_SIGNALING_NO_FWD_FMT);
	lmeas=measure_last_time(ppi,fmeas);

	/* Calculate when the next message should be sent */
	/* A "diff" value is subtracted from the timer to take into account
	 * the execution time of this function. With small time-out like 64ms,
	 * the error become not negligible.
	 */
	tmo_ms=pp_timeout_log_to_ms(L1E_DSPOR_BS(ppi)->logL1SyncInterval);
	diff=lmeas-fmeas;
	if ( tmo_ms >= diff ) /* to be sure to have a positive value */
		tmo_ms-=diff;
	pp_timeout_set(ppi, PP_TO_L1E_TX_SYNC,tmo_ms); /* loop ever since */
}

/* DISABLED state */
static int l1e_handle_state_disabled(struct pp_instance *ppi, Boolean new_state)
{
	l1e_ext_portDS_t * l1e_portDS=L1E_DSPOR(ppi);

	/* State initialization */
	if ( new_state ) {
		/* Table 157 - page 449
		 * All dynamic members of L1SyncBasicPortDS and L1SyncOptPortDS data sets are set
		 * to initialization values
		 */
		l1e_portDS->basic.isTxCoherent = FALSE;
		l1e_portDS->basic.isRxCoherent = FALSE;
		l1e_portDS->basic.isCongruent = FALSE;
		l1e_portDS->basic.peerTxCoherentIsRequired = FALSE;
		l1e_portDS->basic.peerRxCoherentIsRequired = FALSE;
		l1e_portDS->basic.peerCongruentIsRequired = FALSE;
		l1e_portDS->basic.peerIsTxCoherent = FALSE;
		l1e_portDS->basic.peerIsRxCoherent = FALSE;
		l1e_portDS->basic.peerIsCongruent = FALSE;
	}
	/* Check if state transition needed */
	if ( le1_evt_L1_SYNC_ENABLED(ppi) && !le1_evt_L1_SYNC_RESET(ppi) ) {
		/* Go the IDLE state */
		 L1E_DSPOR_BS(ppi)->next_state=L1SYNC_IDLE;
		 return 0; /* no wait to evaluate next state */
	}
	return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */
}

/* IDLE state */
static int l1e_handle_state_idle(struct pp_instance *ppi, Boolean new_state)
{
	l1e_ext_portDS_t * l1e_portDS=L1E_DSPOR(ppi);

	/* State initialization */
	if ( new_state ) {
		/* Table 157 - page 449
		 * The dynamic members listed in Table 155 are set to initialization
		 * values when entering this state.
		 */
		l1e_portDS->basic.peerTxCoherentIsRequired = FALSE;
		l1e_portDS->basic.peerRxCoherentIsRequired = FALSE;
		l1e_portDS->basic.peerCongruentIsRequired = FALSE;
		l1e_portDS->basic.peerIsTxCoherent = FALSE;
		l1e_portDS->basic.peerIsRxCoherent = FALSE;
		l1e_portDS->basic.peerIsCongruent = FALSE;
		l1e_send_sync_msg(ppi,1); /* Send immediately a message */
	}

	/* Check if state transition needed */
	if ( !le1_evt_L1_SYNC_ENABLED(ppi) || le1_evt_L1_SYNC_RESET(ppi) ) {
		/* Go to DISABLE state */
		l1e_portDS->basic.next_state=L1SYNC_DISABLED;
		pdstate_disable_extension(ppi);
		return 0; /* Treatment required asap */
	}
	if ( le1_evt_LINK_OK(ppi) ) {
		l1e_portDS->basic.next_state=L1SYNC_LINK_ALIVE;
		return 0; /* Treatment required asap */
	}
	/* Iterative treatment */
	l1e_send_sync_msg(ppi,0);
	return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */
}

/* LINK_ALIVE state */
static int l1e_handle_state_link_alive(struct pp_instance *ppi, Boolean new_state)
{
	L1SyncBasicPortDS_t *basic= L1E_DSPOR_BS(ppi);

	/* State initialization */
	if ( new_state ) {
		/* Initialize time-out peer L1SYNC reception */
		pp_timeout_set(ppi, PP_TO_L1E_RX_SYNC, l1e_get_rx_tmo_ms(basic));

	}
	/* Check if state transition needed */
	if ( !le1_evt_LINK_OK(ppi) ) {
		/* Go to IDLE state */
		basic->next_state=L1SYNC_IDLE;
		return 0; /* Treatment required asap */
	}
	/* we will allow to go to CONFIG_MATH only for UNCALIBRATED and MASTER states */
	if ( le1_evt_CONFIG_OK(ppi) && (ppi->state==PPS_UNCALIBRATED || ppi->state==PPS_SLAVE || ppi->state==PPS_MASTER)) {
		basic->next_state=L1SYNC_CONFIG_MATCH;
		return 0; /* Treatment required asap */
	}
	/* Iterative treatment */
	l1e_send_sync_msg(ppi,0);
	return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */
}

/* CONFIG_MATCH state */
static int l1e_handle_state_config_match(struct pp_instance *ppi, Boolean new_state)
{
	L1SyncBasicPortDS_t *basic= L1E_DSPOR_BS(ppi);

	/* State initialization */
	if (new_state) {
		switch ( ppi->state ) {
			case PPS_SLAVE :
			case PPS_UNCALIBRATED :
				if ( basic->congruentIsRequired ) {
					basic->isRxCoherent=0;
					pp_diag(ppi, ext, 1, "Locking PLL\n");
					WRH_OPER()->locking_enable(ppi);
					l1e_servo_init(ppi);
				}
				break;
			case PPS_MASTER :
				// Nothing to do for the master state
				break;
			default:
				break;
		}
	}
	/* Check if state transition needed */
	if ( !le1_evt_LINK_OK(ppi) ) {
		/* Go to IDLE state */
		L1E_DSPOR_BS(ppi)->next_state=L1SYNC_IDLE;
		return 0; /* Treatment required asap */
	}
	if ( !le1_evt_CONFIG_OK(ppi) ) {
		/* Return to LINK_ALIVE state */
		L1E_DSPOR_BS(ppi)->next_state=L1SYNC_LINK_ALIVE;
		return 0; /* Treatment required asap */
	}
	if ( le1_evt_STATE_OK(ppi) ) {
		/* Return to UP state */
		L1E_DSPOR_BS(ppi)->next_state=L1SYNC_UP;
		return 0; /* Treatment required asap */
	}
	/* Iterative treatment */
	l1e_send_sync_msg(ppi,0);

#if CONFIG_ARCH_IS_WRPC
	/* This is an hack.  The locking_poll function called in
	   le1_evt_STATE_OK check for spll locking but also performs rxts
	   calibration, which takes multiple iterations.  To speed up the
	   process, don't wait for the timeout and run it without pause.
	   This is done only on the WR node and only in slave mode.

	   FIXME: makes locking_poll return a timeout ?  */
	if (ppi->state == PPS_SLAVE)
		return 0;
#endif
	return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */
}

/* UP state */
static int l1e_handle_state_up(struct pp_instance *ppi, Boolean new_state)
{
	l1e_ext_portDS_t * l1e_portDS=L1E_DSPOR(ppi);
	Enumeration8 next_state=0;

	/* State initialization */
	if ( new_state ) {
		WRH_OPER()->enable_ptracker(ppi);
		WRH_SRV(ppi)->readyForSync=TRUE;
	}

	/* Check if state transition needed */
	if ( !le1_evt_LINK_OK(ppi) ) {
		/* Go to IDLE state */
		next_state=L1SYNC_IDLE;
		pdstate_disable_extension(ppi);
	}
	if ( !le1_evt_CONFIG_OK(ppi) ) {
		/* Return to LINK_ALIVE state */
		next_state=L1SYNC_LINK_ALIVE;
	}
	if ( !le1_evt_STATE_OK(ppi) ) {
		/* Return to CONFIG_MATCH state */
		next_state=L1SYNC_CONFIG_MATCH;
	}
	if (next_state!=0 ) {
		/* So leave SYNC_UP. */
		l1e_portDS->basic.next_state=next_state;
		if ( ppi->state == PPS_SLAVE || ppi->state==PPS_UNCALIBRATED) {
			WRH_OPER()->locking_disable(ppi); /* Unlock the PLL */
			l1e_servo_reset(ppi);
		}
		return 0; /* Treat the next state asap */
	}

	/* Iterative treatment */
	if (new_state)
		pdstate_enable_extension(ppi);
	l1e_send_sync_msg(ppi,0);
	return pp_next_delay_2(ppi,PP_TO_L1E_TX_SYNC, PP_TO_L1E_RX_SYNC); /* Return the shorter timeout */
}
