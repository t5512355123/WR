/*
 * We build for both wr-switch and wr-node (core).
 *
 * Unfortunately, our submodules include <board.h> without using
 * our own Kconfig defines. Thus, assume wr-node unless building
 * specifically for wr-switch (which doesn't refer to submodules).
 * Same appplies to ./tools/, where we can avoid a Makefile
 * patch for add "-include ../include/generated/autoconf.h"
 *
*/

#ifndef __BOARD_H
#define __BOARD_H

#ifdef CONFIG_ARCH_RISCV
    #define DEV_BASE	0x100000
#elif defined CONFIG_ARCH_LM32
    #define DEV_BASE	0x40000
#else
    #error Wrong CPU architecture. Must define either LM32 or RISC-V.
#endif

/* Fixed base addresses */
#define BASE_MINIC              (DEV_BASE + 0x000)
#define BASE_EP                 (DEV_BASE + 0x100)
#define BASE_SOFTPLL            (DEV_BASE + 0x200)
#define BASE_PPS_GEN            (DEV_BASE + 0x300)
#define BASE_SYSCON             (DEV_BASE + 0x400)
#define BASE_UART               (DEV_BASE + 0x500)
#define BASE_ONEWIRE            (DEV_BASE + 0x600)
#define BASE_WDIAGS_PRIV        (DEV_BASE + 0x900)
#define BASE_CLOCK_MONITOR      (DEV_BASE + 0xb00)
#define BASE_AUXWB              (DEV_BASE + 0x8000)

/* Board configuration. */
#if defined(CONFIG_TARGET_GENERIC_PHY_8BIT) || defined(CONFIG_TARGET_GENERIC_PHY_16BIT) || defined(CONFIG_TARGET_SPEC_SILABS)
#  include "boards/generic/board-config.h"
#elif defined(CONFIG_TARGET_WR_SWITCH)
#  include "boards/wr-switch/board.h"
#elif defined(CONFIG_TARGET_AFCZ_V1) || defined(CONFIG_TARGET_AFCZ_V2)
#  include "boards/afcz/board.h"
#elif defined(CONFIG_TARGET_ERTM14)
#  include "boards/ertm14/board.h"
#elif defined(CONFIG_TARGET_SIS8300KU)
#  include "boards/sis8300ku/board.h"
#elif defined(CONFIG_TARGET_PXIE_FMC)
#  include "boards/pxie-fmc/board-config.h"
#elif defined(CONFIG_TARGET_WR2RF_VME)
#  include "boards/wr2rf-vme/board-config.h"
#else
#  error no board defined
#endif

extern struct wr_endpoint_device wrc_endpoint_dev;

int wrc_board_early_init(void);
int wrc_board_init(void);
int wrc_board_create_tasks(void);

#endif
