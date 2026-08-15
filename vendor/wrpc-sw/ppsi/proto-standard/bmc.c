/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

/* Flag Field bits symbolic names (table 57, pag. 151) */
#define FFB_LI61	0x01
#define FFB_LI59	0x02
#define FFB_UTCV	0x04
#define FFB_PTP		0x08
#define FFB_TTRA	0x10
#define FFB_FTRA	0x20

/* ppi->port_idx port is becoming Master. Table 13 (9.3.5) of the spec. */
void bmc_m1(struct pp_instance *ppi)
{
	parentDS_t *parent = DSPAR(ppi);
	defaultDS_t *defds = DSDEF(ppi);
	timePropertiesDS_t *prop = DSPRO(ppi);
	int ret = 0;
	int offset, leap59, leap61;

	/* Current data set update */
	DSCUR(ppi)->stepsRemoved =
			DSCUR(ppi)->offsetFromMaster=
					DSCUR(ppi)->meanDelay=0;
	clear_time(&SRV(ppi)->meanDelay);
	clear_time(&SRV(ppi)->offsetFromMaster);

	/* Parent data set: we are the parent */
	memset(parent, 0, sizeof(*parent));
	parent->parentPortIdentity.clockIdentity = defds->clockIdentity;
	parent->parentPortIdentity.portNumber = 0;

	/* Copy grandmaster params from our defds (FIXME: is ir right?) */
	parent->grandmasterIdentity = defds->clockIdentity;
	parent->grandmasterClockQuality = defds->clockQuality;
	parent->grandmasterPriority1 = defds->priority1;
	parent->grandmasterPriority2 = defds->priority2;

	/* Set currentUtcOffset and currentUtcOffsetValid
	 * If they cannot be set properly, frequencyTraceable & timeTraceable are cleared
	 */
	if (prop->ptpTimescale) {
		ret = TOPS(ppi)->get_utc_offset(ppi, &offset, &leap59, &leap61);
		if (ret) {
			offset = PP_DEFAULT_UTC_OFFSET;
			pp_diag(ppi, bmc, 1,
				"Could not get UTC offset from system, taking default: %i\n",
				offset);
		
		}
		
		if (prop->currentUtcOffset != offset) {
			pp_diag(ppi, bmc, 1, "New UTC offset: %i\n",offset);
			prop->currentUtcOffset = offset;
			TOPS(ppi)->set(ppi, NULL);
		}
		
		if (ret)
		{
			prop->currentUtcOffsetValid =
					prop->leap59 =
							prop->leap61 = FALSE;
		}
		else
		{
			prop->currentUtcOffsetValid = TRUE;
			prop->leap59 = (leap59 != 0);
			prop->leap61 = (leap61 != 0);
		}
	} else {
		/* 9.4 for ARB just take the value when built */
		prop->currentUtcOffset = PP_DEFAULT_UTC_OFFSET;
		/* always false */
		prop->currentUtcOffsetValid =
				prop->leap59 =
						prop->leap61 = FALSE;
	}
}

/* ppi->port_idx port is becoming Master. Table 13 (9.3.5) of the spec. */
void bmc_m2(struct pp_instance *ppi)
{
	/* same as m1, just call this then */
	bmc_m1(ppi);
	/* clockClass is > 127 and MASTER is a GRANDMASTER */
	if ( OPTS(ppi)->gmDelayToGenPpsSec>0 ) {
		/* Activate timing output after gmDelayToGenPps seconds */
		struct pp_globals * ppg=GLBS(ppi);
		if ( pp_gtimeout_is_disabled(ppg,PP_TO_GM_BY_BMCA)) {
			/* Start the timer */
			pp_gtimeout_set(ppg,PP_TO_GM_BY_BMCA,OPTS(ppi)->gmDelayToGenPpsSec*1000);
		} else {
			if ( pp_gtimeout(ppg,PP_TO_GM_BY_BMCA) ) {
				/* Grand master by BMCA validated: The timing output can be enabled */
				pp_gtimeout_disable(ppg,PP_TO_GM_BY_BMCA);
				pp_diag(ppi, time, 1, "Enable timing output (Grand master by BMCA)\n");
				TOPS(ppi)->enable_timing_output(ppg,1);
			}
		}
	}
}

/* ppi->port_idx port is becoming Master. Table 14 (9.3.5) of the spec. */
void bmc_m3(struct pp_instance *ppi)
{
	/* In the default implementation, nothing should be done when a port
	 * goes to master state at m3. This empty function is a placeholder for
	 * extension-specific needs, to be implemented as a hook */

	/* Disable timer (if needed) used to go to GM by BMCA */
	if ( OPTS(ppi)->gmDelayToGenPpsSec>0 )
		pp_gtimeout_disable(GLBS(ppi),PP_TO_GM_BY_BMCA);
}

/* ppi->port_idx port is synchronized to Ebest Table 16 (9.3.5) of the spec. */
void bmc_s1(struct pp_instance *ppi,
			struct pp_frgn_master *frgn_master)
{
	parentDS_t *parent = DSPAR(ppi);
	timePropertiesDS_t *prop = DSPRO(ppi);
	int ret = 0;
	int offset, leap59, leap61;
	int hours, minutes, seconds;

	/* Current DS */
	DSCUR(ppi)->stepsRemoved = frgn_master->stepsRemoved + 1;

	/* Check if it is a new foreign master
	 * In this case the BMCA state machine must be informed
	 * to transition form SLAVE to UNCALIBRATED state.
	 */
	parent->newGrandmaster=bmc_pidcmp(&parent->parentPortIdentity,&frgn_master->sourcePortIdentity)!=0;

	/* Parent DS */
	parent->parentPortIdentity = frgn_master->sourcePortIdentity;
	parent->grandmasterIdentity = frgn_master->grandmasterIdentity;
	parent->grandmasterClockQuality = frgn_master->grandmasterClockQuality;
	parent->grandmasterPriority1 = frgn_master->grandmasterPriority1;
	parent->grandmasterPriority2 = frgn_master->grandmasterPriority2;

	/* Timeproperties DS */
	prop->ptpTimescale = ((frgn_master->flagField[1] & FFB_PTP) != 0);
	
