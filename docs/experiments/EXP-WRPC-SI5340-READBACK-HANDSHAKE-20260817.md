# 實驗紀錄：SI5340 讀回資料有效握手修正

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-READBACK-HANDSHAKE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 預定硬體 source commit：`41024ca880f7b81c5599e4cfbe07021dc7fe2c13`

## 這次想驗證什麼

確認上一輪 SI5340 readback 讀到 `0x00` 是否只是因為 I2C controller 的 read-data-valid 脈波太短，導致較快的上層 `iCLK` readback FSM 沒有在正確時機取到資料。這一輪不恢復 DPLL，也不修改 PHY、PTP filter、servo 演算法、SoftPLL threshold 或 SI5340 transaction 內容。

## 相較 baseline 唯一修改了什麼

相較於 `ce6cad0` 所記錄的 `EXP-WRPC-SI5340-READBACK-20260817`：

1. 在 `i2c_bus_controller_dco.v` 增加 sticky `i2c_read_data_valid`。
2. 讀取完成後保持 valid，直到下一筆 I2C transaction 開始，避免上層跨 clock domain 漏掉單週期 ready pulse。
3. `si5340a_controller_dco.v` 的 readback FSM 改用 sticky valid 取樣；原本的 legacy ready pulse 與 DCO write path 保持不變。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：待 compile 後填寫
- SDC SHA-256：待 compile 後填寫
- Master MIF SHA-256：待 compile 後填寫；本輪不重新燒錄 Master
- Slave MIF SHA-256：待 compile 後填寫
- Slave SOF SHA-256：待 compile 後填寫
- Compile log SHA-256：待 compile 後填寫
- Full Compilation：待 compile 後填寫
- Timing：待 compile 後填寫

## 燒錄結果

待 compile 完成後，僅燒錄 Slave `DE5 [1-11.2]`。本節必須填入：

- programmer checksum
- JTAG ID
- configuration result
- Quartus programmer error/warning
- 燒錄時間
- 原始 programmer log 路徑與 SHA-256

## JTAG/runtime 原始結果

預定執行：

1. `read_dco_diag.tcl`：確認 ACK、readback state/done/data。
2. `read_wb_timeseries_session.tcl 60 1000 3`：確認 readback 修正沒有破壞 Slave runtime，並觀察 `SSTAT`、`PSTAT.locked`、`time_valid`、`pps_valid`、parent、servo activity。

原始 log 路徑與 SHA-256：待實驗完成後填寫。

## Observation

待燒錄與 runtime 觀測後填寫。特別記錄：

- `DCO_I2C_READBACK state/done/page3_0039/page0_001D`
- ACK transactions/errors
- Master/Slave accepted/rejected sample 數量
- Slave `SSTAT[11:8]` 是否進入 4 或 5
- Slave `PSTAT.locked`、`spll_locked`、`time_valid`、`pps_valid`
- `REF_COUNT`、`TAG_COUNT`、`UCNT` 是否持續增加

## Conclusion

待依燒錄與原始 JTAG/runtime 證據填寫。即使 readback 值不再是 `0x00`，也只能證明 readback observability 改善；只有看到 Slave 長時間穩定 `PSTAT.locked=1`、`time_valid=1`、`pps_valid=1`，才可宣稱同步成功。

## Next Step

若 readback 仍為 `0x00`，先停止功能修改，改查 I2C read transaction 的 SDA sampling、page select 與 SI5340 實際 register semantics。若 readback 正常但 Slave 仍未 lock，依證據再選擇下一個單一變因；不得同時恢復 DPLL 與修改 servo/PHY。
