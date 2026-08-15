/*
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Jean-Claude BAU
 *
 * Released according to GNU LGPL, version 2.1 or any later
 */
#include <ppsi/ppsi.h>
#define HAL_EXPORT_STRUCTURES
#include <ppsi-wrs.h>
#include <hal_exports.h>

static hexp_port_info_t *getPortSlot (hexp_port_info_params_t * infos,struct pp_instance *ppi) {
	int i;
	hexp_port_info_t *pinfo;

	for (i = 0; i < infos->numberPortInterfaces; i++) {
		pinfo=&infos->hIFace[i];
		if ( !strcmp(pinfo->name,ppi->iface_name) )
			return pinfo;
	}
	pinfo=&infos->hIFace[infos->numberPortInterfaces];
	strcpy(pinfo->name,ppi->iface_name);
	pinfo->mode=PORT_MODE_OTHER;
	pinfo->synchronized=0;
	infos->numberPortInterfaces++;
	return pinfo;
}
/* Send information about the port for a given instance
*  As many instances can be on the same port, only information on the most
*  interesting port will be sent.
*  Priority :
*   1/ Slave instance
*   2/ Master instance
*   3/ Other
*/

int wrs_update_port_info(struct pp_globals *ppg) {

	int i;
	int ret, rval;
	hexp_port_info_params_t infos={.numberPortInterfaces = 0};
	int nbLinks=ppg->nlinks;

	for (i = 0; i < nbLinks; i++) {
		struct pp_instance *ppi=INST(ppg, i);

		if (ppi->link_up) {
			hexp_port_info_t *pSlot=getPortSlot(&infos,ppi);
			pSlot->mode = 0;
			if ( ppi->state==PPS_SLAVE ) {
				if (!pSlot->synchronized )
					pSlot->synchronized=
							SRV(ppi)->servo_locked &&
							(ppi->protocol_extension==PPSI_EXT_WR || ppi->protocol_extension==PPSI_EXT_L1S) &&
							ppi->extState==PP_EXSTATE_ACTIVE &&
							ppi->pdstate==PP_PDSTATE_PDETECTED;
				/* Set only if it is a synchronzied WR/HA slave
				   (i.e. if the extension is active and protocol detected) */
				if ( pSlot->synchronized )
					pSlot->mode=PORT_MODE_SLAVE;
			} else {
				if ( ppi->state==PPS_MASTER && pSlot->mode!=PORT_MODE_SLAVE ) {
					/* Set only if this is HA/WR Master */
					if((ppi->protocol_extension==PPSI_EXT_WR ||
					    ppi->protocol_extension==PPSI_EXT_L1S) &&
					    ppi->extState==PP_EXSTATE_ACTIVE &&
					    ppi->pdstate==PP_PDSTATE_PDETECTED)
						pSlot->mode=PORT_MODE_MASTER;
				}
			}
		}
	}
	ret = minipc_call(hal_ch, DEFAULT_TO, &__rpcdef_port_info_cmd,
			&rval, &infos);

	if (ret < 0)
		return -1;

	return rval;
}


