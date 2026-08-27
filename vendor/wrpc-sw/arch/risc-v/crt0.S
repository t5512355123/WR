#define __ASSEMBLY__
#include "include/revision.h"
#include "ppsi/include/hw-specific/wrh.h"
#include "arch/risc-v/crt0.h"
#include "include/generated/autoconf.h"

.section .boot, "ax", @progbits

.global _start
_start:
    j      _entry

#ifdef CONFIG_INIT_COMMAND
    .extern build_init_readcmd_p
    .extern debug_boot_stage
    .extern debug_precrt_p_raw_at_reset_entry
    .extern debug_precrt_p_raw_after_data_init
    .extern debug_precrt_boot_magic
    .extern debug_precrt_boot_generation
    .extern debug_precrt_p_at_entry_history
#endif

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

#ifdef CONFIG_INIT_COMMAND
    /* Preserve a generation counter across CPU-only resets. */
    la     t0, debug_precrt_boot_magic
    lw     t1, 0(t0)
    li     t2, 0x424F4F54
    bne    t1, t2, 1f
    la     t0, debug_precrt_boot_generation
    lw     t1, 0(t0)
    addi   t1, t1, 1
    sw     t1, 0(t0)
    j      2f
1:
    sw     t2, 0(t0)
    li     t1, 1
    la     t0, debug_precrt_boot_generation
    sw     t1, 0(t0)
2:
    /* Mirror the pre-CRT entry values through the already-observed fixed
       .debug_boot marker word.  The tag nibbles let the hardware probe
       separate these snapshots from main()'s normal B000/B00x markers. */
    la     t0, debug_boot_stage
    li     t2, 0xE0000000
    or     t2, t2, t1
    sw     t2, 0(t0)
    la     t0, build_init_readcmd_p
    lw     t3, 0(t0)
    li     t2, 0xD0000000
    or     t2, t2, t3
    la     t0, debug_boot_stage
    sw     t2, 0(t0)

    /* Record p at each entry in a four-sample ring. */
    addi   t1, t1, -1
    andi   t1, t1, 3
    slli   t1, t1, 2
    la     t0, debug_precrt_p_at_entry_history
    add    t0, t0, t1
    la     t2, build_init_readcmd_p
    lw     t3, 0(t2)
    sw     t3, 0(t0)

    /* Capture p before any BSS clear or data initialization. */
    la     t0, build_init_readcmd_p
    lw     t1, 0(t0)
    la     t2, debug_precrt_p_raw_at_reset_entry
    sw     t1, 0(t2)
#endif

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

#ifdef CONFIG_INIT_COMMAND
    /* Capture p after BSS clear and the optional .data copy. */
    la     t0, build_init_readcmd_p
    lw     t1, 0(t0)
    la     t2, debug_precrt_p_raw_after_data_init
    sw     t1, 0(t2)
#endif
	
    call   main
