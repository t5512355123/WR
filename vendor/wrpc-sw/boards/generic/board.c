#include "board.h"
#include "wrc-debug.h"
#include "dev/w1.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include "storage.h"
#include "board-decl.h"
#include "de5a-identity.h"

int wrc_board_early_init(void)
{
	wrc_generic_board_storage_init();
	return 0;
}

static int board_get_persistent_mac(uint8_t *mac)
{
	int i;
	struct w1_dev *d;
	
	/* Try from SDB */
	if (storage_get_persistent_mac(0, mac) == 0)
		return 0;

	/* Get from one-wire (derived from unique id) */
	if (HAS_W1) {
		for (i = 0; i < W1_MAX_DEVICES; i++) {
			d = wrpc_w1_bus.devs + i;
			if (d->rom) {
				mac[0] = 0x22;
				mac[1] = 0x33;
				mac[2] = 0xff & (d->rom >> 32);
				mac[3] = 0xff & (d->rom >> 24);
				mac[4] = 0xff & (d->rom >> 16);
				mac[5] = 0xff & (d->rom >> 8);
				return 0;
			}
		}
	}

	/* Not found */
	return -1;
}

int wrc_board_init()
{
	uint8_t mac_addr[6];
	/*
	 * Try reading MAC addr stored in flash
	 */
	if (board_get_persistent_mac(mac_addr) < 0) {
		board_dbg("Failed to get MAC address from the flash. Using fallback address.\n");
		mac_addr[0] = DE5A_FALLBACK_MAC_0;
		mac_addr[1] = DE5A_FALLBACK_MAC_1;
		mac_addr[2] = DE5A_FALLBACK_MAC_2;
		mac_addr[3] = DE5A_FALLBACK_MAC_3;
		mac_addr[4] = DE5A_FALLBACK_MAC_4;
		mac_addr[5] = DE5A_FALLBACK_MAC_5;
	}
	ep_set_mac_addr(&wrc_endpoint_dev, mac_addr);
	ep_pfilter_init_default(&wrc_endpoint_dev);

	return 0;
}

int wrc_board_create_tasks()
{
    return 0;
}
