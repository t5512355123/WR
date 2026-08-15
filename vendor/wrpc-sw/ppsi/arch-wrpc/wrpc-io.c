/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released to the public domain
 */
#include <ppsi/ppsi.h>
#include "wrpc.h"
#include "dev/console.h" /* wrpc-sw */

void pp_puts(const char *s)
{
	puts(s);
}
