/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Aurelio Colosimo <aurelio@aureliocolosimo.it>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdint.h>
#include <errno.h>
#include "ppsi/ppsi.h"
#include "wrpc.h"
#include "../proto-standard/common-fun.h"

/* All of these live in wrpc-sw/include */
#include "dev/minic.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include "dev/pps_gen.h"
#include "dev/console.h"
#include "dev/rxts_calibrator.h"

#include "softpll_ng.h"

/* TODO: get rid of ptp_mode, use WRPC_ARCH_G(ppg)->timingModeCfg instead */
static uint8_t ptp_mode = WRC_MODE_UNKNOWN;

static unsigned char ptp_enabled = 0;

const struct wrh_operations wrh_oper = {
	.locking_enable = wrpc_spll_locking_enable, // entering slave
	.locking_poll = wrpc_spll_locking_poll,
	.locking_disable = wrpc_spll_locking_disable,
	.locking_reset = wrpc_spll_locking_reset,  // entering master, when leaving slave
	.enable_ptracker = wrpc_spll_enable_ptracker,

	.adjust_in_progress = wrpc_adjust_in_progress,
	.adjust_counters = wrpc_adjust_counters,
	.adjust_phase = wrpc_adjust_phase,

	.get_clock_period = wrpc_get_clock_period,
	
	/* not used */
	.set_timing_mode = NULL,
	.get_timing_mode = NULL,
	.get_timing_mode_state = NULL,
};

/*ppi fields*/
static defaultDS_t  defaultDS;
static currentDS_t  currentDS;
static parentDS_t   parentDS;
static timePropertiesDS_t timePropertiesDS;
static struct pp_servo servo;


#if CONFIG_HAS_EXT_WR == 1
/* WR extension declaration */
#include "../proto-ext-whiterabbit/wr-api.h"
#include "../proto-ext-whiterabbit/wr-constants.h"

static struct wr_data wr_ext_data; /* WR extension data */

static struct wr_dsport wr_dsport;
#endif

#if CONFIG_HAS_EXT_L1SYNC
/* WR extension declaration */
#include "../proto-ext-l1sync/l1e-api.h"

static struct l1e_data l1e_ext_data; /* WR extension data */

static l1e_ext_portDS_t l1e_dsport;
#endif

static portDS_t     portDS ;

static int delay_ms = PP_DEFAULT_NEXT_DELAY_MS;
static int start_tics = 0;

struct pp_globals ppg_static; /* forward declaration */
struct pp_globals * const ppg = &ppg_static;
static unsigned char __tx_buffer[PP_MAX_FRAME_LENGTH];
static unsigned char __rx_buffer[PP_MAX_FRAME_LENGTH];

/* despite the name, ppi_static is not static: tests/measure_t24p.c uses it */
struct pp_instance ppi_static;

struct wrpc_arch_data_t wrpc_arch_data = {
	.timingMode = WRH_TM_DISABLED,
	.wrpcModeCfg = WRC_MODE_UNKNOWN
};

/* We now have a structure with all globals, and multiple ppi inside */
struct pp_globals ppg_static = {
	.pp_instances		= &ppi_static,
	.defaultDS		= &defaultDS,
	.currentDS		= &currentDS,
	.parentDS		= &parentDS,
	.timePropertiesDS	= &timePropertiesDS,
	.max_links		= PP_MAX_LINKS,
	.nlinks			= 1,
	/* rt_opts set by pp_init_globals */
	.arch_glbl_data = &wrpc_arch_data,
};


extern struct pp_ext_hooks const pp_hooks;

