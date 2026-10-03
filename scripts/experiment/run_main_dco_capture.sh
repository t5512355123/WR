#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=$(mktemp -d "$repo/build/main-dco-capture.XXXXXX")
# Generated reference fixture: exact prior committed production RTL, renamed
# mechanically only to allow both modules in one simulator. Never edit archive.
git -C "$repo" show eb12a587415fb0c55f620360ddb66c1066a0676b:quartus/si5340a_controller_dco.v |
  sed 's/^module si5340a_controller_dco /module baseline_si5340a_controller_dco /' > "$out/baseline.v"
sources=( "$repo/scripts/experiment/tb_main_dco_capture.sv" "$out/baseline.v"
  "$repo/quartus/si5340a_controller_dco.v" "$repo/quartus/i2c_bus_controller_dco.v"
  "$repo/quartus/si5340a_i2c_reg_controller_dco.v"
  "$repo/quartus/si5340_controller/initial_config.v"
  "$repo/quartus/si5340_controller/clock_divider.v"
  "$repo/quartus/si5340_controller/edge_detector.v"
  "$repo/quartus/si5340_controller/si5340a_clk_frq_sel_gen.v"
  "$repo/quartus/si5340_controller/si5340a_freq_prameter_selector.v" )
cd "$out"
if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
  iverilog -g2012 -s tb_main_dco_capture -o test.vvp "${sources[@]}"
  vvp test.vvp
else
  sim=${MODELSIM_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/modelsim_ase/linuxaloem}
  "$sim/vlib" work
  "$sim/vlog" -sv "${sources[@]}"
  "$sim/vsim" -c -voptargs=+acc work.tb_main_dco_capture \
    -do 'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'
fi
