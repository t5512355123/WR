# Scope audit for the hold-only bundled-data exception.
# Arguments: <project> <revision> <output-directory> <role-prefix>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t protocolled_multibit_scope_audit.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir
set opened 0

proc require_report_path {path label} {
    if {![file exists $path] || [file size $path] == 0} {
        error "${label}_REPORT_MISSING"
    }
    set f [open $path r]
    set text [read $f]
    close $f
    if {[regexp -nocase {no paths found} $text]} {
        error "${label}_PATH_NOT_FOUND"
    }
}

set rc [catch {
    project_open $project -revision $revision
    set opened 1
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    set families [list \
        [list GC_SYNC_FFS_EDGE_DETECT {*|gc_sync_ffs:*U_Edge_Detect*|sync0*} {*|gc_sync_ffs:*U_Edge_Detect*|sync1*}] \
        [list GC_SYNC_FFS_RESET_MATCH_BUFF {*|gc_sync_ffs:*U_Sync_Rst_match_buff*|sync0*} {*|gc_sync_ffs:*U_Sync_Rst_match_buff*|sync1*}] \
        [list GC_SYNC_FFS_AN_RX_READY {*|gc_sync_ffs:*U_sync_an_rx_ready*|sync0*} {*|gc_sync_ffs:*U_sync_an_rx_ready*|sync1*}] \
        [list EVENT_SYNC {*|ep_packet_filter:*|gc_pulse_synchronizer2:*|gc_sync:*|sync0*} {*|ep_packet_filter:*|gc_pulse_synchronizer2:*|gc_sync:*|sync1*}]]

    foreach family $families {
        lassign $family name sync0_pattern sync1_pattern
        set sync0 [get_registers -nowarn $sync0_pattern]
        set sync1 [get_registers -nowarn $sync1_pattern]
        puts "SYNC_CHAIN role=$role_prefix family=$name sync0=[get_collection_size $sync0] sync1=[get_collection_size $sync1]"
        if {[get_collection_size $sync0] <= 0 || [get_collection_size $sync1] <= 0} {
            error "SYNC_CHAIN_COLLECTION_EMPTY:$name"
        }

        foreach analysis {setup hold} {
            set report_file [file join $output_dir "${role_prefix}_${name}_${analysis}.rpt"]
            report_timing -$analysis -from $sync0 -to $sync1 -npaths 1 -nworst 1 \
                -detail full_path -show_routing -file $report_file
            require_report_path $report_file "${role_prefix}_${name}_${analysis}"
        }
        puts "${role_prefix}_${name}_SYNC0_TO_SYNC1_TIMED=PASS"
    }

    set lcr_src [get_registers -nowarn {*|ep_rx_pcs_8bit:*|lcr_final_val*}]
    set lcr_dst [get_registers -nowarn [list \
        {*|ep_autonegotiation:*|rx_config_reg*} \
        {*|ep_autonegotiation:*|mdio_lpa_full_o*} \
        {*|ep_autonegotiation:*|mdio_lpa_half_o*} \
        {*|ep_autonegotiation:*|mdio_lpa_pause_o*} \
        {*|ep_autonegotiation:*|mdio_lpa_rfault_o*} \
        {*|ep_autonegotiation:*|mdio_lpa_lpack_o*} \
        {*|ep_autonegotiation:*|mdio_lpa_npage_o*} \
        {*|ep_autonegotiation:*|state*}]]
    set pclass_src [get_registers -nowarn {*|ep_packet_filter:*|pclass_int*}]
    set pclass_dst [get_registers -nowarn {*|ep_packet_filter:*|pclass_o*}]
    set drop_src [get_registers -nowarn {*|ep_packet_filter:*|drop_int*}]
    set drop_dst [get_registers -nowarn {*|ep_packet_filter:*|drop_o*}]

    foreach {src dst name} [list \
        $lcr_src $lcr_dst LCR \
        $pclass_src $pclass_dst PCLASS \
        $drop_src $drop_dst DROP] {
        if {[get_collection_size $src] <= 0 || [get_collection_size $dst] <= 0} {
            error "${name}_PROTOCOL_CDC_COLLECTION_EMPTY"
        }
        set setup_file [file join $output_dir "${role_prefix}_${name}_SETUP_SCOPE.rpt"]
        report_timing -setup -from $src -to $dst -npaths 1 -nworst 1 \
            -detail full_path -show_routing -file $setup_file
        require_report_path $setup_file "${role_prefix}_${name}_SETUP_SCOPE"
        puts "${role_prefix}_${name}_SETUP_STILL_TIMED=PASS"
    }
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "PROTOCOLLED_MULTIBIT_SCOPE_AUDIT_ERROR: $err"
    exit 1
}

puts "PROTOCOLLED_MULTIBIT_SCOPE_AUDIT=PASS role=$role_prefix"
exit 0
