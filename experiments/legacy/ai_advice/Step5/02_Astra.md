# Astra 建議（二）：Step5 現況、問題沿革與 GPT Luna 實作路線

分析日期：2026-09-12（Asia/Taipei）  
讀者：第一次接手 White Rabbit 專案的人，以及接續實作的 GPT Luna。  
本機專案：`C:\Users\zenbook\我的雲端硬碟\碩士班研究資料\04_WR`  
分支：`exp/step5-softpll-lock`；文件／證據 HEAD：`fb9d963f9fcea3f61a434fa51f92ec29d4b4c5bf`。  
最近一次硬體實驗的 source：`4fa3f3b2ffbe5f09907d0df4529b985de7e75c5f`。

本次只讀取、核對、重算與撰寫；沒有修改控制程式、啟動實驗、燒錄、push 或 merge。實驗仍依使用者要求暫停。文中的新實驗是後續操作規格，不是已完成結果。

## 1. 先用一頁說清楚

### 現在到底卡在哪裡？

**Step5 尚未完成。系統已經能啟動 SoftPLL、調動時鐘，甚至曾讀到 Helper／Main／PSTAT 同時鎖定；缺的是可重現、可信且不中斷的閉迴路鎖定。**

最近一輪真正的 cooldown=0 設定，Helper 的相位誤差仍大幅變動，最後 Helper 沒鎖、Main phase 沒鎖、PSTAT 沒鎖。因此不是「硬體已經好了，只是畫面沒更新」，也不是「只差多等一點」。

不過，舊報告對失敗原因的解釋也有錯誤，不能照單全收：

1. fractional-Ki 的 Helper RMS 原始值是 **1051.5917**，報告誤寫為 **10551.5917**。這輪沒有完成 Step5，但不能用誤植數字判定它讓 Helper 誤差暴增十倍。
2. 報告的「hunting」分類用了 **±200**，目前 Helper lock detector 是 **±2000**。越過 ±200 不等於失鎖，也不足以證明欠阻尼。
3. 報告的「lock rise/fall」實際是 **lock counter 數值增加／減少的次數**，不是 locked bit 的上升／下降次數。
4. observer 遇到 invalid frame 不會清掉連續鎖定計時，可能把不明狀態前後的時間接起來。
5. observer 把 `locked=1、count<1000` 一律拒收，但韌體的滯後式 lock detector 允許這種狀態。
6. 部分實驗名稱說 Kp=-150／cooldown=0，source 實際卻是 -125／8。這使一些「單一變因」比較失去效力。
7. baseline報告寫「最長113.791秒」，但壓縮檔內raw summary是 **13.791秒**，又是一處十倍量級誤植。連同invalid-gap修正後，只能重現5.632秒的連續有效取樣片段，仍非物理連續鎖定證明。

**因此，目前有兩個問題同時存在：真實的控制穩定性不足，以及判讀它的量測／實驗管理不夠可靠。不能只解其中一個。**

### 最值得優先投入什麼？

不是再掃一串 Kp、Ki、bootstrap 數字。建議順序：

```text
修正離線判讀與映像身分
→ 在模擬中驗證 Main／Helper 共用 I2C 的服務公平性
→ 用同一時間軸記錄第一次失鎖與兩路 actuator 等待時間
→ 按證據選擇：仲裁／啟動同步／Main phase 切換／物理控制能力
→ 最後才做有模型依據的 PI 整定
→ 真正的連續鎖定、重現性與物理頻率驗證
```

其中，**Main 絕對目標追蹤會持續排 I2C 工作，而目前 Main 在 idle 仲裁永遠先於 Helper**，是值得立即寫測試驗證的程式風險。Main 一啟動，若它占住通道，Helper 雖然算出了新控制值，也可能不能及時送到 SI5340；Helper 一失鎖，Main 的更新又被 Helper gate 擋住，形成互相影響。

這個機制從 source 看是可能的；**還沒有同窗實機證據證明它就是本次失鎖主因**。下一輪應證明或排除它，而不是直接宣布根因已找到。

## 2. 專案背景：Step4B 跟 Step5 差在哪裡？

### 2.1 兩張板與兩個控制迴路

目前使用兩張 DE5a：

- Master：JTAG cable `DE5 [1-11.1]`。
- Slave：JTAG cable `DE5 [1-11.2]`。
- 已驗證使用的光路是 QSFPA lane 2；「lane 2」是程式中的索引，實體線路仍要依既有接線紀錄確認。

White Rabbit 不只需要網路封包收得到，也需要 Slave 的 clock 跟隨參考 clock。

這個專案的 SoftPLL 有兩個重要迴路：

| 名稱 | 初學者可以怎麼理解 | 為何重要 |
| --- | --- | --- |
| Helper／HPLL | 讓量測用的輔助時鐘維持合適關係 | 量測基礎不穩，Main 不能可靠地繼續校正 |
| Main／DPLL | 調整主要時鐘，先拉近頻率，再調整相位 | 最終要用它建立可用的閉迴路鎖定 |

DMTD／DDMTD tag 是相位量測事件；TRR／IRQ 是把事件送進處理程式的途徑。PI 控制器根據誤差算出「希望的控制值」。FPGA tracker 再把控制值翻譯成 SI5340 的 FINC／FDEC 增減步進。

```text
時鐘差異
  ↓
DMTD tag → TRR → IRQ → Helper 更新
                          ↓ Helper 合格後
                        Main 更新
                          ↓
                   PI absolute target
                          ↓
              共用 I2C 通道的 target tracker
                          ↓
                SI5340 FINC／FDEC 步進
                          ↓
                    新的時鐘差異
```

### 2.2 活動、鎖定與品質是三件事

- **Step4B PASS**：Slave 已進入 SoftPLL startup，事件與處理鏈真的活動。
- **Step5 的鎖定候選**：Helper、Main frequency、Main phase、Main locked、PSTAT locked 在有效窗口內同時成立。
- **穩定可交付的 Step5**：上述狀態連續維持、沒有偷偷失鎖／重啟，頻率與相位誤差符合約定，且重新配置能重現。
- **Step6**：全域時間與後續同步品質；不能因 Step5 的 bit 亮起就一併宣稱完成。

尤其：

- `MAIN_ENABLED=1` 只表示啟用過，不代表現在仍持續收到更新。
- `PSTAT.locked=1` 單一欄位可能過期，必須跟其他狀態與 freshness 一起看。
- `FREQ_ERROR_MEAN≈0` 可能是正負擺動互相抵消，不代表相位固定。
- `POSITION_ACCOUNTING=PASS` 表示軟體／FPGA 帳本一致，不等於實體 SI5340 確實完成所有動作。
- 本 observer 的 `FREQ_ERROR_USED` 是 **Helper** 的 tag-delta 誤差；不能拿它當 Main 的 `dout_dt-dref_dt`。

## 3. 本次檢查範圍與證據優先順序

已盤點 Step5 主目錄中的 **181 份根目錄 Markdown／實驗 REPORT.md**，涵蓋 8/29 至 9/12 的開發脈絡；按問題群核對報告的目的、判定、結論與後續建議，並對關鍵結論回查 source、git 歷史與 raw。不是宣稱每個壓縮檔、每一筆歷史 raw 都已逐筆驗證。

本次另做了：

