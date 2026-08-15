#!/bin/sh

../tools/uart-bootloader/usb-bootloader.py \
	-p /dev/ttyUSB1 \
	-b ertm14m0 \
	-s 115200 \
	-f mcu \
		/user/dcobas/ertm14/tom-bitstreams/Mar25/mmc14_main.bin
