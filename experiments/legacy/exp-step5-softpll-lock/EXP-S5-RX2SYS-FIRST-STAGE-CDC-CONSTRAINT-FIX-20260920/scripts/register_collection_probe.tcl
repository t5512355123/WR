# Read-only Quartus register collection probe for the scope audit.
# Arguments: <project> <revision> <output-file>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 3} {
    puts stderr "usage: quartus_sta -t register_collection_probe.tcl <project> <revision> <output-file>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_file [file normalize [lindex $argv 2]]
set opened 0

set rc [catch {
    project_open $project -revision $revision
    set opened 1
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    set out [open $output_file w]
    foreach pattern {
        *sync0*
        *sync1*
        *U_SYNC_DMTD_NATIVE_EDGE_COUNT*
        *U_sync_bslide*
        *U_Sync2*
        *cmp_in2out_sync*
        *gc_sync*
    } {
        set regs [get_registers -nowarn $pattern]
        puts $out "PATTERN=$pattern COUNT=[get_collection_size $regs]"
        set shown 0
        foreach_in_collection reg $regs {
            if {$shown >= 80} { break }
            puts $out "  [get_register_info $reg -name]"
            incr shown
        }
    }
    close $out
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "REGISTER_COLLECTION_PROBE_ERROR: $err"
    exit 1
}

puts "REGISTER_COLLECTION_PROBE=PASS file=$output_file"
exit 0