1. 讀取舊版 `Astra建議.md`，確認哪些建議已經實作、哪些已過時。
2. 核對現行 Helper、Main、sequencer、lock detector、DCO controller、I2C engine、diagnostics 與 Tcl observer。
3. 以 `git show` 核對七個近期 source commit 的真實 Kp、integral decimation、Slave top-level cooldown。
4. 直接重算四輪各 3600 筆 raw 的 Helper RMS；重算 invalid frame／Helper 欄位拒收數，以及「遇到未知狀態就斷開」的完整鎖定取樣片段。
5. 以 `git ls-remote` 核對 GitHub：實驗分支仍為 `fb9d963`，main 為 `a89b2df`。這是遠端 ref 檢查，不是已重新驗證遠端所有檔案或當下硬體。

證據排序：

```text
可追溯 raw＋重算＋相符 source/image
> 有明確 source/image 的實驗報告
> STATUS／README 摘要
> 實驗資料夾名稱、observer CONFIG 文字、對話中的轉述
```

本機有一份舊 Step32 REPORT 修改及多個未追蹤 raw／archive，本次全部保留。文件中的硬體現況指「最近保存的實驗」，不是本次即時探測的板卡狀態。

## 4. 從 Step5 開始至今，遇到的問題與處理結果

以下把重複掃描與 recovery 合併成問題群，避免讓新接手者在上百個相似名稱中迷路。狀態的「已修」僅代表列出的缺陷／窗口，不表示整個 Step5 完成。

| 時期／問題群 | 當時看到什麼 | 做了什麼、結果如何 | 現在應保留的判斷 |
| --- | --- | --- | --- |
| 8/29–30：Helper 有更新，DCO 卻沒有新動作 | event chain 活動，但 pending／completed 不增加 | pending correlation、same-code one-shot、JTAG one-step／bounded burst，逐層驗證 request 到 bus 路徑 | 不能把「輸出同一 DAC code」誤認為不需要補剩餘步數 |
| 8/30：absolute code 與 incremental actuator 不相容 | 大幅 target 改變只觸發有限步，固定 target 不追完 | 建立 HPLL absolute target/applied tracker；後續修量化 residual | HPLL 追目標介面已有實作；保留實際步進後才更新 applied 的契約 |
| 8/30：每步比例與方向不清楚 | code 動很多，物理響應不如預期 | FINC/FDEC A/B、32-step drift cancellation、32/64/128 burst 校正、零交越搜尋 | 舊校正來自舊 page/mask 與 operating point，不能直接套到隔離後的系統 |
| 8/30：phase 大跳看起來像物理失控 | raw/preclamp 前後對不上，誤差突然巨大 | coherent measurement snapshot／epoch，fixed-actuator 測試揭露 torn shadow sampling | 測量撕裂確實發生過；算術一致性不等於所有 downstream state 都原子 |
| 8/30：SoftPLL 反覆重新初始化 | Helper epoch／update 重歸零，但 CPU 沒 reset | 找到 `wrpc_spll_locking_enable→spll_init`，加入 idempotent guard | 一輪已證明重複入口不再 re-init；後續仍須計數監測 |
| 8/30–9/2：低 rail／高 rail 與工作點錯誤 | error 常在 ±150000，output=5 或 65531 | bootstrap 6144～6336、gain／step-code 掃描，部分窗口進入非 rail、偶爾 Helper lock | 將掃到的「最好點」視為當時條件下結果，不是跨映像的物理常數 |
| 8/31：用錯 SOF 類型 | direct probe 能讀，WB mailbox timeout | 查到 rs422_uart_diag SOF 沒有所需 JTAG mailbox，改用 JTAG runtime build target | build target／role／SOF 身分必須先驗，不能只看編譯成功 |
| 8/31–9/1：光路／PHY／PTP 不穩 | RXERR、link drop、UNCALIBRATED，Step4B 被擋 | attribution、lane1／lane2 比較；lane2 有有效 PASS；未確認的換光纖不當成已做 | 固定既有 lane2；每輪要重新驗 Step1–4B，不得以歷史 PASS 代替 |
| 9/1：JTAG/WB request／response 對不上 | 連固定寄存器都可讀錯，單純延長 settle 無效 | preload 完整 request，再只 toggle commit，等待 completion、穩定讀取；500 次測試及回歸 | 已有可重用修正，不要再無限加 delay；目前仍需釐清殘留 invalid／alias |
| 9/1：PI snapshot 被多個 writer 改寫 | frozen bank A/B 不一致、V2/V3 失敗 | source epoch、request/bank/ACK、V4 exclusive bank ownership，再用 corrected transport smoke | 診斷 ownership 必須唯一；新 telemetry 不可再覆寫重疊 MMIO |
| 9/1–5：冷啟動／配置順序不可重現 | 同一 SOF 有時 link 好、有時不行 | 三次 repeat、Master-first、startup timeline、暖配置 recovery、真實斷電對照 | Master→等待→Slave 是已用 recovery 方法，不是冷啟動根治；成功一次不夠 |
| 9/2：Kp 差 1 卻結果差很多 | -300／-301 鄰近值表現反差 | frozen-fit MIF-only A/B、firmware bisect，避免 fitter 差異混入；Main trace publication 改低速 | 不宜把結果全歸因 PI；firmware timing、量測負載、P&R 也是變因 |
| 9/2：Main frequency 不收斂／authority 不明 | Helper 偶爾鎖，Main 仍未鎖 | Main trace、event-triggered DAC direction test；full-range 多輪被 Helper gate 擋住未執行 | 不能將 NOT_EXECUTED 當 full-range 無效；旧版一次 direction test 不是現版完整 plant model |
| 9/7：SI5340 page/mask 明確錯誤 | mask 應在 page3，runtime 卻寫 page0 | production bit-engine＋page-aware 模型重現；修成 page3→mask→page0→FINC/FDEC；simulation PASS、5/5 upstream 回歸 | 已修，不要重做同一刀；simulation 不取代實體 N0/N1 隔離證據 [E1][E2] |
| 9/7：模擬器授權障礙 | Questa 可編譯但無 license | 改用 user-local Icarus 10.3 完成測試 | 不可再說「因 license 所以從未模擬過」 |
| 9/8：bootstrap polarity 只保留第一步 | reverse 標記與實際方向不一致 | 持續保留 reverse、FINC/FDEC 獨立計數、four-write sequence telemetry | 保留修正；不要根據 reverse 字面猜方向 |
| 9/8：I2C 完成不等於正確作用 | 只有 bus_done／最後命令，缺 page/mask 全序列 | 加四筆 payload、phase mask、sticky ACK telemetry；部分實驗 ACK error=0 | 過去有效交易已有證據；但現版 failure handling 仍不足，見 §6 |
| 9/8：Main 也是「code 改變一次只走一步」 | jump target 不會持續追完 | Main absolute target/applied、獨立 midscale origin、逐筆完成追 residual | 此缺陷已有修正；新長隊列可能改變共用通道延遲，要另測 |
| 9/8–9：signed／wrap／bootstrap 帳本混亂 | applied overflow，0xFFFB 被當成負控制值，bootstrap 似乎被 fine loop 取消 | 保留 unsigned DAC target；applied 用較寬座標；bootstrap／forced 與 fine origin 分帳；回退破壞上游的 signed-target 嘗試 | DAC code 不是 signed phase error；physical origin 與 virtual origin 不能混用 |
| 9/9：plant-test flag 忘記關 | 方向修正已編譯，normal request 卻仍 0 | 查明 `ENABLE_STEP5_HPLL_PLANT_TEST` 仍開，回復 normal path | 測試模式必須出現在 manifest／runtime readback |
| 9/9：Normal HPLL 方向錯／量化死區 | 追到 rail 或剩餘量不發步 | isolated plant identification 後修 target↑→FINC；以 half-step nearest admission 取代過大的死區 | 保留 normal 方向與量化修正，但 64 是 code mapping，不是物理頻率最小單位 |
| 9/9：phase 累積溢位與啟動歷史污染 | preclamp 長期多百萬、整數 wrap、正負飽和 | Helper phase 狀態改 64-bit，diagnostic clamp；60 秒 guard 後 reseed | overflow 有處理；固定60秒仍未與實際 bootstrap_done 同步，起點契約未完全解決 |
| 9/9：取得頻率零點但 Helper lock 難維持 | 3360 附近 frequency 接近零，phase 仍擺動 | Kp、Ki=0、cooldown16/32/64/256、整體 PI decimate64 等 | Ki=0／大 decimation 有 rail 反例；不能靠關閉積分就假定穩定 |
| 9/9：Helper admission 門檻變更 | 原門檻下難累積鎖定 | threshold200→1200→2000；lock_samples10000→1000；Main 才得以更常啟動 | 這是實際修改判定，不能說整段開發「從未放寬門檻」；仍缺物理品質換算 |
| 9/9–11：Main 控制方向與增益不適合 | frequency error 不往零、output rail | Main polarity 改正向；+1100/+30 過激，+150/+1 可達 frequency lock | polarity 有改善證據，但各輪上游失敗須分開 |
| 9/11：Main frequency lock 變成 sticky | error 已超標卻不掉 lock | `delock_samples=20000` 大於 lock_samples50；修為 floor10 | 修正錯誤 detector contract；不再用舊 sticky bit 證明收斂 |
| 9/11–12：observer mapping／bootstrap／counter wrap | fields INVALID、position accounting FAIL | 對齊2000/1000、bootstrap3372→3388；改相鄰 snapshot 的 modulo delta | 修正部分量測缺陷；目前仍有 invalid gap／滯後判斷／8-bit delock 誤用 |
| 9/12：Main phase 被明確定位 | Main trace 顯示 phase error 數千 tics，phase count 不累積 | Main trace 有397個新 publication，不是3600個新量測；Main Kp+300 後曾讀到 phase/PSTAT lock | 已證明 phase 路徑可達，但未證明穩定；不要再把「Main phase 永遠不可達」當現況 |
| 9/12：Helper穩定性與實驗 provenance | Kp-75／-125、cooldown掃描、reseed bias63252 等結果不一 | audit 更正 Kp與cooldown；Kp-175、Ki/4、真正cooldown0重驗 | 目前沒有通過的完整鎖定窗口；先修實驗證據再決定哪個控制修改有價值 |

