obj-$(CONFIG_TARGET_SPEC_SILABS) += boards/spec_silabs/board.o boards/generic/generic-storage.o

obj-$(CONFIG_TARGET_GENERIC_PHY_8BIT) += boards/generic/board.o boards/generic/generic-storage.o
obj-$(CONFIG_TARGET_GENERIC_PHY_16BIT) += boards/generic/board.o boards/generic/generic-storage.o
obj-$(CONFIG_TARGET_WR_SWITCH) += boards/wr-switch/main.o boards/wr-switch/gpio-wrs.o boards/wr-switch/ad9516.o
obj-$(CONFIG_TARGET_AFCZ_V1) += boards/afcz/board.o
obj-$(CONFIG_TARGET_AFCZ_V2) += boards/afcz/board.o
obj-$(CONFIG_TARGET_SIS8300KU) += boards/sis8300ku/board.o

obj-$(CONFIG_TARGET_ERTM14) += \
	boards/ertm14/board.o \
	boards/ertm14/console-ertm.o \
	boards/ertm14/ertm15_rf_distr.o \
	boards/ertm14/phy_calibration.o \
	boards/ertm14/rf_frame_transceiver.o \
	boards/ertm14/cmd_ertm14.o \
	boards/ertm14/common-uart-link.o \
	boards/ertm14/wrpc-uart-link.o \
	boards/ertm14/sdbfs-custom-image.o

obj-$(CONFIG_TARGET_PXIE_FMC) += boards/pxie-fmc/board.o
obj-$(CONFIG_TARGET_WR2RF_VME) += boards/wr2rf-vme/board.o  boards/wr2rf-vme/sdbfs-custom-image.o boards/ertm14/phy_calibration.o

boards/ertm14/sdbfs-custom-image.o: boards/ertm14/sdbfs-custom-image.h
boards/wr2rf-vme/sdbfs-custom-image.o: boards/wr2rf-vme/sdbfs-custom-image.h

boards/ertm14/sdbfs-custom-image.h: boards/ertm14/sdbfs tools/gensdbfs
	./tools/gensdbfs $(sdbfs_swap_bytes-y) -c boards/ertm14/sdbfs-custom-image.h boards/ertm14/sdbfs boards/ertm14/sdbfs-custom-image.bin

boards/wr2rf-vme/sdbfs-custom-image.h: boards/wr2rf-vme/sdbfs tools/gensdbfs
	./tools/gensdbfs $(sdbfs_swap_bytes-y) -c boards/wr2rf-vme/sdbfs-custom-image.h boards/wr2rf-vme/sdbfs boards/wr2rf-vme/sdbfs-custom-image.bin

boards-clean:
	rm -f boards/*/*.o
	rm -f boards/ertm14/sdbfs-custom-image.h
	rm -f boards/wr2rf-vme/sdbfs-custom-image.h
