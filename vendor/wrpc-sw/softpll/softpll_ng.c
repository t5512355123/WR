/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2015 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdio.h>
#include <string.h>
#include <sys/errno.h>

#include <wrc.h>
#include "board.h"
#include "hw/softpll_regs.h"
#include "hw/pps_gen_regs.h"
#include "dev/wdiags.h"

#include "softpll_ng.h"

#include "irq.h"

#ifdef CONFIG_SPLL_FIFO_LOG
  struct spll_fifo_log fifo_log[FIFO_LOG_LEN];
  #define HAS_FIFO_LOG 1
#else
  #define HAS_FIFO_LOG 0
  extern struct spll_fifo_log fifo_log[];
#endif

unsigned char spll_n_chan_ref, spll_n_chan_out;
unsigned char spll_ljd_present = 0;

static const char * const seq_states[] =
{
	[SEQ_START_EXT] = "start-ext",
	[SEQ_WAIT_EXT] = "wait-ext",
	[SEQ_START_HELPER] = "start-helper",
	[SEQ_WAIT_HELPER] = "wait-helper",
	[SEQ_START_MAIN] = "start-main",
	[SEQ_WAIT_MAIN] = "wait-main",
	[SEQ_DISABLED] = "disabled",
	[SEQ_READY] = "ready",
	[SEQ_CLEAR_DACS] = "clear-dacs",
	[SEQ_WAIT_CLEAR_DACS] = "wait-clear-dacs",
};
#define SEQ_STATES_NR  ARRAY_SIZE(seq_states)

volatile struct softpll_state softpll;
volatile uint32_t wrpc_spll_state_visit_mask;
volatile uint32_t wrpc_spll_state_transition_count;
volatile uint8_t wrpc_spll_last_state;
volatile int32_t wrpc_spll_helper_last_tag;
volatile int32_t wrpc_spll_helper_expected_tag;
volatile int32_t wrpc_spll_helper_preclamp_error;
volatile int32_t wrpc_spll_helper_tag_delta;
volatile int32_t wrpc_spll_helper_tag_source;
volatile int32_t wrpc_spll_helper_expected_delta;
volatile uint32_t wrpc_spll_helper_update_count;
volatile uint32_t wrpc_spll_trr_pop_count;
volatile int32_t wrpc_spll_helper_p_adder;
volatile int32_t wrpc_spll_helper_tag_d0;
volatile int32_t wrpc_spll_helper_p_setpoint;
volatile int32_t wrpc_spll_helper_ref_src;
volatile uint32_t wrpc_spll_helper_measurement_epoch;
volatile int32_t wrpc_spll_helper_measurement_tag_delta;
volatile int32_t wrpc_spll_helper_measurement_expected_delta;
volatile int32_t wrpc_spll_helper_measurement_freq_error;
volatile int32_t wrpc_spll_helper_measurement_preclamp_error;
volatile int32_t wrpc_spll_helper_measurement_error;
volatile uint32_t wrpc_spll_helper_measurement_update_count;
volatile int32_t wrpc_spll_helper_measurement_output;
volatile uint32_t wrpc_spll_helper_measurement_dmtd_ref_accept_count;
volatile uint32_t wrpc_spll_helper_measurement_dmtd_fb_accept_count;
volatile uint32_t wrpc_spll_init_count;
volatile uint32_t wrpc_spll_clear_dacs_entry_count;
volatile uint32_t wrpc_spll_last_init_tics;
volatile uint32_t wrpc_spll_last_clear_dacs_tics;

static inline void wrpc_spll_note_state(int state)
{
	if (state == SEQ_CLEAR_DACS && wrpc_spll_last_state != SEQ_CLEAR_DACS) {
		wrpc_spll_clear_dacs_entry_count++;
		wrpc_spll_last_clear_dacs_tics = timer_get_tics();
	}
	if (state >= 0 && state < 32)
		wrpc_spll_state_visit_mask |= (uint32_t)1u << state;
	wrpc_spll_last_state = (uint8_t)state;
}

static volatile int ptracker_mask = 0;
/* fixme: should be done by spll_init() but spll_init is called to
 * switch modes (and we won't like messing around with ptrackers
 * there) */

static inline int aux_locking_enabled(int channel)
{
	uint32_t occr_aux_en = SPLL_OCCR_OUT_EN_R(SPLL->OCCR);

	return occr_aux_en & (1 << channel);
}

static inline void set_channel_status(int channel, int locked)
{
	if(!locked)
		SPLL->OCCR &= ~(SPLL_OCCR_OUT_LOCK_W((1 << channel)));
	else
		SPLL->OCCR |= (SPLL_OCCR_OUT_LOCK_W((1 << channel)));
}


static inline void start_ptrackers(struct softpll_state *s)
{
	int i;
	for (i = 0; i < spll_n_chan_ref; i++)
		if (ptracker_mask & (1 << i))
			ptracker_start(&s->ptrackers[i]);
}

