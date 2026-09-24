/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __BOARD_CONFIG_GENERIC_H
#define __BOARD_CONFIG_GENERIC_H
/*
 * This is meant to be automatically included by the Makefile,
 * when wrpc-sw is build for wrc (node) -- as opposed to wrs (switch)
 */

/* Support etherbone: define the address of the etherbone core. */
#define BASE_ETHERBONE_CFG	BASE_AUXWB

/* Board-specific parameters: the number of tics per seconds, or by how many
   steps SYSCON->TVR is incremented each second.
   This is controlled by the g_cntr_period generic in wrc_periph.vhd, the
   value is 62500 and is not expected to change.
   If clk_sys is 62.5Mhz, there are 1000 tics per second. */
#define TICS_PER_SECOND 1000

/* WR Core system/CPU clock frequency in Hz (clk_sys) */
#define CPU_CLOCK 62500000ULL

/* WR Reference clock period (picoseconds) and frequency (Hz)
   The eth phy interface datarate is 125MB/s.  */
#ifdef CONFIG_TARGET_GENERIC_PHY_16BIT
   /* So if the phy interface use 16b, it is clocked at 62.5Mhz */
#  define NS_PER_CLOCK 16
#  define REF_CLOCK_PERIOD_PS 16000
#  define REF_CLOCK_FREQ_HZ 62500000
#else
   /* So if the phy interface use 8b, it is clocked at 125Mhz */
#  define NS_PER_CLOCK 8
#  define REF_CLOCK_PERIOD_PS 8000
#  define REF_CLOCK_FREQ_HZ 125000000
#endif

/* Maximum number of simultaneously created sockets */
#define NET_MAX_SOCKETS 12

/* Socket buffer size, determines the max. RX packet size */
#define NET_MAX_SKBUF_SIZE 512

/* spll parameter that are board-specific */
#ifdef CONFIG_TARGET_GENERIC_PHY_16BIT
#  define BOARD_DIVIDE_DMTD_CLOCKS	0
#else
   /* For timing closure, DMTD clock is divided by 2 when the RX clock
      is 125Mhz. This is controlled by the g_divide_input_by_2 generic
      in wr_core.vhd */
#  define BOARD_DIVIDE_DMTD_CLOCKS	1
#endif

/* Number of reference channels (RX clocks) */
#define BOARD_MAX_CHAN_REF		1
/* Number of external pll that can be disciplined */
#define BOARD_MAX_CHAN_AUX		2
/* Should be the same as reference channels */
#define BOARD_MAX_PTRACKERS		1

/* Events are not used on this platform */
#define BOARD_USE_EVENTS 0

/* Use one uart at 115200 baud. Some boards may add extra uart. */
#define BOARD_CONSOLE_DEVICES 1
#define CONSOLE_UART_BAUDRATE 115200

/* Maximum number of files in the sdb filesystem.
   Need at least 4: ., sfp database, init script and calibration
   MAC address could also be written on sdbfs. */
#define SDBFS_REC 5

/* Specific to this board (see board.c) */
/* I2C address of the storage eeprom */
#define FMC_EEPROM_ADR 0x50

/* However it is not used. */
#define EEPROM_STORAGE 0


#endif /* __BOARD_CONFIG_GENERIC_H */
