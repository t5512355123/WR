#!/usr/bin/env python3
"""Offline Step 3 handshake acceptance for the coherent JTAG time series."""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path


BOARDS = ("DE5 [1-11.1]", "DE5 [1-11.2]")
SLAVE = BOARDS[1]
REQUIRED_BLOCKS = (
    "FRAME_VALID",
    "PARENT_BLOCK_VALID",
    "WR_STATE_BLOCK_VALID",
    "WR_SIGNAL_BLOCK_VALID",
    "WR_LOCK_BLOCK_VALID",
)


def strip_terminal_controls(text: str) -> str:
    return re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)


def parse_timeseries_text(text: str) -> dict[str, list[dict[str, int | bool]]]:
    text = strip_terminal_controls(text)
    chunks = re.split(r"(?=SESSION_SAMPLE board=)", text)
    rows: dict[str, list[dict[str, int | bool]]] = defaultdict(list)

    for chunk in chunks:
        header = re.search(
            r"SESSION_SAMPLE board=(DE5 \[1-11\.\d\]) sample=(\d+) "
            r"attempt=(\d+) status=([0-9A-Fa-f]+)",
            chunk,
        )
        result = re.search(
            r"SESSION_SAMPLE_RESULT board=DE5 \[1-11\.\d\] sample=(\d+) "
            r"accepted=(\d+) retries=(\d+)",
            chunk,
        )
        if header is None or result is None:
            continue
        if int(header.group(2)) != int(result.group(1)):
            raise ValueError("sample header/result index mismatch")

        blocks: dict[str, bool] = {
            name.lower(): bool(re.search(rf"\b{name}:\s*1\b", chunk))
            for name in REQUIRED_BLOCKS
        }
        local = re.search(
            r"WR_LOCAL:.*?state=(\d+).*?next_state=(\d+).*?"
            r"parent_detection=(\d+).*?wr_mode=(\d+)",
            chunk,
        )
        parent = re.search(
            r"PARENT: foreign_count=(\d+) foreign_best=(\d+) "
            r"detection=(\d+) wr_config=(\d+) is_wr=(\d+) "
            r"mode_on=(\d+) calibrated=(\d+)",
            chunk,
        )
        signal = re.search(
            r"WR_SIGNAL: rx_msg=0x([0-9A-Fa-f]+) rx_count=(\d+) "
            r"tx_msg=0x([0-9A-Fa-f]+) tx_count=(\d+) "
            r"fail_role=(\d+) fail_state=(\d+) fail_count=(\d+)",
            chunk,
        )
        reject = re.search(r"WR_SIGNAL_REJECT: count=(\d+) reason=(\d+)", chunk)
        lock = re.search(r"WR_LOCK:.*?enable=(\d+)", chunk)
        meta = re.search(r"WDIAGS_PTP_META:([0-9A-Fa-f]+)", chunk)
        foreign_meta = re.search(r"WDIAGS_FOREIGN_META:([0-9A-Fa-f]+)", chunk)
        if any(
            value is None
            for value in (local, parent, signal, reject, lock, meta, foreign_meta)
        ):
            continue

        row: dict[str, int | bool] = {
            **blocks,
            "sample": int(header.group(2)),
            "attempt": int(header.group(3)),
            "status": int(header.group(4), 16) & 0xFFFF,
            "accepted": int(result.group(2)) == 1,
            "retries": int(result.group(3)),
            "ptp_meta": int(meta.group(1), 16),
            "foreign_meta": int(foreign_meta.group(1), 16),
            "local_state": int(local.group(1)),
            "next_state": int(local.group(2)),
            "local_parent_detection": int(local.group(3)),
            "local_wr_mode": int(local.group(4)),
            "foreign_count": int(parent.group(1)),
            "foreign_best": int(parent.group(2)),
            "parent_detection": int(parent.group(3)),
            "parent_wr_config": int(parent.group(4)),
            "parent_is_wr": int(parent.group(5)),
            "parent_mode_on": int(parent.group(6)),
            "parent_calibrated": int(parent.group(7)),
            "rx_msg": int(signal.group(1), 16),
            "rx_count": int(signal.group(2)),
            "tx_msg": int(signal.group(3), 16),
            "tx_count": int(signal.group(4)),
            # Diagnostic only: this is NOT the current WR state.
            "fail_state": int(signal.group(6)),
            "reject_count": int(reject.group(1)),
            "reject_reason": int(reject.group(2)),
            "lock_enable_count": int(lock.group(1)),
        }
        rows[header.group(1)].append(row)

    return rows


