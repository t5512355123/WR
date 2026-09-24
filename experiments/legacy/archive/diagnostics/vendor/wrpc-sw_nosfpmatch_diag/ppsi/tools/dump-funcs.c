/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdio.h>
#include <string.h>
#include "ptpdump.h"
#include <ppsi/ieee1588_types.h> /* from ../include */
#include "decent_types.h"
#include <ppsi/lib.h>
#include "../proto-ext-whiterabbit/wr-constants.h"
#include "../proto-ext-l1sync/l1e-constants.h"

#define WR_MODE_ON_MASK 0x8
#define CALIBRATED_MASK 0x4
#define WR_CONFIG_MASK 0x3

static int dump_vlan(char *prefix, int vlan);

static int dumpstruct(char *p1, char *p2, char *name, void *ptr, int size)
{
	int ret, i;
	unsigned char *p = ptr;

	ret = printf("%s%s%s (size %i)\n", p1, p2, name, size);
	for (i = 0; i < size; ) {
		if ((i & 0xf) == 0)
			ret += printf("%s%s", p1, p2);
		ret += printf("%02x", p[i]);
		i++;
		ret += printf(i & 3 ? " " : i & 0xf ? "  " : "\n");
	}
	if (i & 0xf)
		ret += printf("\n");
	return ret;
}

#if __STDC_HOSTED__
static void dump_time(char *prefix, const struct pp_time *t)
{
	struct timeval tv;
	struct tm tm;

	tv.tv_sec = t->secs;
	tv.tv_usec = (t->scaled_nsecs >> 16) / 1000;
	localtime_r(&tv.tv_sec, &tm);
	printf("%sTIME: (%li - 0x%lx) %02i:%02i:%02i.%06li%s\n", prefix,
	       tv.tv_sec, tv.tv_sec,
	       tm.tm_hour, tm.tm_min, tm.tm_sec, (long)tv.tv_usec,
	       is_incorrect(t) ? " invalid" : "");
}
#else
static void dump_time(char *prefix, const struct pp_time *t)
{
	printf("%sTIME: (%li - 0x%lx) %li.%06li%s\n", prefix,
	       (long)t->secs, (long)t->secs, (long)t->secs,
	       (long)(t->scaled_nsecs >> 16) / 1000,
	       is_incorrect(t) ? " invalid" : "");
}
#endif

/* Returns the header size, used by the caller to adjust the next pointer */
static int dump_eth(char *prefix, struct ethhdr *eth)
{
	unsigned char *d = eth->h_dest;
	unsigned char *s = eth->h_source;
	int proto = ntohs(eth->h_proto);
	int ret;
	char mac_s[20];
	char mac_d[20];

	/* Between eth header and payload may be a VLAN tag;
	 * NOTE: We cannot distinguish between both cases looking at
	 * the content of a vlan variable, because vlan number may come from
	 * frame itself or from the socket (CMSG) */
	if (proto == 0x8100) {
		ret = sizeof(struct pp_vlanhdr); /* ETH header + VLAN tag */
		/* Get the proto knowing that there is a VLAN tag */
		proto = ntohs(((struct pp_vlanhdr *)eth)->h_proto);
	} else
		ret = sizeof(struct ethhdr);

	printf("%sETH: %04x (%s -> %s)\n", prefix, proto,
	       format_mac(mac_s, s),
	       format_mac(mac_d, d));
	return ret;
}

static void dump_ip(char *prefix, struct iphdr *ip)
{
	unsigned int s = ntohl(ip->saddr);
	unsigned int d = ntohl(ip->daddr);
	printf("%sIP: %i (%i.%i.%i.%i -> %i.%i.%i.%i) len %i\n", prefix,
	       ip->protocol,
	       (s >> 24) & 0xff, (s >> 16) & 0xff, (s >> 8) & 0xff, s & 0xff,
	       (d >> 24) & 0xff, (d >> 16) & 0xff, (d >> 8) & 0xff, d & 0xff,
	       ntohs(ip->tot_len));
}

static void dump_udp(char *prefix, struct udphdr *udp)
{
	printf("%sUDP: (%i -> %i) len %i\n", prefix,
	       ntohs(udp->source), ntohs(udp->dest), ntohs(udp->len));
}

/* Helpers for fucking data structures */
static void dump_1stamp(char *prefix, char *s, struct stamp *t)
{
	uint64_t  sec = (uint64_t)(ntohs(t->sec.msb)) << 32;

	sec |= (uint64_t)(ntohl(t->sec.lsb));
	printf("%s%s%lu.%09i\n", prefix,
	       s, (unsigned long)sec, (int)ntohl(t->nsec));
}

