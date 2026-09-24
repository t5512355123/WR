# EXP-WRPC-REGRESSION-ABORT-20260825

## 實驗基本資料

- 實驗名稱：Step 2 / Step 3 唯讀回歸與 Step 4 DMTD abort-cause 定位
- 日期：2026-08-25
- Git branch：`exp/step4-softpll-enable`
- Git commit：`115df253439ae67a68488c96500dea4202b5bca8`
- Quartus：Quartus Prime SignalTap II 17.0，Build 595，2017-04-25
- 實驗主機：`pain`
- FPGA 操作：本輪**沒有 program FPGA**，也**沒有 Quartus compile**
- 目前硬體 bitstream provenance：本輪沒有重新燒錄，因此不能把目前板上 image 宣稱為 commit `115df25` 的 fresh SOF

## 這次想驗證什麼

1. 確認 JTAG mailbox retry / validation 修正後，Step 2 與 Step 3 可以用 focused repeated sampling 判定。
2. 確認單一 counter 短窗口為 0 時不會被錯誤判成整個 Step 2 failure。
3. 釐清 Step 4 先前觀察到的
   `GOT_EDGE -> HIGH qualification abort -> no sustained ACCEPT`
   是否有 source-backed abort condition。

## 相較前一版唯一修改

本次只修改 read-only diagnostics：

- `scripts/jtag/read_step4_startup_focused.tcl`
  - 將 `SPLL_DMTD_STATE` 納入 invalid measurement 檢查。
  - 依現有 source 定義輸出 REF/FB 的 HIGH qualification abort condition。
  - 當 sticky bit 無效時輸出 `MEASUREMENT_INVALID_RETEST`，不再自行推論。
- `docs/debug/jtag_register_map.md`
  - 補充 bit 31/30 的 source-backed 意義。
  - 明確說明 sticky evidence 不是 abort 絕對次數。
  - 明確標示目前沒有獨立可靠 Wishbone abort-count read address。

沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD polarity、PI、lock threshold、DCO、SI5340 或 PHY 行為。

## 驗證檔案

- Tcl syntax/runtime check：`raw/STEP4-DIAGNOSTIC-20260825-115df25-syntax-readonly.txt`
- Step 2 長時間唯讀觀測：`raw/STEP2-REGRESSION-20260825-115df25-long.txt`
- Step 2/3 focused 25 samples：`raw/STEP23-REGRESSION-20260825-115df25-handshake.txt`
- Step 4 abort-cause focused 10 samples：`raw/STEP4-ABORT-CAUSE-20260825-115df25-events.txt`
- Step 4 qualification-chain repeated 30 samples：`raw/STEP4-QUALIFICATION-CHAIN-20260825-115df25-30x500.txt`

## 結果一：Tcl reliability

執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step4_startup_focused.tcl 1 0 lock
```

兩片板均完整輸出，Quartus 回報：

```text
Evaluation of Tcl script ... was successful
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

因此本次修改的 Tcl syntax/runtime gate = PASS。

## 結果二：Step 2 regression

### Focused 25 samples

Master `DE5 [1-11.1]`：

- 25/25 samples valid，0 invalid，0 counter decrease
- MAC `02:00:22:33:44:01`
- MODE `2`
- PTP `6`
- PTP_TX delta `80`
- MiniNIC TX/RX counters 持續增加
- RXERR `0`

Slave `DE5 [1-11.2]`：

- 25/25 samples valid，0 invalid，0 counter decrease
- MAC `02:00:22:33:44:02`
- MODE `3`
- PTP `9`
- PTP_TX delta `14`
- MiniNIC TX/RX counters 持續增加
- RXERR `0`
- FOREIGN `1/0`

Focused script 的 gate 結果：

```text
Master STEP2_REGRESSION=PASS
Slave  STEP2_REGRESSION=PASS
```

### 10 秒長時間觀測

Master：

- `PTP_RX`: `0x1333 -> 0x1344`
- `PTP_TX`: `0x2B33 -> 0x2B64`
- MAC/MODE/PTP 持續為 `02:00:22:33:44:01 / 2 / 6`

Slave：

- `PTP_RX`: `0x2B60 -> 0x2B9C`
- `PTP_TX`: `0x0607 -> 0x0610`
- `FOREIGN_META=0x03000001` 持續存在
- MAC/MODE/PTP 持續為 `02:00:22:33:44:02 / 3 / 9`

