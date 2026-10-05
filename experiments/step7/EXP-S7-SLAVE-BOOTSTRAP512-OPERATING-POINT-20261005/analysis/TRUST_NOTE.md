# 資料來源與可信範圍

- `raw/observe/user-dashboard-20261005T151252+0800.log` 是使用者貼回的終端輸出，為本輪 TIME_VALID 恢復的最終逐點證據；不是 agent 新發起的讀取，也不是 300 秒 series。
- `*-ready-*.log` 保存 agent 的 readiness polling；到 elapsed=540 秒仍未觸發 acceptance capture，之後為健康檢查主動暫停。不能把這些離散 short windows 拼成連續 300 秒 PASS。
- `helper-*.log` 中獨立 scalar 與 RTL L2 counter 可支持 rail/headroom、update/service progress 判讀；未通過 publication epoch guard 的 Helper multiword payload 不作 coherent-frame 證據，scalar 與 L2 間也不宣稱跨組原子性。
- `phase-mid-acquisition-60s.log` 的末段與另一個持續 dashboard（shell 33099、dashboard 39332，15:11:03 開始）重疊。`phase-mid-acquisition-60s.json` 只是既有 analyzer 原始機械輸出，它不檢查其他程序是否共用 JTAG。故其中 `diagnostic_capture_complete=true` 不能取代 acquisition exclusivity，整段 capture 不用作正式 CKO 範圍、精度或因果結論。
- 本輪未完成新的 TIME_VALID 300 秒 capture；沒有新的 300 秒 PASS JSON。Step5 flags 在 short dashboard 都為 1，不宣稱五項 PLL lock 的新 300 秒 series。
- Sequential JTAG 的 TAI/cycles 不是同時採樣，不能直接相减宣稱雙板 time skew。未做示波器或實體 jitter/edge measurement。