static void dump_1quality(char *prefix, char *s, ClockQuality *q)
{
	printf("%s%s%02x-%02x-%04x\n", prefix, s, (unsigned int) q->clockClass,
			(unsigned int) q->clockAccuracy, (unsigned int) q->offsetScaledLogVariance);
}

static void dump_1clockid(char *prefix, char *s, ClockIdentity i)
{
	printf("%s%s%02x-%02x-%02x-%02x-%02x-%02x-%02x-%02x\n", prefix, s,
	       i.id[0], i.id[1], i.id[2], i.id[3],
	       i.id[4], i.id[5], i.id[6], i.id[7]);
}

static void dump_1port(char *prefix, char *s, unsigned char *p)
{
	printf("%s%s%02x-%02x-%02x-%02x-%02x-%02x-%02x-%02x-%02x-%02x\n",
	       prefix, s,
	       p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9]);
}


/* Helpers for each message types */
static void dump_msg_announce(char *prefix, struct ptp_announce *p)
{
	ClockQuality	grandmasterClockQuality;

	memcpy( &grandmasterClockQuality,&p->grandmasterClockQuality, sizeof(ClockQuality));
	grandmasterClockQuality.offsetScaledLogVariance=ntohs(grandmasterClockQuality.offsetScaledLogVariance);

	dump_1stamp(prefix, "MSG-ANNOUNCE: stamp ",
		    &p->originTimestamp);
	dump_1quality(prefix, "MSG-ANNOUNCE: grandmaster-quality ",
		      &grandmasterClockQuality);
	printf("%sMSG-ANNOUNCE: grandmaster-prio %i %i\n", prefix,
	       p->grandmasterPriority1, p->grandmasterPriority2);
	dump_1clockid(prefix, "MSG-ANNOUNCE: grandmaster-id ",
		      p->grandmasterIdentity);
}

static void dump_msg_sync_etc(char *prefix, char *s, struct ptp_sync_etc *p)
{
	dump_1stamp(prefix, s, &p->stamp);
}

static void dump_msg_resp_etc(char *prefix, char *s, struct ptp_sync_etc *p)
{
	dump_1stamp(prefix, s, &p->stamp);
	dump_1port(prefix, s, p->port);
}

/* TLV dumper, now white-rabbit aware */
static int wr_dump_tlv(char *prefix, struct ptp_tlv *tlv, int totallen)
{
	/* the field includes 6 bytes of the header, ecludes 4 of them. Bah! */
	int explen = ntohs(tlv->len) + 4;

#ifdef CONFIG_PROFILE_WR
	{
		static char *wr_message_name[] = {
		    "SLAVE_PRESENT",
		    "LOCK",
		    "LOCKED",
		    "CALIBRATE",
		    "CALIBRATED",
		    "WR_MODE_ON",
		};
		uint16_t messageId;
		char *messageId_str = NULL;

		if (ntohs(tlv->type) != TLV_TYPE_ORG_EXTENSION
		    || memcmp(tlv->oui, "\x08\x00\x30", 3) /* WR_TLV_ORGANIZATION_ID */
		    /* WR_TLV_MAGIC_NUMBER, WR_TLV_WR_VERSION_NUMBER */
		    || memcmp(tlv->subtype, "\xDE\xAD\x01", 3)
		    ) {
			return 0;
		}
	
		printf("%sTLV: type %04x len %i oui %02x:%02x:%02x "
			   "sub %02x:%02x:%02x\n", prefix, ntohs(tlv->type), explen,
			   tlv->oui[0], tlv->oui[1], tlv->oui[2],
			   tlv->subtype[0], tlv->subtype[1], tlv->subtype[2]);
		if (explen > totallen) {
			printf("%sTLV: too short (expected %i, total %i)\n", prefix,
				   explen, totallen);
			return totallen;
		}


		messageId = (tlv->data[0] << 8) + tlv->data[1];
		if (SLAVE_PRESENT <= messageId && messageId <= WR_MODE_ON)
			messageId_str = wr_message_name[messageId - SLAVE_PRESENT];
		if (messageId == ANN_SUFIX)
			messageId_str = "ANN_SUFIX";
	
		if (messageId_str) {
			printf("%sTLV: messageId %s(0x%x)\n", prefix, messageId_str,
				   messageId);
			switch(messageId){
			case SLAVE_PRESENT:
			case LOCK:
			case LOCKED:
			case WR_MODE_ON:
				/* no more to be printed */
				break;
			case CALIBRATE:
				if (totallen < 8 || explen < 8) { /* 2+1+1+4 */
					printf("%sTLV: too short (expected %i, total "
						   "%i)\n", prefix, explen, totallen);
					return totallen;
				}
				printf("%sTLV: calSendPattern %s, calRetry %u, "
					   "calPeriod %d\n",
					   prefix,
					   tlv->data[2] ? "True":"False",
					   tlv->data[3],
					   (tlv->data[4] << 24) + (tlv->data[5] << 16)
					   + (tlv->data[6] << 8) + tlv->data[7]
					   );
				break;
			case CALIBRATED:
				/* TODO: print as ints */
				if (totallen < 18 || explen < 18) { /* 2+8+8 */
					printf("%sTLV: too short (expected %i, total "
						   "%i)\n", prefix, explen, totallen);
					return totallen;
				}
				dumpstruct(prefix, "TLV: ", "deltaTx", &tlv->data[2],
					   8);
				dumpstruct(prefix, "TLV: ", "deltaRx", &tlv->data[10],
					   8);
				break;
			case ANN_SUFIX:
				{
				int flags = tlv->data[3]; /* data[2] is unused */
				char *wr_config_str;
				if (totallen < 4 || explen < 4) { /* 2+2 */
					printf("%sTLV: too short (expected %i, total "
						   "%i)\n", prefix, explen, totallen);
					return totallen;
				}
				switch (flags & WR_CONFIG_MASK) {
				case NON_WR:
					wr_config_str = "NON_WR";
					break;
				case WR_S_ONLY:
					wr_config_str = "WR_S_ONLY";
					break;
				case WR_M_ONLY:
					wr_config_str = "WR_M_ONLY";
					break;
				case WR_M_AND_S:
					wr_config_str = "WR_M_AND_S";
					break;
				default:
					wr_config_str="";
					break;
				}
				printf("%sTLV: wrFlags: wrConfig %s, calibrated %s, "
					   "wrModeOn %s\n",
					   prefix,
					   wr_config_str,
					   flags & CALIBRATED_MASK ? "True":"False",
					   flags & WR_MODE_ON_MASK ? "True":"False"
					   );
				break;
				}
			}
		}
		return explen;
	}
#else
	return 0;
#endif

}

