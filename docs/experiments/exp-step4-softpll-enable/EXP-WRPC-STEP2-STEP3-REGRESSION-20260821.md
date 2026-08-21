# EXP-WRPC-STEP2-STEP3-REGRESSION-20260821

## 實驗基本資料

- 實驗名稱：Step 2 / Step 3 唯讀回歸門檻重測
- 日期：2026-08-21
- Branch：`exp/step4-softpll-enable`
- Diagnostics execution HEAD：`8935163cbc1b68d24ce21f3d02b24d645a88a05c`
- 本實驗紀錄保存 commit：`f7fa69d8578180ef2dae70a35335d14d0df71c78`
- 硬體 functional baseline 參考：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- Quartus：17.0.0 Build 595
- 操作範圍：只執行 JTAG read-only diagnostics；沒有 Quartus compile、沒有 FPGA program、沒有 merge main。

## 想驗證什麼

本次先建立可靠的 Step 2 / Step 3 regression gate，確認目前硬體上的讀值是否足以允許後續 Step 4。重點是把 JTAG mailbox 的無效值、counter 回跳，以及跨 register 的非 atomic snapshot，與真正的 FPGA/firmware 功能失敗分開。

## 相較前一版本唯一修改

本輪只修改 JTAG Tcl diagnostics：

1. 對 source-backed critical fields 做合法值驗證與最多 5 次重讀。
2. 將 `A5A5...` 類 stale mailbox value 視為 `INVALID`，不拿去做數值比較。
3. 短時間 counter delta=0 只作資訊/警告，不單獨使 Step 2 fail。
4. focused sampling 會記錄 counter decrease；回跳只標示 `INVALID` / 需重測，不宣稱硬體故障。
5. focused sampling 會把 signaling evidence 與 `WDIAGS_TEMP` 的 state evidence 分開；若 state 持續為 `WRS_IDLE` 或兩者互相矛盾，標示 `READ_INCONSISTENT`。

沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD、PI、lock threshold、DCO、SI5340 或 PHY 行為。

相關 commit：

- `11309fc` 診斷：加入 JTAG 讀值驗證與 Step 2/3 regression gate
- `9314bdd` 診斷：驗證 Endpoint MAC mailbox 讀值
- `36b8300` 診斷：修正 Endpoint MAC 高位欄位驗證
- `cd9e79f` 診斷：將重複讀值不一致標為需重測
- `8935163` 診斷：修正 counter 下降偵測

本次 JTAG 實驗是在 `8935163` 的 diagnostics 執行；raw logs 與本文件之後以 `f7fa69d` 保存。`f7fa69d` 只新增文件與 logs，沒有改變 diagnostics 行為。

## 執行方式

pain 先從 GitHub checkout exact HEAD：

```text
git checkout --detach 8935163cbc1b68d24ce21f3d02b24d645a88a05c
```

