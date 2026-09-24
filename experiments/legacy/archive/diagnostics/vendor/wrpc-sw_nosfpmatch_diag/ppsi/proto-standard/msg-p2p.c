/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

#if CONFIG_HAS_P2P

#include "common-fun.h"
#include "msg.h"

/* Pack PDelay Follow Up message into out buffer of ppi*/
static int msg_pack_pdelay_resp_follow_up(struct pp_instance *ppi,
					  MsgHeader * hdr,
					  struct pp_time *prec_orig_tstamp)
{
	void *buf = ppi->tx_ptp;
	int len;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_PDELAY_R_FUP_FMT;

	len= __msg_pack_header(ppi, mf);

	/* Header */
	*(UInteger8 *) (buf + 4) = hdr->domainNumber; /* FIXME: why? */
	/* We should copy the correction field and add our fractional part */
	hdr->cField.scaled_nsecs
		+= prec_orig_tstamp->scaled_nsecs & 0xffff;
	normalize_pp_time(&hdr->cField);
	*(Integer64 *) (buf + 8) = htonll(hdr->cField.scaled_nsecs);

	*(UInteger16 *) (buf + 30) = htons(hdr->sequenceId);

	/* requestReceiptTimestamp */
	__pack_origin_timestamp(buf,prec_orig_tstamp);

	/* requestingPortIdentity */
	memcpy((buf + 44), &hdr->sourcePortIdentity.clockIdentity,
	       PP_CLOCK_IDENTITY_LENGTH);
	*(UInteger16 *) (buf + 52) = htons(hdr->sourcePortIdentity.portNumber);
	return len;
}

/* Unpack PDelayRespFollowUp message from in buffer of ppi to internal struct */
void msg_unpack_pdelay_resp_follow_up(void *buf,
				      MsgPDelayRespFollowUp * pdelay_resp_flwup)
{
	__unpack_origin_timestamp(buf,&pdelay_resp_flwup->responseOriginTimestamp);
	/* cField added by the caller, as it's already converted */

	memcpy(&pdelay_resp_flwup->requestingPortIdentity.clockIdentity,
	       (buf + 44), PP_CLOCK_IDENTITY_LENGTH);
	pdelay_resp_flwup->requestingPortIdentity.portNumber =
	    ntohs(*(UInteger16 *) (buf + 52));
}

/* pack DelayReq message into out buffer of ppi */
static int msg_pack_pdelay_req(struct pp_instance *ppi,
				struct pp_time *now)
{
	void *buf = ppi->tx_ptp;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_PDELAY_REQ_FMT;
	int len= __msg_pack_header(ppi, mf);
	Integer64 correction_field;

	/* Header */
	__msg_set_seq_id(ppi,mf);

	correction_field=
			is_ext_hook_available(ppi,is_correction_field_compliant) &&
			!ppi->ext_hooks->is_correction_field_compliant(ppi) ?
					0 :
					-ppi->portDS->delayAsymmetry; /* Set -delayAsymmetry in CF */
	*(Integer64 *) (buf + 8) =  htonll(correction_field);

	/* PDelay_req message - we may send zero instead */
	__pack_origin_timestamp(buf,now);
	memset((buf + 44), 0, 10);
	return len;
}

/* pack PDelayResp message into OUT buffer of ppi */
static int msg_pack_pdelay_resp(struct pp_instance *ppi,
			  MsgHeader * hdr, struct pp_time *rcv_tstamp)
{
	void *buf = ppi->tx_ptp;
	UInteger8 *flags8 = buf + 6;;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_PDELAY_RESP_FMT;
	int len= __msg_pack_header(ppi, mf);
	Integer64 correction_field, sub_ns;

	/* Header */
	sub_ns=rcv_tstamp->scaled_nsecs & 0xffff;
	correction_field=is_ext_hook_available(ppi,is_correction_field_compliant) &&
			!ppi->ext_hooks->is_correction_field_compliant(ppi) ?
					sub_ns : /* None compliant CF */
					pp_time_to_interval(&hdr->cField)-sub_ns; /* Set rxCF-sub_ns */
	*(Integer64 *) (buf + 8) =  htonll(correction_field);
	flags8[0] = PP_TWO_STEP_FLAG; /* Table 20) */
	*(UInteger16 *) (buf + 30) = htons(hdr->sequenceId);

	/* requestReceiptTimestamp */
	__pack_origin_timestamp(buf,rcv_tstamp);

	/* requestingPortIdentity */
	memcpy((buf + 44), &hdr->sourcePortIdentity.clockIdentity,
	       PP_CLOCK_IDENTITY_LENGTH);
	*(UInteger16 *) (buf + 52) = htons(hdr->sourcePortIdentity.portNumber);
	return len;
}

/* Unpack PDelayReq message from in buffer of ppi to internal structure */
void msg_unpack_pdelay_req(void *buf, MsgPDelayReq * pdelay_req)
{
	__unpack_origin_timestamp(buf,&pdelay_req->originTimestamp);
}

/* Unpack PDelayResp message from IN buffer of ppi to internal structure */
void msg_unpack_pdelay_resp(void *buf, MsgPDelayResp * presp)
{
	__unpack_origin_timestamp(buf,&presp->requestReceiptTimestamp);
	/* cfield added in the caller */

	memcpy(&presp->requestingPortIdentity.clockIdentity,
	       (buf + 44), PP_CLOCK_IDENTITY_LENGTH);
	presp->requestingPortIdentity.portNumber =
	    ntohs(*(UInteger16 *) (buf + 52));
}

/* Pack and send on general multicast ip address a FollowUp message */
int msg_issue_pdelay_resp_followup(struct pp_instance *ppi, struct pp_time *t)
{
	int len;

	len = msg_pack_pdelay_resp_follow_up(ppi, &ppi->received_ptp_header, t);
	return __send_and_log(ppi, len, PP_NP_GEN,PPM_PDELAY_R_FUP_FMT);
}

/* Pack and send on event multicast ip adress a PDelayReq message */
int msg_issue_pdelay_req(struct pp_instance *ppi)
{
	struct pp_time now;
	int len;

	mark_incorrect(&ppi->t4); /* see commit message */
	TOPS(ppi)->get(ppi, &now);
	ppi->received_dresp=
			ppi->received_dresp_fup=0;
	len = msg_pack_pdelay_req(ppi, &now);
	return __send_and_log(ppi, len, PP_NP_EVT,PPM_PDELAY_REQ_FMT);
}

/* Pack and send on event multicast ip adress a DelayResp message */
int msg_issue_pdelay_resp(struct pp_instance *ppi, struct pp_time *t)
{
	int len;

	len = msg_pack_pdelay_resp(ppi, &ppi->received_ptp_header, t);
	return __send_and_log(ppi, len, PP_NP_EVT,PPM_PDELAY_RESP_FMT);
}


#endif
