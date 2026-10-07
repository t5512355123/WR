/*
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __L1SYNC_EXT_API_H__
#define __L1SYNC_EXT_API_H__

#if CONFIG_HAS_EXT_L1SYNC

#include <ppsi/lib.h>
#include "../include/hw-specific/wrh.h"
#include "l1e-constants.h"

#include <math.h>

#define PROTO_EXT_L1SYNC (1)

/* Time-out */
#define L1E_DEFAULT_L1SYNC_INTERVAL		   0
#define L1E_MIN_L1SYNC_INTERVAL		       -4
#define L1E_MAX_L1SYNC_INTERVAL		       4
#define L1E_DEFAULT_L1SYNC_RECEIPT_TIMEOUT 3
#define L1E_MIN_L1SYNC_RECEIPT_TIMEOUT     2
#define L1E_MAX_L1SYNC_RECEIPT_TIMEOUT     10

/*
 * We don't have ha_dsport, but rather rely on wr_dsport with our fields added.
 *
 *
 * Fortunately (and strangely (thanks Maciej), here the spec *is* consistent.
 * These 3 bits are valid 4 times, in 4 different bytes (conf/active, me/peer)
 */
#define L1E_TX_COHERENT	0x01
#define L1E_RX_COHERENT	0x02
#define L1E_CONGRUENT	0x04
#define L1E_OPT_PARAMS	0x08

enum l1_sync_states { /*draft P1588_v_29: page 334 */
	__L1SYNC_MISSING = 0, /* my addition... */ //TODO: std-error->report in ballout
	L1SYNC_DISABLED = 1,
	L1SYNC_IDLE,
	L1SYNC_LINK_ALIVE,
	L1SYNC_CONFIG_MATCH,
	L1SYNC_UP,
};

/* Pack/Unkpack L1SYNC messages (all of them are signalling messages) */
int l1e_pack_signal(struct pp_instance *ppi);
int l1e_unpack_signal(struct pp_instance *ppi, void *pkt, int plen);

/*
 * These structures are used as extension-specific data in the DSPort
 */
typedef struct  { /*draft P1588_v_29: page 100 and 333-335 */
	/* configurable members */
	Boolean		L1SyncEnabled;
	Boolean		txCoherentIsRequired;
	Boolean		rxCoherentIsRequired;
	Boolean		congruentIsRequired;
	Boolean		optParamsEnabled;
	Integer8	logL1SyncInterval;
	Integer8	L1SyncReceiptTimeout;
	/* dynamic members */
	Boolean		L1SyncLinkAlive;
	Boolean		isTxCoherent;
	Boolean		isRxCoherent;
	Boolean		isCongruent;
	Enumeration8	L1SyncState;
	Boolean		peerTxCoherentIsRequired;
	Boolean		peerRxCoherentIsRequired;
	Boolean		peerCongruentIsRequired;
	Boolean		peerIsTxCoherent;
	Boolean		peerIsRxCoherent;
	Boolean		peerIsCongruent;
	/* None compliant members with IEEE1558-2019 */
	Enumeration8	next_state;
} L1SyncBasicPortDS_t;

typedef struct { /*draft P1588_v_29: page 101 and 340-341  */
	/* configurable members */
	Boolean		 timestampsCorrectedTx;
	/* dynamic members */
	Boolean		 phaseOffsetTxValid;
	Boolean		 frequencyOffsetTxValid;
	TimeInterval	 phaseOffsetTx;
	Timestamp	 phaseOffsetTxTimesatmp;
	TimeInterval	 frequencyOffsetTx;
	Timestamp	 frequencyOffsetTxTimesatmp;
} L1SyncOptParamsPortDS_t;

/* Add all extension port DS related structure must be store here */
typedef struct  {
	L1SyncBasicPortDS_t      basic;
	L1SyncOptParamsPortDS_t  opt_params;

	/* Non standard variables */
	int execute_state_machine;
}l1e_ext_portDS_t;

static inline l1e_ext_portDS_t *L1E_DSPOR(struct pp_instance *ppi)
{
	return (l1e_ext_portDS_t *) ppi->portDS->ext_dsport;
}

static inline L1SyncBasicPortDS_t *L1E_DSPOR_BS(struct pp_instance *ppi)
{
	return &L1E_DSPOR(ppi)->basic;
}

static inline L1SyncOptParamsPortDS_t *L1E_DSPOR_OP(struct pp_instance *ppi)
{
	return &L1E_DSPOR(ppi)->opt_params;
}


/****************************************************************************************/
/* l1e_servo interface */

/* Prototypes */

uint8_t l1e_creat_L1Sync_bitmask(int tx_coh, int rx_coh, int congru);
void    l1e_servo_enable_tracking(int enable);
int l1e_update_correction_values(struct pp_instance *ppi);
int l1e_run_state_machine(struct pp_instance *ppi, void *buf, int len);

/* All data used as extension ppsi l1sync must be put here */
struct l1e_data {
	wrh_servo_t servo; /* As to be in the first place in this structure */
};

static inline  int l1e_get_rx_tmo_ms(L1SyncBasicPortDS_t * bds) {
	return (4 << (bds->logL1SyncInterval + 8)) * bds->L1SyncReceiptTimeout;
}

extern const struct pp_ext_hooks l1e_ext_hooks;

/* Servo routines */
static inline int l1e_servo_init(struct pp_instance *ppi) {
	return wrh_servo_init(ppi);
}

static inline void l1e_servo_reset(struct pp_instance *ppi) {
	wrh_servo_reset(ppi);
}

static inline int l1e_servo_got_sync(struct pp_instance *ppi) {
	return wrh_servo_got_sync(ppi);
}

static inline int l1e_servo_got_resp(struct pp_instance *ppi) {
	return wrh_servo_got_resp(ppi);
}

static inline int l1e_servo_got_presp(struct pp_instance *ppi) {
	return wrh_servo_got_presp(ppi);
}

#else
#define PROTO_EXT_L1SYNC (0)
#endif /* CONFIG_EXT_L1SYNC == 1 */

#endif /* __L1SYNC_EXT_API_H__ */
