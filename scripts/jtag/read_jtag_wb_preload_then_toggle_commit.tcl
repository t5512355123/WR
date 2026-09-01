# JTAG/Wishbone request-bundle CDC audit using a two-phase preload/commit
# protocol.  The shared implementation retains the previous full 64-bit
# completion P1/P2/P3 stability gate and the same 500-iteration workload.
#
# Usage:
#   quartus_stp -t read_jtag_wb_preload_then_toggle_commit.tcl \
#     ?iterations? ?board_filter?

set ::preload_then_toggle_commit 1
source [file join [file dirname [info script]] \
  read_jtag_wb_completion_stable_double_sample.tcl]
