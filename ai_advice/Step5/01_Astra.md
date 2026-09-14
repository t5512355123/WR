# Astra 建議：White Rabbit 實驗現況與最可能推進 Step5 的路線

分析日期：2026-09-07（Asia/Taipei）  
程式基準：`exp/step5-softpll-lock@8857eb4`  
最新硬體證據：2026-09-05 07:52–07:55 的「第二次暖配置」五次 preflight。這是最新已取回紀錄，不是 9 月 7 日即時量測。

本文件依使用者要求進行分析與規劃，**沒有實作下面提出的修正、沒有新增燒錄、沒有推送本文件或合併 main**。先前啟動的暖配置腳本已完成，原始紀錄已取回筆電。

## 一、先說結論

**目前不是「White Rabbit 一直完全沒進步」，也不是「只差找到一組神奇 PI 參數」。最新暖配置已重新取得 Step4B PASS；真正阻塞點回到了 Main frequency lock。**

我認為最值得優先投入的，是驗證並修正「SoftPLL 數位控制值 → SI5340 實體頻率」這層介面，而不是繼續微調 `kp=-300/-301/-302` 或反覆延長等待時間。

這個判斷有三個具體依據：

1. **DCO 的 page／mask 程式路徑與寄存器定義不一致。** 程式宣稱選 N0 或 N1，實際送出的卻是 page 0、offset `0x39`，而目標遮罩在 `0x0339`。如果晶片仍保留啟動時同時開放 N0、N1 的遮罩，兩個 servo 可能一直在推動同一組輸出。
2. **Main 的 DAC 介面仍是「數值改變一次，最多排一個 step」，不是絕對目標追蹤。** PI 卡到 rail 之後，持續送相同 DAC code 不會繼續把實體頻率推向應有的位置；一次從低 code 跳到高 code，也不等於執行了對應的頻率位移。
3. **冷啟動與暖配置的差異已找到。** 相同 SOF，第一次冷配置連線失敗，第二次不斷電配置則連續恢復 Step4B。這是另一條啟動／校準問題，不能再和鎖頻問題混成一個「Step5 error」。

第一、二點是已核對的**程式行為問題**；它們是否、以及各自多大程度造成實際失鎖，仍須硬體 A/B 證明。我不會把合理推論包裝成已完成的根因驗證。

**最推薦的主線：**

```text
保留可用的暖啟動實驗基線
→ 證明 N0／N1 控制隔離與實際 I2C 位址
→ 建立 Main 的 target／applied 絕對位置語意
→ 在獨立量測下取得兩路 actuator 的增益、範圍、速度
→ 先取得 Helper 穩定，再取得 Main 頻率鎖與相位鎖
→ 最後處理單次冷啟動重現性與長時間品質
```

這條路沒有降低 Step5 門檻；它是在先確認控制器真的擁有足夠、正確的控制能力。

## 二、最新實驗到底到哪裡了

### 2.1 不應再只看 GitHub 上一份報告

分支5最新回覆讀到的 HEAD 是 `be4839c`，當時第二次暖配置還沒完成，因此它的「Step4B 本輪未重驗」對那一刻是正確的。現在已取得後續 raw，判斷必須往前更新。

| 實驗狀態 | 雙板 Step1 | Slave Step4B | 可以推論什麼 |
| --- | --- | --- | --- |
| 冷開機、Slave → Master，9/4 | 失敗 | 被 Step1 擋住 | 無有效 Helper／Main 閉迴路測試 |
| 冷開機、Master → Slave，9/5 第一次配置 | 五次皆失敗 | 五次皆被 Step1 擋住 | 交換順序不足以恢復連線 |
| 不再斷電，相同 SOF 再配置 Master → Slave | 五次皆通過 | 第一次被 Step2 擋住；第 2～5 次 PASS | 已找到一個暖配置 recovery case；Main 尚未鎖 |

暖配置五個窗口，Master／Slave 的 PTP_RX delta 分別是：

| 窗口 | Master PTP_RX Δ | Slave PTP_RX Δ | Slave 結果 |
| --- | ---: | ---: | --- |
| 1 | 13 | 22 | UNCALIBRATED；Step4B blocked by Step2 |
| 2 | 11 | 29 | Step1／2／3／4B PASS |
| 3 | 9 | 25 | Step1／2／3／4B PASS |
| 4 | 11 | 25 | Step1／2／3／4B PASS |
| 5 | 11 | 26 | Step1／2／3／4B PASS |