很多次報告寫了「下一輪停止盲掃」，後來卻又回到相似掃描。不是那些方向一定毫無作用，而是缺少穩定基準、量測定義與分流條件，使新結果無法縮小問題。

## 5. 最近四輪：重算後應如何解讀？

### 5.1 實際 source 設定，不看資料夾名稱猜

以下 Main Kp/Ki 均為 +300/+1、Slave bootstrap=3388、Helper code-per-step=64；Helper Kp 與積分／cooldown 如表。數值由四份 raw 的3600個 Helper measurement sample 重算，不是將文字報告照抄。[E3–E6]

| source | Helper Kp | 積分每幾次 update 套用 | 實際 cooldown loads | Helper RMS | max abs | 超過±2000樣本 | invalid FRAME | Helper欄位 INVALID |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 17f20ad | -150 | 1 | 8 | 1026.1969 | 5369 | 188/3600，5.22% | 305 | 39 |
| fd4b2e4 | -175 | 1 | 8 | 1746.3915 | 5963 | 764/3600，21.22% | 295 | 112 |
| 0f7e030 | -150 | 4 | 8 | 1051.5917 | 3677 | 193/3600，5.36% | 604 | 56 |
| 4fa3f3b | -150 | 1 | 0 | 2786.8456 | 6513 | 2129/3600，59.14% | 212 | 390 |

說明：

- RMS 是 `sqrt(sum(error²)/N)`，不是標準差，單位是目前韌體 error tics；不能直接標成 ps／ns。
- `FRAME_VALID` 與 Helper measurement seqlock 是不同有效性域。上述 RMS 重算用已記錄的 Helper measurement；不能因 measurement 一致就認為該筆 Main／PSTAT 也同時有效。
- 這些是取樣比例，不是逐次 ISR 的鎖定 detector fail 比例，也不是按真實時間加權的比例。
- `17f20ad` 的 Helper RMS 較好且曾讀到完整鏈，適合保留為**候選對照**，不是已驗證黃金映像。
- Ki/4 的 RMS 跟 full-Ki/cooldown8 相近、max abs 更小，卻沒有 Main phase/PSTAT lock。這是值得定位的分歧，不能簡化為「Helper變好，所以一定會完成Step5」，也不能用錯字判定它失敗十倍。
- 真正 cooldown0 這一輪較差；但它相對前一輪同時恢復 full Ki，而且重新產生 fitted image，**不是只改 cooldown 的乾淨 A/B**。

較早三輪標成 Kp=-150 的 cooldown64／16／8，source分別為 `84b25fd／988e777／94f135d`，實際 Kp 都是 **-125**。這三輪只能互相比較其實際條件，不能直接納入「-150 cooldown曲線」。

### 5.2 「連續鎖定」數字必須降級為待驗

| source | REPORT記載 | raw observer summary | 本次重算：遇 invalid／未知即斷開的連續取樣片段 |
| --- | ---: | ---: | ---: |
| 17f20ad | 113.791 s（誤植） | 13.791 s | 5.632 s |
| fd4b2e4 | 18.006 s | 18.006 s | 4.524 s |
| 0f7e030 | 0 s | 0 s | 0 s |
| 4fa3f3b | 0 s | 0 s | 0 s |

這也影響Kp=-175的評價：不能再說它把「113.791秒降到18.006秒」。raw summary實際是13.791→18.006秒，而較嚴格的有效取樣片段是5.632→4.524秒；Helper RMS則確實變大。這些單輪、不同invalid率的資料不足以判定哪組具有較好的真實長期鎖定能力，更不能單靠該錯誤比較永久淘汰參數。

右欄只是**較保守的日誌重算**，不是「真正物理鎖定僅有5.632秒」：取樣間仍可能有漏掉的失鎖，反之 invalid 也可能只是讀不到，硬體未必失鎖。必須有 firmware-side sticky loss／連續時間計數，才能補上這個缺口。

重算規則是：每筆須 `FRAME_VALID=1、COHERENT=1`，Helper與Main enabled/frequency/phase/locked/PSTAT都為1；任何一筆不符就斷開，以 `elapsed_ms` 計時。尚未加上全部 future freshness／position／counter完整性條件，因此右欄仍不能作最終PASS。

### 5.3 最近一輪可以確定與不能確定的事

`4fa3f3b` 最近保存窗口：

- 3600 samples，實際約486.457秒。
- Step1–4B preflight PASS。
- Helper measurement與已接受的position/accounting檢查PASS。
- reset counter端點差為0。
- Helper最後locked=0；Main enabled/frequency/phase/main/PSTAT最後為1/1/0/0/0。
- 完整chain為0，**Step5 NOT COMPLETE**。
- Master／Slave worst setup slack分別-0.058ns／-0.209ns；`TIMING_CLOSED=NO`。

