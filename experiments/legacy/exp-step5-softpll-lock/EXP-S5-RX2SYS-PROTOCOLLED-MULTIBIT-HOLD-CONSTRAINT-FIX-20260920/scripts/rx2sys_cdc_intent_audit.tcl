# Fresh Fast 900mV/100C RX-to-SYS hold export after clean compilation.
# Arguments: <project> <revision> <output-directory> <role-prefix>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t rx2sys_cdc_intent_audit.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir
set opened 0
set clock_name "u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk"

set rc [catch {
    project_open $project -revision $revision
    set opened 1
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    set sysclk [get_clocks -nowarn $clock_name]
    puts "SYSCLK625_COLLECTION_COUNT=[get_collection_size $sysclk]"
    if {[get_collection_size $sysclk] != 1} {
        error "SYSCLK625_CLOCK_COLLECTION_MISMATCH"
    }

    set top20_file [file join $output_dir "${role_prefix}_rx2sys_hold_top20_full.rpt"]
    set all_negative_file [file join $output_dir "${role_prefix}_rx2sys_hold_all_negative_full.rpt"]
    set all_negative_summary_file [file join $output_dir "${role_prefix}_rx2sys_hold_all_negative_summary.rpt"]

    report_timing -hold -to_clock $sysclk -npaths 20 -nworst 20 \
        -detail full_path -show_routing -file $top20_file
    report_timing -hold -to_clock $sysclk -less_than_slack 0 \
        -npaths 0 -nworst 1 -detail full_path -show_routing \
        -file $all_negative_file
    report_timing -hold -to_clock $sysclk -less_than_slack 0 \
        -npaths 0 -nworst 1 -detail summary -file $all_negative_summary_file

    foreach path [list $top20_file $all_negative_file $all_negative_summary_file] {
        if {![file exists $path] || [file size $path] == 0} {
            error "RX2SYS_REPORT_MISSING:$path"
        }
    }
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "RX2SYS_CDC_INTENT_AUDIT_ERROR: $err"
    exit 1
}

puts "RX2SYS_CDC_INTENT_AUDIT=PASS role=$role_prefix"
exit 0
