/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <ppsi/ppsi.h>

/*
 * This is the state machine table. */

const struct pp_state_table_item pp_state_table[] = {
	[PPS_INITIALIZING] = {	"initializing",	pp_initializing},
	[PPS_FAULTY] = {	"faulty",	pp_faulty},
	[PPS_DISABLED] = {	"disabled",	pp_disabled},
	[PPS_LISTENING] = {	"listening",	pp_listening},
	[PPS_PRE_MASTER] = {	"pre-master",	pp_master},
	[PPS_MASTER] = {	"master",	pp_master},
	[PPS_PASSIVE] = {	"passive",	pp_passive},
	[PPS_UNCALIBRATED] = {	"uncalibrated",	pp_slave},
	[PPS_SLAVE] = {		"slave",	pp_slave},
#ifdef CONFIG_ABSCAL
	[PPS_ABSCAL] = {	"abscal",	pp_abscal},
#endif
};
