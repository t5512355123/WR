/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __BOARD_ERTM14_H
#define __BOARD_ERTM14_H

#include "dev/gpio.h"
#include "dev/bb_spi.h"
#include "dev/ad951x.h"
#include "dev/ltc695x.h"
#include "dev/ad9910.h"
#include "dev/24aa025.h"
#include "dev/ad7888.h"
#include "dev/leds.h"
#include "ertm15_rf_distr.h"
#include "dev/fine_pulse_generator.h"
#include "dev/spi_flash.h"
#include "dev/bb_i2c.h"
#include "dev/iuart.h"
// #include "ertm14-uart-link.h"
#include "rf_frame_transceiver.h"
#include "board-state.h"
#include "common-uart-link.h"

#define ERTM14_SECONDARY_DEBUG_UART 1

#define WRC_MAX_TASKS 24

#define BOARD_USE_CUSTOM_SDBFS 1
#define BOARD_HAS_CUSTOM_NETWORK_INIT 1

#define BOARD_MAX_LEDS 8

#undef BOARD_ERTM14_REV_1
#define BOARD_ERTM14_REV_2

#define BOARD_CONSOLE_DEVICES 2

#define BOARD_USE_EVENTS 1

/* Board-specific parameters */
#define TICS_PER_SECOND 1000

/* WR Core system/CPU clock frequency in Hz */
#define CPU_CLOCK 62500000ULL

/* WR Reference clock period (picoseconds) and frequency (Hz) */
#define REF_CLOCK_PERIOD_PS 16000
#define REF_CLOCK_FREQ_HZ 62500000

/* Center DMTD frequency (Hz) */
#define DMTD_CLOCK_FREQ_HZ 62500000

/* Baud rate of the builtin UART (does not apply to the VUART) */
#define CONSOLE_UART_BAUDRATE 921600ULL

/* Maximum number of simultaneously created sockets */
#define NET_MAX_SOCKETS 12

/* Socket buffer size, determines the max. RX packet size */
#define NET_MAX_SKBUF_SIZE 512

/* spll parameter that are board-specific */
#  define BOARD_DIVIDE_DMTD_CLOCKS	0
#  define NS_PER_CLOCK 16

#define BOARD_MAX_CHAN_REF		1
#define BOARD_MAX_CHAN_AUX		2
#define BOARD_MAX_PTRACKERS		1

#define BOARD_SPLL_DIV_BITS      8
#define BOARD_SPLL_DAC_BITS     24

#define ERTM14_MAX_CONFIGS 8

#define CONFIG_SPLL_DEGLITCH_THR 700



#define SDBFS_REC 5

#define BASE_ERTM_CLOCK_MONITOR          (BASE_AUXWB + 0x100)
#define BASE_MMC_UART_14             	 (BASE_AUXWB + 0x200)
#define BASE_ERTM14_DDS_SYNC_UNIT    	 (BASE_AUXWB + 0x300)
#define BASE_ERTM14_10MHZ_ALIGN_UNIT 	 (BASE_AUXWB + 0x400)
#define BASE_ERTM14_RF_FRAME_TRANSCEIVER (BASE_AUXWB + 0x500)
#define BASE_ERTM14_STREAMERS            (BASE_AUXWB + 0x600)
#define BASE_MMC_UART_15                 (BASE_AUXWB + 0x700)
#define BASE_ERTM14_DEBUG_UART           (BASE_AUXWB + 0x800)
#define BASE_ERTM14_BUILD_INFO      	 (BASE_AUXWB + 0x900)
#define BASE_ERTM14_DNA             	 (BASE_AUXWB + 0x1000)

#define ERTM14_RF_OUT_MIN_ID	ERTM_COMMON_RF_OUT_MIN_ID
#define ERTM14_RF_OUT_MAX_ID	ERTM_COMMON_RF_OUT_MAX_ID
#define ERTM14_ALL_RF_OUT_ID_MASK ERTM_COMMON_ALL_RF_OUT_ID_MASK

#define ERTM14_OUT_CLKA 0
#define ERTM14_OUT_CLKB 1

#define ERTM14_CLKAB_OUT_MIN_ID	ERTM_COMMON_CLKAB_OUT_MIN_ID
#define ERTM14_CLKAB_OUT_MAX_ID ERTM_COMMON_CLKAB_OUT_MAX_ID

#define ERTM14_CLKAB_OUT_FRONT_PANEL	ERTM_COMMON_CLKAB_OUT_FRONT_PANEL

