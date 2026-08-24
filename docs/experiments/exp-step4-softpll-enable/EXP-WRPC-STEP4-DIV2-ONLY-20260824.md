# EXP-WRPC-STEP4-DIV2-ONLY-20260824

## 實驗識別

- 日期：2026-08-24
- Branch：`exp/step4-divide-input-ab`
- Source commit：`ed003c5ad4cbd34707a7ca97134b62947a9fed9c`
- 實驗名稱：DIV2-only SoftPLL DMTD A/B
- 實驗目的：在 `g_softpll_reverse_dmtds=false` 不變的前提下，單獨驗證
  `g_divide_input_by_2=true -> false` 是否能讓 Step 4 的 DMTD qualification
  與 downstream event chain 恢復。

## 唯一操作變因

相對於 control（`f88aa22`）只改變一個功能設定：

```text
g_softpll_reverse_dmtds = false       （保持 control）
g_softpll_divide_input_by_2 = false   （本輪 B）
```

沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、
PI gain、lock threshold、DCO、SI5340、PHY 或 firmware functional behavior。

為了將既有 `wr_core` 內部耦合設定拆開，本輪新增 top-level generic；其 default
仍為原本 DE5A 8-bit control 的 `true`，只有 Master/Slave diagnostic wrapper
明確 override 為 `false`。

## Build provenance

- pain checkout：exact detached HEAD `ed003c5ad4cbd34707a7ca97134b62947a9fed9c`
- Quartus：17.0.0 Build 595
- Master MIF SHA256：`cf0bf4cfea3b751eb1a6bb9ac6a4e8edae53a12852a2206a7432e05027abe905`
- Slave MIF SHA256：`0896bf06fc985b29a351631f8655d958bbee220620dc47e9b053f9b0a4df4d7f`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`dd3cb9676fe4d4846256b19de6245c0aa37f736fdd5539cb0edeb48bc14b365d`
- Slave SOF SHA256：`559bfdd97e37ef688de26c5609159522c597496a88e52db1a5bcb9633bad04c8`
- Master build：成功，`timing_closed=NO`
- Slave build：成功，`timing_closed=NO`

完整 provenance：

`raw/EXP-WRPC-STEP4-DIV2-ONLY-20260824-build-provenance.txt`

第一次 build 嘗試因 VHDL generic default expression 不合法而停止，沒有燒錄；
該原始 log 保留於：

`raw/EXP-WRPC-STEP4-DIV2-ONLY-20260824-build-master-initial-fail.log`

修正後的 commit 為 `ed003c5`，以上 SOF 均由該 exact commit clean build 產生。

## 燒錄結果

Master（`DE5 [1-11.1]`）：

- Programmer checksum：`0x30B406BA`
- `Configuration succeeded -- 1 device(s) configured`
- 0 errors、0 warnings
- 原始輸出：
  `raw/EXP-WRPC-STEP4-DIV2-ONLY-20260824-program-master.log`

Slave（`DE5 [1-11.2]`）：

- Programmer checksum：`0x30AFCBCB`
- `Configuration succeeded -- 1 device(s) configured`
- 0 errors、0 warnings
- 原始輸出：
  `raw/EXP-WRPC-STEP4-DIV2-ONLY-20260824-program-slave.log`

## Runtime 結果

燒錄後等待板卡穩定，執行：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 1000
```

完整原始輸出：

`raw/EXP-WRPC-STEP4-DIV2-ONLY-20260824-step123-focused.log`

### Master

- valid samples：`14/30`，invalid：`16`
- 有效樣本 MAC：`02:00:22:33:44:01`
- 有效樣本 `MODE=3`、`PTP=4`
- `RXERR=0`，MiniNIC counters 有活動
- `FOREIGN_META=1/0`，但未形成 Master `MODE=2/PTP=6` gate
- `STEP2_REGRESSION=FAIL`
- `STEP3_REGRESSION=FAIL`

### Slave

- valid samples：`16/30`，invalid：`14`
- 有效樣本 MAC：`02:00:22:33:44:02`
- 有效樣本 `MODE=3`、`PTP=4`，未達穩態 PTP=9
- `RXERR=0`
- Foreign metadata 在 `0/255` 與 `1/0` 間變化，parent flags 未成立
- `LOCK_ENABLE=0`，未觀測 `LOCK=0x1001` 或 `SLAVE_PRESENT=0x1000`
- `STEP2_REGRESSION=FAIL`
- `STEP3_REGRESSION=FAIL`

Quartus SignalTap/Tcl 本身成功完成，0 errors、0 warnings；但 JTAG sample
有效率不足且有效樣本狀態已顯示 regression，不能把這次結果解讀成 Step 4
硬體失敗。

### Regression barrier

```text
STEP1_REGRESSION = NOT_ACCEPTED
STEP2_REGRESSION = FAIL
STEP3_REGRESSION = FAIL
STEP4_ALLOWED    = NO
STEP4_RESULT     = NOT_MEASURED
```

因此本輪沒有執行 Step 4 T0/T1，也沒有宣稱 DMTD waveform、accepted event、
tag/TRR/IRQ 或 helper 的結果。

## 初步結論

DIV2-only 的 source isolation 已完成，但 fresh image 未保留既有 Step 1～3
runtime regression。相較於 control，`g_softpll_reverse_dmtds` 保持 false，
唯一 functional A/B 是 `g_softpll_divide_input_by_2=false`；然而本輪結果仍
顯示兩板進入不穩定/未完成初始化狀態。

這一輪不能證明「divide-by-2 是 Step 4 根因」，也不能證明它直接改寫 role。
目前可以證明的是：

```text
DIV2-only B configuration
    -> Step2/Step3 prerequisite regression
    -> Step4 blocked before measurement
