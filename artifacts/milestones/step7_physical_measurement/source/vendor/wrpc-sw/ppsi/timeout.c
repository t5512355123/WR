/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <ppsi/ppsi.h>
#include "include/ppsi/timeout_prot.h"

#define TIMEOUT_MAX_LOG_VALUE 21 /* 2^21 * 1000 =2097152000ms is the maximum value that can be stored in an integer */
#define TIMEOUT_MIN_LOG_VALUE -9 /* 2^-9 = 1ms is the minimum value that can be stored in an integer */
#define TIMEOUT_MAX_VALUE_MS  ((1<< TIMEOUT_MAX_LOG_VALUE)*1000)
#define TIMEOUT_MIN_VALUE_MS  (1000>>-(TIMEOUT_MIN_LOG_VALUE))

typedef struct  {
	const char *name; /* if name==NULL then the counter is considered as free */
	int ctrlFlag;
} timeOutConfig_t;


static const timeOutConfig_t timeOutConfigs[PP_TO_COUNT]= {
	{
		.name="REQUEST",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT | TMO_CF_ALLOW_COMMON_SET,
	},
	{
		.name="SYNC_SEND",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT | TMO_CF_ALLOW_COMMON_SET,
	},
	{
		.name="BMC",
	},
	{
		.name="ANN_RECEIPT",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT | TMO_CF_ALLOW_COMMON_SET,
	},
	{
		.name="ANN_SEND",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT | TMO_CF_ALLOW_COMMON_SET,
	},
	{
		.name="QUAL",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT | TMO_CF_ALLOW_COMMON_SET,
	},
	{
		.name="PROT_STATE",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT,
	},
	{
		.name="IN_STATE",
		.ctrlFlag= TMO_CF_INSTANCE_DEPENDENT,
	},
	{
		.name="GM_BY_BMCA",
		.ctrlFlag= 0,
	},
	{
		.name="L1E_TX_SYNC",
		.ctrlFlag = TMO_CF_INSTANCE_DEPENDENT
	},
	{
		.name="L1E_RX_SYNC",
		.ctrlFlag = TMO_CF_INSTANCE_DEPENDENT
	},
	{
		.name="WR_EXT",
		.ctrlFlag = TMO_CF_INSTANCE_DEPENDENT
	},
#if CONFIG_ARCH_IS_WRS == 1
	{
		.name="SEND_PORT_INDEX",
		.ctrlFlag = 0,
	},
	{
		.name="GM_REFRESH",
		.ctrlFlag = 0,
	},
#endif
};

static inline timeOutInstCnt_t *__pp_get_counter(struct pp_instance *ppi, int index) {
	if ( !(timeOutConfigs[index].ctrlFlag & TMO_CF_INSTANCE_DEPENDENT) )
		ppi=INST(GLBS(ppi),0);
	return &ppi->tmo_cfg[index];
}

void pp_timeout_disable_all(struct pp_instance *ppi) {
	int i;

	for ( i=0; i < PP_TO_COUNT; i++) {
		ppi->tmo_cfg[i].initValueMs=TIMEOUT_DISABLE_VALUE;
		ppi->tmo_cfg[i].tmo=0;
	}
}

/* Return counter index or -1 if not available */
int pp_timeout_get_timer(struct pp_instance *ppi, int index, to_rand_t rand) {
	timeOutInstCnt_t *tmoCnt;

	tmoCnt= __pp_get_counter(ppi,index);
	tmoCnt->which_rand=rand;
	ppi->tmo_cfg[index].initValueMs=TIMEOUT_DISABLE_VALUE;
	return index;
}

int pp_timeout_log_to_ms ( Integer8 logValue) {
	/* logValue can be in range -128 , +127
	 * However we restrict this range to TIMEOUT_MIN_LOG_VALUE, TIMEOUT_MAX_LOG_VALUE
	 * in order to optimize the calculation
	 */

	if ( logValue >= 0 ) {
		return ( logValue > TIMEOUT_MAX_LOG_VALUE ) ?
				TIMEOUT_MAX_VALUE_MS :
			    ((1<< logValue)*1000);
	}
	else {
		return (logValue<TIMEOUT_MIN_LOG_VALUE) ?
				TIMEOUT_MIN_VALUE_MS :
				(1000>>-logValue);
	}
}

