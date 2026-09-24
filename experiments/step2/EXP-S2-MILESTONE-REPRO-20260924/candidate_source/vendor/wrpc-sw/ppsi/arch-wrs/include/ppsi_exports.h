#ifndef __PPSI_EXPORTS_H
#define __PPSI_EXPORTS_H

#include <stdio.h>
#include <stdlib.h>

#define PPSIEXP_COMMAND_WR_TRACKING 1
#define PPSIEXP_COMMAND_L1SYNC_TRACKING 2

/* Export structures, shared by server and client for argument matching */
#ifdef PPSI_EXPORT_STRUCTURES

struct minipc_pd __rpcdef_cmd = {
	.name = "cmd",
	.retval = MINIPC_ARG_ENCODE(MINIPC_ATYPE_INT, int),
	.args = {
		MINIPC_ARG_ENCODE(MINIPC_ATYPE_INT, int),
		MINIPC_ARG_ENCODE(MINIPC_ATYPE_INT, int),
		MINIPC_ARG_END,
	},
};

#endif /* PTP_EXPORT_STRUCTURES */

#endif /* __PPSI_EXPORTS_H */
