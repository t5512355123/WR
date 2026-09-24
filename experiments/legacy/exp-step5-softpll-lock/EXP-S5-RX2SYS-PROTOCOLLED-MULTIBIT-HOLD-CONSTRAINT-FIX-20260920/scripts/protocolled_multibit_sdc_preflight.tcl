# Existing-fitted-DB preflight for the reviewed bundled-data CDC exception.
# Arguments: <project> <revision> <output-directory> <role-prefix>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t protocolled_multibit_sdc_preflight.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir
set opened 0

proc read_text {path} {
    set f [open $path r]
    set value [read $f]
    close $f
    return $value
}

proc require_report_path {path label} {
    if {![file exists $path] || [file size $path] == 0} {
        error "${label}_REPORT_MISSING"
    }
    set text [read_text $path]
    if {[regexp -nocase {no paths found} $text]} {
        error "${label}_PATH_NOT_FOUND"
    }
}

proc require_no_hold_violations {path label} {
    if {![file exists $path] || [file size $path] == 0} {
        error "${label}_NEGATIVE_REPORT_MISSING"
    }
    set text [read_text $path]
    if {[regexp -nocase {Found\s+\d+\s+hold paths\s+\((\d+)\s+violated\)} $text -> violated]} {
        if {$violated != 0} {
            error "${label}_HOLD_NEGATIVE=$violated"
        }
        return
    }
    if {[regexp -nocase {no paths found} $text]} {
        return
    }
    error "${label}_NEGATIVE_REPORT_UNPARSEABLE"
}

set rc [catch {
    project_open $project -revision $revision
    set opened 1
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

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

    puts "LCR_SRC_COLLECTION=[get_collection_size $lcr_src]"
    puts "LCR_DST_COLLECTION=[get_collection_size $lcr_dst]"
    puts "PCLASS_SRC_COLLECTION=[get_collection_size $pclass_src]"
    puts "PCLASS_DST_COLLECTION=[get_collection_size $pclass_dst]"
    puts "DROP_SRC_COLLECTION=[get_collection_size $drop_src]"
    puts "DROP_DST_COLLECTION=[get_collection_size $drop_dst]"

    foreach {src dst name} [list \
        $lcr_src $lcr_dst LCR \
        $pclass_src $pclass_dst PCLASS \
        $drop_src $drop_dst DROP] {
        if {[get_collection_size $src] <= 0 || [get_collection_size $dst] <= 0} {
            error "${name}_PROTOCOL_CDC_COLLECTION_EMPTY"
        }
    }

    set sysclk [get_clocks -nowarn {u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk}]
    puts "SYSCLK625_COLLECTION=[get_collection_size $sysclk]"
    if {[get_collection_size $sysclk] != 1} {
        error "SYSCLK625_COLLECTION_MISMATCH"
    }

    set negative_file [file join $output_dir "${role_prefix}_rx2sys_hold_negative.rpt"]
    report_timing -hold -to_clock $sysclk -less_than_slack 0 \
        -npaths 1000 -nworst 1000 -detail summary -file $negative_file
    require_no_hold_violations $negative_file "${role_prefix}_RX2SYS"
    puts "${role_prefix}_RX2SYS_HOLD_NEGATIVE=0"

    foreach {src dst name} [list \
        $lcr_src $lcr_dst LCR \
        $pclass_src $pclass_dst PCLASS \
        $drop_src $drop_dst DROP] {
        set setup_file [file join $output_dir "${role_prefix}_${name}_setup.rpt"]
        report_timing -setup -from $src -to $dst -npaths 1 -nworst 1 \
            -detail full_path -show_routing -file $setup_file
        require_report_path $setup_file "${role_prefix}_${name}_SETUP"
        puts "${role_prefix}_${name}_SETUP_PATH_FOUND=YES"
    }

    set pulse0 [get_registers -nowarn {*|ep_packet_filter:*|gc_pulse_synchronizer2:*|gc_sync:*|sync0*}]
    set pulse1 [get_registers -nowarn {*|ep_packet_filter:*|gc_pulse_synchronizer2:*|gc_sync:*|sync1*}]
    puts "PULSE_SYNC0_COLLECTION=[get_collection_size $pulse0]"
    puts "PULSE_SYNC1_COLLECTION=[get_collection_size $pulse1]"
    if {[get_collection_size $pulse0] <= 0 || [get_collection_size $pulse1] <= 0} {
        error "PULSE_SYNC_DOWNSTREAM_COLLECTION_EMPTY"
    }
    set pulse_setup_file [file join $output_dir "${role_prefix}_PULSE_SYNC_SYNC0_TO_SYNC1_setup.rpt"]
    report_timing -setup -from $pulse0 -to $pulse1 -npaths 1 -nworst 1 \
        -detail full_path -show_routing -file $pulse_setup_file
    require_report_path $pulse_setup_file "${role_prefix}_PULSE_SYNC_SETUP"
    puts "${role_prefix}_EVENT_SYNC_DOWNSTREAM_TIMED=PASS"
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "PROTOCOLLED_MULTIBIT_SDC_PREFLIGHT_ERROR: $err"
    exit 1
}

puts "PROTOCOLLED_MULTIBIT_SDC_PREFLIGHT=PASS role=$role_prefix"
exit 0