int wrc_ptp_init(void)
{
	struct pp_instance *ppi = &ppi_static;

	pp_printf("PPSi for WRPC. Commit %s, built on " __DATE__ "\n",
		PPSI_VERSION);

	ppi->glbs = &ppg_static;
	ppi->portDS = &portDS;
	ppi->n_ops = &wrpc_net_ops;
	ppi->t_ops = &wrpc_time_ops;
	ppi->vlans_array_len = CONFIG_VLAN_ARRAY_SIZE;
	ppi->proto = PP_DEFAULT_PROTO;
	ppi->delayMechanism = MECH_E2E; /* until changed by cfg */
	ppi->iface_name = "wr0";
	ppi->port_name = "wr0";
	ppi->__tx_buffer = __tx_buffer;
	ppi->__rx_buffer = __rx_buffer;
	ppi->servo = &servo;
	ppi->ptp_support = TRUE;
	ppi->asymmetryCorrectionPortDS.enable = 1;

	/* copy default ppi config */
	memcpy(&ppi->cfg, &__pp_default_instance_cfg, sizeof(__pp_default_instance_cfg));
	ppi->ext_hooks =&pp_hooks; /* default value */
#if CONFIG_HAS_EXT_L1SYNC
	ppi->protocol_extension = PPSI_EXT_L1S;
	ppi->ext_hooks = &l1e_ext_hooks;
	ppi->ext_data = &l1e_ext_data;

	ppi->portDS->ext_dsport = &l1e_dsport;
	L1E_DSPOR_BS(ppi)->L1SyncEnabled=TRUE;
	L1E_DSPOR_BS(ppi)->rxCoherentIsRequired = TRUE;
	L1E_DSPOR_BS(ppi)->txCoherentIsRequired = TRUE;
	L1E_DSPOR_BS(ppi)->congruentIsRequired = TRUE;
#endif
#if CONFIG_HAS_EXT_WR
	ppi->protocol_extension = PPSI_EXT_WR;
	ppi->ext_hooks = &wr_ext_hooks;
	ppi->ext_data = &wr_ext_data;

	ppi->portDS->ext_dsport = &wr_dsport;
#endif
	/* egressLatency and ingressLatency are overwritten on ptp_start */

	ppi->timestampCorrectionPortDS.messageTimestampPointLatency=0;

	pp_init_globals(&ppg_static, &__pp_default_rt_opts);

	return 0;
}

int wrc_ptp_set_mode(int mode)
{
#if CONFIG_HAS_EXT_WR == 1
	struct pp_instance *ppi = &ppi_static;
// 	struct pp_globals *ppg = ppi->glbs;
	struct wr_dsport *wrp = WR_DSPOR(ppi);
#endif
	typeof(ppg->rt_opts->clock_quality_clockClass) *class_ptr;
	int error = 0;

	class_ptr = &ppg->rt_opts->clock_quality_clockClass;

	ptp_mode = 0;

	wrc_ptp_stop();

#if defined(CONFIG_TARGET_SPEC7)
    // proper clock sources must be selected before pll lock!
    board_pre_pll_lock(mode);
#endif

	/* clear rt_opts so bmc_set_default_device_attributes can later set it
	 * according to a set clock class */
	ppg->rt_opts->clock_quality_clockAccuracy = CONFIG_PTP_OPT_CLOCK_ACCURACY;
	ppg->rt_opts->clock_quality_offsetScaledLogVariance = CONFIG_PTP_OPT_CLOCK_ALLAN_VARIANCE;
	ppg->rt_opts->timeSource = CONFIG_PTP_OPT_TIME_SOURCE;
	ppg->rt_opts->ptpTimeScale = -1;
	ppg->rt_opts->frequencyTraceable = -1;
	ppg->rt_opts->timeTraceable = -1;

	switch (mode) {
	case WRC_MODE_GM:
	case WRC_MODE_ABSCAL: /* absolute calibration, gm-lookalike */
		/* Can become slave if clock class is degradated due to PLL
		 * unlocked and the peer on the other side has better clock class */
#if CONFIG_HAS_EXT_WR == 1
		wrp->wrConfig = WR_M_AND_S;
		WRPC_ARCH_G(ppg)->timingMode = WRH_TM_GRAND_MASTER;
#endif
		*class_ptr = PP_PTP_CLASS_GM_LOCKED;
		spll_init(SPLL_MODE_GRAND_MASTER, 0, SPLL_FLAG_ALIGN_PPS);
		error = wrpc_spll_check_lock_with_timeout(LOCK_TIMEOUT_GM);
		/* generate PPS no matter if PLL locked */
		wrpc_enable_timing_output(ppg, 1);

		break;

	case WRC_MODE_MASTER:
#if CONFIG_HAS_EXT_WR == 1
		wrp->wrConfig = WR_M_AND_S;
		WRPC_ARCH_G(ppg)->timingMode = WRH_TM_FREE_MASTER;
#endif
		spll_init(SPLL_MODE_FREE_RUNNING_MASTER, 0, SPLL_FLAG_ALIGN_PPS);

		wrpc_enable_timing_output(ppg, 1);
		*class_ptr = PP_FRUNNING_CLOCK_CLASS;
		error = wrpc_spll_check_lock_with_timeout(LOCK_TIMEOUT_FM);

		break;

	case WRC_MODE_SLAVE:
#if CONFIG_HAS_EXT_WR == 1
		wrp->wrConfig = WR_S_ONLY;
		/* when enter to slave state it will set spll to slave */
		WRPC_ARCH_G(ppg)->timingMode = WRH_TM_BOUNDARY_CLOCK;
#endif

		*class_ptr = PP_CLASS_SLAVE_ONLY;
		break;
	}

	/* Update the default attributes depending on the clock class in
	 * the configuration structure */
	bmc_set_default_device_attributes(ppg);
	/* Update defaultDS & timePropertiesDS with configured setting 
	 * (clockClass,...) */
	bmc_apply_configured_device_attributes(ppg);
	ptp_mode = mode;

	/* Keep a copy of mode for dump */
	WRPC_ARCH_G(ppg)->wrpcModeCfg = mode;

	return error;
}

