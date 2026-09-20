# Read-only SDC collection preflight. Arguments:
#   <project> <revision> <output-directory>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 3} {
    puts stderr "usage: quartus_sta -t first_stage_cdc_sdc_preflight.tcl <project> <revision> <output-directory>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
file mkdir $output_dir
set opened 0

set rc [catch {
    project_open $project -revision $revision
    set opened 1
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    set rx_clkout [get_clocks -nowarn {*|rx_clkout}]
    set rx_pma_clk [get_clocks -nowarn {*|rx_pma_clk}]
    set sync0 [get_registers -nowarn [list \
        {*|gc_sync:*|sync0*} \
        {*|gc_sync_register:*|sync0*}]]

    puts "WR_RX_CLKOUT_COLLECTION=[get_collection_size $rx_clkout]"
    puts "WR_RX_PMA_CLK_COLLECTION=[get_collection_size $rx_pma_clk]"
    puts "WR_RX_SYNC0_COLLECTION=[get_collection_size $sync0]"

    if {[get_collection_size $rx_clkout] != 1} {
        error "WR_RX_CLKOUT_COLLECTION_MISMATCH"
    }
    if {[get_collection_size $rx_pma_clk] != 1} {
        error "WR_RX_PMA_CLK_COLLECTION_MISMATCH"
    }
    if {[get_collection_size $sync0] <= 0} {
        error "WR_RX_SYNC0_COLLECTION_EMPTY"
    }

    set report_file [file join $output_dir first_stage_sdc_preflight_clocks.rpt]
    report_clocks -file $report_file
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "FIRST_STAGE_SDC_PREFLIGHT_ERROR: $err"
    exit 1
}

puts "FIRST_STAGE_SDC_PREFLIGHT=PASS"
exit 0