	if (prop->ptpTimescale) {
		ret = TOPS(ppi)->get_utc_time(ppi, &hours, &minutes, &seconds);
		if (ret) {
			/* "Could not get UTC time from system, taking received flags\n"; */
			pp_diag(ppi, bmc, 1, 
				"Could not get UTC %s from system, taking received flags\n", "time");
			prop->leap59 = ((frgn_master->flagField[1] & FFB_LI59) != 0);
			prop->leap61 = ((frgn_master->flagField[1] & FFB_LI61) != 0);
			prop->currentUtcOffset = frgn_master->currentUtcOffset;
		} else {
			if (hours >= 12) {
				/* stop 2 announce intervals before midnight */
				if ((hours == 23) && (minutes == 59) && 
				    (seconds >= (60 - (2 * (1 << ppi->portDS->logAnnounceInterval))))) {
					pp_diag(ppi, bmc, 2, 
						"Approaching midnight, not updating leap flags\n");			
					ret = TOPS(ppi)->get_utc_offset(ppi, &offset, &leap59, &leap61);
					if (ret) {
						pp_diag(ppi, bmc, 1, 
							"Could not get UTC offset from system\n");
					} else {
						pp_diag(ppi, bmc, 3, 
							"Current UTC flags, "
							"offset: %i, "
							"leap59: %i, "
							"leap61: %i\n",
							offset, leap59, leap61);		
					}
				} else {
					ret = TOPS(ppi)->get_utc_offset(ppi, &offset, &leap59, &leap61);
					if (ret) {
						/* "Could not get UTC flags from system, taking received flags\n" */
						pp_diag(ppi, bmc, 1, 
							"Could not get UTC %s from system, taking received flags\n", "flags");
						prop->leap59 = ((frgn_master->flagField[1] & FFB_LI59) != 0);
						prop->leap61 = ((frgn_master->flagField[1] & FFB_LI61) != 0);
						prop->currentUtcOffset = frgn_master->currentUtcOffset;
						
					} else {
						pp_diag(ppi, bmc, 3, 
							"Current UTC flags, "
							"offset: %i, "
							"leap59: %i, "
							"leap61: %i\n",
							offset, leap59, leap61);		

						if (((leap59 != 0) != ((frgn_master->flagField[1] & FFB_LI59) != 0)) ||
						    ((leap61 != 0) != ((frgn_master->flagField[1] & FFB_LI61) != 0)) ||
						    (offset != frgn_master->currentUtcOffset)) {			
							prop->leap59 = ((frgn_master->flagField[1] & FFB_LI59) != 0);
							prop->leap61 = ((frgn_master->flagField[1] & FFB_LI61) != 0);
							prop->currentUtcOffset = frgn_master->currentUtcOffset;

							if (prop->leap59)
								leap59 = 1;
							else
								leap59 = 0;

							if (prop->leap61)
								leap61 = 1;
							else
								leap61 = 0;

							offset = prop->currentUtcOffset;

							pp_diag(ppi, bmc, 1, 
								"UTC flags changed, "
								"offset: %i, "
								"leap59: %i, "
								"leap61: %i\n",
							        offset, leap59, leap61);		
							
							ret = TOPS(ppi)->set_utc_offset(ppi, offset, leap59, leap61);
							if (ret) {
								pp_diag(ppi, bmc, 1, 
									"Could not set UTC offset on system\n");
							}
						}
					}
				}

			} else {			
				/* stop for 2 announce intervals after midnight */
				if ((hours == 00) && (minutes == 00) && 
				    (seconds <= (0 + (2 * (1 << ppi->portDS->logAnnounceInterval))))) {
					pp_diag(ppi, bmc, 2, 
						"short after midnight, taking local offset\n");			
					ret = TOPS(ppi)->get_utc_offset(ppi, &offset, &leap59, &leap61);
					if (ret) {
						pp_diag(ppi, bmc, 1, 
							"Could not get UTC offset from system\n");
					} else {
						pp_diag(ppi, bmc, 3, 
							"Current UTC flags, "
							"offset: %i, "
							"leap59: %i, "
							"leap61: %i\n",
							offset, leap59, leap61);		
						prop->currentUtcOffset = offset;
					}
					prop->leap59 = FALSE;
					prop->leap61 = FALSE;
				} else {	
					if (prop->currentUtcOffset != frgn_master->currentUtcOffset) {
						pp_diag(ppi, bmc, 1, "New UTC offset in the middle of the day: %i\n",
							frgn_master->currentUtcOffset);
						prop->currentUtcOffset = frgn_master->currentUtcOffset;
						TOPS(ppi)->set(ppi, NULL);
					}
					prop->leap59 = ((frgn_master->flagField[1] & FFB_LI59) != 0);
					prop->leap61 = ((frgn_master->flagField[1] & FFB_LI61) != 0);
				}
			}
		}
	} else {
		/* just take what we get */
		prop->leap59 = ((frgn_master->flagField[1] & FFB_LI59) != 0);
		prop->leap61 = ((frgn_master->flagField[1] & FFB_LI61) != 0);
		prop->currentUtcOffset = frgn_master->currentUtcOffset;
	}
	prop->currentUtcOffsetValid = ((frgn_master->flagField[1] & FFB_UTCV) != 0);
	prop->timeTraceable = ((frgn_master->flagField[1] & FFB_TTRA) != 0);
	prop->frequencyTraceable = ((frgn_master->flagField[1] & FFB_FTRA) != 0);
	prop->ptpTimescale = ((frgn_master->flagField[1] & FFB_PTP) != 0);
	prop->timeSource = frgn_master->timeSource;

	/* Disable timer (if needed) used to go to GM by BMCA */
	pp_gtimeout_disable(GLBS(ppi),PP_TO_GM_BY_BMCA);

	if (is_ext_hook_available(ppi,bmca_s1))
		ppi->ext_hooks->bmca_s1(ppi,frgn_master);

}

void bmc_p1(struct pp_instance *ppi)
{
	/* In the default implementation, nothing should be done when a port
	 * goes to passive state. This empty function is a placeholder for
	 * extension-specific needs, to be implemented as a hook */
}

void bmc_p2(struct pp_instance *ppi)
{
	/* In the default implementation, nothing should be done when a port
	 * goes to passive state. This empty function is a placeholder for
	 * extension-specific needs, to be implemented as a hook */
}

/* Copy local data set into header and announce message. 9.3.4 table 12. */
static void bmc_setup_local_frgn_master(struct pp_instance *ppi,
			   struct pp_frgn_master *frgn_master)
{

	if ( !is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
		/* this shall be always qualified */
		frgn_master->qualified=1;
	}
	memcpy(&frgn_master->receivePortIdentity,
	       &DSPOR(ppi)->portIdentity, sizeof(PortIdentity));
	frgn_master->sequenceId = 0;

	memcpy(&frgn_master->sourcePortIdentity,
		   &DSPOR(ppi)->portIdentity, sizeof(PortIdentity));
	memset(&frgn_master->flagField,
		   0, sizeof(frgn_master->flagField));
	frgn_master->currentUtcOffset = 0; //TODO get this from somewhere
	frgn_master->grandmasterPriority1 = DSDEF(ppi)->priority1;
	memcpy(&frgn_master->grandmasterClockQuality,
	       &DSDEF(ppi)->clockQuality, sizeof(ClockQuality));
	frgn_master->grandmasterPriority2 = DSDEF(ppi)->priority2;
	memcpy(&frgn_master->grandmasterIdentity,
		   &DSDEF(ppi)->clockIdentity, sizeof(ClockIdentity));
	frgn_master->stepsRemoved = 0;
	frgn_master->timeSource = TIME_SRC_INTERNAL_OSCILLATOR; //TODO get this from somewhere

	bzero(frgn_master->ext_specific,sizeof(frgn_master->ext_specific));
}

