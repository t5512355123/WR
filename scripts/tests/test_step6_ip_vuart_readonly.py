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
        self.assertIn('error "query_mode must be ip or calibration"', self.observer)
        self.assertNotIn('"sfp match"', self.observer)

    def test_output_is_read_from_host_vuart_rx_fifo(self):
        self.assertIn("0x00100514", self.observer)
        self.assertIn("(($word >> 8) & 1)", self.observer)

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


if __name__ == "__main__":
    unittest.main()
