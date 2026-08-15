/* Need common board.h */
#include "../../include/board.h"
#include "dev/bb_spi.h"
#include "dev/spi_flash.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include "dev/netif.h"
#include "dev/minic.h"
#include "softpll_ng.h"
#include "storage.h"
#include <wrc-event.h>
#include "wrc-debug.h"

static uint8_t board_mac_addr[6];

uint32_t sdbfs_default_bin[] =
{
	#include "sdbfs-image.h"
};

static const int32_t flash_entry_points[] = { 0x0f00000, -1 };

static void sis83k_read_persistent_mac( uint8_t *mac )
{
	uint32_t id, ver, nrw, nro;
	uint32_t sn;
	uint32_t dna[3];
	diag_read_info(&id, &ver, &nrw, &nro );
	board_dbg("diags: id %d ver %d nrw %d nro %d\n", id, ver, nrw, nro );
	diag_read_word(nro - 4, DIAG_RO_BANK, &dna[0] );
	diag_read_word(nro - 3, DIAG_RO_BANK, &dna[1] );
	diag_read_word(nro - 2, DIAG_RO_BANK, &dna[2] );
	diag_read_word(nro - 1, DIAG_RO_BANK, &sn );

	board_dbg("S/N %x DNA %08x %08x %08x\n", sn, dna[0], dna[1], dna[2] );

	// well, we can't do anything else than generate this crap from the device's DNA. The serial numbers
	// provided by the MMC don't appear to be really UNIQUE...
	uint32_t seed = dna[0] ^ dna[1] ^ dna[2];
	mac[0] = 0x22;
	mac[1] = 0x33;
	mac[2] = (seed >> 24) & 0xff;
	mac[3] = (seed >> 16) & 0xff;
	mac[4] = (seed >> 8) & 0xff;
	mac[5] = seed & 0xff;
}

int wrc_board_early_init()
{
	/*
	 * declare GPIO pins and configure their directions for bit-banging SPI
	 * limit SPI speed to 10MHz by setting bit_delay = CPU_CLOCK / 10^6
	 */
	bb_spi_create( &spi_wrc_flash,
		&pin_sysc_spi_ncs,
		&pin_sysc_spi_mosi,
		&pin_sysc_spi_miso,
		&pin_sysc_spi_sclk, CPU_CLOCK / 10000000 );

	spi_wrc_flash.rd_falling_edge = 1;
	
	/*
	 * Initialize SPI flash and read its ID
	 */
	spi_flash_create( &wrc_flash_dev, &spi_wrc_flash, 0x10000, 0xf00000);
	wrc_flash_dev.use_4byte_addr = 0;
	wrc_flash_dev.size = 0x1000000; // 32 MB flash

	unsigned id = spi_flash_read_id( &wrc_flash_dev );

	if( id != 0x00012018 && id != 0xC22019 )
	{
		pp_printf("Warning! The flash memory has unsupported JEDEC ID: 0x%08x\n", id);
	}

	/*
	 * Initialize storage subsystem with newly created SPI Flash
	 */
	storage_spiflash_create( &wrc_storage_dev, &wrc_flash_dev );

	// override default entry point for the flash
	wrc_storage_dev.entry_points = flash_entry_points;

	/*
	 * Mount SDBFS filesystem from storage.
	 */
	storage_mount( &wrc_storage_dev );

	sis83k_read_persistent_mac( board_mac_addr );

	board_dbg("Board MAC Address: %02x:%02x:%02x:%02x:%02x:%02x\n", board_mac_addr[0], board_mac_addr[1], board_mac_addr[2], board_mac_addr[3], board_mac_addr[4], board_mac_addr[5]);

	 /* reset the networking part of the WRCore and start the WR Endpoint */
   	net_rst();

	ep_init( &wrc_endpoint_dev, (void *) BASE_EP );
	ep_set_mac_addr( &wrc_endpoint_dev, board_mac_addr );

	netif_register_device(&wrc_endpoint_dev, &minic);

	/* Sleep for 1s to make sure WRS v4.2 always realizes that
	 * the link is down */
	timer_delay_ms(200);
	ep_enable( &wrc_endpoint_dev, 1, 1);
	timer_delay_ms(200);

	spll_set_aux_mode( 0, SPLL_AUX_MODE_PHASE_MONITOR );
	spll_set_aux_mode( 1, SPLL_AUX_MODE_PHASE_MONITOR );
	
	return 0;
}



static void sis83k_handle_event( int event )
{
	if ( event == WRC_EVENT_LINK_DOWN )
	{
		// fixme: do we need forced PHY reset here?
	}
}

int wrc_board_init()
{
	event_handler_register( 1 << WRC_EVENT_LINK_DOWN, 1, sis83k_handle_event );

	return 0;
}

int wrc_board_create_tasks()
{
    return 0;
}
