# Read-only SDC collection/preflight and old-DB boundary check.
# Arguments: <project> <revision> <output-directory>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 3} {
    puts stderr "usage: quartus_sta -t gc_sync_ffs_sdc_preflight.tcl <project> <revision> <output-directory>"
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
        {*|gc_sync_register:*|sync0*} \
        {*|gc_sync_ffs:*|sync0*}]]
    set sync0_ffs [get_registers -nowarn {*|gc_sync_ffs:*|sync0*}]

    puts "WR_RX_CLKOUT_COLLECTION=[get_collection_size $rx_clkout]"
    puts "WR_RX_PMA_CLK_COLLECTION=[get_collection_size $rx_pma_clk]"
    puts "WR_RX_SYNC0_COLLECTION=[get_collection_size $sync0]"
    puts "GC_SYNC_FFS_SYNC0_COLLECTION=[get_collection_size $sync0_ffs]"

    if {[get_collection_size $rx_clkout] != 1} {
        error "WR_RX_CLKOUT_COLLECTION_MISMATCH"
    }
    if {[get_collection_size $rx_pma_clk] != 1} {
        error "WR_RX_PMA_CLK_COLLECTION_MISMATCH"
    }
    if {[get_collection_size $sync0] <= 0} {
        error "WR_RX_SYNC0_COLLECTION_EMPTY"
    }
    if {[get_collection_size $sync0_ffs] <= 0} {
        error "GC_SYNC_FFS_SYNC0_COLLECTION_EMPTY"
    }

    set report_file [file join $output_dir gc_sync_ffs_sdc_preflight_clocks.rpt]
    report_clocks -file $report_file

    # The previous fitted DB exposed exactly four remaining first-stage
    # negative paths; export the fresh negative set before any compile.
    set sysclk [get_clocks -nowarn {u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk}]
    puts "SYSCLK625_COLLECTION=[get_collection_size $sysclk]"
    if {[get_collection_size $sysclk] != 1} {
        error "SYSCLK625_COLLECTION_MISMATCH"
    }
    set neg_report [file join $output_dir gc_sync_ffs_preflight_negative_full.rpt]
    report_timing -hold -to_clock $sysclk -less_than_slack 0 -npaths 20 -nworst 20 -detail full_path -show_routing -file $neg_report
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "GC_SYNC_FFS_SDC_PREFLIGHT_ERROR: $err"
    exit 1
}

puts "GC_SYNC_FFS_SDC_PREFLIGHT=PASS"
exit 0
