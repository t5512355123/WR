# 實驗紀錄：SI5340 暫存器讀回觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-READBACK-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 原始碼 commit：`4fa32a30ff9fff20bf7c98f7b737d67c42751b1c`

## 這次想驗證什麼

確認目前 Slave 端 SI5340 的執行期 DCO 寫入流程，是否真的能在指定 page/register 讀回預期資料。這一輪只驗證 register readback，不把讀回值直接拿來改變 White Rabbit 的 PHY、PTP、servo 或 DPLL 行為。

預期觀測：

- page 3 的 register `0x39`：`N_FSTEP_MSK`
- page 0 的 register `0x1D`：`FINC/FDEC`
- I2C ACK/NACK sticky telemetry
- Slave 的 `SSTAT`、`PSTAT.locked`、`time_valid`、`pps_valid`

## 相較 baseline 唯一修改了什麼

相較於 `c6248b1` 的 SI5340 ACK 觀測版，唯一修改是：

1. 在 SI5340 I2C controller 完成一次性 readback sequence。
2. 依序選 page 3、讀 `0x39`，再選 page 0、讀 `0x1D`。
3. 以新的 JTAG probe index 13 讀出 readback data、完成旗標與目前 page。
4. `read_dco_diag.tcl` 增加 readback 解碼。

沒有恢復 DPLL，也沒有修改 PHY、PTP filter、servo 演算法或 SoftPLL lock threshold。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256（未改動基線）：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
- Slave MIF SHA-256：`72e832874562b061e1cc9e1a07bf4f03e0d11b56dc4d326dbbda1bd1f7575c1a`
- Slave SOF SHA-256：`1766e765e8962631c787bb062ac088d18d76f71764ea03f4a3d73a1ad0647181`
- Compile log SHA-256：`49279d3a2dbe9453fc3a4a7a9727b36b19e471d673790bb3928afd3c806819f9`
- Full Compilation：0 errors、275 warnings，Fitter successful
- Timing：setup `-0.361 ns`、hold `-3.503 ns`、recovery `1.213 ns`、removal `0.327 ns`
- Unconstrained：clocks 4、inputs 872、outputs 85
- Programmer checksum：待燒錄後填入
- JTAG ID：待燒錄後填入

## 燒錄結果

已燒錄至 Slave `DE5 [1-11.2]`：

- Programmer checksum：`0x309CAB3C`
- JTAG ID：`0x02E660DD`
- Configuration：succeeded
- Programmer：0 errors、0 warnings
- 時間：2026-08-17 08:31:14 至 08:31:32（Asia/Taipei）
- 原始 programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-20260817/program.log`
- programmer log SHA-256：`58bdc6d832af3b132f42b8dc8c919c6503d8e699b234581500327efea8f25226`

這只證明 bitstream 已成功配置到指定 FPGA，不等於 SI5340 readback 或 WR synchronization 成功。

## JTAG/runtime 原始結果

### 燒錄後 readback snapshot

- 原始 log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-20260817/dco_readback.log`
- log SHA-256：`c454193a50993f24abc8b204149c7c5a0a4f7433576d881ea7543dea955d4b7c`
- Master `DE5 [1-11.1]`：因本輪只燒錄 Slave，沒有對應的 In-System Sources and Probes instance；原始工具回報 `No In-System Sources and Probes instance was found.`
- Slave `DE5 [1-11.2]`：

```text
DCO_I2C_ACK transactions=00EB errors=0000
DCO_I2C_READBACK state=5 done=1 page3_0039=00 page0_001D=00 current_page=00 raw=0000000000000015
```

readback FSM 確實走到 `state=5` 且 `done=1`，但兩個讀回欄位都是 `0x00`。這只能證明目前 readback 流程完成，不能證明 SI5340 的兩個 register 真實值就是 `0x00`；讀資料擷取可能仍有跨 clock domain 或 valid timing 問題。

### 60 秒唯讀 runtime session

- 指令：`quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 3`
- 原始 log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-READBACK-20260817/runtime_60s.log`
- log SHA-256：`09fb6007db798ce54f880d91e8be64a625e9983071b4d5ff373d440e1e824ef9`
- session：`SESSION_TIME_SERIES_DONE`，JTAG/SignalTap 工具回傳 0 errors、0 warnings
- Master：60/60 個 sample accepted；`link_up=1`、`time_valid=1`、`pps_valid=1`
- Slave：1/60 個 sample accepted、59/60 因前後 frame 一致性檢查失敗而 rejected；accepted frame 顯示 `link_up=1`、`SSTAT=0x00000001`、`PSTAT=0x00000001`、`spll_locked=0`、`time_valid=0`
- Slave `WR_LOCK`：`result=1` 是目前 probe 的結果碼，但 `spll_locked=0`、`polls=883802`、`unlocked=883802`、`calibration_fail=0`，不能把 `result=1` 當成 SoftPLL 已鎖定
- Slave `WR_SPLL_ACTIVITY`：`REF_COUNT`、`TAG_COUNT`、`IRQ_COUNT` 與 `UCNT` 有增加，代表 runtime/servo 仍有活動；這不等於 lock 或 time valid

本輪 Slave accepted sample 數量偏低，表示 mailbox 多 register frame 的重讀一致性仍會造成觀測拒絕；但在可採信的 frame 中，沒有看到 `PSTAT.locked=1` 或 `time_valid=1`。

readback probe 欄位：

- bits `3:0`：readback FSM state
- bit `4`：readback done
- bits `12:5`：page 3 register `0x39` read data
- bits `20:13`：page 0 register `0x1D` read data
- bits `28:21`：目前 page 記錄

## Observation

1. SI5340 I2C ACK telemetry 的 error count 是 `0`，目前沒有 NACK 證據。
2. readback FSM 完成，但讀回 `page3_0039=0x00`、`page0_001D=0x00`；這個結果尚不能視為 register 真值。
3. Master 維持既有同步狀態；本輪沒有重新燒錄 Master。
4. Slave 的 link 與 PTP/servo activity 存在，但 `SSTAT=1`、`PSTAT.locked=0`、`spll_locked=0`、`time_valid=0`。
5. Slave 的 60 秒觀測只有 1 筆 frame 通過一致性檢查，需改善觀測 read-data valid/hold 後才適合做更精細的 register 判斷。

## Conclusion

本輪沒有完成 Slave WR synchronization。證據支持的結論只有：

- bitstream 已成功配置，且 SI5340 I2C transaction 目前沒有觀察到 NACK。
- Slave 的 runtime/servo 有活動，但尚未取得 SoftPLL lock，沒有 `time_valid=1` 證據。
- readback FSM 的完成旗標正常，但兩個讀值為 `0x00`，目前不足以確認 SI5340 register 寫入與 output clock effect；因此不能把問題確定歸因於 SI5340 register 內容，也不能宣稱已排除讀回擷取時序問題。
- 目前最保守且與證據一致的判斷仍是：Slave 的 parent/servo/SoftPLL 到 `time_valid` 路徑尚未完成；readback observability 本身也需要先修正。

## Next Step

下一輪只修正 readback 的有效握手：在 I2C controller clock domain 內鎖存 read data 與 read-done，提供 sticky valid/data，再由上層於明確 valid 後取樣。不得同時恢復 DPLL、修改 PHY、PTP filter、servo 或 SoftPLL threshold。修正後需重新 compile、燒錄 Slave，並立即以相同 readback snapshot 與 60 秒唯讀 session 重測。
