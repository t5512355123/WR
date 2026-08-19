# 實驗紀錄：Slave Helper 與 DCO 唯讀關聯觀測

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-OBS-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only diagnostic observability burn；不改 White Rabbit 功能路徑
- Git branch：`exp/master-9f-observability`
- 建立時 commit：`eaffb3e`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

目前已知 positive-control Slave SOF 能重現 `WR_LOCK`、RCER、TAG/REF/TRR/IRQ 活動，但 `HELPER_LOCKDET=0、MAIN_LOCKDET=0、spll_locked=0`。本輪要把 Helper error/output、DCO request/step 與 SoftPLL event counter 放在同一個唯讀時間序列，區分：

1. Helper 是否真的收到有效 tag 並產生 correction。
2. Correction 是否傳到 DCO transaction。
3. DCO step 增加後，下一筆 Helper error 是否朝收斂方向變化。

## 相較 baseline 的唯一變因

- Master：維持歷史成功 `9f848ec` exact SOF，不重新燒錄、不改 role。
- Slave：由目前沒有 DCO probe 的 positive-control SOF，換成先前已編譯的 clean-9f DCO-observability SOF。
- 唯一修改性質：只增加唯讀 DCO debug probe；不改 PHY、`g_softpll_reverse_dmtds`、PTP、servo、DCO page sequence 或 FINC/FDEC 方向。

## Provenance

- Slave diagnostic source commit：`1b52223b4bcab4f440189ce95c8219edb811675c`
- 已有 compile record：`EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818`
- 實際燒錄檔案來自 pain 端當時已存在的編譯輸出；該輸出後來被 page-3/start-hold 編譯覆寫，因此不能把它追溯宣稱為 `1b52223b4bcab4f440189ce95c8219edb811675c` 的新編譯結果。
- 實際使用 SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- 實際 SOF SHA-256：`1e315904af9033f52551a68844a4fd274a8506f13523c10cc0b3fd570c0d494b`
- MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`

## 判準

- 診斷成功：DCO probe 可讀，並能在同一 session 取得 `STEP、HPLL_LOAD、HELPER_ERROR、HELPER_OUTPUT、HELPER_LOCKDET、TAG_VALID/TRR/IRQ`。
- 若 Helper error 長期飽和且 DCO step 增加：支持「feedback 未收斂或 DMTD/clock mapping 不正確」的方向，但仍不能單靠此證明實體 SI5340 輸出問題。
- 若 DCO step 不增加：優先查 Helper-to-DCO handoff。
- 最終同步成功仍需 Slave `spll_locked=1、time_valid=1、pps_valid=1` 並長時間穩定；本輪不是同步成功宣告。

## 編譯結果

本輪重用既有 compile provenance，不重新編譯；燒錄前仍會在 pain 端核對 SOF/MIF hash。

## 燒錄結果

- 燒錄時間：2026-08-18 05:49:18 開始，05:49:22 執行，05:49:37 完成（pain terminal）。
- Quartus Programmer：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm`，版本 17.0 Build 595。
- Programmer cable：`DE5 [1-11.2]`。
- JTAG ID：`0x02E660DD`。
- 使用 SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`。
- SOF SHA-256：`1e315904af9033f52551a68844a4fd274a8506f13523c10cc0b3fd570c0d494b`。
- Programmer checksum：`0x30A4F803`。
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-OBS-20260818/program_slave_helper_dco_obs.log`。
- Programmer log SHA-256：`b0c2384309f313e3e0f2e793f1484ba1b8060ff8f94b7809b2a88d25da2932c3`。
- 結果：JTAG ID 正確，configuration succeeded，Quartus Programmer 回報 0 errors、0 warnings。
- 先前一次使用相對命令名稱的嘗試只得到 `quartus_pgm: command not found`，沒有執行 programming，因此不列為本實驗的燒錄結果。

## JTAG/runtime 原始結果

- 修正觀測腳本 commit：`588b5f8`；使用 instance 8 與 `si5340a_controller_dco.v` 的實際 bit mapping。
- 原始 correlation log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-OBS-20260818/hpll_helper_correlation_60s_corrected.log`。
- correlation log SHA-256：`fef7952110aa913890d95374631e895a9aeef22f805688c9652dcbdf35c654df`。
- 觀測設定：每張板 60 筆、間隔 500 ms；Master 因沒有 DCO probe 而回報 probe 不存在，Slave 完成 60/60 筆讀取。
- Slave 首筆與末筆的 DCO debug 都為 `00A8000002C02B20`，解碼為 `STEP=44、HPLL_LOAD=0、BUSY=0、ERROR=0`；60 筆中沒有 step 增加。
- Slave 的 `HELPER_STATE=00000000、HELPER_ERROR=00000000、HELPER_OUTPUT=00000000、PSTAT=0、SSTAT=0` 全程沒有顯示 positive-control 曾出現的 TAG/REF/TRR/IRQ/servo 活動。
- Quartus SignalTap 腳本本身完成，回報 0 errors、0 warnings；但這只證明腳本執行完成，不代表取得了可用的 SoftPLL correlation 證據。

## Observation

這次實際燒錄映像可以讀到 Slave DCO probe，但讀到的是沒有 SoftPLL event 活動的狀態。`STEP=44` 固定不變，不能解讀成「Helper 誤差為零」；因為 Helper、PSTAT、SSTAT 也同時都是零。結合先前 compile provenance，實際使用的 `1e315904...` 是 page-3/start-hold 編譯輸出，而不是本實驗原本計畫的 clean-9f positive-control DCO 版本。這是實驗版本對應錯誤，不能作為 Servo 根因證據。

## Conclusion

本輪沒有取得可用的 Helper/DCO 關聯證據，也沒有同步成功。唯一可以確認的是：校正後的唯讀腳本能在 Slave instance 8 上正常讀取，但實際燒錄的映像沒有進入可觀測的 positive-control servo 活動。下一輪必須先以正確 source commit 重新編譯並核對 SOF/MIF/hash，再進行相同觀測。

## Next Step

從 `1b52223b4bcab4f440189ce95c8219edb811675c` 重新建立乾淨的 Slave DCO-observability 編譯輸出，保存新的 compile log、SOF hash、MIF hash 與 timing 結果；確認燒錄前後 source/output provenance 一致後，再重跑 60 秒唯讀 correlation。Master 維持歷史 `9f848ec` SOF，不修改 role、PHY、DMTD、PI、threshold 或 lock detector。
