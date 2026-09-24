/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo, Jean-Claude BAU
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>
#include "../proto-standard/common-fun.h"

#ifdef CONFIG_ARCH_WRS
#include <libwr/shmem.h>
#define shmem_lock() wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);
#define shmem_unlock() wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
extern struct wrs_shm_head *ppsi_head;
#else
#define shmem_lock()
#define shmem_unlock()
#endif

static void pp_servo_mpd_fltr(struct pp_instance *, struct pp_avg_fltr *,
			      struct pp_time *);
static int pp_servo_offset_master(struct pp_instance *, struct pp_time *);
static int64_t pp_servo_pi_controller(struct pp_instance *, struct pp_time *);
static void _pp_servo_init(struct pp_instance *ppi);
static void __pp_servo_update(struct pp_instance *ppi);

void pp_servo_init(struct pp_instance *ppi)
{
	shmem_lock(); /* Share memory locked */
	_pp_servo_init(ppi);
	shmem_unlock(); /* Share memory unlocked */
}

static void _pp_servo_init(struct pp_instance *ppi)
{
	int d;
	struct pp_servo * servo=SRV(ppi);

	PP_SERVO_RESET_DATA(servo);
	servo->mpd_fltr.s_exp = 0;	/* clears meanDelay filter */
	if (TOPS(ppi)->init_servo) {
		/* The system may pre-set us to keep current frequency */
		d = TOPS(ppi)->init_servo(ppi);
		if (d == -1) {
			pp_diag(ppi, servo, 1, "error in t_ops->servo_init");
			d = 0;
		}
		servo->obs_drift = -d << 10; /* note "-" */
	} else {
		/* level clock */
		if (pp_can_adjust(ppi))
			TOPS(ppi)->adjust(ppi, 0, 0);
		servo->obs_drift = 0;
	}

	servo->flags |= PP_SERVO_FLAG_VALID;

	pp_diag(ppi, servo, 1, "Initialized: obs_drift %lli\n",
			servo->obs_drift);
}

#define SHIFT64 64
#define SHIFT32 32
#define BITS_IN_INT64 (sizeof(int64_t)*8)
#define LOW_OVERFLOW 1
#define HI32(x)	((x) >> 32)
#define LO32(x)	((x) & (uint64_t)0x0ffffffff)

static int __getMsbSet(uint64_t value) {
	if ( value==0 )
		return 0; /* value=0 so return bit 0 */
	return BITS_IN_INT64 - __builtin_clzll(value); /* using gcc built-in function */
}

/*
 * Multiplication of two 64 bits numbers by:
 * - splitting op1 and op2 into two 32 bit integers
 * - multiplying every number
 * - shifting and adding every number to get the most accurate 64 bit integer
 * Parameters:
 *  - op1 (first operand): a 2^62 scaled value. op1 must be positive
 *  - op2 (second operand): a 2^X scaled value. op2 must be positive
 *  Return :
 *   (op1 x op2)/2^62. The returned value is a 2^X scaled value
 *
 * Based on Rens Roosenstein work.
 * See the gitlab site https://gitlab.com/ohwr/project/wr-fixed-point-calculations for further information.
 */
static uint64_t __mulRelativeDifference(RelativeDifference op1, uint64_t op2)
{
	int shift;
	uint64_t mask;

	shift = BITS_IN_INT64 - __getMsbSet((op1 < op2) ? op1 : op2); // Calc value of shift with most significant bit

	if(shift > 32)
		shift = 32; // Limit shift to 32 bits

	mask= (1 << (32 - shift)) - 1; // Generate the mask

	uint64_t op1_high = HI32(op1);							// splitting into two 32 bit integers
	uint64_t op1_low = LO32(op1);							//
	uint64_t op2_high = HI32(op2);							//
	uint64_t op2_low = LO32(op2);							//

	uint64_t upper = (op1_high * op2_high)<<shift;			// multiplication
	uint64_t mid1 = op1_high * op2_low;						//
	uint64_t mid2 = op2_high * op1_low;						//
	uint64_t lower = (op1_low * op2_low)>>LOW_OVERFLOW;		// potential overflow correction
	uint64_t middle, tmp;

	middle = mid1 + mid2;

	if ((middle < mid1) || (middle < mid2))					// Overflow + shifting
	    upper += ((uint64_t)1 << SHIFT32);					//
	upper += (middle & ~mask) >> (SHIFT32-shift);			//
	tmp = lower;											//
	lower += ((middle & mask) << (SHIFT32-LOW_OVERFLOW));	//

	if (lower < tmp)
		upper += 1;

	return (upper + (lower>>(SHIFT64-shift-LOW_OVERFLOW)))>>(shift-2);	// scale back
}