執行的唯讀 Tcl：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 30 1000

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_master_ptp_slave_parent_long.tcl 10 500
```

三個 Tcl 執行都回報 `Evaluation of Tcl script ... was successful`、SignalTap II 0 errors。沒有寫入 Wishbone control register，也沒有寫入 `DATA_SNAPSHOT`。

## Dashboard 結果

最新 exact HEAD dashboard：`regression_dashboard_8935163.log`。

兩張板在這次短 snapshot 都顯示：

- Step 1 PHY/link：pass
- Master MAC `02:00:22:33:44:01`、MODE=2、PTP=6、MiniNIC/PTP counter 有 delta、RXERR delta=0
- Slave MAC `02:00:22:33:44:02`、MODE=3、PTP=9、Foreign Master=1/best=0、parentIsWRnode=1、parentCalibrated=1、RX LOCK=0x1001、TX SLAVE_PRESENT=0x1000、LOCK_ENABLE=4
- Slave 的 `WDIAGS_TEMP` 讀到 `WRS_IDLE next=WRS_IDLE READ_INCONSISTENT`；SoftPLL event counters 在短窗 delta=0，因此 dashboard Step 4 顯示 error。

短窗結果只能說明當下讀到的欄位；不能取代 focused repeated sampling。

## Focused 30-sample 結果

最新 log：`regression_handshake_8935163.log`，30 samples、每次間隔 1000 ms。

### Master

```text
valid_samples=30
invalid_samples=0
counter_decreased=1
STEP2_REGRESSION=INVALID
```

Master 的 MAC、MODE=2、PTP=6 與 MiniNIC activity 都存在，但 PTP/MiniNIC/RXERR 等 mailbox counter 在不同 sample 間出現回跳或不合理替換值。依本實驗規則，這是 JTAG snapshot/counter consistency 不足，不能宣稱 Master 功能故障，也不能把這組資料當成 PASS。

### Slave

```text
valid_samples=30
invalid_samples=0
counter_decreased=1
STEP2_REGRESSION=INVALID
STEP3_REGRESSION=INVALID
STATE_EVIDENCE=READ_INCONSISTENT
signal_good=27
signal_bad=3
state_idle=30
state_good=0
```

Slave 的 27/30 samples 同時看見：Foreign Master=1、best=0、parent flags=1/0/1、RX=0x1001、TX=0x1000、LOCK_ENABLE=4；但 3/30 samples 的 signal/parent snapshot 不完整，且 30/30 samples 的 `WDIAGS_TEMP` local state 是 `WRS_IDLE`。因此目前只能標為 `INVALID` / `READ_INCONSISTENT`，不能直接寫成 WR signaling functional FAIL。

## 既有長時間 script 交叉結果

最新 log：`regression_long_8935163.log`，10 samples、每次間隔 500 ms。

- Master 持續看到 MODE=2、PTP=6、CPU marker `B004`、fault=0、im_valid=1，PTP_RX/PTP_TX 有增加。
- Slave 多數 samples 看到 MODE=3、PTP=9、`FOREIGN=03000001`、RCER=1；但跨 register mailbox 讀值曾出現不同欄位互相錯位的現象，例如 PSTAT/FOREIGN/SPLL_STATE 欄位出現不符合同一 snapshot 的值。
- 這支持「Endpoint/MiniNIC/PTP path 有 activity」，也支持「目前 JTAG mailbox read consistency 尚不足以作 Step 2/3 release gate」。

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = INVALID
STEP3_REGRESSION = INVALID
STEP4_ALLOWED     = NO
```

### 證據能支持的結論

1. PHY/link、CPU runtime、Endpoint MAC、Master/Slave role、PTP packet activity 和 Slave Foreign Master 在多數讀值中存在。
2. 目前還沒有可靠、單調且一致的 repeated mailbox evidence 可以讓 Step 2/3 通過 regression barrier。
3. `INVALID` 的直接原因是 JTAG/cross-register snapshot consistency：counter 回跳、少數 parent/signal 欄位錯位，以及 `WDIAGS_TEMP` state 與 signaling evidence 的衝突。
4. 這次資料**不足以宣稱硬體/firmware functional failure**，也不足以允許 Step 4 functional experiment。

## Next Step

保持 Step 4 barrier 關閉，不修改任何 WR functional behavior。下一步應先做更小範圍的 JTAG reliability investigation：

1. 將 focused script 的 critical fields 與 counters 分成獨立 mailbox transaction，避免把非 atomic cross-register values 拼成同一列。
2. 對每個 register 保存 read attempt、accepted/rejected reason 與 timestamp；counter decrease 只在同一 register 的 accepted read series 中判定。
3. 針對 `WDIAGS_TEMP`、WR RX/TX signal、LOCK_ENABLE 分開重複讀取，確認 `WRS_IDLE` 是真實狀態還是 mailbox tear。
4. 只有 Step 2/3 在 fresh、accepted samples 下都 PASS，才可重新評估 `STEP4_ALLOWED=YES`。

## 原始證據

- `regression_dashboard_8935163.log`
- `regression_handshake_8935163.log`
- `regression_long_8935163.log`
- 先前修正過程的 dashboard/handshake logs 亦保留在本資料夾。

---

# 追加紀錄：80d8fa2 唯讀 regression retest

## 實驗識別

- 分支：`exp/step4-softpll-enable`
- Git commit：`80d8fa2`（`強化 JTAG counter 讀值穩定性`）
- 實驗日期：2026-08-21
- 實驗類型：唯讀 JTAG regression；沒有燒錄 FPGA，沒有 Quartus compile
- Quartus：17.0 Build 595（17.0.0）
- 硬體狀態：沿用 pain 當時已載入的 bitstream；本次不宣稱 fresh SOF provenance

## 本次修改與目的

只修改 JTAG 唯讀 diagnostics：

