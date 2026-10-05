# Step6 TIME_VALID 300 秒再次驗證與 CKO 時間軸

日期：2026-10-05，臺北時間（Asia/Taipei）。
本次以 Pain 的 `/home/b10504072/04_WR` 為準，觀測開始時為
`feat/file_cleanup` 的 `9b8a231c`，並以 Pain 既有文件作為 README／STATUS／MILESTONES 更新依據。
現有產物記錄的完整建置原始碼為 `bcb84305`，
Master／Slave 分別於 2026-10-04 19:45／19:57 完成編譯，
成功燒錄紀錄的兩板組合為 `20261004T122705Z`。
工作目錄版本與建置紀錄，不等於獨立辨識晶片內實際映像；本次直接觀測硬體狀態。

## 結果

**PASS_TIME_VALID_300S_BOTH_BOARDS：兩台 TIME_VALID 300 秒採樣驗證通過。**
本結論適用於這次主程式已經運行的狀態。
未重新建置韌體／FPGA、燒錄、重置、斷電、詢問顧問，
也未改控制參數、增益、門檻或操作腳本。
唯讀 milestone 與 `/home/b10504072/04_WR_archive_step6_pass/` 保持不變。

| 板子／保存的觀測紀錄 | 有效採樣 | 實際採樣跨度 | 最大間隔 | 判定 |
|---|---:|---:|---:|---|
| Slave，`cko-303s.log` | 359/359 | 302667 ms | 909 ms | PASS_TIME_VALID_300S |
| Master，`master-time-valid-303s.log` | 1190/1190 | 302874 ms | 257 ms | PASS_TIME_VALID_300S |

兩台皆使用既有 `step6_time_valid_300s.py`，要求實際採樣跨度至少 300000 ms、
至少 301 筆具編號採樣、間隔不超過 1000 ms、板號正確、DONE 筆數相符、
每筆 STATUS_TIME_VALID = 1，且沒有讀取錯誤。
讀取器／分析器結束碼皆為 0，TIME_VALID 無效筆數皆為 0，未放寬門檻或有效性定義。
每台依實際讀取器與篩選條件分開分析，原始資料沒有拼接或修改以製造完整觀測。
兩個觀測窗依序進行，並非同時量測時鐘或實體邊緣時間差。

Slave 觀測命令運行於 11:34:02–11:39:07，Master 為 11:40:10–11:45:14。
11:48:17 的最後儀表板顯示兩台 TIME_VALID／PPS_VALID = 1，
Slave 五項鎖定皆為 1、處於 TRACK_PHASE，當下 CKO 為 −48 ps。
儀表板顯示的是短觀測窗結果，Step5 的 INFO／LOCK_ACQUIRED_NOT_STABLE
不會推翻已保存的 359 筆／302.667 秒鎖定觀測；本次沒有修改儀表板邏輯。

## CKO 隨時間變化

![Slave CKO 時間軸與獨立採樣的 TIME_VALID 狀態](analysis/cko-timeseries.png)

實際 CKO 主機時間戳記為 **11:34:03–11:39:06，臺北時間（Asia/Taipei）**。
橫軸是開始觀測後經過的秒數，不是韌體啟動後時間；縱軸單位為皮秒（ps）。
圖表來自原始採樣，不是示意圖、合成信號或插值補出的資料。

| CKO 診斷項目 | 結果 |
|---|---:|
| 原始筆數 | 359 |
| 通過相位資料檢查的筆數 | 289 |
| 排除的不可信相位資料 | 70 |
| 排除的重複 UCNT 更新 | 46 |
| 圖中可信且不重複的更新 | 243 |
| 可信更新跨度 | 302667 ms |
| 最小值／最大值 | −490 / +459 ps |
| 峰對峰 | 949 ps = 0.949 ns |
| 中位數 | −44 ps |
| 母體標準差 | 171.293 ps |
| 此觀測窗的擬合斜率 | −0.1741 ps/s |
| 嚴格 abs(CKO)<60 ps | 68/243 |
| abs(CKO)<=120 ps | 131/243 |
| 可信新更新的最大間隔 | 4302 ms |
| SETP 範圍 | 2567～2975 ps |
| DMS 範圍 | 174500～175388 ps |
| 狀態筆數 | SYNC_PHASE 42／TRACK_PHASE 75／WAIT_OFFSET_STABLE 126 |

只採用通過既有 READS_VALID／phase／frame／epoch／context 檢查，
且 phase-context UCNT 相符的資料。啟動／重置識別資訊須保持不變；
重複或倒退的 UCNT 不當成新量測。
圖表匯出的筆數、最小值、最大值與中位數，皆與既有分析器交叉核對。
折線只連接原始採樣編號相鄰、且被保留的點；排除的資料會留下斷線。
CSV 保留採樣編號、經過時間、UCNT、CKO、SETP、DMS、伺服狀態、
TIME_VALID、健康狀態與 CKO 主機時間戳記。

TIME_VALID 面板使用全部 359 筆獨立狀態讀取，不限於 243 筆相位資料。
健康／時間／鎖定狀態與相位發布資料是分開取得，
不能用本圖主張單個時鐘週期因果關係或跨時鐘域原子對應。