static inline void update_ptrackers(struct softpll_state *s, int tag_value, int tag_source)
{
	int i;

	/* Ptracker for reference channels */
	if(tag_source <= spll_n_chan_ref)
		ptrackers_update(s->ptrackers, tag_value, tag_source);

	/* Ptracker for auxilliary channels (monitor only) */
	for( i = 0; i < spll_n_chan_out - 1; i++ )
	{
		struct spll_aux_state *aux = &s->aux[i];
		if( aux->mode != SPLL_AUX_MODE_PHASE_MONITOR )
			continue;

		if( tag_source == spll_n_chan_ref + i + 1)
		{
			aux->pll.tracker.dbg_channel = i;
			ptrackers_update( &aux->pll.tracker, tag_value, 0 );
		}
	}
}

static inline void sequencing_fsm(struct softpll_state *s, int tag_value, int tag_source)
{
	int previous_state = s->seq_state;

	if( tag_source == spll_n_chan_ref ) // main osc
		s->tag_count++;
	else if ( tag_source == 0 ) // ref 0
		s->ref_count++;

	switch (s->seq_state) {
		/* State "Disabled". Entered when the whole PLL is off */
		case SEQ_DISABLED:
			break;

		/* State "Clear DACs": initial SPLL sequnencer state. Brings both DACs (not the AUXs) to the default values
		   prior to starting the SPLL. */
		case SEQ_CLEAR_DACS:
		{
			/* Helper always starts at the maximum value (to make sure it locks on positive offset */
			SPLL->DAC_HPLL = s->helper.pi.y_max;

			/* Main starts at midscale */
			SPLL->DAC_MAIN = (s->mpll.pi.y_max + s->mpll.pi.y_min) / 2;

			/* we need tags from at least one channel, so that the IRQ that calls this function
			   gets called again */
			spll_enable_tagger(MAIN_CHANNEL, 1);

			s->dac_timeout = timer_get_tics() + TICS_PER_SECOND / 20;
			s->seq_state = SEQ_WAIT_CLEAR_DACS;

			break;
		}

		/* State "Wait until DACs have been cleared". Makes sure the VCO control inputs have stabilized before starting the PLL. */
		case SEQ_WAIT_CLEAR_DACS:
		{
			if (time_after(timer_get_tics(), s->dac_timeout))
			{
				if(s->mode == SPLL_MODE_GRAND_MASTER)
					s->seq_state = SEQ_START_EXT;
				else
					s->seq_state = SEQ_START_HELPER;
			}
			break;
		}

		/* State "Start external reference PLL": starts up BB PLL for locking local reference to 10 MHz input */
		case SEQ_START_EXT:
		{
			spll_enable_tagger(MAIN_CHANNEL, 0);
			external_start(&s->ext);

			s->seq_state = SEQ_WAIT_EXT;
			break;
		}

		/* State "Wait until we are locked to external 10MHz clock" */
		case SEQ_WAIT_EXT:
		{
			if (external_locked(&s->ext)) {
				start_ptrackers(s);
				s->seq_state = SEQ_READY;
				set_channel_status(s->mpll.id_ref, 1);
			}
			break;
		}

		/* Once the DAC are on and stable, start helper PLL */
		case SEQ_START_HELPER:
		{
			helper_start(&s->helper);

			s->seq_state = SEQ_WAIT_HELPER;
			break;
		}

		case SEQ_WAIT_HELPER:
		{
			if (s->helper.ld.locked && s->helper.ld.lock_changed)
			{
				if (s->mode == SPLL_MODE_SLAVE)
				{
					s->seq_state = SEQ_START_MAIN;
				} else {
					/* Free running master, no need to
					   lock the main clock */
					start_ptrackers(s);
					s->seq_state = SEQ_READY;
					set_channel_status(s->mpll.id_ref, 1);
				}
			}
			break;
		}

		case SEQ_START_MAIN:
		{
			mpll_start(&s->mpll);
			s->seq_state = SEQ_WAIT_MAIN;
			break;
		}

		case SEQ_WAIT_MAIN:
		{
			if (s->mpll.locked)
			{
				start_ptrackers(s);
				s->seq_state = SEQ_READY;
				set_channel_status(s->mpll.id_ref, 1);
			}
			break;
		}

		case SEQ_READY:
		{
			if (s->mode == SPLL_MODE_GRAND_MASTER && !external_locked(&s->ext)) {
				s->delock_count++;
				s->seq_state = SEQ_CLEAR_DACS;
				set_channel_status(s->mpll.id_ref, 0);
			} else if (!s->helper.ld.locked) {
				s->delock_count++;
				s->seq_state = SEQ_CLEAR_DACS;
				set_channel_status(s->mpll.id_ref, 0);
			} else if (s->mode == SPLL_MODE_SLAVE && !s->mpll.locked) {
				s->delock_count++;
				s->seq_state = SEQ_CLEAR_DACS;
				set_channel_status(s->mpll.id_ref, 0);
			}
			break;
		}
	}

	if (s->seq_state != previous_state)
		wrpc_spll_state_transition_count++;
	wrpc_spll_note_state(s->seq_state);
}

