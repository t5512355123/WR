/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#include <stdint.h>
#include <string.h>
#include <stddef.h>

#include "ppsi/lib.h"

#include "wrc.h"
#include "wrc-debug.h"
#include "pp-printf.h"
#include "dev/gpio.h"
#include "dev/bb_spi.h"
#include "dev/ad951x.h"
#include "dev/ltc695x.h"
#include "dev/ad9910.h"
#include "dev/24aa025.h"
#include "dev/ad7888.h"
#include "dev/spi_flash.h"
#include "dev/bb_i2c.h"
#include "dev/pps_gen.h"
#include "dev/console.h"
#include "dev/console-uart.h"
#include "dev/endpoint.h"
#include "dev/74x595.h"
#include "dev/minic.h"
#include "dev/netif.h"
#include "dev/leds.h"
#include "dev/wdiags.h"

#include "hw/wrc_diags_regs.h"
#include "revision.h"

#include "endianness.h"

#include "board-state.h"
#include "board-aux.h"
#include "common-uart-link.h"

#include "sensors.h"
#include "softpll_ng.h"
#include "storage.h"
#include "net.h"
#include "wrpc.h"
#include "shell.h"

#include "hw/wr_streamers.h"
#include "wrc-event.h"
#include "lib/events-ptp.h"

#include "ertm15_rf_distr.h"
#include "rf_frame_transceiver.h"

#include "ppsi/ppsi.h"

// allows the eRTM14 board to operate *without* the eRTM15 (no WR support, useful for IPMI testing)
#undef CONFIG_ERTM14_WITHOUT_ERTM15

#include "hw/wb_10mhz_align_unit.h"
#include "wrc-task.h"

#include <errno.h>

struct ertm14_board board;
struct ertm14_board_state _board_state;
struct ertm14_nco_reset ertm14_nco_stats[2];

struct ertm14_board_state *ertm14_current_state = &_board_state;
struct ertm14_board_state ertm14_next_state;
struct ertm14_board_state ertm14_mask;
struct ertm14_board_state ertm14_hardware;

static struct ertm14_mmc_version_info  ertm14_board_info;
static struct ertm14_mmc_version_info  ertm15_board_info;

static uint8_t ertm14_mac[6];

struct gpio_pin pin_pll_main_cs_n = { &board.gpio_aux, 0 };
struct gpio_pin pin_pll_main_sdi = { &board.gpio_aux, 1 };
struct gpio_pin pin_pll_main_sdo = { &board.gpio_aux, 2 };
struct gpio_pin pin_pll_main_sclk = { &board.gpio_aux, 3 };
struct gpio_pin pin_pll_main_reset = { &board.gpio_aux, 4 };
struct gpio_pin pin_pll_main_lock = { &board.gpio_aux, 5 };

struct gpio_pin pin_pll_ext_cs_n = { &board.gpio_aux, 6 };
struct gpio_pin pin_pll_ext_sdi = { &board.gpio_aux, 7 };
struct gpio_pin pin_pll_ext_sdo = { &board.gpio_aux, 8 };
struct gpio_pin pin_pll_ext_sclk = { &board.gpio_aux, 9 };
struct gpio_pin pin_pll_ext_reset = { &board.gpio_aux, 10 };
struct gpio_pin pin_pll_ext_lock = { &board.gpio_aux, 11 };

struct gpio_pin pin_mac_addr_scl = { &board.gpio_aux, 13 };
struct gpio_pin pin_mac_addr_sda = { &board.gpio_aux, 12 };

struct gpio_pin pin_main_xo_en_n = { &board.gpio_aux, 14 };

struct gpio_pin pin_ltc6950_sclk = { &board.gpio_aux, 15 };
struct gpio_pin pin_ltc6950_sdi = { &board.gpio_aux, 16 };
struct gpio_pin pin_ltc6950_sdo = { &board.gpio_aux, 17 };
struct gpio_pin pin_ltc6950_ce_gen = { &board.gpio_aux, 18 };
struct gpio_pin pin_ltc6950_ce_distr = { &board.gpio_aux, 19 };
struct gpio_pin pin_ltc6950_sync = { &board.gpio_aux, 20 };

struct gpio_pin pin_ad9910_lo_sdio = { &board.gpio_aux, 4+21 };
struct gpio_pin pin_ad9910_lo_sclk = { &board.gpio_aux, 5+21 };
struct gpio_pin pin_ad9910_lo_reset = { &board.gpio_aux, 6+21 };
struct gpio_pin pin_ad9910_lo_io_update = { &board.gpio_aux, 3+21 };
const struct gpio_pin pin_ad9910_lo_sync_smp_err = { &board.gpio_aux, 5+21 };

struct gpio_pin pin_ad9910_ref_sdio = { &board.gpio_aux, 4+28 };
struct gpio_pin pin_ad9910_ref_sclk = { &board.gpio_aux, 5+28 };
struct gpio_pin pin_ad9910_ref_reset = { &board.gpio_aux, 6+28 };
struct gpio_pin pin_ad9910_ref_io_update = { &board.gpio_aux, 3+28 };
const struct gpio_pin pin_ad9910_ref_sync_smp_err = { &board.gpio_aux, 5+28 };

struct gpio_pin pin_ocxo_override = { &board.gpio_aux, 48 };
struct gpio_pin pin_ocxo_cs_n = { &board.gpio_aux, 51 };
struct gpio_pin pin_ocxo_sclk = { &board.gpio_aux, 50 };
struct gpio_pin pin_ocxo_data = { &board.gpio_aux, 49 };

struct gpio_pin pin_pwrmon_adc_cs_n = {  &board.gpio_aux, 52 };
struct gpio_pin pin_pwrmon_adc_dout = {  &board.gpio_aux, 46 };
struct gpio_pin pin_pwrmon_adc_din = {  &board.gpio_aux, 47 };
struct gpio_pin pin_pwrmon_adc_sclk = {  &board.gpio_aux, 45 };

struct gpio_pin pin_sys_clk_sel_stb = {  &board.gpio_aux, 61 };
struct gpio_pin pin_sys_clk_sel_next = {  &board.gpio_aux, 62 };

struct gpio_pin pin_pps_out_mode0 = {  &board.gpio_aux, 63 };
struct gpio_pin pin_pps_out_mode1 = {  &board.gpio_aux, 64 };
struct gpio_pin pin_pps_out_mode2 = {  &board.gpio_aux, 65 };

struct gpio_pin pin_led_sync_green = {  &board.gpio_aux, 69 };
struct gpio_pin pin_led_sync_red = {  &board.gpio_aux, 70 };

struct gpio_pin pin_ertm15_leds_ser = { &board.gpio_aux, 66 };
struct gpio_pin pin_ertm15_leds_updtclk = { &board.gpio_aux, 67 };
struct gpio_pin pin_ertm15_leds_shftclk = { &board.gpio_aux, 68 };

struct gpio_pin pin_tm_clk_aux0_lock_en = {  &board.gpio_aux, 71 };
struct gpio_pin pin_fpg_fast_pps_sel = {  &board.gpio_aux, 72 };

// a/b/lo/ref, red->green
struct gpio_pin pin_ertm15_led_clka_red = { &board.gpio_ertm15_leds, 0 };
struct gpio_pin pin_ertm15_led_clka_green = { &board.gpio_ertm15_leds, 1 };
struct gpio_pin pin_ertm15_led_clkb_red = { &board.gpio_ertm15_leds, 2 };
struct gpio_pin pin_ertm15_led_clkb_green = { &board.gpio_ertm15_leds, 3 };
struct gpio_pin pin_ertm15_led_lo_red = { &board.gpio_ertm15_leds, 4 };
struct gpio_pin pin_ertm15_led_lo_green = { &board.gpio_ertm15_leds, 5 };
struct gpio_pin pin_ertm15_led_ref_red = { &board.gpio_ertm15_leds, 6 };
struct gpio_pin pin_ertm15_led_ref_green = { &board.gpio_ertm15_leds, 7 };

struct gpio_pin pin_ertm15_clkab_mosi = { &board.gpio_aux, 57 };
struct gpio_pin pin_ertm15_clkab_miso = { &board.gpio_aux, 57 };
struct gpio_pin pin_ertm15_clkab_sck = { &board.gpio_aux, 58 };
struct gpio_pin pin_ertm15_clka_cs_n = { &board.gpio_aux, 59 };
struct gpio_pin pin_ertm15_clkb_cs_n = { &board.gpio_aux, 60 };

struct ad95xx_config pll_ext_10mhz_config =
#include "configs/ertm_14_pll_ext_10mhz.h"

struct ad95xx_config pll_main_dot050_config =
#include "configs/ertm_14_pll_main_dot050_config.h"

struct ad95xx_config pll_main_ocxo_config =
#include "configs/ertm_14_pll_ocxo_config.h"

struct ltc695x_config pll_ertm15_bootstrap_config =
#include "configs/ertm_15_ltc6950_config_rev2.h"

struct ltc695x_config clkab_ertm15_bootstrap_config =
#include "configs/ertm_15_ltc6953_bootstrap_config.h"

spll_gain_schedule_t spll_main_ocxo_gain_sched;

#define ERTM14_BIST_LTC6950 0
#define ERTM14_BIST_MAC_EEPROM 1
#define ERTM14_BIST_AD951X_MAIN 2
#define ERTM14_BIST_AD951X_EXT 3
#define ERTM14_BIST_MAIN_OCXO 4
#define ERTM14_BIST_DMTD_VCXO 5
#define ERTM14_BIST_CLKA 6
#define ERTM14_BIST_CLKB 7
#define ERTM14_BIST_DDS_REF 8
#define ERTM14_BIST_DDS_LO 9
#define ERTM14_BIST_FLASH_PRESENCE 10
#define ERTM14_BIST_FLASH_FS_MOUNT 11
#define ERTM14_BIST_MMC_14 12
#define ERTM14_BIST_MMC_15 13
#define ERTM14_BIST_ERTM15_PRESENCE 14
#define ERTM14_BIST_PLL_LOCK 15
#define ERTM14_BIST_LOAD_CALIBRATION 16
#define ERTM14_BIST_CHECK_CALIBRATION 17

#define BIST_STATUS_DONE (1<<0)
#define BIST_STATUS_ERROR (1<<1)

struct bist_stage
{
    uint8_t id;
    const char *name;
    uint8_t n_channels;
    uint64_t status;
};

static struct bist_stage ertm_bist[] = {
    {ERTM14_BIST_ERTM15_PRESENCE, "Check eRTM15 presence", 1},
    {ERTM14_BIST_FLASH_PRESENCE, "Check flash presence", 1},
    {ERTM14_BIST_FLASH_FS_MOUNT, "Mount flash FS", 1},
    {ERTM14_BIST_LTC6950, "LTC6950", 1},
    {ERTM14_BIST_MAC_EEPROM, "MAC EEPROM", 1},
    {ERTM14_BIST_AD951X_EXT, "AD9510 (Ext)", 1},
    {ERTM14_BIST_AD951X_MAIN, "AD9510 (Main)", 1},
    {ERTM14_BIST_CLKA, "LTC6953 (CLKA fanout)", 1},
    {ERTM14_BIST_CLKB, "LTC6953 (CLKB fanout)", 1},
    {ERTM14_BIST_DDS_LO, "DDS comm (LO)", 1},
    {ERTM14_BIST_DDS_REF, "DDS comm (REF)", 1},
    {ERTM14_BIST_MMC_14, "MMC Link (eRTM14)", 1},
    {ERTM14_BIST_MMC_15, "MMC Link (eRTM15)", 1},
    {ERTM14_BIST_PLL_LOCK, "PLL Lock", 1},
    {ERTM14_BIST_LOAD_CALIBRATION, "Load caldata from flash", 1},
    {ERTM14_BIST_CHECK_CALIBRATION, "Check caldata validity", 1},
    {0, NULL}};


static struct wrc_sensor ertm_sensors[] = {
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM14 FPGA",
        .id = ERTM14_TEMP_FPGA
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM14 DC/DC",
        .id = ERTM14_TEMP_DCDC
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM14 P3V3",
        .id = ERTM14_VOLTAGE_P3V3
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM14 P12V",
        .id = ERTM14_VOLTAGE_P12V
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 Main PSU",
        .id = ERTM15_TEMP_PSU
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 RF Distr LO",
        .id = ERTM15_TEMP_LO_RF
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 RF Distr REF",
        .id = ERTM15_TEMP_REF_RF
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 DDS LO",
        .id = ERTM15_TEMP_LO_DDS
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 DDS REF",
        .id = ERTM15_TEMP_REF_DDS
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 LTC6950 PLL",
        .id = ERTM15_TEMP_LTC6150
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 OCXO 1",
        .id = ERTM15_TEMP_OCXO1
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 OCXO 2",
        .id = ERTM15_TEMP_OCXO2
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 CLKA Fanout",
        .id = ERTM15_TEMP_CLKA_FANOUT
    },
    {
        .flags = WRC_SENSOR_TEMP_CELSIUS,
        .name = "eRTM15 CLKB Fanout",
        .id = ERTM15_TEMP_CLKB_FANOUT
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM15 P3V3",
        .id = ERTM15_VOLTAGE_P3V3
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM15 P12V",
        .id = ERTM15_VOLTAGE_P12V
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM15 P9V0_LO",
        .id = ERTM15_VOLTAGE_P9V0_LO
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM15 P9V0_REF",
        .id = ERTM15_VOLTAGE_P9V0_REF
    },
    {
        .flags = WRC_SENSOR_VOLTAGE_MV,
        .name = "eRTM15 OCXO Voltage",
        .id = ERTM15_VOLTAGE_POCXO
    },
    {
        .flags = WRC_SENSOR_CURRENT_MA,
        .name = "eRTM15 OCXO Current",
        .id = ERTM15_CURRENT_OCXO
    },
    {
        .flags = 0
    }
};


#define MMC_POLL_STATE_IDLE 0
#define MMC_POLL_STATE_WAIT_RESPONSE 1

#define ERTM14_MMC_POLL_PERIOD_MS 1000 /* milliseconds */
#define ERTM14_MMC_RX_TIMEOUT_MS 1000 /* milliseconds */

struct ertm14_mmc_link
{
    struct uart_link ulink;
    int poll_state;
    timeout_t poll_timeout, rx_timeout;
};

static struct ertm14_mmc_link mmc14_link;
static struct ertm14_mmc_link mmc15_link;

/* Non-hw implementation of the diagnostic registers. The eRTM is a
   special board in the sense that it has no externally accessibe memory map -
   therefore it's pointless to keep dedicated hardware diagnostic registers. We
   just keep a structure reflecting the diag register layout in the RAM below. */

static struct wrc_diags wrc_diags_nonhw;

static void mmc_show_version_info( const char *brdname, struct ertm14_mmc_state *st );
static void streamers_init(void);
static void streamers_set_rx_latency( uint32_t lat );
static void streamers_set_rx_timeout( uint32_t tmo );
static int check_calibration_version(void);