原報告將 `SPLL_DELOCK_COUNT_MAX=250` 寫成明顯失鎖活動，證據不足。這是截成8bit的計數，first=0、max=250、final=0；observer又沒有以valid frame約束max更新。應保留原始值並查wrap／re-init／錯讀，不得直接寫「失鎖250次」。

## 6. 目前最可能的阻塞機制：確定性分層

### A. 已確認的量測／判定缺陷——先修，不用猜

主要位置：`scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl`。

1. `read_helper_pair()` 只接受locked=1且count=lock_samples。  
   但 `vendor/wrpc-sw/softpll/spll_common.c::ld_update()` 在超過threshold時逐次遞減count，到delock floor才撤掉locked。**locked=1、count=999 是合法可能狀態**。應按真正detector契約與原子snapshot驗證，而不是用count=1000當真偽判斷。
2. full-chain timer只在valid且Helper count可讀時更新，沒有else處理未知狀態，會跨invalid gap續算。
3. `ERROR_BAND_EXIT_EVENTS` 使用硬編碼200；`LOCK_COUNT_RISE/FALL_EVENTS` 是counter變化，不是locked transition。
4. `ACTUATOR_HUNT_OBSERVED`／`UNDERDAMPED_OR_OVERAGGRESSIVE` 是啟發式標籤，沒有頻譜、延遲、相位裕度或因果驗證。現在不足以當根因。
5. `spll_delock_max`更新未受frame-valid gate保護；8bit值又不能用max當事件數。
6. Helper seqlock、position epoch與lock flags分開取樣。position穩定epoch不一定凍住尚可變動的target。新方案須明列每一組一致性範圍。
7. raw可見DMTD_REF接受計數偶爾等於measurement epoch等可疑alias；需用address/response/epoch關聯驗證，不能直接解讀為事件計數器重置。

修observer不會讓Clock物理鎖住，但會避免下一輪往錯方向走。

### B. 高優先的控制風險：Main固定優先權＋兩路共享慢速I2C

