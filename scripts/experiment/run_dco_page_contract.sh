#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
sim=${MODELSIM_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/modelsim_ase/bin}
out=$(mktemp -d "$repo/build/dco-page-contract.XXXXXX")
cd "$out"
"$sim/vlib" work
"$sim/vlog" -sv "$repo/scripts/experiment/tb_dco_page_contract.sv" \
  "$repo/quartus/jtag_runtime_diag/si5340a_controller_dco.v" \
  "$repo/quartus/jtag_runtime_diag/i2c_bus_controller_dco.v" \
  "$repo/quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v" \
  "$repo/rtl/clock/si5340_controller/initial_config.v" \
  "$repo/rtl/clock/si5340_controller/clock_divider.v" \
  "$repo/rtl/clock/si5340_controller/edge_detector.v" \
  "$repo/rtl/clock/si5340_controller/si5340a_clk_frq_sel_gen.v" \
  "$repo/rtl/clock/si5340_controller/si5340a_freq_prameter_selector.v"
"$sim/vsim" -c -voptargs=+acc work.tb_dco_page_contract "$@" \
  -do 'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'