所有暖配置窗口的診斷通道均為 TRUSTED，雙板 RXERR delta 為 0；boot generation、CPU reset、WR-core reset、SI-config-drop 的 before／after 值全部為 1，故觀測 reset delta 為 0。這不是宣稱生命週期完全沒有 reset，也不是連續監測兩天的結果。[E1]

### 2.2 暖配置最後一個窗口的實際邊界

```text
SPLL_MODE = SLAVE
SPLL_SEQ_STATE = SEQ_WAIT_MAIN
SPLL_INIT_COUNT = 1
LOCK_ENABLE_COUNT = 4

ΔDMTD_ACCEPT = 47466
ΔTAG_VALID = 47465
ΔTRR_WRITE = 47463
ΔTRR_POP = 47664
ΔIRQ = 46028
ΔHELPER_UPDATE = 23266

HELPER.locked = 1 → 1
HELPER.lock_cnt = 9643 → 9046
MAIN.enabled = 1
MAIN.frequency_locked = 0
MAIN.phase_locked = 0
MAIN.locked = 0
PSTAT.locked = 0
```

各計數並非原子同時取樣，不能拿上述小差異直接判定掉事件，也不能要求 IRQ 與兩路 tag 數完全相等。它們足以支持目前既定的 Step4B 活動性判定；不是單憑這張表就證明長時間無丟失。

`PSTAT` 原始值是 `0x1`，但 locked mask 是 `0x2`，因此 locked 仍是 0。`HELPER.locked=1` 搭配 count 低於 10000 是 lock detector 的滯後行為，不等於解碼錯誤；count 下降也提醒我們不能把短窗口的 locked bit 當成長時間穩定。[E1][S3]

**正確的現況標籤：**

```text
STEP4B_REVALIDATED = YES，僅限這次暖配置的第 2～5 窗口
COLD_START_RELIABILITY = NOT_ESTABLISHED
HELPER_LOCK_OBSERVED = YES
HELPER_LONG_TERM_STABLE = NOT_PROVEN
CURRENT_STEP5_BOUNDARY = MAIN_FREQUENCY_LOCK
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

### 2.3 之前最有價值的長窗口結果

同一組 `88604a5 + 7585a06` frozen-fit 映像曾完成 6000 次 Main observer 讀取，**實際耗時 1090.287 秒，不是恰好 600 秒**。575 個去重後 Main trace 的頻率誤差平均約 -1036.73，範圍 -1270～-725；Main PI 全部在低 rail，沒有一次進入 ±50 的 frequency-lock band。Helper 曾 lock，但整段 locked fraction 約 45.9%，結尾未 lock。[E2]

另有多個「Main DAC direction／full-range」實驗，其實因 Helper gate 沒成立而**根本沒有送出 DAC A/B 控制**。這些結果只能說「實驗沒執行到」，不能推論 Main DAC 沒有調整能力，也不能算作重複否定了同一假說。[E3]

## 三、最高優先：兩路時鐘可能根本沒有被獨立控制

### 3.1 程式實際送的是什麼

`quartus/jtag_runtime_diag/si5340a_controller_dco.v` 約第 145～160 行，runtime 一個 step 只有三筆 write：

```text
write offset 0x01 = 0x00     ← 選 page 0
write offset 0x39 = 0x0E 或 0x0D
write offset 0x1D = 0x01 或 0x02
```

下層 `i2c_bus_controller_dco.v` 直接送出八位元 `iWord_addr`，沒有替 `0x39` 自動補 page 3。官方 Si5340 表格把 `N_FSTEP_MSK` 定義在 `0x0339`，FINC/FDEC 在 `0x001D`；page 0 的 `0x0039` 是別的寄存器。故「程式註解說選 N0/N1」不等於「晶片確實收到選 N0/N1」。[S1][S2][V1]

這不是只看 laptop 舊檔猜測：我讀了 pain 上本次 SOF 所在 staging 的同名 source，其 SHA-256 和 laptop 相同：

```text
04a664b9f74c777809488a9f6edb45bb2fc26ec14e0c4add6101b52a280eaea5
```

staging source 相符提高了關聯性，但還不等於重新驗證 frozen fit netlist；最終仍應用實際 I2C 擷取或符合本映像的 readback 補上最後一段證據。

### 3.2 為什麼這可能比 PI gain 更根本

靜態初始化 source 把 `N_FSTEP_MSK` 設為 `5'b11100`；依遮罩語意，N0、N1 都開放。假如 runtime 從未寫對 mask，所謂「只動 Helper」的 FINC/FDEC 就可能同時改動 Main output。