位置：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`，`rt_state=0` 仲裁。

目前順序：

```text
Main target-applied residual足夠 → 先服務Main
else Helper pending           → 再服務Helper
else bootstrap／forced／normal Helper admission
```

Main現在會一直追absolute residual，並不是只走一步。在Main持續有殘差或更新時，沒有可見的「最多連續服務Main幾次」保障。每一步又包含四筆I2C write，排隊時間不容忽略。

可能的循環：

```text
Helper短暫鎖 → Main啟動／追大殘差
→ Helper I2C延後 → Helper相位漂移
→ Helper失鎖 → mpll_update不再執行
→ Main仍可能追舊target／保留state → 重複獲鎖或等待
```

**source可確認固定優先權；實機是否因此失鎖、延遲多長，待測。** 最省時間的方法是先建liveness模擬，再量per-loop wait與first-loss，而非直接調參。

另外，normal Helper的方向先排入pending，實際執行可能延後；其間新target仍可更新。要測是否會執行過期方向，但已在bus上的transaction不能中途改寫。

### C. 已知啟動同步缺口：60秒不等於bootstrap完成

位置：`softpll_ng.c::SEQ_START_HELPER/update_loops`與`spll_helper.c::helper_reseed`。

guard依timer釋放，沒有讀到RTL的實際`bootstrap_done`與成功計數。不同cold/warm state、服務延遲、Master狀態，可能讓reseed時點不同。

64-bit狀態處理了長期wrap，不會自動消除「從錯的phase起點開始積分」。但近期已經能進入正常範圍，所以不能把每一次後段失鎖都歸因startup。

判別方式：抓首次bootstrap_done、首次reseed、第一個有效tag／PI state／target／applied。如果loss晚很多才出現，且起點一致，優先查B或D，不要再改startup bias。

### D. Main frequency→phase 切換與更新停頓

位置：`spll_main.c::mpll_update`、`softpll_ng.c::update_loops`。

- prelock的PI input是 `-20*(dout_dt-dref_dt)`。
- freq lock後切換phase error，仍使用同一個PI狀態。
- phase detector只在frequency locked的分支更新。
- Helper不locked時，Main的更新被擋住；所以有些Main flags可能是保留狀態。

這使「頻率鎖了但phase一直在數千tics」不一定只是Kp太小，也可能是切換時integrator/target跳動、資料不新鮮或服務延遲。

要看切換前後的PI input、integrator、output、實際applied，以及Main新tag/update序號。只有證明切換造成過大跳動，才做bumpless transfer；不要一開始就重寫Main。

### E. actuator正確性仍有未閉合部分，但不要推翻已做證據

page/mask bug已於9/7修正並模擬PASS；9/8四筆FPGA-side sequence与ACK也有證據。不能回到「page一定還錯」的舊框架。

仍有兩個缺口：

1. **錯誤完成語意。** 現版I2C engine有sticky `oACK_ERROR`，但DCO的 `dco_error` 只見reset清零；completion／applied更新沒有以本次transaction ACK成功作條件。因此 `oDCO_ERROR=0` 不能證明無NACK。這是failure-handling缺口，不是已觀察到NACK造成這次loss。
2. **實體輸出隔離／增益／range。** 帳本中的applied是估算，不是晶片讀回位置；warm reprogram也不應直接等同外部時鐘晶片實體歸零。需獨立頻率量測或有控制條件的兩路響應矩陣。

`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=64` 是 **一個FINC/FDEC在virtual DAC帳本代表幾個code**。64→32不會自動把SI5340本身的頻率步幅減半；反而同一target殘差可能需要更多實體步進，等效增益／range會變。若真想縮小Hz/step，要核對晶片FSTEP配置與資料手冊，再另做實驗。過去Step32負結果不能證明「物理上不允許32」。

### F. Master也是變因，timing也仍是風險

`spll_helper.c` 的Kp/Ki在 `CONFIG_WR_NODE` 下設定，不是只對Slave。若兩角色都用同一來源重建，可能連Master參考端也一起變動。新A/B必須freeze已確認的Master映像與reference state，或明確做role-specific設定。

Quartus timing仍未closed，且早期做過frozen-fit A/B。這不證明所有失鎖都來自timing，但也不能當不存在。要列出負slack路徑、clock group／CDC／unconstrained paths，若路徑涉及tag、mailbox、reset或DCO握手，優先處理。不可用新增false-path把紅字變綠而不分析真實時序。

## 7. 什麼條件才叫「完成Step5」？

分兩层，避免一邊實驗一邊偷換標準。

### 7.1 歷史候選門檻

近期既有observer以至少300秒full-chain作候選門檻。**沒有一輪已可靠達成這個門檻**；所謂113.791秒是REPORT誤植，raw的13.791秒另有跨invalid gap問題。

目前韌體門檻：

| Detector | error threshold | lock_samples | delock floor |
| --- | ---: | ---: | ---: |
| Helper | 2000 | 1000 | 100 |
| Main frequency | 50 | 50 | 10 |
| Main phase | 1200 | 1000 | 100 |

`lock_samples` 是更新事件計數，不是JTAG樣本數，也不是毫秒。這個detector是帶累積／遞減的滯後機制，不是「每個樣本都合格，否則立刻歸零」的簡單連續N次判斷。

### 7.2 建議的交付驗證規格（新提案，需明確固定）

為避免擦邊pass，建議Luna把最終驗證目標設為：

- 先有fresh的Step1–4B preflight與映像身分一致性。
- 同一個有效epoch中，Helper＋Main frequency＋Main phase＋Main locked＋PSTAT同時成立。
- **firmware／hardware端**連續維持至少600秒，sticky loss／re-init／reset／SI-config-drop沒有增加；host用真實時間核對，不跨資料缺口猜測。
- 同一段保存Main與Helper誤差、新更新次數、target/applied、per-loop transaction/ACK/timeout與freshness。
- 排除失鎖flags未更新、freeze／plant-test未關等「假鎖」。
- 同樣source、manifest與測試方法至少3次fresh-program重現。冷啟動與warm recovery分開報告；最終至少加入使用者確認的cold start，不能以warm成功冒充cold可靠。
- 候選穩定後再做1800秒品質觀測。這是擴充工程驗證，不等於已證明WR精度規格。
- 實體frequency/phase品質要有明確量測單位與允收值，根據tag解析度、clock routing與需求核對；不得把tics直接當ns。缺儀器時標註 `PHYSICAL_CLOCK_QUALITY=NOT_VERIFIED`。
- timing未closed時只能報有caveat的functional result，不能稱production-ready。

600秒是本文件提出的較完整交付條件，不是偷偷把歷史300秒改寫成原本就有。若專案reviewer採用不同門檻，先以版本化spec明確記錄，再開始量測；禁止量完才選對自己有利的門檻。

## 8. 給 GPT Luna：可直接執行的工作包

### 全部工作包共通規則

這是一份後續實作規格；使用者恢復實驗後再執行硬體部分。**第一個實作回合只做L0，不要一次做完L0～L6。**

1. 保留既有page/mask、static-FSM gate、Main absolute tracker、normal HPLL polarity、idempotent guard與64-bit phase修正。
2. 不放寬threshold/dwell、不force lock、不繞過Helper gate、不自動merge。
3. 每輪一個明確假設；成功也要寫明尚未证明什么。
4. 先檢查本機git diff／未追蹤raw，不覆蓋別人研究資料。
5. 建議用短實驗ID目錄，避免現有Windows路徑過長；完整標題寫REPORT內。
6. 不得把歷史stage test、partial成功、timeout停止當完整測試。
7. 不在Pain直接修改tracked source；嚴格遵循使用者指定流程：
   **laptop修改→commit/push→Pain pull同一commit→compile/program→raw取回laptop實驗目錄→REPORT→push→下一輪。**
8. 現階段不需要再向分支對話詢問「是不是pass」；先取得可靠證據。未來若要merge，仍遵守使用者要求的review與明確同意，不將本文當merge授權。

### L0：先完成離線證據修復與實驗manifest（最高優先）

建議ID：`EXP-S5-EVIDENCE-V2-YYYYMMDD`。

**目的：** 同一份raw永遠得到同樣判定；名稱、程式、image不再各說各話。這輪不改PI、不改RTL actuator、不燒板。

輸入：

- §5四輪raw：三份 `tmp/observer-20260912.log` 與17f20ad的 `raw-observer.tar.gz`。
- `scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl`。
- `vendor/wrpc-sw/softpll/spll_common.c::ld_update`。
- 兩角色top-level／firmware source與對應build info。

新增檔案（名稱是建議的新檔，不是宣稱已存在）：

- `scripts/analysis/step5_replay.py`：離線解析器，讀raw輸出JSON／CSV。
- `scripts/tests/test_step5_replay.py`：不依賴硬體的單元測試。
- `scripts/experiment/step5_manifest.py`：產生／比對manifest。
- 本輪目錄下 `REPORT.md、comparison.csv、verdict.json、manifest.json`。

實作細節：

1. 用key=value parser讀sample，不用固定欄位位置；遇 `INVALID` 保留unknown，不轉0。board名稱含空白及方括號，不能用空白切出固定第幾欄。
2. 拆三種validity：Helper measurement、actuator accounting、full-chain state。Helper RMS只取其measurement有效樣本；full-chain只取整組狀態有效且fresh的樣本。
3. 修正invalid-gap計時：invalid／未知／epoch或generation重啟／timestamp倒退／超過設定最大gap，一律結束「已驗證的連續片段」。另存UNKNOWN時間，不把讀不到自動判成物理失鎖。
4. 用 `elapsed_ms` 而非 `samples*gap`。future runtime-sticky evidence能跨host gap時，另以硬體連續計數驗證，不能讓舊sample timer靜默補洞。
5. 根據manifest讀threshold／samples／floor。保留±200做獨立品質統計可以，但名稱寫清 `BAND_200`；新增 `OUTSIDE_ACTUAL_HELPER_THRESHOLD`。locked transitions與counter增減分開。
6. 接受符合實際ld_update遲滯語意的locked/count配對；不得單靠放鬆range就接受torn frame，要另查snapshot／epoch。
7. 8bit／16bit counter用相鄰有效樣本做modulo delta，先驗證最大事件率與時間gap足以排除多次wrap；無法證明時回報AMBIGUOUS，不用MAX當總次數。total DCO要拆Main／Helper／forced，不拿一次baseline modulo当長測總量。
8. 新鮮度檢查以producer update/epoch與source timestamp為準；同一慢速trace被輪詢十次，只算一個新measurement。
9. `ACTUATOR_HUNT`先降級成描述性統計／待判讀，不能只因band exit就自動輸出「欠阻尼根因」。
10. manifest至少包含source commit、dirty diff hash、submodule/firmware版本、build target、role、board cable、lane、top-level override、Helper/Main Kp/Ki/shift/bias、update/integral decimation、threshold/dwell/floor、bootstrap count/reverse、HPLL/DPLL code-per-step、cooldown、test/freeze flags、observer hash、MIF/SOF SHA256、Quartus版本、fitted database身分、timing結果。
11. 不可只掃第一個parameter default：例如controller default34但Slave generic map64。需要從角色top-level與實際C preprocessor設定／runtime trace核對；無法判定的值應使pre-program check FAIL，不能猜。

必備單元測試：

| fixture | 預期 |
| --- | --- |
| errors=[3,4] | RMS=sqrt(12.5)，不能大於max_abs4 |
| locked=1、count=999、max1000、floor100 | 不應僅因count<1000就判INVALID |
| full-lock→invalid→full-lock | 兩段不能合併成連續pass |
| Main phase=1但Main update停止／producer stale | 不得增加有效鎖定時間 |
| 8bit counter254→2，且rate/gap可排除多wrap | delta4，不是MAX254次 |
| counter有跳變且gap太長 | AMBIGUOUS，禁止pass |
| metadata cooldown0但top-level8 | provenance FAIL |
| runtime bootstrap3388、observer3372 | FAIL，不能建立假的baseline |
| 同一epoch重複100次 | measurement唯一樣本數1 |
| 欄位缺失／時間倒退／generation改變 | unknown或切epoch，不默默填0 |

本輪驗收：

- 四輪RMS重算與§5相符；Ki/4為1051.5916706。
- 17f20ad須分開驗出REPORT誤植113.791秒、raw summary13.791秒；不能直接輸出verified continuous lock。按本文件簡化gap規則可重現5.632秒（若加更嚴格freshness規則可更短，須說明）。
- 不因修判讀讓任一既有失敗raw變成Step5 PASS。
- 寫勘誤appendix，保留舊raw與舊報告原文；不要大範圍覆寫歷史資料。
- 測試與REPORT commit/push後停止，下一回合才進L1。

### L1：離線驗證共用I2C仲裁與完成語意

建議ID：`EXP-S5-DCO-LIVENESS-YYYYMMDD`。

**目的：** 不花一次全編譯時間就知道固定優先權是否能讓Helper長時間得不到服務。

必讀：

- `si5340a_controller_dco.v` 的idle arbitration、pending、target capture、four-write completion。
- `scripts/experiment/tb_dco_page_contract.sv` 與 `run_dco_page_contract.sh`。
- `i2c_bus_controller_dco.v` 的ACK取樣。

可重用production serializer與page-aware pin model。既有test針對舊Main「只走一步」缺陷，**不能把current Main多步追蹤導致舊assert fail誤認page regression**；拆成page contract、absolute target、liveness三組測試。

必測案例：

1. Main／Helper各自單獨target jump與重送相同target，殘差可追完，位置與完成數正確。
2. 兩路同時request，持續供給Main target，使Main一直有可服務殘差；記錄Helper首筆等待幾個完整transaction。
3. pending期間Helper target反向；確認沒有執行超出允許的一筆stale direction，下一筆從最新target重新決策。
4. 兩路反向交錯，每個logical step的四筆write不可被另一loop插入；page/mask正確，另一個模型divider不移動。
5. 每一筆write分別注入NACK、bus永遠busy、缺completion；不能把未成功logical step算成成功applied。
6. bootstrapping與normal工作交界、counter wrap、同cycle load＋completion。
7. 強制診斷模式的有限步數與normal模式不能混算。

輸出：每個request的owner、target、queue時間、start、各write ACK、complete、applied與model divider位置；明確標示expected-defect和regression。

基準缺陷若重現，先記錄 **SOURCE_LIVENESS_RISK_REPRODUCED**，不是 **HARDWARE_ROOT_CAUSE_CONFIRMED**。若無法重現，檢查test是否真的讓Main持續有residual；仍不能就此斷言實機公平。

**本輪只建立test與證據，不同輪改arbiter、ACK、PI、startup。**

模擬器：沿用歷史user-local Icarus路徑方式；先查實際檔案是否存在。Questa無license可使用已證明能跑的Icarus，不要把工具問題重新當研究瓶頸。

### L2：建立低擾動first-loss證據，重現一個真baseline

建議ID：`EXP-S5-FIRST-LOSS-YYYYMMDD`。

**目的：** 找出第一個失效先後，而不是觀測結束才讀到五個0。

推薦比較基準：先使用**目前明確的4fa3f3b控制設定**，只加入必要diagnostics／修observer，確認現況能重現。17f20ad的cooldown8較好，先列為下一個控制A/B候選，不能這輪順手恢復8且宣稱僅加trace。

修改範圍：

- `vendor/wrpc-sw/softpll/softpll_ng.c`、`spll_helper.c`、`spll_main.c`：只加固定成本事件記錄。
- `vendor/wrpc-sw/lib/task-diags.c`、`vendor/wrpc-sw/dev/wdiags.c`：明確owner／snapshot協議。
- `si5340a_controller_dco.v`：若既有probe不足，才加per-loop等待／完成診斷；每加RTL欄位都記錄fit變更。
- Tcl reader採用L0的新判定。

最低事件／欄位：

```text
identity: generation, config_id, diagnostic_format_version
time: firmware monotonic timestamp, helper/main producer update_seq
startup: bootstrap_start/done, completed_steps, reseed_time/count
Helper: error, output, integrator, lock_count, locked, change reason
Main: freq_error, phase_error, selected PI branch, integrator/output,
      freq/phase counter, enabled, fresh updates, locked
