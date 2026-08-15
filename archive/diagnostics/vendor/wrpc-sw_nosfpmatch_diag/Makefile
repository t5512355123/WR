# Tomasz Wlostowski for CERN, 2011,2012
-include $(CURDIR)/.config

# Set to 'n' to disable LTO, makes debugging much easier
# CONFIG_LTO=n

# use a cross compiler depending on architecture
CROSS_COMPILE_LM32 ?= lm32-elf-
CROSS_COMPILE_RISCV ?= riscv32-elf-

CROSS_COMPILE-$(CONFIG_ARCH_LM32) ?= $(CROSS_COMPILE_LM32)
CROSS_COMPILE-$(CONFIG_ARCH_RISCV) ?= $(CROSS_COMPILE_RISCV)

# use compressed instructions for RISCV
USE-COMP-INSTR-$(CONFIG_RISCV_COMP_INSTR) = c

# use a cross compiler for all architectures
CROSS_COMPILE ?= $(CROSS_COMPILE-y)

ifeq ($(CONFIG_ARCH_LM32),y)
CPU_ARCH = LM32
endif
ifeq ($(CONFIG_ARCH_RISCV),y)
CPU_ARCH = RISCV
endif


ifdef CONFIG_HOST_PROCESS
  CROSS_COMPILE =
endif

export CROSS_COMPILE
export CONFIG_ABSCAL

CC =		$(CROSS_COMPILE)gcc
LD =		$(CROSS_COMPILE)ld
OBJDUMP =	$(CROSS_COMPILE)objdump
OBJCOPY =	$(CROSS_COMPILE)objcopy
SIZE =		$(CROSS_COMPILE)size


AUTOCONF = $(CURDIR)/include/generated/autoconf.h

export AUTOCONF

PPSI = ppsi

# list of file extensions to be copied for MAKEALL script
MAKEALL_COPY_LIST=.bin .elf

# we miss CONFIG_ARCH_LM32 as we have no other archs by now
obj-$(CONFIG_ARCH_LM32) = arch/lm32/crt0.o arch/lm32/irq.o
obj-$(CONFIG_ARCH_RISCV) = arch/risc-v/crt0.o arch/risc-v/irq.o arch/risc-v/irq_helper.o
# silently assume WR_NODE for the next two
LDS-$(CONFIG_ARCH_LM32)   = arch/lm32/ram.ld
LDS-$(CONFIG_ARCH_RISCV)  = arch/risc-v/ram.ld
LDS-$(CONFIG_TARGET_WR_SWITCH) = arch/lm32/ram-wrs.ld
LDS-$(CONFIG_HOST_PROCESS) =

obj-$(CONFIG_WR_NODE)   += wrc_main.o
obj-$(CONFIG_WR_NODE_SIM) += wrc_main_sim.o
obj-$(CONFIG_TARGET_WR_SWITCH) += ipc/minipc-mem-server.o ipc/rt_ipc.o

# add search path but only for dump_mem_ppsi_wrpc.c
vpath dump_mem_ppsi_wrpc.c ppsi/tools
dump_mem_ppsi_wrpc.o: CFLAGS+=-Itools -fno-lto
# for include dump-info_ppsi.h
dump-info.o: CFLAGS+=-Ippsi/tools -fno-lto

# our linker script is preprocessed, so have a rule here
%.ld: %.ld.S $(AUTOCONF)
	$(CC) -include $(AUTOCONF) -E -P $*.ld.S -o $@


cflags-y = -MMD -ffreestanding -include $(AUTOCONF)
cflags-y += -idirafter /usr/include/newlib
cflags-y += -Iinclude -I. -Isoftpll -Iipc -Ipp_printf
cflags-$(CONFIG_LTO) += -flto

# Only for lm32
cflags-$(CONFIG_ARCH_LM32)  +=  -Iinclude/std
cflags-$(CONFIG_ARCH_RISCV) +=  -Iinclude/std

