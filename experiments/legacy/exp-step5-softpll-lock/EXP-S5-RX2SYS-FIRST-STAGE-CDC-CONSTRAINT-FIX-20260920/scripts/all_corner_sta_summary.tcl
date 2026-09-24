# Read-only all-corner timing summary. Arguments:
#   <project> <revision> <output-directory> <role-prefix>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t all_corner_sta_summary.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir

set corners [list \
    [list slow_900mV_100C slow 100 900] \
    [list slow_900mV_0C   slow 0   900] \
    [list fast_900mV_100C fast 100 900] \
    [list fast_900mV_0C   fast 0   900]]
set analyses {setup hold recovery removal}
set clock_name "u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk"
set opened 0

set rc [catch {
    project_open $project -revision $revision
    set opened 1

    foreach corner $corners {
        lassign $corner label model temperature voltage
        create_timing_netlist -model $model -temperature $temperature -voltage $voltage
        read_sdc
        update_timing_netlist

        set clocks [get_clocks -nowarn $clock_name]
        puts "CORNER role=$role_prefix name=$label SYSCLK625_COLLECTION=[get_collection_size $clocks]"

        foreach analysis $analyses {
            set report_file [file join $output_dir "${role_prefix}_${label}_${analysis}.rpt"]
            set analysis_rc [catch {
                report_timing \
                    -$analysis \
                    -npaths 1 \
                    -nworst 1 \
                    -detail summary \
                    -file $report_file
            } analysis_error]
            puts "CORNER_PATH role=$role_prefix name=$label analysis=$analysis rc=$analysis_rc file=$report_file"
            if {$analysis_rc || ![file exists $report_file] || [file size $report_file] == 0} {
                error "CORNER_REPORT_FAILED:$label:$analysis"
            }
        }

        set clock_report [file join $output_dir "${role_prefix}_${label}_clocks.rpt"]
        report_clocks -file $clock_report
        set ucp_report [file join $output_dir "${role_prefix}_${label}_unconstrained.rpt"]
        set ucp_rc [catch {report_ucp -file $ucp_report} ucp_error]
        puts "UNCONSTRAINED_REPORT role=$role_prefix name=$label rc=$ucp_rc file=$ucp_report"
        if {$ucp_rc} {
            puts "UNCONSTRAINED_REPORT_ERROR role=$role_prefix name=$label error=$ucp_error"
        }
        if {$ucp_rc || ![file exists $ucp_report]} {
            error "UNCONSTRAINED_REPORT_FAILED:$label"
        }

        set dmtd [get_registers -nowarn {*|clk_dmtd_62m496}]
        puts "DMTD_62M496_TARGET role=$role_prefix name=$label count=[get_collection_size $dmtd]"
        delete_timing_netlist
    }
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "ALL_CORNER_STA_ERROR: $err"
    exit 1
}

puts "ALL_CORNER_STA_SUMMARY=PASS role=$role_prefix"
exit 0
