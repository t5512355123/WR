/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __RXTS_CALIBRATOR_H
#define __RXTS_CALIBRATOR_H

#define DEFAULT_T24P_PHASE_TRANSITION 2389

void calib_t24p_init(void);
int calib_t24p(void);

int measure_t24p(void);
void calib_t24p_load(void);
#endif