int wrc_ptp_get_mode(void)
{
	return ptp_mode;
}

int wrc_ptp_sync_mech(int e2e_p2p_qry)
{
	struct pp_instance *ppi = &ppi_static;
	int running;

	if (!CONFIG_HAS_P2P)
		return ppi->delayMechanism;

	switch(e2e_p2p_qry) {
	case MECH_E2E:
	case MECH_P2P:
		running = wrc_ptp_run(-1);
		wrc_ptp_run(0);
		ppi->delayMechanism = e2e_p2p_qry;
		wrc_ptp_run(running);
		return 0;
	default:
		return ppi->delayMechanism;
	}
}

int wrc_ptp_start(void)
{
	struct pp_instance *ppi = &ppi_static;
	TimeInterval scaledBitSlide = 0;
	RelativeDifference scaledDelayCoefficient = 0;
	TimeInterval scaledSfpDeltaTx = 0;
	TimeInterval scaledSfpDeltaRx = 0;

	/* sfp match was done before so read calibration data */

	wrpc_read_calibration_data(ppi,
			&scaledBitSlide,
			&scaledDelayCoefficient,
			&scaledSfpDeltaTx,
			&scaledSfpDeltaRx);

	ppi->timestampCorrectionPortDS.semistaticLatency = scaledBitSlide;
	if (scaledDelayCoefficient>=PP_MIN_DELAY_COEFFICIENT_AS_RELDIFF
	    && scaledDelayCoefficient<=PP_MAX_DELAY_COEFFICIENT_AS_RELDIFF ) {
		/* Scaled delay coefficient is valid then delta tx and rx also */
		if ( ppi->asymmetryCorrectionPortDS.enable ) {
			ppi->asymmetryCorrectionPortDS.scaledDelayCoefficient = ppi->cfg.scaledDelayCoefficient = scaledDelayCoefficient;
			/* taken from: enable_asymmetryCorrection(ppi,TRUE); */
			ppi->portDS->delayAsymCoeff=pp_servo_calculateDelayAsymCoefficient(ppi->asymmetryCorrectionPortDS.scaledDelayCoefficient);
			ppi->asymmetryCorrectionPortDS.constantAsymmetry = picos_to_interval(ppi->cfg.constantAsymmetry_ps); /* needed? */

		}
		ppi->timestampCorrectionPortDS.egressLatency =
			picos_to_interval(ppi->cfg.egressLatency_ps) + scaledSfpDeltaTx;
		ppi->timestampCorrectionPortDS.ingressLatency =
			picos_to_interval(ppi->cfg.ingressLatency_ps) + scaledSfpDeltaRx;
	}

	/* Call the state machine. Being it in "Initializing" state, make
	 * ppsi initialize what is necessary */
	delay_ms = pp_state_machine(ppi, NULL, 0);
	start_tics = timer_get_tics();

	/* just tell that the link is up, if not it will anyhow not receive anything */
	ppi->link_up = TRUE;
	ppi->state = PPS_INITIALIZING;
	wrh_servo_reset(ppi);
	ptp_enabled = 1;
	return 0;
}

