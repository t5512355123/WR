# White Rabbit milestone 索引

## 主程式最新實機驗證 — 2026-10-05

**兩台 Step6 TIME_VALID 300 秒採樣驗證皆通過（PASS）。**
本次觀測 Pain 主程式已運行的狀態：
Master 有 1190/1190 筆有效採樣，跨度 302874 ms、最大間隔 257 ms；
Slave 為 359/359 筆、跨度 302667 ms、最大間隔 909 ms。
兩台皆無無效採樣或讀取錯誤。
現有主程式產物來自 `bcb84305`，紀錄整理於 `9b8a231c`。
控制參數維持 `/2 + /12`、60/120 ps；
操作腳本仍可編輯，不加入 SHA 驗收檢查。
本次驗證未建置、燒錄、重置或修改正式封存。

Slave CKO 的 243 筆可信且不重複更新介於 −490～+459 ps，
峰對峰為 949 ps，中位數 −44 ps，標準差 171.3 ps。
五項 PLL 鎖定信號在全部採樣中皆為 1，採樣中的重置識別資訊未改變。
本次重新驗證 TIME_VALID 維持能力，不代表持續 ±60/120 ps 精度、
實體抖動／邊緣時間差或每次冷啟動都成功。
先前獨立啟動失敗的紀錄仍保留於唯讀封存。

[最新報告與時間軸圖](experiments/step6/EXP-S6-LIVE-TIME-VALID-CKO-300S-PROMOTION-20261005/REPORT.md)。
下表列出唯讀封存，不是目前主程式的 SOF 組合。
Step6 原始碼／SOF 參照已依封存既有紀錄修正，唯讀封存本身保持不變。

只有已完成乾淨建置、燒錄，並在兩台 DE5a 實機驗證的凍結版本，
才在此標記為 `PASS`。歷史報告與 SOF 雜湊是來源紀錄，不能取代重現證據。
依使用者於 2026-10-01 修訂的 Step6 門檻，兩台必須各自於至少 300 秒的採樣窗中，
每筆輸出皆維持 `STATUS_TIME_VALID=1`。
快照／PPS 旗標、計數器資料與遞增、相位 offset、Step1／連線、
Step5 鎖定及時序收斂皆不是此門檻。

