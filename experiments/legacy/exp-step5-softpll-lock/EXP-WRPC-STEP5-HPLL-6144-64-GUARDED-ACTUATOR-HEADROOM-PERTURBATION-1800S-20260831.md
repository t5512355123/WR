# EXP-WRPC-STEP5-HPLL-6144-64-GUARDED-ACTUATOR-HEADROOM-PERTURBATION-1800S-20260831

## 判定

```text
STEP4B_COMPLETE = YES
HEADROOM_PERTURBATION_DIRECTION_EFFECTIVE = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

這次實驗證明 6144-step bootstrap 確實改變了 actuator 的可觀測工作區域，但沒有讓 Helper PLL lock。因此不能宣告 Step 5 完成，也不能 merge 到 `main`。

## 實驗範圍

- Branch：`exp/step5-softpll-lock`
- 低軌 audit baseline：`aa5f521c7cbe4686521ac60f22601e9e601912e2`
- 實驗 source commit：`41a0e7d2bf3d12b7518564e53546c8e726a9e82a`
- Evidence commit：`05525ff`
- 實驗窗口：`SAMPLES=18000`、`WINDOW_SECONDS=1799.900`

唯一 functional 變更是 Slave RTL 的：

```text
STEP5_BOOTSTRAP_STEPS: 6208 -> 6144
```

以下設定保持不變：

- `kp=-150`、`ki=-2`
- `SHIFT=12`、`BIAS=5`
- `Y_MIN=5`、`Y_MAX=65531`
- guarded actuator、64 code/step
- helper threshold `200`、lock samples `10000`
- DMTD、P_ADDER、P_SETPOINT、phase setpoint、Main PLL、sequencer、reset tree
- 未強制 FINC/FDEC，未手動寫入 DCO

## Build / program

Slave 與 Master 均 fresh compile 成功，並完成兩張 DE5a 的 fresh program。Quartus 報告仍為 `TIMING_CLOSED=NO`，因此 timing closure 是保留 caveat，不在本實驗中改動。

```text
GIT_COMMIT=41a0e7d2bf3d12b7518564e53546c8e726a9e82a
Slave SOF SHA256 = 9860da4c2dbb1bc6982bc48b8075c47c2900c4ff20d39b3f68044b06922a9865
Master SOF SHA256 = 8c86234c7ce229e0018cf268b86d27211ca96d6d9090720139eb713e4324d0a5
Slave WNS = -0.116 ns
Master WNS = -0.453 ns
```

## 1800-second PI / actuator evidence

完整 observer summary：

```text
SAMPLES=18000
VALID_FRAMES=17958
INVALID_FRAMES=42
WINDOW_SECONDS=1799.900
PI_TRACE_FRACTION=99.767%
PI_SNAPSHOT_REJECTS=2511
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
POSITION_CONTEXT_FAILS=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
RESET_STABLE=PASS
```

Actuator / error distribution：

```text
RAW_ERROR_POSITIVE_FRACTION=73.3822336561%
LOW_RAIL_FRACTION=73.3822336561%
HIGH_RAIL_FRACTION=26.618%
NO_RAIL_FRACTION=0.000%
LOW_RAIL_SATURATION=NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY=NOT_CONFIRMED
CAUSALITY_CASE=B
RAIL_TO_RAIL_CYCLE_COMPLETE=1
```

這表示 6144 已經讓系統離開前一輪 6208 的 100% low-rail 狀態，並且觀測到 high-rail 區段與完整 rail-to-rail cycle；這是 direction-effective headroom evidence，但不是 lock evidence。

交易與 reset 相關的完整窗口結果：

```text
SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=1
POST_INITIAL_SPLL_INIT_DELTA=0
CLEAR_DACS_DELTA=0
SPLL_DELOCK_COUNT_FIRST=0
SPLL_DELOCK_COUNT_FINAL=0
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
NORMAL_REQ_DELTA=4092
NORMAL_COMPLETED_DELTA=4092
DCO_STEP_DELTA=4092
FORCED_COMPLETED_DELTA=0
BOOTSTRAP_COMPLETED_FINAL=6144
BOOTSTRAP_DONE_FINAL=1
```

## Step 4B regression and Step 5 gate

Fresh-program 後的 dashboard regression：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

Step 5 仍停在 Helper lock：

```text
LOCK_COUNT_MAX=0
LOCK_COUNT_FINAL=0
HELPER_LOCKED_FINAL=0
HELPER_LOCK_COUNT_FINAL=0
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此本輪結論是：

- Step 4B：PASS
- 6144 actuator-headroom perturbation：方向性證據成立
- Step 5：NO，Helper PLL 從未進入 lock
- merge to `main`：NO，等待分支 5 明確批准

## Raw evidence

- `raw/build_info_jtag_slave.txt`
- `raw/build_info_jtag_master.txt`
- `raw/build_jtag_slave.log`
- `raw/build_jtag_master.log`
- `raw/program-jtag-slave.log`
- `raw/program-jtag-master.log`
- `raw/dashboard-settled-1.log`
- `raw/dashboard-after-1800s.log`
- `raw/pi-trace-18000.log`

