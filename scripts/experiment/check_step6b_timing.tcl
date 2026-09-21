# Step6B timing gate for Quartus Prime 17 TimeQuest.
#
# Arguments: project.qpf revision output_report
# The gate is deliberately narrower than global timing closure.  It only
# accepts the scheduler's target/ARM/compare paths when the named registers
# are present, matched timing paths exist for both setup and hold, and every
# reported slack is non-negative.

load_package flow
load_package report

if {[llength $argv] < 3} {
  puts "STEP6B_TIMING_RESULT=NOT_RUN_STEP6B_TIMING_NOT_PROVEN reason=ARGUMENTS"
  exit 2
}
set project [lindex $argv 0]
set revision [lindex $argv 1]
set output_report [file normalize [lindex $argv 2]]
file mkdir [file dirname $output_report]

set timing_result PASS
set failure_reason ""
set path_records {}

proc s6b_collection_count {collection} {
  if {[catch {get_collection_size $collection} count]} { return 0 }
  return $count
}

proc s6b_min_slack {paths} {
  set minimum 1.0e30
  set count 0
  foreach_in_collection path $paths {
    set slack ""
    catch {set slack [get_attribute $path slack]}
    if {![string is double -strict $slack]} { return [list INVALID $count] }
    set value [expr {$slack + 0.0}]
    if {$value < $minimum} { set minimum $value }
    incr count
  }
  if {$count == 0} { return [list EMPTY 0] }
  return [list $minimum $count]
}

proc s6b_join_names {collection} {
  set names {}
  foreach_in_collection item $collection {
    lappend names [get_object_name $item]
  }
  return [join $names ,]
}

proc s6b_check_group {name from_pattern to_pattern report_prefix} {
  global timing_result failure_reason path_records output_report
  set from [get_registers -nowarn $from_pattern]
  set to [get_registers -nowarn $to_pattern]
  set from_count [s6b_collection_count $from]
  set to_count [s6b_collection_count $to]
  if {$from_count == 0 || $to_count == 0} {
    lappend path_records [list $name 0 0 0 0 $from_count $to_count]
    set timing_result NOT_RUN_STEP6B_TIMING_NOT_PROVEN
    if {$failure_reason eq ""} { set failure_reason "${name}_register_match_empty" }
    return
  }

  set setup_paths {}
  set hold_paths {}
  catch {set setup_paths [get_timing_paths -from $from -to $to -npaths 100 -setup]}
  catch {set hold_paths [get_timing_paths -from $from -to $to -npaths 100 -hold]}
  set setup [s6b_min_slack $setup_paths]
  set hold [s6b_min_slack $hold_paths]
  set setup_min [lindex $setup 0]
  set hold_min [lindex $hold 0]
  set setup_count [lindex $setup 1]
  set hold_count [lindex $hold 1]
  lappend path_records [list $name $setup_min $hold_min $setup_count $hold_count $from_count $to_count]
  if {$setup_count == 0 || $hold_count == 0 ||
      ![string is double -strict $setup_min] ||
      ![string is double -strict $hold_min] ||
      $setup_min < 0.0 || $hold_min < 0.0} {
    set timing_result NOT_RUN_STEP6B_TIMING_NOT_PROVEN
    if {$failure_reason eq ""} { set failure_reason "${name}_setup_or_hold_not_proven" }
  }
  catch {report_timing -from $from -to $to -npaths 20 -detail full \
    -file "${output_report}.${report_prefix}.setup.rpt"}
  catch {report_timing -from $from -to $to -npaths 20 -detail full -hold \
    -file "${output_report}.${report_prefix}.hold.rpt"}
}

if {[catch {
  project_open -revision $revision $project
  create_timing_netlist
  read_sdc
  update_timing_netlist

  s6b_check_group target_latch \
    {*step6b_target_tai_meta*} {*step6b_target_tai_latched*} target_latch
  s6b_check_group arm_sync \
    {*step6b_arm_meta*} {*step6b_arm_sync*} arm_sync
  s6b_check_group comparator_fired \
    {*step6b_armed*} {*step6b_fired*} comparator_fired
  s6b_check_group comparator_actual_tai \
    {*step6b_armed*} {*step6b_actual_tai*} comparator_actual_tai
  s6b_check_group comparator_actual_cycles \
    {*step6b_armed*} {*step6b_actual_cycles*} comparator_actual_cycles

  set report_channel [open $output_report w]
  puts $report_channel "STEP6B_TIMING_PROJECT=$project"
  puts $report_channel "STEP6B_TIMING_REVISION=$revision"
  puts $report_channel "STEP6B_TIMING_CLOCK=qsfp_ref_125m"
  foreach record $path_records {
    lassign $record name setup_min hold_min setup_count hold_count from_count to_count
    puts $report_channel [format "STEP6B_TIMING_PATH name=%s setup_min_ns=%s hold_min_ns=%s setup_paths=%s hold_paths=%s matched_from=%s matched_to=%s" \
      $name $setup_min $hold_min $setup_count $hold_count $from_count $to_count]
  }
  puts $report_channel "STEP6B_TIMING_RESULT=$timing_result REASON=$failure_reason"
  close $report_channel
  project_close
} error_message]} {
  set timing_result NOT_RUN_STEP6B_TIMING_NOT_PROVEN
  if {$failure_reason eq ""} { set failure_reason "TIMEQUEST_ERROR" }
  set report_channel [open $output_report w]
  puts $report_channel "STEP6B_TIMING_ERROR=$error_message"
  puts $report_channel "STEP6B_TIMING_RESULT=$timing_result REASON=$failure_reason"
  close $report_channel
  catch {project_close}
}

puts "STEP6B_TIMING_RESULT=$timing_result REASON=$failure_reason REPORT=$output_report"
exit [expr {$timing_result eq "PASS" ? 0 : 3}]
