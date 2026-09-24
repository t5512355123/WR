/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2010 - 2013 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.

The so-called debug inteface is a large, interrupt-driven FIFO which
passes various realtime parameters (e.g. error value, tags, DAC drive)
to an external application where they are further analyzed. It's very
useful for optimizing PI coefficients and/or lock thresholds.

The data is organized as a stream of samples, where each sample can
store a number of parameters.  For example, a stream samples with Y
and ERR parameters can be used to evaluate the impact of
integral/proportional gains on the response of the system.

*/

#ifndef __SPLL_DEBUG_H
#define __SPLL_DEBUG_H

#define SPLL_DBG_SIGNAL_Y 0
#define SPLL_DBG_SIGNAL_ERR 1
#define SPLL_DBG_SIGNAL_TAG 2
#define SPLL_DBG_SIGNAL_REF 3
#define SPLL_DBG_SIGNAL_PERIOD 4
#define SPLL_DBG_SIGNAL_SAMPLE_ID 5
#define SPLL_DBG_SIGNAL_EVENT 6
#define SPLL_DBG_SIGNAL_TIME_MS 7
#define SPLL_DBG_SIGNAL_PHASE_CURRENT 8
#define SPLL_DBG_SIGNAL_PHASE_TARGET 9
#define SPLL_DBG_SIGNAL_SRC 10

#define SPLL_DBG_MAX_SOURCES 8 // maximum number of "source" PLLs

#define SPLL_DBG_SRC_HELPER 0
#define SPLL_DBG_SRC_MAIN   1
#define SPLL_DBG_SRC_EXT    2
#define SPLL_DBG_SRC_AUX(n) (3 + ((n)&0x3))		/* ...          : Main PLL aux clock N */
#define SPLL_DBG_SRC_RAW    7

#define SPLL_DBG_LAST_FLAG   0x80

#define SPLL_DBG_EVT_START 1			/* PLL has just started */
#define SPLL_DBG_EVT_LOCK_ACQUIRED 2		/* PLL has just become locked */
#define SPLL_DBG_EVT_GAIN_SWITCH 3	/* PLL switched the PI gain (scheduling) */
#define SPLL_DBG_EVT_LOCK_LOSS 4		/* PLL has just lost lock */

#define SPLL_DBG_EXTRACT_SOURCE(x) ( (x >> 28) & 0x7 )
#define SPLL_DBG_EXTRACT_SIGNAL(x) ( (x >> 24) & 0xf )
#define SPLL_DBG_EXTRACT_VALUE(x) (x & 0xffffff)
#define SPLL_DBG_IS_LAST_RECORD(x) ( x&0x80000000 )

/* Writes a parameter to the debug FIFO.

value: value of the parameter.
what: type of the parameter and its' source. For example, 
	- DBG_ERR | DBG_HELPER means that (value) contains the phase error of the helper PLL.
	- DBG_EVENT indicates an asynchronous event. (value) must contain the event type (DBG_EVT_xxx)

last: when non-zero, indicates the last parameter in a sample.
*/

void spll_debug(int src, int what, int value, int last);


#endif

