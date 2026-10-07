-include Makefile.specific
CONFIG_PCI ?= y
CONFIG_VME ?= n

CFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
CFLAGS += -Wall -Werror -ggdb -O2 -fPIC

GIT_VERSION    := $(shell git describe --always --dirty --long --tags)
SO_VERSION_XYZ := $(shell git describe --tags --abbrev=0 | grep -o -E "[0-9]+\.[0-9]+\.[0-9]")

ifeq ($(SO_VERSION_XYZ),)
	SO_VERSION_XYZ := 0
endif

PREFIX ?= /usr/local
DESTLIBDIR ?= $(PREFIX)/lib

LIB = libual.o
LIB_A = libual.a
LIB_SO = libual.so
LIB_SO_XYZ = $(LIB_SO).$(SO_VERSION_XYZ)

LOBJ := bus.o
LOBJ += bus-pci.o
LOBJ += route.o
LOBJ += irq.o

LIB_DEP :=

ifeq ($(CONFIG_VME), y)
LIBVME_A = $(VMEBRIDGE)/lib
LIBVME_H = $(VMEBRIDGE)/include
CFLAGS += -DCONFIG_VME
CFLAGS += -DVERSION="\"$(GIT_VERSION)\""
CFLAGS += -I$(LIBVME_H) -I$(LIBVME_A)
LDFLAGS += -L$(LIBVME_A) -lvmebus
LOBJ += bus-vme.o
LIB_DEP += $(LIBVME_A)/libvmebus.a
endif

LIB_DEP += $(LOBJ)

CC ?= $(CROSS_COMPILE)gcc
AR ?= $(CROSS_COMPILE)ar
RANLIB ?= $(CROSS_COMPILE)ranlib
MV ?= mv

all: libs

libs: $(LIB_A) $(LIB_SO)

%.o:%.c
	$(CC) $(CFLAGS) -c $^ -o $@

$(LIB_A): $(LIB_DEP)
ifeq ($(CONFIG_VME), y)
	$(AR) r tmp$@ $(LOBJ)
# transform a thin library into a normal one
	printf "create $@\naddlib tmp$@\naddlib $(LIBVME_A)/libvmebus.a\nsave\nend" | $(AR) -M
	$(RM) tmp$@
else
	$(AR) r $@ $(LOBJ)
endif
	$(RANLIB) $@

$(LIB_SO_XYZ): $(LIB_A)
	$(CC) -shared -o $@ -Wl,--whole-archive,-soname,$@.$(VERSION) $^ -Wl,--no-whole-archive -lrt

$(LIB_SO): $(LIB_SO_XYZ)
	ln -sf $< $@

clean:
	-$(RM) -rf $(LIB) $(LIB_A) $(LIB_SO) $(LIB_SO_XYZ)
	-$(RM) -rf *.{a,so,o}
	-$(RM) -rf html Doxyfile Doxyfile.template

cleanall: clean

install: libs
	install -d $(DESTLIBDIR)
	install -m 0644 $(LIB_A) $(DESTLIBDIR)
	install -m 0755 $(LIB_SO_XYZ) $(DESTLIBDIR)
	ln -sf $(LIB_SO_XYZ) $(DESTLIBDIR)/$(LIB_SO)

uninstall:
	rm -f $(DESTLIBDIR)/$(LIB_A) $(DESTLIBDIR)/$(LIB_SO) $(DESTLIBDIR)/$(LIB_SO_XYZ)
	rmdir --ignore-fail-on-non-empty $(DESTLIBDIR)

.PHONY: install uninstall clean all
