# Read-only representative scope audit after the first-stage CDC constraint.
# Arguments: <project> <revision> <output-directory> <role-prefix>

package require ::quartus::project
package require ::quartus::sta

if {$argc != 4} {
    puts stderr "usage: quartus_sta -t first_stage_cdc_scope_audit.tcl <project> <revision> <output-directory> <role-prefix>"
    exit 2
}

set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_dir [file normalize [lindex $argv 2]]
set role_prefix [lindex $argv 3]
file mkdir $output_dir

set families [list \
    [list RX_CAL_STAT {*U_sync_rx_cal_stat*sync0} {*U_sync_rx_cal_stat*sync1}] \
    [list DMTD_NATIVE_EDGE {*U_SYNC_DMTD_NATIVE_EDGE_COUNT*|sync0*} {*U_SYNC_DMTD_NATIVE_EDGE_COUNT*|sync1*}] \
    [list ASYNC_FIFO_GRAY {*U_Sync2*|sync0*} {*U_Sync2*|sync1*}] \
    [list PULSE_SYNC {*cmp_in2out_sync*|sync0*} {*cmp_in2out_sync*|sync1*}] \
    [list BITSLIDE {*U_sync_bslide*|sync0*} {*U_sync_bslide*|sync1*}]]

set opened 0
set rc [catch {
    project_open $project -revision $revision
    set opened 1
    create_timing_netlist -model fast -temperature 100 -voltage 900
    read_sdc
    update_timing_netlist

    foreach family $families {
        lassign $family name sync0_pattern sync1_pattern
        set sync0 [get_registers -nowarn $sync0_pattern]
        set sync1 [get_registers -nowarn $sync1_pattern]
        set sync0_count [get_collection_size $sync0]
        set sync1_count [get_collection_size $sync1]
        puts "SYNC_CHAIN role=$role_prefix family=$name sync0=$sync0_count sync1=$sync1_count"
        if {$sync0_count <= 0 || $sync1_count <= 0} {
            error "SYNC_CHAIN_COLLECTION_EMPTY:$name"
        }

        foreach analysis {setup hold} {
            set edge "${name}_SYNC0_TO_SYNC1_${analysis}"
            set report_file [file join $output_dir "${role_prefix}_${edge}.rpt"]
            set edge_rc [catch {
                report_timing \
                    -$analysis \
                    -from $sync0 \
                    -to $sync1 \
                    -npaths 1 \
                    -nworst 1 \
                    -detail full_path \
                    -show_routing \
                    -file $report_file
            } edge_error]
            puts "SYNC_CHAIN_PATH role=$role_prefix family=$name analysis=$analysis rc=$edge_rc file=$report_file"
            if {$edge_rc || ![file exists $report_file] || [file size $report_file] == 0} {
                error "SYNC0_TO_SYNC1_PATH_NOT_FOUND:$edge"
            }
        }
    }

    # Keep one protocolled multibit path explicitly timed as a scope guard.
    set lcr [get_registers -nowarn {*|lcr_final_val*}]
    set rx_config [get_registers -nowarn {*|rx_config_reg*}]
    puts "PROTOCOLLED_LCR_COLLECTION=[get_collection_size $lcr]"
    puts "PROTOCOLLED_RX_CONFIG_COLLECTION=[get_collection_size $rx_config]"
    if {[get_collection_size $lcr] <= 0 || [get_collection_size $rx_config] <= 0} {
        error "PROTOCOLLED_COLLECTION_EMPTY"
    }
    foreach analysis {setup hold} {
        set report_file [file join $output_dir "${role_prefix}_LCR_TO_RX_CONFIG_${analysis}.rpt"]
        set path_rc [catch {
            report_timing \
                -$analysis \
                -from $lcr \
                -to $rx_config \
                -npaths 1 \
                -nworst 1 \
                -detail full_path \
                -show_routing \
                -file $report_file
        } path_error]
        puts "PROTOCOLLED_PATH role=$role_prefix analysis=$analysis rc=$path_rc file=$report_file"
        if {$path_rc || ![file exists $report_file] || [file size $report_file] == 0} {
            error "PROTOCOLLED_PATH_NOT_FOUND:$analysis"
        }
    }
} err opts]

if {$opened} {
    catch {delete_timing_netlist}
    catch {project_close}
}

if {$rc} {
    puts stderr "FIRST_STAGE_SCOPE_AUDIT_ERROR: $err"
    exit 1
}

puts "FIRST_STAGE_SCOPE_AUDIT=PASS role=$role_prefix"
exit 0
