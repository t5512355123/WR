/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2021-2023 CERN
 * Author: Adam Wujek
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <inttypes.h>
#include "wrc.h"
#include "dev/w1.h"
#include "ppsi/ppsi.h"
#include "wrpc.h"
#include "proto-ext-whiterabbit/wr-api.h"
#include "proto-ext-l1sync/l1e-api.h"
#include "dev/minic.h"
#include "softpll_ng.h"
#include "dev/syscon.h"
#include "dev/pps_gen.h"
#include "dev/endpoint.h"
#include "dev/netif.h"
#include "dev/wdiags.h"
#include "sensors.h"
#include "hal_exports.h"
#include "lib/ipv4.h"
#include "shell.h"
#include "revision.h"
#include "wrc_global.h"
#include "hw/wrc_diags_regs.h"

#ifndef CONFIG_PRINTF_FULL
#error ("WRPC monitor requires full version of pp_printf implementation")
#endif

#ifdef CONFIG_CMD_MONITOR_SERVO_ERR
#define HAS_MONITOR_SERVO_ERR 1
#else
#define HAS_MONITOR_SERVO_ERR 0
#endif

#define WRC_MONITOR_REFRESH_PERIOD (1 * TICS_PER_SECOND)

#define DESCRIPTION_MAIN 1
#define DESCRIPTION_SERVO 2
#define DESCRIPTION_WR_SERVO 4

/* protocol extension data */
#define IS_PROTO_EXT_INFO_AVAILABLE(proto_id) \
	((proto_id < sizeof(proto_ext_info) / sizeof(struct proto_ext_info_t)) \
			&& (proto_ext_info[proto_id].short_ext_name))


static uint8_t prev_gui_description = 0;
static uint8_t gui_description = 1;
static uint32_t next_update_ticks;
/* refresh period for _gui_ and _stat_ commands */
int wrc_ui_refperiod = WRC_MONITOR_REFRESH_PERIOD;

struct proto_ext_info_t {
	char short_ext_name; /* Very short extension name - just one character */	const char *ext_name; /* Extension name */
};

static const struct proto_ext_info_t proto_ext_info [] = {
		[PPSI_EXT_NONE] = {
				.ext_name = "PTP",
				.short_ext_name = 'P',
		},

#if CONFIG_HAS_EXT_WR
		[PPSI_EXT_WR] = {
				.ext_name ="White-Rabbit",
				.short_ext_name ='W',
		},
#endif
#if CONFIG_HAS_EXT_L1SYNC
		[PPSI_EXT_L1S] = {
				.ext_name ="L1Sync",
				.short_ext_name ='L',
		},
#endif

};


/* define size of pp_instance_state_to_name as a last element + 1 */
#define PP_INSTANCE_STATE_MAX (sizeof(pp_instance_state_to_name) / sizeof(char *))

/* define conversion array for the field state in the struct pp_instance */
static const char * const pp_instance_state_to_name[] = {
	/* from ppsi/include/ppsi/ieee1588_types.h, enum pp_std_states */
	/* PPS_END_OF_TABLE = 0 */
	[PPS_END_OF_TABLE] =      "EOT      ",
	[PPS_INITIALIZING] =      "INITING  ",
	[PPS_FAULTY] =            "FAULTY   ",
	[PPS_DISABLED] =          "DISABLED ",
	[PPS_LISTENING] =         "LISTENING",
	[PPS_PRE_MASTER] =        "PREMASTER",
	[PPS_MASTER] =            "MASTER   ",
	[PPS_PASSIVE] =           "PASSIVE  ",
	[PPS_UNCALIBRATED] =      "UNCALIBR ",
	[PPS_SLAVE] =             "SLAVE    ",
	NULL
	};

#define EMPTY_EXTENSION_STATE_NAME      "          "

#if CONFIG_HAS_EXT_L1SYNC
static const char * const l1e_instance_extension_state[]={
		[__L1SYNC_MISSING   ] = "INVALID   ",
		[L1SYNC_DISABLED    ] = "DISABLED  ",
		[L1SYNC_IDLE        ] = "IDLE      ",
		[L1SYNC_LINK_ALIVE  ] = "LINK ALIVE",
		[L1SYNC_CONFIG_MATCH] = "CFG MATCH ",
		[L1SYNC_UP          ] = "L1 SYNC UP",
		NULL
};
#define L1S_INSTANCE_EXTENSION_STATE_MAX (sizeof (l1e_instance_extension_state)/sizeof(char *))