int bmc_idcmp(struct ClockIdentity *a, struct ClockIdentity *b)
{
	return memcmp(a, b, sizeof(*a));
}

int bmc_pidcmp(struct PortIdentity *a, struct PortIdentity *b)
{
	int ret;

	ret = bmc_idcmp(&a->clockIdentity, &b->clockIdentity);
	if (ret != 0)
		return ret;

	return a->portNumber - b->portNumber;
}

/* Check if the foreign master is the ebest */

static int is_ebest(struct pp_globals *ppg, struct pp_frgn_master *foreignMaster) {
	if ( ppg->ebest_idx!=-1 ) {
		/* ebest exists */
		struct pp_instance *ppi_best = INST(ppg, ppg->ebest_idx);
		if ( ppi_best->frgn_rec_best!=-1 ) {
			/* Should be always true */
			struct pp_frgn_master *erbest=&ppi_best->frgn_master[ppi_best->frgn_rec_best];

			if ( (erbest==foreignMaster) ||  bmc_pidcmp(&foreignMaster->sourcePortIdentity,&erbest->sourcePortIdentity)==0)
				return 1; /* This is the ebest */
		}
	}
	return 0;
}

static __inline__ int is_qualified(struct pp_instance *ppi, struct pp_frgn_master *foreignMaster) {
	return foreignMaster->qualified || is_ebest(GLBS(ppi),foreignMaster);
}

static int are_qualified(struct pp_instance *ppi,
			   struct pp_frgn_master *a,
			   struct pp_frgn_master *b, int *ret) {
	int a_is_qualified = is_qualified(ppi,a);
	int b_is_qualified = is_qualified(ppi,b);


	/* if B is not qualified  9.3.2.5 c) & 9.3.2.3 a) & b)*/
	if ( a_is_qualified && !b_is_qualified ) {
		pp_diag(ppi, bmc, 2, "Dataset %s not qualified\n", "B");
		*ret=-1;
		return 0;
	}

	/* if A is not qualified  9.3.2.5 c) & 9.3.2.3 a) & b) */
	if (b_is_qualified && !a_is_qualified) {
		pp_diag(ppi, bmc, 2, "Dataset %s not qualified\n", "A");
		*ret= 1;
		return 0;
	}

	/* if both are not qualified  9.3.2.5 c) & 9.3.2.3 a) & b) */
	if ( !a_is_qualified && !b_is_qualified ) {
		pp_diag(ppi, bmc, 2, "Dataset %s not qualified\n", "A & B");
		*ret= 0;
		return 0;
	}
	return 1;

}

/* compare part2 of the datasets which is the topology, fig 27, page 89 */
static int bmc_gm_cmp(struct pp_instance *ppi,
			   struct pp_frgn_master *a,
			   struct pp_frgn_master *b)
{
	int ret;
	struct ClockQuality *qa = &a->grandmasterClockQuality;
	struct ClockQuality *qb = &b->grandmasterClockQuality;
	char clkid_str[26];

	/* bmc_gm_cmp is called several times, so report only at level 2 */
	pp_diag(ppi, bmc, 2, "%s\n", __func__);

	if ( !are_qualified(ppi,a,b,&ret) ) {
		return ret;
	}

	if (a->grandmasterPriority1 != b->grandmasterPriority1) {
		/* "Priority1 A: %i, Priority1 B: %i\n", */
		pp_diag(ppi, bmc, 3, "%s A: %i, %s B: %i\n",
			"Priority1", a->grandmasterPriority1,
			"Priority1", b->grandmasterPriority1);
		return a->grandmasterPriority1 - b->grandmasterPriority1;
	}

	if (qa->clockClass != qb->clockClass) {
		/* "ClockClass A: %i, ClockClass B: %i\n", */
		pp_diag(ppi, bmc, 3, "%s A: %i, %s B: %i\n",
			"ClockClass", qa->clockClass,
			"ClockClass", qb->clockClass);
		return qa->clockClass - qb->clockClass;
	}

	if (qa->clockAccuracy != qb->clockAccuracy) {
		/* "ClockAccuracy A: %i, ClockAccuracy B: %i\n", */
		pp_diag(ppi, bmc, 3, "%s A: %i, %s B: %i\n",
			"ClockAccuracy", qa->clockAccuracy,
			"ClockAccuracy", qb->clockAccuracy);
		return qa->clockAccuracy - qb->clockAccuracy;
	}

	if (qa->offsetScaledLogVariance != qb->offsetScaledLogVariance) {
		/* "Variance A: %i, Variance B: %i\n", */
		pp_diag(ppi, bmc, 3, "%s A: %i, %s B: %i\n",
			"Variance", qa->offsetScaledLogVariance,
			"Variance", qb->offsetScaledLogVariance);
		return qa->offsetScaledLogVariance
				- qb->offsetScaledLogVariance;
	}

	if (a->grandmasterPriority2 != b->grandmasterPriority2) {
		/* "Priority2 A: %i, Priority2 B: %i\n", */
		pp_diag(ppi, bmc, 3, "%s A: %i, %s B: %i\n",
			"Priority2", a->grandmasterPriority2,
			"Priority2", b->grandmasterPriority2);
		return a->grandmasterPriority2 - b->grandmasterPriority2;
	}

	pp_diag(ppi, bmc, 3, "GmId A: %s\n",
		format_hex8(clkid_str, a->grandmasterIdentity.id));

	pp_diag(ppi, bmc, 3, "GmId B: %s\n",
		format_hex8(clkid_str, b->grandmasterIdentity.id));

	return bmc_idcmp(&a->grandmasterIdentity, &b->grandmasterIdentity);
}

/* compare part2 of the datasets which is the topology, fig 28, page 90 */
static int bmc_topology_cmp(struct pp_instance *ppi,
			   struct pp_frgn_master *a,
			   struct pp_frgn_master *b)
{
	int ret;
	struct PortIdentity *pidtxa = &a->sourcePortIdentity;
	struct PortIdentity *pidtxb = &b->sourcePortIdentity;
	struct PortIdentity *pidrxa = &a->receivePortIdentity;
	struct PortIdentity *pidrxb = &b->receivePortIdentity;
	int diff;
	char clkida_str[26];
	char clkidb_str[26];

	/* bmc_topology_cmp is called several times, so report only at level 2
	 */
	pp_diag(ppi, bmc, 2, "%s\n", __func__);

	if ( !are_qualified(ppi,a,b,&ret) ) {
		return ret;
	}

	diff = a->stepsRemoved - b->stepsRemoved;
	if (diff > 1 || diff < -1) {
		pp_diag(ppi, bmc, 3, "StepsRemoved A: %i, StepsRemoved B: %i\n",
			a->stepsRemoved, b->stepsRemoved);
		return diff;
	}