1. Critical enum/status register 需通過 source-backed 合法性，並取得兩次一致讀值。
2. Free-running counter 以兩次立即讀值確認非遞減；stale 或下降時重試，無法穩定則標記 invalid。
3. focused Step 2 不再要求短窗口 `PTP_TX delta > 0`；改以 PTP RX、MiniNIC TX/RX activity 與 RXERR 沒有增加作為主要 gate。
4. Dashboard 新增 `STEP1_REGRESSION`、`STEP2_REGRESSION`、`STEP3_REGRESSION`、`STEP4_ALLOWED` 與 failure classification。

沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、PHY、DDMTD、PI、lock threshold、DCO 或 SI5340。

## 執行命令

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_master_ptp_slave_parent_long.tcl 10 500
```

三個 Tcl 都是 read-only diagnostics；沒有寫入 Wishbone control register，也沒有寫入 `DATA_SNAPSHOT`。

## 原始 log 與 SHA256

| 檔案 | SHA256 |
|---|---|
| `regression_dashboard_80d8fa2.log` | `A9EE04B76ECED3F13244F93C9E76FE4A75ECD1A1DD18977EDEB6F6F3C312D510` |
| `regression_handshake_80d8fa2.log` | `52F334EB9AD9785CBD1ACA32002D5ECA611CD0C10EC56B8458BFA465D11A780A` |
| `regression_long_80d8fa2.log` | `B26960529795AE5DA4F0A0F559484CA9665DD06975F5AD69157AD4A97EF1E151` |

## 結果

### Dashboard

- 兩片板 Step 1：PASS。
- Master：MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`、PTP/MiniNIC counters 有增加、RXERR delta `0`。
- Slave：MAC `02:00:22:33:44:02`、MODE `3`、PTP `9`、Foreign Master `1/0`、parent flags `1/0/1`、RX `LOCK`、TX `SLAVE_PRESENT`、LOCK_ENABLE `4`。
- Slave dashboard 的 Step 4 event counters 在短 snapshot 均為 `delta=0`，因此 Step 4 顯示 error；這不改變本輪 Step 1～3 barrier。
- Dashboard 最終輸出：兩片板均 `STEP1_REGRESSION=PASS`、`STEP2_REGRESSION=PASS`、`STEP3_REGRESSION=PASS`、`STEP4_ALLOWED=YES`。
- Quartus Tcl：`Evaluation of Tcl script ... was successful`、`0 errors, 0 warnings`。

### 20-sample focused regression

- Master：`valid_samples=20`、`invalid_samples=0`、`counter_decreased=0`、`STEP2_REGRESSION=PASS`。
- Slave：`valid_samples=20`、`invalid_samples=0`、`counter_decreased=0`、`STEP2_REGRESSION=PASS`、`STEP3_REGRESSION=PASS`。
- Master `PTP_TX_DELTA=63`；Slave `PTP_TX_DELTA=6`。PTP TX 不再是單一必要 gate。
- Slave `signal_good=19`、`signal_bad=1`，但 `state_idle=20`、`STATE_EVIDENCE=READ_INCONSISTENT`；工具沒有把單一狀態衝突直接宣稱為 Step 3 硬體失敗。

### 10-sample long runtime

- Master 持續看到 MODE `2`、PTP `6`、PTP RX/TX 增加。
- Slave 持續看到 MODE `3`、PTP `9`、`FOREIGN=03000001`、PTP RX/TX 增加。
- 此 long script 作為交叉觀測，不單獨取代 focused gate。

## 結論與 barrier

本次 accepted read-only evidence 支持 Endpoint、MiniNIC、PPSI/PTP packet path 仍在運作；Slave 也持續看到 Foreign Master、WR RX/TX message 與 `LOCK_ENABLE=4`。之前 Master 偶發的巨大 counter 跳值，在加入 counter read filter 後，本次 20 samples 沒有再出現 counter decrease。

Slave `WRS_IDLE` 與其他 handshake evidence 的衝突仍只能標記 `READ_INCONSISTENT`，不能由本輪資料確定是硬體 state regression 或 mailbox snapshot tear。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

這只表示允許下一輪 Step 4 read-only investigation；不表示 SoftPLL 已 lock，也不表示 `time_valid=1`。本輪沒有 program/compile，因此仍沒有新的 SOF provenance 證據。