def coherent_accepted(
    rows: list[dict[str, int | bool]],
) -> list[dict[str, int | bool]]:
    return [
        row
        for row in rows
        if row["accepted"]
        and all(bool(row[name.lower()]) for name in REQUIRED_BLOCKS)
    ]


def analyze(
    rows: dict[str, list[dict[str, int | bool]]],
    *,
    samples_expected: int = 30,
    minimum_valid: int = 20,
) -> list[str]:
    errors: list[str] = []
    for board in BOARDS:
        board_rows = rows.get(board, [])
        indices = [int(row["sample"]) for row in board_rows]
        if indices != list(range(1, samples_expected + 1)):
            errors.append(f"{board}: expected result indexes 1..{samples_expected}")

        valid = coherent_accepted(board_rows)
        if len(valid) < minimum_valid:
            errors.append(
                f"{board}: only {len(valid)} valid accepted frames; need {minimum_valid}"
            )
        if valid and (
            int(valid[0]["sample"]) != 1
            or int(valid[-1]["sample"]) != samples_expected
        ):
            errors.append(f"{board}: valid accepted boundary samples are missing")

        if board != SLAVE:
            continue

        for row in valid:
            sample = int(row["sample"])
            ptp_meta = int(row["ptp_meta"])
            if ((ptp_meta >> 24) & 0xFF) != 3 or (ptp_meta & 0xFF) != 9:
                errors.append(f"Slave sample {sample}: expected MODE=3/PTP=9")
            foreign = int(row["foreign_meta"])
            if (foreign & 0xFF) != 1 or ((foreign >> 8) & 0xFF) != 0:
                errors.append(f"Slave sample {sample}: foreign-master count/best mismatch")
            if ((foreign >> 24) & 0xFF) != 3 or int(row["parent_is_wr"]) != 1:
                errors.append(f"Slave sample {sample}: WR parent identity is not valid")
            if int(row["parent_calibrated"]) != 1:
                errors.append(f"Slave sample {sample}: parent calibration flag is low")
            if int(row["rx_msg"]) != 0x1001 or int(row["rx_count"]) < 1:
                errors.append(f"Slave sample {sample}: LOCK signaling RX not witnessed")
            if int(row["tx_msg"]) != 0x1000 or int(row["tx_count"]) < 1:
                errors.append(f"Slave sample {sample}: SLAVE_PRESENT TX not witnessed")
            if int(row["local_state"]) != 2 and int(row["lock_enable_count"]) <= 0:
                errors.append(
                    f"Slave sample {sample}: neither current WRS_S_LOCK state nor "
                    "source-backed lock-enable entry counter is present"
                )

        if len(valid) >= 2 and int(valid[0]["reject_count"]) != int(valid[-1]["reject_count"]):
            errors.append("Slave: signaling-reject count advanced during accepted window")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--series", type=Path, required=True)
    args = parser.parse_args()
    rows = parse_timeseries_text(args.series.read_text(errors="replace"))

    for board in BOARDS:
        board_rows = rows.get(board, [])
        valid = coherent_accepted(board_rows)
        state_hits = sum(int(row["local_state"]) == 2 for row in valid)
        enable_hits = sum(int(row["lock_enable_count"]) > 0 for row in valid)
        print(
            f"{board}: results={len(board_rows)} coherent_accepted={len(valid)} "
            f"WRS_S_LOCK_current_samples={state_hits} lock_enable_samples={enable_hits}"
        )

    errors = analyze(rows)
    if errors:
        print("STEP3_HANDSHAKE=NOT_PASS")
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("STEP3_HANDSHAKE=PASS")
    print(
        "WR_LOCK entry is proven by current state or its source-backed "
        "enable counter; fail_state is diagnostic only."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
