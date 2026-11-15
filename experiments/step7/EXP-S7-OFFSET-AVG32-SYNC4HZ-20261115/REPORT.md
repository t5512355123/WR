# EXP-S7-OFFSET-AVG32-SYNC4HZ-20261115 實驗報告

## 結論
**PASS：servo 濾波後的 CKO 以 <60 ps 進入 TRACK，連續 299.9 秒全部 ≤120 ps（目標 120 秒）。**

| 指標 | 前一輪（T24P=7500，單次交換） | 本輪（4 Hz、32 筆平均） |
|---|---:|---:|
| CKO（servo 使用值）範圍 | −540..+503 ps | **−40..+41 ps** |
| CKO 標準差 | 201 ps | **14.3 ps** |
| \|CKO\|≤60 ps | 77/283 | **446/446** |
| TRACK_PHASE | 81/283 | **446/446** |
| 最長嚴格保持 | 8.9 s | **299.9 s（PASS_CKO_HOLD）** |
| raw 單次交換 offset | — | −533..+548 ps，σ 175.9 ps，平均 −2.1 ps |
| TIME_VALID 300 s | PASS | PASS（`verify_time_valid_300s.sh` exit 0） |

判定資料：`raw/cko/20261115T024947Z-cko-mode0.log`（300 s、250 ms 輪詢、607 筆合格、446 筆獨立 servo 更新）、
`analysis/20261115T024947Z-cko-mode0-hold.json`。

## 步驟
1. 第一次 build 在 link 階段失敗：韌體沒有 64 位元除法 helper（`__divdi3`），紀錄 `raw/pipeline/pipeline-attempt1-link-fail.log`。
   改為 32 位元累加（commit `7bd9d648`；32 筆 sub-tick offset 不會溢位）後通過。
2. build → compile（timing_closed=NO）→ 燒錄 Slave、Master → TIME_VALID 300 s PASS → 等 180 s。
3. CKO 擷取：
   - mode 2（DMS/SETP 另一 frame 以 UCNT 對齊）：4 Hz 下 UCNT 在兩次讀取間前進，reader 於 22 s 以
     `five_consecutive_invalid_phase_observations` 停止（`*-cko.log`，19 筆，全部 TRACK、CKO 2..28 ps，不作判定）。
   - mode 1（同 frame）：2 s 即停止（`*-cko-mode1.log`）。
   - **mode 0（只讀 CKO/SSTAT/UCNT frame）：完整 300 s，作為判定依據。** `capture_cko_hold.sh` 預設改為 mode 0。

## 判讀與限制
- servo 的 offset 估測噪聲由約 176 ps 降到約 14 ps，與 176/√32 ≈ 31 ps 的白噪聲預期同量級（含 setpoint 修正與相關性）。
- raw 單次交換噪聲仍在（σ≈176 ps），代表兩板 RX 時間戳記 fine phase 的每封包噪聲**沒有被消除**，只是不再直接驅動 servo。
- CKO 是 PTP 時間戳記估測的偏移，**不是示波器量到的實體 PPS 邊緣差**；實體抖動需另行量測。
- 本輪 4 Hz 更新率實際約 1.5 次獨立更新／秒（446 筆／300 s），因 Delay_Req 隨機化與 servo busy 略過。
- 時序仍未收斂（下一輪處理）。