void streamers_reset_rx_stats(void);

int mmc_link_request_state(struct ertm14_mmc_link *link);
int mmc_link_poll_state(struct ertm14_mmc_link *link, struct ertm14_mmc_state *state, int blocking);

//#define PROFILE_ULINK

void bist_checkpoint( struct bist_stage *bist, int id, int channel, int pass )
{
    int i;
    for(i = 0; bist[i].name; i++ )
        if( bist[i].id == id )
        {
            bist[i].status &= ~(3 << (channel * 2) );

            if(!pass)
                bist[i].status |= BIST_STATUS_ERROR << (channel * 2);
            bist[i].status |= BIST_STATUS_DONE << (channel * 2);
        }
}

void bist_init( struct bist_stage *bist )
{
    int i;
    for(i = 0; bist[i].name; i++ )
        bist[i].status = 0;
}

int bist_summary( struct bist_stage *bist )
{
    int i;
    int n_ok = 0, n_errors = 0;
    pp_printf("Built-in Self Test Summary\n------------------------------\n");
    pp_printf("Id  | Test name                       | Channel | Status       \n");

    for(i = 0; bist[i].name; i++ )
    {
        int ch;
        struct bist_stage *s = &bist[i];

        for( ch = 0; ch < s->n_channels; ch++ )
        {
            pp_printf("%-3d | %-31s | ", i + 1, bist[i].name);
            if( s->n_channels > 1 )
                pp_printf("%-2d    | ", ch );
            else
                pp_printf("-       | ");

            int stat = s->status >> (ch * 2);

            if( !( stat & BIST_STATUS_DONE ) )
                pp_printf("Not ran");
            else if (stat & BIST_STATUS_ERROR)
            {
                pp_printf("ERROR");
                n_errors++;
            }
            else
            {
                pp_printf("OK");
                n_ok++;
            }

            pp_printf("\n");
        }
    }

    if( n_errors )
        pp_printf("--------------------------------\nBIST FAILED with %d ERRORS!\n\n\n", n_errors );
    else
        pp_printf("BIST PASSED.\n");

    return n_errors > 0 ? -1 : 0;
}

static int ertm_init_complete = 0;

void ertm14_set_pps_out_mode(int mode);
void ertm15_force_rf_power_measurement(void);
static void mmc_comm_init(void);

#define LTC6950_ID_VALUE 0x65

static int wait_ertm15_presence(void)
{
    board_dbg("Waiting for the eRTM15 to power up...\n");

    led_action( &board.leds.sync, LED_COLOR_1 | LED_COLOR_2, LED_BLINK );

    timeout_t e15_powerup_timeout;
    timeout_t e15_rx_timeout;

    tmo_init( &e15_powerup_timeout, 60000 );

    while( !tmo_expired( &e15_powerup_timeout ) )
    {
        struct ertm14_mmc_state state;

        tmo_init( &e15_rx_timeout, 1000 );

        mmc_link_request_state( &mmc15_link );

        int ret = -1;
        while( !tmo_expired( &e15_rx_timeout ) )
        {
            leds_update();
            ret = mmc_link_poll_state( &mmc15_link, &state, 0 );
            if( ret != 0 )
                break;
        }

        if( ret > 0 )
        {
            uint32_t flags = le32_to_host( state.flags );
            board_dbg("Got eRTM15 rsp, flags = %x\n", flags );

            if( flags & ERTM_FLAGS_POWERED_ON )
            {
                return 1;
            }
        }
    }

    return 0;
}

/* CLKA inverted outputs: 0, 1, 4, 5, 6 (LTC6953 ordering) */
/* CLKB inverted outputs: 2, 7, 8, 9 (LTC6953 ordering) */

struct clkab_output_map_entry
{
    int8_t id_ltc6953;
    int8_t id_backplane;
    uint8_t invert;
};

/* Backplane output mapping:

   LTC6953 Output        BP Output      Invert
   0                     CLKA10            x
   1                     CLKA11            x
   2                     CLKA9
   3                     CLKA8
   4                     CLKA7             x
   5                     CLKA6             x
   6                     CLKA12            x
   7                     CLKA5
   8                     CLKA4
   9                     CLKA14
   10                    CLKA-FP
*/

static const struct clkab_output_map_entry clka_out_map[] =
    {
        {0, 10, 1},
        {1, 11, 1},
        {2, 9, 0},
        {3, 8, 0},
        {4, 7, 1},
        {5, 6, 1},
        {6, 12, 1},
        {7, 5, 0},
        {8, 4, 0},
        {9, 14, 0},
        {10, ERTM14_CLKAB_OUT_FRONT_PANEL, 0},
        {-1, -1, 0}
};

/* LTC6953 Output        BP Output      Invert
   0                     CLKB14
   1                     CLKB10
   2                     CLKB12             x
   3                     CLKB11
   4                     CLKB9
   5                     CLKB8
   6                     CLKB7
   7                     CLKB6             x
   8                     CLKB5             x
   9                     CLKB4             x
   10                    CLKB-FP
*/


static const struct clkab_output_map_entry clkb_out_map[] =
    {
        {0, 14, 0},
        {1, 10, 0},
        {2, 12, 1},
        {3, 11, 0},
        {4, 9, 0},
        {5, 8, 0},
        {6, 7, 0},
        {7, 6, 1},
        {8, 5, 1},
        {9, 4, 1},
        {10, ERTM14_CLKAB_OUT_FRONT_PANEL, 0},
        {-1, -1, 0}
};


static void ertm14_spll_setup(void)
{
/* configure a suitable PI gain schedule for the SoftPLL: */
    spll_gain_schedule_t* gs=  &spll_main_ocxo_gain_sched;

    gs->n_stages = 1;

/* we start with ~100 Hz bandwidth to make it lock reasonably fast */
    gs->stages[0].kp = -4000 * 16;
    gs->stages[0].ki = -5 * 16;
    gs->stages[0].lock_samples = 30000;
    gs->stages[0].shift = 8;

/* once it's locked, the loop bandwidth is switched to ~0.1 Hz to filter out WR link added phase noise */
    gs->stages[1].kp = -3000;
    gs->stages[1].ki = -5;
    gs->stages[1].lock_samples = 10000;
    gs->stages[1].shift = 8;

    // disable 2nd stage for DOT050 and Morion OCXO
    if ( board.mode & ERTM14_MODE_WITHOUT_ERTM15 )
        gs->n_stages = 1;
    
    if ( board.mode & ERTM14_MODE_OCXO_10MHZ )
        gs->n_stages = 1;
        
#if 0
    gs->n_stages = 1;

/* we start with ~100 Hz bandwidth to make it lock reasonably fast */
    gs->stages[0].kp = -4000;
    gs->stages[0].ki = -5;
    gs->stages[0].lock_samples = 10000;
    gs->stages[0].shift = 12;
#endif

	spll_set_gain_schedule( gs );
    spll_set_pi_gain( SPLL_LOOP_HELPER, 0, -700, -2, 8 );

    // Aux clock 0 is used for 'factory' calibration of CLKAB/LO/REF outputs.
    spll_set_aux_mode( 0, SPLL_AUX_MODE_PHASE_MONITOR );
    gen_gpio_out( &pin_tm_clk_aux0_lock_en, 1 );
}


static int ad9910_set_fine_delay( struct fine_pulse_gen_channel *ch, int n_taps )
{
    struct ad9910_device *dev;

    if(ch->index == ERTM14_DDS_SYNC_REF)
        dev = &board.dds_ad9910_ref;
    else
        dev = &board.dds_ad9910_lo;

    ad9910_configure_sync( dev, 1, n_taps );
    return 0;
}

static void ertm14_dds_trigger_ioupdate( struct ad9910_device *dev )
{
    int channel = (dev == &board.dds_ad9910_ref ? ERTM14_DDS_IOUPDATE_REF : ERTM14_DDS_IOUPDATE_LO);
    fine_pulse_gen_force_pulse( &board.dds_sync_dev, channel );
}


static int ertm14_is_ioupdate_triggered( struct ad9910_device *dev )
{
    int channel = (dev == &board.dds_ad9910_ref ? ERTM14_DDS_IOUPDATE_REF : ERTM14_DDS_IOUPDATE_LO);
    return fine_pulse_gen_is_triggered( &board.dds_sync_dev, 1 << channel );
}


static int ertm14_switch_sys_clock( int use_sys_from_pll )
{
    gen_gpio_out( &pin_sys_clk_sel_next, use_sys_from_pll );
    gen_gpio_out( &pin_sys_clk_sel_stb, 1);
    gen_gpio_out( &pin_sys_clk_sel_stb, 0);
    return 0;
}

    
static int ertm14_dds_sync_init(void)
{
    const int n_params = 4;
    int save_calib = 0;
    struct {
        uint32_t id;
        int channel;
        const char *name;
        int default_value_ps;
    } params[] = {
        { CAL_PARAM_DDS_LO_IOUPDATE_DELAY_PS, ERTM14_DDS_IOUPDATE_LO, "DDS LO IoUpdate", 0 },
        { CAL_PARAM_DDS_REF_IOUPDATE_DELAY_PS, ERTM14_DDS_IOUPDATE_REF, "DDS REF IoUpdate", 0 },
        { CAL_PARAM_CLKA_SYNC_DELAY_PS, ERTM14_PLL_SYNC_CLKA, "CLKA Dist SYNC", 200 },
        { CAL_PARAM_CLKB_SYNC_DELAY_PS, ERTM14_PLL_SYNC_CLKB, "CLKB Dist SYNC", 200 }
    };

    int i;


    // retrieve calibration delays on DDS IOUPDATE and CLKAB SYNC lines from the calibration stored in eeprom
    for( i = 0; i < n_params; i++ )
    {
        uint32_t val = board.dds_sync_delays[ params[i].channel ];
        if( !storage_get_calibration_parameter( params[i].id, &val ) )
        {
            board_dbg("Sync Unit channel '%s': delay (from calibration file) = %d ps\n", params[i].name, val);
        }
        else
        {
            val = params[i].default_value_ps;
            storage_set_calibration_parameter( params[i].id, val );
	    save_calib = 1;
            board_dbg("Sync Unit channel '%s': delay not found in calibration file, using default = %d ps\n", params[i].name, val );
        }
        board.dds_sync_delays[ params[i].channel ] = val;
    }

    if (save_calib)
	    storage_save_calibration();

// Sync_in: continuous waveform, use external delay line (inside AD9910)
    
    // produce a continuous sync clock for the DDSes
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_SYNC_LO, 1, board.dds_sync_delays[ERTM14_DDS_SYNC_LO], 0, FINE_PULSE_GEN_CONTINUOUS );
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_SYNC_REF, 1, board.dds_sync_delays[ERTM14_DDS_SYNC_REF], 0, FINE_PULSE_GEN_CONTINUOUS );

    fine_pulse_gen_set_external_fine_delay( &board.dds_sync_dev, ERTM14_DDS_SYNC_REF, 75, ad9910_set_fine_delay );
    fine_pulse_gen_set_external_fine_delay( &board.dds_sync_dev, ERTM14_DDS_SYNC_LO, 75, ad9910_set_fine_delay );

    //board_dbg("ref delay = %d lo delay = %d\n", board.dds_sync_delays[ERTM14_DDS_IOUPDATE_REF], board.dds_sync_delays[ERTM14_DDS_IOUPDATE_LO] );
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_IOUPDATE_LO, 1, board.dds_sync_delays[ERTM14_DDS_IOUPDATE_LO], 0, 0 );
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_IOUPDATE_REF, 1, board.dds_sync_delays[ERTM14_DDS_IOUPDATE_REF], 0, 0 );

    // LTC6953 EZS_SRQ (SYNC) pulse: positive polarity, trigger on PPS, pulse width > 1ms
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_PLL_SYNC_CLKA, 1, board.dds_sync_delays[ERTM14_PLL_SYNC_CLKA], 1000, 0 );
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_PLL_SYNC_CLKB, 1, board.dds_sync_delays[ERTM14_PLL_SYNC_CLKB], 1000, 0 );
    
    return 0;
}


static void ertm14_dds_sync_calibrate(void)
{
    shw_pps_gen_init();
    shw_pps_gen_enable_output(1);
    shw_pps_gen_unmask_output(1);

    int i = 0, j;

    uint32_t channel_mask = ( 1 << ERTM14_DDS_SYNC_LO ) | ( 1<< ERTM14_DDS_SYNC_REF );

    int fine = 0;

    #define MIN_SAMPLE_WINDOW_LENGTH 3
    #define AD9910_FINE_DELAY_STEP_PS 75

    struct dds_sync_window {
        int smp_err;
        int start;
        int length;
        int best_start;
        int best_length;
        int setpoint;
    } windows[2];

    for( j=0; j<2; j++ )
    {
        windows[j].best_start = -1;
        windows[j].best_length = -1;
        windows[j].start = -1;
        windows[j].length = 0;
    }

    for(i = 0; i < 100; i++)
    {
//        pp_printf("Sync [fine %d]! ", fine);

        fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_SYNC_LO, 1, 100000 + fine, 0, FINE_PULSE_GEN_CONTINUOUS );
        fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_SYNC_REF, 1, 100000 + fine, 0, FINE_PULSE_GEN_CONTINUOUS );
        fine_pulse_gen_set_external_fine_delay( &board.dds_sync_dev, ERTM14_DDS_SYNC_REF, 75, ad9910_set_fine_delay );
        fine_pulse_gen_set_external_fine_delay( &board.dds_sync_dev, ERTM14_DDS_SYNC_LO, 75, ad9910_set_fine_delay );

        fine_pulse_gen_trigger( &board.dds_sync_dev, channel_mask, 1 );
        while ( !fine_pulse_gen_is_triggered( &board.dds_sync_dev, channel_mask ) );

        windows[0].smp_err = !!gen_gpio_in( &pin_ad9910_lo_sync_smp_err );
        windows[1].smp_err = !!gen_gpio_in( &pin_ad9910_ref_sync_smp_err );
        for( j=0; j<2;j++ )
        {
            if (windows[j].smp_err)
            {
                if( windows[j].length >= MIN_SAMPLE_WINDOW_LENGTH && windows[j].best_length < 0 )
                {
                    windows[j].best_start = windows[j].start;
                    windows[j].best_length = windows[j].length;
                }

                windows[j].start = -1;
                windows[j].length = 0;
            }
            else
            {
                if( windows[j].start < 0 )
                    windows[j].start = fine;

                windows[j].length++;
            }
        }

        //pp_printf("Fine %d SmpERR LO %d REF %d\n", fine, windows[0].smp_err, windows[1].smp_err);

        fine += AD9910_FINE_DELAY_STEP_PS;
    }

    for( j=0; j<2; j++ )
    {
        // sync_in fine delay setpoint is the 
        windows[j].setpoint = windows[j].best_start + ( AD9910_FINE_DELAY_STEP_PS * windows[j].best_length ) / 2;
    }
    

    board_dbg("DDS_LO SYNC start=%d ps length=%d samples setpoint=%d ps\n",
        windows[0].best_start, windows[0].best_length, windows[0].setpoint
    );
    board_dbg("DDS_REF SYNC start=%d ps length=%d samples setpoint=%d ps\n",
        windows[1].best_start, windows[1].best_length, windows[1].setpoint
    );

    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_SYNC_LO, 1, 100000 + windows[0].setpoint, 0, FINE_PULSE_GEN_CONTINUOUS );
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_SYNC_REF, 1, 100000 + windows[1].setpoint, 0, FINE_PULSE_GEN_CONTINUOUS );

    fine_pulse_gen_trigger( &board.dds_sync_dev, channel_mask, 1 );
        while ( !fine_pulse_gen_is_triggered( &board.dds_sync_dev, channel_mask ) );
}
    
        
void blink(int id)
{
    struct gpio_pin *pin = NULL;

    if(id == 0 )
        pin = &pin_ertm15_led_lo_green;
    else if (id == 1 )
        pin = &pin_ertm15_led_lo_red;
    else if (id == 2 )
        pin = &pin_ertm15_led_ref_red;

    gen_gpio_out( pin, 1 );
    timer_delay_ms(50);
    gen_gpio_out( pin, 0 );
    timer_delay_ms(50);
}

