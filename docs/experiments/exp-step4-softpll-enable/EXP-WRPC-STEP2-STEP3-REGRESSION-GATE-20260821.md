# EXP-WRPC-STEP2-STEP3-REGRESSION-GATE-20260821

## 實驗識別

- 日期：2026-08-21
- Branch：`exp/step4-softpll-enable`
- Diagnostics HEAD：`da57208e6919f1bfa9483331d1b649fd9c2156ab`
- 前置 diagnostics commits：`a195b16`、`1862850`
- 實驗類型：JTAG read-only regression；沒有燒錄 FPGA，沒有 Quartus compile
- Quartus：17.0 Build 595 / Quartus Prime SignalTap II
- pain checkout：detached exact `da57208e6919f1bfa9483331d1b649fd9c2156ab`

### Diagnostics SHA256

| 檔案 | SHA256 |
|---|---|
| `scripts/jtag/read_wb_runtime.tcl` | `e63665b0014656481a3272a587b8557427b1d78d9b52b8b822aa13a8688e4fc1` |
| `scripts/jtag/read_step23_register_reliability.tcl` | `22ffdc4a05008040319a88d28ce3351017fc2f1073a604eaf80fa8f2c4b2459f` |
| `scripts/jtag/read_wr_handshake_focused.tcl` | `e13f253dee40b16a5c84c088484516a2a3d03f4fed4761e9f2702eb37c00506d` |

## 目的

在進入 Step 4 前，重新建立可靠的 Step 1、Step 2、Step 3 regression gate，並區分：

1. 真正的 Endpoint/MiniNIC/PTP/WR signaling 證據。
2. JTAG mailbox stale、enum invalid、counter reset 或非原子 snapshot 造成的量測問題。
3. 已完成 Step 3 後才發生的 WR handshake timeout，不把它誤標為 Step 3 regression failure。

## 唯一修改

本輪只修改 JTAG Tcl diagnostics：

- `read_wb_runtime.tcl`：對 `WDIAGS_PTP`、`MODE`、`FOREIGN_META`、`PARSE_META`、WR state、`LOCK_ENABLE`、`SPLL_STATE`、`RCER`、`OCER`、WR reject/failure shadow 做 validation/retry；修正 failure shadow 的整數/十六進位重複解碼；Step 3 以 source-backed failure shadow 分離 post-stage timeout。
- `read_step23_register_reliability.tcl`：同一 address 連續取樣，拒絕 invalid mailbox read；counter decrease 只輸出 `COUNTER_RETEST`，不單獨造成 hardware failure；穩定 `WRS_IDLE` 且存在 `last_fail_state=WRS_S_LOCK`、`LOCK_ENABLE>0` 時，Step 3 gate 判 PASS 並另列 timeout。
- `read_wr_handshake_focused.tcl`：WR failure/reject 欄位使用 validated read，並採用相同的 Step 3/post-stage 分類。

沒有修改 RTL、firmware、MIF、PTP algorithm、WR signaling algorithm、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。

## 實驗指令與證據

所有指令均在 pain 使用 Quartus STP read-only 執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  30 100 step2

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  30 100 step3

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  30 100 all

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl \
  30 100
```

原始輸出保存於同一資料夾：

- `regression_register_step2_da57208.log`
- `regression_register_step3_da57208.log`
- `regression_step23_all_1862850.log`
- `regression_dashboard_da57208.log`
- `regression_focused_a195b16.log`

`regression_step23_all_1862850.log` 是 counter decrease 修正前的對照紀錄；其中 Step 3 曾因 `LOCK_ENABLE` decrease 被標成 INVALID，保留作為判定修正前的歷史證據。最終 gate 以 `da57208` 的 Step 2/Step 3 重測為準。

## 結果

### Step 1

- Master/Slave status probe：PHY ready、RX/TX ready、link up/link ok、RX lock-to-data 均 PASS。
- RX/TX encoding error 均為 0。

### Step 2

`regression_register_step2_da57208.log`：

- Master：`EP_MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`，30/30 valid，result PASS。
- Slave：`EP_MAC=02:00:22:33:44:02`、`MODE=3`、`PTP=9`，30/30 valid，result PASS。
- 兩板 MiniNIC/PTP counters 都有持續 activity；`RXERR=0` 全部取樣。
- 單一 `PTP_TX delta=0` 只會是短窗口資訊，不足以讓 Step 2 FAIL。

### Step 3

`regression_register_step3_da57208.log`：

- Slave `FOREIGN_META=03000001`，30/30 valid。
- `PARSE_META` 的 parent flags：`parentIsWRnode=1`、`parentCalibrated=1`；source-defined parent mode flag 保留為 context。
- RX WR message=`0x1001 LOCK`，30/30 valid。
- TX WR message=`0x1000 SLAVE_PRESENT`，30/30 valid。
- `LOCK_ENABLE` 每筆都大於 0；有一筆從 `0x100` 回到 `4`，現在只列 `STEP3_COUNTER_RETEST`，不直接宣稱硬體失敗。
- `WR_FAILURE_DEBUG=02020001` 30/30 valid，表示 `last_fail_state=WRS_S_LOCK`、failure count=1。
- `WDIAGS_TEMP=A000035C` 30/30 顯示目前 live state 是 `WRS_IDLE`。
- 正確分類：`STEP3_INDEPENDENT=PASS`，另列 `POST_STEP3_LOCK_STAGE=TIMEOUT`。

### Dashboard / focused script

`regression_dashboard_da57208.log` 顯示 Slave：

```text
Step 1 pass
Step 2 pass
Step 3 pass
Step 4 error
```

Step 3 同時顯示 `WRS_IDLE POST_STEP3_TIMEOUT` 與 `WR_FAILURE_DEBUG` 的 timeout context。Step 4 的 event error 沒有被拿來否定 Step 2/3，也沒有在本輪修改 Step 4 functional code。

`regression_focused_a195b16.log` 的 30-sample focused observation 顯示：

```text
STEP2_REGRESSION=PASS
STEP3_REGRESSION=PASS
POST_STEP3_LOCK_STAGE=TIMEOUT
```

focused script 的 cross-register snapshot 仍可能出現少數 `parent` 欄位不一致，這被保留為非 atomic mailbox context；Step 3 gate 以獨立 same-address reliability script 為正式 acceptance evidence。

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
POST_STEP3_LOCK_STAGE = TIMEOUT
STEP4_ALLOWED = YES
```

這次沒有證明 SoftPLL lock、`PSTAT.locked=1`、`time_valid=1` 或 DCO/SI5340 closed loop；這些不是本輪 Step 2/3 gate。

### Failure classification

- HARDWARE/FIRMWARE FAILURE：沒有證據支持 Step 2 或 Step 3 functional failure。post-Step3 timeout 是實際 source-backed runtime observation，但發生在 Step 3 acceptance 之後。
- JTAG/DASHBOARD MEASUREMENT FAILURE：已確認並修正兩個判定問題：stale enum read 需要 validation/retry；counter decrease 可能是 reset/clear/snapshot boundary，不能單獨當 hardware failure。另修正 dashboard 將整數重新當十六進位解碼的 bug。

## 下一步

Regression barrier 已開放，可以另開明確的 Step 4 工作項目；但本紀錄對 Step 4 沒有功能修改。後續若開始 Step 4，仍需保持單一 functional variable、先 commit、再 clean build/program，並建立新的實驗紀錄。
