/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* spll_main.h - the main DDMTD PLL. Locks output clock to any reference
   with programmable phase shift. */

#ifndef __SPLL_MAIN_H
#define __SPLL_MAIN_H

/* State of the Main PLL */
/* NOTE: Please increment WRPC_SHMEM_VERSION if you change this structure */
struct spll_main_state {
	int state;

	spll_pi_t pi;
	spll_lock_det_t phase_ld;
	spll_lock_det_t freq_ld;
	spll_gain_schedule_t* gain_sched;

#ifdef CONFIG_FRAC_SPLL
	int div_cnt;
	int div_fb;
	int div_ref;
	int div_interp;
	int n_ref, n_out;

	int tag_out_raw_d, tag_out_raw;
	int tag_out_interp;
#endif

	int dref_dt, dout_dt, tag_ref_raw_d, tag_out_raw_d2;
	int freq_prelock_gain_boost;
	int discard_early_cnt;
	int adder_ref, adder_out;
	int tag_ref, tag_ref_d;
	int tag_out, tag_out_d;
	int locked; // locked flag
	int phase_shift_target;
	int phase_shift_current;
	int id_ref, id_out;	/* IDs of the reference and the output channel */
	int sample_n;
	int dac_index;
	int enabled;
	int ps_freeze, vco_freeze;
	int dbg_src_id;

	uint32_t lock_start_ms;
	int last_phase_lock_duration_ms;
	int last_freq_lock_duration_ms;
};

void mpll_init(struct spll_main_state *s, int id_ref,
		      int id_out);

void mpll_stop(struct spll_main_state *s);

void mpll_start(struct spll_main_state *s);

int mpll_update(struct spll_main_state *s, int tag, int source);

int mpll_set_phase_shift(struct spll_main_state *s,
				int desired_shift_ps);

int mpll_shifter_busy(struct spll_main_state *s);

int spll_vco_freeze(int freeze);

int spll_pshifter_freeze(int freeze);

#endif // __SPLL_MAIN_H
