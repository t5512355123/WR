# EXP-WRPC-STEP2-DCO-RESTORE-20260819

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP2-DCO-RESTORE-20260819`
- 日期：2026-08-19（Asia/Taipei）
- Git branch：`exp/restore-c88cc05-baseline`
- 功能修改 commit：`a427ed3f61a54a704c46cf1e0f650ef591f35de1`
- 實驗狀態：fresh firmware、clean Quartus、雙板燒錄與 JTAG runtime 驗證完成

## 實驗名稱

`恢復已驗證 DCO 單週期請求握手，重新建立 Step 2 fresh HEAD 候選`

## 這次想驗證什麼

確認最新 HEAD 在不改變 Master/Slave role 命令、PHY、Simple Word Alignment、WR clock/reset、PPSI/PTP 或 SoftPLL 演算法的前提下，能否重現 Step 2：

- Master：`MODE=2`、`PTP=6 (PPS_MASTER)`。
- Slave：`MODE=3`、`PTP=9 (PPS_SLAVE)`。
- 兩片 CPU marker=`B004`、`fault=0`、PHY/link 健康、MiniNIC 與 PPSI PTP RX/TX 持續增加。
- Slave 建立 foreign master，且以 source-defined mapping 解碼為 `foreign_count=1`、`best_index=0`。

這一輪不要求 `time_valid=1`、`PSTAT.locked=1` 或 SoftPLL closed loop；那些屬於後續 Step 3～5。

## 相較前一個 fresh HEAD baseline 的唯一修改

只修改：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`。

- 移除 `runtime_start_hold` 對 `bus_start` 的額外保持。
- 恢復已驗證 baseline 的單週期 `bus_start = static_start_pulse || runtime_start`。
- 保留 DCO 唯讀 debug probe；bit 52 固定為 0，避免既有 JTAG decoder 失配。

沒有修改：

- Master/Slave startup role command。
- `g_use_simple_wa => true`。
- unique MAC。
- WR signaling、PTP、servo、SoftPLL 演算法、PI、lock threshold、DDMTD polarity。
- PHY、QSFP、SI5340 register algorithm；本輪只是恢復既有 runtime request handshake。

## 來源與建置規劃

本輪已由 exact commit `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` 在 pain 隔離 checkout 完成：

1. firmware fresh build，重新產生 Master/Slave MIF。
2. Quartus 17 clean compile，重新產生 Master/Slave SOF。
3. 只燒錄這次 fresh build 的 SOF，不使用 historical `c88cc05` SOF。
4. programming 後立即保存完整 programmer output。
5. 等待 30～60 秒後執行 JTAG snapshot 與 time-series。

本輪所有 provenance 欄位均已補齊；historical `c88cc05` SOF 僅作行為參考，沒有用來完成本輪驗證。

## Fresh firmware / Quartus 建置證據

- Build checkout HEAD：`054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`。
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`。
- Quartus binary：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`。
- Master MIF SHA-256：`0d2e5a9468edc8fc7655c210c77e8122c5a980af5e66fa7f85ddfc319c2c5fb2`。
- Slave MIF SHA-256：`9b0cd0b6f70e5ce752cb93cd29ec333e3b8d73635c72b0f267fad17c6149fb58`。
- Master QSF SHA-256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`。
- Slave QSF SHA-256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`。
- Master/Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`。
- Master SOF SHA-256：`79cfac62ebfe86f338e5e79c6500956b6f3a06247c422508d5542f8b5912da1d`。
- Slave SOF SHA-256：`8b5c6652fafabf2f3a6bc0fe0b870c643a6a03dfaf0f419ff52ae32475ae4dee`。
- Master compile log：`/home/b10504072/04_WR_step2_head/build/quartus_jtag_master_compile.log`。
- Slave compile log：`/home/b10504072/04_WR_step2_head/build/quartus_jtag_slave_compile.log`。
- 結果：Master/Slave 均 `Quartus Prime Full Compilation was successful`、0 errors、270 warnings、Fitter successful。
- Timing caveat：兩片 build_info 均為 `TIMING_CLOSED=NO`；Master 摘要 worst setup/hold=`-0.177/-3.493 ns`，Slave=`-0.210/-3.488 ns`，且仍有 unconstrained clocks/ports。

## Master 燒錄結果

- 燒錄時間：2026-08-19 13:04:06～13:04:25（Asia/Taipei）。
- Cable：`DE5 [1-11.1]`。
- Programming file：`/home/b10504072/04_WR_step2_head/quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof`。
- SOF SHA-256：`79cfac62ebfe86f338e5e79c6500956b6f3a06247c422508d5542f8b5912da1d`。
- Programmer checksum：`0x30A3010A`。
- JTAG ID：`0x02E660DD`。
- 結果：`Configuration succeeded -- 1 device(s) configured`；Quartus Programmer `0 errors, 0 warnings`。
- 原始 programmer log：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-DCO-RESTORE-20260819/program_master.log`。
- Programmer log SHA-256：`004fc1176f2d74360992eb125a980018a133044ffebb9c5374f1533be11480c3`。

