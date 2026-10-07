#include <sys/types.h>
#include <ppsi/ppsi.h>
#include <softpll_ng.h>
#include <sfp.h>
#include <wrc_global.h>
#include <sensors.h>

#include <wrc.h>
#include <wrpc.h>

#include "dump-info.h"
#include "dump-info_ppsi.h"

struct dump_info  dump_wrpc_info[] = {
#undef DUMP_STRUCT
#define DUMP_STRUCT struct wrc_global
	DUMP_HEADER("wrc_global"),
	DUMP_FIELD(uint32_t, magic),
	DUMP_FIELD(uint32_t, version),
	DUMP_FIELD(pointer, global_link),
	DUMP_FIELD(int, task_list_max),
	DUMP_FIELD(pointer, task_list),
	DUMP_FIELD(int, temp_group_list_max),
	DUMP_FIELD(pointer, temp_group_list),
	DUMP_FIELD(pointer, config),
	DUMP_FIELD(pointer, softpll),
	DUMP_FIELD(pointer, pll_fifo),
	DUMP_FIELD(pointer, sfp_info),

#undef DUMP_STRUCT
#define DUMP_STRUCT struct wrc_global_link
	DUMP_HEADER("wrc_global_link"),
	DUMP_FIELD(uint32_t, version),
	DUMP_FIELD_SIZE(char, wrc_hw_name, HW_NAME_LENGTH),
	DUMP_FIELD(link_up_status, link_up),
	DUMP_FIELD(uint16_t, vlan),
	DUMP_FIELD(ip_addr_status, ip_state),
	DUMP_FIELD(ip_address, ip_addr),
	DUMP_FIELD_SIZE(bina, mac_addr, ETH_ALEN),

#undef DUMP_STRUCT
#define DUMP_STRUCT struct wrc_task
	/* Save the size of the structure, there is no other way to pass
	 * the size of wrc_task structure */
	DUMP_HEADER_SIZE("wrc_task", sizeof(struct wrc_task)),
	DUMP_FIELD(int, used),
	DUMP_FIELD_SIZE(char, name, 16),
	DUMP_FIELD(pointer, enabled), /* pointer to a function */
	DUMP_FIELD(pointer, init), /* pointer to a function */
	DUMP_FIELD(pointer, job), /* pointer to a function */
	DUMP_FIELD(unsigned_long, nrun),
	DUMP_FIELD(unsigned_long, seconds),
	DUMP_FIELD(unsigned_long, nanos),
	DUMP_FIELD(unsigned_long, max_run_ticks), /* in ticks */

#undef DUMP_STRUCT
#define DUMP_STRUCT struct wrc_sensor
	/* Save the size of the structure, there is no other way to pass
	 * the size of wrc_task structure */
	DUMP_HEADER_SIZE("wrc_sensor", sizeof(struct wrc_sensor)),
	DUMP_FIELD(pointer, name),
	DUMP_FIELD(uint8_t, flags),
	DUMP_FIELD(uint8_t, id),
	DUMP_FIELD(uint16_t, value),

#undef DUMP_STRUCT
#define DUMP_STRUCT struct softpll_state

	DUMP_HEADER("struct_softpll"),
	DUMP_FIELD(spll_mode, mode),
	DUMP_FIELD(int, seq_state),
	DUMP_FIELD(int, dac_timeout),
	DUMP_FIELD(int, delock_count),
	DUMP_FIELD(uint32_t, irq_count),
	DUMP_FIELD(int, mpll_shift_ps),
	DUMP_FIELD(int, helper.p_adder),
	DUMP_FIELD(int, helper.p_setpoint),
	DUMP_FIELD(int, helper.tag_d0),
	DUMP_FIELD(int, helper.ref_src),
	DUMP_FIELD(int, helper.sample_n),
	/* FIXME: missing helper.pi etc.. */
	DUMP_FIELD(yes_no, ext.enabled),
	DUMP_FIELD(int, ext.align_state),
	DUMP_FIELD(int, ext.align_timer),
	DUMP_FIELD(int, ext.align_target),
	DUMP_FIELD(int, ext.align_step),
	DUMP_FIELD(int, ext.align_shift),
	DUMP_FIELD(int, mpll.state),
	/* FIXME: mpll.pi etc */
	DUMP_FIELD(int, mpll.adder_ref),
	DUMP_FIELD(int, mpll.adder_out),
	DUMP_FIELD(int, mpll.tag_ref),
	DUMP_FIELD(int, mpll.tag_out),
	DUMP_FIELD(int, mpll.tag_ref_d),
	DUMP_FIELD(int, mpll.tag_out_d),
	DUMP_FIELD(int, mpll.phase_shift_target),
	DUMP_FIELD(int, mpll.phase_shift_current),
	DUMP_FIELD(int, mpll.id_ref),
	DUMP_FIELD(int, mpll.id_out),
	DUMP_FIELD(int, mpll.sample_n),
	DUMP_FIELD(int, mpll.dac_index),
	DUMP_FIELD(yes_no, mpll.enabled),

#undef DUMP_STRUCT
#define DUMP_STRUCT struct spll_fifo_log

