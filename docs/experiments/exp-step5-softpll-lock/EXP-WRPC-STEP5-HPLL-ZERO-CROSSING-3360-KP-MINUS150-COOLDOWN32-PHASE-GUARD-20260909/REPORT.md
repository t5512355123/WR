# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-COOLDOWN32-PHASE-GUARD-20260909

## 判定

本輪只把 normal HPLL cooldown 從 16 loads 改為 32 loads，保留實體
`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=64` 與其他 Step5 設定不變。編譯、
燒錄、upstream recovery 與完整 3600-sample observer 均成功；coherent
measurement、position accounting、transaction/DCO invariant 與 reset
stability 全部通過，但仍有 actuator hunting，Helper 最終未 lock，故
Step5 尚未完成，不能 merge。

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
ACTUATOR_HUNT_OBSERVED = YES
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
MERGE_APPROVED = NO
```

## Source / experiment variable

```text
Source commit = 7b3f2daf6f4a496633cb26ba1d7b5d31bd76be8d
Helper kp = -150
Helper ki = -1
Slave HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64
Slave STEP5_BOOTSTRAP_STEPS = 3360
Slave STEP5_BOOTSTRAP_REVERSE = 1
Slave STEP5_NORMAL_HPLL_COOLDOWN_LOADS = 32
Helper phase guard = 60 seconds
```

唯一 functional 變因是 `STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 16 -> 32`；lock
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
MASTER_SOF_SHA256 = 51ca4405b9f902905e26de4b77062ef8d740a513c17dfa5b25e9d7ef64b280dc
SLAVE_SOF_SHA256 = 39c4925536b93f3bf685f5111ba58977cb1bc11fd840e6982cd1e2b99e852fe
TIMING_CLOSED = NO
```

## Upstream preflight

第一次配置後依然可能落在已知 recovery 狀態；再次以 Master→45 秒→Slave
配置後，`preflight.log` 顯示有效窗口：

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

因此下方 observer 是有效 Step5 窗口，不是 upstream-blocked 假測。

## 3600-sample coherent Step5 observation

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3597
REJECTED_EPOCH_SNAPSHOTS = 3
REJECTED_ACCOUNTING_CANDIDATES = 211
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3600
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS

FREQ_ERROR_MEAN = 1.18737837086
FREQ_ERROR_RMS = 15.1252853304
FREQ_ERROR_MIN = -56
FREQ_ERROR_MAX = 44
HELPER_ERROR_MEAN = -22682.9480122
HELPER_ERROR_RMS = 47820.77599135
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0478176257993
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 0.405059772032
NO_RAIL_FRACTION = 0.594940227968

ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
LOCK_COUNT_MAX = 10000
LOCK_COUNT_FINAL = 565
LOCK_COUNT_RISE_EVENTS = 333
LOCK_COUNT_FALL_EVENTS = 326
ERROR_BAND_EXIT_EVENTS = 96
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0

TARGET_FINAL = 63850
APPLIED_FINAL = 63877
EXPECTED_APPLIED_ABSOLUTE = 63877
NORMAL_REQ_DELTA_OBSERVED = 24564
NORMAL_COMPLETED_DELTA = 24564
FINC_DELTA = 12269
FDEC_DELTA = 12295
DCO_STEP_DELTA = 24564
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

cooldown32 比 cooldown16 恢復了 position/DCO accounting，但 normal transaction
仍達 24,564 次，且 phase error 在高 rail/非 rail 間往返，形成 underdamped
hunting。雖然 frequency error 已接近零，Helper 沒有進入 final lock，Main
也沒有合法啟用；不能把 frequency-only 的改善當成 Step5 pass。

## 下一步

16/32/64/256 的 rate-limit A/B 已顯示：更新速率不是唯一阻塞點。下一輪停止
cooldown 掃描，改做 phase setpoint/actuator authority 的獨立驗證：保留
`step=64、bootstrap=3360、kp=-150、ki=-1`，新增唯讀 phase/target/applied
correlation，確認負 rail 是 phase setpoint 偏移、實體 authority 不足，還是
共享 DCO 頻率與 phase 量測的座標不一致。不得調低 lock threshold，也不得
以短暫 lock count 或 Main enabled 宣稱 Step5。

## Raw evidence

本輪 Pain 原始檔案位於 `raw/`。原始封存檔 SHA-256：

```text
14c2bd3958a85f2852ece7e55790d16a89e2d6b4521f4e04de1e0fde8b477105
```
