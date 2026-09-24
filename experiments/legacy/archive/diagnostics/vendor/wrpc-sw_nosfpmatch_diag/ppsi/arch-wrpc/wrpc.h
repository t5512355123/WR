/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#ifndef __WRPC_H
#define __WRPC_H

#include <ppsi/ppsi.h>
#include <libwr/hal_shmem.h>

#define LOCK_TIMEOUT_FM (20 * TICS_PER_SECOND)
#define LOCK_TIMEOUT_GM (60 * TICS_PER_SECOND)

/* This part is exactly wrpc-sw::wrc_ptp.h */
#define WRC_MODE_UNKNOWN 0
#define WRC_MODE_GM 1
#define WRC_MODE_MASTER 2
#define WRC_MODE_SLAVE 3
#define WRC_MODE_ABSCAL 4

int wrc_ptp_init(void);
int wrc_ptp_set_mode(int mode);
int wrc_ptp_get_mode(void);
int wrc_ptp_set_prio1(int prio1);
int wrc_ptp_set_prio2(int prio2);
int wrc_ptp_set_domain_number(int domain);
int wrc_ptp_set_clock_class(int clock_class);
int wrc_ptp_set_clock_accuracy(int clock_accuracy);
int wrc_ptp_set_clock_allan_variance(int clock_allan_variance);
int wrc_ptp_set_time_source(int time_source);
int wrc_ptp_sync_mech(int e2e_p2p_qry);
int wrc_ptp_start(void);
int wrc_ptp_stop(void);
int wrc_ptp_run(int start_stop_qry);
int wrc_ptp_update(void);
/* End of wrc-ptp.h */

extern const struct pp_network_operations wrpc_net_ops;
extern const struct pp_time_operations wrpc_time_ops;

/* other network stuff, bah.... */

struct wrpc_ethhdr {
	unsigned char	h_dest[6];
	unsigned char	h_source[6];
	uint16_t	h_proto;
} __attribute__((packed));

typedef struct  wrpc_arch_data_t {
	wrh_timing_mode_t timingMode; /* Timing mode: Grand master, Free running,...*/
	/* Keep a copy of configured mode for dump */
	int wrpcModeCfg; /* Mode: Grand master, master, slave, abscal */
} wrpc_arch_data_t;

/* values mapped to pp_globals->pp_runtime_opts->forcePpsGen */
typedef enum {
	pps_force_off,
	pps_force_on,
	pps_force_check
} wrpc_pps_force_t;

extern struct pp_globals *const ppg;
/* wrpc-spll.c (some should move to time-wrpc/) */
int wrpc_spll_locking_enable(struct pp_instance *ppi);
int wrpc_spll_locking_poll(struct pp_instance *ppi);
int wrpc_spll_locking_disable(struct pp_instance *ppi);
int wrpc_spll_locking_reset(struct pp_instance *ppi);
int wrpc_spll_enable_ptracker(struct pp_instance *ppi);
int wrpc_adjust_in_progress(void);
int wrpc_adjust_counters(int64_t adjust_sec, int32_t adjust_nsec);
int wrpc_adjust_phase(int32_t phase_ps);
int wrpc_enable_timing_output(struct pp_globals *ppg, int enable);
int wrpc_spll_check_lock_with_timeout(int lock_timeout);
int wrc_ptp_bmc_update(void);
int wrc_ptp_link_down(void);
int wrc_pps_force(wrpc_pps_force_t action);
int wrpc_get_GM_lock_state(struct pp_globals *ppg, pp_timing_mode_state_t *state);




/* wrpc-calibration.c */
int wrpc_read_calibration_data(struct pp_instance *ppi,
			       TimeInterval *scaledBitSlide,
			       RelativeDifference *scaledDelayCoefficient,
			       TimeInterval *scaledSfpDeltaTx,
			       TimeInterval *scaledSfpDeltaRx);


int32_t wrpc_get_clock_period(void);

static inline wrpc_arch_data_t *WRPC_ARCH_I(struct pp_instance *ppi)
{
	return (wrpc_arch_data_t *) GLBS(ppi)->arch_glbl_data;
}

static inline wrpc_arch_data_t *WRPC_ARCH_G(struct pp_globals *ppg)
{
	return (wrpc_arch_data_t *) ppg->arch_glbl_data;
}

static inline void wrc_ptp_get_leapsec(int *ptp, int *system)
{
	int tmp;
	*ptp = ppg->timePropertiesDS->currentUtcOffset;
	TOPS(INST(ppg, 0))->get_utc_offset(NULL, system, &tmp, &tmp);
	return;
}

static inline void wrc_ptp_set_leapsec(int leapsec)
{
	TOPS(INST(ppg, 0))->set_utc_offset(NULL, leapsec, 0, 0);
}

int wrc_ptp_is_abscal(void);

extern struct pp_globals ppg_static;
extern struct pp_instance ppi_static;

#endif /* __WRPC_H */