#endif

static const char * const timing_mode_state[] = {
		[WRH_TM_GRAND_MASTER]=     "GM",
		[WRH_TM_FREE_MASTER]=      "FR",
		[WRH_TM_BOUNDARY_CLOCK]=   "BC",
		[WRH_TM_DISABLED]=         "--",
		NULL
	};

#if CONFIG_HAS_EXT_WR
static const char * const wr_instance_extension_state[]={
		[WRS_IDLE ]=              "IDLE      ",
		[WRS_PRESENT] =           "WR_PRESENT",
		[WRS_S_LOCK] =            "WR_S_LOCK ",
		[WRS_M_LOCK] =            "WR_M_LOCK ",
		[WRS_LOCKED] =            "WR_LOCKED ",
		[WRS_CALIBRATION] =       "WR_CAL-ION",
		[WRS_CALIBRATED] =        "WR_CAL-ED ",
		[WRS_RESP_CALIB_REQ] =    "WR_RSP_CAL",
		[WRS_WR_LINK_ON] =        "WR_LINK_ON",
		NULL
};
#define WR_INSTANCE_EXTENSION_STATE_MAX (sizeof (wr_instance_extension_state) / sizeof(char *))

#endif

static const char * const prot_detection_state_name[]={
		"NONE   ", /* No meaning. No extension present */
		"WA_MSG ", /* Waiting first message */
		"PD_IPRG", /* Protocol detection  */
		"EXT_ON ", /* Protocol detected */
		"EXT_OFF" /* Protocol not detected */
};

static inline char * timeToString_ps_as_ns(struct pp_time *time, char *buf)
{
	if (!is_incorrect(time)) {
		return time_to_string(time);
	} else {
		sprintf(buf, "--Incorrect--");
	}
	return buf;
}

static inline int extensionStateColor(struct pp_instance *ppi)
{
	if (ppi->protocol_extension == PPSI_EXT_NONE) {
		return C_GREEN; /* No extension */
	}
	switch (ppi->extState) {
	case PP_EXSTATE_ACTIVE :
		return C_GREEN;
	case PP_EXSTATE_PTP :
		return C_WHITE;
	case PP_EXSTATE_DISABLE :
	default:
		return C_RED;
	}
}

static const char *getStateAsString(const char * const p[], int index)
{
	int i, len;
	static const char errMsg[] = "???????????";

	len = strlen(p[0]);
	for (i = 0; ; i++) {
		if (p[i] == NULL)
			return errMsg + strlen(errMsg) - len;
		if (i == index)
			return p[index];
	}
}

static char *optimized_pp_time_toString_ps_as_ns(struct pp_time *pptime, char *buf)
{
	char lbuf[128];

	if (pptime->secs)
		sprintf(buf,"%s sec", timeToString_ps_as_ns(pptime, lbuf));
	else
		sprintf(buf,"%s ns ", interval_to_string(pp_time_to_interval(pptime)));
	return buf;
}

static char * convert_ps_to_str_ns(char *buff, int64_t num)
{
	int i;
	int len;
	char *p;
	sprintf(buff, "% 05Ld", num);
	len = strlen(buff);
	p = buff + len;
	for (i = 0; i < 4; i++, p--) {/* move EOL and 3 chars */
		*(p + 1) = *(p);
	}
	*(p + 1) = '.';
	return buff;
}

static void print_main_description(void)
{
	int i;
	int ndevs;

	pcprintf(1, 1, C_BLUE, "%s WRPC Monitor %s",
		 wrc_global_link.wrc_hw_name, build_id.commit_id);
	cprintf(C_MAGENTA, " | Esc/q = exit; r = redraw\n\n");

	cprintf(C_BLUE, "TAI Time:%22sUTC offset:%4s  PLL mode:%4s state:\n",
		"", "", "");

	ndevs = netif_get_device_count();

	/*show_ports */
	cprintf(C_CYAN, "---+-------------------+-------------------------+---------+---------+-----\n");
	pp_printf(      " # |        MAC        |       IP (source)       |    RX   |    TX   | VLAN\n");
	pp_printf(      "---+-------------------+-------------------------+---------+---------+-----\n");

	for (i = 0 ; i < ndevs; i++) {
		/* reuse the string above, strings between "|" will be overwritten anyway */
		pp_printf(" # |        MAC        |       IP (source)       |    RX   |    TX   | VLAN\n");
	}

	pp_printf("\n--- HAL ---|------------- PPSI ------------------------------------------------\n");
	pp_printf(  " Itf | Frq |  Config   | MAC of peer port  |    PTP/EXT/PDETECT States   | Pro \n");
	pp_printf(  "-----+-----+-----------+-------------------+-----------------------------+-----\n");
	for (i = 0 ; i < ndevs; i++) {
		/* reuse the string above, strings between "|" will be overwritten anyway */
		pp_printf(" Itf | Frq |  Config   | MAC of peer port  |    PTP/EXT/PDETECT States   | Pro \n");
	}

	cprintf(C_BLUE, "Pro(tocol): R-RawEth, V-VLAN, U-UDP\n");

	cprintf(C_CYAN, "\n--------------------------- Synchronization status ----------------------------");
}