因此存在這個高優先假說：

```text
軟體以為有兩個獨立旋鈕：Main 與 Helper
實際上兩個命令都在推同一組 N0+N1
→ 修 Helper 同時移動 Main，修 Main 又干擾 Helper
→ 主迴路長期 rail，Helper 偶爾鎖到後又不穩
```

若兩種控制刺激在物理上產生相同的兩輸出響應向量，兩輸入到兩輸出的控制矩陣便退化，不能一般性地滿足兩個獨立 setpoint。這是我最想跳脫「只調一個 kp」框架的理由：**先驗證可控制性，再討論控制器。**

這也影響 Master：若 Master Helper 的調整同時動了 Master 主時鐘，Slave 所追的參考本身也在變。不能只修 Slave 然後假設 Master 一定是固定頻率基準。

### 3.3 下一步要怎麼驗證，而不是直接猜改

先在離線 testbench 加一個有 page state 的 SI5340 register model，解碼實際 SCL/SDA，不只檢查 FSM 計數。測試應明確看到：

- HPLL 請求只作用於 N1；DPLL/Main 請求只作用於 N0。
- mask write 的完整位址是 `0x0339`，FINC/FDEC 的完整位址是 `0x001D`。
- static writer 和 runtime writer 不可交錯改 page。
- NACK／timeout 時不可把實體位移記成完成。

正確的基本交易形狀應為：

```text
選 page 3 → 寫 mask → 選回 page 0 → 寫 FINC/FDEC
```

**不能只把目前的 page byte `00` 改成 `03`**：那會把最後的 FINC/FDEC 也留在錯誤頁面。四筆交易也會牽涉 FSM state 寬度、handshake 與 debug decode，必須一起驗證。

先只修 page／mask 隔離，保留 PI、bootstrap、step size 以便歸因；這個 A/B 的成功條件是「實體隔離成立」，不是要求立刻 Step5 PASS。若原本 bootstrap 是在耦合狀態下找出來的，它在隔離後未必仍是正確工作點。

硬體交叉驗證應分別對 N0、N1 施加小而有界的 ±burst，測量兩路輸出頻率變化，形成 2×2 對照表。量測時間基準要獨立於被控制的輸出；優先使用外部頻率計，或由固定板載時鐘作基準的安全跨時鐘計數器。不要只看同樣受到 Helper 影響的 `FREQ_ERROR`。

先確認晶片實際 revision 與適用手冊；檔名中的 `si5340a` 不可直接當成 silicon revision 的證據。舊 `read_dco_readback.tcl` 假設 instance 10 是 readback，使用前必須核對目前 bitstream 的 instance/ID/格式，不能直接套用。[S2]

## 四、第二優先：Main DAC 的介面不是 PI 以為的那種 DAC

### 4.1 已核對的程式行為

同一 DCO source 約第 511～518 行：

```text
若本次 DPLL code != 上次 DPLL code：
    pending = 1
    direction = 新 code 是否比較大
記住最新 code
```

這裡只有一個 pending bit，沒有 Main target／applied position，也沒有保存 code 差值的大小。對比之下，HPLL 已有 `hpll_target_code`、`hpll_applied_code`，會依 residual 繼續排 step。[S1]

依此條件推演，Main `5 → 65531` 並不表示移動 65526 個 code 對應的距離；它只要求一次方向事件。接著一直寫 65531 不會再要求位移。第一筆 code 又只建立 prev 基準。因此，原本規劃的「只送兩個 rail code 就測完整 Main authority」本身可能不是一個有效的 actuator range test。

這可以解釋歷史上「Main PI 已經低 rail，但頻率誤差還遠離零」的候選機制：數學控制器在要求極限輸出，實體 actuator 卻沒有到達那個極限。

### 4.2 推薦的介面契約

Main 應和 Helper 一樣，有明確且可測的絕對位置模型：

```text
software DAC code
→ 經量測標定的 physical target
→ 與 applied physical position 比較
→ 排入有界、可仲裁的 FINC/FDEC
→ 確認成功後才更新 applied
→ target 尚未達到就繼續，即使沒有新的 DAC write
```

重點不是盲目把 `code_per_step=16` 複製到 Main。Main 的碼值中心、方向、物理增益和可用調整範圍都要另外標定。Slave Main 的 PI 初始 bias 是 midscale，Helper 起始 bias 是低端，不能共用「applied 一律設 5」的假設。[S3]

