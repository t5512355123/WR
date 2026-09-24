/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __WREXT_WR_API_H__
#define __WREXT_WR_API_H__

#if CONFIG_HAS_EXT_WR

/* Don't include the Following when this file is included in assembler. */
#ifndef __ASSEMBLY__
#include <ppsi/lib.h>
#include "../include/hw-specific/wrh.h"
#include "wr-constants.h"

typedef enum {
	PD_NO_DETECTION=0, //No new parent detected
	PD_WR_PARENT, // WR parent detected
	PD_NOT_WR_PARENT // Not a WR parent detected
}ParentDetection;

/*
 * This structure is used as extension-specific data in the DSPort
 * (see wrspec.v2-06-07-2011, page 17)
 */
struct wr_dsport {
	wr_state_t state, next_state; /* WR state */
	Boolean    wrModeOn; /* True when extension is running */
	Boolean    parentWrModeOn;
	FixedDelta deltaTx;
	FixedDelta deltaRx;
	FixedDelta otherNodeDeltaTx;
	FixedDelta otherNodeDeltaRx;
	Boolean doRestart;

	Enumeration8 wrConfig;
	Enumeration8 wrMode;
	Enumeration8  wrPortState; /* used for sub-states during calibration */
	/* FIXME check doc: knownDeltaTx, knownDeltaRx, deltasKnown?) */
	Boolean calibrated;
	UInteger32 wrStateTimeout;
	UInteger8 wrStateRetry;
	UInteger32 calPeriod;		/* microseconsds, never changed */
	UInteger8 calRetry;
	Enumeration8 parentWrConfig;
	Boolean parentIsWRnode; /* FIXME Not in the doc */
	/* FIXME check doc: (parentWrMode?) */
	Boolean parentCalibrated;

	/* FIXME: are they in the doc? */
	UInteger16 otherNodeCalSendPattern;
	UInteger32 otherNodeCalPeriod;/* microseconsds, never changed */
	UInteger8 otherNodeCalRetry;

	struct PortIdentity parentAnnPortIdentity; /* Last received announce message port identity */
	UInteger16	parentAnnSequenceId; /* Last received sequence did in the parent announce message */
	ParentDetection     parentDetection; /* Indicates that a new parent has been detected */
};

/* This uppercase name matches "DSPOR(ppi)" used by standard protocol */
static inline struct wr_dsport *WR_DSPOR(struct pp_instance *ppi)
{
	return ppi->portDS->ext_dsport;
}

static inline Integer32 phase_to_cf_units(Integer32 phase)
{
	uint64_t ph64;
	if (phase >= 0) {
		ph64 = phase * 65536LL;
		__div64_32(&ph64, 1000);
		return ph64;
	} else {
		ph64 = -phase * 65536LL;
		__div64_32(&ph64, 1000);
		return -ph64;
	}
}

/* Pack/Unkpack White rabbit message in the suffix of PTP announce message */
void msg_pack_announce_wr_tlv(struct pp_instance *ppi);
void msg_unpack_announce_wr_tlv(void *buf, MsgAnnounce *ann, UInteger16 *wrFlags);

/* Pack/Unkpack/Issue White rabbit message signaling msg */
int msg_pack_wrsig(struct pp_instance *ppi, Enumeration16 wr_msg_id);
int msg_unpack_wrsig(struct pp_instance *ppi, void *buf,
		      MsgSignaling *wrsig_msg, Enumeration16 *wr_msg_id);
int msg_issue_wrsig(struct pp_instance *ppi, Enumeration16 wr_msg_id);

/* White rabbit state functions */
int wr_present(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_m_lock(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_s_lock(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_locked(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_calibration(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_calibrated(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_resp_calib_req(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_link_on(struct pp_instance *ppi, void *buf, int len,int new_state);
int wr_idle(struct pp_instance *ppi, void *buf, int len, int new_state);
int wr_run_state_machine(struct pp_instance *ppi, void *buf, int len);

/* Common functions, used by various states and hooks */
void wr_handshake_init(struct pp_instance *ppi, int mode);
void wr_handshake_fail(struct pp_instance *ppi); /* goto non-wr */
int wr_handshake_retry(struct pp_instance *ppi); /* 1 == retry; 0 == failed */
int wr_execute_slave(struct pp_instance *ppi);
int wr_ready_for_slave(struct pp_instance *ppi);
void wr_reset_process(struct pp_instance *ppi, wr_role_t role);


/* wr_servo interface */
int     wr_servo_init(struct pp_instance *ppi);

typedef struct wr_servo_ext {
	struct pp_time delta_txm;
	struct pp_time delta_rxm;
	struct pp_time delta_txs;
	struct pp_time delta_rxs;
	struct pp_time rawT1, rawT2, rawT3, rawT4, rawT5, rawT6;		/* raw value of timestamps  */
	struct pp_time rawDelayMM; // Calculation of delayMM with raw values of timestamps
}wr_servo_ext_t;


/* All data used as extension ppsi-wr must be put here */
struct wr_data {
	wrh_servo_t servo; /* As to be in the first place in this structure */
	wr_servo_ext_t servo_ext;
};

static inline  struct wr_servo_ext *WRE_SRV(struct pp_instance *ppi)
{
	return &((struct wr_data *)ppi->ext_data)->servo_ext;
}

extern const struct pp_ext_hooks wr_ext_hooks;

/* Servo routines */
static inline void wr_servo_reset(struct pp_instance *ppi) {
	wrh_servo_reset(ppi);
}

extern int wr_servo_got_sync(struct pp_instance *ppi);
extern int wr_servo_got_resp(struct pp_instance *ppi);
extern int wr_servo_got_presp(struct pp_instance *ppi);

#endif /* __ASSEMBLY__ */
#endif  /* CONFIG_EXT_WR == 1*/

#endif /* __WREXT_WR_API_H__ */
