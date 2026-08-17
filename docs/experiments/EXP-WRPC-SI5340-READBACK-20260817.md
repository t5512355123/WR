# 實驗紀錄：SI5340 暫存器讀回觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-READBACK-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 原始碼 commit：`b327f37`（完整 SHA 以 Git log 為準）

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

- Quartus：待 compile 後填入，預期 `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、17.0.0 Build 595
- QSF SHA-256：待 compile 後填入
- SDC SHA-256：待 compile 後填入
- Master MIF SHA-256：待 compile 後填入
- Slave MIF SHA-256：待 compile 後填入
- Slave SOF SHA-256：待 compile 後填入
- Programmer checksum：待燒錄後填入
- JTAG ID：待燒錄後填入

## 燒錄結果

待 compile 成功後燒錄 Slave `DE5 [1-11.2]`。燒錄成功、失敗或結果不明都必須在本節保留原始紀錄與 checksum；compile 成功不等於硬體實驗成功。

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
