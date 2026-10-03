#include <ppsi/ppsi.h>
#include <ppsi/assert.h>
#include "../proto-standard/common-fun.h"

#if CONFIG_ARCH_IS_WRPC
#include "../arch-wrpc/wrpc.h"
#include "../../include/wrh-fixed-diag.h"
#include "../../include/wr-ts-diag.h"
#include "../../include/phase-history.h"
#include "../pp_printf/pp-printf.h"
#include <errno.h>

extern volatile uint32_t wrpc_spll_init_count;
static uint32_t ts_ring[WR_TS_DIAG_RECORDS][WR_TS_DIAG_WORDS];
static uint32_t ts_snapshot[WR_TS_DIAG_RECORDS][WR_TS_DIAG_WORDS];
static uint32_t ts_total, ts_snapshot_id, ts_snapshot_total;
static unsigned ts_head, ts_count, ts_snapshot_count;
static int ts_snapshot_ready;

static void ts_put64(uint32_t *out, int64_t value)
{
	out[0] = (uint32_t)((uint64_t)value >> 32);
	out[1] = (uint32_t)value;
}

static void ts_put_time(uint32_t *out, const struct pp_time *t)
{
	ts_put64(out, t->secs);
	ts_put64(out + 2, t->scaled_nsecs);
}

/* After an actual accepted E2E calculation/control update, before any console
 * work. WRPC shell and this producer are serialized in the same main loop.
 * No ISR consumes/writes this ring and no servo reads it back. */
static void ts_record(struct pp_instance *ppi, uint32_t before_count,
		      unsigned before_state, int32_t before_setp, int result)
{
	struct pp_servo *gs = SRV(ppi);
	wrh_servo_t *s = WRH_SRV(ppi);
	wr_servo_ext_t *se = WRE_SRV(ppi);
	struct wrh_fixed_diag d;
	const unsigned char *id;
	uint32_t *r;
	if (gs->update_count == before_count || !is_delayMechanismE2E(ppi) ||
	    ppi->protocol_extension != PPSI_EXT_WR || ppi->extState != PP_EXSTATE_ACTIVE ||
	    WRPC_ARCH_I(ppi)->timingMode != WRH_TM_BOUNDARY_CLOCK)
		return;
	wrh_fixed_diag_get(&d);
	r = ts_ring[ts_head];
	r[0] = ++ts_total;
	r[1] = gs->update_count;
	r[2] = (uint32_t)before_state << 16 | gs->state;
	r[3] = (uint32_t)before_setp;
	r[4] = (uint32_t)s->cur_setpoint_ps;
	r[5] = (uint32_t)ppi->recv_sync_sequence_id << 16 |
		ppi->received_ptp_header.sequenceId;
	r[6] = (uint32_t)ppi->received_ptp_header.messageType << 24 |
		(uint32_t)ppi->received_ptp_header.domainNumber << 16 |
		ppi->received_ptp_header.sourcePortIdentity.portNumber;
	id = ppi->received_ptp_header.sourcePortIdentity.clockIdentity.id;
	r[7] = (uint32_t)id[0] << 24 | (uint32_t)id[1] << 16 | (uint32_t)id[2] << 8 | id[3];
	r[8] = (uint32_t)id[4] << 24 | (uint32_t)id[5] << 16 | (uint32_t)id[6] << 8 | id[7];
	r[9] = 1; /* E2E, enforced above. Sync and Delay sequences are independent. */
	r[10] = d.phase_writes;
	r[11] = d.servo_inits;
	r[12] = d.enabled << 1 | d.latched;
	r[13] = wrpc_spll_init_count;
	r[14] = gs->flags;
	r[15] = (uint32_t)result;
	ts_put_time(r + 16, &se->rawT1); ts_put_time(r + 20, &se->rawT2);
	ts_put_time(r + 24, &se->rawT3); ts_put_time(r + 28, &se->rawT4);
	ts_put_time(r + 32, &gs->t1); ts_put_time(r + 36, &gs->t2);
	ts_put_time(r + 40, &gs->t3); ts_put_time(r + 44, &gs->t4);
	ts_put_time(r + 48, &se->delta_txm); ts_put_time(r + 52, &se->delta_rxs);
	ts_put_time(r + 56, &se->delta_txs); ts_put_time(r + 60, &se->delta_rxm);
	ts_put_time(r + 64, &gs->delayMM); ts_put_time(r + 68, &gs->delayMS);
	ts_put_time(r + 72, &gs->meanDelay); ts_put_time(r + 76, &gs->offsetFromMaster);
	ts_put_time(r + 80, &se->rawDelayMM);
	ts_put64(r + 84, ppi->portDS->delayAsymmetry);
	wr_phase_history_record(gs->update_count, r[2], before_setp,
		s->cur_setpoint_ps, d.phase_writes,
		gs->offsetFromMaster.secs, gs->offsetFromMaster.scaled_nsecs,
		gs->delayMS.secs, gs->delayMS.scaled_nsecs);
	ts_head = (ts_head + 1) % WR_TS_DIAG_RECORDS;
	if (ts_count < WR_TS_DIAG_RECORDS)
		ts_count++;
}

