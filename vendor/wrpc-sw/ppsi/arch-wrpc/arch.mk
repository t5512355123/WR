# WRPCSW_ROOT shall be defined in the env by WRPC's Makefile
CFLAGS += -I$(WRPCSW_ROOT)/include -I$(WRPCSW_ROOT)/include/std -I$(WRPCSW_ROOT)/softpll

# Let's use the pp_printf we already have in wrpc-sw
CONFIG_NO_PRINTF = y

# All files are under A (short for ARCH): I'm lazy
A := $(PPSI)/arch-$(ARCH)

OBJ-y += \
	$A/wrpc-io.o \
	$A/wrpc-spll.o \
	$A/wrpc-calibration.o \
	$A/wrc_ptp_ppsi.o \
	$(PPSI)/lib/dump-funcs.o \
	$(PPSI)/lib/drop.o \
	$(PPSI)/lib/div64.o \
	$(PPSI)/lib/time-arith.o \
	$(PPSI)/lib/libc-functions.o \

OBJ-$(CONFIG_WRPC_FAULTS) += $A/faults.o

# We only support "wrpc" time operations
TIME := wrpc
include $(PPSI)/time-wrpc/Makefile