/**
 * Calculate the delayAsymmetry : delayAsymCoeff * meanDelay
 *
 * This calculation is made in order to use the maximum of bits in the fraction part. It will depend
 * on the value of delayAsymCoeff and meanDelay. The smaller these values will be, bigger
 * the fraction part will be.
 */
static TimeInterval calculateDelayAsymmetry(RelativeDifference scaledDelayAsymCoeff, TimeInterval scaledMeanDelay, TimeInterval constantAsymmetry) {
	int  negDelayAsymCoeff;
	int  negMeanDelay;

	if ( (negMeanDelay=(scaledMeanDelay<0))==TRUE )
		scaledMeanDelay=-scaledMeanDelay;

	if ( (negDelayAsymCoeff=(scaledDelayAsymCoeff<0))==TRUE )
		scaledDelayAsymCoeff=-scaledDelayAsymCoeff;

	TimeInterval delayAsym = __mulRelativeDifference(scaledDelayAsymCoeff, scaledMeanDelay);

	return constantAsymmetry +(( negDelayAsymCoeff != negMeanDelay) ? -delayAsym : delayAsym);
}

/*
 * Calculation of delay asymmetry with polynomial expansion
 *
 * Based on Rens Roosenstein work.
 * See the gitlab site https://gitlab.com/ohwr/project/wr-fixed-point-calculations for further information.
 */

RelativeDifference pp_servo_calculateDelayAsymCoefficient(RelativeDifference delayCoeff){

	uint64_t term;
	RelativeDifference delayAsymCoeff;
	int negative;
	int sub = 1;

	if((negative=(delayCoeff < 0))==TRUE) // checking whether alpha is negative
		delayCoeff=-delayCoeff;

	delayAsymCoeff = delayCoeff >> 1;  // alpha/2

	term  = __mulRelativeDifference(delayCoeff, delayAsymCoeff) >> 1;	// first term of polynomial expansion

	while(term > 2){									// do polynomial expansion until term = 0
		if( !negative){									// if alpha is positive
			delayAsymCoeff = sub ?
				delayAsymCoeff - term :
				delayAsymCoeff +term;
			sub = !sub;									// Invert for next iteration
		} else {										// if alpha is negative
			delayAsymCoeff += term+1;							//
		}
		term = __mulRelativeDifference(delayCoeff, term) >> 1;
	}

	return negative ? -delayAsymCoeff : delayAsymCoeff;		// units of delayAsymCoeff = [ns]*2^62
}

static int calculate_p2p_delayMM(struct pp_instance *ppi) {
	struct pp_servo *servo=SRV(ppi);
	struct pp_time mtime, stime; /* Avoid modifying stamps in place*/
	static int errcount;

	if (is_timestamp_incorrect_thres(ppi,&errcount, 0x3C /* t3,t4,t5,t6*/))
		return 0; /* Error. Invalid timestamps */

	if (__PP_DIAG_ALLOW(ppi, pp_dt_servo, 2)) {
		pp_diag(ppi, servo, 2, "T3: %s s\n", time_to_string(&ppi->t3));
		pp_diag(ppi, servo, 2, "T4: %s s\n", time_to_string(&ppi->t4));
		pp_diag(ppi, servo, 2, "T5: %s s\n", time_to_string(&ppi->t5));
		pp_diag(ppi, servo, 2, "T6: %s s\n", time_to_string(&ppi->t6));
	}
	/*
	 * Calculate of the round trip delay (delayMM)
	 * delayMM = (t6-t3)-(t5-t4)
	 */

	stime = servo->t6; pp_time_sub(&stime, &servo->t3);
	mtime = servo->t5; pp_time_sub(&mtime, &servo->t4);
	servo->delayMM = stime;
	pp_time_sub(&servo->delayMM, &mtime);
	return 1;
}

