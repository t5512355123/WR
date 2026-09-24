/*
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "l1e-constants.h"

#define MSG_OFFSET_HEADER 0u
#define MSG_OFFSET_HEADER_MESSAGE_LENGTH (MSG_OFFSET_HEADER+2u)
#define MSG_OFFSET_HEADER_CONTROL_FIELD (MSG_OFFSET_HEADER+32u)
#define MSG_OFFSET_TARGET_PORT_IDENTITY 34u
#define MSG_OFFSET_TARGET_PORT_IDENTITY_CLOCK_IDENTITY (MSG_OFFSET_TARGET_PORT_IDENTITY+0u)
#define MSG_OFFSET_TARGET_PORT_IDENTITY_PORT_NUMBER    (MSG_OFFSET_TARGET_PORT_IDENTITY+8u)

#define MSG_OFFSET_TLV    44u
#define MSG_OFFSET_TLV_TYPE               (MSG_OFFSET_TLV  )
#define MSG_OFFSET_TLV_LENGTH_FIELD       (MSG_OFFSET_TLV+2u)
#define MSG_OFFSET_TLV_L1SYNC_PEER_CONF   (MSG_OFFSET_TLV+4u)
#define MSG_OFFSET_TLV_L1SYNC_PEER_ACTIVE (MSG_OFFSET_TLV+5u)
#define MSG_OFFSET_TLV_L1SYNC_OPT_CONFIG                    (MSG_OFFSET_TLV+6u)
#define MSG_OFFSET_TLV_L1SYNC_OPT_PHASE_OFFSET_TX           (MSG_OFFSET_TLV+7u)
#define MSG_OFFSET_TLV_L1SYNC_OPT_PHASE_OFFSET_TX_TIMESTAMP (MSG_OFFSET_TLV+15u)
#define MSG_OFFSET_TLV_L1SYNC_OPT_FREQ_OFFSET_TX            (MSG_OFFSET_TLV+25u)
#define MSG_OFFSET_TLV_L1SYNC_OPT_FREQ_OFFSET_TX_TIMESTAMP  (MSG_OFFSET_TLV+33u)
#define MSG_OFFSET_TLV_L1SYNC_OPT_RESERVED                  (MSG_OFFSET_TLV+43u)


#define MSG_OFFSET_HEADER_TYPE (MSG_OFFSET_HEADER+0)

#define MSG_TYPE_SIGNALING 0xC


#define MSG_GET_16(buf,off) (*(UInteger16 *)((buf)+(off)))
#define MSG_GET_8(buf,off ) *(UInteger8 *)((buf)+(off))

#define MSG_GET_TLV_TYPE(buf)               ntohs((uint16_t)(MSG_GET_16(buf,MSG_OFFSET_TLV_TYPE)))
#define MSG_GET_TLV_LENGTH_FIELD(buf)       ntohs((uint16_t)(MSG_GET_16(buf,MSG_OFFSET_TLV_LENGTH_FIELD)))
#define MSG_GET_TLV_L1SYNC_PEER_CONF(buf)   MSG_GET_8(buf,MSG_OFFSET_TLV_L1SYNC_PEER_CONF)
#define MSG_GET_TLV_L1SYNC_PEER_ACTIVE(buf) MSG_GET_8(buf,MSG_OFFSET_TLV_L1SYNC_PEER_ACTIVE)


#define MSG_SET_HEADER_MESSAGE_LENGTH(buf,val)  	 MSG_GET_16(buf,MSG_OFFSET_HEADER_MESSAGE_LENGTH) = (UInteger16)htons((uint16_t)(val))
#define MSG_SET_TLV_LENGTH_FIELD(buf,val)            MSG_GET_16(buf,MSG_OFFSET_TLV_LENGTH_FIELD)=(UInteger16)htons((uint16_t)(val))
#define MSG_SET_TLV_L1SYNC_PEER_CONF(buf,val)        MSG_GET_8(buf,MSG_OFFSET_TLV_L1SYNC_PEER_CONF)= (UInteger8)(val)
#define MSG_SET_TLV_L1SYNC_PEER_ACTIVE(buf,val)      MSG_GET_8(buf,MSG_OFFSET_TLV_L1SYNC_PEER_ACTIVE)=(UInteger8)(val)

#define MSG_SET_TLV_L1SYNC_OPT_CONFIG(buf,val)       MSG_GET_8(buf,MSG_OFFSET_TLV_L1SYNC_OPT_CONFIG)=(UInteger8)(val)

#define MSG_L1SYNC_LEN 50u
#define MSG_L1SYNC_TLV_LENGTH 2u
#define MSG_L1SYNC_TLV_EXTENDED_LENGTH 40u

static void l1e_print_L1Sync_basic_bitmaps(struct pp_instance *ppi,
					   uint8_t configed,
					   uint8_t active, char* text)
{
	pp_diag(ppi, ext, 3, "ML: L1Sync %s\n", text);
	pp_diag(ppi, ext, 3, "ML: \tConfig: TxC=%d RxC=%d Cong=%d Param=%d\n",
		  ((configed & L1E_TX_COHERENT) == L1E_TX_COHERENT),
		  ((configed & L1E_RX_COHERENT) == L1E_RX_COHERENT),
		  ((configed & L1E_CONGRUENT)   == L1E_CONGRUENT),
		  ((configed & L1E_OPT_PARAMS)  == L1E_OPT_PARAMS));
	pp_diag(ppi, ext, 3, "ML: \tActive: TxC=%d RxC=%d Cong=%d\n",
		  ((active & L1E_TX_COHERENT)   == L1E_TX_COHERENT),
		  ((active & L1E_RX_COHERENT)   == L1E_RX_COHERENT),
		  ((active & L1E_CONGRUENT)     == L1E_CONGRUENT));
}

int l1e_pack_signal(struct pp_instance *ppi)
{
	void *buf=ppi->tx_ptp;
	PortIdentity targetPortIdentity;
	uint8_t local_config, local_active;
	L1SyncBasicPortDS_t * bds=L1E_DSPOR_BS(ppi);
	UInteger16 msgLen=MSG_L1SYNC_LEN; /* Length of a message with a basic L1SYNC TLV */

	memset(&targetPortIdentity,-1,sizeof(targetPortIdentity)); /* cloclk identity and port set all 1's */
	/* Generic pack of a signaling message */
	msg_pack_signaling_no_fowardable(ppi,&targetPortIdentity,TLV_TYPE_L1_SYNC,MSG_L1SYNC_TLV_LENGTH);

	/* Clause O.6.4 */
	local_config = l1e_creat_L1Sync_bitmask(bds->txCoherentIsRequired,
			bds->rxCoherentIsRequired,
			bds->congruentIsRequired);
	if(bds->optParamsEnabled)
		  local_config |= L1E_OPT_PARAMS;

	local_active = l1e_creat_L1Sync_bitmask(bds->isTxCoherent,
			bds->isRxCoherent,
			bds->isCongruent);
	MSG_SET_TLV_L1SYNC_PEER_CONF(buf,local_config);
	MSG_SET_TLV_L1SYNC_PEER_ACTIVE(buf,local_active);

	l1e_print_L1Sync_basic_bitmaps(ppi, local_config,local_active, "Sent");

	if ( bds->optParamsEnabled ) {
		/* Extended format of L1_SYNC TLV */
		L1SyncOptParamsPortDS_t * ods=L1E_DSPOR_OP(ppi);

		local_config= (ods->timestampsCorrectedTx? (uint8_t)1 : (uint8_t)0) |
				(ods->phaseOffsetTxValid ? (uint8_t)2 : (uint8_t)0 ) |
				(ods->frequencyOffsetTxValid ? (uint8_t)4 : (uint8_t)0 );
		MSG_SET_TLV_L1SYNC_OPT_CONFIG(buf,local_config);
		msgLen+=38;
		MSG_SET_TLV_LENGTH_FIELD(buf,MSG_L1SYNC_TLV_EXTENDED_LENGTH);
		/* TODO : The extension fields must be filled with L1SyncOptParamsPortDS_t data set */
	}
	/* header len */
	MSG_SET_HEADER_MESSAGE_LENGTH(buf,msgLen);

	return msgLen;
}