至少需要以下離線測試：

1. 大 code 跳變與等效多個小 code 跳變，最後到同一物理位置。
2. code 不再改變但 residual 不為零時，仍能把目標追完；完成後不再累積步數。
3. 同步發生新命令／完成／方向反轉時，不遺失目標、不重複計步。
4. 忙碌時接到多次新目標，保留最新絕對目標，而非吞掉距離。
5. 只在成功交易後更新 applied；處理有號運算、邊界、reset／重新靜態配置後的座標重建。
6. 共享 I2C 的 Main 與 Helper 不得互相餓死；記錄每路服務率與等待時間。

另一路較大改動的備案，是把 code 直接映射為 N-divider 的絕對 numerator，再做更新提交，避開累加脈衝位置失配。但這會改變 I2C 負荷、量化與更新延遲，需要獨立分支驗證，不能和第一個 mask 修正一起塞進去。[V1]

### 4.3 現有「完成計數」還少一層語意

`i2c_bus_controller_dco.v` 有 `oACK_ERROR`，但此 wrapper 的 instance 未接出該訊號；wrapper 的 `dco_error` 在本 source 只看到 reset 清零，沒有正常運作時設錯誤的路徑。因此 `DCO_ERROR=0`／step counter 增加，不足以保證晶片接受了正確位址的有效命令。[S1][S2]

下一版要分開記錄：request accepted、bus completed、ACK verified、target register verified、physical response observed。前一層 PASS 不可冒充後一層 PASS。

## 五、不要再被「Helper gate」困成無限等待

`softpll_ng.c::update_loops()` 只有在 `helper.ld.locked` 為真時才呼叫 `mpll_update()`。但 Main 啟動過後，enabled 可以繼續保持 1。因此：

```text
MAIN_ENABLED=1 ≠ Main 正在更新 ≠ Main trace 是新量測
```

判斷 Main 的有效量測窗口，至少要同時看到 Helper 有效、Main update counter 推進、trace epoch 合法且屬同一 generation。重複讀到相同值不能當成新的頻率樣本；跨失鎖前後的資料不能混算一個 PI 統計量。[S3]

這不表示可以取消 Helper gate 然後宣告 Main 鎖定。應拆成兩種不同實驗：

- **閉迴路有效性實驗：** 保留 Helper gate，只有合格窗口才判斷 Main error／lock。
- **actuator 開迴路辨識：** 使用受控隔離模式與獨立頻率量測，直接確認命令作用在哪路、方向、增益和範圍；不需要假裝 Helper 已經 lock，也絕不計為 Step5 PASS。

有了第二種工具，就不必每次為了查一個 I2C 或 actuator 問題，先空等 1200 秒取得未必會出現的 Helper gate。

## 六、冷啟動是獨立工程問題：有方向，但尚未定案

冷配置失敗、相同 SOF 暖重配成功，最優先的啟動假說是**外部時鐘／CLKUSR／transceiver 校準的時序關係**。Altera 的 Arria 10 calibration 文件要求配置開始時校準所需的時鐘穩定且持續運行。[V2]

本設計使用 QSFPA_REFCLK 作 PHY 參考，SI5340 又由 FPGA 邏輯初始化，值得懷疑第一次配置時校準所見的時鐘與第二次配置時不同。但還不能排除 NVM 初值、電源／溫度、clock reset 或其他狀態差異；一組 A/B 不足以單獨證明是哪一個。

最有效的驗證不是再換一次板子順序，而是擷取同一條啟動時間線：

```text
電源／configuration
→ CLKUSR、QSFPA/B refclk 是否已存在
→ SI5340 reset／初始化／輸出穩定
→ ATX PLL lock、PLL/channel calibration busy
→ TX analog/digital reset 解除
→ TX-ready、RX-ready、link-up
```

使用固定且先存在的時鐘記錄事件；只記 reset 後的最終值看不到最關鍵的早期失敗。現有 `wr_tx_ready` 直接來自 transceiver reset controller，不是 PTP 軟體猜出的 ready。單純延長 CPU 或 WR-core reset 不等於重新執行 transceiver calibration。[S4]

短期可把「明確記錄的一次暖重配」當實驗室恢復程序，但不可把它包裝成產品冷啟動已解決。長期方案在確認根因後二選一：

- 在正式 transceiver 配置前，讓所需時鐘已由獨立路徑穩定提供；必要時採明確的兩階段啟動。
- 在 reference clock 合格後，依器件與 IP 版本規定執行 user recalibration，再按規定解除 PHY reset。