	if (diff > 0) {
		if (!bmc_pidcmp(pidtxa, pidrxa)) {
			pp_diag(ppi, bmc, 1, "%s:%i: Error 1\n",
				__func__, __LINE__);
			return 0;
		}
		pp_diag(ppi, bmc, 3, "StepsRemoved A: %i, StepsRemoved B: %i\n",
			a->stepsRemoved, b->stepsRemoved);
		return 1;

	}
	if (diff < 0) {
		if (!bmc_pidcmp(pidtxb, pidrxb)) {
			pp_diag(ppi, bmc, 1, "%s:%i: Error 1\n",
				__func__, __LINE__);
			return 0;
		}
		pp_diag(ppi, bmc, 3, "StepsRemoved A: %i, StepsRemoved B: %i\n",
			a->stepsRemoved, b->stepsRemoved);
		return -1;
	}
	/* stepsRemoved is equal, compare identities */
	diff = bmc_pidcmp(pidtxa, pidtxb);
	if (diff) {
		pp_diag(ppi, bmc, 3, "%sId A: %s.%04x,\n%sId B: %s.%04x\n",
			"Tx",
			format_hex8(clkida_str, pidtxa->clockIdentity.id),
			pidtxa->portNumber,
			"Tx",
			format_hex8(clkidb_str, pidtxb->clockIdentity.id),
			pidtxb->portNumber);
		return diff;
	}

	/* sourcePortIdentity is equal, compare receive port identites, which
	 * is the last decision maker, which has to be different */
	pp_diag(ppi, bmc, 3, "%sId A: %s.%04x,\n%sId B: %s.%04x\n",
		"Rx",
		format_hex8(clkida_str, pidtxa->clockIdentity.id),
		pidtxa->portNumber,
		"Rx",
		format_hex8(clkidb_str, pidtxb->clockIdentity.id),
		pidtxb->portNumber);
	return bmc_pidcmp(pidrxa, pidrxb);
}


/*
 * Data set comparison between two foreign masters. Return similar to
 * memcmp().  However, lower values take precedence, so in A-B (like
 * in comparisons,   > 0 means B wins (and < 0 means A wins).
 */
static int bmc_dataset_cmp(struct pp_instance *ppi,
			   struct pp_frgn_master *a,
			   struct pp_frgn_master *b)
{
	char clkid_str[26];
	/* dataset_cmp is called several times, so report only at level 2 */
	pp_diag(ppi, bmc, 2, "%s\n", __func__);
	pp_diag(ppi, bmc, 3, "portId A: %s\n",
		format_hex8(clkid_str, a->sourcePortIdentity.clockIdentity.id));

	pp_diag(ppi, bmc, 3, "portId B: %s\n",
		format_hex8(clkid_str, b->sourcePortIdentity.clockIdentity.id));

	if (!bmc_idcmp(&a->grandmasterIdentity, &b->grandmasterIdentity)) {
		/* Check topology */
		return bmc_topology_cmp(ppi, a, b);
	} else {
		/* Check grandmasters */
		return bmc_gm_cmp(ppi, a, b);
	}
}


/* State decision algorithm 9.3.3 Fig 26 */
/* Never called if externalPortConfigurationEnabled==TRUE */