Actuator per-loop: newest_target, applied, pending, queue_age,
      max_queue_age, service_start_count, successful_step_count,
      failed_step_count, NACK/timeout, service latency
Milestone: full_chain_enter_time, continuous_lock_ticks,
      loss_count, first_loss_time, first_loss_reason bitmask
Reset/init: spll_init_count, CPU/WR reset, SI-config-drop
```

實作要求：

1. 不在ISR印printf或每tag做大筆MMIO寫入。先在RAM固定大小event buffer／sticky first-loss記錄，background低速publish；實際可用RAM先看map，不武斷指定大buffer。
2. ISR/main-task的shared state要有明確epoch；新diagnostic bank不可覆寫已exclusive的PI bank。
3. 首次失敗可同時有多bit，不強迫排序沒有足夠時間解析度的事件；註記timestamp不確定度。
4. 全鏈連續時間與loss在producer端累積，不靠host稀疏輪詢推定；正確处理timer wrap。
5. Main與Helper更新可跳過，必須能看出freshness，不讓stale locked bit延長計時。
6. JTAG整組採request/address/response/epoch的可靠协议；小型測試先讀固定寄存器＋增量counter，再做snapshot stress。
7. 若ACK只有reset清除的sticky bit，不能直接當本次transaction結果。先觀測並設計transaction-local status，不在diagnostic-only這輪更改control成功語意。
8. 不影響採樣節奏是要求，不是口頭假定：記錄ISR／IRQ／helper update rate、overflow/drop，與前基準比較。

硬體窗口：

- Master image與實際參考狀態固定，記錄hash。若共用source改動影響Master，需先說明並重建baseline，不可假稱Slave-only A/B。
- 使用既有合法recovery方法取得3次settled Step1–4B PASS；最多一次既定recovery嘗試，仍失敗則保存UPSTREAM_BLOCKED並停止，不能无限燒錄。
- 先60秒diagnostic smoke；trace有錯／缺freshness就停止，不能進長測。
- smoke PASS再抓最多600秒或足夠數量first-loss事件。硬體bit暫時全亮不提早宣告完成。

本輪要回答：

```text
FIRST_LOSS = HELPER | MAIN_FREQ | MAIN_PHASE | LINK |
             REINIT_RESET | TRANSACTION_ERROR | UNKNOWN