static inline void update_loops(struct softpll_state *s, int tag_value, int tag_source)
{

	helper_update(&s->helper, tag_value, tag_source);

	if(s->helper.ld.locked)
	{
		mpll_update(&s->mpll, tag_value, tag_source);

		if(s->seq_state == SEQ_READY) {
			if(s->mode == SPLL_MODE_SLAVE) {
				int i;
				for (i = 0; i < spll_n_chan_out - 1; i++)
					mpll_update(&s->aux[i].pll.dmtd, tag_value, tag_source);
			}

			update_ptrackers(s, tag_value, tag_source);
		}
	}
}

void spll_irq_entry(void)
{
	struct softpll_state *s = (struct softpll_state *)&softpll;
	uint32_t trr;
	int tag_source, tag_value;

	/* check if there are more tags in the FIFO, and log them if so configured to */
	while (!(SPLL->TRR_CSR & SPLL_TRR_CSR_EMPTY)) {
		trr = SPLL->TRR_R0;
		/* Count only after a successful TRR FIFO read. */
		wrpc_spll_trr_pop_count++;

		/* And process the values */
		tag_source = SPLL_TRR_R0_CHAN_ID_R(trr);
		tag_value  = SPLL_TRR_R0_VALUE_R(trr);

		if (0) {
			spll_debug(SPLL_DBG_SRC_RAW, SPLL_DBG_SIGNAL_SRC, tag_source, 0);
			spll_debug(SPLL_DBG_SRC_RAW, SPLL_DBG_SIGNAL_TAG, tag_value, 1);
		}

		sequencing_fsm(s, tag_value, tag_source);
		update_loops(s, tag_value, tag_source);
	}

	s->irq_count++;
	clear_irq();
}

void spll_very_init(void)
{
	PPSG->ESCR = 0;
	PPSG->CR = PPSG_CR_CNT_EN | PPSG_CR_CNT_RST | PPSG_CR_PWIDTH_W(PPS_WIDTH);

	memset( (void *) &softpll, 0, sizeof(struct softpll_state ));
	softpll.mode = SPLL_MODE_DISABLED;
	wrpc_spll_state_visit_mask = 0;
	wrpc_spll_state_transition_count = 0;
	wrpc_spll_last_state = SEQ_DISABLED;
	wrpc_spll_trr_pop_count = 0;
	wrpc_spll_helper_measurement_epoch = 0;
	wrpc_spll_helper_measurement_tag_delta = 0;
	wrpc_spll_helper_measurement_expected_delta = 0;
	wrpc_spll_helper_measurement_freq_error = 0;
	wrpc_spll_helper_measurement_preclamp_error = 0;
	wrpc_spll_helper_measurement_error = 0;
	wrpc_spll_helper_measurement_update_count = 0;
	wrpc_spll_helper_measurement_output = 0;
	wrpc_spll_helper_measurement_dmtd_ref_accept_count = 0;
	wrpc_spll_helper_measurement_dmtd_fb_accept_count = 0;

	uint32_t csr = SPLL->CSR;

	spll_n_chan_ref = SPLL_CSR_N_REF_R(csr);
	spll_n_chan_out = SPLL_CSR_N_OUT_R(csr);

	if( spll_n_chan_out > 3 ) // fixme: bug in HDL?
		spll_n_chan_out = 3;

	softpll.mpll.gain_sched = NULL;


	helper_very_init((struct spll_helper_state *) &softpll.helper); // set up default PI gains/lock thresholds
	
}