static void control_uart_mode_callback( int is_binary )
{
    if( is_binary )
        uart_link_reset( &board.control_uart_link );
}

static int ertm_process_psnmp(
	struct uart_packet *rx_pkt, struct uart_packet *tx_pkt);

static int control_uart_poll(void)
{
    struct uart_packet *pkt;

    if( uart_link_recv( &board.control_uart_link, &pkt, 0 ) > 0 )
    {
        struct uart_packet t, *tx_pkt = &t;

        #ifdef PROFILE_ULINK
        board_dbg("UL RXReq %d ms\n", timer_get_tics() );
        #endif

        /*... dispatch */
        if( pkt->ptype == ERTM14_UART_PTYPE_PING )
    {
	    /* build funny pong packet */
	    static const char hello[] = "i am david\n";
            tx_pkt->ptype = ERTM14_UART_PTYPE_PING;
            tx_pkt->length = 10;
	    memcpy(&tx_pkt->payload, hello, sizeof(hello));

            uart_link_send( &board.control_uart_link, tx_pkt );

            blink(1);
        } else if (pkt->ptype == ERTM14_UART_PTYPE_SNMP_REQ) {

	    /* dispatch on (psuedo)snmp payload */
	    ertm_process_psnmp(pkt, tx_pkt);

	    /* we presume this is binary, snmp or not */
        #ifdef PROFILE_ULINK
        board_dbg("UL TXResp %d ms\n", timer_get_tics() );
        #endif

            uart_link_send(&board.control_uart_link, tx_pkt);
        #ifdef PROFILE_ULINK
        board_dbg("UL TXDone %d ms\n", timer_get_tics() );
        #endif

	}
    }

    return 0;
}

#include "psnmp-proto.h"

/* ensure all uart traffic is in network order */
static void dds_state_order(struct ertm14_dds_state *dds, int hton)
{
    int i;
    uint32_t (*convert)(uint32_t hostlong) = (hton ? htonl : ntohl);

    dds->ftw         = convert(dds->ftw);
    dds->amp_power   = convert(dds->amp_power);
    dds->ampl_factor = convert(dds->ampl_factor);
    dds->sync_source = convert(dds->sync_source);
    dds->sync_count  = convert(dds->sync_count);
    for (i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++)
	    dds->out_power[i] = convert(dds->out_power[i]);
}

static void board_state_to_no(struct ertm14_board_state *dds, int hton)
{
    struct ertm14_board_state *result = dds;
    int i;
    uint32_t (*convert)(uint32_t hostlong) = (hton ? htonl : ntohl);

    result->clka_enable_mask = convert(result->clka_enable_mask);
    result->clkb_enable_mask = convert(result->clkb_enable_mask);
    for (i = ERTM14_CLKAB_OUT_MIN_ID; i <=  ERTM14_CLKAB_OUT_MAX_ID; i++) {
	    result->clka_freq_hz[i] = convert(result->clka_freq_hz[i]);
	    result->clkb_freq_hz[i] = convert(result->clkb_freq_hz[i]);
    }
    dds_state_order(&result->ref, hton);
    dds_state_order(&result->lo, hton);
}

static void get_sim_board_config(struct ertm14_board_state *bs)
{
    struct ertm14_board_state r, *result = &r;

    copy_config(result, &ertm14_hardware);
    board_state_to_no(result, 1);
    copy_config(bs, result);
}

static void get_board_config(struct ertm14_board_state *bs)
{
    struct ertm14_board_state r, *result = &r;

    copy_config(result, ertm14_current_state);
    board_state_to_no(result, 1);
    copy_config(bs, result);
}

static int clkab_set_output_divider( struct ertm14_board_state *state, int clka_or_clkb, int output, int divider);
static int clkab_enable_output( struct ertm14_board_state *state, int clka_or_clkb, int output, int enable);
static int clkab_enable_sync( struct ertm14_board_state *state, int clka_or_clkb, int output, int enable );

static int apply_dds_config( struct ad9910_device *dev, struct ertm14_dds_state* new_state, struct ertm14_dds_state *old_state, struct ertm14_dds_state *mask, int force_all )
{
    uint32_t new_ftw = old_state->ftw;
    uint32_t new_ampl_factor = old_state->ampl_factor;

//    board_dbg("apply dds cfg: af %d mask %d\n", new_state->ampl_factor, mask->ampl_factor );
//    board_dbg("apply dds cfg: ftw %d mask %d\n", new_state->ftw, mask->ftw );

    int config_changed = 0;

	if( mask->ampl_factor && ( new_state->ampl_factor != old_state->ampl_factor) )
    {
        new_ampl_factor = new_state->ampl_factor;
        config_changed = 1;
    }

    if( mask->ftw && ( new_state->ftw != old_state->ftw) )
    {
        new_ftw = new_state->ftw;
        config_changed = 1;
    }

    if( force_all )
    {
        new_ftw = new_state->ftw;
        new_ampl_factor = new_state->ampl_factor;
        config_changed = 1;
    }

    if( config_changed )
    {
        board_dbg("DDS[%p]: changing FTW=0x%08x, ampl=%d\n", dev, new_ftw, new_ampl_factor );

        //        shw_pps_gen_enable_output(1);
        // shw_pps_gen_unmask_output(1);

        //fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_IOUPDATE_LO, 1, board.dds_sync_delays[ERTM14_DDS_IOUPDATE_LO], 0, 0 );
        //fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_IOUPDATE_REF, 1, board.dds_sync_delays[ERTM14_DDS_IOUPDATE_REF], 0, 0 );

        ad9910_program( dev, new_ftw, 0, new_ampl_factor );

        // ugly hack below: when the NCO reset is subscribed to, we must wait until the IOUPDATE pulse has been forcefully generated.
        // otherwise, the NCO SYNC FSM will take over too early and the sync pulse will never be produced (or produced when the next cycle/NCO reset arrives)

        // we need some sort of builtin PPM here, but for the SPS operation this is enough
        do
        {
            timer_delay_ms(100);
        } while( !ertm14_is_ioupdate_triggered ( dev ) );

        return 1;
    }

    return 0;
}

static void streamers_init(void)
{
    streamers_set_rx_latency( ERTM14_NCO_RESET_DEFAULT_LATENCY );
    streamers_set_rx_timeout( ERTM14_NCO_RESET_DEFAULT_TIMEOUT );
}

static inline void streamers_writel( uint32_t val, uint32_t reg )
{
    writel( val, (void*)(BASE_ERTM14_STREAMERS + reg ) ); 
}

static inline uint32_t streamers_readl( uint32_t reg )
{
    return readl( (void*)(BASE_ERTM14_STREAMERS + reg ) ); 
}

static void streamers_set_rx_latency( uint32_t lat )
{
    board_dbg("streamers: set RX latency = %d cycles\n", lat );
    streamers_writel( lat, offsetof( struct WR_STREAMERS_WB, RX_CFG5 ) );
    streamers_writel( WR_STREAMERS_CFG_OR_RX_FIX_LAT, offsetof( struct WR_STREAMERS_WB, CFG ) );
}

int streamers_get_rx_latency(void)
    {
    return streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG5 ) );
}

int streamers_get_rx_timeout(void)
{
    return streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG6 ) );
}

static void streamers_set_rx_timeout( uint32_t tmo )
{
    board_dbg("streamers: set RX timeout = %d cycles\n", tmo );
    streamers_writel( tmo, offsetof( struct WR_STREAMERS_WB, RX_CFG6 ));
    streamers_writel( WR_STREAMERS_CFG_OR_RX_FIX_LAT, offsetof( struct WR_STREAMERS_WB, CFG ));
}


void streamers_reset_rx_stats(void)
{
    streamers_writel( WR_STREAMERS_SSCR1_RST_STATS, offsetof( struct WR_STREAMERS_WB, SSCR1 ));
}

void ertm14_apply_config(struct ertm14_board_state *cfg,
	struct ertm14_board_state *mask, int force_all)
{
	/* this is lifted from Tom's ertm14_commit_board_config,
	 * adding a condition to each operation to mask them at will
	 */
	int i;
	for (i = 0; i <= ERTM14_CLKAB_OUT_MAX_ID; i++) {
		/* digital clocks */
		int freq_a = cfg->clka_freq_hz[i];
		int freq_b = cfg->clkb_freq_hz[i];
		int div_a = ertm14_get_clkab_divider( freq_a );
		int div_b = ertm14_get_clkab_divider( freq_b );
		int enable_a = ( cfg->clka_enable_mask & (1<<i) ) ? 1 : 0;
		int enable_b = ( cfg->clkb_enable_mask & (1<<i) ) ? 1 : 0;

        if (force_all)
        {
            clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKA, i, div_a);
            clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKB, i, div_b);
            clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKA, i, enable_a );
            clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKB, i, enable_b );
        }
        else
        {
            if (mask->clka_freq_hz[i] && (cfg->clka_freq_hz[i] != ertm14_current_state->clka_freq_hz[i]))
                clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKA, i, div_a);
            if (mask->clkb_freq_hz[i] && (cfg->clkb_freq_hz[i] != ertm14_current_state->clkb_freq_hz[i]))
                clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKB, i, div_b);
            if ((mask->clka_enable_mask & (1<<i)) &&
                ((cfg->clka_enable_mask & (1<<i)) != (ertm14_current_state->clka_enable_mask & (1<<i))))
                clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKA, i, enable_a );
            if ((mask->clkb_enable_mask & (1<<i)) &&
                ((cfg->clkb_enable_mask & (1<<i)) != (ertm14_current_state->clkb_enable_mask & (1<<i))))
                clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKB, i, enable_b );
        }
        }

	/* DDSes */

    if( apply_dds_config( &board.dds_ad9910_lo, &cfg->lo, &ertm14_current_state->lo, &mask->lo, force_all ) )
    {
        event_post(WRC_ERTM14_EVENT_LO_RECONFIGURED);
    }

    if( apply_dds_config( &board.dds_ad9910_ref, &cfg->ref, &ertm14_current_state->ref, &mask->ref, force_all ) )
    {
        event_post(WRC_ERTM14_EVENT_REF_RECONFIGURED);
    }

	for (i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++) {
		int st_lo = cfg->lo.out_state[i] == ERTM15_RF_OUT_ON ? 1 : 0;
		int st_ref = cfg->ref.out_state[i] == ERTM15_RF_OUT_ON ? 1 : 0;

        if( force_all )
        {
    	    ertm15_rf_distr_output_enable(&board.rf_distr, ERTM15_RF_LO, i, st_lo );
	        ertm15_rf_distr_output_enable(&board.rf_distr, ERTM15_RF_REF, i, st_ref );
        }
        else
        {
            if (mask->lo.out_state[i] &&
                (cfg->lo.out_state[i] != ertm14_current_state->lo.out_state[i]))
                    ertm15_rf_distr_output_enable(&board.rf_distr, ERTM15_RF_LO, i, st_lo );
            if (mask->ref.out_state[i] &&
                (cfg->ref.out_state[i] != ertm14_current_state->ref.out_state[i]))
                    ertm15_rf_distr_output_enable(&board.rf_distr, ERTM15_RF_REF, i, st_ref );
    }
}

    if( mask->streamers_latency_cycles )
        streamers_set_rx_latency( cfg->streamers_latency_cycles );
    if( mask->streamers_timeout_cycles )
        streamers_set_rx_timeout( cfg->streamers_timeout_cycles );

    ertm15_update_rf_switches( &board.rf_distr );
}

static void commit_board_config(struct ertm14_board_state *mask)
{
    copy_config(&ertm14_mask, mask);
    board_state_to_no(&ertm14_mask, 0);
    ertm14_apply_config(&ertm14_next_state, &ertm14_mask, 0);
    update_config(ertm14_current_state, &ertm14_next_state, &ertm14_mask);
    clean_config(&ertm14_next_state);
    clean_config(&ertm14_mask);
}

static void set_board_config(struct ertm14_board_state *bs)
{
    /* FIXME: this is far from reentrant */
    copy_config(&ertm14_next_state, bs);
    board_state_to_no(&ertm14_next_state, 0);
}

void get_version_info(struct ertm14_version_info *bi)
    {
	memcpy(&bi->ertm14_serial, &ertm14_board_info.board_serial_number,
			     sizeof(ertm14_board_info.board_serial_number));
	memcpy(&bi->ertm15_serial, &ertm15_board_info.board_serial_number,
			     sizeof(ertm15_board_info.board_serial_number));
	/* FIXME: no mac2? */
	copy_eth_addr(bi->ertm14_mac1_bytes, wrc_endpoint_dev.mac_addr);
	/* FIXME: wrpc_sw_version makes no sense here */
	strncpy(bi->wrpc_sw_commit_id, build_id.commit_id, sizeof(bi->wrpc_sw_commit_id));
	strncpy(bi->wrpc_sw_build_date, build_id.build_date, sizeof(bi->wrpc_sw_build_date));
	strncpy(bi->wrpc_sw_build_time, build_id.build_time, sizeof(bi->wrpc_sw_build_time));
	strncpy(bi->wrpc_sw_build_by, build_id.build_by, sizeof(bi->wrpc_sw_build_by));

	strncpy(bi->ertm14_firmware_version, ertm14_board_info.git_tag,
				    sizeof(bi->ertm14_firmware_version));
	strncpy(bi->ertm15_firmware_version, ertm15_board_info.git_tag,
				    sizeof(bi->ertm15_firmware_version));


    uint32_t cd;
    if( storage_get_calibration_parameter( CAL_PARAM_CALIBRATION_DATE, &cd ) < 0 )
        cd = 0;

    bi->calibration_date = cd;
    }

