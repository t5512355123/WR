# 目前狀態

最後更新：2026-08-15
Audit 內容 commit：`44e8ba48285634a39860ef5732e69317f5f7da79`
建置主機：pain；Master/Slave 韌體與 Quartus 17 建置均已驗證

## 目前已知可用的基準版本

- Project：`quartus/rs422_uart_diag`
- Master SOF programmer checksum：`0x3088011E`
- Slave SOF programmer checksum：`0x308FFC95`
- QSFP-A lane 0 是目前使用的 WR link path。
- Master 與 Slave 在 Quartus Programmer 都設定成功。
- 兩片板卡的 status probe 低 16 bits 都觀察到 `0x82CF`。
- 該 probe 顯示 `link_up=1`、`link_ok=1`，且 RX/TX encoding error 為 0。

## 目前觀察結果

- 現有 probe 證據中的 `time_valid=0`。
- 現有 probe 證據中的 `pps_valid=0`。
- JTAG 除錯版本中的 `PPS_CR` 與 `PPS_ESCR` 為 0。
- 62.5 MHz clock isolation 實驗已編譯並燒錄成功，但沒有產生執行期同步證據。

## 遷移驗證

- Git 原始碼來源：本機 repository 推送到 GitHub，pain 的工作副本從 `origin/main` fast-forward 更新。
- Master 韌體：PASS；Slave 韌體：PASS。
- Master Quartus 17：PASS，0 errors，262 warnings。
- Slave Quartus 17：PASS，0 errors，262 warnings。
- 乾淨的最新 commit checkout 已重新建置兩份韌體與兩份 SOF。
- 精確 artifact commit checkout 已重新建置兩份韌體。WRPC 會嵌入 `__DATE__`/`__TIME__`，因此各次建置都記錄自己的 image hash，不把不同次執行視為 byte-identical。
- 本次遷移驗證沒有燒錄新的 SOF。

## Timing 狀態

Quartus compilation success 與 timing closure 是兩件不同的事。記錄的
TimeQuest report 如下：

- Master: setup `-3.812 ns`, hold `0.039 ns`, recovery `-1.975 ns`, removal
  `0.298 ns`; 3 unconstrained clocks, 1992 input paths and 83 output paths.
- Slave: setup `-3.103 ns`, hold `0.030 ns`, recovery `-1.839 ns`, removal
  `0.326 ns`; 3 unconstrained clocks, 2001 input paths and 83 output paths.
- Timing closed：兩個版本皆為 **NO**。

## 尚未證明

- uRV/wrpc-sw 執行期初始化
- PPSi state 與 Slave `TRACK_PHASE`
- SoftPLL lock
- 有效的 WR global time
- 校準後的 TX/RX delay
- 次奈秒等級的 PPS alignment

## 目前技術瓶頸

建立穩定的 WRPC 執行期讀取路徑，接著在不改變基準 PHY/PTP 行為的前提下，取得 `wrc# stat`、PTP state、SoftPLL lock 與 PPS 證據。

## 下一個實驗

建立獨立的 timing/constraint 實驗，調查負值 TimeQuest slack 與 unconstrained clocks；同時保持本次遷移 commit 與保留的 RS422 artifact set 不變。

## 目前板卡 bitstream

以下是保留的基準 artifact，本文件不會重新產生它們：

- Master：pain `/home/b10504072/04_WR/artifacts/EXP-BASELINE-RS422/master.sof`
- Slave：pain `/home/b10504072/04_WR/artifacts/EXP-BASELINE-RS422/slave.sof`

原始 Quartus output directory 仍保留在正式副本旁，以便追溯。正式韌體輸入位於 pain `/home/b10504072/04_WR/artifacts/EXP-BASELINE-RS422/master.mif` 與 `slave.mif`。

## 工作流程不變條件

每個新實驗都必須記錄 Git commit、精確的 Master/Slave 原始碼、MIF SHA256、Quartus 版本、QSF/SDC SHA256、SOF SHA256、建置主機與 probe output。
