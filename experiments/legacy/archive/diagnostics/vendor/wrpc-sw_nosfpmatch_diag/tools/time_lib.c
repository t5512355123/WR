/*
 * time_lib.c
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

#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <inttypes.h>
#include <sys/timex.h>
#include <ppsi/ppsi.h>

char * timeIntervalToString(TimeInterval time,char *buf) {

	int64_t sign,nanos,picos;

	if ( time<0 && time !=INT64_MIN) {
		sign=-1;
		time=-time;
	} else {
		sign=1;
	}
	nanos = time >> TIME_INTERVAL_FRACBITS;
	picos = (((time & TIME_INTERVAL_FRACMASK) * 1000) + TIME_INTERVAL_ROUNDING_VALUE ) >> TIME_INTERVAL_FRACBITS;
	sprintf(buf,"%" PRId64 ".%03" PRId64, sign*nanos,picos);
	return buf;
}

char * timeToString(struct pp_time *time, char *buf) {
	char sign = '+';
	int64_t scaled_nsecs = time->scaled_nsecs;
	int64_t secs = time->secs, nanos, picos;

	if (!is_incorrect(time)) {
		if (scaled_nsecs < 0 || secs < 0) {
			sign = '-';
			scaled_nsecs = -scaled_nsecs;
			secs = -secs;
		}
		nanos = scaled_nsecs >> TIME_FRACBITS;
		picos = ((scaled_nsecs & TIME_FRACMASK) * 1000 + TIME_ROUNDING_VALUE)
				>> TIME_FRACBITS;
		sprintf(buf,"%c%" PRId64 ".%09" PRId64 "%03" PRId64,
			sign,secs,nanos,picos);
	} else {
		sprintf(buf, "--Incorrect--");
	}
	return buf;
}

char * timestampToString(struct Timestamp *time,char *buf){
		uint64_t sec=(time->secondsField.msb << sizeof(time->secondsField.msb)) + time->secondsField.lsb;
		sprintf(buf,"%" PRIu64 ".%09" PRIu32 "000",
				sec, (uint32_t)time->nanosecondsField);
		return buf;
}

char * relativeDifferenceToString(RelativeDifference time, char *buf ) {
	char sign;
    int32_t nsecs;
	uint64_t sub_yocto=0;
    int64_t fraction;
	uint64_t bitWeight=500000000000000000;
	uint64_t mask;

	if ( time<0 ) {
		time=-time;
		sign='-';
	} else {
		sign='+';
	}

	nsecs=time >> REL_DIFF_FRACBITS;
    fraction=time & REL_DIFF_FRACMASK;
	for (mask=(uint64_t) 1<< (REL_DIFF_FRACBITS-1);mask!=0; mask>>=1 ) {
		if ( mask & fraction )
			sub_yocto+=bitWeight;
		bitWeight/=2;
	}
	sprintf(buf,"%c%"PRId32".%018"PRIu64, sign, nsecs, sub_yocto);
	return buf;
}

/**
 * Function to subtract timeval in a robust way
 *
 * In order to properly print the result on screen you can use:
 *
 *     int neg=timeval_subtract(&diff, &a, &b);
 *     printf("%c%li.%06li\n",neg?'-':'+',labs(diff.tv_sec),labs(diff.tv_usec));
 *
 * @ref: https://stackoverflow.com/questions/15846762/timeval-subtract-explanation
 * @note for safety reason a copy of x,y is used internally so x,y are never modified
 * @param[inout] result A pointer on a timeval structure where the result will be stored.
 * @param[in] x A pointer on x timeval struct
 * @param[in] y A pointer on y timeval struct
 * @return 1 if result is negative (seconds or useconds)
 *
 *
 */
int timeval_subtract(struct timeval *result, struct timeval *x, struct timeval *y)
{
	struct timeval xx = *x;
	struct timeval yy = *y;
	x = &xx; y = &yy;

	if (x->tv_usec > 999999)
	{
		x->tv_sec += x->tv_usec / 1000000;
		x->tv_usec %= 1000000;
	}

	if (y->tv_usec > 999999)
	{
		y->tv_sec += y->tv_usec / 1000000;
		y->tv_usec %= 1000000;
	}

	result->tv_sec = x->tv_sec - y->tv_sec;
	result->tv_usec = x->tv_usec - y->tv_usec;

	if(result->tv_sec>0 && result->tv_usec < 0)
	{
		result->tv_usec += 1000000;
		result->tv_sec--; // borrow
	}
	else if(result->tv_sec<0 && result->tv_usec > 0)
	{
		result->tv_usec -= 1000000;
		result->tv_sec++; // borrow
	}

	return (result->tv_sec < 0) || (result->tv_usec<0);
}


