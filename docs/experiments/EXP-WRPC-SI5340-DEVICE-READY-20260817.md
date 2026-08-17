# 實驗紀錄：SI5340 DEVICE_READY 讀回驗證

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SI5340-DEVICE-READY-20260817`
- 日期：2026-08-17
- 實驗分支：`exp/jtag-runtime-observability`
- 硬體/腳本 source commit：`9f525db9c4ab290cc91bacd39bc545a51adb13d4`

## 這次想驗證什麼

上一輪 readback 的 `0x001D FINC/FDEC` 是 self-clearing register，讀回 `0x00` 不能判定 I2C read path 失敗。本輪改讀 SI5340 官方定義的 page-independent `0x00FE DEVICE_READY`，用已知 expected value 判斷 read transaction 是否能正確取得 SDA 資料；同時保留 page 3 `0x0339` 作為專案 static configuration 的另一個讀值。

官方 Si5340 Rev D manual 對 `0x00FE` 的說明是：device ready 時 read data 應為 `0x0F`，且每個 page 都有此 register，因此不需要先切 page。

## 相較 baseline 唯一修改了什麼

相較於 `31268c2` 的 readback-handshake 版本：

1. readback sequence 的第二個讀取位址由 `0x001D` 改為 page-independent `0x00FE`。
2. probe/Tcl 欄位名稱由 `page0_001D` 改為 `device_ready_00FE`。
3. 不改 SI5340 DCO write transaction、PHY、PTP filter、servo、SoftPLL threshold 或 DPLL。

## 編譯與硬體識別

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`、Version 17.0.0 Build 595
- QSF SHA-256：待 compile 後填寫
- SDC SHA-256：待 compile 後填寫
- Master MIF SHA-256：本輪不重新燒錄 Master
- Slave MIF SHA-256：待 compile 後填寫
- Slave SOF SHA-256：待 compile 後填寫
- Compile log SHA-256：待 compile 後填寫
- Full Compilation：待 compile 後填寫
- Timing：待 compile 後填寫

## 燒錄結果

待 compile 成功後僅燒錄 Slave `DE5 [1-11.2]`，並填入 checksum、JTAG ID、configuration result、Quartus warnings/errors、時間與 programmer log hash。

## JTAG/runtime 原始結果

預定執行：

1. `read_dco_diag.tcl 1000`：保存 ACK 與 `page3_0039/device_ready_00FE`。
2. `read_wb_timeseries_session.tcl 60 1000 3`：確認診斷 readback 修改沒有破壞 Slave runtime。

原始 log 路徑與 SHA-256：待實驗完成後填寫。

## Observation

待填寫：

- `device_ready_00FE` 是否為 `0x0F`
- `page3_0039` 是否與 static/runtime 寫入狀態一致
- Slave accepted/rejected sample 數量
- Slave `SSTAT`、`PSTAT.locked`、`spll_locked`、`time_valid`、`pps_valid`
- parent、REF/TAG/UCNT activity

## Conclusion

待依原始資料填寫。即使 `DEVICE_READY=0x0F`，也只能證明 I2C read path 基本可讀，不能單獨宣稱 SI5340 output clock effect 或 White Rabbit synchronization 成功。

## Next Step

若 `DEVICE_READY` 不是 `0x0F`，繼續查 I2C SDA sampling/shift timing。若 `DEVICE_READY=0x0F` 且 Slave 仍 `PSTAT.locked=0`，再把重點收斂到 SI5340 runtime clock effect、DCO register semantics 或 helper/servo lock path；一次只改一個變因。
