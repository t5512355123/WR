# EXP-WRPC-DMTD-REVERSE-20260817：反向 DDMTD 取樣 A/B 實驗

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DMTD-REVERSE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/jtag-runtime-observability`
- Git commit：`b927e8795a4f45ab80a2e7b1c5d9c3ad475c5415`
- 前一個 baseline commit：`f749a5c8b78a96d31d516cb2a7d08185e40191e`

## 這次想驗證什麼

確認目前 Slave 沒有 `time_valid`、沒有 SoftPLL lock，且 `TAG_VALID/TRR_WRITE` 幾乎沒有有效事件，是否與 DDMTD 的取樣方向及 8-bit PCS 輸入除 2 設定有關。

## 相較 baseline 唯一修改

只在 Master 與 Slave 的 `xwr_core` generic map 加入：

```vhdl
g_softpll_reverse_dmtds => true
```

其他項目均維持 baseline：

- Master/Slave 系統時鐘仍為 62.5 MHz。
- QSFP-A lane 0、PHY line rate、reference clock、DMTD clock、reset 與韌體均未修改。
- 沒有改 PTP、servo、SI5340、PPS 設定或 JTAG 診斷工具。

本設定使 DDMTD offset clock 改由 measured/RX clock 取樣；依 `dmtd_with_deglitcher.vhd` 的註解，這是與 direct mode 功能等價的另一種取樣方向，並會改變 8-bit PCS 的 input divide-by-2 條件。

## Build 證據

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master：`Full Compilation was successful`、Fitter successful、`0 errors`
  - QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
  - SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
  - MIF SHA-256：`38ecd737b1b228d3c618ad7f9fada44b1814eec1d4d9a61a257bcf25ac57b0f4`
  - SOF SHA-256：`795b797184ebcb71821ee94667cd8cd3deca3e194667511d8eeac9f02b0275e6`
  - Fitter checksum：`0x30A3010A`
  - Worst setup slack：`-0.177 ns`
  - Worst hold slack：`-3.493 ns`
  - `TIMING_CLOSED=NO`
- Slave：`Full Compilation was successful`、Fitter successful、`0 errors`
  - QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
  - SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
  - MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
  - SOF SHA-256：`e020cb02a21693a656d4c3d93ce7a1e2d8b1593adca4b079474f4ff4d09ade99`
  - Fitter checksum：`0x309FCFD1`
  - Worst setup slack：`-0.400 ns`
  - Worst hold slack：`-3.460 ns`
  - `TIMING_CLOSED=NO`

完整 build identity 保存於 pain：

- `/home/b10504072/04_WR/build/build_info_jtag_master.txt`
- `/home/b10504072/04_WR/build/build_info_jtag_slave.txt`
- `/home/b10504072/04_WR/build/quartus_jtag_master_compile.log`
- `/home/b10504072/04_WR/build/quartus_jtag_slave_compile.log`

## 燒錄結果

### Master

- Programmer cable：`DE5 [1-11.1]`
- 原始輸出中的 SOF checksum：`0x30A3010A`
- `Configuration succeeded -- 1 device(s) configured`
- `Quartus Prime Programmer was successful. 0 errors, 0 warnings`

### Slave

- Programmer cable：`DE5 [1-11.2]`
- 原始輸出中的 SOF checksum：`0x309FCFD1`
- `Configuration succeeded -- 1 device(s) configured`
- `Quartus Prime Programmer was successful. 0 errors, 0 warnings`

燒錄原始 log：

- Master：`build/artifacts/EXP-WRPC-DMTD-REVERSE-20260817/master_program.log`
  - SHA-256：`0f40a612c91323074b7f4fd406b47f461dffbbac1c9f70d44e37c9f644535272`
- Slave：`build/artifacts/EXP-WRPC-DMTD-REVERSE-20260817/slave_program.log`
  - SHA-256：`fa8c5dc03124c09008fc6c1a987a177feb613cd493179c880733ef62e1304405`

## JTAG/runtime 原始結果

使用既有唯讀 JTAG 工具讀取，沒有寫入 `WDIAGS_CTRL.DATA_SNAPSHOT`、PHY、servo 或 SoftPLL 設定。

### 燒錄後 snapshot

- Master status 曾出現 `...82FF`，之後為 `...82EF`，未形成兩端穩定同步狀態。
- Slave status 為 `...82CF`。

### 60 秒 SoftPLL 原始讀值

Master 與 Slave 的完整輸出保存於：

- `build/artifacts/EXP-WRPC-DMTD-REVERSE-20260817/raw_60s.log`
  - SHA-256：`d2e78a379170251294e6a42a233a09d9bd971abf7558e9b3080ff1802b07c421`

代表性的 raw 結果：

```text
Master RAW_CORE: CTRL=00000001 SSTAT=00000001 PSTAT=00000001 PPS_ESCR=00000000
Master RAW_LOCK: RESULT=00000000 UNLOCKED=00000000 HELPER=00000000 MAIN=00000000
Master RAW_COUNTER: TAG_VALID=00000000 TRR_WRITE=00000000 ...