```

證據分類：

- `STEP4_RESULT=NOT_MEASURED`
- `HARDWARE/FIRMWARE_FAILURE=NOT_PROVEN_AS_ROOT_CAUSE`
- `JTAG_MEASUREMENT_CAVEAT=YES`（Master/Slave invalid samples）
- `DIV2_ONLY_CONFIGURATION_ACCEPTED=NO`

## Next Step

保留本輪 fresh build/program/runtime 證據，先送 White Rabbit 討論確認。不要
在本輪結果上再疊加 reverse、polarity、threshold 或其他 SoftPLL 變因；下一輪
必須先決定如何恢復可靠的 Step 2/3 control，再重新驗證 Step 4。

## 第二次唯讀 focused retest

### 實驗名稱

`DIV2-only Step 1～3 focused regression retest`

### 時間與指令

- 日期：2026-08-24
- branch：`exp/step4-divide-input-ab`
- source HEAD：`ed003c5ad4cbd34707a7ca97134b62947a9fed9c`
- 指令：

  ```text
  quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 1000
  ```

- 本輪為 read-only retest，沒有重新編譯、沒有重新燒錄、沒有寫入 runtime
  control register。
- 完整 raw output：
  `raw/EXP-WRPC-STEP4-DIV2-ONLY-20260824-step123-retest.log`

### Retest 原始 gate 結果

```text
Master valid_samples=13 invalid_samples=17
Master PTP_TX_DELTA=9
Master STEP2_REGRESSION=FAIL
Master STEP3_REGRESSION=FAIL
Master STATE_EVIDENCE=READ_INCONSISTENT
Master state_idle=13 state_good=0

Slave valid_samples=15 invalid_samples=15
Slave PTP_TX_DELTA=46
Slave STEP2_REGRESSION=FAIL
Slave STEP3_REGRESSION=FAIL
Slave STATE_EVIDENCE=READ_INCONSISTENT
Slave state_idle=15 state_good=0
```

### Retest 觀察

- Master 有效樣本的 MAC 為 `02:00:22:33:44:01`，但 `MODE=3`、`PTP=4`，
  沒有重現要求的 `MODE=2`、`PTP=6` Master evidence。
- Slave 有效樣本的 MAC 為 `02:00:22:33:44:02`；前段多數樣本為
  `MODE=3`、`PTP=9`、`FOREIGN_META=1/0`，但也出現 `PTP=4`；
  `parent=0/0/0`、`LOCK_ENABLE=0`，沒有觀測到 `LOCK` 或
  `SLAVE_PRESENT` 訊號。
- 兩板 `RXERR=0`，且 MiniNIC/PTP counters 在有效樣本中有增加；這只能證明
  部分 packet activity，不能取代 Step 2/3 的 role、parent、signaling gate。
- `valid_samples` 與 `invalid_samples` 的比例顯示 mailbox snapshot 仍有明顯
  read inconsistency；因此本次結果同時包含硬體/firmware regression evidence
  與 JTAG measurement caveat。
- Quartus SignalTap/Tcl 執行成功，0 errors、0 warnings；這只證明診斷腳本完成，
  不代表 Step 2/3 通過。

### Retest 結論

第二次 focused retest 重現第一次結果，故不是單次偶發 sample。DIV2-only
configuration 目前不能作為 Step 2/3 regression pass，barrier 保持：

```text
STEP1_REGRESSION = NOT_ACCEPTED
STEP2_REGRESSION = FAIL
STEP3_REGRESSION = FAIL
STEP4_ALLOWED    = NO
STEP4_RESULT     = NOT_MEASURED
```

這仍不能單獨證明 `g_softpll_divide_input_by_2=false` 是根因，因為有效 JTAG
樣本與 invalid sample 混雜，且目前沒有在同一 image 上完成可接受的 Step 2/3
control evidence。下一步應先恢復並確認可靠的 Step 2/3 control baseline，
再重新做 Step 4 單一變因實驗。
