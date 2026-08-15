/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <netinet/if_ether.h>
#include <net/if_arp.h>
#include <net/if.h>
#include <linux/net_tstamp.h>
#include <linux/sockios.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <asm/types.h>
#include <fcntl.h>
#include <errno.h>

#include <ptpdump.h>

#include <ppsi-wrs.h>
#include <hal_exports.h>

#define ETHER_MTU 1518
#define DMTD_UPDATE_INTERVAL 500
#define PACKED __attribute__((packed))

struct scm_timestamping {
	struct timespec systime;
	struct timespec hwtimetrans;
	struct timespec hwtimeraw;
};

PACKED struct etherpacket {
	struct ethhdr ether;
	char data[ETHER_MTU];
};

typedef struct
{
	uint64_t start_tics;
	uint64_t timeout;
} _timeout_t ;

struct wrs_socket {
	/* parameters for linearization of RX timestamps */
	uint32_t clock_period;
	uint32_t phase_transition;
	uint32_t dmtd_phase;
	int dmtd_phase_valid;
	_timeout_t dmtd_update_tmo;
};

static uint64_t get_tics(void)
{
	struct timezone tz = {0, 0};
	struct timeval tv;
	gettimeofday(&tv, &tz);

	return (uint64_t) tv.tv_sec * 1000000ULL + (uint64_t) tv.tv_usec;
}

static inline int tmo_init(_timeout_t *tmo, uint32_t milliseconds)
{
	tmo->start_tics = get_tics();
	tmo->timeout = (uint64_t) milliseconds * 1000ULL;
	return 0;
}

static inline int tmo_restart(_timeout_t *tmo)
{
	tmo->start_tics = get_tics();
	return 0;
}

static inline int tmo_expired(_timeout_t *tmo)
{
	return (get_tics() - tmo->start_tics > tmo->timeout);
}

/* checks if x is inside range <min, max> */
static inline int inside_range(int min, int max, int x)
{
	if(min < max)
		return (x>=min && x<=max);
	else
		return (x<=max || x>=min);
}

static char *fmt_time(struct pp_time *t)
{
	static char buf[64];
	sprintf(buf, "(correct %i) %9lli.%09li",
		!is_incorrect(t), (long long)t->secs,
		(long)(t->scaled_nsecs >> 16));
	return buf;
}

static void update_dmtd(struct wrs_socket *s, struct pp_instance *ppi)
{
	struct hal_port_state *p;

	if (tmo_expired(&s->dmtd_update_tmo))
	{
		p = pp_wrs_lookup_port(ppi->iface_name);
		if (!p)
			return;
		s->dmtd_phase = p->phase_val;
		s->dmtd_phase_valid = p->phase_val_valid;

		tmo_restart(&s->dmtd_update_tmo);
	}
}

/*
 * Note: it looks like transition_point is always zero.
 * Also, all calculations are ps here, but the timestamp is scaled_ns
 *       -- ARub 2016-10
 */
