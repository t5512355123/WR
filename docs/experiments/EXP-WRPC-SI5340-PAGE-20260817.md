# EXP-WRPC-SI5340-PAGE-20260817：修正 SI5340 DCO runtime page/register 序列

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-PAGE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：單一硬體變因 A/B；Master 與 Slave 均重新 compile、燒錄，再做 60 sample JTAG runtime 觀測。

## 這次想驗證什麼

驗證 SI5340 DCO runtime 控制是否因 page/register 選擇錯誤，導致 FINC/FDEC 沒有作用在正確的 N divider。前一輪唯讀 source audit 發現現行序列會在 page 0 寫 `0x39`，而 Si5340 register map 把 N divider FINC/FDEC mask 定義在 page 3 的 `0x0339`。

## Git、分支與工具

- 本機研究分支：`exp/jtag-runtime-observability`
- GitHub source commit：`5e816ead4240878740dc259a5d9c55482f7dd180`
- pain checkout：detached HEAD，明確固定於 `5e816ead4240878740dc259a5d9c55482f7dd180`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## 相較 baseline 唯一修改了什麼

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v` 的 runtime I2C 序列：

```text
原本：page 0 -> address 0x39 -> address 0x1D
本次：page 3 -> address 0x39 -> page 0 -> address 0x1D
```

沒有修改 PHY、lane、polarity、reference/DMTD clock wiring、SoftPLL generic、firmware、servo 或 load pulse CDC。

## Build provenance

### Master

- QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
- SOF SHA-256：`e629810b214379e283b4ef9aba0867126ffedcdc85a3e25134bb84eb0871ec8a`
- Fitter：Successful
- Full Compilation：successful，0 errors、270 warnings
- Timing：`timing_closed=NO`；worst setup `-0.182 ns`、worst hold `-3.507 ns`；unconstrained clocks `3`

### Slave

- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- SOF SHA-256：`4314042885f7e761e042228d42496db77735a470288d59aa148b016d6e75d433`
- Fitter：Successful
- Full Compilation：successful，0 errors、270 warnings
- Timing：`timing_closed=NO`；worst setup `-0.176 ns`、worst hold `-3.530 ns`；unconstrained clocks `3`

## 燒錄結果

### Master：2026-08-17 05:14:08–05:14:27

```text
Using programming file .../DE5a_wr_master_jtag.sof with checksum 0x30A4AB2F
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### Slave：2026-08-17 05:14:37–05:14:56

```text
Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x30A38097
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

原始 programmer logs：

- `build/artifacts/EXP-WRPC-SI5340-PAGE-20260817/program_master.log`
  - SHA-256：`0b9a38821edea2419810dd0f1c4ec009a74bab3bb6a6f88f5fe8b59c63fe5dc1`
- `build/artifacts/EXP-WRPC-SI5340-PAGE-20260817/program_slave.log`
  - SHA-256：`9ddd0807e84a71fc83d8da436b8caf51736beada6885e170f9c02b748c9ae046`

## JTAG/runtime 實驗設定

```text
quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 10
```

這表示每張板最多 60 個 sample、sample 間隔 1000 ms、每筆最多 10 次 retry；腳本只讀 mailbox/register，不寫入 WR 控制暫存器。完整原始輸出：

```text
build/artifacts/EXP-WRPC-SI5340-PAGE-20260817/runtime_60s.log
SHA-256: 2c6a122029455b754e4ad7696d9be9570faf3ba10737f5549a6479f930247a62
```

Quartus SignalTap 腳本結果：successful、0 errors、0 warnings；session 於 05:19:26 完成。

## JTAG/runtime 原始結果

### Master

- `status_low=0xFF`，`time_valid=1`、`pps_valid=1`、`wr_mode=2`、`link_up=1`。
- `PSTAT=0x00000001`，本 register map 下 link bit 為 1、SoftPLL lock bit 為 0；因此本紀錄不把 status low 的 time-valid bit 當成 SoftPLL lock 的替代證據。
- `TAG_COUNT`、`TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`TAG_SOURCE_COUNT` 持續增加。
- `HELPER_ERROR=0xFFFDB610`（`-150000`）、`HELPER_OUTPUT=0xFFFB`；沒有看到 helper error 收斂。

### Slave

- 大部分 accepted sample：`status_low=0xCF`，`time_valid=0`、`pps_valid=0`、`wr_mode=3`、`SSTAT=0x00000001`、`PSTAT=0x00000001`。
- 最後 sample：`status_low=0xEF`，`pps_valid=1`，但 `time_valid=0`、`PSTAT.bit1=0`、`SSTAT=0x00000001`。
- `TAG_COUNT`、`TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`TAG_SOURCE_COUNT` 持續增加；例如最後 sample 的 raw counters：

```text
TAG_VALID_COUNT=00402695/004038F4
TRR_WRITE_COUNT=004026F0/00403951
TAG_SOURCE_COUNT=05888521/05889781
```

- `HELPER_ERROR=0xFFFDB610`（`-150000`）、`HELPER_OUTPUT=0xFFFB`，60 秒內沒有收斂。
- `WR_SPLL_LOCKDET: HELPER=00000000 MAIN=00000000`，`spll_locked=0`。
- `WR_SIGNAL` 仍回報先前的 Slave lock failure record：`fail_role=2`、`fail_state=2`、`fail_count=1`。

## Observation

1. 新 page/register 序列 compile、fit、燒錄都成功，沒有造成 configuration failure。
2. 修正後 Slave 仍有大量 raw tag/feedback activity，因此本輪沒有支持「tagger 完全沒有輸出」的說法。
3. 修正後 Slave helper error 仍飽和在 `-150000`、output `0xFFFB`，`PSTAT.bit1` 沒有變成 1，`SSTAT` 沒有進入 `TRACK_PHASE`，`time_valid` 也沒有變成 1。
4. `pps_valid` 在最後 sample 為 1，但這只代表 PPS valid 條件曾成立，不能代替 SoftPLL lock 或 time-valid。
5. 本輪只改 page/register mapping，沒有處理 `dac_*_load` 從 `clk_sys_625` 到 `CLK_50_B2J` 的跨 clock pulse，因此仍存在另一個獨立、尚未驗證的 DCO actuator 嫌疑。

## Conclusion

本實驗支持：

> SI5340 runtime page/register mapping 已依 register map 修正，且新 bitstream 可正常編譯與燒錄；但這項修正單獨不足以讓 Slave SoftPLL lock，不能宣稱兩張 DE5a 已完成 White Rabbit 時間同步。

本實驗不支持：

> 不能把「page/register mapping」宣稱為唯一根因，也不能把 raw tag counters 增加或短暫 `pps_valid=1` 宣稱為同步成功。

## Next Step

下一個實驗只處理 DCO load request 的 clock-domain crossing（CDC，跨時脈域）：讓 `clk_sys_625` 產生的 DAC load request 在 `CLK_50_B2J` 端以可遺失檢查的 toggle/握手機制接收，保留目前 page/register 修正，不同時改 PHY、SoftPLL generic 或 DMTD wiring。先 compile；若成功再燒錄兩片，並立即建立下一份實驗紀錄。
