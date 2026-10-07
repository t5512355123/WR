/*
 * time_lib.h
 *
 * - Time to string conversion functions
 * - Decode leap seconds file
 *
 *  Created on: 2019
 *  Authors:
 * 		- Jean-Claude BAU / CERN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License...
 */
#include <ppsi/ppsi.h>
#include <time.h>
#include <sys/time.h>


/* Prototypes */
extern char * timeIntervalToString(TimeInterval time,char *buf);
extern char * timeToString(struct pp_time *time,char *buf);
extern char * timestampToString(struct Timestamp *time,char *buf);
extern char * relativeDifferenceToString(RelativeDifference time, char *buf );
extern int timeval_subtract(struct timeval *result, struct timeval *x, struct timeval *y);
extern int getTaiOffsetFromLeapSecondsFile(char *leapSecondsFile, time_t utc, int *nextTai,int *hasExpired );
extern int fixHostTai(char *leapSecondsFile, time_t utc, int *hasExpired, int verbose);

