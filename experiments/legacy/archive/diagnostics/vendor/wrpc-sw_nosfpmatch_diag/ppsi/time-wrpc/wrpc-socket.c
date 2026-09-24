/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include "ppsi/ppsi.h"
#include "../tools/ptpdump.h"

#include "../arch-wrpc/wrpc.h"
#include "dev/syscon.h" /* wrpc-sw */
#include "dev/endpoint.h" /* wrpc-sw */
#include "dev/netif.h"
#include "net.h"
#include "board.h"

#ifdef CONFIG_ABSCAL
#define HAS_ABSCAL 1
#else
#define HAS_ABSCAL 0
#endif
/*
 * we know we create one socket only in wrpc. The buffer size used to be
 * 512. Let's keep it unchanged, because we might enqueue a few frames.
 * I think this can be decreased to 256, but I'd better play safe
 */
static DECLARE_WRPC_SOCKET(ptp_socket, 512);

/* This function should init the minic and get the mac address */
static int wrpc_open_ch(struct pp_instance *ppi)
{
	struct wrpc_socket *sock;
	const unsigned char *mac;
	struct wr_sockaddr addr;
	char *macaddr = PP_MCAST_MACADDRESS;
	struct wrc_netif_device *nif = netif_get_device(0);

	if ( is_delayMechanismP2P(ppi) )
		macaddr = PP_PDELAY_MACADDRESS;
	addr.ethertype = htons(ETH_P_1588);
	memcpy(addr.mac, macaddr, sizeof(mac_addr_t));
	sock = ptpd_netif_create_socket
	  (GET_WRPC_SOCKET(ptp_socket), LEN_WRPC_SOCKET(ptp_socket),
	   &addr, PTPD_SOCK_RAW_ETHERNET, 0, nif);
	if (!sock)
		return -1;

	mac = wrc_endpoint_dev.mac_addr;
	memcpy(ppi->ch[PP_NP_EVT].addr, mac, sizeof(mac_addr_t));
	ppi->ch[PP_NP_EVT].custom = sock;
	memcpy(ppi->ch[PP_NP_GEN].addr, mac, sizeof(mac_addr_t));
	ppi->ch[PP_NP_GEN].custom = sock;

	return 0;
}

/* To receive and send packets, we call the minic low-level stuff */
static int wrpc_net_recv(struct pp_instance *ppi, void *pkt, int len,
			 struct pp_time *t)
{
	int got;
	struct wrpc_socket *sock;
	struct wr_timestamp wr_ts;
	struct wr_sockaddr addr;
	sock = ppi->ch[PP_NP_EVT].custom;
	got = ptpd_netif_recvfrom(sock, &addr, pkt, len, &wr_ts);
	if (got <= 0)
		return got;

	if (t) {
		t->secs = wr_ts.sec;
		t->scaled_nsecs = (int64_t)wr_ts.nsec << 16;
		t->scaled_nsecs += wr_ts.phase * (1 << 16) / 1000;
		/* avoid "incorrect" stamps when abscal is running */
		if (!wr_ts.correct
		    && (!HAS_ABSCAL || !wrc_ptp_is_abscal()))
			mark_incorrect(t);
	}
	/* copy MAC and vlan of a peer to ppi */
	memcpy(ppi->peer, &addr.mac, ETH_ALEN);
	ppi->peer_vid = addr.vlan;
/* wrpc-sw may pass this in USER_CFLAGS, to remove footprint */
#ifndef CONFIG_NO_PTPDUMP
	/* The header is separate, so dump payload only */
	if (pp_diag_allow(ppi, frames, 2))
		dump_payloadpkt("recv: ", pkt, got, t);
#endif
	if (HAS_ABSCAL && wrc_ptp_is_abscal()) {
		struct pp_time t4, t_bts;
		int bitslide;

		/* WR counts bitslide later, in fixed-delta, so subtract it */
		t4 = *t;
		bitslide = ep_get_bitslide(&wrc_endpoint_dev);
		t_bts.secs = 0;
		t_bts.scaled_nsecs = (bitslide << 16) / 1000;
		pp_time_sub(&t4, &t_bts);
		pp_printf("%09d %09d %03d",
			  (int)t4.secs, (int)(t4.scaled_nsecs >> 16),
			  ((int)(t4.scaled_nsecs & 0xffff) * 1000) >> 16);
		/* Print the difference from T1, too */
		pp_time_sub(&t4, &ppi->last_snt_time);
		pp_printf("   %9d.%03d\n", (int)(t4.scaled_nsecs >> 16),
			  ((int)(t4.scaled_nsecs & 0xffff) * 1000) >> 16);
	}

