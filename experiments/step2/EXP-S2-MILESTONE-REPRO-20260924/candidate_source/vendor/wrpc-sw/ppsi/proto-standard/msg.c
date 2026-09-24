/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "common-fun.h"
#include "msg.h"

/* return 1 if the frame is from the current master, else 0 */
int msg_from_current_master(struct pp_instance *ppi)
{
	MsgHeader *hdr = &ppi->received_ptp_header;
	
	if (!bmc_pidcmp(&DSPAR(ppi)->parentPortIdentity,
			&hdr->sourcePortIdentity))
		return 1;
	else
		return 0;
}

/* Unpack header from in buffer to receieved_ptp_header field */
int msg_unpack_header(struct pp_instance *ppi, void *buf, int len)
{
	MsgHeader *hdr = &ppi->received_ptp_header;
	hdr->transportSpecific = (*(Nibble *) (buf + 0)) >> 4;
	hdr->messageType = (*(Enumeration4 *) (buf + 0)) & 0x0F;
	hdr->versionPTP = (*(UInteger4 *) (buf + 1)) & 0x0F;

	/* force reserved bit to zero if not */
	hdr->messageLength = htons(*(UInteger16 *) (buf + 2));
	hdr->domainNumber = (*(UInteger8 *) (buf + 4));

	memcpy(hdr->flagField, (buf + 6), PP_FLAG_FIELD_LENGTH);

	hdr->cField.secs = 0LL;
	hdr->cField.scaled_nsecs = ntohll(*(uint64_t *)(buf + 8));

	memcpy(&hdr->sourcePortIdentity.clockIdentity, (buf + 20),
	       PP_CLOCK_IDENTITY_LENGTH);
	hdr->sourcePortIdentity.portNumber =
		ntohs(*(UInteger16 *) (buf + 28));
	hdr->sequenceId = ntohs(*(UInteger16 *) (buf + 30));
	hdr->logMessageInterval = (*(Integer8 *) (buf + 33));

	return 0;
}

/* Pack header into output buffer -- only called by state-initializing */
void msg_init_header(struct pp_instance *ppi, void *buf)
{
	memset(buf, 0, 34);
	*(char *)(buf + 1) = DSPOR(ppi)->minorVersionNumber<<4 | (DSPOR(ppi)->versionNumber & 0xF);
	*(char *)(buf + 4) = DSDEF(ppi)->domainNumber;

	memcpy((buf + 20), &DSPOR(ppi)->portIdentity.clockIdentity,
	       PP_CLOCK_IDENTITY_LENGTH);
	*(UInteger16 *)(buf + 28) =
				htons(DSPOR(ppi)->portIdentity.portNumber);
}

/* set the sequence id in the buffer and update the stored one */
void __msg_set_seq_id(struct pp_instance *ppi, const struct pp_msgtype_info *mf) {
	void *buf = ppi->tx_ptp;
	ppi->sent_seq[mf->msg_type]++;
	*(UInteger16 *) (buf + 30) = htons(ppi->sent_seq[mf->msg_type]); /* SequenceId */
}

/* Helper used by all "msg_pack" below */
int __msg_pack_header(struct pp_instance *ppi, const struct pp_msgtype_info *msg_fmt)
{
	void *buf = ppi->tx_ptp;
	int len, log;
	uint16_t *flags16 = buf + 6;
	signed char *logp = buf + 33;

	len = msg_fmt->msglen;
	log = msg_fmt->logMessageInterval;
	*(char *)(buf + 0) = msg_fmt->msg_type;
	*(UInteger16 *) (buf + 2) = htons(len);
	*(uint64_t *)(buf + 8)=0; /* correctionField: default is cleared */
	*flags16 = 0; /* most message types wont 0 here */
	*(UInteger8 *)(buf + 32) = msg_fmt->controlField;
	switch(log) {
	case PP_LOG_ANNOUNCE:
		*logp = DSPOR(ppi)->logAnnounceInterval; break;
	case PP_LOG_SYNC:
		*logp = DSPOR(ppi)->logSyncInterval; break;
	case PP_LOG_REQUEST:
		*logp = DSPOR(ppi)->logMinDelayReqInterval; break;
	default:
		*logp = log; break;
	}
	return len;
}

