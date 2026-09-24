# Read-only targeted TimeQuest check for the RX calibration status synchronizer.
# Arguments:
#   <project> <revision> <output-directory>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 3} {
    puts stderr "usage: quartus_sta -t rx_cal_stat_sync_sta.tcl <project> <revision> <output-directory>"
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

    set raw [get_registers -nowarn *mdio_wr_spec_rx_cal_stat_rx*]
    set sync0 [get_registers -nowarn *U_sync_rx_cal_stat*sync0]
    set sync1 [get_registers -nowarn *U_sync_rx_cal_stat*sync1]
    puts "RX_CAL_STAT_RAW_REGISTER_COUNT=[get_collection_size $raw]"
    puts "RX_CAL_STAT_SYNC0_REGISTER_COUNT=[get_collection_size $sync0]"
    puts "RX_CAL_STAT_SYNC1_REGISTER_COUNT=[get_collection_size $sync1]"

    if {[get_collection_size $raw] != 1 ||
        [get_collection_size $sync0] != 1 ||
        [get_collection_size $sync1] != 1} {
        error "RX_CAL_STAT_REGISTER_COLLECTION_MISMATCH"
    }

    report_timing \
        -hold \
        -from $raw \
        -to $sync0 \
        -npaths 1 \
        -nworst 1 \
        -detail full_path \
        -show_routing \
        -file [file join $output_dir rx_cal_stat_raw_to_sync0_hold.rpt]

    report_timing \
        -setup \
        -from $sync0 \
        -to $sync1 \
        -npaths 1 \
        -nworst 1 \
        -detail full_path \
        -show_routing \
        -file [file join $output_dir rx_cal_stat_sync0_to_sync1_setup.rpt]

    report_timing \
        -hold \
        -from $sync0 \
        -to $sync1 \
        -npaths 1 \
        -nworst 1 \
        -detail full_path \
        -show_routing \
        -file [file join $output_dir rx_cal_stat_sync0_to_sync1_hold.rpt]
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "RX_CAL_STAT_SYNC_STA_ERROR: $err"
    exit 1
}

puts "RX_CAL_STAT_SYNC_STA_COMPLETE project=$project revision=$revision output=$output_dir"
exit 0
