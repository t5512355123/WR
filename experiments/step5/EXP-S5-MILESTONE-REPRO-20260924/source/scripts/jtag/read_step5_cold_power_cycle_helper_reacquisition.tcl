# White Rabbit Step5 cold-power-cycle Helper reacquisition observer.
#
# This is a read-only wrapper around read_step5_hpll_lock_convergence.tcl.
# It fixes the branch5 cold-power-cycle experiment at 6000 samples x 100 ms
# and records the exact experiment name in the observer header. It does not
# write WR configuration, force a DAC, alter PI parameters, or modify FPGA
# firmware.
#
# Usage:
#   quartus_stp -t read_step5_cold_power_cycle_helper_reacquisition.tcl ?board_filter?

set board_filter ""
if {[llength $argv] >= 1} { set board_filter [lindex $argv 0] }

set samples 6000
set gap_ms 100
set experiment_name "EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-COLD-POWER-CYCLE-HELPER-REACQUISITION-600S-20260902"

set argv [list $samples $gap_ms $board_filter $experiment_name]
source [file join [file dirname [info script]] read_step5_hpll_lock_convergence.tcl]
