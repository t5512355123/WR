/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * A timeout, is a number that must be compared with the current counter.
 * A counter can be PPSi dependant or dependant.
 * A set of predefined counters are declared and a set is free. It can
 * be use by protocol extensions and specific task.
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef _TIMEOUT_DEF_H_
#define _TIMEOUT_DEF_H_

/*
 * Time-out structure and enumeration
 */
typedef enum   {
	TO_RAND_NONE,	/* Not randomized */
	TO_RAND_70_130,	/* Should be 70% to 130% of 1 << value */
	TO_RAND_0_200,	/* Should be 0% to 200% of 1 << value */
}to_rand_t ;

typedef struct  {
	to_rand_t which_rand;
	int initValueMs;
	unsigned long tmo;
} timeOutInstCnt_t;


/* We use an array of timeouts, with these indexes */
enum pp_timeouts {
	PP_TO_REQUEST = 0,
	PP_TO_SYNC_SEND,
	PP_TO_BMC,
	PP_TO_ANN_RECEIPT,
	PP_TO_ANN_SEND,
	PP_TO_QUALIFICATION,
	PP_TO_PROT_STATE,
	PP_TO_IN_STATE,
	PP_TO_GM_BY_BMCA,
	PP_TO_PREDEF_COUNTERS, /* Number of predefined counters */
	PP_TO_L1E_TX_SYNC = PP_TO_PREDEF_COUNTERS,
	PP_TO_L1E_RX_SYNC,
	PP_TO_WR_EXT_0,
#if CONFIG_ARCH_IS_WRS == 1
	PP_TO_WRS_SEND_PORT_INFO,
	PP_TO_WRS_GM_REFRESH,
#endif
	PP_TO_COUNT
};

/* Control flags */
#define TMO_CF_INSTANCE_DEPENDENT 1 /* PPSi instance dependent: each instance has its own counters */
#define TMO_CF_ALLOW_COMMON_SET   2 /* Counter reseted when pp_timeout_setall() is called */

#define TMO_DEFAULT_BMCA_MS   2000 /* Can be readjusted dynamically to be executed at lest once per announce send msg */

#endif /* ifndef _TIMEOUT_DEF_H_*/
