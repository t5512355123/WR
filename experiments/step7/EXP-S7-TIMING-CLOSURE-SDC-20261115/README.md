# EXP-S7-TIMING-CLOSURE-SDC-20261115

## 目標
1. Master／Slave 兩個設計 TimeQuest 所有 corner 的 setup/hold/recovery/removal slack ≥ 0（`timing_closed=YES`）。
2. 不破壞前一輪成果：TIME_VALID 300 s 與 CKO 嚴格保持（<60 ps 進入、≤120 ps 維持 ≥120 s）重新驗證。

## 前一輪的時序狀態（同一份 compile，quartus_sta 逐 corner 列出負 slack 路徑）
- 唯一違規：**removal，slow 0 °C corner**，Master −0.219 ns／Slave −0.187 ns。
  `wrc_periph|rst_net_n_chain[0]`（62.5 MHz 系統時脈）→ endpoint `ep_tscr_rx_cal_start_sync0/1/2`、`regs_o.tscr_rx_cal_start_o`（RX 時脈）。
- 另發現 SDC 第 4 行 `create_generated_clock ... [get_registers {*|clk_dmtd_62m496}]` **沒有匹配到任何暫存器**
  （Critical Warning 332049），DMTD 62.5 MHz 時脈域完全沒有被分析。

## 本輪變更（只改兩個 .sdc，不改 RTL）
1. DMTD 除 2 暫存器在 top entity，pattern 改為 `{clk_dmtd_62m496}`，並檢查剛好匹配 1 個。
2. `set_clock_groups -asynchronous -group [get_clocks wr_core_dmtd_62m496]`：DMTD（124.992 MHz/2）本來就與所有時脈非同步，
   跨域皆經 gc_sync／gc_pulse_synchronizer2。
3. `set_false_path -from rst_net_n_chain[0] -to {ep_tscr_rx_cal_start_sync0/1/2, regs_o.tscr_rx_cal_start_o}`：
   重置時這 4 個暫存器與其資料輸入皆為 0，非同步重置釋放即使亞穩也不會改變值；限定剛好 1→4 個節點，否則 SDC 報錯。

## 預覽（舊 placement + 新 SDC，quartus_sta）
- 原 removal 違規消失。
- 只剩 DMTD feedback sampler 內 Codex 加的 `dbg_d0_*` 偵錯計數器約 −0.2 ns hold；舊 fit 未約束 DMTD，fitter 沒有修 hold，預期重新 fit 後解決。

## 結果
（實驗後填寫）
