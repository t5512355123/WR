#!/usr/bin/env python3
"""Offline tests for the Step6 Master-first S_LOCK attribution."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))
import step6_slock_master_first_reacquisition as module  # noqa: E402


def sample(
    *,
    role="SLAVE",
    sample_no=0,
    timestamp=0,
    state=2,
    polls="00000010",
    unlocked="00000010",
    calib="00000000",
    disable=0,
    reason=0,
    pass_ready=0,
    failure_seen=0,
    failure_class="NONE",
    post=0,
    generation="00000001",
):
    board = "DE5 [1-11.1]" if role == "MASTER" else "DE5 [1-11.2]"
    return (
        "SLOCK_REACQ_SAMPLE "
        f"ROLE={role} board={board} sample={sample_no:03d} timestamp_ms={timestamp} "
        "READ_VALID=1 SI_CONFIG_DONE=1 WR_READY=1 WR_RX_READY=1 WR_TX_READY=1 "
        "CORE_TM_LINK_UP=1 CORE_LINK_OK=1 WR_RX_LOCKED_TO_DATA=1 CPU_RESET_N=1 "
        "LINK_GOOD=1 LINK_GATE_STREAK=5 LINK_GATE_PASS=1 LINK_GATE_PASS_MS=2000 "
        f"WRC_MODE={'2' if role == 'MASTER' else '3'} PTP_STATE={'6' if role == 'MASTER' else '9'} "
        "PD_STATE=3 EXT_STATE=1 SERVO_STATE=4 "
        f"WR_STATE_VALUE={state} WR_NEXT_STATE=0 WR_TX_ID={'4098' if pass_ready else '4097'} "
        f"WR_DISABLE_VALID={disable} WR_DISABLE_CAUSE=2 WR_FAILURE_REASON={reason} "
        f"LOCK_POLLS={polls} LOCK_UNLOCKED={unlocked} LOCK_CALIB_FAIL={calib} "
        "LOCK_ENABLE=00000004 LOCK_SUCCESS_COUNT=0 SPLL_SEQ_STATE=8 PSTAT_LOCKED=1 "
        "HELPER_LOCKED=1 MAIN_ENABLED=1 MAIN_LOCKED=1 MAIN_FREQ_LOCKED=1 MAIN_PHASE_LOCKED=1 "
        f"BOOT_GENERATION={generation} CPU_RESET_COUNT=00000001 WR_CORE_RESET_COUNT=00000001 "
        "SI_CONFIG_DROP_COUNT=00000001 SLOCK_MAGIC=5752534C SLOCK_STAGE=00000002 "
        "SLOCK_REMAINING_MS=0000EA60 FIRST_SLOCK_MS=0 FIRST_SUCCESS_MS=0 FIRST_EXIT_MS=0 "
        f"FIRST_FAILURE_MS=0 PASS_READY={pass_ready} FAILURE_SEEN={failure_seen} "
        f"FAILURE_CLASS={failure_class} POST_EVENT_SAMPLES={post} STOP_CANDIDATE=NONE"
    )


def test_success_count_and_pass():
    text = "\n".join(
        [
            sample(sample_no=0, timestamp=0),
            sample(sample_no=1, timestamp=500, polls="00000012", unlocked="00000010"),
            sample(sample_no=2, timestamp=1000, state=4, polls="00000013", unlocked="00000010", pass_ready=1, post=1),
        ]
        + [sample(sample_no=3 + i, timestamp=1500 + i * 500, state=4, polls="00000013", unlocked="00000010", pass_ready=1, post=2 + i) for i in range(20)]
    )
    result = module.analyze_text(text)
    assert result["max_lock_success_count"] == 3
    assert result["classification"] == "PASS_SLOCK_SUCCESS"


def test_no_success_before_slock_timeout():
    text = "\n".join(
        [sample(sample_no=i, timestamp=i * 500, disable=1 if i >= 2 else 0, reason=3, failure_seen=1 if i >= 2 else 0, failure_class="FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE", post=i - 1 if i >= 2 else 0) for i in range(22)]
    )
    result = module.analyze_text(text)
    assert result["max_lock_success_count"] == 0
    assert result["classification"] == "FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE"


def test_reset_is_inconclusive():
    text = "\n".join([
        sample(sample_no=0, timestamp=0),
        sample(sample_no=1, timestamp=500, generation="00000002"),
    ])
    result = module.analyze_text(text)
    assert result["classification"] == "INCONCLUSIVE"


def test_master_preflight_requires_ten_stable_samples():
    text = "\n".join(sample(role="MASTER", sample_no=i, timestamp=i * 500, state=0) for i in range(10))
    result = module.analyze_text(text, mode="preflight")
    assert result["master_precondition"] == "PASS_MASTER_PRECONDITION"


def test_master_local_ready_does_not_require_peer_link():
    text = "\n".join(sample(role="MASTER", sample_no=i, timestamp=i * 500, state=0) for i in range(5))
    text = text.replace("CORE_TM_LINK_UP=1 CORE_LINK_OK=1", "CORE_TM_LINK_UP=0 CORE_LINK_OK=0")
    result = module.analyze_text(text, mode="local-ready")
    assert result["master_precondition"] == "PASS_MASTER_PRECONDITION"


if __name__ == "__main__":
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            value()
    print("SLOCK_REACQ_OFFLINE_TESTS_PASS")