static void print_time_pll(void)
{
	int leap_sec, tmp;
	uint64_t sec;
	uint32_t nsec;

	shw_pps_gen_get_time(&sec, &nsec);

	/* TAI Time */
	pcprintf(3, 11, C_WHITE, "%s", format_time(sec, TIME_FORMAT_SORTED));

	/* UTC offset */
	wrc_ptp_get_leapsec(&leap_sec , &tmp /* dummy */);
	pprintf(3, 44, "%d", leap_sec);

	/* Timing mode  */
	pprintf(3, 59, getStateAsString(timing_mode_state, WRPC_ARCH_G(ppg)->timingMode));

	/* PLL locking state */
	pprintf(3, 70, "Lock%s", spll_check_lock(0) ? "ed " : "ing");
}

static void print_port(unsigned i)
{
	struct wrc_netif_device *ndev = netif_get_device(i);
	int port_up = ep_link_up(ndev->ep, NULL);
	int tx, rx, rx_err;
	char buf[20];

	if (port_up) {
		pcprintf(7, 1, C_GREEN, " %u", i);
	} else {
		pcprintf(7, 1, C_RED, "*%u", i);
	}

	format_mac(buf, ndev->ep->mac_addr);
	pcprintf(7, 6, C_MAGENTA, "%s", buf);

	if (i != 0) /* FIXME: should be independent for each interface */
		return;

	if (HAS_IP && port_up) {
		uint8_t ip[INET_ALEN];

		getIP(ip);
		format_ip(buf, ip);
		switch (ip_status) {
		case IP_TRAINING:
			pcprintf(7, 26, C_RED,   "BOOTP running          ");
			break;
		case IP_OK_BOOTP:
			pcprintf(7, 26, C_GREEN, "%16s(BOOTP)", buf);
			break;
		case IP_OK_STATIC:
			pcprintf(7, 26, C_GREEN, "%15s(static)", buf);
			break;
		}
	} else
		pcprintf(7, 26, C_GREEN, "                       ");

	minic_get_stats(ndev->nic, &tx, &rx, &rx_err);
	pcprintf(7, 52, C_MAGENTA, "%7d", rx);
	pprintf(7, 62, "%7d", tx);
	pprintf(7, 72, "%4d", wrc_vlan_number);
}

