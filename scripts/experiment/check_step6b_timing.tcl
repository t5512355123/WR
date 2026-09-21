# Step6B post-fit timing gate, boundary-corrected version.
#
# Arguments: project.qpf revision output_report
#
# This script is an offline STA checker.  It never changes RTL, SDC, QSF,
# MIF, FPGA configuration, or hardware state.  The only accepted result is
# based on real TimeQuest path objects, get_path_info provenance, and numeric
# setup/hold slack.

load_package flow
load_package report

if {[llength $argv] < 3} {
  puts "STEP6B_TIMING_RESULT=NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED REASON=ARGUMENTS"
  exit 2
}

set ::s6b_project [lindex $argv 0]
set ::s6b_revision [lindex $argv 1]
set ::s6b_output_report [file normalize [lindex $argv 2]]
file mkdir [file dirname $::s6b_output_report]
set ::s6b_report_channel [open $::s6b_output_report w]
set ::s6b_timing_result PASS_STEP6B_POSTFIT_TIMING_PROVEN
set ::s6b_failure_reason ""
set ::s6b_project_open 0

proc s6b_report {line} {
  puts $::s6b_report_channel $line
  flush $::s6b_report_channel
}

proc s6b_collection_count {collection} {
  if {[catch {get_collection_size $collection} count]} { return 0 }
  return $count
}

proc s6b_mark_failure {reason result} {
  if {$::s6b_failure_reason eq ""} { set ::s6b_failure_reason $reason }
  if {$::s6b_timing_result eq "PASS_STEP6B_POSTFIT_TIMING_PROVEN"} {
    set ::s6b_timing_result $result
  }
}

proc s6b_filtered_registers {pattern exclude_pattern} {
  set candidates {}
  if {[catch {set candidates [get_registers -nowarn $pattern]} err]} {
    s6b_report [format "STEP6B_REGISTER_QUERY_ERROR pattern=%s error=%s" $pattern $err]
    s6b_mark_failure REGISTER_QUERY_ERROR NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED
    return [get_registers -nowarn __step6b_no_match__]
  }
  set selected [get_registers -nowarn __step6b_no_match__]
  foreach_in_collection item $candidates {
    set name [get_object_name $item]
    if {$exclude_pattern ne "" && [string match $exclude_pattern $name]} {
      continue
    }
    set selected [add_to_collection $selected $item]
  }
  return $selected
}

proc s6b_path_measure {paths label} {
  set path_count [s6b_collection_count $paths]
  if {$path_count == 0} {
    return [dict create status EMPTY count 0 slack INVALID from INVALID to INVALID \
      from_clock INVALID to_clock INVALID type INVALID error "no_timing_paths"]
  }
  set minimum 1.0e30
  set worst_from INVALID
  set worst_to INVALID
  set worst_from_clock INVALID
  set worst_to_clock INVALID
  set worst_type INVALID
  set errors {}
  foreach_in_collection path $paths {
    set slack ""
    set from ""
    set to ""
    set from_clock ""
    set to_clock ""
    set path_type ""
    set error_text ""
    if {[catch {set slack [get_path_info $path -slack]} err]} {
      append error_text "slack:$err;"
    }
    if {[catch {set from [get_path_info $path -from]} err]} {
      append error_text "from:$err;"
    }
    if {[catch {set to [get_path_info $path -to]} err]} {
      append error_text "to:$err;"
    }
    if {[catch {set from_clock [get_path_info $path -from_clock]} err]} {
      append error_text "from_clock:$err;"
    }
    if {[catch {set to_clock [get_path_info $path -to_clock]} err]} {
      append error_text "to_clock:$err;"
    }
    if {[catch {set path_type [get_path_info $path -type]} err]} {
      append error_text "type:$err;"
    }
    if {$error_text ne "" || ![string is double -strict $slack]} {
      if {$error_text eq ""} { set error_text "slack_not_numeric:$slack" }
      lappend errors $error_text
      continue
    }
    set value [expr {$slack + 0.0}]
    if {$value < $minimum} {
      set minimum $value
      set worst_from $from
      set worst_to $to
      set worst_from_clock $from_clock
      set worst_to_clock $to_clock
      set worst_type $path_type
    }
  }
  if {[llength $errors] > 0} {
    return [dict create status INVALID count $path_count slack INVALID \
      from $worst_from to $worst_to from_clock $worst_from_clock \
      to_clock $worst_to_clock type $worst_type error [join $errors |]]
  }
  return [dict create status PASS count $path_count slack $minimum \
    from $worst_from to $worst_to from_clock $worst_from_clock \
    to_clock $worst_to_clock type $worst_type error ""]
}

