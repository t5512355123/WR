# EXP-S5-F3A-GUARD8S-BOOTSTRAP3388-KP2250-KI2-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`026309d4c9e601421bdaca72cf912db44db2e7bd`  
Experiment commit：待本輪報告提交後填入

## Verdict

```text
STEP4B = PASS                 (second settled preflight)
F3A_GUARD_8S = REJECTED_FOR_STEP5_CLOSURE
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
FULL_CHAIN_MAX_SECONDS = 0
NEXT_WORK_PACKAGE = F4a Main PI / frequency prelock gain
MERGE_APPROVED = NO
```

本輪沒有達成 Step5，也沒有 merge。

## 實驗設計

F2B 的 bootstrap `3216` 直接落在 high rail，因此本輪回到最後已證明能
產生 Helper lock 與 Main frequency progress 的 operating point `3388`，
再執行 Fable F3a 的唯一新功能變因：

```c
- STEP5_HELPER_PHASE_GUARD_TICS = (60 * TICS_PER_SECOND)
+ STEP5_HELPER_PHASE_GUARD_TICS = (8 * TICS_PER_SECOND)
```

相對可工作的 F1-A2 基準，bootstrap `3388`、Helper `kp=-2250, ki=-2`、
reverse 1、physical step code 64、cooldown 0、threshold 2000、lock
samples 1000、Main PI、WR timeout 與 RTL arbitration 均保持不變。

Observer 另有非功能性 provenance 修正：命令列明確傳入實際的 bootstrap、
Helper PI、guard 秒數與實驗名稱，讓 post-bootstrap boundary 不再誤用舊
metadata；不改讀取地址、packing 或控制器。

## Laptop → GitHub → Pain

Laptop 端既有 Step5 replay regression tests 通過 7/7，push 後 Pain 拉取
並核對完整 source commit：

```text
REMOTE_HEAD = 026309d4c9e601421bdaca72cf912db44db2e7bd
```

### Build

```text
MASTER_BUILD = PASS (exit 0)
SLAVE_BUILD  = PASS (exit 0)
TIMING_CLOSED = NO (existing implementation caveat)
```

兩張 SOF 與兩份 MIF 的 SHA-256 已保存於 `raw/image-sha256.txt`。

### Program

直接 Quartus programmer 完成實際配置：

```text
MASTER cable = DE5 [1-11.1], Configuration succeeded, 0 errors, 0 warnings
SLAVE  cable = DE5 [1-11.2], Configuration succeeded, 0 errors, 0 warnings
```

Master→Slave 45 s 間隔與 Slave 後 120 s settled wait 均有時間戳記。

## Settled preflight

第一次 preflight 的 Master gate 通過，但 Slave 出現與前幾輪相同的瞬時
`UNCALIBRATED`，因此不採用該次的 Step4B 結果。追加 60 s 後重跑，得到：

```text
Slave STEP1_REGRESSION = PASS
Slave STEP2_REGRESSION = PASS
Slave STEP3_REGRESSION = PASS
Slave STEP4B_ALLOWED   = YES
Slave STEP4B_RESULT    = PASS
```

第二次 preflight 當下已見：

```text
HELPER locked=1
MAIN enabled=1
MAIN frequency locked=1
MAIN phase locked=0
PSTAT locked=0
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
```

## Coherent smoke

使用修正後、帶有實際 image metadata 的 observer：

```text
quartus_stp -t scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl \
  120 100 "DE5 [1-11.2]" 3388 -2250 -2 8 \
  EXP-S5-F3A-GUARD8S-BOOTSTRAP3388-KP2250-KI2-20260915
```

設定列已正確顯示：

```text
bootstrap_steps=3388
kp=-2250 ki=-2
helper_phase_guard_seconds=8
```

Smoke 結果：

```text
SAMPLES = 120
COHERENT_MEASUREMENT_SNAPSHOTS = 120
MEASUREMENT_COHERENCE = PASS
POSITION_SNAPSHOTS = 96
POSITION_ACCOUNTING = PASS

HELPER_ERROR_RMS = 1151.34545931
HELPER_ERROR_MAX_ABS = 5066
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 0.0
NO_RAIL_FRACTION = 1.0
HELPER_LOCKED_SEEN = 104
HELPER_LOCKED_FINAL = 1
NORMAL_REQ_DELTA_OBSERVED = 598
NORMAL_COMPLETED_DELTA = 598
MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
RESET_STABLE = PASS
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

Smoke 通過「可工作的 operating point」門檻，但沒有 phase/PSTAT lock，
因此進入長測而不是宣告通過。

## 6000-sample long observer

同一組 image 與 metadata 執行 6000 samples、100 ms gap；observer 於
`2026-09-15T00:52:11+08:00` 開始，`2026-09-15T01:06:19+08:00` 結束，
最後 sample 的 observer elapsed 為 `847216 ms`。

replay 與 observer summary 一致顯示：

```text
SAMPLES = 6000
COHERENT_MEASUREMENT_SNAPSHOTS = 6000
POSITION_SNAPSHOTS = 4677
POSITION_ACCOUNTING = PASS
MEASUREMENT_COHERENCE = PASS
RESET_STABLE = PASS

HELPER_ERROR_MEAN = 12.5623333333
HELPER_ERROR_RMS = 890.568037453
HELPER_ERROR_MAX_ABS = 5441
FRACTION_ABS_ERROR_LE_200 = 0.400666666667
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 0.0
NO_RAIL_FRACTION = 1.0

HELPER_LOCKED_SEEN = 5293
HELPER_LOCKED_FINAL = 1
FIRST_HELPER_LOCK_SAMPLE = 7
LOCK_COUNT_RISE_EVENTS = 414
LOCK_COUNT_FALL_EVENTS = 175
ERROR_BAND_EXIT_EVENTS = 715
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE

MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

雖然 Helper 不再碰 rail，且 Main frequency lock 穩定存在，但 Main phase
lock 從未成立；此外 Helper 仍以約 0.6–0.7 Hz 的 lock/unlock hunting 反覆
進出。這證明 8 秒 guard 解決的是不必要的 startup 等待，沒有解決 Fable
指出的 Main phase acquisition／damping 問題。

## 判讀與下一步

本輪的結論是「F3a 有效地縮短 startup，但不足以達成 Step5」。不能以
`HELPER_LOCKED_FINAL=1` 或 `MAIN_FREQ_LOCKED_FINAL=1` 代替 phase lock、
PSTAT lock 與連續 300 s full-chain 證據。

下一輪執行 Fable F4a，保持 bootstrap `3388`、guard `8 s`、Helper
`-2250/-2` 與所有 RTL/timeout 不變，只修改 Main firmware：

```c
#define MPLL_FREQ_PRELOCK_GAIN_BOOST 4  /* 原 20 */
s->pi.kp = 1300;                       /* 原 300 */
s->pi.ki = 3;                          /* 原 1 */
```

F4a 的驗收重點是 Main phase error 是否收斂、`MAIN_PHASE_LOCKED` 是否
出現，以及是否能消除 phase mode 進入後的 hunting。若 F4a 仍因 Helper
服務被 Main backlog 餓住，再另開 F4b；本輪不把 F4a/F4b 合併。

## Raw / analysis index

```text
raw/build-master.log
raw/build-slave.log
raw/program-master-direct.log
raw/program-slave-direct.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-after60.log
raw/observer-smoke-120.log
raw/observer-long-6000.log
raw/image-sha256.txt
raw/checksums.sha256
analysis/replay-smoke/verdict.json
analysis/replay-long/verdict.json
```
