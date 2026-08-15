/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011,2014 CERN (www.cern.ch)
 * Copyright (C) 2012 GSI (www.gsi.de)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 * Author: Alessandro rubini (for the build-time creation of the array)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/*
 * The packet filter documentation is moved to tools/pfilter-builder.c, where
 * the actual packet filter rules are created
 */

#include <string.h>

#include <wrc.h>
#include <shell.h>
#include <dev/endpoint.h>
#include <hw/endpoint_regs.h>
#include "wrc_global.h"


static const uint8_t pfilter_rules_novlan[] =
{
	#include "generated/pfilter-rules-novlan.h"
};

static const uint8_t pfilter_rules_vlan[] =
{
	#include "generated/pfilter-rules-vlan.h"
};

void ep_pfilter_init_default(struct wr_endpoint_device *dev)
{
	const uint8_t *mac = dev->mac_addr;
	const uint8_t *vini, *vend, *v;
	int i;

	/* If vlan, use rule-set 1, else rule-set 0 */
	if (wrc_vlan_number == 0) {
		vini = pfilter_rules_novlan;
		vend = vini + ARRAY_SIZE(pfilter_rules_novlan);
	}
	else {
		vini = pfilter_rules_vlan;
		vend = vini + ARRAY_SIZE(pfilter_rules_vlan);
	}

	ep_write( dev, EP_REG_PFCR0, 0);		// disable pfilter

	for (i = 0, v = vini; v < vend; v += 5, i++) {
		uint64_t cmd_word;
		uint32_t l, h;
		uint32_t cr0, cr1;

		h = v[0];
		l = (v[1] << 24) | (v[2] << 16) | (v[3] << 8) | v[4];

	/*
	 * Patch the local MAC address in place,
	 * in the first three instructions after NOP
	 */
                if (i >= 1 && i <= 3) {
                        unsigned midx = 2 * (i - 1);
                        l &= ~(0xffff << 13);
                        l |= ((mac[midx] << 8) | mac[midx + 1]) << 13;
		}
	/* If this is the VLAN rule-set, patch the vlan number too */
		if (((l >> 13) & 0xffff) == 0x0aaa
                    && ((l >> 7) & 0x1f) == 7) {
			mac_dbg("fixing VLAN number in rule: use %i\n",
					wrc_vlan_number);
                        l &= ~(0xffff << 13);
                        l |= wrc_vlan_number << 13;
	}

                cmd_word = l | ((uint64_t)h << 32);
		//mac_dbg("pfilter rule %02i: %x.%08x\n", i,
                //              (uint32_t)(cmd_word >> 32),
                //              (uint32_t)(cmd_word));

		cr1 = EP_PFCR1_MM_DATA_LSB_W(cmd_word & 0xfff);
		cr0 = EP_PFCR0_MM_ADDR_W(i) | EP_PFCR0_MM_DATA_MSB_W(cmd_word >> 12) |
		    EP_PFCR0_MM_WRITE_MASK;

		ep_write( dev, EP_REG_PFCR1, cr1 );
		ep_write( dev, EP_REG_PFCR0, cr0 );
	}

	ep_write( dev, EP_REG_PFCR0, EP_PFCR0_ENABLE);
}
