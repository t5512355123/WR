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

- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`72e832874562b061e1cc9e1a07bf4f03e0d11b56dc4d326dbbda1bd1f7575c1a`
- SOF SHA-256：`ce00ec9af0e6f538df16c41ec705b09fab38f8442f6bcc0897fd1195361c3265`
- Quartus Full Compilation：successful，0 errors、274 warnings；Fitter successful。
- Timing：`timing_closed=NO`；setup `-0.239 ns`、hold `-3.479 ns`、recovery `0.542 ns`、removal `0.330 ns`；unconstrained clocks/input/output `3 / 803 / 83`。
- compile trace SHA-256：`3465f7ad831a53ed79b72b9654ce17ca538920826a555868a319e7ffb4d5b721`
- build log SHA-256：`7abf0d4de5ce51234e30c46f9c71d36e88020a2442245dd0644f2cb058919153`

## 燒錄結果

- 燒錄對象：Slave，cable `DE5 [1-11.2]`
- 燒錄時間：2026-08-17 08:10:05–08:10:24（pain）
- programmer checksum：`0x309FFE28`
- Device JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`Quartus Prime Programmer was successful. 0 errors, 0 warnings`
- programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-ACK-OBS-20260817/program_slave.log`
- programmer log SHA-256：`148e20b887f5db91561af96dfe1706ca8726a7ece062360d46287222b50917de`

本節只證明 ACK diagnostic Slave image 已成功配置，不宣稱 WR synchronization 成功。

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