void spll_init(int mode, int slave_ref_channel, int flags)
{
	static const char * const modes[] = { "disabled", "grandmaster", "freemaster", "slave"  };
	int dummy;
	int i;

	struct softpll_state *s = (struct softpll_state *) &softpll;

	wrpc_spll_init_count++;
	wrpc_spll_last_init_tics = timer_get_tics();

	disable_irq();

	uint32_t csr = SPLL->CSR;

	spll_n_chan_ref = SPLL_CSR_N_REF_R(csr);
	spll_n_chan_out = SPLL_CSR_N_OUT_R(csr);
	if( spll_n_chan_out > 3 ) // fixme: bug in HDL?
		spll_n_chan_out = 3;
	spll_ljd_present = (flags & SPLL_FLAG_USE_LJD ? 1 : 0);

	s->mode = mode;
	s->delock_count = 0;
	s->ref_count = s->tag_count = 0;
	wrpc_spll_helper_last_tag = 0;
	wrpc_spll_helper_expected_tag = 0;
	wrpc_spll_helper_preclamp_error = 0;
	wrpc_spll_helper_tag_delta = 0;
	wrpc_spll_helper_tag_source = 0;
	wrpc_spll_helper_expected_delta = 0;
	wrpc_spll_helper_update_count = 0;
	wrpc_spll_helper_p_adder = 0;
	wrpc_spll_helper_tag_d0 = 0;
	wrpc_spll_helper_p_setpoint = 0;
	wrpc_spll_helper_ref_src = 0;
	wrpc_spll_helper_measurement_epoch = 0;
	wrpc_spll_helper_measurement_tag_delta = 0;
	wrpc_spll_helper_measurement_expected_delta = 0;
	wrpc_spll_helper_measurement_freq_error = 0;
	wrpc_spll_helper_measurement_preclamp_error = 0;
	wrpc_spll_helper_measurement_error = 0;
	wrpc_spll_helper_measurement_update_count = 0;
	wrpc_spll_helper_measurement_output = 0;
	wrpc_spll_helper_measurement_dmtd_ref_accept_count = 0;
	wrpc_spll_helper_measurement_dmtd_fb_accept_count = 0;

	SPLL->OCER = 0;
	SPLL->RCER = 0;
	SPLL->ECCR = 0;
	SPLL->EIC_IDR = 1;

	SPLL->DAC_HPLL = 0;

	SPLL->CSR = 0;
	SPLL->OCER = 0;
	SPLL->RCER = 0;
	SPLL->ECCR = 0;
	SPLL->OCCR = 0;
#ifndef CONFIG_SPLL_DEGLITCH_THR
#define CONFIG_SPLL_DEGLITCH_THR 1000
#endif
	SPLL->DEGLITCH_THR = CONFIG_SPLL_DEGLITCH_THR;

	PPSG->CR |= PPSG_CR_CNT_EN;

	if(mode == SPLL_MODE_DISABLED)
		s->seq_state = SEQ_DISABLED;
	else
		s->seq_state = SEQ_CLEAR_DACS;
	wrpc_spll_state_visit_mask = 0;
	wrpc_spll_state_transition_count = 0;
	wrpc_spll_note_state(s->seq_state);

	int helper_ref;

	if( mode == SPLL_MODE_SLAVE)
		helper_ref = slave_ref_channel; // Slave mode: lock the helper to an uplink port
	else
		helper_ref = spll_n_chan_ref; // Master/GM mode: lock the helper to the local ref clock

	helper_init(&s->helper, helper_ref);
	mpll_init(&s->mpll, slave_ref_channel, spll_n_chan_ref);

	for (i = 0; i < spll_n_chan_out - 1; i++) {
		mpll_init(&s->aux[i].pll.dmtd, slave_ref_channel, spll_n_chan_ref + i + 1);
		s->aux[i].seq_state = AUX_DISABLED;
	}

	for (i = 0; i < spll_n_chan_ref; i++)
		ptracker_init(&s->ptrackers[i], i, PTRACKER_AVERAGE_SAMPLES);

	if(mode == SPLL_MODE_GRAND_MASTER) {
		if(SPLL->ECCR & SPLL_ECCR_EXT_SUPPORTED) {
			s->ext.helper = &s->helper;
			s->ext.main = &s->mpll;
			external_init(&s->ext, spll_n_chan_ref + spll_n_chan_out, flags & SPLL_FLAG_ALIGN_PPS ? 1 : 0);
		} else {
			pll_verbose("softpll: attempting to enable GM mode on non-GM hardware.\n");
			return;
		}
	}

	pll_verbose
	    ("softpll: mode %s, %d ref channels, %d out channels, ref: %d\n",
	     modes[mode], spll_n_chan_ref, spll_n_chan_out, slave_ref_channel);

	/* Purge tag buffer */
	while (!(SPLL->TRR_CSR & SPLL_TRR_CSR_EMPTY))
	{
		dummy = SPLL->TRR_R0;
		(void) dummy;
	}


	/* Purge debug queue */
	if ( SPLL->CSR & SPLL_CSR_DBG_SUPPORTED )
	{
		while (!(SPLL->DFR_HOST_CSR & SPLL_DFR_HOST_CSR_EMPTY))
		{
			dummy = SPLL->DFR_HOST_R0;
			(void) dummy;
		}
	}

	if(mode == SPLL_MODE_DISABLED)
		return;

	SPLL->EIC_IER = 1;
	SPLL->OCER |= 1;

	enable_irq();
}

void spll_shutdown(void)
{
	disable_irq();

	SPLL->OCER = 0;
	SPLL->RCER = 0;
	SPLL->ECCR = 0;
	SPLL->EIC_IDR = 1;
}

int spll_start_channel(int channel)
{
	struct softpll_state *s = (struct softpll_state *) &softpll;

	if (s->seq_state != SEQ_READY || !channel) {
		pll_verbose("Can't start channel %d, the PLL is not ready\n",
			  channel);
		return -1;
	}

	struct spll_aux_state *a = &s->aux[channel - 1];
	struct spll_main_state *m = &a->pll.dmtd;

#ifdef CONFIG_FRAC_SPLL
	m->div_cnt = 0;
	m->div_ref = a->div_ref;
	m->div_fb = a->div_fb;
#endif

	mpll_start(m);

	return 0;
}

void spll_stop_channel(int channel)
{
	struct softpll_state *s = (struct softpll_state *) &softpll;

	if (!channel)
		return;

	mpll_stop(&s->aux[channel - 1].pll.dmtd);
}

