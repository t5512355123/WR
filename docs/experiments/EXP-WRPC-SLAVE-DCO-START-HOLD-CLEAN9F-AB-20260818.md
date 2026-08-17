# 實驗紀錄：Slave DCO runtime_start 保持握手 A/B

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only 單一功能變因；不修改 Master role
- Git branch：`exp/master-9f-observability`
- 實驗狀態：已完成 compile、Slave 燒錄與 60 秒雙板唯讀 runtime 觀測；未達成 Slave 同步
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

確認高速 `iCLK` domain 產生的 `runtime_start` 是否因為只存在一個週期，沒有被慢速 I²C controller 的 `i2c_system_clk` domain 看見。成功判準先限定為 DCO transaction 可以完成：

- `DCO_DEBUG.BUSY` 能由 1 回到 0。
- `rt_state` 能回到 idle。
- `dco_step_count` 能從 0 增加。

這一輪不把 DCO transaction 完成誤稱為 White Rabbit 同步成功；後續仍須驗證 Slave `spll_locked=1`、`time_valid=1`、`pps_valid=1`。

## 相較 baseline 的唯一修改

- Master：維持歷史成功 `9f848ec` exact SOF，不重新編譯、不重新燒錄、不改 role。
- Slave：以 corrected-SOF 使用的 `1b52223` 三筆 runtime sequence 為基線，只新增 `runtime_start_hold`：當 `runtime_start` 出現時保持 `bus_start`，直到 I²C `bus_state` 回報 busy 才清除。
- 不修改 page sequence、FINC/FDEC 方向、DMTD、PI、threshold、lock detector、PHY、PTP 或 firmware。

## 目前 compile 前 provenance

- 預計 source：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`
- 基準 source：`1b52223b4bcab4f440189ce95c8219edb811675c`
- 本輪唯一 RTL 變因：`runtime_start_hold`
- 預計 compile command：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh --flow compile DE5a_wr_slave_jtag`
- 預計 Slave cable：`DE5 [1-11.2]`

## Compile provenance

待 compile 完成後補入：

