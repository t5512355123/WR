# EXP-WRPC-STEP5-LANE2-JTAG-WB-READ-PATH-STABILITY-AUDIT-500X-20260901

## 結論

本輪依分支5建議，在 Slave `DE5 [1-11.2]` 建立單一 persistent
in-system source-probe session，執行 500 輪 read-only JTAG/Wishbone
mailbox stability audit。每輪共 20 次 read，總計 10,000 次 WB read。

結果確認 generic JTAG/WB mailbox read path 不穩定；不是單一 dashboard
before/after sampling 造成的孤立誤判。正式判定：

```text
ITERATIONS = 500
TOTAL_WB_READS = 10000

GENERIC_JTAG_WB_READ_PATH_STABILITY = FAIL
JTAG_WB_MAILBOX_INSTABILITY = CONFIRMED

V4_SMOKE = BLOCKED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪沒有 rebuild、沒有 reprogram、沒有送 V4 snapshot request，也沒有
修改 RTL、firmware、PI、WDIAGS ownership、PHY、PTP 或 SoftPLL。

## 固定條件

```text
Board = DE5 [1-11.2]
QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

## Audit summary

```text
ITERATIONS = 500
TOTAL_WB_READS = 10000

STATIC_SIGNATURE_MISMATCH = 16
BOARD_ID_MISMATCH = 18

STALE_A5A5_COUNT = 0
TIMEOUT_COUNT = 0
INVALID_COUNT = 0

ADDRESS_CROSS_CONTAMINATION_COUNT = 37

DMTD_REF_DECREASE_COUNT = 3
DMTD_FB_DECREASE_COUNT = 0

DMTD_REF_TRIPLE_VALID = 497
DMTD_FB_TRIPLE_VALID = 500

STATIC_SEQUENCE_VALID = 468
ADDRESS_SEQUENCE_VALID = 468
```

第一筆錯誤：

```text
iteration = 33
requested = STATIC_A (0x00100124)
previous = STATIC_B (0x00100128)
expected = 0x02000200
observed = 0x22334402
classification = PREVIOUS_RESPONSE_REPLAY
```

也就是要求 fixed signature register 時，收到上一個 board-ID address 的
回應。這不是動態 DMTD counter 正常增加造成的差異，而是 address-switching
後的 response replay / mailbox contamination。其餘 36 次 cross-contamination
與 16 次 signature mismatch、18 次 board-ID mismatch 共同支持相同分類。

## 測試內容

每輪交錯讀取 immutable registers：

```text
STATIC_A = 0x00100124, expected 0x02000200
STATIC_B = 0x00100128, expected 0x22334402
A1 -> B1 -> A2 -> B2 -> A3 -> B3
```

並對 DMTD counters 做同地址快速三次讀取：

```text
DMTD_REF = 0x00100298
DMTD_FB  = 0x0010029C
R1 -> R2 -> R3
F1 -> F2 -> F3
```

另做 address switching：

```text
STATIC_A -> DMTD_REF -> STATIC_B -> DMTD_FB
         -> STATIC_A -> DMTD_REF -> STATIC_B -> DMTD_FB
```

## 判定

分支5定義的 Case A 條件已成立：

```text
STATIC_SIGNATURE_MISMATCH > 0
BOARD_ID_MISMATCH > 0
ADDRESS_CROSS_CONTAMINATION_COUNT > 0
```

因此：

```text
GENERIC_JTAG_WB_READ_PATH_STABILITY = FAIL
JTAG_WB_MAILBOX_INSTABILITY = CONFIRMED
```

另有：

```text
DMTD_REF_DECREASE_COUNT = 3
```

這表示 DMTD_REF counter 也出現非單調讀值，但在 generic static register
已經明確發生跨地址回放的前提下，本輪不把 DMTD counter publication/CDC
單獨定為唯一 root cause；必須先處理或隔離 generic mailbox read path。

## Step5 gate 狀態

由於 generic JTAG/WB read path 已被確認不可信：

```text
V4_EXCLUSIVE_PI_BANK_DOUBLE_READ = NOT_RUN
V4_SMOKE = BLOCKED
LONG_STEP5_OBSERVATION = NOT_RUN
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

目前不能用不可靠的 mailbox evidence 宣稱 V4 ownership 修正 pass，也不能
用這些讀取錯誤宣稱 Step5 dynamics fail。下一步只應修正/隔離 read-path
protocol，再重新取得可信的 Step4B preflight，之後才可重跑 V4 100-sample
double-read。

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-JTAG-WB-READ-PATH-STABILITY-AUDIT-500X-20260901.log
```