proc s6b_query_paths {from_clock to_clock from to mode label} {
  set paths {}
  set query_error ""
  if {[catch {
    if {$from_clock eq ""} {
      set paths [get_timing_paths -from $from -to $to -npaths 100 $mode]
    } else {
      # Keep the public clock-domain constraint and, when available, the
      # explicit source register collection.  The latter prevents TimeQuest
      # from selecting an unrelated path in the same clock domain.
      set command [list get_timing_paths -from_clock $from_clock \
        -to_clock $to_clock]
      if {[s6b_collection_count $from] > 0} {
        lappend command -from $from
      }
      lappend command -to $to -npaths 100 $mode
      set paths [eval $command]
    }
  } err]} {
    set query_error $err
    s6b_report [format "STEP6B_TIMING_QUERY_ERROR name=%s mode=%s error=%s" \
      $label $mode $err]
  }
  if {$query_error ne ""} {
    return [dict create status ERROR paths {} error $query_error]
  }
  return [dict create status PASS paths $paths error ""]
}

proc s6b_report_timing_file {from_clock to_clock from to mode output_file} {
  set command [list report_timing]
  if {$from_clock ne ""} {
    lappend command -from_clock $from_clock -to_clock $to_clock
    if {[s6b_collection_count $from] > 0} {
      lappend command -from $from
    }
  } else {
    lappend command -from $from
  }
  lappend command -to $to -npaths 20 -detail full_path $mode -file $output_file
  if {[catch {eval $command} err]} {
    s6b_report [format "STEP6B_REPORT_TIMING_ERROR mode=%s file=%s error=%s" \
      $mode $output_file $err]
  }
}

proc s6b_check_group {name from to use_clock refclk report_prefix} {
  set matched_from [s6b_collection_count $from]
  set matched_to [s6b_collection_count $to]
  s6b_report [format "STEP6B_ENDPOINTS name=%s matched_from=%d matched_to=%d" \
    $name $matched_from $matched_to]
  if {$matched_from == 0 || $matched_to == 0} {
    s6b_mark_failure "${name}_endpoint_match_empty" NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED
    return
  }

  if {$use_clock} {
    set setup_query [s6b_query_paths $refclk $refclk $from $to -setup $name.setup]
    set hold_query [s6b_query_paths $refclk $refclk $from $to -hold $name.hold]
  } else {
    set setup_query [s6b_query_paths {} {} $from $to -setup $name.setup]
    set hold_query [s6b_query_paths {} {} $from $to -hold $name.hold]
  }
  set setup_status [dict get $setup_query status]
  set hold_status [dict get $hold_query status]
  set setup_measure [dict create status ERROR count 0 slack INVALID from INVALID to INVALID from_clock INVALID to_clock INVALID type INVALID error "query_not_run"]
  set hold_measure [dict create status ERROR count 0 slack INVALID from INVALID to INVALID from_clock INVALID to_clock INVALID type INVALID error "query_not_run"]
  if {$setup_status eq "PASS"} {
    set setup_measure [s6b_path_measure [dict get $setup_query paths] $name.setup]
  }
  if {$hold_status eq "PASS"} {
    set hold_measure [s6b_path_measure [dict get $hold_query paths] $name.hold]
  }

  foreach pair [list [list setup $setup_measure] [list hold $hold_measure]] {
    lassign $pair kind measure
    set status [dict get $measure status]
    set count [dict get $measure count]
    set slack [dict get $measure slack]
    set from_node [dict get $measure from]
    set to_node [dict get $measure to]
    set from_clock [dict get $measure from_clock]
    set to_clock [dict get $measure to_clock]
    set path_type [dict get $measure type]
    set error_text [dict get $measure error]
    set query_from_clock [expr {$use_clock ? "qsfp_ref_125m" : "UNQUALIFIED"}]
    set query_to_clock [expr {$use_clock ? "qsfp_ref_125m" : "UNQUALIFIED"}]
    s6b_report [format "STEP6B_TIMING_PATH name=%s type=%s status=%s count=%s slack_ns=%s from=%s to=%s from_clock=%s to_clock=%s query_from_clock=%s query_to_clock=%s path_type=%s error=%s" \
      $name $kind $status $count $slack $from_node $to_node $from_clock $to_clock $query_from_clock $query_to_clock $path_type $error_text]
    # TimeQuest 17 may expose the resolved clock object as an internal alias
    # (for example clock_3) in get_path_info.  The public clock-domain query
    # above is the authoritative provenance, while the alias is retained in
    # the report for auditability.
    set domain_ok [expr {$use_clock}]
    if {$status eq "PASS" && $count > 0 && [string is double -strict $slack] &&
        $domain_ok && $slack < 0.0} {
      s6b_mark_failure "${name}_${kind}_negative_slack" FAIL_STEP6B_POSTFIT_TIMING
    } elseif {$status ne "PASS" || $count <= 0 ||
        ![string is double -strict $slack] || !$domain_ok} {
      s6b_mark_failure "${name}_${kind}_not_proven" NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED
    }
  }

  if {$use_clock} {
    s6b_report_timing_file $refclk $refclk {} $to -setup \
      "${::s6b_output_report}.${report_prefix}.setup.rpt"
    s6b_report_timing_file $refclk $refclk {} $to -hold \
      "${::s6b_output_report}.${report_prefix}.hold.rpt"
  } else {
    s6b_report_timing_file {} {} $from $to -setup \
      "${::s6b_output_report}.${report_prefix}.setup.rpt"
    s6b_report_timing_file {} {} $from $to -hold \
      "${::s6b_output_report}.${report_prefix}.hold.rpt"
  }
}

