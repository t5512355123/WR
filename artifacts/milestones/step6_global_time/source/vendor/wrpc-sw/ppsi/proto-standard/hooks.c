#include <ppsi/ppsi.h>

/* proto-standard hooks */

static 	void state_change(struct pp_instance *ppi) {
	if ( ppi->state==PPS_SLAVE && ppi->next_state!=PPS_UNCALIBRATED ) {
		/* Leave SLAVE state : We must stop the timing output generation */
		if ( !GOPTS(GLBS(ppi))->forcePpsGen )
			TOPS(ppi)->enable_timing_output(GLBS(ppi),0);
	}
}
struct pp_ext_hooks const pp_hooks={
		.state_change = state_change
};
