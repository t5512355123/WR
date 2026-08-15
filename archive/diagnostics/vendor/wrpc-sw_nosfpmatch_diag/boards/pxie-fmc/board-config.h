/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
 * Author: Greg Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __BOARD_CONFIG_PXIE_FMC_H
#define __BOARD_CONFIG_PXIE_FMC_H
/*
 * This is meant to be automatically included by the Makefile,
 * when wrpc-sw is build for wrc (node) -- as opposed to wrs (switch)
 */

/* Board-specific parameters */
#define TICS_PER_SECOND 1000

/* WR Core system/CPU clock frequency in Hz */
#define CPU_CLOCK 62500000ULL

/* WR Reference clock period (picoseconds) and frequency (Hz) */
#define NS_PER_CLOCK 16
#define REF_CLOCK_PERIOD_PS 16000
#define REF_CLOCK_FREQ_HZ 62500000

/* Maximum number of simultaneously created sockets */
#define NET_MAX_SOCKETS 12

/* Socket buffer size, determines the max. RX packet size */
#define NET_MAX_SKBUF_SIZE 512

/* spll parameter that are board-specific */
#define BOARD_DIVIDE_DMTD_CLOCKS	0
#define BOARD_MAX_CHAN_REF		1
#define BOARD_MAX_CHAN_AUX		2
#define BOARD_MAX_PTRACKERS		1

#define BOARD_USE_EVENTS 0

#define BOARD_CONSOLE_DEVICES 1

#define CONSOLE_UART_BAUDRATE 115200

/* i2c eeproms address */
#define CFG_EEPROM_ADR 0x50
#define MAC_CHIP_ADR   0x51

#define SDBFS_REC 5

#endif /* __BOARD_CONFIG_PXIE_FMC_H */
