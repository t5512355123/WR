# 架構總覽

DE5a 設計使用搭配 Arria 10 WR PHY 的 `xwr_core`。QSFP-A lane 0 負責 White Rabbit Ethernet link。系統另外包含 SI5340/DCO 時脈控制、執行 wrpc-sw 的 uRV RISC-V soft CPU，以及輸出至 SMA_CLKOUT 的 PPS。

本 repository 將正式的 RS422 除錯基準版本與歷史實驗分開保存。本次整理只改變檔案歸屬與建置路徑，不改變 WR 資料路徑。
