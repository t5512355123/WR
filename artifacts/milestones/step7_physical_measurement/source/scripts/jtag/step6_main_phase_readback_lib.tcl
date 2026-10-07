# Passive subset of the existing F4L v1 publication. No launcher or writes.
# Mapping: spll_main_f4l_diag_fill words 0,1,2,3,4,5,6,12;
# wdiags_write_wr_spll_main_f4l_debug publishes these at 0x00100B58.
# phase_current is sampled BEFORE that MPLL invocation's one-unit shifter
# advance. It is a firmware observation, not physical phase or DAC readback.

proc s6_main_phase_readback {hardware_name sample pair_ucnt total_start_us} {
  set start_us [s6_a_us]
  set u0 [wb_read 0x00100A48]
  set valid 0
  set attempts 0
  set words {}
  for {set attempt 1} {$attempt <= 3} {incr attempt} {
    set attempts $attempt
    set words {}
    foreach address {0x00100B58 0x00100B5C 0x00100B60 0x00100B64
                     0x00100B68 0x00100B6C 0x00100B70 0x00100B88
                     0x00100B58} {
      lappend words [wb_read $address]
    }
    set decoded {}
    set payload_ok 1
    foreach raw $words {
      if {![is_hex $raw]} { set payload_ok 0 }
      lappend decoded [word32 $raw]
    }
    if {$payload_ok} {
      lassign $decoded e0 magic vp source_epoch update init identity current e1
      set version [expr {$vp & 0xff}]
      set page [expr {($vp >> 8) & 0xff}]
      if {$e0 > 0 && $e0 == $e1 && !($e0 & 1) &&
          $magic == 0x46344c31 && $version == 1 && $page < 3 &&
          $source_epoch > 0 && !($source_epoch & 1) && $update > 0} {
        set valid 1
        break
      }
    }
    after 2
  }
  set u1 [wb_read 0x00100A48]
  set end_us [s6_a_us]
  set same_servo 0
  if {$valid && [is_hex $u0] && [is_hex $u1] && [is_hex $pair_ucnt]} {
    set same_servo [expr {
      [word32 $u0] == [word32 $u1] && [word32 $u1] == [word32 $pair_ucnt] ? 1 : 0}]
  }
  set current_units NA
  set current_ps NA
  if {$valid} {
    set current_units [s6_a_signed32 [lindex $words 7]]
    # Same signed64 arithmetic as softpll_ng.to_picos(current * div).
    # HPLL_N=14, CLOCK_PERIOD_PICOSECONDS=8000, divide-DMTD-by-two enabled.
    set current_ps [expr {($current_units * 2 * 8000) >> 14}]
  }
  puts [format "S6_MAIN_PHASE_SAMPLE board=%s sample=%04d TOTAL_START_MS=%d TOTAL_END_MS=%d HOST_START_US=%s HOST_END_US=%s FRAME_VALID=%d ATTEMPTS=%d EPOCH_BEFORE=%s MAGIC=%s VERSION_PAGE=%s SOURCE_EPOCH=%s UPDATE_ID=%s INIT_GENERATION=%s PRODUCER_IDENTITY=%s PHASE_CURRENT_RAW=%s PHASE_CURRENT_UNITS=%s PHASE_CURRENT_PS=%s EPOCH_AFTER=%s SERVO_UCNT_BEFORE=%s SERVO_UCNT_AFTER=%s PAIR_UCNT=%s SERVO_UPDATE_MATCH=%d GROUPS_NOT_ATOMIC=1 CURRENT_IS_PRE_SHIFTER_UPDATE=1" \
    $hardware_name $sample [expr {($start_us - $total_start_us) / 1000}] \
    [expr {($end_us - $total_start_us) / 1000}] $start_us $end_us $valid $attempts \
    {*}[lrange $words 0 7] $current_units $current_ps [lindex $words 8] \
    $u0 $u1 $pair_ucnt $same_servo]
  flush stdout
  return $valid
}
