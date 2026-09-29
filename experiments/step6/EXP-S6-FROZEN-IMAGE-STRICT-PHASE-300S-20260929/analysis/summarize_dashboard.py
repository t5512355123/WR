#!/usr/bin/env python3
"""Summarize complete human-readable Step 1-6 dashboard frames."""

from __future__ import annotations

import argparse
import json
import re
import statistics
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path


PAIR = re.compile(r"([A-Za-z][A-Za-z0-9_]*)=([^\s|]+)")
TIMESTAMP = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}")


@dataclass
class BoardFrame:
    role: str
    name: str
    steps: dict[int, str] = field(default_factory=dict)
    fields: dict[str, str] = field(default_factory=dict)
    offset_ps: int | None = None


@dataclass
class DashboardFrame:
    timestamp: datetime
    boards: dict[str, BoardFrame] = field(default_factory=dict)


def parse_dashboard(text: str) -> tuple[list[DashboardFrame], int, int]:
    frames: list[DashboardFrame] = []
    current: DashboardFrame | None = None
    board: BoardFrame | None = None
    incomplete = 0
    read_errors = 0

    for line in text.splitlines():
        timestamp_match = TIMESTAMP.search(line) if line.startswith("White Rabbit Step 1-6 dashboard") else None
        if timestamp_match:
            if current is not None:
                incomplete += 1
            current = DashboardFrame(datetime.fromisoformat(timestamp_match.group(0)))
            board = None
            continue

        if "DASHBOARD_ERROR" in line:
            read_errors += 1

        role_match = re.match(r"\s*\|\s*(MASTER|SLAVE)\s+(\S+)\s*\|", line)
        if role_match and current is not None:
            role, name = role_match.groups()
            board = BoardFrame(role, name)
            current.boards[role] = board
            continue

        if "Dashboard read complete." in line:
            if current is not None:
                frames.append(current)
                current = None
            board = None
            continue

        if current is None or board is None or "|" not in line:
            continue
        content = line.split("|", 2)[1]
        step_match = re.match(r"\s*Step\s+([1-6])\s+.*?\s{2,}([A-Z][A-Z ]*?)\s*$", content)
        if step_match:
            board.steps[int(step_match.group(1))] = step_match.group(2).strip()
        for key, value in PAIR.findall(content):
            board.fields[key] = value
        servo_state_match = re.search(r"WR PTP servo state\s+([A-Z_]+)", content)
        if servo_state_match:
            board.fields["WR_SERVO_STATE"] = servo_state_match.group(1)
        offset_match = re.search(r"WR phase offset\s+(-?\d+)\s+ps", content)
        if offset_match:
            board.offset_ps = int(offset_match.group(1))

    if current is not None:
        incomplete += 1
    return frames, incomplete, read_errors


def link_ok(board: BoardFrame | None) -> bool:
    return bool(
        board
        and board.steps.get(1) == "PASS"
        and board.fields.get("Link") == "1"
        and board.fields.get("TM") == "1"
    )


def global_time_ok(board: BoardFrame | None) -> bool:
    return bool(
        board
        and board.fields.get("TIME_VALID") == "1"
        and board.fields.get("PPS_VALID") == "1"
        and board.fields.get("snapshot") == "1"
        and board.fields.get("stable") == "1"
    )


def slave_locks_ok(board: BoardFrame | None) -> bool:
    return bool(
        board
        and all(board.fields.get(key) == "1" for key in (
            "Helper", "MainFreq", "MainPhase", "MainLock", "PSTAT"
        ))
    )


