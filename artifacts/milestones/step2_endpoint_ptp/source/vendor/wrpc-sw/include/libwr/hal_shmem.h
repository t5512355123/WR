/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __LIBWR_HAL_SHMEM_H__
#define __LIBWR_HAL_SHMEM_H__


/* Port delay calibration parameters */
typedef struct hal_port_calibration {
	/* alpha as relativeDifference */
	int64_t alpha;

	/* bit slide expressed in picos */
	uint32_t bitslide_ps;

	int delta_tx_ps; /* "delta" of this SFP type WRT calibration type */
	int delta_rx_ps;
} hal_port_calibration_t;

/* Internal port state structure */
struct wrc_port_state {
	/* MAC addr */
	uint8_t hw_addr[6];

	/* 1: PLL is locked to this port */
	int locked;

	/* calibration data */
	hal_port_calibration_t calib;

	/* current DMTD loopback phase (ps) and whether is it valid or not */
	uint32_t phase_val;
	int phase_val_valid;

	/* locking FSM state */
	int lock_state;

	/*reference lock period in picoseconds*/
	uint32_t clock_period;

	/* approximate DMTD phase value (on slave port) at which RX timestamp
	 * (T2) counter transistion occurs (picoseconds) */
	uint32_t t2_phase_transition;

	/* approximate phase value (on master port) at which RX timestamp (T4)
	 * counter transistion occurs (picoseconds) */
	uint32_t t4_phase_transition;
};

#endif /*  __LIBWR_HAL_SHMEM_H__ */
