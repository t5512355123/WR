# EXP-S5-F1A2-HELPER-PI-KP2250-KI2-20260914

日期：2026-09-14（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`e532eddbbc6fae67c9575614819ee07356762ba6`  
Experiment commit：待本輪報告提交後填入

## Verdict

```text
STEP4B = PASS                 (second settled preflight)
F1-A2 = REJECTED              (long coherent capture)
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
FULL_CHAIN_MAX_SECONDS = 0
NEXT_WORK_PACKAGE = F2 bootstrap centering, Slave 3388 -> 3860
MERGE_APPROVED = NO
```

本輪沒有達成 Step5，也沒有 merge。

## 唯一變因

依 Fable 的 F1 fallback，唯一修改為 `vendor/wrpc-sw/softpll/spll_helper.c`
的 `helper_very_init()`、`CONFIG_WR_NODE` 分支：

```c
- s->pi.kp = -4500;
- s->pi.ki = -8;
+ s->pi.kp = -2250;
+ s->pi.ki = -2;
```

其他控制內容保持不變：bootstrap 3388、physical step code 64、cooldown
0、Helper threshold 2000、lock samples 1000、Main PI、Slave phase guard
60 s，以及 WR timeout 60 s。沒有修改 RTL、observer、Main PI、reset、
PHY/PTP 或 timeout。

## Laptop → GitHub → Pain

Laptop 的 Step5 replay regression tests 為 7/7 OK，之後 push source
commit；Pain 核對到：

```text
REMOTE_HEAD = e532eddbbc6fae67c9575614819ee07356762ba6
```

### Build and program

```text
MASTER_BUILD = PASS (exit 0)
SLAVE_BUILD  = PASS (exit 0)
TIMING_CLOSED = NO (existing implementation caveat)
MASTER_PROGRAM = PASS, DE5 [1-11.1], 0 errors, 0 warnings
SLAVE_PROGRAM  = PASS, DE5 [1-11.2], 0 errors, 0 warnings
```

本輪 A/2 產物 hash 保存在 `raw/image-sha256.txt`。Master programming
後等待 45 s，再 programming Slave，之後等待 120 s settled；所有原始
建置、燒錄與等待記錄都在 `raw/`。

## Settled preflight

第一次 120 s preflight 的 Slave 仍在短暫 `UNCALIBRATED`，所以該次
`STEP2_REGRESSION=INVALID`、`STEP4B_ALLOWED=NO`，沒有拿它判斷 A/2。
追加 60 s 後第二次只讀 preflight 通過：

```text
Slave STEP1_REGRESSION = PASS
Slave STEP2_REGRESSION = PASS
Slave STEP3_REGRESSION = PASS
Slave STEP4B_ALLOWED   = YES
Slave STEP4B_RESULT    = PASS
parentCalibrated       = 1
```

該次 preflight 顯示 Helper 已 locked、Main frequency 已 locked，但
Main phase/PSTAT 尚未 locked，符合進入 Step5 observer 的 gate。

## Short smoke

```text
quartus_stp -t scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl 120 100 "DE5 [1-11.2]"
```

短測的 observer summary：

```text
SAMPLES = 120
COHERENT_MEASUREMENT_SNAPSHOTS = 120
POSITION_SNAPSHOTS = 110
HELPER_ERROR_RMS = 900.537
HELPER_ERROR_MAX_ABS = 2455
HELPER_LOCKED_SEEN = 102/120
HELPER_LOCKED_FINAL = 1
ERROR_BAND_EXIT_EVENTS = 14
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

短測比上一輪 Candidate A 有改善，故依停止規則延長觀測，而不是直接
以 smoke 判定成功。

## Long coherent capture

```text
quartus_stp -t scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl 6000 100 "DE5 [1-11.2]"
```

Observer 完整完成 `SAMPLES=6000`；原始 summary 與 Laptop replay
(`analysis/replay/`) 的主要結果如下：

| Metric | Result | Interpretation |
|---|---:|---|
| coherent measurement | 6000/6000 | measurement data valid |
| frame valid | 5903/6000 | invalid frames were not converted to zero |
| position valid | 5184/6000 | accounting invariants pass |
| measured span | 849.144 s | complete long capture |
| Helper error mean | -5.253 | mean is near zero but not sufficient |
| Helper error RMS | 923.016 | far above Fable target <150 |
| Helper error max abs | 5483 | repeated excursions beyond threshold |
| abs(error) <= 200 | 36.1% | not a quantization-limited loop |
| FFT peak (100 ms resample) | 0.671 Hz | same hunt band as baseline |
| Helper output mean / range | 60574 / 56993–64712 | still off-center and moving |
| Helper locked seen / final | 5312 / 6000; final 1 | not continuously locked |
| lock rise / fall events | 439 / 191 | repeated lock churn |
| error-band exit events | 758 | incompatible with closure |
| Main final freq / phase / PSTAT | 1 / 0 / 0 | phase gate never completed |
| full-chain maximum | 0 s | no valid Step5 interval |
| generation change | 0 | no reset/reinit evidence in capture |

Observer summary also reported:

```text
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
STEP5_CHAIN_RESULT = NOT_COMPLETE
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
```

## 判讀

A/2 確實改善了 Candidate A 的短期大幅度 excursion，但長測仍保留
約 0.67 Hz 的 hunt，且 error RMS 約 923、band exit 758 次。Helper
偶爾 locked 不能等同於穩定 locked；Main phase/PSTAT 全程沒有形成
Step5 full chain。由於 measurement、position accounting、reset stability
都通過，這不是 JTAG reader 或 reset failure；結論是 A/2 仍不足以達成
Step5。

## 下一步：F2 bootstrap centering

回到流程第一步。只修改 Slave generic 的 bootstrap 步數：

```vhdl
-- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd
- STEP5_BOOTSTRAP_STEPS => 3388,
+ STEP5_BOOTSTRAP_STEPS => 3860,
```

`STEP5_BOOTSTRAP_REVERSE`、PI、guard、timeout 與其他 generic 不變。F2
預期 Helper output 由目前約 60,574–63,000 的移動工作點拉到約
`32768 ± 3000`，並顯著降低高側 rail 風險；F2 仍需完整 build/program、
settled preflight、short smoke 與 long coherent capture 驗證，不能只靠
公式宣布成功。

## Raw index

```text
raw/build-master.log
raw/build-slave.log
raw/program-master.log
raw/program-slave.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-after60.log
raw/observer-smoke-120.log
raw/observer-long-6000.log
raw/image-sha256.txt
raw/checksums.sha256
analysis/replay/comparison.csv
analysis/replay/verdict.json
```

