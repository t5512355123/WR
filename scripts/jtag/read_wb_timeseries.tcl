# White Rabbit JTAG 唯讀時間序列觀測。
#
# 用法：
#   quartus_stp -t read_wb_timeseries.tcl ?samples? ?gap_ms?
#
# 每個 sample 直接重用既有的 read_wb_runtime.tcl，因此不新增
# FPGA register、firmware 功能或同步控制路徑。gap_ms 是兩次完整
# snapshot 之間的最小等待時間；JTAG 讀取本身所花的時間另計。

package require ::quartus::insystem_source_probe

set samples 60
set gap_ms 1000

if {[llength $argv] >= 1} {
  set samples [expr {int([lindex $argv 0])}]
}
if {[llength $argv] >= 2} {
  set gap_ms [expr {int([lindex $argv 1])}]
}
if {$samples <= 0 || $gap_ms < 0} {
  error "samples must be > 0 and gap_ms must be >= 0"
}

set runtime_script [file join [file dirname [info script]] read_wb_runtime.tcl]
if {![file exists $runtime_script]} {
  error "missing runtime script: $runtime_script"
}

puts [format "TIME_SERIES_CONFIG samples=%d gap_ms=%d script=%s" \
      $samples $gap_ms $runtime_script]

for {set sample 0} {$sample < $samples} {incr sample} {
  puts [format "=== TIME_SERIES_SAMPLE %03d/%03d ===" \
        [expr {$sample + 1}] $samples]
  flush stdout
  source $runtime_script
  flush stdout
  if {$sample + 1 < $samples && $gap_ms > 0} {
    after $gap_ms
  }
}

puts "TIME_SERIES_DONE"
