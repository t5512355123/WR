/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2021-2023 CERN
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* This periodic task is responsible for printing stats (for the stats
   command)  */

#include <inttypes.h>
#include "wrc-task.h"
#include "wrpc.h"
#include "softpll/softpll_ng.h"
#include "dev/endpoint.h"
#include "dev/netif.h"
#include "dev/pps_gen.h"
#include "dev/temperature.h"
#include "wrc_global.h"
#include "shell.h"

#ifdef CONFIG_CMD_MONITOR_SERVO_ERR
#define HAS_MONITOR_SERVO_ERR 1
#else
#define HAS_MONITOR_SERVO_ERR 0
#endif


/* internal "last", exported to shell command */
uint32_t wrc_stats_last;

int wrc_log_stats(void)
{
	struct wrc_netif_device *ndev = netif_get_device(0);
	int tx, rx, rx_err;
	struct spll_aux_clock_status aux_stat;
	uint64_t sec;
	uint32_t nsec;
	static uint32_t last_update_tick;
	int n_out;
	int i;
	struct pp_servo *s = SRV(ppg->pp_instances);
	wrh_servo_t * wrh_servo;


	/* stats update condition for Slave mode */
	if (wrc_stats_last == s->update_count
	    && wrc_ptp_get_mode() == WRC_MODE_SLAVE) {
		last_update_tick = 0;
		return 0;
	}

	if (!wrc_stat_running) {
		last_update_tick = 0;
		return 0;
	}

	/* stats update condition for Master mode */
	if (wrc_task_not_yet(&last_update_tick, wrc_ui_refperiod))
		return 0;


	/* Print only one time */
	if (wrc_stat_running == -1)
		wrc_stat_running = 0;

	wrc_stats_last = s->update_count;

	shw_pps_gen_get_time(&sec, &nsec);
	minic_get_stats(ndev->nic, &tx, &rx, &rx_err);

	pp_printf("lnk:%d rx:%d tx:%d ", (wrc_global_link.link_up == NETIF_LINK_UP), rx, tx);
	pp_printf("lock:%d ", spll_check_lock(0) ? 1 : 0);
	pp_printf("ptp:%s ", get_state_as_string(&ppi_static, ppi_static.state));

	if (wrc_ptp_get_mode() == WRC_MODE_SLAVE) {
		pp_printf("sv:%d ", (s->flags & PP_SERVO_FLAG_VALID) ? 1 : 0);
		pp_printf("ss:'%s' ", s->servo_state_name);
	}

	spll_get_num_channels(NULL, &n_out);

	for (i = 0; i < n_out - 1; i++) {
		aux_stat = spll_get_aux_status(i);
		pp_printf("aux%d:%08x%08x ", i, (int) aux_stat.flags, (int) aux_stat.phase);
	}

	/* fixme: clock is not always 125 MHz */
	pp_printf("sec:%d nsec:%09d ", (int) sec, (int) nsec);
	wrh_servo = (ppi_static.protocol_extension == PPSI_EXT_WR && ppi_static.extState == PP_EXSTATE_ACTIVE) ?
			(wrh_servo_t*) ppi_static.ext_data : NULL;

	if (wrc_ptp_get_mode() == WRC_MODE_SLAVE) {
#if CONFIG_HAS_EXT_WR
		wr_servo_ext_t * wr_servo_ext =
			&((struct wr_data *)wrh_servo)->servo_ext;

		/* RTT */
		pp_printf("mu:%Ld ", pp_time_to_picos(&wr_servo_ext->rawDelayMM));
#endif

		pp_printf("dms:%Ld ", pp_time_to_picos(&s->delayMS));

#if CONFIG_HAS_EXT_WR
		pp_printf("dtxm:%d drxm:%d ",
			  (int) pp_time_to_picos(&wr_servo_ext->delta_txm),
			  (int) pp_time_to_picos(&wr_servo_ext->delta_rxm));
		pp_printf("dtxs:%d drxs:%d ",
			  (int) pp_time_to_picos(&wr_servo_ext->delta_txs),
			  (int) pp_time_to_picos(&wr_servo_ext->delta_rxs));
		pp_printf("asym:%Ld ", interval_to_picos(ppi_static.portDS->delayAsymmetry));

		struct pp_time crtt = wr_servo_ext->rawDelayMM;
		pp_time_sub(&crtt, &wr_servo_ext->delta_txm);
		pp_time_sub(&crtt, &wr_servo_ext->delta_rxm);
		pp_time_sub(&crtt, &wr_servo_ext->delta_txs);
		pp_time_sub(&crtt, &wr_servo_ext->delta_rxs);

		/* Cable RTT */
		pp_printf("crtt:%Ld ", pp_time_to_picos(&crtt));
#endif
		/* Clock offset */
		pp_printf("cko:%d ", (int) pp_time_to_picos(&s->offsetFromMaster));
		pp_printf("setp:%d ", (int) wrh_servo->cur_setpoint_ps);
		pp_printf("ucnt:%d ", (int) s->update_count);
		pp_printf("bslide:%d ", ep_get_bitslide(&wrc_endpoint_dev));
		if (HAS_MONITOR_SERVO_ERR) {
			pp_printf("ses:%u ", wrh_servo->n_err_state);
			pp_printf("seo:%u ", wrh_servo->n_err_offset);
			pp_printf("sedr:%u ", wrh_servo->n_err_delta_rtt);
		}
	}

	pp_printf("hd:%d md:%d ad:%d ", spll_get_dac(-1), spll_get_dac(0),
		spll_get_dac(1));

	if (HAS_TEMP_SENSORS) {
		int32_t temp;

		temp = wrc_temp_get("pcb");
		pp_printf("temp:%d.%04d C", (int) (temp >> 16),
			  (int) ((temp & 0xffff) * 10 * 1000 >> 16));
	}

	pp_printf("\n");

	return 1;
}

