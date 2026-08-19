# EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820`
- 日期：2026-08-20（Asia/Taipei）
- 實驗名稱：修正 DCO request 跨分頻 I2C 時脈的握手
- Git branch：`exp/step4-softpll-enable`
- 功能變更 commit：`2cf8276769301c195e63aff76caf18082be8688d`
- 實驗狀態：已提交並 push；等待 pain 以此 exact commit clean build、program 與 runtime 驗證

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

本節由 pain 以 exact commit 建置後補入；若 compile 失敗或未燒錄，也要保留結果，不得寫成硬體成功。

- Quartus version：待補
- Master MIF SHA256：待補
- Slave MIF SHA256：待補
- Master SOF SHA256：待補
- Slave SOF SHA256：待補
- Master programmer checksum：待補
- Slave programmer checksum：待補
- build/program 原始 log：待補

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

1. pain 從 GitHub fetch 並 checkout `2cf8276769301c195e63aff76caf18082be8688d`。
2. clean firmware build、`quartus_sh --clean`、Master/Slave clean compile。
3. 保存 MIF/SOF hash 與完整 programmer output。
4. 燒錄後立即補齊本紀錄，再執行 read-only JTAG snapshot 與 time-series。