cflags-$(CONFIG_WRPC_PPSI) += \
	-I$(PPSI)/arch-wrpc \
	-I$(PPSI)/proto-ext-whiterabbit \
	-I$(PPSI)

# in order to build tools/wrpc-dump, we need these flags, even for wrs builds
cflags-y += \
	-I$(PPSI)/arch-wrpc/include \
	-I$(PPSI)/include

ifdef CONFIG_WRPC_PPSI
# we should use linux/scripts/setlocalversion instead...
PPSI_VERSION := $(shell cd ppsi; git describe --always --dirty)

cflags-y += -DPPSI_VERSION=\"$(PPSI_VERSION)\"
OBJ-y :=

ARCH=wrpc
include $(PPSI)/ppsi.mk
obj-y += $(OBJ-y)
endif

# Below, CONFIG_PPSI is wrong, as we can't build these for the host
obj-$(CONFIG_EMBEDDED_NODE) += \
	monitor/monitor_ppsi.o

cflags-$(CONFIG_ARCH_LM32) += -mmultiply-enabled -mbarrel-shift-enabled
cflags-$(CONFIG_ARCH_RISCV) += -march=rv32im$(USE-COMP-INSTR-y) -mabi=ilp32
ldflags-$(CONFIG_ARCH_LM32) = -mmultiply-enabled -mbarrel-shift-enabled \
	-nostdlib -T $(LDS-y)
ldflags-$(CONFIG_ARCH_RISCV) = -march=rv32im$(USE-COMP-INSTR-y) -mabi=ilp32 \
	-nostdlib -T $(LDS-y)
asflags-$(CONFIG_ARCH_RISCV) += -march=rv32im$(USE-COMP-INSTR-y) -mabi=ilp32
arch-files-$(CONFIG_ARCH_LM32) = $(OUTPUT).bram $(OUTPUT).vhd $(OUTPUT).mif
arch-files-$(CONFIG_ARCH_RISCV) = $(OUTPUT).bram $(OUTPUT).vhd $(OUTPUT).mif


# packet-filter rules: for CONFIG_VLAN we use both sets
pfilter-y                     := include/generated/pfilter-rules-novlan.h
pfilter-$(CONFIG_VLAN)        += include/generated/pfilter-rules-vlan.h
export pfilter-y

# sdbfs image
sdbfsimg-y	:=	include/generated/sdbfs-default.h
export sdbfsimg-y

sdbfs_swap_bytes-$(CONFIG_ARCH_LM32) =
sdbfs_swap_bytes-$(CONFIG_ARCH_RISCV) = -e

all:

include boards/boards.mk
include shell/shell.mk
include lib/lib.mk
include pp_printf/printf.mk
include dev/dev.mk
include softpll/softpll.mk
include host/host.mk

# ppsi already has div64 (the same one), so only pick it if not using ppsi.
ifndef CONFIG_WRPC_PPSI
  obj-y += pp_printf/div64.o
endif
# And always complain if we pick the libgcc division: 64/32 = 32 is enough here.
obj-$(CONFIG_ARCH_LM32)  += check-error.o
obj-$(CONFIG_ARCH_RISCV) += check-error.o


# add system check functions like stack overflow and check reset
obj-y += system_checks.o

CFLAGS = $(cflags-y) -Wall -Werror -Wstrict-prototypes \
	-ffunction-sections -fdata-sections -Os -ggdb

ldflags-$(CONFIG_LTO) += -flto

# Assembler Flags
ASFLAGS = -MD -I. $(asflags-y)

LDFLAGS = $(ldflags-y) \
	-Wl,--gc-sections -Os -lgcc

OBJS = $(obj-y)

OUTPUT-$(CONFIG_WR_NODE)   = wrc
OUTPUT-$(CONFIG_TARGET_WR_SWITCH) = rt_cpu
OUTPUT := $(OUTPUT-y)

