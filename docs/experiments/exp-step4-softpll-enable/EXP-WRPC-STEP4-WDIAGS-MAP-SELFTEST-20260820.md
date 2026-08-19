# EXP-WRPC-STEP4-WDIAGS-MAP-SELFTEST-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-WDIAGS-MAP-SELFTEST-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- 功能變更 commit：`2276fec8c9103f508216a40393af066c5927589b`
- 實驗狀態：**準備中；尚未編譯、燒錄或宣稱任何 runtime 結果**

## 這次想驗證什麼

先驗證新增的 WDIAGS helper-correlation 位址是否真的能從：

```text
firmware wdiag_write()
    -> WDIAGS DPRAM
    -> Wishbone mailbox
    -> JTAG read
```

正確傳遞，排除 register alias、位址超出 DPRAM 或 word 對齊錯誤。只有這個 mapping gate 通過後，才把 `tag_d0`、`p_adder`、`p_setpoint` 與 helper error 的數值拿來作功能性推論。

## 相較 baseline 的唯一修改

本輪只增加 observability self-test，不改 WR control behavior：

1. WDIAGS DPRAM 深度由 75 words 擴充到 79 words，涵蓋 `0x000..0x138`。
2. firmware 每次診斷 refresh 寫入：
   - `0x12C = 0xA5A5122C`
   - `0x130 = 0xA5A51330`
   - `0x134 = mapping counter`
   - `0x138 = bitwise NOT(mapping counter)`
3. 新增 JTAG 唯讀腳本 `scripts/jtag/read_wdiags_mapping_selftest.tcl`。

沒有修改：

- Master/Slave role 或 MAC
- PHY、Simple Word Alignment、PTP/PPSI
- WR signaling
- SoftPLL sequence、PI gain、lock threshold、DDMTD polarity
- DCO gain、SI5340 演算法或 I2C 行為

## 預期 PASS 條件

兩張板都必須在兩次讀取中得到：

```text
MAGIC_A = A5A5122C
MAGIC_B = A5A51330
COUNTER_END != COUNTER_BEGIN
INVERSE_END = bitwise_not(COUNTER_END)
```

且 `PTP_META`、PTP state 與 status probe 仍可正常讀取。若 magic word 或 counter/inverse 不符合，則本輪只能判定為 **WDIAGS mapping NOT PASS**，不能繼續解讀 helper arithmetic。

## 建置與燒錄 provenance

本節在 exact commit 完成 clean firmware build、Quartus clean compile、program 後立即補齊：

- Git commit / branch
- Master/Slave MIF SHA256
- Master/Slave QSF 與 SDC SHA256
- Master/Slave SOF SHA256
- Quartus version
- firmware build log
- Quartus compile log
- programmer 原始輸出與 checksum

## JTAG runtime 原始結果

本節在燒錄後立即補上：

- `read_wdiags_mapping_selftest.tcl` 原始輸出
- `read_wb_runtime.tcl` 原始輸出
- 必要時的 Step 1～4 time-series 原始輸出

## Observation

待 exact commit fresh build/program 後填寫。判讀時只採用有完整 mailbox/JTAG frame 的資料；若跨 refresh 讀取造成 torn frame，該列標為 invalid，不自行拼接。

## Conclusion

待 runtime 結果填寫。這個實驗的成功只代表 JTAG observability mapping 正確，不代表 SoftPLL lock、`time_valid=1` 或 Step 4 PASS。

## Next Step

若 mapping PASS，再以同一份 fresh bitstream 做 raw helper arithmetic correlation；若 mapping FAIL，先修正 address/window/word alignment，暫停任何 SoftPLL algorithm 或 DCO functional 修改。
