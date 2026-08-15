obj-y += \
	dev/simple_uart.o \
	dev/console.o \
	dev/console-uart.o

obj-$(CONFIG_EMBEDDED_NODE) += \
	dev/console-net.o \
	dev/endpoint.o \
	dev/ep_pfilter.o \
	dev/minic.o \
	dev/syscon.o \
	dev/sfp.o \
	dev/rxts_calibrator.o \
	dev/flash.o \
	dev/gpio.o \
	dev/bb_spi.o \
	dev/bb_i2c.o \
	dev/spi_flash.o \
	dev/iuart.o \
	dev/ltc695x.o \
	dev/ad9520.o \
	dev/i2c_eeprom.o \
	dev/sdbfs.o \
	dev/storage.o \
	dev/storage-flash.o \
	dev/storage-fram.o \
	dev/storage-w1.o \
	dev/storage-i2c.o \
	dev/storage-sfp.o \
	dev/storage-cal.o \
	dev/storage-mac.o \
	dev/storage-init.o \
	dev/fine_pulse_generator.o \
	dev/netif.o \
	dev/leds.o \
	dev/si57x.o \
	dev/wdiags.o \
        dev/clock_monitor.o

obj-$(CONFIG_WR_NODE) += \
	dev/sensors.o \
	dev/pps_gen.o

obj-$(CONFIG_TARGET_WR_SWITCH) += dev/timer-wrs.o dev/gpio.o
obj-$(CONFIG_PUTS_SYSLOG) += dev/puts-syslog.o

obj-$(CONFIG_DAC_LOG) += dev/dac_log.o
obj-$(CONFIG_W1) +=		dev/w1.o	dev/w1-hw.o	dev/w1-shell.o
obj-$(CONFIG_W1_EEPROM) +=	dev/w1-eeprom.o
obj-$(CONFIG_W1_TEMP) +=	dev/temp-w1.o dev/w1-temp.o

obj-$(CONFIG_TEMP_SENSORS) += dev/temperature.o
obj-$(CONFIG_TEMP_FAKE) += dev/temp-fake.o

obj-$(CONFIG_ETHERBONE) += dev/etherbone.o

obj-$(CONFIG_IPMI_CONSOLE) += dev/console-ipmi.o

# board specific dev
obj-$(CONFIG_TARGET_GENERIC_PHY_8BIT) += \

obj-$(CONFIG_TARGET_GENERIC_PHY_16BIT) += \

obj-$(CONFIG_TARGET_WR_SWITCH) += \

obj-$(CONFIG_TARGET_AFCZ) += \

obj-$(CONFIG_TARGET_AFCZ_V2) += \

obj-$(CONFIG_TARGET_SIS8300KU) += \

obj-$(CONFIG_TARGET_ERTM14) += \
				dev/24aa025.o \
				dev/74x595.o \
				dev/ad7888.o \
				dev/ad951x.o \
				dev/ad9910.o \

obj-$(CONFIG_TARGET_PXIE_FMC) += \
				dev/24aa025.o \

obj-$(CONFIG_TARGET_WR2RF_VME) += \
				dev/24aa025.o \

# Filter rules are selected according to configuration, but we may
# have more than one. Note: the filename is reflected in symbol names,
# so they are hardwired in ../Makefile (and ../tools/pfilter-builder too)

dev/ep_pfilter.o: $(pfilter-y)

dev/storage.o: $(sdbfsimg-y)

$(pfilter-y): tools/pfilter-builder
	./tools/pfilter-builder include/generated/

$(sdbfsimg-y): tools/gensdbfs
	./tools/gensdbfs $(sdbfs_swap_bytes-y) -c include/generated/sdbfs-default.h tools/sdbfs tools/sdbfs-default.bin
