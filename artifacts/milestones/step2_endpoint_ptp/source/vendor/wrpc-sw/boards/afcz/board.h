/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __BOARD_WRC_H
#define __BOARD_WRC_H
/*
 * This is meant to be automatically included by the Makefile,
 * when wrpc-sw is build for wrc (node) -- as opposed to wrs (switch)
 */

#define BOARD_HAS_CUSTOM_NETWORK_INIT 1

/* Unusual base addresses */
#undef DEV_BASE
#define DEV_BASE 0x20000

#define BASE_WR_ENDPOINT_MAIN       BASE_EP

#define BASE_SI57X_INTERFACE    (BASE_AUXWB + 0x80)
#define BASE_AFCZ_CLOCK_MONITOR (BASE_AUXWB + 0xc0)
#define BASE_WR_ENDPOINT_BTRAIN (BASE_AUXWB + 0x00)

#define AFCZ_CM_CHANNEL_CLK_PCB 0
#define AFCZ_CM_CHANNEL_CLK_SYS 3
#define AFCZ_CM_CHANNEL_CLK_RX 2
#define AFCZ_CM_CHANNEL_CLK_REF 1
#define AFCZ_CM_CHANNEL_CLK_DMTD 5

#define AFCZ_IC33_CLK_SI570_1_IN 13
#define AFCZ_IC33_CLK_SI570_2_IN 15
#define AFCZ_IC33_FPGA_CLK3_OUT 9
#define AFCZ_IC33_FPGA_CLK_GTX_CUST2_OUT 8
#define AFCZ_IC33_FPGA_FMC2_CLK2_BIDIR_OUT 14

#define AFCZ_I2C_MUX_CHANNEL_SI570 2
#define AFCZ_I2C_MUX_CHANNEL_RTM 7

#define AFCZ_I2C_ADDR_MAC_EEPROM 0x59

#define AFCZ_I2C_EEPROM_MAC_OFFSET 0x9a

#define RTM_4SFP_MUX_SFP0 0
#define RTM_4SFP_MUX_SFP1 1
#define RTM_4SFP_MUX_SFP2 2
#define RTM_4SFP_MUX_SFP3 3
#define RTM_4SFP_MUX_SFP4 4
#define RTM_4SFP_MUX_SFP5 5
#define RTM_4SFP_MUX_SFP6 6



/* Board-specific parameters */
#define TICS_PER_SECOND 1000

/* WR Core system/CPU clock frequency in Hz */
#define CPU_CLOCK 62500000ULL

/* WR Reference clock period (picoseconds) and frequency (Hz) */
#define REF_CLOCK_PERIOD_PS 16000
#define REF_CLOCK_FREQ_HZ 62500000

#define NS_PER_CLOCK 16

/* Baud rate of the builtin UART (does not apply to the VUART) */
#define UART_BAUDRATE 115200ULL

/* Maximum number of simultaneously created sockets */
#define NET_MAX_SOCKETS 12

/* Socket buffer size, determines the max. RX packet size */
#define NET_MAX_SKBUF_SIZE 512

/* spll parameter that are board-specific */
#define BOARD_DIVIDE_DMTD_CLOCKS	0
#define BOARD_MAX_CHAN_REF		1
#define BOARD_MAX_CHAN_AUX		2
#define BOARD_MAX_PTRACKERS		1

#undef CONFIG_DISALLOW_LONG_DIVISION

#define BOARD_CONSOLE_DEVICES 1

#define BOARD_USE_EVENTS 0

#define CONSOLE_UART_BAUDRATE 115200

#define SDBFS_REC 5
 
#endif /* __BOARD_WRC_H */
