# Step 5 startup timeline / first-divergence observer (read-only).
#
# The observer is intentionally diagnostic-only.  It does not write a
# Wishbone control register, issue a DATA_SNAPSHOT request, or send a shell
# command.  It samples both DE5a boards from the beginning of a startup run:
#   0..30 s   every 1 s
#   30..120 s every 2 s
#
# Usage:
#   quartus_stp -t read_step5_startup_timeline_first_divergence.tcl ?trial_id?
#
# The caller must program Master, wait for Master readiness, program Slave,
# and invoke this script immediately after Slave programming completes.

package require ::quartus::insystem_source_probe

set ::trial_id "TRIAL"
if {[llength $argv] >= 1} { set ::trial_id [lindex $argv 0] }
set ::duration_ms 120000
set ::early_window_ms 30000
set ::early_gap_ms 1000
set ::late_gap_ms 2000
set ::start_ms [clock milliseconds]
set ::sample_seq 0
array set ::wb_toggle {}
array set ::prev {}
array set ::first {}
array set ::sample_count {}
array set ::sample_error {}

proc is_hex {value} {
  return [regexp {^[0-9A-Fa-f]+$} $value]
}

proc word32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 8} {
    set text [string range $text end-7 end]
  }
  scan $text %x word
  return [expr {$word & 0xffffffff}]
}

proc display32 {value} {
  set word [word32 $value]
  if {$word < 0} { return $value }
  return [format %08X $word]
}

proc bit32 {value bit} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc field32 {value lsb width} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  set mask [expr {(1 << $width) - 1}]
  return [expr {($word >> $lsb) & $mask}]
}

proc probe_high32 {value} {
  if {![is_hex $value]} { return -1 }
  set text $value
  if {[string length $text] > 16} {
    set text [string range $text end-15 end]
  }
  set text [string repeat 0 [expr {16 - [string length $text]}]]$text
  scan [string range $text 0 7] %x word
  return [expr {$word & 0xffffffff}]
}

