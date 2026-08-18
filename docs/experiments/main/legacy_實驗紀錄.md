# White Rabbit（WR）與 DE5a week02 實驗紀錄

> 本文件用來記錄 v01 專案從環境確認、原始工程檢查、硬體編譯，到產生 FPGA 燒錄檔的完整過程。
> 內容刻意用較容易理解的方式撰寫；第一次出現的技術縮寫都會附上全名與用途。

## 1. 先看結論

### 1.1 這一輪已經完成的事情

本輪已經完成以下工作：

1. 確認可以連線到遠端 Linux 伺服器 `pain`。
2. 找到並使用 Intel Quartus Prime 17.0 工具鏈。
3. 盤點 DE5a 板子的原始工程、腳位設定、時鐘與 QSFP+ 介面。
4. 修正原始工程在 Quartus 17 編譯時遇到的 DDR4 記憶體腳位設定問題。
5. 產生 Arria 10 E3P1 收發器（transceiver）相關的 Qsys 元件。
6. 將官方 White Rabbit Arria 10 PHY（Physical Layer，實體層）wrapper（轉接包裝模組）加入新的 top-level（最上層）工程。
7. 成功完成 Quartus 編譯、產生 SOF（SRAM Object File，FPGA 組態燒錄檔）。
8. 使用 JTAG（Joint Test Action Group，硬體測試與燒錄介面）將 SOF 燒錄到 DE5a。

### 1.2 這一輪尚未完成的事情

目前的設計**還不能稱為完整的 White Rabbit Master（主時鐘節點）**，也還不能宣稱兩片 DE5a 已經完成 White Rabbit 時鐘同步。

目前完成的是：

```text
FPGA 腳位與時鐘確認
        ↓
Arria 10 QSFP+ PHY / transceiver wrapper
        ↓
產生 SOF 並成功燒錄
```

目前還缺少：

- 完整的 `xwr_core` / WRPC（White Rabbit PTP Core，White Rabbit 精確時間同步核心）。
- WRPC 內部的 soft CPU（以 FPGA 邏輯實作的處理器）。
- `wrpc-sw`（WRPC Software，控制 WRPC 的韌體與軟體）。
- PTP（Precision Time Protocol，精確時間協定）引擎。
- SoftPLL（Software Phase-Locked Loop，軟體鎖相迴路）與時鐘伺服控制。
- UART（Universal Asynchronous Receiver/Transmitter，非同步串列介面）或 CSR（Control and Status Register，控制與狀態暫存器）來查看 WR 狀態。
- 實際的 QSFP+ 光纖鏈路、Master/Slave（主從）模式設定、時鐘偏差與 PPS（Pulse Per Second，每秒脈衝）驗證。

所以，本輪的正確結論是：

> **DE5a 的 WR PHY 硬體 bring-up（基本硬體啟動驗證）已完成，但完整 WRPC 與 White Rabbit 時鐘同步尚未完成。**

## 2. 專案基本資料

| 項目 | 內容 |
|---|---|
| 專案名稱 | White Rabbit / DE5a week02 v01 |
| 遠端專案路徑 | `/home/b10504072/04_White_Rabbit/week02/v01/` |
| 本機專案路徑 | `C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_White_Rabbit\week02\v01\` |
| 目標板卡 | Terasic DE5a |
| FPGA | Intel Arria 10 GX，裝置編號 `10AX115N2F45` |
| 主要高速介面 | QSFP+ port A（高速可插拔光纖介面 A 埠） |
| 編譯工具 | Intel Quartus Prime 17.0 Build 595 |
| 使用的 JTAG cable | `DE5 [1-11.1]` |
| 本輪主要 SOF | `output_files_full/DE5a_wr_full.sof` |

## 3. 重要名詞說明

| 縮寫 | 全名 | 白話說明 |
|---|---|---|
| FPGA | Field-Programmable Gate Array | 可以重新燒錄硬體邏輯的晶片。這次實驗的主要晶片就是 FPGA。 |
| WR | White Rabbit | 一套用來讓分散在不同位置的設備共享非常精準時間的開放式技術。官方目標是次奈秒等級的同步。 |
| PHY | Physical Layer | 網路最底層的收發電路，負責把 FPGA 內部的資料轉成 QSFP+ 可傳送的電氣或光學訊號。 |
| QSFP+ | Quad Small Form-factor Pluggable Plus | 一種高速可插拔網路模組介面。這裡使用 DE5a 的 port A。 |
| Qsys | Intel Platform Designer 的舊名稱 | 用來產生與連接 FPGA 內部 IP 元件的工具。 |
| IP | Intellectual Property | 已經設計好的硬體功能模組，例如 PLL、收發器或記憶體控制器。 |
| HDL | Hardware Description Language | 描述數位硬體的語言，例如 Verilog 或 VHDL。 |
| VHDL | VHSIC Hardware Description Language | 一種硬體描述語言。本輪官方 WR PHY wrapper 主要以 VHDL 提供。 |
| PLL | Phase-Locked Loop | 鎖相迴路，用來產生、倍頻或穩定時鐘。 |
| PTP | Precision Time Protocol | IEEE 1588 定義的精準時間同步協定。White Rabbit 是在 PTP 基礎上再加入更精密的硬體與校正機制。 |
| WRPC | White Rabbit PTP Core | White Rabbit 的核心硬體與控制軟體，負責時間同步、時鐘伺服與 Master/Slave/Grandmaster 模式。 |
| SOF | SRAM Object File | Quartus 產生的 FPGA 組態檔，通常透過 JTAG 暫時燒錄到 FPGA。 |
| JTAG | Joint Test Action Group | 常用來測試、除錯與燒錄 FPGA 的硬體介面。 |
| QPF | Quartus Project File | Quartus 專案檔，描述專案名稱與基本設定。 |
| QSF | Quartus Settings File | Quartus 設定檔，包含 HDL 檔案、腳位、裝置與編譯選項。 |
| SDC | Synopsys Design Constraints | 時序限制檔，告訴 Quartus 哪些時鐘存在、頻率是多少，以及資料需要在什麼時間內穩定。 |
| QIP | Quartus IP File | Quartus 產生或引用 IP 元件時使用的檔案。 |
| DDR4 | Double Data Rate 4 | 一種外部記憶體。原始 DE5a 工程中有 DDR4 相關腳位與控制器。 |
| DQS | Data Strobe | DDR 記憶體用來配合資料取樣的資料選通信號。 |
| SI5340 | Silicon Labs 的時鐘產生器系列 | DE5a 上的時鐘晶片，可產生不同頻率的穩定參考時鐘。 |
| UART | Universal Asynchronous Receiver/Transmitter | 常用來讓電腦透過串列埠與 FPGA 內部軟體互動。 |
| CSR | Control and Status Register | 讓軟體讀寫硬體設定與狀態的暫存器。 |
| PPS | Pulse Per Second | 每秒產生一次的時間基準脈衝，可用來驗證不同設備的秒邊界是否一致。 |

## 4. 本輪驗收標準

本輪原本設定的驗收條件如下：

1. 可以連線到 `pain`，並確認 Quartus 工具版本。
2. v01 工程的 top-level、QSF、SDC、IP/HDL 來源與 WR Core 版本可追溯。
3. Quartus 編譯成功，並記錄錯誤數、警告數與 SOF 路徑。
4. 使用 Quartus Programmer 將 SOF 燒錄至 DE5a，記錄 JTAG ID 與燒錄結果。
5. 不把「燒錄成功」誤認成「White Rabbit 已經同步」。如果沒有完整 WRPC、對端設備與狀態讀取方式，就必須明確標記為尚未驗證。

## 5. 實驗流程與結果

### 實驗 01：確認 pain、專案與工具鏈

#### 目的

先確認遠端主機可使用，避免在錯誤的機器或錯誤的資料夾編譯。

#### 做了什麼

- 透過 SSH（Secure Shell，安全遠端登入）連線到 `pain`。
- 讀取主機名稱、使用者名稱與目前工作目錄。
- 檢查 v01 專案是否存在。
- 搜尋 Quartus 工具與可能存在的 White Rabbit 原始碼。

#### 結果

v01 專案存在，遠端路徑為：

```text
/home/b10504072/04_White_Rabbit/week02/v01/
```

第一次檢查時，`/mnt/ds1515` 上的 Quartus 路徑暫時無法使用；後續找到 `/home/b10504072/bin/quartus_pgm`，並在 `/mnt/ds1515` 掛載恢復後重新確認 Quartus 17 CLI（Command-Line Interface，命令列介面）工具可以正常執行。

#### 判讀

這一步證明遠端專案沒有消失，但也發現工具路徑不是一直固定可用，因此後面的命令都必須明確指定 Quartus 17 路徑，避免誤用其他版本。

### 實驗 02：讀取原始 DE5a 工程

#### 目的

了解原始工程的架構、板上時鐘、按鍵、LED、DDR4 與 QSFP+ 腳位，避免直接修改時破壞既有板卡設定。

#### 做了什麼

讀取原始工程中的：

- `DE5a.v`：原始 top-level Verilog（硬體描述語言）模組。
- `DE5a.qsf`：FPGA 裝置、腳位與編譯設定。
- `DE5a.sdc`：時序限制。
- `DE5a.qpf`：Quartus 專案設定。
- `si5340_controller/`：SI5340 時鐘晶片控制模組。

#### 結果

確認 DE5a 原始工程已包含多組板上時鐘、按鍵、LED、DDR4、QDRII 與 QSFP+ 相關資源。這些原始資源後來成為新 top-level 的腳位參考。

### 實驗 03：確認 WR Core 原始碼與硬體資源

#### 目的

確認 White Rabbit 官方程式碼是否存在，以及目前版本是否直接支援 Arria 10。

#### 做了什麼

- 讀取原始 WR Core 專案與其版本資訊。
- 檢查 `wrpc-v5.0` 的標籤與 commit（版本提交識別碼）。
- 搜尋 Arria 10、QSFP+ 與 PHY 相關的 HDL 檔案。
- 檢查 DE5a 的 QSFP-A、參考時鐘與 SI5340 連線方式。

#### 重要發現

官方 `wrpc-v5.0` 核心集合包含 WRPC，但現有平台範例並不是直接針對本次 DE5a Arria 10 E3P1 設計。後來另外找到官方 Arria 10 PHY wrapper，才可以先完成 Arria 10 收發器層的硬體整合。

#### 判讀

這個發現很重要：不能把「找到 WR Core repository」直接當成「DE5a 已經完成 WRPC」。不同 FPGA 家族、收發器版本、時鐘與板卡腳位都需要對應的 wrapper 與設定。

### 實驗 04：確認 Quartus 17 路徑與共享掛載

#### 目的

確認編譯與燒錄真的使用 Quartus 17，而不是系統中其他版本的 Quartus。

#### 做了什麼

- 依照 `~/.bash_aliases` 檢查 Quartus 路徑。
- 檢查 `/mnt/ds1515` 是否已掛載。
- 用 timeout（逾時）方式判斷共享檔案系統是否卡住。
- 確認 `quartus_sh` 與 `quartus_pgm` 的實際位置。

#### 結果

最後使用的 Quartus 17 工具路徑為：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm
```

版本為：

```text
Quartus Prime 17.0 Build 595
```

#### 判讀

工具版本會影響 IP 產生結果與腳位檢查，因此本輪固定使用 Quartus 17。Quartus GUI（圖形使用者介面）曾遇到 `libpng12` 相依性問題，但命令列工具可以執行，所以編譯與燒錄採用 CLI。

### 實驗 05：修正遠端腳本與檔案格式

#### 目的

確保從 Windows 傳到 Linux 的輔助腳本可以正確執行。

#### 做了什麼

- 修正 SSH 命令中的引號與變數展開。
- 將腳本改成 Linux 可直接執行的格式。
- 移除可能由 Windows 編輯器加入的 BOM（Byte Order Mark，位元組順序標記）。
- 將換行格式調整為 Linux 使用的 LF（Line Feed，單一換行字元）。

#### 結果

`pain_preflight.sh`、Qsys 產生腳本、編譯腳本與燒錄腳本都可以在遠端使用。

### 實驗 06：原始 DE5a baseline compile

#### 目的

先編譯未加入 WR PHY 的原始設計，確認後續錯誤是原工程本身問題，還是 WR 新增內容造成的問題。

#### 做了什麼

- 使用 Quartus 17 對 DE5a 原始工程進行 Analysis & Synthesis（分析與合成）。
- 檢查 Fitter（佈局繞線）與 Assembler（產生燒錄檔）階段的錯誤。
- 比較相對路徑與絕對路徑兩種編譯方式。

#### 發現的問題

原始工程在 DDR4 DQS 腳位上觸發了與 open-drain（開漏輸出）相關的設定衝突。這不是 WR protocol（通訊協定）問題，而是 FPGA 腳位電氣屬性與 Quartus 17 檢查規則不一致。

### 實驗 07：修正 DDR4 DQS 腳位設定

#### 目的

排除原始工程的 DDR4 腳位設定錯誤，讓 Quartus 17 能完整走完編譯流程。

#### 做了什麼

- 找出 `AUTO_OPEN_DRAIN_PINS` 設定的來源。
- 清除會把 DDR4 DQS 自動設定成 open-drain 的錯誤 QDF（Quartus Database File，Quartus 暫存資料庫）影響。
- 對本階段沒有實際使用的 DDR4 DQS/DQS_n 腳位，改成合理的 input-only（只輸入）處理。
- 保留必要的腳位位置與電氣標準。

#### 結果

清理 QDF 並明確關閉自動 open-drain 設定後，原始 DE5a baseline 可以通過 Quartus 17 編譯。

#### 判讀

這個修正只處理 DDR4 腳位設定，不代表 DDR4 記憶體功能已被驗證。它的目的是讓本輪未使用的 DDR4 資源不再阻擋 WR PHY 工程編譯。

### 實驗 08：確認 Arria 10 WR PHY 的介面

#### 目的

確認官方 Arria 10 transceiver wrapper 需要哪些時鐘、重置、收發資料與錯誤狀態訊號。

#### 做了什麼

- 讀取官方 `wr_arria10_transceiver` entity（硬體模組介面定義）。
- 確認它使用的 FPGA family（晶片家族）為 `Arria 10 GX E3P1`。
- 確認 QSFP-A 對應的參考時鐘與高速資料 lane（通道）。
- 確認 tx/rx ready、disparity error（編碼差異錯誤）與 encoding error（編碼錯誤）狀態輸出。

#### 結果

官方 wrapper 可以獨立接到新的 Verilog top-level，先完成 transceiver/PHY bring-up，再進入完整 WRPC 整合。

### 實驗 09：產生 Arria 10 E3P1 Qsys IP

#### 目的

把 Arria 10 收發器需要的 PLL、重置控制器與偵測電路產生成 Quartus 可使用的 IP 檔案。

#### 做了什麼

使用 Qsys 產生下列六個元件：

1. `wr_arria10_e3p1_phy`
2. `wr_arria10_e3p1_tx_pll`
3. `wr_arria10_e3p1_atx_pll`
4. `wr_arria10_e3p1_cmu_pll`
5. `wr_arria10_e3p1_det_phy`
6. `wr_arria10_e3p1_rst_ctl`

#### 結果

六個元件的 Qsys 產生程序都回傳：

```text
QSYS_RC=0
QSYS_ALL_RC=0
```

Qsys metadata（元件描述資訊）中有部分 18.1 版本標記，但實際使用的是 Quartus 17.0 的 native IP（工具內建 IP），並出現版本替代警告：

```text
Used altera_xcvr_native_a10 17.0 instead of 18.1
```

#### 判讀

這是版本相容性警告，不是編譯錯誤。產生的 QIP 後續可以被 Quartus 17 工程引用。

### 實驗 10：編譯最小 Arria 10 PHY shell

#### 目的

先不加入完整 WRPC，只驗證 Arria 10 PHY wrapper 與 DE5a 的時鐘、腳位、LED 狀態線能否成功編譯。

#### 做了什麼

- 建立 `DE5a_wr.v` top-level。
- 加入 QSFP-A 的參考時鐘與一條高速收發 lane。
- 加入 SI5340 控制器，讓按鍵可以觸發 125 MHz 參考時鐘設定。
- 將 transceiver 狀態接到板上 LED。

#### 結果

最小 PHY shell 的結果：

```text
Analysis & Synthesis：0 errors，44 warnings
Fitter：0 errors，23 warnings
Assembler：0 errors，1 warning
```

產生的 SOF SHA-256（安全雜湊值）為：

```text
b5f6b98053fee7c3c0ce67184131ede77bbc1dbc561a0d424a7d271a580b9e5c
```

### 實驗 11：整合官方 Arria 10 WR PHY wrapper

#### 目的

把官方提供的 Arria 10 wrapper 放進可被 Quartus 17 編譯的 DE5a top-level，建立比最小 raw shell 更接近 White Rabbit 的硬體基礎。

#### 做了什麼

- 建立 `DE5a_wr_full.v`。
- 實例化 `wr_arria10_transceiver`。
- 設定 FPGA family 為 `Arria 10 GX E3P1`。
- 將 SI5340 狀態與收發器狀態接到 LED。
- 保留 QSFP-A 的參考時鐘、收發資料與模組狀態腳位。

#### LED 與狀態線

目前 top-level 中的主要狀態連接如下：

```text
LED[0]        = si_config_done
LED[1]        = wr_ready
LED[2]        = wr_rx_ready
LED[3]        = wr_debug
LED_BRACKET[0] = wr_tx_ready
LED_BRACKET[1] = ~wr_tx_disparity
LED_BRACKET[2] = ~wr_tx_enc_err
```

這些 LED 主要用來觀察時鐘控制器與 PHY 收發器狀態，不能直接當成 PTP lock（精確時間同步鎖定）指示。

#### 重要限制

`DE5a_wr_full.v` 中刻意沒有放入完整 WRPC soft CPU 與 firmware。這是為了先把硬體收發器層編譯與燒錄成功，避免一次加入太多未知因素。

### 實驗 12：Quartus 17 編譯完整 PHY wrapper 工程

#### 目的

確認加入官方 Arria 10 PHY wrapper 後，完整工程仍然可以產生有效 SOF。

#### 結果

```text
Analysis & Synthesis：0 errors，47 warnings
Fitter：0 errors，22 warnings
Assembler：0 errors，1 warning
BUILD_FULL_RC=0
```

SOF 路徑：

```text
/home/b10504072/04_White_Rabbit/week02/v01/output_files_full/DE5a_wr_full.sof
```

SOF SHA-256：

```text
b835fd731da658378971299bc10f632ddf51f18340170a8963c774926b757a37
```

#### 警告如何理解

Quartus 顯示的警告主要與 SI5340 controller 的未使用輸出、I2C（Inter-Integrated Circuit，晶片間控制匯流排）輸出使能、generated IP 的時鐘建議與未使用通道保留有關。這些警告沒有阻止編譯，但正式產品化前仍應逐項檢查。

### 實驗 13：使用 Quartus Programmer 燒錄 DE5a

#### 目的

確認 SOF 不只是離線編譯成功，也能被實際 FPGA 裝置接受。