| 階段 | 目標 | 狀態 | 正式 milestone 路徑 | 原始碼版本 | Master SOF SHA-256 | Slave SOF SHA-256 | 實驗證據 | 已知限制 |
|---:|---|---|---|---|---|---|---|---|
| 1 | PHY／連線 | **通過（PASS）** | [`artifacts/milestones/step1_phy_link/`](artifacts/milestones/step1_phy_link/) | `b8d4c3d0526f0c2ca282600ef06648dd9f0af595` | `f2e2136e8159ba9135313536f1a641c0865dbf36f267e06ef7826e0363f8c07e` | `15997ca2dd2ea2597d7f25af5522afc0144219769450824c0a7e31526cd44112` | [Step1 重現紀錄](experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/) | 不代表 Endpoint／PTP 或後續階段已驗證。 |
| 2 | Endpoint／MiniNIC／PTP | **通過（PASS）** | [`artifacts/milestones/step2_endpoint_ptp/`](artifacts/milestones/step2_endpoint_ptp/) | `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` | `891ba2ca901cf307edc92223f1115387895b64f20441d8c4adeb3994179548ee` | `fd4339f4d324d9b63cf60c3fb7e627abe6d6a3ff4f7f2e1df558f764ad5a270c` | [Step2 重現紀錄](experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/) | Master 時間序列有 20/30 筆通過一致性檢查；未要求或宣稱時序收斂。 |
| 3 | WR parent／信令握手 | **通過（PASS）** | [`artifacts/milestones/step3_wr_handshake/`](artifacts/milestones/step3_wr_handshake/) | 凍結封存版本 `f235b557ad09d9b37adff2c2b11b36f615f66e9e`；原始碼來源 `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` | `0cae1a4d4c800c3a67e5dcac7ca4abf739475867119ac333d0d71ef39380acf2` | `f196de1f5d431a493c2a8ce0aaeeb34d202f4d04f30c340977a4b771049896de` | [Step3 重現紀錄](experiments/step3/EXP-S3-MILESTONE-REPRO-20260924/) | 只證明 WR parent／信令與進入 SoftPLL 鎖定的呼叫路徑，不宣稱 SoftPLL 鎖定、全域時間或時序收斂。未提供有原始碼依據的重置世代計數器；報告已說明採樣中的重置可觀測性限制。 |
| 4 | SoftPLL 啟動 | **通過（PASS）** | [`artifacts/milestones/step4_softpll_startup/`](artifacts/milestones/step4_softpll_startup/) | 凍結封存 `393f402c6af420b45e9ffa1f0b936cdfd017982c`；歷史來源 `a1980bff30231376a3182486fd786d906876c2d4` | `55cb04191f3e0793623a55ada6c9e842b6d92d26ba196f1b057c5d5595d57717` | `b6b87623d8c7cb4660a04e97bd7a0ce5792783fdd3e6d04a64880307bb26612e` | [Step4 重現紀錄](experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/) | 已重現 Step4A／4B 啟動及事件處理鏈。當時 Step5 第一個未成立信號為 MAIN_PHASE_LOCK；時序未收斂，也未宣稱收斂。 |
| 5 | SoftPLL 完整鎖定 | **通過（PASS）** | [artifacts/milestones/step5_softpll_lock/](artifacts/milestones/step5_softpll_lock/) | 凍結原始碼 26e138fdc0bfc8426704b397141d563cf4d580a2；觀測器 47d9a394e53eda31476c82de2a85ad82573494ed；重現工作目錄版本 6f1096d7f957beeb2f0c065f7219960bae47bb61 | f72501285cef7f6a892b9334e7de93a5a86f8aff7311417f577c14acfd213a30 | d4efd77c91ddc96cd6444e3f47cadf529a4f19da4c9f6b0876ce00557d63ca20 | [Step5 重現紀錄](experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/) | 四項必要鎖定維持 301253 ms，新資料跨度為 300291 ms。時序未收斂；八項直方圖計數警告及旁路／排程可觀測性限制已記錄。 |
| 6 | 兩台 TIME_VALID 維持 300 秒採樣驗證 | **通過（PASS）— 封存的主程式驗證；2026-10-05 再次驗證既有運行狀態** | [唯讀 Step6 封存](artifacts/milestones/step6_global_time/README.md) | 封存來源 `00b2342b22c8de000b08be4f4fc9ac1eb44f215e`；Master step64／bootstrap2048；Slave `/2 + /12` | `33e58bf47e7e944a30d90cb791eba0416213ad9838b073642e44b1057ea42134` | `fa5e4d2ce52e3cbbdf65ceaa14a34b0360d0e2af47bfb3fdd4385893b3e99c6f` | [封存驗證](experiments/step6/EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003/REPORT.md)；[最新實機觀測](experiments/step6/EXP-S6-LIVE-TIME-VALID-CKO-300S-PROMOTION-20261005/REPORT.md) | 封存的主程式：Master 1191/1191 筆、302747 ms；Slave 1190/1190 筆、302799 ms。全新獨立啟動仍為 NOT_ESTABLISHED。最新觀測窗各自通過 300 秒；不代表精度、實體邊緣時間差、時序收斂或每次啟動都成功。 |

歷史逐點相位 offset 與先前觀測仍保留於實驗紀錄及 Git 歷史。
目前只保留一份可操作的 Step6 milestone：
`source.tar.gz` 含已驗證程式碼、所有腳本／儀表板、韌體／FPGA 產物與兩輪證據。
執行 `prepare_source.sh` 可建立獨立的 `source/` 工作目錄。
舊 Step6 封存已移至儲存庫外保留以供恢復，未留作相互競爭的版本。
實體邊緣時間差驗證須獨立處理。