static void print_state(unsigned i)
{
	struct wrc_netif_device *ndev = netif_get_device(i);
	int port_up = ep_link_up(ndev->ep, NULL);
	int locked = spll_check_lock(0);
	int color;


	/* Assume one instance per port */
	/* FIXME: add support of more ports */
//		for (j = 0; j < ppg->nlinks; j++) {
	{
		const char* str_config;
		/* so far support only for one instance */
		struct pp_instance *ppi_pt = ppg->pp_instances;
		int proto_extension = ppi_pt->protocol_extension;
		const struct proto_ext_info_t *pe_info = IS_PROTO_EXT_INFO_AVAILABLE(proto_extension) ? &proto_ext_info[proto_extension] :  &proto_ext_info[0] ;
		unsigned char *p = ppi_pt->activePeer;
		const char * extension_state_name = EMPTY_EXTENSION_STATE_NAME;
		char proto;
		char mac_buf[20];

		if (port_up) {
			pcprintf(12, 1, C_GREEN, " %s", ppi_pt->iface_name);
		} else {
			pcprintf(12, 1, C_RED,   "*%s", ppi_pt->iface_name);
		}

		pcprintf(12, 8, C_GREEN, locked ? "Lck" : "   ");

		// Evaluate the instance configuration
		if (is_slaveOnly(ppg->defaultDS)) {
			str_config = "slaveOnly";
		} else if (is_externalPortConfigurationEnabled(ppg->defaultDS)) {
			str_config = getStateAsString(pp_instance_state_to_name, ppi_pt->externalPortConfigurationPortDS.desiredState);
		} else if (is_masterOnly(ppi_pt->portDS)) {
			str_config = "mastrOnly";
		} else {
			str_config = "auto";
		}
		pcprintf(12, 14, C_WHITE, "%-10s", str_config);

		/* peer not implemented */
		pprintf(12, 26, format_mac(mac_buf, p));

		pcprintf(12, 46, C_GREEN, "%s/", getStateAsString(pp_instance_state_to_name, ppi_pt->state));
		/* print extension state */
		switch (ppi_pt->protocol_extension) {
#if CONFIG_HAS_EXT_WR
		case PPSI_EXT_WR :
		{
			portDS_t *portDS = ppi_pt->portDS;
			struct wr_dsport *extPortDS = portDS->ext_dsport;

			extension_state_name = getStateAsString(wr_instance_extension_state, extPortDS->state);
			break;
		}
#endif
#if CONFIG_HAS_EXT_L1SYNC
		case PPSI_EXT_L1S :
		{
			portDS_t *portDS = ppi_pt->portDS;
			l1e_ext_portDS_t *extPortDS = portDS->ext_dsport;

			extension_state_name = getStateAsString(l1e_instance_extension_state, extPortDS->basic.L1SyncState);
			break;
		}
#endif
		}
		pp_printf("%s/%s", extension_state_name, getStateAsString(prot_detection_state_name, ppi_pt->pdstate));

		/* proto */
		switch (ppi_pt->proto) {
		case PPSI_PROTO_RAW:
			proto = 'R';
			break;
		case PPSI_PROTO_UDP:
			proto = 'U';
			break;
		case PPSI_PROTO_VLAN:
			proto = 'V';
			break;
		default:
			proto = '?';
		}

		pcprintf(12, 76, C_WHITE, "%c", proto);
		color = extensionStateColor(ppi_pt);
		cprintf(color, "-%c", pe_info->short_ext_name);
	}
}

static void print_main_data(void)
{
	int ndevs;
	int i;

	print_time_pll();
	ndevs = netif_get_device_count();

	/* show_ports
	------+-------------------+-------------------------+---------+---------+-----
	Iface |        MAC        |       IP (source)       |    RX   |    TX   | VLAN
	------+-------------------+-------------------------+---------+---------+-----
	*/

	for (i = 0 ; i < ndevs; i++)
		print_port(i);

	/*
	----- HAL ---|---------------- PPSI -------------------------------------------------
	 Iface| Freq |    Config    | MAC of peer port  |    PTP/EXT/PDETECT States    | Pro
	------+------+--------------+-------------------+------------------------------+----- */

	for (i = 0 ; i < ndevs; i++)
		print_state(i);
}

static void print_aux_data(void)
{
	int n_out, i;
	struct spll_aux_clock_status aux_stat;

	spll_get_num_channels(NULL, &n_out);

	for (i = 0; i < n_out - 1; i++) {
		cprintf(C_MAGENTA, "\n\nAux clock %d status:        ", i);

		aux_stat = spll_get_aux_status(i);

		if (aux_stat.flags & SPLL_AUX_SLAVE_ENABLED)
			cprintf(C_GREEN, "enabled");

		if (aux_stat.flags & SPLL_AUX_MONITOR_ENABLED)
			cprintf(C_GREEN, "monitor");

		if (aux_stat.flags & SPLL_AUX_SLAVE_LOCKED)
			cprintf(C_GREEN, ", locked");

		if (aux_stat.flags & SPLL_AUX_MONITOR_READY)
		{
			cprintf(C_GREEN, ", ready");
			cprintf(C_WHITE, " (AUX-to-WR offset: %d ps)", aux_stat.phase);
		}
	}

	return;
}

