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

本節將在燒錄後的 read-only Step 1～3 regression 與 Step 4 T0/T1 量測完成後
補入。若 Step 2 或 Step 3 regression 失敗，本輪不得宣稱 Step 4 結果，並將
`STEP4_ALLOWED=NO`。

## 初步結論

目前只證明 exact commit 已 clean compile 並成功燒錄，尚未由 runtime 證明
DIV2-only 設定能恢復 Step 4。

## Next Step

等待板卡穩定後，先執行 focused Step 1～3 regression；只有全部 prerequisite
通過，才執行 Step 4 startup/T0/T1，觀察 D0 stable hit、accepted DMTD、
event/tag/TRR/IRQ、sequencer 與 helper activity。