/* Init fills the timeout values */
void pp_timeout_init(struct pp_instance *ppi)
{
	portDS_t *port = ppi->portDS;
	timeOutInstCnt_t *tmoCnt=ppi->tmo_cfg;
	Boolean p2p=is_delayMechanismP2P(ppi);
	Integer8 logDelayRequest=p2p ?
			port->logMinPdelayReqInterval : port->logMinDelayReqInterval;

	pp_diag(ppi, time, 3, "%s\n",__func__);

	/* TO_RAND_NONE is the default value */
	tmoCnt[PP_TO_REQUEST].which_rand = p2p ? TO_RAND_NONE : TO_RAND_0_200;
	tmoCnt[PP_TO_SYNC_SEND].which_rand=
			tmoCnt[PP_TO_ANN_SEND].which_rand=TO_RAND_70_130;

	tmoCnt[PP_TO_REQUEST].initValueMs= pp_timeout_log_to_ms(logDelayRequest);
	tmoCnt[PP_TO_SYNC_SEND].initValueMs =  pp_timeout_log_to_ms(port->logSyncInterval);

	// Initialize BMCA timer (Independent Timer)
	// Take the lowest value of logAnnounceInterval
	{
		timeOutInstCnt_t *gtmoCnt=&INST(GLBS(ppi),0)->tmo_cfg[PP_TO_BMC];
		int ms=pp_timeout_log_to_ms(port->logAnnounceInterval);
		if (gtmoCnt->initValueMs==TIMEOUT_DISABLE_VALUE || ms<gtmoCnt->initValueMs)
			gtmoCnt->initValueMs=ms;
	}
	/* Clause 17.6.5.3 : ExternalPortConfiguration enabled
	 *  - The Announce receipt timeout mechanism (see 9.2.6.12) shall not be active.
	 */
	if ( is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
		tmoCnt[PP_TO_ANN_RECEIPT].initValueMs =
				tmoCnt[PP_TO_QUALIFICATION].initValueMs =TIMEOUT_DISABLE_VALUE;
	} else {
		tmoCnt[PP_TO_ANN_RECEIPT].initValueMs=1000 * (port->announceReceiptTimeout << port->logAnnounceInterval);
		tmoCnt[PP_TO_QUALIFICATION].initValueMs =
		    (1000 << port->logAnnounceInterval)*(DSCUR(ppi)->stepsRemoved + 1);
	}
	tmoCnt[PP_TO_ANN_SEND].initValueMs =  pp_timeout_log_to_ms(port->logAnnounceInterval);
}

int pp_timeout_get(struct pp_instance *ppi, int index) {
	timeOutInstCnt_t *tmoCnt= __pp_get_counter(ppi,index);
	return tmoCnt->initValueMs;
}

static inline void __pp_timeout_set(struct pp_instance *ppi, int index, int millisec) {
	timeOutInstCnt_t *tmoCnt= __pp_get_counter(ppi,index);

	tmoCnt->tmo = TOPS(ppi)->calc_timeout(ppi, millisec);
}

void pp_timeout_set_rename(struct pp_instance *ppi, int index, int millisec)
{
	timeOutInstCnt_t *tmoCnt= __pp_get_counter(ppi,index);

	tmoCnt->initValueMs=millisec;
	__pp_timeout_set(ppi,index,millisec);
	pp_diag(ppi, time, 3, "timeout overwr.: %s - %i / %lu\n",
			timeOutConfigs[index].name, millisec, tmoCnt->tmo);
}

void __pp_timeout_reset(struct pp_instance *ppi, int index, unsigned int multiplier)
{
	static uint32_t seed;
	int millisec;
	timeOutInstCnt_t *tmoCnt= __pp_get_counter(ppi,index);

	if ( tmoCnt->initValueMs==TIMEOUT_DISABLE_VALUE)
		return;
	millisec = tmoCnt->initValueMs*multiplier;
	if (tmoCnt->which_rand!=TO_RAND_NONE && millisec>0) {
		uint32_t rval;

		if (!seed) {
			uint32_t *p;
			/* use the least 32 bits of the mac address as seed */
			p = (void *)(&DSDEF(ppi)->clockIdentity)
				+ sizeof(ClockIdentity) - 4;
			seed = *p;
		}
		/* From uclibc: they make 11 + 10 + 10 bits, we stop at 21 */
		seed *= 1103515245;
		seed += 12345;
		rval = (unsigned int) (seed / 65536) % 2048;

		seed *= 1103515245;
		seed += 12345;
		rval <<= 10;
		rval ^= (unsigned int) (seed / 65536) % 1024;

		millisec=(millisec<<1)/5; /* keep 40% of the reference value */
		if ( millisec > 0 ) {
			switch(tmoCnt->which_rand) {
			case TO_RAND_70_130:
				/*
				 * We are required to fit between 70% and 130%
				 * of the value for 90% of the time, at least.
				 * So randomize between 80% and 120%: constant
				 * part is 80% and variable is 40%.
				 */
				millisec = (millisec * 2) + rval % millisec;
				break;
			case TO_RAND_0_200:
				millisec = rval % (millisec * 5);
				break;
			default:
			/* RAND_NONE already treated */
				break;
			}
		}
	}
	__pp_timeout_set(ppi, index, millisec);
	pp_diag(ppi, time, 3, "timeout reseted: %s - %i / %lu\n",
			timeOutConfigs[index].name, millisec, tmoCnt->tmo);
}