static void wrs_linearize_rx_timestamp(struct pp_time *ts,
	int32_t dmtd_phase, int cntr_ahead, int transition_point,
	int clock_period)
{
	int phase, raw_phase;
	int nsec_f, nsec_r;
	int nsec;

	pp_diag(NULL, ext, 3, "linearize  ts %s and phase %i\n",
		fmt_time(ts), dmtd_phase);
	pp_diag(NULL, ext, 3, "    (ahead %i tpoint %i, period %i\n",
		cntr_ahead, transition_point, clock_period);

	raw_phase = dmtd_phase;
	pp_diag(NULL, ext, 3, "    phase now %i\n", raw_phase);

	nsec = ts->scaled_nsecs >> 16;
	pp_diag(NULL, ext, 3, "NEW nsec=%d, phase=%d\n", nsec, raw_phase);

/* The idea is simple: the asynchronous RX timestamp trigger is tagged
 * by two counters: one counting at the rising clock edge, and the
 * other on the falling. That means, the rising timestamp is 180
 * degree in advance wrs to the falling one.
 */

/* Calculate the nanoseconds value for both timestamps. The rising edge one
   is just the HW register */
	nsec_r = nsec;
/* The falling edge TS is the rising - 1 thick
    if the "rising counter ahead" bit is set. */
	nsec_f = cntr_ahead ? nsec - (clock_period / 1000) : nsec;

/* Adjust the rising edge timestamp phase so that it "jumps" roughly
   around the point where the counter value changes */
	int phase_r = raw_phase - transition_point;
	if(phase_r < 0) /* unwrap negative value */
		phase_r += clock_period;

/* Do the same with the phase for the falling edge, but additionally shift
   it by extra 180 degrees (so that it matches the falling edge counter) */
	int phase_f = raw_phase - transition_point + (clock_period / 2);
	if(phase_f < 0)
		phase_f += clock_period;
	if(phase_f >= clock_period)
		phase_f -= clock_period;

/* If we are within +- 25% from the transition in the rising edge counter,
   pick the falling one */
	if( phase_r > 3 * clock_period / 4 || phase_r < clock_period / 4 ) {
		nsec = nsec_f;

		/* The falling edge timestamp is half a cycle later
		   with respect to the rising one. Add
		   the extra delay, as rising edge is our reference */
		phase = phase_f + clock_period / 2;
		if(phase >= clock_period) /* Handle overflow */
		{
			phase -= clock_period;
			nsec += (clock_period / 1000);
		}
		pp_diag(NULL, ext, 3, "    ts pick falling (nsec:%d phase:%d)\n", nsec, phase);
	} else { /* We are closer to the falling edge counter transition?
		    Pick the opposite timestamp */
		nsec  = nsec_r;
		phase = phase_r;
		pp_diag(NULL, ext, 3, "    ts pick rising (nsec:%d phase:%d)\n", nsec, phase);
	}

	/* In an unlikely case, after all the calculations,
	   the ns counter may be overflown. */
	if(nsec >= 1000000000)
	{
		nsec -= 1000000000;
		ts->secs++;
	}
	ts->scaled_nsecs = (int64_t)nsec << 16;
	ts->scaled_nsecs += ((int64_t)phase << 16) / 1000LL;
	pp_diag(NULL, ext, 3, "    ts final  %s\n", fmt_time(ts));
}


static int wrs_recv_msg(struct pp_instance *ppi, int fd, void *pkt, int len,
			struct pp_time *t)
{
	struct ethhdr *hdr = pkt;
	struct wrs_socket *s;
	struct msghdr msg;
	struct iovec entry;
	struct sockaddr_ll from_addr;
	int i;
	union {
		struct cmsghdr cm;
		char aux_buf[CMSG_SPACE(sizeof(struct tpacket_auxdata))];
		char time_buf[1024];
	} control;
	struct cmsghdr *cmsg;
	struct scm_timestamping *sts = NULL;
	struct tpacket_auxdata *aux = NULL;

	s = (struct wrs_socket*)ppi->ch[PP_NP_GEN].arch_chan_data;

	memset(&msg, 0, sizeof(msg));
	msg.msg_iov = &entry;
	msg.msg_iovlen = 1;
	entry.iov_base = pkt;
	entry.iov_len = len;
	msg.msg_name = (caddr_t)&from_addr;
	msg.msg_namelen = sizeof(from_addr);
	msg.msg_control = &control;
	msg.msg_controllen = sizeof(control);

	int ret = recvmsg(fd, &msg, MSG_DONTWAIT);

	if (ret < 0 && errno == EAGAIN) return 0; // would be blocking

	if (ret == -EAGAIN) return 0;

	if (ret <= 0) return ret;

	/* FIXME Check ptp-noposix, commit d34f56f: if sender mac check
	 * is required. Should be added here */

	for (cmsg = CMSG_FIRSTHDR(&msg);
	     cmsg;
	     cmsg = CMSG_NXTHDR(&msg, cmsg)) {

		void *dp = CMSG_DATA(cmsg);

		if(cmsg->cmsg_level == SOL_SOCKET
		   && cmsg->cmsg_type == SO_TIMESTAMPING)
			sts = (struct scm_timestamping *)dp;

		if (cmsg->cmsg_level == SOL_PACKET &&
		    cmsg->cmsg_type == PACKET_AUXDATA)
			aux = (struct tpacket_auxdata *)dp;
	}