#### 使用工具

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm
```

#### pain terminal 的關鍵輸出

```text
Info: Version 17.0.0 Build 595
Info (213045): Using programming cable "DE5 [1-11.1]"
Info (213011): Using programming file .../output_files_full/DE5a_wr_full.sof
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
PROGRAM_RC=0
```

#### 結果

DE5a 成功接受 SOF，JTAG 可以識別 FPGA，且 Programmer 回報 configuration succeeded（組態成功）。

#### 這個結果代表什麼

這證明：

- SOF 格式正確。
- JTAG cable 可以連線。
- Quartus 找到正確的 Arria 10 FPGA。
- FPGA 可以被重新組態。

這**不代表**：

- QSFP+ 光纖已經與另一片板子建立 WR link。
- PTP 封包正在交換。
- Master/Slave 已完成協商。
- 兩片板子的時鐘偏差已經變成零。

### 實驗 14：判定 DE5a-1 是否已具備 WR Master 能力

#### 目的

確認目前燒錄的設計到底是完整 White Rabbit 節點，還是只有收發器底層硬體。

#### 做了什麼

只讀取目前的 top-level、QSF、SOF 與官方 WRPC 說明，沒有修改工程。

#### 查到的 source evidence（原始碼證據）

```text
DE5a_wr_full.v:71:    wr_arria10_transceiver #(
DE5a_wr_full.qsf:16: ... wr_arria10_phy.vhd
assign LED[1] = wr_ready;
assign LED[2] = wr_rx_ready;
```

在目前的 top-level 與 QSF 中沒有看到：

- `xwr_core`
- 完整 WRPC
- soft CPU
- `wrpc-sw` memory image
- PTP engine
- UART/CSR 控制介面
- PPS 產生與讀取介面

#### 結論

目前的 `DE5a_wr_full.sof` 是：

```text
Arria 10 PHY / transceiver wrapper bring-up version
```

而不是：

```text
完整 White Rabbit Master / Slave node
```

因此，即使 DE5a-1 與 DE5a-2 使用 QSFP+ port A 連接，目前也不能宣稱可以完成 White Rabbit 時鐘同步。`wr_ready` 與 `wr_rx_ready` 只能表示底層收發器的某些準備狀態，不能等同於 WR PTP lock。

## 6. 為什麼「PHY ready」不等於「White Rabbit 已同步」

可以把整個系統想成兩層：

### 第一層：道路與收發器

PHY 負責：

- 接收參考時鐘。
- 將 FPGA 內部資料轉成高速訊號。
- 從 QSFP+ 收回高速訊號。
- 檢查基本編碼錯誤。
- 回報 transceiver ready。

這相當於「道路已經蓋好，車子可以進出」。

### 第二層：White Rabbit 的時間控制系統

WRPC 負責：

- 傳送與接收 WR PTP 封包。
- 判斷目前是 Master、Slave 或 Grandmaster。
- 測量來回延遲與相位差。
- 校正光纖與收發器造成的固定延遲。
- 控制 SoftPLL，讓本地時鐘逐步追上主時鐘。
- 產生與驗證 PPS。

這相當於「交通規則、同步手錶與自動校時系統」。

本輪只完成第一層，尚未完成第二層。

## 7. 官方資料與版本追溯

本輪參考的官方專案如下：

- White Rabbit 官方介紹：<https://ohwr.org/projects/white-rabbit/>
- White Rabbit Core Collection：<https://ohwr.org/projects/wr-cores/>
- WRPC Software：<https://ohwr.org/projects/wrpc-sw/>
- White Rabbit 官方 GitLab：<https://gitlab.com/ohwr/project/wr-cores>

官方 WRPC Software 說明指出，WRPC 軟體會執行在 WRPC gateware（FPGA 內部的 WRPC 硬體邏輯）中的 soft CPU 上，並負責控制 HDL 模組及執行 WR Master、WR Slave 或 WR Grandmaster 的時間同步。

## 8. 本輪新增實驗：建立 WR Master 韌體

### 8.1 實驗目的

把 WRPC（White Rabbit PTP Core，White Rabbit 的精密時間同步軟體）編譯成可以放入 FPGA 內部記憶體的韌體，並將節點預設成 Master（主時鐘端）。這一步讓 FPGA 不只是有 Ethernet PHY（Physical Layer，實體層收發器），而是開始具備 White Rabbit 的控制核心。

### 8.2 做了什麼

1. 確認使用 Quartus Prime 17.0 Build 595，以及 `riscv64-unknown-elf-gcc` 交叉編譯器。
2. 下載官方 `wrpc-sw`，使用 `wrpc-v5.0` 版本。
3. 新增 `de5a_master_defconfig`，啟用 RISC-V（開放式指令集架構）核心、WRPC/PPSI（Precision Time Protocol Software Infrastructure，精密時間協定軟體層），並設定：

   ```text
   mode master
   ptp start
   ```

4. 修正舊版工具鏈與 WRPC 原始碼的相容性問題，包括標準型別、C 函式、RISC-V 編譯選項與連結參數。
5. 產生 `wrc.elf`、`wrc.bin` 與 `wrc.mif`。MIF（Memory Initialization File，記憶體初始化檔）會在 FPGA 配置時載入 WRPC 韌體。

### 8.3 結果

韌體編譯成功：

```text
FIRMWARE_CORE_RC=0
FIRMWARE_BIN_RC=0
FIRMWARE_MIF_RC=0
text=83278  data=260  bss=7816  dec=91354  hex=164da  wrc.elf
```

產生的 MIF 為 32-bit 寬、49152 個 word，並複製到：

```text
/home/b10504072/04_White_Rabbit/week02/v01/firmware/wrc_de5a_master.mif
```

### 8.4 結果如何解讀

這表示 WRPC 軟體本身已經能成功編譯，並且已經準備好給 FPGA 內部的 RISC-V soft CPU（以 FPGA 邏輯實作的處理器）執行。這還不代表光纖已經連線，因為光纖連線還需要另一片板子、QSFP+ 模組與正確的光纖。

## 9. 本輪新增實驗：整合完整 DE5a WR Master 頂層

### 9.1 實驗目的

把 WRPC、Arria 10（Intel FPGA 系列）的高速收發器、SI5340 時鐘晶片控制器與原本 DE5a 板子的腳位放進同一個 FPGA 設計，形成可實際燒錄的 WR Master gateware（FPGA 內部硬體邏輯）。

### 9.2 做了什麼

1. 新增 `DE5a_wr_master.vhd`，以 DE5a 原有 PHY 設計為基礎，加入 `xwr_core`（White Rabbit 核心硬體）。
2. 將 `wrc_de5a_master.mif` 接到 WRPC 的內部雙埠記憶體。
3. 保留 SI5340、QSFP+ 高速收發器、SFP/QSFP I2C（Inter-Integrated Circuit，板上周邊控制匯流排）控制與 LED 狀態輸出。
4. 開啟 virtual UART（虛擬序列埠），讓 WRPC 之後可透過控制介面檢查狀態。
5. 修正官方模組與 Quartus 17 的相容性，包括：
   - 補上 `sockit_owm.v` 一線式管理模組。
   - 修正 `ep_tx_framer` 與目前 endpoint package 的訊號名稱。
   - 加入 VHDL 對 Verilog `urv_cpu` 的 component 宣告，讓 RISC-V 核心正確綁定。
   - 使用相同版本的 Wishbone（FPGA 內部控制匯流排）與 WR endpoint package。
   - 排除未被此 Arria 10 設計使用的 AXI、Xilinx 專用與其他跨平台模組。

### 9.3 編譯結果

使用 Quartus 17 完整編譯：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh --flow compile DE5a_wr_master.qpf
```

Terminal 的關鍵結果：

```text
Flow Status                 Successful - Fri Aug 14 15:03:31 2026
Quartus Prime Analysis & Synthesis was successful. 0 errors, 242 warnings
Quartus Prime Fitter was successful. 0 errors, 14 warnings
Quartus Prime Assembler was successful. 0 errors, 1 warning
```

產生的 SOF（SRAM Object File，FPGA 燒錄檔）為：

```text
/home/b10504072/04_White_Rabbit/week02/v01/output_files_master/DE5a_wr_master.sof
SHA-256: 36b2b9151a350abd5e155e24632044ec0d469f7d50c5f8ec9c5c9a749a67ab8e
```

### 9.4 結果如何解讀

雖然有警告，但三個主要編譯階段都是零錯誤。這代表 Quartus 已經把完整 WR Master 設計轉成可配置 FPGA 的檔案；這些警告多半是未使用輸出、工具不認識的舊屬性或空範圍訊號，並沒有阻止 SOF 產生。

## 10. 本輪新增實驗：DE5a 實際 JTAG 燒錄

### 10.1 實驗目的

確認新的完整 WR Master SOF 可以透過 JTAG（Joint Test Action Group，FPGA 除錯與燒錄介面）成功載入 DE5a 的 Arria 10 FPGA。

### 10.2 執行內容

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm \\
  -c "DE5 [1-11.1]" -m jtag \\
  -o "p;/home/b10504072/04_White_Rabbit/week02/v01/output_files_master/DE5a_wr_master.sof"
```

### 10.3 pain Terminal 結果

```text
Using programming cable "DE5 [1-11.1]"
Using programming file .../output_files_master/DE5a_wr_master.sof
checksum 0x308B9DED for device 10AX115N2F45@1
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### 10.4 結果如何解讀

這是目前最重要的硬體證據：新的 WR Master bitstream 已成功寫入 DE5a，而且 JTAG 能辨識正確的 Arria 10 裝置。也就是說，FPGA 端的硬體配置已經完成。

但這個結果只證明「FPGA 能正常載入設計」，不能單獨證明「White Rabbit 已經完成時鐘同步」。要驗證同步，還必須接上 QSFP+ port A、另一片設定為 Slave 的 DE5a，並讀取 WRPC 的 link、PTP lock、offset 與 PPS 結果。

## 11. 目前完成度與限制

| 工作項目 | 狀態 | 說明 |
|---|---:|---|
| Quartus 17 工具確認 | 完成 | Quartus Prime 17.0 Build 595 |
| WRPC Master 韌體 | 完成 | `wrc.elf/bin/mif` 均成功產生 |
| DE5a WR Master top-level | 完成 | `DE5a_wr_master.vhd` |
| 完整 Quartus 編譯 | 完成 | Flow Successful，主要階段 0 errors |
| WR Master SOF | 完成 | `output_files_master/DE5a_wr_master.sof` |
| JTAG 燒錄 | 完成 | 1 個 Arria 10 device configuration succeeded |
| QSFP+ 實體光纖連線 | 尚未驗證 | 目前沒有對端板與光纖連線證據 |
| Master 到 Slave 的 WR lock | 尚未驗證 | 尚無 link/PTP status log |
| PPS offset 量測 | 尚未驗證 | 尚未接示波器或 time-interval counter |

另外，目前頂層仍使用 DE5a 的 QSFPA 參考時鐘作為 bring-up（初步帶起硬體）的共用參考。正式追求 White Rabbit 皮秒級同步時，還需要確認 DDMTD（Digital Dual Mixer Time Difference，數位雙混頻時間差）偏移時鐘、收發器延遲與板卡／光纖校正值，不能只靠「燒錄成功」下結論。

## 12. 正式交付檔案

遠端目前使用的 Master revision：

```text
/home/b10504072/04_White_Rabbit/week02/v01/DE5a_wr_master.qpf
/home/b10504072/04_White_Rabbit/week02/v01/DE5a_wr_master.qsf
/home/b10504072/04_White_Rabbit/week02/v01/DE5a_wr_master.vhd
/home/b10504072/04_White_Rabbit/week02/v01/firmware/wrc_de5a_master.mif
/home/b10504072/04_White_Rabbit/week02/v01/output_files_master/DE5a_wr_master.sof
```

本機報告與工程資料夾：

```text
C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_White_Rabbit\week02\v01\
```

原始紀錄仍保存在 `實驗紀錄_原始版.md`，沒有被覆蓋。

## 13. 最終結論

本輪已完成：

> **DE5a Arria 10 的完整 WRPC Master 硬體整合、Master 韌體產生、Quartus 17 零錯誤編譯，以及實際 JTAG 燒錄。**

目前可以說：

> **這片 DE5a 已具備成為 White Rabbit Master 的 FPGA 設計與韌體。**

目前還不能說：

> **兩片 DE5a 已經完成 White Rabbit 時鐘同步。**

下一個必要實驗是接上 DE5a-1 與 DE5a-2 的 QSFP+ port A，將一片設定為 Master、另一片設定為 Slave，然後記錄兩端的 link state、PTP lock、時間偏差與 PPS 邊緣差。只有這些實測值穩定，才能完成同步驗證。

## 14. 追加實驗：重新稽核並再次配置 DE5 [1-11.1]

### 14.1 實驗目的

確認遠端目前實際存在的檔案，仍然是同一份 WR Master 設計，而不是只根據先前的紀錄推測；接著重新把該版本配置到 `DE5 [1-11.1]`。

### 14.2 稽核內容

重新檢查以下關鍵條件：

- `DE5a_wr_master.vhd` 的 `xwr_core` 使用 `g_board_name => "DE5A"`。
- `xwr_core` 使用 `firmware/wrc_de5a_master.mif`。
- WRPC 的 `.config` 包含 `mode master` 與 `ptp start`。
- Quartus Flow、Analysis & Synthesis、Fitter、Assembler 均為成功。
- SOF 的 SHA-256 仍為 `36b2b9151a350abd5e155e24632044ec0d469f7d50c5f8ec9c5c9a749a67ab8e`。

### 14.3 pain Terminal 結果

```text
Flow Status                 Successful - Fri Aug 14 15:03:31 2026
Quartus Prime Analysis & Synthesis was successful. 0 errors, 242 warnings
Quartus Prime Fitter was successful. 0 errors, 14 warnings
Quartus Prime Assembler was successful. 0 errors, 1 warning
```

重新配置指令使用：

```text
quartus_pgm -c "DE5 [1-11.1]" -m jtag \\
  -o p;/home/b10504072/04_White_Rabbit/week02/v01/output_files_master/DE5a_wr_master.sof
```

燒錄結果：

```text
Using programming cable "DE5 [1-11.1]"
checksum 0x308B9DED for device 10AX115N2F45@1
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### 14.4 結果與判讀

本次重新稽核與配置成功，表示目前這個 JTAG cable 對應的 DE5 Arria 10 已再次載入 WR Master bitstream，且 bitstream 內含 Master 模式的 WRPC 韌體。換句話說，在「尚未接 QSFP+ 線」的條件下，已能確認 FPGA 端的設計與配置角色是 WR Master。

仍然不能由 JTAG 配置成功推導出兩台板子已完成同步。沒有 QSFP+ 實體連線時，無法取得對端的 Ethernet link、WR lock、time offset 或 PPS skew（PPS 邊緣時間差）；這些項目必須在接線後另外量測。

## 15. 兩片 DE5a 的 WR Master/Slave bring-up 與 DDMTD 時鐘修正

### 15.1 實驗名稱

**DE5a-1/DE5a-2 雙板 White Rabbit（WR，白兔精準時間同步）鏈路啟動，以及 DMTD（Digital Dual-Mixer Time Difference，數位雙混頻時間差）偏移時鐘修正。**

### 15.2 為了驗證什麼

本實驗要確認兩件事：

1. 兩條 JTAG（Joint Test Action Group，FPGA 硬體除錯與燒錄介面）連線確實對應到兩片不同的 Arria 10 FPGA。
2. 一片載入 WR Master（主時鐘端）韌體，另一片載入 WR Slave（從時鐘端）韌體，並且使用 WR 所需的 125 MHz 主參考與 124.992 MHz DMTD 偏移時鐘。

WR 的 DMTD 不能只把 125 MHz 原樣接到兩個輸入。它需要一個與 125 MHz 略有頻率差的時鐘，透過兩個時鐘的拍頻來量測相位差；官方 WR 核心介面也把這個輸入標示為 125.x MHz offset clock。這也是本次修正的核心。

### 15.3 修改了什麼

#### （1）確認兩個 JTAG cable

pain 端列出的兩個硬體連線為：

```text
DE5 [1-11.1]  -> 本實驗指定為 Master
DE5 [1-11.2]  -> 本實驗指定為 Slave
```

這個編號是 USB-Blaster/JTAG cable 的識別，不等於板子外殼上一定印有的 DE5a-1 或 DE5a-2；若要在報告中使用「DE5a-1」名稱，應另外貼標籤記錄實體對應。

#### （2）建立 Slave 韌體

WRPC（White Rabbit PTP Core，白兔精準時間協定核心）使用兩份設定：

```text
mode master; ptp start
mode slave;  ptp start
```

兩片硬體共用相同的 WRPC/PHY（Physical Layer，實體層）架構，但載入不同的 MIF（Memory Initialization File，記憶體初始化檔）。

#### （3）修正 QSFP 參考時鐘

- Si5340A 輸出 0：125 MHz，接 QSFP-A 的 PHY 參考時鐘。
- Si5340A 輸出 1：124.992 MHz，接到 QSFP-B 的板上參考時鐘輸入。
- `xwr_core.clk_ref_i` 使用 QSFP-A 的 125 MHz。
- `xwr_core.clk_dmtd_i` 使用 QSFP-B 的 124.992 MHz。
- 在 SDC（Synopsys Design Constraints，時序約束）加入 124.992 MHz 的時鐘週期約束。

輸出 1 使用的 Si5340A 分頻參數為：

```text
NX_NUM = 121810384025
NX_DEN = 2147483648
```

由此得到的計算頻率約為 124.992 MHz。QSFP-B 在本設計中沒有啟用資料收發 lane，只借用它的參考時鐘輸入，因此不需要再接 QSFP-B 的資料線。

#### （4）LED 狀態指示

為了讓沒有 UART（Universal Asynchronous Receiver/Transmitter，非同步串列介面）的情況下仍能判斷狀態，頂層把 WR 狀態接到 LED：

| LED | 訊號 | 白話意義 |
|---|---|---|
| `LED[0]` | `si_config_done` | Si5340A 時鐘設定完成 |
| `LED[1]` | `wr_ready` | Arria 10 PHY 已準備好 |
| `LED[2]` | `tm_link_up` | WR 時間管理鏈路已看到對端 |
| `LED[3]` | `link_ok` | WR 核心判定鏈路協定正常 |
| `LED_BRACKET[0]` | `tm_time_valid` | 時間資料已有效 |
| `LED_BRACKET[1]` | `pps_valid` | PPS（Pulse Per Second，每秒脈衝）已有效 |
| `LED_BRACKET[2]` | `wr_rx_ready` | PHY 接收端準備好 |
| `LED_BRACKET[3]` | `wr_tx_ready` 且無 Si5340 錯誤 | PHY 發送端準備好，且時鐘控制器沒有回報 ID 錯誤 |

### 15.4 Quartus 17 編譯結果

Master 與 Slave 都使用 `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh` 完整編譯。

```text
Master:
  Analysis & Synthesis successful. 0 errors
  Fitter successful. 0 errors
  Assembler successful. 0 errors
  Quartus Prime Full Compilation was successful. 0 errors, 265 warnings

Slave:
  Analysis & Synthesis successful. 0 errors
  Fitter successful. 0 errors
  Assembler successful. 0 errors
  Quartus Prime Full Compilation was successful. 0 errors, 265 warnings
```

新增的時鐘也確實出現在 TimeQuest（Quartus 內建時序分析工具）報告中：

```text
qsfp_dmtd_124m992
```

但報告仍顯示 PHY 內部 `rx_clkout` 路徑有負 slack（最差 setup 約 -2.625 ns，且有 recovery/hold 警告）。因此本版本是「可以產生並燒錄的 bring-up 版本」，時序尚未達到完全收斂，不能宣稱已完成最終可靠性驗證。

### 15.5 pain Terminal 燒錄結果

Slave：

```text
Using programming cable "DE5 [1-11.2]"
Using programming file output_files_slave/DE5a_wr_slave.sof
checksum 0x308F160A for device 10AX115N2F45@1
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

Master：

```text
Using programming cable "DE5 [1-11.1]"
Using programming file output_files_master/DE5a_wr_master.sof
checksum 0x308F160A for device 10AX115N2F45@1
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### 15.6 結果怎麼看

目前已經證明：

- 兩個 JTAG cable 都能正確找到 Arria 10 FPGA。
- Master 與 Slave 的 WRPC 韌體都能編譯進 FPGA。
- 兩片板子的最新 SOF 都已成功燒錄。
- 124.992 MHz DMTD 輸入已加入硬體設計與時序約束。

目前還沒有從遠端終端取得兩片板子的實際 LED 狀態，因此**尚不能把「兩片已燒錄」寫成「兩片已完成 WR 同步」**。請在兩片板子上觀察下列結果：

```text
至少應亮：LED[0]、LED[1]、LED_BRACKET[2]、LED_BRACKET[3]
接上 QSFP+ port A 並等待 WR 鎖定後，應再亮：LED[2]、LED[3]
真正時間同步的關鍵結果是：LED_BRACKET[0] 與 LED_BRACKET[1] 也亮起
```

如果 `LED[0]` 沒亮，先檢查 Si5340A I2C（Inter-Integrated Circuit，兩線式晶片間控制介面）設定；如果 `LED[1]` 沒亮，先檢查 125 MHz 參考時鐘與 Arria 10 PHY；如果 `LED[2]/LED[3]` 沒亮，檢查 QSFP-A port A、光模組、光纖方向與另一片的 Master/Slave 角色；如果只有 `LED_BRACKET[0]` 或 `LED_BRACKET[1]` 沒亮，則鏈路可能已通但 WR 的時間鎖定或 DMTD/時序仍未完成。

最後還需要用示波器或時間間隔計數器把兩片板子的 PPS 輸出接到不同通道，量測兩個 rising edge 的差值。LED 只能證明 WR 內部狀態有效，不能單獨證明外部腳位已達到皮秒等級的同步。

### 15.7 參考資料

- [White Rabbit core collection（官方 wr-cores）](https://gitlab.com/ohwr/project/wr-cores)
- [White Rabbit calibration wiki（官方校正說明）](https://gitlab.com/ohwr/project/white-rabbit/-/wikis/calibration)
- [DE5a-NET 官方頁面](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=231&Language=English&No=1108&PartNo=2)
- [White Rabbit Workshop 2025：DE5a 使用外部 PLL 時鐘的簡報](https://indico.cern.ch/event/1524513/contributions/6556313/attachments/3092316/5481183/white_rabbit_workshop_2025.pdf)

## 16. 實體接線後的雙板重新配置實驗

### 16.1 實驗名稱

**QSFP+ 多埠接線後，重新配置 DE5a Master/Slave 並等待 WR 同步。**

### 16.2 為了驗證什麼

確認實體接線完成後，兩片板子不是停留在上一個未知狀態，而是重新載入目前的 Master/Slave 設計，讓 WRPC 從 reset 後重新建立 Port A 的光纖鏈路與時間同步狀態。

### 16.3 實體接線與本設計的關係

使用者已將兩片 DE5a 的 QSFP+ Port A、Port B、Port C、Port D 逐一對接。此版 FPGA 設計實際啟用的是：

- QSFP-A 的資料 lane 0：WR 1 GbE 光纖資料鏈路。
- QSFP-A 的板上 125 MHz 參考時鐘：PHY 與 WR reference clock。
- QSFP-B 的板上 124.992 MHz 參考時鐘輸入：DMTD offset clock。

因此，Port B/C/D 的光纖資料 lane 在此版沒有被 WR core 使用；它們保持連接不會造成問題，但不能把它們當成已被此設計利用的同步通道。

### 16.4 pain Terminal 結果

先配置 Slave，再配置 Master：

```text
Slave:
  Using programming cable "DE5 [1-11.2]"
  checksum 0x308F160A for device 10AX115N2F45@1
  Device 1 contains JTAG ID code 0x02E660DD
  Configuration succeeded -- 1 device(s) configured
  Quartus Prime Programmer was successful. 0 errors, 0 warnings

