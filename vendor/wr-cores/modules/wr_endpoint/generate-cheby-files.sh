#!/bin/bash

cheby -i ep_mdio_regs.cheby --gen-hdl ep_mdio_regs.vhd
cheby -i ep_mdio_regs.cheby --gen-c ep_mdio_regs.h
cheby -i ep_mdio_regs.cheby --gen-consts ../../sim/regs/ep_mdio_regs.sv