int spll_check_lock(int channel)
{
	if (!channel) {
		int state_value;
		int result;

		wdiags_write_spll_check_lock_debug(
			WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_BEFORE_CALL,
			channel, 0);
		wdiags_write_spll_check_lock_debug(
			WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_ENTERED,
			channel, 0);
		state_value = softpll.seq_state;
		wdiags_write_spll_check_lock_debug(
			WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_AFTER_STATE_READ,
			channel, state_value);
		result = (state_value == SEQ_READY);
		wdiags_write_spll_check_lock_debug(
			WRC_DIAGS_PERSISTENT_SPLL_CHECK_LOCK_BEFORE_RETURN,
			channel, state_value);
		return result;
	}
	else
		return (softpll.seq_state == SEQ_READY)
		    && softpll.aux[channel - 1].pll.dmtd.phase_ld.locked;
}

static int32_t to_picos(int32_t units)
{
	return (int32_t) (((int64_t) units *
			   (int64_t) CLOCK_PERIOD_PICOSECONDS) >> HPLL_N);
}

/* Channel 0 = local PLL reference, 1...N = aux oscillators */
static void set_phase_shift(int channel, int32_t value_picoseconds)
{
	struct spll_main_state *st = (struct spll_main_state *)
	    (!channel ? &softpll.mpll : &softpll.aux[channel - 1].pll.dmtd);
	mpll_set_phase_shift(st, value_picoseconds);
	softpll.mpll_shift_ps = value_picoseconds;
}

void spll_set_phase_shift(int channel, int32_t value_picoseconds)
{
	int i;

	pll_verbose("set_phase_shift %d %ld\n", channel, value_picoseconds);

	if (channel == SPLL_ALL_CHANNELS) {
		set_phase_shift(0, value_picoseconds);
		for (i = 0; i < spll_n_chan_out - 1; i++)
			if (softpll.aux[i].seq_state == AUX_SLAVE_READY)
				set_phase_shift(i + 1, value_picoseconds);
	} else
		set_phase_shift(channel, value_picoseconds);
}

void spll_get_phase_shift(int channel, int32_t *current, int32_t *target)
{
	volatile struct spll_main_state *st = (struct spll_main_state *)
	    (!channel ? &softpll.mpll : &softpll.aux[channel - 1].pll.dmtd);
	int div = (DIVIDE_DMTD_CLOCKS_BY_2 ? 2 : 1);
	if (current)
		*current = to_picos(st->phase_shift_current * div);
	if (target)
		*target = to_picos(st->phase_shift_target * div);
}

int spll_read_ptracker(int channel, int32_t *phase_ps, int *enabled)
{
	volatile struct spll_ptracker_state *st = &softpll.ptrackers[channel];
	int phase = st->phase_val;
	if (phase < 0)
		phase += (1 << HPLL_N);
	else if (phase >= (1 << HPLL_N))
		phase -= (1 << HPLL_N);

	if (DIVIDE_DMTD_CLOCKS_BY_2) {
		phase <<= 1;
		phase &= (1 << HPLL_N) - 1;
	}

	*phase_ps = to_picos(phase);
	if (enabled)
		*enabled = ptracker_mask & (1 << st->id) ? 1 : 0;
	return st->ready;
}

void spll_set_ptracker_average_samples(int channel, int nsamples)
{
	struct softpll_state *s = (struct softpll_state *) &softpll;
	struct spll_ptracker_state *pt = &s->ptrackers[channel];

	disable_irq();
	pt->preserve_sign = 0;
	pt->ready = 0;
	pt->acc = 0;
	pt->avg_count = 0;
	pt->n_avg = nsamples;
	enable_irq();
}


void spll_get_num_channels(int *n_ref, int *n_out)
{
	if (n_ref)
		*n_ref = spll_n_chan_ref;
	if (n_out)
		*n_out = spll_n_chan_out;
}

void ptracker_show_stats(void)
{
	int ch;

	for (ch = 0; ch < MAX_PTRACKERS; ch++) {
		struct spll_ptracker_state *s =
			(struct spll_ptracker_state *)&softpll.ptrackers[ch];
		int32_t phase;
		spll_read_ptracker(ch, &phase, NULL);
		pp_printf("ptrack %d: en %d id %d ready %d phase %d (%d ps) avg %d\n",
			  ch, s->enabled, s->id, s->ready,
			  s->phase_val, (int)phase, s->n_avg);
	}
}

