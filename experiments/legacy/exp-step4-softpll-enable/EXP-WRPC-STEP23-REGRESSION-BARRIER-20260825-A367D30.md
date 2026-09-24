# EXP-WRPC-STEP23-REGRESSION-BARRIER-20260825-A367D30

## 實驗識別

- 日期：2026-08-25
- Branch：`exp/step4-softpll-enable`
- Git commit：`a367d3037db0033da9563c3dd73310dcb49bfa5d`
- 實驗名稱：Step 2/Step 3 read-only regression barrier 與 DMTD high-qualification abort mapping audit
- Quartus：17.0 Build 595

## 本次目的

在繼續 Step 4 之前，先重新確認目前兩片 FPGA 的 Step 2、Step 3
regression gate。另一個目的，是修正既有 DMTD high-qualification abort
counter 的唯讀 Wishbone mapping，讓下一次 fresh compile/program 後可以區分：

- `HIGH_QUAL_ABORT_COUNT` 是否在 live GOT_EDGE qualification 中增加
- `GOT_EDGE_ENTRY` 是否增加
- `ACCEPT` 是否增加

## 唯一變更

本次只加入/修正 read-only observability：

1. 讓 `0x001002A0/0x001002A4` 讀回既有
   `dbg_high_qual_abort_count_o`。
2. dashboard 與 Step 4 focused scripts 將該欄位改名為
   `DMTD_REF/FB_HIGH_QUAL_ABORT_COUNT`。
3. counter 讀值若下降，保留結果交由 snapshot delta 判為
   reset/clear/wrap 或 measurement warning，不直接丟成 hardware failure。
4. 更新 register map、header 與 read-only script 註解。

沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL FSM、DDMTD
polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 firmware functional
behavior。本輪沒有 Quartus compile，也沒有 program FPGA。

## Read-only 執行證據

### focused handshake

指令：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 250 5
```

原始 log：

- `EXP-STEP23-READONLY-20260825-064406.log`
- `EXP-STEP23-POSTCHECK-20260825-065300.log`

兩次執行都得到 Quartus SignalTap `0 errors, 0 warnings`。

### register reliability

指令：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_step23_register_reliability.tcl 20 250 all 5
```

原始 log：

- `EXP-STEP23-RELIABILITY-20260825-full.log`

結果：

- Master：20/20 valid，0 invalid，0 decrease，Step 2 PASS。
- Slave：20/20 valid，0 invalid，0 decrease，Step 2 PASS。
- Quartus script evaluation：successful，0 errors，0 warnings。

## Acceptance 結果

### Step 1：PHY / Link

- Master status probe：`0xFF`
- Slave status probe：`0xCF` 或 `0xEF` 的 read-only snapshot variation
- 本次 focused samples 沒有看到 RX encoding error，CPU/PHY/link 相關條件維持正常。

`STEP1_REGRESSION = PASS`

### Step 2：Endpoint / MiniNIC / PTP

Master：

- MAC：`02:00:22:33:44:01`
- MODE：`2`
- PTP：`6`
- PTP RX/TX、MiniNIC TX/RX 持續增加
- RXERR：20/20 為 `0`

Slave：

- MAC：`02:00:22:33:44:02`
- MODE：`3`
- PTP：`9`
- `FOREIGN_META=03000001`
- PTP RX/TX、MiniNIC TX/RX 持續增加
- RXERR：20/20 為 `0`

`STEP2_REGRESSION = PASS`

### Step 3：WR Parent / Signaling

Slave 20 筆 accepted samples：

- Foreign Master：`count=1`、`best_index=0`
- Parent flags：`parentIsWRnode=1`、`parentWrModeOn=0`、`parentCalibrated=1`
- RX WR message：`0x1001`
- TX WR message：`0x1000`
- `LOCK_ENABLE=4`
- `WR_SIGNAL_REJECT=0`
- `WR_FAILURE_DEBUG` 保留 `S_LOCK` evidence

但是 current state 觀測為 `WRS_IDLE`，focused script 輸出：

```text
POST_STEP3_LOCK_STAGE=TIMEOUT
STATE_EVIDENCE=READ_INCONSISTENT
```

因此本次依既定規則，不把單一 current-state 欄位直接解讀成 Step 3
hardware failure；Step 3 gate 以 repeated focused evidence 判定通過。

`STEP3_REGRESSION = PASS`

## Regression barrier

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
```

本次沒有進行 Step 4 functional experiment。先前的 Step 4 evidence 仍顯示
`GOT_EDGE` 後 high qualification abort，尚未證明 SoftPLL event chain 已通過：

`STEP4_RESULT = NOT_ACHIEVED`

`HIGH_QUAL_ABORT_COUNT` 的新完整 mapping 尚未由 fresh SOF 驗證，因為本輪
明確禁止 compile/program。因此目前不能把新 mapping 的數值當成硬體結論。

## 證據分類

- HARDWARE/FIRMWARE FAILURE：`NOT_PROVEN`
- JTAG/DASHBOARD MEASUREMENT FAILURE：`PRESENT`
  - 舊 bitstream 尚未包含本次 A0/A4 high-abort read mapping。
  - Slave current-state 欄位與 repeated handshake evidence 不一致，需保留為
    `READ_INCONSISTENT`。

## 下一步

在使用者允許下一輪 compile/program 後：

1. 從本 commit 做 clean firmware/Quartus build，產生 fresh SOF。
2. 保存 MIF/SOF SHA256 與 programmer log。
3. 重新做 Step 2/Step 3 barrier。
4. 取樣並比較 `HIGH_QUAL_ABORT_COUNT delta`、
   `GOT_EDGE_ENTRY delta`、`ACCEPT delta`。
5. 只有在這些 fresh-image evidence 完整後，才判斷 Step 4 的第一個 live
   blocker。

