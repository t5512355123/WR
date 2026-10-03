/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/* spll_ptracker.c - implementation of phase trackers. */

#include "softpll_ng.h"
#include "spll_ptracker_diag.h"
extern uint32_t timer_get_tics(void);

static int tag_ref = -1;
static volatile struct spll_ptracker_diag_frame ptracker_diag[MAX_PTRACKERS];

/* One IRQ producer, bounded seqlock consumer. Only an averaging completion
 * publishes a phase. Init/start invalidate metadata without changing control. */
static void ptracker_diag_publish(struct spll_ptracker_state *s, int restart, int tag)
{
	volatile struct spll_ptracker_diag_frame *d;
	uint32_t epoch;
	if ((unsigned)s->id >= MAX_PTRACKERS)
		return; /* Auxiliary tracker IDs are not reference-channel indices. */
	d = &ptracker_diag[s->id];
	epoch = d->epoch;
	d->epoch = epoch + 1;
	if (restart) {
		d->generation++;
		d->publications = 0;
		d->published_ms = 0;
		d->phase_raw = 0;
		d->reference_tag = d->input_tag = -1;
	} else {
		d->publications++;
		d->published_ms = timer_get_tics();
		d->phase_raw = s->phase_val;
		d->reference_tag = tag_ref;
		d->input_tag = tag;
	}
	d->ready_enabled = (uint32_t)!!s->ready | ((uint32_t)!!s->enabled << 1);
	d->epoch = epoch + 2;
}

int spll_ptracker_diag_copy(unsigned channel, struct spll_ptracker_diag_frame *out)
{
	unsigned tries;
	uint32_t before, after;
	volatile struct spll_ptracker_diag_frame *d;
	if (channel >= MAX_PTRACKERS || !out)
		return 0;
	d = &ptracker_diag[channel];
	for (tries = 0; tries < 4; tries++) {
		before = d->epoch;
		if (before & 1) continue;
		out->epoch = before;
		out->generation = d->generation;
		out->publications = d->publications;
		out->published_ms = d->published_ms;
		out->phase_raw = d->phase_raw;
		out->reference_tag = d->reference_tag;
		out->input_tag = d->input_tag;
		out->ready_enabled = d->ready_enabled;
		after = d->epoch;
		if (before == after && !(after & 1)) return 1;
	}
	return 0;
}

void ptracker_init(struct spll_ptracker_state *s, int id, int num_avgs)
{
	s->id = id;
	s->ready = 0;
	s->n_avg = num_avgs;
	s->acc = 0;
	s->avg_count = 0;
	s->enabled = 0;
	s->dbg_channel = -1;
	ptracker_diag_publish(s, 1, -1);
}

void ptracker_start(struct spll_ptracker_state *s)
{
	s->preserve_sign = 0;
	s->enabled = 1;
	s->ready = 0;
	s->acc = 0;
	s->avg_count = 0;

	ptracker_diag_publish(s, 1, -1);
	spll_enable_tagger(s->id, 1);
	spll_enable_tagger(MAIN_CHANNEL, 1);
}

void ptrackers_update(struct spll_ptracker_state *ptrackers, int tag,
		      int source)
{
	/* Adjustment for wrap-arounds.  */
	static const int adj_tab[16] = {
		/* psign */
		/* 0   - 1/4   */  0, 0, 0, -(1<<HPLL_N),
		/* 1/4 - 1/2  */   0, 0, 0, 0,
		/* 1/2 - 3/4  */   0, 0, 0, 0,
		/* 3/4 - 1   */    (1<<HPLL_N), 0, 0, 0};

	if(source == MAIN_CHANNEL)
	{
		tag_ref = tag;
		return;
	}


	register struct spll_ptracker_state *s = ptrackers + source;

	if(!s->enabled)
		return;
#if defined(CONFIG_WR_NODE)
	register int delta = (tag - tag_ref) & ((1 << HPLL_N) - 1);
#else
	register int delta = (tag_ref - tag) & ((1 << HPLL_N) - 1);
#endif
	register int index = delta >> (HPLL_N - 2);

	if( s->dbg_channel >= 0 )
	{
		spll_debug( SPLL_DBG_SRC_AUX(s->dbg_channel), SPLL_DBG_SIGNAL_ERR, tag_ref-tag, 1);
	}

	if (s->avg_count == 0) {
		/* hack: two since PTRACK_WRAP_LO/HI are in 1/4 and 3/4 of the scale,
		   we can use the two MSBs of delta and a trivial LUT instead, removing 2 branches */
		s->preserve_sign = index << 2;
		s->acc = delta;
		s->avg_count ++;
	} else {

		/* same hack again, using another lookup table to adjust for wraparound */
		s->acc += delta + adj_tab[ index + s->preserve_sign ];
		s->avg_count ++;

		if (s->avg_count == s->n_avg) {
			s->phase_val = s->acc / s->n_avg;
			s->ready = 1;
			s->acc = 0;
			s->avg_count = 0;
			ptracker_diag_publish(s, 0, tag);
		}
	}
}
