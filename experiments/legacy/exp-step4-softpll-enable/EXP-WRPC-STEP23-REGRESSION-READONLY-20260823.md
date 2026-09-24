# EXP-WRPC-STEP23-REGRESSION-READONLY-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP23-REGRESSION-READONLY-20260823`
- 日期：2026-08-23（台北時間）
- Branch：`exp/step4-softpll-enable`
- Git commit：`618ca6ad3681e302e9a67edf6c3d995e76f3bd41`
- 實驗名稱：Step 2 / Step 3 read-only regression barrier
- 目的：在進入下一個 Step 4 診斷前，重新確認 Endpoint、MiniNIC、PPSI/PTP 與 WR parent/signaling 的可靠證據。

## 重要 provenance 邊界

本次**沒有 Quartus compile，也沒有 program FPGA**。兩張 DE5a 上實際仍是前一輪 exact commit `8859959` clean build/program 的 SOF；本次只用 branch `618ca6a` 的唯讀 Tcl scripts 讀取現有硬體。因此本紀錄不是 `618ca6a` fresh SOF 的硬體驗證，不能把它寫成 fresh build/program 證據。

前一輪實際 bitstream provenance 參照：

| 項目 | Master | Slave |
|---|---|---|
| source SOF commit | `8859959bd39c7ddd1a0b50bb609b943c9a89479b` | `8859959bd39c7ddd1a0b50bb609b943c9a89479b` |
| SOF SHA256 | `55de8760fab87bf70c79acf436dcc909432aab4c5846b292441535d568ae7440` | `24c38c1eea5d7f0328d333fcdee6aba98ef25b3e163223a9f8dd34778d40ad95` |
| programmer checksum | `0x30A80048` | `0x30A78766` |
| Quartus | `17.0.0 Build 595` | `17.0.0 Build 595` |

這次所有腳本都回報 `Evaluation of Tcl script ... successful`、`0 errors, 0 warnings`。本輪沒有寫入 Wishbone control register，也沒有寫入 `DATA_SNAPSHOT`。

## 唯一操作變因

沒有新增硬體或 firmware 變因。只執行既有的 read-only scripts：

1. `read_step23_register_reliability.tcl 30 250 all`
2. `read_wr_handshake_focused.tcl 30 500`
3. `read_wb_runtime.tcl`
4. `read_step4_runtime_context.tcl 30 500`

Dashboard 對 critical enum/status register 使用 source-backed validation 與 retry；`TIMEOUT`、stale `A5A5xxxx`、不合法 enum 不會被轉成 0，也不會直接成為硬體 FAIL。counter 的 decrease/reset 只作為 retest 或 measurement inconsistency 證據。這次實際 30-sample reliability 中沒有 invalid mailbox sample；focused script 的 WR RX signal 有少量非單調/不一致樣本，已由 gate 保留為 `STATE_EVIDENCE=READ_INCONSISTENT`。

## Step 2 regression

### Master

- 30/30 valid samples
- MAC：`02:00:22:33:44:01`
- MODE：`2`
- PTP：`6 MASTER`
- PTP RX/TX、MiniNIC TX/RX counters 持續增加
- RXERR：30/30 為 0

### Slave

- 30/30 valid samples
- MAC：`02:00:22:33:44:02`
- MODE：`3`
- PTP：`9 SLAVE`
- PTP RX/TX、MiniNIC TX/RX counters 有 activity
- RXERR：30/30 為 0
- FOREIGN_META：30/30 為 `03000001`

### Step 2 結論

```text
STEP2_REGRESSION = PASS
```

PTP TX 在短窗口偶爾可能為零或發生 counter reset/decrease，但本次 30-sample focused evidence 仍有正向 PTP TX delta；依 regression 規則，不以單一短窗口零值宣稱 packet path 失敗。

## Step 3 regression

Slave focused 30-sample gate：

- valid samples：`30`
- Foreign Master：`1/0`
- parentIsWRnode：`1`
- parentCalibrated：`1`
- RX WR message：`0x1001 LOCK`
- TX WR message：`0x1000 SLAVE_PRESENT`
- LOCK_ENABLE：`4`
- PTP TX delta：`10`
- RXERR：`0`
- `POST_STEP3_LOCK_STAGE=TIMEOUT`
- `STATE_EVIDENCE=READ_INCONSISTENT`
- current state samples：30 次皆顯示 `WRS_IDLE`

`WRS_IDLE` 與 `LOCK / SLAVE_PRESENT / LOCK_ENABLE / WR_FAILURE_DEBUG` 同時出現，不能只靠單一 mailbox snapshot 宣稱 Step 3 FAIL。此輪依既有 source-backed acceptance policy，將「已到過 `WRS_S_LOCK` 且完成 locking enable」與「後續 state snapshot 不一致」分開記錄。

### Step 3 結論

```text
STEP3_REGRESSION = PASS
STATE_EVIDENCE = READ_INCONSISTENT
POST_STEP3_LOCK_STAGE = TIMEOUT
```

這個 PASS 只代表 Step 3 barrier 的 parent/signaling/lock-enable 證據成立，不代表 SoftPLL 已 lock，也不代表 `time_valid=1`。

## Dashboard 與 Step 4 觀察

Dashboard 完整輸出成功，沒有 Tcl exception。當次結果：

- Step 1：兩板 pass
- Step 2：兩板 pass
- Slave Step 3：pass
- Step 4：`error`，DMTD REF/FB、tag、TRR、IRQ、helper 的短窗口 delta 都是 0
- Step 5 / Step 6：尚未判定

`read_step4_runtime_context.tcl` 也顯示 Slave 的 SoftPLL shadow 與 counter 欄位會在不同 mailbox read 間出現 snapshot tear/不一致；本次不把這些 raw cross-register 差異直接當成 SoftPLL 根因。這只支持「Step 4 尚未通過，且需要下一個明確的 read-only observability 變因」，不支持修改 SoftPLL 演算法。

## Regression barrier 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

`STEP4_ALLOWED=YES` 的意思是 Step 2/3 barrier 已通過，可以繼續 Step 4 的單一變因研究；它不是 Step 4 PASS。這次沒有 hardware/firmware functional failure 的新證據，也沒有對 SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY 做任何修改。

## 原始證據

- `raw/regression_618ca6a_step23_20260823.log`
- `raw/regression_618ca6a_step3_focused_20260823.log`
- `raw/dashboard_618ca6a_20260823.log`
- `raw/step4_context_618ca6a_20260823.log`

## 下一步

只允許做 read-only source/runtime audit 或新增一個清楚隔離的 diagnostics 觀測變因。若下一步需要改 RTL 或產生新 SOF，必須先在 laptop commit/push，pain checkout 明確 commit，完成 clean build/program 後再另開新的實驗紀錄；不得把本次現有 bitstream 的結果當成新 commit 的 fresh hardware 證據。
