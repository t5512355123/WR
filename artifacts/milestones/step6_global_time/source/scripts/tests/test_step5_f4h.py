#!/usr/bin/env python3
"""Fixture tests for the F4H PHY source/schema contract."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

from step5_f4h_phy_status_source_retest import (  # noqa: E402
    REQUIRED_BITS,
    _expected_gate,
    _source_schema,
)


def f4h_config() -> dict[str, str]:
    return {
        "RUN_ROLE": "f4h",
        "PHY_STATUS_SOURCE": "JTAG_PROBE0",
        "PHY_STATUS_INSTANCE": "0",
        "PHY_STATUS_WIDTH_BITS": "64",
        "PHY_REQUIRED_MASK": "000000CF",
        "WDIAGS_CTRL_ADDR": "0x00100A04",
        "PSTAT_ADDR": "0x00100A0C",
    }


def wr_row(role: str, raw: str, *, ctrl_valid: int = 1,
           core_valid: int = 1, observed_gate: int | None = None) -> dict[str, str | int]:
    if observed_gate is None:
        try:
            value = int(raw, 16) if raw else 0
        except ValueError:
            value = 0
        observed_gate = int((value & 0xCF) == 0xCF)
    return {
        "ROLE": role,
        "BOARD": "DE5 [1-11.1]" if role == "MASTER" else "DE5 [1-11.2]",
        "CYCLE": "1",
        "HOST_START_MS": "100",
        "HOST_END_MS": "101",
        "WR_CORE_VALID": core_valid,
        "ROLE_IDENTITY_VALID": 1,
        "RESET_FIELDS_VALID": 1,
        "TERMINAL": 0,
        "WDIAGS_CTRL_RAW": "00000001" if ctrl_valid else "00000000",
        "WDIAGS_CTRL_VALID": 1,
        "WDIAGS_CTRL_DATA_VALID": ctrl_valid,
        "WDIAGS_CTRL_DATA_SNAPSHOT": 0,
        "PHY_STATUS_PROBE0_RAW": raw,
        "PHY_STATUS_VALID": int(raw not in {"TIMEOUT", "INVALID", "UNKNOWN"}),
        "PHY_STATUS_SOURCE": "JTAG_PROBE0",
        "PHY_STATUS_SOURCE_ID": f"WR_SYNC_{role}",
        "PHY_STATUS_INSTANCE": "0",
        "PHY_STATUS_WIDTH_BITS": "64",
        "PHY_GATE_REQUIRED_MASK": "000000CF",
        "PHY_GATE_FAILURE_BITS": "NONE" if observed_gate else "UNKNOWN",
        "PSTAT_LINK": 1,
        "PSTAT_LOCKED": 0,
        "PHY_LINK_USABLE": observed_gate,
    }


def smoke_rows(raw: str, *, ctrl_valid: int = 1, core_valid: int = 1,
               observed_gate: int | None = None) -> list[dict[str, str | int]]:
    return [
        wr_row("MASTER", raw, ctrl_valid=ctrl_valid, core_valid=core_valid,
               observed_gate=observed_gate),
        wr_row("MASTER", raw, ctrl_valid=ctrl_valid, core_valid=core_valid,
               observed_gate=observed_gate),
        wr_row("SLAVE", raw, ctrl_valid=ctrl_valid, core_valid=core_valid,
               observed_gate=observed_gate),
        wr_row("SLAVE", raw, ctrl_valid=ctrl_valid, core_valid=core_valid,
               observed_gate=observed_gate),
    ]


class F4HSourceTests(unittest.TestCase):
    def test_ctrl_one_probe_bits_zero_is_not_phy_usable(self) -> None:
        result = _source_schema(f4h_config(), smoke_rows("0000000000000001"))
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["gate_pass_rows"], 0)
        self.assertEqual(result["gate_fail_rows"], 4)
        self.assertIn("WR_READY", result["decoded_rows"][0]["failure_bits"])

    def test_ctrl_one_probe_all_required_bits_pass(self) -> None:
        result = _source_schema(f4h_config(), smoke_rows("00000000000000CF"))
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["gate_pass_rows"], 4)
        self.assertEqual(result["gate_fail_rows"], 0)

    def test_each_required_bit_is_independently_required(self) -> None:
        for name, bit in REQUIRED_BITS:
            with self.subTest(name=name, bit=bit):
                raw = f"{0xCF & ~(1 << bit):016X}"
                result = _source_schema(f4h_config(), smoke_rows(raw))
                self.assertEqual(result["status"], "PASS")
                self.assertEqual(result["gate_pass_rows"], 0)
                self.assertEqual(result["per_bit"][name]["failed"], 4)

    def test_ctrl_zero_does_not_replace_direct_physical_evidence(self) -> None:
        result = _source_schema(
            f4h_config(), smoke_rows("00000000000000CF", ctrl_valid=0, core_valid=0)
        )
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["gate_pass_rows"], 4)
        self.assertTrue(all(row["WR_CORE_VALID"] == 0
                            for row in smoke_rows("00000000000000CF", ctrl_valid=0,
                                                   core_valid=0)))

    def test_invalid_ctrl_cannot_be_claimed_as_core_valid(self) -> None:
        result = _source_schema(
            f4h_config(), smoke_rows("00000000000000CF", ctrl_valid=0, core_valid=1)
        )
        self.assertEqual(result["status"], "PHY_SCHEMA_INVALID")
        self.assertIn("CORE_VALID_WITH_INVALID_CTRL", result["issues"])

    def test_old_f4g_raw_cannot_be_upgraded(self) -> None:
        old_config = {"RUN_ROLE": "f4g"}
        result = _source_schema(old_config, smoke_rows("00000000000000CF"))
        self.assertEqual(result["status"], "PHY_SOURCE_NOT_CAPTURED")
        self.assertFalse(result["pass"])

    def test_timeout_is_unknown(self) -> None:
        result = _source_schema(f4h_config(), smoke_rows("TIMEOUT"))
        self.assertEqual(result["status"], "PHY_SOURCE_UNKNOWN")
        self.assertEqual(result["unknown_rows"], 4)

    def test_nonhex_and_short_malformed_source_is_unknown(self) -> None:
        for raw in ("not_hex", "12345678901234567", ""):
            with self.subTest(raw=raw):
                result = _source_schema(f4h_config(), smoke_rows(raw))
                self.assertEqual(result["status"], "PHY_SOURCE_UNKNOWN")

    def test_high_64_bit_data_is_preserved_while_low_gate_decodes(self) -> None:
        raw = "A5000003000000CF"
        decoded, gate_pass, failure_bits = _expected_gate(int(raw, 16))
        self.assertTrue(gate_pass)
        self.assertEqual(failure_bits, "NONE")
        self.assertEqual(decoded["SI_CONFIG_DONE"], 1)
        result = _source_schema(f4h_config(), smoke_rows(raw))
        self.assertEqual(result["gate_pass_rows"], 4)

    def test_role_source_id_mismatch_is_rejected(self) -> None:
        rows = smoke_rows("00000000000000CF")
        rows[0]["PHY_STATUS_SOURCE_ID"] = "WR_SYNC_SLAVE"
        result = _source_schema(f4h_config(), rows)
        self.assertEqual(result["status"], "PHY_SCHEMA_INVALID")
        self.assertIn("PHY_ROLE_SOURCE_ID_MISMATCH", result["issues"])

    def test_observer_decoder_mismatch_is_rejected(self) -> None:
        result = _source_schema(
            f4h_config(), smoke_rows("0000000000000001", observed_gate=1)
        )
        self.assertEqual(result["status"], "PHY_SCHEMA_INVALID")
        self.assertIn("PHY_DECODER_MISMATCH", result["issues"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
