/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <ppsi/ppsi.h>

/**
 * This table show how a clock class is degraded.
 *  #######################################################################################################
 *  #   Initial             |  Degraded value      |Accuracy|Variance|timeSrc|PTP time|frequency|  time   #
 *  #   clock Class         |                      |        |        |       |  scale |traceable|traceable#
 *  #-----------------------------------------------------------------------------------------------------#
 *  # PTP_GM_LOCKED(6)      |PTP_GM_HOLDOVER(7)    | 100ns  | 0xC71D |INT_OSC|  TRUE  |  TRUE   |  TRUE   #
 *  # PTP_GM_LOCKED(6)      |PTP_GM_UNLOCKED_B(187)|Unknown | 0xC71D |INT_OSC|  TRUE  |  FALSE  |  FALSE  #
 *  # PTP_GM_HOLDOVER(7)    |PTP_GM_UNLOCKED_B(187)|Unknown | 0xC71D |INT_OSC|  TRUE  |  FALSE  |  FALSE  #
 *  # ARB_GM_LOCKED(13)     |ARB_GM_HOLDOVER(14)   |  25ns  | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE  #
 *  # ARB_GM_LOCKED(13)     |ARB_GM_UNLOCKED_B(193)|Unknown | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE  #
 *  # ARB_GM_HOLDOVER(14)   |ARB_GM_UNLOCKED_B(193)|Unknown | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE  #
 *  # ARB_GM_UNLOCKED_A(58) |ARB_GM_UNLOCKED_A(58) |Unknown | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE  #
 *  # ARB_GM_UNLOCKED_B(193)|ARB_GM_UNLOCKED_B(193)|Unknown | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE  #
 *  ######################################################################################################
 *
 *  When a clock class is degraded, a field (clockAccuracy, logVariance, timeSource,
 *  ptpTimeScale, frequencyTraceable and timeTraceable) cannot be better that its initial value.
 *  In this case, we will leave it unchanged.
 */

typedef struct {
	unsigned char clockClass;
	unsigned char enable_timing_output;
	deviceAttributesDegradation_t holdover;
	deviceAttributesDegradation_t unlocked;
} clockDegradation_t;