/* Pack Signaling message into out buffer of ppi */
static int __msg_pack_signaling(struct pp_instance *ppi,enum pp_msg_format msg_fmt, PortIdentity *target_port_identity,
		UInteger16 tlv_type,UInteger16 tlv_length_field)
{
	void *buf = ppi->tx_ptp;
	int len;
	const struct pp_msgtype_info *mf = pp_msgtype_info + msg_fmt;

	if (msg_fmt >=PPM_MSG_FMT_MAX)
		return 0;

	len = __msg_pack_header(ppi, mf);
	__msg_set_seq_id(ppi,mf);

	/* Set target port identity */
	*(ClockIdentity *) (buf + 34) = target_port_identity->clockIdentity;
	*(UInteger16 *) (buf + 42) = target_port_identity->portNumber;

	*(UInteger16 *) (buf + 44) = htons(tlv_type); /* TLV type*/
	*(UInteger16 *)(buf + 46)  = htons(tlv_length_field); /* TLV length field */
	return len;
}

/* Pack Signaling message into out buffer of ppi */
int msg_pack_signaling(struct pp_instance *ppi,PortIdentity *target_port_identity,
		UInteger16 tlv_type,UInteger16 tlv_length_field) {
	return __msg_pack_signaling(ppi,PPM_SIGNALING_FMT,target_port_identity,tlv_type,tlv_length_field);
}

/* Pack Signaling message into out buffer of ppi */
int msg_pack_signaling_no_fowardable(struct pp_instance *ppi,PortIdentity *target_port_identity,
		UInteger16 tlv_type,UInteger16 tlv_length_field) {
	return __msg_pack_signaling(ppi,PPM_SIGNALING_NO_FWD_FMT,target_port_identity,tlv_type,tlv_length_field);
}
/* Unpack signaling message from in buffer */
void msg_unpack_signaling(void *buf, MsgSignaling *signaling)
{
	signaling->targetPortIdentity.clockIdentity= *(ClockIdentity *) (buf + 34);
	signaling->targetPortIdentity.portNumber= *(UInteger16 *) (buf + 42);
	signaling->tlv=buf + 44;
}

void __pack_origin_timestamp(void *buf ,struct pp_time *orig_tstamp) {
	*(UInteger16 *)(buf + 34) = htons(orig_tstamp->secs >> 32);
	*(UInteger32 *)(buf + 36) = htonl(orig_tstamp->secs);
	*(UInteger32 *)(buf + 40) = htonl(orig_tstamp->scaled_nsecs >> 16);
}

void __unpack_origin_timestamp(void *buf ,struct pp_time *orig_tstamp) {
	orig_tstamp->secs  = (((int64_t)ntohs(*(UInteger16 *) (buf + 34)))<<32) |
			             ntohl(*(UInteger32 *) (buf + 36));
	orig_tstamp->scaled_nsecs = ((uint64_t)ntohl(*(UInteger32 *) (buf + 40)))<< 16;
}

/* Pack Sync message into out buffer of ppi */
int msg_pack_sync(struct pp_instance *ppi, struct pp_time *orig_tstamp)
{
	void *buf = ppi->tx_ptp;
	UInteger8 *flags8 = buf + 6;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_SYNC_FMT;
	int len= __msg_pack_header(ppi, mf);

	/* Header */
	flags8[0] = PP_TWO_STEP_FLAG; /* Table 20 */
	__msg_set_seq_id(ppi,mf);

	/* Sync message */
	memset((buf + 34), 0, 10);

	/* Adjust time stamp */
	pp_time_add_interval(orig_tstamp,ppi->timestampCorrectionPortDS.egressLatency);
	__pack_origin_timestamp(buf,orig_tstamp);
	return len;
}

/* Unpack Sync message from in buffer */
void msg_unpack_sync(void *buf, MsgSync *sync)
{
	/* The cField is added in the caller according to 1-step vs. 2-step */
	__unpack_origin_timestamp(buf,&sync->originTimestamp);
}

/*
 * Setup flags for an announce message.
 * Set byte 1 of flags taking it from timepropertiesDS' flags field,
 * see 13.3.2.6, Table 20
 */
static void msg_set_announce_flags(struct pp_instance *ppi, UInteger8 *flags)
{
	timePropertiesDS_t *prop = DSPRO(ppi);
	const Boolean *ptrs[] = {
		&prop->leap61,
		&prop->leap59,
		&prop->currentUtcOffsetValid,
		&prop->ptpTimescale,
		&prop->timeTraceable,
		&prop->frequencyTraceable,
	};
	int i;

	/*
	 * alternate master always false, twoStepFlag false in announce,
	 * unicastFlag always false, other flags always false
	 */
	flags[0] = 0;
	for (flags[1] = 0, i = 0; i < ARRAY_SIZE(ptrs); i++)
		if (*ptrs[i])
			flags[1] |= (1 << i);
}