void get_fpga_info(uint8_t *bi)
{
	int i;
	uint32_t *info = (uint32_t *)bi;
	uint32_t *regs = (uint32_t *)(BASE_ERTM14_BUILD_INFO);
	size_t size = sizeof(((struct ertm14_device_metadata *)0)->fpga_buildinfo_text);
	int len = size / sizeof(info[0]);

	for (i = 0; i < len; i++)
		info[i] = htonl(regs[i]);
}

static void get_wrc_diags(struct wrc_diags *diags)
{
	uint32_t *word = (void *)diags;
	int i;
	int n = sizeof(*diags)/sizeof(uint32_t);

	memcpy(diags, &wrc_diags_nonhw, sizeof(struct wrc_diags ));

	for (i = 0; i < n; i++)
		word[i] = htonl(word[i]);
}

static int spll_dbg_enabled = 0;

static void configure_spll_debug_dump( int enabled, int undersample )
{
    spll_dbg_enabled = enabled;
    if( enabled )
    {
        spll_debug_queue_configure( undersample, 32 ); // fixme: make coalescence threshold configurable? is it worth it?
    }
}

static void ertm14_spll_debug_dump_task_init(void)
{
    spll_dbg_enabled = 0;
}

static int ertm14_spll_debug_dump_task_poll(void)
{
    struct uart_packet tx_pkt;
    struct ertm14_spll_debug_dump_data *tx_payload = (struct ertm14_spll_debug_dump_data *) &tx_pkt.payload;
    int count = 64; //sizeof( *tx_payload ) / sizeof( uint32_t ) - 2;

    if( !spll_dbg_enabled )
        return 0;

    int r = spll_get_debug_queue_samples( tx_payload->payload, &count );

    if( count <= 0 )
        return 0;

    tx_payload->flags = ERTM14_SPLL_DEBUG_DUMP_HEADER;

    tx_pkt.ptype = ERTM14_UART_PTYPE_SOFTPLL_LOG;
    tx_pkt.length = sizeof( uint32_t ) * count + 4;

    if( r == -ENOSPC )
        tx_payload->flags |= ERTM14_SPLL_DEBUG_DUMP_OVERFLOW;

    tx_payload->flags = host_to_be32( tx_payload->flags );
    for( int i = 0; i < count; i ++ )
        tx_payload->payload[i] = host_to_be32( tx_payload->payload[i] );

    uart_link_send( &board.control_uart_link, &tx_pkt );

    return 0;
}


static void get_streamers_diags(struct WR_STREAMERS_WB *diags)
{
        memset( diags, 0, sizeof( struct WR_STREAMERS_WB ) );

        streamers_writel( WR_STREAMERS_SSCR1_SNAPSHOT_STATS, offsetof( struct WR_STREAMERS_WB, SSCR1 ) );

    diags->VER = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, VER ) ) );
    diags->SSCR1 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, SSCR1 ) ) );
    diags->SSCR2 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, SSCR2 ) ) );
    diags->SSCR3 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, SSCR3 ) ) );
    diags->RX_STAT0 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT0 ) ) );
    diags->RX_STAT1 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT1 ) ) );
    diags->TX_STAT2 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_STAT2 ) ) );
    diags->TX_STAT3 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_STAT3 ) ) );
    diags->RX_STAT4 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT4 ) ) );
    diags->RX_STAT5 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT5 ) ) );
    diags->RX_STAT6 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT6 ) ) );
    diags->RX_STAT7 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT7 ) ) );
    diags->RX_STAT8 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT8 ) ) );
    diags->RX_STAT9 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT9 ) ) );
    diags->RX_STAT10 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT10 ) ) );
    diags->RX_STAT11 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT11 ) ) );
    diags->RX_STAT12 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT12 ) ) );
    diags->RX_STAT13 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT13 ) ) );
    diags->RX_STAT15 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT15 ) ) );
    diags->RX_STAT16 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT16 ) ) );
    diags->RX_STAT17 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT17 ) ) );
    diags->RX_STAT18 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT18 ) ) );
    diags->RX_STAT19 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT19 ) ) );
    diags->RX_STAT20 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_STAT20 ) ) );

    diags->TX_CFG0 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_CFG0 ) ) );
    diags->TX_CFG1 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_CFG1 ) ) );
    diags->TX_CFG2 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_CFG2 ) ) );
    diags->TX_CFG3 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_CFG3 ) ) );
    diags->TX_CFG4 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_CFG4 ) ) );
    diags->TX_CFG5 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, TX_CFG5 ) ) );

    diags->RX_CFG0 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG0 ) ) );
    diags->RX_CFG1 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG1 ) ) );
    diags->RX_CFG2 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG2 ) ) );
    diags->RX_CFG3 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG3 ) ) );
    diags->RX_CFG4 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG4 ) ) );
    diags->RX_CFG5 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG5 ) ) );
    diags->RX_CFG6 = htonl( streamers_readl( offsetof( struct WR_STREAMERS_WB, RX_CFG6 ) ) );

    streamers_writel( 0, offsetof( struct WR_STREAMERS_WB, SSCR1 ) );
}


static void get_wrc_sensors(struct wrc_sensor *dst)
{
	int nsensors = sizeof(ertm_sensors)/sizeof(ertm_sensors[0]);
    int i;

	memcpy(dst, ertm_sensors, sizeof(ertm_sensors));
	for (i = 0; i < nsensors; i++)
		dst[i].value = htons(dst[i].value);
}

static void refresh_wrc_nco(struct ertm14_nco_reset *nco, int connector)
{
	struct ertm14_dds_state *dds = ((connector == ERTM14_DDS_SYNC_LO) ?
		&ertm14_current_state->lo : &ertm14_current_state->ref);

	nco->reset_count = dds->sync_count;
	nco->subscribed = dds->sync_source;
	diag_read_word(8, DIAG_RO_BANK, &nco->rx_count);
	nco->enabled = (nco->subscribed != ERTM14_SYNC_SOURCE_NONE);
	nco->current_stream_id = 0;	/* unused */
}

static void nco_to_network(struct ertm14_nco_reset *nco)
    {
	nco->enabled		= htonl(nco->enabled);
	nco->sync_source	= htonl(nco->sync_source);
	nco->current_stream_id	= htonl(nco->current_stream_id);
	nco->rx_count		= htonl(nco->rx_count);
	nco->reset_count	= htonl(nco->reset_count);
	nco->connector		= htonl(nco->connector);
};

static void nco_to_host_order(struct ertm14_nco_reset *nco)
        {
	nco->enabled		= ntohl(nco->enabled);
	nco->sync_source	= ntohl(nco->sync_source);
	nco->current_stream_id	= ntohl(nco->current_stream_id);
	nco->rx_count		= ntohl(nco->rx_count);
	nco->reset_count	= ntohl(nco->reset_count);
	nco->connector		= ntohl(nco->connector);
};

static void get_wrc_nco(struct ertm14_nco_reset *nco)
{
	refresh_wrc_nco(&ertm14_nco_stats[0], ERTM14_DDS_SYNC_LO);
	refresh_wrc_nco(&ertm14_nco_stats[1], ERTM14_DDS_SYNC_REF);
	memcpy(nco, &ertm14_nco_stats, sizeof(ertm14_nco_stats));
	nco_to_network(&nco[0]);
	nco_to_network(&nco[1]);
        }

static void subscribe_nco(struct ertm14_nco_reset *nco)
{
	struct ertm14_dds_state *dds;

	nco_to_host_order(nco);

	switch (nco->connector) {
	case ERTM14_DDS_SYNC_LO:
		dds = &ertm14_current_state->lo;
		event_post(WRC_ERTM14_EVENT_LO_RECONFIGURED);
		break;
	case ERTM14_DDS_SYNC_REF:
		dds = &ertm14_current_state->ref;
		event_post(WRC_ERTM14_EVENT_REF_RECONFIGURED);
		break;
	default:
		return;		/* should never happen! */
		break;
    }

	dds->sync_source = nco->sync_source;
}

static int ertm_process_psnmp(struct uart_packet *rx_pkt, struct uart_packet *tx_pkt)
{
	struct ertm14_board_state *bs;
	struct wrc_diags *diags;
        struct WR_STREAMERS_WB *streamer_diags;
	struct ertm14_nco_reset *nco;
	struct wrc_sensor *sensors;
	uint8_t opcode = rx_pkt->payload[0];
	struct ertm14_protocol_op *op;
	struct ertm14_version_info *ver;
	uint8_t *fver, mode;

	/* return board config in case of bad opcode */
	if ((op = get_proto_op(opcode)) == NULL)
		op = get_proto_op(ertm14_get_board_config);

	tx_pkt->ptype = ERTM14_UART_PTYPE_SNMP_RESP;
	tx_pkt->length = op->offset2 + op->length2;

	switch (opcode) {
	case ertm14_get_board_config:
		/* return full board configuration */
		bs = (struct ertm14_board_state *)&tx_pkt->payload[op->offset2];
		get_board_config(bs);
		break;

	case ertm14_set_board_config:
		bs = (struct ertm14_board_state *)&rx_pkt->payload[op->offset1];
		set_board_config(bs);
		tx_pkt->payload[0] = ertm14_set_board_config;
		break;

	case ertm14_commit_board_config:
		bs = (struct ertm14_board_state *)&rx_pkt->payload[op->offset1];
		commit_board_config(bs);
		tx_pkt->payload[0] = ertm14_commit_board_config;
		break;

	case ertm14_get_sim_board_config:
		/* return full board configuration */
		bs = (struct ertm14_board_state *)&tx_pkt->payload[op->offset2];
		get_sim_board_config(bs);
		break;
	case ertm14_get_wrc_diags:
		diags = (struct wrc_diags *)&tx_pkt->payload[0];
		get_wrc_diags(diags);
		break;
        case ertm14_get_streamers_diags:
		streamer_diags = (struct WR_STREAMERS_WB *)&tx_pkt->payload[0];
		get_streamers_diags(streamer_diags);
		break;
        case ertm14_reset_streamers_stats:
                streamers_reset_rx_stats();
                break;
        case ertm14_force_measure_channels_power:
                ertm15_force_rf_power_measurement();
                break;
        case ertm14_configure_spll_debug_dump:
        {
                struct ertm14_spll_debug_dump_request *dbgs = (struct ertm14_spll_debug_dump_request *)&rx_pkt->payload[op->offset1];
                dbgs->enabled = ntohl( dbgs->enabled ); // fixme: this sucks
                dbgs->undersample = ntohl( dbgs->undersample );
                configure_spll_debug_dump( dbgs->enabled, dbgs->undersample );
                break;
        }
	case ertm14_get_wrc_nco:
		nco = (struct ertm14_nco_reset *)&tx_pkt->payload[op->offset2];
		get_wrc_nco(nco);
		break;
	case ertm14_subscribe_nco:
		nco = (struct ertm14_nco_reset *)&rx_pkt->payload[op->offset1];
		subscribe_nco(nco);
		break;
	case ertm14_get_version_info:
		ver = (struct ertm14_version_info *)&tx_pkt->payload[op->offset2];
		get_version_info(ver);
		break;
	case ertm14_get_fpga_info:
		fver = (uint8_t *)&tx_pkt->payload[op->offset2];
		get_fpga_info(fver);
		break;
	case ertm14_get_sensors:
		sensors = (struct wrc_sensor *)&tx_pkt->payload[op->offset2];
		get_wrc_sensors(sensors);
		break;
	case ertm14_ptp_enable:
		mode = rx_pkt->payload[op->offset1];
		if (mode == WRC_MODE_MASTER || mode == WRC_MODE_SLAVE) {
			wrc_ptp_set_mode(mode);
			wrc_ptp_stop();
			wrc_ptp_start();
		} else if (mode == WRC_MODE_UNKNOWN)
			wrc_ptp_stop();
		break;
        case ertm14_exec_shell_command:
                {
                        struct ertm14_shell_command *cmd = (struct ertm14_shell_command *)&rx_pkt->payload[op->offset1];
                        shell_exec(cmd->cmd);
                        break;
                }
    case 0x5a:
		tx_pkt->length = rx_pkt->length;
		tx_pkt->length = 1;	/* no time to reply */
		memcpy(tx_pkt->payload, rx_pkt->payload, rx_pkt->length);
		tx_pkt->payload[0] = 0x5a; /* no time to reply */
		break;

	default:
		/* default op: get configuration */
		break;
	}
	return 0;
}

static int evth_dds_nco_sync;

static void ertm14_dds_nco_sync_init(void)
{
    ertm14_current_state->ref.sync_state = ERTM14_CLK_SYNC_STATE_RESTART;
    ertm14_current_state->lo.sync_state = ERTM14_CLK_SYNC_STATE_RESTART;
    ertm14_current_state->ref.sync_count = 0;
    ertm14_current_state->lo.sync_count = 0;
}

static void rf_nco_sync_disable_channel( struct ertm14_dds_state *state, uint32_t ioupdate_channel )
{
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ioupdate_channel, 0, board.dds_sync_delays[ioupdate_channel], 0, 0  );
    state->sync_count = 0;
}

static void rf_nco_sync_configure_channel( struct ertm14_dds_state *state, uint32_t ioupdate_channel )
{
    int flags = 0;

    if( state->sync_source == ERTM14_SYNC_SOURCE_RF_TRIGGER)
        flags |= FINE_PULSE_GEN_USE_EXT_TRIGGER;

    //pp_printf("ConfigChannel ch %x flags %x dly %d src %d\n",ioupdate_channel,flags, board.dds_sync_delays[ioupdate_channel], state->sync_source );
    fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ioupdate_channel, 1, board.dds_sync_delays[ioupdate_channel], 0, flags  );
    state->sync_count = 0;
}

static void rf_nco_sync_arm_channel( struct ertm14_dds_state *state, uint32_t ioupdate_channel )
{
    if( state->sync_source == ERTM14_SYNC_SOURCE_NONE)
        return;

    fine_pulse_gen_trigger ( &board.dds_sync_dev, (1 << ioupdate_channel), 0 );
}


static int rf_nco_sync_wait_trigger( struct ertm14_dds_state *state, uint32_t ioupdate_channel )
{
    // no sync? consider the channel always triggered
    if( state->sync_source == ERTM14_SYNC_SOURCE_NONE)
        return 1;

    if( fine_pulse_gen_is_triggered ( &board.dds_sync_dev, 1 << ioupdate_channel ) )
    {
        state->sync_count++;
        return 1;
    }

    return 0;
}