Master:
  Using programming cable "DE5 [1-11.1]"
  checksum 0x308F160A for device 10AX115N2F45@1
  Device 1 contains JTAG ID code 0x02E660DD
  Configuration succeeded -- 1 device(s) configured
  Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### 16.5 結果如何解讀

兩片 FPGA 已在實體 QSFP+ 接線完成後重新載入正確角色，這證明「設計檔案、JTAG cable、Master/Slave SOF」三者都正確。但目前 SSH 端沒有辦法直接讀取板上 LED 的亮滅，因此 WR 是否已經完成 `link_ok`、`time_valid`、`pps_valid`，仍要以板上 LED 或外部 PPS 量測結果確認。

### 16.6 現場確認步驟

燒錄完成後等待約 10 至 30 秒，分別在兩片板子記錄：

```text
Master DE5 [1-11.1]
  LED[0..3]          = ____
  LED_BRACKET[0..3]  = ____

Slave DE5 [1-11.2]
  LED[0..3]          = ____
  LED_BRACKET[0..3]  = ____
```

最重要的同步判定是：

```text
LED[2]              = 1  -> tm_link_up
LED[3]              = 1  -> link_ok
LED_BRACKET[0]      = 1  -> tm_time_valid
LED_BRACKET[1]      = 1  -> pps_valid
```

只有燒錄成功、`link_up`、`link_ok`、`time_valid`、`pps_valid` 都成立，才能稱為「WR 內部同步已建立」。若要向教授提供獨立的物理證據，還要把兩片的 PPS（Pulse Per Second，每秒脈衝）輸出接到示波器兩個通道，量測 rising-edge time difference（上升緣時間差）。

## 17. 將 PPS 輸出到 DE5a SMA_CLKOUT 的驗證版

### 17.1 實驗名稱

**把 WR 的 PPS 狀態輸出到 SMA，建立兩片 DE5a 的外部同步量測點。**

### 17.2 為了驗證什麼

前一版雖然已把 `pps_valid_o` 接到 LED_BRACKET[1]，但 `pps_p_o` 尚未接到外部連接器。因此只能透過 LED 觀察內部狀態，還不能用示波器直接比較兩片板子的 PPS 上升緣。本次改版的目的，是讓外部儀器能直接量到 WR 產生的 PPS 脈波。

### 17.3 修改內容

Master 與 Slave 的 top-level VHDL 都新增 `SMA_CLKOUT` 輸出，並將 WR core 的：

```text
pps_p_o -> SMA_CLKOUT
```

同時在兩份 QSF（Quartus Settings File，Quartus 腳位與專案設定檔）加入：

```text
IO_STANDARD       = 1.8 V
LOCATION          = PIN_AA36
```

這次只增加 PPS 觀測輸出，不改變原本 QSFP-A 的 WR 光纖資料路徑，也不把 QSFP-B/C/D 誤當成 WR 資料鏈路。

### 17.4 Quartus 17 編譯結果

使用：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh --flow compile DE5a_wr_slave.qpf
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh --flow compile DE5a_wr_master.qpf
```

結果：

```text
Quartus Prime Full Compilation was successful. 0 errors
Quartus Prime Shell was successful. 0 errors, 265 warnings
```

新產生的 SOF（SRAM Object File，FPGA 暫存配置檔）摘要如下：

```text
Slave : 2645ff2acdb696d47532127f6a3212fba144983f09e71c629941c6c17dc577fd
Master: bb4d627f3b7f9da57d5bb3ba51d4ee76c22790ff669a40907b534f2323c7b847
```

需要注意：Quartus 的 TimeQuest 時序分析仍報告 `rx_clkout` 等路徑有負 slack，並且設計尚未完全約束。因此這是「可產生並可燒錄的實驗版」，不是已完成 timing closure（時序收斂）的最終版。

### 17.5 燒錄結果

先燒錄 Slave，再燒錄 Master：

```text
Slave  DE5 [1-11.2]: Configuration succeeded -- 1 device(s) configured
       Quartus Prime Programmer was successful. 0 errors, 0 warnings

Master DE5 [1-11.1]: Configuration succeeded -- 1 device(s) configured
       Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

兩個 Programmer 操作都讀到 JTAG ID `0x02E660DD`。這證明目前編譯出的兩個角色已確實載入對應的兩片 Arria 10 FPGA。

### 17.6 如何實際確認同步

1. 兩片板子維持 QSFP-A 對接，並等待 WR 建立鏈路。
2. 先看 LED：`LED[2]` 應代表 `tm_link_up`，`LED[3]` 應代表 `link_ok`，`LED_BRACKET[0]` 應代表 `tm_time_valid`，`LED_BRACKET[1]` 應代表 `pps_valid`。
3. 將 Master 的 `SMA_CLKOUT` 接示波器 CH1，Slave 的 `SMA_CLKOUT` 接 CH2。兩個 SMA 訊號的共同地端與儀器接法要符合示波器規格。
4. 觀察每秒一次的 PPS 上升緣，量測 CH1 與 CH2 的時間差。若兩邊都有穩定 PPS，且時間差維持在預期範圍，才是外部可觀察的同步證據。

目前已完成的是：PPS 輸出腳位已加入、兩個 SOF 已成功編譯、兩片板已成功燒錄。尚未完成的是：從本機直接取得 LED 狀態與示波器數值，因此不能在沒有現場觀測資料的情況下宣稱兩片已達到同步。

### 17.7 WR 時鐘同步與 Common Reset 的界線

本實驗要確認的是 WR 的 **link、時間鎖定與 PPS 狀態**。兩片板子的 WR 時鐘並不是靠目前的 `SMA_CLKOUT` 互相餵入而同步；目前設計中，`SMA_CLKOUT` 接的是 WR core 的 `pps_p_o`，也就是每秒一次的 PPS（Pulse Per Second，每秒脈衝）輸出，主要用途是讓示波器比較兩片板子的時間結果。

因此要區分兩件事：

```text
WR synchronization
  QSFP-A 光纖鏈路 + WR PTP/SoftPLL
  -> 校正並鎖定節點時間

Common Reset / START
  另外的同步事件線或共同 trigger
  -> 讓兩片使用者邏輯在同一個 clock edge 開始
```

本次「兩片 DE5a 使用 WR 同步時鐘」不必先加入 Common Reset 才能成立；只有後續要比較兩片 FPGA 的計數器、資料處理開始時間或加速器週期時，才需要另外加入 deterministic START/epoch 機制。不能把 PPS 輸出、Common Reset 與 WR link 混為同一個訊號。

## 18. JTAG Probe 實際同步狀態與 Slave RX 錯誤定位

### 18.1 實驗名稱

DE5a White Rabbit 16-bit JTAG 狀態探針與雙板鏈路診斷。

### 18.2 實驗目的

本實驗不是只看 LED，而是直接從 FPGA 內部讀回幾個能代表 White Rabbit 狀態的訊號，確認問題是在：

1. SFP/光模組是否被偵測到。
2. PHY（Physical Layer，實體層）是否完成初始化。
3. Master 與 Slave 的光纖鏈路是否真的建立。
4. 是否已經取得 WR 的有效時間與 PPS（Pulse Per Second，每秒脈衝）。
5. 接收端是否持續發生 8b/10b 編碼錯誤。

這樣可以把「尚未同步」進一步縮小到實體接收鏈路或 PHY 設定，而不是把所有問題都歸因於軟體。

### 18.3 本次修改

在 `DE5a_wr_master.vhd` 與 `DE5a_wr_slave.vhd` 加入 Quartus 17 的 `altsource_probe`。這個探針提供 16 個狀態位元，再由 `read_wr_sync_probe.tcl` 透過 JTAG（Joint Test Action Group，聯合測試行動組）讀回。

探針位元定義如下，最低位是 bit 0：

| 位元 | 訊號 | 意義 |
|---:|---|---|
| 0 | `si_config_done` | Si5340 時鐘晶片設定完成 |
| 1 | `wr_ready` | WR PHY 初始化完成 |
| 2 | `core_tm_link_up` | WR 時間管理鏈路已起來 |
| 3 | `core_link_ok` | WR 鏈路判定正常 |
| 4 | `core_tm_time_valid` | WR 時間有效 |
| 5 | `core_pps_valid` | WR PPS 有效 |
| 6 | `wr_rx_ready` | 接收端 ready |
| 7 | `wr_tx_ready` | 傳送端 ready |
| 8 | `QSFPA_MOD_PRS_n` | SFP 模組存在，低有效 |
| 9 | `QSFPA_INTERRUPT_n` | SFP 中斷腳位，低有效 |
| 10 | `core_phy_tx_disable` | PHY 是否被關閉傳送 |
| 11 | `core_phy_rst` | PHY 是否仍在 reset |
| 12 | `si_id_error` | Si5340 身分辨識錯誤 |
| 13 | `wr_rx_enc_err` | WR 接收端編碼錯誤 |
| 14 | `wr_tx_enc_err` | WR 傳送端編碼錯誤 |
| 15 | `CPU_RESET_n` | CPU reset 狀態 |

### 18.4 編譯與燒錄證據

使用 Quartus 17 完成 Master 與 Slave 的 Full Compilation，結果都是：

```text
Quartus Prime Full Compilation was successful. 0 errors
Quartus Prime Shell was successful. 0 errors
```

接著使用 JTAG Programmer 載入兩個 SOF（SRAM Object File，FPGA 暫存配置檔）：

```text
Slave  DE5 [1-11.2]: Configuration succeeded -- 1 device(s) configured
Master DE5 [1-11.1]: Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### 18.5 實際 JTAG 讀值

`read_wr_sync_probe.tcl` 連續讀取 6 次，每次約間隔 3 秒。pain terminal 的結果如下：

```text
2026-08-14 19:27:46
probe_hex: 82CF
probe_hex: A2C3
2026-08-14 19:27:51
probe_hex: 82CF
probe_hex: A2C3
2026-08-14 19:27:54
probe_hex: 82CF
probe_hex: A2C3
2026-08-14 19:27:58
probe_hex: 82CF
probe_hex: A2C3
2026-08-14 19:28:01
probe_hex: 82CF
probe_hex: A2C3
2026-08-14 19:28:04
probe_hex: 82CF
probe_hex: A2C3
```

這裡每一組讀值的順序是先 Master、再 Slave。

### 18.6 讀值解碼

| 狀態 | Master `0x82CF` | Slave `0xA2C3` | 解釋 |
|---|---:|---:|---|
| Si5340 設定完成 | 1 | 1 | 兩片時鐘晶片初始化正常 |
| PHY ready | 1 | 1 | 兩片 PHY 都已啟動 |
| SFP 模組存在 | 1 | 1 | 兩片都偵測到 Port A 模組 |
| SFP 中斷正常 | 1 | 1 | 沒有顯示模組中斷異常 |
| PHY TX disable | 0 | 0 | 兩片都沒有被軟體關閉傳送 |
| RX ready / TX ready | 1 / 1 | 1 / 1 | 介面握手狀態正常 |
| `tm_link_up` | 1 | 0 | 只有 Master 看到 WR 時間管理鏈路 |
| `link_ok` | 1 | 0 | Slave 尚未建立有效 WR 鏈路 |
| time valid / PPS valid | 0 / 0 | 0 / 0 | 目前兩片都尚未完成時間鎖定 |
| RX encoding error | 0 | 1 | Slave RX 持續收到無法正確解碼的資料 |
| TX encoding error | 0 | 0 | 沒看到 TX 編碼錯誤 |
| Si ID error | 0 | 0 | 沒看到 Si5340 身分辨識錯誤 |

### 18.7 結果判讀

這次結果可以用高中生也容易理解的方式表示：Master 像是「已經把網路線接通，也能正常發聲」，但 Slave 像是「有偵測到插頭、電源也開了，卻聽到一串無法解碼的雜訊」。因此 Slave 沒有辦法把 WR 封包正確還原，兩片也就不可能進入 time valid 與 PPS valid。

目前最有證據支持的第一個問題點是：

> **Slave 的 Port A RX 接收鏈路或 PHY 解碼路徑發生持續的 encoding error。**

目前沒有證據顯示問題來自：

- SFP 模組完全不存在。
- `core_phy_tx_disable` 被誤設為 1。
- Si5340 身分辨識錯誤。
- TX 端已經發生編碼錯誤。
- Common Reset 尚未加入。

Common Reset 不是目前 WR link 建立失敗的第一原因；它是日後讓使用者邏輯在同一個 clock edge 開始時才需要的額外機制。

### 18.8 下一個驗證實驗

下一步應保持目前 bitstream 不變，只驗證 Port A 的實體接收條件：

1. 確認兩片板真正使用的是 QSFP-A 對 QSFP-A 的同一條光路，而不是只連接 QSFP-B/C/D。
2. 將 Port A 的光纖或 DAC 線兩端互換，重新讀取同一個 16-bit probe。
3. 若錯誤跟著線材移動，優先懷疑線材、模組方向或模組與 1 GbE WR PHY 的相容性。
4. 若錯誤固定在 Slave，改用已知可工作的 1 GbE WR SFP/單模 BiDi 光路，或進一步檢查 Slave Port A 的 RX lane、極性與 transceiver 設定。
5. 只有當兩片都出現 `tm_link_up=1`、`link_ok=1`，並且 `time_valid=1`、`pps_valid=1` 後，才進行示波器 PPS skew 量測。

目前結論是「已成功建立可重現的故障定位證據」，不是「兩片 DE5a 已完成 White Rabbit 同步」。

### 18.11 唯讀比對舊版 QSFP 四埠資料傳輸專案

#### 實驗目的

為了判斷目前問題是否來自 DE5a 的 QSFP 腳位、reference clock（參考時脈）或 transceiver（高速收發器）基本設定，唯讀檢查 `/home/b10504072/02_QSFP/week03/QSFP_4PORT/`。這個專案沒有被修改，也沒有用它的 SOF 取代目前的 WR 設計。

#### 比對結果

舊專案的 `QSFP_4PORT.qsf` 使用的 QSFPA reference clock 與高速差動腳位如下：

```text
QSFPA_REFCLK_p : PIN_AH5
QSFPA_RX_p[0]  : PIN_BB5
QSFPA_TX_p[0]  : PIN_BD5
QSFPA_RX_p[1]  : PIN_AY5
QSFPA_TX_p[1]  : PIN_BC3
QSFPA_RX_p[2]  : PIN_BA3
QSFPA_TX_p[2]  : PIN_BB1
QSFPA_RX_p[3]  : PIN_AW3
QSFPA_TX_p[3]  : PIN_AY1
```

這些腳位與目前 WR 專案的 QSFPA mapping 一致，因此沒有發現「把 Port A 接到錯誤 FPGA pin」的證據。

舊專案另外使用 QSFP-B 與 QSFP-C 做 644.53125 MHz 的 transceiver clock，並以 ATX PLL（高速收發器專用鎖相迴路）產生發射串行時脈；它是四埠資料傳輸專案，和目前 WR 的 1 GbE/125 MHz PHY 架構不同，不能直接把它的 PLL 或 refclk 設定複製到 WR。這個比對只能支持「板級 pin mapping 大致正確」，不能證明目前 WR 的光路已經正常。

#### 結論

舊專案沒有提供目前 WR link failure 的直接修正，但縮小了問題範圍：目前應優先檢查 QSFPA 的光模組、光纖/DAC 方向、Port A RX lane 訊號品質與 WR PHY 的 8b/10b 對齊，而不是先修改 QSFP-B/C/D 的資料邏輯。

### 18.12 實驗：移除 boot script 內的 `sfp match` A/B

#### 實驗目的

驗證空的 `sfp-database` 是否是 WR 啟動未能進入穩定狀態的原因。原始 `sfp-database` 是 0 bytes；WRPC 的 SFP record（模組資料記錄）包含 part number、alpha、TX/RX delay 及 checksum，不能只靠空檔案取得實際模組的校正值。

#### 實際修改

保留原始 master/slave MIF，另外建立兩個 no-`sfp match` firmware：

```text
firmware/wrc_de5a_master_nosfpmatch.mif
firmware/wrc_de5a_slave_nosfpmatch.mif
```

它們只把 boot script 從：

```text
vlan off;ptp stop;sfp match;mode master/slave;ptp start
```

改成：

```text
vlan off;ptp stop;mode master/slave;ptp start
```

master/slave VHDL 的 `g_dpram_initf` 也改為指向新的 MIF；原本的 MIF 與前一版 diagnostic SOF 另行保留，沒有覆蓋。

#### 編譯與燒錄證據

兩個版本都用 Quartus Prime 17 完成 Full Compilation：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
```

Map report 確認新的 MIF 確實被當成 memory initialization file（記憶體初始化檔）納入：

```text
firmware/wrc_de5a_master_nosfpmatch.mif ; Auto-Found Memory Initialization File
firmware/wrc_de5a_slave_nosfpmatch.mif  ; Auto-Found Memory Initialization File
```

Programmer 也成功：

```text
Master checksum 0x308CF8EF: Configuration succeeded
Slave  checksum 0x308CA816: Configuration succeeded
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### pain terminal 實測結果

no-`sfp match` SOF 燒錄後，讀取 64-bit probe 的代表值：

```text
20:54:40  DE5 [1-11.1] 0000004D2FFFA2C3
          DE5 [1-11.2] 0000006126F082CF
20:54:46  DE5 [1-11.1] 000000C92F05A2C3
          DE5 [1-11.2] 0000006136BC82CF
20:54:52  DE5 [1-11.1] 0000004D2FFFA2C3
          DE5 [1-11.2] 0000006336BC82CF
```

低 16-bit 的 `A2C3` 表示該端 `tm_link_up=0`、`link_ok=0`，且 `rx_enc_err=1`；另一端的 `82CF` 表示 link up、link ok，但 `time_valid=0`、`pps_valid=0`。高位狀態也顯示失敗端有 `disperr/errdetect`。

#### 重要限制與結果判讀

這不是完全停用 SFP matching 的實驗。WRPC 的 `wrc_check_link()` 在 Ethernet link up 時仍會自動執行 `sfp_match(0)`；因此本次只移除初始化腳本中的顯式命令，沒有移除 link-up handler 的自動呼叫。這個結果不能被解讀為「SFP DB 已被完全排除」。

實驗仍提供兩個有用結果：

1. no-`sfp match` boot script 沒有讓兩端進入 `time_valid=1`、`pps_valid=1`。
2. master/slave 中至少一端仍出現方向性的 8b/10b disparity/error，問題仍集中在 Port A 光路、模組相容性、RX lane/極性、PHY reset/對齊或 SFP 校正資料，而不是單純把 boot script 多寫一個命令就能解決。

之後依照「先換已知可工作的 Port A 光模組/光纖，再比較錯誤是否跟著光路移動，最後才做完整 SFP PN 與 calibration DB」的順序處理。只有兩端連續看到 `tm_link_up=1`、`link_ok=1`、`time_valid=1`、`pps_valid=1`，才算完成 WR link/time synchronization（鏈路與時間同步）；目前仍未達成。

### 18.9 實驗：依照附圖將 QSFPA TX 四條 lane 的 First Post-Tap 設為 18

#### 實驗目的

先前曾經有「把 Transmitter Pre-Emphasis First Post-Tap Magnitude 設為 18 後，QSFP 可以同步」的經驗，因此這次把附圖中的設定完整轉成 Quartus QSF assignment，確認這個類比傳送參數是否能改善目前的 QSFP-A 鏈路。

#### 實際修改

Master 與 Slave 的 QSF 都加入：

```text
set_instance_assignment -name XCVR_A10_TX_PRE_EMP_SWITCHING_CTRL_1ST_POST_TAP 18 -to QSFPA_TX_p[0]
set_instance_assignment -name XCVR_A10_TX_PRE_EMP_SWITCHING_CTRL_1ST_POST_TAP 18 -to QSFPA_TX_p[1]
set_instance_assignment -name XCVR_A10_TX_PRE_EMP_SWITCHING_CTRL_1ST_POST_TAP 18 -to QSFPA_TX_p[2]
set_instance_assignment -name XCVR_A10_TX_PRE_EMP_SWITCHING_CTRL_1ST_POST_TAP 18 -to QSFPA_TX_p[3]
```

這裡的數字 18 是十進位值；Fitter report 顯示實際硬體參數為 `0x12`，證明目前使用的 transceiver instance 確實採用了 18。

需要特別注意：目前 WR 設計實際只使用 QSFPA lane 0，lane 1 到 lane 3 在 top-level 被固定為 0。因此，附圖中的四條 assignment 已經完整加入，但真正影響目前 WR 1GbE 光路的主要是 lane 0。

#### 編譯證據

使用指定的 Quartus 17 完成 Master 與 Slave Full Compilation：

```text
Quartus Prime Full Compilation was successful. 0 errors, 266 warnings
Quartus Prime Shell was successful. 0 errors, 266 warnings
```

Fitter report 的關鍵結果：

```text
pre_emp_switching_ctrl_1st_post_tap ; 0x000000012
```

兩個 revision 都顯示相同的 `0x12`。編譯仍有原本就存在的 timing warnings，包含 setup/recovery slack 不足；因此這次只能說「編譯成功且參數生效」，不能說 timing 已完全收斂。

#### 燒錄證據

保持兩片板的正常角色配置，使用 JTAG 寫入：

```text
DE5 [1-11.2]  -> output_files_slave/DE5a_wr_slave.sof
DE5 [1-11.1]  -> output_files_master/DE5a_wr_master.sof
```

兩次 Programmer 都回報：

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### 最新 JTAG probe 結果

燒錄後使用 32-bit `read_wr_sync_probe.tcl` 讀取：

```text
=== DE5 [1-11.1] ===
instances: {0 1 32 STER}
probe_hex: 2F0FA2C3

