/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __BOARD_CONFIG_WR2RF_VME_H
#define __BOARD_CONFIG_WR2RF_VME_H

#define BOARD_USE_CUSTOM_SDBFS 1
#define BOARD_HAS_CUSTOM_NETWORK_INIT 1
#define BOARD_CONSOLE_DEVICES 1

#define BOARD_USE_EVENTS 0

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
#define BOARD_MAX_CHAN_AUX		1 /* No extra vcxo */
#define BOARD_MAX_PTRACKERS		1

/* Hardware dithering: wrc_dac_dither convert from 24b to 16b.
   DIV_BITS is the number of bits eaten by hardware dithering,
   DAC_BITS is the number of virtual dac bits (before hw dithering). */
#define BOARD_SPLL_DIV_BITS      8
#define BOARD_SPLL_DAC_BITS     (16 + BOARD_SPLL_DIV_BITS)

#define CONFIG_SPLL_DEGLITCH_THR 550

#define SDBFS_REC 5

#endif /* __BOARD_CONFIG_WR2RF_VME_H */
