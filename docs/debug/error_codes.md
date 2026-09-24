# 錯誤解讀

- `link_up=1` 且 `link_ok=1`：目前可取得的 PHY/PCS link 指示訊號已被拉高。
- `time_valid=0` 或 `pps_valid=0`：不能據此宣稱 WR 時間/PPS 有效。
- `rx_enc_err=1`：本任務把 QSFP-A lane 0 實體連線視為固定且已知良好；先比對目前 source、SOF、firmware/MIF、Quartus project、reset sequencing、PHY configuration、lane mapping、polarity 與 alignment。不要僅憑這個 bit 要求拔插或更換實體線路。
- `No In-System Sources and Probes instance was found`：代表 JTAG script 與目前燒錄的 bitstream 不相容；單靠這個訊息不能判定 WR link 失敗。