=== DE5 [1-11.2] ===
instances: {0 1 32 LAVE}
probe_hex: 33BC82CF
```

依照 probe 定義，低 16-bit 的重點狀態如下：

| JTAG cable | 低 16-bit | `tm_link_up` | `link_ok` | `rx_enc_err` | 判讀 |
|---|---:|---:|---:|---:|---|
| `DE5 [1-11.1]` | `A2C3` | 0 | 0 | 1 | RX 仍有編碼錯誤，WR link 未建立 |
| `DE5 [1-11.2]` | `82CF` | 1 | 1 | 0 | 這一端可以正確收到並解碼 WR 資料 |

`0x33BC82CF` 與 `0x2F0FA2C3` 的高 16-bit 也顯示兩端的 raw RX data、bitslide 與 K-character 狀態並不相同；問題不是單純 WR master/slave 指令沒有下達，而是其中一端的接收資料仍未正確對齊或解碼。

#### 結果與結論

這次實驗的結果是：

1. Pre-Emphasis First Post-Tap Magnitude = 18 已成功寫入 QSF。
2. Quartus Fitter 已確認實際值為 `0x12`。
3. Master/Slave 都成功編譯與燒錄。
4. QSFP-A 的兩端仍沒有同時進入 `tm_link_up=1`、`link_ok=1`。
5. 因此「只調整 First Post-Tap=18」沒有排除目前的鏈路故障。

用簡單的比喻：這次把其中一台設備的「發射音量與高頻補償」調成指定值，設備確實使用了這個設定，但另一端仍然聽到無法解碼的聲音。下一個優先驗證點仍是 QSFP-A 的光纖/DAC、SFP 相容性、模組方向，以及發生錯誤的實體 Port A RX lane；目前不應宣稱 White Rabbit 已經同步。

### 18.10 重複讀值確認

為了排除「剛燒錄後狀態尚未穩定」的可能性，於 2026-08-14 20:16:37、20:16:40、20:16:42 連續讀取三次：

```text
20:16:37  DE5 [1-11.1] 2F0F82C3   DE5 [1-11.2] 235C82CF
20:16:40  DE5 [1-11.1] 2F0FA2C3   DE5 [1-11.2] 33BC82CF
20:16:42  DE5 [1-11.1] 2F0FA2C3   DE5 [1-11.2] 33BC82CF
```

低 16-bit 的故障狀態在三次讀值中都沒有改變：一端維持 `A2C3`，另一端維持 `82CF`。因此本次結果可重現，Pre-Emphasis=18 沒有讓兩片板進入同步狀態。

### 18.13 QSFP-B 替代資料路徑 A/B 實驗

#### 實驗名稱

將 White Rabbit 的資料收發路徑由原本的 QSFP-A 改到 QSFP-B，確認問題是否只是 QSFP-A port 或其接線造成。

#### 實驗目的

兩片 DE5a 已使用 A-A、B-B、C-C、D-D 連線，但原始 WR 設計實際只使用 QSFP-A 的 lane 0 作為 WR Ethernet 資料路徑。這個實驗保留原本 Master/Slave 角色與 First Post-Tap Magnitude=18，只把 WR 的實體資料路徑切到 QSFP-B；若結果改善，代表 A-port 路徑值得優先檢查；若結果不變，則問題較可能在光模組/線材相容性、接收端 transceiver 或校正設定。

#### 改動內容

新增獨立的替代檔案，不覆蓋原版：

```text
DE5a_wr_master_portb.vhd
DE5a_wr_slave_portb.vhd
DE5a_wr_master_portb.qsf/.qpf/.sdc
DE5a_wr_slave_portb.qsf/.qpf/.sdc
```

替代版的主要改動如下：

1. WR PHY TX/RX 改接 `QSFPB_TX_p(0)` 與 `QSFPB_RX_p(0)`。
2. WR 參考時鐘改用 `QSFPB_REFCLK_p`。
3. DMTD 時鐘改用 `QSFPA_REFCLK_p`，並把 SI5340 的 125 MHz 與 124.992 MHz 輸出對調到相應的 refclk。
4. SFP 偵測、I2C、reset、module select 與 low-power 控制改接 QSFP-B。
5. 只對實際使用的 `QSFPB_TX_p[0]` 設定 First Post-Tap Magnitude=18；未使用 lane 不再套用 transceiver pre-emphasis。

#### Quartus 17 編譯結果

使用 pain 上的 Quartus Prime 17.0 完成兩個獨立 revision：

```text
DE5a_wr_master_portb: Quartus Prime Full Compilation was successful. 0 errors, 291 warnings
DE5a_wr_slave_portb : Quartus Prime Full Compilation was successful. 0 errors, 291 warnings
```

Timing analyzer 仍報告原設計已有的未完全約束與少量負 setup/recovery slack；這是 warning，沒有阻止 SOF 產生，但仍代表這不是已完成 timing closure 的設計。

#### 燒錄結果

先燒錄 slave，再燒錄 master：

```text
DE5 [1-11.2] -> output_files_slave_portb/DE5a_wr_slave_portb.sof
checksum: 0x309BF81B
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings

DE5 [1-11.1] -> output_files_master_portb/DE5a_wr_master_portb.sof
checksum: 0x309E3B61
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### Probe 結果

燒錄後等待 8 秒，以 Quartus 17 的 `quartus_stp -t read_wr_sync_probe.tcl` 讀取 64-bit probe：

```text
DE5 [1-11.1] master: 0000006131BC82CF
DE5 [1-11.2] slave : 0000004D2F80A2C3
```

低 16-bit 的解讀：

| 端點 | 低 16-bit | `tm_link_up` | `link_ok` | `rx_enc_err` | `time_valid` | `pps_valid` |
|---|---:|---:|---:|---:|---:|---:|
| Master | `82CF` | 1 | 1 | 0 | 0 | 0 |
| Slave | `A2C3` | 0 | 0 | 1 | 0 | 0 |

為避免把暫態誤認成結果，接著每 5 秒重讀一次，共 6 次：

```text
21:29:43  master 000000C1215082CF  slave 000000CD2F80A2C3
21:29:49  master 0000006131BC82CF  slave 0000004D2F82A2C3
21:29:55  master 0000006131BC82CF  slave 000000CD2F80A2C3
21:30:00  master 0000006331BC82CF  slave 0000004D2F82A2C3
21:30:06  master 000000C1311C82CF  slave 000000CD2F80A2C3
21:30:11  master 0000006331B482CF  slave 0000004D2F82A2C3
```

結果中的低 16-bit 完全維持 Master=`82CF`、Slave=`A2C3`，沒有進入 `time_valid=1` 或 `pps_valid=1`。

#### 實驗結論

這個 A/B 實驗的結論是：

1. B-port 替代設計可以成功編譯、成功燒錄，說明 VHDL、QSF 與 transceiver pin assignment 在工具層面可成立。
2. 實際 WR link 狀態與原本 A-port 實驗相同，沒有因為換到 QSFP-B 而改善。
3. 因此目前不能把問題簡化成「QSFP-A 接錯」或「只要使用 B-port 就會同步」。
4. 現在最優先的檢查順序是：交換兩端 QSFP 光模組/光纖或 DAC，觀察 `rx_enc_err` 是否跟著實體路徑移動；若錯誤固定在 Slave，再檢查 Slave 的 Arria 10 RX lane、refclk、reset/bitslide 與 PCS 設定。
5. 在 `rx_enc_err=0` 且兩端 `link_ok=1` 之前，不應進一步把問題歸因於 WR servo 或 SFP calibration；因為目前尚未通過最底層的 Ethernet/PCS 解碼。

#### 恢復原版

測試完成後已恢復原本 A-port 的診斷版 SOF：

```text
DE5 [1-11.2] -> output_files_slave/DE5a_wr_slave_before_nosfpmatch.sof
checksum: 0x308CA816

DE5 [1-11.1] -> output_files_master/DE5a_wr_master_before_nosfpmatch.sof
checksum: 0x308CF8EF
```

恢復後讀值：

```text
master: 000000E333BC82CF
slave : 0000004D2FD7A2C3
```

所以目前板上不是 B-port 替代版，原始 A-port 測試版本仍在；原始同步故障也被成功重現。

### 18.14 Slave near-end transceiver loopback 隔離實驗

#### 實驗名稱

在不改動 Master、光纖與原版專案的前提下，將 Slave 的 Arria 10 transceiver `loopen_i` 強制為 `1`，讓 Slave 的 TX 在 FPGA 內部直接回到自己的 RX。

#### 實驗目的

區分以下兩種可能：

1. Slave 自己的 refclk、transceiver reset、RX CDR、8b/10b decoder 或 PCS 有問題。
2. Slave 本身正常，真正的問題在外部 QSFP 光路、模組、線材或 Master TX 到 Slave RX 的實體路徑。

#### 改動內容

建立獨立的診斷 revision：

```text
DE5a_wr_slave_loopback.vhd
DE5a_wr_slave_loopback.qsf/.qpf/.sdc
```

唯一功能性改動是：

```vhdl
loopen_i => '1'
```

原本的 Master、原版 Slave、First Post-Tap=18、SI5340 clock selection 與其他 pin assignment 都沒有修改。

#### 編譯與燒錄證據

```text
Quartus Prime Full Compilation was successful. 0 errors, 264 warnings

DE5 [1-11.2] -> output_files_slave_loopback/DE5a_wr_slave_loopback.sof
checksum: 0x308EEEA2
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### Loopback probe 結果

燒錄 Slave loopback、Master 維持原版後，等待 8 秒讀取：

```text
DE5 [1-11.1] Master: 0000004F2F0FA2C3
DE5 [1-11.2] Slave : 0000006131BC82CF
```

低 16-bit 解讀：

| 端點 | 低 16-bit | `tm_link_up` | `link_ok` | `rx_enc_err` |
|---|---:|---:|---:|---:|
| Master，外部收不到有效 Slave 回傳 | `A2C3` | 0 | 0 | 1 |
| Slave，近端 TX-to-RX loopback | `82CF` | 1 | 1 | 0 |

接著每 4 秒重讀 4 次：

```text
21:44:12  Master 0000004D2F0FA2C3  Slave 0000006131BC82CF
21:44:16  Master 0000004D2F0FA2C3  Slave 000000E121D082CF
21:44:21  Master 000000C12F0A82C3  Slave 000000E121D082CF
21:44:25  Master 0000004D2F0BA2C3  Slave 0000006131BC82CF
```

Slave loopback 的低 16-bit 穩定為 `82CF`，而原本外部 QSFP 連線時 Slave 穩定為 `A2C3`。這不是時間同步成功；loopback 沒有真正的遠端 Master，因此 `time_valid` 與 `pps_valid` 不會因此變成 1。

#### 結果判讀

這是目前最有辨識力的結果：

1. Slave 本地 TX、near-end loopback、RX decoder、部分 CDR/clock/reset 路徑可以正常工作。
2. 原本的 `rx_enc_err=1` 並不是 Slave RX 在任何情況下都會出錯。
3. 問題高度集中在外部 Master TX 到 Slave RX 的 QSFP 實體路徑，包含光模組、光纖/DAC、接觸、相容性、單方向訊號品質，或外部路徑上的 polarity/lane 對應。
4. 目前不應再優先修改 WR servo、SFP calibration 或 C/D port；必須先讓外部連線的 Slave `rx_enc_err` 清為 0。

#### 恢復證據

Loopback 測試後已恢復原版 Slave：

```text
DE5 [1-11.2] -> output_files_slave/DE5a_wr_slave_before_nosfpmatch.sof
checksum: 0x308CA816
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

恢復後 8 秒 probe：

```text
Master: 000000CD2FE2A2C3
Slave : 000000C1235082CF
```

目前板上已回到原版 A-port 實驗狀態；完整 WR time synchronization 仍未完成。

#### 下一個最小實驗

保持目前含 `sfp match` 與 First Post-Tap=18 的原版 SOF 不變，只交換兩端 QSFP-A 光模組或光纖/DAC，然後重複讀取同一個 probe：

```text
錯誤跟著模組/線材移動 -> 實體光路或相容性問題
錯誤始終固定在 Slave -> 再查 Slave RX lane polarity、bitslide、reset/refclk 或 PCS
兩端 rx_enc_err=0、link_ok=1 -> 才進入 WR time_valid/PPS 與 calibration 檢查
```

### 18.15 Loopback 後的恢復順序與 baseline 正規化

#### 實驗名稱

在完成 Slave near-end loopback 後，先只恢復 Slave，再依照原本的角色順序重新燒錄 Slave 與 Master，確認診斷版沒有殘留在板上，並建立可重複比較的 A-port baseline（基準狀態）。

#### 為了驗證什麼

這個實驗要確認兩件事：

1. loopback 結束後，兩片板是否真的回到原始 A-port Master/Slave 設計。
2. `rx_enc_err` 的方向是否固定在某一片板，或會受重新初始化與燒錄順序影響。

#### 操作與結果

先只恢復原版 Slave：

```text
DE5 [1-11.2] -> output_files_slave/DE5a_wr_slave_before_nosfpmatch.sof
checksum: 0x308CA816
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

只恢復 Slave 後讀到：

```text
Master: 000000CD2FE2A2C3
Slave : 000000C1235082CF
```

接著每隔約 5 秒連續讀取：

```text
21:46:27  master 000000CF2FE2A2C3  slave 000000C3235082CF
21:46:33  master 000000CD2FE2A2C3  slave 000000E1237082CF
21:46:39  master 000000CF2FE2A2C3  slave 000000C1331C82CF
21:46:44  master 000000CD2FE2A2C3  slave 0000006133BC82CF
21:46:50  master 000000CD2FE2A2C3  slave 0000006133BC82CF
21:46:55  master 000000492F4BA2C3  slave 000000C1235082CF
```

這時錯誤方向變成 Master=`A2C3`、Slave=`82CF`，與 loopback 前的常見方向相反。這表示不能只用「錯誤固定在 Slave」解釋全部現象；外部連線、上電/燒錄初始化順序，或某個方向的光路狀態都可能參與其中。

之後依照原本角色順序重新燒錄兩片：

```text
DE5 [1-11.2] Slave  checksum: 0x308CA816
DE5 [1-11.1] Master checksum: 0x308CF8EF
```

重新燒錄兩片後，4 次 probe 結果為：

```text
21:48:31  master 00000041225082CF  slave 000000CD2F77A2C3
21:48:36  master 000000E132BC82CF  slave 000000CF2F37A2C3
21:48:40  master 000000E332BC82CF  slave 000000CD2F37A2C3
21:48:45  master 000000E132BC82CF  slave 000000CF2F37A2C3
```

#### 怎麼看待這個結果

重新燒錄後又回到常見 baseline：

```text
Master: 82CF -> tm_link_up=1, link_ok=1, rx_enc_err=0
Slave : A2C3 -> tm_link_up=0, link_ok=0, rx_enc_err=1
```

因此目前的結論是：

1. 原始 A-port bitstream 可以正常編譯與燒錄，JTAG probe 也能穩定讀到狀態。
2. Slave near-end loopback 的 `82CF` 證明 Slave 本地 TX、RX decoder 及部分 clock/reset 路徑可以工作。
3. 外部 QSFP-A 連線仍未建立雙向、無編碼錯誤的 WR Ethernet link；`time_valid=0`、`pps_valid=0`，所以**尚不能宣稱 White Rabbit 時間同步成功**。
4. 只恢復一片與重新恢復兩片後，錯誤方向不同，表示下一步不應繼續盲改 WR servo 或 SFP calibration，而要先做實體光路 A/B test。

目前板上狀態已正規化為原始 A-port Master/Slave SOF，沒有把診斷 loopback 或 Port-B 版本留在板上。

#### 下一個必要的實體驗證

保持原始 SOF 不變，交換兩端 QSFP-A 的光模組、光纖/DAC 兩端，或改用已知可工作的 1 GbE White Rabbit 相容光模組。每次只改一個實體因素，再重複：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t /home/b10504072/04_White_Rabbit/week02/v01/read_wr_sync_probe.tcl
```

連續讀取至少 6 次。判讀方式：

```text
錯誤跟著模組或線材移動 -> 實體光路/相容性問題
錯誤始終固定在某片板 -> 再查該板 RX lane polarity、bitslide、reset/refclk 或 PCS
兩端 rx_enc_err=0 且 link_ok=1 -> 才能繼續檢查 time_valid、pps_valid 與 WR calibration
```

### 18.16 QSFP-A lane1 成對 bitstream A/B 實驗

#### 實驗名稱

將 WR 1GbE data path 從 QSFP-A lane0 成對移到 QSFP-A lane1，使用 Master/Slave 相同的 lane1 設計，確認問題是否只存在於 lane0。

#### 為了驗證什麼

因為 QSFP+ 線材有四條獨立 serial lane，lane0 失敗可能來自單一 lane 的 pin、接點、極性或光路品質。因此本實驗只替換 data lane，其他條件全部保持不變：

```text
QSFPA reference clock     不變
QSFP-A SFP I2C/reset      不變
WR master/slave firmware  不變
First Post-Tap            18
WR PHY                    不變
```

#### 硬體修改

建立獨立診斷檔案，沒有覆蓋原始 lane0 版本：

```text
DE5a_wr_master_lane1.vhd/.qsf/.qpf/.sdc
DE5a_wr_slave_lane1.vhd/.qsf/.qpf/.sdc
```

關鍵修改如下：

```text
WR PHY TX/RX：QSFPA lane 0 -> lane 1
RX pin       ：PIN_BB5 -> PIN_AY5
TX pin       ：PIN_BD5 -> PIN_BC3
```

同時修正 lane1 診斷 top 中未使用 TX lane 的固定值，避免 `QSFPA_TX_p[1]` 同時被常數與 PHY 驅動。

#### 編譯結果

使用 Quartus Prime 17 完成兩個完整編譯：

```text
Master lane1: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Slave  lane1: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
```

既有 timing warning 仍存在，例如 lane1 report 的最差 setup slack 約為負值；因此這個結果代表設計可產生 SOF，不代表 timing 已完全收斂。

#### 燒錄結果

```text
DE5 [1-11.2] Slave lane1  checksum: 0x308FEEDB
DE5 [1-11.1] Master lane1 checksum: 0x308FFCE5
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### pain terminal probe 結果

lane1 版本燒錄後等待 8 秒，再每隔約 5 秒讀取 8 次：

```text
22:06:28  Master 0000006337BC82CF  Slave 000000CD2FF6A2C3
22:06:34  Master 0000004137D882CF  Slave 000000C92F00A2C3
22:06:40  Master 0000006137BC82CF  Slave 000000CD2FF6A2C3
22:06:45  Master 0000006137BC82CF  Slave 000000CB2F00A2C3
22:06:51  Master 0000006137BC82CF  Slave 000000CD2FF6A2C3
22:06:56  Master 0000006137BC82CF  Slave 000000C92F00A2C3
22:07:02  Master 000000C3275082CF  Slave 000000CF2FF6A2C3
22:07:08  Master 000000C1275082CF  Slave 000000C92F00A2C3
```

低 16-bit 仍然是：

```text
Master = 82CF -> tm_link_up=1, link_ok=1, rx_enc_err=0
Slave  = A2C3 -> tm_link_up=0, link_ok=0, rx_enc_err=1
```

#### 復原結果

測試結束後立即恢復原始 lane0 SOF：

```text
DE5 [1-11.2] Slave  checksum: 0x308CA816
DE5 [1-11.1] Master checksum: 0x308CF8EF
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

復原後 probe：

```text
Master: 0000006130BC82CF
Slave : 000000492F00A2C3
```

#### 結果與結論

lane1 與 lane0 得到同樣的方向性故障，因此：

1. 問題不像是 QSFP-A lane0 單一 pin、單一 lane 接點或 lane0 專屬資料通道。
2. Slave 本地 loopback 已成功，lane0/lane1 外部連線都在 Slave RX 出現 `rx_enc_err=1`，目前更應優先懷疑外部光模組/線材相容性、單方向光路，或 Slave RX 的共通 polarity/PCS/reset/refclk 設定。
3. 四組 QSFP+ 都接上不代表 WR 會自動使用四條 lane；目前 WR PHY 每次只使用一條被指定的 lane。
4. 目前仍沒有 `time_valid=1` 或 `pps_valid=1`，所以尚未完成 WR 時間同步。

下一個實驗不再新增 lane2/lane3 bitstream；應保持目前已復原的 lane0 SOF，只交換 QSFP-A 兩端的光模組或線材其中一項，再重做相同的 8 次 probe。若錯誤跟著實體元件移動，才能確認是外部光路；若始終固定在 Slave，才進一步修改 Slave RX polarity、bitslip、reset/refclk 或 PCS。

### 18.17 Slave RX polarity 獨立診斷實驗

#### 實驗名稱

