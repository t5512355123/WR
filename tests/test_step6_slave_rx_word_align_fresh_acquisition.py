from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "experiment"))

from step6_slave_rx_word_align_fresh_acquisition import (  # noqa: E402
    analyze_text,
    parse_samples,
)


def sample(index: int, *, good: bool = True, raw_activity: int = 0x1000) -> str:
    return (
        "WORDALIGN_SAMPLE ROLE=SLAVE BOARD=DE5 [1-11.2] "
        f"SAMPLE={index} TIMESTAMP_MS={index * 100} MODE=word-align READ_VALID=1 "
        "SI_CONFIG_DONE=1 WR_READY=1 RX_READY=1 TX_READY=1 CPU_RESET_N=1 "
        "PHY_RST=0 PHY_TX_DISABLE=0 CORE_TM_LINK_UP=0 CORE_LINK_OK=0 "
        "RX_LOCKED_TO_DATA=1 RX_LOCKED_TO_REF=1 "
        f"RX_CLOCK_ACTIVITY={raw_activity + index} RX_CLOCK_ACTIVITY_CHANGED=1 "
        f"RX_SYNCSTATUS={1 if good else 0} RX_PATTERN_READY={1 if good else 0} "
        f"RX_ENC_ERR={0 if good else 1} RX_DISPERR=0 RX_ERRDETECT={0 if good else 1} "
        "RX_PATTERNDETECT=0 RX_RUNNINGDISP=0 RX_DATA=0 RX_DATA_K=0 RX_BITSLIDE=0 "
        "PTP_STATE=4 WDIAGS_TX=00000001 PTP_TX=00000001 ECR_TX_EN=1 ECR_RX_EN=1 "
        f"BOOT_GENERATION=00000001 CPU_RESET_COUNT=00000001 WR_CORE_RESET_COUNT=00000001 SI_CONFIG_DROP_COUNT=00000001 "
        "STICKY45_RAW=0000000000000001 STICKY46_RAW=0000000000000001 "
        "STICKY47_RAW=0000000000000000 STICKY48_RAW=0000000000000000 "
        "FIRST_ENC_ERR_COUNT=0 FIRST_DISPERR_COUNT=0 FIRST_ERRDETECT_COUNT=0 "
        "FIRST_SYNC_LOSS_COUNT=0 FIRST_LOCK_LOSS_COUNT=0 FIRST_LINK_DROP_COUNT=0 "
        "ENC_ERR_DELTA=0 DISPERR_DELTA=0 ERRDETECT_DELTA=0 SYNC_LOSS_DELTA=0 "
        "LOCK_LOSS_DELTA=0 LINK_DROP_DELTA=0 TM_LINK_DROP_DELTA=0 "
        f"LOCAL_READY=1 LOCAL_READY_STREAK=3 LOCAL_READY_PASS=1 "
        f"LOCAL_READY_PASS_TIMESTAMP_MS=0 WORD_ALIGN_WINDOW_START_MS=0 WORD_ALIGN_ELAPSED_MS={index * 100} BASELINE_SET=0 "
        f"WORD_ALIGN_OBSERVED=1 ACTIVITY_PRESENT=1 ALIGNMENT_GOOD={1 if good else 0} "
        f"ALIGNMENT_STREAK={index + 1 if good else 0} RX_NO_LOCK_STREAK=0 RX_NO_ACTIVITY_STREAK=0 "
        f"SYNC_SEEN={1 if good else 0} PATTERN_SEEN={1 if good else 0} ERROR_SEEN={0 if good else 1} COUNTER_INVALID=0 STOP_CANDIDATE=NONE"
    )


def test_parse_preserves_corrected_activity_and_board():
    rows = parse_samples(sample(0))
    assert len(rows) == 1
    assert rows[0]["RX_CLOCK_ACTIVITY"] == 0x1000
    assert rows[0]["BOARD"] == "DE5 [1-11.2]"


def test_master_precondition_requires_five_good_samples():
    text = "\n".join(
        sample(i).replace("MODE=word-align", "MODE=master-precondition")
        .replace("PTP_STATE=4", "PTP_STATE=6")
        .replace("LOCAL_READY=1 LOCAL_READY_STREAK=3 LOCAL_READY_PASS=1", "LOCAL_READY=1 LOCAL_READY_STREAK=1 LOCAL_READY_PASS=0")
        for i in range(5)
    )
    result = analyze_text(text, mode="master-precondition")
    assert result["pass"] is True


def test_five_consecutive_alignment_samples_pass():
    result = analyze_text("\n".join(sample(i, good=True) for i in range(5)))
    assert result["classification"] == "PASS_WORD_ALIGN_ACQUISITION"
    assert result["step6a"] == "NOT_PASS"
    assert result["step6b"] == "NOT_RUN"


def test_persistent_errors_classify_alignment_failure():
    rows = []
    for i in range(10):
        rows.append(sample(i, good=False, raw_activity=0x2000 + i).replace(
            f"TIMESTAMP_MS={i * 100}", f"TIMESTAMP_MS={(i + 1) * 1000}"
        ).replace(
            f"WORD_ALIGN_ELAPSED_MS={i * 100}", f"WORD_ALIGN_ELAPSED_MS={(i + 1) * 1000}"
        ))
    result = analyze_text("\n".join(rows))
    assert result["classification"] == "FAIL_RX_WORD_ALIGNMENT_NEVER_ACQUIRED_WITH_8B10B_ERRORS"
    assert result["recovered_rx_clock_activity"] == "PRESENT"


def test_first_sync_loss_history_classifies_early_loss_after_full_window():
    rows = []
    for i in range(10):
        row = sample(i, good=False, raw_activity=0x3000 + i)
        row = row.replace(
            "FIRST_SYNC_LOSS_COUNT=0", "FIRST_SYNC_LOSS_COUNT=1"
        ).replace(
            f"TIMESTAMP_MS={i * 100}", f"TIMESTAMP_MS={(i + 1) * 1000}"
        ).replace(
            f"WORD_ALIGN_ELAPSED_MS={i * 100}", f"WORD_ALIGN_ELAPSED_MS={(i + 1) * 1000}"
        )
        rows.append(row)
    result = analyze_text("\n".join(rows))
    assert result["classification"] == "FAIL_RX_WORD_ALIGNMENT_EARLY_LOSS_WITH_8B10B_ERRORS"
    assert result["observation_window_complete"] is True
