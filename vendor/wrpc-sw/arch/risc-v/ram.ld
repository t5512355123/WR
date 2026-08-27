OUTPUT_FORMAT("elf32-littleriscv")
ENTRY(_start)
MEMORY
{
    ram :
 ORIGIN = 0x00000000,
 LENGTH = 196608 - 2048 - 0
    datacopy :
        ORIGIN = 196608 - 2048 - 0
 LENGTH = 0
    stack :
 ORIGIN = 196608 - 2048
 LENGTH = 2048
}
SECTIONS
{
    .text :
    {
 *(.boot)
 *(.text)
 *(.text.*)
 *(.gnu.linkonce.t.*)
    } > ram
    .rodata :
    {
 *(.rdata)
 *(.rodata)
 *(.rodata.*)
 *(.srodata.*)
 *(.gnu.linkonce.r.*)
    } > ram
    .data :
    {
 *(.data)
 *(.data.*)
 *(.gnu.linkonce.d.*)
    } > ram
    . = ALIGN(4);
    _gp = . + 0x800;
    .sdata :
    {
 *(.sdata)
 *(.sdata.*)
 *(.gnu.linkonce.s.*)
 . = ALIGN(4);
    } > ram
    _fdata = ADDR(.data);
    _edata = .;
    .sbss :
    {
 *(.sbss)
 *(.sbss.*)
 *(.gnu.linkonce.sb.*)
    } > ram
    .bss :
    {
 *(.bss)
 *(.bss.*)
 *(.gnu.linkonce.b.*)
 *(COMMON)
    } > ram
    .debug_boot 0x0002e000 (NOLOAD) :
    {
 KEEP(*(.debug_boot))
    } > ram
    ASSERT(ADDR(.debug_boot) + SIZEOF(.debug_boot) <= ORIGIN(stack) - 0x1000, "debug_boot must stay at least 4 KiB below the stack")
    _fbss = ADDR(.sbss);
    . = ALIGN(4);
    _end = .;
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
    } > ram
    ASSERT(ADDR(.debug_precrt) + SIZEOF(.debug_precrt) <= ORIGIN(stack) - 0x1000, "debug_precrt must stay at least 4 KiB below the stack")
    PROVIDE(_endram = ORIGIN(stack));
    PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack));
}