兩者都要有超時、失敗分類與可重現證據。不要直接燒 SI5340 NVM、亂加固定 delay，或在每次正常 DCO 微調後無條件重新校準。

**策略：冷啟動可靠性和暖態鎖頻可分線處理。** 既然已能恢復 Step4B，就先用固定恢復程序建立有效控制實驗，不必等待整個冷啟動問題完全根治才研究 Main。但正式系統驗收仍要包含冷啟動。

## 七、把 actuator 當真實受控系統量測，不再當理想 DAC

### 7.1 先量兩路控制矩陣

修好、證明 mask 隔離後，固定另一個 actuator，在數個工作點做小幅正負刺激。每次測試都保存起點，使用成功交易數控制刺激量，並在安全界限內返回已知位置。

| 刺激 | Main 實體頻率變化 | Helper 實體頻率變化 | 要回答的問題 |
| --- | --- | --- | --- |
| 僅 N0 正／負 steps | 應有可重現響應 | 不應有與 N0 同級的被命令位移 | Main 是否獨立、符號與增益為何 |
| 僅 N1 正／負 steps | 不應有與 N1 同級的被命令位移 | 應有可重現響應 | Helper 是否獨立、符號與增益為何 |

「不應有」要以儀器解析度、漂移和不確定度判斷，不要求量測值數學上完全等於零。若交叉項仍接近主項，先查 mask、輸出 mux 和板上實際連線；這時不值得繼續 PI 掃描。

歷史 1024-step HPLL 測試有持續約 5 秒的反向響應，約 `0.256 FREQ_ERROR / physical step`，但那是另一組辨識映像，而且量的是內部誤差量，不是 Hz。它證明「某個物理動作有作用」，**沒有證明目前兩路控制已隔離，也不能直接拿來當 Main 的 gain**。[E4]

### 7.2 增益以外，還要知道速度與可達範圍

對每個 actuator 至少取得：

- 正／負方向的 Hz/step 或 ppm/step，以及對真實相位誤差的影響。
- 指令到輸出變化的延遲、完成一筆交易的時間、最大持續 steps/s。
- 工作點附近的死區、量化、返程誤差與 drift。
- 軟體 code 範圍對應的實體頻率範圍；是否涵蓋所需零誤差點。
- 同時有兩路需求時的服務率、queue/residual 和成功／失敗次數。

歷史 burst 約 1024 steps/1.05 s；而目前 Helper 更新是每秒數千次的量級。兩者不是一個理想「每個 PI sample 立即更新 DAC」的系統。即使符號正確，有限 I2C 速率、延遲與量化仍可能導致 limit cycle、追不上或 rail。

判讀規則：

```text
target 與 applied 差很遠，且差距不縮小
    → 先查執行器速度／命令遺失／排程，不調 PI
applied 已到允許邊界，error 仍同方向
    → 查工作點、範圍、比例與方向
applied 跟得上，但 error 固定幅度來回振盪
    → 才值得分析 loop gain、延遲、量化與 PI
```

### 7.3 把大量 bootstrap 變成有物理意義的初始化

保留 6208 作舊基線的必要紀錄，但不要把它當晶片永遠正確的魔法常數。隔離控制後，先量自由運行頻率，再決定是否用頻率配置或有界的 coarse acquisition 把工作點放到 fine loop 可調範圍中央。

程式的 `HPLL_N=14`。若確認 Main／Helper 的有效分頻拓撲符合該關係，以名義 125 MHz 參考計算，Helper 對應的理想原始頻率約為：

```text
125 MHz × 16384 / 16385 ≈ 124.992371 MHz
```

現有配置名義值是 124.992 MHz。這個算式只提供起始檢核，不代表量到了實際頻率，更不能直接推定 bootstrap 應為某個步數。要把板上 clock route、固定分頻、晶振誤差與真實 actuator gain 一起納入。[S5]

這個方向比讓 rail 上的 PI 等待數十分鐘更有價值：**先讓零誤差點落在可達範圍內，再讓 PI 收斂。**

## 八、建議的下一步執行順序

下面是新的建議路線，不是本次已執行的動作。需要使用者決定繼續實作後才開始；沿用 laptop 修改／push、pain pull／build／program、raw 回筆電的紀錄流程。

### A0：固定證據與可工作的實驗入口