static int rf_nco_sync_fsm( int is_ref, struct ertm14_dds_state *state, uint32_t ioupdate_channel, int event )
{
    const char *name = is_ref ? "ref" : "lo";

    /* fixme: ugly ifs */
    if( is_ref && event == WRC_ERTM14_EVENT_REF_RECONFIGURED)
    {
        board_dbg("nco_sync[%s]: reconfiguration request\n", name );
        state->sync_state = ERTM14_CLK_SYNC_STATE_RESTART;
        state->sync_count = 0;
    }

    if( !is_ref && event == WRC_ERTM14_EVENT_LO_RECONFIGURED)
    {
        board_dbg("nco_sync[%s]: reconfiguration request\n", name );
        state->sync_state = ERTM14_CLK_SYNC_STATE_RESTART;
        state->sync_count = 0;
    }
    
    if ( event == WRC_EVENT_LINK_DOWN || event == WRC_EVENT_TIMING_DOWN )
    {
        board_dbg("nco_sync[%s]: WR link or timing down, restarting FSM\n", name );
        state->sync_state = ERTM14_CLK_SYNC_STATE_RESTART;
        state->sync_count = 0;
    }

    switch( state->sync_state )
    {
        case ERTM14_CLK_SYNC_STATE_RESTART:
            rf_nco_sync_disable_channel( state, ioupdate_channel );

            if(state->sync_source == ERTM14_SYNC_SOURCE_NONE)
            {
                board_dbg("nco_sync[%s]: disabling DDS sync\n", name );
                state->sync_state = ERTM14_CLK_SYNC_STATE_READY;
            }
            else
            {
                board_dbg("nco_sync[%s]: restarting sync FSM\n", name );
                state->sync_state = ERTM14_CLK_SYNC_STATE_WAIT_TIMING;
            }
            break;

        case ERTM14_CLK_SYNC_STATE_WAIT_TIMING:
            if( wrc_is_timing_up() )
            {
                board_dbg("nco_sync[%s]: timing up\n", name);
                state->sync_state = ERTM14_CLK_SYNC_STATE_CONFIGURE;
                streamers_reset_rx_stats();
            }
            break;

        case ERTM14_CLK_SYNC_STATE_CONFIGURE:
            if( !wrc_is_timing_up() )
            {
                state->sync_state = ERTM14_CLK_SYNC_STATE_WAIT_TIMING;
            }
            else
            {
                rf_nco_sync_configure_channel( state, ioupdate_channel );
                rf_nco_sync_arm_channel( state, ioupdate_channel );

                // DEBUG below
                ertm14_set_pps_out_mode( 3 ); // observe RF reset NCO triggers on PPS out
                state->sync_state = ERTM14_CLK_SYNC_STATE_WAIT_TRIGGER;
            }
            break;

        case ERTM14_CLK_SYNC_STATE_WAIT_TRIGGER:
        {
            int trigd = rf_nco_sync_wait_trigger(state, ioupdate_channel);

            if( trigd )
            {
                led_action( is_ref ? &board.leds.ref : &board.leds.lo, LED_COLOR_1, LED_BLINK_SINGLE_NEGATIVE );
                led_action( is_ref ? &board.leds.ref : &board.leds.lo, LED_COLOR_2, LED_OFF );
                board_dbg("nco_sync[%s]: triggered!\n", name);
                rf_nco_sync_arm_channel( state, ioupdate_channel );
                state->sync_state = ERTM14_CLK_SYNC_STATE_READY;
            }

            break;
        }

        /* does the same as above, albeit in a neverending loop (sync_state is exported
           through the library and READY indicates at least one trigger has been received) */
        case ERTM14_CLK_SYNC_STATE_READY:
            {
            int trigd = rf_nco_sync_wait_trigger(state, ioupdate_channel);

            if( trigd )
            {
                led_action( is_ref ? &board.leds.ref : &board.leds.lo, LED_COLOR_1, LED_BLINK_SINGLE_NEGATIVE );
                led_action( is_ref ? &board.leds.ref : &board.leds.lo, LED_COLOR_2, LED_OFF );
                rf_nco_sync_arm_channel( state, ioupdate_channel );
                state->sync_state = ERTM14_CLK_SYNC_STATE_READY;
            }

            break;
        }

        default:
            break;
    }

    return 0;
}

static int ertm14_dds_nco_sync_task(void)
{
    int evt = event_poll( evth_dds_nco_sync );

    rf_nco_sync_fsm( 1, &ertm14_current_state->ref, ERTM14_DDS_IOUPDATE_REF, evt );
    rf_nco_sync_fsm( 0, &ertm14_current_state->lo, ERTM14_DDS_IOUPDATE_LO, evt );

    return 0;
}

static int evth_clkab_sync;

#define CLKAB_SYNC_STATE_IDLE 0
#define CLKAB_SYNC_STATE_WAIT_AFTER_PPS 1
#define CLKAB_SYNC_STATE_WAIT_TRIGGER 2

static int clkab_sync_state;

static void ertm14_clkab_sync_init(void)
{
    clkab_sync_state = CLKAB_SYNC_STATE_IDLE;
}

static int ertm14_clkab_sync_task(void)
{
    int evt = event_poll( evth_clkab_sync );
    ( void ) evt;
    uint8_t *stateA = ertm14_current_state->clka_sync_state;
    uint8_t *stateB = ertm14_current_state->clkb_sync_state;
    
// OK, I'm commenting this one out at the request of the RF guys - we have reduced the choice of
// CLKAB frequencies to the integer multiplies of 62.5 MHz, so that no matter how many times the WR link
// is established, once synced during startup, CLKA/B edges will be always synchronous to the WR PPS.

// This prevents the 2ms-long squelch of the CLKA/B outputs (imposed by the LTC6953 chip), which causes
// the SIS83k boards clocked using the eRTM to reset due to loss of clock.

/*
    if( evt == WRC_EVENT_TIMING_UP )
    {
        int i;
        board_dbg("[clkab_sync] WR timing up, forcing resync of all CLKAB clocks.\n");

        for( i = ERTM14_CLKAB_OUT_MIN_ID; i <= ERTM14_CLKAB_OUT_MAX_ID; i++ )
        {
            stateA[i] = ERTM14_CLK_SYNC_STATE_RESTART;
            stateB[i] = ERTM14_CLK_SYNC_STATE_RESTART;
    }
    }
*/
    uint64_t secs;
    uint32_t nsecs;

    shw_pps_gen_unmask_output(1);
    shw_pps_gen_get_time( &secs, &nsecs );

    switch(clkab_sync_state)
    {
        case CLKAB_SYNC_STATE_IDLE:
            clkab_sync_state = CLKAB_SYNC_STATE_WAIT_AFTER_PPS;
            break;
        case CLKAB_SYNC_STATE_WAIT_AFTER_PPS:
            /* we wait here until we are rather closer to the previous PPS pulse than the next one.
               the reason is, subsequent writes to LTC695x take some milliseconds and must be done
               before the next sync pulse is produced by the fine_pulse_gen */
            if( nsecs < 300000000 )
            {
                int i;
                int any_output_pending = 0;
                for( i = ERTM14_CLKAB_OUT_MIN_ID; i <= ERTM14_CLKAB_OUT_MAX_ID; i++ )
                {
                    /* check which CLKA/B outputs have changed their configuration and
                    set the SREQN bit in the LTC6953. Next time a PPS pulse arrives to the EZS_SRQ
                    input of the corresponding clock fanout chip, the clock phases of the outputs
                    will be aligned with the WR PPS. Note: it's *EXTREMELY IMPORTANT* to only
                    assert SREQN (clkab_enable_sync) on the outputs that have had their configurations
                    changed, as sthe sync procedure causes an intermittent squelch of the clock output
                    being synced */
                    if( stateA[i] == ERTM14_CLK_SYNC_STATE_RESTART )
                    {
                        board_dbg("[clkab_sync] CLKA%d pending\n", i);
                        led_action( &board.leds.clka, LED_COLOR_1, LED_ON );
                        led_action( &board.leds.clka, LED_COLOR_2, LED_ON );
                        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKA, i, 1 );
                        stateA[i] = ERTM14_CLK_SYNC_STATE_WAIT_TRIGGER;
                        any_output_pending = 1;
                    }

                    if( stateB[i] == ERTM14_CLK_SYNC_STATE_RESTART )
                    {
                        board_dbg("[clkab_sync] CLKB%d pending\n", i);
                        led_action( &board.leds.clkb, LED_COLOR_1, LED_ON );
                        led_action( &board.leds.clkb, LED_COLOR_2, LED_ON );
                        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKB, i, 1 );
                        stateB[i] = ERTM14_CLK_SYNC_STATE_WAIT_TRIGGER;
                        any_output_pending = 1;
                    }
                }

                if( any_output_pending )
                {
                    fine_pulse_gen_trigger( &board.dds_sync_dev, (1<<ERTM14_PLL_SYNC_CLKA) | ( 1<<ERTM14_PLL_SYNC_CLKB), 0 );
                    clkab_sync_state = CLKAB_SYNC_STATE_WAIT_TRIGGER;
                }

            }
            break;
        case CLKAB_SYNC_STATE_WAIT_TRIGGER:

            if( fine_pulse_gen_is_triggered( &board.dds_sync_dev, (1<<ERTM14_PLL_SYNC_CLKA) | ( 1<<ERTM14_PLL_SYNC_CLKB) ))
            {
                /* the EZS_SRQ pulse is slightly longer than 100 us for correct operation
                if the LTC6953 sync circuitry, but the FPGen reports 'triggered' at the beginning of the pulse.
                Add a small, 1ms delay before we start messing around with the SREQN bits again. */
                timer_delay_ms(1);

                clkab_sync_state = CLKAB_SYNC_STATE_WAIT_AFTER_PPS;
                int i;
                for( i = ERTM14_CLKAB_OUT_MIN_ID; i <= ERTM14_CLKAB_OUT_MAX_ID; i++ )
                {
                    /* FPGen has produced a sync pulse */
                    if( stateA[i] == ERTM14_CLK_SYNC_STATE_WAIT_TRIGGER )
                    {
                        board_dbg("[clkab_sync] CLKA%d synced!\n", i);
                        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKA, i, 0 );
                        stateA[i] = ERTM14_CLK_SYNC_STATE_READY;
                        led_action( &board.leds.clka, LED_COLOR_1, LED_ON );
                        led_action( &board.leds.clka, LED_COLOR_2, LED_OFF );
                    }

                    if( stateB[i] == ERTM14_CLK_SYNC_STATE_WAIT_TRIGGER )
                    {
                        board_dbg("[clkab_sync] CLKB%d synced!\n", i);
                        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKB, i, 0 );
                        stateB[i] = ERTM14_CLK_SYNC_STATE_READY;
                        led_action( &board.leds.clkb, LED_COLOR_1, LED_ON );
                        led_action( &board.leds.clkb, LED_COLOR_2, LED_OFF );
                    }
                }
            }
            break;
    }

    return 0;
}

static void blink_led( struct gpio_pin *pin )
    {
    gen_gpio_out( pin, 1 );
    timer_delay_ms(150);
    gen_gpio_out( pin, 0 );
    }

static void ertm14_init_leds(void)
{
    blink_led(&pin_led_sync_green);
    blink_led(&pin_led_sync_red);
    
    led_create( &board.leds.sync, &pin_led_sync_green, &pin_led_sync_red, LED_TYPE_DUAL_COLOR, LED_OFF );
    led_set_blink_timing( &board.leds.sync, 1000, 500 );
    led_set_blink_timing( &board.leds.lo, 50, 50 );
    led_set_blink_timing( &board.leds.ref, 50, 50 );

    led_action( &board.leds.sync, LED_COLOR_1, LED_BLINK );
}


static void ertm15_init_leds(void)
{
    blink_led(&pin_ertm15_led_ref_green);
    blink_led(&pin_ertm15_led_lo_green);
    blink_led(&pin_ertm15_led_clkb_green);
    blink_led(&pin_ertm15_led_clka_green);
    blink_led(&pin_ertm15_led_ref_red);
    blink_led(&pin_ertm15_led_lo_red);
    blink_led(&pin_ertm15_led_clkb_red);
    blink_led(&pin_ertm15_led_clka_red);


    led_create( &board.leds.clka, &pin_ertm15_led_clka_green, &pin_ertm15_led_clka_red, LED_TYPE_DUAL_COLOR, LED_OFF );
    led_create( &board.leds.clkb, &pin_ertm15_led_clkb_green, &pin_ertm15_led_clkb_red, LED_TYPE_DUAL_COLOR, LED_OFF );
    led_create( &board.leds.lo, &pin_ertm15_led_lo_green, &pin_ertm15_led_lo_red, LED_TYPE_DUAL_COLOR, LED_OFF );
    led_create( &board.leds.ref, &pin_ertm15_led_ref_green, &pin_ertm15_led_ref_red, LED_TYPE_DUAL_COLOR, LED_OFF );
}

// initializes the eRTM15 LTC6950 PLL & OCXO
int ertm15_pll_init(void)
{
    ltc695x_init(&board.ltc6950_pll, &board.spi_ltc6950);

    int id = ltc695x_read(&board.ltc6950_pll, 0x16);

    if (id != LTC6950_ID_VALUE)
    {
        board_dbg("Error initializing LTC6950 (read RevID: 0x%x, expected: 0x%x)\n", id, LTC6950_ID_VALUE);
        return -1;
    }

    bist_checkpoint( ertm_bist, ERTM14_BIST_LTC6950, 0, id == LTC6950_ID_VALUE);

    // load default 'bootstrap' config and check what is the OCXO frequency
    ltc695x_configure(&board.ltc6950_pll, &pll_ertm15_bootstrap_config);

        board_dbg("Using 100 MHz OCXO\n");
    ltc695x_write(&board.ltc6950_pll, 0x8, 0x1); // reference divider = 1
    ltc695x_write(&board.ltc6950_pll, 0x15, 50); // RDIVOUT = 0, output div = 50
    ltc695x_write(&board.ltc6950_pll, 0x0a, 10); // N divider = 10 (VCO @ 1GHz, PFD @ 100 MHz)

    int locked = 0;

    timeout_t lock_timeout;
    tmo_init( &lock_timeout, 1000 );

    // wait for the PLL to lock
    do {
        if( tmo_expired( &lock_timeout) )
            break;

        locked = ltc695x_read(&board.ltc6950_pll, 0) & LTC695x_R0_LOCK;

        timer_delay_ms(10);
    } while( !locked );

    bist_checkpoint( ertm_bist, ERTM14_BIST_PLL_LOCK, 0, locked );

    if( !locked )
        return -1;

    // now that we are locked, we can sync the outputs so that all coutners start at the same time
    gen_gpio_out( &pin_ltc6950_sync, 0 );
    ltc6950_set_syncen( &board.ltc6950_pll, 0x1f );

    gen_gpio_out( &pin_ltc6950_sync, 1 );
    timer_delay_ms(10);
    gen_gpio_out( &pin_ltc6950_sync, 0 );

    ltc6950_set_syncen( &board.ltc6950_pll, 0x0 );

        board.mode |= ERTM14_MODE_OCXO_100MHZ;
    return 0;
    }
 
static const struct clkab_output_map_entry *clkab_find_map_entry(  int clka_or_clkb, int output )
{
    const struct clkab_output_map_entry *omap = (clka_or_clkb == ERTM14_OUT_CLKA) ? clka_out_map : clkb_out_map;
    int i;
    for( i = 0; omap[i].id_backplane >= 0; i++ )
    {
        if( omap[i].id_backplane  == output )
            return &omap[i];
}

    return NULL;
}

