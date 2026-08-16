# EXP-WRPC-HPLL-CONT-OBS-20260817：HPLL 連續、DPLL 隔離觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-HPLL-CONT-OBS-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave-only 單一隔離變因；Master 維持已知 image。

## 這次想驗證什麼

上一輪 DPLL-only 版本同時禁止 HPLL transaction，因此不能用它判斷 helper/HPLL 是否能 lock。本輪恢復 HPLL 的連續更新，並繼續禁止 DPLL/N0 更新，用來區分：

1. Slave 是否能先由 HPLL/helper 路徑進入 tracking/lock。
2. 如果 HPLL 能 lock 而 DPLL 不動，問題是否集中在 DPLL/N0 actuator。
3. 如果 HPLL 仍不能 lock，是否應優先查 helper feedback/時鐘與 HPLL actuator，而不是 DPLL。

## 相較 baseline 唯一修改了什麼

只修改 `si5340a_controller_dco.v` 的 transaction gate：

- HPLL pending request 改為可連續送出，不再只允許一次。
- DPLL request 仍被禁止，避免同時寫入 N0。
- HPLL/DPLL page、register、FINC/FDEC data、PHY、DMTD、PTP、servo firmware 與 JTAG register map 未修改。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 分支：`exp/jtag-runtime-observability`
- source commit：`97e70ca4abdca31b88be0616d66320f6cb89825a`
- pain build checkout：detached HEAD，固定於 `97e70ca`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## Master/Slave image provenance

### Master（本輪未修改、未重燒）

- source commit：`5e816ead4240878740dc259a5d9c55482f7dd180`
- MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
- SOF SHA-256：`e629810b214379e283b4ef9aba0867126ffedcdc85a3e25134bb84eb0871ec8a`

### Slave（本輪重新編譯、重新燒錄）

- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`72e832874562b061e1cc9e1a07bf4f03e0d11b56dc4d326dbbda1bd1f7575c1a`
- SOF SHA-256：`50672283f8628bc98655ecca8f608834079bac66ac6ef7e0a3b4117177dec79a`
- Quartus Full Compilation：successful，0 errors、275 warnings
- Fitter：successful
- Timing：`timing_closed=NO`
- Worst setup slack：`-0.190 ns`
- Worst hold slack：`-3.506 ns`
- Worst recovery slack：`1.142 ns`
- Worst removal slack：`0.334 ns`
- Unconstrained clocks/input/output：`3 / 721 / 82`
- compile log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-HPLL-CONT-OBS-20260817/compile.log`
- compile log SHA-256：`a4abc2710f865358ca3c5df83eceaec285518ed6df5486e199f09a80614545af`

## 燒錄結果

- 燒錄對象：Slave，cable `DE5 [1-11.2]`
- 燒錄時間：2026-08-17 07:36:35–07:36:54（pain）
- SOF programmer checksum：`0x30A30C52`
- Device JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`Quartus Prime Programmer was successful. 0 errors, 0 warnings`
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-HPLL-CONT-OBS-20260817/program_slave_actual.log`
- Programmer log SHA-256：`504a64b7d3ea32f37500809eae42779643607849a630884d4a38811bde2dd65b`

本節完成時只宣稱 Slave image 已成功配置，不宣稱 WR synchronization 成功；runtime 結果在同一份紀錄後續補入。

## JTAG/runtime 原始結果

待在本顆已燒錄 Slave 上執行唯讀 DCO snapshot 與 60 秒 runtime session 後補入。觀測期間不寫入控制 register、不重新燒錄、不修改 Master。

## Observation

待補入 runtime 原始 log、SHA-256、accepted/rejected sample 數與 Slave 的 `SSTAT`、`PSTAT.locked`、`time_valid`、`pps_valid`、helper error、HPLL/DPLL transaction counter。

## Conclusion

目前由本次結果支持的結論只有：HPLL continuous/DPLL isolation source 已成功 compile，且 Slave 已成功燒錄。Slave 是否能由 HPLL/helper 進入 lock，尚待 runtime 證據。

## Next Step

在不改變目前 bitstream 的情況下執行：

```text
quartus_stp -t scripts/jtag/read_dco_diag.tcl 1000
quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 5
```

若 HPLL done/input 持續增加且 `SSTAT` 進入 `4/5`、`PSTAT.locked=1`，再設計 DPLL-only-on-top-of-locked 的最小變因；若 HPLL 仍無法 lock，先查 helper feedback/clock 與 HPLL actuator。