- source commit：`548d0b0558b0ea73f42353dbd5913e9b7036258c`
- SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- SOF SHA-256：`001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee`
- Slave MIF：`/home/b10504072/04_WR/build/firmware/slave/wrc.mif`
- Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- compile log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/compile_start_hold.log`
- compile log SHA-256：`bd144330217388f20c33f38d76ed03a853fd7e7e86efc9a8ae5c0d95d1e989d9`
- 結果：Quartus Prime Full Compilation、Fitter、Assembler、TimeQuest 均成功，0 errors；完整流程 270 warnings。
- Timing caveat：不同 corner 的 worst-case setup 為 `-0.832 ns`，worst-case hold 為 `-4.096 ns`；TimeQuest 明確表示 setup/hold 未完全約束，因此不宣稱 timing closure。

## 燒錄結果

compile 已成功並完成 hash 核對；本輪已完成燒錄。燒錄後立即記錄：

- Programmer command：`quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- Programmer version：Quartus Prime Programmer 17.0 Build 595 Standard Edition
- 燒錄時間：2026-08-18 06:25:12 開始，06:25:16 開始 configuration，06:25:30 完成
- Programmer cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- SOF SHA-256：`001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee`
- Programmer checksum：`0x30A22D41`
- configuration result：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer result：0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/program_slave_start_hold.log`
- Programmer log SHA-256：`5a88c58a440a113d54892f34c771b9b35c187279d0218c06e6875b6e79ba3d69`
- 為排除前一輪 JTAG session 對 runtime 狀態的干擾，於 2026-08-18 06:37:52 以**完全相同的 SOF**重新燒錄 Slave；沒有 source、MIF、QSF、role 或 PHY 變更。
- 重複燒錄 command：`quartus_pgm -c "DE5 [1-11.2]" -m jtag -o 'p;/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof'`
- 重複燒錄結果：同一 JTAG ID `0x02E660DD`、同一 Programmer checksum `0x30A22D41`、`Configuration succeeded -- 1 device(s) configured`、0 errors、0 warnings。
- 重複燒錄原始 log：`artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/program_slave_start_hold_repeat.log`
- 重複燒錄 log SHA-256：`843D4232062CAEFED73BDBCDFC40E49F6DF85DA7CE8C9F1C99C186519FB13EAF`

## JTAG/runtime 原始結果

本輪完成兩組唯讀觀測，原始檔案與 SHA-256 如下：

- DCO correlation：`artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/dco_correlation_60x500ms.log`
  - SHA-256：`8F5FD1A41C47ED92AC2C6F6FD67D0CB08C3FB0F11E4CEACC06FFAD61C2E2C5A2`
- 雙板 60 秒 time-series：`artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/runtime_full_timeseries_60s.log`
  - SHA-256：`AD70B69E0AA64AB4C87F23EBFA7975F276F6B8927C5910DC3DAE164DC2FA92CF`
- JTAG 指令：`timeout 420s quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 3 2>&1 | tee artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/runtime_full_timeseries_60s.log`
- JTAG 結果：SignalTap/Quartus Prime SignalTap II script 成功，0 errors、0 warnings，`SESSION_TIME_SERIES_DONE`。
- Master：60/60 筆 `accepted=1`；有效樣本維持歷史 baseline 的 `status_low=FF`、`wr_mode=2`、`WDIAGS_PTP=6`、`time_valid=1`、`pps_valid=1`，PTP RX/TX 有活動。
- Slave：60 筆樣本，52 筆 `accepted=1`、8 筆在 3 次 retry 後仍不接受；可接受樣本中約 46 筆為 `status_low=EF`、`link_up=1`、`pps_valid=1`、`time_valid=0`、`wr_mode=3`、`spll_locked=0`；另有 2 筆 `status_low=CF` 且 link_up=1，10 筆 `status_low=CF` 且 link_up=0。
- Slave 60 秒主要診斷欄位：`WDIAGS_SSTAT=0`、`WDIAGS_PSTAT=1`、`WDIAGS_UCNT=0`、`spll_locked=0`；這表示尚未觀察到 servo state 前進、SoftPLL lock 或 update counter 活動。
- DCO correlation：60 筆中 `STEP=10` 共 17 筆、`STEP=12` 共 23 筆、`STEP=14` 共 20 筆；全程 `BUSY=0`、`ERROR=0`，最後 `STEP=14`，`HELPER_ERROR=0`、`HELPER_OUTPUT=0`（以該診斷 probe 的定義為準）。
- 另一次執行 `read_dco_state.tcl` 的結果是兩片板都回報 `No In-System Sources and Probes instance was found`；該腳本讀取不存在的 instance 9，因此判定為腳本/instance 編號不匹配，不列為硬體失敗證據。
- 修正 instance 8 後重新執行 `read_dco_state.tcl 1000`：Slave 成功讀到 `A=B=00A8000000D00320`，解碼為 `rt_state=0、bus_state=0、bus_done=0、ready=1、busy=0、steps=13、hold=0`；Master 沒有 DCO probe，故回報無 instance 是預期結果。固定腳本 log：`artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/dco_state_readonly_fixed.log`，SHA-256：`78FD788BDE03D221D629234C422AF8A186275B96D1A2F2C1D708E778ABCDD78E`。
- 同一 SOF 重新燒錄後的 20 samples/1 s 雙板 session：Master `20/20 accepted`；Slave `16/20 accepted、4/20 retry-limit rejected`。Slave accepted frame 仍主要為 `status=EF、link_up=1、pps_valid=1、time_valid=0、wr_mode=3、PSTAT=1、SSTAT=0、UCNT=0、spll_locked=0`；沒有觀察到 servo state 或 SoftPLL lock 前進。原始 log：`artifacts/EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818/runtime_after_repeat_20samples.log`，SHA-256：`07F05A8A2F57818D2E0C2326735522CE08D3EDED1EDB98FC0E36AD97694673F1`。

## Observation

本輪證據支持 DCO runtime transaction 已完成：`BUSY` 能回到 0，且 `STEP_COUNT` 由 10 經 12 增加到 14。這證明 start-hold 變因至少讓 DCO 寫入流程完成，但不是 White Rabbit 同步成功證據。

Slave 的 PTP/PHY 基本路徑部分存在：多數有效樣本 `link_up=1`、`pps_valid=1`、`wr_mode=3`，但 `time_valid=0`、`PSTAT.locked=0`、`SSTAT=0`、`UCNT=0`。因此目前不能宣稱 Slave servo 已啟動或兩板已同步。

觀測期間 JTAG frame 有 8/60 筆在 retry 上限後不接受，且少數樣本出現 link/status 暫時下降；這些列不被拿來拼接同步結論，並且已完整保留原始 log。

## Conclusion

本輪只支持以下保守結論：`runtime_start_hold` 改善了 DCO/I²C start-accept handshake 的證據，因為交易完成且 step counter 有變化；但 Slave 仍未通過 servo/SoftPLL/time-valid 判準。現有資料尚不足以把根因唯一指定為 feedback、DMTD、signal handoff 或 time-valid gating。

## Next Step

下一輪仍只做 Slave 單一變因，不修改 Master role：先依 White Rabbit 討論結果決定是否只將 `g_softpll_reverse_dmtds` 從 `true` 改回 `false`，用來驗證 DDMTD 取樣方向；若採用此變因，其他 DCO FSM、FINC/FDEC、PI、threshold、lock detector、PHY、PTP 與 MIF 全部保持不變。成功判準不是只看 link up，而是 Slave 能在有效 frame 中達到 `time_valid=1、pps_valid=1、PSTAT.locked=1、SSTAT` 前進且 `UCNT` 持續增加。若不採用 generic 變更，則維持目前 SOF，先擴充同一 instance 8 的 DCO/servo 唯讀 correlation。