1. 將本次暖配置 raw 寫成正式 experiment report，更新目前仍停在冷配置失敗的 STATUS。當前 raw 已在筆電，但尚未 commit/push，分支5尚未讀到這個結果。
2. 保留 exact SOF、來源 commit、SHA、decoder 版本與冷／暖 configuration generation。不要把新 source 的版本號誤當舊 fitted SOF 的版本號。
3. 下一次接觸板子先做唯讀 preflight，確認是否仍是這組映像／有效窗口；不可把 9/5 的結果當 9/7 即時狀態。

成功條件：建立單一、無歧義的 baseline。這一步不要求新 build。

### A1：先做不需板子的「page-aware I2C 合約測試」

實驗建議名稱：`EXP-WRPC-DCO-PAGE-MASK-CONTRACT-AUDIT`。

- 對 exact baseline source 重播一個 HPLL step、一個 DPLL step。
- 加入晶片 page-aware 模型，輸出完整 logical address、data、ACK 和被作用的 N divider。
- 同時為 Main 的大 code jump／持續同 code／busy 時更新補最小反例。
- 對外輸出 source finding 與 test waveform；明確區分模擬事實與實體量測。

成功條件：能重現或推翻本文件指出的 page／DAC contract 問題。若模型推翻，停止沿此假說改硬體，先找模型、實際 silicon 或來源差異。

### A2：只修 page／mask，驗證兩路物理隔離

實驗建議名稱：`EXP-WRPC-DCO-N0-N1-ISOLATION-VALIDATION`。

- 修正 page／mask 交易完整序列，保留現有 static-FSM completion gate fix。
- 接出與記錄 ACK／timeout，避免只看 bus_done；若先僅新增觀測，也要在報告中標明並非已驗證接受。
- 不同時修改 Main PI、Helper PI、lock thresholds 或 reset policy。
- 在有界隔離辨識模式量測兩路響應；必要時用既定暖重配程序建立 link。
- 修硬體邏輯需要重新 synthesis／fit，不能假稱 MIF-only 更新能改到 DCO FSM。

成功條件：實際位址正確、預定輸出受控、非預定輸出不跟著被調；有明確正常／異常交易紀錄。

如果這一步改變了舊的 Helper 工作點，先重新辨識，不要因為「舊 6208 不再 PASS」就立即撤回正確的隔離修正。

### A3：補 Main 絕對 target／applied 追蹤

實驗建議名稱：`EXP-WRPC-MAIN-DAC-ABSOLUTE-TARGET-CONTRACT`。

- 每路獨立 position、方向、量化單位與初始化 origin。
- 先在模型上通過第四節的六類測試，再進板。
- 量測單次 target jump、停止更新 target、反轉 target 的完整追蹤過程。
- 避免直接從 low rail 掃到 high rail；先從已知工作點做小刺激，確認方向、量測解析度與 link 安全，再逐級加大。

成功條件：新 target 不必重複寫入也能被追到；applied 有成功交易與物理響應支撐；Main code 的大小對應可重現的物理設定值。

### A4：真正開始鎖頻，而不是再做「無效等待」

實驗建議名稱：`EXP-WRPC-ISOLATED-PLANT-COARSE-TO-FINE-LOCK`。

1. 固定 Master 的主輸出為可驗證的參考；確認 Master Helper 不再牽動它。
2. 量測並建立 Slave Helper 的 coarse operating point，保留真實 lock detector，不放寬 threshold 假裝 lock。
3. Helper 合格後，啟動 Main frequency acquisition，監控新鮮 error、target、applied、physical frequency 與服務率。
4. 若 Main 達 rail，依第七節判讀，不無限延長窗口。
5. 只有 actuator 隔離、可達、服務率足夠後，才用已識別模型整定 PI。把 I2C 延遲、量化和更新頻率放進離線離散模型，先排除明顯不穩定的設定。
6. Main frequency error 合格後，再進 phase acquisition；最後才驗證整條 lock chain。

增益正負必須從完整鏈路推導。Main 目前用 `freq_error=dout_dt-dref_dt`，prelock 的 PI 輸入是 `-20 × freq_error`，不能只因 error 是負值就直接把 `kp` 翻號。要量出「控制值增加 → 實體頻率 → 所用 error」的符號，再選負回授。[S3]

建議每次先用 30～60 秒有效窗口判斷趨勢。這是快速診斷窗口，不是新的 PASS 門檻；只有誤差向目標收斂、residual 可控且沒有長期 rail，才值得投資後續長窗口。

### A5：穩定性與冷啟動驗收

