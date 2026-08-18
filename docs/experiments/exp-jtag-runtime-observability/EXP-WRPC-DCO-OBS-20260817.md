# EXP-WRPC-DCO-OBS-20260817：DCO transaction pipeline 唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-OBS-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：單一硬體變因；只重新編譯、燒錄 Slave，Master 維持已知 baseline。

## 這次想驗證什麼

確認 Slave 的 DCO 命令是否真的沿著下列路徑流動：

```text
WR SoftPLL source load
    -> 50 MHz destination input
    -> accepted pending request
    -> SI5340 I2C transaction done
```

目的是區分「DCO load 在 clock domain crossing 過程中遺失」與「命令已抵達，但控制器沒有接受或完成」兩類問題。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 研究分支：`exp/jtag-runtime-observability`
- 本輪 commit：`c5092ddb343a2fa50a9349468759d0cf9317b1b5`
- pain checkout：detached HEAD，固定於 `c5092dd`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## 相較 baseline 唯一修改了什麼

只加入 DCO pipeline 的唯讀計數觀測，不修改 DCO 控制流程：

- Slave 增加 HPLL/DPLL source input count。
- Slave 增加 destination input、accepted、transaction done count。
- 增加唯讀 JTAG probe 與 `read_dco_diag.tcl`。
- 原本的 toggle CDC、SI5340 page sequence、SoftPLL、PTP、PHY 與 firmware 均未改動。

## Master/Slave image provenance

### Master：沿用 baseline，未重新燒錄

- source commit：`5e816ead4240878740dc259a5d9c55482f7dd180`
- MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
- SOF SHA-256：`e629810b214379e283b4ef9aba0867126ffedcdc85a3e25134bb84eb0871ec8a`
- 本輪沒有重新燒錄 Master，因此不把 Master 當成新的硬體變因。

### Slave：本輪新編譯並燒錄

- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- SOF SHA-256：`391c5c245fa53da75e685d9c4dc963f225d2aea58ce8c7d69faa490b88c1dcb1`
- Fitter：Successful
- Full Compilation：successful，0 errors、273 warnings
- Timing：`timing_closed=NO`
- Worst setup slack：`-0.163 ns`
- Worst hold slack：`-3.490 ns`
- Worst recovery slack：`1.173 ns`
- Worst removal slack：`0.391 ns`
- Compile log SHA-256：`3465f7ad831a53ed79b72b9654ce17ca538920826a555868a319e7ffb4d5b721`

## 燒錄結果

只燒錄 Slave：

```text
Cable: DE5 [1-11.2]
SOF checksum: 0x30A53A47
Device JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- 燒錄時間：2026-08-17 05:55:42–05:56:00（pain）
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-OBS-20260817/program_slave.log`
- Programmer log SHA-256：`cef8a89cc184d702f0d605358c504181c17375942b5fe6f2407db7e2aea0bf21`

## JTAG/runtime 原始結果

### DCO pipeline 唯讀計數

使用 `read_dco_diag.tcl 1000`，Master 沒有這個新 probe，因此顯示 `No In-System Sources and Probes instance was found`；Slave 讀取成功：

```text
BEGIN_HPLL source=3D5C destination=3D5C accepted=0378 done=0000
END_HPLL   source=5D7A destination=5D7A accepted=0378 done=0000
BEGIN_DPLL source=0001 destination=0001 accepted=0000 done=0000
END_DPLL   source=0001 destination=0001 accepted=0000 done=0000
```

### SoftPLL raw 狀態

Slave 代表性值：

```text
SSTAT=00000101
PSTAT=00000001
LOCK RESULT=00000001
HELPER=00000000
MAIN=00000000
HELPER_ERROR=FFFDB610
HELPER_OUTPUT=0000FFFB
LAST_STATE=00000004
TRANSITIONS=00000003
```

### 20 秒 runtime time-series

- log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-OBS-20260817/runtime_20s.log`
- SHA-256：`1cabdd9b96948a501954d6e48d370eb339aa3b7b7341680c5d8c7d3c64023150`
- Slave `PTP_RX/PTP_TX`、tag/TRR、IRQ 與 `UCNT` 有持續活動。
- Slave `foreign_count=1`、`wr_config=3`、`parent_is_wr=1`、`calibrated=1`。
- Slave 仍為 `PSTAT.locked=0`、`time_valid=0`；`pps_valid` 只在部分 sample 為 1。

其他原始檔：

- DCO log SHA-256：`cda16c02e530e55b2a358a7f727f3768f7f7f761a81c54f7da3a287d898f02e8`
- SoftPLL raw log SHA-256：`3a24a64bf9edb46a339d8969f00c641ae54f7a4a47b97bf5cd9596539b0d9f`

## Observation

1. HPLL source count 與 destination input count 在同一段觀測中同步增加，沒有看到 source 到 destination 的直接計數落差。
2. HPLL accepted count 固定在 `0x0378`，transaction done count 為 `0`；DPLL 沒有新的 accepted/done transaction。
3. 因此目前證據不支持「這一段 CDC 直接大量遺失」是唯一根因，反而顯示 DCO request 接收/排程/完成流程需要進一步檢查。
4. `PSTAT.locked=0`、`time_valid=0` 仍維持；但 PTP、parent、tag、IRQ 與 servo update 活動都存在。

## Conclusion

本實驗支持：

> Slave 的 WR runtime、PTP parent 選擇與 tag/IRQ 路徑仍在運作；HPLL load 至 destination input 的計數也能對上。

本實驗不支持：

> 目前不能宣稱 Slave 已完成同步，也不能把「DCO source pulse 在 CDC 中完全遺失」當成已證明根因。

目前最保守的結論是：**問題優先收斂在 DCO controller 的 request 接受與 I2C transaction 完成流程；尚未證明 SI5340 實際收到有效 FINC/FDEC，亦尚未證明 feedback clock 已被改變。**

## Next Step

下一輪只修改 DCO start handshake：將 runtime I2C start request 保持到 `bus_state` 真正拉高，避免 50 MHz domain 的單週期 pulse 被較慢 I2C state machine 看漏。先 compile，若燒錄則立即建立新的實驗紀錄；不改 PHY、PTP 演算法、servo 或 calibration。

