-include Makefile.specific
LIBUAL = ..
CFLAGS += -Wall -Werror -g -ggdb
CFLAGS += -I$(LIBUAL)/lib
CFLAGS += $(EXTRACFLAGS)
LDLIBS += -Wl,-Bstatic -L$(LIBUAL)/lib -lual
LDLIBS += -Wl,-Bdynamic -lrt

PROGS := ualmem

ifeq ($(CONFIG_VME), y)
CFLAGS += -DCONFIG_VME
endif

BINDESTDIR ?= $(PREFIX)/usr/local/bin

all: $(PROGS)

install:
	install -d $(BINDESTDIR)
	install -m 0755 $(PROGS) $(BINDESTDIR)

uninstall:
	rm -f $(addprefix $(BINDESTDIR)/,$(PROGS))
	rmdir --ignore-fail-on-non-empty $(BINDESTDIR)

clean:
	rm -f $(PROGS) *.o *~

.PHONY: install uninstall clean all
