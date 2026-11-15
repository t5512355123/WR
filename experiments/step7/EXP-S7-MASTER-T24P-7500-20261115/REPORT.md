# EXP-S7-MASTER-T24P-7500-20261115 實驗報告

## 結論
**8 ns 時間戳記歧義已消除，但 CKO 嚴格保持仍 FAIL（最佳 8.9 s / 需 120 s）。**

| 指標 | Baseline（T24P=2389，同日 09:36） | 本輪（T24P=7500） |
|---|---:|---:|
| DMS 跳變 >2 ns | 30 | **0** |
| CKO 範圍 | −2521..+3799 ps | **−540..+503 ps** |
| CKO 標準差 | 1838 ps | **201 ps** |
| TRACK_PHASE 筆數 | 1/162 | 81/283 |
| 最長嚴格保持（<60 進入、≤120 維持） | 0 s | 8.9 s |
| TIME_VALID 300 s | PASS | PASS（`verify_time_valid_300s.sh` exit 0） |

## 步驟
build → compile（兩設計 timing_closed=NO）→ 燒錄 Slave、Master → 等待 TIME_VALID 並驗證 300 s → 等 60 s →
`DURATION_MS=300000 bash scripts/monitor/capture_cko_hold.sh`（Slave，250 ms 輪詢，283 筆獨立更新）。

## 殘差分析（離線，`raw/cko/20261115T020720Z-cko.log`）
- 相鄰更新 CKO 差值標準差 254 ps（SETP 未變時 269 ps）> CKO 本身 201 ps → 以**每次更新獨立的白噪聲**為主，不是慢漂移，也不是 servo 修正造成。
- DMS 每次更新也有約 150 ps 獨立噪聲；實體光纖延遲不可能每秒變動 150 ps，故主要是**時間戳記量測噪聲**。
- 以 forward≈DMS+CKO、return≈DMS−CKO 分解：兩方向每次更新白噪聲約 250／233 ps，近乎相同 → TX 時間戳記為數位精確值，
  因此 **Master 與 Slave 兩邊的 RX 時間戳記 fine phase 都有約 200 ps 量級的每封包噪聲**。
- Si5340 N0 FSTEPW=128 → 每個 FINC/FDEC 約 1.8 ppb，步階太細，不足以解釋數百 ps 的每秒噪聲。
- `pll ts4` 四時間戳記診斷指令不在目前韌體中（reader exit 3，紀錄保留於 `raw/cko/*four-ts.log`）。

## 判讀
單次 PTP 交換的 offset 估測噪聲約 185 ps（σ），在 120 s（約 107 次更新）內不可能每筆都 ≤120 ps。
標準 WR servo 不濾波，是因為一般 WR 硬體時間戳記噪聲只有數 ps；本硬體需要以多次交換平均來估測 offset。

## 下一步（EXP-S7-OFFSET-AVG32-SYNC4HZ-20261115）
提高 PTP 交換率（1 Hz → 4 Hz），servo 以最近 32 筆（約 8 s）經 setpoint 補償的平均 offset 作為進入／撤銷與修正依據；
raw 單次 offset 另外公開以便比較。