static int bmc_state_decision(struct pp_instance *ppi)
{
	static struct pp_frgn_master empty_frn_master;
	int cmpres;
	struct pp_frgn_master d0;
	parentDS_t *parent = DSPAR(ppi);
	struct pp_globals *ppg = GLBS(ppi);
	struct pp_instance *ppi_best;
	int erbestValid=ppi->frgn_rec_best!=-1;
	struct pp_frgn_master *erbest = erbestValid ? &ppi->frgn_master[ppi->frgn_rec_best] : &empty_frn_master;
	struct pp_frgn_master *ebest=&empty_frn_master;;

	/* bmc_state_decision is called several times, so report only at
	 * level 2 */
	pp_diag(ppi, bmc, 2, "%s\n", __func__);


	if ( (ppi->state == PPS_FAULTY) || (ppi->state==PPS_INITIALIZING) )
		/* - Exit from FAULTY state is implementation specific and implemented in state_faulty.c */
		/* - If INITIALIZING state in progress, do not change it. It may wait for GM to be locked */
		return ppi->state;

	if (is_slaveOnly(DSDEF(ppi))) {
		if ( !erbestValid )
    			return PPS_LISTENING; /* No foreign master */
		/* if this is the slave port of the whole system then go to slave otherwise stay in listening*/
		if (ppi->port_idx == ppg->ebest_idx) {
			/* if on this configured port is ebest it will be taken as
			 * parent */
			ebest = erbest;
			goto slave_s1;
		} else
			return PPS_LISTENING;
	}

	if ( !erbestValid && (ppi->state == PPS_LISTENING))
		return PPS_LISTENING; /* (E best is the empty set) AND (PTP Port state is LISTENING)*/

	/* copy local information to a foreign_master structure */
	bmc_setup_local_frgn_master(ppi, &d0);


	if (is_masterOnly(ppi->portDS)) {
		/* if there is a better master show these values */
		if (ppg->ebest_idx >= 0) {
			/* don't update parent dataset */
			goto master_m3;
		} else {
			/* provide our info */
			goto master_m1;
		}
	}

	if ( !(CONFIG_HAS_CODEOPT_SO_ENABLED || CONFIG_HAS_CODEOPT_EPC_ENABLED) ) {
	    /* If slaveOnly or externalPortConfiguration are forced enable,
	     *  this part of the code is never reached. It can be then optimized
	     */
	     
		/* if there is a foreign master take it otherwise just go to master */
		if (ppg->ebest_idx >= 0) {
			ppi_best = INST(ppg, ppg->ebest_idx);
			ebest = &ppi_best->frgn_master[ppi_best->frgn_rec_best];
			pp_diag(ppi, bmc, 2, "Taking real Ebest at port %i foreign "
				"master %i/%i\n", (ppg->ebest_idx+1),
				ppi_best->frgn_rec_best, ppi_best->frgn_rec_num);
		} else {
			/* directly go to master state */
			pp_diag(ppi, bmc, 2, "No real Ebest\n");
			goto master_m1;
		}

		if (DSDEF(ppi)->clockQuality.clockClass < 128) {
			/* dataset_cmp D0 with Erbest */
			cmpres = bmc_dataset_cmp(ppi, &d0, erbest);
			if (cmpres < 0)
				goto master_m1;
			if (cmpres > 0)
				goto passive_p1;
		} else {
			/* dataset_cmp D0 with Ebest */
			cmpres = bmc_dataset_cmp(ppi, &d0, ebest);
			if (cmpres < 0)
				goto master_m2;
			if (cmpres > 0) {
				if (get_numberPorts(DSDEF(ppi)) == 1)
					goto slave_s1; /* directly skip to ordinary
							* clock handling */
				else
					goto check_boundary_clk;
			}

		}
	}
	pp_diag(ppi, bmc, 1, "%s: error\n", __func__);

	return PPS_FAULTY;

check_boundary_clk:
	/* If this port is the Ebest */
	if (ppi->port_idx == ppg->ebest_idx)
		goto slave_s1;

	/* bmc_gm_cmp Ebest with Erbest */
	cmpres = bmc_gm_cmp(ppi, ebest, erbest);
	if (cmpres < 0)
		goto master_m3;

	/* topology_cmp Ebest with Erbest */
	cmpres = bmc_topology_cmp(ppi, ebest, erbest);
	if (cmpres < 0)
		goto passive_p2;
	if (cmpres > 0)
		goto master_m3;

	pp_diag(ppi, bmc, 1, "%s: error\n", __func__);

	return PPS_FAULTY;

passive_p1:
	pp_diag(ppi, bmc, 1, "%s: passive p1\n", __func__);
	if (DSDEF(ppi)->clockQuality.clockClass == PP_CLASS_SLAVE_ONLY) {
		/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
		if (ppi->state != PPS_LISTENING)
			pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
		return PPS_LISTENING;
	}
	/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
	if (ppi->state != PPS_PASSIVE)
		pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
	bmc_p1(ppi);
	return PPS_PASSIVE;

passive_p2:
	pp_diag(ppi, bmc, 1, "%s: passive p2\n", __func__);
	if (DSDEF(ppi)->clockQuality.clockClass == PP_CLASS_SLAVE_ONLY) {
		/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
		if (ppi->state != PPS_LISTENING)
			pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
		return PPS_LISTENING;
	}
	/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
	if (ppi->state != PPS_PASSIVE)
		pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
	bmc_p2(ppi);
	return PPS_PASSIVE;

master_m1:
	pp_diag(ppi, bmc, 1, "%s: master m1\n", __func__);
	if (DSDEF(ppi)->clockQuality.clockClass == PP_CLASS_SLAVE_ONLY) {
		/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
		if (ppi->state != PPS_LISTENING)
			pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
		return PPS_LISTENING;
	}
	bmc_m1(ppi);
	if ((ppi->state != PPS_MASTER) &&
		(ppi->state != PPS_PRE_MASTER)) {
		/* 9.2.6.10 a) timeout 0 */
		pp_timeout_reset_N(ppi, PP_TO_QUALIFICATION,0);
		return PPS_PRE_MASTER;
	} else {
		/* the decision to go from PPS_PRE_MASTER to PPS_MASTER is
		 * done outside the BMC, so just return the current state */
		return ppi->state;
	}

master_m2:
	pp_diag(ppi, bmc, 1, "%s: master m2\n", __func__);
	if (DSDEF(ppi)->clockQuality.clockClass == PP_CLASS_SLAVE_ONLY) {
		/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
		if (ppi->state != PPS_LISTENING)
			pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
		return PPS_LISTENING;
	}
	bmc_m2(ppi);
	if ((ppi->state != PPS_MASTER) &&
		(ppi->state != PPS_PRE_MASTER)) {
		/* 9.2.6.10 a) timeout 0 */
		pp_timeout_reset_N(ppi, PP_TO_QUALIFICATION,0);
		return PPS_PRE_MASTER;
	} else {
		/* the decision to go from PPS_PRE_MASTER to PPS_MASTER is
		 * done outside the BMC, so just return the current state */
		return ppi->state;
	}

master_m3:
	pp_diag(ppi, bmc, 1, "%s: master m3\n", __func__);
	if (DSDEF(ppi)->clockQuality.clockClass == PP_CLASS_SLAVE_ONLY) {
		/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
		if (ppi->state != PPS_LISTENING)
			pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
		return PPS_LISTENING;
	}
	bmc_m3(ppi);
	if ((ppi->state != PPS_MASTER) &&
		(ppi->state != PPS_PRE_MASTER)) {
		/* timeout reinit */
		pp_timeout_init(ppi);
		/* 9.2.6.11 b) timeout steps removed+1*/
		pp_timeout_reset_N(ppi, PP_TO_QUALIFICATION,DSCUR(ppi)->stepsRemoved+1);
		return PPS_PRE_MASTER;
	} else {
		/* the decision to go from PPS_PRE_MASTER to PPS_MASTER is
		 * done outside the BMC, so just return the current state */
		return ppi->state;
	}

slave_s1:
	pp_diag(ppi, bmc, 1, "%s: slave s1\n", __func__);
	/* only update parent dataset if best master is on this port */
	if (ppi->port_idx == GLBS(ppi)->ebest_idx) {
		/* check if we have a new master */
		cmpres = bmc_pidcmp(&parent->parentPortIdentity,
				&ebest->sourcePortIdentity);
		bmc_s1(ppi, ebest);
	} else {
		/* set that to zero in the case we don't have the master
		 * on that port */
		cmpres = 0;
	}
	/* if we are not coming from the slave state we go to uncalibrated
	 * first */
	if ((ppi->state != PPS_SLAVE) &&
		(ppi->state != PPS_UNCALIBRATED)) {
		/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
		pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
		return PPS_UNCALIBRATED;
	} else {
		/* if the master changed we go to uncalibrated*/
		/* At this point we are in state SLAVE or UNCALIBRATED */
		if (cmpres) {
			pp_diag(ppi, bmc, 1,
				"new foreign master, change to uncalibrated\n");
			/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
			if (ppi->state != PPS_UNCALIBRATED )
				pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
			return PPS_UNCALIBRATED;
		} else {
			/* 9.2.6.11 c) reset ANNOUNCE RECEIPT timeout when entering*/
			if (ppi->state != PPS_SLAVE)
				pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
			/* the decision to go from UNCALIBRATED to SLAVE is
			 * done outside the BMC, so just return the current state */
			return ppi->state;
		}
	}
}


void bmc_store_frgn_master(struct pp_instance *ppi,
		       struct pp_frgn_master *frgn_master, void *buf, int len)
{
	MsgHeader *hdr = &ppi->received_ptp_header;
	MsgAnnounce ann;

	/*
	 * header and announce field of each Foreign Master are
	 * useful to run Best Master Clock Algorithm
	 */
	msg_unpack_announce(ppi, buf, &ann);

	memcpy(&frgn_master->receivePortIdentity,
	       &DSPOR(ppi)->portIdentity, sizeof(PortIdentity));
	frgn_master->sequenceId = hdr->sequenceId;

	memcpy(&frgn_master->sourcePortIdentity,
		   &hdr->sourcePortIdentity, sizeof(PortIdentity));
	memcpy(&frgn_master->flagField,
		   &hdr->flagField, sizeof(frgn_master->flagField));
	frgn_master->currentUtcOffset = ann.currentUtcOffset;
	frgn_master->grandmasterPriority1 = ann.grandmasterPriority1;
	memcpy(&frgn_master->grandmasterClockQuality,
	       &ann.grandmasterClockQuality, sizeof(ClockQuality));
	frgn_master->grandmasterPriority2 = ann.grandmasterPriority2;
	memcpy(&frgn_master->grandmasterIdentity,
		   &ann.grandmasterIdentity, sizeof(ClockIdentity));
	frgn_master->stepsRemoved = ann.stepsRemoved;
	frgn_master->timeSource = ann.timeSource;
	frgn_master->qualified=
			frgn_master->lastAnnounceMsgMs=0;
	memcpy(frgn_master->ext_specific,ann.ext_specific,sizeof(frgn_master->ext_specific));
	memcpy(frgn_master->peer_mac, ppi->peer, sizeof(ppi->peer));
}