	if (CONFIG_HAS_WRPC_FAULTS && ppsi_drop_rx()) {
		pp_diag(ppi, frames, 1, "Drop received frame\n");
		return PP_RECV_DROP;
	}

	if (CONFIG_HAS_WRPC_FAULTS)
		usleep(frame_rx_delay_us);
	return got;
}

static int wrpc_net_send(struct pp_instance *ppi, void *pkt, int len, enum pp_msg_format msg_fmt)
{
	const struct pp_msgtype_info *mf = pp_msgtype_info + msg_fmt;
	int snt, drop;
	struct wrpc_socket *sock;
	struct wr_timestamp wr_ts;
	struct wr_sockaddr addr;
	struct pp_time *t = &ppi->last_snt_time;
	int delay_mechanism = mf->delay_mechanism;
	static const uint8_t macaddr[MECH_MAX_SUPPORTED + 1][ETH_ALEN] = {
		[MECH_E2E] = PP_MCAST_MACADDRESS,
		[MECH_P2P] = PP_PDELAY_MACADDRESS,
	};

	/*
	 * To fake a packet loss, we must corrupt the frame; we need
	 * to transmit it for real, if we want to get back our
	 * hardware stamp. Thus, remember if we drop, and use this info.
	 */
	if (CONFIG_HAS_WRPC_FAULTS)
		drop = ppsi_drop_tx();

	sock = ppi->ch[PP_NP_EVT].custom;

	addr.ethertype = htons(ETH_P_1588);
	memcpy(&addr.mac, macaddr[delay_mechanism], sizeof(mac_addr_t));
	if (CONFIG_HAS_WRPC_FAULTS && drop) {
		addr.ethertype = 1;
		addr.mac[0] = 0x22; /* pfilter uses mac; drop for nodes too */
	}

	snt = ptpd_netif_sendto(sock, &addr, pkt, len, &wr_ts);

	if (t) {
		t->secs = wr_ts.sec;
		t->scaled_nsecs = (int64_t)wr_ts.nsec << 16;
		if (!wr_ts.correct)
			mark_incorrect(t);

		pp_diag(ppi, frames, 2, "%s: snt=%d, sec=%ld, nsec=%ld\n",
			__func__, snt, (long)t->secs,
			(long)(t->scaled_nsecs >> 16));
	}
	if (HAS_ABSCAL && wrc_ptp_is_abscal())
		pp_printf("%09d %09d %03d ", /* first half of a line */
			  (int)t->secs, (int)(t->scaled_nsecs >> 16),
			  ((int)(t->scaled_nsecs & 0xffff) * 1000) >> 16);

	if (CONFIG_HAS_WRPC_FAULTS && drop) {
		pp_diag(ppi, frames, 1, "Drop sent frame\n");
		return PP_SEND_DROP;
	}

/* wrpc-sw may pass this in USER_CFLAGS, to remove footprint */
#ifndef CONFIG_NO_PTPDUMP
	/* The header is separate, so dump payload only */
	if (snt >0 && pp_diag_allow(ppi, frames, 2))
		dump_payloadpkt("send: ", pkt, len, t);
#endif

	return snt;
}

static int wrpc_net_exit(struct pp_instance *ppi)
{
	ptpd_netif_close_socket(ppi->ch[PP_NP_EVT].custom);
	return 0;
}

/* This function must be able to be called twice, and clean-up internally */
static int wrpc_net_init(struct pp_instance *ppi)
{
	if (ppi->ch[PP_NP_EVT].custom)
		wrpc_net_exit(ppi);
	pp_prepare_pointers(ppi);
	wrpc_open_ch(ppi);

	return 0;

}

const struct pp_network_operations wrpc_net_ops = {
	.init = wrpc_net_init,
	.exit = wrpc_net_exit,
	.recv = wrpc_net_recv,
	.send = wrpc_net_send,
};