因此 Step 2 regression = **PASS**。短窗口內個別 counter 暫時不增加，不足以推翻整體 packet-path activity。

## 結果三：Step 3 regression

Slave 在 25 samples 中持續觀察到：

```text
FOREIGN=1/0
parent=1/0/1
RX=0x1001/1
TX=0x1000/1
LOCK=1/0
LOCK_ENABLE=4
```

這些條件符合目前 Step 3 focused gate 的 parent / signaling / lock-enable 證據，因此 script 輸出：

```text
Slave STEP3_REGRESSION=PASS
```

但同一批 sample 同時觀察到：

```text
local_state=0
next_state=0
state_idle=25
state_good=0
STATE_EVIDENCE=READ_INCONSISTENT
```

這代表 current-state 欄位與 LOCK / SLAVE_PRESENT / LOCK_ENABLE 證據不一致。依本實驗規則，這一列應分類為 `READ_INCONSISTENT`，不能直接寫成 Step 3 hardware failure；需要後續用同一來源的 mailbox snapshot / state mapping 再確認。

## 結果四：Step 4 abort-cause

執行 10 samples、500 ms gap 的 events focused script。

Slave 最重要的結果：

```text
SPLL_DMTD_STATE = FC00000A
ref_state=2
fb_state=2
ref_threshold_reached=1
fb_threshold_reached=1
ref_high_abort_seen=1
fb_high_abort_seen=1
ref_got_edge_seen=1
fb_got_edge_seen=1
STEP4_QUALIFICATION_ABORT_CAUSE:
  ref=GOT_EDGE_HIGH_ABORT(clk_sampled=0)
  fb=GOT_EDGE_HIGH_ABORT(clk_sampled=0)
```

之後的 activity：

```text
DMTD_REF_ACCEPT delta=0
DMTD_FB_ACCEPT delta=0
DMTD_REF_EVENTS delta=0
DMTD_FB_EVENTS delta=0
TAG_PENDING delta=0
TAG_GRANT delta=0
TAG_VALID delta=0
TRR_WRITE delta=0
IRQ delta=0
STATE_TRANSITION delta=0
HELPER_UPDATE delta=0
STEP4_EVENT_BOUNDARY=QUALIFICATION_ABORT_AFTER_GOT_EDGE
```

Master 也觀察到相同的 `ref_high_abort_seen=1`、`fb_high_abort_seen=1` 與 accept/downstream counter 沒有增加；但 Master 的 Step 2 role/packet path 仍然正常，這一點不能直接等同於 Master/Slave functional failure。

### Source-backed 解讀

目前 source 中：

- `dmtd_with_deglitcher.vhd` 只有在 `GOT_EDGE` HIGH qualification 尚未達 threshold 且 `clk_sampled='0'` 時增加 high-abort count。
- `wr_softpll_ng.vhd` 將 high-abort count 非零轉成 `SPLL_DMTD_STATE` 的 sticky bit 31/30。
- 因此本次讀值支持：兩個 channel 曾發生 `GOT_EDGE` HIGH qualification 因 `clk_sampled='0'` 中止。
- 這是 abort condition evidence，不是 abort 次數，也不能單靠它推導根因是 polarity、threshold、clock duty-cycle 或其他類比問題。

## 後續 30 samples qualification-chain audit

