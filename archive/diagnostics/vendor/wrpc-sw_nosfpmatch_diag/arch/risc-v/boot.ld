OUTPUT_FORMAT("elf32-littleriscv")
ENTRY(_start)
MEMORY
{
    preboot :
      ORIGIN = 0
      LENGTH = 64

    ram :
      ORIGIN = 196608 - 8192
      LENGTH = 8192
    datacopy :
      ORIGIN = 196608 - 2048 - 0
      LENGTH = 0
    stack :
      ORIGIN = 196608 - 2048
      LENGTH = 2048
}
SECTIONS
{
.boot : { *(.boot) } > preboot

    .text :
    {
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
    } > ram
    _fdata = ADDR(.data);
    . = ALIGN(4);
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