GIT_VER = $(shell git describe --always --dirty | sed  's;^wr-switch-sw-;;')
GIT_USR = $(shell git config --get-all user.name)
export GIT_VER
export GIT_USR

# if user.name is not available from git use user@hostname
ifeq ($(GIT_USR),)
GIT_USR = $(shell whoami)@$(shell hostname)
endif

all: libertm
all: tools/genraminit tools/genramvhd tools/genrammif $(OUTPUT).elf $(arch-files-y)

.PRECIOUS: %.elf %.bin
.PHONY: all tools clean extest liblinux
.PHONY: libertm boards-clean

# we need to remove "ptpdump" support for ppsi if RAM size is small and
# we include etherbone
ifneq ($(CONFIG_RAMSIZE),131072)
  ifdef CONFIG_IP
    PPSI_USER_CFLAGS = -DCONFIG_NO_PTPDUMP
  endif
endif

ifeq ($(CONFIG_LTO),y)
  PPSI_USER_CFLAGS += -flto
endif

$(OUTPUT).elf: $(LDS-y) $(AUTOCONF) gitmodules config.o $(OBJS)
	$(CC) $(CFLAGS) -D__GIT_VER__="\"$(GIT_VER)\"" -D__GIT_USR__="\"$(GIT_USR)\"" -Wno-error -c revision.c
	${CC} -Wl,-Map,$(OUTPUT).map -o $@ revision.o config.o $(OBJS) $(LDFLAGS)
	${OBJDUMP} -d $(OUTPUT).elf > $(OUTPUT)_disasm.S
	$(SIZE) $@
	./save_size.sh $(SIZE) $@


OBJCOPY-TARGET-$(CONFIG_ARCH_LM32) = -O elf32-lm32 -B lm32
OBJCOPY-TARGET-$(CONFIG_ARCH_RISCV) = -O elf32-littleriscv -B riscv
OBJCOPY-TARGET-$(CONFIG_HOST_PROCESS) = -O elf64-x86-64 -B i386

config.o: .config
	grep CONFIG .config > .config.bin
	dd bs=1 count=1 if=/dev/zero 2> /dev/null >> .config.bin
	$(OBJCOPY) -I binary $(OBJCOPY-TARGET-y) .config.bin $@
	rm -f .config.bin

GENRAM_ENDIAN_FLAG-$(CONFIG_ARCH_LM32) =
GENRAM_ENDIAN_FLAG-$(CONFIG_ARCH_RISCV) = -l

%.bin: %.elf
	${OBJCOPY} -O binary $< $@

%.bram: %.bin tools/genraminit
	./tools/genraminit $(GENRAM_ENDIAN_FLAG-y) $< $(CONFIG_RAMSIZE) > $@

%.vhd: %.bin tools/genramvhd
	./tools/genramvhd -s $(CONFIG_RAMSIZE) $*.bin > $@

%.mif: %.bin tools/genrammif
	./tools/genrammif $(GENRAM_ENDIAN_FLAG-y) $*.bin $(CONFIG_RAMSIZE) > $@

clean: boards-clean
	rm -f $(OBJS) config.o pconfig.o revision.o $(OUTPUT).elf \
		$(LDS) \
		$(OUTPUT).bin rules-*.bin \
		$(OUTPUT).bram $(OUTPUT).vhd $(OUTPUT).mif $(OUTPUT)_disasm.S
	rm -f $(OBJS:.o=.d)
	$(MAKE) -C $(PPSI) clean
	$(MAKE) -C tools clean
	$(MAKE) -C liblinux clean
	$(MAKE) -C liblinux/extest clean
	$(MAKE) -C libertm clean

distclean: clean
	rm -rf include/config
	rm -rf include/generated
	rm -f $(addprefix *,$(MAKEALL_COPY_LIST))
	$(MAKE) -C $(PPSI) distclean

%.o:		%.c
	${CC} $(CFLAGS) $(PTPD_CFLAGS) $(INCLUDE_DIR) $(LIB_DIR) -c $< -o $@