int l1e_unpack_signal(struct pp_instance *ppi, void *buf, int plen)
{
	L1SyncBasicPortDS_t * basicDS=L1E_DSPOR_BS(ppi);
	int l1sync_peer_conf, l1sync_peer_acti;

	if (MSG_GET_TLV_TYPE(buf) != TLV_TYPE_L1_SYNC) {
		pp_diag(ppi, ext, 1, "Not L1Sync TLV, ignore\n");
		return -1;
	}
	if ( MSG_GET_TLV_LENGTH_FIELD(buf) != 2 || plen != MSG_L1SYNC_LEN) {
		pp_diag(ppi, ext, 1, "L1Sync TLV wrong length, ignore\n");
		return -1;
	}
	l1sync_peer_conf = MSG_GET_TLV_L1SYNC_PEER_CONF(buf);
	l1sync_peer_acti = MSG_GET_TLV_L1SYNC_PEER_ACTIVE(buf);

	l1e_print_L1Sync_basic_bitmaps(ppi, l1sync_peer_conf,l1sync_peer_acti, "Received");

	basicDS->peerTxCoherentIsRequired = (l1sync_peer_conf & L1E_TX_COHERENT) == L1E_TX_COHERENT;
	basicDS->peerRxCoherentIsRequired = (l1sync_peer_conf & L1E_RX_COHERENT) == L1E_RX_COHERENT;
	basicDS->peerCongruentIsRequired  = (l1sync_peer_conf & L1E_CONGRUENT)   == L1E_CONGRUENT;

	basicDS->peerIsTxCoherent     = (l1sync_peer_acti & L1E_TX_COHERENT) == L1E_TX_COHERENT;
	basicDS->peerIsRxCoherent     = (l1sync_peer_acti & L1E_RX_COHERENT) == L1E_RX_COHERENT;
	basicDS->peerIsCongruent      = (l1sync_peer_acti & L1E_CONGRUENT)   == L1E_CONGRUENT;

	return 0;
}