int wr_ts_diag_show_page(unsigned page)
{
	unsigned i, j, first;
	if (page >= WR_TS_DIAG_RECORDS)
		return -EINVAL;
	if (!page) {
		ts_snapshot_count = ts_count;
		ts_snapshot_total = ts_total;
		ts_snapshot_id++;
		first = (ts_head + WR_TS_DIAG_RECORDS - ts_count) % WR_TS_DIAG_RECORDS;
		for (i = 0; i < ts_count; i++)
			memcpy(ts_snapshot[i], ts_ring[(first + i) % WR_TS_DIAG_RECORDS],
			       sizeof(ts_snapshot[i]));
		ts_snapshot_ready = 1;
	}
	if (!ts_snapshot_ready)
		return -EAGAIN;
	pp_printf("TS4_PAGE v=1 snapshot=%08x total=%08x page=%u count=%u words=%u\n",
		  ts_snapshot_id, ts_snapshot_total, page, ts_snapshot_count, WR_TS_DIAG_WORDS);
	if (page < ts_snapshot_count) {
		pp_printf("TS4_V1 idx=%u words=", page);
		for (j = 0; j < WR_TS_DIAG_WORDS; j++)
			pp_printf("%08x%c", ts_snapshot[page][j],
				  j + 1 == WR_TS_DIAG_WORDS ? '\n' : ' ');
	}
	pp_printf("TS4_END snapshot=%08x page=%u\n", ts_snapshot_id, page);
	return 0;
}
#endif

static inline void _calculate_raw_delayMM(struct pp_instance *ppi,
					  const struct pp_time *ta,
					  const struct pp_time *tb,
					  const struct pp_time *tc,
					  const struct pp_time *td)
{
	wr_servo_ext_t *se=WRE_SRV(ppi);

	/* The calculation done will be
	 * (td-ta)-(tc-tb)
	 */
	struct pp_time *sa=&se->rawDelayMM,sb;

	/* sa = (td-ta) */
	*sa=*td;
	pp_time_sub(sa,ta);
	/* sb = (tc-tb) */
	sb=*tc;
	pp_time_sub(&sb,tb);

	/* sa-sb */
	pp_time_sub(sa,&sb);
}

int wr_servo_init(struct pp_instance *ppi)
{
	if ( wrh_servo_init(ppi) ) {
		/* Reset extension servo data */
		memset(WRE_SRV(ppi),0,sizeof(wr_servo_ext_t));
		return 1;
	} else
		return 0;
}

int wr_servo_got_sync(struct pp_instance *ppi) {
	/* Re-adjust T1 and T2 */
	wr_servo_ext_t *se=WRE_SRV(ppi);

	se->rawT1=ppi->t1;
	se->rawT2=ppi->t2;
	if ( is_delayMechanismP2P(ppi) && SRV(ppi)->got_sync) {
		// Calculate raw delayMM
		_calculate_raw_delayMM(ppi,&se->rawT3,&se->rawT4,&se->rawT5,&se->rawT6);
	}
	pp_time_add(&ppi->t1,&se->delta_txm);
	pp_time_sub(&ppi->t2,&se->delta_rxs);
	return wrh_servo_got_sync(ppi);
}

int wr_servo_got_resp(struct pp_instance *ppi) {
	/* Re-adjust T3 and T4 */
	wr_servo_ext_t *se=WRE_SRV(ppi);
#if CONFIG_ARCH_IS_WRPC
	uint32_t before_count = SRV(ppi)->update_count;
	unsigned before_state = SRV(ppi)->state;
	int32_t before_setp = WRH_SRV(ppi)->cur_setpoint_ps;
	int result;
#endif

	se->rawT3=ppi->t3;
	se->rawT4=ppi->t4;
	if ( is_delayMechanismE2E(ppi) && SRV(ppi)->got_sync) {
		// Calculate raw delayMM
		_calculate_raw_delayMM(ppi,&se->rawT1,&se->rawT2,&se->rawT3,&se->rawT4);
	}
	pp_time_add(&ppi->t3,&se->delta_txs);
	pp_time_sub(&ppi->t4,&se->delta_rxm);
#if CONFIG_ARCH_IS_WRPC
	result = wrh_servo_got_resp(ppi);
	ts_record(ppi, before_count, before_state, before_setp, result);
	return result;
#else
	return wrh_servo_got_resp(ppi);
#endif
}

int wr_servo_got_presp(struct pp_instance *ppi)
{
	/* Re-adjust T3,T4,T5 and T6 */
	wr_servo_ext_t *se=WRE_SRV(ppi);

	se->rawT3=ppi->t3;
	se->rawT4=ppi->t4;
	se->rawT5=ppi->t5;
	se->rawT6=ppi->t6;
	pp_time_add(&ppi->t3,&se->delta_txs);
	pp_time_sub(&ppi->t4,&se->delta_rxm);
	pp_time_add(&ppi->t5,&se->delta_txm);
	pp_time_sub(&ppi->t6,&se->delta_rxs);
	return wrh_servo_got_presp(ppi);
}
