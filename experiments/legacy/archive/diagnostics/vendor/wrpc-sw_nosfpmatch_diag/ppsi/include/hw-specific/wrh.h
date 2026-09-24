/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 * Declarations common to WR switches and nodes.
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __WRH_H__
#define __WRH_H__

/* Please increment WRS_PPSI_SHMEM_VERSION if you change any exported data structure */
#define WRS_PPSI_SHMEM_VERSION 36

/* Don't include the Following when this file is included in assembler. */
#ifndef __ASSEMBLY__
#include <stdint.h>
#include <ppsi/lib.h>

/* White Rabbit softpll status values */
#define WRH_SPLL_ERROR		  -1
#define WRH_SPLL_OK		   0
#define WRH_SPLL_LOCKED		   0
#define WRH_SPLL_UNLOCKED  	   1

/* White Rabbit calibration defines */
#define WRH_HW_CALIB_OK		0
#define WRH_HW_CALIB_ERROR	-1

#define FIX_ALPHA_FRACBITS 40
#define FIX_ALPHA_FRACBITS_AS_FLOAT 40.0

typedef enum {
	WRH_TM_LOCKING_STATE_NONE=0,
	WRH_TM_LOCKING_STATE_LOCKING,
	WRH_TM_LOCKING_STATE_LOCKED,
	WRH_TM_LOCKING_STATE_HOLDOVER,
	WRH_TM_LOCKING_STATE_ERROR
}wrh_timing_mode_locking_state_t;


typedef enum {
	WRH_TM_PLL_STATE_LOCKED,
	WRH_TM_PLL_STATE_UNLOCKED,
	WRH_TM_PLL_STATE_HOLDOVER
}wrh_timing_mode_pll_state_t;

typedef enum {
	WRH_TM_GRAND_MASTER=0,
	WRH_TM_FREE_MASTER,
	WRH_TM_BOUNDARY_CLOCK,
	WRH_TM_DISABLED
}wrh_timing_mode_t;


#define WRH_SERVO_OFFSET_STABILITY_THRESHOLD 60 /* psec */

/* White Rabbit hw-dependent functions (code in arch-wrpc and arch-wrs) */
struct wrh_operations {
	int (*locking_enable)(struct pp_instance *ppi);
	int (*locking_poll)(struct pp_instance *ppi);
	int (*locking_disable)(struct pp_instance *ppi);
	int (*locking_reset)(struct pp_instance *ppi);
	int (*enable_ptracker)(struct pp_instance *ppi);

	int (*adjust_in_progress)(void);
	int (*adjust_counters)(int64_t adjust_sec, int32_t adjust_nsec);
	int (*adjust_phase)(int32_t phase_ps);

	int32_t (*get_clock_period)(void);
	int (*get_timing_mode)(struct pp_globals *,wrh_timing_mode_t *state);
	int (*get_timing_mode_state)(struct pp_globals *, wrh_timing_mode_pll_state_t *state);
	int (*set_timing_mode)(struct pp_globals *, wrh_timing_mode_t tm);
};

extern const struct wrh_operations wrh_oper;

static inline const struct wrh_operations *WRH_OPER(void)
{
	return &wrh_oper;
}


/****************************************************************************************/
/* wrh_servo interface */

/* Servo state */
typedef enum {
	WRH_UNINITIALIZED = 0,
	WRH_SYNC_TAI,
	WRH_SYNC_NSEC,
	WRH_SYNC_PHASE,
	WRH_TRACK_PHASE,
	WRH_WAIT_OFFSET_STABLE,
}wrh_servo_state_t;


#define WRH_SERVO_RESET_DATA_SIZE        (sizeof(wrh_servo_t)-offsetof(wrh_servo_t,clock_period_ps))
#define WRH_SERVO_RESET_DATA(servo)      memset(&servo->clock_period_ps,0,WRH_SERVO_RESET_DATA_SIZE);


typedef struct wrh_servo_t {
	/* Values used by snmp. Values are increased at servo update when
	 * erroneous condition occurs. */
	uint32_t n_err_state;
	uint32_t n_err_offset;
	uint32_t n_err_delta_rtt;

	int32_t cur_setpoint_ps;

	/* ----- All data after this line will cleared during a servo reset */

	/* These fields are used by servo code, after setting at init time */
	int32_t clock_period_ps;

	Boolean tracking_enabled;
	Boolean readyForSync; /* Ready for synchronization */
	Boolean doRestart; /* PLL is unlocked: A restart of the calibration is needed */

	/* Following fields are for monitoring/diagnostics (use w/ shmem) */
	int64_t delayMM_ps;
	int64_t delayMS_ps;
	int64_t skew_ps;
	int64_t offsetMS_ps;

	/* These fields are used by servo code, across iterations */
	int64_t prev_delayMS_ps;
	int missed_iters;
} wrh_servo_t;

static inline wrh_servo_t *WRH_SRV(struct pp_instance *ppi)
{
	return (wrh_servo_t *)ppi->ext_data;
}


/* Prototypes */
extern void    wrh_servo_enable_tracking(int enable);
extern int     wrh_servo_init(struct pp_instance *ppi);
extern void    wrh_servo_reset(struct pp_instance *ppi);
extern int     wrh_servo_got_sync(struct pp_instance *ppi);
extern int     wrh_servo_got_resp(struct pp_instance *ppi);
extern int     wrh_servo_got_presp(struct pp_instance *ppi);


#endif /* __ASSEMBLY__ */
#endif /* __WRH_H__ */