/* Pack Announce message into out buffer of ppi */
static int msg_pack_announce(struct pp_instance *ppi)
{
	void *buf = ppi->tx_ptp;
	UInteger8 *flags8 = buf + 6;;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_ANNOUNCE_FMT;
	int len= __msg_pack_header(ppi, mf);

	/* Header */
	__msg_set_seq_id(ppi,mf);
	msg_set_announce_flags(ppi, flags8);

	/* Announce message */
	memset((buf + 34), 0, 30);
	*(Integer16 *) (buf + 44) = htons(DSPRO(ppi)->currentUtcOffset);
	*(UInteger8 *) (buf + 47) = DSPAR(ppi)->grandmasterPriority1;
	*(UInteger8 *) (buf + 48) = DSPAR(ppi)->grandmasterClockQuality.clockClass;
	*(Enumeration8 *) (buf + 49) = DSPAR(ppi)->grandmasterClockQuality.clockAccuracy;
	*(UInteger16 *) (buf + 50) =
		htons(DSPAR(ppi)->grandmasterClockQuality.offsetScaledLogVariance);
	*(UInteger8 *) (buf + 52) = DSPAR(ppi)->grandmasterPriority2;
	memcpy((buf + 53), &DSPAR(ppi)->grandmasterIdentity,
	       PP_CLOCK_IDENTITY_LENGTH);
	/* WORKAROUND 16bit casting doesn't seem to work on unaligned addresses */
	*(UInteger8 *) (buf + 61) = (UInteger8)(DSCUR(ppi)->stepsRemoved >> 8);
	*(UInteger8 *) (buf + 62) = (UInteger8)DSCUR(ppi)->stepsRemoved;
	*(Enumeration8 *) (buf + 63) = DSPRO(ppi)->timeSource;

	if (is_ext_hook_available(ppi,pack_announce))
		len = ppi->ext_hooks->pack_announce(ppi);
	return len;
}

/* Unpack Announce message from in buffer of ppi to internal structure */
void msg_unpack_announce(struct pp_instance *ppi, void *buf, MsgAnnounce *ann)
{
	__unpack_origin_timestamp(buf,&ann->originTimestamp);
	ann->currentUtcOffset = ntohs(*(UInteger16 *) (buf + 44));
	ann->grandmasterPriority1 = *(UInteger8 *) (buf + 47);
	ann->grandmasterClockQuality.clockClass =
		*(UInteger8 *) (buf + 48);
	ann->grandmasterClockQuality.clockAccuracy =
		*(Enumeration8 *) (buf + 49);
	ann->grandmasterClockQuality.offsetScaledLogVariance =
		ntohs(*(UInteger16 *) (buf + 50));
	ann->grandmasterPriority2 = *(UInteger8 *) (buf + 52);
	memcpy(&ann->grandmasterIdentity, (buf + 53),
	       PP_CLOCK_IDENTITY_LENGTH);
	/* WORKAROUND htons doesn't seem to work on unaligned addresses */
	ann->stepsRemoved = *(UInteger8 *)(buf + 61);
	ann->stepsRemoved = (ann->stepsRemoved << 8) + *(UInteger8 *)(buf + 62);
	ann->timeSource = *(Enumeration8 *) (buf + 63);
	bzero(ann->ext_specific,sizeof(ann->ext_specific));

	/* this can fill in extention specific flags otherwise just zero them*/
	if (is_ext_hook_available(ppi,unpack_announce))
		ppi->ext_hooks->unpack_announce(ppi,buf, ann);
}

/* Pack Follow Up message into out buffer of ppi*/
static int msg_pack_follow_up(struct pp_instance *ppi,
			       struct pp_time *prec_orig_tstamp)
{
	void *buf = ppi->tx_ptp;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_FOLLOW_UP_FMT;
	int len= __msg_pack_header(ppi, mf);

	/* Header */
	/* Clause 9.5.10: The value of the sequenceId field of the Follow_Up message
	 * shall be the value of the sequenceId field of the associated Sync message.
	 */
	*(UInteger16 *) (buf + 30) = htons(ppi->sent_seq[PPM_SYNC]);

	/* Follow Up message */
	__pack_origin_timestamp(buf,prec_orig_tstamp);
	/* Fractional part in cField */
	*(UInteger64 *)(buf + 8) =
		htonll(prec_orig_tstamp->scaled_nsecs & 0xffff);
	return len;
}

/* Unpack FollowUp message from in buffer of ppi to internal structure */
void msg_unpack_follow_up(void *buf, MsgFollowUp *flwup)
{

	__unpack_origin_timestamp(buf,&flwup->preciseOriginTimestamp);
	/* cField added by the caller, from already-converted header */
}

