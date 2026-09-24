#!/bin/bash

cheby -i lpdc_mdio_regs.cheby --gen-hdl lpdc_mdio_regs.vhd
cheby -i lpdc_mdio_regs.cheby --consts-style sv --gen-consts ../../../../sim/regs/lpdc_mdio_regs.sv
cheby -i lpdc_mdio_regs.cheby --gen-c lpdc_mdio_regs.h
