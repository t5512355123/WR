import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OBSERVER = ROOT / "scripts" / "jtag" / "read_step6_ip_vuart.tcl"
IP_COMMAND = ROOT / "vendor" / "wrpc-sw" / "shell" / "cmd_ip.c"


class Step6IpVuartObserverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.observer = OBSERVER.read_text(encoding="utf-8")
        cls.ip_command = IP_COMMAND.read_text(encoding="utf-8")

    def test_stimulus_is_only_read_only_ip_get_on_slave(self):
        self.assertIn('ip { set read_only_queries [list "ip get"] }', self.observer)
        self.assertIn('string match "*1-11.2*" $hardware_name', self.observer)
        writes = re.findall(
            r"\bwb_write\s+\$hardware_name\s+(0x[0-9A-Fa-f]+)",
            self.observer,
        )
        self.assertEqual(writes, ["0x00100510"])

    def test_calibration_mode_uses_only_fixed_read_only_commands(self):
        self.assertIn('calibration { set read_only_queries [list "delays" "sfp show"] }',
                      self.observer)
        self.assertIn('error "query_mode must be ip, calibration, sfp_params, sfp_live, pll_read, pll_read_both, or ram_read"', self.observer)
        self.assertNotIn('"sfp match"', self.observer)

    def test_ram_read_cannot_send_a_write_value_or_mmio_address(self):
        mode = self.observer.split('    ram_read {', 1)[1].split('    default {', 1)[0]
        self.assertIn('regexp {^[0-9a-fA-F]{1,8}$}', mode)
        self.assertIn('$numeric_address >= 0x30000', mode)
        self.assertIn('($numeric_address & 3)', mode)
        self.assertIn('format "devmem %08x" $numeric_address', mode)
        self.assertIn('[llength $read_only_queries] > 16', mode)
        self.assertNotIn('format "devmem %08x %', mode)
        ll = (ROOT / 'vendor/wrpc-sw/shell/cmd_ll.c').read_text(encoding='utf-8')
        read_branch = ll.split('static int cmd_devmem', 1)[1].split('DEFINE_WRC_COMMAND(devmem)', 1)[0]
        self.assertIn('if (args[1])', read_branch)
        self.assertIn('*addr = value;', read_branch)
        self.assertIn('} else {', read_branch)

    def test_pll_read_is_statistics_and_get_phase_only(self):
        self.assertIn('pll_read { set read_only_queries [list "pll stat" "pll gps 0"] }', self.observer)
        self.assertIn('pll_read_both { set read_only_queries [list "pll stat" "pll gps 0"] }', self.observer)
        self.assertIn('$query_mode eq "pll_read_both" && [string match "*1-11.1*" $hardware_name]', self.observer)
        pll = (ROOT / 'vendor/wrpc-sw/shell/cmd_pll.c').read_text(encoding='utf-8')
        stat = pll.split('case CMD_STAT:', 1)[1].split('case CMD_SPS:', 1)[0]
        gps = pll.split('case CMD_GPS:', 1)[1].split('case CMD_START:', 1)[0]
        self.assertIn('spll_show_stats();', stat)
        self.assertIn('spll_get_phase_shift(', gps)
        self.assertNotIn('spll_set_phase_shift(', gps)

    def test_sfp_params_mode_sends_only_the_read_only_snapshot_command(self):
        self.assertIn('sfp_params { set read_only_queries [list "sfp params"] }',
                      self.observer)
        self.assertIn('sfp_live { set read_only_queries [list "sfp params live"] }',
                      self.observer)
        self.assertNotIn('sfp_params { set read_only_queries [list "sfp match"] }',
                         self.observer)

    def test_output_is_read_from_host_vuart_rx_fifo(self):
        self.assertIn("0x00100514", self.observer)
        self.assertIn("(($word >> 8) & 1)", self.observer)

    def test_bundled_wb_payload_settles_before_toggle_commit(self):
        transfer = self.observer.split('proc wb_transfer', 1)[1].split('proc wb_read', 1)[0]
        self.assertLess(transfer.index('encode_wb_command $preload_cmd'),
                        transfer.index('set toggle [expr {$prior_toggle ^ 1}]'))
        self.assertIn('$p1 == $p2 && $p2 == $p3', transfer)
        self.assertIn('(($p3 >> 36) & 1) == 0', transfer)
        self.assertIn('0xA5A5', transfer)

    def test_pre_drain_preserves_pages_and_backpressure_has_time_bound(self):
        drain = self.observer.split('proc drain_preexisting_uart', 1)[1].split('proc capture_vuart_reply', 1)[0]
        self.assertIn('append all_hex $chunk_hex', drain)
        self.assertIn('append all_text $chunk_text', drain)
        self.assertIn('[string length $all_hex] < 16384', drain)
        send = self.observer.split('proc send_vuart_command', 1)[1].split('proc drain_preexisting_uart', 1)[0]
        self.assertIn('[clock milliseconds] - $wait_start < $timeout_ms', send)
        self.assertNotIn('$n < 100', send)

    def test_reply_capture_appends_full_pages_before_continuing(self):
        capture = self.observer.split("proc capture_vuart_reply", 1)[1].split("\n}\n", 1)[0]
        self.assertLess(capture.index("append all_hex $chunk_hex"),
                        capture.index('if {$status eq "LIMIT"}'))
        self.assertIn('if {$chunk_hex eq ""} { return [list LIMIT $all_hex $all_text] }',
                      capture)
        self.assertIn("after 1\n      continue", capture)

    def test_observer_gates_command_on_shell_and_vuart_idle(self):
        for token in (
            "post_startup_armed != 1",
            "cpu_reset != 0",
            "marker_mask != 0x0f",
            "boot_generation != $astat_generation",
            "command_stage != 0",
            "$input_pending",
        ):
            self.assertIn(token, self.observer)

    def test_persistent_runtime_breadcrumbs_do_not_block_read_only_query(self):
        self.assertIn("persistent event-correlation breadcrumbs", self.observer)
        self.assertIn("must not block this read-only `ip get` query", self.observer)
        self.assertNotIn("RUNTIME_NOT_IDLE", self.observer)

    def test_failed_preflight_emits_each_gate_component_for_diagnosis(self):
        for token in (
            "failed=%s",
            "POST_STARTUP_NOT_ARMED",
            "CPU_RESET_ASSERTED",
            "SHELL_MARKERS_INCOMPLETE",
            "GENERATION_MISMATCH",
            "COMMAND_STAGE_NOT_IDLE",
            "VUART_INPUT_PENDING",
            "gate_details={%s}",
        ):
            self.assertIn(token, self.observer)

    def test_firmware_ip_get_branch_reads_without_setting_network_config(self):
        self.assertIn('!strcasecmp(args[0], "get")', self.ip_command)
        self.assertIn("getIP(ip);", self.ip_command)
        self.assertIn('!strcasecmp(args[0], "set")', self.ip_command)
        self.assertIn("setIP(ip);", self.ip_command)
        self.assertLess(self.ip_command.index('!strcasecmp(args[0], "get")'),
                        self.ip_command.index('!strcasecmp(args[0], "set")'))

    def test_firmware_calibration_queries_do_not_apply_new_values(self):
        ll = (ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"
              / "vendor" / "wrpc-sw" / "shell" / "cmd_ll.c").read_text(encoding="utf-8")
        sfp = (ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"
               / "vendor" / "wrpc-sw" / "shell" / "cmd_sfp.c").read_text(encoding="utf-8")
        self.assertIn('"delays"', ll)
        self.assertIn('pp_printf("tx: %i   rx: %i\\n"', ll)
        self.assertIn('storage_get_sfp(&sfp, SFP_GET, i)', sfp)

    def test_firmware_sfp_params_observer_only_reads_cached_and_local_state(self):
        sfp_path = (ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"
                    / "vendor" / "wrpc-sw" / "shell" / "cmd_sfp.c")
        sfp = sfp_path.read_text(encoding="utf-8")
        observer = sfp.split("static void print_cached_sfp_params(void)", 1)[1]
        observer = observer.split("static const char * const sfp_cmds", 1)[0]
        observer = re.sub(r"/\*.*?\*/|//[^\n]*", "", observer, flags=re.DOTALL)
        self.assertRegex(sfp, r'\[5\]\s*=\s*"params"')
        self.assertRegex(sfp, r"case 5:\s*print_cached_sfp_params\(\);")
        self.assertIn("storage_match_sfp(&lookup)", observer)
        self.assertIn("SFP_CACHED_HEADER", observer)
        self.assertIn("SFP_ACTIVE_CAL", observer)
        self.assertNotIn("sfp_match(", observer)
        self.assertNotIn("storage_get_sfp", observer)
        self.assertNotIn("storage_sfpdb_erase", observer)
        self.assertNotIn("bb_i2c_put_byte", observer)
        self.assertNotRegex(observer, r"sfp_info\.sfp_params\.[A-Za-z_]+\s*=")

    def test_live_sfp_read_is_explicit_local_and_checks_address_acks(self):
        source = (ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"
                  / "vendor" / "wrpc-sw" / "dev" / "sfp.c").read_text(encoding="utf-8")
        header = (ROOT / "artifacts" / "milestones" / "step6_global_time" / "source"
                  / "vendor" / "wrpc-sw" / "shell" / "cmd_sfp.c").read_text(encoding="utf-8")
        reader = source.split("static int sfp_read_i2c_checked", 1)[1].split(
            "int sfp_read_eeprom_diagnostic", 1)[0]
        self.assertIn("sfp_read_header_diagnostic", source)
        self.assertEqual(reader.count("bb_i2c_put_byte(dev,"), 3)
        self.assertEqual(reader.count("< 0)"), 3)
        self.assertIn("SFF-8636 serial identification", source)
        self.assertIn("SFP_QSFP_PAGE_SELECT", source)
        self.assertIn("SFP_QSFP_SERIAL_ID_START", source)
        self.assertIn("SFP_QSFP_VENDOR_PN_OFFSET", source)
        self.assertIn("memcmp(lower, sfp_info.sfp_header", header)
        self.assertIn('print_raw_bytes("QSFP_LIVE_SERIAL_RAW"', header)
        self.assertIn("QSFP_LIVE_DB_LOOKUP skipped=invalid_serial_id", header)
        self.assertNotIn("sfp_info.sfp_params.", header.split(
            "static void print_live_sfp_header(void)", 1)[1].split(
            "static const char * const sfp_cmds", 1)[0])


if __name__ == "__main__":
    unittest.main()
