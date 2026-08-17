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

燒錄後 ACK snapshot 與 60 秒 runtime 都完成：

- `DCO_I2C_ACK transactions/errors/ack_bits`
- DPLL/HPLL state snapshot
- DCO source/destination/accepted/done
- Slave `SSTAT`、`PSTAT.locked`、`time_valid`、`pps_valid`
- parent、PTP、servo activity

- ACK snapshot log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-ACK-OBS-20260817/dco_ack_diag.log`
- ACK snapshot SHA-256：`f960d0d9d20dedab1d68e80e9916f60d62d7315aa71c9531e71b1106b41ea49c`
- 60 秒 runtime log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SI5340-ACK-OBS-20260817/runtime_60s.log`
- 60 秒 runtime SHA-256：`9d090790fa230c6b48873d1ac145a5e866b4469d7137b56d44b124dc0ad7ae17`
- JTAG/Tcl：`SESSION_TIME_SERIES_DONE`，Quartus SignalTap Tcl 0 errors、0 warnings。
- DCO snapshot：HPLL `accepted=0x000C、done=0x0008`；DPLL `accepted=0x0007、done=0x0000`；DPLL/HPLL state current/previous data 都為 `0x0000`。
- ACK telemetry：`transactions=0x049A、errors=0x0000`；本輪沒有觀察到 sticky NACK。
- Slave accepted samples：60/60；主要狀態 `link_up=1、pps_valid=1、spll_locked=0、time_valid=0`。
- Slave `SSTAT` 主要為 `0x00000101`，沒有 `SSTAT[11:8]=4/5`；`PSTAT.locked` 與 `WR_LOCK.result` 維持 0。
- Slave parent/PTP 狀態在取樣中有活動與重置變化，但沒有形成同步有效狀態。

## Observation

ACK error count 保持 0，降低「SI5340 完全不回 ACK」的可能性；但目前 telemetry 的 `ack_bits` 讀取時已回到 idle/新 transaction 邊界，因此不以單次 `ack_bits=0` 宣稱最後一筆每個 byte 的 ACK。FPGA 端的 `done` 與 ACK count 都不能單獨證明 page 0x03/register 0x39、page 0x00/register 0x1D 已被正確寫入，也不能證明 N1 clock 真正改變。

## Conclusion

本輪證據支持：目前沒有觀察到 SI5340 NACK，且 Slave link/部分 PTP activity 可維持；但 Slave 仍未取得 `spll_locked=1` 或 `time_valid=1`。因此「完全沒有 I2C 回應」不是目前最有證據的說法；真正的 register page、FINC/FDEC semantics、readback 值與輸出 clock effect 仍未被證明。不能宣稱 WR synchronization 成功。

## Next Step

下一輪只做 SI5340 register readback：在不恢復 DPLL、不改 PHY/PTP/servo 的前提下，讀回 page select、N_FSTEP_MSK 與 FINC/FDEC 相關 register，並將 read data/ACK error 納入 JTAG。若 readback 正確，再檢查輸出 clock effect；若不正確，修正 page/register sequence。