只在 Slave 端建立 `rx_polinv=1` 的獨立診斷 bitstream，確認目前的單向 `rx_enc_err` 是否由接收差動極性（RX polarity）造成。原始 lane0 Master/Slave 專案與 SOF 不覆蓋，只在完成測量後復原 Slave。

#### 為了驗證什麼

前面的 lane0、lane1 成對測試都得到 Master=`82CF`、Slave=`A2C3`。這表示錯誤並非只出現在 lane0，但仍可能是 Slave 端共通的 RX 極性或 PCS（Physical Coding Sublayer，實體編碼子層）解碼設定。因此本實驗把「Slave RX 極性反相」作為單一變因。

#### 改了什麼

在 `rxpol_diag/` 建立獨立專案，複製原本的 Slave 設計與產生的 Arria 10 PHY。只修改複製後的 generated PHY Verilog：

```text
原始 PHY：rx_polinv = 1'b0
診斷 PHY：rx_polinv = 1'b1
```

WR Master、Slave 韌體、QSFP-A lane0 pin、125 MHz reference clock、124.992 MHz DMTD clock、reset 與 SFP 控制均保持不變。這個實驗不是修改原始 `work_wrphy_full`，也不是修改只供參考的 QSFP_4PORT 專案。

#### Quartus 17 編譯結果

```text
Project: /home/b10504072/04_White_Rabbit/week02/v01/rxpol_diag/DE5a_wr_slave_rxpol
Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Worst-case setup slack: -3.215 ns
```

`0 errors` 表示可以產生可燒錄的 SOF；`-3.215 ns` 表示既有時序限制仍未完全收斂，因此這個 bitstream 只作為診斷用，不取代原始正式版本。

#### pain terminal 燒錄結果

```text
quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;.../rxpol_diag/output_files_slave_rxpol/DE5a_wr_slave_rxpol.sof
Using programming file .../DE5a_wr_slave_rxpol.sof with checksum 0x308CA7F6
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### 六次連續 probe 結果

Master 保持原始 lane0 SOF，Slave 使用 RX polarity 診斷 SOF。每次以 Quartus 17 `quartus_stp -t read_wr_sync_probe.tcl` 讀取兩片板：

```text
22:24:09  Master 000000492F4FA2C3  Slave 00000041275082CF
22:24:15  Master 000000CD2FE2A2C3  Slave 000000E137BC82CF
22:24:20  Master 000000CD2FE2A2C3  Slave 00000041371C82CF
22:24:25  Master 000000492F4FA2C3  Slave 00000043275082CF
22:24:30  Master 000000492F4FA2C3  Slave 000000E137BC82CF
22:24:35  Master 000000CD2FE2A2C3  Slave 000000E137BC82CF
```

低 16-bit 的判讀為：

```text
Master = A2C3 -> tm_link_up=0, link_ok=0, rx_enc_err=1
Slave  = 82CF -> tm_link_up=1, link_ok=1, rx_enc_err=0
```

#### 結果如何看

RX polarity=1 沒有讓兩端同時建立 WR link，而是讓原本的「哪一端能解碼」方向翻轉。這有兩個重要結論：

1. `rx_polinv` 確實會影響目前的解碼結果，不能完全排除 polarity/PCS 方向問題。
2. 但單獨把 Slave 反相並不是正確解法，因為六次結果仍然沒有兩端同時 `link_ok=1`，更沒有 `time_valid=1` 或 `pps_valid=1`。因此不能宣稱 WR link 或時間同步成功。

#### 復原證據

診斷完成後立即把 Slave 恢復成原始 SOF，Master 沒有更換：

```text
Slave original checksum: 0x308CA816
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings

Restored probe:
Master: 0000004D2F1DA2C3
Slave : 00000041265082CF
```

目前板上狀態已回到原始 lane0 版本。下一個最有效的非破壞性步驟仍是交換 QSFP-A 兩端的光模組或線材其中一項，再讀取相同的 6 至 8 次 probe；若錯誤跟著實體元件移動，便可確認外部光路，若仍固定在 Slave，才繼續查 Slave RX bitslip、PCS word alignment、reset 或 reference-clock。

### 18.18 QSFP-C 參考時脈與光路診斷實驗

#### 實驗名稱

在不覆蓋原始 A-port 專案的前提下，建立 QSFP-C lane0 的 Master/Slave 診斷版，先修正 SI5340 的輸出時脈路由，再把兩片板的資料鏈路由 QSFP-A 改成 QSFP-C。測試完成後恢復原始 A-port bitstream。

#### 為了驗證什麼

四條 QSFP+ 線都接上後，WR 仍然只會使用 top/PHY 明確指定的那一條資料路徑，不會自動把 A、B、C、D 四個 port 合併使用。本實驗要確認：

1. QSFP-C 的 pin mapping 與 read-only 的 `02_QSFP/week03/QSFP_4PORT` 參考專案是否一致。
2. C-port 是否拿到正確的 125 MHz PHY reference clock。
3. 如果 C-port 可以初始化，是否能像原始 A-port 一樣建立 WR link；若不能，問題就不只是「沒有接線」。

#### 改了什麼

建立獨立檔案：

```text
DE5a_wr_master_portc.{vhd,qsf,qpf,sdc}
DE5a_wr_slave_portc.{vhd,qsf,qpf,sdc}
```

使用的 QSFP-C lane0 pin 與唯讀參考專案相同：

```text
REFCLK  PIN_Y5
RX0     PIN_AA3
TX0     PIN_AB1
LP_MODE PIN_AH10
MOD_PRS PIN_AD10
MOD_SEL PIN_AL9
RST     PIN_AJ9
```

第一版 C 診斷版把 `SI5340 OUT2` 設成 `POWER_DOWN`。由 DE5a 的 clock routing 可知，`OUT0 -> QSFP-A`、`OUT1 -> QSFP-B`、`OUT2 -> QSFP-C`、`OUT3 -> QSFP-D`，所以這會使 C-port 沒有 PHY reference clock。修正後的設定為：

```text
OUT0 = 124.992 MHz  -> QSFP-A，供 DMTD
OUT1 = POWER_DOWN   -> QSFP-B
OUT2 = 125 MHz      -> QSFP-C，供 WR PHY
OUT3 = POWER_DOWN   -> QSFP-D
```

同時把 C 診斷版的 SDC 改成 `QSFPA_REFCLK_p=124.992 MHz`、`QSFPC_REFCLK_p=125 MHz`。QSFP-C lane0 的 QSF 已設定 `Transmitter Pre-Emphasis First Post-Tap Magnitude=18`；這個數值與先前 A-port 實驗一致。

唯讀參考專案只用來核對 pin 與 port routing，沒有修改：

```text
/home/b10504072/02_QSFP/week03/QSFP_4PORT/
```

#### Quartus 17 編譯結果

修正後使用 `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh` 完成完整編譯：

```text
Master C: Quartus Prime Full Compilation was successful. 0 errors, 291 warnings
Slave  C: Quartus Prime Full Compilation was successful. 0 errors, 291 warnings
```

兩份設計都產生 `.sof`。既有的 Arria 10 transceiver timing warning 仍存在，因此 `0 errors` 只代表成功產生可燒錄檔，不代表 timing 已完全收斂。

#### pain terminal 燒錄結果

```text
Slave C: checksum 0x3096925A
Master C: checksum 0x30957D73
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### pain terminal probe 結果

C-port 修正前，兩片板都停在：

```text
Master 000000000F008201
Slave  000000000F008201
```

修正 OUT2 後，QSFP-C 的 RX 開始有反應，但沒有建立完整 link。低 16-bit 的代表性結果如下：

```text
22:50:17  Master ...A241  Slave ...8201
22:50:20  Master ...A241  Slave ...A241
22:50:24  Master ...A241  Slave ...A241
22:50:27  Master ...A241  Slave ...8201
22:51:19  Master ...A241  Slave ...8241
22:51:25  Master ...A241  Slave ...A241
22:51:30  Master ...A241  Slave ...8201
```

這些值共同表示：

```text
rx_ready 有時為 1，但 phy_ready/tx_ready 沒有穩定為 1
tm_link_up = 0
link_ok    = 0
time_valid = 0
pps_valid  = 0
```

`A241` 還包含 `rx_enc_err=1`；`8241` 沒有該錯誤，但仍沒有 link；`8201` 則回到 PHY 尚未 ready 的狀態。因此不能把短暫的 RX ready 當成 C-port 成功。

#### 結果如何看

這個實驗得到兩個層次的結論：

1. **已確定的問題：** 第一版 C 診斷版確實漏掉 QSFP-C 所需的 `SI5340 OUT2=125 MHz`。把 OUT2 從關閉改成 125 MHz 後，probe 從 `8201` 變成會出現 `A241/8241`，說明 C-port 參考時脈確實被修復，這不是猜測。
2. **尚未解決的問題：** C-port 在正確 reference clock 下仍沒有穩定 `phy_ready=1`、`tx_ready=1`、`tm_link_up=1`、`link_ok=1`，而且沒有 `time_valid=1` 或 `pps_valid=1`。因此 C-port 仍可能有 transceiver channel、光模組/線材、PCS polarity/word alignment 或 reset/校準相容性問題。

這次結果也不能用來宣稱 QSFP-C 光路壞掉，因為目前還沒有把 C-port 的 RX polarity、transceiver CDR/word alignment 與光模組互換做成獨立 A/B 實驗。下一步應優先保留 OUT2=125 MHz 的 C 診斷版，另做一個只改 RX polarity 的版本，或交換兩端 C-port 光模組/線材後重讀相同 probe；不要同時改多個參數。

#### 復原證據

診斷結束後恢復原始 A-port bitstream：

```text
Slave original: checksum 0x308CA816
Master original: checksum 0x308CF8EF
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

復原後連續 probe 回到既有基線：

```text
22:53:50  Master ...82CF  Slave ...A2C3
22:53:54  Master ...82CF  Slave ...A2C3
22:53:58  Master ...82CF  Slave ...A2C3
```

所以目前兩片板沒有留下 C 診斷版；原始 A-port 方向性錯誤仍可重現，且目前仍不能宣稱 White Rabbit link 或時間同步成功。

### 18.19 雙端 RX polarity 診斷、原始版本復原與 fresh firmware compile

#### 實驗名稱

先建立「Master 與 Slave 都把 Arria 10 RX polarity 反相」的獨立診斷版，完成後恢復原始 A-port；接著重新編譯原始 Master/Slave，確認目前 `.sof` 確實使用指定的 firmware MIF，而不是舊的 `*_nosfpmatch.mif`。

#### 為了驗證什麼

這組實驗分別驗證兩件事：

1. 如果兩端同時反相後能穩定建立 link，問題可能是外部光路或兩端 polarity 定義不一致。
2. 如果原始碼指定的 Master/Slave firmware 與 map report 不一致，可能造成板端角色或 WRPC 初始化行為不可信。

#### 改了什麼

第一階段只在獨立目錄修改 generated PHY 的 `rx_polinv`，Master 與 Slave 都設為 `1'b1`；其他 top、QSFP-A lane0、125 MHz/124.992 MHz clock、pre-emphasis=18 與 firmware 保持不變。診斷完成後恢復原始 bitstream。

第二階段重新執行：

```text
quartus_sh --flow compile DE5a_wr_master
quartus_sh --flow compile DE5a_wr_slave
```

重新編譯前，原始 VHDL 已明確指定：

```text
Master: firmware/wrc_de5a_master.mif
Slave : firmware/wrc_de5a_slave.mif
```

#### Quartus 17 與 pain terminal 結果

雙端 RX polarity 診斷版：

```text
Master compile: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Slave  compile: Quartus Prime Full Compilation was successful. 0 errors, 269 warnings
```

診斷版 probe 代表性結果：

```text
23:08:33  Master ...82CF  Slave ...A2C3
23:08:38  Master ...82CF  Slave ...A2C3
23:08:43  Master ...82CF  Slave ...A2C3
23:08:47  Master ...82CF  Slave ...A2C3
23:08:52  Master ...82CF  Slave ...A2C3
23:08:56  Master ...82CF  Slave ...82C3
```

之後觀察約 80 秒，Slave 只在 `A2C3` 與 `82C3` 之間變動，沒有穩定 `tm_link_up=1`、`link_ok=1`。`82C3` 雖然代表編碼錯誤清除，但 link 仍未建立。

復原原始 A-port 後，曾短暫觀察到：

```text
23:11:08  Master ...82CF  Slave ...82CF
23:11:12  Master ...82CF  Slave ...82CF
23:11:15  Master ...82CF  Slave ...82CF
```

但這個狀態在重新 fresh compile、重新燒錄後不能重現；新 SOF 燒錄後的 probe 為：

```text
23:25:52  Master 000000C1225082CF  Slave 0000004D2F64A2C3
```

新編譯本身的結果是：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
```

新 map report 已確認使用正確 MIF：

```text
Master: firmware/wrc_de5a_master.mif
Slave : firmware/wrc_de5a_slave.mif
```

兩片板也都由 Quartus 17 Programmer 成功設定：

```text
Slave checksum : 0x308CA816
Master checksum: 0x308CF8EF
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### 結果如何看

1. **雙端 RX polarity=1 不是解法。** 它沒有得到穩定雙向 WR link，只是讓 Slave 的錯誤狀態在 `A2C3/82C3` 間變化。
2. **先前雙 `82CF` 只能視為暫態現象。** 因為 fresh compile、fresh programming 後又回到穩定的 `Master=82CF / Slave=A2C3`，不能以那三次讀值宣稱 link 已修好。
3. **stale MIF 風險已排除。** fresh map 明確使用 `wrc_de5a_master.mif` 與 `wrc_de5a_slave.mif`，所以後續若仍有方向性錯誤，應優先回到 generated PHY/refclk/reset、光模組/線材、lane/polarity/PCS 的硬體診斷，而不是繼續猜 firmware 檔案。
4. **時間同步仍未完成。** 即使看到 `82CF`，其中 `time_valid=0`、`pps_valid=0`；目前沒有任何可宣稱 WR time lock 的證據。

另外，新版 Timing Analyzer 仍報 timing requirements not met，代表目前設計雖可 compile/program，但不能稱為 timing closed：Master 最差 setup slack 約 `-3.449 ns`，Slave 約 `-3.215 ns`。這是獨立的工程風險，後續需要修正 clock constraint 或 datapath，而不能忽略。

#### 下一步

保持目前原始 A-port bitstream，不再同時改多個設定。下一個最小變因應是：先用現有的 Slave near-end loopback 重新確認本地 PHY/refclk/reset，再做一次「只交換 A-port 一端光模組」的 A/B 測試；若錯誤跟著光模組移動，才可把根因收斂到外部光路。

### 18.20 Slave near-end loopback 隔離實驗

#### 實驗名稱

只把 Slave 的 Arria 10 transceiver `loopen_i` 固定為 1，讓 Slave 做本地 TX-to-RX near-end loopback；Master 保持目前原始 A-port bitstream，完成後恢復原始 Slave SOF。

#### 為了驗證什麼

這個實驗用來把「Slave 本地 PHY/refclk/reset/PCS」與「Master TX 到 Slave RX 的外部光路」分開。若 loopback 成功而外部模式失敗，問題就不在 Slave 的基本本地收發器初始化，而集中到外部接收方向。

#### 改了什麼

只使用既有獨立診斷設計：

```text
DE5a_wr_slave_loopback.vhd
loopen_i => '1'
```

沒有修改 Master、光纖、QSFP 模組、A-port pin、125 MHz PHY refclk、124.992 MHz DMTD refclk、firmware 或 pre-emphasis。loopback 設計使用 `firmware/wrc_de5a_slave.mif`，燒錄完成後再換回原始 `output_files_slave/DE5a_wr_slave.sof`。

#### pain terminal 燒錄與 probe 結果

Slave loopback 燒錄成功：

```text
Programming cable: DE5 [1-11.2]
checksum: 0x308EEEA2
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

等待初始化後連續讀取 6 組 probe，每次讀到 Master、Slave 各一筆：

```text
23:28:25  Master ...82CF  Slave ...82CF
23:28:31  Master ...82CF  Slave ...82CF
23:28:37  Master ...82CF  Slave ...82CF
23:28:42  Master ...82CF  Slave ...82CF
23:28:48  Master ...82CF  Slave ...82CF
23:28:53  Master ...82CF  Slave ...82CF
```

低 16-bit `82CF` 的意義是：

```text
si_config_done = 1
phy_ready      = 1
tm_link_up     = 1
link_ok        = 1
rx_ready       = 1
tx_ready       = 1
rx_enc_err     = 0
time_valid     = 0
pps_valid      = 0
```

實驗結束後恢復原始 Slave：

```text
checksum: 0x308CA816
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

#### 結果如何看

這是目前辨識力最高的結果：

1. Slave 在本地 loopback 可以穩定完成 `phy_ready`、`tx_ready`、`tm_link_up`、`link_ok`，而且 `rx_enc_err=0`。因此 Slave 的基本 generated PHY、125 MHz refclk、reset sequencing 與本地 PCS 並非完全失效。
2. 原始外部模式則穩定是 Master `82CF`、Slave `A2C3`，即只有 Slave RX 方向出現 `rx_enc_err=1`。把兩者對照後，最可疑的範圍收斂為：

```text
Master TX -> QSFP-A optical module/fiber/cable -> Slave RX
```

3. 目前不能直接說一定是光纖壞掉，因為 near-end loopback 會繞過外部光路，也不能單獨排除 Slave RX polarity、lane mapping、PCS word alignment 或實際 QSFP channel 問題。但現在已不應再盲目調整 pre-emphasis 來代替 A/B 測試。
4. `time_valid=0`、`pps_valid=0` 在 loopback 中仍為 0，這是合理的；loopback 只證明本地收發器與 link 狀態，沒有證明兩片板已完成 WR/PTP 時間同步。

#### 下一個必要的實體 A/B 測試

保持目前原始 A-port bitstream，只交換一個實體元件：優先交換兩端 A-port 的 QSFP 光模組，光纖與 FPGA port 不動；若不方便拆模組，才先只交換 A-A 光纖/DAC。每次只換一項後重複 6 至 8 次 probe：

```text
若錯誤跟著模組或線材移動 -> 外部光路/模組高度可疑
若錯誤仍固定在 Slave      -> 繼續查 Slave RX polarity/lane/PCS/refclk
```

目前板上已恢復原始 A-port，未留下 loopback 診斷版。

### 18.22 SoftPLL DAC request counter 診斷

#### 實驗名稱

建立獨立的 `dac_diag` 診斷版本，觀察 WR Core 內部的兩組 SoftPLL（Software Phase-Locked Loop，軟體鎖相迴路）是否真的提出時鐘調整要求。這一版只作觀測，不把診斷訊號接到 QSFP、SI5340 或任何外部腳位。

#### 為了驗證什麼

目前原始設計的 `time_valid=0`、`pps_valid=0` 有兩種可能：

1. WRPC／PHY 尚未進入可以執行時間伺服的狀態，因此根本沒有產生調整要求。
2. SoftPLL 已經提出調整要求，但 DE5a top 沒有把調整資料送到實際可調的時鐘元件。

本實驗用計數器區分這兩種情況。

#### 改了什麼

在獨立目錄：

```text
/home/b10504072/04_White_Rabbit/week02/v01/dac_diag/
```

Master 與 Slave 各加入兩個 12-bit 計數器：

```text
sync_probe[51:40] = dac_hpll_load_p1_o 次數
sync_probe[63:52] = dac_dpll_load_p1_o 次數
```

並將診斷版 `xwr_core` 的 `dac_hpll_*`、`dac_dpll_*` 接到這些計數器。原始專案的兩組輸出仍然保留為 `open`，沒有被覆蓋。診斷版使用原始 `work_wrphy_full` PHY QIP 與原始 Master/Slave firmware MIF。

#### Quartus 17 compile 與燒錄結果

Slave 診斷版：

```text
Quartus Prime Full Compilation was successful. 0 errors, 267 warnings
Worst-case setup slack: -4.270 ns
Worst-case recovery slack: -3.015 ns
SOF SHA256: 8c4ec37661b3858c751cd8e8c94feb3fd1bd53122fea611884bcea22c8ab7a49
Programmer checksum: 0x308E4EEF
Configuration succeeded
```

Master 診斷版：

```text
Quartus Prime Full Compilation was successful. 0 errors, 267 warnings
Worst-case setup slack: -3.097 ns
Worst-case recovery slack: -2.679 ns
SOF SHA256: 8d8365b244d03112665f01b06c8f62f6155d660bbf3a65f57d906951013515d7
Programmer checksum: 0x308E9C68
Configuration succeeded
```

兩個診斷版都能 compile 與燒錄，但 timing report 仍有負 slack；因此這只能作為 bring-up 診斷版，不能宣稱已完成 timing closure。

#### pain terminal probe 結果

兩片都燒錄診斷版後，連續 6 次讀取結果如下：

```text
00:03:17  Master 0000004134BC82CF  Slave 000000C12F9A82C3
00:03:23  Master 00000061247082CF  Slave 000000492FEEA2C3
00:03:28  Master 0000006134BC82CF  Slave 000000C32F9A82C3
00:03:34  Master 0000006134BC82CF  Slave 000000C12F9A82C3
00:03:39  Master 000000C1245082CF  Slave 000000C12F9A82C3
00:03:45  Master 0000006134BC82CF  Slave 000000492FEEA2C3
```

每筆 probe 的最高 24 bits 都是 `0x000000`，因此：