我建議把驗收分三層，避免又用單一 PASS 字串混在一起：

| 層級 | 所需證據 | 不可混淆之處 |
| --- | --- | --- |
| 暖態控制功能成立 | 同一 run 的 Step1～4B、Helper、Main freq/phase/final lock、PSTAT 全鏈成立 | 冷啟動尚未可靠也要明確標示 |
| Step5 穩定窗口 | 至少完整 600 秒**實際時間**，有效且新鮮的 lock/error 證據、零觀測失鎖／reset／RXERR 增量 | 不用 sample_count × sleep 代替 elapsed；漏樣不算 PASS |
| 系統工程完成 | 建議再做 1800 秒及至少三次獨立啟動重現；冷啟動、timing、輸出品質另行合格 | 建議的加強 QA，並非宣稱原專案早已完成此門檻 |

對外量測要比較 Master／Slave 的頻率差和 phase drift；若用 PPS/TIE，也要清楚區分時鐘鎖定、PTP phase setpoint、固定偏移與 Step6 絕對時間正確性。不能因為顯示 `PSTAT.locked=1` 就宣布達到次奈秒準度。

## 九、兩個容易再次造成誤判的陷阱

### 9.1 現有 lock detector 的註解和實作不完全一致

`ld_update()` 是帶計數滯後的實作，不是「任何一個超標樣本就歸零」的連續樣本判定。尤其目前 Main frequency 的 `lock_samples=50`、`delock_samples=20000`，對照計數上限與遞減條件，frequency lock 一旦達成後不能依這組條件正常退出；鎖前也不能簡單說成 50 個嚴格連續的好樣本。[S3]

這**不是目前 frequency lock 從未成立的原因證明**，但會影響未來 PASS 的可信度。不要在最初 mask A/B 同時改 detector；先保留原行為作對照，獨立統計 raw error 的連續合格時間、失敗樣本、freshness 和真正的 lock-loss events，之後再單獨審核 detector。

同樣地，`SPLL_DELOCK_COUNT=0` 不是「從未失鎖」的充分證據。Main 尚停在 WAIT_MAIN 時，Helper 可以失鎖而沒有經過 READY 那條 delock 計數路徑。[S3]

### 9.2 Timing 不可永久當無關備註

現有 fitted baseline 曾被紀錄為 `timing_closed=NO`。這不會自動推翻每一個觀察，但會降低對 CDC、計數、狀態機與新 fitting 重現性的信心。[E4][E5]

對新的 DCO 修正 build，要辨認未過的 path、clock constraints 與 CDC 方法。不要為了綠燈放寬 constraints；不要把非同步探針讀取的偶發組合當成硬體穩態。若觀測抖動與 build 相關，先做 timing/CDC 稽核，不把 fitting 差異誤當 PI gain 的效果。

## 十、應停止做什麼，以及備案

應停止：

- 反覆改幾個相鄰 kp、但不知道實體 DAC mapping 和兩路控制是否隔離。
- Helper 未運算或 Main trace 不更新時，拿重複樣本重新算「很穩定的誤差」。
- 每次 gate timeout 就把觀測延長，卻沒有新增可區分原因的量測。
- 把 `bus_done`／transaction count／JTAG trusted 當成 actuator register 正確的證明。
- 把舊 SOF、當前 source HEAD、新 decoder 與歷史 PASS 混成同一個實驗。
- 為了保護「已驗證過的程式」而不再檢查它的寄存器位址與控制語意。已驗證活動性不等於已驗證設計正確性。

若 page、絕對 target 與量測均正確後仍進不了 Step5，依序評估：

1. **較粗的 acquisition、較細的 tracking 分工**，解決 I2C slew rate 與工作點範圍；每種模式有獨立已知的轉換條件。
2. **直接 N-divider 絕對設定**，避免大量 FINC/FDEC 才能追上遠端目標；要重新評估延遲與數值精度，不直接混入現有累加位置。
3. **以已知良好的獨立時鐘／DAC 路徑作對照實驗**，確認究竟是 SI5340 actuator 介面，還是 DDMTD／時間戳路徑的限制。這是診斷備案，不是立即購買硬體或改整個架構的指令。

我不建議現在直接放棄 SI5340。已有雙向物理響應、暖態完整 Step4B 和 Helper lock 證據；先把目前明確可疑的控制介面修好，資訊價值最高。

## 十一、下一次開始實作時的第一個任務