	DUMP_HEADER_SIZE("struct_pll_fifo", sizeof(struct spll_fifo_log)),
	DUMP_FIELD(uint32_t, trr),
	DUMP_FIELD(uint32_t, tstamp),
	DUMP_FIELD(uint32_t, duration),
	DUMP_FIELD(uint16_t, irq_count),
	DUMP_FIELD(uint16_t, tag_count),
	/* FIXME: aux_state and ptracker_state -- variable-len arrays */

#undef DUMP_STRUCT
#define DUMP_STRUCT struct spll_stats

	DUMP_HEADER("stats"),
	DUMP_FIELD(uint32_t, magic),
	DUMP_FIELD(int, ver),
	DUMP_FIELD(int, sequence),
	DUMP_FIELD(spll_mode, mode),
	DUMP_FIELD(int, irq_cnt),
	DUMP_FIELD(int, seq_state),
	DUMP_FIELD(int, align_state),
	DUMP_FIELD(int, H_lock),
	DUMP_FIELD(int, M_lock),
	DUMP_FIELD(int, H_y),
	DUMP_FIELD(int, M_y),
	DUMP_FIELD(int, del_cnt),
	DUMP_FIELD(int, start_cnt),
#if CONFIG_ARCH_IS_WRS
	DUMP_FIELD_SIZE(char, commit_id, 32),
	DUMP_FIELD_SIZE(char, build_date, 16),
	DUMP_FIELD_SIZE(char, build_time, 16),
	DUMP_FIELD_SIZE(char, build_by, 32),
#endif

#undef DUMP_STRUCT
#define DUMP_STRUCT struct sfp_info

	DUMP_HEADER("struct_sfp_info"),
	DUMP_FIELD(uint32_t, version),
	DUMP_FIELD_SIZE(char, sfp_params.pn, SFP_PN_LEN),
	DUMP_FIELD(RelativeDifference, sfp_params.alpha),
	DUMP_FIELD(sfp_dump_delta, sfp_params.dTx),
	DUMP_FIELD(sfp_dump_delta, sfp_params.dRx),
	DUMP_FIELD(sfp_in_db, sfp_in_db),
	DUMP_FIELD(pointer, sfp_header),
	DUMP_FIELD(pointer, sfp_dom),


#undef DUMP_STRUCT
#define DUMP_STRUCT struct shw_sfp_header

	DUMP_HEADER("shw_sfp_header"),
	DUMP_FIELD_SIZE(bina, id, 1),
	DUMP_FIELD_SIZE(bina, ext_id, 1),
	DUMP_FIELD_SIZE(bina, connector, 1),
	DUMP_FIELD_SIZE(bina, transciever, 8),
	DUMP_FIELD_SIZE(bina, encoding, 1),
	DUMP_FIELD(sfp_br_nom, br_nom),
	// uint8_t reserved1;
	DUMP_FIELD(sfp_length1, length1),	/* Link length supported for 9/125 mm fiber (km) */
	DUMP_FIELD(sfp_length2, length2),	/* Link length supported for 9/125 mm fiber (100m) */
	DUMP_FIELD(sfp_length3, length3),	/* Link length supported for 50/125 mm fiber (10m) */
	DUMP_FIELD(sfp_length4, length4),	/* Link length supported for 62.5/125 mm fiber (10m) */
	DUMP_FIELD(sfp_length5, length5),	/* Link length supported for copper (1m) */
	DUMP_FIELD(sfp_length6, length6),	/* Link length supported on OM3 (1m) */
	DUMP_FIELD_SIZE(char, vendor_name, 16),
	DUMP_FIELD_SIZE(bina, transceiver, 1),	/* This is now a field named transceiver */
	DUMP_FIELD_SIZE(bina, vendor_oui, 3),
	DUMP_FIELD_SIZE(char, vendor_pn, 16),
	DUMP_FIELD_SIZE(char, vendor_rev, 4),
	DUMP_FIELD(uint16_t, tx_wavelength),
	// 	uint8_t reserved4;
	// 	uint8_t cc_base; /* checksum addr 0-62 */

