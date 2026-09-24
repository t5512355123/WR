# EXP-WRPC-STEP23-BARRIER-MAPPING-AUDIT-20260825

## 實驗名稱

Step 2 / Step 3 read-only regression barrier 與 Step 4 DMTD counter mapping consistency audit。

## 實驗日期

2026-08-25（Asia/Taipei）

## Git 與實驗範圍

- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- HEAD：`736ddec0b079b28c64981146d44d40a277d61afa`
- 前一個 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 本次唯一診斷變因：新增 read-only 的 `GOT_EDGE_ENTRY / QUAL_REACHED_8 / ACCEPT` mapping audit。
- 本次沒有修改 FPGA RTL、firmware、MIF 內容、PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。
- 本次沒有寫入 Wishbone control register。
- 本次沒有 program FPGA；因此 fresh HEAD SOF 只完成 compile/provenance，不能視為 current hardware 的 fresh HEAD runtime 證據。

## 實驗目的

1. 先重新確認 Step 2 Endpoint / MiniNIC / PTP packet path。
2. 再重新確認 Step 3 parent / signaling handshake。
3. 釐清前一輪 `GOT_EDGE_ENTRY delta=0`、`QUAL_REACHED_8` 與 `ACCEPT` 之間是否為 counter mapping 或 readout consistency 問題。
4. 在沒有可靠 Step 4 observability 前，不進行任何 Step 4 functional experiment。

## 執行的 read-only 測試

### Step 2 / Step 3 focused barrier

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 25 500 5
```

此腳本使用 validated mailbox read，並保留 invalid/timeout sample，不把單一 state snapshot 直接當成硬體失敗。

### Step 4 mapping audit

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 50 100 mapping
```

每片板每 100 ms 取樣 50 次，只讀取 source-backed 的六個欄位：

```text
REF_GOT_EDGE_ENTRY  = 0x001002F0
REF_QUAL8           = 0x00100268（使用 source 定義的 bits 31..16）
REF_ACCEPT          = 0x0010022C
FB_GOT_EDGE_ENTRY   = 0x001002F4
FB_QUAL8            = 0x0010026C（使用 source 定義的 bits 31..16）
FB_ACCEPT           = 0x00100230
```

### Dashboard smoke test

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl
```

用途是確認 invalid mailbox read、timeout 或 counter decrease 不會中止 Step 1～Step 6 後續輸出。

## Fresh compile provenance（compile-only，不是硬體驗證）

本輪在 pain 上以 exact HEAD 做了 clean firmware build 與 Quartus 17 clean compile。由於本輪禁止 program FPGA，以下 SOF 不能拿來解釋 current hardware runtime。

### Quartus

```text
Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition
```

### Master

```text
MIF SHA256 = 5e98dd12d887c5bacd21475906885fce9e525152689251733a14e2b0c75c7b7c
QSF SHA256 = cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f
SDC SHA256 = b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8
SOF SHA256 = 8a7e6a5881b9fba940ebbdef4d3dc15d2641dbde97827aaad7612b90448f42a8
Compile    = Full Compilation was successful
Timing     = TIMING_CLOSED=NO, WNS=-0.204 ns
```

### Slave

```text
MIF SHA256 = 801322fb8ff26001c015693c0eb432370a994489f566e68511c0a8f01ded1275
QSF SHA256 = c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437
SDC SHA256 = b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8
SOF SHA256 = 86b7b36f61417d1704e7deb09c4e36450ab353683e797d3504ce5bbc77675b05
Compile    = Full Compilation was successful
Timing     = TIMING_CLOSED=NO, WNS=-1.337 ns
```

`TIMING_CLOSED=NO` 與負 setup slack 是 compile evidence，不能被省略，也不能被改寫成 timing pass。

## Step 2 regression 結果

### Master

- accepted samples：25/25
- MAC：`02:00:22:33:44:01`
- MODE：`2`
- PTP：`6`
- PTP TX delta：`83`
- MiniNIC TX/RX：持續增加
- RXERR：`0`

### Slave

- accepted samples：25/25
- MAC：`02:00:22:33:44:02`
- MODE：`3`
- PTP：`9`
- PTP TX delta：`14`
- MiniNIC TX/RX：持續增加
- RXERR：`0`
- FOREIGN：`1/0`

這些 repeated samples 支持 Endpoint、MiniNIC 與 PPSI/PTP packet path 有活動。短窗口內 PTP TX 的單一 delta 不再被當成 hard fail。

## Step 3 regression 結果

Slave 25 個 accepted samples 中，主要 handshake evidence 為：

```text
FOREIGN       = 1/0
parent        = 1/0/1
RX message    = 0x1001
TX message    = 0x1000
LOCK          = 1/0
LOCK_ENABLE   = 4
```

`local_state=0 / next_state=0` 在本次 sample 中持續出現，腳本因此標記：

```text
STATE_EVIDENCE=READ_INCONSISTENT
```

這個 state snapshot 與 LOCK、SLAVE_PRESENT、LOCK_ENABLE evidence 不一致；依實驗規則，不能只因 state 欄位就宣稱 Step 3 hardware failure。Step 3 regression 以 repeated signaling evidence 判定為 PASS，但保留 state inconsistency caveat。

## Step 4 mapping audit 結果

### Master：DE5 [1-11.1]

```text
REF_GOT_EDGE_ENTRY delta = 0
REF_QUAL8_FIELD     delta = 0
REF_ACCEPT          delta = 0
FB_GOT_EDGE_ENTRY   delta = 0
FB_QUAL8_FIELD      delta = 0
FB_ACCEPT           delta = 0
```

所有六組 series 均為 50/50 valid、沒有 timeout 或 invalid read。

### Slave：DE5 [1-11.2]

```text
REF_GOT_EDGE_ENTRY delta = 0
REF_QUAL8_FIELD     delta = 14526
REF_ACCEPT          delta = 0
FB_GOT_EDGE_ENTRY   delta = 0
FB_QUAL8_FIELD      delta = 0
FB_ACCEPT           delta = 0
```

原始 `REF_QUAL8` 欄位由 `00000001` 變為 `38BE2651`；依 source mapping，只使用 bits 31..16 解讀，因此 field delta 為 `14526`。同一 series 的 raw 32-bit 值有 decrease/reset caveat，不能把 raw decrease 直接當成硬體錯誤。

### 觀察

1. Master 六組 counter 在本窗口沒有活動。
2. Slave 只有 source-defined `REF_QUAL8` 高 16-bit 欄位有活動。
3. GOT_EDGE_ENTRY、ACCEPT、FB QUAL8 沒有同步活動。
4. 因此目前仍無法建立完整的：

```text
DDMTD edge
  -> qualification
  -> accept
  -> tag/TRR/helper
