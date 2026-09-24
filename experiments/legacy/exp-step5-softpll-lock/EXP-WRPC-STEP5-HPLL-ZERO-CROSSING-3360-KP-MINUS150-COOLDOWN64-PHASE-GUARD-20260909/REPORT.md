# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-COOLDOWN64-PHASE-GUARD-20260909

## 判定

本輪只把 normal HPLL cooldown 從上一輪的 256 loads 改為 64 loads，保留
其餘 Step5 設定不變。編譯、燒錄、upstream recovery 與完整 3600-sample
observer 均成功；結果顯示 frequency error 已大幅收斂且沒有 actuator
hunting，但 Helper phase branch 仍未 lock，Main/PSTAT gate 未開啟。因此
Step5 尚未完成，不能 merge。

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
ACTUATOR_HUNT_OBSERVED = NO
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
MERGE_APPROVED = NO
```

## Source / experiment variable

```text
Source commit = 822895c253b2cadc73f563f54b3fc24cdde2dce3
Helper kp = -150
Helper ki = -1
Slave HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64
Slave STEP5_BOOTSTRAP_STEPS = 3360
Slave STEP5_BOOTSTRAP_REVERSE = 1
Slave STEP5_NORMAL_HPLL_COOLDOWN_LOADS = 64
Helper phase guard = 60 seconds
```

唯一 functional 變因是 `STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 256 -> 64`；lock
threshold `200` 與 lock sample count `10000` 沒有修改。

## Build / program

Pain 從上述 commit 的乾淨 worktree 完整編譯 Master/Slave，兩者成功；依
Master→45 秒→Slave 順序直接 JTAG programming，兩者均為
`Configuration succeeded`、`0 errors, 0 warnings`。

```text
MASTER_COMPILE_RESULT = PASS
SLAVE_COMPILE_RESULT = PASS
MASTER_PROGRAM_RESULT = PASS
SLAVE_PROGRAM_RESULT = PASS
MASTER_SOF_SHA256 = ba17e658427d04c32ea83e23607ac699953ac2086b1f562d67d018ebc13ce37b
SLAVE_SOF_SHA256 = d792a13f2c22903acd1dfb1a6534ad983603442de65a1c1d04f78685934a8293
TIMING_CLOSED = NO
```

## Upstream preflight

燒錄後 preflight 成功建立有效 upstream：

```text
Master core_tm_link_up = 1
Master core_link_ok = 1
Master WDIAGS_PTP = 6 MASTER
STEP4A_MASTER_EVENT_CHAIN = PASS

Slave core_tm_link_up = 1
Slave core_link_ok = 1
Slave WDIAGS_PTP = 9 SLAVE
parentIsWRnode = 1
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## 3600-sample coherent Step5 observation

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS

FREQ_ERROR_MEAN = 5.10388888889
FREQ_ERROR_RMS = 19.2431950454
FREQ_ERROR_MIN = -59
FREQ_ERROR_MAX = 46
HELPER_ERROR_MEAN = -88744.3408333
HELPER_ERROR_RMS = 113531.1796995
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.00166666666667
LOW_RAIL_FRACTION = 0.0261111111111
HIGH_RAIL_FRACTION = 0.714722222222
NO_RAIL_FRACTION = 0.259166666667

ACTUATOR_HUNT_OBSERVED = NO
HELPER_DYNAMICS = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT
LOCK_COUNT_MAX = 127
LOCK_COUNT_FINAL = 100
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0

TARGET_FINAL = 65531
APPLIED_FINAL = 65541
EXPECTED_APPLIED_ABSOLUTE = 65541
NORMAL_REQ_DELTA_OBSERVED = 9990
NORMAL_COMPLETED_DELTA = 9990
FINC_DELTA = 4995
FDEC_DELTA = 4995
DCO_STEP_DELTA = 9990
BOOTSTRAP_COMPLETED_FINAL = 3360
BOOTSTRAP_DONE_FINAL = 1

MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

與 cooldown256 比較，cooldown64 讓 normal transaction 數由 `476` 增至
`9990`，並使 frequency error RMS 降至 `19.24`、範圍收斂到 `-59..46`，同時
沒有觀察到 hunting；這是有效的改善。但 phase error 仍大部分時間大於
lock threshold 且偏負，Helper lock detector 只到 `127`、最後 `100`，沒有
形成 `HELPER_LOCKED`。因此 Main 沒有被合法啟用，不能宣稱 Step5 pass。

## 下一步

下一輪保留 `step=64、bootstrap=3360、kp=-150、ki=-1`，將 cooldown 再降至
`16 loads`，測試 phase branch 是否需要更高的更新速率才能穿越 ±200 lock
band；仍使用同一套 recovery sequence 與完整 3600-sample observer。若
cooldown16 仍 phase-rail，下一個方向應停止 cooldown 掃描，改做 Helper
phase setpoint/actuator authority 的獨立辨識，不調低 lock 門檻。

## Raw evidence

本輪 Pain 原始檔案位於 `raw/`。原始封存檔 SHA-256：

```text
09efd414f1fff576816e3fb21fcb84027ca9286f44f224b75fd6d43e8d3a104a
```
