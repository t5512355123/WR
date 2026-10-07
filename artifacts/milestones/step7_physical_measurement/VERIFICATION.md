# Step7：Master／Slave SMA PPS 實體同步觀測

文件整理日期：2026-10-07（Asia/Taipei）。截圖的實際取得時間未提供。
分支：`step7-physical-measurement`；整理前 HEAD：`97462457c753ff48f15c8361e405e21a4180b59f`。

## 結論

**`STAGEWISE_PHYSICAL_ALIGNMENT_OBSERVED`：支持奈秒等級的實體 PPS 對齊。**
使用者表示觀測期間沒有明顯漂移，可作 White Rabbit 實體同步的階段性驗證。
沒有宣稱已完成皮秒精度校準、長時間漂移統計、抖動量測或新一輪 TIME_VALID 300 秒驗收。

![原始觀測圖（未重新繪製或修改）](raw/observe/master-slave-pulse.png)

## 設定與連線

| 項目 | 設定／來源 |
|---|---|
| 儀器 | RIGOL DS1104Z Plus，使用者提供型號 |
| 通道 | CH1 黃色＝Master；CH2 青色＝Slave，依圖上使用者標註 |
| 訊號 | 兩台 SMA_CLKOUT → WR Core 的 pps_p_o；由兩份 top-level 核查 |
| 參考 clock | 125 MHz，Clock Period=8 ns |
| PPS 重複週期 | 1 秒（1 Hz）；使用者設定描述 |
| PPS 脈寬設定 | 10 ms＝1,250,000 ticks × 8 ns；占空比約 1% |
| 採樣／畫面 | 500 MSa/s＝2 ns/sample；5 ns/div；30.0 pts |
| 垂直刻度 | CH1 與 CH2 均為 2.00 V/div |
| 畫面狀態 | STOP；非逐筆連續時間序列 |
| 統計次數 | 圖上標註 60 次 pulse，由使用者提供；未附原始 60 筆資料 |

原始碼依據：

- `vendor/wrpc-sw/include/wrc.h`：`PPS_WIDTH (10 * 1000 * 1000 / NS_PER_CLOCK)`，註解 10ms。
- `vendor/wrpc-sw/dev/pps_gen.c`：初始化 PPS pulse-width 寄存器。
- `vendor/wrpc-sw/boards/generic/board-config.h` 與兩份 top-level 的 `g_pcs_16bit=false`：8 ns 參考週期。
- `vendor/wr-cores/modules/wr_pps_gen/wr_pps_gen.vhd`：PPS 的可設定寬度輸出。
- `quartus/DE5a_wr_master_jtag.vhd`、`quartus/DE5a_wr_slave_jtag.vhd`：`pps_p_o => SMA_CLKOUT`。

1,250,000 是脈寬的設定 tick 數；這張邊緣放大圖不量測完整脈寬，
也未對 RTL 計數／輸出管線做 cycle-exact 的脈寬驗收。本次沒有修改任何脈寬、servo 或 RTL。

## 從圖中讀出的延遲統計

| CH1→CH2 上升緣延遲 | 畫面顯示 |
|---|---:|
| Current | −600.0 ps（−0.6000 ns） |
| Average | −86.44 ps（−0.08644 ns） |
| Maximum | +1.400 ns |
| Minimum | −1.700 ns |
| 範圍（Max−Min） | 3.100 ns |

正負號保留儀器定義，不由單張圖推論固定的物理領先方向。
沒有從影像像素擬合額外的 ps 值，也沒有把平均值解讀為單次誤差上限。

## 為何不宣稱 −86.44 ps 的實際準確度

RIGOL 官方資料表列出本型號的 100 MHz 類比頻寬，以及雙通道 500 MSa/s 的採樣規格：
[DS1000Z 官方資料表](https://www.rigol.com/dam/global/downloads/brochures/en/data-sheet/oscilloscopes/DS1000Z_DataSheet_EN.pdf)。

採樣點是離散的，曲線顯示與邊緣估計可能使用插值／重建。資料表列有插值功能，
但截圖未顯示本次實際選用的插值模式。插值與平均可產生小於採樣間隔的估計值，
所以「每 2 ns 採樣」不是一條絕對的 2 ns 不確定度下限；反過來，
**輸出 ps 位數也不等於儀器或完整量測鏈具備同等精度**。
類比頻寬、雜訊、邊緣 slew rate／量測門檻、線材長度與通道 skew 均會影響結果。
未提供同源分路校準、線材互換、儀器暖機／校準狀態或不確定度預算。

因此，本次確認的層級是「所示觀測條件下，兩路 PPS 邊緣為奈秒等級對齊」。
「沒有明顯漂移」是使用者在現場的觀察，不是由平均／最大／最小統計值證明漂移率為零。
未提供逐筆時間戳記資料，無法量化長時間漂移或 Allan deviation。
示波器的實體通道延遲不等同韌體 CKO，也不直接量測 DE5a 振盪器的固有 jitter。

## 封存與來源界線

目前保留的 build/output 來源為 `4d7e38189e26707afffb2ecc404f3ad0e8a08326`，
與 [2026-10-05 Step7 恢復實驗](../EXP-S7-SLAVE-BOOTSTRAP512-OPERATING-POINT-20261005/REPORT.md) 一致。
Slave bootstrap=512、Master=2048、WR acquire `/2`／track `/12`，60/120 ps 門檻不變。
Master 原 `1-11.1` 拔離 PCIe、以外接 6-pin 供電，Slave 原 `1-11.2` 留在 PCIe；
這是前輪記錄的拓樸，截圖沒有再獨立記錄量測當下的供電接線或載入版本。

封存 SOF：

- Master：36,818,536 bytes；`0fd28157e3652dfaa56e5c14f57c66bc4bd2d4d6ae1a6a74576617e76c5319dd`。
- Slave：36,831,090 bytes；`3565f6b18929341613616e7b03a6aac10a53da0e5953444611ca74e8e3d1e32d`。

使用者提供的截圖未附量測當時 loaded-image 身分紀錄；封存的是目前 Step7 的保留程式與產物，
**不是新的 exact-image fresh-program 重現證據**。
Step7 milestone 包含這張未改動的原圖、本報告、前輪 build/program/recovery 紀錄、
完整 production snapshot、所有 scripts/dashboard、韌體與 SOF。
包裝排除其他 milestone 與失敗 candidate，避免循環封存；只在封存內將 publication manifest
縮限為所包含的 build/output，主程式 manifest 與四步驟工作流程不變。

本次沒有 compile、program、JTAG capture、reset 或 power-cycle。
不修改 Step1–6 milestone 或 `/home/b10504072/04_WR_archive_step6_pass/`；不合併 main。
封存可供後續從外部工作目錄重現，但本次只驗證封存完整性／離線解包，未重新做硬體驗收。

## 狀態記錄

```text
PHYSICAL_PPS_NS_ALIGNMENT = OBSERVED
NO_OBVIOUS_DRIFT = USER_REPORTED_NOT_QUANTIFIED
CALIBRATED_PICOSECOND_ACCURACY = NOT_ESTABLISHED
MEASUREMENT_LOADED_IMAGE_ID = NOT_INDEPENDENTLY_VERIFIED
FRESH_STANDALONE_HARDWARE_REPRODUCTION = NOT_RUN
NEW_TIME_VALID_300S_CAPTURE = NOT_RUN
```
