# Step6A: read-only Global Time observability for one or more DE5a boards.
#
# Probe contract added by EXP-S6-GLOBAL-TIME-OBSERVABILITY-20260920:
#   62 = PPS-boundary snapshot word 0
#        [39:0] TAI, [63:40] cycles[23:0]
#   63 = PPS-boundary snapshot word 1
#        [3:0] cycles[27:24], [4] time_valid, [5] pps_valid,
#        [6] snapshot_valid, [22:7] snapshot sequence
#   64 = one packed live sample
#        [35:0] TAI[35:0], [63:36] cycles[27:0]
#   0  = existing WR status probe
#
# Probe 63 is read before and after probe 62.  A sample is coherent only when
# the sequence word is unchanged across that three-read window.  The PPS
# snapshot is the authoritative full-width TAI/cycle record; probe 64 is used
# only for the short-interval cycle monotonicity check.
#
# Usage:
#   quartus_stp -t read_step6_global_time_observability.tcl ?duration_ms? ?sample_ms? ?board_substring?

package require ::quartus::insystem_source_probe

set duration_ms 15000
set sample_ms 250
set board_filter ""
if {[llength $argv] >= 1} {
  set duration_ms [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2} {
  set sample_ms [expr {int([lindex $argv 1])}]
}
if {[llength $argv] >= 3} {
  set board_filter [lindex $argv 2]
}
if {$duration_ms < 0 || $sample_ms <= 0} {
  error "duration_ms must be >= 0 and sample_ms must be > 0"
}

set tai_mask 1099511627775
set tai36_mask 68719476735
set cycles24_mask 16777215
set cycles28_mask 268435455

proc read_word {instance_index} {
  set raw [read_probe_data -instance_index $instance_index -value_in_hex]
  if {[scan $raw %x word] != 1} {
    error "cannot decode probe ${instance_index}: ${raw}"
  }
  return $word
}

proc print_global_time_sample {hardware_name sample elapsed_ms} {
  set live [read_word 64]
  set word1_before [read_word 63]
  set word0 [read_word 62]
  set word1_after [read_word 63]
  set status [read_word 0]

  set stable [expr {$word1_before == $word1_after ? 1 : 0}]
  set tai [expr {$word0 & 1099511627775}]
  set cycles [expr {(($word0 >> 40) & 16777215) | (($word1_after & 15) << 24)}]
  set snapshot_time_valid [expr {($word1_after >> 4) & 1}]
  set snapshot_pps_valid [expr {($word1_after >> 5) & 1}]
  set snapshot_valid [expr {($word1_after >> 6) & 1}]
  set snapshot_count [expr {($word1_after >> 7) & 65535}]
  set live_tai_lo [expr {$live & 68719476735}]
  set live_cycles [expr {($live >> 36) & 268435455}]

  # Existing status probe, bit 0 is the least-significant status bit.
  set status_si_config [expr {$status & 1}]
  set status_phy_ready [expr {($status >> 1) & 1}]
  set status_tm_link_up [expr {($status >> 2) & 1}]
  set status_link_ok [expr {($status >> 3) & 1}]
  set status_time_valid [expr {($status >> 4) & 1}]
  set status_pps_valid [expr {($status >> 5) & 1}]
  set status_rx_ready [expr {($status >> 6) & 1}]
  set status_tx_ready [expr {($status >> 7) & 1}]

  puts [format "GLOBAL_TIME_SAMPLE board=%s sample=%d elapsed_ms=%d RAW_LIVE=%016X RAW0=%016X RAW1_BEFORE=%016X RAW1_AFTER=%016X STABLE=%d SNAPSHOT_VALID=%d SNAPSHOT_TIME_VALID=%d SNAPSHOT_PPS_VALID=%d SNAPSHOT_COUNT=%d TAI=%d CYCLES=%d LIVE_TAI_LO=%d LIVE_CYCLES=%d STATUS_RAW=%016X STATUS_SI_CONFIG=%d STATUS_PHY_READY=%d STATUS_TM_LINK_UP=%d STATUS_LINK_OK=%d STATUS_TIME_VALID=%d STATUS_PPS_VALID=%d STATUS_RX_READY=%d STATUS_TX_READY=%d" \
        $hardware_name $sample $elapsed_ms $live $word0 $word1_before $word1_after $stable \
        $snapshot_valid $snapshot_time_valid $snapshot_pps_valid $snapshot_count $tai $cycles \
        $live_tai_lo $live_cycles $status $status_si_config $status_phy_ready \
        $status_tm_link_up $status_link_ok $status_time_valid $status_pps_valid \
        $status_rx_ready $status_tx_ready]
  flush stdout
}

puts [format "GLOBAL_TIME_CONFIG duration_ms=%d sample_ms=%d board_filter=%s reference_clock_hz=125000000" \
      $duration_ms $sample_ms $board_filter]
flush stdout

foreach hardware_name [get_hardware_names] {
  if {$board_filter ne "" && [string first $board_filter $hardware_name] < 0} {
    continue
  }
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} {
    puts "GLOBAL_TIME_SKIP board=${hardware_name} reason=no_device"
    continue
  }

  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  puts "GLOBAL_TIME_DEVICE device=${device_name}"
  flush stdout
  catch { end_insystem_source_probe }

  if {[catch {
    start_insystem_source_probe \
      -hardware_name $hardware_name \
      -device_name $device_name
    set begin_ms [clock milliseconds]
    set deadline_ms [expr {$begin_ms + $duration_ms}]
    set sample 0
    while {[clock milliseconds] <= $deadline_ms} {
      set elapsed_ms [expr {[clock milliseconds] - $begin_ms}]
      print_global_time_sample $hardware_name $sample $elapsed_ms
      incr sample
      after $sample_ms
    }
    puts [format "GLOBAL_TIME_DONE board=%s samples=%d elapsed_ms=%d" \
          $hardware_name $sample [expr {[clock milliseconds] - $begin_ms}]]
    flush stdout
  } error_message]} {
    puts "GLOBAL_TIME_ERROR board=${hardware_name} message=${error_message}"
    flush stdout
  }
  catch { end_insystem_source_probe }
}
