/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __COMMON_FUN_H
#define __COMMON_FUN_H

#include <ppsi/ppsi.h>

/* Contains all functions common to more than one state */
int st_com_check_announce_receive_timeout(struct pp_instance *ppi);
int st_com_peer_handle_preq(struct pp_instance *ppi, void *buf, int len);
int st_com_peer_handle_pres(struct pp_instance *ppi, void *buf, int len);
int st_com_peer_handle_pres_followup(struct pp_instance *ppi, void *buf, int len);
int st_com_handle_announce(struct pp_instance *ppi, void *buf,  int len);
int st_com_handle_signaling(struct pp_instance *ppi, void *buf, int len);
void update_meanDelay(struct pp_instance *ppi, TimeInterval meanDelay);

int __send_and_log(struct pp_instance *ppi, int msglen, int chtype,enum pp_msg_format msg_fmt);

/* Count successfully received PTP packets */
static inline int __recv_and_count(struct pp_instance *ppi, void *buf, int len,
		   struct pp_time *t)
{
	int ret;
	ret = ppi->n_ops->recv(ppi, buf, len, t);
	if (ret > 0) {
		/* Adjust reception timestamp: ts'= ts - ingressLatency - semistaticLatency*/
		TimeInterval adjust;
		if (is_ext_hook_available(ppi,get_ingress_latency) ){
			adjust= ppi->ext_hooks->get_ingress_latency(ppi);
		} else  {
			adjust=ppi->timestampCorrectionPortDS.ingressLatency;
			adjust+=ppi->timestampCorrectionPortDS.semistaticLatency;
		}
		pp_time_sub_interval(t,adjust);
		ppi->ptp_rx_count++;
	}
	return ret;
}

#endif /* __COMMON_FUN_H */
