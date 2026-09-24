/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

/* White Rabbit stuff
 * if this defined, WR uses new implementation of timeouts (not using interrupt)
 */

#ifndef __WREXT_WR_CONSTANTS_H__
#define __WREXT_WR_CONSTANTS_H__

#include <limits.h>

#define WR_IS_CALIBRATED		0x04
#define WR_IS_WR_MODE			0x08
#define WR_NODE_MODE			0x03 /* a mask, see NON_WR etc below */

#define WR_TLV_TYPE			0x2004

#define FIX_ALPHA_FRACBITS 40
#define FIX_ALPHA_FRACBITS_AS_FLOAT 40.0
#define FIX_ALPHA_TWO_POW_FRACBITS  ((double)1.099511627776E12) /* double value returned by pow(2.0,40.0) */

#define WR_DEFAULT_STATE_TIMEOUT_MS	300	/* [ms] ML: not really used*/

#define WR_PRESENT_TIMEOUT_MS	     1000

#define WR_M_LOCK_TIMEOUT_MS		15000

/* Special case for eRTM14 and wr2rf.
 * Where it can take more than 15sec to sync PLL */
#if CONFIG_TARGET_ERTM14 || CONFIG_TARGET_WR2RF_VME
#define WR_S_LOCK_TIMEOUT_MS		30000
#else
#define WR_S_LOCK_TIMEOUT_MS		15000
#endif


#define WR_LOCKED_TIMEOUT_MS          300
#define WR_CALIBRATION_TIMEOUT_MS    3000
#define WR_RESP_CALIB_REQ_TIMEOUT_MS  300 //  3
#define WR_CALIBRATED_TIMEOUT_MS      300


#define WR_DEFAULT_CAL_PERIOD		WR_CALIBRATION_TIMEOUT_MS	/* [us] */

#define WR_STATE_RETRY			3	/* if WR handhsake fails */

/* White Rabbit package Size */
#define WR_ANNOUNCE_TLV_LENGTH		0x0A

/* The +4 is for tlvType (2 bytes) and lengthField (2 bytes) */
#define WR_ANNOUNCE_LENGTH (PP_ANNOUNCE_LENGTH + WR_ANNOUNCE_TLV_LENGTH + 4)

/* new stuff for WRPTPv2 */

#define WR_TLV_ORGANIZATION_ID		0x080030
#define WR_TLV_MAGIC_NUMBER		0xDEAD
#define WR_TLV_WR_VERSION_NUMBER	0x01

/* WR_SIGNALING_MSG_BASE_LENGTH Computation:
 * = LEN(header) + LEN(targetPortId) + LEN(tlvType) + LEN(lenghtField)
 *      34       +      10           +     2        +     2 */
#define WR_SIGNALING_MSG_BASE_LENGTH	48

#define WR_DEFAULT_PHY_CALIBRATION_REQUIRED FALSE

/* Indicates if a port is configured as White Rabbit, and what kind
 * (master/slave) */
typedef enum {
	NON_WR = 0,
	WR_M_ONLY	= 0x1,
	WR_S_ONLY	= 0x2,
	WR_M_AND_S	= 0x3,
	WR_MODE_AUTO= 0x4, /* only for ptpx - not in the spec */
}wr_config_t;

/* White Rabbit node */
typedef enum {
	WR_ROLE_NONE=0,
	WR_MASTER = 1,
	WR_SLAVE  = 2
}wr_role_t;

/* Values of Management Actions (extended for WR), see table 38
 */
enum {
	GET,
	SET,
	RESPONSE,
	COMMAND,
	ACKNOWLEDGE,
	WR_CMD, /* White Rabbit */
};

/* brief WR PTP states */
typedef enum {
	WRS_IDLE=0,
	WRS_PRESENT,
	WRS_S_LOCK,
	WRS_M_LOCK,
	WRS_LOCKED,
	WRS_CALIBRATION,
	WRS_CALIBRATED,
	WRS_RESP_CALIB_REQ,
	WRS_WR_LINK_ON,
	WRS_MAX_STATES,
	wr_state_t_ForceToIntSize = INT_MAX
}wr_state_t;

/* White Rabbit commands (for new implementation, single FSM), see table 38 */
enum {

	NULL_WR_TLV = 0x0000,
	SLAVE_PRESENT	= 0x1000,
	LOCK,
	LOCKED,
	CALIBRATE,
	CALIBRATED,
	WR_MODE_ON,
	ANN_SUFIX = 0x2000,
};

#endif /* __WREXT_WR_CONSTANTS_H__ */