static int clkab_set_output_divider( struct ertm14_board_state *state, int clka_or_clkb, int output, int divider )
{
    const struct clkab_output_map_entry *o = clkab_find_map_entry( clka_or_clkb, output );
    struct ltc695x_device* dev = (clka_or_clkb == ERTM14_OUT_CLKA) ? &board.dev_clka_distr : &board.dev_clkb_distr;

    if(!o)
        return -EINVAL;



    ltc6953_configure_output( dev, o->id_ltc6953, divider, o->invert );

    if(clka_or_clkb == ERTM14_OUT_CLKA)
        state->clka_sync_state[output] = ERTM14_CLK_SYNC_STATE_RESTART;
    else
        state->clkb_sync_state[output] = ERTM14_CLK_SYNC_STATE_RESTART;

    return 0;
}


static int clkab_enable_output( struct ertm14_board_state *state, int clka_or_clkb, int output, int enable )
{
    const struct clkab_output_map_entry *o = clkab_find_map_entry( clka_or_clkb, output );
    struct ltc695x_device* dev = (clka_or_clkb == ERTM14_OUT_CLKA) ? &board.dev_clka_distr : &board.dev_clkb_distr;

    if(!o)
        return -EINVAL;

    ltc6953_enable_output( dev, o->id_ltc6953, enable );

    return 0;
}


static int clkab_enable_sync( struct ertm14_board_state *state, int clka_or_clkb, int output, int enable )
{
    const struct clkab_output_map_entry *o = clkab_find_map_entry( clka_or_clkb, output );
    struct ltc695x_device* dev = (clka_or_clkb == ERTM14_OUT_CLKA) ? &board.dev_clka_distr : &board.dev_clkb_distr;

    if(!o)
        return -EINVAL;

    ltc6953_set_srqen( dev, o->id_ltc6953, enable );

    return 0;
}


int ertm14_init_clkab_distribution(void)
{
    /* initialize the SPI bus for the CLKA fanout (LTC6953) */
    bb_spi_create( &board.spi_ltc6953_clka,
        &pin_ertm15_clka_cs_n,
        &pin_ertm15_clkab_mosi,
        &pin_ertm15_clkab_miso,
        &pin_ertm15_clkab_sck,
        1000 );

    ltc695x_init(&board.dev_clka_distr, &board.spi_ltc6953_clka);

    /* initialize the SPI bus for the CLKA fanout (LTC6953) */
    bb_spi_create( &board.spi_ltc6953_clkb,
        &pin_ertm15_clkb_cs_n,
        &pin_ertm15_clkab_mosi,
        &pin_ertm15_clkab_miso,
        &pin_ertm15_clkab_sck,
        1000 );

    ltc695x_init(&board.dev_clkb_distr, &board.spi_ltc6953_clkb);

#define LTC6953_EXPECTED_ID 0x23

    int id_a, id_b;
    id_a = ltc695x_read(&board.dev_clka_distr, 0x38);
    id_b = ltc695x_read(&board.dev_clkb_distr, 0x38);

    int result_a = ltc695x_configure( &board.dev_clka_distr, &clkab_ertm15_bootstrap_config );
    int result_b = ltc695x_configure( &board.dev_clkb_distr, &clkab_ertm15_bootstrap_config );

    bist_checkpoint( ertm_bist, ERTM14_BIST_CLKA, 0, (id_a == LTC6953_EXPECTED_ID) && !result_a );
    bist_checkpoint( ertm_bist, ERTM14_BIST_CLKB, 0, (id_b == LTC6953_EXPECTED_ID) && !result_b );

    if( id_a != LTC6953_EXPECTED_ID || id_b != LTC6953_EXPECTED_ID )
        return -ENODEV;


// set 250 MHz output on CLKA/CLKB on the front panel
    clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKA, ERTM14_CLKAB_OUT_FRONT_PANEL, 4 ); // divide by 4 -> 250 MHz
    clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKB, ERTM14_CLKAB_OUT_FRONT_PANEL, 4 );

    clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKA, ERTM14_CLKAB_OUT_FRONT_PANEL, 1 );
    clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKB, ERTM14_CLKAB_OUT_FRONT_PANEL, 1 );

    return 0;
}

int ertm14_init_ref_clock_distribution(void)
{
    int main_stat = ad951x_init(&board.ad9516_main, &board.spi_pll_main, &pin_pll_main_reset, &pin_pll_main_lock);
    int ext_stat = ad951x_init(&board.ad9516_ext, &board.spi_pll_ext, &pin_pll_ext_reset, &pin_pll_ext_lock);

    bist_checkpoint( ertm_bist, ERTM14_BIST_AD951X_MAIN, 0, main_stat == 0 );
    bist_checkpoint( ertm_bist, ERTM14_BIST_AD951X_EXT, 0, ext_stat == 0 );

    if( main_stat < 0 )
    {
        board_dbg( "Failed to configure the main clock distribution AD9516 (chip not responding)\n ");
        return -1;
    }

    if( ext_stat < 0 )
    {
        board_dbg( "Failed to configure the external 10 MHz clock multiplier AD9516 (chip not responding)\n ");
        return -1;
    }

    if (board.mode & ERTM14_MODE_WITHOUT_ERTM15)
    {
        gen_gpio_out(&pin_main_xo_en_n, 0); // enable DOT050 VCXO
        ad951x_configure(&board.ad9516_main, &pll_main_dot050_config);
    }
    else
    {
        gen_gpio_out(&pin_main_xo_en_n, 1); // disable DOT050 VCXO
        ad951x_configure(&board.ad9516_main, &pll_main_ocxo_config);
        // ad951x_configure(&board.ad9516_ext, &pll_ext_10mhz_config);
    }

    gen_gpio_out( &pin_pll_ext_reset, 0 );

    return 0;
}

int ertm15_init_dds(void)
{
// reset both DDS chips
    gen_gpio_out(&pin_ad9910_ref_reset, 1);
    gen_gpio_out(&pin_ad9910_lo_reset, 1);

    usleep(10);

    gen_gpio_out(&pin_ad9910_ref_reset, 0);
    gen_gpio_out(&pin_ad9910_lo_reset, 0);

// initialize DDS synchronizer unit
    ertm14_dds_sync_init();

    int probe_ref = ad9910_probe( &board.dds_ad9910_ref, &board.spi_ad9910_ref, ertm14_dds_trigger_ioupdate );
    int probe_lo = ad9910_probe( &board.dds_ad9910_lo, &board.spi_ad9910_lo, ertm14_dds_trigger_ioupdate );

    bist_checkpoint( ertm_bist, ERTM14_BIST_DDS_LO, 0, probe_lo == 0 );
    bist_checkpoint( ertm_bist, ERTM14_BIST_DDS_REF, 0, probe_ref == 0 );
    return 0;
}

int ertm14_init_mac_eeprom(void)
{
    bb_i2c_create( &board.i2c_mac_addr, &pin_mac_addr_scl, &pin_mac_addr_sda );
    bb_i2c_init( &board.i2c_mac_addr );

    m24aa025_init( &board.m24_mac_ids[0], &board.i2c_mac_addr, 0x50 );
    m24aa025_init( &board.m24_mac_ids[1], &board.i2c_mac_addr, 0x51 );

    /* Read the mac address. */
    uint8_t *mac = ertm14_mac;
    int err = m24aa025_read_mac( &board.m24_mac_ids[0], mac );

    //m24aa025_read_mac( &board.m24_mac_ids[1], mac );

    bist_checkpoint( ertm_bist, ERTM14_BIST_MAC_EEPROM, 0, !err );

    if( err < 0 )
        return err;

    board_dbg("MAC address: Port 0 = %02x:%02x:%02x:%02x:%02x:%02x\n",
        mac[0],mac[1],mac[2],mac[3],mac[4],mac[5] );

    return 0;
}


void ertm14_set_pps_out_mode(int mode)
{
    gen_gpio_out( &pin_pps_out_mode0, (mode & 0x1) ? 1 : 0);
    gen_gpio_out( &pin_pps_out_mode1, (mode & 0x2) ? 1 : 0);
    gen_gpio_out( &pin_pps_out_mode2, (mode & 0x4) ? 1 : 0);
}

int ertm14_low_level_init(void)
{
    ertm_init_complete = 0;

    memset( &board, 0, sizeof( struct ertm14_board ));


    /* eRTM14 can work independently of eRTM15. If CONFIG_ERTM14_WITHOUT_ERTM15 is set,
       the software will assume we don't have an eRTM15 sandwiched even if we do. */
#ifdef CONFIG_ERTM14_WITHOUT_ERTM15
    board.mode |= ERTM14_MODE_WITHOUT_ERTM15;
#endif

    /* apply a default, sane configuration (initialize the config struct) */
    ertm14_config_init();

    /* most of the I/Os of the slow peripherals (i2c, spi) are bitbanged. First, let's
       initialize the GPIO controller they're connected to */
    wb_gpio_create( &board.gpio_aux, BASE_AUXWB );

    /* enable the main VCXO */
    gen_gpio_set_dir(&pin_main_xo_en_n, 1);
    gen_gpio_out(&pin_main_xo_en_n, 0);

    x595_gpio_create ( &board.gpio_ertm15_leds, 1, &pin_ertm15_leds_updtclk, &pin_ertm15_leds_shftclk, NULL, &pin_ertm15_leds_ser);
    leds_init();

    /* initialize the SPI bus for the main PLL (IC?) */
    bb_spi_create ( &board.spi_pll_main,
        &pin_pll_main_cs_n,
        &pin_pll_main_sdi,
        &pin_pll_main_sdo,
        &pin_pll_main_sclk,
        AD951X_BIT_DELAY
        );

    /* initialize the SPI bus for the external clock (10 MHz input) PLL (IC?) */
    bb_spi_create ( &board.spi_pll_ext,
        &pin_pll_ext_cs_n,
        &pin_pll_ext_sdi,
        &pin_pll_ext_sdo,
        &pin_pll_ext_sclk,
        AD951X_BIT_DELAY
        );

    /* initialize the SPI bus for the eRTM15 PLL (IC?) */
    bb_spi_create( &board.spi_ltc6950,
        &pin_ltc6950_ce_gen,
        &pin_ltc6950_sdi,
        &pin_ltc6950_sdo,
        &pin_ltc6950_sclk,
        100 );

    /* initialize the SPI bus for the eRTM15 REF DDS (IC?) */
    bb_spi_create( &board.spi_ad9910_ref,
        NULL,
        &pin_ad9910_ref_sdio,
        &pin_ad9910_ref_sdio,
        &pin_ad9910_ref_sclk,
        100 );

    /* initialize the SPI bus for the eRTM15 LO DDS (IC?) */
    bb_spi_create( &board.spi_ad9910_lo,
        NULL,
        &pin_ad9910_lo_sdio,
        &pin_ad9910_lo_sdio,
        &pin_ad9910_lo_sclk,
        100 );

    mmc_comm_init();

    ertm14_init_leds();
    
    /* detect if the eRTM15 is present and decide how to configure the board */
    int ertm15_present = wait_ertm15_presence();

    if( !ertm15_present )
        board.mode |= ERTM14_MODE_WITHOUT_ERTM15;

    if ( board.mode & ERTM14_MODE_WITHOUT_ERTM15 )
        board_dbg( "Configuring board *WITHOUT* eRTM15 support (eRTM15 not found, not powered on or disabled in software). The WRC will not be functional!\n");
    else
        board_dbg( "Configuring board WITH eRTM15 support.\n");
    
    bist_checkpoint( ertm_bist, ERTM14_BIST_ERTM15_PRESENCE, 0, ertm15_present );

    if( !ertm15_present )
    {
        led_action( &board.leds.sync, LED_COLOR_1, LED_OFF );
        led_action( &board.leds.sync, LED_COLOR_2, LED_BLINK );
        return 0;
    }
    else
    {
        led_action( &board.leds.sync, LED_COLOR_1, LED_OFF );
        led_action( &board.leds.sync, LED_COLOR_2, LED_OFF );
    }

    if( ! (board.mode & ERTM14_MODE_WITHOUT_ERTM15 ) )
    {
        /* Set up the eRTM15's PLL */
        ertm15_pll_init();
    }

    /* Set up the eRTM14's PLLs (AD9516s) */
    ertm14_init_ref_clock_distribution();

    ertm15_init_leds();

    // fixme: detect fail
    //ertm15_check_oscillators();

    /* At this point, we should have a stable CLK_REF coming from the PLL. Tell the FPGA to use it also as the system clock */
    board_dbg("Switching system clock to CLK_SYS\n");
    ertm14_switch_sys_clock(1);

    /* Disable bit-banged OCXO control (used for debug) */
    gen_gpio_out(&pin_ocxo_override, 0);

    /* Create a debug SPI master for testing the OCXO tuning. Normally it's driven in hardware by the SoftPLL, I left
       this device for debugging purposes. It's active if GPIO pin ocxo_override == 1 */
    bb_spi_create( &board.spi_ocxo_dac,
        &pin_ocxo_cs_n,
        &pin_ocxo_data,
        &pin_ocxo_data,
        &pin_ocxo_sclk,
        100 );


    /* Read unique MAC addresses from storage chips (eRTM14 - IC7 and IC8) */
    ertm14_init_mac_eeprom();

    board_dbg("Init Fine Pulse Generator\n");

    /* Initialize the Fine Pulse Generator - it MUST be done 
       before we touch the DDSes as it drives the DDS IOUPDATE line.
       For my own record: don't touch this, you've wasted time catching the null pointer to
       FPG device already ;-) */

    fine_pulse_gen_init( &board.dds_sync_dev, (void *) BASE_ERTM14_DDS_SYNC_UNIT, FINE_PULSE_GEN_TARGET_KINTEX7 );

    if( ! (board.mode & ERTM14_MODE_WITHOUT_ERTM15 ) )
    {
        board_dbg("Initializing RF distribution\n");

        /* RF Power Monitor ADC (eRTM15 - IC43) */
        bb_spi_create( &board.spi_ad7888,
            &pin_pwrmon_adc_cs_n,
            &pin_pwrmon_adc_din,
            &pin_pwrmon_adc_dout,
            &pin_pwrmon_adc_sclk,
            5 );

        ad7888_create( &board.pwrmon_adc, &board.spi_ad7888 );


    /* RF distribution switches and shift registers controlling these (eRTM15 - IC26..28) */
        ertm15_rf_distr_init( &board.rf_distr, &board.pwrmon_adc );

    /* Now that the PLL clocks are ready, init the DDS synthesizers */
        board_dbg("Initializing DDSes\n");
        ertm15_init_dds();

        /* Program the DDSes to some meaninfgul settings, say, 205 MHz */

        ad9910_program(&board.dds_ad9910_ref, ERTM14_DDS_DEFAULT_FTW, 0, ERTM14_DDS_DEFAULT_AMPLITUDE );
        ad9910_program(&board.dds_ad9910_lo, ERTM14_DDS_DEFAULT_FTW, 0, ERTM14_DDS_DEFAULT_AMPLITUDE );

        ertm15_rf_distr_measure_power ( &board.rf_distr );

        int i;

        board_dbg("PA PWR REF = %d mBm, LO = %d mBm\n", board.rf_distr.pwr_ref_in, board.rf_distr.pwr_lo_in );

        for(i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++)
        {
            board_dbg("OUT[%d] PWR REF = %d mBm, LO = %d mBm\n", i, board.rf_distr.pwr_ref_ch[i], board.rf_distr.pwr_lo_ch[i] );
        }
    }

    /* Setup the SoftPLL for the OCXO we have */
    ertm14_spll_setup();


    if( ! (board.mode & ERTM14_MODE_WITHOUT_ERTM15 ) )
    {
        /* Init CLKA/CLKB distribution (AD9520s) */
        board_dbg("Initializing CLKA/CLKB distribution...\n");
        ertm14_init_clkab_distribution();
        board_dbg("Calibrating DDS sync pulse...\n");
        ertm14_dds_sync_calibrate();
    }

    board_dbg("Init Control UART Link\n");
    uart_link_create_wrpc_console( &board.control_uart_link );

    board.control_uart_link.rx_next_timeout_ms = 5; // to avoid 'choking' effect
    board.control_uart_link.extra_verbose = 0;

    board_dbg("Init RF transceiver & streamers\n");

    streamers_init();

    wr_rf_frame_transceiver_create( &board.rf_xcvr, BASE_ERTM14_RF_FRAME_TRANSCEIVER );

    ertm14_set_pps_out_mode( ERTM14_PPS_OUT_MODE_PPS );

    led_action( &board.leds.ref, LED_COLOR_1 | LED_COLOR_2, LED_ON );
    led_action( &board.leds.lo, LED_COLOR_1 | LED_COLOR_2, LED_ON );
    
    board_dbg("eRTM14/15 early init done\n");

    ertm_init_complete = 1;

    return 0;
}

