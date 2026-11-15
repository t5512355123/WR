# EXP-S7-MASTER-T24P-7500-20261115

## 目標
Slave CKO 以 `|CKO|<60 ps` 進入 TRACK 後，連續 120 秒維持 `|CKO|≤120 ps`（TRACK_PHASE、TIME_VALID 皆成立）。

## 前一輪觀察（EXP-S7-MAIN-REVALIDATION-20261115 baseline，180 s）
- CKO −2521..+3799 ps、標準差 1838 ps；162 筆更新中 146 筆停在 WAIT_OFFSET_STABLE，只 1 筆 TRACK。
- **30 次 DMS（單向延遲）跳變 >2 ns**，每次約 ±4 ns，CKO 同步跳 ±4 ns → round-trip 整整差一個 8 ns 週期。
- `pll stat`：Master `active_t24p_ps=2389`（韌體預設值，從未量測）；Slave 本次開機實測 `7600`（R7500／F3700）。
- `lib/net.c` 線性化：若 T24P 與真實計數器翻轉點相差 >2 ns（±25% 週期），在翻轉點附近會選錯計數器而差 8 ns。
  若 Master 真實翻轉點與 Slave 相近（~7500），則 2389 偏離約 2.9 ns（mod 8 ns），超出容許範圍；
  Master RX phase 隨 Slave SETP 在約 3000–5500 ps 移動，經過 falling counter 真實翻轉點（~3600 ps）時就會跳 8 ns。

## 本輪唯一變更
- `vendor/wrpc-sw/include/dev/rxts_calibrator.h`：`DEFAULT_T24P_PHASE_TRANSITION` 2389 → **7500**。
  Master 無法自行掃描校準（只會從 storage 載入，失敗即用預設值），因此改預設值。
  Slave 每次開機自行量測，不受影響（只有校準失敗時才使用預設值）。
- 新增 `scripts/analysis/cko_hold.py`、`scripts/monitor/capture_cko_hold.sh`（唯讀擷取與嚴格保持判定）。

## 判定
`bash scripts/monitor/capture_cko_hold.sh` → `PASS_CKO_HOLD`（最佳連續保持 ≥120 s）。
另觀察 DMS 跳變次數是否降為 0。

## 結果
**FAIL（部分改善）**：8 ns 跳變 30→0、CKO σ 1838→201 ps，最佳嚴格保持 8.9 s。詳見 [REPORT.md](REPORT.md)。