Master fresh SOF 燒錄成功；Step 2 結論仍以雙板 runtime acceptance 為準。

## Slave 燒錄結果

- 燒錄時間：2026-08-19 13:05:04～13:05:23（Asia/Taipei）。
- Cable：`DE5 [1-11.2]`。
- Programming file：`/home/b10504072/04_WR_step2_head/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`。
- SOF SHA-256：`8b5c6652fafabf2f3a6bc0fe0b870c643a6a03dfaf0f419ff52ae32475ae4dee`。
- Programmer checksum：`0x30A3C3D7`。
- JTAG ID：`0x02E660DD`。
- 結果：`Configuration succeeded -- 1 device(s) configured`；Quartus Programmer `0 errors, 0 warnings`。
- 原始 programmer log：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-DCO-RESTORE-20260819/program_slave.log`。
- Programmer log SHA-256：`8dbbb74cfc56a1c0032f123d7c7ab31b0373b3354148c8724d6f22b6bdf86ef5`。

雙板 fresh SOF 燒錄均成功，接著完成唯讀 JTAG runtime 驗證。

## Fresh HEAD JTAG runtime 驗證

- Snapshot 原始 log：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-DCO-RESTORE-20260819/runtime_snapshot.log`。
- Snapshot SHA-256：`a511764fa64eae7d580d28fd77f59cd33735aefdf16f7a8cfdde6a4d465851f9`。
- 30 秒時序原始 log：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-DCO-RESTORE-20260819/runtime_timeseries_30s.log`。
- 30 秒時序 SHA-256：`8cdb432c69a740a830de32bae0733f64b4caefdff0d8ae674d92b1ed7eb85926`。
- JTAG snapshot script：`scripts/jtag/read_wb_runtime.tcl`，blob SHA-1=`dae2d85faebb479d57a1732b71d0a997147dd289`。
- JTAG time-series script：`scripts/jtag/read_wb_timeseries_session.tcl`，blob SHA-1=`2fd15298b748be97ca0e2811fa9e7afd28dedf36`。
- Quartus STP：`Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings`。
- 30 秒時序：Master 30/30 筆 accepted，Slave 30/30 筆 accepted；部分 mailbox frame 因跨 register snapshot 不一致而重試，accepted sample 仍完整通過驗證。時序 log 中共觀察到 9 次需要重試的 invalid frame，未將它們誤算為功能失敗。

### Snapshot 關鍵結果

| Gate | Master | Slave | 判定 |
|---|---|---|---|
| CPU runtime | `reset=0, fault=0, im_valid=1, marker=B004` | `reset=0, fault=0, im_valid=1, marker=B004` | PASS |
| PHY/link | healthy、`RXERR=0` | healthy、`RXERR=0` | PASS |
| Endpoint MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | PASS |
| MiniNIC frame activity | `WDIAGS_TX/RX` 有活動 | `WDIAGS_TX/RX` 有活動 | PASS |
| PPSI PTP activity | `PTP_RX=0xB1, PTP_TX=0x186` | `PTP_RX=0x174, PTP_TX=0x7D` | PASS |
| PTP role | `MODE=2, PTP=6 (PPS_MASTER)` | `MODE=3, PTP=9 (PPS_SLAVE)` | PASS |
| Foreign Master | 不適用 | `FOREIGN_META=03000001`，解碼為 count=1、best=0 | PASS |

### 證據界線

本輪只驗證 Step 2 Endpoint / MiniNIC / PTP packet path。Slave 的 `PSTAT.locked=0`、`time_valid=0` 仍表示 WR timing synchronization 尚未完成；這是 Step 3～5 的後續工作，不是本輪 Step 2 failure。時序中可見 Slave 的 foreign master metadata 與 PTP counters 持續存在，支持 parent discovery 與 PTP packet path 已穩定運作。

## 結論

本輪已由 build checkout exact HEAD `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` 產生 fresh firmware/MIF 與 clean Quartus SOF，並完成雙板 programming 與 30 秒 read-only JTAG time-series。所有 Step 2 acceptance gates 均有 fresh HEAD 證據支持：

> **Step 2 Endpoint / MiniNIC / PTP packet path = PASS**

這個結論不延伸為 White Rabbit 完整時間同步成功；`PSTAT.locked=0` 與 `time_valid=0` 必須保留在後續 Step 3～5 研究範圍。

## Next Step

1. 將本紀錄與 `STATUS.md`、`docs/MERGE_READINESS.md` 提交至 `exp/restore-c88cc05-baseline`。
2. 等待研究者確認後，才執行 merge 到 `main`；本輪不自行 merge。
3. Merge 後另開 Step 3 branch，研究 WR parent/signaling，不修改本輪已驗證的 Step 2 行為。