void spll_show_stats(void)
{
	struct softpll_state *s = (struct softpll_state *)&softpll;
	const char *statename;

	if (s->seq_state >= SEQ_STATES_NR)
		statename = "<Unknown>";
	else
		statename = seq_states[s->seq_state];

	pp_printf("softpll: mode:%d seq:%s n_ref %d n_out %d\n",
		  s->mode, statename,
		  spll_n_chan_ref, spll_n_chan_out);

	if (s->mode > 0)
	{
		/* Needs 2 pp_printf to avoid buffer overflow on printf
		   buffer. */
	  pp_printf("irqs:%d "
		    "alignment_state:%d HL%d ML%d HY=%d MY=%d DelCnt=%d setpoint:%d refcnt:%d tagcnt:%d h_kp:%d h_ki:%d h_shift:%d ",
		    s->irq_count, s->ext.align_state,
		    s->helper.ld.locked, s->mpll.locked,
		    s->helper.pi.y, s->mpll.pi.y,
		    s->delock_count, s->mpll.phase_shift_current,
		    s->ref_count, s->tag_count,
		    s->helper.pi.kp,
		    s->helper.pi.ki,
		    s->helper.pi.shift);
	  pp_printf("m_kp:%d m_ki:%d m_shift:%d h_lock_duration:%d m_freq_lock_duration:%d m_phase_lock_duration:%d",
		    s->mpll.pi.kp,
		    s->mpll.pi.ki,
		    s->mpll.pi.shift,
		    s->helper.last_lock_duration_ms,
		    s->mpll.last_freq_lock_duration_ms,
		    s->mpll.last_phase_lock_duration_ms
		    );

		if( softpll.mpll.gain_sched )
		{
			pp_printf(" gain_sched:%d/%d", softpll.mpll.gain_sched->current_stage + 1, softpll.mpll.gain_sched->n_stages );
		}

		pp_printf("\n");

	}

	int ch;

	for (ch = 1; ch < spll_n_chan_out; ch++)
	{
		struct spll_aux_state *s = (struct spll_aux_state *) &softpll.aux[ch - 1];

#ifdef CONFIG_FRAC_SPLL
		pp_printf("softpll: AUX%d [ratio %d/%d = %d Hz]: ph %ld seq %d en %d lock %d samples %d nref %d nout %d ERR=%d Y=%d\n",
				ch-1,
				s->div_fb,
				s->div_ref,
				REF_CLOCK_FREQ_HZ * s->div_fb / s->div_ref,
				s->phase_value,
				s->seq_state,
				s->pll.dmtd.enabled,
				s->pll.dmtd.locked,
				s->pll.dmtd.sample_n,
				s->pll.dmtd.n_ref,
				s->pll.dmtd.n_out,
				s->pll.dmtd.pi.x,
				s->pll.dmtd.pi.y );
#else
		pp_printf("softpll: AUX%d: ph %d seq %d en %d lock %d samples %d ERR=%d Y=%d\n",
				ch-1,
                                (int)s->phase_value,
				s->seq_state,
				s->pll.dmtd.enabled,
				s->pll.dmtd.locked,
				s->pll.dmtd.sample_n,
				s->pll.dmtd.pi.x,
				s->pll.dmtd.pi.y );
#endif
	}

	for (ch = 0; ch < spll_n_chan_ref; ch++)
		{
			pp_printf( "softpll: ptracker%d: enabled %d n_avg %d value %d\n", ch,
			s->ptrackers[ch].enabled ? 1 : 0,
			s->ptrackers[ch].n_avg,
			s->ptrackers[ch].phase_val );
		}

	
}

int spll_shifter_busy(int channel)
{
	if (!channel)
		return mpll_shifter_busy((struct spll_main_state *)&softpll.mpll);
	else
		return mpll_shifter_busy((struct spll_main_state *)&softpll.aux[channel - 1].pll.dmtd);
}

void spll_enable_ptracker(int ref_channel, int enable)
{
	if (enable) {
		pll_verbose("Enabling ptracker channel: %d\n", ref_channel);
		ptracker_start((struct spll_ptracker_state *)&softpll.
			       ptrackers[ref_channel]);
		ptracker_mask |= (1 << ref_channel);

	} else {
		pll_verbose("Disabling ptracker tagger: %d\n", ref_channel);
		ptracker_mask &= ~(1 << ref_channel);
		if (ref_channel != softpll.mpll.id_ref)
			spll_enable_tagger(ref_channel, 0);
	}
}

int spll_get_delock_count(void)
{
	return softpll.delock_count;
}

