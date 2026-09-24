# EXP-S5-F4A-CONTROL-RESTORE-MAIN-PI-UPSTREAM-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`ca2a1d45bae191c32bf5629acc887e7b435e8c46`

## Verdict

```text
SOURCE_BUILD = PASS
PROGRAM = PASS
PREFLIGHT = PASS (settled retry)
STEP4B_ALLOWED = YES
CONTROL_LONG_CAPTURE = VALID
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
F4A_UPSTREAM_REGRESSION = STRONGLY_SUPPORTED_BY_CONTROL
MERGE_APPROVED = NO
```

本輪是 F4a 的 control，不是 Step5 pass。它的目的，是把 F4a 的 Main PI
變更與 upstream WR signaling 問題分開。Control 恢復了 Step1/2/3/4B，證明
F4a candidate 不能直接拿來做 phase-lock 判定；但在已知可工作的 upstream 下，
Main phase 仍沒有收斂。

## Control 變因

相對 F4a candidate，本輪只恢復
`vendor/wrpc-sw/softpll/spll_main.c` 的 Main 設定：

```text
MPLL_FREQ_PRELOCK_GAIN_BOOST = 20
Main PI kp = 300
Main PI ki = 1
```

保留 F3a/F4a 共用條件：

```text
bootstrap_steps = 3388
helper_kp = -2250
helper_ki = -2
helper_phase_guard = 8 s
helper_threshold = 2000
helper_lock_samples = 1000
normal_hpll_cooldown_loads = 0
WR timeout = 60 s
```

## Laptop → GitHub → Pain

Laptop 先通過 Step5 replay regression tests：`7/7 OK`，再 push control commit。
Pain pull 後核對：

```text
REMOTE_HEAD = ca2a1d45bae191c32bf5629acc887e7b435e8c46
BRANCH = exp/step5-softpll-lock
```

### Clean build

```text
MASTER_BUILD = PASS, 02:06:06–02:10:16 +08:00
SLAVE_BUILD  = PASS, 02:10:16–02:15:09 +08:00
TIMING_CLOSED = NO
MASTER WNS = -0.251 ns
SLAVE  WNS =  0.032 ns
```

Fresh SOF：

```text
MASTER SOF SHA256 = f44f428bd71784b34dfb7c11ce0854d7748098925bd24f787e8df32f9d8cc2db
SLAVE  SOF SHA256 = 8d7b46f1686a8ae4fec6f3b5e3cdebdc8bfaf2e3f43b6c8347e235c5fdb354dc
```

### 實際燒錄

```text
Master cable DE5 [1-11.1]：Configuration succeeded，0 errors，0 warnings
Slave  cable DE5 [1-11.2]：Configuration succeeded，0 errors，0 warnings
PROGRAM_ORDER = MASTER → 46 s → SLAVE
```

## Settled preflight

120 s settle 後，第一次 preflight 的 Slave 已恢復 PHY/parent signaling，但仍是
啟動暫態 `WDIAGS_PTP=UNCALIBRATED`，所以 Step2/Step4B 當下未採用。追加 60 s
後的 retry 才是有效 gate：

```text
Slave STEP1 = PASS
Slave STEP2 = PASS
Slave STEP3 = PASS
Slave STEP4B_ALLOWED = YES
Slave STEP4B_RESULT = PASS
Slave STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
LOCK_ENABLE = 4
WR_RX_SIGNAL_DEBUG = LOCK count=1
WR_TX_SIGNAL_DEBUG = SLAVE_PRESENT count=1
```

Master 的 Step1/2/3/4A 也全部 PASS。兩次 preflight 的 WB transport 都可信，
retry summary 為：

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
```

## Coherent Step5 observation

### Smoke

Observer 設定列確認使用 control image：`bootstrap=3388`、Helper `kp=-2250`、
`ki=-2`、guard `8 s`、Main `kp=300`、`ki=1`。

```text
SAMPLES = 120
COHERENT_MEASUREMENT_SNAPSHOTS = 120
POSITION_SNAPSHOTS = 96
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
HELPER_LOCKED_SEEN = 105
HELPER_LOCKED_FINAL = 1
HELPER_ERROR_RMS = 1031.5686
HIGH_RAIL_FRACTION = 0.0
RESET_STABLE = PASS
MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

### Long capture

```text
SAMPLES = 6000
COHERENT_MEASUREMENT_SNAPSHOTS = 6000
POSITION_SNAPSHOTS = 4639
HELPER_ERROR_MEAN = 1.7468
HELPER_ERROR_RMS = 929.1974
HELPER_ERROR_MAX_ABS = 5891
FRACTION_ABS_ERROR_LE_200 = 0.3778
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 0.0
HELPER_LOCKED_SEEN = 5308
HELPER_LOCKED_FINAL = 1
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
NORMAL_REQ_DELTA_OBSERVED = 25385
NORMAL_COMPLETED_DELTA = 25385
DCO_STEP_DELTA = 63542
BOOTSTRAP_COMPLETED_FINAL = 3388
MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0.000
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
```

離線 replay 也得到 `full_chain_segments=[]`、`generation_changes=0`，且
`step5_pass=false`。所以 control 的有效結論是：Helper 可以持續工作並產生
normal DCO completions，但 Main phase-lock 沒有出現。

## 判讀

1. F4a candidate 在同一硬體流程下曾使 upstream gate 長時間不成立；恢復
   Main baseline 後，冷開機後的 control 能回到 Step3/Step4B PASS。這對 F4a
   upstream regression 提供強支持。
2. 這仍不是形式上的唯一因果證明，因為每次 fresh Quartus fit 的 SOF hash
   不同，且 preflight 受啟動時間影響；後續應以 per-image isolation 再確認。
3. 在 upstream 合法、JTAG transport trusted、position/accounting/reset 都
   PASS 的條件下，6000 筆仍是 `MAIN_PHASE_LOCKED=0`。因此 F4a 的高 Main PI
   並非可直接採用的修正，F3a control 也不足以達成 Step5。

## 下一步

不要再把高 Main PI 同時編入 Master 與 Slave。下一輪應建立 per-image isolation：

```text
EXP-S5-F4B-SLAVE-ONLY-MAIN-PI-ISOLATION-20260915
```

Master 固定 control（`kp=300, ki=1, boost=20`），只讓 Slave image 使用候選
Main PI；保留本輪已知可工作的 Helper/guard/bootstrap。建置腳本與 image
identity 必須明確標示兩張板的 Main PI，完成 build/program 後先取得三次
settled preflight，再做 smoke/long observer。若 upstream 恢復且 phase 仍不鎖，
才進一步判斷候選 Main PI 的相位效果；若 upstream 再次消失，立即停止，不調
timeout 或 PI。

## Raw evidence

```text
raw/build_jtag_master.log
raw/build_jtag_slave.log
raw/build_info_jtag_master.txt
raw/build_info_jtag_slave.txt
raw/program-master.log
raw/program-slave.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-retry.log
raw/observer-smoke-120.log
raw/observer-long-6000.log
analysis/replay-smoke/verdict.json
analysis/replay-long/verdict.json
raw/checksums.sha256
```

Pain 原始壓縮檔與完整 build logs 保留於 `raw-transfer/`。
