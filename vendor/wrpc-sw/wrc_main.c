/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011,2012 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <inttypes.h>
#include <stdarg.h>

#include "wrc.h"
#include "dev/w1.h"
#include "dev/syscon.h"
#include "dev/console.h"
#include "dev/endpoint.h"
#include "dev/minic.h"
#include "dev/pps_gen.h"
#include "dev/gpio.h"
#include "dev/simple_uart.h"
#include "dev/netif.h"
#include "net.h"
#include "dev/i2c.h"
#include "storage.h"
#include "softpll_ng.h"
#include "dev/pps_gen.h"
#include "shell.h"
#include "lib/ipv4.h"
#include "lib/events-ptp.h"
#include "dev/rxts_calibrator.h"
#include "dev/flash.h"
#include "dev/gpio.h"
#include "netconsole.h"
#include "dev/wdiags.h"

#include "wrpc.h"
#include "system_checks.h"
#include "ppsi/ppsi.h"
#include "wrc_global.h"
#include "dev/w1.h"
#include "dev/temp-fake.h"
#include "dev/temp-w1.h"
#include "dev/temperature.h"
#include "sensors.h"

#include "board.h"

#ifdef CONFIG_DAC_LOG
#include "dev/dac_log.h"
#endif

#ifdef CONFIG_LATENCY_PROBE
#include "lib/latency.h"
#endif

#ifdef CONFIG_LLDP
#include "lib/lldp.h"
#endif

struct wr_endpoint_device wrc_endpoint_dev;

/* CPU-local marker used when the external diagnostics RAM is unavailable. */
/* Keep the marker at the fixed linker section observed by the JTAG wrapper. */
volatile uint32_t debug_boot_stage
	__attribute__((used, section(".debug_boot")));

int wrc_wr_diags(void); // fixme: move the header

extern char _binary__config_bin_start[];
extern struct spll_fifo_log fifo_log[];

struct wrc_global_link wrc_global_link = {
	.version = WRC_G_LINK_VERSION,
	.vlan = CONFIG_VLAN_NR,
	.ip_state = IP_TRAINING,
};

const struct wrc_global wrc_global = {
	.magic = WRC_G_MAGIC,
	.version = WRC_G_VERSION,
	.global_link = &wrc_global_link,
	.task_list_max = WRC_MAX_TASKS,
	.task_list = tasks,
	.temp_group_list_max = WRC_MAX_TEMPERATURES,
#ifdef CONFIG_TEMP_SENSORS
	.temp_group_list = temp_sensors,
#endif
	.softpll = &softpll,
#ifdef CONFIG_SPLL_FIFO_LOG
	.pll_fifo = fifo_log,
#endif
#ifdef CONFIG_CMD_CONFIG
	.config = _binary__config_bin_start,
#endif
	.sfp_info = &sfp_info,
};

static void wrc_initialize(void)
{
	/* Diagnostic-only boot markers in the existing WRPC diagnostics RAM. */
	#ifdef CONFIG_WR_DIAG
	wdiags_init();
	wdiags_write_temp(0x0000B001);
	#endif

	console_init();
	timer_init(1);
	spll_very_init();
	usleep_init();

	/* Initialize W1 before board, in case mac address is read from it. */
	if (HAS_W1)
		wrc_w1_init();

	wrc_board_early_init();

	#ifdef CONFIG_WR_DIAG
	wdiags_write_temp(0x0000B002);
	#endif

	pp_printf("WR Core: starting up...\n");
	get_hw_name(wrc_global_link.wrc_hw_name);

#ifndef BOARD_HAS_CUSTOM_NETWORK_INIT
	net_rst();
	ep_init( &wrc_endpoint_dev, (void *) BASE_EP );
	netif_register_device(&wrc_endpoint_dev, &minic);
	/* Sleep for 1s to make sure WRS v4.2 always realizes that
	 * the link is down */
	timer_delay_ms(200);
	ep_enable( &wrc_endpoint_dev, 1, 1 );
#endif

	minic_init(&minic, (void *)BASE_MINIC);
	shw_pps_gen_init();

	/* initialize w1 temp sensor.  Note that w1 must have been initialized
	   by board. */
	if (HAS_TEMP_SENSORS && HAS_W1_TEMP)
		temp_w1_init();

	if (HAS_TEMP_SENSORS && HAS_TEMP_FAKE)
		temp_faketemp_init();

	wrc_board_init();

	#ifdef CONFIG_WR_DIAG
	wdiags_write_temp(0x0000B003);
	#endif

	/* BSP didn't load the calibration parameters? go ahead */
	if (!storage_is_calibration_loaded())
		storage_load_calibration();

	wrc_ptp_init();
	/* try reading t24 phase transition from EEPROM */
	calib_t24p_load();
	shell_init();
	shell_register_commands();


	_endram = ENDRAM_MAGIC;

	wrc_ptp_set_mode(WRC_MODE_SLAVE);
	wrc_ptp_start();

	wrc_tasks_accounting_init();
}

static int is_link_up(void)
{
	return link_status == NETIF_LINK_UP;
}

