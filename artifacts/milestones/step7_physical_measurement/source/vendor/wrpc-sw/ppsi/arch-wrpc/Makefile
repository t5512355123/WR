# use compressed instructions for RISCV
USE-COMP-INSTR-$(CONFIG_RISCV_COMP_INSTR) = c

CFLAGS-CPU-LM32  = -mmultiply-enabled -mbarrel-shift-enabled
CFLAGS-CPU-RISCV = -march=rv32im$(USE-COMP-INSTR-y) -mabi=ilp32

# use lm32 if not defined
CPU_ARCH ?= LM32

CFLAGS += -ffreestanding \
	-ffunction-sections -fdata-sections \
	-Itools -Iproto-standard \
	$(CFLAGS-CPU-$(CPU_ARCH))

include arch.mk

# TODOA: remove --no-gc-sections
PPSI_O_LDFLAGS = --no-gc-sections -u wrc_ptp_init

# wrpc/Makefile invokes this makefile with the ppsi.a target,
# if you can also call it directly.
all: $(TARGET).a

fsm.o: wrpcsw_root_check

wrpcsw_root_check:
	@if ! [ -e "$(WRPCSW_ROOT)/include/wrc.h" ]; then\
		echo "Error:  can't find $(WRPCSW_ROOT)/include/wrc.h" >&2; \
		echo "  please set WRPCSW_ROOT in your environment" >&2; \
		exit 1;\
	fi