**不是再做一輪 600 秒等待。先用 exact source 做 page-aware I2C testbench，證明 N0/N1 遮罩到底寫到哪裡，並附 Main DAC 大步階只有一個 pending 的反例。**

這件事不需要再實體斷電，也不必先取得 Helper lock；能直接驗證本文件兩個最高優先的推論。若被證實，再依 A2、A3 分開實作與測量。只有控制介面的合約成立後，才回到 PI 整定。

對「最有可能讓實驗前進」的排序，我的選擇是：

1. 修正並證明 DCO page／mask 與兩路隔離。
2. 把 Main 變成有真實物理意義的絕對 target actuator。
3. 根據量測建立 coarse operating point、帶延遲/量化的 fine loop。
4. 以已有暖恢復程序支援控制實驗，同時獨立收斂冷啟動校準。
5. 最後用真實連續時間、獨立輸出量測與重現性確認 Step5。

**這是有具體程式證據的優先路線，不是保證改完就會 lock。它的價值在於：即使第一輪沒有鎖住，也應得到可排除原因的結果，而不是又一份只有「gate timeout」的報告。**

## 證據索引

以下 local 連結使用絕對路徑；raw 與 source 是本分析的主要依據，外部資料只用官方器件文件補核寄存器與校準要求。

- [E1：第二次暖配置 raw 資料夾][E1]；重點為 `preflight-1.log` 到 `preflight-5.log`。尚未 commit/push。
- [E2：同 SOF Main 長窗口結果][E2]，含 1090.287 秒、去重 trace 與 low-rail 統計。
- [E3：Main full-range 實驗其實未執行][E3]。
- [E4：雙向 1024-step actuator 辨識][E4]，需注意是不同 SOF。
- [E5：16 code/step 閉迴路實驗][E5]，含 build／timing 限制。
- [S1：DCO wrapper source][S1]；關鍵區段約 145、394、511、545、650 行。
- [S2：I2C bus 與 static register source][S2]；另見同資料夾 `si5340a_i2c_reg_controller_dco.v` 約 272～334 行及舊 `scripts/jtag/read_dco_readback.tcl`。
- [S3：SoftPLL source][S3]；同資料夾 `spll_main.c`、`spll_helper.c`、`spll_common.c`，以及 `include/hw/wrc_diags_regs.h`。
- [S4：Arria 10 PHY wrapper][S4]；reset controller source 在 `generated/work_wrphy_full/wr_arria10_e3p1_phy/wr_arria10_e3p1_rst_ctl/generated/`。
- [S5：Slave top-level clock／DCO 設定][S5]；另見 `include/spll_defs.h` 與 `rtl/clock/si5340_controller/si5340a_freq_prameter_selector.v`。
- [V1：Skyworks Si5341/Si5340 Rev D Reference Manual][V1]，§6、Si5340 register tables 14.94、14.108、14.119、14.168–169。亦須比對實際 silicon revision。注意 FINC/FDEC 的動態位置不能僅以基準 Nx_NUM 寄存器值是否改變來判定。[V1]
- [V2：Altera Arria 10 Transceiver PHY User Guide — Calibration][V2]。

[E1]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-COLD-FAILED-STATE-SECOND-WARM-REPROGRAM-UPSTREAM-RECOVERY-20260905>
[E2]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-MAIN-TRACE-2S-PUBLICATION-MAIN-FREQUENCY-PRELOCK-OBSERVABILITY-600S-20260902.md>
[E3]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MAIN-DAC-FULL-RANGE-AUTHORITY-IDENTIFICATION-20260902.md>
[E4]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-SI5340-BIDIRECTIONAL-ACTUATOR-STEP-RESPONSE-IDENTIFICATION-LANE2-20260902.md>
[E5]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-6208-16-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-AUTHORITY-CLOSED-LOOP-600S-20260902.md>
[S1]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/quartus/jtag_runtime_diag/si5340a_controller_dco.v>
[S2]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/quartus/jtag_runtime_diag/i2c_bus_controller_dco.v>
[S3]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/vendor/wrpc-sw/softpll/softpll_ng.c>
[S4]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/vendor/wr-cores-arria10/platform/altera/wr_arria10_phy.vhd>
[S5]: <C:/Users/zenbook/我的雲端硬碟/碩士班研究資料/04_WR/quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd>
[V1]: https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/reference-manuals/Si5341-40-D-RM.pdf
[V2]: https://docs.altera.com/r/docs/683617/21.1/arria-10-transceiver-phy-user-guide/calibration