static int l1sync_dump_tlv(char *prefix, struct l1sync_tlv *tlv, int totallen)
{
	int explen = ntohs(tlv->len) + 4;

	if ( CONFIG_HAS_EXT_L1SYNC ) {
		if (ntohs(tlv->type) != TLV_TYPE_L1_SYNC) {
			/* Non L1Sync TLV */
			return 0;
		}

		printf("%sTLV: type %04x len %i conf %02x act %02x\n",
				prefix,
				ntohs(tlv->type), explen,
				(int) tlv->config,
				(int) tlv->active);
		if (explen > totallen) {
			printf("%sTLV: too short (expected %i, total %i)\n", prefix,
				   explen, totallen);
			return totallen;
		}

		/* Now dump non-l1sync tlv in binary, count only payload */
		if (ntohs(tlv->len) > explen - sizeof(*tlv))
			dumpstruct(prefix, "TLV: ", "tlv-content",
				   tlv->data, explen - sizeof(*tlv));
		return explen;
	} else
		return 0;
}

/* Dump unknown TLV */
static int unknown_dump_tlv(char *prefix, struct ptp_tlv *tlv, int totallen)
{
	int tlv_len = ntohs(tlv->len);
	int explen = tlv_len + 4;

	printf("%sTLV: Unknown, type %04x len %i\n",
	       prefix,
	       ntohs(tlv->type), tlv_len);

	if (explen > totallen) {
		printf("%sTLV: too short (expected %i, total %i)\n", prefix,
			    explen, totallen);
		return totallen;
	}

	/* Now dump non-wr tlv in binary, count only payload */
	if (tlv_len > explen - sizeof(*tlv))
		dumpstruct(prefix, "TLV: ", "tlv-content",
			   tlv->data, explen - sizeof(*tlv));

	return tlv_len + 4;
}