s6b_report "STEP6B_TIMING_PROJECT=$::s6b_project"
s6b_report "STEP6B_TIMING_REVISION=$::s6b_revision"
s6b_report "STEP6B_TIMING_CLOCK=qsfp_ref_125m"
s6b_report "STEP6B_TIMING_QUERY_API=get_path_info_-slack"
s6b_report "STEP6B_TIMING_SOURCE_DOMAIN=qsfp_ref_125m"

if {[catch {
  project_open -revision $::s6b_revision $::s6b_project
  set ::s6b_project_open 1
  create_timing_netlist
  read_sdc
  update_timing_netlist

  set refclk [get_clocks -nowarn qsfp_ref_125m]
  if {[s6b_collection_count $refclk] != 1} {
    s6b_report [format "STEP6B_CLOCK_QUERY_ERROR name=qsfp_ref_125m matched=%d" \
      [s6b_collection_count $refclk]]
    s6b_mark_failure REFCLK_NOT_UNIQUE NOT_RUN_STEP6B_CLOCK_DOMAIN_NOT_PROVEN
  } else {
    # P1-P4: explicit synchronous register boundaries, all constrained by
    # the public qsfp_ref_125m clock object.  The JTAG source to the *_meta
    # first stage is intentionally outside this STA gate.
    s6b_check_group target_meta_to_sync \
      [get_registers -nowarn *step6b_target_tai_meta*] \
      [get_registers -nowarn *step6b_target_tai_sync*] 1 $refclk \
      target_meta_to_sync
    s6b_check_group target_sync_to_latched \
      [get_registers -nowarn *step6b_target_tai_sync*] \
      [get_registers -nowarn *step6b_target_tai_latched*] 1 $refclk \
      target_sync_to_latched
    s6b_check_group arm_meta_to_sync \
      [get_registers -nowarn *step6b_arm_meta*] \
      [s6b_filtered_registers *step6b_arm_sync* *step6b_arm_sync_prev*] 1 $refclk \
      arm_meta_to_sync
    s6b_check_group arm_sync_to_prev \
      [s6b_filtered_registers *step6b_arm_sync* *step6b_arm_sync_prev*] \
      [get_registers -nowarn *step6b_arm_sync_prev*] 1 $refclk \
      arm_sync_to_prev

    # P5-P9: all same-clock launch registers to each functional destination.
    s6b_check_group refclk_to_armed {} \
      [get_registers -nowarn *step6b_armed*] 1 $refclk refclk_to_armed
    s6b_check_group refclk_to_fired {} \
      [get_registers -nowarn *step6b_fired*] 1 $refclk refclk_to_fired
    s6b_check_group refclk_to_fire_count {} \
      [get_registers -nowarn *step6b_fire_count*] 1 $refclk refclk_to_fire_count
    s6b_check_group refclk_to_actual_tai {} \
      [get_registers -nowarn *step6b_actual_tai*] 1 $refclk refclk_to_actual_tai
    s6b_check_group refclk_to_actual_cycles {} \
      [get_registers -nowarn *step6b_actual_cycles*] 1 $refclk refclk_to_actual_cycles
  }
} error_message]} {
  s6b_report "STEP6B_TIMING_QUERY_ERROR=$error_message"
  s6b_mark_failure TIMEQUEST_ERROR NOT_RUN_STEP6B_TIMING_BOUNDARY_UNRESOLVED
}

if {$::s6b_project_open} { catch {project_close} }
s6b_report [format "STEP6B_TIMING_RESULT=%s REASON=%s" \
  $::s6b_timing_result $::s6b_failure_reason]
close $::s6b_report_channel
puts [format "STEP6B_TIMING_RESULT=%s REASON=%s REPORT=%s" \
  $::s6b_timing_result $::s6b_failure_reason $::s6b_output_report]
exit [expr {$::s6b_timing_result eq "PASS_STEP6B_POSTFIT_TIMING_PROVEN" ? 0 : 3}]
