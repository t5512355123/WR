from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from audit_wr_failure_record_source_raw import (
    EXPECTED_RAW_SHA256,
    audit_file,
    analyze_text,
    decode_failure_word,
    decode_lock_result_word,
    delta16,
    decode_wr_state_word,
)


REPO_ROOT = Path(__file__).resolve().parents[5]
RAW_LOG = (
    REPO_ROOT
    / "experiments/step6/EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001"
    / "raw/observe/20260930T194058Z-wr-lock-event-continuity.log"
)
FROZEN = REPO_ROOT / "artifacts/milestones/step6_global_time/source/vendor/wrpc-sw"
BUILD_META = (
    REPO_ROOT
    / "experiments/step6/EXP-S6-WRH-SERVO-FIRST-TRACK-FIXED-SETP-OPEN-LOOP-20260930"
    / "raw/build"
)
PROGRAM_LOGS = (
    REPO_ROOT
    / "experiments/step6/EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001/raw/program"
)
PREFLIGHT = (
    REPO_ROOT
    / "experiments/step6/EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001/raw/preflight"
)


class WrFailureRecordAuditTests(unittest.TestCase):
    def test_a6c_decodes_failure_record_and_invalid_disable_ptp_as_unknown(self):
        decoded = decode_failure_word(0x02020001)
        self.assertEqual(decoded, {
            "counter_low8": 1,
            "last_failure_state": 2,
            "last_failure_role": 2,
            "disable_cause": None,
            "disable_valid": 0,
            "disable_ptp_state": None,
        })

    def test_a8c_decodes_s_lock_timeout_and_low16_tics(self):
        decoded = decode_lock_result_word(0xB9190601)
        self.assertEqual(decoded["result_code"], 1)
        self.assertEqual(decoded["check_lock"], 0)
        self.assertEqual(decoded["failure_reason"], 3)
        self.assertEqual(decoded["failure_reason_name"], "WR_S_LOCK_TIMEOUT")
        self.assertEqual(decoded["failure_tics_low16"], 0xB919)

    def test_wr_state_context_decodes_slave_parent_and_rearm_state(self):
        decoded = decode_wr_state_word(0xA0408B5C)
        self.assertEqual(decoded["wr_state"], 1)
        self.assertEqual(decoded["wr_next_state"], 1)
        self.assertEqual(decoded["wr_mode"], 2)
        self.assertEqual(decoded["parent_is_wr_node"], 1)
        self.assertEqual(decoded["parent_wr_config"], 3)

    def test_low16_tics_delta_distinguishes_rollover(self):
        self.assertEqual(delta16(0xFFF0, 0x0010), (32, "VISIBLE_LOWWORD_ROLLOVER"))
        self.assertEqual(delta16(0, 0xB919), (0xB919, "NONDECREASING_LOWWORD"))
        self.assertFalse("seconds" in str(delta16(0, 0xB919)).lower())

    def test_actual_raw_capture_hash_and_failure_boundary(self):
        result = audit_file(RAW_LOG)
        self.assertEqual(result["raw_sha256"], EXPECTED_RAW_SHA256)
        self.assertEqual(result["sample_count"], 741)
        self.assertEqual(result["required_valid_rows"], 741)
        self.assertEqual(result["failure_edge_sample"], 738)
        self.assertEqual(result["failure_counter_before_low8"], 0)
        self.assertEqual(result["failure_counter_after_low8"], 1)
        self.assertEqual(result["lock_result_word_raw"], "0xB9190601")
        self.assertEqual(result["lock_result"]["failure_reason_name"], "WR_S_LOCK_TIMEOUT")
        self.assertEqual(result["failure_record"]["disable_valid"], 0)
        self.assertIsNone(result["failure_record"]["disable_ptp_state"])
        self.assertEqual(result["post_failure_state_names"], ["WRS_PRESENT"] * 3)
        self.assertTrue(result["lock_reason_stable_for_samples_738_740"])
        self.assertTrue(result["lock_tics_stable_for_samples_738_740"])
        self.assertFalse(result["lock_result_read_exact_bracket_logged"])
        self.assertEqual(result["lock_result_read_bound_width_ms"], 11)
        self.assertFalse(result["ptp_state_at_failure_captured"])
        self.assertEqual(result["source_event_count"], 0)

    def test_frozen_source_confirms_reason_packing_and_rearm_guard(self):
        task_diags = (FROZEN / "lib/task-diags.c").read_text(encoding="utf-8")
        wdiags = (FROZEN / "dev/wdiags.c").read_text(encoding="utf-8")
        diag_registers = (
            FROZEN / "include/hw/wrc_diags_regs.h"
        ).read_text(encoding="utf-8")
        constants = (
            FROZEN
            / "ppsi/proto-ext-whiterabbit/wr-constants.h"
        ).read_text(encoding="utf-8")
        common_fun = (
            FROZEN
            / "ppsi/proto-ext-whiterabbit/common-fun.c"
        ).read_text(encoding="utf-8")
        ptp_init = (
            FROZEN / "ppsi/arch-wrpc/wrc_ptp_ppsi.c"
        ).read_text(encoding="utf-8")
        s_lock = (
            FROZEN
            / "ppsi/proto-ext-whiterabbit/state-wr-s-lock.c"
        ).read_text(encoding="utf-8")
        self.assertIn("wrpc_wr_last_fail_reason & 0x7fu) << 9", task_diags)
        self.assertIn("wrpc_wr_last_fail_tics & 0xffffu) << 16", task_diags)
        self.assertIn("wrpc_wr_handshake_fail_count & 0xffffu", task_diags)
        self.assertIn("#define WRC_DIAGS_WDIAG_SERVO_RESTART_COUNT 0x6cUL", diag_registers)
        self.assertIn(
            "wdiag_write(WRC_DIAGS_WDIAG_SERVO_RESTART_COUNT, failure)",
            wdiags,
        )
        self.assertIn("wdiag_write(0x8c, result)", wdiags)
        self.assertIn("wdiags_wr_disable_debug_valid = 1", wdiags)
        self.assertIn("#define WR_FAIL_REASON_WR_S_LOCK_TIMEOUT", constants)
        self.assertIn("WR_FAIL_REASON_WR_S_LOCK_TIMEOUT", s_lock)
        self.assertIn("wr_auto_rearm_slave_after_s_lock_timeout(ppi, reason)", common_fun)
        self.assertIn("if (wr_auto_rearm_slave_after_s_lock_timeout(ppi, reason))", common_fun)
        self.assertIn("WR_M_AND_S", constants)
        self.assertIn("wrpc_wr_handshake_fail_count = 0", ptp_init)
        self.assertIn("wrpc_wr_last_fail_reason = 0", ptp_init)
        self.assertIn("wrpc_wr_last_fail_tics = 0", ptp_init)
        self.assertIn("wdiags_wr_disable_debug_valid = 0", wdiags)

    def test_build_provenance_matches_programmed_sof_hashes(self):
        slave = (BUILD_META / "20260930T133328Z-build-info-slave.txt").read_text()
        master = (BUILD_META / "20260930T133328Z-build-info-master.txt").read_text()
        self.assertIn(
            "SOF_SHA256=13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19",
            slave,
        )
        self.assertIn(
            "SOF_SHA256=697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a",
            master,
        )
        for metadata in (slave, master):
            self.assertIn("SOURCE_ORIGIN_COMMIT=74dc28862653d306e0450cf437ba6d3a230d979d", metadata)
            self.assertIn("REPOSITORY_COMMIT=9c9afa345c1de03760ec9ee07eb742888c3fa8fe", metadata)
        preflight_sofs = (PREFLIGHT / "20260930T193915Z-sof-sha256.txt").read_text()
        self.assertIn("13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19", preflight_sofs)
        self.assertIn("697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a", preflight_sofs)
        slave_program = (PROGRAM_LOGS / "20260930T193915Z-slave-program.log").read_text()
        master_program = (PROGRAM_LOGS / "20260930T193915Z-master-program.log").read_text()
        self.assertIn("checksum 0x30B1E229", slave_program)
        self.assertIn("checksum 0x30B18F28", master_program)

    def test_lock_result_word_rejects_no_particular_failure_semantics(self):
        # The raw bits are decoded independently of the old A6C-derived
        # WR_FAILURE_REASON field emitted by the original Tcl observer.
        result = analyze_text(
            "S6E_SAMPLE sample=0 elapsed_ms=0 REQUIRED_ROW_VALID=1 "
            "WR_FAILURE_RAW=00000000 WR_FAILURE_DELTA_U8=0 "
            "LOCK_RESULT_RAW=00000001 WR_STATE_RAW=A041135C "
            "WR_STATE_NAME=WRS_S_LOCK REJECT_READ_END_MS=100 "
            "POLL_READ_BEGIN_MS=111 SLOCK_TAIL_STABLE=0\n"
            "S6E_SAMPLE sample=1 elapsed_ms=1 REQUIRED_ROW_VALID=1 "
            "WR_FAILURE_RAW=02020001 WR_FAILURE_DELTA_U8=1 "
            "LOCK_RESULT_RAW=B9190601 WR_STATE_RAW=A0408B5C "
            "WR_STATE_NAME=WRS_PRESENT REJECT_READ_END_MS=200 "
            "POLL_READ_BEGIN_MS=211 SLOCK_TAIL_STABLE=0\n"
            "S6E_SAMPLE sample=2 elapsed_ms=2 REQUIRED_ROW_VALID=1 "
            "WR_FAILURE_RAW=02020001 WR_FAILURE_DELTA_U8=0 "
            "LOCK_RESULT_RAW=B9190601 WR_STATE_RAW=A0408B5C "
            "WR_STATE_NAME=WRS_PRESENT REJECT_READ_END_MS=300 "
            "POLL_READ_BEGIN_MS=311 SLOCK_TAIL_STABLE=0\n"
            "S6E_SAMPLE sample=3 elapsed_ms=3 REQUIRED_ROW_VALID=1 "
            "WR_FAILURE_RAW=02020001 WR_FAILURE_DELTA_U8=0 "
            "LOCK_RESULT_RAW=B9190601 WR_STATE_RAW=A0408B5C "
            "WR_STATE_NAME=WRS_PRESENT REJECT_READ_END_MS=400 "
            "POLL_READ_BEGIN_MS=411 SLOCK_TAIL_STABLE=0\n"
            "S6E_SAMPLE sample=4 elapsed_ms=4 REQUIRED_ROW_VALID=1 "
            "WR_FAILURE_RAW=02020001 WR_FAILURE_DELTA_U8=0 "
            "LOCK_RESULT_RAW=B9190601 WR_STATE_RAW=A0408B5C "
            "WR_STATE_NAME=WRS_PRESENT REJECT_READ_END_MS=500 "
            "POLL_READ_BEGIN_MS=511 SLOCK_TAIL_STABLE=0\n"
            "S6E_STOP elapsed_ms=4 reason=NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT\n"
        )
        self.assertEqual(result["failure_edge_sample"], 1)
        self.assertEqual(result["lock_result"]["failure_reason"], 3)
        self.assertEqual(result["raw_observer_stop_reason"], "NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT")
        self.assertFalse(result["extension_disable_recorded"])


if __name__ == "__main__":
    unittest.main()