static int calculate_e2e_delayMM(struct pp_instance *ppi) {
	struct pp_servo *servo=SRV(ppi);
	struct pp_time mtime, stime; /* Avoid modifying stamps in place*/
	static int errcount;

	if (is_timestamp_incorrect_thres(ppi, &errcount, 0xF /* t1,t2,t3,t4 */))
		return 0; /* Error. Invalid timestamps */

	if (__PP_DIAG_ALLOW(ppi, pp_dt_servo, 2)) {
		pp_diag(ppi, servo, 2, "T1: %s s\n", time_to_string(&servo->t1));
		pp_diag(ppi, servo, 2, "T2: %s s\n", time_to_string(&servo->t2));
		pp_diag(ppi, servo, 2, "T3: %s s\n", time_to_string(&servo->t3));
		pp_diag(ppi, servo, 2, "T4: %s s\n", time_to_string(&servo->t4));
	}
	/*
	 * Calculate the round trip delay (delayMM)
	 * delayMM = t4-t1-(t3-t2)
	 */
	mtime = servo->t4;
	pp_time_sub(&mtime, &servo->t1);
	stime = servo->t3;
	pp_time_sub(&stime, &servo->t2);
	servo->delayMM = mtime;
	pp_time_sub(&servo->delayMM, &stime);
	return 1;
}

int pp_servo_calculate_delays(struct pp_instance *ppi) {
	int64_t  meanDelay_ps,delayMM_ps,delayMS_ps;
	static int errcount;
	struct pp_servo *servo=SRV(ppi);
	int ret;

	/* t1/t2 needed by both P2P and E2E calculation */
	if (is_timestamp_incorrect_thres(ppi, &errcount, 0x3 /* t1,t2 */))
		return 0; /* Error. Invalid timestamps */

	ret= is_delayMechanismP2P(ppi) ?
			calculate_p2p_delayMM(ppi)
			: calculate_e2e_delayMM(ppi);
	if ( !ret)
		return 0; /* delays cannot be calculated */

	delayMM_ps = pp_time_to_picos(&servo->delayMM);

	/*
	 * Calculate the meanDelay
	 * meanDelay=delayMM/2)
	 */
	meanDelay_ps=delayMM_ps>>1; /* meanDelay=delayMM/2 */

	if ( ppi->asymmetryCorrectionPortDS.enable ) {
		/* Enabled: The delay asymmetry must be calculated
		 * delayAsymmetry=delayAsymCoefficient * meanPathDelay
		 */
		ppi->portDS->delayAsymmetry=calculateDelayAsymmetry(ppi->portDS->delayAsymCoeff,
				picos_to_interval(meanDelay_ps),
				ppi->asymmetryCorrectionPortDS.constantAsymmetry);
	} else {
		/* Disabled: The delay asymmetry is provided by configuration */
		ppi->portDS->delayAsymmetry=ppi->asymmetryCorrectionPortDS.constantAsymmetry;
	}
	/* delayMS = meanDelay + delayAsym */
	delayMS_ps = meanDelay_ps + interval_to_picos(ppi->portDS->delayAsymmetry);
	picos_to_pp_time(delayMS_ps, &servo->delayMS);
	/* Calculate offsetFromMaster : t1-t2+meanDelay+delayAsym=t1-t2+delayMS */
	servo->offsetFromMaster = servo->t1;
	pp_time_sub(&servo->offsetFromMaster, &servo->t2);
	pp_time_add(&servo->offsetFromMaster, &servo->delayMS); /* Add delayMS */

	if ( ppi->state==PPS_SLAVE )
		DSCUR(ppi)->offsetFromMaster = pp_time_to_interval(&servo->offsetFromMaster);  /* Update currentDS.offsetFromMaster */

	picos_to_pp_time(meanDelay_ps,&servo->meanDelay); /* update servo.meanDelay */
	update_meanDelay(ppi,picos_to_interval(meanDelay_ps)); /* update currentDS.meanDelay and portDS.meanLinkDelay (if needed) */

	if (__PP_DIAG_ALLOW(ppi, pp_dt_servo, 2)) {
		pp_diag(ppi, servo, 2,"delayMM         : %s s\n", time_to_string(&servo->delayMM));
		pp_diag(ppi, servo, 2,"delayMS         : %s s\n", time_to_string(&servo->delayMS));
		pp_diag(ppi, servo, 2,"delayAsym       : %s ns\n", interval_to_string(ppi->portDS->delayAsymmetry));
		pp_diag(ppi, servo, 2,"delayAsymCoeff  : %s ns\n", relative_interval_to_string(ppi->portDS->delayAsymCoeff));
		pp_diag(ppi, servo, 2,"meanDelay       : %s s\n", time_to_string(&servo->meanDelay));
		pp_diag(ppi, servo, 2,"offsetFromMaster: %s s\n", time_to_string(&servo->offsetFromMaster));
	}
	return 1;
}

