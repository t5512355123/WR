# EXP-WRPC-STEP2-STEP3-INDEPENDENT-20260821

## 實驗基本資料

- 實驗名稱：Step 2 / Step 3 獨立 register reliability regression
- 日期：2026-08-21
- Branch：`exp/step4-softpll-enable`
- Diagnostics HEAD：`756004805f6700ea038a2c9501df5086a55c66d1`
- 前一個診斷修正版：`fd4440aa1fe5d210e1f7de99b90f9f22a8c9a2e2`
- 硬體 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- Quartus：17.0.0 Build 595
- 硬體操作：沒有 program FPGA、沒有 Quartus compile、沒有 reboot
- 觀測方式：只讀 JTAG In-System Source and Probe + Wishbone mailbox

本次使用的硬體影像沒有改變；本次只更新 read-only Tcl diagnostics，並在既有已燒錄影像上重複取樣。

## 想驗證什麼

本次目標是重新建立 Step 2 / Step 3 的可靠 regression gate，並區分：

1. JTAG mailbox 讀值不一致或 stale value。
2. counter reset/decrease 等需要重測的量測現象。
3. FPGA/firmware 真的從 WR handshake 狀態離開，並記錄了 handshake failure。

只有 Step 2 與 Step 3 都有可靠證據通過，才允許繼續 Step 4；本次不進行 Step 4 functional experiment。

## 相較前一版本唯一修改

本次只修改 JTAG Tcl：

- `scripts/jtag/read_step23_register_reliability.tcl`
  - 對 `WR_SIGNAL_REJECT` 與 `WR_FAILURE_DEBUG` 加入 source-backed 合法值驗證與 retry。
  - 把 `WR_FAILURE_DEBUG` 的 `last_fail_state`、failure count 與 `WRS_S_LOCK` 歷史證據獨立列出。
  - 不把 packed failure shadow 的欄位變化直接當成 counter decrease；counter reset/decrease 只保留為重測訊號。
  - Master 的 Step 3 顯示為 `NA`，避免把不適用的 Master handshake gate 判成失敗。
- `scripts/jtag/read_wb_runtime.tcl`
  - `WDIAGS_TEMP` 若讀到 `WRS_IDLE`，顯示 `MEASUREMENT_INVALID / RETEST`，不再錯誤顯示 `NA`。

沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD、PI gain、lock threshold、DCO、SI5340 或 PHY 功能。

## 執行命令

pain 先 checkout exact commit：

```text
cd /home/b10504072/04_WR
git fetch origin
git checkout --detach 756004805f6700ea038a2c9501df5086a55c66d1
```

獨立可靠性測試：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  100 100 temp

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  30 100 step2

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  30 100 step3
```

dashboard 交叉檢查：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

以上命令都只做 read-only 讀取；沒有寫 Wishbone control register，也沒有寫 `DATA_SNAPSHOT`。

## 實測證據

### Step 1：WDIAGS_TEMP 穩定性

log：`regression_register_temp_7560048.log`

```text
DE5 [1-11.1] WDIAGS_TEMP samples=100 valid=100 invalid=0 distinct=1 decrease=0 states=0:100
DE5 [1-11.2] WDIAGS_TEMP samples=100 valid=100 invalid=0 distinct=1 decrease=0 states=0:100
```

兩張板的 `WDIAGS_TEMP` 都是有效讀值，且 100 次都解碼為 state 0 (`WRS_IDLE`)。這不是單一 snapshot 的偶發值。

### Step 2：Endpoint / MiniNIC / PTP

log：`regression_register_step2_7560048.log`

兩張板各欄位都是 30/30 valid、0 invalid、0 decrease，且 summary 都是 `result=PASS`。

| 欄位 | Master DE5 [1-11.1] | Slave DE5 [1-11.2] |
|---|---:|---:|
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` |
| MODE | `2` | `3` |
| PTP | `6` | `9` |
| PTP/MiniNIC counter | 30/30 valid、無下降 | 30/30 valid、無下降 |
| RXERR | 30/30 `0` | 30/30 `0` |
| Step 2 | PASS | PASS |

Step 2 的 PASS 是由每個 register 分開連續讀取後得到，不是把不同時間的 mailbox 欄位拼成一個 snapshot。

