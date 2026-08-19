# EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820`
- 日期：2026-08-20（Asia/Taipei）
- 實驗名稱：修正 DCO request 跨分頻 I2C 時脈的握手
- Git branch：`exp/step4-softpll-enable`
- 功能變更 commit：`2cf8276769301c195e63aff76caf18082be8688d`
- 實驗狀態：exact commit 已 clean build、program；等待燒錄後 runtime 驗證

## 這次想驗證什麼

確認 Step 4 的 SoftPLL correction request 是否能從 `xwr_core` 的 HPLL DAC request，經過 top-level DCO wrapper，真正啟動 SI5340 的 I2C runtime transaction 並完成一個 DCO step。

這不是要驗證 `spll_locked=1` 或 `time_valid=1`；本輪只先驗證：

```text
helper correction request
    -> DCO runtime request accepted
    -> I2C bus transaction starts and returns idle
    -> completed DCO step count increases
```

## 相較 baseline 唯一修改

只修改：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`。

現象基線為 `edd1259` fresh SOF：DCO debug 長期顯示：

```text
rt_state=2  bus_state=0  BUSY=1  STEP=0  ERROR=0
```

source audit 發現 outer state machine 使用 50 MHz `iCLK`，但 `i2c_bus_controller_dco` 使用 `clock_divider` 產生的較慢 clock。原本 state 1、3、5 看到 `runtime_start` 後立即前進，`bus_start` 可能只存在一個 50 MHz cycle，分頻後的 I2C domain 可能漏採樣。

本輪唯一修改是：

- state 1 改為等待 `bus_state=1` 後才進 state 2。
- state 3 改為等待 `bus_state=1` 後才進 state 4。
- state 5 改為等待 `bus_state=1` 後才進 state 6。

這讓 `runtime_start/bus_start` 在 request state 保持有效，直到 I2C controller 的 busy indication 回來。沒有修改 Master/Slave role、startup command、PHY、PTP、WR signaling、SoftPLL 演算法、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 register sequence。

## 預期結果

若跨時脈 request pulse 確實是第一個 blocker，預期 Slave 的 JTAG correlation 會從：

```text
rt_state=2  bus_state=0  STEP=0
```

變成可以觀察到：

- `bus_state` 先變為 1，再回到 0。
- `rt_state` 能完成 1 到 6 的三段 transaction。
- `STEP` 增加。
- `DCO_ERROR=0`。
- `DAC_HPLL` 與 SI5340 runtime activity 有可追溯變化。

若仍停在 state 1 且 `bus_state=0`，則表示問題不是單純的 request 保持，下一步要檢查 I2C controller enable、clock divider、SDA/SCL 或 static controller ready；不能直接宣稱 SI5340 或光路故障。

## 建置與燒錄 provenance

pain 是從 GitHub 的 exact commit `4d96eb4c5e9e73276dca45853a4995a7657e459` 建置；沒有使用 historical SOF。兩張板都先執行 clean build，Quartus fit 成功，但 timing 尚未 closure，這個限制必須與功能觀察分開記錄。

- Git branch：`exp/step4-softpll-enable`
- Git HEAD：`4d96eb4c5e9e73276dca45853a4995a7657e459`
- Quartus version：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- 共用 SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`5ab5d5f797c056ceac7a371786dd2647ce75be5cd3b8658a3d29479c64c9b857`
- Slave MIF SHA256：`3d3c351b616d80bb49ad11869a1c09cde7cf9209ff154f4102b2da24afdf3982`
- Master SOF SHA256：`e0ef350b260034c7d4c2abe24bde330ee368f7f50f3b3973953966d2c6ae0ffa`
- Slave SOF SHA256：`88940c4788c7a09ade00c81736155d1404d9fe2a5c152085f6cae60441e8b770`
- Master compile：`Full Compilation was successful`；worst setup slack `-0.180 ns`；worst hold slack `-3.468 ns`
- Slave compile：`Full Compilation was successful`；worst setup slack `-0.176 ns`；worst hold slack `-3.488 ns`
- Master programmer checksum：`0x30A36FF4`；`Configuration succeeded`；`0 errors, 0 warnings`
- Slave programmer checksum：`0x309E949B`；`Configuration succeeded`；`0 errors, 0 warnings`
- 原始附件目錄：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820/`
- build log：`build_jtag_master.log`、`build_jtag_slave.log`
- hash/build info：`sof_mif_hashes_20260820.txt`、`build_info_jtag_master.txt`、`build_info_jtag_slave.txt`
- programmer log：`program_jtag_master_20260820.log`、`program_jtag_slave_20260820.log`

本次沒有執行 reboot，也沒有觀察到 stall 或連線中斷。

## JTAG runtime 原始結果

燒錄後立即補入：

- `read_wb_runtime.tcl` 原始輸出：待補
- time-series 原始輸出：待補
- DCO correlation 原始輸出：待補

至少記錄 Master/Slave 的 CPU marker、PHY/link、MAC、MODE、PTP、Foreign Master、`LOCK_ENABLE`、`SPLL_STATE`、`REF/TAG/IRQ/TAG_VALID/TRR_WRITE/UCNT`、`DCO_DEBUG`、`STEP`、`BUSY`、`ERROR` 與 DAC shadow。

## Observation

待 pain 完成 exact commit 的 clean build、program 與 JTAG observation 後補入。

## Conclusion

目前只能確認 source-level 的單一握手變因已提交、push，不能在未燒錄前宣稱 Step 4 通過。

## Next Step

1. 已完成 exact commit 的 clean firmware build、`quartus_sh --clean`、Master/Slave clean compile。
2. 已完成兩張板的 program，接著只做 read-only JTAG snapshot 與 time-series。
3. 依 JTAG 實測判斷這個握手修正是否讓 DCO request/transaction/step activity 恢復；不以 `PSTAT.locked=1` 作為本輪必要條件。
