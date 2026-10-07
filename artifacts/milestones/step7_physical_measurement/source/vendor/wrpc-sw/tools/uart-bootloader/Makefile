# and don't touch the rest unless you know what you're doing.
CROSS_COMPILE ?= riscv32-elf-

CC =		$(CROSS_COMPILE)gcc
LD =		$(CROSS_COMPILE)ld
OBJDUMP =	$(CROSS_COMPILE)objdump
OBJCOPY =	$(CROSS_COMPILE)objcopy
SIZE =		$(CROSS_COMPILE)size

AUTOCONF ?= ../../include/generated/autoconf.h

CFLAGS = -Werror -include $(AUTOCONF) -I../../ -Os -I../common -I.  -march=rv32im -mabi=ilp32  -ffunction-sections -fdata-sections -I../../include -DCONFIG_TARGET_ERTM14 -I../../pp_printf -DCONFIG_PRINT_BUFSIZE=128 -DCONFIG_BOOTLOADER
OBJS = ../../arch/risc-v/boot-crt0.o boot.o timer.o ../../dev/bb_spi.o ../../dev/gpio.o ../../dev/spi_flash.o  ../../dev/simple_uart.o ../../pp_printf/printf.o ../../pp_printf/vsprintf-mini.o ../../pp_printf/div64.o
LDS = ../../arch/risc-v/boot.ld
LDFLAGS =  -Os -march=rv32im -mabi=ilp32 -Wl,--gc-sections
OUTPUT=wrc-bootloader
BRAM_IMAGE=../../wrc-bootloader.ram

%.o:	%.c
		${CC} $(CFLAGS) -c $^ -o $@

%.o:	%.S
		${CC} $(CFLAGS) -c $^ -o $@

$(OUTPUT): $(LDS) $(OBJS)
	${CC} -o $(OUTPUT).elf -nostartfiles $(LDFLAGS) $(OBJS) -T $(LDS) -lgcc -lc
	${OBJCOPY} -O binary $(OUTPUT).elf $(OUTPUT).bin
	${OBJDUMP} -D $(OUTPUT).elf > disasm.S
	$(SIZE) $(OUTPUT).elf
	../genraminit -l $(OUTPUT).bin 32768 > $(BRAM_IMAGE)

clean:
	rm -f $(OBJS) $(OUTPUT).bin
