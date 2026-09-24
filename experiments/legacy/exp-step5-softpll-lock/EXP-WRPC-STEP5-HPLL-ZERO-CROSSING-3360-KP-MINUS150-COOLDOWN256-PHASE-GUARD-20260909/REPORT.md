# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-COOLDOWN256-PHASE-GUARD-20260909

## 判定

本輪先在 cold power-cycle 後重現 upstream/link blocker；接著依既有成功的
recovery sequence，以 Master 先燒錄、等待 45 秒、再燒錄 Slave，成功恢復
兩板 link 與 Slave Step4B。之後 cooldown256 的完整 3600-sample observer
確實執行，但 Helper phase error 全程落在負 rail，沒有進入 lock；因此本輪
不是 Step5 pass，不能 merge。

```text
STEP4B_ALLOWED = YES (recovery2)
STEP4B_RESULT = PASS (recovery2)
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

## 實驗目的與 source 變更

本輪恢復最後一個已知可進入 fine loop、且 position accounting 通過的基線，並
加入最小的 normal-DCO rate-limit A/B：

```text
Helper PI: kp=-150, ki=-1
Slave HPLL_TRACKER_CODE_PER_PHYSICAL_STEP: 64
Slave STEP5_BOOTSTRAP_STEPS: 3360
Slave STEP5_BOOTSTRAP_REVERSE: 1
Slave STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 256
Helper phase guard: 60 seconds
```

`STEP5_NORMAL_HPLL_COOLDOWN_LOADS=256` 的語意是：每次 normal HPLL physical
transaction 完成後，必須再收到 256 次 accepted Helper target load，才允許
下一個 normal transaction。Master 維持預設 `0`；lock threshold 與 lock
sample count 沒有修改。

Source code commit:

```text
50f1f1db28a83cc22df8ff327659d7e46872c3ec
```

Recovery rebuild 使用的 branch tip 是 `10d782867e1e389043861449626bffe001677ddd`
（只包含本實驗報告，source code 與上述 commit 相同）。

## Build / program

Pain 從上述 source code 的乾淨 detached worktree 完整編譯 Master 與 Slave，
兩次 build 均成功；cold power-cycle 後的首次 programming，以及 recovery
reprogramming，均直接 JTAG 成功，0 errors、0 warnings。

```text
MASTER_COMPILE_RESULT = PASS
SLAVE_COMPILE_RESULT = PASS
MASTER_PROGRAM_RESULT = PASS
SLAVE_PROGRAM_RESULT = PASS
MASTER_SOF_SHA256 = 5a1397708f7622bd00e23bd02e5dbe2c3220fe13bf999d1555dff8a62d140340
SLAVE_SOF_SHA256 = 5cfb0622bce413b68fbef2905767b4da6a1959647a92c918ee15057f25589a92
TIMING_CLOSED = NO
```

Recovery rebuild 的 SOF SHA-256：

```text
MASTER_SOF_SHA256_RECOVERY = 5a1397708f7622bd00e23bd02e5dbe2c3220fe13bf999d1555dff8a62d140340
SLAVE_SOF_SHA256_RECOVERY = 5cfb0622bce413b68fbef2905767b4da6a1959647a92c918ee15057f25589a92
```

## Preflight observation

第一次燒錄後的 preflight 與等待後 retry 都重現 cold-start blocker：

```text
Master:
  si_config_done=1, wr_ready=1, wr_rx_ready=1, wr_tx_ready=1
  core_tm_link_up=0, core_link_ok=0
  STEP4A_MASTER_EVENT_CHAIN=PASS

Slave:
  si_config_done=1, wr_ready=1, wr_rx_ready=1, wr_tx_ready=1
  core_tm_link_up=0, core_link_ok=0
  WDIAGS_PTP=LISTENING (first window)
  parentIsWRnode=0
  STEP4B_ALLOWED=NO
  STEP4B_RESULT=BLOCKED_BY_STEP1
  STEP4B_FIRST_INACTIVE_BOUNDARY=UPSTREAM_PREREQUISITE
  STEP5_RESULT=UPSTREAM_NOT_READY
```

之後完成一次實體 power-cycle，重新燒錄後再以 Master→等待 45 秒→Slave 的
recovery sequence 配置；`preflight-recovery2.log` 顯示：

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

因此本輪的 3600-sample closed-loop trajectory audit 是有效窗口，不是
upstream-blocked 假測。

## 3600-sample Step5 observation

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

FREQ_ERROR_MEAN = 1.24361111111
FREQ_ERROR_RMS = 42.9961012444
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 1.0
NO_RAIL_FRACTION = 0.0

ACTUATOR_HUNT_OBSERVED = NO
HELPER_DYNAMICS = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
LOCK_COUNT_MAX = 1
LOCK_COUNT_FINAL = 1

TARGET_FINAL = 65531
APPLIED_FINAL = 65541
EXPECTED_APPLIED_ABSOLUTE = 65541
NORMAL_REQ_DELTA_OBSERVED = 476
NORMAL_COMPLETED_DELTA = 476
FINC_DELTA = 476
FDEC_DELTA = 0
DCO_STEP_DELTA = 476
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

這個 A/B 的有效結論是：cooldown256 成功消除前一輪的明顯 actuator hunting，
所有 coherent/position/reset 證據通過，且 frequency error 平均接近零；但
phase branch 的 raw/preclamp error 仍為負方向飽和，Helper lock 沒有成立，
所以 Main gate 沒有開啟。這不是「cooldown 已讓 Step5 通過」，而是指出
控制速率與 phase operating point 之間仍有另一個未解決的偏差。

## Power-cycle safety result

第一次 power-cycle 嘗試因控制項辨識度不足而安全停止，記錄保留於
`raw/pain-power-cycle-safety-stop.txt`；之後重新嘗試時 Edge 與 Pain 控制項
辨識成功，完成關閉、10 秒等待、重新開啟，第二次狀態重新辨識成功，120 秒
後 SSH probe 成功。這次實體 power-cycle 與後續 recovery reprogram 均已
完成，相關檔案位於 `raw-recovery/`。

## 下一步

下一輪不再把 cooldown256 當成成功設定；保留 `kp=-150、ki=-1、step=64、
bootstrap=3360`，只把 cooldown 做較短的 A/B（先測 64 loads），以確認 phase
rail 是「等待太久導致 phase 漂移」還是固定 operating-point/相位座標偏差。
仍須先以 Master→45 秒→Slave recovery sequence 取得 `STEP4B_ALLOWED=YES`，
再執行完整 observer；任何沒有 Helper/Main/PSTAT lock 的窗口都不能宣稱
Step5 pass。

## Raw evidence

本輪第一次 Pain 原始封存檔 SHA-256：

```text
34229126b880bf5fdbfa847e287a718074804a6a46fdec8d86fd04737af3defc
```

Recovery 原始封存檔 SHA-256：

```text
2ecd320a9cf4ec54deff6e5565162d0b917e52cffb7cb0b46ac8d02e70647d8e
```
