/*
* This work is part of the White Rabbit project
*
* Copyright (C) 2017 CERN (www.cern.ch)
* Author: Adam Wujek <adam.wujek@cern.ch>
*
* Released according to the GNU GPL, version 2 or any later version.
*/
#ifndef __RISCV_CRT0_H__
#define __RISCV_CRT0_H__

/* offsets for crt0.s */
#define WRPC_MARK		0x10
#define WRC_STATIC_PADDR	0x18

#define PPG_STATIC_PADDR	0x1c
#define STATS_PADDR		0x20
#define UPTIME_SEC_ADDR		0x24
#define VERSION_WRPC_ADDR	0x28
#define VERSION_PPSI_ADDR	0x29

#endif /* __RISCV_CRT0_H__ */