```text
HPLL load request count = 0
DPLL load request count = 0
```

低 16-bit 也沒有形成兩片穩定的同步狀態：Master 多為 `82CF`，Slave 在 `82C3` 與 `A2C3` 間變化，仍沒有 `time_valid=1` 或 `pps_valid=1`。

#### 結果如何看

這次結果要分成兩個層次，不能過度推論：

1. **已證明目前不是「SoftPLL 正在大量調整，但調整量不夠」**。在這次觀測期間，SoftPLL 的 HPLL/DPLL load request 都是 0；也就是 WR 時間伺服尚未進入提出調整命令的階段。可能原因包括 firmware／WRPC 尚未完成啟動、link 尚未維持在可伺服狀態，或 SoftPLL 仍處於 reset/disable 狀態。
2. **`dac_*` 接 `open` 仍是確定存在的必要整合缺口**。即使之後 SoftPLL 開始產生 load request，現有 top 也沒有把 16-bit DAC data 與 load pulse 接到任何真正可以調整 `clk_ref_i` 或 DMTD 相關時鐘的硬體。因此現有設計最多是 static-clock PHY/packet bring-up，還不能稱為完整 WR time-synchronization node。

SI5340 目前由 FPGA 在開機時透過 I2C（Inter-Integrated Circuit，晶片間串列匯流排）固定設定輸出頻率；這不等於 WR runtime servo。SI5340 家族本身可以使用 DCO（Digitally Controlled Oscillator，數位控制振盪器）方式更新 MultiSynth，但仍需要確認 DE5a 實際料號、ClockBuilder 設定、哪個 output 回到 `QSFPA_REFCLK_p`、哪個 output 回到 `QSFPB_REFCLK_p`，以及把 WR DAC code 轉成 SI5340 可接受的 DCO register update。不能把 `dac_*_load` 直接接到任意 SI5340 腳位。

參考資料：

- WR Core `xwr_core` 與 SoftPLL DAC 介面：`https://gitlab.com/ohwr/project/wr-cores/-/blob/master/platform/altera/wr_arria10_phy.vhd`
- SI5340/41 datasheet（DCO 與 direct register update）：`https://www.digikey.com/htmldatasheets/production/1957969/0/0/1/si5340-si5341-datasheet.html`
- SI5340/41 family reference manual：`https://www.skyworksinc.com/-/media/SkyWorks/SL/documents/public/reference-manuals/Si5341-40-D-RM.pdf`

#### 復原結果

診斷完成後已恢復原始 SOF：

```text
Slave SHA256: e3e48c3bfc621639b10451fdddd51372ba4735f424e3be7bec5d6eac1e71bd1f
Slave checksum: 0x308CA816
Master SHA256: f661fd07d79ec287d47a409890c8a9ce2c8a7497a59c88d83f908ec4057ae6cf
Master checksum: 0x308CF8EF
```

恢復後 6 次 probe：

```text
00:04:52  Master ...82CF  Slave ...A2C3
00:04:57  Master ...82CF  Slave ...A2C3
00:05:03  Master ...82CF  Slave ...A2C3
00:05:08  Master ...82CF  Slave ...A2C3
00:05:14  Master ...82CF  Slave ...A2C3
00:05:20  Master ...82CF  Slave ...A2C3
```

因此目前硬體狀態已恢復到原始版本，沒有把診斷版留在板上。

#### 下一步

下一步應先完成兩件不破壞現況的確認：

1. 用 JTAG／WRPC 可觀測方式確認 `wrpc-sw` 確實啟動，並確認 WRPC mode、SoftPLL enable/state 與 link state；load counter 為 0 目前不能被解讀成「DAC 線路是唯一根因」。
2. 查 DE5a schematic/BOM，確認 SI5340 exact OPN 與 clock output topology。若 SI5340 DCO output 確實可透過 I2C 調整，先做單一 output 的固定正負 DCO step 實驗，以頻率計或示波器確認輸出頻率會依預期改變；若板上沒有可用的 DCO 控制路徑，則需要外接 SPI DAC + VCXO/VCSO，才能閉合完整 WR SoftPLL。

### 18.21 復原後外部 A-port link 的一分鐘重測

#### 實驗名稱

在完成 Slave loopback、恢復原始 Slave SOF 後，使用原始 Master/Slave A-port bitstream 連續取樣約一分鐘，確認外部光路是否能重現雙向 link。

#### 為了驗證什麼

前一個 loopback 實驗證明 Slave 本地 PHY 可以工作，但不能直接證明外部 A-A 光路已恢復。因此這次只觀察原始外部連線是否能穩定出現兩端 `82CF`，並區分「永久失敗」與「可重新訓練成功但不穩定」。

#### 改了什麼

沒有修改任何硬體或軟體；只把 Slave 從 loopback SOF 換回原始 `output_files_slave/DE5a_wr_slave.sof`。Master 維持原始 A-port SOF。

#### pain terminal 結果

恢復後先讀到：

```text
probe_hex: 000000E33FBC82CF
probe_hex: 000000C1225082CF
```

接著每約 5 秒取樣一次，共 12 次，低 16-bit 全部為雙 `82CF`：

```text
23:32:07  Master ...82CF  Slave ...82CF
23:32:13  Master ...82CF  Slave ...82CF
23:32:18  Master ...82CF  Slave ...82CF
23:32:24  Master ...82CF  Slave ...82CF
23:32:29  Master ...82CF  Slave ...82CF
23:32:35  Master ...82CF  Slave ...82CF
23:32:41  Master ...82CF  Slave ...82CF
23:32:46  Master ...82CF  Slave ...82CF
23:32:52  Master ...82CF  Slave ...82CF
23:32:57  Master ...82CF  Slave ...82CF
23:33:03  Master ...82CF  Slave ...82CF
23:33:09  Master ...82CF  Slave ...82CF
```

#### 結果如何看

這次可以把結論分成兩層：

1. **目前可重現一分鐘的雙向 WR link。** 兩片板都具備 `phy_ready=1`、`tx_ready=1`、`tm_link_up=1`、`link_ok=1`、`rx_enc_err=0`；這比先前的單次或三次雙 `82CF` 更有證據力。
2. **仍不能宣稱時間同步。** 所有低 16-bit 都是 `82CF`，其中 `time_valid=0`、`pps_valid=0`。目前只能報告「Ethernet/WR link layer 已建立」，不能報告「WR clock/time synchronization 已完成」。

此外，這個結果說明外部路徑不是每次都永久無法工作；它可能受到 transceiver retraining、reset/reprogram 順序、光模組狀態或外部線材接觸狀況影響。下一個最有辨識力的單一變因仍是交換一端 QSFP 光模組或 A-A 光纖，再用相同 12 次 probe 判斷錯誤是否跟著實體元件移動。

### 18.23 `sfp match` / `no-sfp-match` 初始化 A/B 實驗

#### 實驗名稱

比較 WRPC 啟動命令中保留 `sfp match` 與移除 `sfp match` 的差異，確認 SFP（Small Form-factor Pluggable）模組辨識／校正流程是否是 Slave 無法建立 WR link 的直接原因。

#### 為了驗證什麼

原始版本含有：

```text
vlan off;ptp stop;sfp match;mode master/slave;ptp start
```

這次只移除 `sfp match`，其餘 A-port、lane 0、125 MHz refclk、124.992 MHz DMTD（Digital Dual Mixer Time Difference）時脈、First Post-Tap=18 與 WR core 全部維持不變。若兩端 link 能穩定建立，表示模組 matching／校正流程可能阻礙啟動；若仍失敗，則應回到 PHY、光路或 reset/clock 診斷。

#### 改了什麼

建立獨立的 no-sfp-match firmware 與 SOF（SRAM Object File）版本，沒有覆蓋原始輸出：

- Master SOF：`output_files_master/DE5a_wr_master_before_nosfpmatch.sof`
- Slave SOF：`output_files_slave/DE5a_wr_slave_before_nosfpmatch.sof`
- Master SHA256：`d8143100c4ad80f4324edb8f7583f0dbc939b0d94bb1c78d498b5352c264b4cb`
- Slave SHA256：`5135c5453f41d100d226022ddd4a27cba953d7591707891c0e1385269adffb62`
- Quartus Programmer checksum：Master `0x308CF8EF`、Slave `0x308CA816`

#### pain terminal 結果

兩片 no-sfp-match SOF 燒錄成功，前六次在約 30 秒內都讀到雙邊 `82CF`：

```text
00:10:26  Master ...82CF  Slave ...82CF
00:10:31  Master ...82CF  Slave ...82CF
00:10:37  Master ...82CF  Slave ...82CF
00:10:43  Master ...82CF  Slave ...82CF
00:10:48  Master ...82CF  Slave ...82CF
00:10:54  Master ...82CF  Slave ...82CF
```

但是延長觀察約兩分鐘後，Slave 又回到 `A2C3` 或 `82C3`，Master 仍多為 `82CF`：

```text
00:23:23  Master ...82CF  Slave ...A2C3
00:23:33  Master ...82CF  Slave ...82C3
00:23:44  Master ...82CF  Slave ...A2C3
00:24:15  Master ...82CF  Slave ...A2C3
00:25:19  Master ...82CF  Slave ...A2C3
```

之後已重新燒錄原始含 `sfp match` 的 Master/Slave SOF。恢復後最新 probe 為：

```text
Master: 000000E134BC82CF
Slave : 0000004B2FEEA2C3
```

#### 結果如何看

1. 移除 `sfp match` 確實改善了「剛燒錄後立即取得雙邊 link」的機率，但兩分鐘後仍失去 Slave link，因此不能視為修正完成。
2. 這個結果比較像啟動／重新訓練時序或外部光路狀態受到影響，不足以證明 SFP database 是根因。
3. 即使短時間雙邊為 `82CF`，其低 16-bit 的 `time_valid=0`、`pps_valid=0` 仍表示尚未完成 White Rabbit 時間同步。
4. 目前最重要的硬體缺口仍然存在：`xwr_core` 的 `dac_hpll_*`、`dac_dpll_*` 調諧輸出在 top 內未接到可控制 SI5340 DCO（Digitally Controlled Oscillator，數位控制振盪器）或外部 DAC（Digital-to-Analog Converter，數位類比轉換器）的致動路徑。這是後續要完成時間伺服時必須處理的整合問題，但不能用它單獨解釋目前 Slave 的 `rx_enc_err`。

#### 後續判斷

目前已恢復原始 SOF，並保留 no-sfp-match SOF 作為可重現的 A/B 證據。下一個單一變因應優先交換一端 QSFP（Quad Small Form-factor Pluggable）模組或 A-A 光纖，觀察 `A2C3` 是否跟著實體元件移動；若錯誤固定在 Slave，才繼續查 Slave Arria 10 RX lane、polarity、bitslip、CDR（Clock Data Recovery）與 reset/refclk。只有兩端能穩定 `82CF` 後，才進入 SI5340 DCO／SoftPLL 閉環與 PPS（Pulse Per Second，每秒脈衝）同步驗證。

### 18.24 `dac_diag` CDR／PCS／SoftPLL telemetry 診斷

#### 實驗名稱

使用已編譯的 `dac_diag` 診斷版觀測 CDR（Clock Data Recovery，時脈資料回復）、PCS（Physical Coding Sublayer，實體編碼子層）與 SoftPLL DAC（Digital-to-Analog Converter，數位類比轉換器）請求；原始 Master/Slave SOF 保留不覆蓋。

#### 為了驗證什麼

這次要區分三件事：

1. Slave RX 是否有鎖到輸入訊號。
2. Slave 的 8b/10b（8-bit/10-bit line coding）解碼是否正常。
3. WR core 是否已進入會產生 SoftPLL 調諧請求的階段。

#### 改了什麼

沒有修改原始 WR 專案，也沒有更動 `QSFP_4PORT` 參考專案。使用既有診斷輸出：

- Master：`dac_diag/output_files_master_dac/DE5a_wr_master_dac.sof`
- Slave：`dac_diag/output_files_slave_dac/DE5a_wr_slave_dac.sof`
- Master SHA256：`8d8365b244d03112665f01b06c8f62f6155d660bbf3a65f57d906951013515d7`
- Slave SHA256：`8c4ec37661b3858c751cd8e8c94feb3fd1bd53122fea611884bcea22c8ab7a49`
- 兩端 QSF（Quartus Settings File）都已設定 `XCVR_A10_TX_PRE_EMP_SWITCHING_CTRL_1ST_POST_TAP 18`；因此附圖要求的 First Post-Tap=18 已實際套用，這次沒有重複修改。

#### pain terminal 結果

兩端診斷 SOF 都由 Quartus Prime 17 Programmer 成功燒錄，0 errors、0 warnings。現有 64-bit JTAG probe 的高位元定義為：

```text
bit32  rx_lockedtodata
bit33  rx_lockedtoref
bit34  rx_disperr
bit35  rx_errdetect
bit36  rx_syncstatus
bit37  rx_patterndetect
bit38  rx_patterndetect_ready
bit39  rx_runningdisp
bit40..51  HPLL load counter
bit52..63  DPLL load counter
```

在燒錄後立即、約 30 秒、約 120 秒讀取：

```text
time       Master probe          Slave probe
00:43:40   000000E3275082CF      000000CF2F77A2C3
00:44:11   00000063377082CF      000000CD2F37A2C3
00:45:41   000000C137BC82CF      000000CD2F77A2C3
```

低 16-bit 在三次都維持：

```text
Master = 82CF
Slave  = A2C3
```

恢復原始 SOF 後，重新確認：

```text
Master = 0000006134BC82CF
Slave  = 000000492F20A2C3
```

#### 結果如何看

1. Master 的高位 `0xE3` 表示 RX data/ref lock 與 pattern-ready 穩定，沒有 `disperr` 或 `errdetect`。
2. Slave 的高位 `0xCF` 表示 RX 也鎖到 data/ref，但 `disperr=1`、`errdetect=1`，且 pattern detect 沒有成立。這是「收到訊號但 PCS 解碼不正確」，不是完全沒有光訊號。
3. 兩端 HPLL/DPLL load counter 在 0、30、120 秒都沒有增加，表示目前尚未看到 WR SoftPLL 發出 DAC 調諧請求；因此不能宣稱 WR 時間伺服已啟動。
4. `First Post-Tap=18` 已經確認存在，但沒有消除 Slave 的解碼錯誤，所以目前不應再把 pre-emphasis 當成主要未知變因。
5. 原始 bitstream 已恢復，診斷實驗沒有改變正式版本。現階段最合理的判斷是：主要問題仍在 Slave RX 的 lane/polarity/PCS/reset/refclk 或外部光路；時間同步另外還有 SoftPLL DAC 致動路徑未閉合的必要缺口。

#### 後續判斷

下一個最小單一變因是保留現有正式 bitstream，先只交換一端 QSFP 模組；若錯誤不跟著模組移動，再只交換 A-A 光纖。若外部交換後仍固定為 Slave `A2C3`，就回到 Slave generated PHY 的 polarity、bitslip、CDR reset 與 refclk 設定。即使未來兩端都得到 `82CF`，也只能表示 link layer 成立；要宣稱 WR 時間同步，仍必須看到 `time_valid=1`、`pps_valid=1`，並以兩端 PPS（Pulse Per Second，每秒脈衝）量測確認。

### 18.25 DCO I²C step 診斷版：First Post-Tap=18 後的實體驗證

#### 實驗名稱

在保留原始正式版本的前提下，編譯並短時間燒錄 DCO（Digitally Controlled Oscillator，數位控制振盪器）診斷版，測試新增的 SI5340 I²C（Inter-Integrated Circuit）微調路徑是否能讓 WR SoftPLL（Software Phase-Locked Loop，軟體鎖相迴路）送出 DCO step，並觀察 First Post-Tap=18 是否能改善 Slave 的 PCS 解碼錯誤。

#### 為了驗證什麼

這次要驗證：

1. 新增的 I²C bus enable 與 DCO step command 是否能被 Quartus 正確編譯與實作。
2. WR core 的 DPLL/HPLL DAC load 是否會觸發 DCO step counter。
3. DCO 修改是否能讓 Slave 從 `A2C3`（RX encoding error）恢復成 link up，並進一步得到 `time_valid`、`pps_valid`。

#### 改了什麼

所有修改都放在隔離目錄 `/home/b10504072/04_White_Rabbit/week02/v01/dco_diag/`，沒有覆蓋正式專案，也沒有修改唯讀參考 `/home/b10504072/02_QSFP/week03/QSFP_4PORT/`：

- 修正 `i2c_bus_controller_dco.v` 的 port list 與模組名稱，使 wrapper 能正確找到它。
- 保留原本 SI5340 靜態設定，加入 N0/N1 FSTEPW（frequency-step word，頻率步進字）與 FINC/FDEC（frequency increment/decrement，頻率增加/減少）命令控制。
- 將 WR core 的 DPLL/HPLL load/data 接到 DCO wrapper，並增加 DCO busy/error/step counter 的 JTAG probe 位元。
- 兩端 QSF 的 Transmitter Pre-Emphasis First Post-Tap Magnitude 均維持為 18；這個設定已由先前的 fitter 結果確認為 `0x12`。

#### 編譯與燒錄證據

使用的工具是 `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/` 內的 Quartus Prime 17：

```text
Master DCO: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Slave  DCO: Quartus Prime Full Compilation was successful. 0 errors, 265 warnings
Slave DCO programming: Configuration succeeded, checksum 0x308CB490
Master DCO programming: Configuration succeeded, checksum 0x308E9E6A
```

TimeQuest 仍報告原設計類型的未完全約束與負 slack；因此「compile successful」只代表工具完成，不代表時序已經完全可靠。

#### pain terminal 結果

DCO 版燒錄後，連續 6 次透過 JTAG 讀取 `probe_hex`：

```text
time       Master probe          Slave probe
01:12:07   000000C3215482CF      000000492FEEA2C3
01:12:18   000000E331BC82CF      000000C12F9A82C3
01:12:28   00000041215082CF      000000412FFE82C3
01:12:39   00000041215082CF      000000C12F9A82C3
01:12:49   00000043215082CF      000000492FEEA2C3
01:13:00   00000041215082CF      000000C32F9A82C3
```

低 16-bit 的意義仍是：

```text
Master = 82CF: tm_link_up=1, link_ok=1, time_valid=0, pps_valid=0, rx_enc_err=0
Slave  = 82C3: tm_link_up=0, link_ok=0, time_valid=0, pps_valid=0, rx_enc_err=0
Slave  = A2C3: tm_link_up=0, link_ok=0, time_valid=0, pps_valid=0, rx_enc_err=1
```

新增 DCO counter 位元在所有讀值都為 0；也就是沒有證據顯示 WR core 的 DAC load 已經轉成實際 DCO step。最後已恢復正式 SOF：

```text
Slave original programming: Configuration succeeded, checksum 0x308CA816
Master original programming: Configuration succeeded, checksum 0x308CF8EF
After restore: Master 000000E337BC82CF, Slave 000000CD2F77A2C3
```

#### 結果如何看

這次實驗的結論是：

1. DCO 診斷版可以完整編譯與燒錄，說明新增 Verilog/I²C 介面在工具層面沒有錯誤。
2. 但 DCO step counter 為 0，且 Slave 的 `A2C3/82C3` 狀態沒有改善；因此不能說 DCO 校正已經生效。
3. First Post-Tap=18 仍然沒有解決 Slave 單向 8b/10b 解碼錯誤，問題優先順序應回到 Slave RX 的 lane mapping、polarity、bitslip、CDR reset/refclk 或外部 QSFP 光路。
4. 兩端 `time_valid=0`、`pps_valid=0`，所以本次沒有達到 White Rabbit 時間同步，也沒有理由使用示波器宣稱 PPS 已同步。
5. 原始 SOF 已恢復；本次診斷不會影響後續正式測試。

#### 下一步

下一個最有效且不改 RTL 的步驟，是只交換一端 QSFP 模組，再重複相同 probe；若錯誤不跟著模組移動，再只交換 A-A 光纖。若錯誤始終固定在 Slave，才繼續對 Slave generated PHY 做 CDR lock、word/comma alignment、polarity 與 reset 時序的單一變因測試。只有兩端先穩定 link layer，才值得再處理 SI5340 DCO 閉環與 PPS 驗證。

### 18.26 正式 SOF 的 0/30/120 秒 PHY telemetry 觀測

#### 實驗名稱

正式版本 0/30/120 秒 PHY（Physical Layer，實體層）狀態觀測。

#### 為了驗證什麼

確認 Slave 的錯誤是否只是開機後尚未完成 CDR（Clock Data Recovery，時脈資料恢復）或 PCS（Physical Coding Sublayer，實體編碼子層）初始化，還是會在等待後固定維持；同時確認 bitslip、8b/10b 解碼錯誤與現有 WR link 狀態的關係。

#### 改了什麼

沒有修改 RTL、QSF、firmware、SOF 或唯讀參考專案。直接使用已恢復的正式 SOF 與既有 `altsource_probe` telemetry：

```text
bit32  rx_lockedtodata
bit33  rx_lockedtoref
bit34  rx_disperr
bit35  rx_errdetect
bit36  rx_syncstatus
bit37  rx_patterndetect
bit38  rx_patterndetect_ready
bit39  rx_runningdisp
bit24..27  rx_bitslide
```

附圖要求的 `Transmitter Pre-Emphasis First Post-Tap Magnitude=18` 也再次核對為正式兩份 QSF 的既有設定；這次沒有重複改動。