	if ( t ) {
		if (sts) {
			int cntr_ahead = sts->hwtimeraw.tv_sec & 0x80000000 ? 1: 0;
			t->scaled_nsecs = (long long)sts->hwtimeraw.tv_nsec << 16;
			t->secs = sts->hwtimeraw.tv_sec & 0x7fffffff;

			update_dmtd(s, ppi);
			if ( ppi->ext_hooks->require_precise_timestamp!=NULL  &&
					(*ppi->ext_hooks->require_precise_timestamp)(ppi)) {
				/* Precise time stamp required */
				if (s->dmtd_phase_valid) {
					wrs_linearize_rx_timestamp(t, s->dmtd_phase,
						cntr_ahead, s->phase_transition, s->clock_period);
				} else {
					mark_incorrect(t);
				}
			}
		} else {
			mark_incorrect(t);
		}
	}

	/* For UDP, avoid all of the following, as we don't have vlans */
	if (ppi->proto == PPSI_PROTO_UDP)
		goto out;

	/*
	 * Ethernet driver returns internal frame. Our simple WR driver used to
	 * return the whole frame, but not anymore. Use aux pointer to get VLAN
	 */
	if (aux) {
		int vlan = aux->tp_vlan_tci & 0xfff;

		/* With PROTO_VLAN, we bound to ETH_P_ALL: we got all frames */
		if (hdr->h_proto != htons(ETH_P_1588))
			return PP_RECV_DROP; /* no error message */

		/* Also, we got the vlan, and we can discard it if not ours */
		for (i = 0; i < ppi->nvlans; i++)
			if (ppi->vlans[i] == vlan)
				break; /* ok */
		if (i == ppi->nvlans)
			return PP_RECV_DROP; /* not ours: say it's dropped */
		ppi->peer_vid = ppi->vlans[i];
	} else {
		if (hdr->h_proto != htons(ETH_P_1588))
			return PP_RECV_DROP; /* again: drop unrelated frames */
		ppi->peer_vid = 0;
	}

out:
	if (ppsi_drop_rx()) {
		pp_diag(ppi, frames, 1, "Drop received frame\n");
		return PP_RECV_DROP;
	}

	return ret;
}

static int wrs_net_recv(struct pp_instance *ppi, void *pkt, int len,
			struct pp_time *t)
{
	struct pp_channel *ch1, *ch2;
	struct ethhdr *hdr = pkt;
	int ret = -1;
	char prefix[32];

	if (pp_diag_allow(ppi, frames, 2) || pp_diag_allow(ppi, time, 1) )
		sprintf(prefix,"recv-%s: ",(ppi ? ppi->port_name: "ppsi"));

	switch(ppi->proto) {
	case PPSI_PROTO_RAW:
	case PPSI_PROTO_VLAN:
		ch2 = ppi->ch + PP_NP_GEN;

		ret = wrs_recv_msg(ppi, ch2->fd, pkt, len, t);
		if (ret <= 0)
			return ret;
		memcpy(ppi->peer, hdr->h_source, ETH_ALEN);
		if (pp_diag_allow(ppi, frames, 2)) {
			if (ppi->proto == PPSI_PROTO_VLAN)
				pp_printf("%sVLAN %i\n",prefix, ppi->peer_vid);
			dump_1588pkt(prefix, pkt, ret, t, -1);
		}
		break;

	case PPSI_PROTO_UDP:
		/* UDP: always handle EVT msgs before GEN */
		ch1 = &(ppi->ch[PP_NP_EVT]);
		ch2 = &(ppi->ch[PP_NP_GEN]);

		if (ch1->pkt_present)
			ret = wrs_recv_msg(ppi, ch1->fd, pkt, len, t);
		else if (ch2->pkt_present)
			ret = wrs_recv_msg(ppi, ch2->fd, pkt, len, t);
		if (ret < 0)
			break;
		if (pp_diag_allow(ppi, frames, 2))
			dump_payloadpkt(prefix, pkt, ret, t);
		break;

	default:
		return -1;
	}

	if (ret < 0)
		return ret;
	pp_diag(ppi, time, 1, "%sstamp: %s\n", prefix, fmt_time(t));
	return ret;
}

/* Waits for the transmission timestamp and stores it in t (if not null). */
static void poll_tx_timestamp(struct pp_instance *ppi, void *pkt, int len,
			      struct wrs_socket *s, int fd, struct pp_time *t)
{
	char data[16384], *dataptr;
	struct msghdr msg;
	struct iovec entry;
	struct sockaddr_ll from_addr;
	struct {
		struct cmsghdr cm;
		char control[1024];
	} control;
	struct cmsghdr *cmsg;
	struct pollfd pfd;
	int res, retry;

