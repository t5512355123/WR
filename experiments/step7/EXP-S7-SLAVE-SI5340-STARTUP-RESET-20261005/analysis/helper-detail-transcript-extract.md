# 舊 observer 輸出的摘要摘錄

來源：2026-10-05 第一次 SSH session 的工具回傳，不是重建的完整 raw log。
完整 temporary `helper-lock-detail.log` 在重新連線時已不存在；沒有以此摘錄冒充原始檔。

observer exit=0、10 samples，9 個 legacy FRAME_VALID，但 HELPER_STATE／HELPER_LIMITS／HELPER_LOCKED 均 INVALID，故 legacy frame guard 不證明 Helper detector schema 正確。

最後一筆讀值：

- HELPER_ERROR=000249F0（150000），HELPER_OUTPUT=00000005（5）。
- MAIN_ENABLED / MAIN_FREQ_LOCKED / MAIN_PHASE_LOCKED / MAIN_LOCKED / PSTAT_LOCKED = 0。
- NORMAL_REQ=0，NORMAL_COMPLETED=0，DCO_STEP=3388。
- BOOTSTRAP_COMPLETED=3388，BOOTSTRAP_DONE=1。
- FORCED_FINC=3388，FORCED_FDEC=0。
- I2C_ACK_ERROR=0，I2C_DCO_ERROR=0。
- 該短窗四項 reset counter 的增量 = 0。

這些獨立讀值僅支持下限失效與交易計數判讀；不解讀無效 detector 欄位或錯誤的 threshold 百分比。