#### 結果與 pain terminal log

使用 Quartus Prime 17.0 Build 595 的 `quartus_stp`，在燒錄後約 0、30、120 秒各讀一次：

```text
time       Master probe          Slave probe
01:56:07   0000006330BC82CF      000000C92F05A2C3
01:56:37   000000C1205082CF      0000004D2FFFA2C3
01:58:08   0000006330BC82CF      0000004D2FFFA2C3
```

三個時間點的低 16-bit 都是：

```text
Master = 82CF
Slave  = A2C3
```

主要觀察：

- Master 保持 `tm_link_up=1`、`link_ok=1`、`rx_enc_err=0`。
- Slave 保持 `tm_link_up=0`、`link_ok=0`、`rx_enc_err=1`。
- Slave 的 `rx_lockedtodata` 仍為 1，但 bitslip / RX 資料欄位會變動；這表示「有收到並鎖到資料」，卻沒有穩定完成正確的 PCS 解碼與對齊。
- 120 秒後仍未變成有效 link，因此不是單純等待較久即可恢復。

#### 怎麼看待這個結果

這次結果把「開機初始化尚未完成」的可能性大幅降低，問題更集中在 Slave 的 RX lane、polarity、word alignment/bitslip、PCS reset/refclk，或 Slave 所在的外部 QSFP 接收路徑。`First Post-Tap=18` 已正確存在但沒有清除 `rx_enc_err`，因此不應再盲目調整同一個 TX 參數。

這次仍不能宣稱 White Rabbit 時間同步成功：兩端都尚未達到 `time_valid=1`、`pps_valid=1`，而且正式 top 的 `dac_hpll_*`/`dac_dpll_*` 輸出目前仍未接到實際可調時鐘致動器。

#### 下一步

依照兩個輔導工作聊天的共識，下一個單一變因應先保持正式 SOF 不變，取得更完整的 Slave PHY reset/CDR/bitslip 狀態；若確認本地 PHY 狀態穩定而錯誤仍固定，再只交換 QSFP 模組，之後才只交換 A-A 光纖。未取得 schematic/BOM（Bill of Materials，材料清單）前，不應宣稱已確認是光模組、光纖或 FPGA PHY 的唯一故障。

### 18.27 `simple-WA` 對照實驗：隔離複雜 word-alignment watchdog

#### 實驗名稱

`simple-WA`（簡化 word alignment，簡化字組對齊）與正式複雜 word-alignment 路徑的 A/B 對照。

#### 為了驗證什麼

驗證 Slave 的 `rx_enc_err=1` 是否主要由 WR Arria 10 PHY wrapper 內的複雜對齊 watchdog／重新掃描流程造成，而不是先假設光模組或 First Post-Tap 參數故障。

#### 改了什麼

只在隔離目錄 `/home/b10504072/04_White_Rabbit/week02/v01/simplewa_diag/` 將 Master/Slave 的 WR transceiver generic 設成 `g_use_simple_wa => true`；沒有覆蓋正式 top、QSF、firmware，也沒有修改唯讀的 `QSFP_4PORT`。

#### 編譯、燒錄與 pain terminal log

Quartus Prime 17 Full Compilation：

```text
Master: 0 errors / 264 warnings
Slave : 0 errors / 264 warnings
```

Programming checksum：

```text
Slave simple-WA: 0x308D8A33
Master simple-WA: 0x3091BF0E
```

燒錄後 6 次 JTAG probe：

```text
time       Master probe          Slave probe
01:33:55   0000006139BC82CF      000000E131BC82CF
01:34:05   0000006139BC82CF      00000041215082CF
01:34:16   0000006139BC82CF      000000E131BC82CF
01:34:27   0000006139BC82CF      00000041215082CF
01:34:37   000000C1295082CF      000000E331BC82CF
01:34:48   000000E329D082CF      0000006321F882CF
```

#### 結果與解讀

兩端低 16-bit 在 6 次都為 `82CF`，也就是 Slave 的 `rx_enc_err` 清除，`tm_link_up` 與 `link_ok` 成立。這是很強的排除性證據：複雜 alignment 路徑是目前 link failure 的主要嫌疑，`First Post-Tap=18` 並不是唯一關鍵。

但兩端 `time_valid=0`、`pps_valid=0`，因此這只能宣稱「PHY/PCS link 對照改善」，不能宣稱 White Rabbit 時間同步完成。正式版本仍已恢復。

### 18.28 `simple-WA + DCO` 合併實驗：分離 link 與時間伺服問題

#### 實驗名稱

`simple-WA + DCO` 合併診斷，確認 link 修正與 SI5340 DCO（Digitally Controlled Oscillator，數位控制振盪器）致動是否為兩個獨立問題。

#### 為了驗證什麼

在已知 `simple-WA` 能讓兩端 link 成立的條件下，檢查 WR core 是否真的產生 HPLL/DPLL DAC load，並確認 DCO counter 是否增加、`time_valid/pps_valid` 是否出現。

#### 改了什麼

使用隔離目錄 `/home/b10504072/04_White_Rabbit/week02/v01/dco_simplewa_diag/`，同時保留 `g_use_simple_wa => true` 與 DCO I²C wrapper；正式版本、正式 SOF、唯讀參考專案都沒有被覆蓋。

#### 編譯、燒錄與 pain terminal log

```text
Master: 0 errors / 264 warnings
Slave : 0 errors / 264 warnings
Slave programming: 0x3087D91E
Master programming: 0x309046D4
```

6 次 probe 的低 16-bit 均為 `82CF`，例如：

```text
01:49:42 Master 00000061295082CF Slave 000000C3245082CF
01:49:53 Master 000000E139BC82CF Slave 000000C1245082CF
01:50:04 Master 000000E339BC82CF Slave 0000006334BC82CF
01:50:14 Master 000000E339BC82CF Slave 0000006134B882CF
01:50:25 Master 000000E139BC82CF Slave 00000061349C82CF
01:50:36 Master 00000043295482CF Slave 0000006334BC82CF
```

新增 HPLL/DPLL step counter 仍為 0，`time_valid=0`、`pps_valid=0`。

#### 結果與解讀

`simple-WA` 確實能讓 link layer 穩定，但 DCO counter 不動，表示「PHY/PCS link」和「WR SoftPLL 時間伺服」是兩個分開的問題。正式 top 仍把 `dac_hpll_load_p1_o`、`dac_hpll_data_o`、`dac_dpll_load_p1_o`、`dac_dpll_data_o` 接成 `open`，而 SI5340 只有開機靜態設定；因此目前不能宣稱完整 WR PTP node 或已完成時間同步。測試結束後已恢復正式 SOF。

#### 後續決策

下一個正式修正應先以 `simple-WA` 作為 link baseline，再確認 `wrpc-sw` firmware 的 SoftPLL enable/state，並依 DE5a schematic/BOM 確認 SI5340 哪個輸出可以接受 DCO 更新。若沒有可控 DCO 路徑，最小可行硬體方案是補上與 VCXO/VCSO 相容的 DAC 控制器；在此之前不應只靠靜態 125 MHz/124.992 MHz 時鐘宣稱 WR 已同步。

### 18.29 `nosfpmatch` 與 firmware 路徑修正：確認 WRPC 是否真的載入

#### 實驗名稱

WRPC firmware（White Rabbit Processor Core 軟體）MIF（Memory Initialization File，記憶體初始化檔）路徑驗證，以及 `sfp match` 啟動命令的 A/B 實驗。

#### 為了驗證什麼

前面的低 16-bit probe 一直是 `82CF`，表示 PHY/PCS（Physical Coding Sublayer，實體編碼子層）link 可以成立；但 `time_valid=0`、`pps_valid=0`，且看不到 DCO（Digitally Controlled Oscillator，數位控制振盪器）更新。這次要先排除一個更底層的可能性：FPGA 內的 RISC-V WRPC CPU 是否根本沒有載入 firmware。

#### 改了什麼

先建立隔離目錄，不覆蓋正式版本：

```text
/home/b10504072/04_White_Rabbit/week02/v01/dco_simplewa_nosfp_diag/
/home/b10504072/04_White_Rabbit/week02/v01/dco_simplewa_nosfp_loadprobe_diag/
/home/b10504072/04_White_Rabbit/week02/v01/dco_simplewa_loadprobe_fwfix_diag/
```

第一個 no-SFP 版本只把啟動命令從：

```text
vlan off;ptp stop;sfp match;mode master/slave;ptp start
```

改成：

```text
vlan off;ptp stop;mode master/slave;ptp start
```

之後在 load-probe 版本把 MIF 路徑由：

```text
firmware/wrc_de5a_*.mif
```

修正為：

```text
../firmware/wrc_de5a_*.mif
```

這個子目錄關係很重要，因為 Quartus project 在 `dco_simplewa_*_diag/`，firmware 實際位於上一層 `v01/firmware/`。另外，JTAG probe 的 bits 40..63 改成直接計算 WR core 發出的 HPLL/DPLL DAC load 次數，而不是只看 SI5340 transaction step counter。

#### 編譯、燒錄與 pain terminal log

錯誤路徑版本雖然 compile 成功，但 map report 明確顯示：

```text
Critical Warning (127003): Can't find Memory Initialization File
firmware/wrc_de5a_master_nosfpmatch.mif
setting all initial values to 0
```

因此該版本不能當作 firmware runtime 證據；它只證明硬體 link 還能起來。

修正 MIF 路徑後，`nosfpmatch` load-probe 版本：

```text
Master: 0 errors / 265 warnings
Slave : 0 errors / 265 warnings
MIF missing warnings: none
Master SOF SHA-256: 1fecaf2ec5305ec95244c9b72b34c7aa2184185af783723369384a7ca8bd83c7
Slave  SOF SHA-256: ed1a5f0533d9c7758979e4384b61d0d30af24ee590b44c8cb379574d87f58fe9
```

燒錄結果：

```text
Slave : Configuration succeeded, checksum 0x30909D3A
Master: Configuration succeeded, checksum 0x308D7701
```

等待約 80 秒後的 probe 仍為：

```text
02:59:32  Master 0000006137BC82CF  Slave 000000C1215082CF
03:00:46  Master 0000006327FC82CF  Slave 00000043319482CF
```

其中低 16-bit 仍是兩端 `82CF`，bits 40..63 的 raw DAC load counters 仍為 0。

接著使用標準 `sfp match` firmware，但同樣修正 MIF 路徑的 A/B 版本：

```text
Master: 0 errors / 265 warnings
Slave : 0 errors / 265 warnings
MIF missing warnings: none
Master SOF SHA-256: 1e5530853627217bdd900ac23e72c8cb482378256fe7ca4f9098c2b765e27269
Slave  SOF SHA-256: 7b5c92e4358645e36a55c8452790413269a7d153239254e09e1b583cfb6c28c7
```

燒錄結果同樣成功：

```text
Slave : Configuration succeeded, checksum 0x30909D3A
Master: Configuration succeeded, checksum 0x308D7701
```

03:09:29 到 03:11:26 連續 12 次 probe 中，低 16-bit 仍為 `82CF`，`time_valid/pps_valid` 仍為 0，raw DAC load counters 仍為 0。

#### 結果與解讀

這次實驗得到兩個重要結論：

1. 之前的 no-SFP 結果不能直接解讀成 WRPC 行為，因為 MIF 路徑錯誤使 CPU RAM 被 Quartus 置零；現在已由 map report 證實並修正。
2. 在 MIF 路徑修正、firmware 確實被納入 FPGA RAM 後，標準與 no-SFP 啟動方式仍沒有讓 `time_valid` 或 DAC load 出現。因此目前問題已不是單純「忘了載入 firmware」，也不能再只歸咎於 `sfp match`。

目前最可靠的描述仍是：

```text
PHY/PCS link：成立（兩端 82CF）
WRPC firmware：已確認納入 RAM，但 runtime synchronization 尚未證實
PTP/SoftPLL：尚未進入有效同步狀態（time_valid=0、pps_valid=0、DAC load=0）
```

這仍不能宣稱 White Rabbit 時間同步成功；下一步需要直接觀察 WRPC CPU/UART activity、PTP frame activity，以及 SoftPLL lock/state，才能繼續區分「CPU 沒有執行」、「PTP 封包沒有進入 endpoint」與「SI5340 DCO 控制路徑沒有實際致動」。

### 18.30 SFP I²C SCL open-drain A/B：確認 SCL 電氣方向是否阻塞 EEPROM

#### 實驗名稱

SFP I²C（Inter-Integrated Circuit，內部整合電路）SCL（Serial Clock，串列時鐘）open-drain（開漏）修正與 WR runtime probe A/B 實驗。

#### 為了驗證什麼

上一版 top-level 將 `QSFPA_SDA` 做成 open-drain loopback，但 `QSFPA_SCL` 是 `out std_logic`，而 `sfp_scl_i` 固定為 `'1'`。這可能使 WRPC 讀不到 SFP EEPROM（Electrically Erasable Programmable Read-Only Memory，可電氣抹除可程式唯讀記憶體）的實際 SCL 回授，也無法處理 I²C clock stretching。這次只改 SCL 的電氣介面，驗證 SFP I²C activity 是否恢復。

#### 改了什麼

建立獨立診斷分支，不覆蓋原本的 `runtime_probe_diag`：

```text
/home/b10504072/04_White_Rabbit/week02/v01/sfp_i2c_fix_diag/
```

Master 與 Slave 的 top-level 都只做以下修改：

```vhdl
QSFPA_SCL : inout std_logic;

QSFPA_SCL <= '0' when sfp_scl_o = '0' else 'Z';
sfp_scl_i <= QSFPA_SCL;
```

並刪除原先的：

```vhdl
sfp_scl_i <= '1';
QSFPA_SCL <= sfp_scl_o;
```

這符合 WR reference top 對 SFP I²C 的處理方式：FPGA 只主動拉低，邏輯 1 由外部 pull-up（上拉電阻）形成，且輸入端讀回實際線路狀態。

#### 編譯、燒錄與 pain terminal log

使用指定的 Quartus 17：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 260 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 260 warnings
MIF missing warnings: none
```

產生的 SOF（SRAM Object File，FPGA 燒錄檔）雜湊如下：

```text
Master: c99ab6d2ef56d34326a973da89a5a24ab54d35905a96d0182a5cc591c22e8698
Slave : f3f2b2fd471b72d5deb6c6c8330b75aaed76c60d05002c2fc1b0d8e49e4d72bb
```

燒錄成功：

```text
Slave : Configuration succeeded, checksum 0x30877B91
Master: Configuration succeeded, checksum 0x308FAA52
```

燒錄後 probe：

```text
03:52:30  Master 000102C1243882CF  Slave 000102E330BC82CF
03:52:51  Master 000102C324B882CF  Slave 0001036120D082CF
```

這個 probe 的欄位是：低 16-bit 為 WR link/status，bits 47..40 為 UART transition count，bits 55..48 為 SFP SCL output transition count，bits 59..56/63..60 為 DPLL/HPLL raw DAC load count 的低 4 bits。

解碼後：

```text
兩端低 16-bit：0x82CF
兩端 time_valid：0
兩端 pps_valid：0
Master/Slave SFP SCL count：約 0x01/0x01
兩端 raw DPLL/HPLL DAC load：0
```

#### 結果與解讀

這個最小修正已通過 compile 與 programming，但 SCL transition 沒有明顯增加，`time_valid`、`pps_valid` 與 SoftPLL DAC load 仍為 0。因此可以得到的結論是：

1. SCL push-pull/固定輸入確實是電氣上不正確的寫法，已修正為符合 I²C 的 open-drain loopback。
2. 這個修正沒有單獨解決目前的 WR synchronization 問題；SCL 幾乎沒有活動，表示 runtime 很可能尚未進入完整 SFP EEPROM transaction，或 DE5a 的 SFP management path、presence、pull-up、pin mapping 仍有問題。
3. `0x82CF` 仍只能表示 PHY/PCS link 已起來，不能表示 PTP（Precision Time Protocol，精確時間協定）已同步。

下一個最有效的診斷順序應是：

```text
SFP module-present / interrupt / LOS
    -> WRPC 是否真的啟動 sfp match 與 EEPROM ACK
    -> PTP TX/RX frame activity
    -> SoftPLL load/state 與 SI5340 DCO
```

在取得 `time_valid=1`、`pps_valid=1`，以及兩端 PPS（Pulse Per Second，每秒脈波）輸出經獨立量測確認之前，不能宣稱 White Rabbit time synchronization 已完成。

### 18.31 QSFP EEPROM 與 `nosfpmatch` A/B 診斷（2026-08-15）

#### 實驗 1：直接讀取 QSFP EEPROM

**目的**：確認 QSFP-A 的管理介面（I²C，Inter-Integrated Circuit，兩線式序列匯流排）是否真的能讀到模組，而不是把 WRPC 沒有產生 SCL 活動誤判成光模組損壞。

**修改內容**：在獨立的 `sfp_eeprom_diag` 分支加入一次性 EEPROM reader，只讀取 QSFP EEPROM 位址 `0x50` 的前 8 bytes；不改動原本 WR bitstream。讀取完成後立即恢復 `sfp_i2c_fix_diag`。

**pain terminal 證據**：

```text
=== DE5 [1-11.1] ===
probe_hex: 07DA00000004000D
=== DE5 [1-11.2] ===
probe_hex: 07DA00000004000D
```

解碼結果：

```text
EEPROM byte 0 = 0x0D       QSFP+ identifier
EEPROM byte 2 = 0x04
ACK error      = 0
module present = yes
SCL/SDA idle   = high
CPU reset      = released
```

**結果**：兩片板都能讀到 `0x0D`，所以 QSFP 模組存在，I²C 線路至少可以完成讀取交易。這排除了「QSFP 完全沒有回應」這個假設，但不代表 WRPC 的 SFP 校正流程可以直接使用這份資料。

#### 實驗 2：使用 `nosfpmatch` firmware

**目的**：驗證目前同步失敗是否只由 WRPC 的 SFP 自動辨識/校正流程造成。

**修改內容**：使用專案既有的 `dco_simplewa_nosfp_diag` SOF，該版本使用 `wrc_de5a_master_nosfpmatch.mif` 與 `wrc_de5a_slave_nosfpmatch.mif`，跳過開機時的 `sfp match`。沒有修改正式的 `sfp_i2c_fix_diag` 檔案。

**燒錄證據**：

```text
Slave: Configuration succeeded, checksum 0x308F8D1A
Master: Configuration succeeded, checksum 0x308E88C2
```

等待 10 秒後讀取：

```text
Master probe_hex: 000000C3235082CF
Slave  probe_hex: 000000832F1B82C3
```

低 16-bit 解碼：

```text
Master: 0x82CF -> link_up=1, link_ok=1, time_valid=0, pps_valid=0
Slave : 0x82C3 -> link_up=0, link_ok=0, time_valid=0, pps_valid=0
```

**結果與判讀**：跳過 `sfp match` 沒有讓同步成功，反而使 Slave 的 WR link 狀態下降。因此不能把 `nosfpmatch` 當成解法，也不能只靠「先不校正」宣稱時間同步。這個結果支持下一步必須同時處理「模組格式/校正資料」與「WR link/firmware 啟動流程」，而不是只刪除 SFP match。

#### 實驗 3：恢復正式診斷基準

**修改內容**：重新燒錄 `sfp_i2c_fix_diag` 的 Slave/Master SOF，確認診斷版不留在板上。

**燒錄證據**：

```text
Slave: Configuration succeeded, checksum 0x30877B91
Master: Configuration succeeded, checksum 0x308FAA52
```

恢復後等待 5 秒讀取：

```text
Master probe_hex: 00010241375082CF
Slave  probe_hex: 00010241285082CF
```

兩端目前都是：

```text
low16 = 0x82CF
link_up = 1
link_ok = 1
time_valid = 0
pps_valid = 0
```

**目前結論**：

1. 四條 QSFP+ 實體線已接上，但此 WR core 架構仍只使用 QSFP-A lane 0 作資料鏈路，QSFP-B 只提供 DMTD（Digital Dual Mixer Time Difference，數位雙混頻時間差）參考時鐘；Port C/D 並未接入目前的 WR core。
2. QSFP EEPROM 的 I²C 讀取成功，但讀到的是 QSFP+ 格式；WRPC 的 `sfp.c` 會按照 SFP（Small Form-factor Pluggable，小型可插拔收發器）格式讀取並檢查 SFP checksum，因此「EEPROM 可讀」不等於「WRPC 已取得有效校正資料」。
3. 目前最可靠的硬體/軟體診斷證據仍是 `0x82CF` 加上無 encoding error；它只表示 PHY/PCS（Physical Coding Sublayer，實體編碼子層）鏈路已起來，不能表示 PTP（Precision Time Protocol，精確時間協定）已鎖定。
4. 目前尚未取得 `time_valid=1`、`pps_valid=1` 或 WRPC `stat` 的 `lock:1` 證據，也尚未用示波器比較兩片 `SMA_CLKOUT` 的 PPS 上升緣，因此同步尚未完成。

官方校正文件指出，WR PTP Core 需要使用 SFP database 中的 `deltaTx`、`deltaRx` 與 `alpha` 校正值；這些值可透過 WRPC shell 的 `sfp add` 寫入。參考：[White Rabbit calibration](https://gitlab.com/ohwr/project/white-rabbit/-/wikis/calibration/diff?version_id=95a3dc2360c331014d0f69f9298f9d3798f431f4)。WRPC 的 runtime 狀態與 `stat` 判定方式參考：[WRPC User Manual](https://gitlab.com/ohwr/project/wrpc-sw/-/raw/master/doc/wrpc.tex)。

#### 追加診斷：讀取 QSFP vendor-name 區段

為了辨識模組型號，把隔離診斷版的 EEPROM offset 改為 `0x14`，使用指定的 Quartus 17 編譯：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 261 warnings
```