static const clockDegradation_t clockDegradation[]= {
	// PP_PTP_CLASS_GM_LOCKED
	{
		.clockClass=PP_PTP_CLASS_GM_LOCKED,
		.enable_timing_output=1,
		.holdover= {
			// PP_PTP_CLASS_GM_LOCKED + PLL holdover
			.clockQuality={
				.clockClass=PP_PTP_CLASS_GM_HOLDOVER,
				.clockAccuracy=PP_PTP_ACCURACY_GM_HOLDOVER,
				.offsetScaledLogVariance=PP_PTP_VARIANCE_GM_HOLDOVER,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=TRUE,
			.frequencyTraceable=TRUE,
			.timeTraceable=TRUE,
			.msg="holdover",
		},
		.unlocked= {
			// PP_PTP_CLASS_GM_LOCKED + PLL unlocked
			.clockQuality={
				.clockClass=PP_PTP_CLASS_GM_UNLOCKED_B,
				.clockAccuracy=PP_PTP_ACCURACY_GM_UNLOCKED_B,
				.offsetScaledLogVariance=PP_PTP_VARIANCE_GM_UNLOCKED_B,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=TRUE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="unlocked",
		},
	},
#ifndef CONFIG_CODEOPT_WRPC_SIZE
	// PP_ARB_CLASS_GM_LOCKED
	{
		.clockClass=PP_ARB_CLASS_GM_LOCKED,
		.holdover={
			// PP_ARB_CLASS_GM_LOCKED + PLL holdover
			.clockQuality={
				.clockClass=PP_ARB_CLASS_GM_HOLDOVER,
				.clockAccuracy=PP_ARB_ACCURACY_GM_HOLDOVER,
				.offsetScaledLogVariance=PP_ARB_VARIANCE_GM_HOLDOVER,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=FALSE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="holdover",
		},
		.unlocked={
			// PP_ARB_CLASS_GM_LOCKED + PLL unlocked
			.clockQuality={
				.clockClass=PP_ARB_CLASS_GM_UNLOCKED_B,
				.clockAccuracy=CLOCK_ACCURACY_UNKNOWN,
				.offsetScaledLogVariance=PP_ARB_VARIANCE_GM_UNLOCKED_B,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=FALSE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="unlocked",
		}
	},
	// PP_ARB_CLASS_GM_UNLOCKED_A
	{
		.clockClass=PP_ARB_CLASS_GM_UNLOCKED_A,
		.holdover = {
			// PP_ARB_CLASS_GM_UNLOCKED_A + PLL holdover
			.clockQuality={
				.clockClass=PP_ARB_CLASS_GM_UNLOCKED_A,// No changes
				.clockAccuracy=CLOCK_ACCURACY_UNKNOWN,
				.offsetScaledLogVariance=PP_ARB_VARIANCE_GM_UNLOCKED_A,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=FALSE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="holdover",
		},
		.unlocked = {
			// PP_ARB_CLASS_GM_UNLOCKED_A + PLL unlocked
			.clockQuality={
				.clockClass=PP_ARB_CLASS_GM_UNLOCKED_A,// No changes
				.clockAccuracy=CLOCK_ACCURACY_UNKNOWN,
				.offsetScaledLogVariance=PP_ARB_VARIANCE_GM_UNLOCKED_A,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=FALSE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="unlocked",
		}
	},
#endif
	// PP_ARB_CLASS_GM_UNLOCKED_B
	{
		.clockClass=PP_ARB_CLASS_GM_UNLOCKED_B,
		.holdover= {
			// PP_ARB_CLASS_GM_UNLOCKED_B + PLL holdover
			.clockQuality={
				.clockClass=PP_ARB_CLASS_GM_UNLOCKED_B,
				.clockAccuracy=CLOCK_ACCURACY_UNKNOWN, // No changes
				.offsetScaledLogVariance=PP_ARB_VARIANCE_GM_UNLOCKED_B,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=FALSE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="holdover",
		},
		.unlocked={
			// PP_ARB_CLASS_GM_UNLOCKED_B + PLL unlocked
			.clockQuality={
				.clockClass=PP_ARB_CLASS_GM_UNLOCKED_B,
				.clockAccuracy=CLOCK_ACCURACY_UNKNOWN, // No changes
				.offsetScaledLogVariance=PP_ARB_VARIANCE_GM_UNLOCKED_B,
			},
			.timeSource=TIME_SRC_INTERNAL_OSCILLATOR,
			.ptpTimeScale=FALSE,
			.frequencyTraceable=FALSE,
			.timeTraceable=FALSE,
			.msg="unlocked",
		},
	},
};

/* lastTimingModeState for each clockDegration.
   Set to -1 to force initialization the first time.

   Ideally it should be part of the clockDegradation array, but only this
   value is modified.  Make it separate to reduce data size. */
static signed char clockDeg_lastTimingModeState[] =
{
	-1, 	// PP_PTP_CLASS_GM_LOCKED
#ifndef CONFIG_CODEOPT_WRPC_SIZE
	-1,	// PP_ARB_CLASS_GM_LOCKED
	-1,	// PP_ARB_CLASS_GM_UNLOCKED_A
#endif
	-1,	// PP_ARB_CLASS_GM_UNLOCKED_B
};

/**
 Default values for PTP device attributes
#############################################################################
       clock Class     |Accuracy|Variance|timeSrc|PTP time|frequency|  time
                       |        |        |       |  scale |traceable|traceable
------------------------------------------------------------------------------
 PTP_GM_LOCKED(6)      | 100ns  | 0xB900 | GNSS  |  TRUE  |  TRUE   |  TRUE
 PTP_GM_HOLDOVER(7)    | 100ns  | 0xC71D |INT_OSC|  TRUE  |  TRUE   |  TRUE
 PTP_GM_UNLOCKED_A(52) | Unknown| 0xC71D |INT_OSC|  TRUE  |  FALSE  |  FALSE
 PTP_GM_UNLOCKED_B(187)| Unknown| 0xC71D |INT_OSC|  TRUE  |  FALSE  |  FALSE
 ARB_GM_LOCKED(13)     |  25ns  | 0xB900 |ATM_CLK|  FALSE |  FALSE  |  FALSE
 ARB_GM_HOLDOVER(14)   |  25ns  | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE
 ARB_GM_UNLOCKED_A(58) |  25ns  | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE
 ARB_GM_UNLOCKED_B(193)|  25ns  | 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE
 OTHER                 | Unknown| 0xC71D |INT_OSC|  FALSE |  FALSE  |  FALSE
#############################################################################
*/
static const defaultDeviceAttributes_t defaultDeviceAttributes[] = {
	{ .clockClass =	PP_PTP_CLASS_GM_LOCKED,
	  .clock_quality_clockAccuracy = PP_PTP_ACCURACY_GM_LOCKED,
	  .clock_quality_offsetScaledLogVariance = PP_PTP_VARIANCE_GM_LOCKED,
	  .timeSource = PP_PTP_TIME_SOURCE_GM_LOCKED,
	  .ptpTimeScale=TRUE,
	  .frequencyTraceable=TRUE,
	  .timeTraceable=TRUE,
	},
	{ .clockClass =	PP_PTP_CLASS_GM_HOLDOVER,
	  .clock_quality_clockAccuracy = PP_PTP_ACCURACY_GM_HOLDOVER,
	  .clock_quality_offsetScaledLogVariance = PP_PTP_VARIANCE_GM_HOLDOVER,
	  .timeSource = PP_PTP_TIME_SOURCE_GM_HOLDOVER,
	  .ptpTimeScale=TRUE,
	  .frequencyTraceable=TRUE,
	  .timeTraceable=TRUE,
	},
#ifndef CONFIG_CODEOPT_WRPC_SIZE
	{ .clockClass =	PP_PTP_CLASS_GM_UNLOCKED_A,
	  .clock_quality_clockAccuracy = PP_PTP_ACCURACY_GM_UNLOCKED_A,
	  .clock_quality_offsetScaledLogVariance = PP_PTP_VARIANCE_GM_UNLOCKED_A,
	  .timeSource = PP_PTP_TIME_SOURCE_GM_UNLOCKED_A,
	  .ptpTimeScale=TRUE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	},
#endif
	{ .clockClass =	PP_PTP_CLASS_GM_UNLOCKED_B,
	  .clock_quality_clockAccuracy = PP_PTP_ACCURACY_GM_UNLOCKED_B,
	  .clock_quality_offsetScaledLogVariance = PP_PTP_VARIANCE_GM_UNLOCKED_B,
	  .timeSource = PP_PTP_TIME_SOURCE_GM_UNLOCKED_B,
	  .ptpTimeScale=TRUE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	},
#ifndef CONFIG_CODEOPT_WRPC_SIZE
	{ .clockClass =	PP_ARB_CLASS_GM_LOCKED,
	  .clock_quality_clockAccuracy = PP_ARB_ACCURACY_GM_LOCKED,
	  .clock_quality_offsetScaledLogVariance = PP_ARB_VARIANCE_GM_LOCKED,
	  .timeSource = PP_ARB_TIME_SOURCE_GM_LOCKED,
	  .ptpTimeScale=FALSE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	},
	{ .clockClass =	PP_ARB_CLASS_GM_HOLDOVER,
	  .clock_quality_clockAccuracy = PP_ARB_ACCURACY_GM_HOLDOVER,
	  .clock_quality_offsetScaledLogVariance = PP_ARB_VARIANCE_GM_HOLDOVER,
	  .timeSource = PP_PTP_TIME_SOURCE_GM_HOLDOVER,
	  .ptpTimeScale=FALSE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	},
	{ .clockClass =	PP_ARB_CLASS_GM_UNLOCKED_A,
	  .clock_quality_clockAccuracy = PP_ARB_ACCURACY_GM_UNLOCKED_A,
	  .clock_quality_offsetScaledLogVariance = PP_ARB_VARIANCE_GM_UNLOCKED_A,
	  .timeSource = PP_ARB_TIME_SOURCE_GM_UNLOCKED_A,
	  .ptpTimeScale=FALSE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	},
#endif
	{ .clockClass =	PP_ARB_CLASS_GM_UNLOCKED_B,
	  .clock_quality_clockAccuracy = PP_ARB_ACCURACY_GM_UNLOCKED_B,
	  .clock_quality_offsetScaledLogVariance = PP_ARB_VARIANCE_GM_UNLOCKED_B,
	  .timeSource = PP_ARB_TIME_SOURCE_GM_UNLOCKED_B,
	  .ptpTimeScale=FALSE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	},
	{ .clockClass =	-1, // The last set is the default to use if the clock class is not found
	  .clock_quality_clockAccuracy = PP_ACCURACY_DEFAULT,
	  .clock_quality_offsetScaledLogVariance = PP_VARIANCE_DEFAULT,
	  .timeSource = PP_TIME_SOURCE_DEFAULT,
	  .ptpTimeScale=FALSE,
	  .frequencyTraceable=FALSE,
	  .timeTraceable=FALSE,
	}
};

void bmc_update_clock_quality(struct pp_globals *ppg)
{
	const char *pp_diag_msg;
	defaultDS_t *defDS=ppg->defaultDS;
	struct pp_runtime_opts *rt_opts = ppg->rt_opts;
	int rt_opts_clock_quality_clockClass=rt_opts->clock_quality_clockClass;
	pp_timing_mode_state_t timing_mode_state;
	const clockDegradation_t *clkDeg=clockDegradation;
	signed char *lastTimingModeState;
	int i;

	/* Check if we are concerned by this clock class */
	for (i=0; i<ARRAY_SIZE(clockDegradation); i++ )
		if (rt_opts_clock_quality_clockClass==clkDeg->clockClass )
			break; // This clock class need to be checked
		else
			clkDeg++;
	if ( i>=ARRAY_SIZE(clockDegradation) )
		return; // No degradation possible for this clock class

	lastTimingModeState = &clockDeg_lastTimingModeState[i];
	
	/* Get the clock status ( locked, holdover, unlocked ) */
	if (TOPS(INST(ppg,0))->get_GM_lock_state(ppg,&timing_mode_state) ) {
		pp_diag(NULL, bmc, 1,
			"Could not get GM locking state, taking old clock class: %i\n",
			ppg->defaultDS->clockQuality.clockClass);
		return;
	}

	pp_diag_clear_msg(pp_diag_msg);

	if (*lastTimingModeState != timing_mode_state) {
		// Changes detected
		if ( timing_mode_state == PP_TIMING_MODE_STATE_LOCKED) {
			// PLL locked: return back to the initial clock class
			// We restore the initial configured settings
			bmc_apply_configured_device_attributes(ppg);
			if ( clkDeg->enable_timing_output)
				TOPS(INST(ppg,0))->enable_timing_output(ppg,1); /* Enable PPS generation */
			pp_diag_set_msg(pp_diag_msg,"locked");
		} else {
			const deviceAttributesDegradation_t *devAttr =
					timing_mode_state== PP_TIMING_MODE_STATE_UNLOCKED ?
							&clkDeg->unlocked : &clkDeg->holdover;
			// The clock is degraded
			// We apply new settings if they can be applied
			timePropertiesDS_t *tpDS=GDSPRO(ppg);

			defDS->clockQuality.clockClass=devAttr->clockQuality.clockClass;
			if (devAttr->clockQuality.clockAccuracy>(Enumeration8)rt_opts->clock_quality_clockAccuracy )
				defDS->clockQuality.clockAccuracy=devAttr->clockQuality.clockAccuracy;
			if (devAttr->clockQuality.offsetScaledLogVariance>(UInteger16)rt_opts->clock_quality_offsetScaledLogVariance)
				defDS->clockQuality.offsetScaledLogVariance=devAttr->clockQuality.offsetScaledLogVariance;
			if ( devAttr->timeSource > rt_opts->timeSource)
				tpDS->timeSource=devAttr->timeSource;
			if ( rt_opts->ptpTimeScale )
				tpDS->ptpTimescale=devAttr->ptpTimeScale;
			if ( rt_opts->frequencyTraceable )
				tpDS->frequencyTraceable=devAttr->frequencyTraceable;
			if ( rt_opts->timeTraceable )
				tpDS->timeTraceable=devAttr->timeTraceable;
			pp_diag_set_msg(pp_diag_msg,devAttr->msg);
		}
		*lastTimingModeState=timing_mode_state;
	}
	if ( pp_diag_is_msg_set(pp_diag_msg) ) {
		timePropertiesDS_t *tpDS=GDSPRO(ppg);
		pp_diag(NULL, bmc, 1,
				"Timing mode changed : %s, "
				"clock class: %d"
				", clock accuracy: %d"
				", clock variance: 0x%04x"
				", timeSource: 0x%02x"
				", ptpTimeScale: %d"
				", frequencyTraceable: %d"
				", timeTraceable: %d"
				"\n",
				pp_diag_get_msg(pp_diag_msg),
				defDS->clockQuality.clockClass,
				defDS->clockQuality.clockAccuracy,
				defDS->clockQuality.offsetScaledLogVariance,
				tpDS->timeSource,
				tpDS->ptpTimescale,
				tpDS->frequencyTraceable,
				tpDS->timeTraceable);
	}
}


void bmc_set_default_device_attributes (struct pp_globals *ppg) {
	const defaultDeviceAttributes_t *pDef=defaultDeviceAttributes;
	struct pp_runtime_opts *rt_opts=ppg->rt_opts;
	int clockClass=rt_opts->clock_quality_clockClass;

	while ( pDef->clockClass!=clockClass && pDef->clockClass!=-1)
		pDef++;
/*	if (pDef->clockClass == -1)
		pp_printf("%s clockClass %d not found\n", __func__, pDef->clockClass);*/
	if ( rt_opts->clock_quality_clockAccuracy==-1 )
		rt_opts->clock_quality_clockAccuracy=(unsigned)pDef->clock_quality_clockAccuracy;
	if ( rt_opts->clock_quality_offsetScaledLogVariance==-1 )
		rt_opts->clock_quality_offsetScaledLogVariance=(unsigned)pDef->clock_quality_offsetScaledLogVariance;
	if ( rt_opts->timeSource==-1 )
		rt_opts->timeSource=(unsigned)pDef->timeSource;
	if ( rt_opts->ptpTimeScale==-1 )
		rt_opts->ptpTimeScale=pDef->ptpTimeScale;
	if ( rt_opts->frequencyTraceable==-1 )
		rt_opts->frequencyTraceable=pDef->frequencyTraceable;
	if ( rt_opts->timeTraceable==-1 )
		rt_opts->timeTraceable=pDef->timeTraceable;
}


/**
 *  Update defaultDS & timePropertiesDS with configured setting
 */
void bmc_apply_configured_device_attributes(struct pp_globals *ppg) {
	struct pp_runtime_opts *rt_opts=ppg->rt_opts;
	timePropertiesDS_t *tpDS=GDSPRO(ppg);
	defaultDS_t *defDS=ppg->defaultDS;

	defDS->clockQuality.clockClass=rt_opts->clock_quality_clockClass;
	defDS->clockQuality.clockAccuracy=rt_opts->clock_quality_clockAccuracy;
	defDS->clockQuality.offsetScaledLogVariance=rt_opts->clock_quality_offsetScaledLogVariance;
	tpDS->timeSource=rt_opts->timeSource;
	tpDS->ptpTimescale=rt_opts->ptpTimeScale;
	tpDS->frequencyTraceable=rt_opts->frequencyTraceable;
	tpDS->timeTraceable=rt_opts->timeTraceable;

	defDS->priority1 = rt_opts->priority1;
	defDS->priority2 = rt_opts->priority2;
	defDS->domainNumber = rt_opts->domainNumber;

}
