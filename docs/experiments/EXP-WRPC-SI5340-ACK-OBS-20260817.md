# EXP-WRPC-SI5340-ACK-OBS-20260817：SI5340 I2C ACK/NACK 唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-ACK-OBS-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave-only diagnostics；Master 維持已知 baseline。

## 這次想驗證什麼

前一輪已確認 FPGA 內部 DCO transaction counter 會增加，但目前 I2C controller 的 ACK state 只前進狀態，沒有讀 SDA 判斷 ACK/NACK。因此本輪要回答：

1. SI5340 slave address、register address、write data 是否真的回 ACK。
2. `done` counter 增加是否只是 FPGA FSM 完成，還是 SI5340 確實回應。
3. runtime 寫入是否有可觀察的 NACK 證據。

## 相較 baseline 唯一修改了什麼

只增加唯讀 ACK telemetry：

- `i2c_bus_controller_dco.v` 在 ACK high phase 取樣 SDA。
- sticky 累加 transaction count、NACK count 與最近一次四個 ACK bit。
- 新增 `WR_I2C_ACK_DIAG_SLAVE` probe，instance index 12。
- `read_dco_diag.tcl` 新增 ACK telemetry 解析。

原本的 I2C state transition、slave address、page/register/data、DCO gate、PHY、DMTD、PTP、servo 與 clock routing 都不修改。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- branch：`exp/jtag-runtime-observability`
- source commit：`f6646ae6458f5c58bd5c87ae16fdd7d8b3a77703`
- pain build checkout：待 compile 前固定為 `f6646ae` detached HEAD。
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## Image provenance

### Master（本輪不修改、不重燒）

- source commit：`5e816ead4240878740dc259a5d9c55482f7dd180`
- MIF/SOF：沿用 baseline；本輪不重新生成。

### Slave（待 compile）

- QSF/SDC/MIF/SOF SHA-256：待 compile 後記錄。
- Quartus compile、timing 與 programmer 結果：待完成後記錄。

## 燒錄結果

待 compile 成功後才燒錄；若 compile 失敗，不把它寫成硬體實驗成功。

## JTAG/runtime 原始結果

待燒錄後保存：

- `DCO_I2C_ACK transactions/errors/ack_bits`
- DPLL/HPLL state snapshot
- DCO source/destination/accepted/done
- Slave `SSTAT`、`PSTAT.locked`、`time_valid`、`pps_valid`
- parent、PTP、servo activity

## Observation

待補入原始 log 與 SHA-256。

## Conclusion

在取得 ACK telemetry 前，不宣稱 SI5340 ACK/NACK、register page、FINC/FDEC 或 clock effect 的根因。

## Next Step

若 ACK bits 顯示 NACK，先修正 I2C bus/address/時序；若 ACK 全部正常但 time_valid 仍為 0，再做 register readback 或輸出 clock effect 的最小診斷。不要在本輪同時恢復 DPLL。
