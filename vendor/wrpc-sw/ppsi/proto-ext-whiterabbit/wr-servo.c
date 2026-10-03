#include <ppsi/ppsi.h>
#include <ppsi/assert.h>
#include "../proto-standard/common-fun.h"

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

	se->rawT3=ppi->t3;
	se->rawT4=ppi->t4;
	if ( is_delayMechanismE2E(ppi) && SRV(ppi)->got_sync) {
		// Calculate raw delayMM
		_calculate_raw_delayMM(ppi,&se->rawT1,&se->rawT2,&se->rawT3,&se->rawT4);
	}
	pp_time_add(&ppi->t3,&se->delta_txs);
	pp_time_sub(&ppi->t4,&se->delta_rxm);
	return wrh_servo_got_resp(ppi);
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