暫時燒錄到 Master 的 checksum 為 `0x308B727F`；讀取結果如下：

```text
Master probe_hex: 07DA000000000000
EEPROM offset 0x14..0x1B: 00 00 00 00 00 00 00 00
ACK error: 0
```

讀取完成後已重新燒錄正式 Master SOF，checksum `0x308FAA52`；恢復後兩端再次為：

```text
Master probe_hex: 00010241285082CF
Slave  probe_hex: 0001026132BC82CF
```

這個追加診斷只證明指定 offset 的讀取交易沒有回傳可用的 vendor-name 文字，不能單獨判斷模組故障，因為目前使用的是自製 reader，且 QSFP+ 的 page/address map 不應直接假設等同於 SFP。後續若要把 WRPC firmware 改成支援這類 QSFP+ 模組，仍需先取得模組的實際料號、光纖兩方向波長，以及經量測的 `deltaTx`、`deltaRx`、`alpha`；不能用全 0 或猜測值宣稱已完成校正。
### 18.32 四條 QSFP+ 線連接後的雙板 WR 基準實測（2026-08-15）

#### 實驗目的

兩台 DE5a 已完成 QSFP+ PortA-A、PortB-B、PortC-C、PortD-D 的實體連接。本實驗確認四條線都接上的情況下，現有 WR gateware 的 link 與時間同步狀態，並保存可重現的燒錄與 JTAG（Joint Test Action Group，聯合測試行動小組）讀值。

#### 目前設計實際使用的連接

目前正式 top 不是四埠 WR bonding：

```text
QSFP-A lane 0      WR 1GbE 資料鏈路
QSFP-B REFCLK      DMTD 參考時鐘
QSFP-B/C/D data    沒有接入 xwr_core
QSFP-C/D REFCLK    沒有接入 xwr_core
```

四條線接上不會自動變成四條同步鏈路；目前同步實驗的有效資料路徑仍只有 QSFP-A lane 0。Port C/D 保持未使用是 gateware 設計結果。

#### 實驗 1：根目錄舊 SOF 的 A/B 燒錄檢查

**目的**：確認專案根目錄的 `output_files_master/DE5a_wr_master.sof` 與 `output_files_slave/DE5a_wr_slave.sof` 是否等同於前面已驗證的診斷基準。

**燒錄結果**：兩片都顯示 `Configuration succeeded`，但 checksum 為：

```text
Master checksum: 0x308CF8EF
Slave  checksum: 0x308CA816
```

連續 6 次讀取低 16-bit 都是 `0xA2C3`，也就是 `rx_enc_err=1`、`tm_link_up=0`、`link_ok=0`、`time_valid=0`、`pps_valid=0`。根目錄 SOF 不是目前可用的 WR 基準；只看 Programmer 成功訊息會誤判，JTAG 狀態才顯示實際 link down。

#### 實驗 2：恢復已驗證的 `sfp_i2c_fix_diag` 基準

**目的**：把兩片板恢復到先前已確認可建立 PHY/link 的版本，再做同步判定。

**燒錄結果**：

```text
Master: Configuration succeeded, checksum 0x308FAA52
Slave : Configuration succeeded, checksum 0x30877B91
```

恢復後連續 3 次讀取：

```text
Sample 1: Master 000102E323F882CF, Slave 000102E133BC82CF
Sample 2: Master 00010243235082CF, Slave 00010241235082CF
Sample 3: Master 00010241235082CF, Slave 00010243235082CF
```

三次低 16-bit 都是 `0x82CF`：

```text
si_config_done = 1    phy_ready  = 1    tm_link_up = 1
link_ok        = 1    time_valid = 0    pps_valid  = 0
rx_ready       = 1    tx_ready   = 1    rx_enc_err = 0
tx_enc_err     = 0
```

目前已恢復到可工作的 PHY/PCS link，但仍不能宣稱 WR 時間同步成功，因為 `time_valid` 和 `pps_valid` 都是 0。

#### VUART / WRPC CLI 檢查結果

目前 top 雖然設定 `g_virtual_uart => true`，但 `xwr_core` 的 `wb_slave_i` 沒有接到主機 Wishbone（共享匯流排）或 PCIe（Peripheral Component Interconnect Express，周邊元件高速互連）介面；`g_phys_uart => false`，且 `uart_txd_o => open`。因此現階段不能直接從 pain 的 SSH session 執行 `wrc# stat`，`wrpc-vuart` 也沒有可用的硬體資源入口。這是目前設計缺少 WRPC runtime 觀測介面的限制，不是同步成功或失敗的證據。

#### 本次實驗結論

1. 四條 QSFP+ 線已連接，但目前 gateware 只使用 A lane 0 與 B 參考時鐘；C/D 不會自動參與 WR 同步。
2. 根目錄舊 SOF 雖然燒錄成功，實際狀態是 `0xA2C3`，已恢復且確認不是目前基準。
3. 保存的 `sfp_i2c_fix_diag` 恢復版可穩定得到 `0x82CF`，證明 PHY/link 層可工作。
4. 目前仍缺少 `time_valid=1`、`pps_valid=1`、WRPC `stat` 中 `lock:1` 與 Slave 的 `TRACK_PHASE` 證據，所以 WR 時間同步尚未完成。
5. 下一步優先順序是：先提供 WRPC CLI/runtime 觀測入口，再確認 QSFP identifier `0x0D` 是否有對應校正資料；若沒有，必須取得模組料號與實測 `deltaTx`、`deltaRx`、`alpha`，不能用猜測值替代。

官方 WRPC 手冊說明 `sfp match` 會載入校正資料，Slave 需要先完成 t24p phase transition calibration；`stat` 應至少看到 `lnk:1`、`lock:1` 與 `ptp:slave`，最後仍要用等長示波器線比較兩端 1-PPS。參考：[WRPC User Manual](https://gitlab.com/ohwr/project/wrpc-sw/-/raw/master/doc/wrpc.tex)、[White Rabbit calibration](https://gitlab.com/ohwr/project/white-rabbit/-/wikis/calibration/diff?version_id=95a3dc2360c331014d0f69f9298f9d3798f431f4)。

### 18.34 JTAG Wishbone mailbox 讀取 WR 內部暫存器（2026-08-15）

#### 實驗名稱

JTAG Wishbone mailbox runtime register readback。

#### 為了驗證什麼

RS422 路徑目前沒有接到 pain 主機，因此無法直接執行 WRPC shell 的 `wrc# stat`。本實驗在獨立的 `jtag_wb_diag` 版本加入 JTAG mailbox，讓主機透過 Quartus 17 的 In-System Sources and Probes（系統內部訊號源與探針）送出一次 Wishbone（FPGA 內部暫存器匯流排）讀取，再讀回 `xwr_core` 的 PPS generator 與 SoftPLL 暫存器。目的在於把「WRPC 沒有進入同步狀態」與「JTAG 讀取工具本身有問題」分開。

#### 改了什麼

1. 新增 `jtag_wb_diag/wr_jtag_wb_mailbox.vhd`。
2. JTAG source probe instance 1 接收 request toggle、讀取/寫入選擇、byte select、address 與 data。
3. mailbox 只執行單一 classic Wishbone cycle，完成後以 persistent done toggle 回報，避免 JTAG 讀取時錯過只有一個 clock 週期的 `ack`。
4. 保留既有 status probe instance 0，沒有修改 QSFP-A lane 0、DMTD 參考時鐘或正式 RS422 基準版本。
5. 新增 `jtag_wb_diag/read_wr_wb_diag.tcl`，讀取：
   - PPS control register：`0x00100300`
   - PPS external sync control register：`0x0010031C`
   - SoftPLL CSR：`0x00100200`
   - SoftPLL external clock control：`0x00100204`
   - SoftPLL output channel control：`0x00100210`

#### 編譯證據

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 261 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 261 warnings
Quartus 版本: 17.0.0 Build 595
```

#### 燒錄證據

```text
JTAG mailbox Master checksum: 0x3098FB5E
JTAG mailbox Slave  checksum: 0x30962662
兩片皆 Configuration succeeded / Successfully performed operation(s)
```

#### pain terminal 實際讀值

兩片 JTAG mailbox 都成功回傳暫存器值：

```text
=== DE5 [1-11.1] ===
status_probe: 000102E338BC82CF
PPS_CR:       00000000
PPS_ESCR:     00000000
SPLL_CSR:     01010000
SPLL_ECCR:    00000000
SPLL_OCCR:    00000000

=== DE5 [1-11.2] ===
status_probe: 000102C1245082CF
PPS_CR:       00000000
PPS_ESCR:     00000000
SPLL_CSR:     01010000
SPLL_ECCR:    00000000
SPLL_OCCR:    00000000
```

其中 `0x01010000` 依 SoftPLL register definition 解碼為 1 個 reference channel、1 個 output channel；它證明 SoftPLL 相關硬體區塊存在並可被讀取，但不是「已鎖定」的證據。`PPS_CR=0` 表示 PPS counter/output 沒有被啟用；`PPS_ESCR=0` 表示 `PPS_VALID` 與 `TM_VALID` 都沒有被設成 1。這與 status probe 的低 16-bit `0x82CF` 完全一致：`tm_link_up=1`、`link_ok=1`，但 `time_valid=0`、`pps_valid=0`。

#### 結果怎麼看

這次可以確認三件事：

1. QSFP-A lane 0 的 PHY/PCS link 仍能建立；兩片不是完全沒有光路。
2. JTAG mailbox、Wishbone address、PPS/SoftPLL register map 都能正常工作，因此「讀不到 WR 狀態」不是單純工具讀取失敗。
3. 目前仍不能宣稱 White Rabbit 時間同步成功。硬體 link up 只代表 Ethernet/PCS 可通；要宣稱同步，至少還需要 WRPC runtime 的 `lock:1`、Slave 進入 `TRACK_PHASE`，以及 status probe 的 `time_valid=1`、`pps_valid=1`。

`PPS_CR/PPS_ESCR` 為 0 的最直接解釋是：目前 FPGA 內的 WRPC firmware 沒有把 PPS generator 啟用，或 PTP/SoftPLL state machine 尚未完成啟動；它不能單獨證明是光纖品質、QSFP pre-emphasis 或 lane polarity 問題。下一步應取得真正的 `wrc# stat`/`ptp get` runtime 輸出，或在不改動正式光路的前提下確認 firmware boot 與 PTP packet state。

#### 恢復基準版本與最後狀態

診斷完成後，沒有把 JTAG mailbox 版本留在板上，重新燒錄 `rs422_uart_diag`：

```text
Master checksum: 0x3088011E
Slave  checksum: 0x308FFC95
兩片皆 Configuration succeeded / Successfully performed operation(s)
```

恢復後重新讀取：

```text
Master probe_hex: 000102C1205082CF
Slave  probe_hex: 000102C1205082CF
```

因此目前兩片 DE5a 已回到同一份 RS422 診斷基準，`0x82CF` 的解讀仍是「link up、尚未取得 time-valid/pps-valid 證據」，沒有把診斷版結果誤當成同步成功。

### 18.33 RS422 UART 診斷與取消 SFP 型號匹配的 A/B 實驗（2026-08-15）

#### 實驗目的

前一版只有 JTAG 低 16-bit 狀態，無法直接看到 WRPC（White Rabbit PTP Core，White Rabbit 精密時間同步核心）的 `wrc# stat`。本實驗先加入實體 RS422（Recommended Standard 422，差動串列介面）腳位，確認是否能取得 WRPC CLI；接著建立一份只移除 `sfp match`、保留 Master/Slave PTP 啟動的診斷版，檢查 QSFP+ 記憶體格式或 SFP 型號匹配是否是 `time_valid=0` 的唯一原因。

#### 實驗 1：RS422 UART 診斷版

**修改內容**：在獨立的 `rs422_uart_diag` 版本加入 `RS422_DE`、`RS422_DIN`、`RS422_DOUT`、`RS422_RE_n`，並將 `xwr_core` 的 `uart_rxd_i/uart_txd_o` 接到這組差動介面。Master 與 Slave 都使用 Quartus 17 完整編譯。

**編譯結果**：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 262 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 262 warnings
```

**燒錄結果**：

```text
Master checksum: 0x3088011E
Slave  checksum: 0x308FFC95
兩片皆 Configuration succeeded / Successfully performed operation(s)
```

**主機端檢查**：pain 沒有 `/dev/ttyUSB*` 或 `/dev/ttyACM*`，`lsusb` 也沒有 USB-RS422/USB-UART 轉接器。因此雖然 FPGA 已輸出 RS422 腳位，現在仍沒有可從 SSH 讀取 `wrc#` 的實體主機接收端。這表示 UART 診斷路徑已編譯、已燒錄，但尚未具備讀取條件。

#### 實驗 2：取消 SFP 型號匹配的 A/B

**修改內容**：複製成獨立的 `nosfpmatch_rs422_diag`，使用新的 Master/Slave firmware；初始化命令分別為：

```text
Master: vlan off;ptp stop;mode master;ptp start
Slave : vlan off;ptp stop;mode slave;ptp start
```

此版本只拿掉 `sfp match`，沒有改動 QSFP lane、TX pre-emphasis 18、DMTD 參考時鐘或校正資料庫，目的是隔離單一因素。

**編譯結果**：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 262 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 262 warnings
```

**燒錄與 JTAG 結果**：兩片診斷版均成功燒錄。等待約 15 秒後讀取：

```text
Master probe_hex: 000102E130BC82CF
Slave  probe_hex: 000102C1285082CF
```

低 16-bit 仍為 `0x82CF`：

```text
tm_link_up = 1    link_ok = 1    time_valid = 0    pps_valid = 0
rx_enc_err = 0    tx_enc_err = 0
```

**結果判讀**：取消 SFP 型號匹配沒有讓 `time_valid` 或 `pps_valid` 變成 1，因此不能把「SFP 型號匹配」單獨判定為唯一故障原因。這個結果也不能證明 QSFP+ 完全相容，因為沒有 `wrc# stat`、沒有 `lock:1`、沒有 Slave `TRACK_PHASE`，而且這個診斷版本沒有正式的模組校正值。

#### 恢復正式診斷基準

為避免把未完成校正的 no-SFP-match 版本留在板上，實驗結束後重新燒錄 `rs422_uart_diag`：

```text
Master checksum: 0x3088011E
Slave  checksum: 0x308FFC95
```

等待 10 秒後再次讀取：

```text
Master probe_hex: 000102E1373C82CF
Slave  probe_hex: 0001026334BC82CF
```

恢復結果與診斷版一致：PHY/PCS link 保持正常，但時間同步仍沒有證據。

#### 本次結論與下一步

1. 編譯與燒錄流程正常；兩片 DE5a 的 QSFP-A lane 0 仍可建立 Ethernet/PCS link。
2. `sfp match` 不是目前唯一可疑點；移除它沒有改善 `time_valid`/`pps_valid`。
3. 目前最缺的是可讀取 WRPC runtime 狀態的路徑。下一個最有效的低風險步驟是接上 RS422/USB-UART 接收器，或在不改動 QSFP 資料路徑的前提下建立 JTAG mailbox，取得 `wrc# stat`、`ptp get` 與 `sfp show` 的實際輸出。
4. 取得 runtime 輸出後，才可區分 PTP state machine 未啟動、SoftPLL/DMTD 未鎖定、QSFP+ calibration 缺失，或光路方向/模組相容性問題。現在的 `0x82CF` 只能宣稱 link up，不能宣稱 WR synchronized。

### 18.35 62.5 MHz WR core 時鐘隔離診斷與雙板 A/B 測試（2026-08-15）

#### 1. 實驗名稱

**62.5 MHz WR core system clock isolation A/B test**。

#### 2. 實驗目的

前面的專案雖然把 WR core 的系統時鐘接到 DE5a 的 50 MHz 板上時鐘，然而 WR-cores 原始設定與 firmware 都以 62.5 MHz 作為系統時鐘基準。這次建立一個獨立診斷版本，使用 PLL 將 50 MHz 轉成 62.5 MHz，只把 `xwr_core` 和 JTAG mailbox 切換到這個時鐘，藉此判斷「系統時鐘頻率不一致」是否是 WRPC 沒有進入正常初始化的主因。

另外，使用者要求的 Transmitter Pre-Emphasis First Post-Tap Magnitude = 18 已經存在於本次 JTAG 診斷版 Master/Slave 的 QSF 設定；這次沒有再修改成其他數值，避免把時鐘與類比 TX 參數混在同一個實驗中。

#### 3. 實驗修改內容

在不改動原始 `jtag_wb_diag`、`rs422_uart_diag` 與唯讀參考專案的前提下，複製建立：

```text
/home/b10504072/04_White_Rabbit/week02/v01/clock625_jtagwb_diag/
```

主要修改如下：

1. 新增 `wr_sys_clk_625.vhd`，以 Arria 10 `altpll` 將 `CLK_50_B2J` 的 50 MHz 轉成 62.5 MHz。
2. Master 與 Slave 的 `xwr_core.clk_sys_i` 改接 62.5 MHz PLL 輸出。
3. JTAG mailbox 改用同一個 62.5 MHz，並以 PLL lock 狀態作為 core reset 的釋放條件。
4. 補回隔離資料夾遺漏的 SI5340 控制器來源：`si5340a_controller_dco.v`、`si5340a_i2c_reg_controller_dco.v`、`i2c_bus_controller_dco.v`。
5. 新增受控 runtime snapshot 腳本，短暫讀取 CPU uptime、版本與 static register，再釋放 CPU reset；這是診斷操作，不是正式 WR runtime 介面。

#### 4. 編譯結果

Quartus 17.0 使用完整 flow 編譯，結果如下：

```text
Master: Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
Slave : Quartus Prime Full Compilation was successful. 0 errors, 264 warnings
```

TimeQuest 也成功完成，但仍提示原設計有部分 setup/hold 未完全約束。這些是既有設計警告，不是本次 62.5 MHz 修改造成的 fatal error。

#### 5. 燒錄與 pain terminal 證據

兩片診斷版都成功燒錄：

```text
Master clock625 checksum: 0x30991898
Slave  clock625 checksum: 0x30992C59
Configuration succeeded
Successfully performed operation(s)
```

燒錄後用 JTAG mailbox 讀取的主要結果：

```text
Master status_probe: 000202C1255082CF
Slave  status_probe: 000202E132BC82CF

Master PPS_CR : 00000000
Master PPS_ESCR: 00000000
Slave  PPS_CR : 00000000
Slave  PPS_ESCR: 00000000

Master SPLL_CSR: 01010000
Slave  SPLL_CSR: 01010000
```

兩片低 16-bit 都是 `0x82CF`，可解讀為：

```text
tm_link_up = 1
link_ok    = 1
time_valid = 0
pps_valid  = 0
rx_enc_err = 0
tx_enc_err = 0
```

受控 runtime snapshot 等待約 5 秒後，兩片的 uptime 仍未形成可接受的遞增 runtime 證據；同時 `PPS_CR`、`PPS_ESCR` 仍為 0。這表示目前沒有取得 `wrc# stat`、`TRACK_PHASE` 或 `time_valid/pps_valid=1` 的證據。

#### 6. 結果解讀

這次實驗得到兩個清楚結果：

1. **62.5 MHz 版本可以正確編譯與燒錄，並沒有破壞 QSFP-A lane 0 的 link。**
2. **只把 WR core 系統時鐘從 50 MHz 改成 62.5 MHz，沒有讓 WRPC 進入可證明同步的狀態。**

因此目前不能下結論說 50 MHz 一定是唯一故障原因；它仍是合理的設計風險，但 A/B 結果顯示還有其他問題需要確認，例如 firmware reset/啟動路徑、DMTD/SoftPLL 參考時鐘接線、WRPC runtime 的可讀取介面，以及 QSFP/PHY 的正式 calibration。`SPLL_CSR=0x01010000` 只能表示 SPLL register block 可讀且有基本設定，不能直接當作「SPLL 已鎖定」。

本次測試完成後已恢復原本的 RS422 baseline：

```text
Master checksum: 0x3088011E
Slave  checksum: 0x308FFC95
```

恢復燒錄成功。原本的 JTAG mailbox 只存在診斷版，因此在 RS422 baseline 上執行 mailbox 讀取時會出現 `No In-System Sources and Probes instance was found`；這是介面不匹配，不是新增的 WR link failure。恢復後仍以原有低 16-bit link probe 作為保守檢查，不能把它延伸解讀成時間同步成功。

#### 本次實驗結論

目前最可靠的結論是：**光路/PCS link 已建立，但 WR 時間同步尚未被證明；TX pre-emphasis=18 與 62.5 MHz 修正都已實際完成 A/B，仍不足以讓 `time_valid`、`pps_valid` 或 `TRACK_PHASE` 成立。** 下一步應優先建立真正可讀取 WRPC runtime 的 UART/RS422 或穩定 JTAG mailbox，並取得兩片的 WRPC state、SoftPLL lock 與 PPS 狀態，再進行光模組/Port A/B 的替換測試。