static void control_timing_output(struct pp_instance *ppi) {
	uint64_t offsetPs = pp_time_to_picos(&SRV(ppi)->offsetFromMaster);
	int offsetFromMasterUs;

	__div64_32(&offsetPs, 1000000);
	offsetFromMasterUs = offsetPs;

	int ptpPpsThresholdUs=OPTS(ppi)->ptpPpsThresholdMs*1000;

	/* activate timing output if abs(offsetFromMasterMs)<ptpPpsThreshold */
	if ( offsetFromMasterUs<0)
		offsetFromMasterUs=-offsetFromMasterUs;

	if ( offsetFromMasterUs<=ptpPpsThresholdUs ) {
		TOPS(ppi)->enable_timing_output(GLBS(ppi),1);
	} else {
		if ( !OPTS(ppi)->forcePpsGen ) { /* if timing output forced, never stop it */
			/* disable only if abs(offsetFromMasterMs)>ptpPpsThresholdMs+20% */
			ptpPpsThresholdUs+=ptpPpsThresholdUs/5;
			if ( offsetFromMasterUs>ptpPpsThresholdUs ) {
				TOPS(ppi)->enable_timing_output(GLBS(ppi),0);
			}
		}
	}
}

/* Called by slave and uncalib when we have t1 and t2 */
/* t1 & t2  are already checked and they are correct */
void pp_servo_got_sync(struct pp_instance *ppi, int allowTimingOutput)
{
	struct pp_servo *servo=SRV(ppi);

	shmem_lock(); /* Share memory locked */

	servo->t1=ppi->t1;
	servo->t2=ppi->t2;
	if ( is_delayMechanismP2P(ppi) && servo->got_sync) {
		/* P2P mechanism */
		servo->got_sync=0;
		__pp_servo_update(ppi);
		if (allowTimingOutput ) {
			control_timing_output(ppi);
		}
	} else
		servo->got_sync=1;

	shmem_unlock(); /* Share memory locked */
}

/* called by slave states when delay_resp is received (all t1..t4 are valid) */
int pp_servo_got_resp(struct pp_instance *ppi, int allowTimingOutput)
{
	struct pp_servo *servo=SRV(ppi);
	static int errcount=0;

	if ( !servo->got_sync )
		return 0; /* t1 & t2 not available yet */
	servo->got_sync=0;  /* reseted for next time */


	if (is_timestamp_incorrect_thres(ppi, &errcount, 0xC /* t3,t4 */))
		return 0;

	shmem_lock(); /* Share memory locked */

	/* Save t3 and t4 */
	servo->t3=ppi->t3;
	servo->t4=ppi->t4;

	__pp_servo_update(ppi);

	shmem_unlock(); /* Share memory locked */

	if (allowTimingOutput)
		control_timing_output(ppi);

	return 1;
}