/* pack DelayReq message into out buffer of ppi */
static int msg_pack_delay_req(struct pp_instance *ppi,
			       struct pp_time *now)
{
	void *buf = ppi->tx_ptp;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_DELAY_REQ_FMT;
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

	/* Delay_req message - we may send zero instead */
	memset((buf + 34), 0, 10);
	/* Adjust time stamp */
	pp_time_add_interval(now,ppi->timestampCorrectionPortDS.egressLatency);
	__pack_origin_timestamp(buf,now);
	return len;
}

/* pack DelayResp message into OUT buffer of ppi */
static int msg_pack_delay_resp(struct pp_instance *ppi,
			 MsgHeader *hdr, struct pp_time *rcv_tstamp)
{
	void *buf = ppi->tx_ptp;
	const struct pp_msgtype_info *mf = pp_msgtype_info + PPM_DELAY_RESP_FMT;
	int len= __msg_pack_header(ppi, mf);
	Integer64 correction_field, sub_ns;

	/* Header */
	sub_ns=rcv_tstamp->scaled_nsecs & 0xffff;
	correction_field=is_ext_hook_available(ppi,is_correction_field_compliant) &&
			!ppi->ext_hooks->is_correction_field_compliant(ppi) ?
					sub_ns : /* None compliant CF */
					pp_time_to_interval(&hdr->cField)-sub_ns; /* Set rxCF-sub_ns */
	*(Integer64 *) (buf + 8) =  htonll(correction_field);
	*(UInteger16 *) (buf + 30) = htons(hdr->sequenceId);

	/* Delay_resp message */
	__pack_origin_timestamp(buf,rcv_tstamp);

	memcpy((buf + 44), &hdr->sourcePortIdentity.clockIdentity,
		  PP_CLOCK_IDENTITY_LENGTH);
	*(UInteger16 *) (buf + 52) =
		htons(hdr->sourcePortIdentity.portNumber);
	return len;
}

/* Unpack delayReq message from in buffer of ppi to internal structure */
void msg_unpack_delay_req(void *buf, MsgDelayReq *delay_req)
{
	__unpack_origin_timestamp(buf,&delay_req->originTimestamp);
}

/* Unpack delayResp message from IN buffer of ppi to internal structure */
void msg_unpack_delay_resp(void *buf, MsgDelayResp *resp)
{
	__unpack_origin_timestamp(buf,&resp->receiveTimestamp);
	/* cfield added in the caller */

	memcpy(&resp->requestingPortIdentity.clockIdentity,
	       (buf + 44), PP_CLOCK_IDENTITY_LENGTH);
	resp->requestingPortIdentity.portNumber =
		ntohs(*(UInteger16 *) (buf + 52));
}

/* Pack and send on general multicast ip adress an Announce message */
int msg_issue_announce(struct pp_instance *ppi)
{
	int len = msg_pack_announce(ppi);

	return __send_and_log(ppi, len, PP_NP_GEN,PPM_ANNOUNCE_FMT);
}

/* Pack and send on event multicast ip adress a Sync message */
int msg_issue_sync_followup(struct pp_instance *ppi)
{
	struct pp_time now;
	int e, len;

	/* Send sync on the event channel with the "current" timestamp */
	TOPS(ppi)->get(ppi, &now);
	len = msg_pack_sync(ppi, &now);
	e = __send_and_log(ppi, len, PP_NP_EVT,PPM_SYNC_FMT);
	if (e) return e;

	/* Send followup on general channel with sent-stamp of sync */
	len = msg_pack_follow_up(ppi, &ppi->last_snt_time);
	return __send_and_log(ppi, len, PP_NP_GEN,PPM_FOLLOW_UP_FMT);
}


/* Pack and send on event multicast ip adress a DelayReq message */
static int msg_issue_delay_req(struct pp_instance *ppi)
{
	struct pp_time now;
	int len;

	TOPS(ppi)->get(ppi, &now);
	len = msg_pack_delay_req(ppi, &now);

	return __send_and_log(ppi, len, PP_NP_EVT,PPM_DELAY_REQ_FMT);
}

int msg_issue_request(struct pp_instance *ppi)
{
	if ( is_delayMechanismP2P(ppi) )
		return msg_issue_pdelay_req(ppi);
	return msg_issue_delay_req(ppi);
}

/* Pack and send on event multicast ip adress a DelayResp message */
int msg_issue_delay_resp(struct pp_instance *ppi, struct pp_time *t)
{
	int len;

	len = msg_pack_delay_resp(ppi, &ppi->received_ptp_header, t);
	return __send_and_log(ppi, len, PP_NP_GEN,PPM_DELAY_RESP_FMT);
}

