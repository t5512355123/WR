#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=$(mktemp -d "$repo/build/dco-liveness.XXXXXX")
cd "$out"
sources=( "$repo/scripts/experiment/tb_dco_liveness.sv" \
  "$repo/quartus/jtag_runtime_diag/si5340a_controller_dco.v" \
  "$repo/quartus/jtag_runtime_diag/i2c_bus_controller_dco.v" \
  "$repo/quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v" \
  "$repo/rtl/clock/si5340_controller/initial_config.v" \
  "$repo/rtl/clock/si5340_controller/clock_divider.v" \
  "$repo/rtl/clock/si5340_controller/edge_detector.v" \
  "$repo/rtl/clock/si5340_controller/si5340a_clk_frq_sel_gen.v" \
  "$repo/rtl/clock/si5340_controller/si5340a_freq_prameter_selector.v" )

if [[ -n ${IVERILOG_ROOT:-} ]]; then
  "$IVERILOG_ROOT/usr/bin/iverilog" -B "$IVERILOG_ROOT/usr/lib/x86_64-linux-gnu/ivl" \
    -g2012 -s tb_dco_liveness -o test.vvp "${sources[@]}"
  "$IVERILOG_ROOT/usr/bin/vvp" -M "$IVERILOG_ROOT/usr/lib/x86_64-linux-gnu/ivl" test.vvp "$@"
elif command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
  iverilog -g2012 -s tb_dco_liveness -o test.vvp "${sources[@]}"
  vvp test.vvp "$@"
else
  sim=${MODELSIM_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/modelsim_ase/bin}
  "$sim/vlib" work
  "$sim/vlog" -sv "${sources[@]}"
  "$sim/vsim" -c -voptargs=+acc work.tb_dco_liveness "$@" \
    -do 'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'
fi