void ertm14_config_init(void)
{
    int j;

    struct ertm14_board_state *cfg = ertm14_current_state;

        cfg->valid = 1;
    cfg->lo.ftw = ERTM14_DDS_DEFAULT_FTW;
    cfg->ref.ftw = ERTM14_DDS_DEFAULT_FTW;
    cfg->lo.ampl_factor = ERTM14_DDS_DEFAULT_AMPLITUDE;
    cfg->ref.ampl_factor = ERTM14_DDS_DEFAULT_AMPLITUDE;

        for( j = 0; j <= ERTM14_RF_OUT_MAX_ID; j++)
        {
            cfg->ref.out_state [j] = ERTM15_RF_OUT_MONITOR;
            cfg->lo.out_state [j] = ERTM15_RF_OUT_MONITOR;
        }
    
        cfg->ref.sync_count = 0;
        cfg->lo.sync_count = 0;

        cfg->ref.sync_source = ERTM14_SYNC_SOURCE_RF_TRIGGER;
        cfg->lo.sync_source = ERTM14_SYNC_SOURCE_RF_TRIGGER;

    cfg->ref.sync_state = ERTM14_CLK_SYNC_STATE_RESTART;
    cfg->lo.sync_state = ERTM14_CLK_SYNC_STATE_RESTART;

        for(j = 0; j <= ERTM14_CLKAB_OUT_MAX_ID; j++)
        {
            cfg->clka_freq_hz[j] = 500000000;
            cfg->clkb_freq_hz[j] = 500000000;
        cfg->clka_sync_state[j] = ERTM14_CLK_SYNC_STATE_RESTART;
        cfg->clkb_sync_state[j] = ERTM14_CLK_SYNC_STATE_RESTART;
        }

    cfg->clka_enable_mask = -1; // all CLKA outputs ON
    cfg->clkb_enable_mask = -1; // all CLKB outputs ON

    cfg->streamers_latency_cycles = ERTM14_NCO_RESET_DEFAULT_LATENCY;
    cfg->streamers_timeout_cycles = ERTM14_NCO_RESET_DEFAULT_TIMEOUT;

    copy_config(&ertm14_hardware, cfg);
}

struct ertm14_board_state *ertm14_get_current_state(void)
{
    return ertm14_current_state;
}

#if 0
static int ertm14_commit_config( struct  ertm14_board_state *cfg )
{  
    int i;
        for( i = 0; i <= ERTM14_CLKAB_OUT_MAX_ID; i++)
        {

            // digital clocks

            int freq_a = cfg->clka_freq_hz[i];
            int freq_b = cfg->clkb_freq_hz[i];
            int div_a = ertm14_get_clkab_divider( freq_a );
            int div_b = ertm14_get_clkab_divider( freq_b );
            int enable_a = ( cfg->clka_enable_mask & (1<<i) ) ? 1 : 0;
            int enable_b = ( cfg->clkb_enable_mask & (1<<i) ) ? 1 : 0;

            board_dbg("CLKA%d: freq=%d Hz, divider=%d, enable=%d\n", i, freq_a, div_a, enable_a);
            board_dbg("CLKA%d: freq=%d Hz, divider=%d, enable=%d\n", i, freq_b, div_b, enable_b);

            clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKA, i, div_a );
            clkab_set_output_divider( ertm14_current_state, ERTM14_OUT_CLKB, i, div_b );
            clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKA, i, enable_a );
            clkab_enable_output( ertm14_current_state, ERTM14_OUT_CLKB, i, enable_b );
        }

            // DDSes
        ad9910_program(&board.dds_ad9910_lo, cfg->lo.ftw, 0, cfg->lo.ampl_factor );
        ad9910_program(&board.dds_ad9910_ref, cfg->ref.ftw, 0, cfg->ref.ampl_factor );

        board_dbg("DDS LO: FTW=0x%08x, ampl=%d\n", cfg->lo.ftw, cfg->lo.ampl_factor );
        board_dbg("DDS REF: FTW=0x%08x, ampl=%d\n", cfg->ref.ftw, cfg->ref.ampl_factor );
        
        for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++)
        {
            int st_lo = cfg->lo.out_state[i] == ERTM15_RF_OUT_ON ? 1 : 0;
            int st_ref = cfg->ref.out_state[i] == ERTM15_RF_OUT_ON ? 1 : 0;
            board_dbg("i %d lo %x ref %x\n", i, st_lo, st_ref );

            ertm15_rf_distr_output_enable( &board.rf_distr, ERTM15_RF_LO, i, st_lo );
            ertm15_rf_distr_output_enable( &board.rf_distr, ERTM15_RF_REF, i, st_ref );
        }

        ertm15_update_rf_switches( &board.rf_distr );
    return 0;
}
#endif

static struct {
    int freq;
    int divider;
} clkab_freqs [] = {
    { 500000000, 1},
    { 250000000, 2},
    { 125000000, 4},
    { 62500000, 8},
    {-1,-1}
};

int ertm14_get_clkab_divider( int freq )
{
    int i;
    for (i=0;clkab_freqs[i].freq >= 0; i++)
    {
        if (clkab_freqs[i].freq == freq)
            return clkab_freqs[i].divider;
    }
    
    return -1;
}

int ertm14_get_supported_clkab_freqs( int *freqs, int max_count )
{
    int i;
    for(i = 0;clkab_freqs[i].freq >= 0; i++)
    {
        if(  i < max_count )
        {
            freqs [i] = clkab_freqs[i].freq;
        } else
            break;
    }

    return i;
}


#define ERTM14_EXPECTED_FLASH_ID 0x00016018

int wrc_board_early_init()
{
    static int32_t flash_entry_points[64];
    int i;

    console_ertm14_init();

    bist_init( ertm_bist );

    wdiags_set_base_address( &wrc_diags_nonhw );

    wrc_register_sensors( ertm_sensors );

    /* initialize SPI flash */
    bb_spi_create( &spi_wrc_flash,
		&pin_sysc_spi_ncs,
		&pin_sysc_spi_mosi,
		&pin_sysc_spi_miso,
		&pin_sysc_spi_sclk, 0 );

	spi_flash_create( &wrc_flash_dev, &spi_wrc_flash, 16384, 0x600000 );


#if 0
    uint32_t ts = timer_get_tics();

    for(i=0;i<1000000;i++)
    {
        //gen_gpio_out(&pin_sysc_spi_sclk, 0);
        //gen_gpio_out(&pin_sysc_spi_sclk, 1);

        sysc_gpio_set_out(&pin_sysc_spi_sclk, 0);
        sysc_gpio_set_out(&pin_sysc_spi_sclk, 1);

    }

    uint32_t te = timer_get_tics();
    pp_printf("meas: %d ms\n", te - ts);
    for(;;);
#endif



	uint32_t id = spi_flash_read_id( &wrc_flash_dev );

    bist_checkpoint( ertm_bist, ERTM14_BIST_FLASH_PRESENCE, 0, id == ERTM14_EXPECTED_FLASH_ID );

	/* initialize I2C bus */
	bb_i2c_init( &dev_i2c_fmc );

    for(i = 0; i < 32 + 8; i++)
        flash_entry_points[i] = 0x600000 + 0x40000 * i;

    flash_entry_points[i] = -1;
    
    /* init storage (we use the SPI flash on eRTM14) */
    storage_spiflash_create( &wrc_storage_dev, &wrc_flash_dev );
    wrc_storage_dev.entry_points = &flash_entry_points[0];

    int rv = storage_mount( &wrc_storage_dev );
    bist_checkpoint( ertm_bist, ERTM14_BIST_FLASH_FS_MOUNT, 0, rv == 0 );

    rv = storage_load_calibration();
    bist_checkpoint( ertm_bist, ERTM14_BIST_LOAD_CALIBRATION, 0, rv == 0 );

    rv = check_calibration_version();
    bist_checkpoint( ertm_bist, ERTM14_BIST_CHECK_CALIBRATION, 0, rv == 0 );

    uint32_t cd;

    if( storage_get_calibration_parameter( CAL_PARAM_CALIBRATION_DATE, &cd ) < 0 )
        cd = 0;

    if( !cd )
    {
        board_dbg("WARNING! Board calibration info has no calibration date!\n");
    }
    else
    {
        board_dbg("Calibration data: %d UTC timestamp\n", cd );
    }

   	net_rst();

    int ll = ertm14_low_level_init();
    
    /* reset the networking part of the WRCore and start the WR Endpoint */
    ep_init( &wrc_endpoint_dev, (void *) BASE_EP );
    ep_set_mac_addr( &wrc_endpoint_dev, ertm14_mac );
    netif_register_device(&wrc_endpoint_dev, &minic);

    /* Sleep for 1s to make sure WRS v4.2 always realizes that
 * the link is down */

	timer_delay_ms(200);
	ep_enable( &wrc_endpoint_dev, 1, 1);
	timer_delay_ms(200);
    bist_summary( ertm_bist );

    return ll;
}

/* FIXME: these should be in a .h file */
extern int phy_calibration_poll(void);
extern void phy_calibration_init(void);


static void mmc_show_version_info( const char *brdname, struct ertm14_mmc_state *st )
{
    pp_printf("MMC Build Info for %s:\n", brdname );
    pp_printf("  - Git build commit : %32s\n", st->info.git_sha );
    pp_printf("  - Git build tag    : %32s\n", st->info.git_tag );
    pp_printf("  - Build date       : %u (Unix)\n",
	      (unsigned)le32_to_host( st->info.build_date ) );
    pp_printf("  - Serial Number    : %32s\n",   st->info.board_serial_number );
}

int mmc_link_init( struct ertm14_mmc_link *link, struct simple_uart_device *uart_dev, uint32_t uart_base, uint32_t uart_speed )
{
    suart_init( uart_dev, uart_base, uart_speed ); // fixme: check errors
    uart_link_create_wrpc_suart( &link->ulink, uart_dev );
    tmo_init( &link->poll_timeout, ERTM14_MMC_POLL_PERIOD_MS );
    link->poll_state = MMC_POLL_STATE_IDLE;
    return 0;
}

int mmc_link_request_state(struct ertm14_mmc_link *link)
{
    struct uart_packet tx_pkt;

    if (link->poll_state != MMC_POLL_STATE_IDLE)
        return -EBUSY;

    tx_pkt.ptype = ERTM14_UART_PTYPE_MMC_STATUS_REQ;
    tx_pkt.length = 0;
    uart_link_send(&link->ulink, &tx_pkt);
    tmo_init(&link->rx_timeout, ERTM14_MMC_RX_TIMEOUT_MS);
    link->poll_state = MMC_POLL_STATE_WAIT_RESPONSE;

    return 0;
}

int mmc_link_poll_state(struct ertm14_mmc_link *link, struct ertm14_mmc_state *state, int blocking)
{
    if (link->poll_state != MMC_POLL_STATE_WAIT_RESPONSE)
        return -EAGAIN;

    do
    {
        struct uart_packet *rx_pkt;

        if (tmo_expired(&link->rx_timeout))
        {
            link->poll_state = MMC_POLL_STATE_IDLE;
            return -ETIMEDOUT;
        }

        int ret = uart_link_recv(&link->ulink, &rx_pkt, 0);

        if (ret < 0)
        {
            link->poll_state = MMC_POLL_STATE_IDLE;
            return ret;
        }
        else if (ret > 0)
        {
            if ((rx_pkt->ptype != ERTM14_UART_PTYPE_MMC_STATUS_RESP) || rx_pkt->length != sizeof(struct ertm14_mmc_state))
            {
                link->poll_state = MMC_POLL_STATE_IDLE;
                return -EBADMSG;
            }

            if (state)
                memcpy( state, rx_pkt->payload, sizeof(struct ertm14_mmc_state ) );
            return 1;
        }

    } while (blocking);

    return 0;
}

void poll_mmc_sensors(struct ertm14_mmc_link *link)
{
    struct ertm14_mmc_state state;

    if( mmc_link_poll_state(link, &state, 0) <= 0)
        return;

    int i;

    for (i = 0; i < ERTM14_MAX_SENSORS_COUNT; i++)
    {
        struct ertm14_mmc_sensor_state *s;
        s = &state.sensors[i];

        if (!(s->flags & ERTM14_SENSOR_VALID))
            continue;

        struct wrc_sensor *sensor = wrc_sensor_find_by_id(s->id);

        if (!sensor)
            continue;

        // ARMs are little endian, LM32 is big endian.... Such is life...
        sensor->value = le16_to_host(s->value);
        sensor->flags |= WRC_SENSOR_VALID;
    }
}

int mmc_test_communication( struct ertm14_mmc_link *link, struct ertm14_mmc_state *state, int attempts )
{
    int i;

    for(i = 0; i < attempts; i++)
    {
        board_dbg("Trying to communicate with the MMC, attempt %d/%d\n", i+1, attempts );
        mmc_link_request_state( link );
        int ret = mmc_link_poll_state( link, state, 1 );

        if( ret > 0)
            return ret;
    }

    return 0;
}

static void mmc14_link_init(void)
{
    tmo_init(&mmc14_link.poll_timeout, ERTM14_MMC_POLL_PERIOD_MS );
}