def summarize(frames: list[DashboardFrame], incomplete: int, read_errors: int) -> dict[str, object]:
    role_samples = {"MASTER": 0, "SLAVE": 0}
    link_pass = {"MASTER": 0, "SLAVE": 0}
    global_valid = {"MASTER": 0, "SLAVE": 0}
    slave_lock_pass = 0
    slave_lock_frames: list[DashboardFrame] = []
    slave_time_frames: list[DashboardFrame] = []
    servo_state_counts: dict[str, int] = {}
    consecutive_slave_locks = maximum_consecutive_slave_locks = 0
    strict_pass = 0
    consecutive = maximum_consecutive = 0
    qualified_run_start: datetime | None = None
    maximum_qualified_run_span_seconds = 0.0
    valid_time_offsets: list[int] = []
    all_offsets: list[int] = []
    qualified_samples: list[dict[str, object]] = []
    servo_state_transitions: list[dict[str, object]] = []
    previous_servo_state: str | None = None

    for frame in frames:
        master = frame.boards.get("MASTER")
        slave = frame.boards.get("SLAVE")
        for role, current in (("MASTER", master), ("SLAVE", slave)):
            if current:
                role_samples[role] += 1
                link_pass[role] += int(link_ok(current))
                global_valid[role] += int(global_time_ok(current))
                if role == "SLAVE" and global_time_ok(current):
                    slave_time_frames.append(frame)
        if slave:
            if slave.offset_ps is not None:
                all_offsets.append(slave.offset_ps)
                if global_time_ok(slave):
                    valid_time_offsets.append(slave.offset_ps)
            locks = slave_locks_ok(slave)
            slave_lock_pass += int(locks)
            if locks:
                slave_lock_frames.append(frame)
                consecutive_slave_locks += 1
                maximum_consecutive_slave_locks = max(
                    maximum_consecutive_slave_locks, consecutive_slave_locks
                )
            else:
                consecutive_slave_locks = 0
            state = slave.fields.get("WR_SERVO_STATE", "UNKNOWN")
            servo_state_counts[state] = servo_state_counts.get(state, 0) + 1
            if state != previous_servo_state:
                servo_state_transitions.append({
                    "timestamp": frame.timestamp.isoformat(),
                    "servo_state": state,
                    "offset_ps": slave.offset_ps,
                })
                previous_servo_state = state
        else:
            locks = False
            consecutive_slave_locks = 0

        qualified = bool(
            master and slave
            and link_ok(master) and link_ok(slave)
            and global_time_ok(master) and global_time_ok(slave)
            and locks
            and slave.offset_ps is not None
            and abs(slave.offset_ps) < 60
        )
        strict_pass += int(qualified)
        if qualified:
            if consecutive == 0:
                qualified_run_start = frame.timestamp
            qualified_samples.append({
                "timestamp": frame.timestamp.isoformat(),
                "slave_offset_ps": slave.offset_ps,
                "servo_state": slave.fields.get("WR_SERVO_STATE"),
            })
            consecutive += 1
            maximum_consecutive = max(maximum_consecutive, consecutive)
            if qualified_run_start is not None:
                maximum_qualified_run_span_seconds = max(
                    maximum_qualified_run_span_seconds,
                    (frame.timestamp - qualified_run_start).total_seconds(),
                )
        else:
            consecutive = 0
            qualified_run_start = None

    return {
        "complete_frames": len(frames),
        "incomplete_frames": incomplete,
        "read_errors": read_errors,
        "first_frame": frames[0].timestamp.isoformat() if frames else None,
        "last_frame": frames[-1].timestamp.isoformat() if frames else None,
        "frame_span_seconds": round((frames[-1].timestamp - frames[0].timestamp).total_seconds(), 3) if len(frames) > 1 else 0,
        "role_samples": role_samples,
        "link_pass_samples": link_pass,
        "global_time_valid_samples": global_valid,
        "slave_global_time_first_sample": slave_time_frames[0].timestamp.isoformat() if slave_time_frames else None,
        "slave_global_time_last_sample": slave_time_frames[-1].timestamp.isoformat() if slave_time_frames else None,
        "slave_all_five_lock_samples": slave_lock_pass,
        "slave_all_five_lock_first_sample": slave_lock_frames[0].timestamp.isoformat() if slave_lock_frames else None,
        "slave_all_five_lock_last_sample": slave_lock_frames[-1].timestamp.isoformat() if slave_lock_frames else None,
        "slave_all_five_lock_sample_span_seconds": round((slave_lock_frames[-1].timestamp - slave_lock_frames[0].timestamp).total_seconds(), 3) if len(slave_lock_frames) > 1 else 0,
        "slave_maximum_consecutive_all_five_locks": maximum_consecutive_slave_locks,
        "slave_servo_state_samples": servo_state_counts,
        "slave_servo_state_transitions": servo_state_transitions,
        "slave_offset_samples": len(all_offsets),
        "slave_offset_samples_with_valid_global_time": len(valid_time_offsets),
        "slave_offset_under_60ps_samples_with_valid_global_time": sum(abs(value) < 60 for value in valid_time_offsets),
        "slave_offset_min_ps_with_valid_global_time": min(valid_time_offsets) if valid_time_offsets else None,
        "slave_offset_max_ps_with_valid_global_time": max(valid_time_offsets) if valid_time_offsets else None,
        "slave_offset_median_ps_with_valid_global_time": statistics.median(valid_time_offsets) if valid_time_offsets else None,
        "all_gates_pass_samples": strict_pass,
        "all_gates_pass_sample_details": qualified_samples,
        "maximum_consecutive_all_gates_pass_samples": maximum_consecutive,
        "maximum_consecutive_all_gates_pass_span_seconds": maximum_qualified_run_span_seconds,
        "expanded_step6_observation_pass": bool(
            maximum_consecutive >= 25
            and maximum_qualified_run_span_seconds >= 300
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dashboard_log", type=Path)
    args = parser.parse_args()
    frames, incomplete, errors = parse_dashboard(args.dashboard_log.read_text(encoding="utf-8", errors="replace"))
    print(json.dumps(summarize(frames, incomplete, errors), indent=2))


if __name__ == "__main__":
    main()
