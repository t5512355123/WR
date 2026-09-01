# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V3-FROZEN-BANK-DOUBLE-READ-STABILITY-AUDIT-100SAMPLES-20260901

## 結論

本輪依分支5-WR 的指定條件，對目前 live state 執行唯讀 gate 與
100-sample frozen-bank A/B double-read stability audit。結果：

```text
READ_ONLY_PRECONDITION_GATE = PASS
FROZEN_BANK_READ_STABILITY = FAIL
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
MERGE_APPROVED = NO
```

因此本輪不能判定 Step5 pass，也不能 merge 到 `main`。

## 固定條件

```text
branch = exp/step5-softpll-lock
baseline HEAD = 7717231
board = DE5 [1-11.2]
QSFPA data path = lane 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
samples = 100
gap_ms = 100
```

本輪沒有重新編譯、沒有重新燒錄，沒有修改 RTL、firmware、SoftPLL、PI、
PHY、lane 或 PTP role。

## 唯讀 gate

執行 double-read 前先確認目前 live state：

```text
Master Step1/Step2 = PASS
Master event chain = PASS
Slave Step1 = PASS
Slave Step2 = PASS
Slave PTP role = SLAVE
Slave PTP RX activity = increasing
Slave RXERR delta = 0
Slave Step3 = PASS
parentIsWRnode = 1
parentCalibrated = 1
LOCK_ENABLE_COUNT = 4
Slave Step4B_ALLOWED = YES
Slave STEP4B_RESULT = PASS
Slave STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
SPLL_INIT stable = 1
event counters = increasing
reset deltas = 0
```

所以觀測前置條件成立；這不是因為 Step1–4B 失敗而造成的 abort。

## 100 筆 frozen-bank double-read 結果

```text
SAMPLES = 100
VALID_FRAMES = 29
INVALID_FRAMES = 71
DOUBLE_READ_TRANSACTIONS_VALID = 29
DOUBLE_READ_TRANSACTIONS_INVALID = 71
PASS_A_TRANSPORT_VALID = 87
PASS_B_TRANSPORT_VALID = 83
BANK_WORD_FOR_WORD_MATCH_COUNT = 29
BANK_WORD_FOR_WORD_MISMATCH_COUNT = 48
FROZEN_BANK_READ_STABILITY = FAIL
DOUBLE_READ_INTERPRETATION = JTAG_WB_OR_BANK_OWNERSHIP_INSTABILITY_CONFIRMED
```

有效的 A/B 讀取仍出現跨欄位差異，例如 `PI_KP`、`PI_KI`、`PI_TAG_RAW`、
`PI_RAW_ERROR`、`PI_P_ADDER`、integrator、clamp 與 lock-samples。第一個
差異欄位並非固定在單一 PI 欄位，故目前證據支持讀取/ownership instability，
不能把這些資料當作穩定 frozen-bank snapshot。

## V3 transport / reject attribution

```text
SNAPSHOT_REQ_COUNT = 100
SNAPSHOT_BANK_COMMIT_COUNT = 93
SNAPSHOT_ACK_COUNT = 93
SNAPSHOT_OVERWRITE_COUNT = 0
ACK_TIMEOUT = 7
ACK_MISMATCH = 5
EPOCH_GENERATION_MISMATCH = 9
EPOCH_CHANGED_DURING_READ = 9
ATOMIC_SNAPSHOT_TRANSPORT_V3 = FAIL
REJECT_ATTRIBUTION_COVERAGE = 71/71 (100.0%)
UNCLASSIFIED_INVALID_FRAMES = 0
```

有效 frame 的 PI accounting 與 output mismatch 計數為 0，但這不構成 Step5
lock 證據。整段觀測期間仍為：

```text
HELPER_LOCKED_FINAL = 0
HELPER_LOCK_COUNT_FINAL = 0
PSTAT_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
RESET_STABLE = PASS
LOW_RAIL_SATURATION = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
```

這表示 reset/Step4B event path 穩定，但 helper lock 尚未成立，且 A/B 不穩定
本身已觸發分支5定義的停止條件。因此不能把 PI math 或 rail observation
誤升級為 Step5 pass。

## Raw evidence

Pain server raw log：

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V3-FROZEN-BANK-DOUBLE-READ-STABILITY-AUDIT-100SAMPLES-20260901-rerun.log
```

工具最後回報 Tcl / SignalTap evaluation successful；上述 FAIL 是被測系統
與 snapshot stability 的結果，不是工具執行錯誤。

## 後續決策

依分支5的 acceptance rule，本輪應停止，不進行 1800 秒 lock run，不 merge，
並把 `JTAG/WB/bank ownership instability` 作為下一輪診斷的 blocker。
