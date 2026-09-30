from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import tkinter
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from analyze_publication_trace import (  # noqa: E402
    analyze_trace,
    normalize_timed_read,
    strict_offset_in_band,
    validate_frame,
)


ROOT = Path(__file__).resolve().parents[2]
TCL_POLICY = ROOT / "scripts" / "publication_contract_policy.tcl"
VALID_AUDIT = {
    "field_writer_contract_complete": True,
    "writer_aliases_complete": True,
    "publication_protocol_proven": True,
    "sequence_owner_proven": True,
    "aba_excluded_for_60s": True,
}
GROUP_FIELDS = {
    "EVENT": ("STATE", "RX", "TX", "A8C"),
    "PHASE": ("CKO", "SETP", "UCNT"),
}


def make_frame(kind: str, sequence: int, publication: int) -> dict:
    start = sequence * 30
    fields = GROUP_FIELDS[kind]
    payload = {}
    cursor = start + 1
    for index, field in enumerate(fields):
        raw_value = publication + index + 1
        if field == "UCNT":
            raw_value = 0x100 + sequence
        payload[field] = {
            "raw": f"{raw_value:08X}",
            "valid": True,
            "transport_valid": True,
            "read_start_ms": cursor,
            "read_end_ms": cursor + 1,
        }
        cursor += 2

    generation = publication * 2
    return {
        "kind": kind,
        "frame_start_ms": start,
        "frame_end_ms": cursor,
        "data_valid_before": 1,
        "snapshot_before": 0,
        "generation_before": generation,
        "generation_inverse_before": (~generation) & 0xFFFFFFFF,
        "owner_before": "DIAG_PUBLISHER",
        "overlay_active_before": False,
        "data_valid_after": 1,
        "snapshot_after": 0,
        "generation_after": generation,
        "generation_inverse_after": (~generation) & 0xFFFFFFFF,
        "owner_after": "DIAG_PUBLISHER",
        "overlay_active_after": False,
        "payload": payload,
    }


def valid_trace() -> dict:
    frames = []
    publication = 2
    for index in range(10):
        frames.append(make_frame("EVENT", index * 2, publication))
        frames.append(make_frame("PHASE", index * 2 + 1, publication))
        publication += 2
    return {
        "source_audit": copy.deepcopy(VALID_AUDIT),
        "capture": {
            "start_ms": 0,
            "end_ms": 600,
            "step1_gate_initial": 1,
            "step1_gate_final": 1,
            "reset_signature_valid": True,
            "reset_changed": False,
            "wb_timeout_count": 0,
            "wb_unstable_count": 0,
            "unexpected_transaction_trigger_count": 0,
        },
        "frames": frames,
        "status_observations": [
            {"name": "SSTAT", "raw": "00000101", "read_start_ms": 2, "read_end_ms": 3},
            {"name": "A6C", "raw": "00000000", "read_start_ms": 4, "read_end_ms": 5},
            {"name": "SSTAT", "raw": "00000401", "read_start_ms": 500, "read_end_ms": 501},
            {"name": "A6C", "raw": "00000000", "read_start_ms": 502, "read_end_ms": 503},
        ],
    }


def _to_tcl(interp: tkinter.Tcl, value, parent_key: str | None = None):
    if isinstance(value, dict):
        args = []
        for key, child in value.items():
            args.extend((str(key), _to_tcl(interp, child, str(key))))
        return interp.call("dict", "create", *args)
    if isinstance(value, (list, tuple)):
        return interp.call("list", *(_to_tcl(interp, child, parent_key) for child in value))
    if value is True:
        if parent_key in {"data_valid_before", "data_valid_after", "snapshot_before", "snapshot_after"}:
            return "BOOL_TRUE"
        return "1"
    if value is False:
        if parent_key in {"data_valid_before", "data_valid_after", "snapshot_before", "snapshot_after"}:
            return "BOOL_FALSE"
        return "0"
    if value is None:
        return ""
    return str(value)


