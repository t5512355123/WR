# 實驗紀錄：Slave Helper 與 DCO 正確映像關聯觀測

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-CORRECT-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only diagnostic observability；不改 Master role 與 White Rabbit 控制演算法
- Git branch：`exp/master-9f-observability`
- source commit：`1b52223b4bcab4f440189ce95c8219edb811675c`
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

前一輪使用了被 page-3/start-hold 編譯覆寫的輸出檔，雖然 DCO probe 可讀，卻沒有 positive-control 的 servo 活動。本輪重新從正確的 clean-9f DCO-observability source 編譯，目標是建立可追溯的 Slave 映像，並在燒錄後用唯讀 JTAG 同時觀察：

- TAG、TRR、IRQ 與 SoftPLL event 是否持續活動。
- Helper error/output 與 Helper/Main lock detector 的狀態。
- SI5340 DCO transaction 是否產生新的 step，以及 step 後 Helper error 是否變化。

## 相較 baseline 的唯一變因

- Master：維持歷史成功 `9f848ec` exact SOF，不重新燒錄、不改 role。
- Slave：只使用 clean-9f Slave 加入唯讀 DCO probe 的 source commit；不改 PHY、`g_softpll_reverse_dmtds`、PTP、servo、DCO page sequence、FINC/FDEC 方向、PI、threshold 或 lock detector。
- 本輪另外修正的是觀測腳本的讀取 index/bit mapping，不是 FPGA 功能路徑。

## Compile provenance

- Quartus command：`quartus_sh --flow compile DE5a_wr_slave_jtag`
- pain checkout：`1b52223b4bcab4f440189ce95c8219edb811675c`
- SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- SOF SHA-256：`60c04349cc76da8668c8c373541d031b82bdfab27197165ba7784278f5e7258b`
- Slave MIF：`/home/b10504072/04_WR/build/firmware/slave/wrc.mif`
- MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Compile log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-OBS-20260818/compile_clean9f_dco_correct_source.log`
- Compile log SHA-256：`d4b5406bff8ec5c2098be59fe795a044319d0f38c7efbcf516a0b7de46ee588`
- 結果：Full Compilation、Fitter、Assembler、TimeQuest 均成功，0 errors；完整流程 270 warnings。
- Timing caveat：TimeQuest 顯示 worst-case hold slack 在不同 corner 最差為 `-4.081 ns`，且 design not fully constrained；因此本輪是診斷用 build，不宣稱 timing 完全收斂。

## 燒錄結果

- 燒錄時間：2026-08-18 06:04:22 開始，06:04:25 執行，06:04:40 完成（pain terminal）。
- Programmer：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm`，版本 17.0 Build 595。
- Programmer cable：`DE5 [1-11.2]`。
- JTAG ID：`0x02E660DD`。
- 使用 SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`。
- SOF SHA-256：`60c04349cc76da8668c8c373541d031b82bdfab27197165ba7784278f5e7258b`。
- Programmer checksum：`0x30A04DFA`。
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-CORRECT-20260818/program_slave_correct_dco.log`。
- Programmer log SHA-256：`b346f2a2d0c9f37083f5453261bb782fdc8df647aaebcae81ec76d89020a3169`。
- 結果：configuration succeeded，1 device configured，Quartus Programmer 回報 0 errors、0 warnings。

## JTAG/runtime 原始結果

- 觀測命令：`quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 60 500`。
- 原始 correlation log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-CORRECT-20260818/hpll_helper_correlation_60s.log`。
- correlation log SHA-256：`b5ec2f2f3c436b5d98130043b180244ce15016195bbec2b5e24fd0ed527d5329`。
- Master：沒有 instance 8 DCO probe，腳本回報 probe 不存在；這是 Master frozen baseline 的預期介面差異，不是 Master programming failure。
- Slave：60/60 筆 `HPLL_HELPER_SAMPLE` 成功讀取，Quartus SignalTap 腳本完成並回報 0 errors、0 warnings。
- 首筆 Slave：`SSTAT=00000101`、`PSTAT=00000001`、`SPLL_STATE=00030004`、`DCO_DEBUG=FFB800000008A3A2`、`STEP=0`、`HPLL_LOAD=0`、`BUSY=1`、`ERROR=0`、`HELPER_ERROR_SIGNED=-150000`。
- 末筆 Slave：`SSTAT=00000001`、`PSTAT=00000001`、`SPLL_STATE=00030004`、`DCO_DEBUG=FFB800000008A3A2`、`STEP=0`、`HPLL_LOAD=0`、`BUSY=1`、`ERROR=0`、`HELPER_ERROR_SIGNED=-150000`。

## Observation

corrected-SOF 已排除前一輪輸出檔覆寫問題，Slave 確實進入了 active SoftPLL 路徑：`SSTAT` 的有效位為 1，`SPLL_STATE` 的 sequence state 為 4，且 `PSTAT` 的 link bit 為 1。但 60 筆中 DCO debug 完全固定，沒有 step event；`BUSY=1` 持續存在，`HPLL_LOAD=0`、`ERROR=0`，而 Helper error 多數飽和在 `-150000`，Helper output 多數也在同一個 clamp 附近。部分單次 mailbox 讀值會因不同欄位更新時序而短暫變化，因此以首尾與固定 DCO debug 欄位作主要判斷。

## Conclusion

本輪仍未同步成功，但已取得有效的定位證據：Slave 已經通過 link/parent/servo 的前段並進入 sequence state 4；目前主要阻塞點優先落在 Helper correction 到 HPLL/DCO transaction 的完成路徑。`BUSY=1`、`STEP=0`、`HPLL_LOAD=0` 表示在這 30 秒左右的有效觀測期間沒有完成 DCO step。這支持「DCO/I2C transaction 或 helper-to-DCO handoff 卡住」為領先假設，但不能僅靠這組 probe 排除 SI5340 實體回應、clock-domain crossing 或 DMTD feedback 問題，也不能宣稱已證明根因。

## Next Step

先不修改 Master、PHY、DMTD、PI、threshold 或 lock detector。下一步應在同一 corrected-SOF 上增加更直接的唯讀 DCO/I2C transaction state、ack/error、clock-divider activity 與 HPLL load 脈衝觀測；若確認 transaction state 卡在等待 ack，再只改一個 DCO controller 的 clock-domain/ack handoff 變因。若 transaction 完成但 error 不收斂，才轉向 feedback/DMTD mapping。每個分支都要重新編譯、核對 hash、燒錄後立即新增實驗紀錄。