/* A big function to dump the ptp information */
static void dump_payload(char *prefix, void *pl, int len)
{
	struct ptp_header *h = pl;
	void *msg_specific = (void *)(h + 1);
	int donelen = 34; /* packet length before tlv */
	int version = h->versionPTP_and_reserved & 0xf;
	int messageType = h->type_and_transport_specific & 0xf;
	char *cfptr = (void *)&h->correctionField;

	if (version != 2) {
		printf("%sVERSION: unsupported (%i)\n", prefix, version);
		goto out;
	}
	printf("%sVERSION: %i (type %i, len %i, domain %i)\n", prefix,
	       version, messageType,
	       ntohs(h->messageLength), h->domainNumber);
	printf("%sFLAGS: 0x%02x%02x (correction 0x%08x:%08x %08u)\n",
	       prefix, (unsigned) h->flagField[0],(unsigned) h->flagField[1],
	       ntohl(*(int *)cfptr),
	       ntohl(*(int *)(cfptr + 4)),
	       ntohl(*(int *)(cfptr + 4)));
	dump_1port(prefix, "PORT: ", h->sourcePortIdentity);
	printf("%sREST: seq %i, ctrl %i, log-interval %i\n", prefix,
	       ntohs(h->sequenceId), h->controlField, h->logMessageInterval);
#define CASE(t, x) case PPM_ ##x: printf("%sMESSAGE: (" #t ") " #x "\n", prefix)
	switch(messageType) {
		CASE(E, SYNC);
		dump_msg_sync_etc(prefix, "MSG-SYNC: ", msg_specific);
		donelen = 44;
		break;

		CASE(E, DELAY_REQ);
		dump_msg_sync_etc(prefix, "MSG-DELAY_REQ: ", msg_specific);
		donelen = 44;
		break;

		CASE(G, FOLLOW_UP);
		dump_msg_sync_etc(prefix, "MSG-FOLLOW_UP: ", msg_specific);
		donelen = 44;
		break;

		CASE(G, DELAY_RESP);
		dump_msg_resp_etc(prefix, "MSG-DELAY_RESP: ", msg_specific);
		donelen = 54;
		break;

		CASE(G, ANNOUNCE);
		dump_msg_announce(prefix, msg_specific);
		donelen = 64;
		break;

		CASE(G, SIGNALING);
		dump_1port(prefix, "MSG-SIGNALING: target-port ", msg_specific);
		donelen = 44;
		break;

#if __STDC_HOSTED__ /* Avoid pdelay dump within ppsi, we don't use it */
		CASE(E, PDELAY_REQ);
		dump_msg_sync_etc(prefix, "MSG-PDELAY_REQ: ", msg_specific);
		donelen = 54;
		break;

		CASE(E, PDELAY_RESP);
		dump_msg_resp_etc(prefix, "MSG-PDELAY_RESP: ", msg_specific);
		donelen = 54;
		break;

		CASE(G, PDELAY_R_FUP);
		dump_msg_resp_etc(prefix, "MSG-PDELAY_RESP_FOLLOWUP: ",
				  msg_specific);
		donelen = 54;
		break;

		CASE(G, MANAGEMENT);
		/* FIXME */
		break;
#endif
	}

	/*
	 * Dump any trailing TLV, but ignore a trailing 2-long data hunk.
	 * The trailing zeroes appear with less-than-minimum Eth messages.
	 */

	while (donelen < len && len - donelen > 2) {
		int n = len - donelen;
		int ret;

		switch ( messageType) {
		case PPM_ANNOUNCE :
			if ((ret = wr_dump_tlv(prefix, pl + donelen, n))) {
				donelen += ret;
			} else {
				donelen += unknown_dump_tlv(prefix, pl + donelen, n);
			}
			break;
		case PPM_SIGNALING :
			if ((ret = l1sync_dump_tlv(prefix, pl + donelen, n))) {
				donelen += ret;
			} else if ((ret = wr_dump_tlv(prefix, pl + donelen, n))) {
				donelen += ret;
			} else {
				/* Unknown TLV */
				donelen += unknown_dump_tlv(prefix, pl + donelen, n);
			}
			break;
		default :
			goto out;
		}
	}
out:
	/* Finally, binary dump of it all */
	dumpstruct(prefix, "DUMP: ", "payload", pl, len);
}

/* This dumps a complete udp frame, starting from the eth header */
int dump_udppkt(char *prefix, void *buf, int len, const struct pp_time *t,
		int vlan)
{
	struct ethhdr *eth = buf;
	struct iphdr *ip;
	struct udphdr *udp;
	void *payload;

	if (t)
		dump_time(prefix, t);

	dump_vlan(prefix, vlan);

	ip = buf + dump_eth(prefix, eth);
	dump_ip(prefix, ip);

	udp = (void *)(ip + 1);
	dump_udp(prefix, udp);

	payload = (void *)(udp + 1);
	dump_payload(prefix, payload, len - (payload - buf));

	return 0;
}

/* This dumps the payload only, used for udp frames without headers */
int dump_payloadpkt(char *prefix, void *buf, int len, const struct pp_time *t)
{
	if (t)
		dump_time(prefix, t);
	dump_payload(prefix, buf, len);
	return 0;
}

/* This dumps everything, used for raw frames with headers and ptp payload */
int dump_1588pkt(char *prefix, void *buf, int len, const struct pp_time *t,
		 int vlan)
{
	struct ethhdr *eth = buf;
	void *payload;

	if (t)
		dump_time(prefix, t);
	dump_vlan(prefix, vlan);
	payload = buf + dump_eth(prefix, eth);
	dump_payload(prefix, payload, len - (payload - buf));

	return 0;
}

static int dump_vlan(char *prefix, int vlan)
{
	if (vlan >= 0)
		printf("%sVLAN %i\n", prefix, vlan);

	return 0;
}