liblinux:
	$(MAKE) -C liblinux CC=cc

libertm: $(AUTOCONF)
ifneq ($(CONFIG_TARGET_WR_SWITCH),y)
	$(MAKE) -C $@ CC=cc
endif

extest:
	$(MAKE) -C liblinux/extest CC=cc

# Build only the requested helper.  The upstream combined rule invokes the
# complete host-tools set, including wrpc-dump, while building the firmware.
tools/gensdbfs tools/pfilter-builder tools/genraminit tools/genramvhd tools/genrammif: .config $(AUTOCONF) gitmodules liblinux extest libertm
	$(MAKE) -C tools $(notdir $@)

tools: .config $(AUTOCONF) gitmodules liblinux extest libertm
	$(MAKE) -C tools

tools-diag: liblinux extest
	$(MAKE) -C tools wrpc-diags wrpc-vuart wr-streamers

# if needed, check out the submodules (first time only), so users
# who didn't read carefully the manual won't get confused
gitmodules:
	@echo "Checking out submodules"
	git submodule update --init
	touch gitmodules

# Explicit rule for $(CURDIR)/.config
# needed since -include XXX triggers build for XXX
$(CURDIR)/.config:
	@# Keep this dummy comment

# following targets from Makefile.kconfig
silentoldconfig:
	@mkdir -p include/config
	$(MAKE) quiet=quiet_ -f Makefile.kconfig $@

scripts_basic config:
	$(MAKE) quiet=quiet_ -f Makefile.kconfig $@

%_defconfig:
# copy config from WRPC repo
	@echo "Use configs/$@ as defconfig"
	@cp configs/$@ configs/tmp_defconfig
# concatenate ppsi's config if present
	@if [ -f ppsi/configs/$@ ]; then \
		echo "Use ppsi/configs/$@ as defconfig for PPSI"; \
		cat ppsi/configs/$@ >> configs/tmp_defconfig; \
	else \
		echo "ppsi/configs/$@ not found. Use default values for PPSI"; \
	fi
	$(MAKE) quiet=quiet_ -f Makefile.kconfig tmp_defconfig
	rm configs/tmp_defconfig

%config:
	$(MAKE) quiet=quiet_ -f Makefile.kconfig $@

defconfig:
	$(MAKE) quiet=quiet_ -f Makefile.kconfig spec_defconfig

# silentoldconfig is needed to regenerate autoconf.h
$(AUTOCONF): .config
	@mkdir -p include/config include/generated
	$(MAKE) -f Makefile.kconfig silentoldconfig

# Re-configure in case of Kconfig change
.config: Kconfig $(PPSI)/Kconfig_ppsi
	@mkdir -p include/config include/generated
	$(MAKE) -f Makefile.kconfig silentoldconfig

# This forces more compilations than needed, but it's useful
# (we depend on .config and not on include/generated/autoconf.h
# because the latter is touched by silentoldconfig at each build)
$(obj-y): .config $(wildcard include/*.h)

# if DEFCONFIG_NAME is not defined assign anything to it.
# It will limit matching of the target below
DEFCONFIG_NAME?="some_unique_dummy_name"

# copy compiled files for MAKEALL script
# files like $(DEFCONFIG_NAME).[elf|bin] etc.
$(addprefix $(DEFCONFIG_NAME),$(MAKEALL_COPY_LIST)):
	@cp -f $(OUTPUT)$(suffix $@) $@

makeall_copy: $(addprefix $(DEFCONFIG_NAME),$(MAKEALL_COPY_LIST))

PYTHON ?= python3
load:
		- killall -9 usb-bootloader.py
		- ./tools/uart-bootloader/usb-bootloader.py -b default -s 921600 -t -p "$(PORT)" wrc.bin

# print output name (used by MAKEALL)
output_name:
	echo $(OUTPUT)

$(OBJS): $(AUTOCONF)

-include $(OBJS:.o=.d)
