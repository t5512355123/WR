/*
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released to the public domain
 */

#include <ppsi/ppsi.h>
#include <ppsi-wrs.h>

#define PPSI_EXPORT_STRUCTURES
#include <ppsi_exports.h>

/* Execute command coming ipc */
static int wrsipc_cmd(int cmd, int value)
{
	if(cmd == PPSIEXP_COMMAND_WR_TRACKING) {
		if ( CONFIG_HAS_EXT_WR ) {
			wrh_servo_enable_tracking(value);
			return 0;
		}
	}
	if(cmd == PPSIEXP_COMMAND_L1SYNC_TRACKING) {
		if ( CONFIG_HAS_EXT_L1SYNC ) {
			wrh_servo_enable_tracking(value);
			return 0;
		}
	}
	return -1;

}

static int export_cmd(const struct minipc_pd *pd,
				 uint32_t *args, void *ret)
{
	int i;
	i = wrsipc_cmd(args[0], args[1]);
	*(int *)ret = i;
	return 0;
}

/* To be called at startup, right after the creation of server channel */
void wrs_init_ipcserver(struct minipc_ch *ppsi_ch)
{
	__rpcdef_cmd.f = export_cmd;

	minipc_export(ppsi_ch, &__rpcdef_cmd);
}
