# EXP-WRPC-STEP23-REGRESSION-READONLY-0548ECE-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP23-REGRESSION-READONLY-0548ECE-20260823`
- 日期：2026-08-23（台北時間）
- Branch：`exp/step4-softpll-enable`
- Git commit：`0548ece1499d06b793b7fc58fd255250af1a1cf7`
- 實驗名稱：Step 2 / Step 3 regression barrier 與 JTAG read validation 回歸

## 這次想驗證什麼

在允許繼續 Step 4 前，重新確認：

1. Endpoint、MiniNIC、PPSI/PTP packet path 仍可重複觀測。
2. Slave 的 Foreign Master、WR signaling 與 `LOCK_ENABLE` 仍成立。
3. dashboard 遇到 stale/invalid mailbox read 時會 retry/reject，不會把無效資料當成 hardware failure。

## 唯一修改的變因

本輪唯一 source 修改是 `scripts/jtag/read_wb_runtime.tcl`：

- 新增 `WDIAGS_PSTAT (0x00100A0C)` 的 source-backed bit validation。
- 新增 `WR_RX_SIGNAL (0x00100A64)` 與 `WR_TX_SIGNAL (0x00100A68)` 的合法 message ID validation，接受 `0x1000..0x1005`。
- dashboard 對這三個欄位改用既有 `wb_read_validated` retry path。

沒有修改：

- Master/Slave role switching
- PTP、WR signaling、SoftPLL 演算法
- DDMTD polarity、PI gain、lock threshold
- DCO、SI5340、PHY functional RTL
- Wishbone register address 或 FPGA/firmware 行為

這次沒有 Quartus compile，也沒有 program FPGA；本輪屬於 read-only diagnostics regression。

## 硬體與 provenance 邊界

pain checkout：`0548ece1499d06b793b7fc58fd255250af1a1cf7`。

實際板上 bitstream 沿用前一輪 `8859959` fresh build/program 的 SOF，不能把本輪 Tcl commit 寫成 fresh SOF provenance：

| 項目 | Master | Slave |
|---|---|---|
| SOF source commit | `8859959bd39c7ddd1a0b50bb609b943c9a89479b` | `8859959bd39c7ddd1a0b50bb609b943c9a89479b` |
| SOF SHA256 | `55de8760fab87bf70c79acf436dcc909432aab4c5846b292441535d568ae7440` | `24c38c1eea5d7f0328d333fcdee6aba98ef25b3e163223a9f8dd34778d40ad95` |
| Programmer checksum | `0x30A80048` | `0x30A78766` |
| Quartus | `17.0.0 Build 595` | `17.0.0 Build 595` |

## 燒錄與執行結果

本輪沒有燒錄，因此不存在新的 programmer result；沒有執行 `quartus_sh` 或 `quartus_pgm`。三支 JTAG script 均回報 `Evaluation of Tcl script ... successful`、`0 errors, 0 warnings`。

## Step 1：PHY / Link

兩片 dashboard 與 focused reads 都顯示 PHY ready、RX/TX ready、timing link/link OK、RX lock-to-data 正常，encoding error 為 0。

```text
STEP1_REGRESSION = PASS
```

## Step 2：Endpoint / MiniNIC / PTP

`read_step23_register_reliability.tcl 30 250 all`：

- Master：30/30 valid；MAC=`02:00:22:33:44:01`、MODE=`2`、PTP=`6`；MiniNIC/PTP counters 有活動；RXERR=0。
- Slave：30/30 valid；MAC=`02:00:22:33:44:02`、MODE=`3`、PTP=`9`；MiniNIC/PTP counters 有活動；RXERR=0；FOREIGN_META=`03000001`。

`read_wr_handshake_focused.tcl 30 500` 也得到兩板 Step 2 PASS。Slave 30/30 valid，PTP RX、MiniNIC TX/RX 持續增加；短窗口 PTP TX 偶爾為 0 或 reset/decrease，不以單一 counter 判定 packet path 失敗。

```text
STEP2_REGRESSION = PASS
```

## Step 3：WR Parent / Signaling

Slave focused 30 samples：

- valid samples：`30`
- Foreign Master：`1/0`
- parentIsWRnode：`1`
- parentCalibrated：`1`
- RX WR message：`0x1001 LOCK`
- TX WR message：`0x1000 SLAVE_PRESENT`
- LOCK_ENABLE：`4`
- PTP TX delta：`12`
- signal_good：`26`，signal_bad：`4`
- `POST_STEP3_LOCK_STAGE=TIMEOUT`
- `STATE_EVIDENCE=READ_INCONSISTENT`
- current state：30 個 accepted samples 均讀到 `WRS_IDLE`

`WRS_IDLE` 與 `LOCK`、`SLAVE_PRESENT`、`LOCK_ENABLE=4` 及 failure shadow 同時存在，不能只用這個 state shadow 判定 Step 3 hardware fail。focused script 的 gate 依 source-backed parent/signaling/lock-enable evidence 判定 PASS，並保留 state inconsistency 供後續研究。

```text
STEP3_REGRESSION = PASS
```

## Step 4：SoftPLL startup observation

本輪只讀取，沒有修改 SoftPLL。dashboard 在 Slave 看到：

- `LOCK_ENABLE=4`
- `SPLL_MODE=SLAVE`
- `RCER=1`
- DMTD REF/FB、tag valid、TRR write、IRQ、helper update 的短窗口 delta 為 0
- `OCER` 有一次 `TIMEOUT`，依規則列為 measurement warning，不轉成數值 0

`read_step4_startup_focused.tcl 10 500 events --raw`：

- Master：sampled activity 有，但 `accept_ref=0`、`accept_fb=0`，下游 event/tag/TRR/IRQ/helper 全為 0，結果=`DMTD_DEGLITCH_ACCEPT`。
- Slave：`sampled_fb=1595`，`accept_ref=0`、`accept_fb=0`，下游 event/tag/TRR/IRQ/helper 全為 0；REF sampled counter 出現 decrease/reset，結果=`DMTD_DEGLITCH_MEASUREMENT_AMBIGUOUS`。
- 同一 script 回報 `0 errors, 0 warnings`。

因此本輪沒有新增 Step 4 PASS 證據：

```text
STEP4_ALLOWED = YES
STEP4_RESULT  = NOT_PASS
```

`STEP4_ALLOWED=YES` 只表示 Step 2/3 barrier 通過；不表示 SoftPLL 已 lock，也不表示 `time_valid=1`。

## 最終 regression gate

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

## Failure classification

- HARDWARE/FIRMWARE FAILURE：本輪沒有新的 hardware/firmware failure evidence。
- JTAG/DASHBOARD_MEASUREMENT_FAILURE：本輪沒有 Tcl exception；focused script 明確把 state shadow 的不一致保留為 `READ_INCONSISTENT`，沒有當成硬體失敗。dashboard 的 stale/invalid retry path 在本次執行中沒有造成中止。
- Step 4 blocker：仍是「DMTD accepted event 與下游 event chain 沒有 sustained activity」；這是 observability boundary，不是已證明的實體 clock、PHY 或 SoftPLL algorithm 根因。

## 原始證據

- `raw/dashboard_0548ece_20260823.log`
- `raw/regression_0548ece_step23_readonly_20260823.log`
- `raw/regression_0548ece_step3_focused_20260823.log`
- `raw/regression_0548ece_step4_readonly_20260823.log`

## 下一步

Step 4 仍只能進行 source-backed read-only audit 或在明確批准後新增 diagnostic-only observability。不得因本輪結果修改 PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。
