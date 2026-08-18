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

觀測期間沒有寫入控制 register、沒有重新燒錄、沒有修改 Master。Quartus 17 SignalTap/Tcl session 完成，`SESSION_TIME_SERIES_DONE`，Master 與 Slave 各完成 60 個樣本；frame retry 後均為有效取樣。

- DCO snapshot log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-HPLL-CONT-OBS-20260817/dco_diag.log`
- DCO snapshot SHA-256：`fd47960001a0e8178f44200e3af02f9f86f71e9800a94182e8dcafbcea7fd5b3`
- 60 秒 runtime log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-HPLL-CONT-OBS-20260817/runtime_60s.log`
- 60 秒 runtime SHA-256：`f0574758bd59b7762d315f53b360b5eb9d9a2903138ee24f315f60dcfe0853c9`
- JTAG/Tcl：成功，`0 errors, 0 warnings`，`SESSION_TIME_SERIES_DONE`
- Master：60/60 accepted；主要狀態 `status_low=FF`、`link_up=1`、`time_valid=1`、`pps_valid=1`。
- Slave：60/60 accepted；`link_up=1`，`SSTAT=0x00000001`、`PSTAT.locked=0`、`spll_locked=0`、`time_valid=0`。
- Slave：`pps_valid` 在樣本中於 `0` 與 `1` 間變動，但沒有伴隨 `time_valid=1` 或 SoftPLL lock；不能視為同步成功。
- Slave：`foreign_count=1`、`foreign_best=0`、`parent_is_wr=1`、`parent_calibrated=1`；PTP RX/TX、DMS、CKO、UCNT 有活動。
- Slave：`SSTAT` 在 accepted frames 維持 `1`，沒有進入 `4/5`；`WR_LOCK` 維持 `result=0`、`spll_locked=0`。
- DCO snapshot：HPLL `accepted=0x0012`、`done=0x000C`；DPLL `accepted=0x000B`、`done=0x0000`，DPLL state 顯示 `dpll_pending=1`。
- DCO snapshot 也顯示 `DPLL prev_data=0x0000`、`input_data=0x0000`；這支持 DPLL 輸入資料沒有形成有效變化的方向，但單次 snapshot 仍不足以證明每次 load 的資料都相同。
- Master 的 DCO probe instance 不存在於本輪 Master image；因此本輪 DCO transaction 證據只適用於 Slave。

## Observation

本輪唯一修改是讓 HPLL transaction 可連續服務、DPLL 保持隔離；這沒有讓 Slave 進入 SoftPLL tracking。Slave 已經看見 WR parent 且 PTP/servo 有活動，但 `SSTAT=1`、`PSTAT.locked=0`、`time_valid=0` 在整個 60 秒內沒有改善。HPLL counter 增加不能等同於 SI5340 實際完成正確的時鐘校正，因為目前 bus controller 的 transaction counter 是 RTL FSM 完成計數，尚未提供每一筆 ACK/readback 的證據。

## Conclusion

本輪證據支持：HPLL continuous/DPLL isolation image 已成功 compile、燒錄；Slave 的 PHY link、PTP parent 選擇與部分 servo 活動仍在，但 HPLL-only 沒有使 Slave 進入 `SSTAT=4/5`、`PSTAT.locked=1` 或 `time_valid=1`。因此「Slave WR servo/SoftPLL 到 time_valid 路徑」仍是優先問題範圍，但尚未能宣稱根因是 HPLL、DPLL、CDC、SI5340 ACK 或 helper clock 中的任何單一項。

## Next Step

先不改變目前功能路徑，新增純唯讀的 HPLL/DPLL data-change snapshot，直接保存每一個 load 事件看到的 current/previous data、change count、pending 與 direction；目標是區分「load 有到但 data 沒變」與「data 有變但 transaction 沒完成」。下一輪若需燒錄，會先以新 commit 在 pain compile，再依本紀錄格式追加新的燒錄證據。

```text
唯讀 data-change observability；不修改 PHY、PTP、servo、SI5340 寫入資料或 DCO gate。
```

只有在 data-change 證據完成後，才決定是否做 DPLL-on-top-of-helper-lock 或 SI5340 ACK/readback 的下一個單一變因。