**診斷觀測已完成，但較嚴格的連續 CKO 驗證仍為
INCONCLUSIVE_INCOMPLETE_CAPTURE（資料不足以判定）。**
原有規則要求至少 90% 的資料通過相位檢查，且新更新間隔不超過 2000 ms；
本次為 289/359 = 80.5%，最大間隔 4302 ms。
可信的超出範圍採樣也直接表明：這次 CKO 序列未限制在 ±120 ps 內。
本次不是持續 ±60/120 ps 精度通過；TIME_VALID 300 秒採樣通過不要求 CKO 符合這些精度限制。

CKO 變動是時間戳記／WR 伺服診斷，不是實體振盪器抖動。
未使用示波器量測 PPS 邊緣時間差，也未做同時實體量測。
SETP 持續改變表示這次不是先前固定 SETP／不校正的觀測。
歷史 `/0+/0` 診斷峰對峰為 929 ps，本次為 949 ps，變動幅度接近，
但中位數已由 −6120 ps 移至接近零。
啟動與控制條件不同，因此這只是背景比較，不是增益／抖動的因果結論；
本次未新增調參授權，也沒有調參。

## 其他信號與資料品質限制

Slave 全部 359 筆原始狀態中，READS_VALID、STEP1_GATE、GLOBAL_TIME_VALID、
STATUS_TIME_VALID、STATUS_PPS_VALID，以及 Helper／Main 頻率／Main 相位／Main／PSTAT 鎖定皆為 1。
重置識別資訊 `(BOOT_GENERATION,CPU_RESET_COUNT,WR_CORE_RESET_COUNT,SI_CONFIG_DROP_COUNT)`
維持 `(1,1,1,1)`，RESET_CHANGED 為 1 的筆數是 0。
Slave 快照 TAI 由 53883 前進至 54186。
Master 1190/1190 筆 PPS／快照／連線前置信號皆為 1，專用 LIVE 時間欄位單調遞增。

既有通用 TIME_VALID 分析器對 Slave 顯示
`step1_link_ready_rows=0`、`live_time_monotonic=false`，
原因是交錯讀取器使用不同 Step1 欄位名稱，且沒有該診斷計算所需的專用 LIVE_* 欄位。
這不是時鐘停住或連線失敗的證據。
`live-state-diagnostics.json` 另行重算實際原始 STEP1_GATE 筆數；
驗收仍採明確選定的 STATUS_TIME_VALID，不把不支援的診斷欄位改成 1。

前置與後置檢查皆已保存。兩台依序讀取，因此列出的 TAI 不要求相同；
這不是相同 PPS 時刻對照、經校準的絕對 UTC／TAI 證明或實體 PPS 邊緣時間差測試。
時序仍未收斂，且不是這個功能 milestone 的門檻。
先前全新獨立啟動失敗的紀錄仍保留；本次沒有新做冷啟動，
所以每次啟動必定取得鎖定的能力仍為 NOT_ESTABLISHED（尚未建立）。

## 重現方法與檔案

- [原始 CKO 觀測紀錄](raw/observe/cko-303s.log)
- [原始 Master Global Time 觀測紀錄](raw/observe/master-time-valid-303s.log)
- [Slave TIME_VALID 判定](analysis/slave-time-valid-from-cko.json)
- [Master TIME_VALID 判定](analysis/master-time-valid-300s.json)
- [通過相位資料檢查的 CKO 統計](analysis/cko-300s.json)
- [原始狀態與鎖定筆數](analysis/live-state-diagnostics.json)
- [圖表 CSV](analysis/cko-timeseries.csv)、[SVG](analysis/cko-timeseries.svg)
- [圖表產生程式](analysis/plot_cko.py)

在儲存庫根目錄重現 SVG／CSV：

```sh
python3 experiments/step6/EXP-S6-LIVE-TIME-VALID-CKO-300S-PROMOTION-20261005/analysis/plot_cko.py
```

PNG 是 SVG 轉出的 1800×1140 點陣圖。
已目視檢查資料點、座標軸單位、參考帶、資料缺口與標籤，確認沒有裁切。
繁體中文版沿用同一批 243 筆可信觀測與座標，不修改原始紀錄或 CSV。
圖表產生器只使用 Python 標準函式庫與儲存庫既有分析器；
PNG 使用本機內附的 Sharp 轉出，字體採用可顯示繁體中文的字體設定。
既有 TIME_VALID／CKO 分析測試共 16 項通過。
本機重算與 Pain 保存的判定及統計一致；兩個 Python 執行環境的浮點斜率僅差 6e-17 ps/s。
使用者可編輯的建置／編譯／燒錄／儀表板流程未加入 SHA 驗收檢查。

README 在 GitHub `main` 首頁開頭嵌入圖表。
根目錄 MILESTONES 區分主程式既有運行狀態的驗證與唯讀封存，
並依封存既有紀錄修正過時的 Step6 原始碼／SOF 參照；未改寫或重新封存任何唯讀檔案。
本次新增發布範圍限於根目錄文件與這個證據資料夾。
