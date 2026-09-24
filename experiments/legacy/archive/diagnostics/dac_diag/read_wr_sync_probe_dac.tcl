# Read the WR status probe from every connected DE5a JTAG cable.
# Probe bits, from MSB to LSB in the returned word:
#   [15] CPU_RESET_n    [14] tx_enc_err       [13] rx_enc_err
#   [12] si_id_error    [11] phy_rst          [10] tx_disable
#   [9]  interrupt_n    [8]  module_present_n [7]  tx_ready
#   [6]  rx_ready       [5]  pps_valid        [4]  time_valid
#   [3]  link_ok        [2]  tm_link_up       [1]  phy_ready
#   [0]  si_config_done

package require ::quartus::insystem_source_probe

foreach hardware_name [get_hardware_names] {
  set device_names [get_device_names -hardware_name $hardware_name]
  if {[llength $device_names] == 0} {
    puts "${hardware_name}: no device"
    continue
  }

  set device_name [lindex $device_names 0]
  puts "=== ${hardware_name} ==="
  puts "device: ${device_name}"

  if {[catch {
    set instances [get_insystem_source_probe_instance_info \
      -hardware_name $hardware_name \
      -device_name $device_name]
    puts "instances: ${instances}"
  } error_message]} {
    puts "instance_error: ${error_message}"
    continue
  }

  if {[catch {
    start_insystem_source_probe \
      -hardware_name $hardware_name \
      -device_name $device_name
  } error_message]} {
    puts "start_error: ${error_message}"
    continue
  }

  if {[catch {
    puts "probe_hex: [read_probe_data -instance_index 0 -value_in_hex]"
  } error_message]} {
    puts "read_error: ${error_message}"
  }

  catch { end_insystem_source_probe }
}