struct pp_frgn_master * bmc_add_frgn_master(struct pp_instance *ppi,  struct pp_frgn_master *frgn_master)
{
	int sel;
	MsgHeader *hdr = &ppi->received_ptp_header;
	struct PortIdentity *pid = &hdr->sourcePortIdentity;
	char clkid_str[26];

	pp_diag(ppi, bmc, 2, "%s\n", __func__);

	assert(ppi->state != PPS_DISABLED, "Should not be called when state is  DISABLED\n");
	assert(ppi->state != PPS_FAULTY, "Should not be called when state is FAULTY\n");
	assert(ppi->state != PPS_INITIALIZING, "Should not be called when state is INITIALIZING\n");

	pp_diag(ppi, bmc, 3, "%s: %s.%04x\n",
		"Foreign Master Port Id",
		format_hex8(clkid_str, pid->clockIdentity.id),
		pid->portNumber);

	if (is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
		/* Clause 17.6.5.3 : 9.5 shall continue to be in effect
		 * with the exception of the specifications of 9.5.2.3 and 9.5.3
		 * - per 9.5.2.2, PTP implementation ignores any message received from the same port
		 *   that transmitted this message
		 * - because 9.5.2.3 is ignored, PTP implementation accepts any message received
		 *   from another "PTP Port" (ppsi instance) on the same "PTP Instance" (wr switch)
		 */
		if (!bmc_idcmp(&pid->clockIdentity, &DSDEF(ppi)->clockIdentity) &&
				pid->portNumber==ppi->port_idx) {
			pp_diag(ppi, bmc, 2, "Announce frame from %s\n", "same port");
			return NULL;
		}
		sel = 0;
		ppi->frgn_rec_num=1;
		ppi->frgn_rec_best=0;

	} else {
		int cmpres;
		int i, worst;
		struct pp_frgn_master worst_frgn_master;
		struct pp_frgn_master temp_frgn_master;
		if (get_numberPorts(DSDEF(ppi)) > 1) {

			/* Check if announce from the same port from this clock 9.3.2.5 a)
			 * from another port of this clock we still handle even though it
			 * states something different in IEEE1588 because in 9.5.2.3
			 * there is a special handling described for boundary clocks
			 * which is done in the BMC
			 */
			if (!bmc_idcmp(&pid->clockIdentity,
					&DSDEF(ppi)->clockIdentity)) {
				cmpres = bmc_pidcmp(pid, &DSPOR(ppi)->portIdentity);

				pp_diag(ppi, bmc, 2, "Announce frame from %s\n", "this clock");

				if (cmpres < 0) {
					pp_diag(ppi, bmc, 2, "Announce frame from %s\n", "a better port on this clock");
					bmc_p1(ppi);
					ppi->next_state = PPS_PASSIVE;
					/* as long as we receive that reset the announce timeout */
					pp_timeout_reset(ppi, PP_TO_ANN_RECEIPT);
				} else if (cmpres > 0) {
					pp_diag(ppi, bmc, 2, "Announce frame from %s\n", "a worse port on this clock");
					return NULL;
				} else {
					pp_diag(ppi, bmc, 2, "Announce frame from %s\n", "this port");
					return NULL;
				}
			}
		} else {
			/* Check if announce from a port from this clock 9.3.2.5 a) */
			if (!bmc_idcmp(&pid->clockIdentity,
					&DSDEF(ppi)->clockIdentity)) {
				pp_diag(ppi, bmc, 2, "Announce frame from %s\n", "this clock");
				return NULL;
			}
		}

		/* Check if announce has steps removed larger than 255 9.3.2.5 d) */
		if (frgn_master->stepsRemoved >= 255) {
			pp_diag(ppi, bmc, 2, "Announce frame steps removed"
				" larger or equal 255: %i\n",
				frgn_master->stepsRemoved);
			return NULL;
		}

		/* Check if foreign master is already known */
		for (i=0;i < ppi->frgn_rec_num; i++)
		{
			if (!bmc_pidcmp(pid,
					&ppi->frgn_master[i].sourcePortIdentity)) {
				// Foreign master found
				pp_diag(ppi, bmc, 2, "Foreign Master %i updated\n", i);

				/* fill in number of announce received */
				frgn_master->qualified=ppi->frgn_master[i].qualified;
				frgn_master->lastAnnounceMsgMs=ppi->frgn_master[i].lastAnnounceMsgMs;

				/* update the number of announce received if correct
				 * sequence number 9.3.2.5 b) */
				if (hdr->sequenceId == (ppi->frgn_master[i].sequenceId + 1)) {
					unsigned long now=TOPS(ppi)->calc_timeout(ppi, 0);

					frgn_master->qualified = time_before_eq(now,
						frgn_master->lastAnnounceMsgMs + ppi->frgn_master_time_window_ms);
					frgn_master->lastAnnounceMsgMs=now;
				}
				/* already in Foreign master data set, update info */
				memcpy(&ppi->frgn_master[i], frgn_master,
					   sizeof(struct pp_frgn_master));
				return NULL;
			}
		}

		/* set qualification timeouts as valid to compare against worst*/
		frgn_master->qualified=1;

		/* New foreign master */
		if ( !CONFIG_HAS_CODEOPT_SINGLE_FMASTER ) {
			/* Code optimization if only one foreign master */
			if (ppi->frgn_rec_num < PP_NR_FOREIGN_RECORDS) {
				/* there is space for a new one */
				sel = ppi->frgn_rec_num;
				ppi->frgn_rec_num++;

			} else {
				/* find the worst to replace */
				for (i = 1, worst = 0; i < ppi->frgn_rec_num; i++) {
					/* qualify them for this check */
					memcpy(&temp_frgn_master, &ppi->frgn_master[i],
						   sizeof(struct pp_frgn_master));
					memcpy(&worst_frgn_master, &ppi->frgn_master[worst],
						   sizeof(struct pp_frgn_master));
					temp_frgn_master.qualified=
						worst_frgn_master.qualified=1;

					if (bmc_dataset_cmp(ppi, &temp_frgn_master,
								&worst_frgn_master) > 0)
						worst = i;
				}

				/* copy the worst again and qualify it */
				memcpy(&worst_frgn_master, &ppi->frgn_master[worst],
					   sizeof(struct pp_frgn_master));
				worst_frgn_master.qualified=1;

				/* check if worst is better than the new one, and skip the new
				 * one if so */
				if (bmc_dataset_cmp(ppi, &worst_frgn_master, frgn_master)
					< 0) {
						pp_diag(ppi, bmc, 1, "%s:%i: New foreign "
							"master worse than worst in the full "
							"table, skipping\n",
					__func__, __LINE__);
					return NULL;
				}

				sel = worst;
			}
		} else {
			sel = 0;
			ppi->frgn_rec_num=1;
		}

		/* clear qualification timeouts */
		frgn_master->qualified=0;

		/* This is the first one qualified 9.3.2.5 e)*/
		frgn_master->lastAnnounceMsgMs=TOPS(ppi)->calc_timeout(ppi, 0);
	}
	/* Copy the temporary foreign master entry */
	memcpy(&ppi->frgn_master[sel], frgn_master,
		   sizeof(struct pp_frgn_master));