```

5. 這個結果可以證明 observability chain 仍不一致，但不能單獨證明 SoftPLL functional algorithm 已失敗。

## Dashboard 結果

`read_wb_runtime.tcl` 在兩片板均完整印出 Step 1～Step 6，Quartus SignalTap 回報：

```text
Evaluation of Tcl script ... was successful
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

Master dashboard：Step 1 PASS、Step 2 PASS，其餘因 dashboard 的 focused gate 資料不足而顯示 NA。

Slave dashboard：Step 1 PASS、Step 2 PASS、Step 3 PASS、Step 4 error、Step 5/6 NA。`OCER=TIMEOUT` 與零 delta 事件被保留為 measurement warning/error evidence，但沒有造成 Tcl exception 或提前終止。

## 目前正式判定

```text
STEP1_REGRESSION       = PASS
STEP2_REGRESSION       = PASS
STEP3_REGRESSION       = PASS
STEP4_ALLOWED          = YES
STEP4_RESULT           = NOT_PASS / MEASUREMENT_INVALID
HARDWARE_FIRMWARE_FAIL = NOT_PROVEN
JTAG_DASHBOARD_ISSUE   = OBSERVED
```

Step 4 目前不能標示 PASS。原因是三組 counter mapping 尚未呈現可互相支持的完整活動鏈，而且本輪沒有 program fresh HEAD SOF，所以不能把 compile-only artifact 的狀態歸因到 current hardware。

## 結論

本次 read-only evidence 支持 Step 2 與 Step 3 regression 通過，因此 regression barrier 沒有阻擋後續 Step 4 研究。可是 Step 4 的 counter observability 仍然不足，且出現 Master 全部不動、Slave 只有 REF QUAL8 欄位活動的 asymmetric result。

目前最保守、證據支持的結論是：

> Step 4 尚未通過；現階段優先問題是 JTAG register/counter mapping 與 runtime observability consistency，尚不能宣稱是 FPGA/firmware/SoftPLL functional failure。

## 下一步

1. 保持所有 functional RTL、firmware、SoftPLL、DDMTD、DCO、SI5340 與 PHY 不變。
2. 請 reviewer 先檢查這次 mapping audit 的 source-backed interpretation，特別是 `QUAL_REACHED_8` 的 packed field 與 raw read decrease/reset。
3. 在 reviewer 確認 mapping 定義前，不 program、不修改功能，只能做更精確的 read-only source/register audit。
4. 若需要用 exact HEAD 做硬體驗證，必須另開明確的 program 實驗：先保存 programmer output、SOF checksum 與 fresh HEAD raw JTAG log，再單獨寫入新的實驗紀錄。

## Raw evidence

本次 raw logs 與 provenance 位於：

`docs/experiments/exp-step4-softpll-enable/raw/20260825/`

- `step2_step3_barrier_current_hardware.log`
- `step4_mapping_audit_current_hardware.log`
- `dashboard_current_hardware.log`
- `build_info_jtag_master_736ddec.txt`
- `build_info_jtag_slave_736ddec.txt`
- `quartus_master_compile_736ddec.log`
- `quartus_slave_compile_736ddec.log`
