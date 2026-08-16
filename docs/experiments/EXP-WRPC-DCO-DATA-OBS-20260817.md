# EXP-WRPC-DCO-DATA-OBS-20260817：DCO load 資料變化唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-DATA-OBS-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave-only diagnostics；Master 維持已知 baseline。

## 這次想驗證什麼

前一輪 HPLL continuous/DPLL isolation 顯示 DCO counter 有增加，但 Slave 仍未進入 SoftPLL tracking。這次要直接觀察 DPLL/HPLL 在每次 load 事件看到的 current data 與 previous data，區分：

1. load event 有到達，但資料值沒有變化。
2. 資料值有變化，但 CDC 或 controller 沒有形成 pending。
3. pending 已形成，但 transaction 沒有完成。

## 相較 baseline 唯一修改了什麼

只增加唯讀觀測：

- `si5340a_controller_dco.v` 新增 HPLL request state output。
- Slave 新增 `WR_DCO_HPLL_STATE_SLAVE` probe，instance index 11。
- `read_dco_diag.tcl` 同時解析 DPLL probe 10 與 HPLL probe 11。

沒有修改 PHY、DMTD、PTP、servo、SI5340 寫入資料、DCO gate、I2C transaction state machine 或 clock routing。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- branch：`exp/jtag-runtime-observability`
- source commit：`8054e4aa2a952e331412f8abaf7dbcb1c280ee87`
- pain build checkout：待 compile 前固定為 `8054e4a` detached HEAD。
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## Image provenance

### Master（本輪不修改、不重燒）

- source commit：`5e816ead4240878740dc259a5d9c55482f7dd180`
- MIF/SOF：沿用前一輪 baseline；本輪不重新生成。

### Slave（待 compile）

- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`72e832874562b061e1cc9e1a07bf4f03e0d11b56dc4d326dbbda1bd1f7575c1a`
- SOF SHA-256：`dd426ddf2529245554bf7a3ba665782f3c93ba5eff1dc6c25bebe426aeee3539`
- Quartus Full Compilation：successful，0 errors、274 warnings；Fitter successful。
- Timing：`timing_closed=NO`；setup `-0.435 ns`、hold `-3.492 ns`、recovery `1.160 ns`、removal `0.335 ns`；unconstrained clocks/input/output `3 / 736 / 81`。
- compile trace SHA-256：`3465f7ad831a53ed79b72b9654ce17ca538920826a555868a319e7ffb4d5b721`
- build log SHA-256：`565425e77c62db278e2f178404af045b13fc43e2de39703f9860bc7e00fb6944`

## 燒錄結果

- 燒錄對象：Slave，cable `DE5 [1-11.2]`
- 燒錄時間：2026-08-17 07:52:43–07:53:01（pain）
- programmer checksum：`0x30A1F2A5`
- Device JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`Quartus Prime Programmer was successful. 0 errors, 0 warnings`
- programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DATA-OBS-20260817/program_slave.log`
- programmer log SHA-256：`44ac70637d966d9a7cd7b8b171ebb6e13d66f90d628b6faef57dca7a12faff47`

本節只證明新的 diagnostic Slave image 已成功配置，不宣稱 WR synchronization 成功。

## JTAG/runtime 原始結果

待 Slave 燒錄後執行 DCO snapshot 與 60 秒唯讀 runtime session。預計保存：

- `DCO_DPLL_STATE`
- `DCO_HPLL_STATE`
- source/destination/accepted/done counters
- `SSTAT`、`PSTAT.locked`、`time_valid`、`pps_valid`
- parent metadata、PTP/servo activity

## Observation

待補入原始 log、SHA-256、accepted sample 數與 data-change 結果。

## Conclusion

在取得實際 JTAG 證據前，不宣稱 DPLL data、CDC、I2C ACK 或 SoftPLL gating 任一項為根因。

## Next Step

若 data-change snapshot 證明 DPLL data 沒有變化，下一輪只追查 DPLL correction value 的產生/CDC；若 data 有變且 pending/accepted/done 都成立，才進一步設計 SI5340 ACK/readback 或安全的 DPLL-on-top-of-helper-lock 實驗。