	pp_diag(ppi, bmc, 1, "New foreign Master %i added\n", sel);
	return &ppi->frgn_master[sel];
}

static void bmc_flush_frgn_master(struct pp_instance *ppi)
{
	pp_diag(ppi, bmc, 2, "%s\n", __func__);

	memset(ppi->frgn_master, 0, sizeof(ppi->frgn_master));
	ppi->frgn_rec_num = 0;
}


static void bmc_remove_foreign_master(struct pp_instance *ppi, int frg_master_idx) {
	int i;

	if ( ppi->frgn_rec_best == frg_master_idx ) {
		ppi->frgn_rec_best=-1;
	}
	for (i = frg_master_idx; i < PP_NR_FOREIGN_RECORDS; i++) {
		if (frg_master_idx < (ppi->frgn_rec_num-1)) {
			/* overwrite and shift next foreign
			 * master in */
			memcpy(&ppi->frgn_master[i],
			       &ppi->frgn_master[i+1],
			       sizeof(struct pp_frgn_master));
			if ( ppi->frgn_rec_best == (i+1) )
				ppi->frgn_rec_best=i; // Re-adjust the erBest
		} else {
			/* clear the last (and others) since
			 * shifted */
			memset(&ppi->frgn_master[i], 0,
			       sizeof(struct pp_frgn_master));
		}
	}

	/* one less and restart at the shifted one */
	ppi->frgn_rec_num--;
}

void bmc_flush_erbest(struct pp_instance *ppi)
{
	if ( ppi->frgn_rec_best!=-1 && ppi->frgn_rec_best<ppi->frgn_rec_num ) {
		pp_diag(ppi, bmc, 1, "Aged out %sforeign master %i/%i\n", "ErBest ",
			ppi->frgn_rec_best, ppi->frgn_rec_num);
		bmc_remove_foreign_master(ppi,ppi->frgn_rec_best);
	}
	ppi->frgn_rec_best=-1;
}

static void bmc_age_frgn_master(struct pp_instance *ppi)
{
	int i=0;


	unsigned long now=TOPS(ppi)->calc_timeout(ppi, 0);

	while (i < ppi->frgn_rec_num ) {
		struct pp_frgn_master *frgn_master=&ppi->frgn_master[i];

		/* get qualification */
		if ( !is_ebest(GLBS(ppi),frgn_master) ) {
			if (time_after(now, frgn_master->lastAnnounceMsgMs + ppi->frgn_master_time_window_ms)) {
				// Remove age out
				pp_diag(ppi, bmc, 1, "Aged out %sforeign master %i/%i\n", "",
						i, ppi->frgn_rec_num);
				bmc_remove_foreign_master(ppi,i);
				continue;
			}
		}
		i++;
	}
}

static inline void bmc_age_frgn_masters(struct pp_globals  *ppg)
{
	int i;
	pp_diag(NULL, bmc, 1, "bmc_age_frgn_masters\n");

	for (i=0; i<get_numberPorts(GDSDEF(ppg)); i++)
		bmc_age_frgn_master(INST(ppg,i));

}

/* Returns :
 * 0 :  if erbest is not from another port of the device,
 * 1 : if the port shall go to passive
 */
static int bmc_check_frgn_master(struct pp_instance *ppi)
{
	int i;
	struct PortIdentity *pid;
	char clkid_str[26];

	if (ppi->frgn_rec_num > 0) {
		for (i =0; i < ppi->frgn_rec_num; i++) {
			/* from the same clock */
			if (!bmc_idcmp(&ppi->frgn_master[i].sourcePortIdentity.clockIdentity,
					&DSDEF(ppi)->clockIdentity)) {
				/* from a better port */
				if(0 > bmc_pidcmp(&ppi->frgn_master[i].sourcePortIdentity,
						&DSPOR(ppi)->portIdentity)) {
					pid = &ppi->frgn_master[i].sourcePortIdentity;
					pp_diag(ppi, bmc, 3, "%s: %s.%04x\n",
					   "Better Master on same Clock Port Id",
						format_hex8(clkid_str, pid->clockIdentity.id),
						pid->portNumber);
					return 1;
				}
			}
		}
	}
	return 0;
}

/* Check if any port is in initializing state with a link up */
static struct pp_instance *bmc_any_port_initializing(struct pp_globals *ppg)
{
	int i;
	struct pp_instance *ppi;

	/* bmc_any_port_initializing is called several times, so report only at
	 * level 2 */
	pp_diag(NULL, bmc, 2, "%s\n", __func__);

	for (i=0; i < get_numberPorts(GDSDEF(ppg)); i++)
	{
		ppi = INST(ppg, i);
		if (ppi->link_up && (ppi->state == PPS_INITIALIZING)) {
			return ppi;
		}
	}
	return NULL;
}

int bmc_is_erbest(struct pp_instance *ppi, PortIdentity *srcPortIdentity) {
	if (ppi->frgn_rec_num > 0 && ppi->frgn_rec_best != -1) {
		return bmc_pidcmp(&ppi->frgn_master[ppi->frgn_rec_best].sourcePortIdentity,
				srcPortIdentity)==0;
	}
	return 0;
}


static void bmc_update_erbest_inst(struct pp_instance *ppi) {

	struct pp_frgn_master *frgn_master;
	PortIdentity *frgn_master_pid;
	int j, best;
	char clkid_str[26];

	/* if link is down clear foreign master table */
	if ((!ppi->link_up) && (ppi->frgn_rec_num > 0))
		bmc_flush_frgn_master(ppi);

	if (ppi->frgn_rec_num > 0) {
		/* Only if port is not in the FAULTY or DISABLED
		 * state 9.2.6.8 */
		frgn_master = ppi->frgn_master;
		if ((ppi->state != PPS_FAULTY) && (ppi->state != PPS_DISABLED)) {
			best=0;
			if ( !is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
				if ( !CONFIG_HAS_CODEOPT_SINGLE_FMASTER ) {
				/* Code optimization if only one foreign master. The loop becomes obsolete */
					for (j = 1; j < ppi->frgn_rec_num;
						 j++)
						if (bmc_dataset_cmp(ppi,
							  &frgn_master[j],
							  &frgn_master[best]
							) < 0)
							best = j;
				}
				if ( is_qualified(ppi,&frgn_master[best]) ) {
					pp_diag(ppi, bmc, 1, "Best foreign master is "
						"at index %i/%i\n", best,
						ppi->frgn_rec_num);

					frgn_master_pid = &frgn_master[best].sourcePortIdentity;
					pp_diag(ppi, bmc, 3, "%s: %s.%04x\n",
						"SourcePortId",
						format_hex8(clkid_str, frgn_master_pid->clockIdentity.id),
						frgn_master_pid->portNumber);
				} else
					best=-1;
			}
			ppi->frgn_rec_best = best;
		} else { //if ((ppi->state != ...
			ppi->frgn_rec_num = 0;
			ppi->frgn_rec_best = -1;
			memset(&ppi->frgn_master, 0,
				   sizeof(ppi->frgn_master));
		}
	} else { // if (ppi->frgn_rec_num > 0)
		ppi->frgn_rec_best = -1;
	}

	/* Store MAC of a peer */
	if (ppi->frgn_rec_best >= 0)
		memcpy(&ppi->activePeer,
		       &ppi->frgn_master[ppi->frgn_rec_best].peer_mac,
		       sizeof(ppi->activePeer));
}