static void mmc15_link_init(void)
{
    tmo_init(&mmc15_link.poll_timeout, ERTM14_MMC_POLL_PERIOD_MS );
}

static int mmc14_link_poll(void)
{
    if (tmo_expired(&mmc14_link.poll_timeout))
    {
        tmo_restart(&mmc14_link.poll_timeout);
        mmc_link_request_state( &mmc14_link );
    }
    else
    {
        poll_mmc_sensors( &mmc14_link );
    }

    return 0;
}

static int mmc15_link_poll(void)
{
    if (tmo_expired(&mmc15_link.poll_timeout))
    {
        tmo_restart(&mmc15_link.poll_timeout);
        mmc_link_request_state( &mmc15_link );
    }
    else
    {
        poll_mmc_sensors( &mmc15_link );
    }

    return 0;
}

static void mmc_comm_init(void)
{
    struct ertm14_mmc_state st14;
    struct ertm14_mmc_state st15;

    board_dbg("Init MMC15 UART Link\n");

    mmc_link_init( &mmc14_link, &board.mmc_14_uart, BASE_MMC_UART_14, 115200 );
    mmc_link_init( &mmc15_link, &board.mmc_15_uart, BASE_MMC_UART_15, 115200 );

    int ertm14_ok = mmc_test_communication( &mmc14_link, &st14, 3 );
    int ertm15_ok = mmc_test_communication( &mmc15_link, &st15, 3 );

    bist_checkpoint( ertm_bist, ERTM14_BIST_MMC_14, 0, ertm14_ok );
    bist_checkpoint( ertm_bist, ERTM14_BIST_MMC_15, 0, ertm15_ok );


    if( ertm14_ok )
    {
        mmc_show_version_info( "eRTM14", &st14 );
	memcpy(&ertm14_board_info, &st14.info, sizeof(ertm14_board_info));
    } else {
        board_dbg("MMC14 communication attempt failed.\n");
    }

    if( ertm15_ok )
    {
        mmc_show_version_info( "eRTM15", &st15 );
	memcpy(&ertm15_board_info, &st15.info, sizeof(ertm15_board_info));
    } else {
        board_dbg("MMC15 communication attempt failed.\n");
    }
}


static timeout_t rfmon_timeout;

void ertm15_init_rf_monitor( void )
{
    tmo_init( &rfmon_timeout, 2000 );
}

void ertm15_force_rf_power_measurement( void )
{
        struct ertm14_board_state *bstate = ertm14_get_current_state();

        int i;

        for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++ )
        {
        bstate->lo.out_power[i] = 0;
        bstate->ref.out_power[i] = 0;
        }

    bstate->lo.amp_power = 0;
    bstate->ref.amp_power = 0;

    ertm15_rf_distr_measure_power_restart( &board.rf_distr, 1 );
}

int ertm15_update_rf_monitor( void )
{
    if( ertm15_rf_distr_is_pwrmon_idle( &board.rf_distr ) )
    {
        struct ertm14_board_state *bstate = ertm14_get_current_state();

        int i;

        for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++ )
{
            bstate->lo.out_power[i] = board.rf_distr.pwr_lo_ch[i] | ERTM_FLAGS_DDS_POWER_VALID_MASK;
            bstate->ref.out_power[i] = board.rf_distr.pwr_ref_ch[i] | ERTM_FLAGS_DDS_POWER_VALID_MASK;
}

        bstate->lo.amp_power = board.rf_distr.pwr_lo_in | ERTM_FLAGS_DDS_POWER_VALID_MASK;
        bstate->ref.amp_power = board.rf_distr.pwr_ref_in | ERTM_FLAGS_DDS_POWER_VALID_MASK;
    }

    if( tmo_expired( &rfmon_timeout ) )
{
     //   pp_printf("TmoExp st %d ch %d\n",board.rf_distr.pwr_meas_state, board.rf_distr.pwr_meas_channel);
        if( ertm15_rf_distr_is_pwrmon_idle( &board.rf_distr ) )
        {
            // pp_printf("PwrMonRst\n");
            tmo_restart( &rfmon_timeout );
            ertm15_rf_distr_measure_power_restart( &board.rf_distr, 0 );
}
    }

    ertm15_rf_distr_pwrmon_update( &board.rf_distr );

    return 0;
}

static int prev_ptp_servo_state = -1;
static int prev_ptp_state = -1;

extern struct pp_instance ppi_static;

static int wrc_ptp_get_servo_state(void)
{
	struct pp_instance *ppi = &ppi_static;
	return SRV(ppi)->state;
}

static int wrc_ptp_get_state(void)
{
	struct pp_instance *ppi = &ppi_static;
	return ppi->state;
}

int ertm14_update_leds( void )
{
    /* White Rabbit Servo */
    enum {
        WR_UNINITIALIZED = 0,
        WR_SYNC_NSEC,
        WR_SYNC_TAI,
        WR_SYNC_PHASE,
        WR_TRACK_PHASE,
        WR_WAIT_OFFSET_STABLE,
    };


    /* Enumeration States (table 8, page 73) */
    enum {
        PPS_END_OF_TABLE	= 0,
        PPS_INITIALIZING,
        PPS_FAULTY,
        PPS_DISABLED,
        PPS_LISTENING,
        PPS_PRE_MASTER,
        PPS_MASTER,
        PPS_PASSIVE,
        PPS_UNCALIBRATED,
        PPS_SLAVE,
    };

    int ptp_servo_state = wrc_ptp_get_servo_state();
    int ptp_state = wrc_ptp_get_state();

    if( ptp_servo_state != prev_ptp_servo_state || ptp_state != prev_ptp_state )
    {
        if( ptp_servo_state == WR_TRACK_PHASE && ptp_state == PPS_SLAVE )
        {
            led_action( &board.leds.sync, LED_COLOR_1, LED_ON );
            led_action( &board.leds.sync, LED_COLOR_2, LED_OFF );
        }
        else if ( ptp_state == PPS_LISTENING || ptp_state == PPS_INITIALIZING )
        {
            led_action( &board.leds.sync, LED_COLOR_1, LED_OFF );
            led_action( &board.leds.sync, LED_COLOR_2, LED_OFF );
        }
        else if ( ptp_state == PPS_SLAVE )
        {
            led_action( &board.leds.sync, LED_COLOR_1, LED_BLINK );
            led_action( &board.leds.sync, LED_COLOR_2, LED_OFF );
        }

        prev_ptp_servo_state = ptp_servo_state;
        prev_ptp_state = ptp_state;
    }


    leds_update();
    return 0;
}

/* Read DNA and commit id from HW and calibration storage.
   If they don't match, invalidate lptp calibration parameter (as it is
   highly dependent on the bitstream. */
static int check_calibration_version(void)
{
	volatile unsigned *dna = (volatile unsigned *)BASE_ERTM14_DNA;
	const char *bi;
	int valid = 0; /* -1: error, 0: too old, 1: ok */
	unsigned int sha_0;
	unsigned int dna_0;

	/* Read DNA from hw. */
	if (!(dna[0] & 1)) {
		/* Not expected: DNA not ready... */
		board_dbg("cannot read DNA (invalid)\n");
		valid = -1;
	}
	else
		dna_0 = dna[1];

	/* Read commit id from buildinfo.
	   TODO: instead of storing it as a string, store it as a number ? */
	/* Find: '\ncommit:' */
	sha_0 = 0;
	for (bi = (const char *)BASE_ERTM14_BUILD_INFO; *bi; bi++) {
		if (memcmp (bi, "\ncommit:", 8) == 0) {
			bi += 8;
			for (unsigned j = 0; j < 8; j++) {
				sha_0 <<= 4;
				if (bi[j] >= '0' && bi[j] <= '9')
					sha_0 += bi[j] - '0';
				else if (bi[j] >= 'a' && bi[j] <= 'f')
					sha_0 += bi[j] - 'a' + 10;
				else {
					valid = -1;
					break;
				}
			}
			break;
		}
	}
	if (*bi == 0) {
		board_dbg("cannot find commit in buildinfo\n");
		valid = -1;
	}

	/* Now compare with stored calibration, but only if values have been
	   read.  */
	if (valid == 0) {
		uint32_t v;
		valid = 1;
		if (storage_get_calibration_parameter(CAL_PARAM_FPGA_DNA_0, &v) != 0
		    || v != dna_0)
			valid = 0;
		if (storage_get_calibration_parameter(CAL_PARAM_COMMIT_SHA_0, &v) != 0
		    || v != sha_0)
			valid = 0;
	}
	if (valid == 1) {
		/* Everything is OK. */
		board_dbg("calibration data are valid\n");
		return 0;
	}
	
	/* Clear all bitstream/board-specific calibration data. */
	storage_remove_calibration_parameter(CAL_PARAM_PHY_TARGET_TX_PHASE);
	storage_remove_calibration_parameter(CAL_PARAM_T24P);
	storage_remove_calibration_parameter(CAL_PARAM_CLKA_SYNC_DELAY_PS);
	storage_remove_calibration_parameter(CAL_PARAM_CLKB_SYNC_DELAY_PS);

	storage_save_calibration();

	if (valid == 0) {
		/* Values are too old. */
		int err;
		board_dbg("update dna/sha in calibration\n");
		err = storage_set_calibration_parameter(CAL_PARAM_FPGA_DNA_0, dna_0);
		err |= storage_set_calibration_parameter(CAL_PARAM_COMMIT_SHA_0, sha_0);
		/* Will be written when lptp is updated.  */
		if (err != 0)
        {
		board_dbg("cannot set dna/sha calibration\n");
        }
	}

    return -1;
}

int wrc_board_init()
{
    ertm14_shell_init();

    evth_dds_nco_sync = event_listener_create();
    evth_clkab_sync = event_listener_create();

    console_set_mode_switch_hook( &console_uart_dev, control_uart_mode_callback );

    wrc_task_create( "control-uart", NULL, control_uart_poll );
    wrc_task_create( "mmc14", mmc14_link_init, mmc14_link_poll );
    wrc_task_create( "leds", NULL, ertm14_update_leds );
    wrc_task_create( "phy-cal", phy_calibration_init, phy_calibration_poll );

    if( ! ( board.mode & ERTM14_MODE_WITHOUT_ERTM15 ) )
    {
        wrc_task_create( "rf-nco-sync", ertm14_dds_nco_sync_init, ertm14_dds_nco_sync_task );
        wrc_task_create( "clkab-sync", ertm14_clkab_sync_init, ertm14_clkab_sync_task );
        wrc_task_create( "mmc15", mmc15_link_init, mmc15_link_poll );
        wrc_task_create( "rf-monitor", ertm15_init_rf_monitor, ertm15_update_rf_monitor );
    }

    wrc_task_create( "spll-dbg", ertm14_spll_debug_dump_task_init, ertm14_spll_debug_dump_task_poll );

    struct ertm14_board_state mask;
    memset(&mask, 0xff, sizeof( struct ertm14_board_state )); // make sure we commit everything to HW

    ertm14_apply_config( ertm14_current_state, &mask, 1 );

    return 0;
}


int wrc_board_create_tasks()
{
    wrc_task_create("events-ptp", wrc_events_ptp_init, wrc_events_ptp_poll);

    return 0;
}

void ertm14_sync_pulse_cal(void)
{
    pp_printf("Sync Pulse calibration [press X to continue]:\n");

    int dly_clka =  board.dds_sync_delays[ERTM14_PLL_SYNC_CLKA];
    int dly_clkb =  board.dds_sync_delays[ERTM14_PLL_SYNC_CLKB];
    int dly_ioupd_ref =  board.dds_sync_delays[ERTM14_DDS_IOUPDATE_REF];
    int dly_ioupd_lo =  board.dds_sync_delays[ERTM14_DDS_IOUPDATE_LO];


    pp_printf("Current offsets:\n CLKA = %d ps\n CLKB = %d ps\n DDS REF = %d ps\n DDS LO = %d ps\n", dly_clka, dly_clkb,  dly_ioupd_ref, dly_ioupd_lo);

    uint32_t channel_mask = ( 1 << ERTM14_PLL_SYNC_CLKA ) | ( 1<< ERTM14_PLL_SYNC_CLKB )
                            | ( 1<< ERTM14_DDS_IOUPDATE_LO) | ( 1<< ERTM14_DDS_IOUPDATE_REF);

    shw_pps_gen_init();
    shw_pps_gen_enable_output(1);
    shw_pps_gen_unmask_output(1);

    ertm14_set_pps_out_mode(0);



    int offset;

    // CLKA @ 400 ps
    // CLKB @ 400 ps

    offset = 400;
    ertm14_set_pps_out_mode(0);

    int div = ertm14_get_clkab_divider( 62500000 );



    clkab_set_output_divider( ertm14_current_state, 0, ERTM14_CLKAB_OUT_FRONT_PANEL, div );
    clkab_set_output_divider( ertm14_current_state, 1, ERTM14_CLKAB_OUT_FRONT_PANEL, div );

    int i;
    for( i = ERTM14_CLKAB_OUT_MIN_ID; i <= ERTM14_CLKAB_OUT_MAX_ID; i++ )
    {
        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKA, i, 1 );
        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKB, i, 1 );
    }

    spll_init( SPLL_MODE_FREE_RUNNING_MASTER, 0, 0 );

    int quit = 0;
    do
    {
        pp_printf("Offset is %d ps, a = increase, z = decrease, x = quit\n", offset);

        fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_PLL_SYNC_CLKA, 1, offset, 1000, 0 );
        fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_PLL_SYNC_CLKB, 1, offset, 1000, 0 );
        fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_IOUPDATE_LO, 1, offset, 0, 0 );
        fine_pulse_gen_setup_channel ( &board.dds_sync_dev, ERTM14_DDS_IOUPDATE_REF, 1, offset, 0, 0 );

        fine_pulse_gen_trigger( &board.dds_sync_dev, channel_mask, 0 );

#if 0
        struct spll_aux_clock_status st = spll_get_aux_status( 0 );

        pp_printf("Aux0: en:%d rdy:%d ph:%s\n",
        st.flags & SPLL_AUX_MONITOR_ENABLED ? 1 : 0,
        st.flags & SPLL_AUX_MONITOR_READY ? 1 : 0,
        st.phase
        );
#endif
        while ( !fine_pulse_gen_is_triggered (&board.dds_sync_dev, channel_mask ) );

        int c = console_getc();
        switch(c)
        {
            case 'a': if( offset < 16000 ) offset += 100; break;
            case 'z': if( offset > 100 ) offset -= 100; break;
            case 'x': quit = 1; break;
            default: break;
        }
    } while(!quit);

    gen_gpio_out( &pin_tm_clk_aux0_lock_en, 0 );

    for( i = ERTM14_CLKAB_OUT_MIN_ID; i <= ERTM14_CLKAB_OUT_MAX_ID; i++ )
    {
        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKA, i, 0 );
        clkab_enable_sync( ertm14_current_state, ERTM14_OUT_CLKB, i, 0 );
    }
}
