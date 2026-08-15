# to avoid ifdef as much as possible, I use the kernel trick for OBJ variables
OBJ-y += $(PPSI)/fsm.o $(PPSI)/diag.o $(PPSI)/timeout.o $(PPSI)/msgtype.o

# Include arch code. Each arch chooses its own time directory..
-include $(PPSI)/arch-$(ARCH)/arch.mk

# include pp_printf code, by default the "full" version. Please
# set CONFIG_PRINTF_NONE or CONFIG_PRINTF_XINT if needed.
ifndef CONFIG_NO_PRINTF
OBJ-y += pp_printf/pp-printf.o

pp_printf/pp-printf.o: $(wildcard pp_printf/*.[ch])
	CFLAGS="$(ARCH_PP_PRINTF_CFLAGS)" \
	$(MAKE) -C pp_printf pp-printf.o CC="$(CC)" LD="$(LD)" \
		CONFIG_PRINTF_64BIT=y CFLAGS_OPTIMIZATION="$(CFLAGS_OPTIMIZATION)"
endif

# We need this -I so <arch/arch.h> can be found
CFLAGS += -Iarch-$(ARCH)/include

# proto-standard is always included, as it provides default function
# so the extension can avoid duplication of code.
ifeq ($(CONFIG_HAS_EXT_WR),1)
  include $(PPSI)/proto-ext-whiterabbit/Makefile
endif
ifeq ($(CONFIG_HAS_EXT_L1SYNC),1)
  include $(PPSI)/proto-ext-l1sync/Makefile
endif
include $(PPSI)/proto-ext-common/Makefile
include $(PPSI)/proto-standard/Makefile

# ...and the TIME choice sets the default operations
CFLAGS += -DDEFAULT_TIME_OPS=$(TIME)_time_ops
CFLAGS += -DDEFAULT_NET_OPS=$(TIME)_net_ops

CFLAGS-$(CONFIG_ABSCAL) += -DCONFIG_ABSCAL=1
CFLAGS += $(CFLAGS-y)