MAIN_CONTENDED_WITH_HELPER = observed / not observed / unknown
HELPER_MAX_WAIT = measured time and number of main services
FIRST_LOSS_RELATIVE_TO_MAIN_START = measured time
BOOTSTRAP_DONE_BEFORE_RESEED = proven / false / unknown
```

任何UNKNOWN先修measurement，不用再換PI。

### L3：依first-loss證據，只選一個功能修正

| L2證據 | 唯一下一個功能實驗 | 不應做的事 |
| --- | --- | --- |
| Helper待服務時間在Main啟動後大增，並先於Helper誤差超限；L1也重現 | 加**有界公平仲裁** | 不能同輪改Ki／cooldown／step-code |
| bootstrap_done晚於reseed、或startup target／origin對不上 | 改**completion驅動的bootstrap→reseed handshake** | 不再用另一個任意秒數 |
| Helper穩、服務延遲正常，Main在freq→phase切換時PI/target跳變 | 針對切換做**bumpless transfer／狀態初始化**的單一A/B | 不提高phase threshold |
| 出現NACK／timeout但applied仍增加 | 修**transaction成功／失敗完成契約** | 不以bus_done當成功、不盲目自動重送非冪等步進 |
| Helper與Main更新都fresh，PI要求與成功applied一致，物理誤差不按預期變 | 做L4的獨立plant量測 | 不繼續掃Kp |
| first-loss與link/reset先發生相關 | 獨立startup／timing／PHY問題包 | 不拿該窗口裁決PI |
| 量測仍無效或資料不足 | 回L0/L2 | 不宣稱已找到硬體根因 |

#### L3A 有界公平仲裁的具體規格

僅在上述證據支持時實作，建議新增可回退parameter，baseline=舊策略、test=新策略。

- 以**完整logical transaction**為仲裁單位，四筆page/mask/page/command不可拆開交錯。
- 兩路均可服務時，採round-robin，或明確「Main最多連續1筆後必須服務已ready的Helper」；同樣保障Main不被Helper永久排擠。
- 只有一路ready時不空等。
- normal pending是可合併的最新absolute target，不建立無界FIFO；已開始transaction則鎖住owner／direction／payload。
- Helper cooldown是其自身ready條件；公平保證從它確實ready開始算，不把cooldown等待誤算starvation。
- bootstrap／forced維持有限且明確priority與mode，normal run禁止殘留forced操作。
- Main／Helper成功位置獨立更新，不能以公平性修正順便更改方向、origin或步幅。
- L1全部regression通過；在無bus stall且每步服務時間有上界T時，ready Helper等待不超過當前in-flight剩餘＋至多約一筆競爭者服務的設計上界，須依實際arbiter逐cycle證明。
- 硬體A/B保留PI／bootstrap／cooldown等全部控制，先看queue latency是否確實下降，再看loss與lock時間；無改善就保留負結果，不直接換一串gain。

#### L3B bootstrap完成同步的具體規格

若證據支持：

- RTL以**成功完成步數**與generation公開done，不只用queue remaining=0。
- firmware一次性接收同generation的done，在第一個有效Helper tag建立phase baseline；不要每poll重reseed。
- reinit／generation改變重新arm；timeout回報錯誤，不force進入Main。
- 先確認guard期間是否仍有DCO load／bootstrap的啟動依賴，避免互相等待deadlock。
- warm配置的external physical origin與FPGA virtual origin需有已證明的初始化契約；沒有就標未知，不能讓程式假装同步。
- 這輪不新增自動coarse搜尋、不改bias數字；先修事件先後。

#### L3C ACK／timeout修正的安全界線

FINC/FDEC不是可以無條件重送的冪等命令。若final command可能已到晶片但completion不明，重送會多走一步。

- 每logical transaction清楚保存四筆ACK、timeout phase、final-command是否可能已送出。
- 只有能證明完整成功才計入successful_step與applied。
- 前段失敗可以abort并保留原applied；後段不確定回報 `POSITION_UNCERTAIN`，停止該loop的新控制並要求明確recovery，不自行猜少走／多走一步。
- 不可把sticky NACK永久鎖死整條bus而沒有診斷／恢復規格。
- 先用L1 NACK注入測試；功能與仲裁修改分輪完成。

### L4：必要時重新量測「控制值→實體頻率」而非靠rail平均找零點

建議ID：`EXP-S5-PLANT-MATRIX-YYYYMMDD`。

啟動條件：L2/L3已證明telemetry與transaction成功，但響應仍不符；或準備設計新的控制器增益。

目標量測：

```text
                  Main 小幅正/負步進    Helper 小幅正/負步進
Main output Δf           G00                   G01
Helper output Δf         G10                   G11
```

不要求所有cross-term必為零：要先核對實際clock tree，分清實體输出耦合與DMTD量測本來就有的交互關係。

步驟：

1. 固定Master reference与已知physical初始狀態；normal actuator以專門bounded identification mode隔離，量測仍可運作。這是非Step5模式，不能以此宣告PASS。
2. 不用clamped `±150000` 的phase平均值找frequency零點；用同單位fresh frequency差與獨立clock計數／儀器量測。
3. 使用已驗證安全的小幅±step，先offline核對range；每次恢復到可確認的baseline，不直接照抄早期4096-step burst。
4. 每路至少重複3組正／負測試，取得Hz/成功physical-step（或明確尚未轉Hz的量測單位）、dead time、settling、noise、drift、可達範圍。
5. 若用FPGA counter，reference clock不能也被同一受測actuator改動；CDC與gate time要正確。沒有獨立reference／儀器就明確保留品質證據缺口。
6. 存完整page/mask、每筆ACK、成功/失敗step、target/applied，以及另一loop是否真的freeze／未發命令。
7. 確認normal loop與identification mode有相同physical direction，避免再次發生「測試方向對，normal路徑沒測到」。

若plant方向不對／off-target明顯，先處理routing、mask、FSTEP／clock設定；若可達range不足，才調coarse anchor／physical gain。若plant可控而delay明顯，再用其模型整定PI。

### L5：有測量模型後才整定；必要時分離捕獲與保持

不要把「換更強模型來猜下一組Kp」當研究方法。

輸入：L4的gain／delay／noise與L2的實際Helper/Main update rate、actuator服務率、quantizer mapping。

1. 建簡化離散模型：頻率調整經時間積分成phase，加入實際PI fixed-point shift、飽和／anti-windup、half-step量化、四筆I2C延遲與仲裁。
2. 回放已有target/error與loss事件，比較模型與硬體是否同方向；不要求模型完美，但要能解釋增益與延遲量級。
3. 先提出**一組**可說明依據的候選，不直接自動grid-search燒板；基準／候選每輪只改一項已定義control policy。
4. 若需要較小effective Ki，prefer有固定點／殘值保留的確定性實作與溢位分析。每四次才做完整積分是時間抽樣近似，不是任意訊號下精確乘0.25；其anti-windup效果也要測。
5. 如果capture需要快、hold需要慢，才做明確ACQUIRE→TRACK狀態：以bootstrap成功、實測error與dwell轉換，不靠經過任意秒數。狀態轉換須bumpless、integrator對齊，失鎖有界恢復，不重置來製造漂亮鎖定統計。
6. 若評估更細Hz/step，先核對SI5340設定規格；code-per-step與physical FSTEP分開。不能再說64→32自動減半物理擾動。
7. 固定Main reference／freeze-fit策略／同樣觀測負載，至少一個重複baseline，才比較改善。
8. 以Helper和Main**共同穩定**為目標；Helper RMS較小但Main phase永遠0不是勝利。

### L6：closure與交接，不再只看最後一行

建議ID：`EXP-S5-CLOSURE-YYYYMMDD`。

- 先凍結manifest及spec，再量測§7條件。
- 提供三種結果：`PASS`、`FAIL_VALID_RUN`、`INVALID_OR_UPSTREAM_BLOCKED`；不要把第三種當PI反例。
- 結果至少包含：有效觀測期間、最大host gap、firmware continuous lock、每個loss reason delta、freq/phase分布、per-loop成功/錯誤、re-init/reset、source/MIF/SOF hash、cold/warm分類、timing caveat。
- 保存一份外行也看得懂的REPORT與machine-readable JSON，以及raw checksum／可重算指令。
- 未達成就寫出最早失敗boundary，不用「很接近了」取代判定。
- 達成functional gate但缺物理quality／timing，分欄呈現，不混稱完整工程驗證。
- 僅在使用者指定review者依最新證據明確同意後，才可另行執行merge；本文件不授權merge。

## 9. Luna 的每輪操作模板

下面是流程模板，不是本次已執行命令；未確認的revision／新實驗ID不可原樣亂用。

### Laptop

```powershell
git status --short
git branch --show-current
git rev-parse HEAD
git diff --stat
# 讀本輪工作包，先實作對應測試／最小變更。
# 只git add本輪明確檔案，不使用會包入所有raw的git add .。
# 測試通過後commit，記下完整SOURCE_COMMIT。
git push origin exp/step5-softpll-lock
git ls-remote origin refs/heads/exp/step5-softpll-lock
```

來源工作樹不乾淨時，先辨識哪些是本輪修改。不可reset --hard、git clean或覆蓋研究raw。

### Pain

- 透過既有SSH配置連線；不要把密碼放進script、REPORT、git、命令歷史。
- 在正確repo確認branch/status，`git pull --ff-only origin exp/step5-softpll-lock`，核對HEAD等於laptop的完整SOURCE_COMMIT；不同就停止。
- 優先用該commit的獨立build worktree／輸出目錄，避免髒build與其他run混入。所有source變更仍回laptop做。
- 固定build target為JTAG runtime，不誤用RS422 target。
- 已有builder：
  - `firmware/scripts/build_master_firmware.sh`
  - `firmware/scripts/build_slave_firmware.sh`
  - `scripts/build/build_jtag_master.sh`
  - `scripts/build/build_jtag_slave.sh`
- 若只改Slave且Master必須freeze，使用已核對hash的Master映像，不順手重建Master；若兩角色都需要更新，先承認這是新baseline。
- 舊 `scripts/experiment/build_dco_page_isolation.sh` 可參考工作樹／build步驟，但內含固定舊ID與旧test assumptions，不要原封不動當新實驗入口。
- Full build、MIF-only build應事先選擇並記錄；RTL變更不能用MIF-only假裝已更新。
- build PASS後先驗manifest／hash／timing，再依既有已驗證program命令對正確cable燒錄。
- preflight用 `scripts/jtag/read_wb_runtime.tcl --raw`。實際Quartus安裝路徑、program target先查現有script與manifest，不能從記憶猜。
- 每個observer只開一個有ownership的session，避免多reader互相覆寫diagnostic bank。
- 需要實體斷電而目前沒有明確授權時，先停下請使用者操作／授權；不能把硬體配置成功當作已斷電。

### 回 Laptop 保存與結束

每輪建立：

```text
docs/experiments/exp-step5-softpll-lock/<短實驗ID>/
  REPORT.md
  manifest.json
  verdict.json
  raw/
    build / programming / preflight / telemetry logs
    checksums.sha256
  analysis/
    comparison.csv
    replay-result.json