static void print_servo_description(void)
{

	if (HAS_MONITOR_SERVO_ERR) {
		pcprintf(19, 45, C_BLUE, "err state:");
		pprintf(20, 45, "err offset:");
		pprintf(21, 45, "err delta:");
	}

	pcprintf(16, 1, C_BLUE, "Servo state:\n");

	cprintf(C_CYAN, "\n--- Timing parameters ---------------------------------------------------------\n");

	cprintf(C_BLUE, "meanDelay        :\n");

	pp_printf("delayMS          :\n");
	pp_printf("delayMM          :\n");

	//pp_printf("Estimated link length:     ");

	pp_printf("delayAsymmetry   :\n");
	pp_printf("delayCoefficient :");
	pprintf(23, 45, "fpa\n");

	pp_printf("ingressLatency   :\n");
	pp_printf("egressLatency    :\n");
	pp_printf("semistaticLatency:\n");
	pp_printf("offsetFromMaster :\n");
	if (gui_description & DESCRIPTION_WR_SERVO) {
		pp_printf("Phase setpoint   :\n");
		pp_printf("Skew             :\n");
	}
	pp_printf("Update counter   :\n");
	if (gui_description & DESCRIPTION_WR_SERVO) {
		pp_printf("Master PHY delays TX:\n"); /* RX: */
		pp_printf("Slave  PHY delays TX:\n"); /* RX: */
	}
}

static void print_servo_data(struct pp_instance *ppi)
{
	wrh_servo_t * wrh_servo;
	char buf[128];
	int row_offset;
	int proto_extension = ppi->extState!= PP_EXSTATE_DISABLE ? ppi->protocol_extension : PPSI_EXT_NONE;
	const struct proto_ext_info_t *pe_info = IS_PROTO_EXT_INFO_AVAILABLE(proto_extension) ? &proto_ext_info[proto_extension] :  &proto_ext_info[0];

	/* --------------------------- Synchronization status ---------------------------- */
	pprintf(16, 1, "");
	if (ppi->state != PPS_SLAVE || !(ppi->servo->flags & PP_SERVO_FLAG_VALID)) {
		cprintf(C_RED, "Link down, master mode or sync info not valid");
		return;
	}

	wrh_servo = (ppi->extState == PP_EXSTATE_ACTIVE) ?
			(wrh_servo_t*) ppi->ext_data : NULL;

	/* should print servio description */
	gui_description |= DESCRIPTION_SERVO;

#if CONFIG_HAS_EXT_WR
	wr_servo_ext_t * wr_servo_ext = NULL;
	if (wrh_servo) {
		wr_servo_ext = &((struct wr_data *)wrh_servo)->servo_ext;
	}
#endif

	/* should print WR servio description */
	gui_description |= wrh_servo ? DESCRIPTION_WR_SERVO : 0;

	/* Avoid printing new data if change in description is expected.
	 * This avoids extra redraw of data values */
	if(prev_gui_description
	   != (gui_description & (DESCRIPTION_MAIN
				  | DESCRIPTION_SERVO
				  | DESCRIPTION_WR_SERVO)))
		return;

	pcprintf(16, 23, C_WHITE, "%s: %-20s %-15s\n",
		 pe_info->ext_name,
		 ppi->servo->servo_state_name,
		 ppi->servo->flags & PP_SERVO_FLAG_WAIT_HW ?
		 "(wait for hw)" : "");

	/* "tracking disabled" is just a testing tool */
	if (wrh_servo && !wrh_servo->tracking_enabled)
		cprintf(C_RED, "Tracking forcibly disabled\n");

	if (HAS_MONITOR_SERVO_ERR && wrh_servo) {
		pcprintf(19, 60, C_WHITE, " %u ", wrh_servo->n_err_state);
		pprintf(20, 60, " %u ", wrh_servo->n_err_offset);
		pprintf(21, 60, " %u ", wrh_servo->n_err_delta_rtt);
	}

	/* +- Timing parameters --------------------------------------------------------- */

	pcprintf(19, 20, C_WHITE, "%20s ns", interval_to_string(ppg->currentDS->meanDelay));

	/*delayMS */
	pprintf(20, 20, "%24s", optimized_pp_time_toString_ps_as_ns(&ppi->servo->delayMS, buf));
	{
		struct pp_time *delayMM = &ppi->servo->delayMM;
#if CONFIG_HAS_EXT_WR
		if (wr_servo_ext)
			delayMM = &wr_servo_ext->rawDelayMM;
#endif
		/* delayMM */
		pprintf(21, 20, "%24s", optimized_pp_time_toString_ps_as_ns(delayMM, buf));
	}

	//cprintf(C_BLUE, "Estimated link length:     ");
	/* (RTT - deltas) / 2 * c / ri
	    c = 299792458 - speed of light in m/s
	    ri = 1.4682 - refractive index for fiber g.652. However,
			experimental measurements using long (~5km) and
			short (few m) fibers gave a value 1.4827
	    */
	//cprintf(C_WHITE, "%10.2f meters\n",
	//	crtt / 2 / 1e6 * 299.792458 / 1.4827);


	/* delayAsymmetry */
	pprintf(22, 20, "%20s ns",   interval_to_string(ppi->portDS->delayAsymmetry));
	/* delayCoefficient */
	pprintf(23, 22, "%s", relative_interval_to_string(ppi->asymmetryCorrectionPortDS.scaledDelayCoefficient));
	/* fpa */
	pprintf(23, 51, "%Lu", ppi->asymmetryCorrectionPortDS.scaledDelayCoefficient); /* print as unsigned! */

	/* ingressLatency */
	pprintf(24, 20, "%20s ns", interval_to_string(ppi->timestampCorrectionPortDS.ingressLatency));
	/* egressLatency */
	pprintf(25, 20, "%20s ns", interval_to_string(ppi->timestampCorrectionPortDS.egressLatency));
	/* semistaticLatency */
	pprintf(26, 20, "%20s ns", interval_to_string(ppi->timestampCorrectionPortDS.semistaticLatency));

	/*if (0) {
		cprintf(C_BLUE, "Fiber asymmetry:   ");
		cprintf(C_WHITE, "%.3f nsec\n",
			ss.fiber_asymmetry/1000.0);
	}*/

	/* offsetFromMaster */
	pprintf(27, 20, "%20s ns", interval_to_string (ppg->currentDS->offsetFromMaster));
	row_offset = 28;
	if (wrh_servo) {
		/* Phase setpoint */
		pprintf(28, 20, "%20s ns", convert_ps_to_str_ns(buf, (int64_t) wrh_servo->cur_setpoint_ps));


		/* Skew */
		pprintf(29, 20, "%20s ns", convert_ps_to_str_ns(buf, wrh_servo->skew_ps));
		row_offset += 2;
	}

	 /* Update counter */
	pprintf(row_offset, 24, "%16u times", ppi->servo->update_count);
#if CONFIG_HAS_EXT_WR
	if (wr_servo_ext) {
		/* Master PHY delays TX */
		pprintf(31, 26, "%22s", optimized_pp_time_toString_ps_as_ns(&wr_servo_ext->delta_txm, buf));
		cprintf(C_BLUE, "  RX:");
		/* print and clear till the end of a line */
		cprintf(C_WHITE,"%22s\e[K", optimized_pp_time_toString_ps_as_ns(&wr_servo_ext->delta_rxm, buf));

		/* Slave  PHY delays TX */
		pcprintf(32, 26, C_WHITE,"%22s", optimized_pp_time_toString_ps_as_ns(&wr_servo_ext->delta_txs, buf));
		cprintf(C_BLUE, "  RX:");
		/* print and clear till the end of a line */
		cprintf(C_WHITE,"%22s\e[K", optimized_pp_time_toString_ps_as_ns(&wr_servo_ext->delta_rxs, buf));
	}
#endif
}

