/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __BOARD_AUX_ERTM14_H
#define __BOARD_AUX_ERTM14_H

#include <string.h>
#include "board-state.h"

static void __attribute__((__unused__))
copy_config(struct ertm14_board_state *dst, const struct ertm14_board_state *src)
{
	memcpy(dst, src, sizeof(struct ertm14_board_state));
}

static void __attribute__((__unused__))
clean_config(struct ertm14_board_state *bs)
{
	memset(bs, 0, sizeof(struct ertm14_board_state));
}

static void update_dds_state(struct ertm14_dds_state *dst,
			    const struct ertm14_dds_state *src,
			    const struct ertm14_dds_state *mask)
{
	int i;

	if (mask->ftw)
		dst->ftw	 = src->ftw;
	if (mask->amp_power)
		dst->amp_power	 = src->amp_power;
	if (mask->ampl_factor)
		dst->ampl_factor = src->ampl_factor;
	if (mask->sync_source)
		dst->sync_source = src->sync_source;
	if (mask->sync_count)
		dst->sync_count	= src->sync_count;
	for (i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++) {
		if (mask->out_state[i])
			dst->out_state[i] = src->out_state[i];
		if (mask->out_power[i])
			dst->out_power[i] = src->out_power[i];
	}

}

static inline void update_bits(uint32_t *dst, uint32_t src, uint32_t mask)
{
	*dst &= ~mask;
	*dst |= src & mask;
}

static void update_config(struct ertm14_board_state *dst,
			    const struct ertm14_board_state *src,
			    const struct ertm14_board_state *mask)
{
	int i;

	update_dds_state(&dst->ref, &src->ref, &mask->ref);
	update_dds_state(&dst->lo, &src->lo, &mask->lo);
	if (mask->valid)
		dst->valid = src->valid;
	if (mask->clka_enable_mask)
		update_bits(&dst->clka_enable_mask, src->clka_enable_mask, mask->clka_enable_mask);
	if (mask->clkb_enable_mask)
		update_bits(&dst->clkb_enable_mask, src->clkb_enable_mask, mask->clkb_enable_mask);
	if (mask->streamers_latency_cycles)
		dst->streamers_latency_cycles = src->streamers_latency_cycles;
	if (mask->streamers_timeout_cycles)
		dst->streamers_timeout_cycles = src->streamers_timeout_cycles;
	for (i = ERTM14_CLKAB_OUT_MIN_ID; i <= ERTM14_CLKAB_OUT_MAX_ID; i++) {
		if (mask->clka_freq_hz[i])
			dst->clka_freq_hz[i] = src->clka_freq_hz[i];
		if (mask->clkb_freq_hz[i])
			dst->clkb_freq_hz[i] = src->clkb_freq_hz[i];
	}
}
#endif /* __BOARD_AUX_ERTM14_H */