/**
 * Get the TAI offset decoding the leap seconds file
 * @param leapSecondsFile The leapSecond file name. Use the default one if NULL
 * @param utc             Number of seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC)
 * @param nextTai         if nextTai is not NULL, set to the next TAI in the next 12 hours
 * @param hasExpired      if hasExpired is not NULL, set to 1 if the file has expired
 * @return >=0 : TAI offset
 *          -1 : Error
 */

#define OFFSET_NTP_TIME_TO_UTC ((uint64_t)2208988800LL) /* NTP time to UTC (1900 to 1970 in seconds) */
#define TWELVE_HOURS           ((uint64_t)(60*60*12) )  /* Number of seconds in 12 hours */

static char *defaultLeapSecondsFile = "/etc/leap-seconds.list";

int getTaiOffsetFromLeapSecondsFile(char *leapSecondsFile, time_t utc, int *nextTai,int *hasExpired ) {

	uint64_t expirationDate, ntpTime,nextNtpTime;
	int tai_offset = 9; /* For the time before 1972, we consider that the offset is 9 */
	FILE *f;
	char line[128];

	if ( leapSecondsFile == NULL )
		leapSecondsFile=defaultLeapSecondsFile;

	ntpTime = (uint64_t)utc + OFFSET_NTP_TIME_TO_UTC;
	nextNtpTime= ntpTime + TWELVE_HOURS;

	f = fopen(leapSecondsFile, "r");
	if (!f) {
		fprintf(stderr, "%s: Cannot open file %s: %s\n", __func__, leapSecondsFile,strerror(errno));
		return -1;
	}
	/* Scan the file */
	while (fgets(line, sizeof(line), f)) {
		int tai;
		uint64_t leapNtpTime;

		if ( strcmp(line,"# ")==0)
			continue; // This is a comment
		if (sscanf(line, "#@ %" PRIu64 , &expirationDate) == 1) {
			if ( hasExpired !=NULL )
				*hasExpired=ntpTime>expirationDate;
			continue;
		}
		if (sscanf(line, "%" PRIu64 " %i", &leapNtpTime, &tai) != 2)
			continue;

		/* check this line, and apply it if it's in the past */
		if (leapNtpTime < ntpTime) {
			tai_offset = tai;
			if ( nextTai )
				*nextTai=tai;
		}
		else {
			if ( nextTai && leapNtpTime<=nextNtpTime )
				*nextTai=tai;
			break; // File read can be aborted
		}
	}
	fclose(f);
	return tai_offset;
}


/**
 * Fix the TAI representation looking at the leap file
 * @param leapSecondsFile The leapSecond file name. Use the default one if NULL
 * @param utc             Number of seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC)
 * @param hasExpired      if hasExpired is not NULL, set to 1 if the file has expired
 * @param verbose         Activate verbose mode
 * @return >=0 : TAI offset
 *          -1 : Error
 */
int fixHostTai(char *leapSecondsFile, time_t utc, int *hasExpired, int verbose)
{
	struct timex t;
	int tai_offset;

	/* first: get the current offset */
	memset(&t, 0, sizeof(t));
	if (adjtimex(&t) < 0) {
		fprintf(stderr, "%s: adjtimex(): %s\n", __func__,
			strerror(errno));
		return 0;
	}

	if ( (tai_offset=getTaiOffsetFromLeapSecondsFile(NULL,utc,NULL,hasExpired))<0 ) {
		fprintf(stderr, "%s: Cannot get TAI offset\n", __func__);
		return 0;
	}

	if ( verbose && hasExpired && *hasExpired ) {
		printf("Leap seconds file has expired.\n");
	}

	if (tai_offset != t.tai) {
		if (verbose)
			printf("Previous TAI offset: %i\n", t.tai);
		t.constant = tai_offset;
		t.modes = MOD_TAI;
		if (adjtimex(&t) < 0) {
			fprintf(stderr, "%s: adjtimex(): %s\n", __func__,
				strerror(errno));
			return tai_offset;
		}
		/* read back timex */
		memset(&t, 0, sizeof(t));
		if (adjtimex(&t) < 0) {
			fprintf(stderr, "%s: adjtimex(): %s\n", __func__,
				strerror(errno));
			return 0;
		}
	}
	if (verbose)
		printf("Current TAI offset: %i\n", t.tai);
	return tai_offset;
}
