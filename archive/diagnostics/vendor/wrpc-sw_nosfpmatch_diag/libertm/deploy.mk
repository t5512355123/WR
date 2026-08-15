ERTM_VERSION ?= $(shell git describe --always --dirty | sed 's;libertm-v;;' )
DEPLOY_TARGET ?= /acc/local/L867/drv/ertm/$(ERTM_VERSION)
TOOLS = ../tools/uart-bootloader/usb-bootloader.py ertm-cli udev-find

deploy: $(LIBS) libertm.h $(TOOLS) ertm-setup
	mkdir -p $(DEPLOY_TARGET)/lib $(DEPLOY_TARGET)/include/hw \
		$(DEPLOY_TARGET)/tools $(DEPLOY_TARGET)/bin
	ln -s ../pyenv $(DEPLOY_TARGET)
	install -b libertm.h ../boards/ertm14/ertm-common.h -C $(DEPLOY_TARGET)/include
	install -b ../include/hw/wrc_diags_regs.h -C $(DEPLOY_TARGET)/include/hw
	install -b $(TOOLS) -C $(DEPLOY_TARGET)/tools
	(cd $(DEPLOY_TARGET)/bin ; ln -sf ../tools/* .)
	install -b ertm-setup -C $(DEPLOY_TARGET)/bin
