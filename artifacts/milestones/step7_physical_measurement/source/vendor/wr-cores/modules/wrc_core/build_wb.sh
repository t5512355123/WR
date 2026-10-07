#!/bin/bash

mkdir -p doc
wbgen2 -D ./doc/wrc_syscon.html -p wrc_syscon_pkg.vhd -H record -V wrc_syscon_wb.vhd -C wrc_syscon_regs.h --cstyle struct --lang vhdl -K ../../sim/wrc_syscon_regs.vh wrc_syscon_wb.wb
wbgen2 -V wrc_cpu_csr_wb.vhd -p wrc_cpu_csr_wbgen2_pkg.vhd --hstyle record_full -Z --lang vhdl -K ../../testbench/wrc_core/wrc_cpu_csr_regs.vh wrc_cpu_csr.wb
