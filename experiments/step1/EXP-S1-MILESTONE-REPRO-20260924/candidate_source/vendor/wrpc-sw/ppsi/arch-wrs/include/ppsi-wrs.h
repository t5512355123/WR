/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released to the public domain
 */

/*
 * These are the functions provided by the various wrs files
 */

#include <minipc.h>
#include <hw-specific/wrh.h>
#include "libwr/shmem.h"
#include <libwr/hal_shmem.h>
#include <ppsi/timeout_def.h>


#define WRS_NUMBER_PHYSICAL_PORTS 18 /* Number of physical ports on a WR switch */

extern struct minipc_ch *hal_ch;
extern struct minipc_ch *ppsi_ch;
extern struct hal_port_state *hal_ports;
extern int hal_nports;
extern struct hal_shmem_header *hal_shmem;


static inline struct hal_port_state *pp_wrs_lookup_port(char *name)
{
	int i;

	for (i = 0; i < hal_nports; i++)
		if (hal_ports[i].in_use &&!strcmp(name, hal_ports[i].name))
                        return hal_ports + i;
	return NULL;
}

#define DEFAULT_TO 200000 /* ms */

#define POSIX_ARCH(ppg) ((struct unix_arch_data *)(ppg->arch_glbl_data))
struct unix_arch_data {
	struct timeval tv;
};

typedef struct  wrs_arch_data_t {
	struct unix_arch_data unix_data; // Must be kept at first position
	wrh_timing_mode_locking_state_t timingModeLockingState; /* Locking state for PLL */
	wrh_timing_mode_t timingMode; /* Timing mode: Grand master, Free running,...*/
	int gmUnlockErr; /* Error counter: Give the number of time the PLL was unlocked in GM mode */
}wrs_arch_data_t;

static inline wrs_arch_data_t *WRS_ARCH_I(struct pp_instance *ppi)
{
	return (wrs_arch_data_t *) GLBS(ppi)->arch_glbl_data;
}

static inline wrs_arch_data_t *WRS_ARCH_G(struct pp_globals *ppg)
{
	return (wrs_arch_data_t *) ppg->arch_glbl_data;
}

extern void wrs_main_loop(struct pp_globals *ppg);

extern void wrs_init_ipcserver(struct minipc_ch *ppsi_ch);

/* wrs-calibration.c */
int wrs_read_calibration_data(struct pp_instance *ppi, TimeInterval *scaledBitSlide,
		RelativeDifference *scaledDelayCoefficient,
		TimeInterval *scaledSfpDeltaTx, TimeInterval *scaledSfpDeltaRx);
int32_t wrs_get_clock_period(void);

/* wrs-startup.c */
void enable_asymmetryCorrection(struct pp_instance *ppi, Boolean enable );

/* wrs-time.c (some should moce to wrs-spll.c) */
void wrs_init_rts_addr(uint32_t addr,const char *devname);
int wrs_locking_enable(struct pp_instance *ppi);
int wrs_locking_poll(struct pp_instance *ppi);
int wrs_locking_disable(struct pp_instance *ppi);
int wrs_locking_reset(struct pp_instance *ppi);
int wrs_enable_ptracker(struct pp_instance *ppi);
int wrs_adjust_in_progress(void);
int wrs_adjust_counters(int64_t adjust_sec, int32_t adjust_nsec);
int wrs_adjust_phase(int32_t phase_ps);
int wrs_enable_timing_output(struct pp_globals *,int enable);
int wrs_get_timing_mode(struct pp_globals *, wrh_timing_mode_t *tm);
int wrs_get_timing_mode_state(struct pp_globals *,wrh_timing_mode_pll_state_t *state);
int wrs_set_timing_mode(struct pp_globals *,wrh_timing_mode_t tm);
int wrs_update_port_info(struct pp_globals *ppg);

/* Default value if not set by hal */
#define HAL_REF_CLOCK_PERIOD_PS        1600
#define HAL_DEF_T2_PHASE_TRANS         0