void redraw_gui(void)
{
	prev_gui_description = 0;
	next_update_ticks = 0;
}


int wrc_mon_gui(void)
{
	static uint32_t last_servo_count;
	uint32_t now;
	struct pp_servo *s = SRV(ppg->pp_instances);

	/* print new values only if time elapsed or servo's update_count
	 * increased */
	if (prev_gui_description != gui_description) {
		term_clear();
		if (gui_description & DESCRIPTION_MAIN) {
			print_main_description();
		}
		if (gui_description & DESCRIPTION_SERVO) {
			print_servo_description();
		}
		next_update_ticks = 0;
		term_clear_to_end();
		prev_gui_description = gui_description;
		return 1;
	}

	/* update on timeout or servo update */
	now = timer_get_tics();
	if (time_before(now, next_update_ticks)
	    && last_servo_count == s->update_count)
		return 0;

	next_update_ticks = now + wrc_ui_refperiod;
	last_servo_count = s->update_count;
	prev_gui_description = gui_description;
	gui_description = DESCRIPTION_MAIN;
	print_main_data();

	/* Print servo */
	/* FIXME: add support of multiple instances */
	print_servo_data(ppg->pp_instances);
	print_aux_data();
	/* clear colors */
	pp_printf("\e[m\n");
	/* clear till the end of a screen */
	term_clear_to_end();

	return 1;
}
