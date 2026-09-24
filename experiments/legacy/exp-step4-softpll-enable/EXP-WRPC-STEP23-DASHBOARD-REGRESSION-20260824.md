# EXP-WRPC-STEP23-DASHBOARD-REGRESSION-20260824

## 實驗識別

- 日期：2026-08-24
- 實驗名稱：JTAG dashboard 格式與 Step 2/3 唯讀回歸
- Git branch：`exp/step4-softpll-enable`
- Git commit：`30758be3320ffeaa65765948a6a4c0724417b298`
- pain checkout：同一個 `30758be3320ffeaa65765948a6a4c0724417b298`
- Quartus：17.0.0 Build 595
- 實驗性質：只修改 Tcl/read-only diagnostics；沒有 firmware build、Quartus compile 或 FPGA program

## 目的

驗證以下 dashboard 修正：

1. `A5A5...` stale mailbox 值會被 validation/retry 擋下，不會被當成合法 PTP enum。
2. `TIMEOUT`、`INVALID`、`DECREASED` 不會進入不安全的數值比較，也不會中止後續 Step 輸出。
3. 單一 observation window 的 `PTP_TX delta=0` 不會單獨讓 Step 2 失敗。
4. 預設輸出維持 `[pass/error/info] symbol 結果: value/expected`；`info` 的 expected 固定為 `NA`。

## 唯一修改變因

只修改 `scripts/jtag/read_wb_runtime.tcl` 的 UI 與讀值錯誤處理：

- commit `b89c18c`：收斂狀態輸出與未知狀態 fallback。
- commit `30758be`：修正 `WDIAGS_RXERR` 實際列印仍使用舊 `DELTA=0` 字串的問題。

沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD、PHY 或任何 Wishbone control 行為。

## 執行指令

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl \
  20 500 25

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl --raw
```

原始輸出：

- `raw/EXP-WRPC-DASHBOARD-30758BE-20260824/dashboard.log`
- `raw/EXP-WRPC-DASHBOARD-30758BE-20260824/focused-20x500.log`

## Runtime 結果

### Dashboard 預設模式

- Master `DE5 [1-11.1]`：Step 1 PASS、Step 2 PASS。
- Slave `DE5 [1-11.2]`：Step 1 PASS、Step 2 PASS、Step 3 PASS。
- Slave Step 4：`error`；DMTD、tag、TRR、IRQ、helper 的 accepted/event delta 仍為 0。
- Slave Step 5/6：NA，因 Step 4 尚未通過。
- `WDIAGS_RXERR` 兩板都顯示 `delta=0`，且實際輸出為 `Δ=0/Δ=0`。
- 兩板均完整輸出 Step 1～Step 6，沒有 Tcl exception。

### Focused Step 2/3 regression

```text
Master: valid_samples=20 invalid_samples=0 counter_decreased=0
        PTP_TX_DELTA=68 STEP2_REGRESSION=PASS

Slave : valid_samples=20 invalid_samples=0 counter_decreased=0
        PTP_TX_DELTA=7 STEP2_REGRESSION=PASS STEP3_REGRESSION=PASS
        STATE_EVIDENCE=READ_INCONSISTENT
```

Slave 的 repeated samples 持續觀察到：

- `MODE=3`、`PTP=9`
- `FOREIGN_META=1/0`
- parent flags=`1/0/1`
- RX=`0x1001`、TX=`0x1000`
- `LOCK_ENABLE=4`
- PTP/MiniNIC counters 增加、`RXERR=0`

Slave 的 `WRS_IDLE` 讀值與上述 signaling evidence 不一致，focused script 明確標成 `READ_INCONSISTENT`，沒有因此直接宣稱 Step 3 FAIL。

### Raw 模式

`--raw` 執行成功，保留兩張板的 before/after `RAW_SNAPSHOT`，並輸出：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
FAILURE_CLASSIFICATION = NO_FAILURE_EVIDENCE
```

`STEP4_ALLOWED=YES` 只表示 Step 1～3 regression barrier 通過；不表示 Step 4 SoftPLL 已完成。

## Acceptance 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
```

本次沒有出現 invalid mailbox sample，因此本次結果沒有證據支持 `JTAG/DASHBOARD_MEASUREMENT_FAILURE`。Slave 的 state/signaling 不一致則保留為 `READ_INCONSISTENT`，不可簡化成硬體故障。

## 結論

Dashboard 的唯讀可靠性與輸出格式修正有效：非法/不一致的 mailbox 讀值不會被當成合法 enum，也不會中止整張 dashboard；單一 counter 的零增量不會單獨造成 Step 2 failure。現有 control image 在本次唯讀回歸重新通過 Step 1～3 barrier。

但是 Step 4 尚未完成。Slave 仍只有 SoftPLL 初始化與 channel enable 的部分證據，DMTD accepted event 到 tag/TRR/IRQ/helper 的下游事件沒有持續增加。本紀錄不宣稱 SoftPLL lock，也不宣稱已找到根因。

## 下一步

維持目前 control image，不燒錄新硬體；先做 source/runtime read-only localization，追蹤 `WRS_S_LOCK -> locking_enable() -> SoftPLL channel enable -> sequence/DDMTD/servo` 的第一個無活動節點。只有 Step 2/3 regression 再次通過後，才允許新的 Step 4 單一 functional variable 實驗。
