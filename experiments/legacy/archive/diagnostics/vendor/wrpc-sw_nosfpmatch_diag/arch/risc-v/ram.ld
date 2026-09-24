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
    _fbss = ADDR(.sbss);
    . = ALIGN(4);
    _end = .;
    PROVIDE(_endram = ORIGIN(stack));
    PROVIDE(_fstack = ORIGIN(stack) + LENGTH(stack));
}
