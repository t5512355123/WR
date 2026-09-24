/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012, 2013 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include "storage.h"

#include "dev/fram.h"


const struct storage_rwops spi_fram_rwops = {
	(void *)fram_read,
	(void *)fram_write,
	(void *)fram_erase
};