Slave RAW_CORE: CTRL=00000001 SSTAT=00000001 PSTAT=00000001 PPS_ESCR=00000080
Slave RAW_LOCK: RESULT=00000000 UNLOCKED=00000000 HELPER=00000000 MAIN=00000000
Slave RAW_COUNTER: TAG_VALID=00000000 TRR_WRITE=00000000 ...
```

status 的低位仍顯示 Slave `time_valid=0`、`pps_valid=0`；`PSTAT=1` 對應目前沒有可宣稱的 SoftPLL lock。`TAG_VALID` 與 `TRR_WRITE` 在 60 秒前後仍為 0，沒有形成有效 DDMTD tag 流。

燒錄後第一次 snapshot 與 raw 讀值保存於：

- `build/artifacts/EXP-WRPC-DMTD-REVERSE-20260817/runtime_after_program.log`
  - SHA-256：`1bf5f0c2ff3b432c61f16415e00bd6867ab87a86c257ef7b63c98473eee77554`
- `build/artifacts/EXP-WRPC-DMTD-REVERSE-20260817/raw_after_program.log`
  - SHA-256：`da2d5f168d3e8fe26af36839cb97bd71a1597a7bb28790da09134c0e974509ff`

## Observation

1. Quartus compile、Fitter 與兩片 FPGA 燒錄都成功，所以本次變更沒有造成建置或 configuration failure。
2. Reverse-DMTD 模式沒有讓 `TAG_VALID` 或 `TRR_WRITE` 在 60 秒內開始穩定增加。
3. Slave 的 PTP/runtime 仍有活動，但 `PSTAT.locked=0`、`time_valid=0`、`pps_valid=0`。
4. 因此目前不能把問題解釋成單純的 DDMTD 正反向選擇；至少「切換 reverse DMTD」本身沒有解決問題。
5. 目前最需要查的是：DMTD clock 的實際來源與相位/頻率是否符合 SoftPLL 期望，以及 Arria 10 PHY 是否提供真正可用的 sampled RX clock。僅把同一條 `wr_rx_clk` 同時接到 `phy_rx_rbclk_i` 和 `phy_rx_rbclk_sampled_i`，不等同於產生外部 sampled DDMTD clock。

## Conclusion

本實驗的證據只支持以下結論：

> **`g_softpll_reverse_dmtds => true` 沒有使目前 DE5a Slave 完成 SoftPLL lock 或 White Rabbit time validity；目前同步仍未成功。**

本實驗不能證明 PHY、DMTD wiring 或 reset 中哪一項是最終根因，也不能宣稱「reverse mode 一定不可用」。

## Next Step

下一輪只做一件事：不再改 reverse mode，先對照 Arria 10 transceiver/PHY 的實際 `rx_sampled` 輸出與目前 `g_records_for_phy` 設定，確認是否存在真正的 external sampled RX clock。接著以唯讀 JTAG 觀測 `TAG_VALID/TRR_WRITE`、`SSTAT`、`PSTAT` 與 `UCNT`，再決定要修正 sampled-clock wiring，或只調整 DMTD clock source。

在下一次燒錄前，仍須先建立新的 commit；燒錄後立即新增對應的實驗紀錄。

## 完整證據位置

所有本次編譯、燒錄與 JTAG 輸出均保存在 pain：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DMTD-REVERSE-20260817/
```