def cross_language_vectors():
    vectors = []
    valid = make_frame("PHASE", 0, 2)
    vectors.append(("positive", valid, None))

    frame = copy.deepcopy(valid)
    frame["data_valid_before"] = 0
    vectors.append(("data_valid_low", frame, "DATA_VALID_GUARD_REJECTED"))

    frame = copy.deepcopy(valid)
    frame["data_valid_before"] = True
    vectors.append(("boolean_is_not_integer_valid", frame, "DATA_VALID_GUARD_REJECTED"))

    frame = copy.deepcopy(valid)
    frame["snapshot_after"] = 1
    vectors.append(("snapshot_active", frame, "DATA_SNAPSHOT_GUARD_REJECTED"))

    frame = copy.deepcopy(valid)
    frame["generation_after"] += 2
    frame["generation_inverse_after"] = (~frame["generation_after"]) & 0xFFFFFFFF
    vectors.append(("publication_crossed_read", frame, "PUBLICATION_SEQUENCE_CHANGED"))

    frame = copy.deepcopy(valid)
    frame["generation_inverse_after"] ^= 1
    vectors.append(("inverse_mismatch", frame, "PUBLICATION_SEQUENCE_INVERSE_MISMATCH"))

    frame = copy.deepcopy(valid)
    frame["generation_before"] |= 1
    frame["generation_after"] |= 1
    frame["generation_inverse_before"] = (~frame["generation_before"]) & 0xFFFFFFFF
    frame["generation_inverse_after"] = (~frame["generation_after"]) & 0xFFFFFFFF
    vectors.append(("uncommitted_generation", frame, "PUBLICATION_SEQUENCE_UNCOMMITTED"))

    frame = copy.deepcopy(valid)
    frame["owner_before"] = "UNKNOWN"
    vectors.append(("unknown_owner", frame, "PUBLICATION_OWNER_OR_OVERLAY_REJECTED"))

    frame = copy.deepcopy(valid)
    frame["overlay_active_after"] = True
    vectors.append(("overlay_active", frame, "PUBLICATION_OWNER_OR_OVERLAY_REJECTED"))

    frame = copy.deepcopy(valid)
    frame["payload"]["SSTAT"] = copy.deepcopy(frame["payload"]["CKO"])
    vectors.append(("wrong_payload_membership", frame, "PAYLOAD_GROUP_MEMBERSHIP_INVALID"))

    frame = copy.deepcopy(valid)
    frame["payload"]["CKO"]["valid"] = False
    vectors.append(("payload_invalid", frame, "PAYLOAD_NOT_VALID"))

    frame = copy.deepcopy(valid)
    frame["payload"]["CKO"].pop("read_start_ms")
    vectors.append(("timestamp_missing", frame, "PAYLOAD_TIMESTAMP_INVALID"))

    frame = copy.deepcopy(valid)
    frame["payload"]["SETP"]["read_start_ms"] = frame["payload"]["CKO"]["read_start_ms"]
    vectors.append(("timestamp_overlap_or_order", frame, "PAYLOAD_TIMESTAMP_OUTSIDE_OR_NONMONOTONIC"))

    frame = copy.deepcopy(valid)
    frame["payload"]["CKO"] = "malformed-record"
    vectors.append(("malformed_payload_record", frame, "PAYLOAD_RECORD_MISSING"))

    frame = copy.deepcopy(valid)
    frame["payload"]["CKO"]["raw"] = "FFFFFFFFF"
    vectors.append(("raw_word_wider_than_u32", frame, "PAYLOAD_RAW_INVALID"))
    return vectors


class PublicationTraceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tcl = tkinter.Tcl()
        cls.tcl.call("source", str(TCL_POLICY))

    def test_python_and_tcl_policy_agree_on_identical_fixture_vectors(self):
        for name, frame, expected_reason in cross_language_vectors():
            with self.subTest(vector=name):
                python_ok, python_reason, _ = validate_frame(frame)
                tcl_reason = self.tcl.call("::s6pub::validate_frame", _to_tcl(self.tcl, frame))
                self.assertEqual(python_reason, expected_reason)
                self.assertEqual(tcl_reason, expected_reason or "NONE")
                self.assertEqual(python_ok, expected_reason is None)

    def test_synthetic_contract_control_passes_without_claiming_step6(self):
        result = analyze_trace(valid_trace())
        self.assertEqual(result["verdict"], "OFFLINE_OBSERVER_CONTRACT_PASS_NOT_STEP6")
        self.assertEqual(result["event_distinct_publications"], 10)
        self.assertEqual(result["phase_distinct_publications"], 10)
        self.assertEqual(result["event_trusted_frames"], 10)
        self.assertEqual(result["phase_trusted_frames"], 10)
        self.assertTrue(result["phase_ucnt_advanced"])
        self.assertFalse(result["cross_group_atomicity_claimed"])
        self.assertFalse(result["sstat_a6c_joined_to_frames"])
        self.assertFalse(result["step6_offset_claimed"])
        self.assertFalse(result["stable_window_established"])

    def test_actual_source_audit_fixture_blocks(self):
        fixture = json.loads((ROOT / "analysis" / "current-source-audit.json").read_text())
        result = analyze_trace(fixture)
        self.assertEqual(result["verdict"], "BLOCKED_SOURCE_AUDIT_UNPROVEN")
        self.assertIn("PUBLICATION_PROTOCOL_PROVEN_UNPROVEN", result["source_audit_blockers"])
        self.assertEqual(result["phase_trusted_frames"], 0)

    def test_latest_five_legacy_raw_frames_replay_with_zero_trusted_phase_frames(self):
        replay = json.loads((ROOT / "analysis" / "legacy_raw_replay.json").read_text())
        result = analyze_trace(replay)
        self.assertEqual(replay["replay_metadata"]["raw_attempt_count"], 5)
        self.assertEqual(result["phase_candidate_frames"], 5)
        self.assertEqual(result["phase_trusted_frames"], 0)
        self.assertEqual(result["candidate_rejection_reasons"], {"PUBLICATION_SEQUENCE_CHANGED": 5})
        self.assertFalse(result["stable_window_established"])
        self.assertEqual(result["servo_offset_verdict"], "NOT_ESTABLISHED")
        for index, frame in enumerate(replay["frames"]):
            with self.subTest(raw_frame=index):
                self.assertEqual(validate_frame(frame)[1], "PUBLICATION_SEQUENCE_CHANGED")
                self.assertEqual(
                    self.tcl.call("::s6pub::validate_frame", _to_tcl(self.tcl, frame)),
                    "PUBLICATION_SEQUENCE_CHANGED",
                )

    def test_legacy_timed_read_key_aliases_normalize_identically_in_python_and_tcl(self):
        for raw_field, canonical in (
            ("WR_STATE_RAW", "STATE"),
            ("WR_RX_RAW", "RX"),
            ("WR_TX_RAW", "TX"),
        ):
            with self.subTest(raw_field=raw_field):
                expected = {
                    f"{canonical}_READ_BEGIN_MS": 101,
                    f"{canonical}_READ_END_MS": 102,
                }
                self.assertEqual(normalize_timed_read(raw_field, 101, 102), expected)
                self.assertEqual(
                    self.tcl.call("::s6pub::normalize_timed_read", raw_field, "101", "102"),
                    _to_tcl(self.tcl, expected),
                )

    def test_strict_sixty_ps_boundary_matches_tcl(self):
        for value, expected in ((-61, False), (-60, False), (-59, True), (0, True), (59, True), (60, False), (61, False)):
            with self.subTest(cko_ps=value):
                self.assertEqual(strict_offset_in_band(value), expected)
                self.assertEqual(int(self.tcl.call("::s6pub::strict_offset_in_band", str(value))), int(expected))

    def test_same_ucnt_with_changed_phase_payload_rejects(self):
        trace = valid_trace()
        phase_frames = [frame for frame in trace["frames"] if frame["kind"] == "PHASE"]
        phase_frames[1]["payload"]["UCNT"]["raw"] = phase_frames[0]["payload"]["UCNT"]["raw"]
        phase_frames[1]["payload"]["CKO"]["raw"] = "DEADBEEF"
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "REJECTED_SAME_UCNT_PHASE_PAYLOAD_CONFLICT")

    def test_ucnt_rollback_or_reset_rejects(self):
        trace = valid_trace()
        phase_frames = [frame for frame in trace["frames"] if frame["kind"] == "PHASE"]
        phase_frames[2]["payload"]["UCNT"]["raw"] = "00000001"
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "REJECTED_PHASE_UCNT_ROLLBACK_OR_RESET")

    def test_publication_generation_rollback_or_wrap_stops(self):
        trace = valid_trace()
        phase_frames = [frame for frame in trace["frames"] if frame["kind"] == "PHASE"]
        phase_frames[2]["generation_before"] = phase_frames[2]["generation_after"] = 2
        phase_frames[2]["generation_inverse_before"] = phase_frames[2]["generation_inverse_after"] = 0xFFFFFFFD
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "REJECTED_PUBLICATION_SEQUENCE_ROLLBACK_OR_WRAP")
        self.assertEqual(result["stop_reason"], "PHASE_PUBLICATION_SEQUENCE_ROLLBACK_OR_WRAP")

    def test_reset_signature_change_rejects(self):
        trace = valid_trace()
        trace["capture"]["reset_changed"] = True
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "REJECTED_STEP1_OR_RESET_GATE")

    def test_transport_timeout_rejects(self):
        trace = valid_trace()
        trace["capture"]["wb_timeout_count"] = 1
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "REJECTED_TRANSPORT_OR_UNEXPECTED_TRIGGER")
        self.assertEqual(result["stop_reason"], "WB_TIMEOUT_COUNT")

    def test_endpoint_data_valid_does_not_replace_source_order_proof(self):
        trace = valid_trace()
        trace["source_audit"]["publication_protocol_proven"] = False
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "BLOCKED_SOURCE_AUDIT_UNPROVEN")
        self.assertEqual(result["phase_trusted_frames"], 0)

    def test_field_writer_audit_is_mandatory(self):
        trace = valid_trace()
        trace["source_audit"]["field_writer_contract_complete"] = False
        result = analyze_trace(trace)
        self.assertIn("FIELD_WRITER_CONTRACT_COMPLETE_UNPROVEN", result["source_audit_blockers"])

    def test_sequence_ownership_audit_is_mandatory(self):
        trace = valid_trace()
        trace["source_audit"]["sequence_owner_proven"] = False
        result = analyze_trace(trace)
        self.assertIn("SEQUENCE_OWNER_PROVEN_UNPROVEN", result["source_audit_blockers"])

    def test_data_valid_low_rejects_frame(self):
        frame = make_frame("EVENT", 0, 2)
        frame["data_valid_before"] = 0
        self.assertEqual(validate_frame(frame)[1], "DATA_VALID_GUARD_REJECTED")

    def test_publication_sequence_change_rejects_frame(self):
        frame = make_frame("PHASE", 0, 2)
        frame["generation_after"] += 2
        frame["generation_inverse_after"] = (~frame["generation_after"]) & 0xFFFFFFFF
        self.assertEqual(validate_frame(frame)[1], "PUBLICATION_SEQUENCE_CHANGED")

    def test_frozen_sequence_cannot_supply_ten_distinct_publications(self):
        trace = valid_trace()
        phase_frames = [frame for frame in trace["frames"] if frame["kind"] == "PHASE"]
        frozen = phase_frames[0]["generation_before"]
        for frame in phase_frames[1:]:
            frame["generation_before"] = frame["generation_after"] = frozen
            frame["generation_inverse_before"] = frame["generation_inverse_after"] = (~frozen) & 0xFFFFFFFF
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "NOT_ENOUGH_VALID_DISTINCT_PUBLICATIONS")
        self.assertLess(result["phase_distinct_publications"], 10)

    def test_sstat_and_a6c_are_not_joined_to_frames(self):
        trace = valid_trace()
        trace["status_observations"][1]["raw"] = "00000800"
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "STOP_STATUS_GUARD")
        self.assertEqual(result["stop_reason"], "PREEXISTING_STICKY_DISABLE_RECORD")
        self.assertFalse(result["sstat_a6c_joined_to_frames"])

    def test_a6c_new_sticky_record_stops_independently(self):
        trace = valid_trace()
        trace["status_observations"][3]["raw"] = "00000800"
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "STOP_STATUS_GUARD")
        self.assertEqual(result["stop_reason"], "NEW_STICKY_DISABLE_RECORD")

    def test_status_timestamp_invalid_rejects_without_frame_join(self):
        trace = valid_trace()
        trace["status_observations"][0]["read_end_ms"] = -1
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "STOP_STATUS_GUARD")
        self.assertEqual(result["stop_reason"], "STATUS_TIMESTAMP_OR_RAW_INVALID")
        self.assertFalse(result["sstat_a6c_joined_to_frames"])

    def test_status_time_must_be_monotonic_and_inside_capture(self):
        trace = valid_trace()
        trace["status_observations"][2]["read_start_ms"] = 3
        trace["status_observations"][2]["read_end_ms"] = 4
        result = analyze_trace(trace)
        self.assertEqual(result["stop_reason"], "STATUS_TIMESTAMP_NONMONOTONIC_OR_OUTSIDE_CAPTURE")

    def test_same_group_invalid_streak_stops(self):
        trace = valid_trace()
        frames = []
        for index in range(5):
            bad_event = make_frame("EVENT", index * 2, 20 + index * 2)
            bad_event["generation_after"] += 2
            bad_event["generation_inverse_after"] = (~bad_event["generation_after"]) & 0xFFFFFFFF
            frames.extend((bad_event, make_frame("PHASE", index * 2 + 1, 40 + index * 2)))
        trace["frames"] = frames
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "STOP_FIVE_CONSECUTIVE_INVALID_FRAMES")
        self.assertTrue(result["stop_reason"].startswith("FIVE_CONSECUTIVE_INVALID_EVENT"))

    def test_cross_group_generation_equality_is_not_atomicity(self):
        trace = valid_trace()
        for index in range(10):
            event = trace["frames"][index * 2]
            phase = trace["frames"][index * 2 + 1]
            phase["generation_before"] = phase["generation_after"] = event["generation_before"]
            phase["generation_inverse_before"] = phase["generation_inverse_after"] = event["generation_inverse_before"]
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "OFFLINE_OBSERVER_CONTRACT_PASS_NOT_STEP6")
        self.assertFalse(result["cross_group_atomicity_claimed"])

    def test_capture_over_sixty_seconds_rejects(self):
        trace = valid_trace()
        trace["capture"]["end_ms"] = 60_001
        result = analyze_trace(trace)
        self.assertEqual(result["verdict"], "REJECTED_CAPTURE_WINDOW_INVALID")


if __name__ == "__main__":
    unittest.main()
