/*
* This work is part of the White Rabbit project
*
* Copyright (C) 2017 CERN (www.cern.ch)
* Author: Adam Wujek <adam.wujek@cern.ch>
*
* Released according to the GNU GPL, version 2 or any later version.
*/
#ifndef __LM32_CRT0_H__
#define __LM32_CRT0_H__

/* offsets for crt0.s */
#define WRPC_MARK		0x80
#define WRC_STATIC_PADDR	0x90

#define PPG_STATIC_PADDR	0x98
#define STATS_PADDR		0x9c
#define UPTIME_SEC_ADDR		0xa0
#define VERSION_WRPC_ADDR	0xa4
#define VERSION_PPSI_ADDR	0xa5

#define HDL_TESTBENCH_PADDR	0xbc

#endif /* __LM32_CRT0_H__ */