/* called by slave states when delay_resp is received (all t1..t4 are valid) */
int pp_servo_got_presp(struct pp_instance *ppi)
{
	struct pp_servo * servo = SRV(ppi);
	static int errcount=0;

	if (is_timestamp_incorrect_thres(ppi, &errcount, 0x3C /* t3-t6 */))
		return 0;

	shmem_lock(); /* Share memory locked */

	servo->t3=ppi->t3;
	servo->t4=ppi->t4;
	servo->t5=ppi->t5;
	servo->t6=ppi->t6;
	servo->got_sync=1;

	shmem_unlock(); /* Share memory unlocked */
	return 1;
}


static void __pp_servo_update(struct pp_instance *ppi) {
	struct pp_servo *servo=SRV(ppi);
	struct pp_time *meanDelay =&servo->meanDelay;
	struct pp_avg_fltr *meanDelayFilter = &servo->mpd_fltr;
	struct pp_time *offsetFromMaster = &servo->offsetFromMaster;
	int adj32;

	if ( !pp_servo_calculate_delays(ppi) )
		return;

	if (meanDelay->secs) /* Hmm.... we called this "bad event" */
		return;

	pp_servo_mpd_fltr(ppi, meanDelayFilter, meanDelay);

	/* update 'offsetFromMaster' and possibly jump in time */
	if (!pp_servo_offset_master(ppi,offsetFromMaster)) {

		/* PI controller returns a scaled_nsecs adjustment, so shift back */
		adj32 = (int)(pp_servo_pi_controller(ppi, offsetFromMaster) >> 16);

		/* apply controller output as a clock tick rate adjustment, if
		 * provided by arch, or as a raw offset otherwise */
		if (pp_can_adjust(ppi)) {
			if (TOPS(ppi)->adjust_freq)
				TOPS(ppi)->adjust_freq(ppi, adj32);
			else
				TOPS(ppi)->adjust_offset(ppi, adj32);
		}

		pp_diag(ppi, servo, 2, "Observed drift: %9i\n",
			(int)SRV(ppi)->obs_drift >> 10);
	}
	servo->update_count++;
	TOPS(ppi)->get(ppi, &servo->update_time);

}

static void pp_servo_mpd_fltr(struct pp_instance *ppi, struct pp_avg_fltr *meanDelayFilter,
		       struct pp_time *meanDelay)
{
	int s;
	uint64_t y;

	if (meanDelayFilter->s_exp < 1) {
		/* First time, keep what we have */
		meanDelayFilter->y = meanDelay->scaled_nsecs;
		if (meanDelay->scaled_nsecs < 0)
			meanDelayFilter->y = 0;
	}
	/* avoid overflowing filter: calculate number of bits */
	s = OPTS(ppi)->s;
	while (meanDelayFilter->y >> (63 - s))
		--s;
	if (meanDelayFilter->s_exp > 1LL << s)
		meanDelayFilter->s_exp = 1LL << s;
	/* crank down filter cutoff by increasing 's_exp' */
	if (meanDelayFilter->s_exp < 1LL << s)
		++meanDelayFilter->s_exp;

	/*
	 * It may happen that mpd appears as negative. This happens when
	 * the slave clock is running fast to recover a late time: the
	 * (t3 - t2) measured in the slave appears longer than the (t4 - t1)
	 * measured in the master.  Ignore such values, by keeping the
	 * current average instead.
	 */
	if (meanDelay->scaled_nsecs < 0)
		meanDelay->scaled_nsecs = meanDelayFilter->y;
	if (meanDelay->scaled_nsecs < 0)
		meanDelay->scaled_nsecs = 0;