為避免用 10 samples 過度解讀，使用相同 current image 再執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step4_startup_focused.tcl 30 500 events
```

這一輪同樣沒有 program/compile，Quartus 回報 `0 errors, 0 warnings`。

### Master

- `DMTD_REF_GOT_EDGE_ENTRY delta=0`
- `DMTD_FB_GOT_EDGE_ENTRY delta=0`
- `DMTD_REF_QUAL_REACHED_8 delta=262144`
- `DMTD_FB_QUAL_REACHED_8 delta=0`
- `DMTD_REF_ACCEPT delta=0`
- `DMTD_FB_ACCEPT delta=0`
- `TAG/TRR/IRQ/HELPER delta=0`
- `SPLL_DMTD_STATE=FC00000A`
- REF/FB `high_abort_seen=1`
- boundary=`QUALIFICATION_PROGRESS_TO_DEGLITCH_ACCEPT`

### Slave

- `DMTD_REF_GOT_EDGE_ENTRY delta=0`
- `DMTD_FB_GOT_EDGE_ENTRY delta=0`
- `DMTD_REF_QUAL_REACHED_8 delta=0`
- `DMTD_FB_QUAL_REACHED_8 delta=0`
- `DMTD_REF_ACCEPT delta=0`
- `DMTD_FB_ACCEPT delta=DECREASED_OR_RESET`；這是 32-bit counter snapshot decrease/reset 類型的 measurement caveat，不直接當成硬體 error
- `TAG/TRR/IRQ/HELPER delta=0`
- `SPLL_DMTD_STATE=FC00000A`
- REF/FB `high_abort_seen=1`
- `STEP4_QUALIFICATION_ABORT_CAUSE=GOT_EDGE_HIGH_ABORT(clk_sampled=0)`
- boundary=`QUALIFICATION_ABORT_AFTER_GOT_EDGE`

### 30 samples 的新增判讀

這次 repeated audit 顯示 DMTD sampled / D0 counters 持續增加，但 `GOT_EDGE_ENTRY` 在這個視窗沒有新增；因此目前不能把 sticky `GOT_EDGE` bit 解讀成「每個 sample 都反覆進入 GOT_EDGE」。較保守、證據支持的描述是：

```text
歷史上曾進入 GOT_EDGE，且曾發生 HIGH qualification abort；
本次 30-sample window 沒有新的 GOT_EDGE entry，也沒有新的 sustained ACCEPT。
```

Master 的 REF `QUAL_REACHED_8` 有 activity，但仍沒有 accept；Slave 的 REF/FB `QUAL_REACHED_8` 都沒有新增。這表示下一個 blocker 仍在 `GOT_EDGE / qualification -> ACCEPT` 邊界，但目前不能再聲稱「abort 每次都在重複發生」。

## Regression barrier 結果

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS (STATE_EVIDENCE=READ_INCONSISTENT)
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
```

## Hardware/Firmware 與 JTAG measurement 的區分

### 已有足夠證據的部分

- Step 2 的 MAC、role、PTP state、PTP/MiniNIC counters、RXERR 與 FOREIGN_META 在 repeated samples 中一致，支持 Endpoint / MiniNIC / PTP packet path regression PASS。
- Step 3 的 FOREIGN、parent metadata、SLAVE_PRESENT、LOCK、LOCK_ENABLE 在 repeated samples 中一致，支持 focused Step 3 gate PASS。
- Step 4 的 `SPLL_DMTD_STATE` 讀值有效，且 sticky abort evidence 與 source condition 對得上；下游 counters 同時沒有活動。

### 尚不能宣稱的部分

- 本輪沒有 program FPGA，因此不能宣稱 `115df25` 對應的 fresh SOF 已在板上重現。
- Step 3 current-state 欄位存在 repeated `READ_INCONSISTENT`，仍需 source/register snapshot 角度釐清。
- Step 4 尚未 PASS；目前證據定位到 `GOT_EDGE_HIGH_ABORT(clk_sampled=0)` 後沒有 accept/downstream activity，但尚未證明更下游的硬體/firmware 根因。

因此目前不能把結果簡化成「HEAD functional hardware failure」；本輪同時包含一個已定位的 Step 4 runtime behavior blocker，以及 Step 3 current-state 欄位的 measurement/state-mapping inconsistency。

## 結論

Step 2 與 Step 3 的 focused regression gate 可以通過，因此 Step 4 研究 barrier 已解除；但 Step 4 尚未達成。最早可重現且有 source-backed 證據的斷點是：

```text
GOT_EDGE
  -> HIGH qualification 因 clk_sampled='0' 中止
  -> ACCEPT 沒有增加
  -> TAG/TRR/IRQ/helper 沒有活動
```

本輪沒有修改任何 functional behavior，也沒有燒錄或編譯。

## 下一步

1. 保留 Step 2/3 回歸結果，不修改 role、PTP、WR signaling 或 SoftPLL 演算法。
2. 在允許 fresh hardware provenance 後，以 exact source commit 建立並燒錄 fresh image，再重跑同一組 Step 2/3 barrier。
3. 若 fresh image 仍重現相同 abort，才在 read-only source-backed範圍內繼續拆解 `clk_sampled` 到 deglitcher 的邊界證據；不要先改 threshold、polarity、PI、lock threshold、DCO 或 SI5340。
4. 下一個 read-only 實驗應繼續保留 `GOT_EDGE_ENTRY`、`QUAL_REACHED_8`、`ACCEPT` 三者的分離，不要以 sticky bit 推算事件頻率；若要取得新資訊，先確認現有 source-backed counter 的 image mapping 與 mailbox snapshot consistency。
