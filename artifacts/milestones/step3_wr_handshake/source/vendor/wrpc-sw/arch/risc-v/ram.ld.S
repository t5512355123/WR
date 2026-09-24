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

#if CONFIG_DATASIZE != 0
    _datacopy = ORIGIN(datacopy);
#endif
	
    /* End of RAM for checking stack overflows */
    PROVIDE(_endram = ORIGIN(stack));

    /* First location in stack is highest address in STACK */
    PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack));
}
