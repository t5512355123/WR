# 實驗紀錄：SI5340 讀回資料有效握手修正

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-READBACK-HANDSHAKE-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 硬體 source commit：`41024ca880f7b81c5599e4cfbe07021dc7fe2c13`
- pain 實際 checkout/build commit：`543c5b3b696ef7cb21f6cc7150c71d45bc358740`

## 這次想驗證什麼

確認上一輪 SI5340 readback 讀到 `0x00` 是否只是因為 I2C controller 的 read-data-valid 脈波太短，導致較快的上層 `iCLK` readback FSM 沒有在正確時機取到資料。這一輪不恢復 DPLL，也不修改 PHY、PTP filter、servo 演算法、SoftPLL threshold 或 SI5340 transaction 內容。

## 相較 baseline 唯一修改了什麼

相較於 `ce6cad0` 所記錄的 `EXP-WRPC-SI5340-READBACK-20260817`：

1. 在 `i2c_bus_controller_dco.v` 增加 sticky `i2c_read_data_valid`。
2. 讀取完成後保持 valid，直到下一筆 I2C transaction 開始，避免上層跨 clock domain 漏掉單週期 ready pulse。
3. `si5340a_controller_dco.v` 的 readback FSM 改用 sticky valid 取樣；原本的 legacy ready pulse 與 DCO write path 保持不變。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：本輪未重新燒錄 Master；沿用已燒錄 baseline
- Slave MIF SHA-256：`4dbd34e41617c6605e5e05406b1b373dcbce1e9781ec89ee9006fa583e3b327c`
- Slave SOF SHA-256：`e0eab0f2cd394fcbaf4b53bde233db5289e4b68a2348599da6460815f39abcb2`
- Compile log SHA-256：`e0103c4e77e7fa3d30cd1fa764df0bc7f461edc1bf0c42a87db400d83c788a8b`
- Full Compilation：successful，0 errors；Fitter successful
- Timing：setup `-0.404 ns`、hold `-3.501 ns`、recovery `0.920 ns`、removal `0.330 ns`
- Timing closure：`NO`；unconstrained clocks `4`、inputs `881`、outputs `85`

## 燒錄結果

已僅燒錄 Slave `DE5 [1-11.2]`：

- programmer checksum：`0x30A1B8A0`
- JTAG ID：`0x02E660DD`
- configuration：`succeeded`
- Quartus programmer：0 errors、0 warnings
- 時間：2026-08-17 08:51:41 開始，08:51:59 結束（Asia/Taipei）
- 原始 programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-HANDSHAKE-20260817/program.log`
- programmer log SHA-256：`979f59294fca42dda99c92ea1001318ffbbe4c4d565789c0da238180ebf83cef`

## JTAG/runtime 原始結果

1. `read_dco_diag.tcl 1000`：JTAG/SignalTap evaluation successful；Master 因本輪未燒錄診斷版而回報沒有 probe，Slave readback 如下：

```text
DCO_I2C_ACK transactions=00EB errors=0000
DCO_I2C_READBACK state=5 done=1 page3_0039=00 page0_001D=00 current_page=00 raw=0000000000000015
```

- readback log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-HANDSHAKE-20260817/dco_readback.log`
- readback log SHA-256：`d0186348d5ea949fdaecf5d2d9800d8661e883856738e2ebeb94f7d56f46ac59`

2. `read_wb_timeseries_session.tcl 60 1000 3`：`SESSION_TIME_SERIES_DONE`，Quartus SignalTap evaluation successful，0 errors、0 warnings。

- runtime log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-HANDSHAKE-20260817/runtime_60s.log`
- runtime log SHA-256：`00ac663d6f83f1f0e88cbcc57940ce16c1b1d7a116f6d6df84e9c9a2302f4f49`
- Master：60/60 accepted；可採信 frame 維持 `status_low=FF`、`link_up=1`、`time_valid=1`、`pps_valid=1`
- Slave：56/60 accepted、4/60 rejected；可採信 frame 維持 `status_low=CF`、`link_up=1`、`SSTAT=0x00000001`、`PSTAT.locked=0`、`spll_locked=0`、`time_valid=0`、`pps_valid=0`
- Slave parent/servo：`foreign_count=1`、`parent_is_wr=1`、`parent_calibrated=1`，`REF_COUNT`、`TAG_COUNT`、`UCNT` 有活動；`WR_LOCK` 顯示 `result=1` 但 `spll_locked=0`、`unlocked=883785`、`calibration_fail=0`

## Observation

1. ACK telemetry error count 是 `0`，目前沒有 NACK 證據。
2. readback FSM 完成，但兩個欄位仍為 `0x00`；sticky valid 沒有改變讀值，因此目前仍不能視為 register 真值。
3. Slave accepted frame 從上一輪 `1/60` 提升到 `56/60`，支持 sticky valid 改善了觀測跨 clock domain 的可採信率；這是 observability 改善，不是 WR synchronization 成功。
4. Slave 的 link、parent、PTP/servo activity 存在，但 `SSTAT=1`、`PSTAT.locked=0`、`spll_locked=0`、`time_valid=0`。

## Conclusion

本輪沒有完成 Slave WR synchronization。證據支持的結論是：

- bitstream 已成功配置，且 SI5340 I2C transaction 目前沒有觀察到 NACK。
- sticky valid 修正提高了 Slave runtime frame 的接受率，但沒有讓 SI5340 readback 產生非零值，也沒有讓 Slave 取得 SoftPLL lock。
- accepted frame 仍沒有 `PSTAT.locked=1`、`time_valid=1` 或 `pps_valid=1`；因此不能宣稱兩台 DE5a 已同步。

## Next Step

下一輪不重複同一個 sticky valid 修正；改為離線核對 I2C read transaction 的 SDA sampling、`read_data_tmp` shift 時序、page select 與 SI5340 register semantics，設計下一個能直接證明「讀回 bus byte 是否正確」的單一觀測變因。不得同時恢復 DPLL、修改 PHY、PTP filter、servo 或 SoftPLL threshold。
