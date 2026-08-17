# EXP-WRPC-SLAVE-I2C-NACK-20260817

## 實驗名稱

Slave SI5340 I2C NACK 唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-I2C-NACK-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave 單一 RTL 觀測變因燒錄實驗

## 想驗證什麼

上一輪已看到 Slave DCO `completed_steps` 增加，但 `time_valid`、`SSTAT`、`UCNT` 與 `PSTAT.locked` 都沒有活動。現有 I2C controller 完全沒有取樣 ACK slot，因此需要區分：

1. SI5340 真的回 ACK，交易也真的可能被接受；或
2. 只是 FPGA FSM 自己走完，SI5340 實際回 NACK。

本輪只觀測 ACK，不改 SI5340 register data、page sequence、FINC/FDEC direction、WR role、PTP、PHY 或 Master。

## 相較 baseline 唯一修改

只修改兩個 Slave RTL 檔案：

- `quartus/jtag_runtime_diag/i2c_bus_controller_dco.v`
  - 在裝置位址、register address 與 write-data 的 ACK slot，於 SCL high 時取樣 SDA。
  - 若 SDA 維持 high，設定 sticky `oACK_ERROR`。
  - 原有 I2C state transition 與 transaction timing 不變。
- `quartus/jtag_runtime_diag/si5340a_controller_dco.v`
  - 將 `oACK_ERROR` 接到既有 `oDCO_DEBUG[31]`。

本輪成功判準不是 Slave 同步完成，而是取得可判讀的 `oDCO_DEBUG[31]`：

- `0`：在觀測期間沒有取到 NACK。
- `1`：至少有一個 ACK slot 取到 SDA high，表示存在 NACK 證據。

注意：`0` 仍不能單獨證明 SI5340 register 已生效；若為 `0`，還要搭配 helper/servo/clock response 判讀。

## Git / bitstream provenance

- Branch：`exp/master-9f-observability`
- Source commit：`e09ddbfec19deb39109cfe13be2513afce292147`
- Master 固定 baseline tag：`master-diagnostic-baseline-20260817`
- Quartus：Quartus Prime 17.0 Build 595
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- `i2c_bus_controller_dco.v` SHA-256：待 pain 同步後確認
- `si5340a_controller_dco.v` SHA-256：待 pain 同步後確認
- Slave SOF SHA-256：待 compile 後確認

## Compile 結果

待 pain 從 GitHub fetch `e09ddbf` 後，使用 Quartus 17.0 compile；compile-only 不視為硬體實驗成功。

## 燒錄結果

待 compile 成功後只燒錄 Slave `DE5 [1-11.2]`，Master 維持 known-good baseline。燒錄後立即補上：

```text
Programming cable:
JTAG ID:
Programmer checksum:
Configuration result:
```

## JTAG/runtime 原始結果

燒錄後保存於：

```text
artifacts/EXP-WRPC-SLAVE-I2C-NACK-20260817/
```

至少包含 programmer log、`read_wb_runtime.tcl`、`read_dco_state.tcl`、`read_dco_activity.tcl` 與 60 秒唯讀 time-series；並記錄 `oDCO_DEBUG[31]`、`completed_steps`、`helper_error`、`spll_locked`、`SSTAT`、`UCNT`、`time_valid`、`pps_valid`。

## Observation

待燒錄後填寫。若發現 NACK，將證據解讀為「SI5340 I2C transaction 未被裝置接受」，不直接歸因於 DDMTD 或 Master role。

## Conclusion

待燒錄後填寫。結論只可由 ACK/NACK raw evidence 與 Slave runtime time-series 支持。

## Next Step

若 NACK=1，先修正 SI5340 I2C 實體/位址/enable 路徑；若 NACK=0 但 helper 完全不動，再進入 register readback 或 clock frequency-effect 的單一變因實驗。Master role 永不在本輪或下一輪修改。
