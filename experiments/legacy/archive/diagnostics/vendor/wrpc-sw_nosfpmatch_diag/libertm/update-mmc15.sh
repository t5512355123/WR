#!/bin/sh

../tools/uart-bootloader/usb-bootloader.py \
	-p /dev/ttyUSB0 \
	-b ertm14m1 \
	-s 115200 \
	-f mcu \
		/user/dcobas/ertm14/tom-bitstreams/Mar25/mmc15_main.bin
