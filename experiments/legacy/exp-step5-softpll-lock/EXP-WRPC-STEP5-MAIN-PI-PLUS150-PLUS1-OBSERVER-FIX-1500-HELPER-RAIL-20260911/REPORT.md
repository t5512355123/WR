# EXP-WRPC-STEP5-MAIN-PI-PLUS150-PLUS1-OBSERVER-FIX-1500-HELPER-RAIL-20260911

## 結論

**Step 5 = NOT COMPLETE。** 本輪確認 Step 4B 的事件鏈仍然成立，Main frequency lock 曾成立，但 Helper 最終飽和在高 rail，Main phase lock、Main lock 與 `PSTAT.locked` 都沒有成立，因此不能宣告 Step 5 pass。

本輪亦確認問題不是觀測器的欄位錯置：修正後的 coherent observer 能正確讀出 Helper lock threshold=2000、lock dwell=1000，且所有 1500 個 measurement snapshot 都 coherent。

## 版本與硬體流程

- branch: `exp/step5-softpll-lock`
- source HEAD: `f72feac` (`exp: correct Step5 trajectory accounting`)
- control firmware provenance: Main PI `kp=+150, ki=+1` inherited from `f73d3a9`; `f72feac` only corrected Step 5 observer accounting.
- board: `DE5 [1-11.2]`
- fresh full compile: Master PASS, Slave PASS
- fresh JTAG program: Slave PASS, Master PASS
- Master SOF SHA256: `741c9e4633d467f1415b2f4dba3eb1e8df7cd9f7618addd04254a437cfe43cad`
- Slave SOF SHA256: `34a83200408e4dcc325de671906f33232b803e52ee789faafbc12a4c38498853`

The first immediate preflight was invalid because Slave was still `UNCALIBRATED`. After the required warm-up/retry, the coherent run had valid WR/PTP traffic, `STEP4B_RESULT=PASS`, `LOCK_ENABLE_COUNT=4`, and `SPLL_SEQ_STATE=SEQ_WAIT_MAIN`.

## Coherent 1500-sample result

Observer: `read_step5_coherent_closed_loop_trajectory_audit.tcl 1500 100 "DE5 [1-11.2]"`

```text
COHERENT_MEASUREMENT_SNAPSHOTS=1500
REJECTED_EPOCH_SNAPSHOTS=0
MEASUREMENT_ACCOUNTING_FAILS=0
POSITION_SNAPSHOTS=1458
POSITION_INVARIANT_FAILS=0
TRANSACTION_INVARIANT_FAILS=0
DCO_TOTAL_LOWER_BOUND_FAILS=0
FREQ_ERROR_MEAN=-2.4153
FREQ_ERROR_RMS=10.0303
FREQ_ERROR_MIN=-40
FREQ_ERROR_MAX=26
HELPER_ERROR_MEAN=-109488.8747
HELPER_ERROR_RMS=1251223.0282
HELPER_ERROR_MAX_ABS=150000
LOW_RAIL_FRACTION=0.0
HIGH_RAIL_FRACTION=0.9007
LOCK_COUNT_MAX=1000
LOCK_COUNT_FINAL=0
HELPER_LOCKED_SEEN=209
HELPER_LOCKED_FINAL=0
MAIN_ENABLED_FINAL=1
MAIN_FREQ_LOCKED_FINAL=1
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
FULL_CHAIN_300S=0
STEP5_CHAIN_RESULT=NOT_COMPLETE
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
RESET_STABLE=PASS
NORMAL_REQ_DELTA_OBSERVED=117
NORMAL_COMPLETED_DELTA=117
FINC_DELTA=60
FDEC_DELTA=57
DCO_STEP_DELTA=24119
BOOTSTRAP_COMPLETED_FINAL=3360
BOOTSTRAP_DONE_FINAL=1
```

Interpretation: the initial Helper admission did occur, and Main frequency detector reached lock. The failure is downstream of frequency convergence: the Helper phase error left its admission band and drove the actuator to the upper rail. The hardware remained alive and did not reinitialize, so this is a closed-loop control/phase-coordinate failure, not another Step 4 startup reset.

## Additional Helper PI trace

Observer: `read_step5_helper_pi_state_rail_audit.tcl 120 100 "DE5 [1-11.2]"`

```text
VALID_FRAMES=120
PI_TRACE_FRACTION=100.000
PI_SNAPSHOT_REJECTS=0
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
RAW_ERROR_MEAN=-9338615.1333
RAW_ERROR_MIN=-9464741
RAW_ERROR_MAX=-9017622
RAW_ERROR_POSITIVE_FRACTION=0.0
HELPER_ERROR_MEAN=-150000
HIGH_RAIL_FRACTION=100.000
LOCK_COUNT_FINAL=0
FREQ_ERROR_MEAN=-0.4833
FREQ_ERROR_RMS=9.3853
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
P_ADDER_FINAL=51332352
P_SETPOINT_FINAL=60448439
PI_INTEGRATOR_BEFORE_FINAL=268256636
PI_INTEGRATOR_AFTER_FINAL=268256636
PI_UNCLAMPED_FINAL=71027
PI_CLAMPED_FINAL=65531
PI_CLAMP_SIDE_FINAL=1
```

The important separation is:

- consecutive-tag frequency error is near zero;
- raw phase error is persistently about `-9.3M` tics;
- the exported/clamped Helper error is therefore always `-150000`;
- anti-windup is behaving as designed and is not the cause;
- output is high-rail limited rather than hunting through both rails.

This points to the Helper phase accumulator / tag-coordinate contract (including wrap and normalization), not to an insufficient PI gain or a lock threshold that should be widened. The current source uses `TAG_BITS=22`, while the TRR tag value field is 24 bits, and it applies a separate `HELPER_TAG_WRAPAROUND=100000000` normalization. That combination must be audited against the actual tag representation before another gain experiment.

## Evidence archive

The complete raw v2 archive, including build, program, preflight, 1500-sample trajectory, and Helper PI trace logs, is:

```text
EXP-WRPC-STEP5-MAIN-PI-PLUS150-PLUS1-OBSERVER-FIX-1500-HELPER-RAIL-20260911-raw-v2.tgz
SHA256=df5e8d629f3c5e8631134cb4efa3927984befd445d7ba5b3d5fef2ede7377876
```

The extracted raw files are kept in this experiment folder under `raw/`.

## Next experiment decision

Do not change PI gains, lock thresholds, or bypass the Helper gate in the next iteration. First perform a source audit and controlled correction of the Helper tag/phase accumulator representation. The acceptance criteria for that next run are:

1. raw phase error no longer has a persistent multi-million-tic bias;
2. Helper output is not permanently rail-limited;
3. Helper lock remains valid after the Main loop is enabled;
4. only then run the long same-window Step 5 closure test.

`MERGE_APPROVED=NO`