	/* extended ID fields start here */
	DUMP_FIELD_SIZE(bina, options, 2),
	DUMP_FIELD_SIZE(bina, br_max, 1),
	DUMP_FIELD_SIZE(bina, br_min, 1),
	DUMP_FIELD_SIZE(char, vendor_serial, 16),
	DUMP_FIELD_SIZE(char, date_code, 8),
	DUMP_FIELD(sfp_diag_mon_type, diagnostic_monitoring_type),
	DUMP_FIELD_SIZE(bina, enhanced_options, 1),
	DUMP_FIELD_SIZE(bina, sff_8472_compliance, 1),
	// 	uint8_t cc_ext;/* checksum addr 64-94 */


#undef DUMP_STRUCT
#define DUMP_STRUCT struct shw_sfp_dom

	DUMP_HEADER("shw_sfp_dom"),
	/* Treshold values, 0 - 55 */
// 	DUMP_FIELD_SIZE(sfp_temp, temp_high_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_temp, temp_low_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_temp, temp_high_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_temp, temp_low_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_vcc, volt_high_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_vcc, volt_low_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_vcc, volt_high_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_vcc, volt_low_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_bias, bias_high_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_bias, bias_low_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_bias, bias_high_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_bias, bias_low_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_pow, tx_pow_high_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_pow, tx_pow_low_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_pow, tx_pow_high_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_tx_pow, tx_pow_low_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_rx_pow, rx_pow_high_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_rx_pow, rx_pow_log_alarm, 2),
// 	DUMP_FIELD_SIZE(sfp_rx_pow, rx_pow_high_warn, 2),
// 	DUMP_FIELD_SIZE(sfp_rx_pow, rx_pow_low_warn, 2),
// 	DUMP_FIELD_SIZE(bina, unalloc0, 16),
// 	// /* Calibration data, 56-91 */
// 	DUMP_FIELD_SIZE(bina, cal_rx_pwr4, 4),
// 	DUMP_FIELD_SIZE(bina, cal_rx_pwr3, 4),
// 	DUMP_FIELD_SIZE(bina, cal_rx_pwr2, 4),
// 	DUMP_FIELD_SIZE(bina, cal_rx_pwr1, 4),
// 	DUMP_FIELD_SIZE(bina, cal_rx_pwr0, 4),
// 	DUMP_FIELD_SIZE(bina, cal_tx_i_slope, 2),
// 	DUMP_FIELD_SIZE(bina, cal_tx_i_offset, 2),
// 	DUMP_FIELD_SIZE(bina, cal_tx_pow_slope, 2),
// 	DUMP_FIELD_SIZE(bina, cal_tx_pow_offset, 2),
// 	DUMP_FIELD_SIZE(bina, cal_T_slope, 2),
// 	DUMP_FIELD_SIZE(bina, cal_T_offset, 2),
// 	DUMP_FIELD_SIZE(bina, cal_V_slope, 2),
// 	DUMP_FIELD_SIZE(bina, cal_V_offset, 2),
// 	// /* Unallocated and checksum, 92-95 */
// 	DUMP_FIELD_SIZE(bina, cal_unalloc, 3),
// 	DUMP_FIELD_SIZE(bina, CC_DMI, 1),
	// /* Real Time Diagnostics, 96-111 */
	DUMP_FIELD_SIZE(sfp_temp, temp, 2),
	DUMP_FIELD_SIZE(sfp_vcc, vcc, 2),
	DUMP_FIELD_SIZE(sfp_tx_bias, tx_bias, 2),
	DUMP_FIELD_SIZE(sfp_tx_pow, tx_pow, 2),
	DUMP_FIELD_SIZE(sfp_rx_pow, rx_pow, 2),
// 	DUMP_FIELD_SIZE(bina, rtd_unalloc0, 4),
// 	DUMP_FIELD_SIZE(bina, OSCB, 1),
// 	DUMP_FIELD_SIZE(bina, rtd_unalloc1, 1),
// 	// /* Alarms and Warnings, 112 - 117 */
// 	DUMP_FIELD_SIZE(bina, alw, 6),
// 	// /* Extended Module Control/Status bytes 118 - 119 */
// 	DUMP_FIELD_SIZE(bina, emcsb, 2),
// 	// /* Vendor locations 120 - 127 */
// 	DUMP_FIELD_SIZE(bina, vendor_locations, 8),
// 	// /* User data 128 - 247 */
// 	DUMP_FIELD_SIZE(bina, dom_user, 120),
// 	// /* Vendor specific control function locations 248 - 255 */
// 	DUMP_FIELD_SIZE(bina, vendor_functions, 8),

	DUMP_HEADER("end"),

};