static int wrc_check_link(void)
{
	static int prev_state = 0;
	#ifdef CONFIG_FORCE_MASTER_AFTER_INIT
	static int master_switch_attempted = 0;
	int master_switch_rc;
	#endif
	int state = ep_link_up( &wrc_endpoint_dev, NULL);
	int rv = 0;

	if (!prev_state && state) {
		wrc_verbose("Link up.\n");
		event_post( WRC_EVENT_LINK_UP );
		sfp_match(0);
		#ifdef CONFIG_FORCE_MASTER_AFTER_INIT
		if (!master_switch_attempted) {
			/* Defer the Master transition until the endpoint is link-up. */
			debug_boot_stage = 0xB2000001;
			master_switch_attempted = 1;
			master_switch_rc = wrc_ptp_set_mode(WRC_MODE_MASTER);
			debug_boot_stage = 0xB2000000 |
				((unsigned int)master_switch_rc & 0xffffU);
		}
		#endif
		wrc_ptp_start();
		link_status = NETIF_LINK_WENT_UP;
		rv = 1;
	} else if (prev_state && !state) {
		wrc_verbose("Link down.\n");
		wrc_events_ptp_link_down();
		event_post( WRC_EVENT_LINK_DOWN );
		link_status = NETIF_LINK_WENT_DOWN;
		wrc_ptp_stop();
		wrc_ptp_link_down();
		rv = 1;
	} else
		link_status = (state ? NETIF_LINK_UP : NETIF_LINK_DOWN);

	prev_state = state;

	return rv;
}

static int ui_update(void)
{
	return shell_interactive();
}

/* initialize functions to be called after reset in check_reset function */
void init_hw_after_reset(void)
{
	/* Ok, now init the devices so we can printf and delay */
	console_init();
	timer_init(1);
}


/* count uptime, in seconds, for remote polling */
static uint32_t uptime_lastj;
static void init_uptime(void)
{
	uptime_lastj = timer_get_tics();
}

static int update_uptime(void)
{
	extern uint32_t uptime_sec;
	uint32_t j;
	static uint32_t fraction = 0;

	j = timer_get_tics();
	fraction += j - uptime_lastj;
	uptime_lastj = j;
	if (fraction > TICS_PER_SECOND) {
		fraction -= TICS_PER_SECOND;
		uptime_sec++;
		return 1;
	}
	return 0;
}

static void create_tasks(void)
{
	struct wrc_task *t;

	/* clear task table in case of a reset */
	wrc_tasks_preinit();

	/* create all other tasks */
	wrc_task_create( "idle", NULL, NULL );
	wrc_task_create( "check-link", NULL, wrc_check_link );
	wrc_task_create( "uptime", init_uptime, update_uptime );
	wrc_task_create( "ptp", NULL, wrc_ptp_update);
	wrc_task_create( "ptp_bmc", NULL, wrc_ptp_bmc_update);
	wrc_task_create( "shell+gui", shell_boot_script, ui_update );
	wrc_task_create( "spll-bh", NULL, spll_update );

	if (HAS_TEMP_SENSORS)
		wrc_task_create("temperature", NULL, wrc_temp_refresh);

	t = wrc_task_create( "net-bh", NULL, net_bh_poll );
	wrc_task_set_enable( t, is_link_up );

#ifdef CONFIG_DAC_LOG
	wrc_task_create( "dac-logger", daclog_init, daclog_poll );
#endif

#ifdef CONFIG_IP
	t = wrc_task_create( "arp", arp_init, arp_poll );
	wrc_task_set_enable( t, is_link_up );
	/* Run ipv4 even if link is down. ipv4_poll has to be executed even
	 * on link down to trigger the bootp request when the link is up.
	 * Needed by syslog to track link up */
	wrc_task_create( "ipv4", ipv4_init, ipv4_poll );
#endif

#ifdef CONFIG_LATENCY_PROBE
	wrc_task_create( "latency-probe", latency_init, latency_poll );
#endif

#ifdef CONFIG_LLDP
	t = wrc_task_create( "lldp", lldp_init, lldp_poll );
	wrc_task_set_enable( t, is_link_up );
#endif

#ifdef CONFIG_SNMP
	t = wrc_task_create( "snmp", snmp_init, snmp_poll );
	wrc_task_set_enable( t, is_link_up );
#endif

	wrc_task_create( "stats", NULL, wrc_log_stats );

#ifdef CONFIG_WR_DIAG
	wrc_task_create( "diags", NULL, wrc_wr_diags );
#endif

#ifdef CONFIG_NETCONSOLE
	t = wrc_task_create( "netconsole", netconsole_init, netconsole_poll );
	wrc_task_set_enable( t, is_link_up );
#endif

#ifdef CONFIG_SFP_DOM
	/* Read DOM data from SFP even if the link is down or/and SFP
	 * unplugged */
	wrc_task_create("sfp_dom", NULL, sfp_dom_update);
#endif
}

int main(void) __attribute__ ((weak));
int main(void)
{
	debug_boot_stage = 0x0000B000;
	#ifdef CONFIG_WR_DIAG
	/* Early markers distinguish CPU entry from task/setup failures. */
	wdiags_write_temp(0x0000B000);
	#endif

	check_reset();
	create_tasks();
	debug_boot_stage = 0x0000B00A;
	#ifdef CONFIG_WR_DIAG
	wdiags_write_temp(0x0000B00A);
	#endif
	wrc_board_create_tasks();
	debug_boot_stage = 0x0000B00B;
	#ifdef CONFIG_WR_DIAG
	wdiags_write_temp(0x0000B00B);
	#endif

	wrc_initialize();
	debug_boot_stage = 0x0000B001;

	/* initialization of individual tasks */
	wrc_tasks_run_inits();
	#ifdef CONFIG_FORCE_MASTER_AFTER_INIT
	/* Preserve the shell diagnostic marker when the Master image records it. */
	if ((debug_boot_stage & 0xff000000U) != 0xb1000000U)
		debug_boot_stage = 0x0000B004;
	#else
	debug_boot_stage = 0x0000B004;
	#endif
	#ifdef CONFIG_WR_DIAG
	wdiags_write_temp(0x0000B004);
	#endif

	for (;;) {
		// run all pending tasks
		wrc_poll_all_tasks();
		// call all event handlers
		if (BOARD_USE_EVENTS)
			events_dispatch();
		/* better safe than sorry */
		check_stack();
	}
}
