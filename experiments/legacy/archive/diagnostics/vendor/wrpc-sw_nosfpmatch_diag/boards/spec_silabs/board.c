#include "board.h"
#include "dev/spi_flash.h"
#include "dev/i2c_eeprom.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include "dev/si57x.h"
#include "storage.h"
#include "../generic/board-decl.h"

#include <wrc-debug.h>

#include <softpll/softpll_ng.h>

static struct wr_si57x_interface_device si57x;

#define BASE_SI57X_INTERFACE	(DEV_BASE + 0x8000)

#define SI57X_I2C_ADDR 0x55

static void wrc_board_si57x_init(void)
{
	uint8_t regs[16];

	wr_si57x_interface_init(&si57x, BASE_SI57X_INTERFACE, SI57X_I2C_ADDR);

	si57x_reset(&si57x);

	timer_delay_ms(10);

	si57x_read(&si57x, 0, regs, 16);
	uint32_t f_xtal = 0;

	si57x_get_xtal_frequency(&si57x, &f_xtal);

	// set Si570 to 100 MHz, hw interface VCO gain = 3 (~20 ppm)
	si57x_set_frequency(&si57x, f_xtal, 100000000, 3);

	spll_set_aux_mode(0, SPLL_AUX_MODE_SLAVE);
	spll_set_aux_frequency_ratio(0, 5, 4); // 100 MHz / 4 = 125 MHz / 5

	timer_delay_ms(100); // do we really need this?
}

int wrc_board_early_init(void)
{
	wrc_generic_board_storage_init();
	wrc_board_si57x_init();

	return 0;
}

int wrc_board_init(void)
{
	uint8_t mac_addr[6];
	/*
	 * Try reading MAC addr stored in flash
	 */
	if (storage_get_persistent_mac(0, mac_addr) == -1) {
		board_dbg("Failed to get MAC address from the flash. Using fallback address.\n");
		mac_addr[0] = 0x22;
		mac_addr[1] = 0x33;
		mac_addr[2] = 0x44;	/* fallback MAC if get_persistent_mac fails */
		mac_addr[3] = 0x55;
		mac_addr[4] = 0x66;
		mac_addr[5] = 0x77;
	}
	ep_set_mac_addr(&wrc_endpoint_dev, mac_addr);
	ep_pfilter_init_default(&wrc_endpoint_dev);

	return 0;
}

int wrc_board_create_tasks()
{
    return 0;
}