int wrc_ptp_stop(void)
{
	struct pp_instance *ppi = &ppi_static;

	/* Moving fiber: forget about this parent (FIXME: shouldn't be here) */
#if CONFIG_HAS_EXT_WR == 1
	struct wr_dsport *wrp = WR_DSPOR(ppi);
	wrp->parentWrConfig = wrp->parentWrModeOn = 0;
#endif

	memset(ppi->frgn_master, 0, sizeof(ppi->frgn_master));
	ppi->frgn_rec_num = 0;          /* no known master */
	
	ppi->frgn_rec_best = -1;

	/* just tell that the link is down now */
	ppi->link_up = FALSE;
	ptp_enabled = 0;
	ppi->next_state = PPS_DISABLED;
	pp_leave_current_state(ppi);
	ppi->n_ops->exit(ppi);
	
	ppi->servo->servo_state_name = "LINK_DOWN";
	if( ppi->ext_hooks->servo_reset) {
		(*ppi->ext_hooks->servo_reset)(ppi);

	}
#if CONFIG_HAS_EXT_WR
	/* FIXME: this should be done in a different place and in a nicer way.
	    This dirty hack was introduce to force re-doing of WR Link Setup
	    when a link goes down and then up. */
	if (ppi->ext_data)
		WRH_SRV(ppi)->doRestart = TRUE;
#endif
	pp_close_globals(&ppg_static);

	return 0;
}

int wrc_ptp_link_down(void)
{
	/* special case, keep PPS on for GM and Master */
	if (ptp_mode == WRC_MODE_MASTER || ptp_mode == WRC_MODE_GM) {
		wrpc_enable_timing_output(ppg, 1);
		/* if spll not in SPLL_MODE_FREE_RUNNING_MASTER/GM,
		    Can happen if fiber is unplugged between locking spll in slave mode
		    and entering PP_SLAVE state */
		if (WRPC_ARCH_G(ppg)->timingMode == WRH_TM_BOUNDARY_CLOCK) {
			WRPC_ARCH_G(ppg)->timingMode = WRH_TM_FREE_MASTER;
			spll_init(SPLL_MODE_FREE_RUNNING_MASTER, 0, SPLL_FLAG_ALIGN_PPS);
		}
	}
	return 0;
}

int wrc_ptp_run(int start_stop_query)
{
	switch(start_stop_query) {
	case 0:
		return wrc_ptp_stop();
	case 1:
		return wrc_ptp_start();
	default:
		return ptp_enabled;
	}
}

/* this returns whether or not the function did any work */
int wrc_ptp_update(void)
{
	int l;
	int now;
	struct pp_instance *ppi = &ppi_static;

	if (!ptp_enabled)
		return 0;

	if (ppi->state != PPS_INITIALIZING) {
		/* Try to receive only after initialization (which initialize
		   the socket too */
		l = __recv_and_count(ppi, ppi->rx_frame, PP_MAX_FRAME_LENGTH - 4,
				     &ppi->last_rcv_time);
		if (l) {
			delay_ms = pp_state_machine(ppi, ppi->rx_ptp, l);
			return 1;
		}
	}

#if TICS_PER_SECOND != 1000
#error "TICS_PER_SECOND must be 1000"
#endif
	now = timer_get_tics();
	if ((now - start_tics) < delay_ms)
		return 0;

	/* Nothing received, but timeout elapsed */
	start_tics = now;
	delay_ms = pp_state_machine(ppi, NULL, 0);
	return 1;
}

