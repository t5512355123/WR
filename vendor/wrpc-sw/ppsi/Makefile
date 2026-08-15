#
# Alessandro Rubini for CERN, 2011,2013 -- public domain
#

# We are now Kconfig-based
WRPCSW_ROOT?=.
# Root of the main software, for now used only by WRPC. For other make it a
# current directory (".")
MAINSW_ROOT=$(WRPCSW_ROOT)
-include $(CURDIR)/$(MAINSW_ROOT)/.config

# We still accept command-line choices like we used to do.
# Also, we must remove the quotes from these Kconfig values
PROTO_EXTS ?= $(patsubst "%",%,$(CONFIG_EXTENSIONS))
ARCH ?= $(patsubst "%",%,$(CONFIG_ARCH))
CROSS_COMPILE ?= $(patsubst "%",%,$(CONFIG_CROSS_COMPILE))

# For "make config" to work, we need a valid ARCH
ifeq ($(ARCH),)
   ARCH = unix
endif

#### In theory, users should not change stuff below this line (but please read)

# classic cross-compilation tool-set
AS              = $(CROSS_COMPILE)as
LD              = $(CROSS_COMPILE)ld
CC              = $(CROSS_COMPILE)gcc
CPP             = $(CC) -E
AR              = $(CROSS_COMPILE)ar
NM              = $(CROSS_COMPILE)nm
STRIP           = $(CROSS_COMPILE)strip
OBJCOPY         = $(CROSS_COMPILE)objcopy
OBJDUMP         = $(CROSS_COMPILE)objdump

ifeq ($(CONFIG_LTO),y)
AR              = $(CROSS_COMPILE)gcc-ar
endif

# To cross-build bare stuff (x86-64 under i386 and vice versa). We need this:
LD := $(LD) $(shell echo $(CONFIG_ARCH_LDFLAGS))
CC := $(CC) $(shell echo $(CONFIG_ARCH_CFLAGS))
# (I apologize, but I couldn't find another way to remove quotes)

# Instead of repeating "ppsi" over and over, bless it TARGET
TARGET = ppsi

# we should use linux/scripts/setlocalversion instead...
VERSION = $(shell git describe --always --dirty)

# CFLAGS to use. Both this Makefile (later) and app-makefile may grow CFLAGS
CFLAGS = $(USER_CFLAGS)
CFLAGS += -Wall -Wstrict-prototypes -Wmissing-prototypes -Werror
CFLAGS += -ffunction-sections -fdata-sections

export CFLAGS_OPTIMIZATION:= ${shell echo $(CONFIG_OPTIMIZATION)}

CFLAGS += $(CFLAGS_OPTIMIZATION)

CFLAGS += -I$(MAINSW_ROOT)
CFLAGS += -I$(MAINSW_ROOT)/include
CFLAGS += -Iinclude -fno-common
CFLAGS += -DPPSI_VERSION=\"$(VERSION)\"

# ppsi directory (can be relative).
PPSI=.

# Declare the variable as a simply expanded variable
OBJ-y :=

include $(PPSI)/arch-$(ARCH)/Makefile

include $(PPSI)/ppsi.mk

export CFLAGS

# And this is the rule to build our target.o file. The architecture may
# build more stuff. Please note that ./MAKEALL looks for $(TARGET)
# (i.e., the ELF which is either the  output or the input to objcopy -O binary)
#
# The object only depends on OBJ-y because each subdirs added needed
# libraries: see proto-standard/Makefile as an example.

$(TARGET).o: $(OBJ-y)
	$(LD) --gc-sections -Map $(TARGET).map1 -r -o $@ $(PPSI_O_LDFLAGS) \
		--start-group $(OBJ-y) --end-group

$(TARGET).a: $(OBJ-y)
	$(AR) rc $@ $(OBJ-y)


$(OBJ-y): $(MAINSW_ROOT)/.config $(wildcard include/ppsi/*.h)

# Finally, "make clean" is expected to work
clean::
	rm -f $$(find . -name '*.[oa]' ! -path './scripts/kconfig/*') *.bin $(TARGET) *~ $(TARGET).map*

distclean: clean
	rm -rf include/config include/generated
	rm -f .config

# Explicit rule for $(CURDIR)/.config
# needed since -include XXX triggers build for XXX
$(CURDIR)/$(MAINSW_ROOT)/.config:
	@#Keep this dummy comment

# following targets from Makefile.kconfig
silentoldconfig:
	@mkdir -p include/config
	$(MAKE) -f Makefile.kconfig $@

scripts_basic config:
	$(MAKE) -f Makefile.kconfig $@

%config:
	$(MAKE) -f Makefile.kconfig $@

defconfig:
	@echo "Using unix_defconfig"
	@$(MAKE) -f Makefile.kconfig unix_defconfig

# "$(MAINSW_ROOT)/.config", when MAINSW_ROOT is "."
./.config .config: silentoldconfig
