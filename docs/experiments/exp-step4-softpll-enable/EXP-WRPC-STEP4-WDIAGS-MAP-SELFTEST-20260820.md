# EXP-WRPC-STEP4-WDIAGS-MAP-SELFTEST-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-WDIAGS-MAP-SELFTEST-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- 功能變更 commit：`a8f08b737ae5897bf278572972e8ace572298549`
- 實驗狀態：**mapping self-test PASS；fresh SOF 仍是 `a8f08b7` build，decode script 為 `f5411fa`**

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

本輪使用 exact commit 完成 clean firmware build、Quartus clean compile，並以該次 fresh SOF 進行燒錄：

- Git commit / branch：`a8f08b737ae5897bf278572972e8ace572298549` / `exp/step4-softpll-enable`
- Quartus：`17.0.0 Build 595`
- Master MIF SHA256：`c08542f4cf3bddecf35b29537dd86764ae37a7198e3dd8ae9ba91b36c0015468`
- Slave MIF SHA256：`f1c6272d8b12448da87d435a5ce7a0e7245c788a532d6bebb388a1dbb07434a8`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`d6d50dc82caf8e6ea569c7c8210d1accbf6ba4df57cf8a9496daa26e1b6ade64`
- Slave SOF SHA256：`00a2bb2d0f938befd8fa47cbd55a9289b15a06cb3af3631d0231033d16439cb0`
- Master/Slave compile：`Full Compilation was successful`；兩者 timing report 均為 `TIMING_CLOSED=NO`
- Master Programmer：成功，checksum `0x30A5EF0D`，原始輸出見 `program_master_20260820.log`
- Slave Programmer：成功，checksum `0x30A4A104`，原始輸出見 `program_slave_20260820.log`
- 完整 provenance 檔案：`build_info_jtag_master.txt`、`build_info_jtag_slave.txt`、各 build/compile log

## JTAG runtime 原始結果

燒錄後首次只讀 mapping self-test 原始輸出已保存於：

- `jtag_wdiags_mapping_selftest_20260820.log`
- 執行指令：`quartus_stp -t scripts/jtag/read_wdiags_mapping_selftest.tcl 1000`
- Master Programmer 結果：`Configuration succeeded`，checksum `0x30A5EF0D`
- Slave Programmer 結果：`Configuration succeeded`，checksum `0x30A4A104`
- 必要時的 Step 1～4 time-series 原始輸出

修正判定重試後的第二次原始輸出：

- `jtag_wdiags_mapping_selftest_20260820_f5411fa.log`
- decode script commit：`f5411fa23e694c61567ef98f87f0d7f6f04d2307`

## Observation

首次結果：

| 板卡 | Magic A/B | Counter | Inverse | 初步判定 |
|---|---|---:|---:|---|
| Master | 正確 | `0x75 -> 0x76` | BEGIN 正確；END=`0x00000076` | FAIL；END inverse 不等於 `~counter` |
| Slave | 正確 | `0x47 -> 0x48` | `~0x48 = 0xFFFFFFB7` | PASS |

第二次結果：Master 與 Slave 均出現 `begin_valid=1`、`end_valid=1`。Master BEGIN 的第一次讀列因 `MAGIC_B` 不完整而標為 `valid=0`，第二次重讀通過；其後 Master END 與 Slave 的 BEGIN/END 均通過。這表示原始問題是 Wishbone/JTAG 逐欄讀取時可能跨 refresh 的不一致列；重試判定可以排除該列，不能把 invalid 列拼接進結論。mapping self-test PASS 只代表新增欄位可被正確觀測，不代表 SoftPLL 已 lock。

## Conclusion

雙板 mapping self-test PASS。這個實驗只證明新增 WDIAGS observability 的位址與 word mapping 可用，不代表 SoftPLL lock、`time_valid=1` 或 Step 4 PASS。

## Next Step

使用同一份 fresh SOF 與已驗證的 mapping decode script，進行 raw helper arithmetic correlation；仍只讀取並保存 ref/tag/IRQ/TRR/helper/PI/DCO 相關欄位，不修改 SoftPLL algorithm 或 DCO functional behavior。
