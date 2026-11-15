# EXP-S7-OFFSET-AVG32-SYNC4HZ-20261115

## 目標
Slave CKO 以 `|CKO|<60 ps` 進入 TRACK 後，連續 120 秒維持 `|CKO|≤120 ps`。

## 背景
前一輪（EXP-S7-MASTER-T24P-7500-20261115）已消除 8 ns 歧義；剩下的是每次 PTP 交換約 185 ps（σ）的獨立 offset 估測噪聲，
來源是兩邊 RX 時間戳記 fine phase 的每封包噪聲。

## 本輪變更（估測器，不動 FPGA 迴路）
1. `ppsi/include/ppsi/constants.h`：`PP_DEFAULT_SYNC_INTERVAL`、`PP_DEFAULT_MIN_DELAY_REQ_INTERVAL` 0 → −2（每秒 4 次）。
2. `ppsi/proto-ext-common/wrh-servo.c`：保留最近 32 筆 offset，並以其後 setpoint 變化補償後取平均（約 8 s 視窗）。
   - WAIT_OFFSET_STABLE：收滿 32 筆才判斷；平均 <60 ps 進入 TRACK，否則以平均值的 1/2 修正 setpoint。
   - TRACK_PHASE：平均 >120 ps 撤回 SYNC_PHASE；否則 setpoint += 平均/8。
   - 60/120 ps 門檻（`WRH_SERVO_OFFSET_STABILITY_THRESHOLD`）不變。
3. `lib/task-diags.c`：JTAG 的 CKO 暫存器改為 servo 使用的濾波 offset；原本永遠為 0 的 ASYM 暫存器改放 raw 單次 offset。
4. `scripts/jtag/read_step6_servo_interleaved_offset.tcl` 新增 `S6_RAW_OFFSET ... RAW_OFFSET_PS=`；
   `scripts/analysis/cko_hold.py` 同時統計 raw 與濾波值。

## 注意
CKO 改為「濾波後的 offset 估測」，代表多次交換的平均時間偏移；單次交換的噪聲仍在 raw 欄位中，並未消失。
這不是實體 PPS 邊緣抖動的量測。

## 結果
（實驗後填寫）
