# EXP-S5-F2B-BOOTSTRAP-3216-KP2250-KI2-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`92707653712eb9435e56fdd1f07a000fbace6ffa`  
Experiment commit：待本輪報告提交後填入

## Verdict

```text
STEP4B = PASS                 (second settled preflight)
F2B_BOOTSTRAP_3216 = REJECTED
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
FULL_CHAIN_MAX_SECONDS = 0
NEXT_WORK_PACKAGE = F3a guard reduction on known-good bootstrap 3388
MERGE_APPROVED = NO
```

本輪沒有達成 Step5，也沒有 merge。

## 唯一功能變因

承接 F2 的 Helper `kp=-2250, ki=-2`，本輪只把 Slave bootstrap 從
`3860` 改為經驗 bracket 的中點 `3216`：

```vhdl
- STEP5_BOOTSTRAP_STEPS => 3860,
+ STEP5_BOOTSTRAP_STEPS => 3216,
```

`STEP5_BOOTSTRAP_REVERSE => 1`、Helper/Main PI、physical step code 64、
cooldown 0、threshold 2000、lock samples 1000、phase guard 60 s、WR
timeout 60 s 及其他 Master/Slave 控制內容均未修改。

## Laptop → GitHub → Pain

Laptop 端先通過既有 Step5 replay regression tests 7/7，push 後 Pain 拉取並
核對到完整 source commit：

```text
REMOTE_HEAD = 92707653712eb9435e56fdd1f07a000fbace6ffa
```

### Build

```text
MASTER_BUILD = PASS (exit 0)
SLAVE_BUILD  = PASS (exit 0)
TIMING_CLOSED = NO (existing implementation caveat)
```

本輪兩張 SOF 與兩份 MIF 的 SHA-256 已保存於
`raw/image-sha256.txt`；build log 也明確保留 `timing_closed=NO`。

### Program

既有標準 wrapper 會觸發 sudo prompt；為避免把未完成 wrapper 當成燒錄成功，
本輪以直接 Quartus programmer 完成實際配置：

```text
MASTER cable = DE5 [1-11.1], Configuration succeeded, 0 errors, 0 warnings
SLAVE  cable = DE5 [1-11.2], Configuration succeeded, 0 errors, 0 warnings
```

Master→Slave 45 s 間隔與 Slave 後 120 s settled wait 均有時間戳記。

## Settled preflight

第一次 settled preflight 的 Master gate 通過；Slave 當時仍為瞬時
`UNCALIBRATED`，所以沒有拿第一次結果作為 Step4B 判定。追加 60 s 後重跑，
上游 gate 恢復：

```text
Slave STEP1_REGRESSION = PASS
Slave STEP2_REGRESSION = PASS
Slave STEP3_REGRESSION = PASS
Slave STEP4B_ALLOWED   = YES
Slave STEP4B_RESULT    = PASS
```

同一份第二次 preflight 只把 Step5 的起始狀態報為：

```text
HELPER_LOCKED = 0
HELPER_LOCK_COUNT = 14
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

這是 observation window 開始前的狀態，不被解讀成長時間結論。

## Short coherent observer

依照 Step5 smoke gate 執行 Slave-only、120 samples、100 ms gap 的只讀觀測：

```text
quartus_stp -t scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl 120 100 "DE5 [1-11.2]"
```

主要結果如下：

```text
SAMPLES = 120
COHERENT_MEASUREMENT_SNAPSHOTS = 120
MEASUREMENT_COHERENCE = PASS
POSITION_SNAPSHOTS = 120
POSITION_ACCOUNTING = FAIL

HELPER_OUTPUT_FINAL = 65531
HIGH_RAIL_FRACTION = 1.0
LOW_RAIL_FRACTION = 0.0
NO_RAIL_FRACTION = 0.0
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0

NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
DCO_STEP_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 3216
BOOTSTRAP_DONE_FINAL = 1

MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE

RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
```

觀測中的 raw position/transaction 欄位本身可讀且 replay 顯示 120 筆
`position_valid`，但目前 observer source 的固定 metadata 仍寫著
`bootstrap_steps=3388`，而且 `POST_BOOTSTRAP_BASELINE_SET=0`。因此本輪的
`POSITION_ACCOUNTING=FAIL` 是 observer provenance/accounting limitation，
不能冒充硬體 position failure；它也不會推翻 rail、Helper lock、normal
transaction 與 Main/PSTAT 的直接結果。

此外，observer 的設定列仍顯示舊的 `kp=-150, ki=-1` metadata；本輪實際
firmware image 是 `kp=-2250, ki=-2`。這個 metadata mismatch 已記錄為下輪
只讀 observer 的修正項，不能拿 observer 設定列作本輪 image provenance。

## 判讀

3216 沒有落在可捕獲的工作區，而是直接把 Helper 推到上 rail：

```text
HELPER_OUTPUT = 65531
HELPER_ERROR  = -150000 (clamp)
NORMAL transaction = no progress
HELPER_LOCK = never observed
```

因此不能開始 6000-sample 或 300 s long run，也不能把這輪稱作
`INCONCLUSIVE`：即使 position accounting 受 stale observer boundary 影響，
coherent measurement、output rail、lock bit、transaction counters 與 reset
delta 已足以拒絕 3216 這個 operating point。

這個結果也修正 bracket 策略：3216 位於已知 3072 low-rail 與 3372/3388
可運作區之下，直接再往 3136 二分會離開已知可運作區。下一輪應回到最後
已證明能產生 Helper lock 的 `3388`，先執行 Fable F3a 的時序實驗；不再把
已知 rail 的 midpoint 當成新的 PI 證據。

## 下一步

依 Fable 的 F3a，下一輪使用已知可工作的 bootstrap `3388`，只縮短
Helper phase guard：

```c
- STEP5_HELPER_PHASE_GUARD_TICS = (60 * TICS_PER_SECOND)
+ STEP5_HELPER_PHASE_GUARD_TICS = (8 * TICS_PER_SECOND)
```

`kp=-2250, ki=-2`、bootstrap 3388、reverse 1、所有 threshold/timeout、
Main PI、RTL arbitration 與 reset policy 保持不變。相對 F1-A2，這是
「已知 good operating point + F3a guard」的單一新功能變因；3216/3860 是
被拒絕的 bracket 候選，不再作為 F3 的基準。

下一輪 observer 只做非功能性 provenance 修正，讓命令列明確傳入實際
bootstrap、Helper PI 與 guard metadata；不改讀取地址、packing 或控制邏輯。

## Raw / analysis index

```text
raw/build-master.log
raw/build-slave.log
raw/program-master-direct.log
raw/program-slave-direct.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-after60.log
raw/observer-smoke-120.log
raw/image-sha256.txt
raw/checksums.sha256
analysis/replay/comparison.csv
analysis/replay/verdict.json
```
