# All files are under A (short for ARCH): I'm lazy
A := arch-$(ARCH)

# classic cross-compilation tool-set
SIZE =		$(CROSS_COMPILE)size

CFLAGS += -Itools

# needed for --gc-sections option of ld
PPSI_O_LDFLAGS = --entry=main

# Prevent a warning for a missing prototype in pp_printf, bug since ever
ARCH_PP_PRINTF_CFLAGS += -include ../$A/include/strnlen.h

arch-spec-c = $A/wrs-startup.c \
	$A/hal_minirpc.c \
	$A/main-loop.c \
	$A/wrs-io.c \
	$A/wrs-conf.c \
	$A/wrs-calibration.c \
	$A/wrs-port.c \
	$A/wrs-ipcserver.c \
	$A/shmem.c \
	$A/util.c \
	lib/cmdline.c \
	lib/conf.c \
	lib/libc-functions.c \
	lib/dump-funcs.c \
	lib/drop.c \
	lib/assert.c \
	lib/div64.c \
	lib/time-arith.c

arch-spec-o = $(patsubst %.c,%.o,$(arch-spec-c))

OBJ-y += $(arch-spec-o)

# build symbolic links for libwr
libwr_headers = hal_shmem.h \
	generic_fsm.h\
	sfp_lib.h\
	util.h\
	shmem.h	\
	timeout.h

libwr_headers_in_ppsi= $(addprefix $A/include/libwr/,$(libwr_headers))

all: $(TARGET)
$(arch-spec-o) : $(libwr_headers_in_ppsi)


$(libwr_headers_in_ppsi):
	@f=$(notdir $@); \
	echo "Creating symbolic link to include/libwr/$$f";\
	ln -sf ../../../../libwr/include/libwr/$$f  $@

# build symbolic links for source files in libwr
libwr_source = hal_minirpc.c

libwr_source_in_ppsi= $(addprefix $A,/$(libwr_source))

$(arch-spec-o) : $(libwr_source_in_ppsi)

$(libwr_source_in_ppsi):
	@f=$(notdir $@); \
	echo "Creating symbolic link to $$f";\
	ln -sf ../../libwr/$$f  $@

# build symbolic links for userspace files from wrs
wrs_userspace_headers = hal_exports.h

wrs_userspace_headers_in_ppsi = $(addprefix $A/include/,$(wrs_userspace_headers))

$(arch-spec-o): $(wrs_userspace_headers_in_ppsi)

$(wrs_userspace_headers_in_ppsi):
	@f=$(notdir $@); \
	echo "Creating symbolic link to include/$$f";\
	ln -sf ../../../include/$$f  $@


export size_db_file:=size_wrs_db.txt
export size_info_file:=size_wrs_info.txt

# We only support "wrs" time operations
TIME = wrs
include time-$(TIME)/Makefile

# Unix time operations are always included as a fallback
include time-unix/Makefile
CFLAGS += -Iproto-ext-whiterabbit -Iproto-standard

# mini-rpc directory contains minipc library
export CROSS_COMPILE
MINIPC_DIR := $A/mini-rpc
MINIPC_LIB := $(MINIPC_DIR)/libminipc.a
CFLAGS += -I$(MINIPC_DIR)
.PHONY: $(MINIPC_LIB)
$(MINIPC_LIB):
	$(MAKE) -C $(MINIPC_DIR) CFLAGS_OPTIMIZATION="$(CFLAGS_OPTIMIZATION)"

OBJ-y += $(MINIPC_LIB)

clean::
	rm -f \
		$(libwr_headers_in_ppsi) \
		$(libwr_source_in_ppsi) \
		$(wrs_userspace_headers_in_ppsi)

# to build the target, we need -lstd again, in case we call functions that
# were not selected yet (e.g., pp_init_globals() ).
$(TARGET): $(TARGET).o
	$(CC) -Wl,-Map,$(TARGET).map2 -o $@ $(TARGET).o -lrt
	$(SIZE) $@
	./arch-wrs/save_size.sh $(SIZE) $@
	tail -20 $(size_info_file)


