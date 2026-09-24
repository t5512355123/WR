# Read-only TimeQuest scope audit for the diagnostic activity CDC exception.
# Arguments: <project> <revision> <output-directory> <role-prefix>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t constraint_scope_audit.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir

set pairs {
    {ref_activity_toggle  ref_activity_meta  ref_activity_sync  ref_activity_prev}
    {dmtd_activity_toggle dmtd_activity_meta dmtd_activity_sync dmtd_activity_prev}
    {rx_activity_toggle   rx_activity_meta   rx_activity_sync   rx_activity_prev}
}

set opened 0
set failed 0
set rc [catch {
    project_open $project -revision $revision
    set opened 1
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
        -file [file join $output_dir "${role_prefix}_clk50_setup_after_constraint_top20.rpt"]

    foreach tuple $pairs {
        lassign $tuple src meta sync prev

        set src_regs [get_registers -nowarn $src]
        set meta_regs [get_registers -nowarn $meta]
        set sync_regs [get_registers -nowarn $sync]
        set prev_regs [get_registers -nowarn $prev]

        foreach {name regs} [list src $src_regs meta $meta_regs sync $sync_regs prev $prev_regs] {
            set count [get_collection_size $regs]
            puts "REGISTER_COLLECTION role=$role_prefix name=$name count=$count"
            if {$count != 1} {
                error "CDC_SCOPE_REGISTER_COLLECTION_MISMATCH:$name"
            }
        }

        foreach {edge from_regs to_regs} [list \
            "${src}_TO_${meta}" $src_regs $meta_regs \
            "${meta}_TO_${sync}" $meta_regs $sync_regs \
            "${sync}_TO_${prev}" $sync_regs $prev_regs] {
            set edge_file [file join $output_dir "${role_prefix}_${edge}_setup.rpt"]
            set edge_rc [catch {
                report_timing \
                    -setup \
                    -from $from_regs \
                    -to $to_regs \
                    -npaths 1 \
                    -nworst 1 \
                    -detail full_path \
                    -show_routing \
                    -file $edge_file
            } edge_error]
            puts "EDGE_RESULT role=$role_prefix edge=$edge rc=$edge_rc"
            if {$edge_rc} {
                puts "EDGE_ERROR role=$role_prefix edge=$edge error=$edge_error"
            }
            if {$edge ne "${src}_TO_${meta}" && $edge_rc} {
                set failed 1
            }
        }
    }
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "CONSTRAINT_SCOPE_AUDIT_ERROR: $err"
    exit 1
}
if {$failed} {
    puts stderr "CONSTRAINT_SCOPE_AUDIT_RESULT=FAIL"
    exit 1
}

puts "CONSTRAINT_SCOPE_AUDIT_RESULT=PASS role=$role_prefix"
exit 0