/* Find Erbest, 9.3.2.2 */
static inline void bmc_update_erbest(struct pp_globals *ppg)
{
	int i;
	for (i=0; i < get_numberPorts(GDSDEF(ppg)); i++)
		bmc_update_erbest_inst (INST(ppg, i));
}

/* Find Ebest, 9.3.2.2 */
static void bmc_update_ebest(struct pp_globals *ppg)
{
	int i, best=-1;
	struct pp_instance *ppi_best;
	PortIdentity *frgn_master_pid;
	char clkid_str[26];

	/* bmc_update_ebest is called several times, so report only at
	 * level 2 */
	pp_diag(NULL, bmc, 2, "%s\n", __func__);

	for (i = 0; i < get_numberPorts(GDSDEF(ppg)); i++) {
		struct pp_instance *tppi = INST(ppg, i);

		if ( best==-1 && (tppi->frgn_rec_best!=-1) ) {
			/* Best not set yet but first erbest found */
			best=i;
		} else {
			ppi_best = INST(ppg, best);

			if ((tppi->frgn_rec_best!=-1) &&
				((bmc_dataset_cmp(tppi,
				  &tppi->frgn_master[tppi->frgn_rec_best],
				  &ppi_best->frgn_master[ppi_best->frgn_rec_best]
				) < 0) || (ppi_best->frgn_rec_num == 0)))

					best = i;
			}
	}
	/* check if best master is qualified */
	if (best==-1) {
		pp_diag(NULL, bmc, 2, "No Ebest\n");
	} else {
		ppi_best = INST(ppg, best);
		pp_diag(ppi_best, bmc, 1, "Best foreign master is at port "
			"%i\n", (best+1));
		frgn_master_pid = &ppi_best->frgn_master[ppi_best->frgn_rec_best].sourcePortIdentity;
		pp_diag(ppi_best, bmc, 3, "%s: %s.%04x\n",
			"SourcePortId",
			format_hex8(clkid_str, frgn_master_pid->clockIdentity.id),
			frgn_master_pid->portNumber);
	}
	if (ppg->ebest_idx != best) {
		ppg->ebest_updated = 1;
	}
	ppg->ebest_idx=best;
}


void bmc_calculate_ebest(struct pp_globals *ppg)
{
	int i;

	/* bmc is called several times, so report only at level 2 */
	pp_diag(NULL, bmc, 2, "%s\n", __func__);

	/* check if we shall update the clock qualities */
	bmc_update_clock_quality(ppg);

	if ( !is_externalPortConfigurationEnabled(GDSDEF(ppg)) )
		/* Age foreign masters */
		bmc_age_frgn_masters(ppg);

	/* Only if port is not any port is in the INITIALIZING state 9.2.6.8 */
	{
		struct pp_instance *ppi;

		if ( (ppi=bmc_any_port_initializing(ppg))!=NULL) {
			pp_diag(ppi, bmc, 2, "A Port is in initializing\n");
			return;
		}
	}

	if ( !is_externalPortConfigurationEnabled(GDSDEF(ppg)) ) {

		/* Calculate Erbest of all ports Figure 25 */
		bmc_update_erbest(ppg);

		/* Calculate Ebest Figure 25 */
		/* ebest shall be calculated only once after the calculation of the erbest on all ports
		 *       See Figure 25 STATE_DECISION_EVENT logic
		 */
		bmc_update_ebest(ppg);
	}
	/* Set triggers for PPSi instances to execute
	 * bmc_apply_state_descision()
	 */
	for ( i=0; i<get_numberPorts(GDSDEF(ppg)); i++)
		INST(ppg,i)->bmca_execute=1;
}

/*
 * Clause 17.6.5.4: Updating data sets when external port configuration is enabled
 */
static int bmc_state_descision_epc(struct pp_instance *ppi) {

	switch (ppi->state){
	case PPS_SLAVE:
	case PPS_UNCALIBRATED:
		/* Update the data set: Table 137 */
		if ( ppi->frgn_rec_num>0 ) {
			bmc_s1(ppi,&ppi->frgn_master[0]);
		}
		break;
	case PPS_MASTER:
	case PPS_PRE_MASTER:
	case PPS_PASSIVE:
		{
			/* Update the data set: Table 136 */
			int i;
			int exec_m2=1;
			for (i=get_numberPorts(DSDEF(ppi))-1; i>=0;i--) {
				pp_std_states state=INST(GLBS(ppi),i)->state;
				if ( state==PPS_SLAVE || state==PPS_UNCALIBRATED ) {
					/* Clause 17.6.5.4 a)  if none of the PTP Instance’s PTP Ports are in the
					 * SLAVE or UNCALIBRATED state and at least one PTP Port is in the MASTER, PRE_MASTER,
					 * or PASSIVE state, ...
					 */
					exec_m2=0;
					break;
				}
			}
			if ( exec_m2)
				bmc_m2(ppi);
		}
		break;
	}
	return ppi->externalPortConfigurationPortDS.desiredState;
}

int bmc_apply_state_descision(struct pp_instance *ppi) {
	int next_state=-1;

	if (!ppi->link_up) {
		/* Set it back to initializing */
		next_state=PPS_INITIALIZING;
	} else {
		if ( is_externalPortConfigurationEnabled(DSDEF(ppi)) ) {
			/* Clause 17.6.5.3: The state machines of Figure 30 or Figure 31 shall not be used */
			next_state=bmc_state_descision_epc(ppi);
		} else {
			if ( get_numberPorts(DSDEF(ppi)) > 1 ) {
				if ( bmc_check_frgn_master(ppi) ) {
					bmc_p1(ppi);
					next_state=PPS_PASSIVE;
				}
			}
		}
	}

	if ( !is_externalPortConfigurationEnabled(DSDEF(ppi)) && next_state == -1 ) {
		/* Make state decision */
		next_state= bmc_state_decision(ppi);
	}

	/* Extra states handled here */
	if (is_ext_hook_available(ppi,state_decision))
		next_state = ppi->ext_hooks->state_decision(ppi, ppi->next_state);
	return is_externalPortConfigurationEnabled(DSDEF(ppi)) ? ppi->state : next_state;
}
