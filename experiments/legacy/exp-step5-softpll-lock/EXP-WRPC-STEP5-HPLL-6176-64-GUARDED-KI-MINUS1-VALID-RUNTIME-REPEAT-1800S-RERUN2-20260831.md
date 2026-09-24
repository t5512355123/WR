# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-RERUN2-20260831

## Experiment identity

- Branch: `exp/step5-softpll-lock`
- Firmware/evidence baseline: `79f4e8fe349186d81ba74ad888bae6e29cdcdf77`
- Experiment intent: repeat the same `ki=-1` Step 5 candidate after restoring a valid runtime/JTAG observation session.
- Functional parameters held constant:
  - `bootstrap_steps=6176`
  - `code_per_physical_step=64`
  - `kp=-150`
  - `ki=-1`
  - `threshold=200`
  - `lock_samples=10000`
- No new control, PHY, DMTD, tracker, reset-tree, or sequencer change was made in this rerun.

## Important runtime-observer correction

The first attempt in this repeat used the `rs422_uart_diag` SOF files. Those top-level designs do not instantiate the JTAG Wishbone mailbox required by `scripts/jtag/read_wb_runtime.tcl` and the Step 5 observer. That explains the earlier pattern of Step 1 direct-probe PASS followed by Step 2/3/4 mailbox TIMEOUT/INVALID; it was not valid firmware evidence.

For this rerun, the existing `scripts/build/build_jtag_master.sh` and `scripts/build/build_jtag_slave.sh` targets were used. Both JTAG top levels instantiate `wr_jtag_wb_mailbox` and use the same firmware MIFs containing `ki=-1`.

## Build/program evidence

- Master JTAG project: `DE5a_wr_master_jtag`
- Slave JTAG project: `DE5a_wr_slave_jtag`
- Quartus: 17.0.0 Build 595
- Master compilation: `Full Compilation was successful`
- Slave compilation: `Full Compilation was successful`
- Master SOF SHA-256: `36ea8534852ff95e4b0f7a764fb94f91d39c2df1b889ffdfa399715b8b440c46`
- Slave SOF SHA-256: `2e973de2f131016c3f4dbd2a26134669eac8b81c23d2ee5a1066de8ef41146de`
- Master programming: success, 0 errors, 0 warnings; checksum `0x30B897E6`
- Slave programming: success, 0 errors, 0 warnings; checksum `0x30B77398`
- Timing remains open: Master `WNS=-0.453 ns`, Slave `WNS=-0.367 ns` (`TIMING_CLOSED=NO`).

## Runtime preflight

After fresh programming and a 180-second stabilization wait, three independent read-only `read_wb_runtime.tcl --raw` dashboards were run. All three were valid and identical at the gate level:

```text
Master: STEP1_REGRESSION=PASS
        STEP2_REGRESSION=PASS
        STEP4A_RESULT=PASS

Slave:  STEP1_REGRESSION=PASS
        STEP2_REGRESSION=PASS
        STEP3_REGRESSION=PASS
        STEP4B_ALLOWED=YES
        STEP4B_RESULT=PASS
        STEP4B_FIRST_INACTIVE_BOUNDARY=ACTIVE

All:    FAILURE_CLASSIFICATION=NO_FAILURE_EVIDENCE
```

Raw evidence remains on pain at:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-RERUN2-20260831/
```

Files:

- `preflight-01-jtag.log`
- `preflight-02-jtag.log`
- `preflight-03-jtag.log`

## Required 100-sample smoke

Command parameters were `samples=100`, `gap_ms=100`, Slave board `DE5 [1-11.2]`.

The smoke did not meet the validity gate:

```text
SAMPLES=100
VALID_FRAMES=0
INVALID_FRAMES=100
PI_TRACE_PRESENT=0
PI_TRACE_FRACTION=0.000
PI_SNAPSHOT_REJECTS=594
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
MEASUREMENT_COHERENCE=CHECK
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
RESET_STABLE=PASS
SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=1
HELPER_LOCKED_FINAL=0
HELPER_LOCK_COUNT_FINAL=0
PSTAT_LOCKED_FINAL=0
```

The raw sample payloads were present and the counters advanced, but every frame was rejected by the observer's epoch-consistency rule. Therefore this is an invalid measurement window, not evidence that `ki=-1` failed to lock.

Raw smoke evidence:

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-RERUN2-20260831/smoke-100-jtag.log
```

## Decision

Per the Step 5 protocol, the failed 100-sample validity gate requires stopping before the 1800-second observer. No 1800-second result was collected in this rerun.

```text
RUNTIME_OBSERVER_PREFLIGHT = PASS
STEP4B_RUNTIME_GATE = PASS
STEP5_SMOKE_VALID = NO
EXPERIMENT_VALID_FOR_STEP5 = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

This report does not change the firmware or control parameters and does not authorize a merge. The next decision must address the observer validity failure before any Step 5 lock conclusion is drawn.

