# 實驗紀錄：Slave Helper 與 DCO 唯讀關聯觀測

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-HELPER-DCO-CORRELATION-OBS-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only diagnostic observability burn；不改 White Rabbit 功能路徑
- Git branch：`exp/master-9f-observability`
- 建立時 commit：待本紀錄初始 commit
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
- 預定使用 SOF：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818/slave.sof`
- 預定 SOF SHA-256：`f57e2b099048a3129ff51b9760a701c1b0ea4306994dbe38b32910d7345cdc1b`
- MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`

## 判準

- 診斷成功：DCO probe 可讀，並能在同一 session 取得 `STEP、HPLL_LOAD、HELPER_ERROR、HELPER_OUTPUT、HELPER_LOCKDET、TAG_VALID/TRR/IRQ`。
- 若 Helper error 長期飽和且 DCO step 增加：支持「feedback 未收斂或 DMTD/clock mapping 不正確」的方向，但仍不能單靠此證明實體 SI5340 輸出問題。
- 若 DCO step 不增加：優先查 Helper-to-DCO handoff。
- 最終同步成功仍需 Slave `spll_locked=1、time_valid=1、pps_valid=1` 並長時間穩定；本輪不是同步成功宣告。

## 編譯結果

本輪重用既有 compile provenance，不重新編譯；燒錄前仍會在 pain 端核對 SOF/MIF hash。

## 燒錄結果

本節待燒錄後立即補上 programmer 原始結果、時間、JTAG ID、checksum、SOF hash 與 log hash。

## JTAG/runtime 原始結果

本節待燒錄後補上唯讀 correlation 原始 log、hash、有效樣本數與首尾值。

## Observation

待完成。

## Conclusion

待完成；不能把診斷 probe 可讀誤寫成同步成功。

## Next Step

待完成；依 Helper error、DCO step 與 event counter 的實際關聯決定下一個單一 Slave 變因。