proc bit64_high {value bit} {
  set word [probe_high32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc bit64_low {value bit} {
  set word [word32 $value]
  if {$word < 0} { return -1 }
  return [expr {($word >> $bit) & 1}]
}

proc probe_byte64 {value bit} {
  if {$bit < 32} { return [bit64_low $value $bit] }
  return [bit64_high $value [expr {$bit - 32}]]
}

proc safe_probe_read {instance} {
  if {[catch {set value [read_probe_data -instance_index $instance -value_in_hex]}]} {
    return TIMEOUT
  }
  if {![is_hex $value]} { return INVALID }
  return $value
}

proc probe_read {instance} {
  return [safe_probe_read $instance]
}

proc wb_read {hardware_name addr} {
  set ::wb_toggle($hardware_name) [expr {$::wb_toggle($hardware_name) ^ 1}]
  set toggle $::wb_toggle($hardware_name)
  set cmd [expr {$toggle | (0xf << 2) | (($addr & 0xffffffff) << 6)}]
  if {[catch {
    write_source_data -instance_index 1 -value [format %024X $cmd] -value_in_hex
  }]} {
    return TIMEOUT
  }
  after 5
  for {set n 0} {$n < 100} {incr n} {
    set value [safe_probe_read 1]
    set word [word32 $value]
    if {[is_hex $value]} {
      scan $value %x wide
      set done_toggle [expr {($wide >> 35) & 1}]
      set active [expr {($wide >> 36) & 1}]
      if {$word >= 0 && $done_toggle == $toggle && $active == 0} {
        return [format %08X $word]
      }
    }
    after 1
  }
  return TIMEOUT
}

proc wb_sync_toggle {hardware_name} {
  set value [safe_probe_read 1]
  if {[is_hex $value]} {
    scan $value %x wide
    set ::wb_toggle($hardware_name) [expr {($wide >> 35) & 1}]
  } else {
    set ::wb_toggle($hardware_name) 0
  }
}

proc ptp_state_name {state} {
  switch -- $state {
    1 { return INITIALIZING }
    2 { return FAULTY }
    3 { return DISABLED }
    4 { return LISTENING }
    5 { return PRE_MASTER }
    6 { return MASTER }
    7 { return PASSIVE }
    8 { return UNCALIBRATED }
    9 { return SLAVE }
  }
  return UNKNOWN
}

proc mode_name {mode} {
  switch -- $mode {
    2 { return MASTER }
    3 { return SLAVE }
  }
  return UNKNOWN
}

proc spll_mode_name {mode} {
  switch -- $mode {
    0 { return DISABLED }
    1 { return GRAND_MASTER }
    2 { return FREE_RUNNING_MASTER }
    3 { return SLAVE }
  }
  return UNKNOWN
}

proc spll_state_name {state} {
  switch -- $state {
    0 { return SEQ_UNINITIALIZED }
    1 { return SEQ_START_EXT }
    2 { return SEQ_WAIT_EXT }
    3 { return SEQ_START_HELPER }
    4 { return SEQ_WAIT_HELPER }
    5 { return SEQ_START_MAIN }
    6 { return SEQ_WAIT_MAIN }
    7 { return SEQ_DISABLED }
    8 { return SEQ_READY }
    9 { return SEQ_CLEAR_DACS }
    10 { return SEQ_WAIT_CLEAR_DACS }
  }
  return UNKNOWN
}

proc signal_name {message_id} {
  switch -- $message_id {
    4096 { return SLAVE_PRESENT }
    4097 { return LOCK }
    4098 { return LOCKED }
    4099 { return CALIBRATE }
    4100 { return CALIBRATED }
    4101 { return WR_MODE_ON }
  }
  return UNKNOWN
}

proc wr_state_name {state} {
  switch -- $state {
    0 { return WRS_IDLE }
    1 { return WRS_PRESENT }
    2 { return WRS_S_LOCK }
    3 { return WRS_M_LOCK }
    4 { return WRS_LOCKED }
    5 { return WRS_CALIBRATION }
    6 { return WRS_CALIBRATED }
    7 { return WRS_RESP_CALIB_REQ }
    8 { return WRS_WR_LINK_ON }
  }
  return UNKNOWN
}

proc num_or_invalid {value} {
  set n [word32 $value]
  if {$n < 0} { return INVALID }
  return $n
}

proc first_value {role field} {
  if {[info exists ::first($role,$field)]} {
    return $::first($role,$field)
  }
  return NEVER
}

proc note_first {role field condition elapsed} {
  if {$condition && ![info exists ::first($role,$field)]} {
    set ::first($role,$field) $elapsed
  }
}

proc note_transition {role field value elapsed} {
  if {$value < 0} { return }
  if {[info exists ::prev($role,$field)] && $::prev($role,$field) != $value} {
    puts [format "STARTUP_TIMELINE_TRANSITION trial=%s role=%s elapsed_ms=%d signal=%s from=%s to=%s" \
      $::trial_id $role $elapsed $field $::prev($role,$field) $value]
    flush stdout
  }
  set ::prev($role,$field) $value
}

proc note_counter_activity {role field value elapsed} {
  set current [word32 $value]
  if {$current < 0} { return }
  if {![info exists ::prev($role,$field)]} {
    set ::prev($role,$field) $current
    if {$current > 0} { note_first $role $field 1 $elapsed }
    return
  }
  set previous $::prev($role,$field)
  if {$current > $previous} { note_first $role $field 1 $elapsed }
  set ::prev($role,$field) $current
}

proc collect_targets {} {
  set masters {}
  set slaves {}
  foreach hardware_name [get_hardware_names] {
    set role ""
    if {[string first "1-11.1" $hardware_name] >= 0} { set role MASTER }
    if {[string first "1-11.2" $hardware_name] >= 0} { set role SLAVE }
    if {$role eq ""} { continue }
    set device_names [get_device_names -hardware_name $hardware_name]
    if {[llength $device_names] == 0} { continue }
    set target [list $role $hardware_name [lindex $device_names 0]]
    if {$role eq "MASTER"} { lappend masters $target } else { lappend slaves $target }
  }
  return [concat $masters $slaves]
}

proc read_board_sample {role hardware_name device_name sample elapsed} {
  if {[catch {
    start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name
    set ::wb_toggle($hardware_name) 0
    wb_sync_toggle $hardware_name

    set status [probe_read 0]
    set entry_probe [probe_read 26]
    set reset_probe [probe_read 27]

    set ptp [wb_read $hardware_name 0x00100A10]
    set ptp_rx [wb_read $hardware_name 0x00100A54]
    set ptp_tx [wb_read $hardware_name 0x00100A58]
    set rxerr [wb_read $hardware_name 0x00100A60]
    set ptp_meta [wb_read $hardware_name 0x00100A5C]
    set foreign_meta [wb_read $hardware_name 0x00100A78]
    set parse_meta [wb_read $hardware_name 0x00100A80]
    set wr_rx_signal [wb_read $hardware_name 0x00100A64]
    set wr_tx_signal [wb_read $hardware_name 0x00100A68]
    set wr_failure [wb_read $hardware_name 0x00100A6C]
    set wr_state [wb_read $hardware_name 0x00100A4C]
    set wr_reject [wb_read $hardware_name 0x00100A50]
    set pstat [wb_read $hardware_name 0x00100A0C]
    set lock_enable [wb_read $hardware_name 0x00100A9C]
    set lock_calib_fail [wb_read $hardware_name 0x00100A98]
    set lock_unlocked [wb_read $hardware_name 0x00100A94]
    set spll_state [wb_read $hardware_name 0x00100AA0]
    set ocer [wb_read $hardware_name 0x00100AA4]
    set rcer [wb_read $hardware_name 0x00100AA8]
    set spll_init [wb_read $hardware_name 0x00100B44]
    set tag_valid [wb_read $hardware_name 0x00100284]
    set trr_write [wb_read $hardware_name 0x00100288]
    set trr_pop [wb_read $hardware_name 0x00100B54]
    set irq [wb_read $hardware_name 0x00100AEC]
    set helper_update [wb_read $hardware_name 0x00100B18]
    set dmtd_ref_accept [wb_read $hardware_name 0x0010022C]
    set dmtd_fb_accept [wb_read $hardware_name 0x00100230]
  } error_message]} {
    catch {end_insystem_source_probe}
    incr ::sample_error($role)
    puts [format "STARTUP_TIMELINE_SAMPLE_ERROR trial=%s role=%s board=%s sample=%03d elapsed_ms=%d message=%s" \
      $::trial_id $role $hardware_name $sample $elapsed $error_message]
    flush stdout
    return
  }
  catch {end_insystem_source_probe}
  incr ::sample_count($role)

  set si_config_done [bit32 $status 0]
  set wr_ready [bit32 $status 1]
  set core_tm_link_up [bit32 $status 2]
  set core_link_ok [bit32 $status 3]
  set wr_rx_ready [bit32 $status 6]
  set wr_tx_ready [bit32 $status 7]
  set wr_rx_enc_err [bit32 $status 13]
  set wr_tx_enc_err [bit32 $status 14]
  set cpu_reset_n [bit32 $status 15]
  set wr_rx_locked_to_data [bit64_high $status 0]
  set boot_generation [probe_high32 $entry_probe]
  set cpu_reset_count [probe_byte64 $reset_probe 16]
  set wr_core_reset_count [probe_byte64 $reset_probe 24]
  set si_config_reset_count [probe_byte64 $reset_probe 40]

  set mode [field32 $ptp_meta 24 8]
  set ptp_state [field32 $ptp_meta 0 8]
  set ptp_state_raw [field32 $ptp 0 8]
  set foreign_count [field32 $foreign_meta 0 8]
  set foreign_best [field32 $foreign_meta 8 8]
  set foreign_detection [field32 $foreign_meta 16 8]
  set foreign_wr_config [field32 $foreign_meta 24 8]
  set parent_is_wrnode [bit32 $parse_meta 24]
  set parent_mode_on [bit32 $parse_meta 25]
  set parent_calibrated [bit32 $parse_meta 26]
  set rx_signal_id [field32 $wr_rx_signal 16 16]
  set rx_signal_count [field32 $wr_rx_signal 0 16]
  set tx_signal_id [field32 $wr_tx_signal 16 16]
  set tx_signal_count [field32 $wr_tx_signal 0 16]
  set wr_state_value [field32 $wr_state 11 4]
  set wr_next_state [field32 $wr_state 15 4]
  set spll_seq_state [field32 $spll_state 0 8]
  set spll_align_state [field32 $spll_state 8 8]
  set spll_mode [field32 $spll_state 16 8]
  set spll_delock_count [field32 $spll_state 24 8]
  set pstat_locked [bit32 $pstat 1]

  set elapsed_now [expr {[clock milliseconds] - $::start_ms}]
  if {$elapsed_now > $elapsed} { set elapsed $elapsed_now }

  foreach pair [list \
      [list si_config_done $si_config_done] \
      [list wr_ready $wr_ready] \
      [list wr_rx_ready $wr_rx_ready] \
      [list wr_tx_ready $wr_tx_ready] \
      [list wr_rx_locked_to_data $wr_rx_locked_to_data] \
      [list core_tm_link_up $core_tm_link_up] \
      [list core_link_ok $core_link_ok] \
      [list ptp_state $ptp_state] \
      [list parent_is_wrnode $parent_is_wrnode] \
      [list parent_mode_on $parent_mode_on] \
      [list parent_calibrated $parent_calibrated] \
      [list spll_seq_state $spll_seq_state] \
      [list spll_mode $spll_mode] \
      [list pstat_locked $pstat_locked] \
      [list rx_signal_id $rx_signal_id] \
      [list tx_signal_id $tx_signal_id]] {
    note_transition $role [lindex $pair 0] [lindex $pair 1] $elapsed
  }
  note_first $role first_core_tm_link_up [expr {$core_tm_link_up == 1}] $elapsed
  note_first $role first_core_link_ok [expr {$core_link_ok == 1}] $elapsed
  note_first $role first_parent_wr_calibrated [expr {$parent_is_wrnode == 1 && $parent_calibrated == 1}] $elapsed
  note_first $role first_lock_enable [expr {[word32 $lock_enable] > 0}] $elapsed
  note_first $role first_spll_init [expr {[word32 $spll_init] > 0}] $elapsed
  note_first $role first_pstat_locked [expr {$pstat_locked == 1}] $elapsed
  note_counter_activity $role ptp_rx_activity $ptp_rx $elapsed
  note_counter_activity $role ptp_tx_activity $ptp_tx $elapsed
  note_counter_activity $role dmtd_ref_accept $dmtd_ref_accept $elapsed
  note_counter_activity $role dmtd_fb_accept $dmtd_fb_accept $elapsed
  note_counter_activity $role tag_valid $tag_valid $elapsed
  note_counter_activity $role trr_write $trr_write $elapsed
  note_counter_activity $role trr_pop $trr_pop $elapsed
  note_counter_activity $role irq $irq $elapsed
  note_counter_activity $role helper_update $helper_update $elapsed
  if {[info exists ::first($role,dmtd_ref_accept)] || [info exists ::first($role,dmtd_fb_accept)]} {
    note_first $role first_dmtd_accept 1 $elapsed
  }
  if {[info exists ::first($role,tag_valid)] && [info exists ::first($role,trr_write)] && \
      [info exists ::first($role,trr_pop)] && [info exists ::first($role,irq)] && \
      [info exists ::first($role,helper_update)]} {
    note_first $role first_step4b_event_chain 1 $elapsed
  }

  puts [format "STARTUP_TIMELINE_SAMPLE trial=%s role=%s board=%s sample=%03d timestamp_ms=%d si_config_done=%s wr_ready=%s wr_rx_ready=%s wr_tx_ready=%s wr_rx_locked_to_data=%s wr_rx_enc_err=%s wr_tx_enc_err=%s core_tm_link_up=%s core_link_ok=%s WRC_MODE=%s(%s) PTP_STATE=%s(%s) PTP_RAW_STATE=%s PTP_RX_COUNT=%s PTP_TX_COUNT=%s RXERR_COUNT=%s BOOT_GENERATION=%s CPU_RESET_COUNT=%s WR_CORE_RESET_COUNT=%s SI_CONFIG_RESET_COUNT=%s CPU_RESET_N=%s FOREIGN_META=%s foreign_count=%s foreign_best=%s foreign_detection=%s foreign_wr_config=%s parentIsWRnode=%s parentModeOn=%s parentCalibrated=%s WR_RX_SIGNAL=%s(id=%s:%s,count=%s) WR_TX_SIGNAL=%s(id=%s:%s,count=%s) WR_STATE=%s(next=%s,name=%s) WR_FAILURE=%s WR_REJECT=%s LOCK_ENABLE_COUNT=%s LOCK_CALIB_FAIL_COUNT=%s LOCK_UNLOCKED_COUNT=%s SPLL_INIT_COUNT=%s SPLL_MODE=%s(%s) SPLL_SEQ_STATE=%s(%s) SPLL_ALIGN_STATE=%s SPLL_DELOCK_COUNT=%s RCER=%s OCER=%s DMTD_REF_ACCEPT=%s DMTD_FB_ACCEPT=%s TAG_VALID=%s TRR_WRITE=%s TRR_POP=%s IRQ_COUNT=%s HELPER_UPDATE_COUNT=%s PSTAT=%s PSTAT_LOCKED=%s" \
    $::trial_id $role $hardware_name $sample $elapsed $si_config_done $wr_ready $wr_rx_ready $wr_tx_ready $wr_rx_locked_to_data $wr_rx_enc_err $wr_tx_enc_err $core_tm_link_up $core_link_ok \
    $mode [mode_name $mode] $ptp_state [ptp_state_name $ptp_state] $ptp_state_raw [display32 $ptp_rx] [display32 $ptp_tx] [display32 $rxerr] \
    [expr {$boot_generation < 0 ? "INVALID" : [format %08X $boot_generation]}] \
    [expr {$cpu_reset_count < 0 ? "INVALID" : $cpu_reset_count}] [expr {$wr_core_reset_count < 0 ? "INVALID" : $wr_core_reset_count}] [expr {$si_config_reset_count < 0 ? "INVALID" : $si_config_reset_count}] $cpu_reset_n \
    [display32 $foreign_meta] [num_or_invalid $foreign_count] [num_or_invalid $foreign_best] [num_or_invalid $foreign_detection] [num_or_invalid $foreign_wr_config] $parent_is_wrnode $parent_mode_on $parent_calibrated \
    [display32 $wr_rx_signal] $rx_signal_id [signal_name $rx_signal_id] $rx_signal_count [display32 $wr_tx_signal] $tx_signal_id [signal_name $tx_signal_id] $tx_signal_count \
    [display32 $wr_state] $wr_next_state [wr_state_name $wr_state_value] [display32 $wr_failure] [display32 $wr_reject] [display32 $lock_enable] [display32 $lock_calib_fail] [display32 $lock_unlocked] [display32 $spll_init] \
    $spll_mode [spll_mode_name $spll_mode] $spll_seq_state [spll_state_name $spll_seq_state] $spll_align_state $spll_delock_count [display32 $rcer] [display32 $ocer] \
    [display32 $dmtd_ref_accept] [display32 $dmtd_fb_accept] [display32 $tag_valid] [display32 $trr_write] [display32 $trr_pop] [display32 $irq] [display32 $helper_update] [display32 $pstat] $pstat_locked]
  flush stdout
}

proc print_board_summary {role} {
  set first_dmtd [first_value $role first_dmtd_accept]
  set first_tag [first_value $role tag_valid]
  set first_write [first_value $role trr_write]
  set first_pop [first_value $role trr_pop]
  set first_irq [first_value $role irq]
  set first_helper [first_value $role helper_update]
  set boundary WR_CORE_LINK
  if {[first_value $role first_core_tm_link_up] ne "NEVER" && [first_value $role first_core_link_ok] ne "NEVER"} {
    set boundary PTP_RX
  }
  if {$boundary eq "PTP_RX" && $first_dmtd ne "NEVER"} {
    set boundary WR_PARENT_HANDSHAKE
  }
  if {$boundary eq "WR_PARENT_HANDSHAKE" && [first_value $role first_parent_wr_calibrated] ne "NEVER"} {
    set boundary LOCKING_ENABLE_DISPATCH
  }
  if {$boundary eq "LOCKING_ENABLE_DISPATCH" && [first_value $role first_lock_enable] ne "NEVER"} {
    if {$first_tag ne "NEVER" && $first_write ne "NEVER" && $first_pop ne "NEVER" && $first_irq ne "NEVER" && $first_helper ne "NEVER"} {
      set boundary STARTUP_GATE
    } else {
      set boundary SOFTPLL_EVENT_CHAIN
    }
  }
  if {$::sample_count($role) == 0} { set boundary OBSERVER_ERROR }
  set unclassified 0
  if {$boundary eq "OBSERVER_ERROR"} { set unclassified 1 }
  puts [format "STARTUP_TIMELINE_BOARD_SUMMARY trial=%s role=%s samples=%d sample_errors=%d FIRST_CORE_TM_LINK_UP_MS=%s FIRST_CORE_LINK_OK_MS=%s FIRST_PTP_RX_ACTIVITY_MS=%s FIRST_PTP_TX_ACTIVITY_MS=%s FIRST_DMTD_ACCEPT_MS=%s FIRST_PARENT_WR_CALIBRATED_MS=%s FIRST_LOCK_ENABLE_MS=%s FIRST_SPLL_INIT_MS=%s FIRST_TAG_VALID_MS=%s FIRST_TRR_WRITE_MS=%s FIRST_TRR_POP_MS=%s FIRST_IRQ_MS=%s FIRST_HELPER_UPDATE_MS=%s FIRST_PSTAT_LOCKED_MS=%s FIRST_INACTIVE_BOUNDARY=%s UNCLASSIFIED=%d" \
    $::trial_id $role $::sample_count($role) $::sample_error($role) \
    [first_value $role first_core_tm_link_up] [first_value $role first_core_link_ok] [first_value $role ptp_rx_activity] [first_value $role ptp_tx_activity] $first_dmtd \
    [first_value $role first_parent_wr_calibrated] [first_value $role first_lock_enable] [first_value $role first_spll_init] $first_tag $first_write $first_pop $first_irq $first_helper \
    [first_value $role first_pstat_locked] $boundary $unclassified]
  flush stdout
}

set ::targets [collect_targets]
if {[llength $::targets] == 0} {
  error "no DE5a targets matching 1-11.1 and 1-11.2 were found"
}
foreach role {MASTER SLAVE} {
  set ::sample_count($role) 0
  set ::sample_error($role) 0
}

puts [format "STARTUP_TIMELINE_CONFIG trial=%s duration_ms=%d early_window_ms=%d early_gap_ms=%d late_gap_ms=%d targets=%s" \
  $::trial_id $::duration_ms $::early_window_ms $::early_gap_ms $::late_gap_ms $::targets]
flush stdout

while {[expr {[clock milliseconds] - $::start_ms}] < $::duration_ms} {
  incr ::sample_seq
  set elapsed [expr {[clock milliseconds] - $::start_ms}]
  foreach target $::targets {
    read_board_sample [lindex $target 0] [lindex $target 1] [lindex $target 2] $::sample_seq $elapsed
  }
  set now_elapsed [expr {[clock milliseconds] - $::start_ms}]
  if {$now_elapsed < $::duration_ms} {
    if {$now_elapsed < $::early_window_ms} {
      set target_elapsed [expr {$now_elapsed + $::early_gap_ms}]
    } else {
      set target_elapsed [expr {$now_elapsed + $::late_gap_ms}]
    }
    set sleep_ms [expr {$target_elapsed - ([clock milliseconds] - $::start_ms)}]
    if {$sleep_ms > 0} { after $sleep_ms }
  }
}

foreach role {MASTER SLAVE} { print_board_summary $role }
puts [format "STARTUP_TIMELINE_DONE trial=%s elapsed_ms=%d" $::trial_id [expr {[clock milliseconds] - $::start_ms}]]
flush stdout
