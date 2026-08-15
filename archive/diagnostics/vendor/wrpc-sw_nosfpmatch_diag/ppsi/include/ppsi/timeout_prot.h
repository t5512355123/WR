/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * Timer prototypes.
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef _TIMEOUT_PROT_H_
#define _TIMEOUT_PROT_H_

#define TIMEOUT_DISABLE_VALUE -1

extern void pp_timeout_init(struct pp_instance *ppi);
extern void __pp_timeout_reset(struct pp_instance *ppi, int index, unsigned int multiplier);
extern int pp_timeout_get(struct pp_instance *ppi, int index);
extern void pp_timeout_setall(struct pp_instance *ppi);
extern int pp_timeout(struct pp_instance *ppi, int index)
	__attribute__((warn_unused_result));
extern int pp_next_delay_1(struct pp_instance *ppi, int i1);
extern int pp_next_delay_2(struct pp_instance *ppi, int i1, int i2);
extern int pp_next_delay_3(struct pp_instance *ppi, int i1, int i2, int i3);
extern int pp_timeout_get_timer(struct pp_instance *ppi, int index, to_rand_t rand);
extern void pp_timeout_set_rename(struct pp_instance *ppi, int index, int millisec);
extern void pp_timeout_disable_all(struct pp_instance *ppi);


/*
 * Access to global timers : Do not depend on a PPSi instances
 * Counters are stored on instance 0.
 */

static inline int pp_gtimeout_get(struct pp_globals *ppg, int index) {
	return pp_timeout_get(INST(ppg,0),index);
}

static inline void pp_timeout_set(struct pp_instance *ppi,int index, int millisec)
{
	pp_timeout_set_rename(ppi,index,millisec);
}

static inline void pp_gtimeout_set(struct pp_globals *ppg,int index, int millisec) {
	pp_timeout_set(INST(ppg,0),index,millisec);
}

static inline int pp_timeout_is_disabled(struct pp_instance *ppi, int index)
{
	return pp_timeout_get(ppi, index)==TIMEOUT_DISABLE_VALUE;
}

static inline int pp_gtimeout_is_disabled(struct pp_globals *ppg, int index)
{
	return pp_gtimeout_get(ppg, index)==TIMEOUT_DISABLE_VALUE;
}

static inline void pp_timeout_disable(struct pp_instance *ppi, int index)
{
	pp_timeout_set(ppi, index, TIMEOUT_DISABLE_VALUE);
}

static inline void pp_gtimeout_disable(struct pp_globals *ppg, int index)
{
	pp_gtimeout_set(ppg, index, TIMEOUT_DISABLE_VALUE);
}

static inline void pp_gtimeout_reset(struct pp_globals *ppg, int index) {
	__pp_timeout_reset(INST(ppg,0),index,1);
}

static inline int pp_gtimeout(struct pp_globals *ppg, int index) {
	return pp_timeout(INST(ppg,0),index);
}

static inline int pp_gnext_delay_1(struct pp_globals *ppg, int index) {
	return pp_next_delay_1(INST(ppg,0),index);
}

static inline int pp_gtimeout_get_timer(struct pp_globals *ppg, int index, to_rand_t rand){
	return pp_timeout_get_timer(INST(ppg,0),index,rand);
}

static inline void pp_timeout_reset(struct pp_instance *ppi, int index)
{
	__pp_timeout_reset(ppi,index,1);
}

static inline void pp_timeout_reset_N(struct pp_instance *ppi, int index, unsigned int multiplier)
{
	__pp_timeout_reset(ppi,index,multiplier);
}


#endif // ifndef _TIMEOUT_PROT_H_
