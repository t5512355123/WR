.PHONY: all objects clean libs so-lib static-lib

TARGET = libertm
CFLAGS += -fPIC -Wall -g
CFLAGS += -DCONFIG_TARGET_ERTM14

ERTM_UART_LOCATION = ../lib
ERTM_BOARD_LOCATION = ../boards/ertm14/
WRC_INCLUDES = ../include

CFLAGS += -I $(ERTM_UART_LOCATION) -I $(ERTM_BOARD_LOCATION)
CFLAGS += -I $(WRC_INCLUDES) -I../softpll
CFLAGS += -I../ppsi/arch-wrpc -I../ppsi/arch-wrpc/include -I../ppsi/include

GIT_VER ?= $(shell git describe --always --dirty | sed  's;^wr-switch-sw-;;')
GIT_USR ?= $(shell git config --get-all user.name)
GIT_URL ?= $(shell git remote show -n gitlab| sed -n 's; *Fetch URL: *\(.*\);\1;p')

CFLAGS += "-DVERSION=\"$(VERSION)\""
CFLAGS += "-DGIT_VER=\"$(GIT_VER)\""
CFLAGS += "-DGIT_USR=\"$(GIT_USR)\""
CFLAGS += "-DGIT_URL=\"$(GIT_URL)\""

LIBS = $(TARGET).a $(TARGET).so libertm_display.so
LIBOBJS = $(TARGET).o linux-uart-link.o common-uart-link.o udev-serial.o magics.o flock.o
LIBOBJS += semaph.o

all: libs main aux_logger udev-find
libs: $(LIBS)

$(TARGET).a $(TARGET).so: $(LIBOBJS)
$(TARGET).so:
	$(CC) -shared -o $@ $^
$(TARGET).a:
	$(AR) r $@ $^
$(TARGET).o: $(TARGET).h

main: main.o libertm.a display.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS) $(LDFLAGS) -lm -ludev

aux_logger: aux_logger.o libertm.a display.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS) $(LDFLAGS) -lm -ludev

udev-find: udev-find.o libertm.a
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS) $(LDFLAGS) -lm -ludev

common-uart-link.o: $(ERTM_BOARD_LOCATION)/common-uart-link.c
	$(CC) $(CFLAGS) -o $@ -c $^
ertm14-uart-link.o: $(ERTM_UART_LOCATION)/ertm14-uart-link.c
	$(CC) $(CFLAGS) -c -o $@ $^ $(LDLIBS) $(LDFLAGS)
linux-uart-link.o: $(ERTM_BOARD_LOCATION)/common-uart-link.h
libertm.o: libertm.h private.h

semaph: semaph.o
semaph: LDLIBS+=-lpthread

libertm_display.so: display.o
	$(LD) -shared -o $@ $^

clean:
	rm -f *.o *.a *.so
	rm -f serial ertm-serial main aux_logger udev-find

include deploy.mk
