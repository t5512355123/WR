# 除錯架構

除錯證據分成三個層次：

1. FPGA 設定結果與 Quartus 報告。
2. Link/status probe 證據。
3. WRPC 執行期證據，例如 UART、PTP 狀態、SoftPLL 與 PPS。

只看到 link-up probe，不代表時間同步已經成功。每一個實驗都必須清楚寫明實際證明了哪一個層次。
