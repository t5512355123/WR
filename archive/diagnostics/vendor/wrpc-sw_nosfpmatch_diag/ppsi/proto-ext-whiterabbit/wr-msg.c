
/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on ptp-noposix project (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "../proto-standard/common-fun.h"

/* Pack White rabbit message in the suffix of PTP announce message */
void msg_pack_announce_wr_tlv(struct pp_instance *ppi)
{
	void *buf;
	UInteger16 wr_flags;
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	buf = ppi->tx_ptp;

	/* Change length */
	*(UInteger16 *)(buf + 2) = htons(WR_ANNOUNCE_LENGTH);

	*(UInteger16 *)(buf + 64) = htons(TLV_TYPE_ORG_EXTENSION);
	*(UInteger16 *)(buf + 66) = htons(WR_ANNOUNCE_TLV_LENGTH);
	/* CERN's OUI: WR_TLV_ORGANIZATION_ID, how to flip bits? */
	*(UInteger16 *)(buf + 68) = htons((WR_TLV_ORGANIZATION_ID >> 8));
	*(UInteger16 *)(buf + 70) = htons((0xFFFF & (WR_TLV_ORGANIZATION_ID << 8
		| WR_TLV_MAGIC_NUMBER >> 8)));
	*(UInteger16 *)(buf + 72) = htons((0xFFFF & (WR_TLV_MAGIC_NUMBER << 8
		| WR_TLV_WR_VERSION_NUMBER)));
	/* wrMessageId */
	*(UInteger16 *)(buf + 74) = htons(ANN_SUFIX);

	wr_flags = wrp->wrConfig;
	if (wrp->calibrated)
		wr_flags |= WR_IS_CALIBRATED;

	if (wrp->wrModeOn)
		wr_flags |= WR_IS_WR_MODE;
	*(UInteger16 *)(buf + 76) = htons(wr_flags);
}

void msg_unpack_announce_wr_tlv(void *buf, MsgAnnounce *ann, UInteger16 *wrFlags)
{
	UInteger16 tlv_type;
	UInteger32 tlv_organizationID;
	UInteger16 tlv_magicNumber;
	UInteger16 tlv_versionNumber;
	UInteger16 tlv_wrMessageID;

	tlv_type = ntohs(*(UInteger16 *)(buf + 64));
	tlv_organizationID = ntohs(*(UInteger16 *)(buf+68)) << 8;
	tlv_organizationID = ntohs(*(UInteger16 *)(buf+70)) >> 8
		| tlv_organizationID;
	tlv_magicNumber = 0xFF00 & (ntohs(*(UInteger16 *)(buf+70)) << 8);
	tlv_magicNumber = ntohs(*(UInteger16 *)(buf+72)) >> 8
		| tlv_magicNumber;
	tlv_versionNumber = 0xFF & ntohs(*(UInteger16 *)(buf+72));
	tlv_wrMessageID = ntohs(*(UInteger16 *)(buf+74));

	if (tlv_type == TLV_TYPE_ORG_EXTENSION &&
		tlv_organizationID == WR_TLV_ORGANIZATION_ID &&
		tlv_magicNumber == WR_TLV_MAGIC_NUMBER &&
		tlv_versionNumber == WR_TLV_WR_VERSION_NUMBER &&
		tlv_wrMessageID == ANN_SUFIX) {
		*wrFlags= ntohs(*(UInteger16 *)(buf + 76));
	} else
		*wrFlags = 0;
}

/* White Rabbit: packing WR Signaling messages*/
int msg_pack_wrsig(struct pp_instance *ppi, Enumeration16 wr_msg_id)
{
	void *buf;
	UInteger16 len = 0;
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	buf = ppi->tx_ptp;

	/* Changes in header */
	*(char *)(buf+0) = *(char *)(buf+0) & 0xF0; /* RAZ messageType */
	*(char *)(buf+0) = *(char *)(buf+0) | 0x0C; /* Table 19 -> signaling */

	*(UInteger8 *)(buf+32) = 0x05; //Table 23 -> all other
	*(char *)(buf+33) = 0x7F; /* logMessageInterval for Signaling
				   * (Table 24) */

	/* target portIdentity */
	memcpy((buf+34), &DSPAR(ppi)->parentPortIdentity.clockIdentity,
		PP_CLOCK_IDENTITY_LENGTH);
	*(UInteger16 *)(buf + 42) =
			    htons(DSPAR(ppi)->parentPortIdentity.portNumber);

	/* WR TLV */
	*(UInteger16 *)(buf+44) = htons(TLV_TYPE_ORG_EXTENSION);
	/* leave lenght free */
	*(UInteger16 *)(buf+48) = htons((WR_TLV_ORGANIZATION_ID >> 8));
	*(UInteger16 *)(buf+50) = htons((0xFFFF &
		(WR_TLV_ORGANIZATION_ID << 8 | WR_TLV_MAGIC_NUMBER >> 8)));
	*(UInteger16 *)(buf+52) = htons((0xFFFF &
		(WR_TLV_MAGIC_NUMBER    << 8 | WR_TLV_WR_VERSION_NUMBER)));
	/* wrMessageId */
	*(UInteger16 *)(buf+54) = htons(wr_msg_id);

	switch (wr_msg_id) {
	case CALIBRATE:
		if (wrp->calibrated) {
			*(UInteger16 *)(buf + 56) =
				    htons(WR_DSPOR(ppi)->calRetry | 0x0000);
		} else {
			*(UInteger16 *)(buf + 56) =
				    htons(WR_DSPOR(ppi)->calRetry | 0x0100);
		}

		/* calPeriod in a frame crosses a word boundary,
		   split it into two parts */
		*(UInteger16 *)(buf + 58) =
				    htonl(WR_DSPOR(ppi)->calPeriod) & 0xFFFF;
		*(UInteger16 *)(buf + 60) =
				    htonl(WR_DSPOR(ppi)->calPeriod) >> 16;
		len = 14;
		break;

	case CALIBRATED:
		/* delta TX */
		*(UInteger32 *)(buf + 56) =
				    htonl(wrp->deltaTx.scaledPicoseconds.msb);
		*(UInteger32 *)(buf + 60) =
				    htonl(wrp->deltaTx.scaledPicoseconds.lsb);

		/* delta RX */
		*(UInteger32 *)(buf + 64) =
				    htonl(wrp->deltaRx.scaledPicoseconds.msb);
		*(UInteger32 *)(buf + 68) =
				    htonl(wrp->deltaRx.scaledPicoseconds.lsb);
		len = 24;
		break;

	default:
		/* only WR TLV "header" and wrMessageID */
		len = 8;
		break;
	}
	/* header len */
	*(UInteger16 *)(buf + 2) = htons(WR_SIGNALING_MSG_BASE_LENGTH + len);

	/* TLV len */
	*(Integer16 *)(buf+46) = htons(len);

	/* FIXME diagnostic */
	return WR_SIGNALING_MSG_BASE_LENGTH + len;
}

/* White Rabbit: unpacking wr signaling messages */
/* Returns 1 if WR message */
int msg_unpack_wrsig(struct pp_instance *ppi, void *buf,
		      MsgSignaling *wrsig_msg, Enumeration16 *pwr_msg_id)
{
	UInteger16 tlv_type;
	UInteger32 tlv_organizationID;
	UInteger16 tlv_magicNumber;
	UInteger16 tlv_versionNumber;
	Enumeration16 wr_msg_id;
	struct wr_dsport *wrp = WR_DSPOR(ppi);

	memcpy(&wrsig_msg->targetPortIdentity.clockIdentity, (buf + 34),
	       PP_CLOCK_IDENTITY_LENGTH);
	wrsig_msg->targetPortIdentity.portNumber =
					    ntohs(*(UInteger16 *)(buf + 42));

	tlv_type           = ntohs(*(UInteger16 *)(buf + 44));
	tlv_organizationID = ntohs(*(UInteger16 *)(buf + 48)) << 8;
	tlv_organizationID = ntohs(*(UInteger16 *)(buf + 50)) >> 8
				| tlv_organizationID;
	tlv_magicNumber = 0xFF00 & (ntohs(*(UInteger16 *)(buf + 50)) << 8);
	tlv_magicNumber = ntohs(*(UInteger16 *)(buf + 52)) >>  8
				| tlv_magicNumber;
	tlv_versionNumber = 0xFF & ntohs(*(UInteger16 *)(buf + 52));

	if (tlv_type != TLV_TYPE_ORG_EXTENSION) {
		/* "handle Signaling msg, failed, not organization extension TLV = 0x%x\n" */
		pp_diag(ppi, frames, 1, "%sorganization extension TLV = 0x%x\n",
			"handle Signaling msg, failed, not ", tlv_type);
		return 0;
	}

	if (tlv_organizationID != WR_TLV_ORGANIZATION_ID) {
		/* "handle Signaling msg, failed, not CERN's OUI = 0x%x\n" */
		pp_diag(ppi, frames, 1, "%sCERN's OUI = 0x%x\n",
			"handle Signaling msg, failed, not ", tlv_organizationID);
		return 0;
	}

	if (tlv_magicNumber != WR_TLV_MAGIC_NUMBER) {
		/* "handle Signaling msg, failed, not White Rabbit magic number = 0x%x\n" */
		pp_diag(ppi, frames, 1, "%sWhite Rabbit magic number = 0x%x\n",
			"handle Signaling msg, failed, not ", tlv_magicNumber);
		return 0;
	}

	if (tlv_versionNumber  != WR_TLV_WR_VERSION_NUMBER ) {
		/* "handle Signaling msg, failed, not supported version number = 0x%x\n" */
		pp_diag(ppi, frames, 1, "%ssupported version number = 0x%x\n",
			"handle Signaling msg, failed, not ", tlv_versionNumber);
		return 0;
	}

	wr_msg_id = ntohs(*(UInteger16 *)(buf + 54));

	if (pwr_msg_id) {
		*pwr_msg_id = wr_msg_id;
	}

	switch (wr_msg_id) {
	case CALIBRATE:
		wrp->otherNodeCalSendPattern =
			0x00FF & (ntohs(*(UInteger16 *)(buf + 56)) >> 8);
		wrp->otherNodeCalRetry =
			0x00FF & ntohs(*(UInteger16 *)(buf + 56));

		/* OtherNodeCalPeriod in a frame crosses a word boundary,
		   split it into two parts */
		WR_DSPOR(ppi)->otherNodeCalPeriod =
					    ntohs(*(UInteger16 *)(buf + 60));
		WR_DSPOR(ppi)->otherNodeCalPeriod <<= 16;
		WR_DSPOR(ppi)->otherNodeCalPeriod |=
					    ntohs(*(UInteger16 *)(buf + 58));

		pp_diag(ppi, frames, 1, "otherNodeCalPeriod 0x%x\n",
			WR_DSPOR(ppi)->otherNodeCalPeriod);

		break;

	case CALIBRATED:
		/* delta TX */
		wrp->otherNodeDeltaTx.scaledPicoseconds.msb =
					    ntohl(*(UInteger32 *)(buf + 56));
		wrp->otherNodeDeltaTx.scaledPicoseconds.lsb =
					    ntohl(*(UInteger32 *)(buf + 60));

		/* delta RX */
		wrp->otherNodeDeltaRx.scaledPicoseconds.msb =
					    ntohl(*(UInteger32 *)(buf + 64));
		wrp->otherNodeDeltaRx.scaledPicoseconds.lsb =
					    ntohl(*(UInteger32 *)(buf + 68));
		break;

	default:
		/* no data */
		break;
	}
	if ( ppi->pdstate==PP_PDSTATE_PDETECTION)
		pdstate_set_state_pdetected(ppi);
	return 1;
}

/* Pack and send a White Rabbit signalling message */
int msg_issue_wrsig(struct pp_instance *ppi, Enumeration16 wr_msg_id)
{
	int len = msg_pack_wrsig(ppi, wr_msg_id);

	return __send_and_log(ppi, len, PP_NP_GEN,PPM_SIGNALING_FMT);
}
