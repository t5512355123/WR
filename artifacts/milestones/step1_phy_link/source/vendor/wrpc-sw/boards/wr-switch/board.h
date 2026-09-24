/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __BOARD_WRS_H
#define __BOARD_WRS_H

#define TICS_PER_SECOND 100000

#define CPU_CLOCK             62500000
#define REF_CLOCK_FREQ_HZ     62500000
#define NS_PER_CLOCK          16
#define REF_CLOCK_PERIOD_PS   16000

#undef DEV_BASE
#undef BASE_MINIC
#undef BASE_SOFTPLL
#undef BASE_PPS_GEN
#undef BASE_UART

/* RT CPU Memory layout */
#define BASE_UART 0x10000
#define BASE_SOFTPLL 0x10100
#define BASE_SPI 0x10200
#define BASE_GPIO 0x10300
#define BASE_TIMER 0x10400
#define BASE_PPS_GEN 0x10500
#define BASE_SPI_LJD_BOARD 0x10700

/* spll parameter that are board-specific */
#define BOARD_DIVIDE_DMTD_CLOCKS	0
#define BOARD_MAX_CHAN_REF		18
#define BOARD_MAX_CHAN_AUX		1
#define BOARD_MAX_PTRACKERS		18

#define CONSOLE_UART_BAUDRATE 115200
#define BOARD_CONSOLE_DEVICES 1

#define BOARD_USE_EVENTS 0

#endif