```

1. raw取回後核對checksum；區分 `source commit` 與 `report commit`。
2. REPORT写目的、唯一變因、真实設定、preflight、結果、因果限制、下一個分流、停止條件。
3. commit/push這輪文件；失敗結果也要留。
4. 遵守使用者目前「實驗結束先停」要求，沒有新的恢復指令就不自動進下一輪。

## 10. 給使用者的結論

Step5到現在的進展是真實的：事件鏈、DCO介面、page/mask、方向、絕對目標追蹤、phase累積與Main路徑都有逐步改善。現在不是從零開始。

但還不能說「只差最後一個PI參數」。真正需要突破的是：

1. **讓量測報告值得相信**：連續時間不能跨未知窗口、detector語意不能讀錯、參數不能跟image不一致。
2. **把兩個控制器一起運作時的影響看清楚**：Main是否占住actuator服務、Helper是否因此先失鎖；Main是否在錯誤／過期phase狀態繼續追target。
3. **確認軟體帳本對應真實clock**：成功交易、物理方向、步幅、初始化與獨立頻率品質。
4. **只在這些條件清楚後整定控制器**。

最推薦的下一個實作，不是重燒另一組gain，而是 **L0證據修復＋L1共用I2C liveness測試**。它們都可先離線進行，成本低，且能直接決定後續硬體實驗該改哪一層。

## 附錄A：主要證據與程式導航

以下路徑皆相對專案根目錄；E3–E6為本次重算的四輪。其他歷史資料可由實驗名在同目錄定位。

以下連結已更新為本次 repository layout 的相對路徑；本檔屬歷史建議，source file 後續可能已演進。快速開啟：[最近一次實驗報告](../../exp-step5-softpll-lock/EXP-WRPC-STEP5-TRUE-BASELINE-REVALIDATION-KP-MINUS150-3388-COOLDOWN0-20260912/REPORT.md)、[有 RMS 誤植的 Ki/4 報告](../../exp-step5-softpll-lock/EXP-WRPC-STEP5-HELPER-FRACTIONAL-KI-QUARTER-KP-MINUS150-3388-20260912/REPORT.md)、[有時間誤植的 baseline 報告](../../exp-step5-softpll-lock/EXP-WRPC-STEP5-TRUE-BASELINE-ACCOUNTING-FIX-3388-KP-MINUS150-COOLDOWN0-20260912/REPORT.md)、[observer](../../../../scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl)、[DCO 仲裁程式](../../../../quartus/si5340a_controller_dco.v)、[lock detector](../../../../vendor/wrpc-sw/softpll/spll_common.c)。

| 代號 | 檔案／用途 |
| --- | --- |
| E1 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-DCO-PAGE-MASK-CONTRACT-AUDIT-20260907/REPORT.md`：production bit-engine重現page錯誤、Main one-step缺陷 |
| E2 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-DCO-PAGE-ISOLATION-20260907/REPORT.md`：page修正simulation PASS、5次preflight |
| E3 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-TRUE-BASELINE-ACCOUNTING-FIX-3388-KP-MINUS150-COOLDOWN0-20260912/`：實際cooldown8；archive內 `tmp/observer-20260912.log` |
| E4 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-KP-MINUS175-3388-MAIN-KP300-COOLDOWN0-20260912/`：實際cooldown8；tmp raw |
| E5 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HELPER-FRACTIONAL-KI-QUARTER-KP-MINUS150-3388-20260912/`：RMS誤植；tmp raw重算1051.5916706 |
| E6 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-TRUE-BASELINE-REVALIDATION-KP-MINUS150-3388-COOLDOWN0-20260912/`：最近硬體窗口；tmp raw |
| E7 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-PROVENANCE-CORRECTION-KP-20260912/REPORT.md`：Kp/cooldown勘誤 |
| E8 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-PI-TRACE-20260912/REPORT.md`：Main phase數千tics與397個unique publication |
| E9 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-20260912/REPORT.md`：Main phase可達，未穩定 |
| E10 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-PLANT-ID-5632-20260909/REPORT.md`：隔離後方向辨識 |
| E11 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HELPER-PI-CODESTEP32-COOLDOWN0-3360-KP-MINUS150-THRESHOLD1200-20260909/REPORT.md`：32-code負結果及測量限制 |
| S1 | `vendor/wrpc-sw/softpll/spll_common.c::ld_update`：真實lock detector滯後 |
| S2 | `vendor/wrpc-sw/softpll/spll_helper.c`：64-bit phase、gain、decimation、measurement seqlock、reseed |
| S3 | `vendor/wrpc-sw/softpll/spll_main.c`：frequency/phase切換、PI、detector floor |
| S4 | `vendor/wrpc-sw/softpll/softpll_ng.c`：60秒guard、Helper gating Main、READY loss／reinit |
| S5 | `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：仲裁、target/applied、四筆transaction、completion |
| S6 | `quartus/jtag_runtime_diag/i2c_bus_controller_dco.v`：sticky ACK error，不是transaction成功閘門 |
| S7 | `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`：真正Slave generic map override |
| S8 | `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd`：Master不同控制參數與連接 |
| S9 | `scripts/jtag/read_step5_coherent_closed_loop_trajectory_audit.tcl`：本次發現的reader/timer/label問題 |
| S10 | `vendor/wrpc-sw/lib/task-diags.c`、`vendor/wrpc-sw/dev/wdiags.c`：publication、8bit delock packing、bank ownership |
| S11 | `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：既有Main trace observer |
| S12 | `scripts/experiment/tb_dco_page_contract.sv`、`run_dco_page_contract.sh`：可重用pin-level模擬 |

本文件採用「已證明／合理風險／待測」分層。任何後续模型接手，都應先核對當下HEAD是否仍相同；不同則先讀新增實驗，不把本文的9/12結論永久當成最新現況。