// clock monitor core channels (see ertm14_top.vhd for assignment to the clock monitor core)
#define ERTM14_CMON_CLK_SYS 0       /* system clock */
#define ERTM14_CMON_CLK_DMTD 1      /* DDMTD sampling clock */
#define ERTM14_CMON_CLK_PLL_FB 2    /* fixme: I don't remember, check in VHDL */
#define ERTM14_CMON_CLK_REF 3       /* WR REF clock (from the VCXO/OCXO) */
#define ERTM14_CMON_CLK_RX 4        /* RX clock (recovered by the WR PHY) */


// #define ERTM14_CALIBRATION_DEBUG 1

#define ERTM14_MODE_WITHOUT_ERTM15 (1 << 0)
#define ERTM14_MODE_OCXO_10MHZ (1 << 1)
#define ERTM14_MODE_OCXO_100MHZ (1 << 2)

#define ERTM14_DEFAULT_DDS_FREQUENCY_HZ 205000000ULL

#define WRC_ERTM14_EVENT_APPLY_NEW_CONFIG (WRC_EVENT_PRIVATE_START+0)

#define WRC_ERTM14_EVENT_LO_RECONFIGURED        (WRC_EVENT_PRIVATE_START+1)
#define WRC_ERTM14_EVENT_REF_RECONFIGURED       (WRC_EVENT_PRIVATE_START+2)
#define WRC_ERTM14_EVENT_CLKAB_RECONFIGURED     (WRC_EVENT_PRIVATE_START+3)

#define ERTM14_DDS_DEFAULT_FTW 0x39374BC6 /* 223.5 MHz @ 1 GHz refclk */
#define ERTM14_DDS_DEFAULT_AMPLITUDE 66 /* 12 dBm */


/* modes of the PPS output, it can output a variety of signals
   for diagnostics or pure fun ;-) */
#define ERTM14_PPS_OUT_MODE_PPS 0
#define ERTM14_PPS_OUT_MODE_RF_FRAME_VALID 1
#define ERTM14_PPS_OUT_MODE_STRM_RX_VALID 2
#define ERTM14_PPS_OUT_MODE_RF_RESET_NCO 3
#define ERTM14_PPS_OUT_MODE_CONSTANT_0 4
#define ERTM14_PPS_OUT_MODE_CONSTANT_1 5

struct ertm14_board
{
    struct gpio_device gpio_aux;

    struct spi_bus spi_pll_main;
    struct spi_bus spi_pll_ext;
    struct spi_bus spi_ltc6950;
    struct spi_bus spi_ltc6953_clka;
    struct spi_bus spi_ltc6953_clkb;
    struct spi_bus spi_ad9910_ref;
    struct spi_bus spi_ad9910_lo;
    struct spi_bus spi_ocxo_dac;
    struct spi_bus spi_ad7888;
    struct i2c_bus i2c_clka_distr;
    struct i2c_bus i2c_clkb_distr;

    struct ad951x_device ad9516_main;
    struct ad951x_device ad9516_ext;
    struct ltc695x_device ltc6950_pll;
    struct ad9910_device dds_ad9910_ref;
    struct ad9910_device dds_ad9910_lo;
    struct ad7888_device pwrmon_adc;
    struct ertm15_rf_distribution_device rf_distr;
    struct ltc695x_device dev_clka_distr;
    struct ltc695x_device dev_clkb_distr;
    struct i2c_bus i2c_mac_addr;
    struct m24aa025_device m24_mac_ids[2];
    struct fine_pulse_gen_device dds_sync_dev;
    struct wr_rf_frame_transceiver_device rf_xcvr;
    struct gpio_device gpio_ertm15_leds;
    struct uart_link control_uart_link;
    struct simple_uart_device mmc_14_uart;
    struct simple_uart_device mmc_15_uart;

    struct
    {
        struct led_device sync;
        struct led_device ref;
        struct led_device lo;
        struct led_device clka;
        struct led_device clkb;
    } leds;

    int mode;
    int dds_resync_count;

    uint32_t dds_sync_delays[ 6 ];
};

extern struct ertm14_board board;

void ertm14_config_init(void);
struct ertm14_board_state *ertm14_get_current_state(void);
int ertm14_get_clkab_divider( int freq );
void ertm14_shell_init(void);
void ertm14_apply_config(struct ertm14_board_state *cfg,
	struct ertm14_board_state *mask, int force_all);
void ertm14_set_pps_out_mode(int mode);
void ertm14_sync_pulse_cal(void);

void console_ertm14_init(void);

#endif /* __BOARD_WRC_H */
