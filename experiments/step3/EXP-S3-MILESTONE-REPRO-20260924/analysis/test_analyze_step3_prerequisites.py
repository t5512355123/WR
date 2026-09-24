from __future__ import annotations

import unittest

from analyze_step3_prerequisites import (
    EXPECTED,
    validate_series_board,
    validate_snapshot_board,
)


def healthy_snapshot(board: str) -> dict[str, list[str]]:
    expected = EXPECTED[board]
    return {
        "EP_MAC_H": ["02000200"],
        "EP_MAC_L": [expected["mac"][-8:]],
        "WDIAGS_MODE": [f"{expected['mode']:08X}"],
        "WDIAGS_PTP": [f"{expected['ptp']:08X}"],
        "status_probe": ["00000000000080FF"],
        "cpu_debug": [
            "PC=0x00001000 reset=0 fault=0 im_valid=1",
            "PC=0x00002000 reset=0 fault=0 im_valid=1",
        ],
        "cpu_marker": ["0x0000B004 seen=1"],
        # The runtime reader's CPU_RESET readback and WDIAGS_RESTART alias are
        # deliberately arbitrary; neither is used as a reset-level signal.
        "CPU_RESET": ["83274730"],
        "WDIAGS_RESTART": ["01030001"],
    }


def healthy_series(board: str) -> list[dict[str, int | bool]]:
    expected = EXPECTED[board]
    rows = []
    for sample in range(1, 31):
        rows.append(
            {
                "sample": sample,
                "accepted": True,
                "frame_valid": True,
                "status": 0x80FF,
                "ptp_meta": (expected["mode"] << 24) | expected["ptp"],
                "ptp_rx": sample,
                "ptp_tx": sample + 10,
                "foreign_meta": 0x03000001 if board == "DE5 [1-11.2]" else 0,
            }
        )
    return rows


class Step3PrerequisiteTests(unittest.TestCase):
    def test_reset_level_uses_cpu_probe_not_undefined_debug_readbacks(self) -> None:
        for board in EXPECTED:
            fields = healthy_snapshot(board)
            fields["CPU_RESET"] = ["83274730"]
            fields["WDIAGS_RESTART"] = ["02020009"]
            self.assertEqual(validate_snapshot_board(board, fields, "test"), [])

    def test_snapshot_fails_if_cpu_reset_pin_or_debug_state_fails(self) -> None:
        board = "DE5 [1-11.2]"
        fields = healthy_snapshot(board)
        fields["status_probe"] = ["00000000000000FF"]
        fields["cpu_debug"] = ["PC=0 reset=1 fault=0 im_valid=1"] * 2
        errors = validate_snapshot_board(board, fields, "test")
        self.assertTrue(any("status bit 15" in error for error in errors))
        self.assertTrue(any("reports reset" in error for error in errors))

    def test_series_rejects_step1_encoding_error_even_when_frame_is_valid(self) -> None:
        board = "DE5 [1-11.1]"
        rows = healthy_series(board)
        rows[5]["status"] = 0x80FF | (1 << 13)
        errors = validate_series_board(board, rows)
        self.assertTrue(any("encoding-error" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
