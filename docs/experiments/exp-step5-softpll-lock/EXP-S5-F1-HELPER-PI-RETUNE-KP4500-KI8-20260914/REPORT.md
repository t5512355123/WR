# EXP-S5-F1-HELPER-PI-RETUNE-KP4500-KI8-20260914

日期：2026-09-14（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`f93c61a11d13687a800ea182e1d335576c51d42a`  
Experiment commit：待本輪報告提交後填入

## Verdict

```text
STEP4B = PASS                 (second settled preflight)
F1_CANDIDATE_A = REJECTED     (short smoke)
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
FULL_CHAIN_MAX_SECONDS = 0
NEXT_WORK_PACKAGE = F1-A2 (kp=-2250, ki=-2), one functional variable
MERGE_APPROVED = NO
```

本輪沒有達成 Step5，因此不能宣稱 Step5 PASS，也沒有 merge。

## 目的與唯一變因

依 `ai_advice/Step5/04_Fable.md` 的 F1 工作包，唯一修改是
`vendor/wrpc-sw/softpll/spll_helper.c` 的 `helper_very_init()`、
`CONFIG_WR_NODE` 分支：

```c
- s->pi.kp = -150;
- s->pi.ki = -1;
+ s->pi.kp = -4500;
+ s->pi.ki = -8;
```

保留 bootstrap 3388、physical step code 64、cooldown 0、Helper threshold
2000、Helper lock samples 1000、Main PI、Slave phase guard 60 s，以及 WR
timeout 60 s。沒有修改 RTL、observer、Main PI、reset、PHY/PTP 或 timeout。

## F0 離線模型檢查

使用 Fable 附錄 C 的固定 100 ms resampling、clipped Helper error FFT，
先檢查既有基線 raw：

| Raw | valid samples | span | FFT peak | zero-cross period | Helper output mean | error RMS |
|---|---:|---:|---:|---:|---:|---:|
| bootstrap 3388 (2026-09-12) | 3374 | 424.2 s | 0.672 Hz | 1.45 s | 63692.9 | 596.6 |
| bootstrap 3372 (2026-09-11) | 3206 | 537.4 s | 0.627 Hz | 1.59 s | 63080.6 | 1341.1 |

兩份 raw 都落在 Fable 預期的 0.4–1.0 Hz 單峰範圍，因此執行 F1。

## Laptop → GitHub → Pain

Laptop 先完成 7/7 hardware-independent replay regression tests，
再以 source commit `f93c61a` push 到 GitHub。Pain 以該完整 commit
checkout/pull，並核對：

```text
REMOTE_HEAD = f93c61a11d13687a800ea182e1d335576c51d42a
```

### Full build

```text
MASTER_BUILD = PASS (exit 0)
SLAVE_BUILD  = PASS (exit 0)
TIMING_CLOSED = NO (existing implementation caveat)
```

本輪產物 hash 已保存於 `raw/image-sha256.txt`：

```text
MASTER_SOF = 82c9033b6a31423f74c3e60ed5fdb8929f7f083d2e6b6f8d87955040e1a4e638
SLAVE_SOF  = bad65cad1d60e51518aebfb2c9a5774fc1891f4f1f00e2e5ac5dd6d33bba0c0b
MASTER_MIF = 54e0bc6677d20bb5487223ea283405960e4aaf0be2723a43ca665377bb2e1f81
SLAVE_MIF  = 824fd9464f7c2fec669b07cfbcd6a018a9b5f11b5fc38c712b628dc769a94224
```

### Programming

```text
MASTER cable = DE5 [1-11.1], configuration succeeded, 0 errors, 0 warnings
SLAVE  cable = DE5 [1-11.2], configuration succeeded, 0 errors, 0 warnings
```

流程遵守 Master programming → 45 s wait → Slave programming → 120 s
settled wait。相關原始 log 與等待時間檔案都在 `raw/`。

## Settled preflight

第一次 120 s settled preflight 中，Master 的 Step1–4A 通過，但 Slave
尚處 `WDIAGS_PTP=UNCALIBRATED`，因此 `STEP2_REGRESSION=INVALID`、
`STEP4B_ALLOWED=NO`；這份 capture 沒有拿來判定 F1。

在不改變映像的情況下再等待 60 s，第二次只讀 preflight 得到：

```text
Slave STEP1_REGRESSION = PASS
Slave STEP2_REGRESSION = PASS
Slave STEP3_REGRESSION = PASS
Slave STEP4B_ALLOWED   = YES
Slave STEP4B_RESULT    = PASS
parentCalibrated       = 1
```

此時 Helper 已是 locked、Main frequency 已 locked，但 Main phase 尚未
locked；因此進入 coherent observer 是有效的，且沒有把第一次 transient
invalid 當成 Step5 結果。

## F1 short smoke

只讀 observer 命令：

```text
quartus_stp -t scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl 120 100 "DE5 [1-11.2]"
```

觀測結果（完整 raw：`raw/observer-smoke-120.log`；離線 replay：
`analysis/replay/`）：

| Metric | Result | Interpretation |
|---|---:|---|
| samples | 120 | capture completed |
| coherent measurement | 120/120 | measurement transport valid |
| frame valid | 119/120 | one frame invalid, not treated as zero |
| position valid | 104/120 | accounting checks still pass |
| Helper error RMS | 1307.496 | far above Fable target <150 |
| Helper error max abs | 5609 | exceeds 2000 lock threshold |
| abs(error) <= 200 | 31.67% | not a small quantization limit cycle |
| FFT peak (100 ms resample) | 0.877 Hz | no stable improvement over baseline |
| Helper output mean / range | 58809 / 49739–65530 | large actuator excursion, reaches upper rail vicinity |
| Helper lock seen / final | 90 samples / 0 | lock not sustained |
| lock rise / fall events | 17 / 8 | repeated lock churn |
| error-band exit events | 19 | incompatible with stable Helper |
| Main final freq / phase / PSTAT | 1 / 0 / 0 | phase gate never completed |
| full-chain maximum | 0 s | no Step5 closure interval |
| generation / reset deltas | 0 / 0 | no reset caused the result |

Observer 自己的 summary 亦標記：

```text
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE
STEP5_CHAIN_RESULT = NOT_COMPLETE
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
```

## 判讀

F1 的新 firmware 確實已編譯並燒錄；觀測資料也證明 downstream DMTD、
Helper update、normal request/completion 仍在前進，且沒有 reset 或
generation 變化。因此本輪不是 transport failure，也不是「F1 沒進 image」
就可以直接結案。

但 `kp=-4500, ki=-8` 沒有把 Helper error 收斂到目標，反而在約 0.877 Hz
的較大振幅運動中反覆離開 lock band；Main phase/PSTAT 全程未成立。依
Fable 的驗收要求，Candidate A 被 reject，Step5 仍是 NOT_COMPLETE。

## 下一步

回到流程第一步。只改同一個檔案的 Candidate A/2：

```c
s->pi.kp = -2250;
s->pi.ki = -2;
```

其餘參數、full build/program 順序、120 s settled preflight、短 smoke 與
長時間觀測規則全部保持不變。若 A/2 仍無法收斂，再依 Fable 的結果分流
處理 bootstrap 置中（F2）；本輪不預先合併 F2。

## Raw index

```text
raw/build-master.log
raw/build-slave.log
raw/program-master.log
raw/program-slave.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-after60.log
raw/observer-smoke-120.log
raw/image-sha256.txt
raw/checksums.sha256
analysis/replay/comparison.csv
analysis/replay/verdict.json
```