	/*
	 * It may happen that mpd appears to be very big. This happens
	 * when we have software timestamps and there is overhead
	 * involved -- or when the slave clock is running slow.  In
	 * this case use a value just slightly bigger than the current
	 * average (so if it really got longer, we will adapt).  This
	 * kills most outliers on loaded networks.
	 * The constant multipliers have been chosed arbitrarily, but
	 * they work well in testing environment.
	 */
	if (meanDelay->scaled_nsecs > 3 * meanDelayFilter->y) {
		pp_diag(ppi, servo, 1, "Trim too-long mpd: %i\n",
			(int)(meanDelay->scaled_nsecs >> 16));
		/* add fltr->s_exp to ensure we are not trapped into 0 */
		meanDelay->scaled_nsecs = meanDelayFilter->y * 2 + meanDelayFilter->s_exp + 1;
	}
	/* filter 'meanDelay' (running average) -- use an unsigned "y" */
	y = (meanDelayFilter->y * (meanDelayFilter->s_exp - 1) + meanDelay->scaled_nsecs);
	__div64_32(&y, meanDelayFilter->s_exp);
	meanDelay->scaled_nsecs =	meanDelayFilter->y = y;
	update_meanDelay(ppi,pp_time_to_interval(meanDelay)); /* update currentDS.meanDelay and portDS.meanLinkDelay (idf needed) */
	pp_diag(ppi, servo, 1, "After avg(%i), meanDelay: %s \n",
		(int)meanDelayFilter->s_exp, time_to_string(meanDelay));
}

/* Thresholds are used to decide if we must use time or frequency adjustment
 * 20ms: This is the minimum value because it is used as a threshold to set the time in wrs_set_time() */
#define TIME_ADJUST_THRESHOLD_SCALED_NS	(((int64_t)20000000)<<TIME_INTERVAL_FRACBITS) /* 20ms */
#define TIME_ADJUST_THRESHOLD_SEC 0

static int pp_servo_offset_master(struct pp_instance *ppi, struct pp_time *ofm)
{
	struct pp_time time_tmp;

	if ( !( ofm->secs ||
			(ofm->scaled_nsecs>TIME_ADJUST_THRESHOLD_SCALED_NS ) ||
			(ofm->scaled_nsecs<-TIME_ADJUST_THRESHOLD_SCALED_NS)
			)) {
		return 0; /* proceeed with adjust */
	}

	if (!pp_can_adjust(ppi))
		return 0; /* e.g., a loopback test run... "-t" on cmdline */

	TOPS(ppi)->get(ppi, &time_tmp);
	pp_time_add(&time_tmp, ofm);
	TOPS(ppi)->set(ppi, &time_tmp);

	_pp_servo_init(ppi);

	return 1; /* done */
}

static int64_t pp_servo_pi_controller(struct pp_instance * ppi, struct pp_time *ofm)
{
	long long I_term;
	long long P_term;
	long long tmp;
	int I_sign;
	int P_sign;
	int64_t adj;

	/* the accumulator for the I component */
	SRV(ppi)->obs_drift += ofm->scaled_nsecs;

	/* Anti-windup. The PP_ADJ_FREQ_MAX value is multiplied by OPTS(ppi)->ai
	 * (which is the reciprocal of the integral gain of the controller).
	 * Then it's scaled by 16 bits to match our granularity and
	 * avoid bit losses */
	tmp = (((long long)PP_ADJ_FREQ_MAX) * OPTS(ppi)->ai) << 16;
	if (SRV(ppi)->obs_drift > tmp)
		SRV(ppi)->obs_drift = tmp;
	else if (SRV(ppi)->obs_drift < -tmp)
		SRV(ppi)->obs_drift = -tmp;

	/* calculation of the I component, based on obs_drift */
	I_sign = (SRV(ppi)->obs_drift > 0) ? 0 : -1;
	I_term = SRV(ppi)->obs_drift;
	if (I_sign)
		I_term = -I_term;
	__div64_32((uint64_t *)&I_term, OPTS(ppi)->ai);
	if (I_sign)
		I_term = -I_term;

	/* calculation of the P component */
	P_sign = (ofm->scaled_nsecs > 0) ? 0 : -1;
	/* alrady shifted 16 bits, so we avoid losses */
	P_term = ofm->scaled_nsecs;
	if (P_sign)
		P_term = -P_term;
	__div64_32((uint64_t *)&P_term, OPTS(ppi)->ap);
	if (P_sign)
		P_term = -P_term;

	/* calculate the correction of applied by the controller */
	adj = P_term + I_term;
	/* Return the scaled-nanos values; the caller is scaling back */

	return adj;
}
