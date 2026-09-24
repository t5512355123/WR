#define __ASSEMBLY__
#include "include/revision.h"
#include "ppsi/include/hw-specific/wrh.h"
#include "arch/risc-v/crt0.h"
#include "include/generated/autoconf.h"

.section .boot, "ax", @progbits

.global _start
_start:
    j      _entry

.org 0x8

.extern trap_entry
_exception_entry:
    j      trap_entry

	.org WRPC_MARK
wrpc_mark:
/* Used by the dumping tool to identify byte ordering */
	.ascii     "WRPC----"
/* Pointer to structures, for the dumping tool */
.org WRC_STATIC_PADDR
wrc_global_addr:
	.word  wrc_global
	
#ifdef CONFIG_WRPC_PPSI
	.org PPG_STATIC_PADDR
ppg_static_addr:
	.word  ppg_static
#endif

	.org UPTIME_SEC_ADDR
	.global uptime_sec
uptime_sec:
	.word  0

	.org VERSION_WRPC_ADDR
version_wrpc:
	.byte  WRPC_SHMEM_VERSION

	.org VERSION_PPSI_ADDR
version_ppsi:
	.byte  WRS_PPSI_SHMEM_VERSION
	.byte 0, 0

    .global _reset_handler
    .type   _reset_handler, @function
_reset_handler:
_entry:

    la     gp, _gp                 # Initialize global pointer
    la     sp, _fstack

# clear the bss segment
    la     t0, _fbss
    la     t1, _end
1:
#ifdef __riscv64
    sd     zero,0(t0)
    addi   t0, t0, 8
#else
    sw     zero,0(t0)
    addi   t0, t0, 4
#endif
    bltu   t0, t1, 1b

#if CONFIG_DATASIZE != 0
# Copy RAM
    la     t0, _fdata   # Dest
    la     t1, _edata   # Max address
    la     t2, _datacopy  # Src
1:  lw     t3, 0(t2)
    sw     t3, 0(t0)
    addi   t0, t0, 4
    addi   t2, t2, 4
    bltu   t0, t1, 1b
#endif
	
    call   main
