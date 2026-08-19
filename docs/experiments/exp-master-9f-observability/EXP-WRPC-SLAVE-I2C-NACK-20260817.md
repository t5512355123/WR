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
- `i2c_bus_controller_dco.v` SHA-256：`d04cac3f4eb9785d3552cf9f78ae85765a604fa730c78fc89cbe7eb11b9bf3cc`
- `si5340a_controller_dco.v` SHA-256：`a64a24dea63ff6656520efaa19a5c406540e05f6a8bc03b50cd1ee170786695e`
- Slave SOF SHA-256：`c7c0db469b9d5908b7f21320d7a8ca699f86aa29fff2f2ede9685b164b401bae`

## Compile 結果

pain 從 GitHub fetch `e09ddbf` 後，使用 Quartus 17.0 Build 595 完成完整 compile：

```text
Quartus Prime Full Compilation was successful. 0 errors, 268 warnings
Fitter: successful, 0 errors, 17 warnings
Assembler: successful, 0 errors, 1 warning
TimeQuest: successful, 0 errors, 7 warnings
```

時序報告仍有 requirement warning；本次 compile 的 slow corner 摘要包含 setup slack `-0.175 ns`、hold slack `-3.552 ns`。因此這是可產生 SOF 的 compile 結果，不是 timing closure，也不代表硬體同步成功。

## 燒錄結果

compile 成功後只燒錄 Slave `DE5 [1-11.2]`，Master 維持 known-good baseline。燒錄時間為 2026-08-17 23:28（Asia/Taipei）：

```text
Programming cable: DE5 [1-11.2]
JTAG ID: 0x02E660DD
Programmer checksum: 0x30A2C557
Configuration result: Configuration succeeded -- 1 device(s) configured
Quartus Programmer: successful, 0 errors, 0 warnings
```

原始 programmer log：

```text
artifacts/EXP-WRPC-SLAVE-I2C-NACK-20260817/exp_wrpc_slave_i2c_nack_20260817_program.log
SHA-256: e02e16d6e214fdd45c59ffd3b904d3d2a17c31e3d6e217c1de5a48d779aae207
```

## JTAG/runtime 原始結果

燒錄後保存於：

```text
artifacts/EXP-WRPC-SLAVE-I2C-NACK-20260817/
```

至少包含 programmer log、`read_wb_runtime.tcl`、`read_dco_state.tcl`、`read_dco_activity.tcl` 與兩段 30-sample 唯讀 time-series；並記錄 `oDCO_DEBUG[31]`、`completed_steps`、`helper_error`、`spll_locked`、`SSTAT`、`UCNT`、`time_valid`、`pps_valid`。

燒錄後關鍵 raw evidence：

```text
Master DE5 [1-11.1]
  cpu_marker=B004, MODE=2, PTP=6, status=0xFF
  PTP RX/TX=0x00006F44/0x0000FC1A

Slave DE5 [1-11.2]（燒錄後第一個 snapshot）
  cpu_marker=B004, MODE=3, PTP=4, status=0xEF
  link_up/time_valid/pps_valid=1/0/1
  SSTAT=0x00000000, PSTAT=0x00000001, UCNT=0
  PTP RX/TX=0/0

Slave DCO_STATE 初始讀值：0005000100000320
  completed_steps=0x0001, rt_state=0, bus_busy=0,
  static_ready=1, oDCO_DEBUG[31]=0

Slave DCO_STATE 後續讀值：0005000700002B20
  completed_steps=0x0007, rt_state=0, bus_busy=0,
  static_ready=1, oDCO_DEBUG[31]=0
```

`oDCO_DEBUG[31]=0` 表示本次 sticky NACK 觀測期間沒有取到 SDA high 的 ACK slot；這是「沒有觀察到 NACK」的證據，不是 SI5340 register readback 成功的充分證明。

原始檔案與 SHA-256：

```text
exp_wrpc_slave_i2c_nack_20260817_runtime_snapshot.log 0271e7e8f694010611b6f77a1d28990263124bb1408d7b79bb86473f38c1278f
exp_wrpc_slave_i2c_nack_20260817_dco_state.log 1c534e52811f74594ee23666f99924b75db3bad8ef998c89db439615e420d2c3
exp_wrpc_slave_i2c_nack_20260817_dco_activity.log 6355ce1671327500f53d81954f2b6b7de2bebdb553cf5bf5f21ae391bdabdc21
exp_wrpc_slave_i2c_nack_20260817_runtime_timeseries.log 21ec70c1d9eb8826db6e04adb98757bb9e084eb36eddd327a25fdf60412359bf
exp_wrpc_slave_i2c_nack_20260817_runtime_final.log ff3e3295cdd3d61887dda5a9f50fc12f232217f189cfa7a594b42a93a237892f
exp_wrpc_slave_i2c_nack_20260817_dco_state_final.log 8470920f6b9aac9d354fed30f7b455c1d0ef82472ad88287f1b4f8de6188c62b
exp_wrpc_slave_i2c_nack_20260817_dco_activity_final.log 12190302ca74bfc55492e72b100063542e8cbcc08ddc1832e82121195293ca47
exp_wrpc_slave_i2c_nack_20260817_runtime_timeseries_2.log 6c604c2874d021915dc0c4697c685a6a5dd7661ac0f46238c41da98ed63fce43
```

第二段 time-series 的最後有效 Slave frame 為：

```text
status_low=EF, time_valid=0, pps_valid=1, wr_mode=3,
sstat_wr_valid=1, servo_state=0, link_up=1, spll_locked=0
WDIAGS_SSTAT=0x00000001, WDIAGS_PSTAT=0x00000001,
WDIAGS_PTP_RX=0x000001AE, WDIAGS_PTP_TX=0x0000014A,
WDIAGS_UCNT=0, WDIAGS_CKO=0, WDIAGS_SETP=0
```

## Observation

本次沒有觀察到 NACK，且 `completed_steps` 從 1 增至 7；因此可以排除「每一筆交易都明確被 NACK」作為目前最直接的解釋，但仍不能宣稱 register readback 或實體頻率修正已成功。

## Conclusion

本實驗結果為「NACK 觀測未發現錯誤，DCO FSM 可完成交易，但 Slave 同步仍未完成」。證據支持：

- Slave 可配置且 CPU marker=`B004`。
- DCO transaction completion count 有增加，最後 `completed_steps=7`。
- `oDCO_DEBUG[31]=0`，本輪未觀察到 ACK slot 的 NACK。
- Slave PTP RX/TX 可恢復活動，並曾進入 `SSTAT=0x101` 的前置 servo 狀態。

證據不支持：

- SI5340 register 已被 readback 驗證。
- SoftPLL 已 lock。
- Slave 已完成 White Rabbit synchronization。

因此目前問題已從「FPGA FSM 是否卡住或大量 NACK」收斂到「SI5340 correction 的實際頻率效果、register semantics 或 feedback loop 是否正確」。

## Next Step

下一輪不改 Master role、PTP 或 PHY。由於本輪沒有 NACK且 DCO completed 增加，先做「Slave SI5340 register readback / output frequency effect」的單一變因診斷：優先確認 page 3 `0x39` mask、page 0 `0x1D` FINC/FDEC 寫入後的實際 register value，或用可重複的時鐘頻率計數器確認 DCO step 是否改變目標 clock。只有取得 clock effect 後，才判斷 FINC/FDEC direction 或 DDMTD polarity。
