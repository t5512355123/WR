OUTPUT_FORMAT("elf32-littleriscv")
ENTRY(_start)

MEMORY
{
    ram :
	ORIGIN = 0x00000000,
	LENGTH = CONFIG_RAMSIZE - CONFIG_STACKSIZE - CONFIG_DATASIZE
    datacopy :
        ORIGIN = CONFIG_RAMSIZE - CONFIG_STACKSIZE - CONFIG_DATASIZE
	LENGTH = CONFIG_DATASIZE
    stack :
	ORIGIN = CONFIG_RAMSIZE - CONFIG_STACKSIZE
	LENGTH = CONFIG_STACKSIZE
}

SECTIONS
{
    /*--------------------------------------------------------------------*/
    /* Code and read-only segment                                         */
    /*--------------------------------------------------------------------*/

    /* text: Program code section */
    .text :
    {
	*(.boot)
	*(.text)
	*(.text.*)
	*(.gnu.linkonce.t.*)
    } > ram

    /* rodata: Read-only data */
    .rodata :
    {
	*(.rdata)
	*(.rodata)
	*(.rodata.*)
	*(.srodata.*)
	*(.gnu.linkonce.r.*)
    } > ram

    /*--------------------------------------------------------------------*/
    /* Initialized data segment                                           */
    /*--------------------------------------------------------------------*/

    /* data: Writable data */
    .data :
#if CONFIG_DATASIZE != 0
	AT (ORIGIN(datacopy))
#endif
    {
	*(.data)
	*(.data.*)
	*(.gnu.linkonce.d.*)
    } > ram

    /* Have _gp point to middle of sdata/sbss to maximize displacement range */
    . = ALIGN(4);
    _gp = . + 0x800;

    /* Writable small data segment */
    .sdata :
    {
	*(.sdata)
	*(.sdata.*)
	*(.gnu.linkonce.s.*)
	. = ALIGN(4);
    } > ram

    /* Bounds of data segment.  Be sure the end is aligned.  */
    _fdata = ADDR(.data);
    _edata = .;

    /*--------------------------------------------------------------------*/
    /* Uninitialized data segment                                         */
    /*--------------------------------------------------------------------*/

    /* Writable uninitialized small data segment */
    .sbss :
    {
	*(.sbss)
	*(.sbss.*)
	*(.gnu.linkonce.sb.*)
    } > ram

    /* bss: Uninitialized writeable data section */
    .bss :
    {
	*(.bss)
	*(.bss.*)
	*(.gnu.linkonce.b.*)
	*(COMMON)
    } > ram

    /* Fixed JTAG-observable boot marker, immediately before the stack. */
    .debug_boot 0x0002e000 (NOLOAD) :
    {
	KEEP(*(.debug_boot))
    } > ram
    ASSERT(ADDR(.debug_boot) + SIZEOF(.debug_boot) <= ORIGIN(stack) - 0x1000,
	   "debug_boot must stay at least 4 KiB below the stack")

    /* Bounds of bss segment. */
    _fbss = ADDR(.sbss);
    . = ALIGN(4);
    _end = .;

    /* Fixed pre-CRT capture area.  It is after _end so crt0.S does not
       clear the reset-entry sample while clearing BSS. */
    .debug_precrt 0x0002e010 (NOLOAD) :
    {
	KEEP(*(.debug_precrt_p_raw_at_reset_entry))
	KEEP(*(.debug_precrt_p_raw_after_data_init))
	KEEP(*(.debug_precrt_boot_magic))
	KEEP(*(.debug_precrt_boot_generation))
	KEEP(*(.debug_precrt_p_at_entry_history))
	KEEP(*(.debug_precrt_persistent_magic))
	KEEP(*(.debug_precrt_persistent_mode_master_stage))
	KEEP(*(.debug_precrt_persistent_lock_wait_substage))
	KEEP(*(.debug_precrt_persistent_boot_generation_at_stage))
	KEEP(*(.debug_precrt_persistent_stage_history))
	KEEP(*(.debug_precrt_persistent_spll_check_lock_stage))
	KEEP(*(.debug_precrt_persistent_spll_check_lock_channel))
	KEEP(*(.debug_precrt_persistent_spll_check_lock_state_value))
	KEEP(*(.debug_precrt_persistent_spll_check_lock_boot_generation))
	KEEP(*(.debug_precrt_persistent_command_stage))
	KEEP(*(.debug_precrt_persistent_command_rx_byte_count))
	KEEP(*(.debug_precrt_persistent_command_last_byte))
	KEEP(*(.debug_precrt_persistent_command_length))
	KEEP(*(.debug_precrt_persistent_command_hash))
	KEEP(*(.debug_precrt_persistent_command_boot_generation))
	KEEP(*(.debug_precrt_persistent_fault_magic))
	KEEP(*(.debug_precrt_persistent_fault_count))
	KEEP(*(.debug_precrt_persistent_fault_mcause))
	KEEP(*(.debug_precrt_persistent_fault_mepc))
	KEEP(*(.debug_precrt_persistent_fault_mtval))
	KEEP(*(.debug_precrt_persistent_fault_ra))
	KEEP(*(.debug_precrt_persistent_fault_sp))
	KEEP(*(.debug_precrt_persistent_fault_boot_generation))
	KEEP(*(.debug_precrt_persistent_fault_last_mode_master_stage))
	KEEP(*(.debug_precrt_persistent_fault_last_spll_check_lock_stage))
	KEEP(*(.debug_precrt_firmware_main_loop_reached))
	KEEP(*(.debug_precrt_shell_poll_loop_reached))
	KEEP(*(.debug_precrt_boot_init_sequence_done))
	KEEP(*(.debug_precrt_firmware_main_loop_generation))
	KEEP(*(.debug_precrt_shell_poll_generation))
	KEEP(*(.debug_precrt_boot_init_generation))
    } > ram
    ASSERT(ADDR(.debug_precrt) + SIZEOF(.debug_precrt) <= ORIGIN(stack) - 0x1000,
	   "debug_precrt must stay at least 4 KiB below the stack")

#if CONFIG_DATASIZE != 0
    _datacopy = ORIGIN(datacopy);
#endif
	
    /* End of RAM for checking stack overflows */
    PROVIDE(_endram = ORIGIN(stack));

    /* First location in stack is highest address in STACK */
    PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack));
}
