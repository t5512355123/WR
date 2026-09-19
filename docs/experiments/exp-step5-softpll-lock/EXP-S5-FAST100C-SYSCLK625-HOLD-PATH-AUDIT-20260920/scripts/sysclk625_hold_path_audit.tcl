# Read-only Quartus Prime 17.0 TimeQuest audit for the first remaining
# Fast-900mV/100C hold boundary.  Arguments:
#   <project> <revision> <output-directory> <role-prefix>
# Run from the directory containing the fitted QPF/QSF and revision database.

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t sysclk625_hold_path_audit.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir

set clock_name "u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk"
set top20_file [file join $output_dir "${role_prefix}_sysclk625_hold_top20_full.rpt"]
set violations_file [file join $output_dir "${role_prefix}_sysclk625_hold_violations_full.rpt"]
set summary_file [file join $output_dir "${role_prefix}_sysclk625_hold_all_violations_summary.rpt"]
set opened 0

set rc [catch {
    project_open $project -revision $revision
    set opened 1

    # Reconstruct the existing fitted timing database without compiling.
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    set sysclk [get_clocks $clock_name]
    set sysclk_count [get_collection_size $sysclk]
    puts "SYSCLK625_COLLECTION_COUNT=$sysclk_count"
    if {$sysclk_count != 1} {
        error "SYSCLK625_CLOCK_COLLECTION_MISMATCH"
    }

    report_timing \
        -hold \
        -to_clock $sysclk \
        -npaths 20 \
        -nworst 20 \
        -detail full_path \
        -show_routing \
        -file $top20_file

    report_timing \
        -hold \
        -to_clock $sysclk \
        -less_than_slack 0 \
        -npaths 20 \
        -nworst 20 \
        -detail full_path \
        -show_routing \
        -file $violations_file

    report_timing \
        -hold \
        -to_clock $sysclk \
        -less_than_slack 0 \
        -npaths 0 \
        -nworst 1 \
        -detail summary \
        -file $summary_file
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "SYSCLK625_HOLD_AUDIT_ERROR: $err"
    exit 1
}

puts "SYSCLK625_HOLD_AUDIT_COMPLETE project=$project revision=$revision output=$output_dir"
exit 0
