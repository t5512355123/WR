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

待燒錄後保存：

- `read_dco_diag.tcl` 的 DCO、ACK、readback snapshot
- 60 秒唯讀 runtime session
- 原始 log 的 SHA-256

readback probe 欄位：

- bits `3:0`：readback FSM state
- bit `4`：readback done
- bits `12:5`：page 3 register `0x39` read data
- bits `20:13`：page 0 register `0x1D` read data
- bits `28:21`：目前 page 記錄

## Observation

待實驗結果填寫。特別區分：

- ACK error 是否為零
- readback 是否完成
- readback 值是否合理且與實際 runtime write sequence 一致
- Slave `SSTAT` 是否進入 TRACK_PHASE 相關狀態
- `PSTAT.locked`、`time_valid`、`pps_valid` 是否成立並穩定

## Conclusion

待依原始 JTAG/runtime 證據填寫。若 readback 正確，只能排除部分 page/register sequence 疑慮，不能單獨宣稱 clock output 已改變，也不能單獨宣稱 WR synchronization 成功。

## Next Step

若 readback 正確但 `PSTAT.locked=0`、`time_valid=0`，下一輪再針對 SI5340 output clock effect 或 helper/parent servo 路徑設計單一變因；不在本輪同時恢復 DPLL。
