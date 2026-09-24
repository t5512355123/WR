# EXP-S5-F2-BOOTSTRAP-3860-KP2250-KI2-20260914

日期：2026-09-14／15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`30ce7adc6951b9be3d990081fc9de75ac3864d7f`  
Experiment commit：待本輪報告提交後填入

## Verdict

```text
STEP4B = PASS                 (second settled preflight)
F2_BOOTSTRAP_3860 = REJECTED
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
FULL_CHAIN_MAX_SECONDS = 0
NEXT_WORK_PACKAGE = empirical reverse bootstrap bracket, midpoint 3216
MERGE_APPROVED = NO
```

本輪沒有達成 Step5，也沒有 merge。

## 唯一變因

承接 F1-A2（Helper `kp=-2250, ki=-2`），本輪只修改 Slave generic：

```vhdl
- STEP5_BOOTSTRAP_STEPS => 3388,
+ STEP5_BOOTSTRAP_STEPS => 3860,
```

`STEP5_BOOTSTRAP_REVERSE => 1`、Helper PI、physical step code 64、cooldown
0、threshold 2000、lock samples 1000、phase guard 60 s、WR timeout 60 s
及其他 Master/Slave 控制內容均未修改。

## Laptop → GitHub → Pain

Laptop 端先核對 diff 並通過 Step5 replay regression tests 7/7，push 後
Pain 核對到完整 source commit：

```text
REMOTE_HEAD = 30ce7adc6951b9be3d990081fc9de75ac3864d7f
```

### Build

```text
MASTER_BUILD = PASS (exit 0)
SLAVE_BUILD  = PASS (exit 0)
TIMING_CLOSED = NO (existing implementation caveat)
```

本輪 Master／Slave SOF 與 MIF hash 已保存於 `raw/image-sha256.txt`。

### Program

標準 wrapper 在 sudo prompt 停住，因此沒有把未完成 wrapper 當成成功；
確認直接 Quartus programmer 可用後，以本輪剛建出的 SOF 完成實際燒錄：

```text
MASTER cable = DE5 [1-11.1], configuration succeeded, 0 errors, 0 warnings
SLAVE  cable = DE5 [1-11.2], configuration succeeded, 0 errors, 0 warnings
```

實際成功輸出分別保存在 `raw/program-master-direct.log` 與
`raw/program-slave-direct.log`。Master→Slave 45 s 間隔與 Slave 後的
120 s settled wait 也有時間戳記。

## Settled preflight

第一次 120 s preflight 的 Master gate 通過；Slave 尚在上游
`UNCALIBRATED`，故 `STEP4B_ALLOWED=NO`，沒有拿這次判定 F2。

追加 60 s 後第二次 preflight 的上游 gate 通過：

```text
Slave STEP1_REGRESSION = PASS
Slave STEP2_REGRESSION = PASS
Slave STEP3_REGRESSION = PASS
Slave STEP4B_ALLOWED   = YES
Slave STEP4B_RESULT    = PASS
parentCalibrated       = 1
```

但同一份 preflight 已顯示：

```text
HELPER_LOCKED = 0
HELPER_LOCK_COUNT = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## Short coherent observer

為了保存 F2 的 downstream 證據，執行一次 120-sample、100 ms、Slave-only
只讀 observer：

```text
quartus_stp -t scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl 120 100 "DE5 [1-11.2]"
```

Observer 完整結束且 measurement transport 有效，但結果是明確的低 rail
失效：

```text
SAMPLES = 120
COHERENT_MEASUREMENT_SNAPSHOTS = 120
POSITION_SNAPSHOTS = 120
HELPER_ERROR_MEAN = 150000
HELPER_ERROR_RMS = 150000
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0
LOW_RAIL_FRACTION = 1.0
HIGH_RAIL_FRACTION = 0.0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 3860
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

Observer 自己的判讀為：

```text
HELPER_DYNAMICS = STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
```

## 判讀與對下一步的修正

F2 的 3860 結果不是「PI 不夠快」：bootstrap 已完成 3860 次，但
Helper target/applied 停在 5、preclamp error 約 1.07e8，normal tracker
沒有任何 request。這是 bootstrap operating point／方向的失配，必須停止
長測與 PI 掃描。

這份實機結果也修正了 Fable 對加法方向的推論：既有資料中 bootstrap 3072
（同樣 reverse 語意）曾落在低 rail，而 3360–3388 可進入高側工作區；
3860 再次低 rail，表示 3388 與 3860 之間存在方向／工作點轉折，不能再
直接把 `+472` 當成置中公式。這不是用 observer 反推 Step5 PASS，而是
用已驗證的兩側 raw 建立下一個單變因 bracket。

## 下一步

回到流程第一步，只把 Slave bootstrap 改為 bracket 中點：

```vhdl
-- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd
- STEP5_BOOTSTRAP_STEPS => 3860,
+ STEP5_BOOTSTRAP_STEPS => 3216,
```

3216 是已觀測的 3072（低 rail）與 3360（高側工作區）之間的第一個
中點候選；PI、reverse、guard、timeout 與所有其他參數保持不變。下一輪
必須重做完整 build/program、settled preflight、short smoke；只有若
Helper output 落在有效區且 lock 穩定，才延長觀測。若 3216 仍落 rail，
再以二分方式取下一個 bootstrap，不再使用未驗證的單向公式。

## Raw index

```text
raw/build-master.log
raw/build-slave.log
raw/program-master.log
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

