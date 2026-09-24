# Read-only Quartus Prime 17.0 TimeQuest path export.
# Arguments: <project> <revision> <output-directory> <role-prefix>
# This script must be run from the directory containing the QSF files.

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t timing_top20_path_export.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir

set top20_file [file join $output_dir "${role_prefix}_clk50_setup_top20_full.rpt"]
set violations_file [file join $output_dir "${role_prefix}_clk50_setup_violations_full.rpt"]
set opened 0

set rc [catch {
    project_open $project -revision $revision
    set opened 1

    # Reconstruct the timing netlist from the existing fitted database only.
    create_timing_netlist -model slow -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    report_timing \
        -setup \
        -to_clock [get_clocks {clk_50m}] \
        -npaths 20 \
        -nworst 20 \
        -detail full_path \
        -show_routing \
        -file $top20_file

    report_timing \
        -setup \
        -to_clock [get_clocks {clk_50m}] \
        -less_than_slack 0 \
        -npaths 20 \
        -nworst 20 \
        -detail full_path \
        -show_routing \
        -file $violations_file
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "TIMING_EXPORT_ERROR: $err"
    exit 1
}

puts "TIMING_EXPORT_COMPLETE project=$project revision=$revision output=$output_dir"
exit 0
