-include ../.config
EB    ?= no
SDBFS ?= no

CFLAGS = -Wall -Werror -ggdb -I../include -I../liblinux -I../liblinux/extest
CFLAGS += -D__GIT_VER__="\"$(GIT_VER)\"" -D__GIT_USR__="\"$(GIT_USR)\""
CFLAGS += -DBUILD_HOST
CFLAGS += --std=gnu99
CFLAGS += -I../libertm
CFLAGS += -I../boards/ertm14
CFLAGS += -I../softpll

LDFLAGS = $(TOOLS_LDFLAGS) -lutil -L../liblinux -ldevmap -L../liblinux/extest -lextest
ALL    = genraminit genramvhd genrammif
#ALL   += wrpc-w1-read wrpc-w1-write
ALL   += pfilter-builder
ALL   += mapper
ALL   += wrpc-vuart
ALL   += wrpc-load
ALL   += wr-streamers
ALL   += wrpc-diags
ALL   += gensdbfs
ifneq ($(CONFIG_TARGET_WR_SWITCH),y)
ALL   += wrpc
endif
ALL-$(CONFIG_WRPC_PPSI)  += wrpc-dump

ALL+= $(ALL-y)

ifneq ($(EB),no)
ALL += eb-w1-write
endif
ifneq ($(SDBFS),no)
ALL += sdb-wrpc.bin
endif

ifeq ($(SUPPORT_CERN_VMEBRIDGE), y)
LIBVME_LIB = $(VMEBRIDGE)/lib
LIBVME_INC = $(VMEBRIDGE)/include
LIBVME_CFLAGS += -I$(LIBVME_INC) -I$(LIBVME_LIB) -DSUPPORT_CERN_VMEBRIDGE
LIBVME_LDFLAGS += -L$(LIBVME_LIB) -lvmebus
endif

AS		= as
LD		= ld
CC		= gcc
CPP		= $(CC) -E
AR		= ar
NM		= nm
STRIP		= strip
OBJCOPY		= objcopy
OBJDUMP		= objdump

all:	$(ALL)

%:	%.c
	$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@

wrpc-w1-read: wrpc-w1-read.c ../dev/w1.c ../dev/w1-eeprom.c ../dev/w1-hw.c
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

wrpc-w1-write: wrpc-w1-write.c ../dev/w1.c ../dev/w1-eeprom.c ../dev/w1-hw.c
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

eb-w1-write: eb-w1-write.c ../dev/w1.c ../dev/w1-eeprom.c eb-w1.c
	$(CC) $(CFLAGS) -I $(EB) $^ $(LDFLAGS) -o $@ -L $(EB)/.libs -letherbone

GENSDBFS_SRCS = gensdbfs.c

gensdbfs: $(GENSDBFS_SRCS)
	${CC} $(CFLAGS) -o $@ $(GENSDBFS_SRCS)

sdb-wrpc.bin: sdbfs
	$(SDBFS)/gensdbfs $< $@

vpath dump_mem_ppsi_wrpc.c ../ppsi/tools
wrpc-dump: wrpc-dump.c dump-info-host.o time_lib.o dump_mem_ppsi_wrpc.o
	$(CC) $(CFLAGS) -include $(AUTOCONF) -I../ppsi/include -I../ppsi/arch-wrpc -I../ppsi/arch-wrpc/include -I.. \
	-I ../softpll \
	$^ -o $@

time_lib.o: time_lib.c
	$(CC) $(CFLAGS) -include $(AUTOCONF) -I../ppsi/include -I../ppsi/arch-wrpc/include -I.. \
	-I ../softpll -c \
	$^ -o $@

dump_mem_ppsi_wrpc.o: ../ppsi/tools/dump_mem_ppsi_wrpc.c
dump_mem_ppsi_wrpc.o: CFLAGS+=-include $(AUTOCONF) -I../ppsi/include -I../ppsi/arch-wrpc -I../ppsi/arch-wrpc/include -I.

wr-streamers: wr-streamers.c
	$(CC) $(CFLAGS)  $^ $(LDFLAGS) -o $@ -lreadline

wrpc-diags: wrpc-diags.c
	$(CC) $(CFLAGS)  $^ $(LDFLAGS) -o $@ -lreadline

wrpc-vuart: wrpc-vuart.o vuart_lib.o
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

wrpc-load: wrpc-load.o
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

wrpc: wrpc.o
	$(CC) $(CFLAGS) $^ $(TOOL_LDFLAGS) $(LIBVME_LDFLAGS) -o $@  ../libertm/libertm.a -ludev -lm

wrpc.o: wrpc.c
	$(CC) -c $(CFLAGS) $< $(LIBVME_CFLAGS) -o $@

pfilter-builder: pfilter-builder.c
	$(CC) $(CFLAGS)  -include ../include/generated/autoconf.h \
		$@.c $(LDFLAGS) -o $@

# FIXME: this stuff must be reorganized
ertm14-uart-link.o: ertm14-uart-link.h
ertm-serial: ertm-serial.c ertm14-uart-link.o
	$(CC) $(CFLAGS) -include ../include/generated/autoconf.h \
		-I ../lib \
		$^ $(LDFLAGS) -o $@

# combine structures back to the object file
dump-wrpc-info-host.bin: ../dump-info.o
	$(CROSS_COMPILE)objcopy --only-section=.data.dump_wrpc_info \
		-O binary $< $@

dump-ppsi-info-host.bin: ../dump_mem_ppsi_wrpc.o
	$(CROSS_COMPILE)objcopy --only-section=.data.dump_ppsi_info \
		-O binary $< $@

dump-info-host.o: dump-wrpc-info-host.bin dump-ppsi-info-host.bin
	$(AS) makebin.S -o $@

../dump-info.o: ../dump-info.c
	$(MAKE) -C .. dump-info.o

../dump_mem_ppsi_wrpc.o: dump_mem_ppsi_wrpc.c
	$(MAKE) -C .. dump_mem_ppsi_wrpc.o

clean:
	rm -f $(ALL) *.o *~ dump-info-host.bin
