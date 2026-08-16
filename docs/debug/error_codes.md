# 錯誤解讀

- `link_up=1` 且 `link_ok=1`：目前可取得的 PHY/PCS link 指示訊號已被拉高。
- `time_valid=0` 或 `pps_valid=0`：不能據此宣稱 WR 時間/PPS 有效。
- `rx_enc_err=1`：在修改 WR 軟體之前，應先檢查接收端 serial/PCS 方向、lane mapping、polarity、alignment 與 optical path。
- `No In-System Sources and Probes instance was found`：代表 JTAG script 與目前燒錄的 bitstream 不相容；單靠這個訊息不能判定 WR link 失敗。