	struct sock_extended_err *serr = NULL;
	struct scm_timestamping *sts = NULL;

	memset(&msg, 0, sizeof(msg));
	msg.msg_iov = &entry;
	msg.msg_iovlen = 1;
	entry.iov_base = data;
	entry.iov_len = sizeof(data);
	msg.msg_name = (caddr_t)&from_addr;
	msg.msg_namelen = sizeof(from_addr);
	msg.msg_control = &control;
	msg.msg_controllen = sizeof(control);

	if (t) /* poison the stamp */
		mark_incorrect(t);

	pfd.fd = fd;
	pfd.events = POLLERR;

	#define N_RETRY 3
	for (retry = 0; retry < N_RETRY; retry++) {
		errno = 0;
		res = poll(&pfd, 1, 2 /* ms */);
		if (res < 0 && errno != EAGAIN) {
			pp_diag(ppi, time, 1, "%s: poll() = %i (%s)\n",
				__func__, res, strerror(errno));
			continue;
		}
		if (res < 1)
			continue;

		res = recvmsg(fd, &msg, MSG_ERRQUEUE);
		if (res <= 0) {
			/* sometimes we got EAGAIN despite poll() = 1 */
			pp_diag(ppi, time, 1, "%s: recvmsg() = %i (%s)\n",
				__func__, res, strerror(errno));
			continue;
		}
		/*
		 * Now, check if this frame is our frame. If not, retry.
		 * Note: for UDP we get back a raw frame. So check trailing
		 * part only (we know it's 14 + 20 + 8 to skip, but we'd
		 * better not rely on that -- think vlans for example
		 */
		dataptr = data + res - len;
		if (dataptr >= data && !memcmp(dataptr, pkt, len))
			break;
		pp_diag(ppi, time, 1, "%s: recvmsg(): not our frame\n",
			__func__);
	}
	if (retry) {
		pp_diag(ppi, time, 1, "%s: %i iterations. %s\n", __func__,
			retry, errno ? strerror(errno) : "");
	}
	if (retry == N_RETRY) /* we got nothing */
		return;

	if (!t) /* maybe caller is not interested, though we popped it out */
		return;

	/*
	 * Raw frames return "sock_extended_err" too, telling this is
	 * a tx timestamp. UDP does not; so don't check in udp mode
	 * (the pointer is only checked for non-null)
	 */
	if (!(ppi->proto != PPSI_PROTO_UDP))
		serr = (void *)1;

	for (cmsg = CMSG_FIRSTHDR(&msg);
	     cmsg;
	     cmsg = CMSG_NXTHDR(&msg, cmsg)) {

		void *dp = CMSG_DATA(cmsg);

		if(cmsg->cmsg_level == SOL_PACKET
		   && cmsg->cmsg_type == PACKET_TX_TIMESTAMP)
			serr = (struct sock_extended_err *) dp;

		if(cmsg->cmsg_level == SOL_SOCKET
		   && cmsg->cmsg_type == SO_TIMESTAMPING)
			sts = (struct scm_timestamping *) dp;

		if(sts && serr)	{
			t->scaled_nsecs =
				(long long)sts->hwtimeraw.tv_nsec << 16;
			t->secs = sts->hwtimeraw.tv_sec & 0x7fffffff;
		}
	}
}