/* this returns whether or not the function did any work */
int wrc_ptp_bmc_update(void)
{
	static int start_tics_bmc;

	if (!ptp_enabled || wrc_ptp_is_abscal()) {
	    /* ptp disabled */
	    return 0;
	}

	/* BMCA must run at least once per announce interval 9.2.6.8 */
	if (timer_get_tics() - start_tics_bmc < TMO_DEFAULT_BMCA_MS) {
		/* not yet */
		return 0;
	}

	start_tics_bmc = timer_get_tics();
	bmc_calculate_ebest(ppg);
	return 1;
}

int wrc_pps_force(wrpc_pps_force_t action)
{
	if (action == pps_force_check) {
		/* wrpc_pps_force_t is mapped to values forcePpsGen */
		return GOPTS(ppg)->forcePpsGen;
	}
	GOPTS(ppg)->forcePpsGen = action & 1; /* 0 or 1 */
	/* Disable pps generation if needed; according to forcePpsGen */
	wrpc_enable_timing_output(ppg, 2);
	return action & 1;
}

int wrc_ptp_is_abscal(void)
{
	return ptp_mode == WRC_MODE_ABSCAL;
}

/* lm32's compiler does not remove strings used in the function if
 * the function is optimized out. So if the option is not used don't include
 * (the not optimized out strings in) functions wrpc_ptp_set*. Ugly but can be
 * repoved when LM32's support is dropped. */
#if (defined CONFIG_CMD_PTP_ADV && defined CONFIG_ARCH_LM32) || defined CONFIG_ARCH_RISCV
static int assign_ptp_param(char *name, int *param, int value, int min, int max)
{
	int running;

	if (value == -1) {
		pp_printf("%s = %d\n", name, *param);
		return 0;
	}

	if (value < min || value > max) {
		/* value out of range */
		return -EINVAL;
	}

	running = wrc_ptp_run(-1);
	wrc_ptp_run(0);
	*param = value;
	/* copy updated parameters from rt_opts */
	bmc_apply_configured_device_attributes(ppg);
	wrc_ptp_run(running);
	return 0;
}

int wrc_ptp_set_prio1(int prio1)
{
	return assign_ptp_param("prio1", &__pp_default_rt_opts.priority1,
				prio1, PP_MIN_PRIORITY1, PP_MAX_PRIORITY1);
}

int wrc_ptp_set_prio2(int prio2)
{
	return assign_ptp_param("prio2", &__pp_default_rt_opts.priority2,
				prio2, PP_MIN_PRIORITY2, PP_MAX_PRIORITY2);
}

int wrc_ptp_set_domain_number(int domain)
{
	return assign_ptp_param("domain", &__pp_default_rt_opts.domainNumber,
				domain, PP_MIN_DOMAIN_NUMBER,
				PP_MAX_DOMAIN_NUMBER);
}

int wrc_ptp_set_clock_class(int clock_class)
{
	return assign_ptp_param("clock class",
				&__pp_default_rt_opts.clock_quality_clockClass,
				clock_class, PP_MIN_CLOCK_CLASS,
				PP_MAX_CLOCK_CLASS);
}

int wrc_ptp_set_clock_accuracy(int clock_accuracy)
{
	return assign_ptp_param("clock accuracy",
				&__pp_default_rt_opts.clock_quality_clockAccuracy,
				clock_accuracy, PP_MIN_CLOCK_ACCURACY,
				PP_MAX_CLOCK_ACCURACY);
}

int wrc_ptp_set_clock_allan_variance(int clock_allan_variance)
{
	return assign_ptp_param("clock allan variance",
				&__pp_default_rt_opts.clock_quality_offsetScaledLogVariance,
				clock_allan_variance, PP_MIN_CLOCK_VARIANCE,
				PP_MAX_CLOCK_VARIANCE);
}

int wrc_ptp_set_time_source(int time_source)
{
	return assign_ptp_param("time source",
				&__pp_default_rt_opts.timeSource,
				time_source, PP_MIN_TIME_SOURCE,
				PP_MAX_TIME_SOURCE);
}

#endif