static int spll_update_aux_clock(int ch)
{
	int done_sth = 0;
	struct spll_aux_state *s = (struct spll_aux_state *)&softpll.aux[ch - 1];

	if(s->seq_state != AUX_DISABLED && !aux_locking_enabled(ch))
	{
		pll_verbose("softpll: disabled aux channel %d\n", ch);
		spll_stop_channel(ch);
		set_channel_status(ch, 0);
		s->seq_state = AUX_DISABLED;
		return 1;
	}

	switch (s->seq_state) {
	case AUX_DISABLED:
		if (softpll.mpll.locked && aux_locking_enabled(ch)) {
			if( s->mode == SPLL_AUX_MODE_SLAVE )
			{
				pll_verbose("softpll: enabled slave aux channel %d\n", ch);
				if( !spll_start_channel(ch) )
				{
					s->seq_state = AUX_LOCK_PLL;
				}
			}
			else if ( s->mode == SPLL_AUX_MODE_PHASE_MONITOR )
			{
				pll_verbose("softpll: enabled phase monitor on aux channel %d\n", ch);
				s->seq_state = AUX_WAIT_MONITOR_LOCK;
				ptracker_init( &s->pll.tracker, ch + spll_n_chan_ref, PTRACKER_AVERAGE_SAMPLES );
				ptracker_start( &s->pll.tracker );
			}
			done_sth = 1;
		}
		break;

	case AUX_WAIT_MONITOR_LOCK:
		if( s->pll.tracker.ready )
		{
			s->seq_state = AUX_MONITOR_READY;
			s->phase_value = s->pll.tracker.phase_val;
			set_channel_status(ch, 1);
			done_sth = 1;
			break;
		}

	case AUX_MONITOR_READY:
		if (!softpll.mpll.locked)
		{
			pll_verbose("softpll: aux phase monitor channel %d disabled due to PLL LOS\n", ch);
			set_channel_status(ch, 0);
			s->seq_state = AUX_DISABLED;
			done_sth = 1;
		}
		else
		{
			s->phase_value = s->pll.tracker.phase_val;
		}
		break;

	case AUX_LOCK_PLL:
		if (s->pll.dmtd.phase_ld.locked) {
			pll_verbose ("softpll: channel %d locked [aligning @ %d ps]\n", ch, softpll.mpll_shift_ps);
			set_phase_shift(ch, softpll.mpll_shift_ps);
			s->seq_state = AUX_ALIGN_PHASE;
			done_sth = 1;
		}
		break;

	case AUX_ALIGN_PHASE:
		if (!mpll_shifter_busy(&s->pll.dmtd)) {
			pll_verbose("softpll: channel %d phase aligned\n", ch);
			set_channel_status(ch, 1);
			s->seq_state = AUX_SLAVE_READY;
			done_sth = 1;
		}
		break;

	case AUX_SLAVE_READY:
		if (!softpll.mpll.locked || !s->pll.dmtd.phase_ld.locked) {
			pll_verbose("softpll: aux channel %d or mpll lost lock\n", ch);
			set_channel_status(ch, 0);
			s->seq_state = AUX_DISABLED;
			done_sth = 1;
		}
		break;
	}
	return done_sth;
}

/* Bottom half of the interrupt handler  */
int spll_update(void)
{
	int ret = 0;
	int ch;

	switch(softpll.mode) {
		case SPLL_MODE_GRAND_MASTER:
			ret = external_align_fsm(&softpll.ext);
			break;
	}

	for (ch = 1; ch < spll_n_chan_out; ch++)
	  ret |= spll_update_aux_clock(ch);

#ifdef CONFIG_TARGET_WR_SWITCH
	/* store statistics */
	stats.sequence++;
	stats.mode  = softpll.mode;
	stats.irq_cnt = softpll.irq_count;
	stats.seq_state = softpll.seq_state;
	stats.align_state = softpll.ext.align_state;
	stats.H_lock = softpll.helper.ld.locked;
	stats.M_lock = softpll.mpll.locked;
	stats.H_y = softpll.helper.pi.y;
	stats.M_y = softpll.mpll.pi.y;
	stats.del_cnt = softpll.delock_count;
	stats.sequence++;
#endif

	return ret != 0;
}

struct spll_aux_clock_status spll_get_aux_status(int channel )
{
	struct spll_aux_clock_status rval;

	rval.flags = 0;
	rval.mode = 0;
	rval.phase = 0;

	if( channel < 0 || channel >= MAX_CHAN_AUX )
		return rval;

	int state = softpll.aux[channel].seq_state;

	rval.mode = softpll.aux[channel].mode;

	switch ( state )
	{
		case AUX_DISABLED:
			rval.flags = 0;
			break;
		case AUX_LOCK_PLL:
			rval.flags = SPLL_AUX_SLAVE_ENABLED;
			break;
		case AUX_WAIT_MONITOR_LOCK:
			rval.flags = SPLL_AUX_MONITOR_ENABLED;
			break;
		case AUX_MONITOR_READY:
			rval.flags = SPLL_AUX_MONITOR_ENABLED | SPLL_AUX_MONITOR_READY;
			break;
		case AUX_SLAVE_READY:
			rval.flags = SPLL_AUX_MONITOR_ENABLED | SPLL_AUX_SLAVE_LOCKED;
			break;
	}

	rval.phase = softpll.aux[channel].phase_value;

	return rval;
}

int spll_get_dac(int index)
{
	if (index < 0)
		return softpll.helper.pi.y;
	else if (index == 0)
		return softpll.mpll.pi.y;
	else if (index > 0)
		return softpll.aux[index - 1].pll.dmtd.pi.y;
	return 0;
}

void spll_set_dac(int index, int value)
{
	if (index < 0) {
		softpll.helper.pi.y = value;
		SPLL->DAC_HPLL = value;
	} else {
		SPLL->DAC_MAIN =
				    SPLL_DAC_MAIN_DAC_SEL_W(index) | (value & 0xffff);

		if (index == 0)
			softpll.mpll.pi.y = value;
		else if (index > 0)
			softpll.aux[index - 1].pll.dmtd.pi.y = value;
	}
}

