# EXP-WRPC-STEP5-MAIN-PI-PLUS150-PLUS1-FREQ-LOCK-PHASE-WAIT-20260909

## 判定

本輪依指定流程完成 laptop push、Pain pull、firmware/MIF 生成、Master/Slave
Quartus full compile、Slave→Master 燒錄、upstream recovery 與 Main observer。
`KP=+150, KI=+1` 讓 Main 進入 frequency detector lock 狀態，並消除了上一輪
的 PI rail；但 phase lock 與 PSTAT lock 尚未成立，因此 Step5 尚未完成。

```text
SOURCE_HEAD = f73d3a9
MASTER_SOF_SHA256 = 3434c4718a5ac01a83a3a2d335be8b2072473a6e1c48652cc516dd124e4b46c6
SLAVE_SOF_SHA256  = 88bfd79f58417448064fe53a48f1d6fd335e3882bc3928d0c10f28a16602a011
TIMING_CLOSED = NO
PROGRAM_ORDER_VALID_WINDOW = SLAVE_THEN_MASTER
STEP1_TO_STEP3 = PASS (retry-1)
STEP4B = PASS (retry-1)
MAIN_FREQ_DETECTOR = REACHED
MAIN_PHASE_LOCK = NOT_REACHED
PSTAT_LOCK = NOT_REACHED
STEP5 = NOT_COMPLETE
MERGE_APPROVED = NO
```

## 本輪變因與設定

唯一 firmware 變更是 WR node Main PI operating point：

```text
Main KP = +150
Main KI = +1
Main SHIFT = 12
Main BIAS = 32768
Main frequency threshold = 50
Main frequency lock_samples = 50
Helper threshold = 2000
Helper lock_samples = 1000
Slave bootstrap = 3360, reverse = 1
HPLL code per physical step = 64
DPLL code per physical step = 16
HPLL cooldown = 0
```

Main polarity、DCO page/mask sequence、absolute target/applied tracker、static-FSM
completion gate 與 Helper 設定均保留。

## Build / program / upstream

Master 與 Slave firmware 及 Quartus full compile 均成功；兩張 SOF 已成功配置。
第一次 preflight 在燒錄後仍看到 Slave `UNCALIBRATED`，故不納入 Step5 判定；
等待後的 retry-1 才是有效窗口：

```text
Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
Master PTP = MASTER, RX/TX activity > 0
Slave  PTP = SLAVE, RX/TX activity > 0
Slave  WR_RX_SIGNAL = LOCK
LOCK_ENABLE_COUNT = 4
SPLL_INIT_COUNT = 1
STEP1 = PASS
STEP2 = PASS
STEP3 = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
```

有效窗口中 DMTD、TAG、TRR、IRQ 與 Helper update 均增加；四個 reset/drop
delta 均為 0。

## Main frequency observation

觀測器執行 600 個請求；因 mailbox/trace 去重與 transport 時間，實際窗口為
`2658.211` 秒，只有 42 筆新的 Main trace，不能把請求數當成 600 筆獨立
物理樣本：

```text
SAMPLES = 600
TRACE_VALID = 435
TRACE_UNIQUE = 42
TRACE_DEDUP_SKIPPED = 393
FRAME_VALID = 569
INVALID = 165
MEASUREMENT_FAILS = 0
RESET_STABLE = PASS
```

Main DMTD frequency error（內部誤差單位，不是外部頻率計 Hz）為：

```text
FREQ_ERROR_MEAN = 83.1428571429
FREQ_ERROR_RMS = 103.3516688078
FREQ_ERROR_MIN = 43
FREQ_ERROR_MAX = 417
FREQ_ERROR_FINAL = 58
FRACTION_ABS_FREQ_ERROR_LE_50 = 0.0238095238095
```

PI 行為已由兩端 rail 轉為中間 operating point：

```text
PI_LOW_RAIL_FRACTION = 0.0
PI_HIGH_RAIL_FRACTION = 0.0
PI_NO_RAIL_FRACTION = 1.0
MAIN_PI_OUTPUT_FINAL = 12820
MAIN_PI_CLAMP_SIDE_FINAL = 0
```

Main frequency detector 的狀態曾達到 50/50：

```text
MAIN_FREQ_LOCK_COUNT_MAX_SEEN = 50
MAIN_FREQ_LOCK_COUNT_FINAL = 50
MAIN_FREQ_LOCKED_EVER = 1
MAIN_FREQ_LOCKED_FINAL = 1
MAIN_ENABLED_FINAL = 1
```

但由於 `delock_samples=20000` 的滯後，`MAIN_FREQ_LOCKED=1` 不能單獨代表
整段 raw error 都在 ±50；本輪只有 2.38% 的新 trace 落在該區間，故此欄位只
記為 detector reached，不宣稱完整 frequency quality 已驗收。

Helper 狀態維持有效：

```text
HELPER_LOCKED_EVER = 1
HELPER_LOCKED_FINAL = 1
HELPER_LOCK_COUNT_MAX = 1000
HELPER_LOCK_COUNT_FINAL = 1000
SPLL_DELOCK_MAX = 0
```

Phase 與完整鏈仍未通過：

```text
MAIN_PHASE_LOCKED_EVER = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_EVER = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_EVER = 0
PSTAT_LOCKED_FINAL = 0
STEP5_COMPLETE = NO
```

## 觀測器 provenance caveat

本輪 per-sample telemetry 明確回報 `MAIN_PI_KP=150`、`MAIN_PI_KI=1`；但
observer 最後的 CONFIG 行仍沿用上一輪的 experiment label 與 `main_kp=1100,
main_ki=30`。這不改變已燒錄映像的 firmware，也不影響 per-sample runtime
欄位，但下一輪正式觀測前必須先修正該 metadata，避免把腳本設定誤當成硬體
實際設定。

## 下一步

保留 `+150/+1`，不要再改增益；目前最有價值的下一步是修正並 push observer
metadata，然後用正確欄位映射執行 coherent closed-loop trajectory audit，
確認 phase detector 是否真的收到 Main frequency lock 後的 phase updates。
只有在同一有效窗口看到 Helper、Main frequency、Main phase、Main locked、
PSTAT 全部為 1，並有完整穩定時間、coherent/accounting/reset 證據，才可宣稱
Step5 PASS。

若 phase 仍一直為 0，下一個程式變因應放在 phase branch 的 input/actuator
路徑診斷，不應再修改 frequency PI 或放寬 lock threshold。

## Raw evidence

本資料夾 `raw/` 保存 build、program、兩次 preflight、Main observer 與
runtime snapshot；遠端 archive 位於 laptop `artifacts/`：

```text
EXP-WRPC-STEP5-MAIN-PI-PLUS150-PLUS1-FREQ-LOCK-PHASE-WAIT-20260909-raw.tgz
SHA256 = cbba5ec57da44e5c5bbf3ab383e1b183cfb79206564c440c0f5fb0869541db01
```
