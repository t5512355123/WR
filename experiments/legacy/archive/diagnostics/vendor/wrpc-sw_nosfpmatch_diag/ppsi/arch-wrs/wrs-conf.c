/*
 * Copyright (C) 2014 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to GNU LGPL, version 2.1 or any later
 */

#include <ppsi/ppsi.h>


struct pp_argline pp_arch_arglines[] = {
	GLOB_OPTION_INT("rx-drop", ARG_INT, NULL, rxdrop),
	GLOB_OPTION_INT("tx-drop", ARG_INT, NULL, txdrop),
	{}
};