void spll_set_gain_schedule( spll_gain_schedule_t* sch )
{
	disable_irq();
	softpll.mpll.gain_sched = sch;
	enable_irq();
}

void spll_set_pi_gain( int loop, int sched_stage, int kp, int ki, int shift )
{
	pll_verbose("set_pi_gain loop=%d stage=%d kp=%d ki=%d, shift=%d\n", loop, sched_stage, kp, ki, shift);
	disable_irq();
	switch(loop)
	{
		case SPLL_LOOP_HELPER:
			softpll.helper.pi.kp = kp;
			softpll.helper.pi.ki = ki;
			softpll.helper.pi.shift = shift;
			break;
		case SPLL_LOOP_MAIN:
			if( softpll.mpll.gain_sched && sched_stage < softpll.mpll.gain_sched->n_stages )
			{
				softpll.mpll.gain_sched->stages[sched_stage].ki = ki;
				softpll.mpll.gain_sched->stages[sched_stage].kp = kp;
				softpll.mpll.gain_sched->stages[sched_stage].shift = shift;
				if( softpll.mpll.gain_sched->current_stage == sched_stage )
				{
					softpll.mpll.pi.kp = kp;
					softpll.mpll.pi.ki = ki;
					softpll.mpll.pi.shift = shift;
				}
			}
			else
			{
				softpll.mpll.pi.kp = kp;
				softpll.mpll.pi.ki = ki;
				softpll.mpll.pi.shift = shift;
			}
			break;
		default:
			break;
	}
	enable_irq();
}



static struct spll_debug_queue_state
{
	int undersample_ratio;
	uint8_t undersample_count[SPLL_DBG_MAX_SOURCES];
	uint8_t undersample_pass[SPLL_DBG_MAX_SOURCES];
	int coalesce_threshold;
} dbg_state;


void spll_debug_queue_configure( int undersample, int coalsesce_threshold )
{
	int dummy, i;
	while (!(SPLL->DFR_HOST_CSR & SPLL_DFR_HOST_CSR_EMPTY))
		{
			dummy = SPLL->DFR_HOST_R0;
			(void) dummy;
		}

	dbg_state.undersample_ratio = undersample;
	dbg_state.coalesce_threshold = coalsesce_threshold * undersample;

	for(i=0;i<SPLL_DBG_MAX_SOURCES;i++)
	{
		dbg_state.undersample_count[i] = 0;
		dbg_state.undersample_pass[i] = 0;
		}
}


int spll_get_debug_queue_samples( uint32_t *buf, int *count )
{
	int n_ents = 0;
	int latch_full = SPLL->DFR_HOST_CSR & SPLL_DFR_HOST_CSR_FULL;
	int latch_count = SPLL_DFR_HOST_CSR_USEDW_R(SPLL->DFR_HOST_CSR);
	struct spll_debug_queue_state *st = &dbg_state;

	if( !latch_full && latch_count < dbg_state.coalesce_threshold )
	{
		*count = 0;
		return 0;
	}

	while(1)
	{
		if ( SPLL->DFR_HOST_CSR & SPLL_DFR_HOST_CSR_EMPTY )
			break;

		if( n_ents == *count )
			break;

		volatile uint32_t v = SPLL->DFR_HOST_R0;
		int signal = SPLL_DBG_EXTRACT_SIGNAL( v );
		int src = SPLL_DBG_EXTRACT_SOURCE( v );

		if(st->undersample_pass[src] || signal == SPLL_DBG_SIGNAL_EVENT )
		{
			*buf++ = v;
			n_ents ++;
		}

		if( v & 0x80000000 ) // last entry in the record
		{
			st->undersample_count[src]++;
			if (st->undersample_count[src] >= st->undersample_ratio)
			{
				st->undersample_count[src] = 0;
				st->undersample_pass[src] = 1;
			} else {
				st->undersample_pass[src] = 0;
			}
		}

	}

	*count = n_ents;

	if( latch_full )
		return -ENOSPC;

	return 0;
}

void spll_set_aux_mode( int channel, int mode )
{
	softpll.aux[channel].mode = mode;
}

#ifdef CONFIG_FRAC_SPLL
void spll_set_aux_frequency_ratio( int channel, int div_ref, int div_fb )
{
	softpll.aux[channel].div_fb = div_fb;
	softpll.aux[channel].div_ref = div_ref;
}
#endif

int spll_pshifter_freeze(int freeze)
{
	softpll.mpll.ps_freeze = freeze;
	return 0;
}

int spll_vco_freeze(int freeze)
{
	softpll.mpll.vco_freeze = freeze;
	return 0;
}

int spll_is_ext_supported(void)
{
	return (SPLL->ECCR & SPLL_ECCR_EXT_SUPPORTED) ? 1 : 0;
}
