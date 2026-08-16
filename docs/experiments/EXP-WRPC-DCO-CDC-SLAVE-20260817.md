# EXP-WRPC-DCO-CDC-SLAVE-20260817：Slave DCO load toggle CDC

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-CDC-SLAVE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：單一硬體變因 A/B；只重新編譯、燒錄 Slave，Master 維持原 bitstream。

## 這次想驗證什麼

驗證 `xwr_core` 在 `clk_sys_625` domain 產生的 `dac_hpll_load` / `dac_dpll_load`，直接送到 `CLK_50_B2J` domain 的 SI5340 DCO controller 時，是否因 pulse 跨時脈域而遺失，造成 Slave helper error 飽和、SoftPLL 無法 lock。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 研究分支：`exp/jtag-runtime-observability`
- 本機 commit：`b490a5de9def78c40bffe2e9aeee27e4731ad22e`
- pain checkout：detached HEAD，明確固定於 `b490a5de9def78c40bffe2e9aeee27e4731ad22e`
- Master baseline source：`5e816ead4240878740dc259a5d9c55482f7dd180` 的已燒錄 image；本輪沒有重燒 Master。
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## 相較 baseline 唯一修改了什麼

只修改 `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`：

1. 在 `clk_sys_625` domain 將每次 DCO load 的 16-bit data 暫存，並反轉 event toggle。
2. 在 `CLK_50_B2J` domain 對 toggle 與 held data 做兩級同步。
3. 偵測 toggle 變化後，產生一個乾淨的 destination-side load pulse 給 SI5340 controller。

本輪沒有修改 Master、PHY、lane、polarity、reference/DMTD clock wiring、SoftPLL generic、PTP、firmware 或 SI5340 runtime page sequence。

## Build provenance

- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- Slave SOF SHA-256：`30b9e62380508e111b011cd8d0d74a2ab029313c65b65af398918b5952762be4`
- Fitter：Successful
- Full Compilation：successful，0 errors、271 warnings
- Timing：`timing_closed=NO`
- Worst setup slack：`-0.389 ns`
- Worst hold slack：`-3.507 ns`
- Worst recovery slack：`0.825 ns`
- Worst removal slack：`0.331 ns`
- Unconstrained clocks：`3`
- Compile log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-CDC-SLAVE-20260817/compile_slave_trace.log`

## 燒錄結果

只燒錄 Slave：

```text
Cable: DE5 [1-11.2]
SOF checksum: 0x30A245FB
Device JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- 燒錄時間：2026-08-17 05:37:33–05:37:51（pain）
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-CDC-SLAVE-20260817/program_slave.log`
- Programmer log SHA-256：`5f0fb0f736143ce86cae4803209f577a6ba2ed570bb1db42fd43d7a962879443`

## JTAG/runtime 設定

燒錄後執行：

```text
quartus_stp -t scripts/jtag/read_spll_diag_raw.tcl 1000
quartus_stp -t scripts/jtag/read_clock_activity.tcl 1000
quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 10
```

原始檔案與 SHA-256：

- raw SoftPLL：`raw_spll.log`，`085a499f399f6548d215187eb5581c23fbf13960ce2435195c5733f270512f0c`
- clock activity：`clock_activity.log`，`b89907b95dedb400727e8faf8563f8321d52329bc878fdf07e237bb24aa15609`
- 60 秒時間序列：`runtime_60s.log`，`5c477782b16b614d1c2b7bd74a726d4c9336da1aa28e144ab5a2e3539f0f5713`

完整路徑：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-CDC-SLAVE-20260817/
```

## JTAG/runtime 原始結果

### Slave

- raw BEGIN/END：`SSTAT=0x00000101`、`PSTAT=0x00000001`。
- `status_low` 在 `0xCF` 與 `0xEF` 間變化；`time_valid=0`，`pps_valid` 偶爾為 1，但沒有 SoftPLL lock。
- `WR_SPLL_LOCKDET`：`HELPER=0x00000000`、`MAIN=0x00000000`。
- `HELPER_ERROR=0xFFFDB610`，即 `-150000`，60 秒內仍固定在飽和值。
- `HELPER_OUTPUT=0x0000FFFB`。
- `LAST_STATE=0x00000004`、`TRANSITIONS=0x00000003`、`VISIT_MASK=0x00000618`。
- 60 秒內 `TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`TAG_SOURCE_COUNT` 與 `IRQ_COUNT` 持續增加。
- 最後 accepted sample：`PSTAT=0x00000001`、`SSTAT=0x00000001`、`time_valid=0`、`pps_valid=0`。
- parent 欄位最後可讀為 `foreign_count=1`、`foreign_best=0`、`wr_config=3`、`is_wr=1`、`calibrated=1`。

### Master

- Master 沿用原本已燒錄 image，未被本輪修改或重燒。
- raw 觀測仍為 `PSTAT=0x00000001`、`HELPER_ERROR=0xFFFDB610`、`HELPER_OUTPUT=0x0000FFFB`；tag/IRQ counters 有活動。
- 本輪沒有把 Master 的結果當成 CDC A/B 的新變因證據。

### Clock activity

兩片都顯示：

- `PHY_READY=1`
- `RX_LOCK_DATA=1`
- `QSFPA_REFCLK`、`QSFPB_REFCLK/DMTD`、recovered RX clock counters 都有變化。
- `RX_LOCK_REF=0`；這是目前觀測值，不能與 `RX_LOCK_DATA=1` 混為一談。

## Observation

1. Slave toggle CDC 版可以正常 compile、fit、產生 SOF、燒錄，JTAG session 也成功完成。
2. tagger/FIFO/IRQ 路徑仍然活著；因此本輪不支持「SoftPLL 完全沒有收到 tag」的解釋。
3. 將 source pulse 改成 toggle synchronizer 後，Slave 的 helper error 仍為 `-150000`，`PSTAT.bit1` 仍為 0，`SSTAT` 沒有進入穩定 tracking state，`time_valid` 仍為 0。
4. 因此本輪沒有觀察到「CDC 修正使 DCO feedback 或 SoftPLL lock 改善」的證據。
5. 目前仍缺少 SI5340 runtime I2C 的實際 ACK/readback，以及 DCO controller `dco_step_count` 在 JTAG 上的直接證據；不能從 `WR_SPLL_DAC_*` firmware shadow 直接宣稱 SI5340 已接受或拒絕命令。

## Conclusion

本實驗支持：

> `dac_*_load` 的直接跨 clock-domain 連接確實是設計風險；本輪已用 toggle/held-data 方式建立一個可觀測的 destination pulse。

本實驗不支持：

> 在本次單一 Slave A/B 中，CDC 修正沒有讓 helper error、PSTAT lock、SSTAT 或 time_valid 改善，因此目前不能把 CDC 宣稱為 Slave 無法同步的主要根因。

目前最保守的結論是：**SoftPLL tag/IRQ 活動存在，但 DCO transaction 是否完成、SI5340 是否改變 feedback clock，仍未被硬體直接證明。**

## Next Step

下一輪不再盲目改 PHY 或 DMTD。先做一個新的單一變因：只增加 DCO transaction 唯讀觀測，至少露出 source load count、destination accepted count、controller runtime state、I2C transaction complete/ACK error 與 `dco_step_count`。先 compile；若需要燒錄，燒錄後立即建立下一份紀錄。根據觀測結果再決定是查 I2C ACK/page/readback、DCO feedback，或控制方向 polarity。