static int wrs_net_send(struct pp_instance *ppi, void *pkt, int len,enum pp_msg_format msg_fmt)
{
	const struct pp_msgtype_info *mf = pp_msgtype_info + msg_fmt;
	int chtype = mf->chtype;
	struct sockaddr_in addr;
	struct ethhdr *hdr = pkt;
	struct pp_vlanhdr *vhdr = pkt;
	struct pp_channel *ch = ppi->ch + chtype;
	struct pp_time *t = &ppi->last_snt_time;
	int delay_mechanism = mf->delay_mechanism;
	static uint16_t udpport[] = {
		[PP_NP_GEN] = PP_GEN_PORT,
		[PP_NP_EVT] = PP_EVT_PORT,
	};
	static const uint8_t macaddr[MECH_MAX_SUPPORTED + 1][ETH_ALEN] = {
		[MECH_E2E] = PP_MCAST_MACADDRESS,
		[MECH_P2P] = PP_PDELAY_MACADDRESS,
	};
	struct wrs_socket *s;
	int ret, fd, drop;
	char prefix[32];

	s = (struct wrs_socket *)ppi->ch[PP_NP_GEN].arch_chan_data;

	/*
	 * To fake a packet loss, we must corrupt the frame; we need
	 * to transmit it for real, if we want to get back our
	 * hardware stamp. Thus, remember if we drop, and use this info.
	 */
	drop = ppsi_drop_tx();
	if (pp_diag_allow(ppi, frames, 2))
		sprintf(prefix,"send-%s: ",(ppi ? ppi->port_name: "ppsi"));

	switch (ppi->proto) {
	case PPSI_PROTO_RAW:
		/* raw socket implementation always uses gen socket */
		ch = ppi->ch + PP_NP_GEN;
		hdr->h_proto = htons(ETH_P_1588);
		if (drop)
			hdr->h_proto++;

		memcpy(hdr->h_dest, macaddr[delay_mechanism], ETH_ALEN);
		memcpy(hdr->h_source, ch->addr, ETH_ALEN);

		if (t)
			TOPS(ppi)->get(ppi, t);

		ret = send(ch->fd, hdr, len, 0);
		if (ret < 0) {
			pp_diag(ppi, frames, 0, "send failed: %s\n",
				strerror(errno));
			break;
		}
		poll_tx_timestamp(ppi, pkt, len, s, ch->fd, t);

		if (drop) /* avoid messaging about stamps that are not used */
			break;

		if (pp_diag_allow(ppi, frames, 2))
			dump_1588pkt(prefix, pkt, len, t, -1);
		pp_diag(ppi, time, 1, "send stamp: %s\n", fmt_time(t));
		return ret;

	case PPSI_PROTO_VLAN:
		/* similar to sending raw frames, but w/ different header */
		ch = ppi->ch + PP_NP_GEN;
		vhdr->h_proto = htons(ETH_P_1588);
		vhdr->h_tci = htons(ppi->peer_vid); /* prio is 0 */
		vhdr->h_tpid = htons(0x8100);
		if (drop)
			hdr->h_proto++;

		memcpy(hdr->h_dest, macaddr[delay_mechanism], ETH_ALEN);
		memcpy(vhdr->h_source, ch->addr, ETH_ALEN);

		if (t)
			TOPS(ppi)->get(ppi, t);

		if (len < 64)
			len = 64;
		ret = send(ch->fd, vhdr, len, 0);
		if (ret < 0) {
			pp_diag(ppi, frames, 0, "send failed: %s\n",
				strerror(errno));
			break;
		}
		poll_tx_timestamp(ppi,  pkt, len, s, ch->fd, t);

		if (drop) /* avoid messaging about stamps that are not used */
			break;

		if (pp_diag_allow(ppi, frames, 2))
			dump_1588pkt(prefix, pkt, len, t, ppi->peer_vid);
		pp_diag(ppi, time, 1, "send stamp: %s\n", fmt_time(t));
		return ret;

	case PPSI_PROTO_UDP:
		fd = ppi->ch[chtype].fd;
		addr.sin_family = AF_INET;
		addr.sin_port = htons(udpport[chtype]);
		addr.sin_addr.s_addr = ppi->mcast_addr[delay_mechanism];
		if (drop)
			addr.sin_port = 3200;
		ret = sendto(fd, pkt, len, 0, (struct sockaddr *)&addr,
			     sizeof(struct sockaddr_in));
		if (ret < 0) {
			pp_diag(ppi, frames, 0, "send failed: %s\n",
				strerror(errno));
			break;
		}
		poll_tx_timestamp(ppi, pkt, len, s, fd, t);

		if (drop) /* like above: skil messages about timestamps */
			break;

		if (pp_diag_allow(ppi, frames, 2))
			dump_payloadpkt(prefix, pkt, len, t);
		pp_diag(ppi, time, 1, "send stamp: %s\n", fmt_time(t));
		return ret;

	default:
		return -1;
	}

	if (drop)
		pp_diag(ppi, frames, 1, "Drop sent frame\n");

	return ret;
}