/*
 * When we enter a new fsm state, we init all timeouts. Who cares if
 * some of them are not used (and even if some have no default timeout)
 */
void pp_timeout_setall(struct pp_instance *ppi)
{
	int i;
	for (i = 0; i < PP_TO_COUNT; i++) {
		if (timeOutConfigs[i].ctrlFlag & TMO_CF_ALLOW_COMMON_SET )
			pp_timeout_reset(ppi, i);
	}
	/* but announce_send must be send soon */
	__pp_timeout_set(ppi, PP_TO_ANN_SEND, 20);
}

int pp_timeout(struct pp_instance *ppi, int index)
{
	timeOutInstCnt_t *tmoCnt= __pp_get_counter(ppi,index);
	int ret;
	unsigned long now;

	if ( tmoCnt->initValueMs==TIMEOUT_DISABLE_VALUE )
		return 0; /* counter is disabled */

	now=TOPS(ppi)->calc_timeout(ppi, 0);
	ret = time_after_eq(now,tmoCnt->tmo);
	if (ret)
		pp_diag(ppi, time, 1, "timeout expired: %s - %lu\n",
				timeOutConfigs[index].name,now);
	return ret;
}

/*
 * How many ms to wait for the timeout to happen, for ppi->next_delay.
 * It is not allowed for a timeout to not be pending
 */
int pp_next_delay_1(struct pp_instance *ppi, int i1)
{
	timeOutInstCnt_t *tmoCnt= __pp_get_counter(ppi,i1);
	unsigned long now = TOPS(ppi)->calc_timeout(ppi, 0);

	return time_before(tmoCnt->tmo, now) ? 0 : tmoCnt->tmo - now;
}

int pp_next_delay_2(struct pp_instance *ppi, int i1, int i2)
{
	timeOutInstCnt_t *tmoCnt1= __pp_get_counter(ppi,i1);
	timeOutInstCnt_t *tmoCnt2= __pp_get_counter(ppi,i2);
	unsigned long now = TOPS(ppi)->calc_timeout(ppi, 0);
	unsigned long tmo_min;

	tmo_min = tmoCnt1->tmo;

	/* write to tmo_min timeout which is earlier */
	if (time_after(tmo_min, tmoCnt2->tmo))
		tmo_min = tmoCnt2->tmo;

	/* check if the earlier timeout already passed */
	if (time_before(now, tmo_min)) {
		/* not passed return left ms */
		return tmo_min - now;
	}

	/* the earliest timeout already passed */
	return 0;
}

int pp_next_delay_3(struct pp_instance *ppi, int i1, int i2, int i3)
{
	timeOutInstCnt_t *tmoCnt1= __pp_get_counter(ppi,i1);
	timeOutInstCnt_t *tmoCnt2= __pp_get_counter(ppi,i2);
	timeOutInstCnt_t *tmoCnt3= __pp_get_counter(ppi,i3);
	unsigned long now = TOPS(ppi)->calc_timeout(ppi, 0);
	unsigned long tmo_min;

	tmo_min = tmoCnt1->tmo;

	/* write to tmo_min timeout which is earlier */
	if (time_after(tmo_min, tmoCnt2->tmo))
		tmo_min = tmoCnt2->tmo;

	if (time_after(tmo_min, tmoCnt3->tmo))
		tmo_min = tmoCnt3->tmo;

	/* check if the earliest timeout already passed */
	if (time_before(now, tmo_min)) {
		/* not passed, return left ms */
		return tmo_min - now;
	}

	/* the earliest timeout already passed */
	return 0;
}