### Step 3：WR Parent / Signaling

log：`regression_register_step3_7560048.log`

Slave 30/30 samples：

```text
FOREIGN_META      = 03000001
PARSE_META        = parent flags valid，expected=30/30
WR_RX_SIGNAL      = 10010001       # RX message 0x1001，count=1
WR_TX_SIGNAL      = 10000001       # TX message 0x1000，count=1
LOCK_ENABLE       = 00000004       # 4
WR_SIGNAL_REJECT  = 00000000       # reject count=0，30/30
WR_FAILURE_DEBUG  = 02020001       # last_fail_state=2，failure count=1
WDIAGS_TEMP       = A000035C       # state=0，WRS_IDLE，30/30
```

腳本輸出：

```text
STEP3_STATE_EVIDENCE board=DE5 [1-11.2] result=POST_FAILURE_IDLE last_fail_state=WRS_S_LOCK failure_samples=30 current_state=WRS_IDLE failure_count_max=1
STEP3_INDEPENDENT board=DE5 [1-11.2] result=FAIL
```

這個結果和 source 的語意一致：`wr_handshake_fail()` 會先保存當時的 `wrp->state`，再把 `next_state` 設成 `WRS_IDLE` 並重設 WR process。因此目前證據支持「Slave 曾經到達 `WRS_S_LOCK` 並執行過 `LOCK_ENABLE=4`，之後發生 handshake failure 回到 `WRS_IDLE`」。

這不是單純的 JTAG mailbox tear：`WDIAGS_TEMP` 100/100 與 30/30 都是 state 0，且 `WR_FAILURE_DEBUG` 同時穩定記錄 `last_fail_state=2`。目前尚不能把失敗根因再往下歸因到 SoftPLL 或其他 Step 4 元件，但已足以判定 Step 3 regression 尚未通過。

### Dashboard 交叉結果

log：`regression_dashboard_7560048.log`

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           MEASUREMENT_INVALID / RETEST
Step 4 SoftPLL Startup        error
```

dashboard 的 Step 3 `MEASUREMENT_INVALID / RETEST` 是刻意保守的 UI 結果；獨立 register series 已進一步排除單純 mailbox tear，故 regression gate 以 focused independent result 為準：Step 3 FAIL。

所有 Tcl 執行均回報：

```text
Evaluation of Tcl script ... was successful
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

## Regression Barrier 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = FAIL
STEP4_ALLOWED     = NO
```

### Hardware/Firmware failure 與 JTAG measurement failure 的區分

- Step 2：目前不是硬體/firmware failure；獨立 register series 已通過。先前 cross-register focused script 的 invalid 結果屬於量測一致性不足，不能沿用作 Step 2 失敗結論。
- Step 3：目前不是單純 JTAG measurement failure。獨立同一 register series 仍穩定看到 `WRS_IDLE`，且 `WR_FAILURE_DEBUG` source-backed 記錄 `last_fail_state=WRS_S_LOCK` 與 failure count，因此是 runtime handshake 在到達 lock stage 後失敗的實際證據。
- Step 3 的更下游根因尚未證明；本紀錄不把它直接宣稱為 SoftPLL、DDMTD、DCO 或 SI5340 根因。

## 下一步

1. 保持 `STEP4_ALLOWED=NO`，不要修改 Step 4 functional code。
2. 保存本次 exact HEAD、Tcl logs 與 source mapping，請 White Rabbit reviewer 檢查「到達 `WRS_S_LOCK` 後回 Idle」是否應被視為 Step 3 gate fail 或 Step 4 boundary evidence。
3. 下一輪若要繼續，只能先做 read-only focused diagnosis，釐清 `WR_FAILURE_DEBUG`、lock polling 與 state transition 的時間關係；仍不可先改 SoftPLL 演算法。

## 原始證據檔案

- `regression_register_temp_7560048.log`
- `regression_register_step2_7560048.log`
- `regression_register_step3_7560048.log`
- `regression_dashboard_7560048.log`
- `regression_register_temp_fd4440a.log`
- `regression_register_step2_fd4440a.log`
- `regression_register_step3_fd4440a.log`

前一輪的 diagnostics logs 也保留在同一資料夾，沒有刪除。