/* Helper for setting up hardware timestamps */
static int wrs_enable_timestamps(struct pp_instance *ppi, int fd)
{
	int so_timestamping_flags = SOF_TIMESTAMPING_TX_HARDWARE |
		SOF_TIMESTAMPING_RX_HARDWARE |
		SOF_TIMESTAMPING_RAW_HARDWARE;
	struct ifreq ifr;
	struct hwtstamp_config hwconfig;

	if (fd < 0)
		return 0; /* nothing to do */

	/* Since version v3.2-rc1 (commit 850a545bd) linux kernel check whether
	 * field "flags" of struct hwtstamp_config is empty, otherwise ioctl
	 * for SIOCSHWTSTAMP returns -EINVAL */
	memset(&ifr, 0, sizeof(struct ifreq));
	memset(&hwconfig, 0, sizeof(struct hwtstamp_config));

	strncpy(ifr.ifr_name, ppi->iface_name, sizeof(ifr.ifr_name));
	hwconfig.tx_type = HWTSTAMP_TX_ON;
	hwconfig.rx_filter = HWTSTAMP_FILTER_PTP_V2_L2_EVENT;
	ifr.ifr_data = (void *)&hwconfig;

	if (ioctl(fd, SIOCSHWTSTAMP, &ifr) < 0) {
		pp_diag(ppi, frames, 1,
			"%s: ioctl(SIOCSHWTSTAMP): %s\n",
			ppi->iface_name, strerror(errno));
		return -1;
	}

	if (setsockopt(fd, SOL_SOCKET, SO_TIMESTAMPING,
		       &so_timestamping_flags, sizeof(int)) < 0) {
		pp_diag(ppi, frames, 1,
			"socket: setsockopt(TIMESTAMPING): %s\n",
			strerror(errno));
		return -1;
	}

	return 0;
}

static int wrs_net_exit(struct pp_instance *ppi);

static int wrs_net_init(struct pp_instance *ppi)
{
	int r, i;
	struct hal_port_state *p;

	if (ppi->ch[PP_NP_GEN].arch_chan_data)
		wrs_net_exit(ppi);

	/* Generic OS work is done by standard Unix stuff */
	r = unix_net_ops.init(ppi);

	if (r)
		return r;

	/* We used to have a mini-rpc call, but we now access shmem */
	p = pp_wrs_lookup_port(ppi->iface_name);
	if (!p)
		return -1;

	/* Only one wrs_socket is created for each pp_instance, because
	 * wrs_socket is related to the interface and not to the pp_channel */
	struct wrs_socket *s = calloc(1, sizeof(struct wrs_socket));

	if (!s)
		return -1;

	/*
	 * The following 3 values used to come from an RPC call.  But
	 * the RPC structure is not the same as the one exported in
	 * shared memory (don't know why); so here I unroll the
	 * conversions, and what is constant in the HAL becomes
	 * constant here (ARub)
	 */
	s->clock_period = (p->clock_period)?p->clock_period:HAL_REF_CLOCK_PERIOD_PS;
	s->phase_transition = (p->t2_phase_transition)?p->t2_phase_transition:HAL_DEF_T2_PHASE_TRANS;
	s->dmtd_phase = p->phase_val;

	s->dmtd_phase_valid = 0;

	ppi->ch[PP_NP_GEN].arch_chan_data = s;
	ppi->ch[PP_NP_EVT].arch_chan_data = s;
	tmo_init(&s->dmtd_update_tmo, DMTD_UPDATE_INTERVAL);

	for (i = PP_NP_GEN, r = 0; i <= PP_NP_EVT && r == 0; i++)
		r = wrs_enable_timestamps(ppi, ppi->ch[i].fd);
	if (r) {
		ppi->ch[PP_NP_GEN].arch_chan_data = NULL;
		ppi->ch[PP_NP_EVT].arch_chan_data = NULL;
		free(s);
	}
	return r;
}

static int wrs_net_exit(struct pp_instance *ppi)
{
	unix_net_ops.exit(ppi);
	free(ppi->ch[PP_NP_GEN].arch_chan_data);
	ppi->ch[PP_NP_GEN].arch_chan_data = NULL;
	ppi->ch[PP_NP_EVT].arch_chan_data = NULL;
	return 0;
}

static int wrs_net_check_packet(struct pp_globals *ppg, int delay_ms)
{
	return unix_net_ops.check_packet(ppg, delay_ms);
}

const struct pp_network_operations wrs_net_ops = {
	.init = wrs_net_init,
	.exit = wrs_net_exit,
	.recv = wrs_net_recv,
	.send = wrs_net_send,
	.check_packet = wrs_net_check_packet,
};
